"""Palette-aware, image-free triangular atmosphere backgrounds for Qt widgets."""

from __future__ import annotations

import heapq
import math
from dataclasses import dataclass, replace

from PySide6.QtCore import QPointF, QRectF, QSize, Qt, QVariantAnimation
from PySide6.QtGui import QColor, QLinearGradient, QPainter, QPainterPath, QPixmap, QRadialGradient
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
    light_direction_degrees: float | None = None
    light_strength: float = 0.12
    light_center_x: float = 0.5
    light_center_y: float = 0.5
    edge_vignette_strength: float = 0.16
    fog_direction_degrees: float = 18.0
    fog_strength: float = 0.075
    origin_jitter: float = 0.35
    row_phase_jitter: float = 0.18
    row_height_jitter: float = 0.06
    row_height_jitter_target_rows: float = 6.0

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
            origin_jitter=_clamp(float(self.origin_jitter), 0.0, 0.5),
            row_phase_jitter=_clamp(float(self.row_phase_jitter), 0.0, 0.3),
            row_height_jitter=_clamp(float(self.row_height_jitter), 0.0, 0.1),
            row_height_jitter_target_rows=_clamp(float(self.row_height_jitter_target_rows), 0.0, 12.0),
            light_direction_degrees=(
                float(self.light_direction_degrees) % 360.0
                if self.light_direction_degrees is not None
                else None
            ),
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


@dataclass(frozen=True, slots=True)
class _TriangleFace:
    col: int
    row: int
    face: int
    path: QPainterPath
    center: QPointF


@dataclass(frozen=True, slots=True)
class _TriangleWave:
    color: QColor
    mode: str
    duration_ms: int
    front_width: float
    front_alpha: float
    hold_alpha: float
    seed_offset: int


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


def _centered_row_noise(row: int, channel: int, seed: int) -> float:
    return (_cell_random(0, row, channel, seed) * 2.0) - 1.0


def _row_height(row: int, nominal_height: float, variation: float, seed: int, channel: int) -> float:
    return nominal_height * (1.0 + _centered_row_noise(row, channel, seed) * variation)


def _effective_row_height_jitter(
    surface_height: float,
    nominal_height: float,
    configured_jitter: float,
    target_rows: float,
) -> float:
    """Increase row variation on short surfaces with only a few visible bands."""

    if configured_jitter <= 0.0 or target_rows <= 0.0 or nominal_height <= 0.0:
        return configured_jitter
    visible_rows = max(1.0, surface_height / nominal_height)
    if visible_rows >= target_rows:
        return configured_jitter
    return min(0.1, configured_jitter * (target_rows / visible_rows))


def _row_boundary(row: int, nominal_height: float, variation: float, seed: int, channel: int) -> float:
    """Return a stable row boundary measured from the fixed row-zero anchor."""

    if row > 0:
        return sum(_row_height(index, nominal_height, variation, seed, channel) for index in range(row))
    if row < 0:
        return -sum(_row_height(index, nominal_height, variation, seed, channel) for index in range(row, 0))
    return 0.0


def _warped_row(
    row: int,
    *,
    side: float,
    nominal_height: float,
    seed: int,
    origin_jitter: float,
    phase_jitter: float,
    height_jitter: float,
    channel: int,
) -> tuple[float, float, float]:
    origin_x = _centered_row_noise(0, channel, seed) * side * origin_jitter
    origin_y = _centered_row_noise(0, channel + 1, seed) * nominal_height * origin_jitter
    top = origin_y + _row_boundary(row, nominal_height, height_jitter, seed, channel + 2)
    bottom = origin_y + _row_boundary(row + 1, nominal_height, height_jitter, seed, channel + 2)
    stagger = side * 0.5 if row & 1 else 0.0
    phase = origin_x + stagger + _centered_row_noise(row, channel + 3, seed) * side * phase_jitter
    return top, bottom, phase


