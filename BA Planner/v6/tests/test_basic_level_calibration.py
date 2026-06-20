from __future__ import annotations

import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

from core.scanner import Scanner


class BasicLevelCalibrationTests(unittest.TestCase):
    def test_panel_truth_trains_position_specific_run_templates(self) -> None:
        scanner = Scanner.__new__(Scanner)
        scanner._basic_level_run_templates = {}
        glyph_9 = np.full((32, 24), 90, dtype=np.uint8)
        glyph_0 = np.full((32, 24), 10, dtype=np.uint8)

        with patch(
            "core.scanner.extract_basic_student_level_glyphs",
            return_value=([glyph_9, glyph_0], True),
        ):
            learned = scanner._learn_basic_level_for_run(
                Image.new("RGB", (32, 32)),
                {},
                90,
            )

        self.assertTrue(learned)
        self.assertEqual(1, len(scanner._basic_level_run_templates[0]["9"]))
        self.assertEqual(1, len(scanner._basic_level_run_templates[1]["0"]))

    def test_mismatched_digit_count_is_not_trained(self) -> None:
        scanner = Scanner.__new__(Scanner)
        scanner._basic_level_run_templates = {}
        glyph = np.full((32, 24), 255, dtype=np.uint8)

        with patch(
            "core.scanner.extract_basic_student_level_glyphs",
            return_value=([glyph], False),
        ):
            learned = scanner._learn_basic_level_for_run(
                Image.new("RGB", (32, 32)),
                {},
                90,
            )

        self.assertFalse(learned)
        self.assertEqual({}, scanner._basic_level_run_templates)


if __name__ == "__main__":
    unittest.main()
