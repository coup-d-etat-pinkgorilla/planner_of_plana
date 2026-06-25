"""Pixel-accurate layered template and ROI alignment tool."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

from PIL import Image
from PySide6.QtCore import QPointF, QRectF, Qt, Signal
from PySide6.QtGui import QAction, QColor, QImage, QKeyEvent, QPainter, QPen, QPixmap
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QFileDialog, QFormLayout, QGraphicsItem,
    QGraphicsPixmapItem, QGraphicsRectItem, QGraphicsScene, QGraphicsView,
    QHBoxLayout, QLabel, QListWidget, QListWidgetItem, QMainWindow,
    QMessageBox, QPushButton, QSlider, QSpinBox, QSplitter, QToolBar,
    QVBoxLayout, QWidget,
)

IMAGE_FILTER = "Images (*.png *.jpg *.jpeg *.webp *.bmp);;All files (*)"


@dataclass
class LayerSpec:
    path: str
    name: str
    x: int = 0
    y: int = 0
    width: int = 1
    height: int = 1
    opacity: int = 55
    visible: bool = True


@dataclass
class RoiSpec:
    x: int = 0
    y: int = 0
    width: int = 128
    height: int = 128


@dataclass
class AlignmentProject:
    reference_path: str = ""
    layers: list[LayerSpec] = field(default_factory=list)
    roi: RoiSpec = field(default_factory=RoiSpec)


def _resolved_path(path: str, project_dir: Path | None = None) -> Path:
    value = Path(path).expanduser()
    if not value.is_absolute() and project_dir is not None:
        value = project_dir / value
    return value.resolve()


def load_project(path: Path) -> AlignmentProject:
    raw = json.loads(path.read_text(encoding="utf-8"))
    base = path.parent
    layers = []
    for data in raw.get("layers", []):
        item = dict(data)
        item["path"] = str(_resolved_path(item["path"], base))
        layers.append(LayerSpec(**item))
    reference = raw.get("reference_path", "")
    return AlignmentProject(
        reference_path=str(_resolved_path(reference, base)) if reference else "",
        layers=layers,
        roi=RoiSpec(**raw.get("roi", {})),
    )


def save_project(project: AlignmentProject, path: Path) -> None:
    base = path.parent.resolve()

    def portable(value: str) -> str:
        resolved = _resolved_path(value)
        try:
            return str(resolved.relative_to(base))
        except ValueError:
            return str(resolved)

    payload = asdict(project)
    if project.reference_path:
        payload["reference_path"] = portable(project.reference_path)
    for raw, layer in zip(payload["layers"], project.layers):
        raw["path"] = portable(layer.path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def render_virtual(project: AlignmentProject, canvas_size: tuple[int, int]) -> Image.Image:
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    for layer in project.layers:
        if not layer.visible:
            continue
        source = Image.open(layer.path).convert("RGBA")
        source = source.resize((max(1, layer.width), max(1, layer.height)), Image.Resampling.LANCZOS)
        if layer.opacity < 100:
            alpha = source.getchannel("A").point(lambda value: value * layer.opacity // 100)
            source.putalpha(alpha)
        canvas.alpha_composite(source, dest=(layer.x, layer.y))
    return canvas


def export_alignment(project: AlignmentProject, output_dir: Path) -> list[Path]:
    if not project.reference_path:
        raise ValueError("Reference image is not set")
    reference = Image.open(project.reference_path).convert("RGBA")
    virtual = render_virtual(project, reference.size)
    preview = Image.alpha_composite(reference, virtual)
    roi = project.roi
    box = (roi.x, roi.y, roi.x + roi.width, roi.y + roi.height)
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs = {
        "reference_roi.png": reference.crop(box),
        "virtual_template_roi.png": virtual.crop(box),
        "overlay_preview_roi.png": preview.crop(box),
        "virtual_template_full.png": virtual,
    }
    paths = []
    for name, image in outputs.items():
        target = output_dir / name
        image.save(target)
        paths.append(target)
    metadata = output_dir / "alignment.json"
    metadata.write_text(json.dumps(asdict(project), ensure_ascii=False, indent=2), encoding="utf-8")
    paths.append(metadata)
    return paths


def pil_to_pixmap(image: Image.Image) -> QPixmap:
    rgba = image.convert("RGBA")
    data = rgba.tobytes("raw", "RGBA")
    qimage = QImage(data, rgba.width, rgba.height, QImage.Format_RGBA8888).copy()
    return QPixmap.fromImage(qimage)


class LayerItem(QGraphicsPixmapItem):
    def __init__(self, index: int, callback) -> None:
        super().__init__()
        self.index = index
        self.callback = callback
        self.setFlags(
            QGraphicsItem.ItemIsMovable | QGraphicsItem.ItemIsSelectable
            | QGraphicsItem.ItemSendsGeometryChanges
        )

    def itemChange(self, change, value):
        if change == QGraphicsItem.ItemPositionChange:
            return QPointF(round(value.x()), round(value.y()))
        if change == QGraphicsItem.ItemPositionHasChanged:
            self.callback(self.index, round(self.pos().x()), round(self.pos().y()))
        return super().itemChange(change, value)


class PixelView(QGraphicsView):
    cursor_moved = Signal(int, int)
    nudge_requested = Signal(int, int)

    def __init__(self, scene: QGraphicsScene) -> None:
        super().__init__(scene)
        self.setRenderHints(QPainter.Antialiasing | QPainter.SmoothPixmapTransform)
        self.setDragMode(QGraphicsView.ScrollHandDrag)
        self.setMouseTracking(True)
        self.setBackgroundBrush(QColor(35, 38, 44))
        self.setFocusPolicy(Qt.StrongFocus)

    def wheelEvent(self, event) -> None:
        factor = 1.25 if event.angleDelta().y() > 0 else 0.8
        if 0.05 <= self.transform().m11() * factor <= 64:
            self.scale(factor, factor)

    def mouseMoveEvent(self, event) -> None:
        pos = self.mapToScene(event.position().toPoint())
        self.cursor_moved.emit(int(pos.x()), int(pos.y()))
        super().mouseMoveEvent(event)

    def keyPressEvent(self, event: QKeyEvent) -> None:
        delta = {Qt.Key_Left: (-1, 0), Qt.Key_Right: (1, 0),
                 Qt.Key_Up: (0, -1), Qt.Key_Down: (0, 1)}.get(event.key())
        if delta:
            step = 10 if event.modifiers() & Qt.ShiftModifier else 1
            self.nudge_requested.emit(delta[0] * step, delta[1] * step)
            return
        super().keyPressEvent(event)

    def drawForeground(self, painter: QPainter, rect: QRectF) -> None:
        super().drawForeground(painter, rect)
        if self.transform().m11() < 8:
            return
        painter.save()
        painter.setPen(QPen(QColor(255, 255, 255, 28), 0))
        for x in range(int(rect.left()), int(rect.right()) + 2):
            painter.drawLine(x, int(rect.top()), x, int(rect.bottom()) + 1)
        for y in range(int(rect.top()), int(rect.bottom()) + 2):
            painter.drawLine(int(rect.left()), y, int(rect.right()) + 1, y)
        painter.restore()
