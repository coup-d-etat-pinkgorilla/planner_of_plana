from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image

from core.matcher import (
    _BASIC_EQUIPMENT_CARD_X,
    _BASIC_EQUIPMENT_TEXT_X,
    _basic_equipment_template_card,
    _render_basic_equipment_level_text,
    read_basic_equipment_generated_level_result,
)


ROOT = Path(__file__).resolve().parents[1]
REGIONS = json.loads((ROOT / "regions" / "student_normal_info_regions.json").read_text(encoding="utf-8-sig"))


class BasicEquipmentGeneratedLevelTests(unittest.TestCase):
    def _synthetic_basic_screen(self, *, slot: int, family: str, tier: int, level: int) -> Image.Image:
        icon_region = REGIONS[f"basic_equipment_{slot}_icon_region"]
        geometry = icon_region.get("template_geometry") or {}
        card = _basic_equipment_template_card(
            family,
            tier,
            background_relpath=str(icon_region.get("template_background") or "icons/temp/square.png"),
            icon_width_ratio=float(geometry.get("icon_width_ratio", 0.995)),
            icon_height_ratio=float(geometry.get("icon_height_ratio", 0.98125)),
            icon_offset_x_ratio=float(geometry.get("icon_offset_x_ratio", 0.0)),
            icon_offset_y_ratio=float(geometry.get("icon_offset_y_ratio", 0.0)),
        )
        self.assertIsNotNone(card)
        card.alpha_composite(
            _render_basic_equipment_level_text(level),
            dest=(_BASIC_EQUIPMENT_TEXT_X[slot] - _BASIC_EQUIPMENT_CARD_X[slot], 6),
        )
        image = Image.new("RGB", (2560, 1440), "black")
        image.paste(card.convert("RGB"), (_BASIC_EQUIPMENT_CARD_X[slot], 1114))
        return image

    def test_reads_two_digit_level_with_position_templates(self) -> None:
        image = self._synthetic_basic_screen(slot=1, family="Shoes", tier=9, level=63)
        result = read_basic_equipment_generated_level_result(
            image,
            REGIONS["basic_equipment_1_level_digits_quad"],
            1,
            "Shoes",
            "T9",
            REGIONS["basic_equipment_1_icon_region"],
        )
        self.assertEqual(result.value, 63)
        self.assertFalse(result.uncertain)
        self.assertIn("pos1=6", result.label)
        self.assertIn("pos2=3", result.label)

    def test_reads_single_digit_level_with_blank_second_cell(self) -> None:
        image = self._synthetic_basic_screen(slot=1, family="Shoes", tier=1, level=9)
        result = read_basic_equipment_generated_level_result(
            image,
            REGIONS["basic_equipment_1_level_digits_quad"],
            1,
            "Shoes",
            "T1",
            REGIONS["basic_equipment_1_icon_region"],
        )
        self.assertEqual(result.value, 9)
        self.assertFalse(result.uncertain)
        self.assertIn("pos1=9", result.label)
        self.assertIn("pos2=blank", result.label)


if __name__ == "__main__":
    unittest.main()