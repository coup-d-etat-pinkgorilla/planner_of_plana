"""Design-only widget gallery and runtime-structure inspector for BA Planner.

The gallery edits isolated samples.  Actual-size previews may create an
off-screen, design-mode ``StudentViewerWindow`` so unique production sections
can be detached with their complete child hierarchy intact.
"""

from __future__ import annotations

import argparse
from dataclasses import replace
import html
import importlib
import math
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PySide6.QtCore import (
    QEasingCurve,
    QEvent,
    QObject,
    QPoint,
    QPointF,
    QParallelAnimationGroup,
    QPropertyAnimation,
    QRect,
    QRectF,
    QSize,
    QSequentialAnimationGroup,
    QTimer,
    QUrl,
    Qt,
)
from PySide6.QtGui import QColor, QDesktopServices, QKeySequence, QPainter, QPainterPath, QPen, QPixmap, QRegion, QShortcut, QTextDocument
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QColorDialog,
    QComboBox,
    QDoubleSpinBox,
    QFormLayout,
    QFrame,
    QGridLayout,
    QGroupBox,
    QHeaderView,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPlainTextEdit,
    QProgressBar,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QSpinBox,
    QSplitter,
    QTabWidget,
    QTableWidget,
    QTableWidgetItem,
    QTreeWidget,
    QTreeWidgetItem,
    QVBoxLayout,
    QWidget,
)
from PySide6.QtWebEngineWidgets import QWebEngineView

from gui.diagonal_shape import diagonal_shape_path
from gui.ui_design_spec import (
    ComponentOverride,
    DEFAULT_PALETTE,
    DiagonalShapeSpec,
    GalleryStyleSpec,
    SUPPORTED_WIDGET_TYPES,
    UIDesignSpec,
    UI_DESIGN_SPEC_PATH,
    load_ui_design_spec,
    save_ui_design_spec,
)


UI_DESIGN_DRAFT_PATH = ROOT / "debug" / "ui_studio_design_draft.json"
UI_BEHAVIOR_DOCS_DIR = ROOT / "docs" / "ui-behavior"
MERMAID_BROWSER_BUNDLE = ROOT / "tools" / "vendor" / "mermaid" / "mermaid.min.js"
_STUDIO_RENDER_ENABLED_PROPERTY = "uiStudioRenderEnabled"
_STUDIO_RENDER_ORIGINAL_HIDDEN_PROPERTY = "uiStudioRenderOriginalHidden"
_STUDIO_RENDER_ORIGINAL_RETAIN_PROPERTY = "uiStudioRenderOriginalRetain"
_GALLERY_COLUMNS = {"widgets": 2, "sections": 2}
_RUNTIME_THUMBNAIL_CACHE: dict[tuple[str, str, str], QPixmap] = {}
_HOT_RELOAD_VISUAL_MODULES = (
    "gui.triangle_texture",
    "gui.diagonal_scroll_list",
    "gui.viewer_shared",
    "gui.viewer_components.home",
    "gui.viewer_components.scan",
    "gui.viewer_components.students",
    "gui.viewer_components.resources",
    "gui.viewer_components.inventory",
    "gui.viewer_components.raid",
    "gui.viewer_components.tactical",
    "gui.viewer_components.statistics",
    "gui.viewer_components.planner",
    "gui.viewer_components.window",
    "gui.viewer_app_qt",
)
_RUNTIME_SECTION_TARGETS = {
    "section:scanHeaderSection": ("_scan_header_section", None, "student"),
    "section:homeConnectionSection": ("_home_connection_panel", "_home_right_host", None),
    "section:homeSettingsSection": ("_home_settings_panel", "_home_center_host", None),
    "section:scanDebugSection": ("_scan_debug_section", None, "student"),
    "section:scanMirrorSection": ("_scan_mirror_section", None, "student"),
    "section:scanStudentMirrorSection": ("_scan_student_card", None, "student"),
    "section:scanInventoryGridMirrorSection": ("_scan_inventory_card", None, "inventory"),
    "section:scanWorkSection": ("_scan_right_section", None, "student"),
    "section:scanProgressSection": ("_scan_progress_section", None, "student"),
    "section:scanPreviewSection": ("_scan_preview_section", None, "student"),
    "section:scanResultSection": ("_scan_result_section", None, "student"),
}


def _discard_module_bytecode(module_name: str, module=None) -> None:
    cached_path = getattr(module, "__cached__", None) if module is not None else None
    if cached_path is None:
        module_spec = importlib.util.find_spec(module_name)
        cached_path = getattr(module_spec, "cached", None)
    if cached_path:
        Path(cached_path).unlink(missing_ok=True)


def _reload_visual_modules(*, reload_studio: bool = True) -> tuple[str, ...]:
    """Reload visual dependencies and the running Studio sample factories."""
    reloaded: list[str] = []
    _RUNTIME_THUMBNAIL_CACHE.clear()
    importlib.invalidate_caches()
    for module_name in _HOT_RELOAD_VISUAL_MODULES:
        module = sys.modules.get(module_name)
        # Timestamp-based pyc validation has one-second granularity. UCS is
        # often refreshed several times inside that window, and same-size
        # source edits can otherwise resurrect the previous bytecode.
        _discard_module_bytecode(module_name, module)
        if module is None:
            module = importlib.import_module(module_name)
        else:
            module = importlib.reload(module)
        reloaded.append(module.__name__)
    if reload_studio:
        running_module = sys.modules[__name__]
        module_spec = getattr(running_module, "__spec__", None)
        canonical_name = getattr(module_spec, "name", None) or __name__
        # ``python -m tools.ui_component_studio`` registers the live module as
        # __main__. Alias that exact object before reload so sample factories
        # update without constructing a second Studio module or window.
        sys.modules[canonical_name] = running_module
        _discard_module_bytecode(canonical_name, running_module)
        importlib.reload(running_module)
        reloaded.append(canonical_name)
    return tuple(reloaded)

_SECTION_GALLERY_STYLES = (
    GalleryStyleSpec("section:homeMenuSection", "홈 · 메뉴 섹션", "QFrame"),
    GalleryStyleSpec("section:homeConnectionSection", "홈 · 연결 섹션", "QFrame"),
    GalleryStyleSpec("section:homeScanSection", "홈 · 스캔 섹션", "QFrame"),
    GalleryStyleSpec("section:homeSettingsSection", "홈 · 설정 섹션", "QFrame"),
    GalleryStyleSpec("section:homeItemCategorySection", "홈 · 아이템 범위 섹션", "QFrame"),
    GalleryStyleSpec("section:homeResourcePromptSection", "홈 · 자원 입력 섹션", "QFrame"),
    GalleryStyleSpec("section:scanHeaderSection", "스캔 · 헤더 섹션", "QFrame"),
    GalleryStyleSpec("section:scanDebugSection", "스캔 · 디버그 메시지", "QFrame"),
    GalleryStyleSpec("section:scanMirrorSection", "스캔 · 결과 미러 컨테이너", "QFrame"),
    GalleryStyleSpec("section:scanStudentMirrorSection", "스캔 · 학생 결과 미러", "QFrame"),
    GalleryStyleSpec("section:scanInventoryGridMirrorSection", "스캔 · 그리드 결과 미러", "QFrame"),
    GalleryStyleSpec("section:scanWorkSection", "스캔 · 캡처 작업 섹션", "QFrame"),
    GalleryStyleSpec("section:scanProgressSection", "스캔 · 진행률 섹션", "QFrame"),
    GalleryStyleSpec("section:scanPreviewSection", "스캔 · 캡처 미리보기 섹션", "QFrame"),
    GalleryStyleSpec("section:scanResultSection", "스캔 · 완료 결과 섹션", "QFrame"),
    GalleryStyleSpec("section:standardPanel", "공통 · 표준 패널", "QFrame"),
    GalleryStyleSpec("section:planBand", "플랜 · 정보 밴드", "QFrame"),
    GalleryStyleSpec("section:planEditorSectionCard", "플랜 · 편집 섹션", "QFrame"),
    GalleryStyleSpec("section:planEditorContentPanel", "플랜 · 콘텐츠 패널", "QFrame"),
    GalleryStyleSpec("section:statisticsPanel", "통계 · 분석 패널", "QFrame"),
    GalleryStyleSpec("section:studentFilterBar", "학생 · 필터 바", "QFrame"),
    GalleryStyleSpec("section:studentGroupSelector", "학생 · 그룹 선택기", "QFrame"),
    GalleryStyleSpec("section:trainingTargetEditor", "목표 · 육성 목표 편집기", "QFrame"),
    GalleryStyleSpec("section:targetPresetSelector", "목표 · 프리셋 선택기", "QFrame"),
    GalleryStyleSpec("section:trainingMilestoneEditor", "목표 · 마일스톤 편집기", "QFrame"),
    GalleryStyleSpec("section:bulkTargetApplyPanel", "목표 · 일괄 적용 패널", "QFrame"),
    GalleryStyleSpec("section:planGroupCard", "계획 · 그룹 카드", "QFrame"),
    GalleryStyleSpec("section:priorityList", "계획 · 우선순위 목록", "QFrame"),
    GalleryStyleSpec("section:scenarioCompareCard", "계획 · 시나리오 비교", "QFrame"),
    GalleryStyleSpec("section:resourceRequirementTable", "재화 · 요구량 표", "QFrame"),
    GalleryStyleSpec("section:resourceUsagePanel", "재화 · 사용처 패널", "QFrame"),
    GalleryStyleSpec("section:resourceCategorySummary", "재화 · 카테고리 요약", "QFrame"),
    GalleryStyleSpec("section:currentVsTargetPanel", "비교 · 현재/목표", "QFrame"),
    GalleryStyleSpec("section:incrementalCostPanel", "분석 · 증분 비용", "QFrame"),
    GalleryStyleSpec("section:bottleneckPanel", "분석 · 병목 패널", "QFrame"),
    GalleryStyleSpec("section:conflictAlertPanel", "분석 · 충돌 경고", "QFrame"),
    GalleryStyleSpec("section:scanStatusCard", "데이터 · 스캔 상태", "QFrame"),
    GalleryStyleSpec("section:anomalyList", "데이터 · 이상 변화 목록", "QFrame"),
    GalleryStyleSpec("section:detailDrawer", "공통 · 상세 드로어", "QFrame"),
    GalleryStyleSpec("section:emptyState", "공통 · 빈 상태", "QFrame"),
)

_ASSET_GALLERY_STYLES = (
    GalleryStyleSpec("asset:squareImage", "이미지 · 정사각 샘플", "QFrame"),
    GalleryStyleSpec("asset:studentPortrait", "이미지 · 학생 Portrait", "QFrame"),
    GalleryStyleSpec("asset:resourceIcon", "이미지 · 재화 아이콘", "QFrame"),
)

_WIDGET_GALLERY_STYLES = (
    GalleryStyleSpec("widget:studentCard", "학생 · 카드", "QFrame"),
    GalleryStyleSpec("widget:studentCompactRow", "학생 · 압축 행", "QFrame"),
    GalleryStyleSpec("widget:planStatusBadge", "상태 · 계획 배지", "QFrame"),
    GalleryStyleSpec("widget:resourceRequirementRow", "재화 · 요구량 행", "QFrame"),
    GalleryStyleSpec("widget:resourceProgressBar", "재화 · 충족률 막대", "QFrame"),
    GalleryStyleSpec("widget:metricCard", "통계 · KPI 카드", "QFrame"),
    GalleryStyleSpec("widget:distributionBarChart", "차트 · 가로 막대", "QFrame"),
    GalleryStyleSpec("widget:histogram", "차트 · 히스토그램", "QFrame"),
    GalleryStyleSpec("widget:stackedBar", "차트 · 누적 막대", "QFrame"),
    GalleryStyleSpec("widget:heatmap", "차트 · 히트맵", "QFrame"),
    GalleryStyleSpec("widget:scatterPlot", "차트 · 산점도", "QFrame"),
    GalleryStyleSpec("widget:trendChart", "차트 · 추이선", "QFrame"),
    GalleryStyleSpec("widget:dataFreshnessBadge", "상태 · 데이터 최신성", "QFrame"),
    GalleryStyleSpec("widget:filterChipBar", "공통 · 필터 칩", "QFrame"),
    GalleryStyleSpec("widget:sortMenu", "공통 · 정렬 메뉴", "QFrame"),
    GalleryStyleSpec("widget:viewModeToggle", "공통 · 보기 전환", "QFrame"),
)

_REFERENCE_STUDENT_PORTRAIT = ROOT / "templates" / "students_portraits" / "seia.png"
_REFERENCE_RESOURCE_ICON = ROOT / "templates" / "icons" / "ooparts" / "Item_Icon_Material_Nebra_2.png"

_SECTION_SELECTOR_MARKERS = (
    "section",
    "panel",
    "band",
    "header",
    "dashboard",
    "workspace",
)


def studio_rendering_enabled(widget: QWidget) -> bool:
    return widget.property(_STUDIO_RENDER_ENABLED_PROPERTY) is not False


def set_studio_rendering(widget: QWidget, enabled: bool) -> None:
    """Compatibility helper retained for callers outside the gallery."""
    enabled = bool(enabled)
    policy = widget.sizePolicy()
    if not enabled:
        if studio_rendering_enabled(widget):
            widget.setProperty(_STUDIO_RENDER_ORIGINAL_HIDDEN_PROPERTY, widget.isHidden())
            widget.setProperty(_STUDIO_RENDER_ORIGINAL_RETAIN_PROPERTY, policy.retainSizeWhenHidden())
        policy.setRetainSizeWhenHidden(True)
        widget.setSizePolicy(policy)
        widget.setProperty(_STUDIO_RENDER_ENABLED_PROPERTY, False)
        widget.setHidden(True)
        return
    policy.setRetainSizeWhenHidden(bool(widget.property(_STUDIO_RENDER_ORIGINAL_RETAIN_PROPERTY)))
    widget.setSizePolicy(policy)
    widget.setProperty(_STUDIO_RENDER_ENABLED_PROPERTY, True)
    widget.setHidden(bool(widget.property(_STUDIO_RENDER_ORIGINAL_HIDDEN_PROPERTY)))


def configure_studio_application(app: QApplication) -> None:
    from gui.viewer_shared import _apply_ui_font

    _apply_ui_font(app)


def _class_from_selector(selector: str) -> str:
    tail = selector.rsplit("/", 1)[-1]
    class_name = tail.split("#", 1)[0].split("[", 1)[0]
    return class_name if class_name in SUPPORTED_WIDGET_TYPES else "QFrame"


def _sample_widget(widget_type: str, parent: QWidget) -> QWidget:
    if widget_type == "QLabel":
        widget = QLabel("Label · 학생 정보", parent)
        widget.setAlignment(Qt.AlignCenter)
    elif widget_type == "QPushButton":
        widget = QPushButton("Action button", parent)
    elif widget_type == "QLineEdit":
        widget = QLineEdit("Input text", parent)
    elif widget_type == "QComboBox":
        widget = QComboBox(parent)
        widget.addItems(["Option A", "Option B"])
    elif widget_type == "QProgressBar":
        widget = QProgressBar(parent)
        widget.setValue(64)
    elif widget_type == "QPlainTextEdit":
        widget = QPlainTextEdit("Multiline text\nDesign sample", parent)
    else:
        widget = QFrame(parent)
        widget.setFrameShape(QFrame.StyledPanel)
    widget.setMinimumSize(210, 76)
    widget.setMaximumHeight(110)
    return widget


def _section_key(entry_id: str) -> str:
    if entry_id.startswith("section:"):
        return entry_id.removeprefix("section:").lower()
    selector = entry_id.removeprefix("selector:")
    return selector.rsplit("/", 1)[-1].lower()


def _entry_object_name(entry_id: str) -> str:
    if entry_id.startswith("section:"):
        return entry_id.removeprefix("section:")
    tail = entry_id.removeprefix("selector:").rsplit("/", 1)[-1]
    return tail.split("#", 1)[1].split("[", 1)[0] if "#" in tail else ""


def _is_section_entry(entry_id: str) -> bool:
    if entry_id.startswith("section:"):
        return True
    if not entry_id.startswith("selector:"):
        return False
    tail = entry_id.rsplit("/", 1)[-1].lower()
    return any(marker in tail for marker in _SECTION_SELECTOR_MARKERS)


