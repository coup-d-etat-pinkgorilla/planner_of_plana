from __future__ import annotations

import unittest
from unittest.mock import patch

from PIL import Image

from core.scanner import FieldStatus, Scanner, StudentEntry


class EquipmentTierInferenceTests(unittest.TestCase):
    def _scan_slot(self, *, score: float, level: int) -> StudentEntry:
        scanner = Scanner.__new__(Scanner)
        scanner._info = lambda _message: None
        scanner._status = lambda *_args, **_kwargs: None
        entry = StudentEntry(student_id="test")
        region = {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0}
        regions = {
            "equipment_2": region,
            "equipment_2_level_digit_1": region,
            "equipment_2_level_digit_2": region,
        }

        with (
            patch("core.scanner.rank_equip_tier_candidates", return_value=[("T10", score)]),
            patch("core.scanner.read_equip_level", return_value=level),
        ):
            scanner._scan_equip_slot(
                entry,
                Image.new("RGB", (32, 32), "white"),
                regions,
                2,
                skip_flags=set(),
                scan_level=True,
            )
        return entry

    def test_level70_and_supported_t10_match_is_inferred(self) -> None:
        entry = self._scan_slot(score=0.686, level=70)

        self.assertEqual(entry.equip2, "T10")
        self.assertEqual(entry.equip2_level, 70)
        self.assertEqual(entry.get_meta("equip2").status, FieldStatus.INFERRED)
        self.assertNotIn("equip2", entry.uncertain_fields())

    def test_low_t10_score_stays_uncertain(self) -> None:
        entry = self._scan_slot(score=0.65, level=70)

        self.assertEqual(entry.equip2, "unknown")
        self.assertEqual(entry.get_meta("equip2").status, FieldStatus.UNCERTAIN)


if __name__ == "__main__":
    unittest.main()
