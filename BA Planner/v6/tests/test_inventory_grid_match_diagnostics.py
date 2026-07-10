from __future__ import annotations

import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from core.inventory_grid_matcher import (
    DEFAULT_GRID_TEMPLATE,
    inspect_inventory_grid_tier_color,
    match_inventory_grid_template,
    prepare_inventory_grid_comparison,
)
from core.scanner import inventory_profile_template_catalog


ROOT = Path(__file__).resolve().parents[1]


class InventoryGridMatchDiagnosticsTests(unittest.TestCase):
    def _slot(self, icon_path: Path, background: str = "icons/temp/square.png") -> Image.Image:
        size = (234, 190)
        image = Image.new("RGBA", size)
        for path, geometry in (
            (ROOT / "templates" / background, DEFAULT_GRID_TEMPLATE["background_geometry"]),
            (icon_path, DEFAULT_GRID_TEMPLATE["icon_geometry"]),
        ):
            layer = Image.open(path).convert("RGBA").resize(
                (
                    round(size[0] * float(geometry["width_ratio"])),
                    round(size[1] * float(geometry["height_ratio"])),
                ),
                Image.Resampling.LANCZOS,
            )
            image.alpha_composite(
                layer,
                (
                    round(size[0] * float(geometry["offset_x_ratio"])),
                    round(size[1] * float(geometry["offset_y_ratio"])),
                ),
            )
        return image.convert("RGB")

    def test_prepared_comparison_uses_same_score_as_production_match(self) -> None:
        item_id = "Item_Icon_Material_Nebra_0"
        icon = ROOT / "templates" / "icons" / "ooparts" / f"{item_id}.png"
        slot = self._slot(icon)

        prepared = prepare_inventory_grid_comparison(slot, item_id, str(icon), mode="composite")
        result = match_inventory_grid_template(slot, [(item_id, str(icon))])

        self.assertIsNotNone(prepared)
        assert prepared is not None
        self.assertEqual(prepared.screen_image.shape, prepared.template_image.shape)
        self.assertAlmostEqual(result.score, prepared.similarity.combined_score, places=7)
        self.assertTrue(np.array_equal(prepared.screen_image, prepared.template_image))

    def test_color_inspection_reports_exact_selected_sample_box(self) -> None:
        slot = Image.new("RGB", (234, 190), (0, 0, 0))
        ImageDraw.Draw(slot).rectangle((30, 44, 39, 71), fill=(180, 203, 218))

        inspection = inspect_inventory_grid_tier_color(slot)

        self.assertEqual(inspection.tier_hint, 0)
        self.assertIsNotNone(inspection.sample_box)
        self.assertEqual(inspection.median_rgb, (180.0, 203.0, 218.0))
        self.assertAlmostEqual(inspection.distances[0][1], 0.0)

    def test_production_comparison_uses_direct_only_when_direct_match_accepts(self) -> None:
        correct_id = "Item_Icon_SkillBook_Gehenna_3"
        wrong_id = "Item_Icon_SkillBook_Shanhaijing_3"
        correct = ROOT / "templates" / "icons" / "skill_book" / f"{correct_id}.png"
        wrong = ROOT / "templates" / "icons" / "skill_book" / f"{wrong_id}.png"
        slot = self._slot(correct, "icons/temp/square_purple.png")
        catalog = [(wrong_id, str(wrong)), (correct_id, str(correct))]
        config = {
            "direct_icon_match": {
                "enabled": True,
                "screen_crop_ratio": {"left": 0.3547, "right": 0.4103, "top": 0.2632, "bottom": 0.4474},
                "template_crop_ratio": {"left": 0.3480, "right": 0.4097, "top": 0.2541, "bottom": 0.4420},
                "threshold": 0.82,
                "margin": 0.08,
            }
        }

        accepted = prepare_inventory_grid_comparison(
            slot,
            correct_id,
            str(correct),
            config,
            catalog=catalog,
        )
        rejected = prepare_inventory_grid_comparison(
            slot,
            correct_id,
            str(correct),
            {"direct_icon_match": {**config["direct_icon_match"], "threshold": 1.01}},
            catalog=catalog,
        )

        self.assertIsNotNone(accepted)
        self.assertIsNotNone(rejected)
        assert accepted is not None and rejected is not None
        self.assertEqual(accepted.mode, "direct_icon")
        self.assertEqual(rejected.mode, "composite")

    def test_activity_report_catalog_uses_canonical_ids(self) -> None:
        catalog = dict(inventory_profile_template_catalog("item", "activity_reports"))

        self.assertEqual(set(catalog), {f"Item_Icon_ExpItem_{tier}" for tier in range(4)})
        for tier in range(4):
            self.assertTrue(catalog[f"Item_Icon_ExpItem_{tier}"].endswith(f"report_{tier}.png"))


if __name__ == "__main__":
    unittest.main()
