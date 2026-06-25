"""Actions used by the template alignment GUI."""

from pathlib import Path

from PIL import Image
from PySide6.QtCore import Qt
from PySide6.QtWidgets import QFileDialog, QListWidgetItem, QMessageBox

from tools.template_alignment_tool import (
    IMAGE_FILTER, LayerItem, LayerSpec, RoiSpec, export_alignment, load_project,
    pil_to_pixmap, save_project,
)


class AlignmentActionsMixin:
    def choose_reference(self):
        path, _ = QFileDialog.getOpenFileName(self, "Reference screenshot", "", IMAGE_FILTER)
        if path:
            self.set_reference(Path(path))

    def set_reference(self, path: Path):
        image = Image.open(path).convert("RGBA")
        self.project.reference_path = str(path.resolve())
        self.reference_item.setPixmap(pil_to_pixmap(image))
        self.scene.setSceneRect(0, 0, image.width, image.height)
        if self.project.roi == RoiSpec():
            self.project.roi = RoiSpec(0, 0, image.width, image.height)
            self.sync_roi()
        self.fit()

    def choose_layers(self):
        paths, _ = QFileDialog.getOpenFileNames(self, "Add image layers", "", IMAGE_FILTER)
        for path in paths:
            self.add_layer(Path(path))

    def add_layer(self, path: Path):
        image = Image.open(path)
        self.project.layers.append(
            LayerSpec(str(path.resolve()), path.stem, width=image.width, height=image.height)
        )
        self.rebuild_layers(len(self.project.layers) - 1)

    def rebuild_layers(self, selected=0):
        for item in self.layer_items:
            self.scene.removeItem(item)
        self.layer_items.clear()
        self.layer_list.clear()
        for index, spec in enumerate(self.project.layers):
            item = LayerItem(index, self.item_moved)
            self.scene.addItem(item)
            self.layer_items.append(item)
            self.layer_list.addItem(QListWidgetItem(spec.name))
            self.refresh_layer(index)
        if self.project.layers:
            self.layer_list.setCurrentRow(max(0, min(selected, len(self.project.layers) - 1)))

    def refresh_layer(self, index):
        spec, item = self.project.layers[index], self.layer_items[index]
        image = Image.open(spec.path).convert("RGBA").resize(
            (spec.width, spec.height), Image.Resampling.LANCZOS
        )
        item.setPixmap(pil_to_pixmap(image))
        item.setPos(spec.x, spec.y)
        item.setOpacity(spec.opacity / 100)
        item.setVisible(spec.visible)
        item.setZValue(index)

    def select_layer(self, index):
        if not 0 <= index < len(self.project.layers):
            return
        self._updating = True
        spec = self.project.layers[index]
        self.visible.setChecked(spec.visible)
        self.opacity.setValue(spec.opacity)
        for widget, value in (
            (self.lx, spec.x), (self.ly, spec.y),
            (self.lw, spec.width), (self.lh, spec.height),
        ):
            widget.setValue(value)
        self.layer_items[index].setSelected(True)
        self._updating = False

    def layer_changed(self, *_):
        index = self.layer_list.currentRow()
        if self._updating or not 0 <= index < len(self.project.layers):
            return
        spec = self.project.layers[index]
        old_w, old_h = spec.width, spec.height
        new_w, new_h = self.lw.value(), self.lh.value()
        sender = self.sender()
        if self.aspect.isChecked() and old_w and old_h:
            self._updating = True
            if sender is self.lw:
                new_h = max(1, round(new_w * old_h / old_w))
                self.lh.setValue(new_h)
            elif sender is self.lh:
                new_w = max(1, round(new_h * old_w / old_h))
                self.lw.setValue(new_w)
            self._updating = False
        spec.x, spec.y = self.lx.value(), self.ly.value()
        spec.width, spec.height = new_w, new_h
        spec.opacity, spec.visible = self.opacity.value(), self.visible.isChecked()
        self.refresh_layer(index)

    def item_moved(self, index, x, y):
        if self._updating or not 0 <= index < len(self.project.layers):
            return
        self.project.layers[index].x, self.project.layers[index].y = x, y
        if self.layer_list.currentRow() == index:
            self._updating = True
            self.lx.setValue(x)
            self.ly.setValue(y)
            self._updating = False

    def remove_layer(self):
        index = self.layer_list.currentRow()
        if 0 <= index < len(self.project.layers):
            del self.project.layers[index]
            self.rebuild_layers(index)

    def reorder(self, delta):
        index = self.layer_list.currentRow()
        target = index + delta
        if 0 <= index < len(self.project.layers) and 0 <= target < len(self.project.layers):
            self.project.layers[index], self.project.layers[target] = (
                self.project.layers[target], self.project.layers[index]
            )
            self.rebuild_layers(target)

    def roi_changed(self, *_):
        if self._updating:
            return
        self.project.roi = RoiSpec(
            self.rx.value(), self.ry.value(), self.rw.value(), self.rh.value()
        )
        roi = self.project.roi
        self.roi_item.setRect(roi.x, roi.y, roi.width, roi.height)

    def sync_roi(self):
        self._updating = True
        roi = self.project.roi
        for widget, value in (
            (self.rx, roi.x), (self.ry, roi.y),
            (self.rw, roi.width), (self.rh, roi.height),
        ):
            widget.setValue(value)
        self._updating = False
        self.roi_item.setRect(roi.x, roi.y, roi.width, roi.height)

    def nudge(self, dx, dy):
        if 0 <= self.layer_list.currentRow() < len(self.project.layers):
            self.lx.setValue(self.lx.value() + dx)
            self.ly.setValue(self.ly.value() + dy)

    def show_layers(self, visible):
        for item, spec in zip(self.layer_items, self.project.layers):
            item.setVisible(visible and spec.visible)

    def fit(self):
        if not self.scene.sceneRect().isEmpty():
            self.view.fitInView(self.scene.sceneRect(), Qt.KeepAspectRatio)

    def choose_project(self):
        path, _ = QFileDialog.getOpenFileName(self, "Open project", "", "JSON (*.json)")
        if path:
            self.open_project(Path(path))

    def open_project(self, path: Path):
        try:
            self.project, self.project_path = load_project(path), path
            if self.project.reference_path:
                self.set_reference(Path(self.project.reference_path))
            self.rebuild_layers()
            self.sync_roi()
        except Exception as exc:
            QMessageBox.critical(self, "Open failed", str(exc))

    def choose_save(self):
        initial = str(self.project_path or Path("template_alignment.json"))
        path, _ = QFileDialog.getSaveFileName(self, "Save project", initial, "JSON (*.json)")
        if path:
            try:
                self.project_path = Path(path)
                save_project(self.project, self.project_path)
                self.statusBar().showMessage(f"Saved: {path}", 5000)
            except Exception as exc:
                QMessageBox.critical(self, "Save failed", str(exc))

    def choose_export(self):
        directory = QFileDialog.getExistingDirectory(self, "Export ROI images")
        if directory:
            try:
                paths = export_alignment(self.project, Path(directory))
                QMessageBox.information(
                    self, "Export complete", "\n".join(path.name for path in paths)
                )
            except Exception as exc:
                QMessageBox.critical(self, "Export failed", str(exc))
