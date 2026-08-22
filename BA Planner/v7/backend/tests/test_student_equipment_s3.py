from __future__ import annotations

from pathlib import Path
import json
from threading import Event
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import EquipmentMenuCaptureAdapter, StudentMatcherAdapter
from core.scanner_session import ScannerError
from core.student_equipment_recognizer import (
    EQUIPMENT_MAX_LEVEL,
    EquipmentMenuRecognizer,
    StudentEquipmentRecognizer,
    equipment_level_matches_tier,
)
from core.student_scan_recognizer import StudentBasicCropSet


BACKEND = Path(__file__).parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
FIXTURE = Path(__file__).parent / "fixtures" / "student_scan_s2_serika_new_year.png"
LIVE_ROOT = Path(__file__).parent / "fixtures" / "student_equipment_s3_dataset" / "live_1280x720"
LIVE_MASTER = Path(__file__).parent / "fixtures" / "student_equipment_s3_live_master.json"


class StableCapture:
    def wait_stable(self, _target, cancel, timeout=2.0):
        if cancel.is_set():
            raise ScannerError("cancelled", "cancelled")
        return Image.open(FIXTURE).convert("RGB")

    def capture(self, _target):
        raise AssertionError("unexpected second basic capture")

    def scroll(self, _target, _delta):
        raise AssertionError("unexpected scroll")


class OneMenuCapture:
    def __init__(self) -> None:
        self.calls = 0

    def capture_equipment_menu(self, _target, cancel):
        if cancel.is_set():
            raise ScannerError("cancelled", "cancelled")
        self.calls += 1
        return Image.new("RGB", (2560, 1440), "black")

    def close_equipment_menu(self, _target):
        return None


class ClickStableCapture:
    def __init__(self) -> None:
        self.clicks: list[tuple[float, float]] = []
        self.stable_calls = 0

    def click(self, _target, x_ratio, y_ratio):
        self.clicks.append((x_ratio, y_ratio))

    def wait_stable(self, _target, _cancel, timeout=2.0):
        self.stable_calls += 1
        return Image.new("RGB", (64, 36), "black")

    def capture(self, _target):
        return Image.new("RGB", (64, 36), "black")

    def scroll(self, _target, _delta):
        return None


