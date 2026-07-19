from __future__ import annotations

import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QPoint, QPointF, QRectF
from PySide6.QtWidgets import QApplication, QFrame, QVBoxLayout, QWidget

from gui.diagonal_shape import (
    diagonal_shape_path,
    resolved_diagonal_depth,
    validate_diagonal_shapes,
)
from gui.ui_design_runtime import apply_ui_design_spec, object_selector
from gui.ui_design_spec import ComponentOverride, DiagonalShapeSpec, UIDesignSpec


class DiagonalShapeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_fixed_right_cut_removes_the_lower_right_corner(self) -> None:
        shape = DiagonalShapeSpec(
            edge="right",
            direction="forward",
            depth_mode="fixed",
            depth=30,
            radius=0,
        )
        path = diagonal_shape_path(QRectF(0, 0, 200, 100), shape)
        self.assertTrue(path.contains(QPointF(190, 10)))
        self.assertTrue(path.contains(QPointF(20, 80)))
        self.assertFalse(path.contains(QPointF(190, 90)))

    def test_angle_depth_recomputes_from_current_height(self) -> None:
        shape = DiagonalShapeSpec(edge="right", depth_mode="angle", angle_degrees=80.0, radius=7)
        shallow = resolved_diagonal_depth(300, 100, shape)
        deep = resolved_diagonal_depth(300, 200, shape)
        self.assertGreater(deep, shallow)

    def test_extend_mode_reverses_the_edge_wedge_interpretation(self) -> None:
        cut = DiagonalShapeSpec(mode="cut", edge="left", depth_mode="fixed", depth=30, radius=0)
        extend = DiagonalShapeSpec(mode="extend", edge="left", depth_mode="fixed", depth=30, radius=0)
        rect = QRectF(0, 0, 200, 100)
        self.assertFalse(diagonal_shape_path(rect, cut).contains(QPointF(5, 5)))
        self.assertTrue(diagonal_shape_path(rect, extend).contains(QPointF(5, 5)))

    def test_runtime_applies_clip_effect_and_content_safe_margin(self) -> None:
        root = QWidget()
        target = QFrame(root)
        target.setObjectName("target")
        target.setGeometry(0, 0, 240, 120)
        target.setLayout(QVBoxLayout())
        selector = object_selector(target, root)
        shape = DiagonalShapeSpec(
            edge="right",
            depth_mode="fixed",
            depth=30,
            radius=6,
            content_safe_margin=36,
        )
        spec = UIDesignSpec(components={
            selector: ComponentOverride(selector=selector, diagonal_shape=shape),
        })
        apply_ui_design_spec(root, spec)
        self.assertFalse(target.mask().isEmpty())
        self.assertGreaterEqual(target.layout().contentsMargins().right(), 36)
        root.deleteLater()
        self.app.processEvents()

    def test_runtime_mask_excludes_the_cut_corner(self) -> None:
        root = QWidget()
        root.resize(220, 120)
        target = QFrame(root)
        target.setObjectName("target")
        target.setGeometry(10, 10, 200, 100)
        target.setStyleSheet("background: #ff0000; border: none;")
        selector = object_selector(target, root)
        shape = DiagonalShapeSpec(edge="right", depth_mode="fixed", depth=40, radius=0)
        apply_ui_design_spec(root, UIDesignSpec(components={
            selector: ComponentOverride(selector=selector, diagonal_shape=shape),
        }))
        root.show()
        self.app.processEvents()
        self.assertTrue(target.mask().contains(QPoint(185, 10)))
        self.assertFalse(target.mask().contains(QPoint(185, 90)))
        root.close()
        root.deleteLater()
        self.app.processEvents()

    def test_validator_reports_unsafe_margin_and_conflicting_seam(self) -> None:
        root = QWidget()
        target = QFrame(root)
        target.setObjectName("target")
        target.setGeometry(0, 0, 240, 120)
        selector = object_selector(target, root)
        shape = DiagonalShapeSpec(
            edge="right",
            depth_mode="fixed",
            depth=40,
            radius=6,
            content_safe_margin=8,
            seam_gap=2,
            overlap=1,
        )
        spec = UIDesignSpec(components={
            selector: ComponentOverride(selector=selector, diagonal_shape=shape),
        })
        issues = validate_diagonal_shapes(root, spec)
        self.assertIn("safe_margin", {issue.code for issue in issues})
        self.assertIn("seam", {issue.code for issue in issues})
        root.deleteLater()


if __name__ == "__main__":
    unittest.main()
