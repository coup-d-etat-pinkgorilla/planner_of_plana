from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_scan_recognizer import StudentBasicCropSet, StudentBasicRecognizer


BACKEND = Path(__file__).resolve().parents[1]
FIXTURE = BACKEND / "tests" / "fixtures" / "student_relationship_s4"


class StudentRelationshipS4Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads((FIXTURE / "manifest.json").read_text(encoding="utf-8"))
        cls.recognizer = StudentBasicRecognizer(
            RecognitionAssetCatalog(BACKEND / "assets" / "recognition" / "v1"),
        )

    def test_boundary_gates_remain_explicit(self) -> None:
        self.assertEqual([1, 9], self.manifest["coverage"]["not_verified"])
        self.assertIn(6, self.manifest["coverage"]["verified_ranks"])
        self.assertIn(10, self.manifest["coverage"]["verified_ranks"])
        self.assertIn(100, self.manifest["coverage"]["verified_ranks"])

    def test_rank_100_calibration_asset_is_wired_and_replays(self) -> None:
        record = next(
            item for item in self.manifest["records"] if item["rank"] == 100
        )
        self.assertEqual([2560, 1440], record["source_size"])
        self.assertEqual("calibration", record["partition"])
        with Image.open(FIXTURE / self.manifest["atlas"]["path"]) as atlas:
            observation = self.recognizer.read_relationship_rank(
                atlas.crop(record["atlas_box"])
            )
        self.assertEqual(100, observation.value, observation.note)
        self.assertEqual("ok", observation.status)

    def test_live_hibiki_rank_50_regression_replays(self) -> None:
        record = next(
            item for item in self.manifest["records"]
            if item["source_file"] == "hibiki_rank50_1280x720_20260824.png"
        )
        self.assertEqual(50, record["rank"])
        self.assertEqual([1280, 720], record["source_size"])
        with Image.open(FIXTURE / self.manifest["atlas"]["path"]) as atlas:
            observation = self.recognizer.read_relationship_rank(
                atlas.crop(record["atlas_box"])
            )
        self.assertEqual(50, observation.value, observation.note)
        self.assertEqual("ok", observation.status)

    def test_unseen_rank_24_is_read_as_digits_instead_of_nearest_whole_rank(self) -> None:
        frame_path = BACKEND / "tests" / "fixtures" / "student_scan_s2_serika_new_year.png"
        with Image.open(frame_path) as frame:
            crops = StudentBasicCropSet.from_frame(
                frame,
                self.recognizer.catalog.region("student"),
            )
        try:
            observation = self.recognizer.read_relationship_rank(
                crops.images["basic_relationship_rank_region"],
                {
                    digit_count: crops.cell_groups[
                        f"basic_relationship_rank_studio_{digit_count}_cells"
                    ]
                    for digit_count in (1, 2, 3)
                },
            )
        finally:
            crops.close()
        self.assertEqual(24, observation.value, observation.note)
        self.assertEqual("ok", observation.status)
        self.assertEqual("relationship_rank_studio_position_bank", observation.source)

    def test_validation_partition_matches_reviewed_rank(self) -> None:
        with Image.open(FIXTURE / self.manifest["atlas"]["path"]) as atlas:
            for record in self.manifest["records"]:
                if record["partition"] != "validation":
                    continue
                with self.subTest(rank=record["rank"], source=record["source_file"]):
                    observation = self.recognizer.read_relationship_rank(atlas.crop(record["atlas_box"]))
                    self.assertEqual(record["rank"], observation.value, observation.note)
                    self.assertEqual("ok", observation.status)

    def test_rank_28_and_30_are_independent_zero_eight_validation_samples(self) -> None:
        records = {
            record["rank"]: record
            for record in self.manifest["records"]
            if record["rank"] in {28, 30}
        }
        self.assertEqual({28, 30}, set(records))
        self.assertEqual("studio_validation", records[28]["partition"])
        self.assertEqual("studio_validation", records[30]["partition"])
        self.assertEqual("mashiro", records[28]["student_ref"])
        self.assertEqual("utaha", records[30]["student_ref"])


if __name__ == "__main__":
    unittest.main()
