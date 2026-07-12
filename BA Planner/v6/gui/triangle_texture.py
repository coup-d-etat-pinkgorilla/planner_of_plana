"""Palette-aware, image-free triangular atmosphere backgrounds for Qt widgets."""

from __future__ import annotations

import math
from dataclasses import dataclass, replace

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QLinearGradient, QPainter, QPainterPath, QRadialGradient
from PySide6.QtWidgets import QWidget


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _with_alpha(color: str | QColor, alpha: float) -> QColor:
    result = QColor(color)
    result.setAlphaF(_clamp(alpha, 0.0, 1.0))
    return result


@dataclass(frozen=True, slots=True)
class TriangleTextureConfig:
    """Visual controls shared by full-window and local texture surfaces.

    Directions use screen-space degrees: 0 points right and 90 points down.
    """

    base_color: str
    panel_color: str
    soft_color: str
    accent_color: str
    triangle_size: float = 28.0
    tessellation_contrast: float = 0.035
    random_seed: int = 7319
    macro_triangle_chance: float = 0.075
    macro_triangle_scale: float = 3.0
    macro_triangle_contrast: float = 0.026
    light_direction_degrees: float = 132.0
    light_strength: float = 0.12
    light_center_x: float = 0.5
    light_center_y: float = 0.5
    edge_vignette_strength: float = 0.16
    fog_direction_degrees: float = 18.0
    fog_strength: float = 0.075

    def normalized(self) -> "TriangleTextureConfig":
        return replace(
            self,
            triangle_size=max(6.0, float(self.triangle_size)),
            tessellation_contrast=_clamp(float(self.tessellation_contrast), 0.0, 0.18),
            random_seed=int(self.random_seed),
            macro_triangle_chance=_clamp(float(self.macro_triangle_chance), 0.0, 0.35),
            macro_triangle_scale=_clamp(float(self.macro_triangle_scale), 1.5, 6.0),
            macro_triangle_contrast=_clamp(float(self.macro_triangle_contrast), 0.0, 0.12),
            light_strength=_clamp(float(self.light_strength), 0.0, 0.45),
            light_center_x=_clamp(float(self.light_center_x), 0.0, 1.0),
            light_center_y=_clamp(float(self.light_center_y), 0.0, 1.0),
            edge_vignette_strength=_clamp(float(self.edge_vignette_strength), 0.0, 0.45),
            fog_strength=_clamp(float(self.fog_strength), 0.0, 0.3),
            light_direction_degrees=float(self.light_direction_degrees) % 360.0,
            fog_direction_degrees=float(self.fog_direction_degrees) % 360.0,
        )


def _gradient_axis(rect: QRectF, degrees: float) -> tuple[QPointF, QPointF]:
    radians = math.radians(degrees)
    dx, dy = math.cos(radians), math.sin(radians)
    span = abs(dx) * rect.width() + abs(dy) * rect.height()
    center = rect.center()
    offset = QPointF(dx * span * 0.5, dy * span * 0.5)
    return center - offset, center + offset


def _triangle_path(a: QPointF, b: QPointF, c: QPointF) -> QPainterPath:
    path = QPainterPath(a)
    path.lineTo(b)
    path.lineTo(c)
    path.closeSubpath()
    return path


def _cell_random(col: int, row: int, face: int, seed: int) -> float:
    """Stable coordinate noise that cannot flicker between paint events."""

    value = (col * 0x1F123BB5) ^ (row * 0x5F356495) ^ (face * 0x6C8E9CF5) ^ seed
    value &= 0xFFFFFFFF
    value ^= value >> 16
    value = (value * 0x7FEB352D) & 0xFFFFFFFF
    value ^= value >> 15
    value = (value * 0x846CA68B) & 0xFFFFFFFF
    value ^= value >> 16
    return value / 0xFFFFFFFF


