"""Realtime ROI background/source subtraction preview tool.

Drop this file into the same ``tools`` package as the existing template
alignment scripts, then run from the project root:

    python -m tools.template_background_subtractor
    python -m tools.template_background_subtractor path/to/template_alignment.json

This is intentionally a separate tool. It reads Template Alignment Studio
projects, but it does not modify the original alignment/studio source files.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path
from typing import Iterable

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from PySide6.QtCore import QPointF, Qt
from PySide6.QtGui import QAction, QColor, QPen, QPolygonF
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QComboBox,
    QDoubleSpinBox,
    QFileDialog,
    QFormLayout,
    QGraphicsPixmapItem,
    QGraphicsPolygonItem,
    QGraphicsScene,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSlider,
    QSpinBox,
    QSplitter,
    QToolBar,
    QVBoxLayout,
    QWidget,
)

try:  # Normal project layout: tools/template_background_subtractor.py
    from tools.template_alignment_studio_model import (
        LayerSpec,
        RoiSpec,
        StudioProject,
        load_project,
        render_layer,
        render_virtual,
    )
    from tools.template_alignment_tool import IMAGE_FILTER, PixelView, pil_to_pixmap
except ModuleNotFoundError:  # Helpful when testing next to the uploaded files.
    from template_alignment_studio_model import (  # type: ignore
        LayerSpec,
        RoiSpec,
        StudioProject,
        load_project,
        render_layer,
        render_virtual,
    )
    from template_alignment_tool import IMAGE_FILTER, PixelView, pil_to_pixmap  # type: ignore


SOURCE_PROJECT_VIRTUAL = "Project virtual: all visible layers"
SOURCE_SELECTED_LAYER = "Project layer: selected layer only"
SOURCE_EXTERNAL_IMAGE = "External image: paste into ROI"

PREVIEW_ABS = "Residual: abs(reference - source)"
PREVIEW_SIGNED = "Residual: signed centered at 128"
PREVIEW_POSITIVE = "Residual: positive only"
PREVIEW_NEGATIVE = "Residual: negative only"
PREVIEW_CLEANED = "Cleaned/reference minus source"
PREVIEW_SOURCE = "Adjusted source only"
PREVIEW_REFERENCE = "Reference ROI only"
PREVIEW_ALPHA = "Source alpha/mask"
PREVIEW_OVERLAY = "Reference + adjusted source overlay"


class SimpleRoiItem(QGraphicsPolygonItem):
    """Visible ROI marker for the reference canvas."""

    def __init__(self) -> None:
        super().__init__()
        self.setPen(QPen(QColor(255, 55, 80), 1))
        self.setBrush(QColor(255, 40, 70, 24))
        self.setZValue(2000)

    def update_shape(self, roi: RoiSpec) -> None:
        self.setPolygon(QPolygonF(_roi_local_points(roi)))
        self.setPos(roi.x, roi.y)
        self.setVisible(roi.enabled)


def _clamp_u8(array: np.ndarray) -> np.ndarray:
    return np.clip(array, 0, 255).astype(np.uint8)


def _roi_local_points(roi: RoiSpec) -> list[QPointF]:
    slant = int(roi.slant) if roi.shape == "parallelogram" else 0
    return [
        QPointF(slant, 0),
        QPointF(roi.width + slant, 0),
        QPointF(roi.width, roi.height),
        QPointF(0, roi.height),
    ]


def _roi_points(roi: RoiSpec) -> list[tuple[int, int]]:
    slant = int(roi.slant) if roi.shape == "parallelogram" else 0
    return [
        (roi.x + slant, roi.y),
        (roi.x + roi.width + slant, roi.y),
        (roi.x + roi.width, roi.y + roi.height),
        (roi.x, roi.y + roi.height),
    ]


def _roi_box(roi: RoiSpec) -> tuple[int, int, int, int]:
    points = _roi_points(roi)
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return min(xs), min(ys), max(xs), max(ys)


def _crop_with_fill(image: Image.Image, box: tuple[int, int, int, int], fill=(0, 0, 0, 0)) -> Image.Image:
    """Crop possibly out-of-bounds box while preserving the requested size."""

    left, top, right, bottom = box
    width, height = max(1, right - left), max(1, bottom - top)
    result = Image.new("RGBA", (width, height), fill)
    src_box = (
        max(0, left),
        max(0, top),
        min(image.width, right),
        min(image.height, bottom),
    )
    if src_box[2] <= src_box[0] or src_box[3] <= src_box[1]:
        return result
    patch = image.convert("RGBA").crop(src_box)
    result.alpha_composite(patch, dest=(src_box[0] - left, src_box[1] - top))
    return result


def _roi_mask(roi: RoiSpec, box: tuple[int, int, int, int]) -> Image.Image:
    width, height = max(1, box[2] - box[0]), max(1, box[3] - box[1])
    mask = Image.new("L", (width, height), 255)
    if roi.shape == "parallelogram":
        mask = Image.new("L", (width, height), 0)
        local = [(x - box[0], y - box[1]) for x, y in _roi_points(roi)]
        ImageDraw.Draw(mask).polygon(local, fill=255)
    return mask


def _paste_with_clip(canvas: Image.Image, image: Image.Image, dest: tuple[int, int]) -> None:
    """Alpha-composite image onto canvas, allowing negative destinations."""

    dx, dy = dest
    src_left = max(0, -dx)
    src_top = max(0, -dy)
    src_right = min(image.width, canvas.width - dx)
    src_bottom = min(image.height, canvas.height - dy)
    if src_right <= src_left or src_bottom <= src_top:
        return
    patch = image.crop((src_left, src_top, src_right, src_bottom))
    canvas.alpha_composite(patch, dest=(dx + src_left, dy + src_top))


def _apply_source_traits(
    source: Image.Image,
    *,
    alpha_percent: int,
    gain_percent: int,
    bias: int,
    gamma: float,
    blur_radius: float,
    alpha_threshold: int,
) -> Image.Image:
    """Apply tunable traits before subtraction."""

    image = source.convert("RGBA")
    if blur_radius > 0:
        image = image.filter(ImageFilter.GaussianBlur(blur_radius))

    arr = np.asarray(image).astype(np.float32)
    rgb = arr[..., :3]
    alpha = arr[..., 3]

    if abs(gamma - 1.0) > 1e-6:
        # gamma < 1 brightens mid-tones, gamma > 1 darkens them.
        rgb = np.power(np.clip(rgb / 255.0, 0, 1), gamma) * 255.0
    if gain_percent != 100:
        rgb *= gain_percent / 100.0
    if bias:
        rgb += bias
    if alpha_percent != 100:
        alpha *= alpha_percent / 100.0
    if alpha_threshold > 0:
        alpha = np.where(alpha >= alpha_threshold, alpha, 0)

    arr[..., :3] = _clamp_u8(rgb)
    arr[..., 3] = _clamp_u8(alpha)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")



def _parse_hex_color(value: str) -> tuple[float, float, float]:
    text = (value or "").strip()
    if not text.startswith("#"):
        text = "#" + text
    if len(text) == 4:
        text = "#" + "".join(ch * 2 for ch in text[1:])
    if len(text) != 7:
        raise ValueError(f"Invalid target color: {value!r}")
    try:
        return tuple(float(int(text[i : i + 2], 16)) for i in (1, 3, 5))  # type: ignore[return-value]
    except ValueError as exc:
        raise ValueError(f"Invalid target color: {value!r}") from exc


def _reference_color_mask(
    reference_roi: Image.Image,
    *,
    target_hex: str,
    tolerance_percent: int,
    feather_radius: float,
) -> np.ndarray:
    """Return a 0..1 mask where reference pixels are close to target_hex."""

    target = np.asarray(_parse_hex_color(target_hex), dtype=np.float32)
    ref = np.asarray(reference_roi.convert("RGBA")).astype(np.float32)

    ref_rgb = ref[..., :3]
    ref_alpha = ref[..., 3] / 255.0
    distance = np.linalg.norm(ref_rgb - target, axis=2)
    max_distance = (3 * (255.0 ** 2)) ** 0.5
    threshold = max(0.0, min(100.0, float(tolerance_percent))) / 100.0 * max_distance

    color_mask = ((distance <= threshold) & (ref_alpha > 0)).astype(np.float32)
    if feather_radius > 0:
        # Feather after hard threshold so antialiased/near-boundary pixels can be tuned visually.
        mask_img = Image.fromarray((color_mask * 255).astype(np.uint8), "L")
        mask_img = mask_img.filter(ImageFilter.GaussianBlur(feather_radius))
        color_mask = np.asarray(mask_img).astype(np.float32) / 255.0
    return color_mask


def _apply_reference_color_filter(
    source_roi: Image.Image,
    reference_roi: Image.Image,
    *,
    enabled: bool,
    target_hex: str,
    tolerance_percent: int,
    feather_radius: float,
) -> Image.Image:
    """Keep source alpha only where reference pixels are close to target_hex."""

    if not enabled:
        return source_roi

    color_mask = _reference_color_mask(
        reference_roi,
        target_hex=target_hex,
        tolerance_percent=tolerance_percent,
        feather_radius=feather_radius,
    )
    src = np.asarray(source_roi.convert("RGBA")).astype(np.float32)
    src[..., 3] *= color_mask
    return Image.fromarray(_clamp_u8(src), "RGBA")


def _apply_reference_preview_filter(
    reference_roi: Image.Image,
    *,
    enabled: bool,
    target_hex: str,
    tolerance_percent: int,
    feather_radius: float,
) -> Image.Image:
    """For 'Reference ROI only', hide reference pixels outside the target color range."""

    image = reference_roi.convert("RGBA")
    if not enabled:
        return image
    color_mask = _reference_color_mask(
        image,
        target_hex=target_hex,
        tolerance_percent=tolerance_percent,
        feather_radius=feather_radius,
    )
    arr = np.asarray(image).astype(np.float32)
    arr[..., 3] *= color_mask
    return Image.fromarray(_clamp_u8(arr), "RGBA")


def _image_to_rgb_alpha(image: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    arr = np.asarray(image.convert("RGBA")).astype(np.float32)
    return arr[..., :3], arr[..., 3:4] / 255.0


def _residual_images(
    reference_roi: Image.Image,
    source_roi: Image.Image,
    roi_mask: Image.Image,
    *,
    use_alpha_weight: bool,
    display_gain: float,
) -> tuple[dict[str, Image.Image], dict[str, float]]:
    ref_rgb, ref_alpha = _image_to_rgb_alpha(reference_roi)
    src_rgb, src_alpha = _image_to_rgb_alpha(source_roi)
    mask = np.asarray(roi_mask).astype(np.float32)[..., None] / 255.0
    effective_alpha = src_alpha if use_alpha_weight else (src_alpha > 0).astype(np.float32)
    effective_source = src_rgb * effective_alpha

    signed = (ref_rgb - effective_source) * mask
    abs_res = np.abs(signed)
    pos = np.maximum(signed, 0)
    neg = np.maximum(-signed, 0)
    cleaned = np.clip(ref_rgb - effective_source, 0, 255)

    scaled_abs = _clamp_u8(abs_res * display_gain)
    signed_centered = _clamp_u8(128.0 + signed * display_gain)
    pos_img = _clamp_u8(pos * display_gain)
    neg_img = _clamp_u8(neg * display_gain)
    cleaned_img = _clamp_u8(cleaned)
    alpha_img = _clamp_u8(src_alpha.repeat(3, axis=2) * 255.0)

    preview_alpha = _clamp_u8(np.maximum(ref_alpha, mask) * 255.0).squeeze(-1)
    source_arr = np.asarray(source_roi.convert("RGBA")).copy()
    source_arr[..., 3] = np.minimum(source_arr[..., 3], preview_alpha)

    overlay = Image.alpha_composite(reference_roi.convert("RGBA"), source_roi.convert("RGBA"))

    valid = mask.squeeze(-1) > 0
    active = (src_alpha.squeeze(-1) > 0) & valid
    metric_area = active if np.any(active) else valid
    abs_values = abs_res[metric_area]
    alpha_values = src_alpha.squeeze(-1)[metric_area]
    metrics = {
        "roi_pixels": float(np.count_nonzero(valid)),
        "source_pixels": float(np.count_nonzero(active)),
        "mean_abs": float(abs_values.mean()) if abs_values.size else 0.0,
        "max_abs": float(abs_values.max()) if abs_values.size else 0.0,
        "source_alpha_mean": float(alpha_values.mean()) if alpha_values.size else 0.0,
    }

    previews = {
        PREVIEW_ABS: Image.fromarray(np.dstack([scaled_abs, preview_alpha]), "RGBA"),
        PREVIEW_SIGNED: Image.fromarray(np.dstack([signed_centered, preview_alpha]), "RGBA"),
        PREVIEW_POSITIVE: Image.fromarray(np.dstack([pos_img, preview_alpha]), "RGBA"),
        PREVIEW_NEGATIVE: Image.fromarray(np.dstack([neg_img, preview_alpha]), "RGBA"),
        PREVIEW_CLEANED: Image.fromarray(np.dstack([cleaned_img, preview_alpha]), "RGBA"),
        PREVIEW_SOURCE: Image.fromarray(source_arr, "RGBA"),
        PREVIEW_REFERENCE: reference_roi.convert("RGBA"),
        PREVIEW_ALPHA: Image.fromarray(np.dstack([alpha_img, preview_alpha]), "RGBA"),
        PREVIEW_OVERLAY: overlay,
    }
    return previews, metrics


class BackgroundSubtractorWindow(QMainWindow):
    def __init__(self, project_path: Path | None = None, reference_path: Path | None = None, source_path: Path | None = None):
        super().__init__()
        self.setWindowTitle("ROI Background/Subtraction Preview - color filter reference v3")
        self.resize(1760, 980)

        self.project = StudioProject()
        self.project_path: Path | None = None
        self.reference_image: Image.Image | None = None
        self.external_source_path: Path | None = None
        self.external_source_image: Image.Image | None = None
        self._updating = False
        self._last_outputs: dict[str, Image.Image] = {}
        self._last_metrics: dict[str, float] = {}

        self.scene = QGraphicsScene(self)
        self.view = PixelView(self.scene)
        self.reference_item = QGraphicsPixmapItem()
        self.reference_item.setZValue(-1000)
        self.scene.addItem(self.reference_item)
        self.source_overlay_item = QGraphicsPixmapItem()
        self.source_overlay_item.setOpacity(0.55)
        self.source_overlay_item.setZValue(100)
        self.scene.addItem(self.source_overlay_item)
        self.roi_item = SimpleRoiItem()
        self.scene.addItem(self.roi_item)

        self.preview_scene = QGraphicsScene(self)
        self.preview_view = PixelView(self.preview_scene)
        self.preview_item = QGraphicsPixmapItem()
        self.preview_scene.addItem(self.preview_item)

        split = QSplitter(Qt.Horizontal)
        split.addWidget(self.view)
        split.addWidget(self.preview_view)
        split.addWidget(self._side_panel())
        split.setSizes([820, 540, 400])
        self.setCentralWidget(split)
        self._toolbar()

        if project_path:
            self.open_project(project_path)
        if reference_path:
            self.set_reference(reference_path)
        if source_path:
            self.set_external_source(source_path)
        self._sync_roi_item()
        self.update_preview()

    @staticmethod
    def _spin(minimum=-10000, maximum=10000) -> QSpinBox:
        spin = QSpinBox()
        spin.setRange(minimum, maximum)
        return spin

    @staticmethod
    def _double_spin(minimum=-10000.0, maximum=10000.0, step=0.1, decimals=2) -> QDoubleSpinBox:
        spin = QDoubleSpinBox()
        spin.setRange(minimum, maximum)
        spin.setSingleStep(step)
        spin.setDecimals(decimals)
        return spin

    def _toolbar(self) -> None:
        bar = QToolBar("Subtraction")
        self.addToolBar(bar)
        for text, callback in (
            ("Open project", self.choose_project),
            ("Reference", self.choose_reference),
            ("Source image", self.choose_external_source),
            ("Export preview", self.choose_export),
            ("Fit", self.fit_views),
            ("100%", self.reset_views),
        ):
            action = QAction(text, self)
            action.triggered.connect(callback)
            bar.addAction(action)
        bar.addSeparator()
        self.toolbar_color_filter = QCheckBox("Color filter #2D4663")
        self.toolbar_color_filter.setToolTip("Same as the COLOR FILTER checkbox in the right panel.")
        self.toolbar_color_filter.setChecked(self.use_color_filter.isChecked())
        self.toolbar_color_filter.toggled.connect(self.use_color_filter.setChecked)
        self.use_color_filter.toggled.connect(self.toolbar_color_filter.setChecked)
        bar.addWidget(self.toolbar_color_filter)

    def _side_panel(self) -> QScrollArea:
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        panel = QWidget()
        scroll.setWidget(panel)
        root = QVBoxLayout(panel)

        self.status = QLabel("Open a project or reference image.")
        self.status.setWordWrap(True)
        root.addWidget(self.status)


        color_title = QLabel("COLOR FILTER / subtraction mask")
        color_title.setWordWrap(True)
        color_title.setStyleSheet("font-weight: 700; color: #8ecbff;")
        root.addWidget(color_title)
        self.use_color_filter = QCheckBox("Enable color filter: subtract only where reference is near target color")
        self.use_color_filter.setChecked(False)
        self.target_color = QLineEdit("#2D4663")
        self.color_tolerance = self._spin(0, 100)
        self.color_tolerance.setValue(8)
        self.color_feather = self._double_spin(0.0, 30.0, 0.25, 2)
        self.color_feather.setValue(0.0)
        color_form = QFormLayout()
        color_form.addRow("", self.use_color_filter)
        color_form.addRow("Target RGB", self.target_color)
        color_form.addRow("Tolerance %", self.color_tolerance)
        color_form.addRow("Feather px", self.color_feather)
        root.addLayout(color_form)
        color_help = QLabel("Applied before subtraction. It checks REFERENCE pixels, then keeps source alpha only where the reference color is close to Target RGB. It also filters the 'Reference ROI only' preview, so you can tune the target color/tolerance directly. Use 'Source alpha/mask' preview to inspect the subtraction mask.")
        color_help.setWordWrap(True)
        root.addWidget(color_help)
        self.use_color_filter.toggled.connect(self.update_preview)
        self.target_color.editingFinished.connect(self.update_preview)
        self.color_tolerance.valueChanged.connect(self.update_preview)
        self.color_feather.valueChanged.connect(self.update_preview)

        root.addWidget(QLabel("ROI / area"))
        self.roi_combo = QComboBox()
        self.roi_combo.currentIndexChanged.connect(self.select_roi)
        root.addWidget(self.roi_combo)
        self.roi_shape = QComboBox()
        self.roi_shape.addItems(["rectangle", "parallelogram"])
        self.rx, self.ry = self._spin(), self._spin()
        self.rw, self.rh = self._spin(1, 50000), self._spin(1, 50000)
        self.rslant = self._spin(-50000, 50000)
        roi_form = QFormLayout()
        for label, widget in (
            ("Shape", self.roi_shape),
            ("X", self.rx),
            ("Y", self.ry),
            ("Width", self.rw),
            ("Height", self.rh),
            ("Slant", self.rslant),
        ):
            roi_form.addRow(label, widget)
        root.addLayout(roi_form)
        for widget in (self.roi_shape, self.rx, self.ry, self.rw, self.rh, self.rslant):
            signal = widget.currentTextChanged if isinstance(widget, QComboBox) else widget.valueChanged
            signal.connect(self.roi_controls_changed)

        root.addWidget(QLabel("Subtraction source"))
        self.source_mode = QComboBox()
        self.source_mode.addItems([SOURCE_PROJECT_VIRTUAL, SOURCE_SELECTED_LAYER, SOURCE_EXTERNAL_IMAGE])
        self.source_mode.currentTextChanged.connect(self.source_mode_changed)
        root.addWidget(self.source_mode)
        self.layer_combo = QComboBox()
        self.layer_combo.currentIndexChanged.connect(self.layer_source_changed)
        root.addWidget(self.layer_combo)

        source_buttons = QHBoxLayout()
        reset_roi = QPushButton("Fill ROI")
        reset_roi.clicked.connect(self.reset_source_to_roi)
        reset_natural = QPushButton("Natural size")
        reset_natural.clicked.connect(self.reset_source_to_natural_size)
        source_buttons.addWidget(reset_roi)
        source_buttons.addWidget(reset_natural)
        root.addLayout(source_buttons)

        self.sx, self.sy = self._spin(), self._spin()
        self.sw, self.sh = self._spin(1, 50000), self._spin(1, 50000)
        source_form = QFormLayout()
        for label, widget in (
            ("Offset X", self.sx),
            ("Offset Y", self.sy),
            ("Width", self.sw),
            ("Height", self.sh),
        ):
            source_form.addRow(label, widget)
            widget.valueChanged.connect(self.update_preview)
        root.addLayout(source_form)

        root.addWidget(QLabel("Source traits / correction"))
        self.alpha = QSlider(Qt.Horizontal)
        self.alpha.setRange(0, 200)
        self.alpha.setValue(100)
        self.gain = QSlider(Qt.Horizontal)
        self.gain.setRange(0, 300)
        self.gain.setValue(100)
        self.bias = self._spin(-255, 255)
        self.gamma = self._double_spin(0.10, 5.00, 0.05, 2)
        self.gamma.setValue(1.00)
        self.blur = self._double_spin(0.0, 20.0, 0.25, 2)
        self.alpha_threshold = self._spin(0, 255)
        self.display_gain = self._double_spin(0.1, 50.0, 0.5, 1)
        self.display_gain.setValue(3.0)
        trait_form = QFormLayout()
        for label, widget in (
            ("Alpha %", self.alpha),
            ("RGB gain %", self.gain),
            ("RGB bias", self.bias),
            ("Gamma", self.gamma),
            ("Blur radius", self.blur),
            ("Alpha threshold", self.alpha_threshold),
            ("Display gain", self.display_gain),
        ):
            trait_form.addRow(label, widget)
        root.addLayout(trait_form)
        for widget in (self.alpha, self.gain, self.bias, self.gamma, self.blur, self.alpha_threshold, self.display_gain):
            widget.valueChanged.connect(self.update_preview)

        self.use_alpha_weight = QCheckBox("Use alpha as subtract weight")
        self.use_alpha_weight.setChecked(True)
        self.use_alpha_weight.toggled.connect(self.update_preview)
        self.show_overlay = QCheckBox("Show adjusted source on left")
        self.show_overlay.setChecked(True)
        self.show_overlay.toggled.connect(self.update_preview)
        root.addWidget(self.use_alpha_weight)
        root.addWidget(self.show_overlay)


        self.preview_mode = QComboBox()
        self.preview_mode.addItems([
            PREVIEW_ABS,
            PREVIEW_SIGNED,
            PREVIEW_POSITIVE,
            PREVIEW_NEGATIVE,
            PREVIEW_CLEANED,
            PREVIEW_SOURCE,
            PREVIEW_REFERENCE,
            PREVIEW_ALPHA,
            PREVIEW_OVERLAY,
        ])
        self.preview_mode.currentTextChanged.connect(self.update_preview)
        root.addWidget(QLabel("Preview"))
        root.addWidget(self.preview_mode)

        self.metrics = QLabel("Metrics: -")
        self.metrics.setWordWrap(True)
        root.addWidget(self.metrics)
        root.addStretch(1)
        return scroll

    def current_roi(self) -> RoiSpec:
        return RoiSpec(
            name=self.roi_combo.currentText() or "manual",
            x=self.rx.value(),
            y=self.ry.value(),
            width=self.rw.value(),
            height=self.rh.value(),
            enabled=True,
            shape=self.roi_shape.currentText() or "rectangle",
            slant=self.rslant.value(),
        )

    def choose_project(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Open alignment/studio project", "", "JSON (*.json)")
        if path:
            self.open_project(Path(path))

    def open_project(self, path: Path) -> None:
        try:
            self.project = load_project(Path(path))
            self.project_path = Path(path)
            if self.project.reference_path:
                self.set_reference(Path(self.project.reference_path), update_status=False)
            self._rebuild_roi_combo()
            self._rebuild_layer_combo()
            self.status.setText(f"Project: {path}")
            self.update_preview()
        except Exception as exc:
            QMessageBox.critical(self, "Open project failed", str(exc))

    def choose_reference(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Reference/background image", "", IMAGE_FILTER)
        if path:
            self.set_reference(Path(path))

    def set_reference(self, path: Path, update_status: bool = True) -> None:
        image = Image.open(path).convert("RGBA")
        self.reference_image = image
        self.project.reference_path = str(Path(path).resolve())
        self.reference_item.setPixmap(pil_to_pixmap(image))
        self.scene.setSceneRect(0, 0, image.width, image.height)
        if not self.project.rois:
            self.project.rois = [RoiSpec("main", 0, 0, image.width, image.height)]
        if self.rw.value() <= 1 and self.rh.value() <= 1:
            self.rx.setValue(0)
            self.ry.setValue(0)
            self.rw.setValue(image.width)
            self.rh.setValue(image.height)
        if update_status:
            self.status.setText(f"Reference: {path}")
        self.fit_views()
        self.update_preview()

    def choose_external_source(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Source image to subtract", "", IMAGE_FILTER)
        if path:
            self.set_external_source(Path(path))

    def set_external_source(self, path: Path) -> None:
        self.external_source_path = Path(path)
        self.external_source_image = Image.open(path).convert("RGBA")
        self.source_mode.setCurrentText(SOURCE_EXTERNAL_IMAGE)
        self.reset_source_to_natural_size()
        self.status.setText(f"External source: {path}")
        self.update_preview()

    def _rebuild_roi_combo(self) -> None:
        self._updating = True
        self.roi_combo.clear()
        for index, roi in enumerate(self.project.rois):
            label = roi.name or f"roi_{index + 1}"
            if roi.shape == "parallelogram":
                label += " [para]"
            self.roi_combo.addItem(label, userData=index)
        self._updating = False
        if self.project.rois:
            self.roi_combo.setCurrentIndex(0)
            self.select_roi(0)

    def _rebuild_layer_combo(self) -> None:
        self._updating = True
        self.layer_combo.clear()
        for index, layer in enumerate(self.project.layers):
            self.layer_combo.addItem(f"[{layer.kind}] {layer.name}", userData=index)
        self._updating = False
        if self.project.layers:
            self.layer_combo.setCurrentIndex(0)

    def select_roi(self, index: int) -> None:
        if self._updating:
            return
        data = self.roi_combo.itemData(index)
        if data is None or not 0 <= int(data) < len(self.project.rois):
            return
        roi = self.project.rois[int(data)]
        self._updating = True
        self.roi_shape.setCurrentText(roi.shape if roi.shape in {"rectangle", "parallelogram"} else "rectangle")
        self.rx.setValue(roi.x)
        self.ry.setValue(roi.y)
        self.rw.setValue(roi.width)
        self.rh.setValue(roi.height)
        self.rslant.setValue(roi.slant)
        self._updating = False
        self.reset_source_to_roi()
        self.update_preview()

    def roi_controls_changed(self, *_args) -> None:
        if self._updating:
            return
        self._sync_roi_item()
        self.update_preview()

    def source_mode_changed(self, *_args) -> None:
        if self.source_mode.currentText() == SOURCE_PROJECT_VIRTUAL:
            self.reset_source_to_roi()
        elif self.source_mode.currentText() == SOURCE_SELECTED_LAYER:
            self.reset_source_to_natural_size()
        elif self.source_mode.currentText() == SOURCE_EXTERNAL_IMAGE and self.external_source_image:
            self.reset_source_to_natural_size()
        self.update_preview()

    def layer_source_changed(self, *_args) -> None:
        if self.source_mode.currentText() == SOURCE_SELECTED_LAYER:
            self.reset_source_to_natural_size()
        self.update_preview()

    def reset_source_to_roi(self) -> None:
        self._updating = True
        self.sx.setValue(0)
        self.sy.setValue(0)
        self.sw.setValue(max(1, self.rw.value()))
        self.sh.setValue(max(1, self.rh.value()))
        self._updating = False
        self.update_preview()

    def reset_source_to_natural_size(self) -> None:
        width, height = self._natural_source_size()
        self._updating = True
        self.sx.setValue(0)
        self.sy.setValue(0)
        self.sw.setValue(max(1, width))
        self.sh.setValue(max(1, height))
        self._updating = False
        self.update_preview()

    def _natural_source_size(self) -> tuple[int, int]:
        mode = self.source_mode.currentText()
        if mode == SOURCE_SELECTED_LAYER:
            layer = self._selected_layer()
            if layer:
                return layer.width, layer.height
        if mode == SOURCE_EXTERNAL_IMAGE and self.external_source_image:
            return self.external_source_image.size
        return max(1, self.rw.value()), max(1, self.rh.value())

    def _selected_layer(self) -> LayerSpec | None:
        data = self.layer_combo.currentData()
        if data is None or not 0 <= int(data) < len(self.project.layers):
            return None
        return self.project.layers[int(data)]

    def _sync_roi_item(self) -> None:
        self.roi_item.update_shape(self.current_roi())

    def _reference_roi(self, roi: RoiSpec) -> tuple[Image.Image, Image.Image, tuple[int, int, int, int]]:
        if self.reference_image is None:
            raise ValueError("Reference/background image is not set")
        box = _roi_box(roi)
        ref = _crop_with_fill(self.reference_image, box, fill=(0, 0, 0, 255))
        mask = _roi_mask(roi, box)
        ref.putalpha(mask)
        return ref, mask, box

    def _raw_source_canvas(self, roi: RoiSpec, box: tuple[int, int, int, int]) -> Image.Image:
        width, height = max(1, box[2] - box[0]), max(1, box[3] - box[1])
        mode = self.source_mode.currentText()
        source_canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))

        if mode == SOURCE_PROJECT_VIRTUAL:
            if self.reference_image is None:
                return source_canvas
            virtual = render_virtual(self.project, self.reference_image.size)
            raw = _crop_with_fill(virtual, box)
            raw = raw.resize((max(1, self.sw.value()), max(1, self.sh.value())), Image.Resampling.LANCZOS)
            _paste_with_clip(source_canvas, raw, (self.sx.value(), self.sy.value()))
            return source_canvas

        if mode == SOURCE_SELECTED_LAYER:
            layer = self._selected_layer()
            if layer is None:
                return source_canvas
            raw = render_layer(layer).resize((max(1, self.sw.value()), max(1, self.sh.value())), Image.Resampling.LANCZOS)
            dest = (layer.x - box[0] + self.sx.value(), layer.y - box[1] + self.sy.value())
            _paste_with_clip(source_canvas, raw, dest)
            return source_canvas

        if mode == SOURCE_EXTERNAL_IMAGE:
            if self.external_source_image is None:
                return source_canvas
            raw = self.external_source_image.resize((max(1, self.sw.value()), max(1, self.sh.value())), Image.Resampling.LANCZOS)
            _paste_with_clip(source_canvas, raw, (self.sx.value(), self.sy.value()))
            return source_canvas

        return source_canvas

    def _adjusted_source_roi(self, roi: RoiSpec, box: tuple[int, int, int, int], mask: Image.Image) -> Image.Image:
        raw = self._raw_source_canvas(roi, box)
        adjusted = _apply_source_traits(
            raw,
            alpha_percent=self.alpha.value(),
            gain_percent=self.gain.value(),
            bias=self.bias.value(),
            gamma=self.gamma.value(),
            blur_radius=self.blur.value(),
            alpha_threshold=self.alpha_threshold.value(),
        )
        # Respect the ROI shape, especially parallelogram masks.
        alpha = Image.composite(adjusted.getchannel("A"), Image.new("L", adjusted.size, 0), mask)
        adjusted.putalpha(alpha)
        return adjusted

    def update_preview(self, *_args) -> None:
        if self._updating:
            return
        try:
            self._sync_roi_item()
            if self.reference_image is None:
                self.metrics.setText("Metrics: reference image is not set")
                return
            roi = self.current_roi()
            reference_roi, mask, box = self._reference_roi(roi)
            source_roi = self._adjusted_source_roi(roi, box, mask)
            source_roi = _apply_reference_color_filter(
                source_roi,
                reference_roi,
                enabled=self.use_color_filter.isChecked(),
                target_hex=self.target_color.text(),
                tolerance_percent=self.color_tolerance.value(),
                feather_radius=self.color_feather.value(),
            )
            outputs, metrics = _residual_images(
                reference_roi,
                source_roi,
                mask,
                use_alpha_weight=self.use_alpha_weight.isChecked(),
                display_gain=float(self.display_gain.value()),
            )
            outputs[PREVIEW_REFERENCE] = _apply_reference_preview_filter(
                reference_roi,
                enabled=self.use_color_filter.isChecked(),
                target_hex=self.target_color.text(),
                tolerance_percent=self.color_tolerance.value(),
                feather_radius=self.color_feather.value(),
            )
            self._last_outputs = outputs
            self._last_metrics = metrics
            selected = self.preview_mode.currentText() or PREVIEW_ABS
            preview = outputs.get(selected, outputs[PREVIEW_ABS])
            self.preview_item.setPixmap(pil_to_pixmap(preview))
            self.preview_scene.setSceneRect(0, 0, preview.width, preview.height)

            if self.show_overlay.isChecked():
                self.source_overlay_item.setPixmap(pil_to_pixmap(source_roi))
                self.source_overlay_item.setPos(box[0], box[1])
                self.source_overlay_item.setVisible(True)
            else:
                self.source_overlay_item.setVisible(False)

            self.metrics.setText(
                "Metrics\n"
                f"ROI pixels: {metrics['roi_pixels']:.0f}\n"
                f"Source pixels: {metrics['source_pixels']:.0f}\n"
                f"Mean abs: {metrics['mean_abs']:.3f}\n"
                f"Max abs: {metrics['max_abs']:.1f}\n"
                f"Mean alpha: {metrics['source_alpha_mean']:.3f}"
            )
        except Exception as exc:
            self.metrics.setText(f"Preview failed: {exc}")

    def choose_export(self) -> None:
        if not self._last_outputs:
            self.update_preview()
        directory = QFileDialog.getExistingDirectory(self, "Export current subtraction preview")
        if not directory:
            return
        try:
            out = Path(directory)
            out.mkdir(parents=True, exist_ok=True)
            name_map = {
                PREVIEW_REFERENCE: "reference_roi.png",
                PREVIEW_SOURCE: "adjusted_source_roi.png",
                PREVIEW_ABS: "residual_abs_roi.png",
                PREVIEW_SIGNED: "residual_signed_roi.png",
                PREVIEW_POSITIVE: "residual_positive_roi.png",
                PREVIEW_NEGATIVE: "residual_negative_roi.png",
                PREVIEW_CLEANED: "cleaned_minus_source_roi.png",
                PREVIEW_ALPHA: "source_alpha_roi.png",
                PREVIEW_OVERLAY: "overlay_roi.png",
            }
            for key, filename in name_map.items():
                if key in self._last_outputs:
                    self._last_outputs[key].save(out / filename)
            payload = {
                "project_path": str(self.project_path) if self.project_path else "",
                "reference_path": self.project.reference_path,
                "external_source_path": str(self.external_source_path) if self.external_source_path else "",
                "source_mode": self.source_mode.currentText(),
                "selected_layer": self.layer_combo.currentText(),
                "roi": asdict(self.current_roi()),
                "source_transform": {
                    "offset_x": self.sx.value(),
                    "offset_y": self.sy.value(),
                    "width": self.sw.value(),
                    "height": self.sh.value(),
                },
                "traits": {
                    "alpha_percent": self.alpha.value(),
                    "rgb_gain_percent": self.gain.value(),
                    "rgb_bias": self.bias.value(),
                    "gamma": self.gamma.value(),
                    "blur_radius": self.blur.value(),
                    "alpha_threshold": self.alpha_threshold.value(),
                    "use_alpha_weight": self.use_alpha_weight.isChecked(),
                    "display_gain": self.display_gain.value(),
                    "reference_color_filter_enabled": self.use_color_filter.isChecked(),
                    "reference_color_target": self.target_color.text(),
                    "reference_color_tolerance_percent": self.color_tolerance.value(),
                    "reference_color_feather_px": self.color_feather.value(),
                },
                "metrics": self._last_metrics,
            }
            (out / "subtraction_preview.json").write_text(
                json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            QMessageBox.information(self, "Export complete", f"Exported preview files to:\n{out}")
        except Exception as exc:
            QMessageBox.critical(self, "Export failed", str(exc))

    def fit_views(self) -> None:
        if not self.scene.sceneRect().isEmpty():
            self.view.fitInView(self.scene.sceneRect(), Qt.KeepAspectRatio)
        if not self.preview_scene.sceneRect().isEmpty():
            self.preview_view.fitInView(self.preview_scene.sceneRect(), Qt.KeepAspectRatio)

    def reset_views(self) -> None:
        self.view.resetTransform()
        self.preview_view.resetTransform()


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", nargs="?", type=Path, help="Template Alignment Studio/legacy JSON project")
    parser.add_argument("--reference", type=Path, help="Reference/background image")
    parser.add_argument("--source", type=Path, help="External source image to paste into ROI and subtract")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    app = QApplication(sys.argv)
    window = BackgroundSubtractorWindow(args.project, args.reference, args.source)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
