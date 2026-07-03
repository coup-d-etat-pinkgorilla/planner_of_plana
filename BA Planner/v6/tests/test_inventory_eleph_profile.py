from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image

from core.inventory_profiles import (
    get_inventory_profile,
    inventory_item_display_name,
    inventory_profile_ordered_item_ids,
)
from core.scanner import (
    _inventory_detail_template_catalog,
    _inventory_detail_template_region,
    _inventory_grid_template_config,
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

    def test_secret_stone_display_name_uses_student_name(self) -> None:
        self.assertEqual(inventory_item_display_name("Item_Icon_SecretStone_aru"), ARU_ELEPH)

    def test_item_grid_catalog_includes_student_eleph_icons(self) -> None:
        catalog = dict(_inventory_template_catalog("item"))
        self.assertIn("Item_Icon_SecretStone_aru", catalog)
        self.assertTrue(catalog["Item_Icon_SecretStone_aru"].endswith("Item_Icon_SecretStone_aru.png"))

    def test_student_eleph_grid_config_uses_custom_crop(self) -> None:
        section = json.loads(Path("regions/item_regions.json").read_text(encoding="utf-8-sig"))["item"]
        config = _inventory_grid_template_config(section, "student_elephs")
        self.assertIsNotNone(config)
        assert config is not None
        self.assertEqual(config["tier_hint"]["enabled"], False)
        self.assertAlmostEqual(config["crop_ratio"]["left"], 0.3630, places=4)
        self.assertAlmostEqual(config["crop_ratio"]["right"], 0.3592, places=4)
        self.assertAlmostEqual(config["crop_ratio"]["top"], 0.2896, places=4)
        self.assertAlmostEqual(config["crop_ratio"]["bottom"], 0.3159, places=4)

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
