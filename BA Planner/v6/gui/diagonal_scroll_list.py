"""Rounded Qt lists whose rows and scroll handle follow a diagonal edge."""

from __future__ import annotations

import math
from dataclasses import replace
from typing import Literal

from PySide6.QtCore import QEvent, QPoint, QRect, QRectF, QSize, Qt, QTimer
from PySide6.QtGui import QColor, QMouseEvent, QPainter, QPainterPath, QPen, QPixmap
from PySide6.QtWidgets import QAbstractItemView, QListWidget, QListWidgetItem, QWidget

from gui.triangle_texture import TriangleTextureConfig, paint_triangle_texture


Edge = Literal["left", "right"]
ShapeMode = Literal["cut", "extend"]


def _rounded_polygon_path(points: list[tuple[float, float]], radius: float) -> QPainterPath:
    path = QPainterPath()
    if len(points) < 3:
        return path
    before: list[tuple[float, float]] = []
    after: list[tuple[float, float]] = []
    for index, point in enumerate(points):
        previous = points[index - 1]
        following = points[(index + 1) % len(points)]
        incoming = (point[0] - previous[0], point[1] - previous[1])
        outgoing = (following[0] - point[0], following[1] - point[1])
        incoming_length = math.hypot(*incoming)
        outgoing_length = math.hypot(*outgoing)
        corner = min(max(0.0, radius), incoming_length / 2.0, outgoing_length / 2.0)
        incoming_scale = corner / max(1e-6, incoming_length)
        outgoing_scale = corner / max(1e-6, outgoing_length)
        before.append((point[0] - incoming[0] * incoming_scale, point[1] - incoming[1] * incoming_scale))
        after.append((point[0] + outgoing[0] * outgoing_scale, point[1] + outgoing[1] * outgoing_scale))
    path.moveTo(*after[0])
    for index in range(1, len(points)):
        path.lineTo(*before[index])
        path.quadTo(*points[index], *after[index])
    path.lineTo(*before[0])
    path.quadTo(*points[0], *after[0])
    path.closeSubpath()
    return path


