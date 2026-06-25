"""Photoshop-like pixel alignment GUI for virtual matcher templates."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtGui import QAction, QColor, QPen
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QFormLayout, QGraphicsPixmapItem, QGraphicsRectItem,
    QGraphicsScene, QHBoxLayout, QLabel, QListWidget, QMainWindow, QPushButton,
    QSlider, QSpinBox, QSplitter, QToolBar, QVBoxLayout, QWidget,
)

from tools.template_alignment_actions import AlignmentActionsMixin
from tools.template_alignment_tool import AlignmentProject, LayerItem, PixelView


class AlignmentWindow(AlignmentActionsMixin, QMainWindow):
    def __init__(self, project_path: Path | None = None) -> None:
        super().__init__()
        self.setWindowTitle("Template Layer & ROI Aligner")
        self.resize(1500, 920)
        self.project, self.project_path = AlignmentProject(), project_path
        self.scene = QGraphicsScene(self)
        self.view = PixelView(self.scene)
        self.view.cursor_moved.connect(
            lambda x, y: self.statusBar().showMessage(f"pixel: {x}, {y}")
        )
        self.view.nudge_requested.connect(self.nudge)
        self.reference_item = QGraphicsPixmapItem()
        self.reference_item.setZValue(-1000)
        self.scene.addItem(self.reference_item)
        self.layer_items: list[LayerItem] = []
        self.roi_item = QGraphicsRectItem()
        self.roi_item.setPen(QPen(QColor(255, 55, 80), 1))
        self.roi_item.setBrush(QColor(255, 40, 70, 18))
        self.roi_item.setZValue(1000)
        self.scene.addItem(self.roi_item)
        self._updating = False
        split = QSplitter()
        split.addWidget(self.view)
        split.addWidget(self._side_panel())
        split.setSizes([1100, 400])
        self.setCentralWidget(split)
        self._toolbar()
        if project_path:
            self.open_project(project_path)

    @staticmethod
    def _spin(minimum=-10000, maximum=10000):
        spin = QSpinBox()
        spin.setRange(minimum, maximum)
        return spin

    def _toolbar(self):
        bar = QToolBar("Project")
        self.addToolBar(bar)
        for text, callback in (
            ("Reference", self.choose_reference), ("Add layer", self.choose_layers),
            ("Open project", self.choose_project), ("Save project", self.choose_save),
            ("Export ROI", self.choose_export), ("Fit", self.fit),
            ("100%", self.view.resetTransform),
        ):
            action = QAction(text, self)
            action.triggered.connect(callback)
            bar.addAction(action)

    def _side_panel(self):
        panel = QWidget()
        root = QVBoxLayout(panel)
        root.addWidget(QLabel("Layers (bottom → top)"))
        self.layer_list = QListWidget()
        self.layer_list.currentRowChanged.connect(self.select_layer)
        root.addWidget(self.layer_list, 1)
        buttons = QHBoxLayout()
        for text, callback in (
            ("+", self.choose_layers), ("−", self.remove_layer),
            ("↑", lambda: self.reorder(1)), ("↓", lambda: self.reorder(-1)),
        ):
            button = QPushButton(text)
            button.clicked.connect(callback)
            buttons.addWidget(button)
        root.addLayout(buttons)

        self.visible = QCheckBox("Visible")
        self.aspect = QCheckBox("Lock aspect ratio")
        self.aspect.setChecked(True)
        self.opacity = QSlider(Qt.Horizontal)
        self.opacity.setRange(0, 100)
        self.lx, self.ly = self._spin(), self._spin()
        self.lw, self.lh = self._spin(1, 20000), self._spin(1, 20000)
        self.visible.toggled.connect(self.layer_changed)
        for control in (self.opacity, self.lx, self.ly, self.lw, self.lh):
            control.valueChanged.connect(self.layer_changed)
        form = QFormLayout()
        for label, widget in (
            ("", self.visible), ("Opacity", self.opacity), ("X", self.lx),
            ("Y", self.ly), ("Width", self.lw), ("Height", self.lh),
            ("", self.aspect),
        ):
            form.addRow(label, widget)
        root.addLayout(form)

        root.addWidget(QLabel("ROI (reference pixel coordinates)"))
        self.rx, self.ry = self._spin(), self._spin()
        self.rw, self.rh = self._spin(1, 20000), self._spin(1, 20000)
        roi_form = QFormLayout()
        for label, widget in (
            ("X", self.rx), ("Y", self.ry),
            ("Width", self.rw), ("Height", self.rh),
        ):
            widget.valueChanged.connect(self.roi_changed)
            roi_form.addRow(label, widget)
        root.addLayout(roi_form)
        blink = QPushButton("Hold to hide layers (blink)")
        blink.pressed.connect(lambda: self.show_layers(False))
        blink.released.connect(lambda: self.show_layers(True))
        root.addWidget(blink)
        self.sync_roi()
        return panel


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", nargs="?", type=Path)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--layer", type=Path, action="append", default=[])
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    app = QApplication(sys.argv)
    window = AlignmentWindow(args.project)
    if args.reference and not args.project:
        window.set_reference(args.reference)
    for layer in args.layer:
        window.add_layer(layer)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
