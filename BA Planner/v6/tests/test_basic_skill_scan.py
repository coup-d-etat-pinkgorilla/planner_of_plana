from __future__ import annotations

import unittest
from unittest.mock import patch

from PIL import Image

from core.matcher import RecognitionResult
from core.scanner import FieldStatus, Scanner, StudentEntry


class BasicSkillScanTests(unittest.TestCase):
    def _scanner(self) -> Scanner:
        scanner = Scanner.__new__(Scanner)
        region = {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0}
        scanner.r = {
            "student": {
                "basic_EX_skill": region,
                "basic_Skill_1": region,
                "basic_Skill_2": region,
                "basic_Skill_3": region,
            }
        }
        scanner._info = lambda _message: None
        scanner._status = lambda *_args, **_kwargs: None
        return scanner

    def test_one_star_skips_enhanced_and_sub_skills(self) -> None:
        scanner = self._scanner()
        entry = StudentEntry(student_id="shizuko_swimsuit", student_star=1)
        recognized = [
            RecognitionResult(value=1, score=0.99),
            RecognitionResult(value=1, score=0.99),
        ]

        with patch("core.scanner.read_basic_skill_result", side_effect=recognized) as reader:
            success = scanner._read_skills_from_basic(
                entry,
                Image.new("RGB", (32, 32), "white"),
            )

        self.assertTrue(success)
        self.assertEqual(reader.call_count, 2)
        self.assertEqual((entry.ex_skill, entry.skill1), (1, 1))
        self.assertIsNone(entry.skill2)
        self.assertIsNone(entry.skill3)
        self.assertEqual(entry.get_meta("skill2").status, FieldStatus.SKIPPED)
        self.assertEqual(entry.get_meta("skill3").status, FieldStatus.SKIPPED)

    def test_uncertain_basic_result_uses_menu_fallback_without_partial_write(self) -> None:
        scanner = self._scanner()
        entry = StudentEntry(student_id="test", student_star=3)

        with patch(
            "core.scanner.read_basic_skill_result",
            return_value=RecognitionResult(value=3, score=0.60, uncertain=True),
        ):
            success = scanner._read_skills_from_basic(
                entry,
                Image.new("RGB", (32, 32), "white"),
            )

        self.assertFalse(success)
        self.assertIsNone(entry.ex_skill)
        self.assertIsNone(entry.skill1)
        self.assertIsNone(entry.skill2)
        self.assertIsNone(entry.skill3)


if __name__ == "__main__":
    unittest.main()