class DiagonalListItemHost(QWidget):
    """Transparent item slot with a painted diagonal surface and safe content rect."""

    def __init__(
        self,
        content: QWidget,
        *,
        edge: Edge,
        mode: ShapeMode,
        opposite_mode: ShapeMode | None,
        maximum_depth: int,
        radius: int,
        fill: str,
        selected_fill: str,
        content_padding: int,
        triangle_texture: TriangleTextureConfig | None = None,
        shadow_color: str | None = None,
        shadow_offset: float = 2.0,
        shadow_inset: float = 3.0,
        shadow_layers: int = 4,
        shadow_alpha: float = 0.2,
        gutter_depth: int | None = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._content = content
        self._content.setParent(self)
        self._edge = edge
        self._mode = mode
        self._left_mode = mode if edge == "left" else opposite_mode
        self._right_mode = mode if edge == "right" else opposite_mode
        self._maximum_depth = max(0, int(maximum_depth))
        self._gutter_depth = self._maximum_depth if gutter_depth is None else max(0, int(gutter_depth))
        self._radius = max(0, int(radius))
        self._fill = QColor(fill)
        self._selected_fill = QColor(selected_fill)
        self._content_padding = max(0, int(content_padding))
        self._triangle_texture = triangle_texture.normalized() if triangle_texture is not None else None
        self._shadow_color = QColor(shadow_color) if shadow_color else None
        self._shadow_offset = max(0.0, float(shadow_offset))
        self._shadow_inset = max(0.0, float(shadow_inset))
        self._shadow_layers = max(1, int(shadow_layers))
        self._shadow_alpha = min(1.0, max(0.0, float(shadow_alpha)))
        self._top_depth = 0.0
        self._bottom_depth = 0.0
        self._selected = False
        self._hovered = False
        self._pressed = False
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WA_StyledBackground, False)
        self.setAttribute(Qt.WA_TransparentForMouseEvents, True)

    def setEdgeDepths(self, top_depth: float, bottom_depth: float) -> None:
        top = min(float(self._gutter_depth), max(0.0, float(top_depth)))
        bottom = min(float(self._gutter_depth), max(0.0, float(bottom_depth)))
        if abs(top - self._top_depth) < 0.25 and abs(bottom - self._bottom_depth) < 0.25:
            return
        self._top_depth = top
        self._bottom_depth = bottom
        self._sync_content_geometry()
        self.update()

    def setGutterDepth(self, depth: int) -> None:
        depth = max(0, int(depth))
        if depth == self._gutter_depth:
            return
        self._gutter_depth = depth
        self._sync_content_geometry()
        self.update()

    def setSelected(self, selected: bool) -> None:
        selected = bool(selected)
        if selected == self._selected:
            return
        self._selected = selected
        self.update()

    def setHovered(self, hovered: bool) -> None:
        hovered = bool(hovered)
        if hovered == self._hovered:
            return
        self._hovered = hovered
        self.update()

    def setPressed(self, pressed: bool) -> None:
        pressed = bool(pressed)
        if pressed == self._pressed:
            return
        self._pressed = pressed
        self.update()

    def _surface_points(self, width: float | None = None, height: float | None = None) -> list[tuple[float, float]]:
        width = float(self.width()) if width is None else max(0.0, float(width))
        height = float(self.height()) if height is None else max(0.0, float(height))
        gutter = float(self._gutter_depth)
        left_top = 0.0
        left_bottom = 0.0
        if self._left_mode == "extend":
            left_top = gutter - self._top_depth
            left_bottom = gutter - self._bottom_depth
        elif self._left_mode == "cut":
            left_top = self._top_depth
            left_bottom = self._bottom_depth

        right_top = width
        right_bottom = width
        if self._right_mode == "extend":
            base_right = max(0.0, width - gutter)
            right_top = base_right + self._top_depth
            right_bottom = base_right + self._bottom_depth
        elif self._right_mode == "cut":
            right_top = width - self._top_depth
            right_bottom = width - self._bottom_depth

        return [
            (left_top, 0.0),
            (right_top, 0.0),
            (right_bottom, height),
            (left_bottom, height),
        ]

    def _content_rect(self) -> QRect:
        padding = self._content_padding
        gutter = self._gutter_depth
        left = padding
        right = padding
        if self._left_mode is not None:
            left += gutter
        if self._right_mode is not None:
            right += gutter
        return self.rect().adjusted(left, padding, -right, -padding)

    def _sync_content_geometry(self) -> None:
        rect = self._content_rect()
        self._content.setGeometry(rect if rect.isValid() else QRect())

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._sync_content_geometry()

    def paintEvent(self, event) -> None:
        if self.width() <= 0 or self.height() <= 0:
            return
        inset = self._shadow_inset if self._shadow_color is not None else 0.0
        surface_width = max(1.0, float(self.width()) - inset)
        surface_height = max(1.0, float(self.height()) - inset)
        path = _rounded_polygon_path(
            self._surface_points(surface_width, surface_height),
            min(float(self._radius), surface_width / 2.0, surface_height / 2.0),
        )
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        if self._shadow_color is not None:
            painter.setPen(Qt.NoPen)
            for layer in range(self._shadow_layers, 0, -1):
                progress = layer / self._shadow_layers
                color = QColor(self._shadow_color)
                color.setAlphaF(self._shadow_alpha * (1.0 - (progress * 0.65)))
                painter.setBrush(color)
                painter.drawPath(path.translated(self._shadow_offset * progress, self._shadow_offset * progress))
        fill = self._selected_fill if self._selected else self._fill
        painter.setPen(Qt.NoPen)
        if self._triangle_texture is None:
            painter.setBrush(fill)
            painter.drawPath(path)
        else:
            config = replace(
                self._triangle_texture,
                base_color=fill.name(QColor.HexArgb),
                triangle_size=max(6.0, surface_height * 0.8),
            )
            texture = QPixmap(self.size())
            texture.fill(Qt.transparent)
            texture_painter = QPainter(texture)
            paint_triangle_texture(texture_painter, QRectF(texture.rect()), config)
            texture_painter.end()
            painter.save()
            painter.setClipPath(path)
            painter.drawPixmap(0, 0, texture)
            painter.restore()
        state_overlay = QColor(Qt.transparent)
        if not self.isEnabled():
            state_overlay = QColor(0, 0, 0, 138)
        elif self._pressed:
            state_overlay = QColor(0, 0, 0, 34)
        elif self._hovered:
            state_overlay = QColor(255, 255, 255, 24)
        if state_overlay.alpha() > 0:
            painter.fillPath(path, state_overlay)
        painter.end()