def _base_triangle_faces(rect: QRectF, cfg: TriangleTextureConfig) -> list[_TriangleFace]:
    """Return the exact fine-grid faces used by both the texture and wave layers."""

    side = cfg.triangle_size
    height = side * math.sqrt(3.0) * 0.5
    row_height_jitter = _effective_row_height_jitter(
        rect.height(),
        height,
        cfg.row_height_jitter,
        cfg.row_height_jitter_target_rows,
    )
    minimum_height = height * (1.0 - row_height_jitter)
    first_row = math.floor((rect.top() - height) / minimum_height) - 2
    last_row = math.ceil((rect.bottom() + height) / minimum_height) + 2
    faces: list[_TriangleFace] = []
    for row in range(first_row, last_row + 1):
        y, next_y, offset = _warped_row(
            row,
            side=side,
            nominal_height=height,
            seed=cfg.random_seed,
            origin_jitter=cfg.origin_jitter,
            phase_jitter=cfg.row_phase_jitter,
            height_jitter=row_height_jitter,
            channel=20,
        )
        first_col = math.floor((rect.left() - offset - side) / side)
        last_col = math.ceil((rect.right() - offset + side) / side)
        for col in range(first_col, last_col + 1):
            x = col * side + offset
            first_points = (QPointF(x, y), QPointF(x + side, y), QPointF(x + side * 0.5, next_y))
            second_points = (
                QPointF(x + side, y),
                QPointF(x + side * 1.5, next_y),
                QPointF(x + side * 0.5, next_y),
            )
            for face, points in enumerate((first_points, second_points)):
                center = QPointF(
                    sum(point.x() for point in points) / 3.0,
                    sum(point.y() for point in points) / 3.0,
                )
                faces.append(_TriangleFace(col, row, face, _triangle_path(*points), center))
    return faces


