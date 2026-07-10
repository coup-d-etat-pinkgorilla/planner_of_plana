"""Visual inspector for production inventory-grid ROIs and composed templates."""

from __future__ import annotations

import argparse
import copy
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QAction, QImage, QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QComboBox,
    QFileDialog,
    QFormLayout,
    QFrame,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSpinBox,
    QSplitter,
    QToolBar,
    QVBoxLayout,
    QWidget,
)

from core.inventory_grid_matcher import DEFAULT_GRID_TEMPLATE
from tools.inventory_grid_match_inspector_model import (
    DEFAULT_CAPTURE_ROOT,
    REFERENCE_SLOT_SIZE,
    CaptureCase,
    InspectorExperiment,
    SlotRecord,
    aggregate_color_inspections,
    base_matching_config,
    discover_capture_cases,
    effective_matching_config,
    inspect_record_color,
    load_session,
    prepare_comparison,
    profile_catalog,
    rank_record,
    save_session,
    slot_records,
)


THUMBNAIL_HEIGHT = 118


def _rgb_array(image: Image.Image | np.ndarray) -> np.ndarray:
    if isinstance(image, Image.Image):
        return np.asarray(image.convert("RGB"), dtype=np.uint8)
    array = np.asarray(image, dtype=np.uint8)
    if array.ndim == 2:
        array = np.repeat(array[:, :, None], 3, axis=2)
    return np.ascontiguousarray(array[:, :, :3])


def _pixmap(image: Image.Image | np.ndarray, *, height: int = THUMBNAIL_HEIGHT) -> QPixmap:
    array = _rgb_array(image)
    h, w = array.shape[:2]
    qimage = QImage(array.data, w, h, int(array.strides[0]), QImage.Format_RGB888).copy()
    pixmap = QPixmap.fromImage(qimage)
    if height > 0:
        pixmap = pixmap.scaledToHeight(height, Qt.SmoothTransformation)
    return pixmap


def _ratio_box(crop_ratio: dict, size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = size
    return (
        int(round(width * float(crop_ratio.get("left", 0.0)))),
        int(round(height * float(crop_ratio.get("top", 0.0)))),
        int(round(width * (1.0 - float(crop_ratio.get("right", 0.0))))),
        int(round(height * (1.0 - float(crop_ratio.get("bottom", 0.0))))),
    )


class InteractiveSlotLabel(QLabel):
    sample_position_changed = Signal(int, int)

    def __init__(self) -> None:
        super().__init__()
        self.setAlignment(Qt.AlignCenter)
        self.setMinimumWidth(160)
        self._source_size = REFERENCE_SLOT_SIZE
        self._dragging = False

    def set_source_size(self, size: tuple[int, int]) -> None:
        self._source_size = size

    def _emit_position(self, event) -> None:
        if self.pixmap() is None or self.pixmap().isNull():
            return
        pm = self.pixmap()
        left = (self.width() - pm.width()) / 2.0
        top = (self.height() - pm.height()) / 2.0
        px = max(0.0, min(float(pm.width() - 1), event.position().x() - left))
        py = max(0.0, min(float(pm.height() - 1), event.position().y() - top))
        x = int(round(px * self._source_size[0] / max(1, pm.width())))
        y = int(round(py * self._source_size[1] / max(1, pm.height())))
        self.sample_position_changed.emit(x, y)

    def mousePressEvent(self, event) -> None:
        if event.button() == Qt.LeftButton:
            self._dragging = True
            self._emit_position(event)
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event) -> None:
        if self._dragging:
            self._emit_position(event)
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event) -> None:
        self._dragging = False
        super().mouseReleaseEvent(event)


