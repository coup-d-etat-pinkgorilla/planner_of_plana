from __future__ import annotations

import unittest
from pathlib import Path

from PIL import Image

from core.config import TEMPLATE_DIR
from core.inventory_grid_matcher import DEFAULT_GRID_TEMPLATE, match_inventory_grid_template
from core.scanner import InventoryMotionEstimate, _inventory_overlap_rows_from_motion, _inventory_template_catalog, _new_inventory_slot_indices


ROOT = Path(__file__).resolve().parents[1]


class InventoryGridMatcherTests(unittest.TestCase):
    def _render_slot(
        self,
        icon_path: Path,
        size: tuple[int, int] = (234, 190),
        background: str | None = None,
    ) -> Image.Image:
        config = DEFAULT_GRID_TEMPLATE
        slot = Image.new("RGBA", size, (0, 0, 0, 0))

        def paste(path: Path, geometry: dict) -> None:
            width, height = size
            layer = Image.open(path).convert("RGBA").resize(
                (
                    max(1, round(width * float(geometry["width_ratio"]))),
                    max(1, round(height * float(geometry["height_ratio"]))),
                ),
                Image.Resampling.LANCZOS,
            )
            slot.alpha_composite(
                layer,
                dest=(
                    round(width * float(geometry["offset_x_ratio"])),
                    round(height * float(geometry["offset_y_ratio"])),
                ),
            )

        paste(TEMPLATE_DIR / (background or config["background"]), config["background_geometry"])
        paste(icon_path, config["icon_geometry"])
        return slot.convert("RGB")

    def test_matches_generated_slot_middle_crop(self) -> None:
        correct = TEMPLATE_DIR / "icons" / "ooparts" / "Item_Icon_Material_Nebra_0.png"
        wrong = TEMPLATE_DIR / "icons" / "ooparts" / "Item_Icon_Material_Antikythera_0.png"
        self.assertTrue(correct.exists())
        self.assertTrue(wrong.exists())

        result = match_inventory_grid_template(
            self._render_slot(correct),
            [
                ("Item_Icon_Material_Antikythera_0", str(wrong)),
                ("Item_Icon_Material_Nebra_0", str(correct)),
            ],
        )

        self.assertEqual(result.item_id, "Item_Icon_Material_Nebra_0")
        self.assertGreaterEqual(result.score, 0.95)
        self.assertGreater(result.margin, 0.02)

    def test_uses_ooparts_tier_background_color(self) -> None:
        correct = TEMPLATE_DIR / "icons" / "ooparts" / "Item_Icon_Material_Nebra_3.png"
        wrong = TEMPLATE_DIR / "icons" / "ooparts" / "Item_Icon_Material_Nebra_0.png"
        self.assertTrue(correct.exists())
        self.assertTrue(wrong.exists())

        result = match_inventory_grid_template(
            self._render_slot(correct, background="icons/temp/square_purple.png"),
            [
                ("Item_Icon_Material_Nebra_0", str(wrong)),
                ("Item_Icon_Material_Nebra_3", str(correct)),
            ],
        )

        self.assertEqual(result.item_id, "Item_Icon_Material_Nebra_3")
        self.assertGreaterEqual(result.score, 0.95)

    def test_equipment_tier_one_uses_item_style_crop(self) -> None:
        icon = TEMPLATE_DIR / "icons" / "equipment" / "Equipment_Icon_Hairpin_Tier1.png"
        self.assertTrue(icon.exists())
        equipment_piece_crop_config = {
            "crop_ratio": {
                "left": 0.2436,
                "right": 0.3205,
                "top": 0.2526,
                "bottom": 0.4368,
            }
        }

        result = match_inventory_grid_template(
            self._render_slot(icon),
            [("Equipment_Icon_Hairpin_Tier1", str(icon))],
            equipment_piece_crop_config,
        )

        self.assertEqual(result.item_id, "Equipment_Icon_Hairpin_Tier1")
        self.assertGreaterEqual(result.score, 0.95)

    def test_equipment_weapon_parts_use_item_style_crop(self) -> None:
        icon = TEMPLATE_DIR / "icons" / "equipment" / "Equipment_Icon_WeaponExpGrowthZ_3.png"
        self.assertTrue(icon.exists())
        equipment_piece_crop_config = {
            "crop_ratio": {
                "left": 0.2436,
                "right": 0.3205,
                "top": 0.2526,
                "bottom": 0.4368,
            }
        }

        result = match_inventory_grid_template(
            self._render_slot(icon, background="icons/temp/square_purple.png"),
            [("Equipment_Icon_WeaponExpGrowthZ_3", str(icon))],
            equipment_piece_crop_config,
        )

        self.assertEqual(result.item_id, "Equipment_Icon_WeaponExpGrowthZ_3")
        self.assertGreaterEqual(result.score, 0.95)

    def test_equipment_grid_catalog_prefers_piece_icons_for_tier_two_to_ten(self) -> None:
        catalog = dict(_inventory_template_catalog("equipment"))

        self.assertTrue(catalog["Equipment_Icon_Hairpin_Tier7"].endswith("Equipment_Icon_Hairpin_Tier7_Piece.png"))
        self.assertTrue(catalog["Equipment_Icon_Hairpin_Tier2"].endswith("Equipment_Icon_Hairpin_Tier2_Piece.png"))
        self.assertTrue(catalog["Equipment_Icon_Hairpin_Tier10"].endswith("Equipment_Icon_Hairpin_Tier10_Piece.png"))
        self.assertTrue(catalog["Equipment_Icon_Hairpin_Tier1"].endswith("Equipment_Icon_Hairpin_Tier1.png"))
        self.assertTrue(catalog["Equipment_Icon_Exp_3"].endswith("Equipment_Icon_Exp_3.png"))
        self.assertTrue(catalog["Equipment_Icon_WeaponExpGrowthZ_3"].endswith("Equipment_Icon_WeaponExpGrowthZ_3.png"))
        self.assertNotIn("Equipment_Icon_Hairpin_Tier7_Piece", catalog)


