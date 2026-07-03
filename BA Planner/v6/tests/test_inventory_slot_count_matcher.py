from __future__ import annotations

import unittest

from core.inventory_slot_count_matcher import _expand_slot_count_value


class InventorySlotCountMatcherTests(unittest.TestCase):
    def test_does_not_expand_k_suffix_counts(self) -> None:
        self.assertEqual(_expand_slot_count_value("21", "k"), "21")
        self.assertEqual(_expand_slot_count_value("22", "K"), "22")

    def test_keeps_plain_digit_counts(self) -> None:
        self.assertEqual(_expand_slot_count_value("459"), "459")


if __name__ == "__main__":
    unittest.main()
