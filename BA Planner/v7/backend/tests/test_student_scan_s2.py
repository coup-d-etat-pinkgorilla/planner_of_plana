from __future__ import annotations

import json
from pathlib import Path
from threading import Event
from tempfile import TemporaryDirectory
import unittest

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.recognition_answer_samples import RecognitionAnswerSampleStore
from core.repository_dto import CONFIRMED_STUDENT_VALUE_FIELDS, ConfirmedStudent
from core.scanner_matchers import StudentMatcherAdapter
from core.scanner_session import ScannerError
from core.student_scan_recognizer import StudentBasicCropSet, StudentBasicRecognizer


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
        self.assertFalse(result["review_required"])
        evidence = {item["field"]: item for item in result["evidence"]}
        self.assertEqual("ok", evidence["skill2"]["status"])
        self.assertEqual("basic_skill_combined", evidence["skill2"]["source"])
        self.assertEqual("ok", evidence["combat_hp"]["status"])
        self.assertEqual("ok", evidence["weapon_state"]["status"])
        self.assertEqual("basic_weapon_state_template", evidence["weapon_state"]["source"])
        self.assertEqual("student_level_studio_position_bank", evidence["level"]["source"])
        self.assertEqual("relationship_rank_studio_position_bank", evidence["bond_rank"]["source"])
        self.assertEqual("weapon_level_studio_position_bank", evidence["weapon_level"]["source"])

    def test_payload_uses_only_repository_dto_fields_and_excludes_unimplemented_slices(self) -> None:
        capture = CountingCapture(FIXTURES / "student_scan_s2_serika_new_year.png")
        payload = StudentMatcherAdapter(capture, self.catalog)(
            {"target_id": "fixture"}, Event(), lambda *_item: None
        )[0]["payload"]
        parsed = ConfirmedStudent.from_dict(payload)
        self.assertEqual(payload, parsed.to_dict())
        self.assertLessEqual(set(payload["values"]), set(CONFIRMED_STUDENT_VALUE_FIELDS))
        s4_and_later = set(self.expected["excluded_s2_fields"]) - {
            "bond_rank", "equip1", "equip2", "equip3", "equip4",
            "stat_hp", "stat_atk", "stat_heal",  # F3 ability-potential fields
        }
        self.assertTrue(s4_and_later.isdisjoint(payload["values"]))

    def test_failed_field_does_not_erase_other_confirmed_fields(self) -> None:
        capture = CountingCapture(FIXTURES / "student_scan_s2_serika_new_year.png")
        result = StudentMatcherAdapter(capture, self.catalog)(
            {"target_id": "fixture"}, Event(), lambda *_item: None
        )[0]
        self.assertEqual(1, result["payload"]["values"]["skill2"])
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
        self.assertEqual(12, len(crops.cell_groups))
        self.assertEqual(
            (2, 2, 2, 2, 2, 1, 2, 3),
            tuple(
                len(crops.cell_groups[key])
                for key in StudentBasicCropSet.STUDIO_NUMERIC_KEYS
            ),
        )
        crops.close()

    def test_weapon_star_above_game_maximum_is_not_confirmed(self) -> None:
        recognizer = StudentBasicRecognizer(self.catalog)
        recognizer._color_bbox = lambda *_args: (0, 0, 49, 10)
        observation = recognizer.read_weapon_star(Image.new("RGB", (60, 20)))
        self.assertIsNone(observation.value)
        self.assertEqual("uncertain", observation.status)

    def test_weapon_studio_bank_is_resolution_invariant(self) -> None:
        recognizer = StudentBasicRecognizer(self.catalog)
        templates = recognizer.studio_numeric_bank.templates
        cells = tuple(
            templates[roi][digit].resize(
                (max(1, templates[roi][digit].width // 2), max(1, templates[roi][digit].height // 2)),
                Image.Resampling.NEAREST,
            ).convert("RGB")
            for roi, digit in (("weaponlevel_digit1", "4"), ("weaponlevel_digit2", "8"))
        )
        try:
            match = recognizer.studio_numeric_bank.match(
                cells,
                field="weapon_level",
                roi_names=("weaponlevel_digit1", "weaponlevel_digit2"),
            )
            self.assertEqual(48, match.value)
            self.assertGreaterEqual(match.score, 0.65)
            self.assertGreaterEqual(match.margin, 0.05)
        finally:
            for cell in cells:
                cell.close()

    def test_review_training_covers_all_requested_student_numeric_fields(self) -> None:
        with TemporaryDirectory() as temporary:
            store = RecognitionAnswerSampleStore(Path(temporary))
            matcher = StudentMatcherAdapter(
                CountingCapture(FIXTURES / "student_scan_s2_serika_new_year.png"),
                self.catalog,
                answer_samples=store,
            )

            def cells(field: str) -> tuple[Image.Image, Image.Image]:
                color = (90, 110, 135) if field == "relationship_rank" else (255, 255, 255)
                result = []
                for x in (4, 7):
                    image = Image.new("RGB", (12, 16))
                    for y in range(3, 13):
                        image.putpixel((x, y), color)
                    result.append(image)
                return tuple(result)  # type: ignore[return-value]

            groups = {
                "basic_student_level_studio_cells": cells("student_level"),
                "basic_weapon_level_studio_cells": cells("weapon_level"),
                "basic_relationship_rank_studio_2_cells": cells("relationship_rank"),
                "basic_equipment_1_level_studio_cells": cells("equipment_level"),
                "basic_equipment_2_level_studio_cells": cells("equipment_level"),
                "basic_equipment_3_level_studio_cells": cells("equipment_level"),
            }
            specimen = {"source_size": (1280, 720), "numeric_groups": groups}
            payload = {
                "values": {
                    "level": 12, "bond_rank": 28, "weapon_level": 48,
                    "equip1_level": 10, "equip2_level": 20, "equip3_level": 30,
                }
            }
            try:
                self.assertEqual(
                    12,
                    matcher.train_user_answer("a" * 24, "candidate-1", specimen, payload),
                )
                loaded = store.load_numeric("a" * 24, (1280, 720))
                try:
                    self.assertEqual(12, len(loaded))
                    self.assertEqual(
                        {"student_level", "relationship_rank", "weapon_level", "equipment_level"},
                        {sample.field for sample in loaded},
                    )
                finally:
                    store.close(loaded)
            finally:
                for group in groups.values():
                    for image in group:
                        image.close()


if __name__ == "__main__":
    unittest.main()