class InventoryRowStepScrollTests(unittest.TestCase):
    def test_selects_only_new_bottom_row_after_one_row_overlap(self) -> None:
        self.assertEqual(
            _new_inventory_slot_indices(20, grid_cols=5, grid_rows=4, overlap_rows=3),
            {15, 16, 17, 18, 19},
        )

    def test_motion_overlap_supports_three_row_page_scroll(self) -> None:
        motion = InventoryMotionEstimate(
            expected_step_px=606,
            actual_move_px=606,
            y_offset_px=0,
            score=0.95,
            search_min_px=100,
            search_max_px=700,
        )
        self.assertEqual(_inventory_overlap_rows_from_motion(motion, 202, 4), (1, 3, 0, False))

    def test_motion_overlap_supports_partial_final_scrolls(self) -> None:
        two_rows = InventoryMotionEstimate(606, 404, 202, 0.95, 100, 700)
        one_row = InventoryMotionEstimate(606, 202, 404, 0.95, 100, 700)
        self.assertEqual(_inventory_overlap_rows_from_motion(two_rows, 202, 4), (2, 2, 0, True))
        self.assertEqual(_inventory_overlap_rows_from_motion(one_row, 202, 4), (3, 1, 0, True))

    def test_motion_overlap_reports_roi_offset_for_under_scroll(self) -> None:
        motion = InventoryMotionEstimate(202, 186, 16, 0.90, 150, 250)
        self.assertEqual(_inventory_overlap_rows_from_motion(motion, 202, 4), (3, 1, 16, True))

    def test_falls_back_to_full_page_when_overlap_is_unknown(self) -> None:
        self.assertIsNone(
            _new_inventory_slot_indices(20, grid_cols=5, grid_rows=4, overlap_rows=0)
        )


if __name__ == "__main__":
    unittest.main()
