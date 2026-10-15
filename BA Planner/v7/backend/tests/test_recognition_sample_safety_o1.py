import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from PIL import Image

from core.numeric_sample_safety import numeric_mask_issue, ROI_FIELDS
from core.recognition_answer_samples import RecognitionAnswerSampleStore
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter
from core.student_scan_recognizer import StudentBasicRecognizer, Observation
from core.student_equipment_recognizer import StudentEquipmentRecognizer, EquipmentMetrics
from core.studio_numeric_bank import StudioNumericBank, StudioNumericMatch
from core.scanner_session import ScannerSessionService

BACKEND = Path(__file__).resolve().parents[1]
FIXTURE = BACKEND / "tests/fixtures/studio_numeric_o0"
PROFILE = "a" * 24


def cells(rank):
    result = []
    for p in (1, 2):
        with Image.open(FIXTURE / f"rank{rank}-digit{p}.png") as mask:
            cell = Image.new("RGB", mask.size, "white")
            cell.paste((45, 70, 100), (0, 0, *mask.size), mask)
            result.append(cell)
    return tuple(result)


def training_adapter(store):
    adapter = StudentMatcherAdapter.__new__(StudentMatcherAdapter)
    adapter.answer_samples = store
    catalog = RecognitionAssetCatalog(BACKEND / "assets/recognition/v1")
    adapter.basic_recognizer = SimpleNamespace(studio_numeric_bank=StudioNumericBank.from_catalog(catalog))
    adapter.equipment_recognizer = SimpleNamespace(studio_numeric_bank=StudioNumericBank.from_catalog(catalog))
    return adapter


