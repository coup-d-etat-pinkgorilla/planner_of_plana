"""Future product focused draft: metadata exact mapping, strict new scalars, stable identity."""
from __future__ import annotations

from dataclasses import replace
import json
from pathlib import Path
import unittest

from core import inventory_catalog as catalog
from core.equipment_items import EQUIPMENT_SERIES, EQUIPMENT_ORDERED_ITEM_IDS

ROOT = Path(__file__).resolve().parents[2]
OLD_KEYS = {"resource_key", "item_id", "display_name", "category", "profile_id", "order_index", "zero_fill_allowed"}
NEW_KEYS = OLD_KEYS | {"school", "family", "tier"}


class InventoryMetadataFB3aTests(unittest.TestCase):
    def test_all_rows_have_exact10_and_scan_support_stays7_and6(self):
        self.assertTrue(catalog.CATALOG)
        self.assertTrue(all(set(row.to_dict()) == NEW_KEYS for row in catalog.CATALOG))
        self.assertEqual(("equipment", "activity_reports", "tech_notes", "tactical_bd", "ooparts", "presents", "student_elephs"), catalog.SCAN_PROFILES)
        self.assertEqual(catalog.SCAN_PROFILES[1:], catalog.ITEM_SCAN_PROFILES)
        self.assertEqual(catalog._catalog_revision(catalog.catalog_payload()), catalog.CATALOG_REVISION)

    def test_all_supply_school_notes_and_bds_are_explicit(self):
        for school in catalog._SCHOOLS:
            for prefix, family in (("Item_Icon_SkillBook", "tech_notes"), ("Item_Icon_Material_ExSkill", "tactical_bd")):
                for tier in range(1, 5):
                    row = catalog.BY_KEY[f"{prefix}_{school}_{tier - 1}"]
                    with self.subTest(key=row.resource_key):
                        self.assertEqual((school, family, tier), (row.school, row.family, row.tier))
        ultimate = catalog.BY_KEY["Item_Icon_SkillBook_Ultimate"]
        self.assertEqual((None, None, None), (ultimate.school, ultimate.family, ultimate.tier))
        self.assertEqual("Item_Icon_SkillBook_Ultimate", catalog.canonical_resource_key("Item_Icon_SkillBook_Ultimate_Piece"))

    def test_all_ooparts_and_workbook_tokens_are_explicit(self):
        for _display, icon in catalog._OPARTS:
            for tier in range(1, 5):
                row = catalog.BY_KEY[f"Item_Icon_Material_{icon}_{tier - 1}"]
                self.assertEqual((None, f"oopart:{icon}", tier), (row.school, row.family, row.tier))
        for token in ("PotentialMaxHP", "PotentialAttack", "PotentialHealPower"):
            row = catalog.BY_KEY["Item_Icon_WorkBook_" + token]
            self.assertEqual((None, "workbook:" + token, None), (row.school, row.family, row.tier))

    def test_all_equipment_series_useall_exp_and_weapon_parts(self):
        for series in EQUIPMENT_SERIES:
            for tier in range(1, 11):
                row = catalog.BY_KEY[f"Equipment_Icon_{series.icon_key}_Tier{tier}"]
                self.assertEqual((None, "equipment:" + series.icon_key, tier), (row.school, row.family, row.tier))
            row = catalog.BY_KEY[f"Equipment_Icon_{series.icon_key}_Useall_Piece"]
            self.assertEqual((None, "equipment:" + series.icon_key, None), (row.school, row.family, row.tier))
        for tier in range(1, 5):
            row = catalog.BY_KEY[f"Equipment_Icon_Exp_{tier - 1}"]
            self.assertEqual((None, "equipment_exp", tier), (row.school, row.family, row.tier))
            for part in ("A", "B", "C", "Z"):
                row = catalog.BY_KEY[f"Equipment_Icon_WeaponExpGrowth{part}_{tier - 1}"]
                self.assertEqual((None, "weapon_exp:" + part, tier), (row.school, row.family, row.tier))
        self.assertEqual(list(EQUIPMENT_ORDERED_ITEM_IDS), [row.item_id for row in catalog.CATALOG if row.profile_id == "equipment"])

    def test_reports_have_tiers_and_presents_elephs_have_null_metadata(self):
        for tier in range(1, 5):
            row = catalog.BY_KEY[f"Item_Icon_ExpItem_{tier - 1}"]
            self.assertEqual((None, "activity_report", tier), (row.school, row.family, row.tier))
        rows = [row for row in catalog.CATALOG if row.profile_id in {"presents", "student_elephs"}]
        self.assertTrue(rows)
        self.assertTrue(all((row.school, row.family, row.tier) == (None, None, None) for row in rows))

    def test_exact_equipment_lookup_does_not_infer_from_suffix_or_label(self):
        lookup = catalog._equipment_row_metadata()
        for key in ("Equipment_Icon_Watch_Tier11", "Equipment_Icon_Unknown_Tier2", "Equipment_Icon_Watch_Tier2_Garbage", "Equipment_Icon_WeaponExpGrowthQ_0", "Equipment_Icon_Exp_4", "Equipment_Icon_Watch_Useall_PieceX"):
            self.assertNotIn(key, lookup)
        row = catalog.InventoryCatalogRow("unknown_42", "unknown_42", "Trinity BD T9", "material", "unreviewed", 0, True)
        self.assertEqual((None, None, None), (row.school, row.family, row.tier))
        self.assertEqual(NEW_KEYS, set(row.to_dict()))

    def test_new_tier_is_exact_positive_int_or_null(self):
        row = catalog.BY_KEY["Item_Icon_ExpItem_0"]
        for bad in (True, False, 0, -1, 1.0, 1.5, "1", [], {}):
            with self.subTest(value=bad), self.assertRaises(ValueError):
                replace(row, tier=bad)
        for good in (None, 1, 10, 11):  # Wire scalar has no global max; mapping yields the reviewed local tiers.
            self.assertEqual(good, replace(row, tier=good).tier)

    def test_new_metadata_strings_only_are_validated(self):
        row = catalog.BY_KEY["Item_Icon_ExpItem_0"]
        for field in ("school", "family"):
            for bad in (True, 1, 1.0, [], {}, "\ud800", "\udfff"):
                with self.subTest(field=field, value=repr(bad)), self.assertRaises(ValueError):
                    replace(row, **{field: bad})
            for good in (None, "", "Future school 🧪", "  raw  "):
                self.assertEqual(good, getattr(replace(row, **{field: good}), field))
        # Existing names/keys/stored history validators are not strengthened by the new-field checks.
        self.assertEqual("\ud800", replace(row, display_name="\ud800").display_name)

    def test_shared_parity_fixture_and_schema_required10(self):
        fixture = json.loads((ROOT / "contracts/fixtures/inventory_catalog_v6_parity.json").read_text(encoding="utf-8"))
        self.assertEqual(fixture["catalog_revision"], catalog.CATALOG_REVISION)
        for expected in fixture["representative_rows"]:
            self.assertTrue({"school", "family", "tier"}.issubset(expected))
            actual = catalog.BY_KEY[expected["resource_key"]].to_dict()
            for key, value in expected.items():
                self.assertEqual(value, actual[key])
        schema = json.loads((ROOT / "contracts/planning-inventory-catalog-v1.schema.json").read_text(encoding="utf-8"))
        self.assertEqual(NEW_KEYS, set(schema["$defs"]["item"]["required"]))
        self.assertFalse(schema["$defs"]["item"]["additionalProperties"])


    def test_shared_negative_row_oracles_use_schema_and_strict_constructor_separately(self):
        from jsonschema import Draft202012Validator
        fixture = json.loads((ROOT / "contracts/fixtures/inventory_catalog_fb3_metadata.json").read_text(encoding="utf-8"))
        schema = json.loads((ROOT / "contracts/planning-inventory-catalog-v1.schema.json").read_text(encoding="utf-8"))
        validator = Draft202012Validator(schema["$defs"]["item"])
        for case in fixture["cases"]:
            row = case["row"]
            with self.subTest(case=case["name"]):
                self.assertEqual(case["schema_valid"], validator.is_valid(row))
                valid = False
                if set(row) == NEW_KEYS:
                    try:
                        catalog.InventoryCatalogRow(**row)
                        valid = True
                    except (ValueError, TypeError):
                        pass
                self.assertEqual(case["strict_dto_valid"], valid)


if __name__ == "__main__":
    unittest.main()
