from __future__ import annotations

import json
import os
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from core.inventory_profiles import (
    get_inventory_profile,
    inventory_item_display_name,
    inventory_profile_ordered_item_ids,
)
from core.scanner import (
    INVENTORY_DIRECT_ICON_MATCH_ENV,
    _inventory_detail_template_catalog,
    _inventory_detail_template_region,
    _inventory_grid_template_config,
    _inventory_grid_template_matching_config,
    _inventory_template_catalog,
)


ARU_ELEPH = "".join(chr(cp) for cp in [0xC544, 0xB8E8, 0xC758, 0x20, 0xC5D8, 0xB808, 0xD504])


class InventoryElephProfileTests(unittest.TestCase):
    def test_profile_excludes_jp_only_students_and_sorts_variants_before_base(self) -> None:
        profile = get_inventory_profile("student_elephs")
        self.assertIsNotNone(profile)
        assert profile is not None

        ordered_ids = list(inventory_profile_ordered_item_ids(profile))
        self.assertIn("Item_Icon_SecretStone_neru_school_uniform", ordered_ids)
        self.assertIn("Item_Icon_SecretStone_neru_bunny_girl", ordered_ids)
        self.assertIn("Item_Icon_SecretStone_neru", ordered_ids)
        self.assertNotIn("Item_Icon_SecretStone_kisaki_swimsuit", ordered_ids)

        neru_order = [
            ordered_ids.index("Item_Icon_SecretStone_neru_school_uniform"),
            ordered_ids.index("Item_Icon_SecretStone_neru_bunny_girl"),
            ordered_ids.index("Item_Icon_SecretStone_neru"),
        ]
        self.assertEqual(neru_order, sorted(neru_order))

    def test_profile_sorts_by_full_eleph_item_label(self) -> None:
        profile = get_inventory_profile("student_elephs")
        self.assertIsNotNone(profile)
        assert profile is not None

        ordered_ids = list(inventory_profile_ordered_item_ids(profile))
        mari_targets = [
            "Item_Icon_SecretStone_mari_idol",
            "Item_Icon_SecretStone_mari_sportswear",
            "Item_Icon_SecretStone_marina_qipao",
            "Item_Icon_SecretStone_marina",
            "Item_Icon_SecretStone_mari",
        ]
        rei_targets = [
            "Item_Icon_SecretStone_reisa_magical",
            "Item_Icon_SecretStone_reisa",
            "Item_Icon_SecretStone_rei",
            "Item_Icon_SecretStone_reijo",
        ]

        self.assertEqual([item_id for item_id in ordered_ids if item_id in mari_targets], mari_targets)
        self.assertEqual([item_id for item_id in ordered_ids if item_id in rei_targets], rei_targets)

    def test_secret_stone_display_name_uses_student_name(self) -> None:
        self.assertEqual(inventory_item_display_name("Item_Icon_SecretStone_aru"), ARU_ELEPH)

    def test_present_display_names_use_korean_labels(self) -> None:
        self.assertEqual(inventory_item_display_name("Item_Icon_Favor_0"), "웨이브캣 배게")
        self.assertEqual(inventory_item_display_name("Item_Icon_Favor_Lv2_10"), "음악 연주회 입장권")
        self.assertEqual(inventory_item_display_name("Item_Icon_Favor_SSR_GL_20"), "Anime Expo 기념 카드")

    def test_item_grid_catalog_includes_student_eleph_icons(self) -> None:
        catalog = dict(_inventory_template_catalog("item"))
        self.assertIn("Item_Icon_SecretStone_aru", catalog)
        self.assertTrue(catalog["Item_Icon_SecretStone_aru"].endswith("Item_Icon_SecretStone_aru.png"))

    def test_scan_matching_config_enables_direct_icon_by_default(self) -> None:
        section = json.loads(Path("regions/item_regions.json").read_text(encoding="utf-8-sig"))["item"]
        base_config = _inventory_grid_template_config(section, "tech_notes")
        self.assertIsNotNone(base_config)
        assert base_config is not None
        self.assertTrue(base_config["direct_icon_match"]["enabled"])

        with patch.dict("os.environ", {}, clear=False):
            os.environ.pop(INVENTORY_DIRECT_ICON_MATCH_ENV, None)
            config = _inventory_grid_template_matching_config(section, "tech_notes")

        self.assertIsNotNone(config)
        assert config is not None
        self.assertTrue(config["direct_icon_match"]["enabled"])
        self.assertTrue(base_config["direct_icon_match"]["enabled"])

    def test_scan_matching_config_can_disable_direct_icon_by_env(self) -> None:
        section = json.loads(Path("regions/item_regions.json").read_text(encoding="utf-8-sig"))["item"]

        with patch.dict("os.environ", {INVENTORY_DIRECT_ICON_MATCH_ENV: "0"}):
            config = _inventory_grid_template_matching_config(section, "tech_notes")

        self.assertIsNotNone(config)
        assert config is not None
        self.assertFalse(config["direct_icon_match"]["enabled"])

    def test_student_eleph_grid_config_uses_custom_crop(self) -> None:
        section = json.loads(Path("regions/item_regions.json").read_text(encoding="utf-8-sig"))["item"]
        config = _inventory_grid_template_config(section, "student_elephs")
        self.assertIsNotNone(config)
        assert config is not None
        self.assertEqual(config["tier_hint"]["enabled"], False)
        self.assertEqual([row["name"] for row in config["composite_rois"]], ["face", "outer_appearance"])
        self.assertAlmostEqual(config["composite_rois"][0]["weight"], 0.9)
        self.assertAlmostEqual(config["crop_ratio"]["left"], 0.3630, places=4)
        self.assertAlmostEqual(config["crop_ratio"]["right"], 0.3592, places=4)
        self.assertAlmostEqual(config["crop_ratio"]["top"], 0.2896, places=4)
        self.assertAlmostEqual(config["crop_ratio"]["bottom"], 0.3159, places=4)

    def test_present_profile_uses_present_icon_templates_and_eleph_grid_config(self) -> None:
        profile = get_inventory_profile("presents")
        self.assertIsNotNone(profile)
        assert profile is not None

        ordered_ids = list(inventory_profile_ordered_item_ids(profile))
        self.assertIn("Item_Icon_Favor_0", ordered_ids)
        self.assertIn("Item_Icon_Favor_SSR_GL_20", ordered_ids)
        self.assertNotIn("Item_Icon_SecretStone_aru", ordered_ids)

        catalog = dict(_inventory_template_catalog("item"))
        self.assertIn("Item_Icon_Favor_0", catalog)
        self.assertTrue(catalog["Item_Icon_Favor_0"].endswith("templates\\icons\\presents\\Item_Icon_Favor_0.png") or catalog["Item_Icon_Favor_0"].endswith("templates/icons/presents/Item_Icon_Favor_0.png"))

        section = json.loads(Path("regions/item_regions.json").read_text(encoding="utf-8-sig"))["item"]
        config = _inventory_grid_template_config(section, "presents")
        self.assertIsNotNone(config)
        assert config is not None
        self.assertEqual(config["tier_hint"]["enabled"], True)
        self.assertEqual(config["background"], "icons/temp/square_yellow.png")
        self.assertEqual(config["candidate_filter"]["mode"], "background_tier")
        self.assertEqual(config["use_numeric_tier_backgrounds"], False)
        self.assertEqual(config["background_rules"][0]["contains"], "SSR")
        self.assertEqual(config["background_rules"][0]["background"], "icons/temp/square_purple.png")
        self.assertEqual(config["background_rules"][1]["contains"], "Lv2")
        self.assertEqual(config["background_rules"][1]["background"], "icons/temp/square_purple.png")
        self.assertAlmostEqual(config["crop_ratio"]["left"], 0.34, places=4)
        self.assertAlmostEqual(config["crop_ratio"]["right"], 0.34, places=4)
        self.assertEqual(config["composite_rois"][0]["name"], "object")

    def test_present_profile_order_matches_folder_natural_order(self) -> None:
        profile = get_inventory_profile("presents")
        self.assertIsNotNone(profile)
        assert profile is not None

        ordered_ids = list(inventory_profile_ordered_item_ids(profile))
        expected_span = [
            "Item_Icon_Favor_8",
            "Item_Icon_Favor_9",
            "Item_Icon_Favor_10",
            "Item_Icon_Favor_11",
        ]
        self.assertEqual([item_id for item_id in ordered_ids if item_id in expected_span], expected_span)

        expected_ssr_span = [
            "Item_Icon_Favor_SSR_GL_8",
            "Item_Icon_Favor_SSR_GL_9",
            "Item_Icon_Favor_SSR_GL_10",
            "Item_Icon_Favor_SSR_GL_11",
        ]
        self.assertEqual([item_id for item_id in ordered_ids if item_id in expected_ssr_span], expected_ssr_span)

    def test_present_detail_fallback_templates_use_eleph_roi(self) -> None:
        catalog = dict(_inventory_detail_template_catalog("presents"))
        self.assertIn("Item_Icon_Favor_0", catalog)
        self.assertIn("Item_Icon_Favor_SSR_GL_20", catalog)
        with Image.open(catalog["Item_Icon_Favor_0"]) as image:
            self.assertEqual(image.size, (298, 327))
        region = _inventory_detail_template_region("presents")
        self.assertIsNotNone(region)
        assert region is not None
        self.assertAlmostEqual(region["x1"], 511 / 2560, places=6)
        self.assertAlmostEqual(region["y1"], 331 / 1440, places=6)
        self.assertAlmostEqual(region["x2"], 809 / 2560, places=6)
        self.assertAlmostEqual(region["y2"], 658 / 1440, places=6)

    def test_student_eleph_detail_fallback_templates_exist(self) -> None:
        catalog = dict(_inventory_detail_template_catalog("student_elephs"))
        self.assertIn("Item_Icon_SecretStone_aru", catalog)
        with Image.open(catalog["Item_Icon_SecretStone_aru"]) as image:
            self.assertEqual(image.size, (298, 327))
        region = _inventory_detail_template_region("student_elephs")
        self.assertIsNotNone(region)
        assert region is not None
        self.assertAlmostEqual(region["x1"], 511 / 2560, places=6)
        self.assertAlmostEqual(region["y1"], 331 / 1440, places=6)
        self.assertAlmostEqual(region["x2"], 809 / 2560, places=6)
        self.assertAlmostEqual(region["y2"], 658 / 1440, places=6)


if __name__ == "__main__":
    unittest.main()