class _DiagonalScrollRail(QWidget):
    def __init__(self, owner: "DiagonalScrollList") -> None:
        super().__init__(owner)
        self._owner = owner
        self.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        self.setAttribute(Qt.WA_TranslucentBackground, True)

    def paintEvent(self, event) -> None:
        if self._owner.verticalScrollBar().maximum() <= self._owner.verticalScrollBar().minimum():
            return
        top = float(self._owner._track_margin)
        bottom = float(max(self._owner._track_margin, self.height() - self._owner._track_margin))
        half = max(1.0, self._owner._handle_width / 2.0)
        top_x = self._owner.rightBoundaryX(top) - self._owner._handle_margin
        bottom_x = self._owner.rightBoundaryX(bottom) - self._owner._handle_margin
        path = _rounded_polygon_path(
            [
                (top_x - half, top),
                (top_x + half, top),
                (bottom_x + half, bottom),
                (bottom_x - half, bottom),
            ],
            half,
        )
        color = QColor(self._owner._rail_color)
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.fillPath(path, color)
        painter.end()


class DiagonalScrollHandle(QWidget):
    def __init__(self, owner: "DiagonalScrollList") -> None:
        super().__init__(owner)
        self._owner = owner
        self._dragging = False
        self._drag_offset_y = 0
        self._top_boundary_x = 0.0
        self._bottom_boundary_x = 0.0
        self.setCursor(Qt.PointingHandCursor)
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.hide()

    def updatePosition(self) -> None:
        bar = self._owner.verticalScrollBar()
        top_margin = self._owner._track_margin
        track_height = max(0, self._owner.height() - 2 * top_margin)
        if track_height <= 0 or bar.maximum() <= bar.minimum() or not self._owner.isVisible():
            self.hide()
            return
        page = max(1, bar.pageStep())
        total = max(page, bar.maximum() - bar.minimum() + page)
        handle_height = max(self._owner._minimum_handle_height, round(track_height * page / total))
        handle_height = min(track_height, handle_height)
        travel = max(0, track_height - handle_height)
        ratio = (bar.value() - bar.minimum()) / max(1, bar.maximum() - bar.minimum())
        y = top_margin + round(travel * ratio)
        top_x = self._owner.rightBoundaryX(float(y)) - self._owner._handle_margin
        bottom_x = self._owner.rightBoundaryX(float(y + handle_height)) - self._owner._handle_margin
        half = max(1, self._owner._handle_width // 2)
        left = math.floor(min(top_x, bottom_x) - half - 1)
        right = math.ceil(max(top_x, bottom_x) + half + 1)
        self._top_boundary_x = top_x - left
        self._bottom_boundary_x = bottom_x - left
        self.setGeometry(left, y, max(1, right - left), handle_height)
        self.raise_()
        self.show()
        self.update()

    def setScrollFromY(self, y: int) -> None:
        bar = self._owner.verticalScrollBar()
        top_margin = self._owner._track_margin
        track_height = max(1, self._owner.height() - 2 * top_margin)
        travel = max(1, track_height - self.height())
        clamped = max(top_margin, min(top_margin + travel, int(y)))
        ratio = (clamped - top_margin) / travel
        bar.setValue(bar.minimum() + round((bar.maximum() - bar.minimum()) * ratio))

    def mousePressEvent(self, event: QMouseEvent) -> None:
        if event.button() != Qt.LeftButton:
            return super().mousePressEvent(event)
        self._dragging = True
        self._drag_offset_y = round(event.position().y())
        event.accept()

    def mouseMoveEvent(self, event: QMouseEvent) -> None:
        if not self._dragging:
            return super().mouseMoveEvent(event)
        self.setScrollFromY(self.y() + round(event.position().y()) - self._drag_offset_y)
        event.accept()

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:
        if event.button() == Qt.LeftButton and self._dragging:
            self._dragging = False
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def paintEvent(self, event) -> None:
        half = max(1.0, self._owner._handle_width / 2.0)
        path = _rounded_polygon_path(
            [
                (self._top_boundary_x - half, 0.5),
                (self._top_boundary_x + half, 0.5),
                (self._bottom_boundary_x + half, max(0.5, self.height() - 0.5)),
                (self._bottom_boundary_x - half, max(0.5, self.height() - 0.5)),
            ],
            half,
        )
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.fillPath(path, QColor(self._owner._handle_color))
        painter.setPen(QPen(QColor(self._owner._handle_border_color), 1))
        painter.drawPath(path)
        painter.end()


class DiagonalScrollList(QListWidget):
    """QListWidget with Y-dependent diagonal rows and a shape-aware scrollbar."""

    def __init__(
        self,
        *,
        edge: Edge = "left",
        mode: ShapeMode = "extend",
        opposite_mode: ShapeMode | None = None,
        angle_degrees: float = 80.0,
        maximum_depth: int = 30,
        lock_angle: bool = False,
        radius: int = 7,
        row_fill: str = "#243447",
        selected_fill: str = "#355c78",
        rail_color: str = "#355064",
        handle_color: str = "#7fc7eb",
        handle_border_color: str = "#b7e3f7",
        row_height: int = 62,
        row_gap: int = 7,
        content_padding: int = 8,
        row_triangle_texture: TriangleTextureConfig | None = None,
        row_shadow_color: str | None = None,
        row_shadow_offset: float = 2.0,
        row_shadow_inset: float = 3.0,
        row_shadow_layers: int = 4,
        row_shadow_alpha: float = 0.2,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        if edge not in ("left", "right"):
            raise ValueError(f"unsupported diagonal edge: {edge}")
        if mode not in ("cut", "extend"):
            raise ValueError(f"unsupported diagonal mode: {mode}")
        if opposite_mode not in (None, "cut", "extend"):
            raise ValueError(f"unsupported opposite diagonal mode: {opposite_mode}")
        self._edge: Edge = edge
        self._mode: ShapeMode = mode
        self._opposite_mode = opposite_mode
        self._left_mode = mode if edge == "left" else opposite_mode
        self._right_mode = mode if edge == "right" else opposite_mode
        self._angle_degrees = float(angle_degrees)
        self._maximum_depth = max(0, int(maximum_depth))
        self._lock_angle = bool(lock_angle)
        self._radius = max(0, int(radius))
        self._row_fill = row_fill
        self._selected_fill = selected_fill
        self._rail_color = rail_color
        self._handle_color = handle_color
        self._handle_border_color = handle_border_color
        self._row_height = max(1, int(row_height))
        self._content_padding = max(0, int(content_padding))
        self._row_triangle_texture = row_triangle_texture
        self._row_shadow_color = row_shadow_color
        self._row_shadow_offset = max(0.0, float(row_shadow_offset))
        self._row_shadow_inset = max(0.0, float(row_shadow_inset))
        self._row_shadow_layers = max(1, int(row_shadow_layers))
        self._row_shadow_alpha = min(1.0, max(0.0, float(row_shadow_alpha)))
        self._track_margin = max(8, self._radius + 4)
        self._handle_width = max(5, self._radius)
        self._handle_margin = max(5, self._radius)
        self._minimum_handle_height = max(24, self._radius * 4)
        self.setFrameShape(QListWidget.NoFrame)
        self.setSelectionMode(QAbstractItemView.SingleSelection)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setSpacing(max(0, int(row_gap)))
        self.setUniformItemSizes(False)
        right_margin = self._handle_width + self._handle_margin * 2
        self.setViewportMargins(0, 0, right_margin, 0)
        self.setStyleSheet(
            "QListWidget { background: transparent; border: none; outline: none; }"
            "QListWidget::item { background: transparent; border: none; }"
            "QListWidget::item:selected { background: transparent; }"
        )
        self.viewport().setAutoFillBackground(False)
        self.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self.viewport().setAttribute(Qt.WA_Hover, True)
        self.viewport().setMouseTracking(True)
        self.viewport().setCursor(Qt.PointingHandCursor)
        self._hovered_item: QListWidgetItem | None = None
        self._pressed_item: QListWidgetItem | None = None
        self._rail = _DiagonalScrollRail(self)
        self._handle = DiagonalScrollHandle(self)
        self.verticalScrollBar().valueChanged.connect(self._schedule_geometry_update)
        self.verticalScrollBar().rangeChanged.connect(self._schedule_geometry_update)
        self.currentItemChanged.connect(lambda *_: self._sync_selection())
        self.itemSelectionChanged.connect(self._sync_selection)
        QTimer.singleShot(0, self._update_diagonal_geometry)

    def addDiagonalWidget(
        self,
        content: QWidget,
        *,
        data: object = None,
        accessible_text: str = "",
        tooltip: str = "",
        row_height: int | None = None,
    ) -> QListWidgetItem:
        item = QListWidgetItem()
        item.setSizeHint(QSize(1, self._row_height if row_height is None else max(1, int(row_height))))
        item.setData(Qt.UserRole, data)
        if accessible_text:
            item.setData(Qt.AccessibleTextRole, accessible_text)
        if tooltip:
            item.setToolTip(tooltip)
        host = DiagonalListItemHost(
            content,
            edge=self._edge,
            mode=self._mode,
            opposite_mode=self._opposite_mode,
            maximum_depth=self._maximum_depth,
            gutter_depth=self.gutterDepth(),
            radius=self._radius,
            fill=self._row_fill,
            selected_fill=self._selected_fill,
            content_padding=self._content_padding,
            triangle_texture=self._row_triangle_texture,
            shadow_color=self._row_shadow_color,
            shadow_offset=self._row_shadow_offset,
            shadow_inset=self._row_shadow_inset,
            shadow_layers=self._row_shadow_layers,
            shadow_alpha=self._row_shadow_alpha,
        )
        host.setAccessibleName(accessible_text)
        self.addItem(item)
        self.setItemWidget(item, host)
        self._schedule_geometry_update()
        return item

    def diagonalHost(self, item: QListWidgetItem) -> DiagonalListItemHost | None:
        host = self.itemWidget(item)
        return host if isinstance(host, DiagonalListItemHost) else None

    def refreshDiagonalGeometry(self) -> None:
        self._sync_selection()
        self._schedule_geometry_update()

    def depthAtY(self, y: float) -> float:
        viewport_height = max(1.0, float(self.viewport().height()))
        natural_depth = viewport_height / max(0.01, abs(math.tan(math.radians(self._angle_degrees))))
        full_depth = natural_depth if self._lock_angle else min(float(self._maximum_depth), natural_depth)
        return full_depth * min(1.0, max(0.0, float(y) / viewport_height))

    def gutterDepth(self) -> int:
        if not self._lock_angle:
            return self._maximum_depth
        viewport_height = max(1.0, float(self.viewport().height()))
        natural_depth = viewport_height / max(0.01, abs(math.tan(math.radians(self._angle_degrees))))
        return max(self._maximum_depth, math.ceil(natural_depth))

    def rightBoundaryX(self, y: float) -> float:
        if self._right_mode is None:
            return float(self.width())
        depth = self.depthAtY(y)
        if self._right_mode == "extend":
            return float(self.width() - self._maximum_depth) + depth
        return float(self.width()) - depth

    def _sync_selection(self) -> None:
        current = self.currentItem()
        for row in range(self.count()):
            item = self.item(row)
            host = self.diagonalHost(item)
            if host is not None:
                host.setSelected(item is current and item.isSelected())

    def _set_hovered_item(self, item: QListWidgetItem | None) -> None:
        if item is self._hovered_item:
            return
        previous = self.diagonalHost(self._hovered_item) if self._hovered_item is not None else None
        if previous is not None:
            previous.setHovered(False)
        self._hovered_item = item
        current = self.diagonalHost(item) if item is not None else None
        if current is not None:
            current.setHovered(True)

    def _set_pressed_item(self, item: QListWidgetItem | None) -> None:
        if item is self._pressed_item:
            return
        previous = self.diagonalHost(self._pressed_item) if self._pressed_item is not None else None
        if previous is not None:
            previous.setPressed(False)
        self._pressed_item = item
        current = self.diagonalHost(item) if item is not None else None
        if current is not None:
            current.setPressed(True)

    def viewportEvent(self, event: QEvent) -> bool:
        event_type = event.type()
        if hasattr(self, "_hovered_item") and event_type in (QEvent.MouseMove, QEvent.HoverMove):
            position = event.position().toPoint() if hasattr(event, "position") else QPoint()
            self._set_hovered_item(self.itemAt(position))
        elif hasattr(self, "_hovered_item") and event_type in (QEvent.Leave, QEvent.HoverLeave):
            self._set_hovered_item(None)
            self._set_pressed_item(None)
        elif hasattr(self, "_pressed_item") and event_type == QEvent.MouseButtonPress:
            position = event.position().toPoint() if hasattr(event, "position") else QPoint()
            self._set_pressed_item(self.itemAt(position))
        elif hasattr(self, "_pressed_item") and event_type == QEvent.MouseButtonRelease:
            self._set_pressed_item(None)
        return super().viewportEvent(event)

    def clear(self) -> None:
        if hasattr(self, "_hovered_item"):
            self._set_hovered_item(None)
            self._set_pressed_item(None)
        super().clear()

    def _schedule_geometry_update(self, *args) -> None:
        self._update_diagonal_geometry()
        QTimer.singleShot(0, self._update_diagonal_geometry)

    def _update_diagonal_geometry(self) -> None:
        try:
            gutter_depth = self.gutterDepth()
        except RuntimeError:
            # A queued zero-delay refresh can outlive the underlying Qt
            # viewport during section teardown.
            return
        for row in range(self.count()):
            item = self.item(row)
            host = self.diagonalHost(item)
            if host is None:
                continue
            rect = self.visualItemRect(item)
            if rect.isEmpty():
                continue
            host.setGutterDepth(gutter_depth)
            host.setEdgeDepths(self.depthAtY(rect.top()), self.depthAtY(rect.bottom()))
        self._rail.setGeometry(self.rect())
        self._rail.lower()
        self._rail.update()
        self._handle.updatePosition()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._schedule_geometry_update()

    def showEvent(self, event) -> None:
        super().showEvent(event)
        self._schedule_geometry_update()

    def scrollContentsBy(self, dx: int, dy: int) -> None:
        super().scrollContentsBy(dx, dy)
        self._schedule_geometry_update()
