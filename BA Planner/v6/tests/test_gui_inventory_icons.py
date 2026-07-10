from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PIL import Image, ImageDraw
from PySide6.QtCore import QSize
from PySide6.QtWidgets import QApplication

from gui import viewer_app_qt as viewer
from gui.viewer_app_qt import _inventory_icon_path, _item_icon_background_path


def _ensure_qapplication() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app


class GuiInventoryIconTests(unittest.TestCase):
    def test_present_icon_uses_present_template_directory(self) -> None:
        path = _inventory_icon_path("Item_Icon_Favor_0", None)

        self.assertIsNotNone(path)
        assert path is not None
        self.assertTrue(path.exists())
        self.assertEqual(path.name, "Item_Icon_Favor_0.png")
        self.assertIn("presents", path.parts)

    def test_inventory_classifies_elephs_and_presents_into_dedicated_tabs(self) -> None:
        classify = viewer.StudentViewerWindow._inventory_classify_item

        self.assertEqual(
            classify(object(), "Item_Icon_SecretStone_aru", {"item_id": "Item_Icon_SecretStone_aru"}),
            "elephs",
        )
        self.assertEqual(
            classify(object(), "Item_Icon_Favor_0", {"item_id": "Item_Icon_Favor_0"}),
            "presents",
        )
        self.assertEqual(
            classify(object(), "Item_Icon_Favor_20", {"quantity": 1}),
            "presents",
        )

    def test_t3_present_uses_existing_t3_background(self) -> None:
        background = _item_icon_background_path("Item_Icon_Favor_SSR_GL_20")

        self.assertIsNotNone(background)
        assert background is not None
        self.assertEqual(background.name, "square_purple.png")

    def test_non_ssr_present_uses_existing_t2_background(self) -> None:
        background = _item_icon_background_path("Item_Icon_Favor_20")

        self.assertIsNotNone(background)
        assert background is not None
        self.assertEqual(background.name, "square_yellow.png")

    def test_lv2_present_uses_existing_t3_background(self) -> None:
        background = _item_icon_background_path("Item_Icon_Favor_Lv2_10")

        self.assertIsNotNone(background)
        assert background is not None
        self.assertEqual(background.name, "square_purple.png")

    def test_planner_item_pixmap_uses_present_background_rules(self) -> None:
        _ensure_qapplication()
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            t2_bg = tmp / "t2.png"
            t3_bg = tmp / "t3.png"
            icon = tmp / "icon.png"
            Image.new("RGBA", (64, 64), (12, 34, 56, 255)).save(t2_bg)
            Image.new("RGBA", (64, 64), (210, 45, 90, 255)).save(t3_bg)
            icon_image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            ImageDraw.Draw(icon_image).rectangle((24, 24, 40, 40), fill=(255, 255, 255, 255))
            icon_image.save(icon)

            with (
                patch.object(viewer, "ITEM_ICON_BACKGROUND_YELLOW", t2_bg),
                patch.object(viewer, "ITEM_ICON_BACKGROUND_PURPLE", t3_bg),
            ):
                normal = viewer._item_icon_pixmap(
                    size=QSize(64, 64),
                    item_id="Item_Icon_Favor_20",
                    icon_path=icon,
                )
                lv2 = viewer._item_icon_pixmap(
                    size=QSize(64, 64),
                    item_id="Item_Icon_Favor_Lv2_10",
                    icon_path=icon,
                )

        self.assertEqual(normal.toImage().pixelColor(2, 2).getRgb()[:3], (12, 34, 56))
        self.assertEqual(lv2.toImage().pixelColor(2, 2).getRgb()[:3], (210, 45, 90))

    def test_scan_mirroring_fallback_uses_t3_background_for_lv2(self) -> None:
        _ensure_qapplication()
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            t2_bg = tmp / "t2.png"
            t3_bg = tmp / "t3.png"
            Image.new("RGBA", (64, 64), (20, 40, 60, 255)).save(t2_bg)
            Image.new("RGBA", (64, 64), (180, 70, 30, 255)).save(t3_bg)

            with (
                patch.object(viewer, "ITEM_ICON_BACKGROUND_YELLOW", t2_bg),
                patch.object(viewer, "ITEM_ICON_BACKGROUND_PURPLE", t3_bg),
                patch.object(viewer, "_inventory_icon_path", return_value=None),
            ):
                pixmap = viewer._scan_inventory_slot_pixmap(
                    size=QSize(64, 64),
                    item_id="Item_Icon_Favor_Lv2_10",
                    item_name=None,
                )

        self.assertEqual(pixmap.toImage().pixelColor(2, 2).getRgb()[:3], (180, 70, 30))


if __name__ == "__main__":
    unittest.main()