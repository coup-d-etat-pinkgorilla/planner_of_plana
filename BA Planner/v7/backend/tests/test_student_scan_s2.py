from __future__ import annotations

import json
from pathlib import Path
from threading import Event
import unittest

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.repository_dto import CONFIRMED_STUDENT_VALUE_FIELDS, ConfirmedStudent
from core.scanner_matchers import StudentMatcherAdapter
from core.scanner_session import ScannerError
from core.student_scan_recognizer import StudentBasicCropSet


BACKEND = Path(__file__).parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
FIXTURES = Path(__file__).parent / "fixtures"


class CountingCapture:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.stable_calls = 0

    def wait_stable(self, _target, cancel, timeout=2.0):
        if cancel.is_set():
            raise ScannerError("cancelled", "cancelled")
        self.stable_calls += 1
        return Image.open(self.path).convert("RGB")

    def capture(self, _target):
        raise AssertionError("S2 must use the single stable capture")

    def scroll(self, _target, _delta):
        raise AssertionError("student basic recognition must not scroll")


class StudentScanS2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = RecognitionAssetCatalog(ASSETS)
        cls.expected = json.loads(
            (FIXTURES / "student_scan_s2_serika_new_year.json").read_text(encoding="utf-8")
        )

    def test_real_fixed_basic_screen_matches_v6_observations_from_one_capture(self) -> None:
        capture = CountingCapture(FIXTURES / "student_scan_s2_serika_new_year.png")
        progress: list[tuple[int, int | None, str]] = []
        result = StudentMatcherAdapter(capture, self.catalog)(
            {"target_id": "fixture"}, Event(), lambda *item: progress.append(item)
        )[0]

        self.assertEqual(1, capture.stable_calls)
        self.assertEqual([0, 1, 2, 3, 4], [item[0] for item in progress])
        self.assertEqual(self.expected["student_id"], result["payload"]["student_id"])
        for field, value in self.expected["confirmed_values"].items():
            self.assertEqual(value, result["payload"]["values"][field], field)
        self.assertTrue(result["review_required"])
        evidence = {item["field"]: item for item in result["evidence"]}
        self.assertEqual("uncertain", evidence["skill2"]["status"])
        self.assertNotIn("skill2", result["payload"]["values"])
        self.assertEqual("ok", evidence["combat_hp"]["status"])
        self.assertEqual("inferred", evidence["weapon_state"]["status"])

    def test_payload_uses_only_repository_dto_fields_and_excludes_later_slices(self) -> None:
        capture = CountingCapture(FIXTURES / "student_scan_s2_serika_new_year.png")
        payload = StudentMatcherAdapter(capture, self.catalog)(
            {"target_id": "fixture"}, Event(), lambda *_item: None
        )[0]["payload"]
        parsed = ConfirmedStudent.from_dict(payload)
        self.assertEqual(payload, parsed.to_dict())
        self.assertLessEqual(set(payload["values"]), set(CONFIRMED_STUDENT_VALUE_FIELDS))
        s4_and_later = set(self.expected["excluded_s2_fields"]) - {
            "equip1", "equip2", "equip3", "equip4",
        }
        self.assertTrue(s4_and_later.isdisjoint(payload["values"]))

    def test_failed_field_does_not_erase_other_confirmed_fields(self) -> None:
        capture = CountingCapture(FIXTURES / "student_scan_s2_serika_new_year.png")
        result = StudentMatcherAdapter(capture, self.catalog)(
            {"target_id": "fixture"}, Event(), lambda *_item: None
        )[0]
        self.assertNotIn("skill2", result["payload"]["values"])
        for field, value in self.expected["confirmed_values"].items():
            self.assertEqual(value, result["payload"]["values"][field], field)

    def test_multi_form_template_identity_becomes_canonical_form_ref(self) -> None:
        self.assertEqual(
            "hoshino_battle#2",
            StudentMatcherAdapter._canonical_student_ref("hoshino_battle_1"),
        )

    def test_crop_set_owns_named_crops_without_retaining_full_frame(self) -> None:
        with Image.open(FIXTURES / "student_scan_s2_serika_new_year.png") as frame:
            crops = StudentBasicCropSet.from_frame(frame, self.catalog.region("student"))
        self.assertEqual((2560, 1440), crops.source_size)
        self.assertFalse(hasattr(crops, "frame"))
        self.assertIn("student_texture_region", crops.images)
        self.assertEqual(4, len(crops.cell_groups))
        crops.close()


if __name__ == "__main__":
    unittest.main()
