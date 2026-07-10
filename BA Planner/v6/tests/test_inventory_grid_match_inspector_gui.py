from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PIL import Image
from PySide6.QtWidgets import QApplication

from tools.inventory_grid_match_inspector import InspectorWindow


def _app() -> QApplication:
    return QApplication.instance() or QApplication([])


class InventoryGridMatchInspectorGuiTests(unittest.TestCase):
    def test_window_loads_capture_rows_and_nudges_color_box(self) -> None:
        _app()
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            case = root / "item" / "activity_reports" / "captures" / "scroll_01_try_01"
            case.mkdir(parents=True)
            before = case / "before_capture.png"
            after = case / "after_capture.png"
            Image.new("RGB", (2560, 1440), (180, 203, 218)).save(before)
            Image.new("RGB", (2560, 1440), (180, 203, 218)).save(after)
            (case / "summary.json").write_text(
                json.dumps(
                    {
                        "slot_count": 20,
                        "before_capture": str(before),
                        "after_capture": str(after),
                        "new_scan_slot_indices_0_based": list(range(20)),
                    }
                ),
                encoding="utf-8",
            )

            window = InspectorWindow(root)
            initial_x = window.sample_x.value()
            window.nudge_sample(1, 0)

            self.assertEqual(window.profile_combo.currentText(), "activity_reports")
            self.assertEqual(len(window.rows), 20)
            self.assertEqual(window.sample_x.value(), initial_x + 1)
            self.assertEqual(window.rows[0].current_item_id(), "Item_Icon_ExpItem_0")
            window.close()


if __name__ == "__main__":
    unittest.main()