def _center_crop(pixmap: QPixmap, size: QSize) -> QPixmap:
    scaled = pixmap.scaled(size, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation)
    left = max(0, (scaled.width() - size.width()) // 2)
    top = max(0, (scaled.height() - size.height()) // 2)
    return scaled.copy(left, top, size.width(), size.height())


def _asset_sample(entry_id: str, parent: QWidget) -> QWidget:
    host = QFrame(parent)
    host.setObjectName("assetSample")
    host.setFrameShape(QFrame.StyledPanel)
    layout = QVBoxLayout(host)
    layout.setContentsMargins(12, 10, 12, 10)
    layout.setSpacing(7)

    image = QLabel()
    image.setObjectName("assetPreview")
    image.setAlignment(Qt.AlignCenter)
    image.setStyleSheet("background:rgba(30,36,52,0.62); border-radius:10px;")
    caption = QLabel()
    caption.setObjectName("assetReferencePath")
    caption.setAlignment(Qt.AlignCenter)

    if entry_id == "asset:resourceIcon":
        path = _REFERENCE_RESOURCE_ICON
        target_size = QSize(150, 118)
        pixmap = QPixmap(str(path))
        rendered = pixmap.scaled(target_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        caption.setText("Item_Icon_Material_Nebra_2.png")
    elif entry_id == "asset:studentPortrait":
        path = _REFERENCE_STUDENT_PORTRAIT
        target_size = QSize(184, 132)
        pixmap = QPixmap(str(path))
        rendered = pixmap.scaled(target_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        caption.setText("students_portraits/seia.png")
    else:
        path = _REFERENCE_STUDENT_PORTRAIT
        target_size = QSize(132, 132)
        pixmap = QPixmap(str(path))
        rendered = _center_crop(pixmap, target_size)
        caption.setText("Square crop · seia.png")

    image.setFixedSize(target_size)
    image.setPixmap(rendered)
    image.setToolTip(str(path))
    caption.setToolTip(str(path))
    layout.addWidget(image, 0, Qt.AlignCenter)
    layout.addWidget(caption)
    host.setMinimumSize(210, 178)
    host.setMaximumHeight(210)
    return host


def _gallery_badge(text: str, color: str, parent: QWidget | None = None) -> QLabel:
    badge = QLabel(text, parent)
    badge.setAlignment(Qt.AlignCenter)
    badge.setStyleSheet(
        f"color:white; background:{color}; border-radius:8px; padding:3px 8px; font-weight:700;"
    )
    return badge


def _gallery_surface(palette: dict[str, str], parent: QWidget, *, radius: int = 12) -> QFrame:
    surface = QFrame(parent)
    surface.setObjectName("gallerySurface")
    surface.setFrameShape(QFrame.NoFrame)
    surface.setStyleSheet(
        f"QFrame#gallerySurface {{ background:{palette.get('panel', DEFAULT_PALETTE['panel'])}; "
        f"border:1px solid rgba(255,255,255,38); border-radius:{radius}px; }}"
    )
    return surface


def _gallery_text(text: str, palette: dict[str, str], *, strong: bool = False) -> QLabel:
    label = QLabel(text)
    weight = "font-weight:700;" if strong else ""
    label.setStyleSheet(f"color:{palette.get('text', DEFAULT_PALETTE['text'])}; {weight}")
    return label


class GalleryChartCanvas(QWidget):
    """Small design-only chart canvas used to review chart silhouettes."""

    def __init__(self, mode: str, palette: dict[str, str], parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.mode = mode
        self.colors = (
            QColor(palette.get("accent", DEFAULT_PALETTE["accent"])),
            QColor("#62b8ff"),
            QColor("#8bd5a5"),
            QColor("#f5c66b"),
        )
        self.setMinimumSize(210, 130)
        self.setMaximumHeight(170)

    def paintEvent(self, event) -> None:
        super().paintEvent(event)
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        rect = QRectF(self.rect()).adjusted(8, 8, -8, -8)
        painter.setPen(QPen(QColor(255, 255, 255, 48), 1))
        painter.setBrush(QColor(31, 38, 56))
        painter.drawRoundedRect(rect, 10, 10)
        plot = rect.adjusted(18, 14, -14, -18)
        if self.mode == "bar":
            values = (0.9, 0.72, 0.58, 0.44)
            gap = 7.0
            height = max(5.0, (plot.height() - gap * (len(values) - 1)) / len(values))
            for index, value in enumerate(values):
                y = plot.top() + index * (height + gap)
                painter.fillRect(QRectF(plot.left(), y, plot.width() * value, height), self.colors[index])
        elif self.mode == "histogram":
            values = (0.42, 0.68, 0.9, 0.56, 0.74)
            gap = 7.0
            width = max(4.0, (plot.width() - gap * (len(values) - 1)) / len(values))
            for index, value in enumerate(values):
                height = plot.height() * value
                x = plot.left() + index * (width + gap)
                bar = QRectF(x, plot.bottom() - height, width, height)
                painter.fillRect(bar, self.colors[index % len(self.colors)])
        elif self.mode == "stacked":
            y = plot.center().y() - 14
            ratios = (0.35, 0.27, 0.22, 0.16)
            x = plot.left()
            for ratio, color in zip(ratios, self.colors):
                width = plot.width() * ratio
                painter.fillRect(QRectF(x, y, width, 28), color)
                x += width
        elif self.mode == "heatmap":
            rows, columns = 4, 6
            gap = 4.0
            cell_w = (plot.width() - gap * (columns - 1)) / columns
            cell_h = (plot.height() - gap * (rows - 1)) / rows
            for row in range(rows):
                for column in range(columns):
                    base = QColor(self.colors[(row + column) % len(self.colors)])
                    base.setAlpha(80 + ((row * columns + column) * 17) % 176)
                    painter.fillRect(
                        QRectF(plot.left() + column * (cell_w + gap), plot.top() + row * (cell_h + gap), cell_w, cell_h),
                        base,
                    )
        elif self.mode == "scatter":
            points = ((.08, .72), (.2, .58), (.31, .78), (.44, .48), (.57, .42), (.68, .31), (.82, .24), (.91, .38))
            painter.setPen(Qt.NoPen)
            for index, (x_ratio, y_ratio) in enumerate(points):
                painter.setBrush(self.colors[index % len(self.colors)])
                painter.drawEllipse(QPointF(plot.left() + plot.width() * x_ratio, plot.top() + plot.height() * y_ratio), 5, 5)
        else:
            points = ((0, .78), (.18, .66), (.35, .7), (.52, .42), (.7, .5), (.84, .24), (1, .18))
            path = QPainterPath()
            for index, (x_ratio, y_ratio) in enumerate(points):
                point = QPointF(plot.left() + plot.width() * x_ratio, plot.top() + plot.height() * y_ratio)
                path.moveTo(point) if index == 0 else path.lineTo(point)
            painter.setPen(QPen(self.colors[0], 3))
            painter.setBrush(Qt.NoBrush)
            painter.drawPath(path)
        painter.end()


def _student_card_sample(palette: dict[str, str], parent: QWidget, *, compact: bool) -> QWidget:
    host = _gallery_surface(palette, parent)
    layout = QHBoxLayout(host)
    layout.setContentsMargins(10, 9, 10, 9)
    layout.setSpacing(10)
    portrait = QLabel()
    size = QSize(54, 54) if compact else QSize(88, 74)
    portrait.setFixedSize(size)
    portrait.setPixmap(_center_crop(QPixmap(str(_REFERENCE_STUDENT_PORTRAIT)), size))
    portrait.setScaledContents(False)
    layout.addWidget(portrait)
    text = QVBoxLayout()
    text.addWidget(_gallery_text("세이아", palette, strong=True))
    text.addWidget(_gallery_text("트리니티 · SPECIAL", palette))
    if compact:
        text.addWidget(_gallery_text("Lv.90  |  목표 5·10·10·10", palette))
    else:
        badges = QHBoxLayout()
        badges.addWidget(_gallery_badge("계획", palette.get("accent", DEFAULT_PALETTE["accent"])))
        badges.addWidget(_gallery_badge("달성 가능", "#3d9a68"))
        badges.addStretch(1)
        text.addLayout(badges)
    layout.addLayout(text, 1)
    host.setMinimumSize(220, 78 if compact else 112)
    host.setMaximumHeight(128)
    return host


def _resource_row_sample(palette: dict[str, str], parent: QWidget) -> QWidget:
    host = _gallery_surface(palette, parent)
    layout = QGridLayout(host)
    layout.setContentsMargins(9, 8, 9, 8)
    icon = QLabel()
    icon.setFixedSize(48, 40)
    pixmap = QPixmap(str(_REFERENCE_RESOURCE_ICON)).scaled(icon.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
    icon.setPixmap(pixmap)
    layout.addWidget(icon, 0, 0, 2, 1)
    layout.addWidget(_gallery_text("네브라 디스크", palette, strong=True), 0, 1)
    layout.addWidget(_gallery_text("보유 18  ·  필요 42  ·  부족 24", palette), 1, 1)
    layout.addWidget(_gallery_badge("부족", "#c84f6a"), 0, 2, 2, 1)
    layout.setColumnStretch(1, 1)
    host.setMinimumSize(250, 76)
    host.setMaximumHeight(92)
    return host


def _resource_progress_sample(palette: dict[str, str], parent: QWidget) -> QWidget:
    host = _gallery_surface(palette, parent)
    layout = QVBoxLayout(host)
    layout.setContentsMargins(12, 10, 12, 10)
    row = QHBoxLayout()
    row.addWidget(_gallery_text("18 / 42", palette, strong=True))
    row.addStretch(1)
    row.addWidget(_gallery_text("42.9%", palette))
    layout.addLayout(row)
    progress = QProgressBar()
    progress.setRange(0, 100)
    progress.setValue(43)
    progress.setTextVisible(False)
    layout.addWidget(progress)
    layout.addWidget(_gallery_text("예약 12 · 부족 36", palette))
    host.setMinimumSize(220, 88)
    host.setMaximumHeight(104)
    return host


def _widget_contract_sample(entry_id: str, palette: dict[str, str], parent: QWidget) -> QWidget:
    key = entry_id.removeprefix("widget:").lower()
    if key == "studentcard":
        return _student_card_sample(palette, parent, compact=False)
    if key == "studentcompactrow":
        return _student_card_sample(palette, parent, compact=True)
    if key == "resourcerequirementrow":
        return _resource_row_sample(palette, parent)
    if key == "resourceprogressbar":
        return _resource_progress_sample(palette, parent)
    if key in {"distributionbarchart", "histogram", "stackedbar", "heatmap", "scatterplot", "trendchart"}:
        mode = {
            "distributionbarchart": "bar",
            "histogram": "histogram",
            "stackedbar": "stacked",
            "heatmap": "heatmap",
            "scatterplot": "scatter",
            "trendchart": "trend",
        }[key]
        return GalleryChartCanvas(mode, palette, parent)
    host = _gallery_surface(palette, parent)
    layout = QVBoxLayout(host)
    layout.setContentsMargins(12, 10, 12, 10)
    layout.setSpacing(7)
    if key == "metriccard":
        layout.addWidget(_gallery_text("평균 육성도", palette))
        value = _gallery_text("63.4%", palette, strong=True)
        value.setStyleSheet(value.styleSheet() + " font-size:22px;")
        layout.addWidget(value)
        layout.addWidget(_gallery_text("이전 스캔 대비 +2.1%", palette))
    elif key == "planstatusbadge":
        badges = QHBoxLayout()
        for text, color in (("달성 가능", "#3d9a68"), ("일부 가능", "#c18b3e"), ("재화 부족", "#c84f6a")):
            badges.addWidget(_gallery_badge(text, color))
        layout.addLayout(badges)
    elif key == "datafreshnessbadge":
        badges = QHBoxLayout()
        for text, color in (("최신", "#3d9a68"), ("1일 전", "#4c7fac"), ("오래됨", "#c84f6a")):
            badges.addWidget(_gallery_badge(text, color))
        layout.addLayout(badges)
    elif key == "filterchipbar":
        chips = QHBoxLayout()
        for text in ("트리니티 ×", "신비 ×", "계획 없음 ×"):
            chips.addWidget(_gallery_badge(text, palette.get("accent", DEFAULT_PALETTE["accent"])))
        layout.addLayout(chips)
    elif key == "sortmenu":
        combo = QComboBox()
        combo.addItems(("부족량 높은 순", "충족률 낮은 순", "이름 순"))
        layout.addWidget(combo)
    elif key == "viewmodetoggle":
        buttons = QHBoxLayout()
        for text in ("카드", "목록", "표", "차트"):
            button = QPushButton(text)
            button.setCheckable(True)
            button.setChecked(text == "목록")
            buttons.addWidget(button)
        layout.addLayout(buttons)
    layout.addStretch(1)
    host.setMinimumSize(220, 92)
    host.setMaximumHeight(132)
    return host


def _sample_copy(title: str, subtitle: str, palette: dict[str, str], parent: QWidget) -> QWidget:
    host = QWidget(parent)
    layout = QVBoxLayout(host)
    layout.setContentsMargins(14, 12, 14, 12)
    layout.setSpacing(7)
    title_label = QLabel(title)
    title_label.setObjectName("title")
    title_label.setStyleSheet(f"color:{palette.get('text', DEFAULT_PALETTE['text'])}; font-weight:700;")
    subtitle_label = QLabel(subtitle)
    subtitle_label.setObjectName("count")
    subtitle_label.setStyleSheet(f"color:{palette.get('soft', DEFAULT_PALETTE['soft'])};")
    subtitle_label.setWordWrap(True)
    layout.addWidget(title_label)
    layout.addWidget(subtitle_label)
    layout.addStretch(1)
    return host


def _home_section_sample(entry_id: str, palette: dict[str, str], parent: QWidget) -> QWidget:
    from gui.viewer_components.home import (
        ACCENT,
        ACCENT_SOFT,
        BORDER,
        HOME_DIAGONAL_ANGLE,
        HOME_MENU_CAPTION_COLOR,
        HOME_MENU_CAPTION_RATIO,
        HOME_MENU_CAPTION_TEXT_COLOR,
        HOME_MENU_SETTINGS_TEXT_COLOR,
        HOME_MENU_TEXTURE_OVERSCAN,
        HOME_MENU_TEXTURES,
        INK,
        MUTED,
        PALETTE_ACCENT,
        PALETTE_PANEL,
        PALETTE_PANEL_ALT,
        PALETTE_SOFT,
        PALETTE_TEXT,
        SHADOW,
        SURFACE,
        SURFACE_ALT,
        HomeGlassSection,
        HomeElidedLabel,
        DiagonalComponentControlSlot,
        DiagonalMenuComboBox,
        HomeMenuButtonRow,
        HomeMenuRowsWidget,
        HomeSettingsMenuRowsWidget,
        HomeTabComponent,
        HomeWindowCandidateRow,
        LiftedShadowSpec,
        ParallelogramActionButton,
        TriangleTextureConfig,
        _alpha_hex,
        _mix_hex,
    )

    key = _section_key(entry_id)
    home_label_style = (
        f"QLabel {{ color: {INK}; background: transparent; }}"
        f"QLabel#title {{ font-size: 24px; font-weight: 800; color: {INK}; }}"
        f"QLabel#count, QLabel#filterSummary {{ color: {MUTED}; }}"
        f"QLabel#sectionTitle {{ font-size: 15px; font-weight: 800; color: {INK}; }}"
    )
    if "scan" in key:
        component = object.__new__(HomeTabComponent)
        component._ui_scale = 1.0
        section = component._build_home_scan_panel()
        section.setParent(parent)
        section.setStyleSheet(home_label_style)
        return section

    if "menu" in key:
        shadow = LiftedShadowSpec(color=SHADOW, offset_x=2.0, offset_y=2.0, inset=3.0, layers=4, max_alpha=0.22)
        section = HomeGlassSection(
            fill=_alpha_hex(_mix_hex(palette.get("panel_alt", PALETTE_PANEL_ALT), PALETTE_PANEL_ALT, 0.64), 0.78),
            radius=7,
            cut_right=True,
            lifted_shadow=shadow,
        )
        section.setObjectName("homeMenuSection")
        layout = QVBoxLayout(section)
        layout.setContentsMargins(18, 18, 30, 18)
        layout.setSpacing(10)
        menu_gap = 10
        corner_radius = 7
        settings_base = _mix_hex(PALETTE_PANEL_ALT, PALETTE_TEXT, 0.2)
        settings_panel = _mix_hex(PALETTE_PANEL, PALETTE_PANEL_ALT, 0.58)
        settings_soft = _mix_hex(settings_base, PALETTE_TEXT, 0.18)
        settings_texture = TriangleTextureConfig(
            base_color=settings_base,
            panel_color=settings_panel,
            soft_color=settings_soft,
            accent_color=settings_soft,
            tessellation_contrast=0.1,
            random_seed=8417,
            macro_triangle_chance=0.12,
            macro_triangle_scale=2.8,
            macro_triangle_contrast=0.05,
            light_direction_degrees=0.0,
            light_strength=0.1,
            light_center_x=0.5,
            light_center_y=0.5,
            edge_vignette_strength=0.06,
            fog_direction_degrees=0.0,
            fog_strength=0.035,
        )
        entries = (
            (("싯딤의 상자와 연결", 0),),
            (("학생부 확인", 0), ("계획 설정", 1), ("인벤토리", 2)),
            (("전술대항전", 0), ("통계", 1)),
            (("설정", 0),),
        )
        rows: list[HomeMenuButtonRow] = []
        for row_index, row_entries in enumerate(entries):
            buttons: list[ParallelogramActionButton] = []
            for label, position in row_entries:
                primary = row_index == 0
                settings = label == "설정"
                button = ParallelogramActionButton(
                    label,
                    fill=(
                        _mix_hex(PALETTE_ACCENT, SURFACE_ALT, 0.28)
                        if primary else _mix_hex(SURFACE, PALETTE_PANEL_ALT, 0.32)
                    ),
                    accent=ACCENT,
                    slant=menu_gap,
                    extend_left=position > 0,
                    angle_degrees=HOME_DIAGONAL_ANGLE,
                    radius=corner_radius,
                    texture_path=HOME_MENU_TEXTURES.get(label),
                    triangle_texture=settings_texture if settings else None,
                    triangle_visible_ratio=0.52,
                    display_text=False,
                    lifted_shadow=None if settings else shadow,
                    caption_overlay_ratio=0.0 if settings else HOME_MENU_CAPTION_RATIO,
                    caption_overlay_color=HOME_MENU_CAPTION_COLOR,
                    caption_text_enabled=True,
                    caption_text_color=(HOME_MENU_SETTINGS_TEXT_COLOR if settings else HOME_MENU_CAPTION_TEXT_COLOR),
                    texture_overscan=HOME_MENU_TEXTURE_OVERSCAN,
                    show_focus_outline=False,
                    triangle_texture_only=settings,
                    state_effects_enabled=not settings,
                )
                button.setObjectName(f"homeMenuButton_{row_index}_{position}")
                button.setAccessibleName(label)
                button.setMinimumHeight(72)
                buttons.append(button)
            rows.append(
                HomeMenuButtonRow(
                    buttons,
                    seam_gap=menu_gap,
                    angle_degrees=HOME_DIAGONAL_ANGLE,
                    radius=corner_radius,
                )
            )
        rows_widget = HomeMenuRowsWidget(section, rows, row_gap=menu_gap)
        rows_widget.setObjectName("homeMenuRows")
        layout.addWidget(rows_widget, 1)
        return section

    glass_fill = _alpha_hex(
        _mix_hex(palette.get("panel_alt", PALETTE_PANEL_ALT), PALETTE_PANEL_ALT, 0.64),
        0.78,
    )
    object_name = _entry_object_name(entry_id) or key.split("#")[-1]

    def home_section(*, cut_right: bool = False, extended: bool = True, shadow=None) -> tuple[HomeGlassSection, QVBoxLayout]:
        section = HomeGlassSection(
            fill=glass_fill,
            radius=7,
            cut_right=cut_right,
            extend_left=30 if extended else 0,
            round_extension_corners=extended,
            lifted_shadow=shadow,
        )
        section.setObjectName(object_name)
        section.setStyleSheet(
            home_label_style +
            f"QPushButton {{ background: transparent; color: #ffb5f0; border: 1px solid {_mix_hex('#ffb5f0', SURFACE_ALT, 0.28)}; border-radius: 9px; padding: 8px 10px; min-height: 22px; font-weight: 700; }}"
            f"QPushButton:disabled {{ color: {MUTED}; border-color: {_mix_hex(BORDER, SURFACE_ALT, 0.28)}; }}"
            f"QLineEdit, QComboBox {{ background: {SURFACE_ALT}; color: {INK}; border: 1px solid {BORDER}; border-radius: 9px; padding: 8px 10px; min-height: 22px; }}"
        )
        section_layout = QVBoxLayout(section)
        margins = (18, 18, 30, 18)
        if extended:
            section.setBaseContentMargins(*margins)
        else:
            section_layout.setContentsMargins(*margins)
        section_layout.setSpacing(10)
        return section, section_layout

    def projected_menu_section(
        title_text: str,
        hint_text: str,
        button_rows: tuple[tuple[str, ...], ...],
    ) -> HomeGlassSection:
        section, section_layout = home_section(cut_right="item" in key, extended=True)
        title = QLabel(title_text); title.setObjectName("title"); section_layout.addWidget(title)
        hint = QLabel(hint_text); hint.setObjectName("count"); hint.setWordWrap(True); section_layout.addWidget(hint)
        for labels in button_rows:
            buttons = [
                ParallelogramActionButton(
                    label,
                    fill=SURFACE,
                    accent=ACCENT,
                    slant=8,
                    extend_left=True,
                    angle_degrees=HOME_DIAGONAL_ANGLE,
                    radius=7,
                    full_height_slant=True,
                )
                for label in labels
            ]
            row = HomeMenuButtonRow(
                buttons,
                seam_gap=8,
                angle_degrees=HOME_DIAGONAL_ANGLE,
                radius=7,
                full_height_slant=True,
            )
            row.setFixedHeight(54)
            slot = DiagonalComponentControlSlot(section, row, left_clearance=18, right_clearance=24)
            section_layout.addWidget(slot)
        section_layout.addStretch(1)
        return section

    if "connection" in key:
        from gui.viewer_components.home import HomeSectionHost, HomeTabComponent, HomeWindowCandidateRow

        class _ConnectionGalleryHarness(QWidget, HomeTabComponent):
            def __init__(self) -> None:
                super().__init__()
                self._ui_scale = 1.0
                self._home_right_host = HomeSectionHost()

            @staticmethod
            def _saved_target() -> tuple[int, str]:
                return 22, "Blue Archive"

            @staticmethod
            def _apply_target_window_selection(_hwnd: int, _title: str) -> bool:
                return False

            def _refresh_home_window_candidates(self) -> None:
                sample_windows = (
                    {"hwnd": 22, "title": "Blue Archive", "size": "1920 × 1080", "likely": True},
                    {"hwnd": 23, "title": "Blue Archive - 서브 모니터", "size": "1600 × 900", "likely": True},
                    {"hwnd": 24, "title": "브라우저", "size": "1280 × 720", "likely": False},
                )
                self._home_window_list.clear()
                for window in sample_windows:
                    row = HomeWindowCandidateRow(
                        title=str(window["title"]),
                        size=str(window["size"]),
                        likely_ba=bool(window["likely"]),
                    )
                    self._home_window_list.addDiagonalWidget(
                        row,
                        data=window,
                        accessible_text=f"{window['title']}, {window['size']}",
                    )
                self._home_window_list.setCurrentRow(0)
                self._home_window_list.refreshDiagonalGeometry()
                self._sync_home_window_selection()

        harness = _ConnectionGalleryHarness()
        section = harness._build_home_connection_panel()
        section.setParent(parent)
        section.setStyleSheet(home_label_style)
        # Keep the lightweight behavior owner alive without inserting a fake
        # wrapper into the selectable gallery hierarchy.
        section._ui_studio_runtime_owner = harness  # type: ignore[attr-defined]
        harness._refresh_home_window_candidates()
        return section

    if "itemcategory" in key:
        component = object.__new__(HomeTabComponent)
        component._ui_scale = 1.0
        component._home_start_scan = lambda *_args: None
        component._home_show_resource_prompt = lambda: None
        section = component._build_home_item_panel()
        section.setParent(parent)
        section.setStyleSheet(home_label_style)
        # Keep the lightweight behavior owner alive for signal-bound callbacks.
        section._ui_studio_runtime_owner = component  # type: ignore[attr-defined]
        return section

    if "resourceprompt" in key:
        component = object.__new__(HomeTabComponent)
        component._ui_scale = 1.0
        component._home_save_manual_resources = lambda: None
        component._home_cancel_resource_prompt = lambda: None
        section = component._build_home_resource_panel()
        section.setParent(parent)
        section.setStyleSheet(home_label_style)
        section._ui_studio_runtime_owner = component  # type: ignore[attr-defined]
        return section

    if "settings" in key:
        settings_shadow = LiftedShadowSpec(color=SHADOW, offset_x=2.0, offset_y=2.0, inset=3.0, layers=4, max_alpha=0.18)
        section, layout = home_section(cut_right=True, shadow=settings_shadow)
        content = QWidget(section)
        content_layout = QVBoxLayout(content); content_layout.setContentsMargins(0, 0, 0, 0); content_layout.setSpacing(0)
        surface_fill = _alpha_hex(_mix_hex(SURFACE, PALETTE_PANEL_ALT, 0.36), 0.92)

        def texture(name: str, base_color: str, *, button: bool = False) -> TriangleTextureConfig:
            seed = 3100 + sum((index + 1) * ord(char) for index, char in enumerate(name))
            return TriangleTextureConfig(
                base_color=base_color,
                panel_color=_mix_hex(base_color, PALETTE_PANEL_ALT, 0.12) if button else PALETTE_PANEL_ALT,
                soft_color=_mix_hex(base_color, PALETTE_SOFT, 0.10) if button else PALETTE_SOFT,
                accent_color=PALETTE_ACCENT,
                triangle_size=42 if button else 54,
                tessellation_contrast=0.026,
                random_seed=seed,
                macro_triangle_chance=0.06,
                macro_triangle_scale=2.6,
                macro_triangle_contrast=0.014 if button else 0.018,
                light_strength=0.025 if button else 0.085,
                edge_vignette_strength=0.065 if button else 0.10,
                fog_strength=0.015 if button else 0.055,
            )

        def surface(name: str, margins: tuple[int, int, int, int]) -> tuple[HomeGlassSection, QVBoxLayout]:
            panel = HomeGlassSection(
                fill=surface_fill, radius=7, cut_right=True, extend_left=30,
                angle_degrees=80.0, round_extension_corners=True,
                triangle_texture=texture(name, surface_fill), lifted_shadow=settings_shadow,
            )
            panel.setObjectName(name); panel_layout = QVBoxLayout(panel); panel.setBaseContentMargins(*margins)
            return panel, panel_layout

        button_fill = _mix_hex(PALETTE_ACCENT, PALETTE_PANEL_ALT, 0.62)
        rows: list[HomeGlassSection] = []
        header, header_layout = surface("homeSettingsHeaderSurface", (18, 18, 24, 18))
        title = QLabel("설정"); title.setObjectName("title"); header_layout.addWidget(title)
        active = QLabel("활성 프로필: Default"); active.setObjectName("count"); header_layout.addWidget(active)
        target = HomeElidedLabel("연결된 Blue Archive 창: 없음"); target.setObjectName("count"); header_layout.addWidget(target); rows.append(header)
        profile, profile_layout = surface("homeSettingsProfileSurface", (14, 12, 24, 12))
        profile_title = QLabel("계정 관리"); profile_title.setObjectName("sectionTitle"); profile_layout.addWidget(profile_title)
        combo_fill = _alpha_hex(_mix_hex(SURFACE_ALT, PALETTE_ACCENT, 0.14), 0.96)
        combo = DiagonalMenuComboBox(fill=combo_fill, accent=ACCENT, angle_degrees=80.0, radius=7, triangle_texture=texture("profile:dropdown", combo_fill, button=True))
        combo.addItems(("Default", "Raid", "Tactical")); combo.setAccessibleName("프로필 선택")
        profile_layout.addWidget(DiagonalComponentControlSlot(profile, combo, left_clearance=14, right_clearance=24))

        def settings_row(panel: HomeGlassSection, *labels: str) -> DiagonalComponentControlSlot:
            buttons = [ParallelogramActionButton(label, fill=button_fill, accent=ACCENT, slant=8, extend_left=True, angle_degrees=80.0, radius=7, full_height_slant=True) for label in labels]
            row = HomeMenuButtonRow(buttons, seam_gap=8, angle_degrees=80.0, radius=7, full_height_slant=True); row.setFixedHeight(54)
            return DiagonalComponentControlSlot(panel, row, left_clearance=14, right_clearance=24)

        for labels in (("프로필 적용", "새 프로필"), ("새로고침", "계정 설정"), ("현재 프로필 데이터 삭제",)):
            profile_layout.addWidget(settings_row(profile, *labels))
        rows.append(profile)
        window_panel, window_layout = surface("homeSettingsWindowSurface", (14, 12, 24, 12))
        window_title = QLabel("블루아카이브 창 인식 해제"); window_title.setObjectName("sectionTitle"); window_layout.addWidget(window_title); window_layout.addWidget(settings_row(window_panel, "연결 해제")); rows.append(window_panel)
        support, support_layout = surface("homeSettingsSupportSurface", (14, 12, 24, 12))
        support_title = QLabel("지원"); support_title.setObjectName("sectionTitle"); support_layout.addWidget(support_title)
        support_description = QLabel("문제가 발생했다면 설명과 진단정보를 작성해 신고할 수 있습니다."); support_description.setObjectName("count"); support_description.setWordWrap(True); support_layout.addWidget(support_description); support_layout.addWidget(settings_row(support, "문제 신고")); rows.append(support)
        settings_rows = HomeSettingsMenuRowsWidget(section, rows, row_heights=[108, 286, 108, 158], row_gap=8, parent=content)
        content_layout.addWidget(settings_rows, 1); layout.addWidget(content, 1)
        return section

    cut_right = any(marker in key for marker in ("menu", "settings", "item", "resource"))
    extend_left = 34 if any(marker in key for marker in ("connection", "scan", "settings", "item", "resource")) else 0
    section = HomeGlassSection(
        fill=palette.get("panel", DEFAULT_PALETTE["panel"]),
        radius=9,
        cut_right=cut_right,
        extend_left=extend_left,
        round_extension_corners=bool(extend_left),
    )
    section.setObjectName(_entry_object_name(entry_id) or key.split("#")[-1])
    layout = QVBoxLayout(section)
    layout.setContentsMargins(24 + (20 if extend_left else 0), 18, 30 if cut_right else 18, 18)
    layout.setSpacing(9)
    title = "메뉴" if "menu" in key else "스캔" if "scan" in key else "연결 및 설정"
    layout.addWidget(_sample_copy(title, "섹션의 실제 절단·확장 실루엣과 내부 여백을 확인합니다.", palette, section))
    for label in (("학생", "플랜", "인벤토리") if "menu" in key else ("기본 작업", "보조 작업")):
        button = ParallelogramActionButton(
            label,
            fill=palette.get("panel_alt", DEFAULT_PALETTE["panel_alt"]),
            accent=palette.get("accent", DEFAULT_PALETTE["accent"]),
            extend_left=bool(extend_left),
            angle_degrees=80.0,
            radius=7,
        )
        button.setMinimumHeight(42)
        button.setMaximumHeight(48)
        layout.addWidget(button)
    layout.addStretch(1)
    return section


def _scan_header_sample(entry_id: str, palette: dict[str, str], parent: QWidget) -> QWidget:
    from gui.viewer_components.scan import DiagonalScanFrame, SlantedScanHeader

    outer = DiagonalScanFrame(fill=palette.get("panel_alt", DEFAULT_PALETTE["panel_alt"]), radius=6)
    outer.setObjectName("scanHeaderSection")
    outer_layout = QVBoxLayout(outer)
    outer_layout.setContentsMargins(5, 5, 5, 5)
    active = DiagonalScanFrame(fill=palette.get("accent", DEFAULT_PALETTE["accent"]), radius=6)
    active.setObjectName("scanHeaderActiveRegion")
    active_layout = QHBoxLayout(active)
    active_layout.setContentsMargins(6, 6, 28, 6)
    header = SlantedScanHeader(fill=palette.get("panel", DEFAULT_PALETTE["panel"]), radius=14)
    header.setObjectName("scanHeader")
    header_layout = QVBoxLayout(header)
    header_layout.setContentsMargins(18, 14, 24, 14)
    header_title = QLabel("스캔 작업 공간")
    header_title.setStyleSheet(f"color:{palette.get('text', DEFAULT_PALETTE['text'])}; font-weight:700;")
    header_subtitle = QLabel("프로필과 연결 상태를 표시하는 복합 헤더")
    header_subtitle.setStyleSheet(f"color:{palette.get('soft', DEFAULT_PALETTE['soft'])};")
    header_layout.addWidget(header_title)
    header_layout.addWidget(header_subtitle)
    active_layout.addWidget(header, 1)
    accessory = QFrame()
    accessory.setObjectName("scanHeaderAccessory")
    accessory.setFixedWidth(92)
    accessory.setStyleSheet(
        f"background:{palette.get('soft', DEFAULT_PALETTE['soft'])}; border-radius:12px;"
    )
    accessory_layout = QVBoxLayout(accessory)
    portrait = QLabel("ACC\nESSORY")
    portrait.setAlignment(Qt.AlignCenter)
    portrait.setStyleSheet(f"color:{palette.get('panel_alt', DEFAULT_PALETTE['panel_alt'])}; font-weight:700;")
    accessory_layout.addWidget(portrait)
    active_layout.addWidget(accessory)
    outer_layout.addWidget(active)
    return outer


def _standard_section_sample(entry_id: str, palette: dict[str, str], parent: QWidget) -> QWidget:
    key = _section_key(entry_id)
    if "planeditorsectioncard" in key:
        from gui.viewer_shared import PlanEditorSectionCard
        section = PlanEditorSectionCard(ui_scale=1.0)
    elif "planeditorcontentpanel" in key:
        from gui.viewer_shared import PlanEditorContentPanel
        section = PlanEditorContentPanel(ui_scale=1.0)
    else:
        section = QFrame(parent)
        section.setFrameShape(QFrame.StyledPanel)
        section.setStyleSheet(
            f"QFrame {{ background:{palette.get('panel', DEFAULT_PALETTE['panel'])}; "
            "border:1px solid rgba(255,255,255,38); border-radius:14px; }"
        )
    section.setObjectName(_entry_object_name(entry_id) or key.split("#")[-1])
    layout = QVBoxLayout(section)
    layout.setContentsMargins(16, 14, 16, 14)
    layout.setSpacing(8)
    title = QLabel("분석 섹션" if "stat" in key else "정보 섹션")
    title.setObjectName("sectionTitle")
    title.setStyleSheet(f"color:{palette.get('text', DEFAULT_PALETTE['text'])}; font-weight:700;")
    description = QLabel("제목, 상태, 주요 지표와 작업 컨트롤이 함께 배치되는 섹션입니다.")
    description.setObjectName("count")
    description.setStyleSheet(f"color:{palette.get('soft', DEFAULT_PALETTE['soft'])};")
    description.setWordWrap(True)
    progress = QProgressBar()
    progress.setValue(68)
    layout.addWidget(title)
    layout.addWidget(description)
    layout.addWidget(progress)
    layout.addStretch(1)
    return section


def _feature_panel(
    title: str,
    subtitle: str,
    palette: dict[str, str],
    parent: QWidget,
) -> tuple[QFrame, QVBoxLayout]:
    panel = _gallery_surface(palette, parent, radius=14)
    layout = QVBoxLayout(panel)
    layout.setContentsMargins(16, 14, 16, 14)
    layout.setSpacing(9)
    layout.addWidget(_gallery_text(title, palette, strong=True))
    if subtitle:
        subtitle_label = _gallery_text(subtitle, palette)
        subtitle_label.setWordWrap(True)
        layout.addWidget(subtitle_label)
    return panel, layout


def _labeled_progress(layout: QVBoxLayout, label: str, value: int, palette: dict[str, str]) -> None:
    row = QHBoxLayout()
    row.addWidget(_gallery_text(label, palette))
    row.addStretch(1)
    row.addWidget(_gallery_text(f"{value}%", palette, strong=True))
    layout.addLayout(row)
    progress = QProgressBar()
    progress.setRange(0, 100)
    progress.setValue(value)
    progress.setTextVisible(False)
    layout.addWidget(progress)


def _feature_section_sample(entry_id: str, palette: dict[str, str], parent: QWidget) -> QWidget:
    key = _section_key(entry_id).split("#")[-1]
    titles = {
        "studentfilterbar": ("학생 필터", "검색과 분류 조건을 조합해 대상 집합을 만듭니다."),
        "studentgroupselector": ("학생 집합", "저장된 조건 집합과 계획 범위를 선택합니다."),
        "trainingtargeteditor": ("육성 목표", "현재 상태에서 올릴 목표 단계를 지정합니다."),
        "targetpresetselector": ("목표 프리셋", "반복해서 쓰는 목표 구성을 선택하거나 저장합니다."),
        "trainingmilestoneeditor": ("육성 마일스톤", "실행 가능한 여러 단계로 목표를 나눕니다."),
        "bulktargetapplypanel": ("일괄 목표 적용", "선택한 학생 18명에게 공통 목표를 적용합니다."),
        "plangroupcard": ("다음 총력전", "기한과 우선순위를 가진 계획 그룹입니다."),
        "prioritylist": ("재화 배정 우선순위", "위에서부터 순서대로 보유 재화를 배정합니다."),
        "scenariocomparecard": ("시나리오 비교", "실제 계획과 가상 조건의 차이를 비교합니다."),
        "resourcerequirementtable": ("필요 재화", "보유·필요·예약·부족을 정렬 가능한 행으로 표시합니다."),
        "resourceusagepanel": ("재화 사용처", "선택한 재화를 요구하는 학생과 목표 단계를 표시합니다."),
        "resourcecategorysummary": ("재화 카테고리", "계열별 부족 상태와 평균 충족률을 요약합니다."),
        "currentvstargetpanel": ("현재와 목표", "변경되는 육성 항목을 나란히 비교합니다."),
        "incrementalcostpanel": ("학생 추가 시 변화", "새 계획이 만드는 순증가 비용을 미리 봅니다."),
        "bottleneckpanel": ("핵심 병목", "가장 많은 계획을 막는 재화를 표시합니다."),
        "conflictalertpanel": ("계획 충돌", "목표 조건과 데이터 문제를 해결 가능한 경고로 표시합니다."),
        "scanstatuscard": ("스캔 상태", "기준 시점과 인식 품질을 함께 표시합니다."),
        "anomalylist": ("이상 변화", "이전 스캔과 비교해 확인이 필요한 변화를 표시합니다."),
        "detaildrawer": ("학생 상세", "목록을 떠나지 않고 선택 항목의 세부 정보를 표시합니다."),
        "emptystate": ("표시할 데이터가 없습니다", "스캔하거나 계획을 추가하면 이 영역에 결과가 나타납니다."),
    }
    title, subtitle = titles.get(key, ("구성 섹션", "복합 위젯의 레이아웃을 확인합니다."))
    panel, layout = _feature_panel(title, subtitle, palette, parent)

    if key == "studentfilterbar":
        row = QHBoxLayout()
        search = QLineEdit(); search.setPlaceholderText("학생 이름, ID, 태그 검색")
        school = QComboBox(); school.addItems(("모든 학교", "트리니티", "밀레니엄"))
        role = QComboBox(); role.addItems(("모든 역할", "딜러", "서포터"))
        row.addWidget(search, 2); row.addWidget(school, 1); row.addWidget(role, 1)
        layout.addLayout(row)
        chips = QHBoxLayout()
        for text in ("보유 학생 ×", "신비 ×", "계획 없음 ×"):
            chips.addWidget(_gallery_badge(text, palette.get("accent", DEFAULT_PALETTE["accent"])))
        chips.addStretch(1); layout.addLayout(chips)
    elif key == "studentgroupselector":
        row = QHBoxLayout()
        for index, text in enumerate(("보유 전체", "미계획", "다음 총력전", "저장된 필터")):
            button = QPushButton(text); button.setCheckable(True); button.setChecked(index == 1); row.addWidget(button)
        layout.addLayout(row)
    elif key == "trainingtargeteditor":
        grid = QGridLayout()
        for row_index, (label, values) in enumerate((("레벨", ("83", "90")), ("EX", ("3", "5")), ("기본", ("7", "10")), ("장비", ("T7", "T9")))):
            grid.addWidget(_gallery_text(label, palette, strong=True), row_index, 0)
            grid.addWidget(_gallery_text(values[0], palette), row_index, 1)
            grid.addWidget(_gallery_text("→", palette), row_index, 2)
            target = QComboBox(); target.addItems((values[1], values[0])); grid.addWidget(target, row_index, 3)
        grid.setColumnStretch(3, 1); layout.addLayout(grid)
    elif key == "targetpresetselector":
        row = QHBoxLayout(); combo = QComboBox(); combo.addItems(("실전 투입", "최소 육성", "고점 세팅", "사용자 정의"))
        row.addWidget(combo, 1); row.addWidget(QPushButton("적용")); row.addWidget(QPushButton("저장")); layout.addLayout(row)
        layout.addWidget(_gallery_text("Lv.90 · EX5 · 일반 7/7/7 · 장비 T9", palette))
    elif key == "trainingmilestoneeditor":
        for number, text, status in ((1, "Lv.90 · 3/7/7/7", "달성 가능"), (2, "EX5 · M/7/7", "일부 가능"), (3, "전용무기 2성", "재화 부족")):
            row = QHBoxLayout(); row.addWidget(_gallery_badge(str(number), palette.get("accent", DEFAULT_PALETTE["accent"])))
            row.addWidget(_gallery_text(text, palette, strong=True), 1)
            row.addWidget(_gallery_text(status, palette)); row.addWidget(QPushButton("⋮")); layout.addLayout(row)
        layout.addWidget(QPushButton("+ 단계 추가"), 0, Qt.AlignLeft)
    elif key == "bulktargetapplypanel":
        row = QHBoxLayout(); preset = QComboBox(); preset.addItems(("실전 투입", "최소 육성")); row.addWidget(preset, 1)
        for text in ("높은 목표 유지", "미계획 학생만"):
            check = QCheckBox(text); check.setChecked(True); row.addWidget(check)
        row.addWidget(QPushButton("18명에게 적용")); layout.addLayout(row)
    elif key == "plangroupcard":
        metrics = QHBoxLayout()
        for label, value in (("학생", "8명"), ("기한", "D-12"), ("충족률", "64%"), ("병목", "3종")):
            box = QVBoxLayout(); box.addWidget(_gallery_text(label, palette)); box.addWidget(_gallery_text(value, palette, strong=True)); metrics.addLayout(box)
        layout.addLayout(metrics); _labeled_progress(layout, "계획 진행", 64, palette)
    elif key == "prioritylist":
        for index, name, state in ((1, "미카", "완전 가능"), (2, "드레스 히나", "일부 가능"), (3, "수영복 호시노", "시작 불가")):
            row = QHBoxLayout(); row.addWidget(_gallery_badge(str(index), palette.get("accent", DEFAULT_PALETTE["accent"])))
            row.addWidget(_gallery_text("☰", palette)); row.addWidget(_gallery_text(name, palette, strong=True), 1); row.addWidget(_gallery_text(state, palette)); layout.addLayout(row)
    elif key == "scenariocomparecard":
        compare = QHBoxLayout()
        for name, students, shortages, rate in (("실제 계획", 12, 8, 63), ("트리니티 시나리오", 21, 14, 48)):
            card, card_layout = _feature_panel(name, "", palette, panel)
            card_layout.addWidget(_gallery_text(f"학생 {students}명 · 부족 {shortages}종", palette)); _labeled_progress(card_layout, "충족률", rate, palette)
            compare.addWidget(card)
        layout.addLayout(compare)
    elif key == "resourcerequirementtable":
        grid = QGridLayout()
        for column, header in enumerate(("재화", "보유", "필요", "예약", "부족")):
            grid.addWidget(_gallery_text(header, palette, strong=True), 0, column)
        for row_index, values in enumerate((("네브라 디스크", "18", "42", "12", "36"), ("트리니티 노트", "27", "31", "9", "13"), ("크레딧", "24M", "18M", "4M", "0")), 1):
            for column, value in enumerate(values): grid.addWidget(_gallery_text(value, palette), row_index, column)
        grid.setColumnStretch(0, 1); layout.addLayout(grid)
    elif key == "resourceusagepanel":
        for name, goal, amount in (("미카", "EX 4 → 5", 15), ("드레스 히나", "기본 8 → 9", 12), ("수영복 호시노", "서브 7 → 10", 20)):
            row = QHBoxLayout(); row.addWidget(_gallery_text(name, palette, strong=True)); row.addWidget(_gallery_text(goal, palette), 1); row.addWidget(_gallery_text(str(amount), palette, strong=True)); layout.addLayout(row)
    elif key == "resourcecategorysummary":
        for label, value in (("BD", 78), ("기술 노트", 54), ("오파츠", 62), ("장비 설계도", 84)):
            _labeled_progress(layout, label, value, palette)
    elif key == "currentvstargetpanel":
        grid = QGridLayout()
        for column, header in enumerate(("항목", "현재", "목표")): grid.addWidget(_gallery_text(header, palette, strong=True), 0, column)
        for row_index, values in enumerate((("레벨", "83", "90"), ("EX", "3", "5"), ("일반 스킬", "7/7/7", "10/7/7"), ("장비", "T7", "T9")), 1):
            for column, value in enumerate(values): grid.addWidget(_gallery_text(value, palette, strong=column == 2), row_index, column)
        grid.setColumnStretch(0, 1); layout.addLayout(grid)
    elif key == "incrementalcostpanel":
        row = QHBoxLayout()
        for label, value in (("크레딧", "+38.5M"), ("부족 재화", "+3종"), ("가능 학생", "-2명")):
            box = QVBoxLayout(); box.addWidget(_gallery_text(label, palette)); box.addWidget(_gallery_text(value, palette, strong=True)); row.addLayout(box)
        layout.addLayout(row); layout.addWidget(_gallery_badge("새 병목 · 트리니티 최상급 노트", "#c84f6a"), 0, Qt.AlignLeft)
    elif key == "bottleneckpanel":
        for label, value in (("최상급 트리니티 노트", 24), ("네브라 디스크", 38), ("크레딧", 61)):
            _labeled_progress(layout, label, value, palette)
    elif key in {"conflictalertpanel", "anomalylist"}:
        rows = (
            (("목표 충돌", "미카에게 서로 다른 EX 목표가 설정됨"), ("조건 불충족", "전용무기 목표에 필요한 성급이 부족함"), ("오래된 데이터", "인벤토리 스캔이 9일 전임"))
            if key == "conflictalertpanel" else
            (("급격한 감소", "최상급 노트 -42"), ("상태 역행", "학생 레벨 90 → 83"), ("미확인", "오파츠 1종 인식 실패"))
        )
        for heading, detail in rows:
            row = QHBoxLayout(); row.addWidget(_gallery_badge("!", "#c84f6a")); row.addWidget(_gallery_text(heading, palette, strong=True)); row.addWidget(_gallery_text(detail, palette), 1); row.addWidget(QPushButton("확인")); layout.addLayout(row)
    elif key == "scanstatuscard":
        metrics = QHBoxLayout()
        for label, value in (("마지막 스캔", "2시간 전"), ("성공", "210"), ("실패", "1"), ("수동 수정", "3")):
            box = QVBoxLayout(); box.addWidget(_gallery_text(label, palette)); box.addWidget(_gallery_text(value, palette, strong=True)); metrics.addLayout(box)
        layout.addLayout(metrics); _labeled_progress(layout, "인벤토리 신뢰도", 96, palette)
    elif key == "detaildrawer":
        header = QHBoxLayout(); header.addWidget(_gallery_text("세이아", palette, strong=True)); header.addStretch(1); header.addWidget(QPushButton("닫기 ×")); layout.addLayout(header)
        layout.addWidget(_gallery_text("현재 Lv.90 · 목표 EX5 · 계획 그룹 2개", palette))
        tabs = QHBoxLayout()
        for text in ("현재 상태", "목표", "필요 재화", "이력"): tabs.addWidget(QPushButton(text))
        layout.addLayout(tabs); _labeled_progress(layout, "목표 충족률", 72, palette)
    elif key == "emptystate":
        symbol = QLabel("◇"); symbol.setAlignment(Qt.AlignCenter); symbol.setStyleSheet(f"color:{palette.get('accent', DEFAULT_PALETTE['accent'])}; font-size:34px;")
        layout.addWidget(symbol); action = QPushButton("첫 계획 만들기"); layout.addWidget(action, 0, Qt.AlignCenter)

    layout.addStretch(1)
    panel.setMinimumSize(420, 180)
    panel.setMaximumHeight(300)
    return panel


def _section_sample(entry_id: str, palette: dict[str, str], parent: QWidget) -> QWidget:
    key = _section_key(entry_id)
    feature_start = next(
        index for index, style in enumerate(_SECTION_GALLERY_STYLES)
        if style.gallery_id == "section:studentFilterBar"
    )
    feature_keys = {
        style.gallery_id.removeprefix("section:").lower()
        for style in _SECTION_GALLERY_STYLES[feature_start:]
    }
    if key.split("#")[-1] in feature_keys:
        widget = _feature_section_sample(entry_id, palette, parent)
    elif "scanheader" in key:
        widget = _scan_header_sample(entry_id, palette, parent)
    elif "home" in key or any(marker in key for marker in ("menusection", "connectionsection")):
        widget = _home_section_sample(entry_id, palette, parent)
    else:
        widget = _standard_section_sample(entry_id, palette, parent)
    if "home" in key and "scanheader" not in key:
        widget.setMinimumSize(360, 520)
        widget.setMaximumHeight(720)
    else:
        widget.setMinimumSize(360, 190)
        widget.setMaximumHeight(300)
    return widget


def _create_entry_sample(
    entry_id: str,
    widget_type: str,
    palette: dict[str, str],
    parent: QWidget,
) -> QWidget:
    if _is_section_entry(entry_id):
        return _section_sample(entry_id, palette, parent)
    if entry_id.startswith("asset:"):
        return _asset_sample(entry_id, parent)
    if entry_id.startswith("widget:"):
        return _widget_contract_sample(entry_id, palette, parent)
    return _sample_widget(widget_type, parent)


def _compose_widget_style(widget: QWidget, base_style: str, style: str) -> str:
    """Combine full QSS blocks with declaration-only UCS edits safely."""
    base = str(base_style or "").strip()
    override = str(style or "").strip()
    if not override:
        return base
    if "{" in override:
        layer = override
    else:
        object_name = widget.objectName().strip()
        selector = f"#{object_name}" if object_name else type(widget).__name__
        layer = f"{selector} {{\n{override}\n}}"
    return "\n".join(part for part in (base, layer) if part)


class AspectRatioThumbnail(QLabel):
    """Letterboxed section snapshot that never stretches its source ratio."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._source_pixmap = QPixmap()
        self.setObjectName("sectionThumbnail")
        self.setAlignment(Qt.AlignCenter)
        self.setMinimumSize(360, 220)
        self.setMaximumHeight(300)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setStyleSheet("QLabel#sectionThumbnail { background: #5f6268; border: none; }")

    def setSourcePixmap(self, pixmap: QPixmap) -> None:
        self._source_pixmap = QPixmap(pixmap)
        self._refresh_scaled_pixmap()

    def sourcePixmap(self) -> QPixmap:
        return QPixmap(self._source_pixmap)

    def sourceAspectRatio(self) -> float:
        if self._source_pixmap.isNull() or self._source_pixmap.height() <= 0:
            return 0.0
        return self._source_pixmap.width() / self._source_pixmap.height()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._refresh_scaled_pixmap()

    def _refresh_scaled_pixmap(self) -> None:
        if self._source_pixmap.isNull():
            self.clear()
            return
        available = self.contentsRect().size()
        if available.width() <= 0 or available.height() <= 0:
            return
        self.setPixmap(
            self._source_pixmap.scaled(
                available,
                Qt.KeepAspectRatio,
                Qt.SmoothTransformation,
            )
        )


def _render_sample_pixmap(sample: QWidget) -> QPixmap:
    """Render a catalog-only sample at its authored ratio, not the grid ratio."""
    source_size = sample.minimumSize().expandedTo(sample.sizeHint())
    source_size.setWidth(max(1, source_size.width()))
    source_size.setHeight(max(1, source_size.height()))
    sample.resize(source_size)
    sample.ensurePolished()
    if sample.layout() is not None:
        sample.layout().activate()
    pixmap = QPixmap(source_size)
    pixmap.fill(Qt.transparent)
    sample.render(pixmap)
    return pixmap


class _RuntimeSectionThumbnailRenderer:
    """Render all runtime-backed cards through one temporary design window."""

    def __init__(self, spec: UIDesignSpec) -> None:
        self.spec = spec
        self.source: QMainWindow | None = None

    def _ensure_source(self) -> QMainWindow:
        if self.source is not None:
            return self.source
        from gui.ui_design_runtime import apply_ui_design_spec
        from gui.viewer_app_qt import StudentViewerWindow

        source = StudentViewerWindow(1.0, design_mode=True)
        source._startup_window_applied = True
        source.setAttribute(Qt.WA_DontShowOnScreen, True)
        source.resize(SectionPreviewWindow.PREVIEW_WIDTH, SectionPreviewWindow.PREVIEW_HEIGHT)
        source.show()
        QApplication.processEvents()
        apply_ui_design_spec(source, self.spec)
        self.source = source
        return source

    def render(self, entry_id: str, style_sheet: str = "") -> QPixmap:
        target_spec = _RUNTIME_SECTION_TARGETS.get(entry_id)
        if target_spec is None:
            return QPixmap()
        cache_key = (repr(self.spec), entry_id, style_sheet.strip())
        cached = _RUNTIME_THUMBNAIL_CACHE.get(cache_key)
        if cached is not None and not cached.isNull():
            return QPixmap(cached)
        source = self._ensure_source()
        target = getattr(source, target_spec[0], None)
        if not isinstance(target, QWidget):
            return QPixmap()

        slot_name, scan_mode = target_spec[1], target_spec[2]
        if scan_mode is not None:
            source._show_home_scan_layout_preview(scan_mode, animate=False)
            if entry_id == "section:scanResultSection":
                target.setGeometry(source._scan_right_section.geometry())
            QApplication.processEvents()
        if slot_name is not None:
            slot = getattr(source, slot_name)
            target.setGeometry(slot.rect())
        target.show()
        QApplication.processEvents()

        source_size = target.size().expandedTo(target.minimumSize()).expandedTo(target.sizeHint())
        if source_size.width() <= 0 or source_size.height() <= 0:
            return QPixmap()
        original_style = target.styleSheet()
        if style_sheet.strip():
            target.setStyleSheet(_compose_widget_style(target, original_style, style_sheet))
        try:
            pixmap = QPixmap(source_size)
            pixmap.fill(Qt.transparent)
            target.render(pixmap)
            _RUNTIME_THUMBNAIL_CACHE[cache_key] = QPixmap(pixmap)
            return pixmap
        finally:
            if target.styleSheet() != original_style:
                target.setStyleSheet(original_style)

    def close(self) -> None:
        if self.source is None:
            return
        self.source.setAttribute(Qt.WA_DeleteOnClose, True)
        self.source.close()
        self.source = None
        QApplication.processEvents()


class GalleryCard(QFrame):
    def __init__(self, entry_id: str, title: str, widget_type: str, palette: dict[str, str], on_select, parent=None):
        super().__init__(parent)
        self.entry_id = entry_id
        self.setObjectName("galleryCard")
        self.setFrameShape(QFrame.StyledPanel)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 10, 12, 12)
        header = QPushButton(title)
        header.setFlat(True)
        header.setToolTip(entry_id)
        header.clicked.connect(lambda: on_select(entry_id))
        self.sample = _create_entry_sample(entry_id, widget_type, palette, self)
        self.sample.setProperty("uiStudioGalleryBaseStyle", self.sample.styleSheet())
        layout.addWidget(header)
        self.thumbnail: AspectRatioThumbnail | None = None
        if _is_section_entry(entry_id):
            # The editable sample remains available to the inspector, while
            # the card displays a non-interactive snapshot. This prevents the
            # gallery grid from resizing and distorting the real section tree.
            self.sample.hide()
            self.thumbnail = AspectRatioThumbnail(self)
            layout.addWidget(self.thumbnail)
        else:
            layout.addWidget(self.sample)

    def refresh_thumbnail(
        self,
        runtime_renderer: "_RuntimeSectionThumbnailRenderer | None" = None,
        style_sheet: str = "",
    ) -> None:
        if self.thumbnail is None:
            return
        pixmap = QPixmap()
        if self.entry_id in _RUNTIME_SECTION_TARGETS and runtime_renderer is not None:
            pixmap = runtime_renderer.render(self.entry_id, style_sheet)
        if pixmap.isNull():
            pixmap = _render_sample_pixmap(self.sample)
        self.thumbnail.setSourcePixmap(pixmap)

    def set_selected(self, selected: bool) -> None:
        self.setProperty("selected", selected)
        self.style().unpolish(self)
        self.style().polish(self)


_TAB_STATE_SPECS = {
    "홈": {
        "startup": "시작 → 대시보드",
        "states": (
            "대시보드\n메뉴 + 연결",
            "대시보드\n메뉴 + 설정/아이템/재화",
            "스캔 진행\n헤더 + 디버그 + 미러 + 작업",
            "스캔 완료\n헤더 + 디버그 + 미러 + 결과",
        ),
        "transitions": (
            (0, 1, "메뉴 버튼 / HomeSectionHost.transitionTo"),
            (0, 2, "스캔 시작 / _home_start_scan"),
            (2, 3, "스캔 완료 / _show_scan_result_transition"),
            (2, 0, "뒤로 / _home_return_dashboard"),
            (3, 0, "결과 닫기"),
        ),
        "sections": "homeRootStack → homeDashboard[menuHost, centerHost, rightHost]\n"
                    "homeRootStack → scanWorkspace[scanDebugSection, scanMirrorSection, "
                    "scanWorkSection|scanResultSection]",
    },
    "학생부": {
        "startup": "탭 진입 → 필터 복원 → 학생 목록",
        "states": ("학생 목록\n필터 + 그룹 + 카드", "학생 상세\n선택 학생", "육성 목표 편집\n프리셋 + 마일스톤"),
        "transitions": ((0, 1, "학생 선택"), (1, 2, "목표 편집"), (2, 1, "적용/취소"), (1, 0, "목록으로")),
        "sections": "studentFilterBar → studentGroupSelector → studentCardGrid\n"
                    "studentDetail → trainingTargetEditor[targetPresetSelector, trainingMilestoneEditor]",
    },
    "계획": {
        "startup": "탭 진입 → 계획 데이터 새로고침",
        "states": ("계획 목록\nplanBand + planGroupCard", "계획 편집\nplanEditorSectionCard", "비교\nscenarioCompareCard"),
        "transitions": ((0, 1, "계획 생성/선택"), (1, 0, "저장/닫기"), (0, 2, "시나리오 비교"), (2, 0, "비교 닫기")),
        "sections": "planBand → planGroupCard[priorityList]\nplanEditorSectionCard → planEditorContentPanel",
    },
    "필요 재화": {
        "startup": "숨김 탭 → 계획에서 요청 시 진입",
        "states": ("요구량 요약", "사용처 상세", "병목/충돌 분석"),
        "transitions": ((0, 1, "행 선택"), (1, 0, "상세 닫기"), (0, 2, "분석 보기"), (2, 0, "요약으로")),
        "sections": "resourceCategorySummary → resourceRequirementTable\n"
                    "resourceUsagePanel → currentVsTargetPanel → bottleneckPanel/conflictAlertPanel",
    },
    "인벤토리": {
        "startup": "탭 진입 → 마지막 장비/아이템 모드 복원",
        "states": ("장비\n시리즈 탭 + 그리드", "아이템\n카테고리 탭 + 그리드"),
        "transitions": ((0, 1, "루트 모드: 아이템"), (1, 0, "루트 모드: 장비")),
        "sections": "inventoryRootTabs → equipmentTabs → equipmentGrid\n"
                    "inventoryRootTabs → itemTabs → itemGrid",
    },
    "전술대항전": {
        "startup": "탭 진입 → 편성/인사이트 복원",
        "states": ("편성", "인사이트", "상세 분석"),
        "transitions": ((0, 1, "인사이트 버튼"), (1, 2, "항목 선택"), (2, 1, "상세 닫기"), (1, 0, "편성 버튼")),
        "sections": "tacticalRoster → tacticalInsightStack → detailDrawer",
    },
    "통계": {
        "startup": "숨김 탭 → 통계 요청 시 데이터 집계",
        "states": ("요약 KPI", "차트 탭", "분포/추이 상세"),
        "transitions": ((0, 1, "차트 선택"), (1, 2, "데이터 포인트 선택"), (2, 1, "상세 닫기")),
        "sections": "statisticsPanel → metricCard[] → statsChartTabs\n"
                    "distributionBarChart/histogram/stackedBar/heatmap/scatterPlot/trendChart",
    },
}

_APP_OVERVIEW_SPEC = {
    "startup": "앱 실행 → 메인 UI 구성 → 홈 탭/대시보드",
    "states": ("홈", "학생부", "계획", "필요 재화\n(숨김)", "인벤토리", "전술대항전", "통계\n(숨김)"),
    "transitions": (
        (0, 1, "홈 메뉴 또는 탭: 학생부"), (0, 2, "홈 메뉴 또는 탭: 계획"),
        (0, 4, "홈 메뉴 또는 탭: 인벤토리"), (0, 5, "홈 메뉴 또는 탭: 전술대항전"),
        (2, 3, "계획: 필요 재화"), (1, 2, "학생 상세: 플랜에 추가"),
        (2, 1, "계획: 학생 탭에서 보기"),
    ),
    "sections": "mainTabs → home | students | plan | resource(hidden) | inventory | tactical | statistics(hidden)",
}


def _section_edge(
    edge_id: str,
    source: str,
    button: str,
    target: str,
    action: str,
    guard: str = "-",
    result: str = "섹션 전환",
) -> dict[str, str]:
    return {
        "id": edge_id, "source": source, "button": button, "target": target,
        "action": action, "guard": guard, "result": result,
    }


_SECTION_FLOW_SPECS = {
    "전체 화면": (
        _section_edge("app.home.students", "홈 대시보드", "학생부 확인", "학생부", "_home_navigate_main(_students_tab)"),
        _section_edge("app.home.plan", "홈 대시보드", "계획 설정", "계획", "_home_navigate_main(_plan_tab)"),
        _section_edge("app.home.inventory", "홈 대시보드", "인벤토리", "인벤토리", "_home_navigate_main(_inventory_tab)"),
        _section_edge("app.home.tactical", "홈 대시보드", "전술대항전", "전술대항전", "_home_navigate_main(_tactical_tab)"),
        _section_edge("app.students.plan", "학생 상세", "플랜에 추가", "계획", "_add_current_student_to_plan"),
        _section_edge("app.plan.students", "계획 학생", "학생 탭에서 보기", "학생 상세", "_focus_selected_plan_student_in_viewer"),
        _section_edge("app.plan.resources", "계획 편집", "필요 재화", "필요 재화", "plan_editor_stack.setCurrentIndex(1)"),
    ),
    "홈": (
        _section_edge("home.connection.open", "homeMenuSection", "연결", "homeConnectionSection", "_home_primary_action", "게임 창 미연결"),
        _section_edge("home.scan_menu.open", "homeMenuSection", "연결/스캔", "homeScanSection", "_home_primary_action", "게임 창 연결됨"),
        _section_edge("home.settings.open", "homeMenuSection", "설정", "homeSettingsSection", "_home_show_settings"),
        _section_edge("home.items.open", "homeScanSection", "아이템", "homeItemCategorySection", "_home_show_item_categories"),
        _section_edge("home.resources.open", "homeItemCategorySection", "재화 직접 입력", "homeResourcePromptSection", "_home_show_resource_prompt"),
        _section_edge("home.resources.cancel", "homeResourcePromptSection", "취소", "homeItemCategorySection", "_home_cancel_resource_prompt"),
        _section_edge("home.resources.save", "homeResourcePromptSection", "확인", "homeItemCategorySection", "_home_save_manual_resources", "두 값이 유효한 정수"),
        _section_edge("home.scan.students", "homeScanSection", "학생", "scanWorkspace/student mirror", "_home_start_scan('students')", "연결됨 / 실행 중 아님"),
        _section_edge("home.scan.current", "homeScanSection", "단일", "scanWorkspace/student mirror", "_home_start_scan('student_current')", "연결됨 / 실행 중 아님"),
        _section_edge("home.scan.equipment", "homeScanSection", "장비", "scanWorkspace/inventory mirror", "_home_start_scan('equipment')", "연결됨 / 실행 중 아님"),
        _section_edge("home.scan.items", "homeItemCategorySection", "아이템 종류", "scanWorkspace/inventory mirror", "_home_start_scan('items', filter)", "연결됨 / 실행 중 아님"),
        _section_edge("home.scan.result", "scanWorkSection", "스캔 완료 이벤트", "scanResultSection", "_show_scan_result_transition", "프로세스 종료 code=0"),
        _section_edge("home.scan.back", "scanWorkspace", "홈으로", "homeDashboard", "_home_return_dashboard"),
    ),
    "학생부": (
        _section_edge("students.filter.open", "studentFilterBar", "필터", "filterDialog", "_open_filter_dialog"),
        _section_edge("students.detail.open", "studentCardGrid", "학생 카드", "studentDetail", "student selection handler", "학생 존재"),
        _section_edge("students.plan.open", "studentDetail", "플랜에 추가", "계획", "_add_current_student_to_plan", "학생 선택됨"),
    ),
    "계획": (
        _section_edge("plan.student.select", "planGroupCard", "계획 학생", "planEditorSectionCard", "plan selection handler"),
        _section_edge("plan.editor.targets", "planEditorSectionCard", "목표 타겟", "trainingTargetEditor", "plan_editor_stack.setCurrentIndex(0)"),
        _section_edge("plan.editor.resources", "planEditorSectionCard", "필요 재화", "resourceRequirementTable", "plan_editor_stack.setCurrentIndex(1)"),
        _section_edge("plan.student.open", "planEditorSectionCard", "학생 탭에서 보기", "학생 상세", "_focus_selected_plan_student_in_viewer", "계획 학생 선택됨"),
    ),
    "필요 재화": (
        _section_edge("resources.mode.scope", "resourceSearchSection", "범위", "resourceScopeSection", "_set_resource_left_mode(0)"),
        _section_edge("resources.mode.search", "resourceScopeSection", "검색", "resourceSearchSection", "_set_resource_left_mode(1)"),
        _section_edge("resources.filter.open", "resourceSearchSection", "필터", "filterDialog", "_open_filter_dialog"),
        _section_edge("resources.search.commit", "resourceSearchSection", "선택한 학생 추가", "resourceScopeSection", "_resource_add_pending_to_scope", "선택 있음"),
    ),
    "인벤토리": (
        _section_edge("inventory.equipment.open", "inventoryItemSection", "장비", "inventoryEquipmentSection", "_set_inventory_root_mode(0)"),
        _section_edge("inventory.items.open", "inventoryEquipmentSection", "아이템", "inventoryItemSection", "_set_inventory_root_mode(1)"),
        _section_edge("inventory.pressure.equipment", "inventoryPressurePanel", "장비", "equipmentPressureSection", "_set_inventory_pool_pressure_mode('equipment')"),
        _section_edge("inventory.pressure.ooparts", "inventoryPressurePanel", "오파츠", "oopartsPressureSection", "_set_inventory_pool_pressure_mode('ooparts')"),
    ),
    "전술대항전": (
        _section_edge("tactical.insight.opponent", "tacticalJokboSection", "상대", "tacticalOpponentSection", "tactical_insight_stack.setCurrentIndex(0)"),
        _section_edge("tactical.insight.jokbo", "tacticalOpponentSection", "족보", "tacticalJokboSection", "tactical_insight_stack.setCurrentIndex(1)"),
        _section_edge("tactical.history.edit", "tacticalHistorySection", "수정", "tacticalMatchEditor", "_edit_selected_tactical_match", "전적 선택됨"),
        _section_edge("tactical.abbrev.open", "tacticalMainSection", "펼치기/접기", "tacticalAbbreviationSection", "_set_tactical_abbreviation_expanded"),
    ),
    "통계": (
        _section_edge("stats.chart.change", "statisticsPanel", "차트 탭", "selectedChartSection", "_stats_chart_tab_changed"),
        _section_edge("stats.sunburst.drill", "sunburstSection", "차트 노드", "sunburstDetailSection", "_stats_apply_sunburst_path"),
        _section_edge("stats.sunburst.back", "sunburstDetailSection", "뒤로/전체", "sunburstSection", "_stats_sunburst_back"),
    ),
}

_SECTION_HANDLER_MARKERS = (
    "setCurrentIndex", "setCurrentWidget", "_navigate_", "_transition", "_set_resource_left_mode",
    "_set_inventory_root_mode", "_set_inventory_pool_pressure_mode", "_open_filter_dialog",
    "_home_start_scan", "_home_show_", "_home_return_dashboard", "_focus_selected_plan_student",
    "_add_current_student_to_plan", "_edit_selected_tactical_match", "_set_tactical_abbreviation_expanded",
    "_stats_chart_tab_changed", "_stats_apply_sunburst_path", "_stats_sunburst_back",
)

_BEHAVIOR_SOURCE_FILES = {
    "홈": ("gui/viewer_components/home.py", "gui/viewer_components/scan.py"),
    "학생부": ("gui/viewer_components/students.py",),
    "계획": ("gui/viewer_components/planner.py",),
    "필요 재화": ("gui/viewer_components/resources.py",),
    "인벤토리": ("gui/viewer_components/inventory.py",),
    "전술대항전": ("gui/viewer_components/tactical.py",),
    "통계": ("gui/viewer_components/statistics.py",),
}
_TAB_ID_PREFIX = {
    "전체 화면": "app", "홈": "home", "학생부": "students", "계획": "plan",
    "필요 재화": "resources", "인벤토리": "inventory", "전술대항전": "tactical", "통계": "stats",
}
_TAB_MARKDOWN_FILES = {
    "전체 화면": UI_BEHAVIOR_DOCS_DIR / "README.md",
    "홈": UI_BEHAVIOR_DOCS_DIR / "home.md",
    "학생부": UI_BEHAVIOR_DOCS_DIR / "students.md",
    "계획": UI_BEHAVIOR_DOCS_DIR / "plan.md",
    "필요 재화": UI_BEHAVIOR_DOCS_DIR / "resources.md",
    "인벤토리": UI_BEHAVIOR_DOCS_DIR / "inventory.md",
    "전술대항전": UI_BEHAVIOR_DOCS_DIR / "tactical.md",
    "통계": UI_BEHAVIOR_DOCS_DIR / "statistics.md",
}


def _behavior(
    event_id: str,
    state: str,
    control: str,
    event: str,
    guard: str,
    action: str,
    next_state: str,
    visible: str,
    recovery: str = "-",
) -> dict[str, str]:
    return {
        "id": event_id, "state": state, "control": control, "event": event,
        "guard": guard, "action": action, "next": next_state,
        "visible": visible, "recovery": recovery,
    }


_TAB_BEHAVIOR_TRANSITIONS = {
    "홈": (
        _behavior("home.primary.open_connection", "대시보드/미연결", "_home_primary_button", "클릭", "저장된 연결 없음", "_home_primary_action → 창 후보 새로고침", "연결 선택", "우측 연결 섹션 표시"),
        _behavior("home.primary.toggle_scan", "대시보드/연결됨", "_home_primary_button", "클릭", "게임 창 연결됨", "_home_primary_action", "스캔 메뉴 열림/닫힘", "우측 스캔 섹션 전환"),
        _behavior("home.connection.refresh", "연결 선택", "refresh", "클릭", "-", "_refresh_home_window_candidates", "연결 선택", "창 후보 목록 갱신"),
        _behavior("home.connection.confirm", "연결 선택", "_home_window_confirm_button", "클릭", "후보 선택됨", "_apply_home_window_candidate", "대시보드/연결됨", "연결 대상 라벨 갱신"),
        _behavior("home.connection.cancel", "연결 선택", "cancel", "클릭", "-", "_cancel_home_window_selection", "대시보드", "연결 섹션 닫힘"),
        _behavior("home.navigate.students", "대시보드", "학생부 확인", "클릭", "-", "_home_navigate_main(_students_tab)", "학생부 탭", "메인 탭 전환"),
        _behavior("home.navigate.plan", "대시보드", "계획 설정", "클릭", "-", "_home_navigate_main(_plan_tab)", "계획 탭", "메인 탭 전환"),
        _behavior("home.navigate.inventory", "대시보드", "인벤토리", "클릭", "-", "_home_navigate_main(_inventory_tab)", "인벤토리 탭", "메인 탭 전환"),
        _behavior("home.navigate.tactical", "대시보드", "전술대항전", "클릭", "-", "_home_navigate_main(_tactical_tab)", "전술대항전 탭", "메인 탭 전환"),
        _behavior("home.settings.toggle", "대시보드", "설정", "클릭", "-", "_home_show_settings", "설정 열림/닫힘", "중앙 설정 섹션 전환"),
        _behavior("home.settings.profile.apply", "설정", "apply_profile", "클릭", "프로필 선택됨", "_apply_selected_profile", "설정", "활성 프로필·계정 정보 갱신", "실패 경고"),
        _behavior("home.settings.profile.create", "설정", "new_profile", "클릭", "유효한 이름", "_create_profile", "설정", "새 프로필 선택", "중복/입력 오류 경고"),
        _behavior("home.settings.profile.refresh", "설정", "refresh_profile", "클릭", "-", "_refresh_settings_profiles", "설정", "프로필 목록 갱신"),
        _behavior("home.settings.account.open", "설정", "account_settings", "클릭", "-", "_open_account_settings_dialog", "계정 설정 다이얼로그", "계정 편집 UI 표시"),
        _behavior("home.settings.disconnect", "설정/연결됨", "_settings_disconnect_button", "클릭", "연결됨", "_disconnect_target_window", "설정/미연결", "연결 라벨·홈 액션 갱신"),
        _behavior("home.settings.report", "설정", "report_button", "클릭", "-", "_open_bug_report_dialog", "문제 신고 다이얼로그", "신고 양식 표시"),
        _behavior("home.scan.students", "스캔 메뉴", "student", "클릭", "연결됨 / 실행 중 아님", "_home_start_scan('students')", "스캔 진행", "학생 미러 + 로그 + 진행률", "실행 실패 → 설정"),
        _behavior("home.scan.current_student", "스캔 메뉴", "single_student", "클릭", "연결됨 / 실행 중 아님", "_home_start_scan('student_current')", "스캔 진행", "단일 학생 미러", "실행 실패 → 설정"),
        _behavior("home.scan.items", "아이템 종류", "동적 item button", "클릭", "연결됨 / 실행 중 아님", "_home_start_scan('items', filter)", "스캔 진행", "인벤토리 그리드 미러", "실행 실패 → 설정"),
        _behavior("home.scan.equipment", "스캔 메뉴", "equipment", "클릭", "연결됨 / 실행 중 아님", "_home_start_scan('equipment')", "스캔 진행", "장비 그리드 미러", "실행 실패 → 설정"),
        _behavior("home.scan.cancel", "스캔 진행", "_scan_stop_button", "클릭", "프로세스 실행 중", "_request_scanner_stop", "중지 요청", "버튼 비활성 + 중지 요청 라벨", "프로세스 종료 코드 표시"),
        _behavior("home.scan.success", "스캔 진행", "scanner process", "종료 code=0", "지원 스캔 모드", "_on_scanner_process_finished", "스캔 완료", "우측 결과 섹션 전환"),
        _behavior("home.scan.failure", "스캔 진행", "scanner process", "종료 code≠0", "-", "_on_scanner_process_finished", "스캔 실패", "오류 코드 + 알림", "대시보드 복귀 가능"),
        _behavior("home.resources.save", "수동 재화 입력", "confirm", "클릭", "두 값이 0 이상 정수", "_home_save_manual_resources", "아이템 종류", "저장 후 데이터 갱신", "입력 오류 → 현재 상태 유지"),
        _behavior("home.resources.cancel", "수동 재화 입력", "cancel", "클릭", "-", "_home_cancel_resource_prompt", "아이템 종류", "입력 패널 닫힘"),
    ),
    "학생부": (
        _behavior("students.filter.open", "학생 목록", "_filter_button", "클릭", "-", "_open_filter_dialog", "필터 다이얼로그", "배경 입력 차단"),
        _behavior("students.refresh", "학생 목록", "refresh_button", "클릭", "-", "_reload_data", "학생 목록", "목록·통계 갱신"),
        _behavior("students.select", "학생 목록", "studentGrid/card", "선택", "학생 존재", "detail selection handler", "학생 상세", "선택 학생 상세 표시"),
        _behavior("students.add_to_plan", "학생 상세", "_detail_plan_button", "클릭", "학생 선택됨", "_add_current_student_to_plan", "학생 상세", "계획 포함 상태 갱신"),
    ),
    "계획": (
        _behavior("plan.add", "계획 목록", "_plan_add_button", "클릭", "검색 학생 선택됨", "_add_selected_student_to_plan", "계획 학생 선택", "학생 행 추가"),
        _behavior("plan.remove", "계획 학생 선택", "_plan_remove_button", "클릭", "계획 학생 선택됨", "_remove_selected_plan_student", "계획 목록", "학생 행 제거"),
        _behavior("plan.open_student", "계획 학생 선택", "_plan_open_button", "클릭", "계획 학생 선택됨", "_focus_selected_plan_student_in_viewer", "학생부 상세", "학생부 탭 전환"),
        _behavior("plan.editor.targets", "계획 편집", "목표 타겟", "클릭", "-", "plan_editor_stack.setCurrentIndex(0)", "목표 편집", "목표 컨트롤 표시"),
        _behavior("plan.editor.resources", "계획 편집", "필요 재화", "클릭", "-", "plan_editor_stack.setCurrentIndex(1)", "필요 재화", "요구량 결과 표시"),
        _behavior("plan.ability.toggle", "목표 편집", "stat_toggle", "클릭", "-", "_toggle_ability_release_targets", "목표 편집", "능력 해방 목표 펼침/접힘"),
    ),
    "필요 재화": (
        _behavior("resources.filter.open", "검색", "_resource_filter_button", "클릭", "-", "_open_filter_dialog", "필터 다이얼로그", "배경 입력 차단"),
        _behavior("resources.refresh", "범위/검색", "resource_refresh_button", "클릭", "-", "_reload_data", "현재 모드", "재화 계산 갱신"),
        _behavior("resources.mode.scope", "검색", "범위", "클릭", "-", "_set_resource_left_mode(0)", "범위", "계획 범위 그리드 표시"),
        _behavior("resources.mode.search", "범위", "검색", "클릭", "-", "_set_resource_left_mode(1)", "검색", "학생 검색 그리드 표시"),
        _behavior("resources.scope.remove", "범위", "_resource_remove_scope_button", "클릭", "선택 있음", "_resource_remove_scope_selected", "범위", "선택 학생 제거"),
        _behavior("resources.scope.clear", "범위", "비우기", "클릭", "-", "_resource_clear_checked", "범위/비어 있음", "범위 초기화"),
        _behavior("resources.search.add_selected", "검색", "_resource_add_selected_button", "클릭", "선택 있음", "_resource_add_pending_to_scope", "범위", "선택 학생을 계산 범위에 추가"),
        _behavior("resources.search.add_visible", "검색", "결과 전체 추가", "클릭", "검색 결과 있음", "_resource_check_visible", "범위", "표시 결과 추가"),
        _behavior("resources.search.clear", "검색", "선택 해제", "클릭", "-", "_resource_clear_search_selection", "검색", "검색 선택 해제"),
    ),
    "인벤토리": (
        _behavior("inventory.mode.equipment", "아이템", "장비", "클릭", "-", "_set_inventory_root_mode(0)", "장비", "장비 시리즈 탭 표시"),
        _behavior("inventory.mode.items", "장비", "아이템", "클릭", "-", "_set_inventory_root_mode(1)", "아이템", "아이템 카테고리 탭 표시"),
        _behavior("inventory.pressure.equipment", "장비/아이템", "장비 압박", "클릭", "-", "_set_inventory_pool_pressure_mode('equipment')", "장비 압박", "장비 부족 분포 표시"),
        _behavior("inventory.pressure.ooparts", "장비/아이템", "오파츠 압박", "클릭", "-", "_set_inventory_pool_pressure_mode('ooparts')", "오파츠 압박", "오파츠 부족 분포 표시"),
    ),
    "전술대항전": (
        _behavior("tactical.history.more", "전적 목록", "_tactical_match_load_more_button", "클릭", "추가 데이터 있음", "_load_more_tactical_matches", "전적 목록", "다음 전적 추가"),
        _behavior("tactical.history.copy_attack", "전적 선택", "_tactical_match_copy_attack_button", "클릭", "전적 선택됨", "_copy_selected_tactical_match_attack", "입력 편성", "공격 편성 복사"),
        _behavior("tactical.history.copy_defense", "전적 선택", "_tactical_match_copy_defense_button", "클릭", "전적 선택됨", "_copy_selected_tactical_match_defense", "입력 편성", "방어 편성 복사"),
        _behavior("tactical.history.edit", "전적 선택", "_tactical_match_edit_button", "클릭", "전적 선택됨", "_edit_selected_tactical_match", "전적 편집", "선택 전적 입력 패널로 이동"),
        _behavior("tactical.history.delete", "전적 선택", "_tactical_match_delete_button", "클릭", "전적 선택 + 확인", "_delete_selected_tactical_match", "전적 목록", "전적 삭제"),
        _behavior("tactical.history.import", "전적 목록", "_tactical_match_import_button", "클릭", "파일 선택", "_import_tactical_spreadsheet", "전적 목록", "Excel 전적 반영", "형식 오류 경고"),
        _behavior("tactical.insight.opponent", "족보", "상대", "클릭", "-", "tactical_insight_stack.setCurrentIndex(0)", "상대 인사이트", "상대 검색 패널 표시"),
        _behavior("tactical.insight.jokbo", "상대 인사이트", "족보", "클릭", "-", "tactical_insight_stack.setCurrentIndex(1)", "족보", "족보 검색 패널 표시"),
        _behavior("tactical.match.result", "전적 입력", "승/패", "클릭", "-", "_set_tactical_panel_result", "전적 입력", "승패 선택 표시"),
        _behavior("tactical.match.mode", "전적 입력", "공격/방어/족보", "클릭", "-", "_set_tactical_panel_mode", "전적 입력", "입력 모드 전환"),
        _behavior("tactical.match.save", "전적 입력", "save_button", "클릭", "필수 입력 유효", "_save_tactical_match_panel", "전적 목록", "전적 저장", "검증 실패 → 현재 상태"),
        _behavior("tactical.match.clear", "전적 입력", "clear_button", "클릭", "-", "_clear_tactical_match_panel", "빈 전적 입력", "입력 초기화"),
        _behavior("tactical.capture", "전적 입력", "캡처/Folder/붙여넣기", "클릭", "이미지 사용 가능", "_import/_paste_tactical_screenshot_panel", "전적 입력", "인식 결과 채움", "인식 실패 경고"),
        _behavior("tactical.abbrev.toggle", "전술대항전", "_tactical_abbrev_toggle", "클릭", "-", "_set_tactical_abbreviation_expanded", "약어 편집 열림/닫힘", "약어 행 표시 전환"),
    ),
    "통계": (
        _behavior("stats.sunburst.root", "선버스트 탐색", "_stats_sunburst_root_button", "클릭", "-", "_stats_reset_sunburst_root", "전체 통계", "루트 차트 표시"),
        _behavior("stats.sunburst.back", "하위 통계", "_stats_sunburst_back_button", "클릭", "breadcrumb 있음", "_stats_sunburst_back", "상위 통계", "상위 차트 표시"),
        _behavior("stats.sunburst.clear", "선버스트 선택", "_stats_sunburst_clear_button", "클릭", "선택 있음", "_stats_clear_sunburst_selection", "현재 통계", "선택 강조 해제"),
        _behavior("stats.chart.change", "통계", "_stats_chart_tabs", "탭 변경", "-", "_stats_chart_tab_changed", "선택 차트", "차트 페이지 전환"),
        _behavior("stats.mode.change", "선택 차트", "mode combo", "선택 변경", "-", "_stats_set_mode", "선택 차트", "집계 모드 변경"),
        _behavior("stats.breadcrumb", "하위 통계", "breadcrumb button", "클릭", "경로 유효", "_stats_apply_sunburst_path", "선택 상위 경로", "선버스트 재계산"),
    ),
}


def _discover_source_interactions(tab_name: str) -> list[dict[str, str]]:
    """Inventory signal connections without importing or executing the main UI."""
    interactions: list[dict[str, str]] = []
    assignment_pattern = re.compile(
        r"(?P<var>[A-Za-z_][\w.]*)\s*=\s*(?:QPushButton|ParallelogramButton|ParallelogramActionButton)\(\s*[furbFURB]*[\"'](?P<label>[^\"']*)"
    )
    signal_pattern = re.compile(
        r"(?P<control>[A-Za-z_][\w.]*)\.(?P<signal>clicked|toggled|currentChanged|currentIndexChanged|returnPressed|textChanged|itemDoubleClicked|selection_changed)\.connect\((?P<handler>.+)\)"
    )
    for relative in _BEHAVIOR_SOURCE_FILES.get(tab_name, ()):
        path = ROOT / relative
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue
        labels: dict[str, str] = {}
        for line in lines:
            match = assignment_pattern.search(line)
            if match:
                labels[match.group("var")] = match.group("label")
        for line_number, line in enumerate(lines, 1):
            match = signal_pattern.search(line.strip())
            if not match:
                continue
            control = match.group("control")
            handler = match.group("handler").strip()
            interactions.append({
                "control": control,
                "label": labels.get(control, "동적/텍스트 없음"),
                "signal": match.group("signal"),
                "handler": handler,
                "source": f"{relative}:{line_number}",
            })
    return interactions


class MarkdownMermaidView(QWebEngineView):
    """Render repository Markdown and its Mermaid blocks with local assets."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.current_path: Path | None = None
        self.last_html = ""

    @staticmethod
    def _document_html(markdown_text: str) -> tuple[str, list[str]]:
        diagrams: list[str] = []

        def replace_mermaid(match: re.Match) -> str:
            token = f"UCS_MERMAID_BLOCK_{len(diagrams)}"
            diagrams.append(match.group(1).strip())
            return f"\n{token}\n"

        markdown_without_diagrams = re.sub(
            r"```mermaid\s*\r?\n(.*?)```",
            replace_mermaid,
            markdown_text,
            flags=re.DOTALL | re.IGNORECASE,
        )
        document = QTextDocument()
        document.setMarkdown(markdown_without_diagrams)
        rendered = document.toHtml()
        body_match = re.search(r"<body[^>]*>(.*)</body>", rendered, flags=re.DOTALL | re.IGNORECASE)
        body = body_match.group(1) if body_match else rendered
        for index, diagram in enumerate(diagrams):
            token = f"UCS_MERMAID_BLOCK_{index}"
            body = body.replace(token, f'<div class="mermaid-card"><pre class="mermaid">{html.escape(diagram)}</pre></div>')
        return body, diagrams

    def load_markdown(self, path: Path) -> bool:
        self.current_path = path
        if not path.exists() or not MERMAID_BROWSER_BUNDLE.exists():
            missing = path if not path.exists() else MERMAID_BROWSER_BUNDLE
            self.setHtml(f"<h2>Markdown 미리보기를 열 수 없습니다.</h2><p>누락: {html.escape(str(missing))}</p>")
            return False
        markdown_text = path.read_text(encoding="utf-8")
        body, diagrams = self._document_html(markdown_text)
        mermaid_url = QUrl.fromLocalFile(str(MERMAID_BROWSER_BUNDLE)).toString()
        page_html = f"""<!doctype html>
<html><head><meta charset="utf-8">
<style>
body {{ font-family: "Noto Sans KR", "Malgun Gothic", sans-serif; margin: 24px; color: #22313d; background: #f4f6f8; }}
h1, h2, h3 {{ color: #18384b; }}
.mermaid-card {{ background: white; border: 1px solid #b9c8d3; border-radius: 10px; padding: 18px; margin: 18px 0; overflow: auto; }}
.mermaid {{ display: flex; justify-content: center; min-width: max-content; }}
table {{ border-collapse: collapse; width: 100%; background: white; }}
th, td {{ border: 1px solid #cbd5dd; padding: 7px 9px; text-align: left; }}
code {{ background: #e7edf2; padding: 2px 4px; border-radius: 4px; }}
#mermaid-error {{ color: #a42d2d; white-space: pre-wrap; }}
</style>
<script src="{mermaid_url}"></script></head>
<body>{body}<div id="mermaid-error"></div>
<script>
window.addEventListener('load', async () => {{
  try {{
    mermaid.initialize({{startOnLoad: false, securityLevel: 'strict', theme: 'neutral', flowchart: {{curve: 'basis', htmlLabels: true}}}});
    await mermaid.run({{querySelector: '.mermaid'}});
    document.body.dataset.mermaidRendered = 'true';
  }} catch (error) {{
    document.getElementById('mermaid-error').textContent = String(error && error.stack || error);
    document.body.dataset.mermaidRendered = 'false';
  }}
}});
</script></body></html>"""
        self.last_html = page_html
        self.setHtml(page_html, QUrl.fromLocalFile(str(path.parent) + "/"))
        return bool(diagrams)


class StateMachineCanvas(QWidget):
    """Mermaid-like, read-only section-edge renderer with one clear row per edge."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.spec: dict = {}
        self.setMinimumSize(820, 470)

    def set_spec(self, spec: dict) -> None:
        self.spec = spec
        rows = max(1, len(spec.get("transitions", ())))
        self.setMinimumSize(1040, max(470, 45 + rows * 92))
        self.update()

    def paintEvent(self, _event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.fillRect(self.rect(), QColor("#e9edf2"))
        states = self.spec.get("states", ())
        if not states:
            return
        source_x, button_x, target_x = 28, 375, 712
        section_w, button_w, box_h = 286, 250, 62
        font = painter.font(); font.setPointSize(max(8, font.pointSize() - 1)); painter.setFont(font)
        for row, (source, target, label) in enumerate(self.spec.get("transitions", ())):
            if source >= len(states) or target >= len(states):
                continue
            top = 24 + row * 92
            source_rect = QRectF(source_x, top, section_w, box_h)
            button_rect = QRectF(button_x, top + 7, button_w, box_h - 14)
            target_rect = QRectF(target_x, top, section_w, box_h)
            for rect, fill in ((source_rect, "#dff4f7"), (target_rect, "#ffffff")):
                painter.setPen(QPen(QColor("#5a7188"), 2))
                painter.setBrush(QColor(fill))
                painter.drawRoundedRect(rect, 12, 12)
            painter.setPen(QPen(QColor("#48768d"), 2))
            painter.drawLine(source_rect.right(), source_rect.center().y(), button_rect.left(), button_rect.center().y())
            painter.drawLine(button_rect.right(), button_rect.center().y(), target_rect.left(), target_rect.center().y())
            for end_x, center_y in ((button_rect.left(), button_rect.center().y()), (target_rect.left(), target_rect.center().y())):
                painter.drawLine(QPointF(end_x, center_y), QPointF(end_x - 9, center_y - 5))
                painter.drawLine(QPointF(end_x, center_y), QPointF(end_x - 9, center_y + 5))
            painter.setPen(QPen(QColor("#7a8fa0"), 1))
            painter.setBrush(QColor("#f4f7fa"))
            painter.drawRoundedRect(button_rect, 18, 18)
            painter.setPen(QColor("#243746"))
            painter.drawText(source_rect.adjusted(10, 6, -10, -6), Qt.AlignCenter | Qt.TextWordWrap, states[source])
            painter.drawText(button_rect.adjusted(8, 4, -8, -4), Qt.AlignCenter | Qt.TextWordWrap, label)
            painter.drawText(target_rect.adjusted(10, 6, -10, -6), Qt.AlignCenter | Qt.TextWordWrap, states[target])
            painter.setPen(QPen(QColor("#48768d"), 2))



class _PreviewInputGuard(QObject):
    """Allow pointer feedback while suppressing actions in design previews."""

    _BLOCKED_EVENTS = {
        QEvent.Type.MouseButtonPress,
        QEvent.Type.MouseButtonRelease,
        QEvent.Type.MouseButtonDblClick,
        QEvent.Type.ContextMenu,
    }

    def protect(self, root: QWidget) -> None:
        root.installEventFilter(self)
        for obj in root.findChildren(QObject):
            obj.installEventFilter(self)

    def eventFilter(self, watched: QObject, event: QEvent) -> bool:
        if event.type() in self._BLOCKED_EVENTS:
            event.accept()
            return True
        return super().eventFilter(watched, event)


class SectionPreviewWindow(QMainWindow):
    """Planner-sized preview with visual pointer feedback but blocked actions."""

    PREVIEW_WIDTH = 1920
    PREVIEW_HEIGHT = 1080
    PULL_MS = 150
    EXIT_MS = 430
    ENTER_MS = 520
    SETTLE_MS = 260
    MAIN_MARGIN = 16
    MAIN_TAB_CONTENT_TOP = 55
    HOME_DASHBOARD_TOP = 235
    HOME_DASHBOARD_WIDTH = 1888
    HOME_DASHBOARD_HEIGHT = 817
    HOME_SECTION_WIDTH = round(HOME_DASHBOARD_WIDTH * 0.30)

    def __init__(
        self,
        entry_id: str,
        widget_type: str,
        spec: UIDesignSpec,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent, Qt.Window)
        self.entry_id = entry_id
        self.spec = spec
        self._animation: QParallelAnimationGroup | None = None
        self._runtime_source: QMainWindow | None = None
        self._runtime_geometry: QRect | None = None
        self._animating = False
        self._settled_geometry = QRect()
        self.samples: dict[str, QWidget] = {}
        self._settled_geometries: dict[str, QRect] = {}
        self._runtime_sources: dict[str, QMainWindow] = {}
        self._runtime_geometries: dict[str, QRect | None] = {}
        self.setAttribute(Qt.WA_DeleteOnClose, True)
        self.resize(self.PREVIEW_WIDTH, self.PREVIEW_HEIGHT)

        host = QWidget()
        host.setObjectName("uiStudioPreviewRoot")
        host.setStyleSheet("QWidget#uiStudioPreviewRoot { background: #707070; }")
        self.setCentralWidget(host)
        self.preview_host = host
        self._input_guard = _PreviewInputGuard(self)
        self._intro_shortcut = QShortcut(QKeySequence("Q"), self)
        self._intro_shortcut.setContext(Qt.WindowShortcut)
        self._intro_shortcut.activated.connect(self.play_intro)
        self._outro_shortcut = QShortcut(QKeySequence("W"), self)
        self._outro_shortcut.setContext(Qt.WindowShortcut)
        self._outro_shortcut.activated.connect(self.play_outro)
        self.add_section(entry_id, widget_type)

    @property
    def entry_ids(self) -> tuple[str, ...]:
        return tuple(self.samples)

    def add_section(self, entry_id: str, widget_type: str) -> bool:
        """Add a distinct preview region, keeping the newest one on top."""
        if entry_id in self.samples:
            return False

        self._stop_animation()
        for existing_id, existing in self.samples.items():
            existing.setGeometry(self._settled_geometries[existing_id])
            existing.show()

        self.entry_id = entry_id
        self._runtime_source = None
        self._runtime_geometry = None
        sample = self._take_runtime_section(self.preview_host) or _create_entry_sample(
            entry_id, widget_type, self.spec.palette, self.preview_host
        )
        # Several production-painted surfaces intentionally have no parent
        # constructor argument; the gallery layout normally reparents them.
        # The free-positioned preview host must do that explicitly.
        sample.setParent(self.preview_host)
        sample.setMinimumSize(1, 1)
        sample.setMaximumSize(16777215, 16777215)
        self.sample = sample
        self._apply_design_values(entry_id, sample)
        geometry = self._actual_main_geometry(entry_id, sample, self._runtime_geometry)
        self._settled_geometry = geometry
        self.samples[entry_id] = sample
        self._settled_geometries[entry_id] = geometry
        self._runtime_geometries[entry_id] = self._runtime_geometry
        if self._runtime_source is not None:
            self._runtime_sources[entry_id] = self._runtime_source
        sample.setGeometry(geometry)
        sample.show()
        sample.raise_()
        self._input_guard.protect(sample)
        self.setWindowTitle(
            f"UCS 실제 크기 미리보기 · {len(self.samples)}개 영역 · Q: intro / W: outro"
        )
        return True

    def sample_for(self, entry_id: str) -> QWidget | None:
        return self.samples.get(entry_id)

    def _take_runtime_section(self, host: QWidget) -> QWidget | None:
        """Detach unique production sections from a design-mode main hierarchy."""
        target_spec = _RUNTIME_SECTION_TARGETS.get(self.entry_id)
        if target_spec is None:
            return None

        from gui.ui_design_runtime import apply_ui_design_spec
        from gui.viewer_app_qt import StudentViewerWindow

        source = StudentViewerWindow(1.0, design_mode=True)
        source._startup_window_applied = True
        source.setAttribute(Qt.WA_DontShowOnScreen, True)
        source.resize(self.PREVIEW_WIDTH, self.PREVIEW_HEIGHT)
        source.show()
        QApplication.processEvents()
        apply_ui_design_spec(source, self.spec)

        target = getattr(source, target_spec[0])
        slot_name, scan_mode = target_spec[1], target_spec[2]
        if scan_mode is not None:
            source._show_home_scan_layout_preview(scan_mode, animate=False)
            if self.entry_id == "section:scanResultSection":
                target.setGeometry(source._scan_right_section.geometry())
            QApplication.processEvents()
        if slot_name is not None:
            slot = getattr(source, slot_name)
            target.setGeometry(slot.rect())
        target.show()
        QApplication.processEvents()
        origin = target.mapTo(source, QPoint(0, 0))
        self._runtime_geometry = QRect(origin, target.size())

        runtime_qss = source.styleSheet()
        target_override = target.styleSheet()
        target.setParent(host)
        if runtime_qss:
            target.setStyleSheet("\n".join(part for part in (runtime_qss, target_override) if part))
        target.setAttribute(Qt.WA_TransparentForMouseEvents, False)
        source.hide()
        self._runtime_source = source
        return target

    def _actual_main_geometry(
        self,
        entry_id: str,
        sample: QWidget,
        runtime_geometry: QRect | None,
    ) -> QRect:
        """Return the selected unit's settled rect in the 1920x1080 main window."""
        if runtime_geometry is not None and runtime_geometry.isValid():
            return QRect(runtime_geometry)
        path = entry_id.casefold()
        dashboard_left = self.MAIN_MARGIN
        section_width = self.HOME_SECTION_WIDTH
        dashboard_height = self.HOME_DASHBOARD_HEIGHT
        right_x = dashboard_left + self.HOME_DASHBOARD_WIDTH - section_width
        seam_overlap = max(0.0, (dashboard_height - 7.0) / math.tan(math.radians(80.0)))
        center_x = dashboard_left + round(section_width - seam_overlap + 10.0)

        scan_selector_rects = {
            "slantedscanheader#scanheader": QRect(25, 64, 1653, 148),
            "studentportraitwidget#scanheaderaccessory": QRect(1678, 64, 188, 148),
        }
        connection_selector_rects = {
            "diagonalscrolllist#homewindowcandidatelist": QRect(1501, 337, 373, 647),
            "qlabel#title": QRect(1501, 253, 373, 24),
            "qlabel#count": QRect(1501, 287, 373, 15),
            "qlabel#filtersummary": QRect(1501, 312, 373, 15),
        }
        if entry_id.startswith("selector:"):
            tail = entry_id.rsplit("/", 1)[-1].casefold()
            if "homeconnectionsection" in path and tail == "qpushbutton[0]":
                return QRect(1501, 994, 78, 40)
            if "homeconnectionsection" in path and tail == "qpushbutton[1]":
                return QRect(1701, 994, 50, 40)
            if "homeconnectionsection" in path and tail == "qpushbutton[2]":
                return QRect(1758, 994, 116, 40)
            if "scanheadersection" in path and tail in scan_selector_rects:
                return QRect(scan_selector_rects[tail])
            if "homeconnectionsection" in path and tail in connection_selector_rects:
                return QRect(connection_selector_rects[tail])

        if "scanheadersection" in path:
            return QRect(16, 55, 1888, 166)
        if "homemenusection" in path:
            return QRect(dashboard_left, self.HOME_DASHBOARD_TOP, section_width, dashboard_height)
        if any(marker in path for marker in (
            "homesettingssection", "homeitemsection", "homeitemcategorysection",
            "homeresourcesection", "homeresourcepromptsection",
        )):
            return QRect(center_x, self.HOME_DASHBOARD_TOP, section_width, dashboard_height)
        if any(marker in path for marker in ("homeconnectionsection", "homescansection")):
            return QRect(right_x, self.HOME_DASHBOARD_TOP, section_width, dashboard_height)
        if entry_id.startswith("selector:") and path.rstrip().endswith("/qstackedwidget"):
            return QRect(16, 235, 1888, 817)

        hint = sample.sizeHint().expandedTo(sample.minimumSize())
        if _is_section_entry(entry_id):
            size = QSize(760, 420)
        else:
            size = QSize(max(320, min(760, hint.width())), max(160, min(520, hint.height())))
        # Catalog-only samples have no unique runtime instance. Anchor them at
        # the real main-tab content origin instead of inventing a centered slot.
        return QRect(self.MAIN_MARGIN, self.MAIN_TAB_CONTENT_TOP, size.width(), size.height())

    def _layout_sample(self) -> None:
        if self._animating:
            return
        for entry_id, sample in self.samples.items():
            geometry = self._actual_main_geometry(
                entry_id,
                sample,
                self._runtime_geometries.get(entry_id),
            )
            self._settled_geometries[entry_id] = geometry
            sample.setGeometry(geometry)
        if hasattr(self, "entry_id") and self.entry_id in self._settled_geometries:
            self._settled_geometry = self._settled_geometries[self.entry_id]

    def _apply_design_values(self, entry_id: str, sample: QWidget) -> None:
        from gui.ui_design_runtime import iter_widget_tree

        type_qss = "\n".join(
            f"{style.widget_type} {{\n{style.style_sheet}\n}}"
            for gallery_id, style in self.spec.gallery_styles.items()
            if gallery_id.startswith("type:") and style.style_sheet.strip()
        )
        if type_qss:
            sample.setStyleSheet(_compose_widget_style(sample, sample.styleSheet(), type_qss))

        selected_selector = entry_id.removeprefix("selector:") if entry_id.startswith("selector:") else ""
        matches: dict[QWidget, ComponentOverride] = {}
        for widget, local_selector in iter_widget_tree(sample):
            if selected_selector:
                local_tail = local_selector.split("/", 1)[1] if "/" in local_selector else ""
                candidate = selected_selector + (f"/{local_tail}" if local_tail else "")
                override = self.spec.components.get(candidate)
                if override is not None:
                    matches[widget] = override
                continue
            candidates = [
                override
                for selector, override in self.spec.components.items()
                if selector == local_selector or selector.endswith(f"/{local_selector}")
            ]
            if len(candidates) == 1:
                matches[widget] = candidates[0]
        for widget, override in matches.items():
            if override.style_sheet is not None:
                widget.setStyleSheet(
                    _compose_widget_style(widget, widget.styleSheet(), override.style_sheet)
                )

    def _angles(self, entry_id: str) -> tuple[float, float]:
        key = _section_key(entry_id)
        if "scandebug" in key or "scanmirror" in key or "scanstudent" in key or "scaninventory" in key:
            return 0.0, 180.0
        if "scanwork" in key or "scanresult" in key:
            return 180.0, 0.0
        if "homemenu" in key or "menusection" in key:
            return 0.0, 180.0
        if "homeconnection" in key or "homescan" in key:
            return 180.0, 0.0
        if "home" in key:
            return 80.0, 260.0
        return 90.0, 270.0

    @staticmethod
    def _unit(angle_degrees: float) -> tuple[float, float]:
        radians = math.radians(float(angle_degrees) % 360.0)
        return math.cos(radians), -math.sin(radians)

    def _clear_offset(self, rect: QRect, angle_degrees: float) -> QPoint:
        ux, uy = self._unit(angle_degrees)
        distances: list[float] = []
        if ux > 1e-6:
            distances.append((self.preview_host.width() - rect.left()) / ux)
        elif ux < -1e-6:
            distances.append((rect.right() + 1) / -ux)
        if uy > 1e-6:
            distances.append((self.preview_host.height() - rect.top()) / uy)
        elif uy < -1e-6:
            distances.append((rect.bottom() + 1) / -uy)
        distance = min(distances) + 40.0 if distances else float(max(rect.width(), rect.height()) + 40)
        return QPoint(round(ux * distance), round(uy * distance))

    def _stop_animation(self) -> None:
        if self._animation is not None:
            self._animation.stop()
        self._animation = None
        self._animating = False

    def play_intro(self) -> None:
        self._stop_animation()
        group = QParallelAnimationGroup(self)
        for entry_id, sample in self.samples.items():
            geometry = self._settled_geometries[entry_id]
            intro, _outro = self._angles(entry_id)
            final_pos = geometry.topLeft()
            start = final_pos + self._clear_offset(geometry, (intro + 180.0) % 360.0)
            cruise_end = final_pos + QPoint(
                round((start.x() - final_pos.x()) * 0.16),
                round((start.y() - final_pos.y()) * 0.16),
            )
            sample.setGeometry(geometry)
            sample.move(start)
            sample.show()
            cruise = QPropertyAnimation(sample, b"pos")
            cruise.setDuration(self.ENTER_MS)
            cruise.setStartValue(start)
            cruise.setEndValue(cruise_end)
            cruise.setEasingCurve(QEasingCurve.Linear)
            settle = QPropertyAnimation(sample, b"pos")
            settle.setDuration(self.SETTLE_MS)
            settle.setStartValue(cruise_end)
            settle.setEndValue(final_pos)
            settle.setEasingCurve(QEasingCurve.OutCubic)
            sequence = QSequentialAnimationGroup(group)
            sequence.addAnimation(cruise)
            sequence.addAnimation(settle)
            group.addAnimation(sequence)
        group.finished.connect(self._finish_intro)
        self._animation = group
        self._animating = True
        group.start()

    def _finish_intro(self) -> None:
        for entry_id, sample in self.samples.items():
            sample.move(self._settled_geometries[entry_id].topLeft())
            sample.show()
        self._animation = None
        self._animating = False

    def play_outro(self) -> None:
        self._stop_animation()
        group = QParallelAnimationGroup(self)
        for entry_id, sample in self.samples.items():
            geometry = self._settled_geometries[entry_id]
            _intro, outro = self._angles(entry_id)
            origin = geometry.topLeft()
            offset = self._clear_offset(geometry, outro)
            pull_target = origin - QPoint(round(offset.x() * 0.055), round(offset.y() * 0.055))
            exit_target = origin + offset
            sample.setGeometry(geometry)
            sample.show()
            pull = QPropertyAnimation(sample, b"pos")
            pull.setDuration(self.PULL_MS)
            pull.setStartValue(origin)
            pull.setEndValue(pull_target)
            pull.setEasingCurve(QEasingCurve.OutCubic)
            leave = QPropertyAnimation(sample, b"pos")
            leave.setDuration(self.EXIT_MS)
            leave.setStartValue(pull_target)
            leave.setEndValue(exit_target)
            leave.setEasingCurve(QEasingCurve.InCubic)
            sequence = QSequentialAnimationGroup(group)
            sequence.addAnimation(pull)
            sequence.addAnimation(leave)
            group.addAnimation(sequence)
        group.finished.connect(self._finish_outro)
        self._animation = group
        self._animating = True
        group.start()

    def _finish_outro(self) -> None:
        for entry_id, sample in self.samples.items():
            sample.hide()
            sample.move(self._settled_geometries[entry_id].topLeft())
        self._animation = None
        self._animating = False

    def keyPressEvent(self, event) -> None:
        if event.key() == Qt.Key_Q:
            self.play_intro()
            event.accept()
            return
        if event.key() == Qt.Key_W:
            self.play_outro()
            event.accept()
            return
        super().keyPressEvent(event)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        if hasattr(self, "sample"):
            self._layout_sample()

    def closeEvent(self, event) -> None:
        self._stop_animation()
        sources = tuple(self._runtime_sources.values())
        self._runtime_sources.clear()
        self._runtime_source = None
        for source in sources:
            source.setAttribute(Qt.WA_DeleteOnClose, True)
            source.close()
        super().closeEvent(event)


class PaletteEditor(QGroupBox):
    def __init__(self, studio: "StudioWindow"):
        super().__init__("Palette")
        self.studio = studio
        self.edits: dict[str, QLineEdit] = {}
        self.chips: dict[str, QPushButton] = {}
        form = QFormLayout(self)
        for key in DEFAULT_PALETTE:
            row = QWidget()
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(0, 0, 0, 0)
            chip = QPushButton()
            chip.setFixedSize(38, 24)
            edit = QLineEdit()
            edit.editingFinished.connect(self.sync)
            chip.clicked.connect(lambda _checked=False, token=key: self.choose(token))
            row_layout.addWidget(chip)
            row_layout.addWidget(edit)
            form.addRow(key.replace("_", " ").title(), row)
            self.edits[key] = edit
            self.chips[key] = chip
        self.load()

    def load(self) -> None:
        for key, edit in self.edits.items():
            edit.setText(self.studio.spec.palette.get(key, DEFAULT_PALETTE[key]))
        self.refresh_chips()

    def choose(self, key: str) -> None:
        color = QColorDialog.getColor(QColor(self.edits[key].text()), self, key)
        if color.isValid():
            self.edits[key].setText(color.name())
            self.sync()

    def sync(self) -> None:
        for key, edit in self.edits.items():
            color = QColor(edit.text().strip())
            if color.isValid():
                self.studio.spec.palette[key] = color.name()
        self.refresh_chips()

    def refresh_chips(self) -> None:
        for key, chip in self.chips.items():
            chip.setStyleSheet(f"background:{self.studio.spec.palette[key]}; border:1px solid #777;")


class StudioWindow(QMainWindow):
    """A single-window gallery; no live Planner hierarchy is created."""

    def __init__(self, spec_path: Path):
        super().__init__()
        app = QApplication.instance()
        if app is not None:
            configure_studio_application(app)
        self.spec_path = spec_path
        self.draft_path = (
            UI_DESIGN_DRAFT_PATH
            if spec_path.resolve() == UI_DESIGN_SPEC_PATH.resolve()
            else spec_path.with_name(f"{spec_path.stem}.draft.json")
        )
        self.spec = load_ui_design_spec(spec_path)
        self.preview = None
        self.cards: dict[str, GalleryCard] = {}
        self.widgets: dict[str, QWidget] = {}
        self._retired_gallery_batches: list[list[QWidget]] = []
        self.current_selector = ""
        self._ensure_base_gallery()
        self.setWindowTitle("BA Planner UI Component Studio · Gallery")
        self.resize(1220, 820)
        self._build_ui()
        self.refresh_gallery()

    def _ensure_base_gallery(self) -> None:
        for widget_type in SUPPORTED_WIDGET_TYPES:
            gallery_id = f"type:{widget_type}"
            self.spec.gallery_styles.setdefault(
                gallery_id,
                GalleryStyleSpec(gallery_id, widget_type, widget_type),
            )
        for section_style in _SECTION_GALLERY_STYLES:
            self.spec.gallery_styles.setdefault(section_style.gallery_id, replace(section_style))
        for asset_style in _ASSET_GALLERY_STYLES:
            self.spec.gallery_styles.setdefault(asset_style.gallery_id, replace(asset_style))
        for widget_style in _WIDGET_GALLERY_STYLES:
            self.spec.gallery_styles.setdefault(widget_style.gallery_id, replace(widget_style))

    def _entries(self) -> list[tuple[str, str, str, str]]:
        entries = [
            (
                gallery_id,
                style.title,
                style.widget_type,
                "sections" if _is_section_entry(gallery_id) else "widgets",
            )
            for gallery_id, style in self.spec.gallery_styles.items()
        ]
        entries.extend(
            (
                f"selector:{selector}",
                selector.rsplit("/", 1)[-1],
                _class_from_selector(selector),
                "sections" if _is_section_entry(f"selector:{selector}") else "widgets",
            )
            for selector in self.spec.components
        )
        return entries

    def _build_ui(self) -> None:
        central = QWidget()
        self.setCentralWidget(central)
        outer = QVBoxLayout(central)
        toolbar = QHBoxLayout()
        title = QLabel("Component Gallery")
        title.setStyleSheet("font-size:18px; font-weight:600;")
        toolbar.addWidget(title)
        toolbar.addStretch(1)
        self.preview_button = QPushButton("선택 항목 미리보기")
        self.preview_button.setEnabled(False)
        self.preview_button.clicked.connect(self.open_preview)
        self.source_refresh_button = QPushButton("소스 새로고침")
        self.source_refresh_button.setToolTip(
            "UCS를 종료하지 않고 GUI 소스 모듈을 다시 불러온 뒤 갤러리와 미리보기를 재생성합니다."
        )
        self.source_refresh_button.clicked.connect(self.reload_source_and_refresh)
        save_button = QPushButton("디자인 저장")
        save_button.clicked.connect(self.confirm)
        revert_button = QPushButton("저장본으로 되돌리기")
        revert_button.clicked.connect(self.revert)
        toolbar.addWidget(self.preview_button)
        toolbar.addWidget(self.source_refresh_button)
        toolbar.addWidget(revert_button)
        toolbar.addWidget(save_button)
        outer.addLayout(toolbar)

        self.source_refresh_status = QLabel("")
        self.source_refresh_status.setObjectName("sourceRefreshStatus")
        self.source_refresh_status.setStyleSheet("color: #9fb3c8;")
        outer.addWidget(self.source_refresh_status)

        info = QLabel(
            "실제 데이터나 기능은 실행하지 않습니다. 런타임 섹션 카드는 디자인 모드 스냅샷을 표시하고, "
            "카탈로그 전용 카드는 독립 샘플을 표시합니다. "
            "위치·크기·레이아웃·표시 상태·동작은 UCS가 변경하지 않습니다."
        )
        info.setWordWrap(True)
        outer.addWidget(info)

        splitter = QSplitter()
        outer.addWidget(splitter, 1)
        self.gallery_tabs = QTabWidget()
        self.gallery_tabs.setObjectName("componentGalleryTabs")
        self.gallery_layouts: dict[str, QGridLayout] = {}
        for category, label in (("widgets", "위젯"), ("sections", "섹션")):
            gallery_host = QWidget()
            gallery_layout = QGridLayout(gallery_host)
            gallery_layout.setAlignment(Qt.AlignTop)
            gallery_layout.setHorizontalSpacing(12)
            gallery_layout.setVerticalSpacing(12)
            for column in range(_GALLERY_COLUMNS[category]):
                gallery_layout.setColumnStretch(column, 1)
            scroll = QScrollArea()
            scroll.setWidgetResizable(True)
            scroll.setWidget(gallery_host)
            self.gallery_tabs.addTab(scroll, label)
            self.gallery_layouts[category] = gallery_layout
        self.state_machine_tab = self._build_state_machine_tab()
        self.gallery_tabs.addTab(self.state_machine_tab, "상태 머신")
        self.gallery_tabs.currentChanged.connect(self._gallery_tab_changed)
        # Compatibility alias for existing tooling and tests that address the
        # original single widget gallery directly.
        self.gallery_layout = self.gallery_layouts["widgets"]
        splitter.addWidget(self.gallery_tabs)

        inspector_scroll = QScrollArea()
        inspector_scroll.setWidgetResizable(True)
        inspector = QWidget()
        inspector_layout = QVBoxLayout(inspector)
        self.selection_label = QLabel("카드를 선택하세요")
        self.selection_label.setWordWrap(True)
        inspector_layout.addWidget(self.selection_label)
        inspector_layout.addWidget(QLabel("선택 섹션 하부 트리"))
        self.selection_tree = QTreeWidget()
        self.selection_tree.setColumnCount(3)
        self.selection_tree.setHeaderLabels(["요소", "objectName", "텍스트/역할"])
        self.selection_tree.setMinimumHeight(230)
        self.selection_tree.currentItemChanged.connect(self._tree_item_changed)
        inspector_layout.addWidget(self.selection_tree)
        self.tree_path_edit = QLineEdit()
        self.tree_path_edit.setReadOnly(True)
        self.tree_path_edit.setPlaceholderText("트리에서 요소를 선택하세요")
        inspector_layout.addWidget(self.tree_path_edit)
        copy_path_button = QPushButton("대화용 지시 경로 복사")
        copy_path_button.clicked.connect(self.copy_tree_instruction)
        inspector_layout.addWidget(copy_path_button)
        self.style_edit = QPlainTextEdit()
        self.style_edit.setPlaceholderText("선택한 컴포넌트의 QSS 선언 (중괄호 내부) 또는 selector 전용 QSS")
        self.style_edit.setMinimumHeight(150)
        inspector_layout.addWidget(QLabel("QSS"))
        inspector_layout.addWidget(self.style_edit)
        apply_button = QPushButton("갤러리 샘플에 적용")
        apply_button.clicked.connect(self.apply_properties)
        inspector_layout.addWidget(apply_button)
        self.shape_editor = self._build_shape_editor()
        inspector_layout.addWidget(self.shape_editor)
        self.palette_editor = PaletteEditor(self)
        inspector_layout.addWidget(self.palette_editor)
        inspector_layout.addStretch(1)
        inspector_scroll.setWidget(inspector)
        splitter.addWidget(inspector_scroll)
        splitter.setSizes([780, 400])

    def _build_state_machine_tab(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        toolbar = QHBoxLayout()
        toolbar.addWidget(QLabel("메인 탭"))
        self.state_tab_combo = QComboBox()
        self.state_tab_combo.addItems(("전체 화면", *_TAB_STATE_SPECS.keys()))
        self.state_tab_combo.currentTextChanged.connect(self._refresh_state_machine)
        toolbar.addWidget(self.state_tab_combo)
        self.state_missing_only = QCheckBox("검토 필요만")
        self.state_missing_only.toggled.connect(lambda _checked: self._refresh_state_machine(self.state_tab_combo.currentText()))
        toolbar.addWidget(self.state_missing_only)
        toolbar.addStretch(1)
        layout.addLayout(toolbar)
        self.state_startup_label = QLabel()
        self.state_startup_label.setWordWrap(True)
        layout.addWidget(self.state_startup_label)
        self.state_transition_label = QLabel()
        self.state_transition_label.setWordWrap(True)
        layout.addWidget(self.state_transition_label)
        self.state_detail_tabs = QTabWidget()
        markdown_page = QWidget()
        markdown_layout = QVBoxLayout(markdown_page)
        markdown_toolbar = QHBoxLayout()
        self.state_markdown_path_label = QLabel()
        self.state_markdown_path_label.setTextInteractionFlags(Qt.TextSelectableByMouse)
        markdown_toolbar.addWidget(self.state_markdown_path_label, 1)
        refresh_markdown = QPushButton("문서 새로고침")
        refresh_markdown.clicked.connect(lambda: self._load_state_markdown(self.state_tab_combo.currentText()))
        markdown_toolbar.addWidget(refresh_markdown)
        open_markdown = QPushButton("Markdown 파일 열기")
        open_markdown.clicked.connect(self.open_state_markdown_file)
        markdown_toolbar.addWidget(open_markdown)
        copy_markdown_path = QPushButton("경로 복사")
        copy_markdown_path.clicked.connect(self.copy_state_markdown_path)
        markdown_toolbar.addWidget(copy_markdown_path)
        markdown_layout.addLayout(markdown_toolbar)
        self.state_markdown_host = QWidget()
        self.state_markdown_host_layout = QVBoxLayout(self.state_markdown_host)
        self.state_markdown_host_layout.setContentsMargins(0, 0, 0, 0)
        self.state_markdown_placeholder = QLabel("상태 머신 탭을 열면 Markdown 문서를 렌더링합니다.")
        self.state_markdown_placeholder.setAlignment(Qt.AlignCenter)
        self.state_markdown_host_layout.addWidget(self.state_markdown_placeholder, 1)
        self.state_markdown_view: MarkdownMermaidView | None = None
        markdown_layout.addWidget(self.state_markdown_host, 1)
        self.state_detail_tabs.addTab(markdown_page, "Markdown 문서")

        self.state_transition_table = QTableWidget()
        self.state_transition_table.setColumnCount(9)
        self.state_transition_table.setHorizontalHeaderLabels(
            ("Stable ID", "출발 섹션", "전환 버튼/이벤트", "Guard", "Action", "도착 섹션", "보이는 결과", "소스 검증", "상태")
        )
        self.state_transition_table.setAlternatingRowColors(True)
        self.state_transition_table.setWordWrap(True)
        self.state_transition_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeToContents)
        self.state_transition_table.horizontalHeader().setStretchLastSection(True)
        self.state_detail_tabs.addTab(self.state_transition_table, "섹션 전환표")

        audit_page = QWidget()
        audit_layout = QVBoxLayout(audit_page)
        self.state_coverage_label = QLabel()
        self.state_coverage_label.setWordWrap(True)
        audit_layout.addWidget(self.state_coverage_label)
        self.state_audit_table = QTableWidget()
        self.state_audit_table.setColumnCount(7)
        self.state_audit_table.setHorizontalHeaderLabels(
            ("상태", "컨트롤", "표시", "Signal", "연결된 Handler", "소스", "대응 Stable ID")
        )
        self.state_audit_table.setAlternatingRowColors(True)
        self.state_audit_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeToContents)
        self.state_audit_table.horizontalHeader().setStretchLastSection(True)
        audit_layout.addWidget(self.state_audit_table, 1)
        self.state_detail_tabs.addTab(audit_page, "연결 감사")

        layout.addWidget(self.state_detail_tabs, 1)
        self._refresh_state_machine(self.state_tab_combo.currentText())
        return page

    def _gallery_tab_changed(self, index: int) -> None:
        if index == self.gallery_tabs.indexOf(self.state_machine_tab):
            self._ensure_state_markdown_view()

    def _ensure_state_markdown_view(self) -> None:
        if self.state_markdown_view is not None:
            return
        self.state_markdown_placeholder.hide()
        self.state_markdown_view = MarkdownMermaidView(self.state_markdown_host)
        self.state_markdown_host_layout.addWidget(self.state_markdown_view, 1)
        self._load_state_markdown(self.state_tab_combo.currentText())

    def _load_state_markdown(self, tab_name: str) -> bool:
        path = _TAB_MARKDOWN_FILES.get(tab_name)
        self.state_markdown_path_label.setText(str(path or "문서 없음"))
        if path is None or self.state_markdown_view is None:
            return False
        return self.state_markdown_view.load_markdown(path)

    def open_state_markdown_file(self) -> bool:
        path = _TAB_MARKDOWN_FILES.get(self.state_tab_combo.currentText())
        if path is None or not path.exists():
            return False
        return bool(QDesktopServices.openUrl(QUrl.fromLocalFile(str(path))))

    def copy_state_markdown_path(self) -> bool:
        path = _TAB_MARKDOWN_FILES.get(self.state_tab_combo.currentText())
        if path is None:
            return False
        QApplication.clipboard().setText(str(path))
        return True

    def _refresh_state_machine(self, tab_name: str) -> None:
        spec = _APP_OVERVIEW_SPEC if tab_name == "전체 화면" else _TAB_STATE_SPECS.get(tab_name, {})
        self.state_startup_label.setText(f"시작 구조: {spec.get('startup', '-')}")
        if tab_name == "홈":
            motion = "탭 전환: 이전 홈 섹션은 각 섹션 outro 각도, 재진입은 각 섹션 intro 각도로 이동"
        else:
            motion = "탭 전환: 이전 탭 body는 270° outro, 선택 탭 body는 90° intro (헤더는 고정)"
        self.state_transition_label.setText(motion)
        markdown_path = _TAB_MARKDOWN_FILES.get(tab_name)
        self.state_markdown_path_label.setText(str(markdown_path or "문서 없음"))
        if self.state_markdown_view is not None:
            self._load_state_markdown(tab_name)
        self._populate_behavior_tables(tab_name)

    @staticmethod
    def _section_canvas_spec(tab_name: str) -> dict:
        edges = _SECTION_FLOW_SPECS.get(tab_name, ())
        nodes: list[str] = []
        for edge in edges:
            for key in ("source", "target"):
                if edge[key] not in nodes:
                    nodes.append(edge[key])
        node_index = {node: index for index, node in enumerate(nodes)}
        return {
            "states": tuple(nodes),
            "transitions": tuple(
                (node_index[edge["source"]], node_index[edge["target"]], edge["button"])
                for edge in edges
            ),
        }

    @staticmethod
    def _behavior_matches_interaction(transition: dict[str, str], interaction: dict[str, str]) -> bool:
        haystack = " ".join((interaction["control"], interaction["label"], interaction["handler"]))
        direct_needles = (transition["control"], transition["action"])
        if any(needle and needle in haystack for needle in direct_needles):
            return True
        action_symbols = re.findall(r"_[A-Za-z][A-Za-z0-9_]+", transition["action"])
        return any(symbol in haystack for symbol in action_symbols)

    def _populate_behavior_tables(self, tab_name: str) -> None:
        edges = list(_SECTION_FLOW_SPECS.get(tab_name, ()))
        all_interactions = _discover_source_interactions(tab_name)
        edge_matches: dict[int, list[dict[str, str]]] = {}
        for edge_index, edge in enumerate(edges):
            matches = [item for item in all_interactions if self._edge_matches_interaction(edge, item)]
            if matches:
                edge_matches[edge_index] = matches
        candidate_interactions = [
            item for item in all_interactions
            if any(marker in item["handler"] for marker in _SECTION_HANDLER_MARKERS)
            or any(self._edge_matches_interaction(edge, item) for edge in edges)
        ]
        candidate_mapping: dict[int, str] = {}
        for index, interaction in enumerate(candidate_interactions):
            for edge in edges:
                if self._edge_matches_interaction(edge, interaction):
                    candidate_mapping[index] = edge["id"]
                    break

        rows = [
            (index, edge) for index, edge in enumerate(edges)
            if not self.state_missing_only.isChecked() or index not in edge_matches
        ]
        self.state_transition_table.setRowCount(len(rows))
        for row, (edge_index, edge) in enumerate(rows):
            sources = edge_matches.get(edge_index, [])
            status = "소스 확인" if sources else "수동 확인 필요"
            values = (
                edge["id"], edge["source"], edge["button"], edge["guard"], edge["action"],
                edge["target"], edge["result"], "\n".join(item["source"] for item in sources) or "동적 연결/수동 검토", status,
            )
            for column, value in enumerate(values):
                item = QTableWidgetItem(value)
                if status != "소스 확인":
                    item.setBackground(QColor("#ffe4df"))
                self.state_transition_table.setItem(row, column, item)
        self.state_transition_table.resizeRowsToContents()

        self.state_audit_table.setRowCount(len(candidate_interactions))
        for row, interaction in enumerate(candidate_interactions):
            stable_id = candidate_mapping.get(row, "TODO")
            values = (
                "연결됨" if row in candidate_mapping else "검토 필요", interaction["control"], interaction["label"],
                interaction["signal"], interaction["handler"], interaction["source"], stable_id,
            )
            for column, value in enumerate(values):
                item = QTableWidgetItem(value)
                if row not in candidate_mapping:
                    item.setBackground(QColor("#ffe4df"))
                self.state_audit_table.setItem(row, column, item)
        verified_edges = len(edge_matches)
        total_edges = len(edges)
        unmodeled_candidates = len(candidate_interactions) - len(candidate_mapping)
        self.state_coverage_label.setText(
            f"섹션 연결 커버리지 · 정의 {total_edges}개 · 소스 신호 확인 {verified_edges}개 · 동적 연결/수동 확인 {total_edges - verified_edges}개 · 미정의 연결 후보 {unmodeled_candidates}개\n"
            "새로고침·복사·삭제·입력값 변경처럼 현재 섹션 안에서 끝나는 동작은 제외합니다. 감사 대상은 섹션, 스택 페이지, 다이얼로그 또는 메인 탭을 바꾸는 연결뿐입니다."
        )

    @staticmethod
    def _edge_matches_interaction(edge: dict[str, str], interaction: dict[str, str]) -> bool:
        handler = interaction["handler"]
        tokens = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", edge["action"])
        meaningful = [token for token in tokens if token.startswith("_") or token.startswith("setCurrent")]
        return any(token in handler for token in meaningful)

    @staticmethod
    def _mermaid_for_sections(tab_name: str, edges: list[dict[str, str]]) -> str:
        nodes: list[str] = []
        for edge in edges:
            for key in ("source", "target"):
                if edge[key] not in nodes:
                    nodes.append(edge[key])
        node_ids = {node: f"SECTION_{index}" for index, node in enumerate(nodes)}
        lines = ["stateDiagram-v2", f"    %% UCS section flow: {tab_name}"]
        if nodes:
            lines.append(f"    [*] --> {node_ids[nodes[0]]}")
        for node, node_id in node_ids.items():
            lines.append(f'    state "{node}" as {node_id}')
        for edge in edges:
            label = f"{edge['button']} [{edge['id']}]"
            lines.append(f"    {node_ids[edge['source']]} --> {node_ids[edge['target']]}: {label}")
        return "\n".join(lines)

    @staticmethod
    def _mermaid_for_behavior(tab_name: str, transitions: list[dict[str, str]]) -> str:
        states: list[str] = []
        for transition in transitions:
            for key in ("state", "next"):
                value = transition[key]
                if value not in states:
                    states.append(value)
        state_ids = {state: f"S{index}" for index, state in enumerate(states)}
        lines = ["stateDiagram-v2", f"    %% UCS: {tab_name}"]
        if states:
            lines.append(f"    [*] --> {state_ids[states[0]]}")
        for state, state_id in state_ids.items():
            lines.append(f'    state "{state}" as {state_id}')
        for transition in transitions:
            label = f"{transition['id']} / {transition['event']}"
            lines.append(f"    {state_ids[transition['state']]} --> {state_ids[transition['next']]}: {label}")
        return "\n".join(lines)

    @staticmethod
    def _widget_summary(widget: QWidget) -> str:
        if isinstance(widget, (QLabel, QPushButton, QCheckBox)):
            return widget.text().strip().replace("\n", " ")[:80]
        if isinstance(widget, QLineEdit):
            return widget.placeholderText().strip()[:80]
        if isinstance(widget, QComboBox):
            return widget.currentText().strip()[:80]
        if isinstance(widget, QPlainTextEdit):
            return (widget.placeholderText() or widget.toPlainText()).strip().replace("\n", " ")[:80]
        return ""

    def _populate_selection_tree(self, entry_id: str, root_widget: QWidget | None = None) -> None:
        self.selection_tree.clear()
        self.tree_path_edit.clear()
        root_widget = root_widget or self.widgets.get(entry_id)
        if root_widget is None:
            return

        def add_widget(widget: QWidget, parent_item: QTreeWidgetItem | None, path: str) -> None:
            class_name = type(widget).__name__
            object_name = widget.objectName()
            segment = f"{class_name}#{object_name}" if object_name else class_name
            current_path = f"{path}/{segment}" if path else segment
            item = QTreeWidgetItem([class_name, object_name, self._widget_summary(widget)])
            item.setData(0, Qt.UserRole, current_path)
            if parent_item is None:
                self.selection_tree.addTopLevelItem(item)
            else:
                parent_item.addChild(item)
            siblings: dict[str, int] = {}
            for child in widget.children():
                if not isinstance(child, QWidget) or child.window() is child:
                    continue
                child_key = f"{type(child).__name__}#{child.objectName()}"
                siblings[child_key] = siblings.get(child_key, 0) + 1
                suffix = f"[{siblings[child_key] - 1}]" if siblings[child_key] > 1 or not child.objectName() else ""
                add_widget(child, item, f"{current_path}{suffix}")

        add_widget(root_widget, None, entry_id)
        self.selection_tree.expandToDepth(2)
        if self.selection_tree.topLevelItemCount():
            self.selection_tree.setCurrentItem(self.selection_tree.topLevelItem(0))
        for column in range(3):
            self.selection_tree.resizeColumnToContents(column)

    def _tree_item_changed(self, current: QTreeWidgetItem | None, _previous: QTreeWidgetItem | None) -> None:
        self.tree_path_edit.setText(str(current.data(0, Qt.UserRole)) if current is not None else "")

    def copy_tree_instruction(self) -> bool:
        path = self.tree_path_edit.text().strip()
        if not self.current_selector or not path:
            return False
        tab_name = "섹션" if _is_section_entry(self.current_selector) else "위젯"
        instruction = f"UCS > {tab_name} > {self.current_selector} > {path}: [변경할 내용]"
        QApplication.clipboard().setText(instruction)
        return True

    def _spin(self, low: int, high: int, value: int = 0) -> QSpinBox:
        spin = QSpinBox()
        spin.setRange(low, high)
        spin.setValue(value)
        return spin

    def _build_shape_editor(self) -> QGroupBox:
        box = QGroupBox("Diagonal shape · selector 카드 전용")
        form = QFormLayout(box)
        self.shape_enabled_check = QCheckBox("형태 적용")
        self.shape_mode_combo = QComboBox(); self.shape_mode_combo.addItems(["cut", "extend"])
        self.shape_edge_combo = QComboBox(); self.shape_edge_combo.addItems(["left", "right", "top", "bottom"])
        self.shape_direction_combo = QComboBox(); self.shape_direction_combo.addItems(["forward", "reverse"])
        self.shape_angle_spin = QDoubleSpinBox(); self.shape_angle_spin.setRange(0.5, 89.5); self.shape_angle_spin.setValue(80)
        self.shape_depth_mode_combo = QComboBox(); self.shape_depth_mode_combo.addItems(["angle", "fixed"])
        self.shape_depth_spin = self._spin(0, 1000, 24)
        self.shape_radius_spin = self._spin(0, 1000, 7)
        self.shape_safe_margin_spin = self._spin(0, 1000, 24)
        self.shape_hit_mask_check = QCheckBox("클릭 영역도 형태에 맞춤"); self.shape_hit_mask_check.setChecked(True)
        form.addRow(self.shape_enabled_check)
        form.addRow("Mode", self.shape_mode_combo)
        form.addRow("Edge", self.shape_edge_combo)
        form.addRow("Direction", self.shape_direction_combo)
        form.addRow("Angle", self.shape_angle_spin)
        form.addRow("Depth mode", self.shape_depth_mode_combo)
        form.addRow("Depth", self.shape_depth_spin)
        form.addRow("Radius", self.shape_radius_spin)
        form.addRow("Safe margin", self.shape_safe_margin_spin)
        form.addRow(self.shape_hit_mask_check)
        return box

    @staticmethod
    def _set_combo(combo: QComboBox, value: str) -> None:
        index = combo.findText(value)
        combo.setCurrentIndex(max(0, index))

    def _clear_gallery(self, *, retire_for_reload: bool = False) -> None:
        retired: list[QWidget] = []
        for layout in self.gallery_layouts.values():
            while layout.count():
                item = layout.takeAt(0)
                if item.widget() is not None:
                    widget = item.widget()
                    if retire_for_reload:
                        widget.hide()
                        widget.setEnabled(False)
                        retired.append(widget)
                    else:
                        widget.deleteLater()
        if retired:
            self._retired_gallery_batches.append(retired)
            # Several production samples queue zero-delay geometry/mask work.
            # Deleting their C++ objects before those callbacks drain leaves
            # Shiboken wrappers dangling across a module reload.
            QTimer.singleShot(250, lambda batch=retired: self._dispose_retired_gallery(batch))
        self.cards.clear()
        self.widgets.clear()

    def _dispose_retired_gallery(self, batch: list[QWidget]) -> None:
        if batch not in self._retired_gallery_batches:
            return
        self._retired_gallery_batches.remove(batch)
        for widget in batch:
            widget.deleteLater()

    def refresh_gallery(self) -> None:
        self._clear_gallery()
        positions = {"widgets": 0, "sections": 0}
        runtime_renderer = _RuntimeSectionThumbnailRenderer(self.spec)
        try:
            for entry_id, title, widget_type, category in self._entries():
                card = GalleryCard(entry_id, title, widget_type, self.spec.palette, self.select_entry)
                position = positions[category]
                columns = _GALLERY_COLUMNS[category]
                self.gallery_layouts[category].addWidget(card, position // columns, position % columns)
                positions[category] += 1
                self.cards[entry_id] = card
                self.widgets[entry_id] = card.sample
                self._render_entry(entry_id, runtime_renderer=runtime_renderer)
        finally:
            runtime_renderer.close()
        if self.current_selector in self.cards:
            self.cards[self.current_selector].set_selected(True)

    def reload_source_and_refresh(self) -> bool:
        """Hot-reload visual modules and rebuild the current Studio view."""
        selected_entry = self.current_selector
        reopen_preview = self.preview is not None
        if selected_entry:
            self.apply_properties()
        if self.preview is not None:
            preview = self.preview
            self.preview = None
            preview.close()
        self._clear_gallery(retire_for_reload=True)
        # Let zero-delay geometry work finish while the retired samples still
        # own valid C++ widgets. Their delayed disposal is scheduled separately.
        QApplication.processEvents()

        try:
            reloaded = _reload_visual_modules()
        except Exception as exc:
            self.refresh_gallery()
            if selected_entry in self.cards:
                self.select_entry(selected_entry)
            self.source_refresh_status.setText(f"소스 새로고침 실패: {type(exc).__name__}: {exc}")
            return False

        self.refresh_gallery()
        if selected_entry in self.cards:
            self.select_entry(selected_entry)
            if reopen_preview:
                self.open_preview()
        self.source_refresh_status.setText(
            f"소스 새로고침 완료 · GUI 모듈 {len(reloaded)}개 재로딩"
        )
        return True

    def _entry_style(self, entry_id: str) -> tuple[str, DiagonalShapeSpec | None]:
        if not entry_id.startswith("selector:"):
            style = self.spec.gallery_styles[entry_id]
            return style.style_sheet, style.diagonal_shape
        selector = entry_id.removeprefix("selector:")
        override = self.spec.components.get(selector)
        return ((override.style_sheet or "") if override else "", override.diagonal_shape if override else None)

    def _render_entry(
        self,
        entry_id: str,
        *,
        runtime_renderer: _RuntimeSectionThumbnailRenderer | None = None,
    ) -> None:
        card = self.cards.get(entry_id)
        if card is None:
            return
        style, shape = self._entry_style(entry_id)
        base_style = card.sample.property("uiStudioGalleryBaseStyle")
        combined_style = _compose_widget_style(card.sample, str(base_style or ""), style)
        card.sample.setStyleSheet(combined_style)
        card.sample.clearMask()
        if shape is not None:
            path = diagonal_shape_path(QRectF(card.sample.rect()), shape)
            card.sample.setMask(QRegion(path.toFillPolygon().toPolygon()))
        owns_renderer = runtime_renderer is None and entry_id in _RUNTIME_SECTION_TARGETS
        if owns_renderer:
            runtime_renderer = _RuntimeSectionThumbnailRenderer(self.spec)
        try:
            card.refresh_thumbnail(runtime_renderer, style)
        finally:
            if owns_renderer and runtime_renderer is not None:
                runtime_renderer.close()

    def select_entry(self, entry_id: str) -> None:
        for key, card in self.cards.items():
            card.set_selected(key == entry_id)
        self.current_selector = entry_id
        self.preview_button.setEnabled(True)
        self.gallery_tabs.setCurrentIndex(1 if _is_section_entry(entry_id) else 0)
        style, shape = self._entry_style(entry_id)
        self.selection_label.setText(entry_id)
        self._populate_selection_tree(entry_id)
        self.style_edit.setPlainText(style)
        selector_entry = entry_id.startswith("selector:")
        self.shape_editor.setEnabled(selector_entry)
        shape = shape or DiagonalShapeSpec()
        self.shape_enabled_check.setChecked(selector_entry and self._entry_style(entry_id)[1] is not None)
        self._set_combo(self.shape_mode_combo, shape.mode)
        self._set_combo(self.shape_edge_combo, shape.edge)
        self._set_combo(self.shape_direction_combo, shape.direction)
        self.shape_angle_spin.setValue(shape.angle_degrees)
        self._set_combo(self.shape_depth_mode_combo, shape.depth_mode)
        self.shape_depth_spin.setValue(shape.depth)
        self.shape_radius_spin.setValue(shape.radius)
        self.shape_safe_margin_spin.setValue(shape.content_safe_margin)
        self.shape_hit_mask_check.setChecked(shape.hit_mask)

    def _shape_from_editor(self) -> DiagonalShapeSpec | None:
        if not self.shape_enabled_check.isChecked():
            return None
        return DiagonalShapeSpec(
            mode=self.shape_mode_combo.currentText(),
            edge=self.shape_edge_combo.currentText(),
            direction=self.shape_direction_combo.currentText(),
            angle_degrees=self.shape_angle_spin.value(),
            depth_mode=self.shape_depth_mode_combo.currentText(),
            depth=self.shape_depth_spin.value(),
            radius=self.shape_radius_spin.value(),
            content_safe_margin=self.shape_safe_margin_spin.value(),
            hit_mask=self.shape_hit_mask_check.isChecked(),
        )

    def apply_properties(self) -> bool:
        entry_id = self.current_selector
        if not entry_id:
            return False
        style_sheet = self.style_edit.toPlainText()
        if not entry_id.startswith("selector:"):
            old = self.spec.gallery_styles[entry_id]
            self.spec.gallery_styles[entry_id] = replace(old, style_sheet=style_sheet)
        else:
            selector = entry_id.removeprefix("selector:")
            old = self.spec.components.get(selector) or ComponentOverride(selector)
            # Preserve legacy layout values in the file for migration history,
            # but Studio can only alter visual fields.
            old.style_sheet = style_sheet
            old.diagonal_shape = self._shape_from_editor()
            self.spec.components[selector] = old
        save_ui_design_spec(self.spec, self.draft_path)
        self._render_entry(entry_id)
        return True

    def open_preview(self) -> bool:
        entry_id = self.current_selector
        if not entry_id:
            return False
        self.apply_properties()
        widget_type = next(
            (item_widget_type for item_id, _title, item_widget_type, _category in self._entries() if item_id == entry_id),
            _class_from_selector(entry_id),
        )
        preview = self.preview
        if preview is None:
            preview = SectionPreviewWindow(entry_id, widget_type, self.spec)
            preview.destroyed.connect(lambda _obj=None, window=preview: self._clear_preview(window))
            self.preview = preview
        else:
            preview.add_section(entry_id, widget_type)
        sample = preview.sample_for(entry_id)
        if sample is not None:
            self._populate_selection_tree(entry_id, sample)
        preview.show()
        preview.raise_()
        preview.activateWindow()
        return True

    def _clear_preview(self, window: SectionPreviewWindow) -> None:
        if self.preview is window:
            self.preview = None

    def confirm(self) -> None:
        if self.current_selector:
            self.apply_properties()
        self.palette_editor.sync()
        save_ui_design_spec(self.spec, self.spec_path)
        if self.spec_path.resolve() != UI_DESIGN_SPEC_PATH.resolve():
            save_ui_design_spec(self.spec, UI_DESIGN_SPEC_PATH)
        self.draft_path.unlink(missing_ok=True)
        QMessageBox.information(self, "저장 완료", "갤러리의 디자인 값만 저장했습니다.")

    def revert(self) -> None:
        self.spec = load_ui_design_spec(self.spec_path)
        self._ensure_base_gallery()
        self.current_selector = ""
        self.preview_button.setEnabled(False)
        self.palette_editor.load()
        self.refresh_gallery()
        self.selection_label.setText("카드를 선택하세요")
        self.selection_tree.clear()
        self.tree_path_edit.clear()
        self.style_edit.clear()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="BA Planner UI Component Studio gallery")
    parser.add_argument("--spec", type=Path, default=UI_DESIGN_SPEC_PATH)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    app = QApplication(sys.argv[:1])
    configure_studio_application(app)
    studio = StudioWindow(args.spec.resolve())
    studio.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
