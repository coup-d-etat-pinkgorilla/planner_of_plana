"""Project file and export actions for Template Alignment Studio."""

from pathlib import Path

from PySide6.QtWidgets import QFileDialog, QMessageBox

from tools.template_alignment_studio_model import export_project, load_project, save_project


class StudioProjectMixin:
    def choose_project(self):
        path, _ = QFileDialog.getOpenFileName(self, "Open project", "", "JSON (*.json)")
        if path:
            self.open_project(Path(path))

    def open_project(self, path):
        try:
            self.project, self.project_path = load_project(Path(path)), Path(path)
            if self.project.reference_path:
                self.set_reference(Path(self.project.reference_path))
            self.rebuild_layers(); self.rebuild_rois()
        except Exception as exc:
            QMessageBox.critical(self, "Open failed", str(exc))

    def choose_save(self):
        initial = str(self.project_path or Path("template_alignment_studio.json"))
        path, _ = QFileDialog.getSaveFileName(self, "Save project", initial, "JSON (*.json)")
        if path:
            try:
                self.project_path = Path(path); save_project(self.project, self.project_path)
                self.statusBar().showMessage(f"Saved: {path}", 5000)
            except Exception as exc:
                QMessageBox.critical(self, "Save failed", str(exc))

    def choose_export(self):
        directory = QFileDialog.getExistingDirectory(self, "Export named ROI images")
        if directory:
            try:
                paths = export_project(self.project, Path(directory))
                QMessageBox.information(self, "Export complete", f"Exported {len(paths)} files")
            except Exception as exc:
                QMessageBox.critical(self, "Export failed", str(exc))

    def show_layers(self, visible):
        for item, layer in zip(self.layer_items, self.project.layers):
            item.setVisible(visible and layer.visible)
