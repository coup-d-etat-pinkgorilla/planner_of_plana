from __future__ import annotations

import unittest
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

from tools import build_present_detail_templates as builder


class PresentDetailTemplateBuilderTests(unittest.TestCase):
    def test_committed_background_is_blue_detail_screen_crop(self) -> None:
        with Image.open(builder.DEFAULT_BACKGROUND_ASSET) as source:
            background = source.convert("RGB")

        self.assertEqual(background.size, (298, 327))
        mean_red, mean_green, mean_blue = ImageStat.Stat(background).mean
        self.assertGreater(mean_blue, mean_red + 20)
        self.assertGreater(mean_green, mean_red + 10)

    def test_saved_present_templates_match_production_composition(self) -> None:
        config = builder.load_region_config()
        with Image.open(builder.DEFAULT_BACKGROUND_ASSET) as source:
            background = source.convert("RGB")

        for item_id in (
            "Item_Icon_Favor_18",
            "Item_Icon_Favor_Lv2_9",
            "Item_Icon_Favor_SSR_GL_16",
        ):
            icon_path = builder.DEFAULT_ICON_DIR / f"{item_id}.png"
            saved_path = builder.DEFAULT_OUTPUT_DIR / f"{item_id}.png"
            with Image.open(icon_path) as icon:
                expected = builder.compose_present_detail_template(background, icon, config)
            with Image.open(saved_path) as saved:
                actual = saved.convert("RGB")
            self.assertIsNone(
                ImageChops.difference(expected, actual).getbbox(),
                msg=item_id,
            )

    def test_every_present_icon_has_a_detail_fallback_template(self) -> None:
        icon_names = {path.name for path in builder.DEFAULT_ICON_DIR.glob("*.png")}
        detail_names = {
            path.name
            for path in builder.DEFAULT_OUTPUT_DIR.glob("*.png")
            if not path.name.startswith("_")
        }

        self.assertEqual(len(icon_names), 75)
        self.assertEqual(detail_names, icon_names)


if __name__ == "__main__":
    unittest.main()