class NumericSampleO1Tests(unittest.TestCase):
    def setUp(self):
        self.temporary = self.enterContext(TemporaryDirectory())
        self.store = RecognitionAnswerSampleStore(Path(self.temporary))
        self.adapter = training_adapter(self.store)
        self.bank = self.adapter.basic_recognizer.studio_numeric_bank
        self.addCleanup(self.bank.close)
        self.addCleanup(self.adapter.equipment_recognizer.studio_numeric_bank.close)
        self.rank26 = cells(26)
        self.rank10 = cells(10)
        for cell in (*self.rank26, *self.rank10): self.addCleanup(cell.close)
        self.specimen = {"source_size": (1280, 720), "numeric_groups": {
            "basic_relationship_rank_studio_2_cells": self.rank26,
            "basic_student_level_studio_cells": self.rank10,
        }}

    def train(self, value=26, fields=("bond_rank",)):
        return self.adapter.train_user_answer(PROFILE, "candidate", self.specimen,
                                             {"values": {"level": 90, "bond_rank": value}}, fields)

    def test_only_confirmed_field_is_stored_and_second_revalidation_creates_no_files(self):
        self.assertEqual(0, self.train(fields=()))
        self.assertEqual(2, self.train())
        first = {p.relative_to(self.store.root): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in self.store.root.rglob("*") if p.is_file()}
        self.assertEqual(0, self.train())
        second = {p.relative_to(self.store.root): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in self.store.root.rglob("*") if p.is_file()}
        self.assertEqual(first, second)
        samples = self.store.load_numeric(PROFILE, (1280, 720))
        self.addCleanup(self.store.close, samples)
        self.assertEqual(2, len(samples))
        self.assertTrue(all(s.field == "relationship_rank" and s.validated for s in samples))
        self.assertEqual(2, self.specimen["_sample_training_report"]["reused_count"])

    def test_actual_26_and_normal_10_after_correct_user_training(self):
        with Image.open(FIXTURE / "rank10-digit2.png") as old_zero:
            self.bank.add_user_template("affectionlevel_digit2", "0", old_zero, sample_id="legacy-zero")
        self.assertIsNone(self.bank.match(self.rank26, field="relationship_rank",
            roi_names=("affectionlevel_digit1", "affectionlevel_digit2")).value)
        self.assertEqual(2, self.train())
        for rank, source in ((26, self.rank26), (10, self.rank10)):
            match = self.bank.match(source, field="relationship_rank",
                roi_names=("affectionlevel_digit1", "affectionlevel_digit2"))
            self.assertEqual(rank, match.value)

    def test_mislabeled_six_is_quarantined_not_loaded_or_activated_and_retries_are_idempotent(self):
        self.train(value=20)
        report = self.specimen["_sample_training_report"]
        self.assertEqual(["bond_rank"], report["blocked_fields"])
        self.assertEqual(1, report["quarantined_count"])
        before = len(list(self.store.root.rglob("*.*")))
        self.train(value=20)
        self.assertEqual(before, len(list(self.store.root.rglob("*.*"))))
        self.assertNotIn("0", self.bank.user_templates.get("affectionlevel_digit2", {}))
        manifest, = list((self.store.root / "_quarantine").rglob("*.json"))
        row = json.loads(manifest.read_text())
        self.assertEqual("quarantined", row["safety_status"])
        self.assertIn("opposite=6", row["reason"])
        self.assertEqual(row["png_sha256"], hashlib.sha256(manifest.with_suffix(".png").read_bytes()).hexdigest())
        self.assertFalse(Path(row["original_path"]).exists())
        loaded = self.store.load_numeric(PROFILE, (1280, 720))
        self.addCleanup(self.store.close, loaded)
        self.assertEqual(["2"], [s.digit for s in loaded])

    def test_collision_keeps_review_red_until_corrected_field_is_confirmed(self):
        payload = {"version": 1, "student_id": "airi", "values": {"bond_rank": 20}}
        service = ScannerSessionService(
            target_provider=lambda: [{"target_id": "w", "title": "fixture", "status": "ready"}],
            student_matcher=lambda *_: [{"candidate_id": "candidate", "payload": payload,
                "evidence": [{"field": "bond_rank", "status": "ok", "source": "fixture"}],
                "_answer_specimen": self.specimen}], inventory_matcher=lambda *_: [],
            repository=SimpleNamespace(), asset_status=lambda: {"ready": True},
            student_validator=lambda *_: {"field": "student_stat_validation", "status": "verified", "source": "fixture"},
            candidate_review_hook=lambda _, profile, candidate, specimen, answer, _reason, _approve, fields:
                self.adapter.train_user_answer(profile, candidate, specimen, answer, fields),
        )
        self.addCleanup(service.close)
        session = service.start("student", "w", PROFILE)
        service.wait(session["session_id"])
        args = (session["session_id"],session["generation"],"candidate")
        wrong = service.review(*args,1,payload,approve=False,reason="edited_and_revalidated_in_scan_page",confirmed_fields=["bond_rank"])
        self.assertTrue(wrong["review_required"])
        self.assertTrue(any(row.get("source") == "recognition_sample_safety" for row in wrong["evidence"]))
        payload = {**payload,"values": {"bond_rank": 26}}
        correct = service.review(*args,2,payload,approve=False,reason="edited_and_revalidated_in_scan_page",confirmed_fields=["bond_rank"])
        self.assertFalse(correct["review_required"])

    def test_fragment_masks_are_rejected_for_every_supported_field_roi(self):
        for roi, field in ROI_FIELDS.items():
            for count in (1, 6):
                with self.subTest(roi=roi, count=count):
                    mask = Image.new("L", (14, 18))
                    for x in range(count): mask.putpixel((x + 2, 5), 255)
                    self.addCleanup(mask.close)
                    self.assertIsNotNone(numeric_mask_issue(mask, field, roi))
                    with self.assertRaisesRegex(ValueError, "numeric_mask_rejected"):
                        self.store.save_numeric(PROFILE, (1280, 720), field=field, roi_name=roi,
                                                digit="0", mask=mask, candidate_id="fragment")
        self.assertFalse(self.store.root.exists())

    def test_disconnected_and_thin_masks_fail_quality_gate(self):
        mask = Image.new("L", (20, 20))
        self.addCleanup(mask.close)
        for x, y in ((x,y) for x in (3,4,15,16) for y in range(4,12)):
            mask.putpixel((x,y),255)
        self.assertEqual("fragmented_components", numeric_mask_issue(mask, "relationship_rank", "affectionlevel_digit1"))

    def test_content_key_includes_scope_candidate_label_and_pixel_hash(self):
        with Image.open(FIXTURE / "rank26-digit2.png") as mask:
            args = dict(field="relationship_rank", roi_name="affectionlevel_digit2", digit="6", mask=mask)
            one = self.store.save_numeric(PROFILE, (1280,720), candidate_id="one", **args)
            same = self.store.save_numeric(PROFILE, (1280,720), candidate_id="one", **args)
            other = self.store.save_numeric(PROFILE, (1280,720), candidate_id="other", **args)
            scope = self.store.save_numeric("b"*24, (1280,720), candidate_id="one", **args)
            resolution = self.store.save_numeric(PROFILE, (1920,1080), candidate_id="one", **args)
            label = self.store.save_numeric(PROFILE, (1280,720), candidate_id="one", **{**args, "digit": "0"})
            changed = mask.convert("L")
            self.addCleanup(changed.close)
            changed.putpixel((0,0),255)
            pixels = self.store.save_numeric(PROFILE, (1280,720), candidate_id="one", **{**args, "mask": changed})
        self.assertEqual(one,same)
        self.assertEqual(6,len({one,other,scope,resolution,label,pixels}))

    def test_verified_opposite_user_samples_are_checked_without_legacy_bonus(self):
        with Image.open(FIXTURE / "rank10-digit2.png") as zero:
            roi = "affectionlevel_digit2"
            self.bank.add_user_template(roi, "6", zero, sample_id="opposite")
            self.assertIsNone(self.bank.sample_conflict(roi, "0", zero))
            self.bank.add_user_template(roi, "6", zero, sample_id="opposite", validated=True)
            self.assertIn("opposite=6", self.bank.sample_conflict(roi, "0", zero))

    def test_corrupted_content_is_not_loaded_or_silently_reused(self):
        self.train()
        path = next(self.store.root.glob("*/1280x720/numeric/*/*/*/*.png"))
        original = path.read_bytes()
        path.write_bytes(b"damaged")
        loaded = self.store.load_numeric(PROFILE, (1280,720))
        self.addCleanup(self.store.close, loaded)
        self.assertEqual(1,len(loaded))
        self.assertEqual(1,self.train())
        self.assertEqual(original,path.read_bytes())
        path.with_suffix('.json').write_text('[]',encoding='utf-8')
        loaded = self.store.load_numeric(PROFILE,(1280,720))
        self.addCleanup(self.store.close,loaded)
        self.assertEqual(1,len(loaded))
        self.assertEqual(1,self.train())