def _wave_arrival_times(
    faces: list[_TriangleFace],
    rect: QRectF,
    side: float,
    seed: int,
) -> list[float]:
    """Build a connected, seeded propagation field with fast root-like branches."""

    if not faces:
        return []
    center = rect.center()
    source = min(
        range(len(faces)),
        key=lambda index: (faces[index].center.x() - center.x()) ** 2
        + (faces[index].center.y() - center.y()) ** 2,
    )

    bucket_size = max(1.0, side)
    buckets: dict[tuple[int, int], list[int]] = {}
    for index, face in enumerate(faces):
        key = (math.floor(face.center.x() / bucket_size), math.floor(face.center.y() / bucket_size))
        buckets.setdefault(key, []).append(index)

    neighbors: list[set[int]] = [set() for _ in faces]
    for index, face in enumerate(faces):
        bx = math.floor(face.center.x() / bucket_size)
        by = math.floor(face.center.y() / bucket_size)
        candidates: list[tuple[float, int]] = []
        for bucket_y in range(by - 1, by + 2):
            for bucket_x in range(bx - 1, bx + 2):
                for other in buckets.get((bucket_x, bucket_y), ()):
                    if other == index:
                        continue
                    dx = faces[other].center.x() - face.center.x()
                    dy = faces[other].center.y() - face.center.y()
                    distance = math.hypot(dx, dy)
                    if distance <= side * 1.15:
                        candidates.append((distance, other))
        for _distance, other in sorted(candidates)[:4]:
            neighbors[index].add(other)
            neighbors[other].add(index)

    distances = [math.inf] * len(faces)
    distances[source] = 0.0
    queue: list[tuple[float, int]] = [(0.0, source)]
    while queue:
        current_distance, index = heapq.heappop(queue)
        if current_distance != distances[index]:
            continue
        current = faces[index]
        for other in neighbors[index]:
            target = faces[other]
            dx = target.center.x() - current.center.x()
            dy = target.center.y() - current.center.y()
            geometric = math.hypot(dx, dy) / max(1.0, side)
            low_col = min(current.col, target.col)
            low_row = min(current.row, target.row)
            channel = 80 + current.face * 7 + target.face * 13
            noise = _cell_random(low_col, low_row, channel, seed)
            # Squared noise creates a few cheap connected channels that lead the
            # broader front, producing roots without repaint-time randomness.
            edge_cost = geometric * (0.28 + 1.52 * noise * noise)
            candidate = current_distance + edge_cost
            if candidate < distances[other]:
                distances[other] = candidate
                heapq.heappush(queue, (candidate, other))

    finite = [distance for distance in distances if math.isfinite(distance)]
    maximum = max(finite, default=1.0)
    if maximum <= 0.0:
        return [0.0] * len(faces)
    # Reserve the final part of the animation for the trailing faces to fade.
    return [
        (distance / maximum) * 0.82 if math.isfinite(distance) else 0.82
        for distance in distances
    ]


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
    face_colors = (
        _with_alpha(cfg.soft_color, cfg.tessellation_contrast * 0.62),
        _with_alpha(cfg.panel_color, cfg.tessellation_contrast * 0.9),
        _with_alpha("#000000", cfg.tessellation_contrast * 0.38),
        _with_alpha(cfg.accent_color, cfg.tessellation_contrast * 0.2),
    )
    painter.setPen(Qt.PenStyle.NoPen)
    for face in _base_triangle_faces(rect, cfg):
        shade = min(3, int(_cell_random(face.col, face.row, face.face, cfg.random_seed) * 4.0))
        painter.setBrush(face_colors[shade])
        painter.drawPath(face.path)

    # Sparse oversized faces interrupt the fine grid without drawing outlines.
    macro_side = side * cfg.macro_triangle_scale
    macro_height = macro_side * math.sqrt(3.0) * 0.5
    macro_row_height_jitter = _effective_row_height_jitter(
        rect.height(),
        macro_height,
        cfg.row_height_jitter,
        cfg.row_height_jitter_target_rows,
    )
    macro_minimum_height = macro_height * (1.0 - macro_row_height_jitter)
    macro_first_row = math.floor((rect.top() - macro_height) / macro_minimum_height) - 2
    macro_last_row = math.ceil((rect.bottom() + macro_height) / macro_minimum_height) + 2
    macro_colors = (
        _with_alpha(cfg.soft_color, cfg.macro_triangle_contrast),
        _with_alpha(cfg.panel_color, cfg.macro_triangle_contrast * 0.82),
        _with_alpha(cfg.accent_color, cfg.macro_triangle_contrast * 0.34),
    )
    for row in range(macro_first_row, macro_last_row + 1):
        y, next_y, offset = _warped_row(
            row,
            side=macro_side,
            nominal_height=macro_height,
            seed=cfg.random_seed,
            origin_jitter=cfg.origin_jitter,
            phase_jitter=cfg.row_phase_jitter,
            height_jitter=macro_row_height_jitter,
            channel=40,
        )
        macro_first_col = math.floor((rect.left() - offset - macro_side) / macro_side)
        macro_last_col = math.ceil((rect.right() - offset + macro_side) / macro_side)
        for col in range(macro_first_col, macro_last_col + 1):
            x = col * macro_side + offset
            for face in range(2):
                chance = _cell_random(col, row, face + 4, cfg.random_seed)
                if chance >= cfg.macro_triangle_chance:
                    continue
                if face == 0:
                    path = _triangle_path(
                        QPointF(x, y), QPointF(x + macro_side, y), QPointF(x + macro_side * 0.5, next_y)
                    )
                else:
                    path = _triangle_path(
                        QPointF(x + macro_side, y),
                        QPointF(x + macro_side * 1.5, next_y),
                        QPointF(x + macro_side * 0.5, next_y),
                    )
                color_index = min(2, int(_cell_random(col, row, face + 8, cfg.random_seed) * 3.0))
                painter.setBrush(macro_colors[color_index])
                painter.drawPath(path)

    painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    if cfg.light_direction_degrees is not None:
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
        self._texture_cache: QPixmap | None = None
        self._texture_cache_key: tuple[int, int, float] | None = None
        self._wave_faces: list[_TriangleFace] = []
        self._wave_arrivals: list[float] = []
        self._wave_geometry_key: tuple[object, ...] | None = None
        self._wave: _TriangleWave | None = None
        self._wave_progress = 0.0
        self._held_color: QColor | None = None
        self._held_alpha = 0.0
        self._wave_animation = QVariantAnimation(self)
        self._wave_animation.setStartValue(0.0)
        self._wave_animation.setEndValue(1.0)
        self._wave_animation.valueChanged.connect(self._set_wave_progress)
        self._wave_animation.finished.connect(self._finish_wave)
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

    def textureConfig(self) -> TriangleTextureConfig:
        return self._texture_config

    def setTextureConfig(self, config: TriangleTextureConfig) -> None:
        normalized = config.normalized()
        if normalized != self._texture_config:
            self._texture_config = normalized
            self._invalidate_texture_cache()
            self._invalidate_wave_geometry()
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

    def playWave(
        self,
        color: str | QColor,
        *,
        duration_ms: int,
        mode: str = "pulse",
        front_width: float = 0.18,
        front_alpha: float = 0.56,
        hold_alpha: float = 0.3,
        seed_offset: int = 0,
    ) -> None:
        """Play a triangle-by-triangle wave: pulse, hold, or restore."""

        if mode not in {"pulse", "hold", "restore"}:
            raise ValueError(f"unsupported triangle wave mode: {mode}")
        self._wave_animation.stop()
        self._wave = _TriangleWave(
            color=QColor(color),
            mode=mode,
            duration_ms=max(1, int(duration_ms)),
            front_width=_clamp(float(front_width), 0.04, 0.4),
            front_alpha=_clamp(float(front_alpha), 0.0, 1.0),
            hold_alpha=_clamp(float(hold_alpha), 0.0, 0.75),
            seed_offset=int(seed_offset),
        )
        self._wave_progress = 0.0
        self._invalidate_wave_geometry()
        self._wave_animation.setDuration(self._wave.duration_ms)
        self._wave_animation.start()
        self.update()

    def hasHeldWave(self) -> bool:
        return self._held_color is not None and self._held_alpha > 0.0

    def _set_wave_progress(self, value: object) -> None:
        self._wave_progress = _clamp(float(value), 0.0, 1.0)
        self.update()

    def _finish_wave(self) -> None:
        wave = self._wave
        if wave is None:
            return
        if wave.mode == "hold":
            self._held_color = QColor(wave.color)
            self._held_alpha = wave.hold_alpha
        elif wave.mode == "restore":
            self._held_color = None
            self._held_alpha = 0.0
        self._wave = None
        self._wave_progress = 0.0
        self.update()

    def _invalidate_texture_cache(self) -> None:
        self._texture_cache = None
        self._texture_cache_key = None

    def _invalidate_wave_geometry(self) -> None:
        self._wave_geometry_key = None
        self._wave_faces = []
        self._wave_arrivals = []

    def _ensure_texture_cache(self) -> None:
        ratio = max(1.0, self.devicePixelRatioF())
        cache_key = (self.width(), self.height(), ratio)
        if self._texture_cache is not None and self._texture_cache_key == cache_key:
            return
        pixel_size = QSize(max(1, round(self.width() * ratio)), max(1, round(self.height() * ratio)))
        cache = QPixmap(pixel_size)
        cache.setDevicePixelRatio(ratio)
        cache.fill(Qt.GlobalColor.transparent)
        painter = QPainter(cache)
        paint_triangle_texture(painter, QRectF(self.rect()), self._texture_config)
        painter.end()
        self._texture_cache = cache
        self._texture_cache_key = cache_key

    def _ensure_wave_geometry(self) -> None:
        wave_seed = self._wave.seed_offset if self._wave is not None else 0
        key = (
            self.width(),
            self.height(),
            self._texture_config,
            wave_seed,
        )
        if key == self._wave_geometry_key:
            return
        rect = QRectF(self.rect())
        self._wave_faces = _base_triangle_faces(rect, self._texture_config)
        self._wave_arrivals = _wave_arrival_times(
            self._wave_faces,
            rect,
            self._texture_config.triangle_size,
            self._texture_config.random_seed + wave_seed,
        )
        self._wave_geometry_key = key

    def _paint_wave_layer(self, painter: QPainter) -> None:
        if self._wave is None and self._held_color is None:
            return
        self._ensure_wave_geometry()
        painter.save()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, False)
        painter.setPen(Qt.PenStyle.NoPen)
        wave = self._wave
        for face, arrival in zip(self._wave_faces, self._wave_arrivals):
            hold_color = self._held_color
            hold_alpha = self._held_alpha
            if wave is not None and wave.mode == "hold" and self._wave_progress >= arrival:
                hold_color = wave.color
                hold_alpha = wave.hold_alpha
            elif wave is not None and wave.mode == "restore" and self._wave_progress >= arrival:
                hold_color = None
                hold_alpha = 0.0
            if hold_color is not None and hold_alpha > 0.0:
                painter.setBrush(_with_alpha(hold_color, hold_alpha))
                painter.drawPath(face.path)

            if wave is None or self._wave_progress < arrival:
                continue
            age = self._wave_progress - arrival
            if age > wave.front_width:
                continue
            strength = (1.0 - (age / wave.front_width)) ** 1.35
            painter.setBrush(_with_alpha(wave.color, wave.front_alpha * strength))
            painter.drawPath(face.path)
        painter.restore()

    def resizeEvent(self, event) -> None:  # noqa: N802 - Qt API
        self._invalidate_texture_cache()
        self._invalidate_wave_geometry()
        super().resizeEvent(event)

    def paintEvent(self, event) -> None:  # noqa: N802 - Qt API
        self._ensure_texture_cache()
        painter = QPainter(self)
        if self._texture_cache is not None:
            painter.drawPixmap(0, 0, self._texture_cache)
        self._paint_wave_layer(painter)
        painter.end()