class StudentEquipmentS3Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = RecognitionAssetCatalog(ASSETS)
        cls.regions = cls.catalog.region("student")

    def test_real_fixture_short_circuits_empty_and_level_locked_slots(self) -> None:
        with Image.open(FIXTURE) as frame:
            crops = StudentBasicCropSet.from_frame(frame, self.regions)
        recognizer = StudentEquipmentRecognizer(self.catalog)
        try:
            result, unresolved = recognizer.recognize(
                crops, student_ref="serika_new_year", student_level=12,
            )
            self.assertEqual("empty", result["equip1"].value)
            self.assertEqual("empty", result["equip2"].value)
            self.assertEqual("level_locked", result["equip3"].value)
            self.assertEqual("skipped", result["equip3_level"].status)
            self.assertEqual("skipped", result["equip4"].status)
            self.assertEqual((), unresolved)
            self.assertEqual(0, recognizer.metrics.generated_cards)
        finally:
            recognizer.close()
            crops.close()

    def test_small_roi_fallback_reads_t10_boundary_and_warm_answer_is_identical(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        region = self.regions["basic_equipment_1_level_digits_quad"]
        crop = recognizer._generated_level_crop(1, "Shoes", "T10", 70, region, (2560, 1440))
        self.assertIsNotNone(crop)
        try:
            cold = recognizer.read_generated_level(
                crop, slot=1, family="Shoes", tier="T10", region=region,
                source_size=(2560, 1440),
            )
            generated = recognizer.metrics.generated_cards
            warm = recognizer.read_generated_level(
                crop, slot=1, family="Shoes", tier="T10", region=region,
                source_size=(2560, 1440),
            )
            self.assertEqual(70, cold.value)
            self.assertEqual(cold.value, warm.value)
            self.assertEqual(generated, recognizer.metrics.generated_cards)
            self.assertGreater(recognizer.metrics.cache_hits, 0)
            self.assertEqual(0, recognizer.metrics.full_size_reference_canvases)
            self.assertLessEqual(recognizer.metrics.peak_cache_entries, 384)
        finally:
            crop.close()
            recognizer.close()

    def test_single_digit_uses_blank_second_cell(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        region = self.regions["basic_equipment_1_level_digits_quad"]
        crop = recognizer._generated_level_crop(1, "Shoes", "T1", 9, region, (2560, 1440))
        try:
            result = recognizer.read_generated_level(
                crop, slot=1, family="Shoes", tier="T1", region=region,
                source_size=(2560, 1440),
            )
            self.assertEqual(9, result.value)
            self.assertIn("'b'", result.note)
        finally:
            crop.close()
            recognizer.close()

    def test_session_calibration_requires_competitors_then_precedes_generated_fallback(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        region = self.regions["basic_equipment_1_level_digits_quad"]
        samples = [
            recognizer._generated_level_crop(1, "Shoes", "T10", value, region, (2560, 1440))
            for value in (60, 65, 70)
        ]
        try:
            recognizer.learn_basic_level(samples[0], slot=1, value=60, region=region)
            insufficient = recognizer.read_empirical_level(
                samples[0], slot=1, tier="T10", region=region,
            )
            self.assertIsNone(insufficient.value)
            recognizer.learn_basic_level(samples[1], slot=1, value=65, region=region)
            recognizer.learn_basic_level(samples[2], slot=1, value=70, region=region)
            resolved = recognizer.read_empirical_level(
                samples[2], slot=1, tier="T10", region=region,
            )
            self.assertEqual(70, resolved.value)
            self.assertEqual("equipment_empirical_glyph", resolved.source)
            self.assertEqual(1, recognizer.metrics.empirical_hits)
            self.assertEqual(6, recognizer.metrics.calibration_samples)
        finally:
            for sample in samples:
                sample.close()
            recognizer.close()

    def test_all_tier_level_boundaries_and_invalid_pair(self) -> None:
        for tier, maximum in EQUIPMENT_MAX_LEVEL.items():
            with self.subTest(tier=tier):
                self.assertTrue(equipment_level_matches_tier(1, tier))
                self.assertTrue(equipment_level_matches_tier(maximum, tier))
                self.assertFalse(equipment_level_matches_tier(maximum + 1, tier))
        self.assertFalse(equipment_level_matches_tier(48, "T4"))
        self.assertFalse(equipment_level_matches_tier(1, "T11"))

    def test_favorite_t1_t2_and_locked_states(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        try:
            for tier in ("T1", "T2"):
                with self.subTest(tier=tier):
                    source = recognizer._favorite_templates[tier].copy()
                    result = recognizer.read_favorite(source)
                    source.close()
                    self.assertEqual(tier, result.value)
            empty = Image.new("RGB", (100, 100), "white")
            regions = {
                "basic_equipment_1_level_digits_quad": {"x1": 0, "y1": 0, "x2": .1, "y2": .1},
                "basic_equipment_2_level_digits_quad": {"x1": .1, "y1": 0, "x2": .2, "y2": .1},
                "basic_equipment_3_level_digits_quad": {"x1": .2, "y1": 0, "x2": .3, "y2": .1},
                "basic_favorite_tier_region": {"x1": .3, "y1": 0, "x2": .4, "y2": .1},
            }
            crops = StudentBasicCropSet.from_frame(empty, regions)
            with (
                patch("core.student_equipment_recognizer.student_meta.favorite_item_enabled", return_value=True),
                patch("core.student_equipment_recognizer.student_meta.equipment_slots", return_value=(None, None, None)),
            ):
                values, _unresolved = recognizer.recognize(
                    crops, student_ref="serika_new_year", student_level=1,
                    favorite_growth_active=False,
                )
            self.assertEqual("love_locked", values["equip4"].value)
            crops.close()
            empty.close()

            favorite_empty = Image.new("RGB", (100, 100), "white")
            ImageDraw.Draw(favorite_empty).rectangle((40, 10, 60, 30), fill=(255, 185, 24))
            empty_regions = {
                "basic_favorite_empty_dot_region": {"x1": .4, "y1": .1, "x2": .61, "y2": .31},
            }
            empty_crops = StudentBasicCropSet.from_frame(favorite_empty, empty_regions)
            with (
                patch("core.student_equipment_recognizer.student_meta.favorite_item_enabled", return_value=True),
                patch("core.student_equipment_recognizer.student_meta.equipment_slots", return_value=(None, None, None)),
            ):
                empty_values, _unresolved = recognizer.recognize(
                    empty_crops, student_ref="serika_new_year", student_level=0,
                )
            self.assertEqual("empty", empty_values["equip4"].value)
            empty_crops.close()
            favorite_empty.close()
        finally:
            recognizer.close()

    def test_family_restricted_icon_reader_distinguishes_tier_boundaries(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        region = self.regions["basic_equipment_1_icon_region"]
        try:
            for tier in ("T1", "T10"):
                with self.subTest(tier=tier):
                    card = recognizer._base_card("Shoes", tier).copy().convert("RGB")
                    result = recognizer.read_tier(card, "Shoes", region)
                    card.close()
                    self.assertEqual(tier, result.value)
        finally:
            recognizer.close()

    def test_fallback_captures_menu_once_and_reads_only_unresolved_slots(self) -> None:
        menu = OneMenuCapture()
        with patch("core.student_equipment_recognizer.student_meta.favorite_item_enabled", return_value=True):
            result = StudentMatcherAdapter(
                StableCapture(), self.catalog, equipment_menu=menu,
            )({"target_id": "fixture"}, Event(), lambda *_item: None)[0]
        self.assertEqual(1, menu.calls)
        self.assertEqual("empty", result["payload"]["values"]["equip1"])
        self.assertEqual("empty", result["payload"]["values"]["equip2"])
        self.assertEqual("level_locked", result["payload"]["values"]["equip3"])
        menu_evidence = [item for item in result["evidence"] if item["source"].startswith("equipment_menu")]
        self.assertTrue(menu_evidence)
        self.assertEqual({"equip4"}, {item["field"] for item in menu_evidence})

    def test_menu_recognizer_does_not_emit_resolved_neighbor_slots(self) -> None:
        recognizer = EquipmentMenuRecognizer(self.catalog)
        frame = Image.new("RGB", (2560, 1440), "black")
        try:
            result = recognizer.recognize(frame, (2,))
        finally:
            frame.close()
        self.assertLessEqual(set(result), {"equip2", "equip2_level"})

    def test_production_menu_orchestrator_opens_captures_once_and_closes(self) -> None:
        capture = ClickStableCapture()
        orchestrator = EquipmentMenuCaptureAdapter(capture, self.catalog)
        frame = orchestrator.capture_equipment_menu({"target_id": "fixture"}, Event())
        frame.close()
        orchestrator.close_equipment_menu({"target_id": "fixture"})
        self.assertEqual(1, capture.stable_calls)
        self.assertEqual(2, len(capture.clicks))
        self.assertNotEqual(capture.clicks[0], capture.clicks[1])

    def test_benchmark_fixture_records_required_performance_and_data_gaps(self) -> None:
        report = json.loads(
            (Path(__file__).parent / "fixtures" / "student_equipment_s3_benchmark.json").read_text(encoding="utf-8")
        )
        self.assertTrue(report["cold_warm_identical"])
        self.assertEqual(0, report["cache_and_memory"]["full_size_reference_canvases"])
        self.assertLessEqual(report["cache_and_memory"]["peak_cache_entries"], 384)
        self.assertEqual(1.0, report["answers"]["synthetic_same-generator"]["accuracy"])
        self.assertEqual(70, report["answers"]["synthetic_same-generator"]["one_pixel_shift_predicted"])
        self.assertEqual([], report["master_required"])
        self.assertEqual("retain for unresolved slots; required by the real T10/Lv70 evidence", report["answers"]["real_master"]["decision"]["equipment_menu_fallback"])

    def test_master_real_mika_repeats_resolve_with_position_bank_without_menu(self) -> None:
        basic = StudentEquipmentRecognizer(self.catalog)
        menu = EquipmentMenuRecognizer(self.catalog)
        try:
            for index in range(1, 4):
                with self.subTest(sample=index):
                    basic_path = LIVE_ROOT / "student_detail" / f"sample_{index:02d}.png"
                    with Image.open(basic_path) as frame:
                        crops = StudentBasicCropSet.from_frame(frame, self.regions)
                    values, unresolved = basic.recognize(
                        crops, student_ref="mika", student_level=90,
                    )
                    crops.close()
                    self.assertEqual(["T10", "T10", "T10"], [values[f"equip{slot}"].value for slot in (1, 2, 3)])
                    self.assertEqual((), unresolved)
                    self.assertEqual([70, 70, 70], [values[f"equip{slot}_level"].value for slot in (1, 2, 3)])
                    self.assertTrue(all(
                        values[f"equip{slot}_level"].source == "equipment_position_binary"
                        for slot in (1, 2, 3)
                    ))
        finally:
            basic.close()

    def test_master_real_hibiki_repeats_read_favorite_t2(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        try:
            for index in range(1, 4):
                with self.subTest(sample=index):
                    path = LIVE_ROOT / "favorite_hibiki" / "student_detail" / f"sample_{index:02d}.png"
                    with Image.open(path) as frame:
                        crops = StudentBasicCropSet.from_frame(frame, self.regions)
                    values, _unresolved = recognizer.recognize(
                        crops, student_ref="hibiki", student_level=90,
                    )
                    crops.close()
                    self.assertEqual("T2", values["equip4"].value)
                    self.assertGreaterEqual(values["equip4"].confidence, 0.85)
        finally:
            recognizer.close()

    def test_master_comparison_keeps_unresolved_only_menu_fallback(self) -> None:
        report = json.loads(LIVE_MASTER.read_text(encoding="utf-8"))
        self.assertEqual(3, report["stable_repeats_per_condition"])
        self.assertEqual(3, report["same_answer_comparison"][3]["final_levels_correct_per_repeat"])
        self.assertEqual(3, report["favorite_comparison"]["correct"])
        self.assertIn("retain", report["decision"]["equipment_menu_fallback"])

    def test_v6_master_baseline_was_reproduced(self) -> None:
        report = json.loads(
            (Path(__file__).parent / "fixtures" / "student_equipment_s3_v6_baseline.json").read_text(encoding="utf-8")
        )
        self.assertTrue(report["result"]["correct"])
        self.assertEqual(70, report["cold_cache_state"]["full_screen_candidate_crops"]["misses"])
        self.assertEqual([2560, 1440, 3], report["candidate_canvas"])


if __name__ == "__main__":
    unittest.main()
