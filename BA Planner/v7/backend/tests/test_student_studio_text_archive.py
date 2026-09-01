from __future__ import annotations

import json
from pathlib import Path
import unittest


FIXTURE = Path(__file__).parent / "fixtures" / "student_studio_text_archive_summary.json"


class StudentStudioTextArchiveBenchmarkTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.summary = json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_archive_and_answer_coverage_is_frozen(self) -> None:
        self.assertEqual(self.summary["screenshot_files"], 313)
        self.assertEqual(self.summary["resolved_answer_files"], 163)
        self.assertEqual(self.summary["template_count"], 160)
        self.assertEqual(
            self.summary["unsupported_layouts"],
            {"equipment_one_digit": 9},
        )

    def test_two_digit_equipment_is_visually_exact(self) -> None:
        row = self.summary["results"]["equipment_level_visual_ground_truth"]
        self.assertEqual((row["correct"], row["values"]), (307, 307))
        self.assertEqual(row["confusion"], {})
        self.assertGreater(row["minimum_margin"], 0.07)

    def test_relationship_all_supported_layouts_are_visually_exact(self) -> None:
        row = self.summary["results"]["relationship_rank_visual_ground_truth"]
        self.assertEqual((row["correct"], row["values"]), (26, 26))
        self.assertEqual((row["digit_correct"], row["digits"]), (52, 52))
        self.assertEqual(row["accuracy"], 1.0)
        self.assertEqual(row["confusion"], {})
        self.assertGreater(row["minimum_margin"], 0.03)
        self.assertEqual(
            {
                layout: (result["correct"], result["values"], result["digit_correct"], result["digits"])
                for layout, result in row["layouts"].items()
            },
            {
                "1": (1, 1, 1, 1),
                "2": (24, 24, 48, 48),
                "3": (1, 1, 3, 3),
            },
        )

    def test_student_tall_component_cleanup_restores_legacy_agreement(self) -> None:
        row = self.summary["results"]["student_level_legacy_agreement"]
        self.assertEqual((row["correct"], row["values"]), (122, 122))
        self.assertEqual(row["confusion"], {})
        self.assertGreater(row["minimum_margin"], 0.14)

    def test_student_reviewed_series_covers_non_ninety_levels(self) -> None:
        row = self.summary["results"]["student_level_visual_ground_truth"]
        self.assertEqual((row["correct"], row["values"]), (10, 10))
        self.assertEqual((row["digit_correct"], row["digits"]), (19, 19))
        self.assertEqual(row["single_digit_blank_correct"], 1)
        self.assertEqual(row["coverage_values"], [1, 12, 23, 34, 45, 56, 67, 78, 89, 90])

    def test_weapon_zero_eight_samples_are_independent_visual_ground_truth(self) -> None:
        row = self.summary["results"]["weapon_level_visual_ground_truth"]
        self.assertEqual((row["correct"], row["values"]), (16, 16))
        self.assertEqual((row["digit_correct"], row["digits"]), (32, 32))
        self.assertEqual(row["confusion"], {})
        self.assertGreater(row["minimum_margin"], 0.09)

    def test_weapon_legacy_agreement_remains_exact(self) -> None:
        row = self.summary["results"]["weapon_level_legacy_agreement"]
        self.assertEqual((row["correct"], row["values"]), (89, 89))
        self.assertEqual(row["confusion"], {})


if __name__ == "__main__":
    unittest.main()