class SlotRowWidget(QFrame):
    def __init__(self, window: "InspectorWindow", record: SlotRecord) -> None:
        super().__init__()
        self.window = window
        self.record = record
        self.catalog = window.catalog
        self.catalog_by_id = dict(self.catalog)
        self.setFrameShape(QFrame.StyledPanel)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(6, 6, 6, 6)
        self.meta = QLabel()
        self.meta.setFixedWidth(135)
        self.original = InteractiveSlotLabel()
        self.original.sample_position_changed.connect(window.place_sample_box)
        self.screen = QLabel(alignment=Qt.AlignCenter)
        self.template = QLabel(alignment=Qt.AlignCenter)
        self.diff = QLabel(alignment=Qt.AlignCenter)
        self.color_patch = QLabel(alignment=Qt.AlignCenter)
        for label in (self.original, self.screen, self.template, self.diff, self.color_patch):
            label.setMinimumHeight(THUMBNAIL_HEIGHT + 8)

        controls = QWidget()
        controls_layout = QVBoxLayout(controls)
        controls_layout.setContentsMargins(4, 0, 0, 0)
        self.candidate = QComboBox()
        self.candidate.setEditable(True)
        self.candidate.setInsertPolicy(QComboBox.NoInsert)
        for item_id, _path in self.catalog:
            self.candidate.addItem(item_id, item_id)
        saved = window.experiment.selected_candidates.get(record.key)
        default_id = saved or self._default_item_id()
        if default_id:
            index = self.candidate.findData(default_id)
            if index >= 0:
                self.candidate.setCurrentIndex(index)
        self.candidate.currentIndexChanged.connect(self._candidate_changed)
        best = QPushButton("최고 후보 계산")
        best.clicked.connect(self.rank_candidates)
        self.score = QLabel()
        self.score.setTextInteractionFlags(Qt.TextSelectableByMouse)
        controls_layout.addWidget(self.candidate)
        controls_layout.addWidget(best)
        controls_layout.addWidget(self.score)
        controls_layout.addStretch(1)

        layout.addWidget(self.meta)
        layout.addWidget(self._column("원본+ROI", self.original))
        layout.addWidget(self._column("최종 Screen ROI", self.screen))
        layout.addWidget(self._column("최종 합성 템플릿", self.template))
        layout.addWidget(self._column("Difference", self.diff))
        layout.addWidget(self._column("색상 샘플", self.color_patch))
        layout.addWidget(controls, 1)
        self.refresh()

    @staticmethod
    def _column(title: str, label: QLabel) -> QWidget:
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(2, 0, 2, 0)
        heading = QLabel(title, alignment=Qt.AlignCenter)
        heading.setStyleSheet("color:#667085")
        layout.addWidget(heading)
        layout.addWidget(label)
        return widget

    def _default_item_id(self) -> str | None:
        if self.record.frame.case.profile_id == "activity_reports" and self.record.slot_index < 4:
            return f"Item_Icon_ExpItem_{self.record.slot_index}"
        return self.catalog[0][0] if self.catalog else None

    def _candidate_changed(self) -> None:
        item_id = self.current_item_id()
        if item_id:
            self.window.experiment.selected_candidates[self.record.key] = item_id
        self.refresh()

    def current_item_id(self) -> str | None:
        return self.candidate.currentData() or self.candidate.currentText().strip() or None

    def rank_candidates(self) -> None:
        if not self.catalog:
            return
        QApplication.setOverrideCursor(Qt.WaitCursor)
        try:
            ranked = rank_record(self.record, self.catalog, self.window.effective_config)
        finally:
            QApplication.restoreOverrideCursor()
        current = self.current_item_id()
        self.candidate.blockSignals(True)
        self.candidate.clear()
        for item_id, score in ranked:
            self.candidate.addItem(f"{score:.4f}  {item_id}", item_id)
        index = self.candidate.findData(current)
        self.candidate.setCurrentIndex(index if index >= 0 else 0)
        self.candidate.blockSignals(False)
        self._candidate_changed()

    def _annotated_slot(self, inspection) -> Image.Image:
        image = self.record.slot_crop.copy().convert("RGB")
        draw = ImageDraw.Draw(image)
        crop = self.window.effective_config.get("crop_ratio", DEFAULT_GRID_TEMPLATE["crop_ratio"])
        draw.rectangle(_ratio_box(crop, image.size), outline=(0, 220, 255), width=2)
        tier = self.window.effective_config.get("tier_hint", {})
        search = tier.get("sample_search_box")
        if isinstance(search, dict):
            sx = image.width / float(tier.get("reference_width", REFERENCE_SLOT_SIZE[0]))
            sy = image.height / float(tier.get("reference_height", REFERENCE_SLOT_SIZE[1]))
            box = (
                round(float(search.get("x", 0)) * sx),
                round(float(search.get("y", 0)) * sy),
                round((float(search.get("x", 0)) + float(search.get("width", 1))) * sx),
                round((float(search.get("y", 0)) + float(search.get("height", 1))) * sy),
            )
            draw.rectangle(box, outline=(255, 160, 0), width=2)
        if inspection.sample_box:
            draw.rectangle(inspection.sample_box, outline=(30, 220, 70), width=2)
        return image

    def refresh(self) -> None:
        item_id = self.current_item_id()
        phase = self.record.frame.phase
        self.meta.setText(
            f"{phase.upper()}\n{self.record.frame.case.label}\n"
            f"Slot {self.record.slot_index + 1:02d}\n"
            f"dy={self.record.frame.y_offset_px:+d}px\n"
            f"{'ACTIVE' if self.record.is_active else 'OVERLAP'}"
        )
        inspection = inspect_record_color(self.record, self.window.effective_config)
        annotated = self._annotated_slot(inspection)
        self.original.setPixmap(_pixmap(annotated))
        self.original.set_source_size(self.record.slot_crop.size)
        if not item_id or item_id not in self.catalog_by_id:
            self.score.setText("후보 템플릿 없음")
            return

        path = self.catalog_by_id[item_id]
        production = prepare_comparison(
            self.record,
            item_id,
            path,
            self.window.base_config,
            mode=self.window.match_mode,
            catalog=self.catalog,
        )
        experiment = prepare_comparison(
            self.record,
            item_id,
            path,
            self.window.effective_config,
            mode=self.window.match_mode,
            catalog=self.catalog,
        )
        if experiment is None:
            self.score.setText("합성 템플릿 생성 실패")
            return
        self.screen.setPixmap(_pixmap(experiment.screen_image))
        self.template.setPixmap(_pixmap(experiment.template_image))
        left = experiment.screen_image
        right = experiment.template_image
        if left.shape != right.shape:
            right = np.asarray(Image.fromarray(right).resize((left.shape[1], left.shape[0])))
        difference = np.abs(left.astype(np.int16) - right.astype(np.int16)).astype(np.uint8)
        self.diff.setPixmap(_pixmap(difference))

        if inspection.sample_box:
            patch = self.record.slot_crop.crop(inspection.sample_box)
            self.color_patch.setPixmap(_pixmap(patch, height=70))
        else:
            self.color_patch.clear()

        pscore = production.similarity.combined_score if production else float("nan")
        escore = experiment.similarity.combined_score
        rgb = inspection.median_rgb
        rgb_text = "-" if rgb is None else ",".join(str(int(round(v))) for v in rgb)
        distance = inspection.distances[0][1] if inspection.distances else None
        self.score.setText(
            f"경로: {experiment.mode}\n"
            f"Production: {pscore:.4f}\nExperiment: {escore:.4f}\n"
            f"NCC {experiment.similarity.ncc_score:.4f} / Pixel {experiment.similarity.pixel_diff_score:.4f}\n"
            f"Tier {inspection.tier_hint} conf={inspection.confidence:.3f}\n"
            f"RGB({rgb_text}) dist={'-' if distance is None else f'{distance:.2f}'} margin={inspection.distance_margin:.2f}"
        )


