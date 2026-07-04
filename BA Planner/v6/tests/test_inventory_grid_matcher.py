from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from core.config import TEMPLATE_DIR
from core.inventory_grid_matcher import DEFAULT_GRID_TEMPLATE, InventoryGridRowAnchorState, _background_for_item, match_inventory_grid_template
from core.scanner import (
    InventoryMotionEstimate,
    _inventory_overlap_rows_from_motion,
    _inventory_scroll_debug_dir,
    _inventory_anchor_scan_order,
    _carried_inventory_anchor_indices,
    _inventory_template_catalog,
    _new_inventory_slot_indices,
)


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

    def test_present_profile_background_rules_use_t2_default_and_t3_for_ssr(self) -> None:
        config = {
            "background": "icons/temp/square_yellow.png",
            "background_rules": [
                {"contains": "SSR", "background": "icons/temp/square_purple.png"},
            ],
        }

        self.assertEqual(_background_for_item("Item_Icon_Favor_0", config).name, "square_yellow.png")
        self.assertEqual(_background_for_item("Item_Icon_Favor_SSR_GL_20", config).name, "square_purple.png")

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



    def test_row_anchor_uses_open_profile_range_after_previous_anchor(self) -> None:
        ordered = [f"item_{idx}" for idx in range(12)]
        state = InventoryGridRowAnchorState(grid_cols=5)

        self.assertTrue(state.record_confirmed(0, 1))
        candidates = state.candidate_item_ids_for_slot(4, ordered)

        self.assertEqual(candidates, ordered[2:])
        self.assertIn("item_8", candidates)

    def test_row_anchor_uses_only_values_between_confirmed_anchors(self) -> None:
        ordered = [f"item_{idx}" for idx in range(12)]
        state = InventoryGridRowAnchorState(grid_cols=5)

        self.assertTrue(state.record_confirmed(0, 1))
        self.assertTrue(state.record_confirmed(4, 7))
        candidates = state.candidate_item_ids_for_slot(2, ordered)

        self.assertEqual(candidates, ordered[3:6])
        self.assertNotIn("item_1", candidates)
        self.assertNotIn("item_7", candidates)

    def test_row_anchor_applies_present_folder_order_after_confirmed_slot(self) -> None:
        ordered = [
            "Item_Icon_Favor_8",
            "Item_Icon_Favor_9",
            "Item_Icon_Favor_10",
            "Item_Icon_Favor_11",
            "Item_Icon_Favor_12",
        ]
        state = InventoryGridRowAnchorState(grid_cols=5)

        self.assertTrue(state.record_confirmed(0, 1))
        candidates = state.candidate_item_ids_for_slot(1, ordered)

        self.assertEqual(candidates, ordered[2:])
        self.assertNotIn("Item_Icon_Favor_8", candidates)
        self.assertNotIn("Item_Icon_Favor_9", candidates)


    def test_row_anchor_exact_gap_returns_single_ordered_candidate(self) -> None:
        ordered = [f"item_{idx}" for idx in range(12)]
        state = InventoryGridRowAnchorState(grid_cols=5)

        self.assertTrue(state.record_confirmed(0, 1))
        self.assertTrue(state.record_confirmed(4, 5))

        self.assertEqual(state.exact_profile_index_for_slot(2), 3)
        self.assertEqual(state.candidate_item_ids_for_slot(2, ordered), ["item_3"])

    def test_anchor_gap_limits_candidates_by_slot_position_when_items_are_missing(self) -> None:
        ordered = [f"item_{idx}" for idx in range(12)]
        state = InventoryGridRowAnchorState(grid_cols=5)

        self.assertTrue(state.record_confirmed(0, 0))
        self.assertTrue(state.record_confirmed(5, 6))

        self.assertEqual(state.candidate_item_ids_for_slot(1, ordered), ["item_1", "item_2"])
        self.assertEqual(state.candidate_item_ids_for_slot(2, ordered), ["item_2", "item_3"])
        self.assertEqual(state.candidate_item_ids_for_slot(3, ordered), ["item_3", "item_4"])
        self.assertEqual(state.candidate_item_ids_for_slot(4, ordered), ["item_4", "item_5"])

    def test_right_edge_anchor_limits_candidates_before_anchor_by_position(self) -> None:
        ordered = [f"item_{idx}" for idx in range(12)]
        state = InventoryGridRowAnchorState(grid_cols=5)

        self.assertTrue(state.record_confirmed(4, 5))

        self.assertEqual(state.candidate_item_ids_for_slot(0, ordered), ["item_0", "item_1"])
        self.assertEqual(state.candidate_item_ids_for_slot(1, ordered), ["item_1", "item_2"])
        self.assertEqual(state.candidate_item_ids_for_slot(2, ordered), ["item_2", "item_3"])
        self.assertEqual(state.candidate_item_ids_for_slot(3, ordered), ["item_3", "item_4"])

    def test_non_anchor_confirmation_does_not_split_anchor_range(self) -> None:
        ordered = [f"item_{idx}" for idx in range(12)]
        state = InventoryGridRowAnchorState(grid_cols=5)

        self.assertTrue(state.record_confirmed(0, 1))
        self.assertFalse(state.record_confirmed(2, 3, as_anchor=False))
        self.assertTrue(state.record_confirmed(4, 7))

        self.assertEqual(state.anchor_profile_indices(), {0: 1, 4: 7})
        self.assertEqual(state.surrounding_anchors(3), ((0, 1), (4, 7)))
        self.assertEqual(state.candidate_item_ids_for_slot(3, ordered), ["item_4", "item_5", "item_6"])

    def test_row_anchor_sparse_gap_does_not_constrain_candidates(self) -> None:
        ordered = [f"item_{idx}" for idx in range(12)]
        state = InventoryGridRowAnchorState(grid_cols=5)

        self.assertTrue(state.record_confirmed(0, 1))
        self.assertTrue(state.record_confirmed(4, 3))

        self.assertTrue(state.has_sparse_anchor_gap(2))
        self.assertIsNone(state.candidate_item_ids_for_slot(2, ordered))