class IndependentNumericO1Tests(unittest.TestCase):
    def test_confident_opposite_reader_blocks_user_and_session(self):
        for source in ("bank_user_confirmed", "bank_session_calibrated"):
            studio = Observation(26,.95,"ok",source,"")
            opposite = Observation(20,.9,"ok","independent","")
            result = StudentBasicRecognizer._resolve_numeric_readers(studio,opposite)
            self.assertIsNone(result.value)
            self.assertEqual("uncertain",result.status)
            self.assertIn("studio=26",result.note)

    def test_user_level_does_not_skip_independent_reader(self):
        recognizer = StudentBasicRecognizer(RecognitionAssetCatalog(BACKEND / "assets/recognition/v1"))
        self.addCleanup(recognizer.studio_numeric_bank.close)
        crop = Image.new("RGB",(32,20),"white")
        self.addCleanup(crop.close)
        match = StudioNumericMatch(90,.95,.2,("9","0"),((0,0),(0,0)),True,True)
        with patch.object(recognizer.studio_numeric_bank,"match",return_value=match), \
             patch("core.student_scan_recognizer.rank_glyph",side_effect=[("8",.99,.3),("0",.99,.3)]) as reader:
            result=recognizer.read_level(crop)
        self.assertEqual(2,reader.call_count)
        self.assertEqual("independent_numeric_conflict",result.source)

    def test_user_bond_and_session_weapon_do_not_skip_independent_readers(self):
        recognizer = StudentBasicRecognizer(RecognitionAssetCatalog(BACKEND / "assets/recognition/v1"))
        self.addCleanup(recognizer.studio_numeric_bank.close)
        crop = Image.new("RGB",(32,20),(255,100,150))
        self.addCleanup(crop.close)
        match = StudioNumericMatch(26,.99,.3,("2","6"),((0,0),(0,0)),True,True)
        absent = StudioNumericMatch(None,0,0,(),(),False)
        with patch.object(recognizer.studio_numeric_bank,"match",side_effect=[absent,match,absent]), \
             patch("core.student_scan_recognizer.rank_glyph",side_effect=[("20",.99,.3),("2",.99,.3),("0",.99,.3)]), \
             patch("core.student_scan_recognizer.split_relationship_rank_digits",side_effect=[(),(crop,crop),()]):
            self.assertEqual("independent_numeric_conflict",recognizer.read_relationship_rank(crop).source)
        weapon_crop = Image.new("RGB",(32,20),"white")
        self.addCleanup(weapon_crop.close)
        match = StudioNumericMatch(60,.99,.3,("6","0"),((0,0),(0,0)),True,False,True)
        with patch.object(recognizer.studio_numeric_bank,"match",return_value=match), \
             patch("core.student_scan_recognizer.rank_glyph",side_effect=[("4",.99,.3),("0",.99,.3)]):
            self.assertEqual("independent_numeric_conflict",recognizer.read_weapon_level(weapon_crop,source_size=(1280,720)).source)

    def test_equipment_user_value_conflicting_with_immutable_reader_stays_uncertain(self):
        recognizer = StudentEquipmentRecognizer.__new__(StudentEquipmentRecognizer)
        recognizer.metrics = EquipmentMetrics()
        recognizer.studio_numeric_bank = StudioNumericBank({})
        self.addCleanup(recognizer.studio_numeric_bank.close)
        match = StudioNumericMatch(20,.99,.3,("2","0"),((0,0),(0,0)),True,True)
        with patch.object(recognizer.studio_numeric_bank,"match",return_value=match), \
             patch.object(recognizer,"_read_studio_position_level",return_value=Observation(10,.99,"ok","immutable","")) as independent:
            result = recognizer.read_position_binary_level(None,tier="T9",region={})
        independent.assert_called_once()
        self.assertEqual("independent_numeric_conflict",result.source)


if __name__ == "__main__": unittest.main()
