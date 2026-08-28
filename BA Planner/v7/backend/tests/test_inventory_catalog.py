from __future__ import annotations

import unittest

from core.inventory_catalog import CATALOG, BY_KEY, CATALOG_REVISION, _catalog_revision, catalog_payload, ordered_student_eleph_ids


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

    def test_catalog_revision_is_deterministic_sha256(self) -> None:
        self.assertRegex(CATALOG_REVISION, r"^[0-9a-f]{64}$")
        self.assertEqual(CATALOG_REVISION, _catalog_revision(catalog_payload()))

    def test_student_eleph_order_is_version_scoped_not_identity(self) -> None:
        names = {"a": "나", "b": "다", "new": "가"}
        base = ordered_student_eleph_ids(["a", "b"], names.__getitem__, lambda _sid: False)
        expanded = ordered_student_eleph_ids(["a", "b", "new"], names.__getitem__, lambda _sid: False)
        self.assertEqual(["a", "b"], base)
        self.assertEqual(["new", "a", "b"], expanded)
        self.assertEqual("a", base[0])
        self.assertEqual("a", expanded[1])


if __name__ == "__main__":
    unittest.main()
