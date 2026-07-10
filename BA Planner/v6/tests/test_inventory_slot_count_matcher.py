from __future__ import annotations

import unittest

from core.inventory_slot_count_matcher import K_SUFFIX_DIGIT_LEFT_SHIFT_PX, _digit_region, _expand_slot_count_value


class InventorySlotCountMatcherTests(unittest.TestCase):
    def test_does_not_expand_k_suffix_counts(self) -> None:
        self.assertEqual(_expand_slot_count_value("21", "k"), "21")
        self.assertEqual(_expand_slot_count_value("22", "K"), "22")

    def test_keeps_plain_digit_counts(self) -> None:
        self.assertEqual(_expand_slot_count_value("459"), "459")

    def test_k_suffix_digit_region_can_shift_left_six_pixels(self) -> None:
        slot = {"x1": 0.10, "y1": 0.20, "x2": 0.30, "y2": 0.40}
        normal = _digit_region(slot, 2, (1000, 800))
        shifted = _digit_region(
            slot,
            2,
            (1000, 800),
            x_offset_px=-K_SUFFIX_DIGIT_LEFT_SHIFT_PX,
        )
        normal_x = normal["points_ratio"][0]["x"] * 1000
        shifted_x = shifted["points_ratio"][0]["x"] * 1000
        self.assertAlmostEqual(normal_x - shifted_x, 6.0)


if __name__ == "__main__":
    unittest.main()
