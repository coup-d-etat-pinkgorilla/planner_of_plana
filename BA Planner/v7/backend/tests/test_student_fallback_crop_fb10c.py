"""FB10c first weapon ROI producer + actual repository/session image lifetime."""
from copy import deepcopy
from io import BytesIO
from pathlib import Path
from threading import Event
from types import SimpleNamespace
import base64
import json
import tempfile
import unittest
from unittest.mock import Mock, patch

from PIL import Image
from jsonschema import Draft202012Validator

from core.repository_store import JsonRepository
from core.repository_dto import FieldEvidence
from core.scanner_session import ScannerSessionService
from core.student_fallback_evidence import weapon_fallback_review_details
from core.scanner_matchers import StudentMatcherAdapter
from core.student_scan_recognizer import Observation, StudentBasicCropSet


ROOT = Path(__file__).resolve().parents[2]
PAYLOAD = {
    "version": 1, "student_id": "shiroko", "values": {"level": 90},
    "provenance": {"level": "synthetic_lifecycle_fixture"},
}


def evidence():
    return [{
        "field": "weapon_level_fallback", "status": "ok",
        "source": "weapon_panel_fallback", "confidence": 1.0,
        "note": "synthetic lifecycle evidence",
        "details": {
            "crop_png_base64": "synthetic_image_marker",
            "crop_source": "basic_info", "crop_width": 8, "crop_height": 4,
            "delta": {"AttackPower": 0},
        },
    }]


