from __future__ import annotations

from pathlib import Path
from threading import Event
from hashlib import sha256
import json
import re
import unittest
from unittest.mock import patch

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import Match, StudentMatcherAdapter
from core.student_equipment_recognizer import StudentEquipmentRecognizer
from core.student_scan_recognizer import StudentBasicCropSet


BACKEND = Path(__file__).parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
LIVE_ROOT = Path(__file__).parent / "fixtures" / "student_equipment_s3_dataset" / "live_1280x720"
BENCHMARK = Path(__file__).parent / "fixtures" / "student_equipment_s3b_benchmark.json"
ARCHIVE_FIXTURE = Path(__file__).parent / "fixtures" / "student_equipment_s3b_archive"
PROMOTION_FIXTURE = Path(__file__).parent / "fixtures" / "student_equipment_s3b_promotion_probe"
GENERATED_BENCHMARK = Path(__file__).parent / "fixtures" / "student_equipment_s3b_generated_glyph_benchmark.json"


class LiveMikaCapture:
    def wait_stable(self, _target, _cancel, timeout=2.0):
        return Image.open(LIVE_ROOT / "student_detail" / "sample_01.png").convert("RGB")

    def capture(self, _target):
        raise AssertionError("unexpected second capture")

    def scroll(self, _target, _delta):
        raise AssertionError("unexpected scroll")


