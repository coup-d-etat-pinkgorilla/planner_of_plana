from __future__ import annotations

import unittest

from core.inventory_catalog import CATALOG, BY_KEY, catalog_payload


class InventoryCatalogTests(unittest.TestCase):
    def test_catalog_has_stable_unique_identity_and_profile_order(self) -> None:
        keys = [row.resource_key for row in CATALOG]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertEqual(keys, [row["resource_key"] for row in catalog_payload()])
        for profile in {row.profile_id for row in CATALOG}:
            indexes = [row.order_index for row in CATALOG if row.profile_id == profile]
            self.assertEqual(indexes, sorted(indexes))
            self.assertEqual(len(indexes), len(set(indexes)))

    def test_representative_v6_profiles_are_present_and_zero_fill_is_explicit(self) -> None:
        representative = {
            "Item_Icon_ExpItem_0": "activity_reports",
            "Item_Icon_SkillBook_Hyakkiyako_0": "tech_notes",
            "Item_Icon_Material_ExSkill_Hyakkiyako_0": "tactical_bd",
            "Item_Icon_Material_Nebra_0": "ooparts",
            "Item_Icon_SecretStone_ayane": "student_elephs",
        }
        for key, profile in representative.items():
            with self.subTest(key=key):
                self.assertIn(key, BY_KEY)
                self.assertEqual(BY_KEY[key].profile_id, profile)
                self.assertTrue(BY_KEY[key].zero_fill_allowed)


if __name__ == "__main__":
    unittest.main()
