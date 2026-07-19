from __future__ import annotations

import os
from pathlib import Path
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtWidgets import QApplication, QCheckBox, QComboBox, QHBoxLayout, QLabel, QLineEdit, QWidget

from gui.ui_design_runtime import (
    apply_ui_design_spec,
    capture_transient_widget_state,
    object_selector,
    resolve_widget_selector,
    restore_transient_widget_state,
    widget_index,
)
from gui.ui_design_spec import (
    AnimationSpec,
    ComponentOverride,
    DiagonalShapeSpec,
    GalleryStyleSpec,
    NewWidgetSpec,
    UIDesignSpec,
    load_ui_design_spec,
    save_ui_design_spec,
)


class UIDesignSpecTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_spec_round_trip_preserves_v2_gallery_and_legacy_data(self) -> None:
        spec = UIDesignSpec()
        spec.palette["accent"] = "#123456"
        spec.gallery_styles["type:QPushButton"] = GalleryStyleSpec(
            "type:QPushButton", "Button", "QPushButton", "color: #123456;"
        )
        spec.components["QWidget/QLabel#title"] = ComponentOverride(
            selector="QWidget/QLabel#title",
            fixed_size=[240, 60],
            diagonal_shape=DiagonalShapeSpec(edge="right", angle_degrees=78.0),
        )
        spec.components["qml/overlays/dialog"] = ComponentOverride(
            selector="qml/overlays/dialog",
            qml_surface="panelAlt",
            qml_border_surface="accent",
            qml_scrim_surface="backgroundDeep",
            qml_scrim_opacity=0.5,
        )
        spec.components["qml/delegates/student-card"] = ComponentOverride(
            selector="qml/delegates/student-card",
            qml_alternate_surface="panelRaised",
            qml_selected_surface="surfaceSelected",
            qml_selected_border_surface="accent",
        )
        spec.components["qml/elements/student-status-badge"] = ComponentOverride(
            selector="qml/elements/student-status-badge",
            qml_surface="backgroundDeep",
            qml_opacity=0.78,
        )
        spec.new_widgets.append(NewWidgetSpec("new-1", "QWidget", "QLabel", "studioLabel"))
        spec.animations.append(AnimationSpec("anim-1", "QWidget/QLabel#title"))
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui.json"
            save_ui_design_spec(spec, path)
            loaded = load_ui_design_spec(path)
        self.assertEqual(loaded.version, 2)
        self.assertEqual(loaded.gallery_styles["type:QPushButton"].style_sheet, "color: #123456;")
        self.assertEqual(loaded.components["QWidget/QLabel#title"].fixed_size, [240, 60])
        self.assertEqual(loaded.components["qml/overlays/dialog"].qml_surface, "panelAlt")
        self.assertEqual(loaded.components["qml/overlays/dialog"].qml_scrim_opacity, 0.5)
        self.assertEqual(loaded.components["qml/delegates/student-card"].qml_selected_surface, "surfaceSelected")
        self.assertEqual(loaded.components["qml/delegates/student-card"].qml_selected_border_surface, "accent")
        self.assertEqual(loaded.components["qml/elements/student-status-badge"].qml_opacity, 0.78)
        self.assertEqual(loaded.animations[0].animation_id, "anim-1")

    def test_runtime_applies_only_visual_fields(self) -> None:
        root = QWidget(); root.setObjectName("root")
        title = QLabel("title", root); title.setObjectName("title")
        selector = object_selector(title, root)
        original_size = title.size()
        spec = UIDesignSpec(
            components={selector: ComponentOverride(
                selector, fixed_size=[222, 55], enabled=False, style_sheet="color: #123456;"
            )},
            new_widgets=[NewWidgetSpec("new-2", object_selector(root, root), "QLabel", "studioLabel")],
            animations=[AnimationSpec("show-1", selector, trigger="on_show")],
        )
        index = apply_ui_design_spec(root, spec, play_animations=True)
        self.assertEqual(title.size(), original_size)
        self.assertTrue(title.isEnabled())
        self.assertIn("#123456", title.styleSheet())
        self.assertIsNone(root.findChild(QLabel, "studioLabel"))
        self.assertFalse(hasattr(root, "_ui_design_animations"))
        self.assertEqual(index[selector], title)

    def test_legacy_geometry_never_detaches_widget_from_layout(self) -> None:
        root = QWidget(); layout = QHBoxLayout(root)
        target = QLabel("target"); sibling = QLabel("sibling")
        layout.addWidget(target); layout.addWidget(sibling)
        root.resize(500, 120); root.show(); self.app.processEvents()
        sibling_before = sibling.geometry()
        selector = object_selector(target, root)
        apply_ui_design_spec(root, UIDesignSpec(components={
            selector: ComponentOverride(selector, geometry=[73, 41, 180, 64])
        }))
        self.app.processEvents()
        self.assertNotEqual(list(target.geometry().getRect()), [73, 41, 180, 64])
        self.assertEqual(sibling.geometry(), sibling_before)
        root.close()

    def test_targeted_selector_resolution_does_not_require_full_index(self) -> None:
        root = QWidget(); root.setObjectName("root")
        branch = QWidget(root); branch.setObjectName("branch")
        label = QLabel(branch); label.setObjectName("label")
        selector = object_selector(label, root)
        self.assertEqual(resolve_widget_selector(root, selector), label)
        self.assertIsNone(resolve_widget_selector(root, selector + "/QLabel#missing"))

    def test_selector_distinguishes_unnamed_siblings(self) -> None:
        root = QWidget(); first = QLabel(root); second = QLabel(root)
        self.assertNotEqual(object_selector(first, root), object_selector(second, root))
        self.assertEqual(len(widget_index(root)), 3)

    def test_transient_form_state_restores_without_emitting_signals(self) -> None:
        root = QWidget()
        edit = QLineEdit(root); edit.setObjectName("query"); edit.setText("query")
        combo = QComboBox(root); combo.setObjectName("mode"); combo.addItems(["A", "B"]); combo.setCurrentIndex(1)
        check = QCheckBox(root); check.setObjectName("enabled"); check.setChecked(True)
        state = capture_transient_widget_state(root)
        edit.setText(""); combo.setCurrentIndex(0); check.setChecked(False)
        changed: list[str] = []
        edit.textChanged.connect(lambda: changed.append("edit"))
        combo.currentIndexChanged.connect(lambda: changed.append("combo"))
        check.toggled.connect(lambda: changed.append("check"))
        restore_transient_widget_state(root, state)
        self.assertEqual(edit.text(), "query"); self.assertEqual(combo.currentText(), "B")
        self.assertTrue(check.isChecked()); self.assertEqual(changed, [])


if __name__ == "__main__":
    unittest.main()