class StudentEquipmentS3BTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = RecognitionAssetCatalog(ASSETS)
        cls.regions = cls.catalog.region("student")

    def test_menu_digit_assets_are_prepared_once_as_compact_binary_templates(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        try:
            self.assertEqual(51, recognizer.metrics.binary_template_count)
            self.assertEqual(3570, recognizer.metrics.binary_template_bytes)
            self.assertEqual({"1", "2", "3", "4", "5", "6", "7"}, set(recognizer._binary_templates[(1, 1)]))
            self.assertEqual(set("0123456789"), set(recognizer._binary_templates[(3, 2)]))
            self.assertFalse(recognizer.binary_production_enabled)
            self.assertFalse(recognizer.generated_binary_production_enabled)
            self.assertEqual(70, recognizer.metrics.generated_binary_template_count)
            self.assertEqual(9800, recognizer.metrics.generated_binary_template_bytes)
            self.assertEqual({"fill"}, set(recognizer._generated_binary_templates))
        finally:
            recognizer.close()

    def test_real_mika_and_hibiki_lv70_shadow_cells_are_36_of_36(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        answers: list[int | str | None] = []
        try:
            roots = (
                LIVE_ROOT / "student_detail",
                LIVE_ROOT / "favorite_hibiki" / "student_detail",
            )
            for root in roots:
                for index in range(1, 4):
                    with Image.open(root / f"sample_{index:02d}.png") as frame:
                        crops = StudentBasicCropSet.from_frame(frame, self.regions)
                    try:
                        for slot in (1, 2, 3):
                            observation = recognizer.read_binary_level(
                                crops.images[f"basic_equipment_{slot}_level_digits_quad"],
                                slot=slot,
                                tier="T10",
                                region=self.regions[f"basic_equipment_{slot}_level_digits_quad"],
                            )
                            answers.append(observation.value)
                            self.assertEqual("shadow", observation.status)
                            self.assertFalse(observation.confirmed)
                            self.assertIn("production_enabled=false", observation.note)
                            self.assertIn("labels=['7', '0']", observation.note)
                    finally:
                        crops.close()
            self.assertEqual([70] * 18, answers)
            self.assertEqual(36, len(answers) * 2)
            self.assertEqual(18, recognizer.metrics.binary_shadow_hits)
        finally:
            recognizer.close()

    def test_shadow_result_never_replaces_generated_or_menu_fallback_value(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        path = LIVE_ROOT / "student_detail" / "sample_01.png"
        try:
            with Image.open(path) as frame:
                crops = StudentBasicCropSet.from_frame(frame, self.regions)
            try:
                values, unresolved = recognizer.recognize(
                    crops, student_ref="mika", student_level=90,
                )
            finally:
                crops.close()
            self.assertEqual((1, 2, 3), unresolved)
            self.assertTrue(all(values[f"equip{slot}_level"].value is None for slot in (1, 2, 3)))
            self.assertEqual(
                [70, 70, 70],
                [recognizer.last_binary_shadow[f"equip{slot}_level"].value for slot in (1, 2, 3)],
            )
            self.assertTrue(all(
                not recognizer.last_binary_shadow[f"equip{slot}_level"].confirmed
                for slot in (1, 2, 3)
            ))
        finally:
            recognizer.close()

    def test_missing_feature_and_invalid_tier_are_shadow_only_fallbacks(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        blank = Image.new("RGB", (48, 36), "white")
        region = self.regions["basic_equipment_1_level_digits_quad"]
        try:
            missing = recognizer.read_binary_level(
                None, slot=1, tier="T10", region=region,
            )
            invalid = recognizer.read_binary_level(
                blank, slot=1, tier="T99", region=region,
            )
            feature = recognizer.read_binary_level(
                blank, slot=1, tier="T10", region=region,
            )
            for observation in (missing, invalid, feature):
                self.assertIsNone(observation.value)
                self.assertEqual("shadow", observation.status)
                self.assertFalse(observation.confirmed)
        finally:
            blank.close()
            recognizer.close()

    def test_single_digit_blank_logic_is_exercised_without_claiming_real_coverage(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        path = LIVE_ROOT / "student_detail" / "sample_01.png"
        region = self.regions["basic_equipment_1_level_digits_quad"]
        try:
            with Image.open(path) as frame:
                crops = StudentBasicCropSet.from_frame(frame, self.regions)
            try:
                source = crops.images["basic_equipment_1_level_digits_quad"]
                single_digit = source.copy()
                midpoint = single_digit.width // 2
                single_digit.paste("white", (midpoint, 0, single_digit.width, single_digit.height))
                observation = recognizer.read_binary_level(
                    single_digit, slot=1, tier="T1", region=region,
                )
                single_digit.close()
            finally:
                crops.close()
            self.assertEqual(7, observation.value)
            self.assertEqual("shadow", observation.status)
            self.assertIn("labels=['7', 'blank']", observation.note)
        finally:
            recognizer.close()

    def test_low_gate_missing_templates_and_invalid_pair_all_fall_through(self) -> None:
        path = LIVE_ROOT / "student_detail" / "sample_01.png"
        region = self.regions["basic_equipment_1_level_digits_quad"]
        with Image.open(path) as frame:
            crops = StudentBasicCropSet.from_frame(frame, self.regions)
        crop = crops.images["basic_equipment_1_level_digits_quad"]
        strict = StudentEquipmentRecognizer(
            self.catalog, binary_shadow_threshold=0.99, binary_shadow_margin=0.99,
        )
        missing = StudentEquipmentRecognizer(self.catalog)
        try:
            low = strict.read_binary_level(crop, slot=1, tier="T10", region=region)
            self.assertIsNone(low.value)
            self.assertGreater(strict.metrics.binary_shift_retries, 0)
            invalid_pair = missing.read_binary_level(crop, slot=1, tier="T9", region=region)
            self.assertIsNone(invalid_pair.value)
            missing._binary_templates.pop((1, 1))
            no_templates = missing.read_binary_level(crop, slot=1, tier="T10", region=region)
            self.assertIsNone(no_templates.value)
            self.assertIn("templates_missing", no_templates.note)
        finally:
            strict.close()
            missing.close()
            crops.close()

    def test_binary_metrics_do_not_expand_s3_candidate_cache(self) -> None:
        recognizer = StudentEquipmentRecognizer(self.catalog)
        path = LIVE_ROOT / "student_detail" / "sample_01.png"
        try:
            with Image.open(path) as frame:
                crops = StudentBasicCropSet.from_frame(frame, self.regions)
            try:
                for slot in (1, 2, 3):
                    recognizer.read_binary_level(
                        crops.images[f"basic_equipment_{slot}_level_digits_quad"],
                        slot=slot,
                        tier="T10",
                        region=self.regions[f"basic_equipment_{slot}_level_digits_quad"],
                    )
            finally:
                crops.close()
            self.assertEqual(0, len(recognizer.cache))
            self.assertEqual(0, recognizer.metrics.full_size_reference_canvases)
            self.assertLessEqual(recognizer.metrics.binary_template_bytes, 4096)
            self.assertGreater(recognizer.metrics.binary_match_ms, 0.0)
        finally:
            recognizer.close()

    def test_adapter_exposes_shadow_evidence_without_payload_commit(self) -> None:
        adapter = StudentMatcherAdapter(LiveMikaCapture(), self.catalog)
        try:
            with patch.object(adapter.matcher, "match", return_value=Match("mika", 1.0, 1.0)):
                result = adapter({"target_id": "fixture"}, Event(), lambda *_args: None)[0]
            shadow = [item for item in result["evidence"] if item["source"] == "equipment_binary_shadow"]
            generated_shadow = [
                item for item in result["evidence"]
                if item["source"] == "equipment_generated_binary_shadow"
            ]
            self.assertEqual(3, len(shadow))
            self.assertEqual(3, len(generated_shadow))
            self.assertEqual({"shadow"}, {item["status"] for item in shadow})
            self.assertEqual({"shadow"}, {item["status"] for item in generated_shadow})
            self.assertTrue(all("production_enabled=false" in item["note"] for item in shadow))
            self.assertTrue(all("variant=fill" in item["note"] for item in generated_shadow))
            self.assertTrue(all(
                result["payload"]["values"].get(f"equip{slot}_level") is None
                for slot in (1, 2, 3)
            ))
        finally:
            adapter.equipment_recognizer.close()

    def test_benchmark_records_shadow_accuracy_performance_and_master_gates(self) -> None:
        report = json.loads(BENCHMARK.read_text(encoding="utf-8"))
        self.assertEqual("shadow_only", report["mode"])
        self.assertFalse(report["production_enabled"])
        self.assertEqual(36, report["accuracy"]["digit_cells_correct"])
        self.assertEqual(36, report["accuracy"]["digit_cells_total"])
        self.assertEqual(0, report["accuracy"]["committed_false_positives"])
        self.assertEqual(0, report["fallback"]["reduction_while_shadow"])
        self.assertEqual(6, report["fallback"]["menu_calls_after"])
        self.assertEqual(51, report["cache_and_memory"]["binary_template_count"])
        self.assertLessEqual(report["cache_and_memory"]["binary_template_bytes"], 4096)
        self.assertEqual(0, report["cache_and_memory"]["full_size_reference_canvases"])
        self.assertEqual(298, report["archive_validation"]["correct"])
        self.assertEqual(298, report["archive_validation"]["total"])
        self.assertEqual(316, report["combined_evidence"]["level_pairs_correct"])
        self.assertEqual(632, report["combined_evidence"]["digit_cells_correct"])
        self.assertEqual(0, report["combined_evidence"]["committed_false_positives"])
        self.assertEqual(4, len(report["master_required"]))

    def test_reviewed_archive_atlas_replays_298_real_equipment_rois(self) -> None:
        manifest = json.loads((ARCHIVE_FIXTURE / "manifest.json").read_text(encoding="utf-8"))
        atlas_path = ARCHIVE_FIXTURE / manifest["atlas"]["path"]
        self.assertEqual(manifest["atlas"]["sha256"], sha256(atlas_path.read_bytes()).hexdigest())
        self.assertEqual(298, manifest["reviewed_roi_count"])
        self.assertEqual(64, manifest["coverage"]["student_count"])
        self.assertEqual(["1", "2", "3", "4", "5", "6", "7"], manifest["coverage"]["position_1_digits"])
        self.assertEqual(["0", "1", "3", "4", "5", "7", "9"], manifest["coverage"]["position_2_digits"])
        self.assertFalse(manifest["coverage"]["blank"])
        self.assertEqual(
            ["position_2_digit_2", "position_2_digit_6", "position_2_digit_8", "single_digit_blank"],
            manifest["coverage"]["missing_for_production"],
        )
        self.assertFalse(manifest["ground_truth"]["template_leakage"])
        recognizer = StudentEquipmentRecognizer(self.catalog)
        try:
            with Image.open(atlas_path) as atlas:
                for record in manifest["records"]:
                    crop = atlas.crop(tuple(record["atlas_box"]))
                    observation = recognizer.read_binary_level(
                        crop,
                        slot=int(record["slot"]),
                        tier=str(record["tier"]),
                        region=self.regions[f"basic_equipment_{record['slot']}_level_digits_quad"],
                    )
                    crop.close()
                    self.assertEqual(record["expected_value"], observation.value, record["source_file"])
                    self.assertEqual("shadow", observation.status)
                    self.assertFalse(observation.confirmed)
            self.assertEqual(298, recognizer.metrics.binary_attempts)
            self.assertEqual(298, recognizer.metrics.binary_shadow_hits)
        finally:
            recognizer.close()

    def test_generated_glyph_variants_replay_18_single_and_two_digit_probes(self) -> None:
        manifest = json.loads((PROMOTION_FIXTURE / "manifest.json").read_text(encoding="utf-8"))
        atlas_path = PROMOTION_FIXTURE / manifest["atlas"]["path"]
        self.assertEqual(manifest["atlas"]["sha256"], sha256(atlas_path.read_bytes()).hexdigest())
        self.assertEqual(18, manifest["reviewed_roi_count"])
        recognizer = StudentEquipmentRecognizer(self.catalog)
        try:
            with Image.open(atlas_path) as atlas:
                for record in manifest["records"]:
                    crop = atlas.crop(tuple(record["atlas_box"]))
                    try:
                        for variant in ("outline", "fill_outline", "fill"):
                            observation = recognizer.read_generated_binary_level(
                                crop,
                                slot=int(record["slot"]),
                                tier=str(record["tier"]),
                                variant=variant,
                            )
                            candidate = re.search(r"(?:^|;)value=(\d+)(?:;|$)", observation.note)
                            self.assertIsNotNone(candidate, record["source_file"])
                            self.assertEqual(
                                int(record["expected_value"]), int(candidate.group(1)),
                                f"{variant}:{record['source_file']}:slot{record['slot']}",
                            )
                        self.assertEqual(
                            int(record["expected_value"]),
                            recognizer.read_generated_binary_level(
                                crop,
                                slot=int(record["slot"]),
                                tier=str(record["tier"]),
                                variant="fill",
                            ).value,
                        )
                    finally:
                        crop.close()
        finally:
            recognizer.close()

    def test_generated_fill_benchmark_replays_all_334_without_fallback_or_wrong_accept(self) -> None:
        report = json.loads(GENERATED_BENCHMARK.read_text(encoding="utf-8"))
        self.assertEqual(334, report["datasets"]["combined_level_pairs"])
        fill = report["methods"]["generated_fill"]
        self.assertEqual(334, fill["top1_correct"])
        self.assertEqual(334, fill["accepted_correct"])
        self.assertEqual(0, fill["accepted_wrong"])
        self.assertEqual(0, fill["fallback"])
        self.assertEqual("benchmark_lead_not_production_selected", report["selection_status"])
        self.assertFalse(report["production_enabled"])
        self.assertEqual(70, report["cache_and_memory"]["generated_fill_template_count"])
        self.assertEqual(9800, report["cache_and_memory"]["generated_fill_template_bytes"])
        self.assertEqual(0, report["cache_and_memory"]["full_size_reference_canvases"])


if __name__ == "__main__":
    unittest.main()
