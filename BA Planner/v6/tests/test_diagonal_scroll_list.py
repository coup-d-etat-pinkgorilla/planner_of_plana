from __future__ import annotations

import os
import math
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import Qt
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication, QLabel

from gui.diagonal_scroll_list import DiagonalScrollList


class DiagonalScrollListTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def _build_list(self, *, edge: str = "left", mode: str = "extend") -> DiagonalScrollList:
        widget = DiagonalScrollList(
            edge=edge,
            mode=mode,
            angle_degrees=80.0,
            maximum_depth=30,
            radius=7,
            row_height=54,
            row_gap=5,
            content_padding=6,
        )
        widget.resize(420, 260)
        for index in range(18):
            widget.addDiagonalWidget(
                QLabel(f"candidate {index}"),
                data=index,
                accessible_text=f"candidate {index}",
            )
        widget.show()
        self.app.processEvents()
        widget.refreshDiagonalGeometry()
        self.app.processEvents()
        return widget

    def test_rows_follow_viewport_y_while_vertical_scroll_model_is_preserved(self) -> None:
        widget = self._build_list()
        item = widget.item(3)
        host = widget.diagonalHost(item)
        self.assertIsNotNone(host)
        depth_before = (host._top_depth, host._bottom_depth)
        content_left_before = host._content.geometry().left()

        widget.verticalScrollBar().setValue(min(widget.verticalScrollBar().maximum(), 4))
        self.app.processEvents()
        depth_after = (host._top_depth, host._bottom_depth)

        self.assertNotEqual(depth_before, depth_after)
        self.assertEqual(host._content.geometry().left(), content_left_before)
        self.assertEqual(content_left_before, 36)
        self.assertGreater(widget.verticalScrollBar().maximum(), 0)
        widget.deleteLater()

    def test_cut_mode_reserves_safe_content_space(self) -> None:
        widget = self._build_list(edge="left", mode="cut")
        host = widget.diagonalHost(widget.item(0))
        self.assertIsNotNone(host)
        self.assertEqual(host._content.geometry().left(), 36)
        self.assertGreaterEqual(host._content.geometry().right(), host._content.geometry().left())
        widget.deleteLater()

    def test_right_diagonal_handle_tracks_boundary_and_drag_maps_scroll_range(self) -> None:
        widget = self._build_list(edge="right", mode="cut")
        handle = widget._handle
        self.assertTrue(handle.isVisible())
        self.assertNotAlmostEqual(handle._top_boundary_x, handle._bottom_boundary_x, delta=0.1)

        handle.setScrollFromY(widget.height())
        self.app.processEvents()
        self.assertEqual(widget.verticalScrollBar().value(), widget.verticalScrollBar().maximum())
        bottom_y = handle.y()

        handle.setScrollFromY(0)
        self.app.processEvents()
        self.assertEqual(widget.verticalScrollBar().value(), widget.verticalScrollBar().minimum())
        self.assertLess(handle.y(), bottom_y)
        widget.deleteLater()

    def test_keyboard_selection_remains_native(self) -> None:
        widget = self._build_list()
        widget.setCurrentRow(0)
        widget.setFocus()
        QTest.keyClick(widget, Qt.Key_Down)
        self.assertEqual(widget.currentRow(), 1)
        self.assertEqual(widget.currentItem().data(Qt.UserRole), 1)
        widget.deleteLater()

    def test_rows_show_button_like_hover_and_press_feedback(self) -> None:
        widget = self._build_list()
        first_item = widget.item(0)
        second_item = widget.item(1)
        first_host = widget.diagonalHost(first_item)
        second_host = widget.diagonalHost(second_item)
        first_center = widget.visualItemRect(first_item).center()
        second_center = widget.visualItemRect(second_item).center()

        QTest.mouseMove(widget.viewport(), first_center)
        self.app.processEvents()
        self.assertTrue(first_host._hovered)
        self.assertFalse(second_host._hovered)

        QTest.mousePress(widget.viewport(), Qt.LeftButton, pos=first_center)
        self.app.processEvents()
        self.assertTrue(first_host._pressed)
        QTest.mouseRelease(widget.viewport(), Qt.LeftButton, pos=first_center)
        self.app.processEvents()
        self.assertFalse(first_host._pressed)

        QTest.mouseMove(widget.viewport(), second_center)
        self.app.processEvents()
        self.assertFalse(first_host._hovered)
        self.assertTrue(second_host._hovered)
        widget.deleteLater()

    def test_locked_angle_uses_natural_depth_instead_of_maximum_depth_cap(self) -> None:
        widget = DiagonalScrollList(
            edge="left",
            mode="extend",
            angle_degrees=80.0,
            maximum_depth=24,
            lock_angle=True,
            radius=7,
            row_height=54,
            row_gap=5,
            content_padding=6,
        )
        widget.resize(420, 288)
        widget.addDiagonalWidget(QLabel("candidate"))
        widget.show()
        self.app.processEvents()

        viewport_height = float(widget.viewport().height())
        full_depth = widget.depthAtY(viewport_height)
        actual_angle = math.degrees(math.atan2(viewport_height, full_depth))
        self.assertAlmostEqual(actual_angle, 80.0, places=6)
        self.assertGreater(widget.gutterDepth(), widget._maximum_depth)

        widget.deleteLater()

    def test_bilateral_rows_extend_left_and_cut_right_with_safe_content(self) -> None:
        widget = DiagonalScrollList(
            edge="left",
            mode="extend",
            opposite_mode="cut",
            angle_degrees=80.0,
            maximum_depth=24,
            lock_angle=True,
            radius=7,
            row_height=90,
            row_gap=5,
            content_padding=6,
        )
        widget.resize(420, 288)
        item = widget.addDiagonalWidget(QLabel("settings"), row_height=108)
        widget.show()
        self.app.processEvents()
        widget.refreshDiagonalGeometry()
        self.app.processEvents()

        host = widget.diagonalHost(item)
        self.assertIsNotNone(host)
        top_left, top_right, bottom_right, bottom_left = host._surface_points()
        self.assertGreater(top_left[0], bottom_left[0])
        self.assertGreater(top_right[0], bottom_right[0])
        self.assertEqual(item.sizeHint().height(), 108)
        self.assertEqual(host._content.geometry().left(), widget.gutterDepth() + 6)
        self.assertLess(host._content.geometry().right(), host.width() - 6)
        widget.deleteLater()


if __name__ == "__main__":
    unittest.main()
