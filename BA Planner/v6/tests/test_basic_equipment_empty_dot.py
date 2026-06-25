from __future__ import annotations

import unittest

from PIL import Image, ImageDraw

from core import student_meta
from core.scanner import EquipSlotFlag, Scanner, StudentEntry


class BasicEquipmentEmptyDotTests(unittest.TestCase):
    def _scanner(self) -> Scanner:
        scanner = Scanner.__new__(Scanner)
        scanner.r = {
            "student": {
                "basic_equipment_2_empty_dot_region": {
                    "x1": 0.10,
                    "y1": 0.10,
                    "x2": 0.30,
                    "y2": 0.30,
                },
                "basic_favorite_empty_dot_region": {
                    "x1": 0.40,
                    "y1": 0.10,
                    "x2": 0.60,
                    "y2": 0.30,
                },
            }
        }
        scanner._info = lambda _message: None
        scanner._on_progress = None
        scanner._status = lambda *_args, **_kwargs: None
        return scanner

    def test_uses_configured_region_for_equipment_empty_dot(self) -> None:
        scanner = self._scanner()
        image = Image.new("RGB", (100, 100), "white")
        draw = ImageDraw.Draw(image)
        draw.rectangle((12, 12, 24, 24), fill=(255, 185, 24))

        self.assertTrue(scanner._basic_equipment_empty_dot_present(image, 2))
        self.assertFalse(scanner._basic_equipment_empty_dot_present(image, 1))

    def test_uses_configured_region_for_favorite_empty_dot(self) -> None:
        scanner = self._scanner()
        image = Image.new("RGB", (100, 100), "white")
        draw = ImageDraw.Draw(image)
        draw.rectangle((42, 12, 54, 24), fill=(255, 185, 24))

        self.assertTrue(scanner._basic_equipment_empty_dot_present(image, 4))

    def test_basic_hints_skip_any_empty_equipment_slot(self) -> None:
        scanner = self._scanner()
        image = Image.new("RGB", (100, 100), "white")
        draw = ImageDraw.Draw(image)
        draw.rectangle((12, 12, 24, 24), fill=(255, 185, 24))
        entry = StudentEntry(student_id="hoshino", display_name="Hoshino")
        slots = {2}

        scanner._apply_basic_equipment_hints(
            entry,
            image,
            slots,
            include_favorite=False,
            growth_button_active=True,
        )

        self.assertEqual(entry.equip2, EquipSlotFlag.EMPTY.value)
        self.assertIsNone(entry.equip2_level)
        self.assertEqual(set(), slots)
        self.assertEqual("basic_empty_dot", entry.meta_summary()["equip2"]["note"])

    def test_favorite_item_support_comes_from_metadata(self) -> None:
        self.assertTrue(student_meta.favorite_item_enabled("hoshino"))
        self.assertFalse(student_meta.favorite_item_enabled("ayane"))


if __name__ == "__main__":
    unittest.main()