class InspectorWindow(QMainWindow):
    def __init__(self, capture_root: Path = DEFAULT_CAPTURE_ROOT) -> None:
        super().__init__()
        self.setWindowTitle("Inventory Grid Match Inspector")
        self.resize(1880, 1040)
        self.capture_root = Path(capture_root)
        self.cases: list[CaptureCase] = []
        self.current_case: CaptureCase | None = None
        self.records: list[SlotRecord] = []
        self.rows: list[SlotRowWidget] = []
        self.experiment = InspectorExperiment()
        self.base_config: dict = {}
        self.effective_config: dict = {}
        self.catalog: list[tuple[str, str]] = []
        self._loading_controls = False

        self._build_ui()
        self.reload_cases()

    @property
    def match_mode(self) -> str:
        return str(self.mode_combo.currentData() or "production")

    def _build_ui(self) -> None:
        toolbar = QToolBar("Inspector")
        self.addToolBar(toolbar)
        for text, callback in (
            ("캡처 루트", self.choose_root),
            ("새로 고침", self.reload_cases),
            ("세션 열기", self.open_session),
            ("세션 저장", self.save_session_dialog),
            ("Production 초기화", self.reset_production),
        ):
            action = QAction(text, self)
            action.triggered.connect(callback)
            toolbar.addAction(action)

        top = QWidget()
        top_layout = QHBoxLayout(top)
        self.profile_combo = QComboBox()
        self.case_combo = QComboBox()
        self.phase_combo = QComboBox()
        self.phase_combo.addItem("Before", "before")
        self.phase_combo.addItem("After", "after")
        self.phase_combo.addItem("Both", "both")
        self.mode_combo = QComboBox()
        self.mode_combo.addItem("Production auto", "production")
        self.mode_combo.addItem("Composite", "composite")
        self.mode_combo.addItem("Direct icon", "direct_icon")
        self.active_only = QCheckBox("신규/활성 슬롯만")
        for label, widget in (
            ("프로필", self.profile_combo),
            ("캡처", self.case_combo),
            ("화면", self.phase_combo),
            ("경로", self.mode_combo),
        ):
            top_layout.addWidget(QLabel(label))
            top_layout.addWidget(widget)
        top_layout.addWidget(self.active_only)
        top_layout.addStretch(1)
        self.root_label = QLabel()
        top_layout.addWidget(self.root_label)

        self.list_container = QWidget()
        self.list_layout = QVBoxLayout(self.list_container)
        self.list_layout.setAlignment(Qt.AlignTop)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(self.list_container)

        right = self._controls_panel()
        splitter = QSplitter()
        left = QWidget()
        left_layout = QVBoxLayout(left)
        left_layout.setContentsMargins(0, 0, 0, 0)
        left_layout.addWidget(top)
        left_layout.addWidget(scroll, 1)
        splitter.addWidget(left)
        splitter.addWidget(right)
        splitter.setSizes([1530, 350])
        self.setCentralWidget(splitter)

        self.profile_combo.currentIndexChanged.connect(self._profile_changed)
        self.case_combo.currentIndexChanged.connect(self._case_changed)
        self.phase_combo.currentIndexChanged.connect(self.rebuild_rows)
        self.mode_combo.currentIndexChanged.connect(self.refresh_rows)
        self.active_only.toggled.connect(self.rebuild_rows)

    def _controls_panel(self) -> QWidget:
        panel = QWidget()
        root = QVBoxLayout(panel)
        roi_group = QGroupBox("Composite ROI (기준 234×190)")
        roi_form = QFormLayout(roi_group)
        self.roi_left = self._spin(0, REFERENCE_SLOT_SIZE[0] - 1)
        self.roi_right = self._spin(0, REFERENCE_SLOT_SIZE[0] - 1)
        self.roi_top = self._spin(0, REFERENCE_SLOT_SIZE[1] - 1)
        self.roi_bottom = self._spin(0, REFERENCE_SLOT_SIZE[1] - 1)
        for label, widget in (
            ("Left px", self.roi_left),
            ("Right px", self.roi_right),
            ("Top px", self.roi_top),
            ("Bottom px", self.roi_bottom),
        ):
            roi_form.addRow(label, widget)
            widget.valueChanged.connect(self._roi_changed)
        root.addWidget(roi_group)

        color_group = QGroupBox("색상 Sample/Search")
        color_form = QFormLayout(color_group)
        self.tier_enabled = QCheckBox("측정 활성화")
        self.fixed_sample = QCheckBox("Fixed sample")
        self.sample_x = self._spin(0, REFERENCE_SLOT_SIZE[0] - 1)
        self.sample_y = self._spin(0, REFERENCE_SLOT_SIZE[1] - 1)
        self.sample_w = self._spin(1, REFERENCE_SLOT_SIZE[0])
        self.sample_h = self._spin(1, REFERENCE_SLOT_SIZE[1])
        self.search_x = self._spin(0, REFERENCE_SLOT_SIZE[0] - 1)
        self.search_y = self._spin(0, REFERENCE_SLOT_SIZE[1] - 1)
        self.search_w = self._spin(1, REFERENCE_SLOT_SIZE[0])
        self.search_h = self._spin(1, REFERENCE_SLOT_SIZE[1])
        self.stride = self._spin(1, 100)
        color_form.addRow(self.tier_enabled)
        color_form.addRow(self.fixed_sample)
        for label, widget in (
            ("Sample X", self.sample_x),
            ("Sample Y", self.sample_y),
            ("Sample W", self.sample_w),
            ("Sample H", self.sample_h),
            ("Search X", self.search_x),
            ("Search Y", self.search_y),
            ("Search W", self.search_w),
            ("Search H", self.search_h),
            ("Stride", self.stride),
        ):
            color_form.addRow(label, widget)
            widget.valueChanged.connect(self._color_changed)
        self.tier_enabled.toggled.connect(self._color_changed)
        self.fixed_sample.toggled.connect(self._color_changed)
        nudge = QWidget()
        nudge_layout = QGridLayout(nudge)
        for text, dx, dy, row, col in (
            ("↑", 0, -1, 0, 1),
            ("←", -1, 0, 1, 0),
            ("→", 1, 0, 1, 2),
            ("↓", 0, 1, 2, 1),
        ):
            button = QPushButton(text)
            button.clicked.connect(lambda _checked=False, x=dx, y=dy: self.nudge_sample(x, y))
            nudge_layout.addWidget(button, row, col)
        color_form.addRow("1px 이동", nudge)
        root.addWidget(color_group)

        self.aggregate = QLabel()
        self.aggregate.setWordWrap(True)
        self.aggregate.setTextInteractionFlags(Qt.TextSelectableByMouse)
        root.addWidget(QLabel("현재 목록 색상 집계"))
        root.addWidget(self.aggregate)
        root.addStretch(1)
        return panel

    @staticmethod
    def _spin(minimum: int, maximum: int) -> QSpinBox:
        spin = QSpinBox()
        spin.setRange(minimum, maximum)
        spin.setKeyboardTracking(False)
        return spin

    def choose_root(self) -> None:
        path = QFileDialog.getExistingDirectory(self, "캡처 루트", str(self.capture_root))
        if path:
            self.capture_root = Path(path)
            self.reload_cases()

    def reload_cases(self) -> None:
        self.cases = discover_capture_cases(self.capture_root)
        profiles = sorted({case.profile_id for case in self.cases})
        current = self.profile_combo.currentText()
        self.profile_combo.blockSignals(True)
        self.profile_combo.clear()
        self.profile_combo.addItems(profiles)
        index = self.profile_combo.findText(current)
        self.profile_combo.setCurrentIndex(index if index >= 0 else 0)
        self.profile_combo.blockSignals(False)
        self.root_label.setText(str(self.capture_root))
        self._profile_changed()

    def _profile_changed(self) -> None:
        profile = self.profile_combo.currentText()
        cases = [case for case in self.cases if case.profile_id == profile]
        self.case_combo.blockSignals(True)
        self.case_combo.clear()
        for case in cases:
            self.case_combo.addItem(case.label, case)
        self.case_combo.blockSignals(False)
        self._case_changed()

    def _case_changed(self) -> None:
        case = self.case_combo.currentData()
        self.current_case = case if isinstance(case, CaptureCase) else None
        if self.current_case is None:
            self.rebuild_rows()
            return
        self.base_config = base_matching_config(self.current_case.source, self.current_case.profile_id)
        self.catalog = profile_catalog(self.current_case.source, self.current_case.profile_id)
        self._load_controls_from_config()
        self.rebuild_rows()

    def _resolved_config(self, config: dict) -> dict:
        merged = copy.deepcopy(DEFAULT_GRID_TEMPLATE)
        for key, value in config.items():
            if isinstance(value, dict) and isinstance(merged.get(key), dict):
                nested = copy.deepcopy(merged[key])
                nested.update(copy.deepcopy(value))
                merged[key] = nested
            else:
                merged[key] = copy.deepcopy(value)
        return merged

    def _load_controls_from_config(self) -> None:
        config = self._resolved_config(self.base_config)
        crop = config["crop_ratio"]
        tier = config["tier_hint"]
        sample = tier["sample_box"]
        search = tier["sample_search_box"]
        self._loading_controls = True
        try:
            self.roi_left.setValue(round(float(crop["left"]) * REFERENCE_SLOT_SIZE[0]))
            self.roi_right.setValue(round(float(crop["right"]) * REFERENCE_SLOT_SIZE[0]))
            self.roi_top.setValue(round(float(crop["top"]) * REFERENCE_SLOT_SIZE[1]))
            self.roi_bottom.setValue(round(float(crop["bottom"]) * REFERENCE_SLOT_SIZE[1]))
            self.tier_enabled.setChecked(bool(tier.get("enabled", True)))
            self.fixed_sample.setChecked(False)
            for widget, key in ((self.sample_x, "x"), (self.sample_y, "y"), (self.sample_w, "width"), (self.sample_h, "height")):
                widget.setValue(round(float(sample[key])))
            for widget, key in ((self.search_x, "x"), (self.search_y, "y"), (self.search_w, "width"), (self.search_h, "height")):
                widget.setValue(round(float(search[key])))
            self.stride.setValue(round(float(tier.get("sample_stride", 1))))
        finally:
            self._loading_controls = False
        self._sync_experiment_from_controls()

    def _sync_experiment_from_controls(self) -> None:
        width, height = REFERENCE_SLOT_SIZE
        self.experiment.crop_ratio = {
            "left": self.roi_left.value() / width,
            "right": self.roi_right.value() / width,
            "top": self.roi_top.value() / height,
            "bottom": self.roi_bottom.value() / height,
        }
        self.experiment.tier_enabled = self.tier_enabled.isChecked()
        self.experiment.fixed_sample = self.fixed_sample.isChecked()
        self.experiment.sample_box = {
            "x": self.sample_x.value(),
            "y": self.sample_y.value(),
            "width": self.sample_w.value(),
            "height": self.sample_h.value(),
        }
        self.experiment.sample_search_box = {
            "x": self.search_x.value(),
            "y": self.search_y.value(),
            "width": self.search_w.value(),
            "height": self.search_h.value(),
        }
        self.experiment.sample_stride = self.stride.value()
        self.effective_config = effective_matching_config(self.base_config, self.experiment)

    def _roi_changed(self) -> None:
        if self._loading_controls:
            return
        self._sync_experiment_from_controls()
        self.refresh_rows()

    def _color_changed(self) -> None:
        if self._loading_controls:
            return
        self._sync_experiment_from_controls()
        self.refresh_rows()

    def nudge_sample(self, dx: int, dy: int) -> None:
        self.sample_x.setValue(self.sample_x.value() + dx)
        self.sample_y.setValue(self.sample_y.value() + dy)
        if not self.fixed_sample.isChecked():
            self.search_x.setValue(self.search_x.value() + dx)
            self.search_y.setValue(self.search_y.value() + dy)

    def place_sample_box(self, x: int, y: int) -> None:
        self.sample_x.setValue(max(0, x - self.sample_w.value() // 2))
        self.sample_y.setValue(max(0, y - self.sample_h.value() // 2))
        if not self.fixed_sample.isChecked():
            self.search_x.setValue(max(0, x - self.search_w.value() // 2))
            self.search_y.setValue(max(0, y - self.search_h.value() // 2))

    def _clear_rows(self) -> None:
        while self.list_layout.count():
            item = self.list_layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()
        self.rows.clear()

    def rebuild_rows(self) -> None:
        self._clear_rows()
        if self.current_case is None:
            self.records = []
            self.aggregate.clear()
            return
        try:
            self.records = slot_records(self.current_case, str(self.phase_combo.currentData() or "before"))
        except Exception as exc:
            QMessageBox.critical(self, "캡처 로드 실패", str(exc))
            self.records = []
            return
        if self.active_only.isChecked():
            self.records = [record for record in self.records if record.is_active]
        for record in self.records:
            row = SlotRowWidget(self, record)
            self.rows.append(row)
            self.list_layout.addWidget(row)
        self._refresh_aggregate()

    def refresh_rows(self) -> None:
        for row in self.rows:
            row.refresh()
        self._refresh_aggregate()

    def _refresh_aggregate(self) -> None:
        summary = aggregate_color_inspections(self.records, self.effective_config) if self.records else {}
        if not summary:
            self.aggregate.clear()
            return
        self.aggregate.setText(
            f"전체 {summary['total']} / 측정 {summary['sampled']} / 인식 {summary['recognized']} / unknown {summary['unknown']}\n"
            f"최악 거리: {summary['worst_distance']}\n최소 margin: {summary['minimum_margin']}\n"
            f"최악 슬롯: {', '.join(summary['worst_slots'])}"
        )

    def reset_production(self) -> None:
        selected = dict(self.experiment.selected_candidates)
        self.experiment = InspectorExperiment(selected_candidates=selected)
        self._load_controls_from_config()
        self.rebuild_rows()

    def save_session_dialog(self) -> None:
        session_dir = self.capture_root / "inspector_sessions"
        path, _filter = QFileDialog.getSaveFileName(
            self,
            "실험 세션 저장",
            str(session_dir / f"{self.profile_combo.currentText() or 'session'}.json"),
            "JSON (*.json)",
        )
        if path:
            save_session(Path(path), self.capture_root, self.profile_combo.currentText(), self.experiment)

    def open_session(self) -> None:
        path, _filter = QFileDialog.getOpenFileName(self, "실험 세션 열기", str(self.capture_root), "JSON (*.json)")
        if not path:
            return
        try:
            capture_root, profile_id, experiment = load_session(Path(path))
        except Exception as exc:
            QMessageBox.critical(self, "세션 로드 실패", str(exc))
            return
        self.capture_root = capture_root
        self.reload_cases()
        index = self.profile_combo.findText(profile_id)
        if index >= 0:
            self.profile_combo.setCurrentIndex(index)
        self.experiment = experiment
        self._apply_experiment_to_controls()
        self.rebuild_rows()

    def _apply_experiment_to_controls(self) -> None:
        exp = self.experiment
        self._loading_controls = True
        try:
            if exp.crop_ratio:
                self.roi_left.setValue(round(exp.crop_ratio["left"] * REFERENCE_SLOT_SIZE[0]))
                self.roi_right.setValue(round(exp.crop_ratio["right"] * REFERENCE_SLOT_SIZE[0]))
                self.roi_top.setValue(round(exp.crop_ratio["top"] * REFERENCE_SLOT_SIZE[1]))
                self.roi_bottom.setValue(round(exp.crop_ratio["bottom"] * REFERENCE_SLOT_SIZE[1]))
            if exp.tier_enabled is not None:
                self.tier_enabled.setChecked(exp.tier_enabled)
            self.fixed_sample.setChecked(exp.fixed_sample)
            if exp.sample_box:
                self.sample_x.setValue(round(exp.sample_box["x"]))
                self.sample_y.setValue(round(exp.sample_box["y"]))
                self.sample_w.setValue(round(exp.sample_box["width"]))
                self.sample_h.setValue(round(exp.sample_box["height"]))
            if exp.sample_search_box:
                self.search_x.setValue(round(exp.sample_search_box["x"]))
                self.search_y.setValue(round(exp.sample_search_box["y"]))
                self.search_w.setValue(round(exp.sample_search_box["width"]))
                self.search_h.setValue(round(exp.sample_search_box["height"]))
            if exp.sample_stride is not None:
                self.stride.setValue(round(exp.sample_stride))
        finally:
            self._loading_controls = False
        self._sync_experiment_from_controls()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-root", type=Path, default=DEFAULT_CAPTURE_ROOT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    app = QApplication.instance() or QApplication(sys.argv)
    window = InspectorWindow(args.capture_root)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
