from __future__ import annotations

import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QRect
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication

from gui.ui_scale import UIScaleContext, aspect_ratio_from_size, fit_size_to_aspect
from gui.viewer_app_qt import StudentViewerWindow
from gui.viewer_shared import _window_frame_for_screen_area


class UIScaleContextTests(unittest.TestCase):
    def test_scale_is_continuous_around_the_old_small_window_threshold(self) -> None:
        below = UIScaleContext.from_size(1630, 917).scale
        above = UIScaleContext.from_size(1632, 918).scale
        self.assertLess(abs(above - below), 0.01)

    def test_common_window_sizes_keep_geometry_and_font_on_one_scale(self) -> None:
        for width, height, expected in (
            (1920, 1080, 1.0),
            (1600, 900, 5 / 6),
            (1280, 720, 2 / 3),
            (960, 540, 0.5),
        ):
            context = UIScaleContext.from_size(width, height)
            self.assertAlmostEqual(context.scale, expected, places=3)
            self.assertAlmostEqual(context.font_point_size, 11.0 * expected, places=3)

    def test_nearest_aspect_size_preserves_one_dragged_dimension(self) -> None:
        self.assertEqual(fit_size_to_aspect(1280, 700), (1280, 720))
        self.assertEqual(fit_size_to_aspect(1200, 720), (1200, 675))

    def test_monitor_aspect_is_derived_from_its_screen_geometry(self) -> None:
        aspect = aspect_ratio_from_size(1600, 1000)
        self.assertAlmostEqual(aspect, 1.6)
        self.assertEqual(fit_size_to_aspect(1280, 700, aspect), (1280, 800))

    def test_available_area_is_fitted_to_the_monitor_aspect(self) -> None:
        fitted = _window_frame_for_screen_area(
            QRect(0, 0, 1600, 1000),
            QRect(0, 0, 1600, 960),
        )
        self.assertEqual(fitted, QRect(32, 0, 1536, 960))


class ViewerResizeScaleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_design_viewer_rebuilds_from_memory_at_new_aspect_size(self) -> None:
        screen_geometry = QRect(0, 0, 1920, 1080)
        window = StudentViewerWindow(
            0.5,
            startup_geometry=screen_geometry,
            startup_screen_geometry=screen_geometry,
            design_mode=True,
        )
        students = window._all_students
        old_root = window.centralWidget()
        window.show()
        self.app.processEvents()
        window.setMinimumSize(1, 1)
        window.resize(1280, 700)
        QTest.qWait(260)
        self.app.processEvents()
        self.assertEqual(window.size().width(), 1280)
        self.assertEqual(window.size().height(), 720)
        self.assertAlmostEqual(window._ui_scale, 2 / 3, places=3)
        self.assertAlmostEqual(window.font().pointSizeF(), 11.0 * (2 / 3), places=2)
        self.assertIs(window._all_students, students)
        self.assertIsNot(window.centralWidget(), old_root)
        window.close()
        window.deleteLater()
        self.app.processEvents()

    def test_design_viewer_keeps_the_startup_monitor_aspect(self) -> None:
        screen_geometry = QRect(0, 0, 1600, 1000)
        window = StudentViewerWindow(
            0.8,
            startup_geometry=screen_geometry,
            startup_screen_geometry=screen_geometry,
            design_mode=True,
        )
        window.show()
        self.app.processEvents()
        window.setMinimumSize(1, 1)
        window.resize(1280, 700)
        QTest.qWait(260)
        self.app.processEvents()
        self.assertEqual(window.size().width(), 1280)
        self.assertEqual(window.size().height(), 800)
        self.assertAlmostEqual(window._ui_aspect_ratio, 1.6)
        window.close()
        window.deleteLater()
        self.app.processEvents()


if __name__ == "__main__":
    unittest.main()
