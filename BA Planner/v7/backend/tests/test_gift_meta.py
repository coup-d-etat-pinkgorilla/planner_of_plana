from __future__ import annotations

import unittest

from core import gift_meta, student_meta


class GiftMetaTests(unittest.TestCase):
    def test_generated_minimal_gift_catalog_is_available(self) -> None:
        self.assertEqual(52, len(gift_meta.all_ids()))
        self.assertEqual("Favor", gift_meta.category(5000))
        self.assertGreater(gift_meta.exp_value(5000), 0)
        self.assertTrue(gift_meta.tags(5000))

    def test_student_gift_affinity_accessors_are_typed(self) -> None:
        self.assertIsInstance(student_meta.schaledb_id("hoshino"), int)
        self.assertTrue(student_meta.favor_item_tags("hoshino"))
        self.assertTrue(student_meta.favor_item_unique_tags("hoshino"))
        self.assertEqual((), student_meta.favor_item_tags("missing"))


if __name__ == "__main__":
    unittest.main()