class InventoryAnchorScanOrderTests(unittest.TestCase):
    def test_anchor_scan_order_checks_right_edge_anchor_then_same_row(self) -> None:
        self.assertEqual(
            _inventory_anchor_scan_order(20, grid_cols=5, grid_rows=4),
            [4, 0, 1, 2, 3, 9, 5, 6, 7, 8, 14, 10, 11, 12, 13, 19, 15, 16, 17, 18],
        )

    def test_anchor_scan_order_respects_row_step_scan_subset(self) -> None:
        self.assertEqual(
            _inventory_anchor_scan_order(20, grid_cols=5, grid_rows=4, scan_indices={15, 16, 17, 18, 19}),
            [19, 15, 16, 17, 18],
        )

class InventoryCarriedAnchorTests(unittest.TestCase):
    def test_carries_confirmed_bottom_overlap_rows_to_next_page_top(self) -> None:
        confirmed = {0: 10, 5: 15, 10: 20, 15: 25, 16: 26, 19: 29}

        self.assertEqual(
            _carried_inventory_anchor_indices(confirmed, total_slots=20, grid_cols=5, grid_rows=4, overlap_rows=1),
            {0: 25, 1: 26, 4: 29},
        )

    def test_carries_multiple_overlap_rows_preserving_slot_offsets(self) -> None:
        confirmed = {4: 14, 5: 15, 9: 19, 10: 20, 15: 25, 19: 29}

        self.assertEqual(
            _carried_inventory_anchor_indices(confirmed, total_slots=20, grid_cols=5, grid_rows=4, overlap_rows=3),
            {0: 15, 4: 19, 5: 20, 10: 25, 14: 29},
        )

class InventoryScrollDebugDirTests(unittest.TestCase):
    def test_equipment_scan_uses_inventory_scroll_debug_folder(self) -> None:
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch("core.scanner.BASE_DIR", Path(tmp)),
            patch("core.scanner.time.strftime", return_value="20260704_120000"),
            patch.dict("core.scanner.os.environ", {"BA_INVENTORY_SCROLL_DEBUG": "1"}),
        ):
            path = _inventory_scroll_debug_dir("equipment", "equipment")

            self.assertIsNotNone(path)
            assert path is not None
            self.assertTrue(path.is_dir())
            self.assertEqual(path.name, "20260704_120000_equipment_equipment")
            self.assertEqual(path.parent.name, "inventory_scroll_scan")


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

    def test_motion_overlap_clamps_large_normal_residual_by_default(self) -> None:
        motion = InventoryMotionEstimate(606, 582, 24, 0.89, 1, 890)
        self.assertEqual(_inventory_overlap_rows_from_motion(motion, 202, 4), (1, 3, 0, False))

    def test_motion_overlap_can_carry_confirmed_normal_residual(self) -> None:
        motion = InventoryMotionEstimate(606, 582, 24, 0.89, 1, 890)
        self.assertEqual(
            _inventory_overlap_rows_from_motion(motion, 202, 4, carry_normal_offset=True),
            (1, 3, 24, False),
        )
    def test_motion_overlap_reports_roi_offset_for_under_scroll(self) -> None:
        motion = InventoryMotionEstimate(202, 186, 16, 0.90, 150, 250)
        self.assertEqual(_inventory_overlap_rows_from_motion(motion, 202, 4), (3, 1, 16, True))

    def test_motion_overlap_rejects_near_zero_tail_scroll(self) -> None:
        motion = InventoryMotionEstimate(609, 1, 608, 0.86, 1, 890)
        self.assertIsNone(_inventory_overlap_rows_from_motion(motion, 203, 4))

    def test_falls_back_to_full_page_when_overlap_is_unknown(self) -> None:
        self.assertIsNone(
            _new_inventory_slot_indices(20, grid_cols=5, grid_rows=4, overlap_rows=0)
        )


if __name__ == "__main__":
    unittest.main()