def paint_triangle_texture(
    painter: QPainter,
    rect: QRectF,
    config: TriangleTextureConfig,
) -> None:
    """Paint a seamless low-contrast tessellation with light and fog layers."""

    if rect.isEmpty():
        return
    cfg = config.normalized()
    painter.save()
    painter.setClipRect(rect)
    painter.fillRect(rect, QColor(cfg.base_color))
    painter.setRenderHint(QPainter.RenderHint.Antialiasing, False)

    side = cfg.triangle_size
    height = side * math.sqrt(3.0) * 0.5
    first_col = math.floor((rect.left() - side) / side)
    last_col = math.ceil((rect.right() + side) / side)
    first_row = math.floor((rect.top() - height) / height)
    last_row = math.ceil((rect.bottom() + height) / height)
    face_colors = (
        _with_alpha(cfg.soft_color, cfg.tessellation_contrast * 0.62),
        _with_alpha(cfg.panel_color, cfg.tessellation_contrast * 0.9),
        _with_alpha("#000000", cfg.tessellation_contrast * 0.38),
        _with_alpha(cfg.accent_color, cfg.tessellation_contrast * 0.2),
    )
    painter.setPen(Qt.PenStyle.NoPen)
    for row in range(first_row, last_row + 1):
        y = row * height
        offset = side * 0.5 if row & 1 else 0.0
        for col in range(first_col, last_col + 1):
            x = col * side + offset
            shade = min(3, int(_cell_random(col, row, 0, cfg.random_seed) * 4.0))
            painter.setBrush(face_colors[shade])
            painter.drawPath(_triangle_path(QPointF(x, y), QPointF(x + side, y), QPointF(x + side * 0.5, y + height)))
            second_shade = min(3, int(_cell_random(col, row, 1, cfg.random_seed) * 4.0))
            painter.setBrush(face_colors[second_shade])
            painter.drawPath(_triangle_path(QPointF(x + side, y), QPointF(x + side * 1.5, y + height), QPointF(x + side * 0.5, y + height)))

    # Sparse oversized faces interrupt the fine grid without drawing outlines.
    macro_side = side * cfg.macro_triangle_scale
    macro_height = macro_side * math.sqrt(3.0) * 0.5
    macro_first_col = math.floor((rect.left() - macro_side) / macro_side)
    macro_last_col = math.ceil((rect.right() + macro_side) / macro_side)
    macro_first_row = math.floor((rect.top() - macro_height) / macro_height)
    macro_last_row = math.ceil((rect.bottom() + macro_height) / macro_height)
    macro_colors = (
        _with_alpha(cfg.soft_color, cfg.macro_triangle_contrast),
        _with_alpha(cfg.panel_color, cfg.macro_triangle_contrast * 0.82),
        _with_alpha(cfg.accent_color, cfg.macro_triangle_contrast * 0.34),
    )
    for row in range(macro_first_row, macro_last_row + 1):
        y = row * macro_height
        offset = macro_side * 0.5 if row & 1 else 0.0
        for col in range(macro_first_col, macro_last_col + 1):
            x = col * macro_side + offset
            for face in range(2):
                chance = _cell_random(col, row, face + 4, cfg.random_seed)
                if chance >= cfg.macro_triangle_chance:
                    continue
                if face == 0:
                    path = _triangle_path(
                        QPointF(x, y), QPointF(x + macro_side, y), QPointF(x + macro_side * 0.5, y + macro_height)
                    )
                else:
                    path = _triangle_path(
                        QPointF(x + macro_side, y),
                        QPointF(x + macro_side * 1.5, y + macro_height),
                        QPointF(x + macro_side * 0.5, y + macro_height),
                    )
                color_index = min(2, int(_cell_random(col, row, face + 8, cfg.random_seed) * 3.0))
                painter.setBrush(macro_colors[color_index])
                painter.drawPath(path)

    painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    light_start, light_end = _gradient_axis(rect, cfg.light_direction_degrees)
    directional_light = QLinearGradient(light_start, light_end)
    directional_light.setColorAt(0.0, _with_alpha(cfg.soft_color, 0.0))
    directional_light.setColorAt(0.5, _with_alpha(cfg.soft_color, cfg.light_strength * 0.12))
    directional_light.setColorAt(1.0, _with_alpha(cfg.soft_color, cfg.light_strength * 0.28))
    painter.fillRect(rect, directional_light)

    light_center = QPointF(
        rect.left() + rect.width() * cfg.light_center_x,
        rect.top() + rect.height() * cfg.light_center_y,
    )
    central_light = QRadialGradient(light_center, max(rect.width(), rect.height()) * 0.58)
    central_light.setColorAt(0.0, _with_alpha(cfg.soft_color, cfg.light_strength))
    central_light.setColorAt(0.34, _with_alpha(cfg.soft_color, cfg.light_strength * 0.72))
    central_light.setColorAt(0.7, _with_alpha(cfg.accent_color, cfg.light_strength * 0.1))
    central_light.setColorAt(1.0, _with_alpha(cfg.soft_color, 0.0))
    painter.fillRect(rect, central_light)

    fog_start, fog_end = _gradient_axis(rect, cfg.fog_direction_degrees)
    fog = QLinearGradient(fog_start, fog_end)
    fog.setColorAt(0.0, _with_alpha(cfg.panel_color, 0.0))
    fog.setColorAt(0.28, _with_alpha(cfg.soft_color, cfg.fog_strength * 0.45))
    fog.setColorAt(0.56, _with_alpha(cfg.soft_color, cfg.fog_strength))
    fog.setColorAt(0.82, _with_alpha(cfg.panel_color, cfg.fog_strength * 0.28))
    fog.setColorAt(1.0, _with_alpha(cfg.panel_color, 0.0))
    painter.fillRect(rect, fog)

    glow_center = fog_start * 0.3 + fog_end * 0.7
    glow = QRadialGradient(glow_center, max(rect.width(), rect.height()) * 0.82)
    glow.setColorAt(0.0, _with_alpha(cfg.soft_color, cfg.fog_strength * 0.5))
    glow.setColorAt(0.48, _with_alpha(cfg.accent_color, cfg.fog_strength * 0.12))
    glow.setColorAt(1.0, _with_alpha(cfg.base_color, 0.0))
    painter.fillRect(rect, glow)

    vignette = QRadialGradient(light_center, max(rect.width(), rect.height()) * 0.72)
    vignette.setColorAt(0.0, _with_alpha("#000000", 0.0))
    vignette.setColorAt(0.56, _with_alpha("#000000", 0.0))
    vignette.setColorAt(0.82, _with_alpha("#000000", cfg.edge_vignette_strength * 0.42))
    vignette.setColorAt(1.0, _with_alpha("#000000", cfg.edge_vignette_strength))
    painter.fillRect(rect, vignette)
    painter.restore()


class TriangleTextureWidget(QWidget):
    """A reusable texture surface; child widgets should use transparent backgrounds."""

    def __init__(self, config: TriangleTextureConfig, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._texture_config = config.normalized()
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

    def textureConfig(self) -> TriangleTextureConfig:
        return self._texture_config

    def setTextureConfig(self, config: TriangleTextureConfig) -> None:
        normalized = config.normalized()
        if normalized != self._texture_config:
            self._texture_config = normalized
            self.update()

    def setTextureDirections(self, *, light: float | None = None, fog: float | None = None) -> None:
        changes: dict[str, float] = {}
        if light is not None:
            changes["light_direction_degrees"] = light
        if fog is not None:
            changes["fog_direction_degrees"] = fog
        if changes:
            self.setTextureConfig(replace(self._texture_config, **changes))

    def setTriangleSize(self, size: float) -> None:
        self.setTextureConfig(replace(self._texture_config, triangle_size=size))

    def paintEvent(self, event) -> None:  # noqa: N802 - Qt API
        painter = QPainter(self)
        paint_triangle_texture(painter, QRectF(self.rect()), self._texture_config)
        painter.end()