class StudentFallbackCropTests(unittest.TestCase):
    def case(self, *, two=False, private=True):
        temporary = tempfile.TemporaryDirectory(prefix="ba_planner_fb10c_")
        self.addCleanup(temporary.cleanup)
        repository = JsonRepository(Path(temporary.name))
        pid = repository.create_profile("Synthetic lifecycle", "create")['profile']['profile_id']
        crop = Image.new("RGB", (8, 4), "red") if private else None
        rows = [{"payload": deepcopy(PAYLOAD), "evidence": evidence()}]
        if private:
            rows[0]["_answer_specimen"] = {"numeric_groups": {"test": (crop,)}}
        if two:
            rows.append({"payload": deepcopy(PAYLOAD), "evidence": evidence()})
        ids = iter(["s", "c1", "c2"])
        sink = []
        service = ScannerSessionService(
            target_provider=lambda: [{"target_id": "fixture", "title": "Synthetic", "status": "ready"}],
            student_matcher=lambda *_: rows, inventory_matcher=lambda *_: [],
            repository=repository, asset_status=lambda: {"ready": True},
            event_sink=sink.append, id_factory=lambda: next(ids),
        )
        self.addCleanup(service.close)
        service.start("student", "fixture", profile_id=pid)
        service.wait("s")
        return service, repository, pid, crop, sink

    def images_present(self, value):
        return 'crop_png_base64' in json.dumps(value)

    def commit(self, service, pid):
        return service.commit(session_id="s", generation=1, candidate_id="c1",
                              candidate_revision=1, profile_id=pid,
                              expected_repository_revision=0, idempotency_key="commit")

    def test_actual_adapter_only_encodes_existing_weapon_fallback_named_basic_crop(self):
        level = Image.new("RGB", (8, 4), "red")
        star = Image.new("RGB", (9, 3), "blue")
        crops = StudentBasicCropSet(
            images={"basic_weapon_level_digits_quad": level, "basic_weapon_star_region": star},
            cell_groups={}, source_size=(1280, 720), regions={},
        )
        adapter = object.__new__(StudentMatcherAdapter)
        identity = SimpleNamespace(student_ref="shiroko", source="synthetic_identity", score=1.0, margin=1.0)
        adapter.name_matcher = None
        adapter._capture_identified = lambda *_: (Image.new("RGB", (1, 1)), identity)
        def cut(frame):
            frame.close()
            return crops
        adapter._basic_crops = cut
        adapter._activate_numeric_samples = Mock()
        observations = {
            "student_star": Observation(5, 1, "ok", "fixture", ""),
            "weapon_level": Observation(None, .4, "uncertain", "fixture", "rejected basic read"),
            "weapon_star": Observation(4, 1, "ok", "fixture", ""),
        }
        state = Observation("weapon_equipped", 1, "ok", "basic_weapon_state_template", "")
        adapter._read_growth_fields = Mock(return_value=(observations, state))
        adapter._resolve_equipment = Mock()
        adapter.weapon_menu = object()
        adapter.weapon_recognizer = SimpleNamespace(recognize_menu=Mock())
        adapter.equipment_recognizer = SimpleNamespace(
            last_binary_shadow={}, last_generated_binary_shadow={}, last_position_binary_shadow={},
        )
        recovered = Observation(30, 1, "ok", "weapon_menu_template", "actual result fixture")
        with patch(f'{StudentMatcherAdapter.__module__}.read_panel_fields', return_value={"weapon_level": recovered}) as reader:
            row = adapter._scan_current({}, Event(), lambda *_: None)[0]
        reader.assert_called_once()
        self.assertEqual(30, row['payload']['values']['weapon_level'])
        raw_fallback = next(item for item in row['evidence'] if item['field'] == 'weapon_level_fallback')
        FieldEvidence.from_dict(raw_fallback)
        self.assertNotIn('details', raw_fallback)
        service, _, _, _, _ = self.case(private=False)
        candidate = service._make_candidate(service._sessions['s'], row).to_wire()
        fallback = next(item for item in candidate['evidence'] if item['field'] == 'weapon_level_fallback')
        self.assertIn('trigger_source=fixture', fallback['note'])
        self.assertEqual('basic_info', fallback['details']['crop_source'])
        with Image.open(BytesIO(base64.b64decode(fallback['details']['crop_png_base64']))) as decoded:
            self.assertEqual((8, 4), decoded.size)
            self.assertEqual((255, 0, 0), decoded.getpixel((0, 0)))
        self.assertEqual(1, sum('crop_png_base64' in item.get('details', {}) for item in candidate['evidence']))
        self.assertNotIn('inverse_value', fallback['details'])
        self.assertEqual({}, crops.images)
        with self.assertRaises(ValueError):
            level.getpixel((0, 0))

    def test_normal_fields_and_missing_crop_never_gain_image_or_inverse_value(self):
        normal = [{"field": "weapon_level", "status": "ok", "source": "basic"},
                  {"field": "weapon_star_fallback", "status": "uncertain", "source": "weapon_panel_fallback"}]
        self.assertEqual({}, weapon_fallback_review_details(normal, SimpleNamespace(images={})))
        self.assertFalse(self.images_present(normal))
        self.assertNotIn('inverse_value', json.dumps(normal))

    def test_hold_edit_and_calculation_revalidation_preserve_review_crop(self):
        service, _, _, crop, _ = self.case()
        service.review("s", 1, "c1", 1, deepcopy(PAYLOAD), approve=False, reason="held_in_scan_page")
        service.review("s", 1, "c1", 2, deepcopy(PAYLOAD), approve=False, reason="edited_and_revalidated_in_scan_page")
        service._student_validator = lambda *_: {"field": "student_stat_validation", "status": "verified", "source": "synthetic_validation"}
        service.revalidate("s", 1, "c1", 3)
        self.assertTrue(self.images_present(service.snapshot("s", 1)))
        self.assertEqual((255, 0, 0), crop.getpixel((0, 0)))

    def test_approval_redacts_retained_event_copies_and_preserves_other_candidate(self):
        service, _, _, crop, _ = self.case(two=True)
        response = service.review("s", 1, "c1", 1, deepcopy(PAYLOAD), approve=True, reason="approved_in_scan_page")
        self.assertFalse(self.images_present(response))
        self.assertEqual({"AttackPower": 0}, response['evidence'][0]['details']['delta'])
        snapshot = service.snapshot("s", 1)
        first = [e['payload']['candidate'] for e in snapshot['events'] if e['payload'].get('candidate', {}).get('candidate_id') == 'c1']
        self.assertFalse(self.images_present(first))
        self.assertTrue(self.images_present(service.candidate("s", 1, "c2")))
        with self.assertRaises(ValueError):
            crop.getpixel((0, 0))

    def test_discard_redacts_encoded_crop_even_when_private_specimen_is_empty(self):
        for reason in ('discarded_in_scan_page', 'discarded_in_student_page'):
            with self.subTest(reason=reason):
                service, _, _, _, _ = self.case(private=False)
                response = service.review("s", 1, "c1", 1, deepcopy(PAYLOAD), approve=False, reason=reason)
                self.assertFalse(self.images_present(response))
                self.assertFalse(self.images_present(service.snapshot("s", 1)))

    def test_durable_commit_redacts_candidate_events_and_replays_original_receipt(self):
        service, repo, pid, crop, _ = self.case()
        response = self.commit(service, pid)
        self.assertFalse(self.images_present(service.snapshot("s", 1)))
        self.assertFalse(self.images_present(repo.get_state(pid)))
        self.assertEqual(response, self.commit(service, pid))
        receipt = service._current_commits[("s", "commit")]
        self.assertIsNone(receipt.request)
        self.assertFalse(self.images_present(json.loads(receipt.response_json)))
        for path in repo.root.rglob('*.json'):
            self.assertNotIn(b'crop_png_base64', path.read_bytes(), str(path))
        with self.assertRaises(ValueError):
            crop.getpixel((0, 0))

    def test_failed_repository_write_retains_crop_until_successful_original_retry(self):
        service, repo, pid, crop, _ = self.case()
        writer = repo.update_students
        calls = []
        def interrupted(*args, **kwargs):
            calls.append(1)
            if len(calls) == 1:
                raise OSError('synthetic failure before durable write')
            return writer(*args, **kwargs)
        with patch.object(repo, 'update_students', side_effect=interrupted):
            with self.assertRaises(OSError):
                self.commit(service, pid)
            self.assertTrue(self.images_present(service.snapshot('s', 1)))
            self.assertEqual((255, 0, 0), crop.getpixel((0, 0)))
            self.commit(service, pid)
        self.assertFalse(self.images_present(service.snapshot('s', 1)))

    def test_shutdown_redacts_server_state_but_cannot_recall_emitted_client_copies(self):
        service, _, _, crop, sink = self.case()
        self.assertTrue(self.images_present(sink))
        service.close()
        self.assertFalse(self.images_present(service.snapshot('s', 1)))
        self.assertTrue(self.images_present(sink))
        with self.assertRaises(ValueError):
            crop.getpixel((0, 0))

    def test_additive_details_and_redacted_details_validate_existing_protocol(self):
        service, _, _, _, _ = self.case()
        schema = json.loads((ROOT / 'contracts/scanner-protocol-v1.schema.json').read_text(encoding='utf-8'))
        validator = Draft202012Validator({'$ref': '#/$defs/candidate', '$defs': schema['$defs']})
        validator.validate(service.candidate('s', 1, 'c1'))
        service.review('s', 1, 'c1', 1, deepcopy(PAYLOAD), approve=False, reason='discarded_in_scan_page')
        validator.validate(service.candidate('s', 1, 'c1'))


if __name__ == '__main__':
    unittest.main()
