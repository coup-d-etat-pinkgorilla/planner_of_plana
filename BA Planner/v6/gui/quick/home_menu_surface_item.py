"""Painted Qt Quick surface for the interlocking legacy Home menu buttons."""

from __future__ import annotations

import math

from PySide6.QtCore import Property, QPointF, QRectF, QUrl, Signal, Qt
from PySide6.QtGui import QColor, QFont, QImage, QLinearGradient, QPainter, QPainterPath, QPen, QTransform
from PySide6.QtQuick import QQuickPaintedItem

from gui.diagonal_shape import _rounded_polygon_path
from gui.triangle_texture import TriangleTextureConfig, paint_triangle_texture


class HomeMenuSurfaceItem(QQuickPaintedItem):
    """Own the bilateral diagonal path, texture clipping, caption, and hit mask."""

    appearanceChanged = Signal()

    def __init__(self, parent: QQuickPaintedItem | None = None) -> None:
        super().__init__(parent)
        self._palette: dict[str, object] = {}
        self._image_source = QUrl()
        self._caption = ""
        self._extend_left = False
        self._cut_right = True
        self._triangle_only = False
        self._hovered = False
        self._pressed = False
        self._enabled = True
        self._angle = 80.0
        self._radius = 7.0
        self._image = QImage()
        self.setAntialiasing(True)
        self.setOpaquePainting(False)

    def _set(self, name: str, value: object) -> None:
        attribute = f"_{name}"
        if getattr(self, attribute) != value:
            setattr(self, attribute, value)
            self.appearanceChanged.emit()
            self.update()

    @Property("QVariantMap", notify=appearanceChanged)
    def themePalette(self) -> dict[str, object]:
        return dict(self._palette)

    @themePalette.setter
    def themePalette(self, value: dict[str, object]) -> None:
        self._set("palette", dict(value or {}))

    @Property(QUrl, notify=appearanceChanged)
    def imageSource(self) -> QUrl:
        return QUrl(self._image_source)

    @imageSource.setter
    def imageSource(self, value: QUrl) -> None:
        resolved = QUrl(value)
        if resolved == self._image_source:
            return
        self._image_source = resolved
        self._image = QImage(resolved.toLocalFile()) if resolved.isLocalFile() else QImage()
        self.appearanceChanged.emit()
        self.update()

    @Property(str, notify=appearanceChanged)
    def caption(self) -> str:
        return self._caption

    @caption.setter
    def caption(self, value: str) -> None:
        self._set("caption", str(value or ""))

    @Property(bool, notify=appearanceChanged)
    def extendLeft(self) -> bool:
        return self._extend_left

    @extendLeft.setter
    def extendLeft(self, value: bool) -> None:
        self._set("extend_left", bool(value))

    @Property(bool, notify=appearanceChanged)
    def cutRight(self) -> bool:
        return self._cut_right

    @cutRight.setter
    def cutRight(self, value: bool) -> None:
        self._set("cut_right", bool(value))

    @Property(bool, notify=appearanceChanged)
    def triangleOnly(self) -> bool:
        return self._triangle_only

    @triangleOnly.setter
    def triangleOnly(self, value: bool) -> None:
        self._set("triangle_only", bool(value))

    @Property(bool, notify=appearanceChanged)
    def hovered(self) -> bool:
        return self._hovered

    @hovered.setter
    def hovered(self, value: bool) -> None:
        self._set("hovered", bool(value))

    @Property(bool, notify=appearanceChanged)
    def pressed(self) -> bool:
        return self._pressed

    @pressed.setter
    def pressed(self, value: bool) -> None:
        self._set("pressed", bool(value))

    @Property(bool, notify=appearanceChanged)
    def controlEnabled(self) -> bool:
        return self._enabled

    @controlEnabled.setter
    def controlEnabled(self, value: bool) -> None:
        self._set("enabled", bool(value))

    @Property(float, notify=appearanceChanged)
    def angle(self) -> float:
        return self._angle

    @angle.setter
    def angle(self, value: float) -> None:
        self._set("angle", min(89.5, max(45.0, float(value))))

    @Property(float, notify=appearanceChanged)
    def radius(self) -> float:
        return self._radius

    @radius.setter
    def radius(self, value: float) -> None:
        self._set("radius", max(0.0, float(value)))

    def _color(self, key: str, fallback: str) -> QColor:
        return QColor(str(self._palette.get(key, fallback)))

    def diagonal_slant(self) -> float:
        width, height = float(self.width()), float(self.height())
        radius = min(self._radius, width / 2.0, height / 2.0)
        requested = max(0.0, height - 2.0 * radius) / max(0.01, math.tan(math.radians(self._angle)))
        return min(requested, width * 0.24, height * 0.48)

    @Property(float, notify=appearanceChanged)
    def diagonalSlant(self) -> float:
        return self.diagonal_slant()

    def surface_path(self) -> QPainterPath:
        width = max(1.0, float(self.width()) - 3.0)
        height = max(1.0, float(self.height()) - 3.0)
        slant = self.diagonal_slant()
        left_top = slant if self._extend_left else 0.0
        right_bottom = width - slant if self._cut_right else width
        points = [
            QPointF(left_top, 0.0), QPointF(width, 0.0),
            QPointF(right_bottom, height), QPointF(0.0, height),
        ]
        return _rounded_polygon_path(points, [self._radius] * 4)

    def contains(self, point: QPointF) -> bool:  # QQuickItem containment-mask virtual
        return self.surface_path().contains(point)

    def _paint_image(self, painter: QPainter, path: QPainterPath) -> bool:
        if self._image.isNull():
            return False
        target = path.boundingRect()
        source = QRectF(self._image.rect())
        target_ratio = target.width() / max(1.0, target.height())
        source_ratio = source.width() / max(1.0, source.height())
        if source_ratio > target_ratio:
            crop_width = source.height() * target_ratio
            source.setX((source.width() - crop_width) / 2.0)
            source.setWidth(crop_width)
        else:
            crop_height = source.width() / max(0.01, target_ratio)
            source.setY((source.height() - crop_height) / 2.0)
            source.setHeight(crop_height)
        painter.save()
        painter.setClipPath(path)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        painter.drawImage(target, self._image, source)
        painter.restore()
        return True

    def _paint_triangle(self, painter: QPainter, path: QPainterPath) -> None:
        base = self._color("panelAlt", "#2c3140")
        panel = self._color("panel", "#313b59")
        soft = self._color("muted", "#a6a9b5")
        accent = self._color("accentSoft", "#844d72")
        config = TriangleTextureConfig(
            base_color=base.name(), panel_color=panel.name(), soft_color=soft.name(), accent_color=accent.name(),
            triangle_size=max(6.0, float(self.height()) * 0.80), tessellation_contrast=0.10,
            random_seed=8417, macro_triangle_chance=0.12, macro_triangle_scale=2.8,
            macro_triangle_contrast=0.05, light_strength=0.10, light_center_x=0.5,
            light_center_y=0.5, edge_vignette_strength=0.06, fog_direction_degrees=0.0,
            fog_strength=0.035,
        )
        painter.save()
        painter.setClipPath(path)
        paint_triangle_texture(painter, QRectF(0.0, 0.0, float(self.width()), float(self.height())), config)
        painter.restore()

    def paint(self, painter: QPainter) -> None:
        path = self.surface_path()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        shadow = self._color("shadow", "#1d202a")
        for dx, dy, alpha in ((1.0, 1.0, 0.18), (2.0, 2.0, 0.10), (3.0, 3.0, 0.04)):
            layer = QColor(shadow)
            layer.setAlphaF(alpha)
            painter.fillPath(QTransform.fromTranslate(dx, dy).map(path), layer)
        if self._triangle_only:
            self._paint_triangle(painter, path)
        elif not self._paint_image(painter, path):
            painter.fillPath(path, self._color("panel", "#313b59"))

        if not self._enabled:
            painter.fillPath(path, QColor(0, 0, 0, 138))
        elif self._pressed:
            painter.fillPath(path, QColor(0, 0, 0, 34))
        elif self._hovered:
            painter.fillPath(path, QColor(255, 255, 255, 24))

        if not self._triangle_only:
            top = float(self.height()) * 0.65
            wash = self._color("backgroundAlt", "#747b86")
            gradient = QLinearGradient(0.0, top, 0.0, float(self.height()))
            for stop, alpha in ((0.0, 0), (0.18, 117), (0.30, 214), (0.56, 245), (1.0, 255)):
                color = QColor(wash)
                color.setAlpha(alpha)
                gradient.setColorAt(stop, color)
            painter.save()
            painter.setClipPath(path)
            painter.fillRect(QRectF(0.0, top, float(self.width()), float(self.height()) - top), gradient)
            painter.restore()

        if self._caption:
            slant = self.diagonal_slant()
            left = max(10.0, float(self.height()) * 0.08)
            right = slant + max(8.0, float(self.height()) * 0.055)
            text_top = float(self.height()) * 0.65
            text_rect = QRectF(left, text_top, max(1.0, float(self.width()) - left - right), max(1.0, float(self.height()) - text_top - 7.0))
            font = QFont(painter.font())
            font.setBold(True)
            font.setPixelSize(max(12, min(24, round(float(self.height()) * 0.14))))
            painter.setFont(font)
            painter.setPen(self._color("text", "#f2f2f2"))
            painter.drawText(text_rect, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignBottom | Qt.TextFlag.TextWordWrap, self._caption)

        pen = QPen(self._color("border", "#5c5960"), 1.0)
        pen.setCosmetic(True)
        painter.setPen(pen)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawPath(path)
