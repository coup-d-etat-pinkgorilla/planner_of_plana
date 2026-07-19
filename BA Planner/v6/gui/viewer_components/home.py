"""Home dashboard, diagonal section geometry, and section transitions."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, replace

from PySide6.QtWidgets import QGraphicsDropShadowEffect, QGraphicsOpacityEffect

from gui import viewer_shared as _viewer_shared
from gui.diagonal_scroll_list import DiagonalScrollList

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


HOME_DIAGONAL_ANGLE = 80.0
HOME_CENTER_INTRO_ANGLE = 80.0
HOME_CENTER_OUTRO_ANGLE = 260.0
HOME_MENU_INTRO_ANGLE = 0.0
HOME_MENU_OUTRO_ANGLE = 180.0
HOME_SECTION_SEAM_GAP = 10.0
HOME_PANEL_MOTION = {
    "settings": (80.0, 260.0),
    "items": (80.0, 260.0),
    "resources": (80.0, 260.0),
}
HOME_MENU_ASSET_DIR = BASE_DIR / "assets" / "ui" / "home_menu"
HOME_MENU_CAPTION_RATIO = 0.35
HOME_MENU_CAPTION_COLOR = "#747b86"
HOME_MENU_CAPTION_TEXT_COLOR = "#ffffff"
HOME_MENU_SETTINGS_TEXT_COLOR = "#ffffff"
HOME_MENU_TEXTURE_OVERSCAN = 1.06
HOME_MENU_TEXTURES = {
    "학생부 확인": HOME_MENU_ASSET_DIR / "students.png",
    "통계": HOME_MENU_ASSET_DIR / "statistics.png",
    "싯딤의 상자와 연결": HOME_MENU_ASSET_DIR / "shittim.png",
    "스캔": HOME_MENU_ASSET_DIR / "scan.png",
    "전술대항전": HOME_MENU_ASSET_DIR / "pvp.png",
    "계획 설정": HOME_MENU_ASSET_DIR / "plan.png",
    "인벤토리": HOME_MENU_ASSET_DIR / "inventory.png",
}


def _home_candidate_triangle_texture(base_color: str, *, random_seed: int = 7759) -> TriangleTextureConfig:
    """Return the shared BA texture used by connection candidates and scan actions."""

    return TriangleTextureConfig(
        base_color=base_color,
        panel_color=PALETTE_PANEL,
        soft_color=PALETTE_SOFT,
        accent_color=PALETTE_ACCENT,
        tessellation_contrast=0.032,
        random_seed=random_seed,
        macro_triangle_chance=0.075,
        macro_triangle_scale=3.0,
        macro_triangle_contrast=0.024,
        light_strength=0.12,
        light_center_x=0.5,
        light_center_y=0.5,
        edge_vignette_strength=0.16,
        fog_direction_degrees=18.0,
        fog_strength=0.075,
    )


@dataclass(frozen=True, slots=True)
class LiftedShadowSpec:
    """Small painter-native shadow that follows one custom surface path."""

    color: str
    offset_x: float = 2.0
    offset_y: float = 2.0
    inset: float = 3.0
    layers: int = 4
    max_alpha: float = 0.2


def _paint_lifted_shadow(painter: QPainter, path: QPainterPath, spec: LiftedShadowSpec | None) -> None:
    if spec is None or path.isEmpty():
        return
    layers = max(1, int(spec.layers))
    max_alpha = min(1.0, max(0.0, float(spec.max_alpha)))
    painter.save()
    painter.setPen(Qt.NoPen)
    for layer in range(layers, 0, -1):
        progress = layer / layers
        color = QColor(spec.color)
        color.setAlphaF(max_alpha * (1.0 - (progress * 0.65)))
        painter.setBrush(color)
        painter.drawPath(path.translated(spec.offset_x * progress, spec.offset_y * progress))
    painter.restore()


def _apply_lifted_widget_shadow(widget: QWidget, spec: LiftedShadowSpec) -> QGraphicsDropShadowEffect:
    """Apply a restrained shadow to one isolated ordinary widget."""
    effect = QGraphicsDropShadowEffect(widget)
    color = QColor(spec.color)
    color.setAlphaF(min(1.0, max(0.0, float(spec.max_alpha))))
    effect.setColor(color)
    effect.setOffset(float(spec.offset_x), float(spec.offset_y))
    effect.setBlurRadius(max(3.0, float(spec.inset) * 2.0))
    widget.setGraphicsEffect(effect)
    return effect


def _scaled_font(source: QFont, factor: float) -> QFont:
    """Return a copy of a Qt font scaled in its active sizing unit."""

    font = QFont(source)
    factor = max(0.01, float(factor))
    if font.pixelSize() > 0:
        font.setPixelSize(max(1, round(font.pixelSize() * factor)))
    elif font.pointSizeF() > 0.0:
        font.setPointSizeF(font.pointSizeF() * factor)
    return font


def _diagonal_depth(height: float, radius: float, angle_degrees: float = HOME_DIAGONAL_ANGLE) -> float:
    vertical_run = max(0.0, float(height) - (2.0 * float(radius)))
    return vertical_run / max(0.01, math.tan(math.radians(angle_degrees)))


def _rounded_polygon_path(points: list[QPointF], radius: float) -> QPainterPath:
    """Return one antialiased polygon path with a radius at every vertex."""
    path = QPainterPath()
    if len(points) < 3:
        return path

    before: list[QPointF] = []
    after: list[QPointF] = []
    for index, point in enumerate(points):
        previous = points[index - 1]
        following = points[(index + 1) % len(points)]
        incoming = point - previous
        outgoing = following - point
        incoming_length = math.hypot(incoming.x(), incoming.y())
        outgoing_length = math.hypot(outgoing.x(), outgoing.y())
        corner_radius = min(max(0.0, radius), incoming_length / 2.0, outgoing_length / 2.0)
        incoming_scale = corner_radius / max(1e-6, incoming_length)
        outgoing_scale = corner_radius / max(1e-6, outgoing_length)
        before.append(point - (incoming * incoming_scale))
        after.append(point + (outgoing * outgoing_scale))

    path.moveTo(after[0])
    for index in range(1, len(points)):
        path.lineTo(before[index])
        path.quadTo(points[index], after[index])
    path.lineTo(before[0])
    path.quadTo(points[0], after[0])
    path.closeSubpath()
    return path


class HomeGlassSection(QFrame):
    """Low-contrast glass section with optional cut and extension edges."""

    def __init__(
        self,
        *,
        fill: str,
        radius: int,
        cut_right: bool = False,
        extend_left: int = 0,
        angle_degrees: float = HOME_DIAGONAL_ANGLE,
        lifted_shadow: LiftedShadowSpec | None = None,
        round_extension_corners: bool = False,
        triangle_texture: TriangleTextureConfig | None = None,
    ) -> None:
        super().__init__()
        self._fill = QColor(fill)
        self._radius = max(0, int(radius))
        self._cut_right = bool(cut_right)
        self._extend_left = max(0, int(extend_left))
        self._angle_degrees = float(angle_degrees)
        self._lifted_shadow = lifted_shadow
        self._round_extension_corners = bool(round_extension_corners)
        self._triangle_texture = triangle_texture.normalized() if triangle_texture is not None else None
        self._base_content_margins: tuple[int, int, int, int] | None = None
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WA_StyledBackground, False)

    def leftExtensionDepth(self, width: float | None = None, height: float | None = None) -> float:
        """Return the left wedge depth that preserves the configured screen-space angle."""
        if self._extend_left <= 0:
            return 0.0
        resolved_width = float(self.width()) if width is None else max(0.0, float(width))
        resolved_height = float(self.height()) if height is None else max(0.0, float(height))
        tangent = abs(math.tan(math.radians(self._angle_degrees)))
        natural_depth = resolved_height / max(0.01, tangent)
        return min(natural_depth, max(0.0, resolved_width - (2.0 * float(self._radius))))

    def setBaseContentMargins(self, left: int, top: int, right: int, bottom: int) -> None:
        """Anchor child content to the preserved rectangular base, outside the wedge."""
        self._base_content_margins = (int(left), int(top), int(right), int(bottom))
        self._sync_base_content_margins()

    def _sync_base_content_margins(self) -> None:
        layout = self.layout()
        if layout is None or self._base_content_margins is None:
            return
        left, top, right, bottom = self._base_content_margins
        extension = math.ceil(self.leftExtensionDepth())
        layout.setContentsMargins(left + extension, top, right, bottom)

    def rightEdgeXAt(self, y: float) -> float:
        """Return the cut surface's right boundary at a section-local Y."""
        width = float(self.width())
        height = float(self.height())
        if not self._cut_right or width <= 0.0 or height <= 0.0:
            return width
        extension = self.leftExtensionDepth(width, height)
        radius = min(float(self._radius), max(0.0, (width - extension) / 2.0), height / 2.0)
        computed_cut = _diagonal_depth(height, radius, self._angle_degrees)
        requested_cut = extension if extension > 0.0 else computed_cut
        cut = min(max(0.0, width - extension - (2.0 * radius)), requested_cut)
        if extension > 0.0 and self._round_extension_corners:
            progress = min(1.0, max(0.0, float(y) / height))
            return width - (cut * progress)
        straight_run = max(1e-6, height - (2.0 * radius))
        progress = min(1.0, max(0.0, (float(y) - radius) / straight_run))
        return width - (cut * progress)

    def leftEdgeXAt(self, y: float) -> float:
        """Return the extended surface's left boundary at a section-local Y."""
        width = float(self.width())
        height = float(self.height())
        if self._extend_left <= 0 or width <= 0.0 or height <= 0.0:
            return 0.0
        extension = self.leftExtensionDepth(width, height)
        progress = min(1.0, max(0.0, float(y) / height))
        return extension * (1.0 - progress)

    def _shape_path(self, width: float, height: float) -> QPainterPath:
        if width <= 0.0 or height <= 0.0:
            return QPainterPath()
        extension = self.leftExtensionDepth(width, height)
        base_left = extension
        radius = min(float(self._radius), max(0.0, (width - extension) / 2.0), height / 2.0)
        computed_cut = _diagonal_depth(height, radius, self._angle_degrees)
        requested_cut = extension if extension > 0.0 else computed_cut
        cut = min(max(0.0, width - extension - (2.0 * radius)), requested_cut) if self._cut_right else 0.0
        right_top = width
        right_bottom = max(base_left + (2.0 * radius), width - cut)

        if extension > 0.0 and self._round_extension_corners:
            return _rounded_polygon_path(
                [
                    QPointF(base_left, 0.0),
                    QPointF(right_top, 0.0),
                    QPointF(right_bottom, height),
                    QPointF(0.0, height),
                ],
                radius,
            )

        path = QPainterPath()
        path.moveTo(base_left + radius, 0.0)
        path.lineTo(right_top - radius, 0.0)
        path.quadTo(right_top, 0.0, right_top, radius)
        path.lineTo(right_bottom, height - radius)
        path.quadTo(right_bottom, height, right_bottom - radius, height)
        if extension > 0.0:
            # Preserve the whole base rectangle and add one full-height wedge.
            # Its outer edge is parallel to a sibling's equally deep right cut.
            path.lineTo(base_left, height)
            path.lineTo(0.0, height)
            path.lineTo(base_left, 0.0)
            path.lineTo(base_left + radius, 0.0)
        else:
            path.lineTo(base_left + radius, height)
            path.quadTo(base_left, height, base_left, height - radius)
            path.lineTo(base_left, radius)
            path.quadTo(base_left, 0.0, base_left + radius, 0.0)
        path.closeSubpath()
        return path

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._sync_base_content_margins()

    def paintEvent(self, event) -> None:
        width = float(self.width())
        height = float(self.height())
        if width <= 0.0 or height <= 0.0:
            return
        inset = max(0.0, float(self._lifted_shadow.inset)) if self._lifted_shadow is not None else 0.0
        path = self._shape_path(max(1.0, width - inset), max(1.0, height - inset))

        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        _paint_lifted_shadow(painter, path, self._lifted_shadow)
        painter.save()
        painter.setClipPath(path)
        if self._triangle_texture is None:
            painter.fillPath(path, self._fill)
        else:
            # Compact cards need a scale tied to their own height; inheriting
            # the full-window triangle size makes the texture read as a flat
            # gradient on short settings surfaces.
            config = replace(
                self._triangle_texture,
                triangle_size=max(6.0, height * 0.80),
            )
            texture = QPixmap(self.size())
            texture.fill(Qt.transparent)
            texture_painter = QPainter(texture)
            paint_triangle_texture(texture_painter, QRectF(texture.rect()), config)
            texture_painter.end()
            painter.drawPixmap(0, 0, texture)
        painter.restore()
        painter.end()


class HomeButtonCaptionOverlay(QWidget):
    """Mouse-transparent caption wash painted independently above a menu button."""

    def __init__(
        self,
        *,
        ratio: float,
        color: str,
        show_text: bool,
        text_color: str,
        parent: QWidget,
    ) -> None:
        super().__init__(parent)
        self._ratio = min(1.0, max(0.0, float(ratio)))
        self._color = QColor(color)
        self._show_text = bool(show_text)
        self._text_color = QColor(text_color)
        self.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WA_StyledBackground, False)

    def paintEvent(self, event) -> None:
        button = self.parentWidget()
        if not isinstance(button, ParallelogramActionButton) or (self._ratio <= 0.0 and not self._show_text):
            return
        path = button.surfacePath()
        width = float(button.width())
        height = float(button.height())
        if path.isEmpty() or width <= 0.0 or height <= 0.0:
            return

        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.setClipPath(path)
        if self._ratio > 0.0:
            top = height * (1.0 - self._ratio)
            transparent = QColor(self._color)
            low = QColor(self._color)
            readable = QColor(self._color)
            near_opaque = QColor(self._color)
            opaque = QColor(self._color)
            transparent.setAlpha(0)
            low.setAlphaF(0.46)
            readable.setAlphaF(0.84)
            near_opaque.setAlphaF(0.96)
            opaque.setAlphaF(1.0)
            gradient = QLinearGradient(0.0, top, 0.0, height)
            gradient.setColorAt(0.0, transparent)
            gradient.setColorAt(0.18, low)
            gradient.setColorAt(0.3, readable)
            gradient.setColorAt(0.56, near_opaque)
            gradient.setColorAt(1.0, opaque)
            painter.fillRect(QRectF(0.0, top, width, height - top), gradient)

        if self._show_text and button.accessibleName():
            slant = button._diagonal_slant(width, height)
            left = max(10.0, height * 0.08)
            right = slant + max(8.0, height * 0.055)
            bottom = max(7.0, height * 0.055)
            text_top = height * 0.65
            text_rect = QRectF(
                left,
                text_top,
                max(1.0, width - left - right),
                max(1.0, height - text_top - bottom),
            )
            font = QFont(button.font())
            font.setBold(True)
            font.setPixelSize(max(12, min(24, round(height * 0.14))))
            painter.setFont(font)
            painter.setPen(self._text_color)
            painter.drawText(text_rect, Qt.AlignLeft | Qt.AlignBottom | Qt.TextWordWrap, button.accessibleName())
        painter.end()


class ParallelogramActionButton(QPushButton):
    """Action button with a cut right edge and an optional left extension."""

    def __init__(
        self,
        text: str,
        *,
        fill: str,
        accent: str,
        slant: int = 20,
        extend_left: bool = True,
        angle_degrees: float | None = None,
        radius: int = 0,
        texture_path: Path | None = None,
        triangle_texture: TriangleTextureConfig | None = None,
        triangle_visible_ratio: float = 0.5,
        display_text: bool = True,
        lifted_shadow: LiftedShadowSpec | None = None,
        caption_overlay_ratio: float = 0.0,
        caption_overlay_color: str = HOME_MENU_CAPTION_COLOR,
        caption_text_enabled: bool = False,
        caption_text_color: str = HOME_MENU_CAPTION_TEXT_COLOR,
        texture_overscan: float = 1.0,
        show_focus_outline: bool = True,
        triangle_fade_direction_degrees: float | None = None,
        triangle_fade_end_color: str | None = None,
        triangle_fade_start: float = 0.0,
        triangle_fade_end: float = 1.0,
        triangle_texture_only: bool = False,
        state_effects_enabled: bool = True,
        full_height_slant: bool = False,
        cut_right: bool = True,
        reserve_shadow_inset: bool = False,
    ) -> None:
        super().__init__()
        self._fill = QColor(fill)
        self._accent = QColor(accent)
        self._slant = max(8, int(slant))
        self._extend_left = bool(extend_left)
        self._angle_degrees = float(angle_degrees) if angle_degrees is not None else None
        self._radius = max(0, int(radius))
        self._display_text = bool(display_text)
        self._texture = QPixmap(str(texture_path)) if texture_path is not None else QPixmap()
        self._triangle_texture = triangle_texture.normalized() if triangle_texture is not None else None
        self._triangle_visible_ratio = min(1.0, max(0.0, float(triangle_visible_ratio)))
        self._triangle_cache = QPixmap()
        self._triangle_cache_size = QSize()
        self._lifted_shadow = lifted_shadow
        self._caption_overlay_ratio = min(1.0, max(0.0, float(caption_overlay_ratio)))
        self._caption_overlay_color = QColor(caption_overlay_color)
        self._caption_text_enabled = bool(caption_text_enabled)
        self._caption_text_color = QColor(caption_text_color)
        self._texture_overscan = min(1.3, max(1.0, float(texture_overscan)))
        self._show_focus_outline = bool(show_focus_outline)
        self._triangle_fade_direction_degrees = (
            float(triangle_fade_direction_degrees) % 360.0
            if triangle_fade_direction_degrees is not None
            else None
        )
        self._triangle_fade_end_color = QColor(triangle_fade_end_color) if triangle_fade_end_color else None
        self._triangle_fade_start = min(1.0, max(0.0, float(triangle_fade_start)))
        self._triangle_fade_end = min(1.0, max(self._triangle_fade_start, float(triangle_fade_end)))
        self._triangle_texture_only = bool(triangle_texture_only)
        self._state_effects_enabled = bool(state_effects_enabled)
        self._full_height_slant = bool(full_height_slant)
        self._cut_right = bool(cut_right)
        self._reserve_shadow_inset = bool(reserve_shadow_inset)
        self.setActionName(text)
        self.setProperty("homeAction", True)
        self.setCursor(Qt.PointingHandCursor)
        self.setMinimumHeight(54)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self.setStyleSheet("background: transparent; border: none; padding: 0px;")
        self._caption_overlay = (
            HomeButtonCaptionOverlay(
                ratio=self._caption_overlay_ratio,
                color=self._caption_overlay_color.name(),
                show_text=self._caption_text_enabled,
                text_color=self._caption_text_color.name(),
                parent=self,
            )
            if self._caption_overlay_ratio > 0.0 or self._caption_text_enabled
            else None
        )

    def setActionName(self, text: str) -> None:
        """Update the accessible action name without forcing visible button copy."""
        self.setAccessibleName(text)
        self.setText(text if self._display_text else "")
        overlay = getattr(self, "_caption_overlay", None)
        if overlay is not None:
            overlay.update()

    def setTexturePath(self, texture_path: Path | None) -> None:
        self._texture = QPixmap(str(texture_path)) if texture_path is not None else QPixmap()
        self.update()

    def _scaled_triangle_texture(self) -> QPixmap:
        if self._triangle_texture is None or self.size().isEmpty():
            return QPixmap()
        if not self._triangle_cache.isNull() and self._triangle_cache_size == self.size():
            return self._triangle_cache

        texture = QPixmap(self.size())
        texture.fill(Qt.transparent)
        texture_painter = QPainter(texture)
        config = replace(
            self._triangle_texture,
            triangle_size=max(6.0, float(self.height()) * 0.8),
        )
        paint_triangle_texture(texture_painter, QRectF(texture.rect()), config)
        texture_painter.end()
        self._triangle_cache = texture
        self._triangle_cache_size = QSize(self.size())
        return texture

    def _paint_image_texture(self, painter: QPainter, path: QPainterPath) -> bool:
        if self._texture.isNull():
            return False
        target_size = QSize(
            max(1, math.ceil(self.width() * self._texture_overscan)),
            max(1, math.ceil(self.height() * self._texture_overscan)),
        )
        scaled = self._texture.scaled(
            target_size,
            Qt.KeepAspectRatioByExpanding,
            Qt.SmoothTransformation,
        )
        x = (self.width() - scaled.width()) // 2
        y = (self.height() - scaled.height()) // 2
        painter.save()
        painter.setClipPath(path)
        painter.drawPixmap(x, y, scaled)
        painter.restore()
        return True

    def _paint_triangle_surface(self, painter: QPainter, path: QPainterPath) -> bool:
        if self._triangle_texture is None:
            return False

        width = float(self.width())
        height = float(self.height())
        texture = self._scaled_triangle_texture()
        if self._triangle_texture_only:
            if texture.isNull():
                return False
            painter.save()
            painter.setClipPath(path)
            painter.drawPixmap(0, 0, texture)
            painter.restore()
            return True

        base_gray = QColor(self._triangle_texture.base_color)
        light_gray = QColor(self._triangle_texture.soft_color)
        if self._triangle_fade_direction_degrees is None:
            background = QLinearGradient(0.0, 0.0, width, 0.0)
            background.setColorAt(0.0, base_gray)
            background.setColorAt(1.0, light_gray)
        else:
            radians = math.radians(self._triangle_fade_direction_degrees)
            dx = math.cos(radians)
            dy = math.sin(radians)
            span = abs(dx) * width + abs(dy) * height
            center = QPointF(width * 0.5, height * 0.5)
            offset = QPointF(dx * span * 0.5, dy * span * 0.5)
            background = QLinearGradient(center - offset, center + offset)
            background.setColorAt(0.0, base_gray)
            background.setColorAt(1.0, self._triangle_fade_end_color or light_gray)
        painter.fillPath(path, background)

        visible_width = width * self._triangle_visible_ratio
        if not texture.isNull() and visible_width > 0.0:
            source = QRectF(0.0, 0.0, visible_width, height)
            painter.save()
            painter.setClipPath(path)
            painter.setOpacity(0.88)
            painter.drawPixmap(source, texture, source)
            painter.restore()

        # Fade the tessellation into the brighter right-side light without a
        # hard vertical seam at the end of the textured half.
        if self._triangle_fade_direction_degrees is None:
            fade = QLinearGradient(0.0, 0.0, width, 0.0)
            transparent_end = QColor(light_gray)
            transparent_end.setAlpha(0)
            fade.setColorAt(max(0.0, self._triangle_visible_ratio - 0.16), transparent_end)
            fade.setColorAt(min(1.0, self._triangle_visible_ratio + 0.08), light_gray)
            fade.setColorAt(1.0, light_gray)
        else:
            radians = math.radians(self._triangle_fade_direction_degrees)
            dx = math.cos(radians)
            dy = math.sin(radians)
            span = abs(dx) * width + abs(dy) * height
            center = QPointF(width * 0.5, height * 0.5)
            offset = QPointF(dx * span * 0.5, dy * span * 0.5)
            fade = QLinearGradient(center - offset, center + offset)
            fade_color = QColor(self._triangle_fade_end_color or light_gray)
            transparent_end = QColor(fade_color)
            transparent_end.setAlpha(0)
            fade.setColorAt(0.0, transparent_end)
            fade.setColorAt(self._triangle_fade_start, transparent_end)
            fade.setColorAt(self._triangle_fade_end, fade_color)
            fade.setColorAt(1.0, fade_color)
        painter.fillPath(path, fade)
        return True

    def _diagonal_slant(self, width: float, height: float) -> float:
        radius = min(float(self._radius), width / 2.0, height / 2.0)
        requested = (
            (
                height / max(0.01, math.tan(math.radians(self._angle_degrees)))
                if self._full_height_slant
                else _diagonal_depth(height, radius, self._angle_degrees)
            )
            if self._angle_degrees is not None
            else float(self._slant)
        )
        return min(requested, width * 0.24, height * 0.48)

    def _shape_path(self, width: float, height: float, slant: float) -> QPainterPath:
        base_left = slant if self._extend_left else 0.0
        radius = min(float(self._radius), width / 2.0, height / 2.0)
        bottom_right = width - slant if self._cut_right else width
        return _rounded_polygon_path(
            [
                QPointF(base_left, 0.0),
                QPointF(width, 0.0),
                QPointF(bottom_right, height),
                QPointF(0.0, height),
            ],
            radius,
        )

    def hitButton(self, pos: QPoint) -> bool:
        width = float(self.width())
        height = float(self.height())
        if width <= 0.0 or height <= 0.0:
            return False
        slant = self._diagonal_slant(width, height)
        return self._shape_path(width, height, slant).contains(QPointF(pos))

    def surfacePath(self) -> QPainterPath:
        width = float(self.width())
        height = float(self.height())
        if width <= 0.0 or height <= 0.0:
            return QPainterPath()
        return self._shape_path(width, height, self._diagonal_slant(width, height))

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        if self._caption_overlay is not None:
            self._caption_overlay.setGeometry(self.rect())
            self._caption_overlay.raise_()

    def paintEvent(self, event) -> None:
        width = float(self.width())
        height = float(self.height())
        if width <= 0.0 or height <= 0.0:
            return
        inset = (
            max(0.0, float(self._lifted_shadow.inset))
            if self._lifted_shadow is not None and self._reserve_shadow_inset
            else 0.0
        )
        surface_width = max(1.0, width - inset)
        surface_height = max(1.0, height - inset)
        slant = self._diagonal_slant(surface_width, surface_height)
        path = self._shape_path(surface_width, surface_height, slant)

        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        _paint_lifted_shadow(painter, path, self._lifted_shadow)
        painter.setPen(Qt.NoPen)
        painted_texture = self._paint_image_texture(painter, path)
        if not painted_texture:
            painted_texture = self._paint_triangle_surface(painter, path)
        if not painted_texture:
            painter.setBrush(self._fill)
            painter.drawPath(path)
        if self._state_effects_enabled:
            state_overlay = QColor(Qt.transparent)
            if not self.isEnabled():
                state_overlay = QColor(0, 0, 0, 138)
            elif self.isDown():
                state_overlay = QColor(0, 0, 0, 34)
            elif self.underMouse():
                state_overlay = QColor(255, 255, 255, 24)
            if state_overlay.alpha() > 0:
                painter.fillPath(path, state_overlay)
        if self._show_focus_outline and self.hasFocus():
            pen = QPen(self._accent)
            pen.setWidthF(2.0)
            painter.setPen(pen)
            painter.setBrush(Qt.NoBrush)
            painter.drawPath(path)
        if self._display_text and self.text():
            painter.setPen(QColor(INK))
            painter.setFont(self.font())
            safe_left = slant + 6.0 if self._extend_left else 6.0
            safe_right = slant + 6.0 if self._cut_right else 6.0
            safe_rect = QRectF(
                safe_left,
                0.0,
                max(1.0, surface_width - safe_left - safe_right),
                surface_height,
            )
            painter.drawText(safe_rect, Qt.AlignCenter | Qt.TextWordWrap, self.text())
        painter.end()


class LeftExtendedActionButton(QPushButton):
    """Rounded button that preserves its base rectangle and adds a left wedge."""

    def __init__(
        self,
        text: str,
        *,
        fill: str,
        accent: str,
        angle_degrees: float,
        radius: int,
        lifted_shadow: LiftedShadowSpec | None = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(text, parent)
        self._fill = QColor(fill)
        self._accent = QColor(accent)
        self._angle_degrees = float(angle_degrees)
        self._radius = max(0, int(radius))
        self._lifted_shadow = lifted_shadow
        self.setCursor(Qt.PointingHandCursor)
        self.setStyleSheet("background: transparent; border: none; padding: 0px;")

    def extensionDepth(self) -> float:
        radius = min(float(self._radius), self.width() / 2.0, self.height() / 2.0)
        vertical_run = max(0.0, float(self.height()) - (2.0 * radius))
        requested = vertical_run / max(0.01, abs(math.tan(math.radians(self._angle_degrees))))
        return min(requested, max(0.0, float(self.width()) - (2.0 * radius)))

    def _surface_path(self, width: float, height: float) -> QPainterPath:
        if width <= 0.0 or height <= 0.0:
            return QPainterPath()
        radius = min(float(self._radius), width / 2.0, height / 2.0)
        vertical_run = max(0.0, height - (2.0 * radius))
        requested = vertical_run / max(0.01, abs(math.tan(math.radians(self._angle_degrees))))
        extension = min(requested, max(0.0, width - (2.0 * radius)))
        radius = min(float(self._radius), width / 2.0, height / 2.0)
        return _rounded_polygon_path(
            [
                QPointF(extension, 0.0),
                QPointF(width, 0.0),
                QPointF(width, height),
                QPointF(0.0, height),
            ],
            radius,
        )

    def surfacePath(self) -> QPainterPath:
        return self._surface_path(float(self.width()), float(self.height()))

    def hitButton(self, pos: QPoint) -> bool:
        return self.surfacePath().contains(QPointF(pos))

    def paintEvent(self, event) -> None:
        inset = max(0.0, float(self._lifted_shadow.inset)) if self._lifted_shadow is not None else 0.0
        surface_width = max(1.0, float(self.width()) - inset)
        surface_height = max(1.0, float(self.height()) - inset)
        path = self._surface_path(surface_width, surface_height)
        if path.isEmpty():
            return
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        _paint_lifted_shadow(painter, path, self._lifted_shadow)
        fill = QColor(self._fill)
        if not self.isEnabled():
            fill = fill.darker(138)
        elif self.isDown():
            fill = fill.darker(112)
        elif self.underMouse():
            fill = fill.lighter(108)
        painter.setPen(Qt.NoPen)
        painter.setBrush(fill)
        painter.drawPath(path)
        if self.hasFocus():
            painter.setPen(QPen(self._accent, 2.0))
            painter.setBrush(Qt.NoBrush)
            painter.drawPath(path)
        radius = min(float(self._radius), surface_width / 2.0, surface_height / 2.0)
        vertical_run = max(0.0, surface_height - (2.0 * radius))
        extension = min(
            vertical_run / max(0.01, abs(math.tan(math.radians(self._angle_degrees)))),
            max(0.0, surface_width - (2.0 * radius)),
        )
        text_rect = QRectF(extension, 0.0, max(1.0, surface_width - extension), surface_height)
        painter.setPen(QColor(INK if self.isEnabled() else MUTED))
        painter.setFont(self.font())
        painter.drawText(text_rect, Qt.AlignCenter, self.text())
        painter.end()


class DiagonalLineEdit(QLineEdit):
    """Native line edit painted on a rounded surface with a cut right edge."""

    def __init__(
        self,
        *,
        fill: str,
        border: str,
        accent: str,
        angle_degrees: float,
        radius: int,
        lifted_shadow: LiftedShadowSpec | None = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._fill = QColor(fill)
        self._border = QColor(border)
        self._accent = QColor(accent)
        self._angle_degrees = float(angle_degrees)
        self._radius = max(0, int(radius))
        self._lifted_shadow = lifted_shadow
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setStyleSheet(
            f"QLineEdit {{ background: transparent; border: none; color: {INK}; "
            f"padding: 7px 18px 7px 10px; selection-background-color: {ACCENT}; }}"
        )

    def cutDepth(self, width: float | None = None, height: float | None = None) -> float:
        resolved_width = float(self.width()) if width is None else max(0.0, float(width))
        resolved_height = float(self.height()) if height is None else max(0.0, float(height))
        requested = resolved_height / max(0.01, abs(math.tan(math.radians(self._angle_degrees))))
        return min(requested, resolved_width * 0.24, resolved_height * 0.48)

    def _shape_path(self, width: float, height: float) -> QPainterPath:
        cut = self.cutDepth(width, height)
        return _rounded_polygon_path(
            [
                QPointF(0.5, 0.5),
                QPointF(width, 0.5),
                QPointF(width - cut, height),
                QPointF(0.5, height),
            ],
            min(float(self._radius), width / 2.0, height / 2.0),
        )

    def surfacePath(self) -> QPainterPath:
        inset = max(0.0, float(self._lifted_shadow.inset)) if self._lifted_shadow is not None else 0.0
        width = max(1.0, float(self.width()) - 1.0 - inset)
        height = max(1.0, float(self.height()) - 1.0 - inset)
        return self._shape_path(width, height)

    def interactionPath(self) -> QPainterPath:
        """Preserve the pre-shadow hit area while the painted surface reserves an inset."""

        return self._shape_path(max(1.0, float(self.width()) - 1.0), max(1.0, float(self.height()) - 1.0))

    def mousePressEvent(self, event) -> None:
        if not self.interactionPath().contains(event.position()):
            event.ignore()
            return
        super().mousePressEvent(event)

    def paintEvent(self, event) -> None:
        path = self.surfacePath()
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        _paint_lifted_shadow(painter, path, self._lifted_shadow)
        fill = QColor(self._fill)
        if not self.isEnabled():
            fill = fill.darker(125)
        painter.setPen(QPen(self._accent if self.hasFocus() else self._border, 1.5 if self.hasFocus() else 1.0))
        painter.setBrush(fill)
        painter.drawPath(path)
        painter.end()
        super().paintEvent(event)


class DiagonalMenuComboBox(QComboBox):
    """Native combo behavior with a bilateral diagonal closed surface."""

    def __init__(
        self,
        *,
        fill: str,
        accent: str,
        angle_degrees: float,
        radius: int,
        triangle_texture: TriangleTextureConfig | None = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._fill = QColor(fill)
        self._accent = QColor(accent)
        self._angle_degrees = float(angle_degrees)
        self._radius = max(0, int(radius))
        self._extend_left = True
        self._triangle_texture = triangle_texture.normalized() if triangle_texture is not None else None
        self.setMinimumHeight(54)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setCursor(Qt.PointingHandCursor)
        self.setStyleSheet("QComboBox { background: transparent; border: none; padding: 0px; }")
        self.view().setStyleSheet(
            f"QAbstractItemView {{ background: {SURFACE_ALT}; color: {INK}; border: 1px solid {BORDER}; "
            "outline: none; padding: 4px; } "
            f"QAbstractItemView::item {{ min-height: 34px; padding: 4px 10px; }} "
            f"QAbstractItemView::item:selected {{ background: {ACCENT_SOFT}; color: {INK}; }}"
        )

    def _diagonal_slant(self) -> float:
        width = float(self.width())
        height = float(self.height())
        requested = height / max(0.01, math.tan(math.radians(self._angle_degrees)))
        return min(requested, width * 0.24, height * 0.48)

    def surfacePath(self) -> QPainterPath:
        width = float(self.width())
        height = float(self.height())
        if width <= 0.0 or height <= 0.0:
            return QPainterPath()
        slant = self._diagonal_slant()
        return _rounded_polygon_path(
            [
                QPointF(slant, 0.0),
                QPointF(width, 0.0),
                QPointF(width - slant, height),
                QPointF(0.0, height),
            ],
            min(float(self._radius), width / 2.0, height / 2.0),
        )

    def mousePressEvent(self, event) -> None:
        if not self.surfacePath().contains(event.position()):
            event.ignore()
            return
        super().mousePressEvent(event)

    def paintEvent(self, event) -> None:
        path = self.surfacePath()
        if path.isEmpty():
            return
        width = float(self.width())
        height = float(self.height())
        slant = self._diagonal_slant()
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.setPen(Qt.NoPen)
        if self._triangle_texture is None:
            painter.fillPath(path, self._fill)
        else:
            config = replace(self._triangle_texture, triangle_size=max(6.0, height * 0.80))
            texture = QPixmap(self.size())
            texture.fill(Qt.transparent)
            texture_painter = QPainter(texture)
            paint_triangle_texture(texture_painter, QRectF(texture.rect()), config)
            texture_painter.end()
            painter.save()
            painter.setClipPath(path)
            painter.drawPixmap(0, 0, texture)
            painter.restore()
        if not self.isEnabled():
            painter.fillPath(path, QColor(0, 0, 0, 120))
        elif self.underMouse():
            painter.fillPath(path, QColor(255, 255, 255, 20))
        if self.hasFocus():
            focus_pen = QPen(self._accent)
            focus_pen.setWidthF(2.0)
            painter.setPen(focus_pen)
            painter.setBrush(Qt.NoBrush)
            painter.drawPath(path)

        safe_left = slant + 12.0
        arrow_space = slant + 30.0
        text_rect = QRectF(safe_left, 0.0, max(1.0, width - safe_left - arrow_space), height)
        painter.setPen(QColor(INK))
        painter.setFont(self.font())
        display_text = self.fontMetrics().elidedText(self.currentText(), Qt.ElideRight, round(text_rect.width()))
        painter.drawText(text_rect, Qt.AlignLeft | Qt.AlignVCenter, display_text)

        arrow_x = max(safe_left + 8.0, width - slant - 18.0)
        arrow_y = height * 0.5
        arrow = QPainterPath()
        arrow.moveTo(arrow_x - 5.0, arrow_y - 2.5)
        arrow.lineTo(arrow_x + 5.0, arrow_y - 2.5)
        arrow.lineTo(arrow_x, arrow_y + 3.5)
        arrow.closeSubpath()
        painter.setPen(Qt.NoPen)
        painter.setBrush(self._accent)
        painter.drawPath(arrow)
        painter.end()


class HomeMenuButtonRow(QWidget):
    """Lay out one equal-width row with a constant visible diagonal seam gap."""

    def __init__(
        self,
        buttons: list[ParallelogramActionButton],
        *,
        seam_gap: int,
        angle_degrees: float,
        radius: int,
        full_height_slant: bool = False,
        width_weights: list[float] | None = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._buttons = buttons
        self._seam_gap = max(0, int(seam_gap))
        self._angle_degrees = float(angle_degrees)
        self._radius = max(0, int(radius))
        self._full_height_slant = bool(full_height_slant)
        if width_weights is not None and len(width_weights) != len(buttons):
            raise ValueError("button width weights must match the button count")
        self._width_weights = [max(0.01, float(weight)) for weight in width_weights] if width_weights else None
        self.setMinimumHeight(max((button.minimumHeight() for button in buttons), default=0))
        for button in buttons:
            button.setParent(self)

    def diagonalSlant(self) -> float:
        width = float(self.width())
        height = float(self.height())
        if width <= 0.0 or height <= 0.0:
            return 0.0
        radius = min(float(self._radius), width / 2.0, height / 2.0)
        requested = (
            height / max(0.01, math.tan(math.radians(self._angle_degrees)))
            if self._full_height_slant
            else _diagonal_depth(height, radius, self._angle_degrees)
        )
        return min(requested, width * 0.24, height * 0.48)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        count = len(self._buttons)
        width = float(self.width())
        height = float(self.height())
        if count == 0 or width <= 0.0 or height <= 0.0:
            return
        slant = self.diagonalSlant()
        total_button_width = width + ((count - 1) * (slant - self._seam_gap))
        weights = self._width_weights or [1.0] * count
        weight_total = sum(weights)
        button_widths = [total_button_width * weight / weight_total for weight in weights]
        left = 0.0
        for index, button in enumerate(self._buttons):
            button_width = button_widths[index]
            rounded_left = round(left)
            right = round(left + button_width)
            if index == count - 1:
                right = self.width()
            button.setGeometry(rounded_left, 0, max(1, right - rounded_left), self.height())
            left += button_width - slant + self._seam_gap


class DiagonalComponentControlSlot(QWidget):
    """Project one layout-positioned control across a bilateral parent surface."""

    def __init__(
        self,
        surface: HomeGlassSection,
        control: QWidget,
        *,
        left_clearance: int,
        right_clearance: int,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent or surface)
        self._surface = surface
        self._control = control
        self._left_clearance = max(0, int(left_clearance))
        self._right_clearance = max(0, int(right_clearance))
        self._last_endpoints = (0.0, 0.0, 0.0, 0.0)
        self.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setFixedHeight(max(1, control.minimumHeight(), control.sizeHint().height()))
        control.setParent(surface)
        control.show()
        QTimer.singleShot(0, self.syncControlGeometry)

    def control(self) -> QWidget:
        return self._control

    def boundaryEndpoints(self) -> tuple[float, float, float, float]:
        return self._last_endpoints

    def syncControlGeometry(self) -> None:
        try:
            if self.height() <= 0 or self._surface.width() <= 0:
                return
            top_y = float(self.mapTo(self._surface, QPoint(0, 0)).y())
            bottom_y = top_y + float(self.height())
            left_top = self._surface.leftEdgeXAt(top_y) + self._left_clearance
            left_bottom = self._surface.leftEdgeXAt(bottom_y) + self._left_clearance
            right_top = self._surface.rightEdgeXAt(top_y) - self._right_clearance
            right_bottom = self._surface.rightEdgeXAt(bottom_y) - self._right_clearance
            control_left = round(left_bottom)
            control_right = round(right_top)
            self._control.setGeometry(
                control_left,
                round(top_y),
                max(1, control_right - control_left),
                self.height(),
            )
            self._control.raise_()
            self._last_endpoints = (left_top, left_bottom, right_top, right_bottom)
        except RuntimeError:
            # A queued initial projection may run after UCS hot-refresh tears
            # down its isolated gallery sample.
            return

    def moveEvent(self, event) -> None:
        super().moveEvent(event)
        self.syncControlGeometry()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self.syncControlGeometry()

    def showEvent(self, event) -> None:
        super().showEvent(event)
        self.syncControlGeometry()


class HomeMenuRowsWidget(QWidget):
    """Give each row the section width available at that row's starting Y."""

    def __init__(
        self,
        section: HomeGlassSection,
        rows: list[HomeMenuButtonRow],
        *,
        row_gap: int,
    ) -> None:
        super().__init__(section)
        self._section = section
        self._rows = rows
        self._row_gap = max(0, int(row_gap))
        for row in rows:
            row.setParent(self)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        count = len(self._rows)
        if count == 0:
            return
        usable_height = max(0.0, float(self.height() - ((count - 1) * self._row_gap)))
        row_height = usable_height / count
        for index, row in enumerate(self._rows):
            top = round(index * (row_height + self._row_gap))
            bottom = round(top + row_height)
            section_y = float(self.y() + top)
            boundary_inset = max(0.0, float(self._section.width()) - self._section.rightEdgeXAt(section_y))
            row_width = max(1, round(float(self.width()) - boundary_inset))
            row.setGeometry(0, top, row_width, max(1, bottom - top))


class HomeSettingsMenuRowsWidget(QWidget):
    """Lay out settings surfaces as stepped rows following the section cut."""

    def __init__(
        self,
        section: HomeGlassSection,
        rows: list[HomeGlassSection],
        *,
        row_heights: list[int],
        row_gap: int,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        if len(rows) != len(row_heights):
            raise ValueError("settings rows and heights must have the same length")
        self._section = section
        self._rows = rows
        self._row_heights = [max(1, int(height)) for height in row_heights]
        self._row_gap = max(0, int(row_gap))
        self.setMinimumHeight(sum(self._row_heights) + self._row_gap * max(0, len(rows) - 1))
        for row in rows:
            row.setParent(self)
            row.show()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        top = 0
        for row, row_height in zip(self._rows, self._row_heights):
            section_y = float(self.mapTo(self._section, QPoint(0, top)).y())
            row_bottom_y = section_y + float(row_height)
            left_boundary_inset = max(0.0, self._section.leftEdgeXAt(row_bottom_y))
            right_boundary_inset = max(
                0.0,
                float(self._section.width()) - self._section.rightEdgeXAt(section_y),
            )
            row_left = round(left_boundary_inset)
            row_right = round(float(self.width()) - right_boundary_inset)
            row.setGeometry(row_left, top, max(1, row_right - row_left), row_height)
            top += row_height + self._row_gap


class HomeDashboardWidget(QWidget):
    """Own the three Home slots and interlock the menu and center bevels."""

    def __init__(self, *, ui_scale: float, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._ui_scale = float(ui_scale)
        self._hosts: tuple[HomeSectionHost, HomeSectionHost, HomeSectionHost] | None = None
        self._seam_gap = scale_px(HOME_SECTION_SEAM_GAP, self._ui_scale)
        self._radius = scale_px(7, self._ui_scale)
        self._center_dock = "menu"

    def setHosts(
        self,
        menu: HomeSectionHost,
        center: HomeSectionHost,
        right: HomeSectionHost,
    ) -> None:
        self._hosts = (menu, center, right)
        for host in self._hosts:
            host.setParent(self)
            host.show()
        self._sync_host_geometry()

    def seamGap(self) -> int:
        return self._seam_gap

    def setCenterDock(self, dock: str) -> None:
        resolved = "right" if str(dock) == "right" else "menu"
        if self._center_dock == resolved:
            return
        self._center_dock = resolved
        self._sync_host_geometry()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._sync_host_geometry()

    def _sync_host_geometry(self) -> None:
        if self._hosts is None:
            return
        menu, center, right = self._hosts
        width = max(1, self.width())
        height = max(1, self.height())
        section_width = max(1, round(width * 0.30))
        tangent = abs(math.tan(math.radians(HOME_DIAGONAL_ANGLE)))
        # The menu's rounded right bevel runs from y=radius to y=h-radius.
        # Shift the center slot left so the settings left bevel stays one
        # established menu gap away throughout that shared straight interval.
        seam_overlap = max(0.0, (height - float(self._radius)) / max(0.01, tangent))
        right_x = max(0, width - section_width)
        if self._center_dock == "right":
            # Item/resource panels mate with the Scan panel, so solve the
            # center origin from the fixed right slot instead of the menu.
            full_overlap = height / max(0.01, tangent)
            center_x = max(0, round(right_x - section_width + full_overlap - self._seam_gap))
        else:
            center_x = max(0, round(section_width - seam_overlap + self._seam_gap))
        menu.setGeometry(0, 0, section_width, height)
        center.setGeometry(center_x, 0, section_width, height)
        right.setGeometry(right_x, 0, min(section_width, width - right_x), height)
        menu.raise_()
        center.raise_()
        right.raise_()


class HomeElidedLabel(QLabel):
    """Single-line label that preserves its full text outside the painted copy."""

    def __init__(self, text: str, parent: QWidget | None = None) -> None:
        super().__init__(str(text), parent)
        self._full_text = ""
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        self.setFullText(text)

    def setFullText(self, text: str) -> None:
        self._full_text = str(text)
        self.setToolTip(self._full_text)
        self.setAccessibleName(self._full_text)
        self._sync_elided_text()

    def _sync_elided_text(self) -> None:
        available = max(1, self.width())
        elided = self.fontMetrics().elidedText(self._full_text, Qt.ElideRight, available)
        if self.text() != elided:
            super().setText(elided)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._sync_elided_text()


class HomeWindowTitleLabel(HomeElidedLabel):
    """Elided window title used inside a candidate row."""


class HomeConnectionLayout(QVBoxLayout):
    """Keep full-width controls evenly inset from both section edges."""

    def __init__(self, parent: QWidget, *, left_inset: int) -> None:
        super().__init__(parent)
        self._left_inset = max(0, int(left_inset))
        self._full_bleed_targets: list[QWidget | QLayout] = []

    def markFullBleed(self, target: QWidget | QLayout) -> None:
        self._full_bleed_targets.append(target)

    def setGeometry(self, rect: QRect) -> None:
        super().setGeometry(rect)
        for index in range(self.count()):
            item = self.itemAt(index)
            if item.widget() not in self._full_bleed_targets and item.layout() not in self._full_bleed_targets:
                continue
            geometry = item.geometry()
            item.setGeometry(
                QRect(
                    self._left_inset,
                    geometry.y(),
                    max(1, geometry.right() + 1 - self._left_inset),
                    geometry.height(),
                )
            )


class HomeWindowCandidateRow(QWidget):
    def __init__(self, *, title: str, size: str, likely_ba: bool, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        badge = QLabel("BA" if likely_ba else "")
        badge.setFixedWidth(24)
        badge.setAlignment(Qt.AlignCenter)
        badge.setStyleSheet(f"color: {'#3dbf7a' if likely_ba else MUTED}; font-weight: 800;")
        layout.addWidget(badge)
        title_label = HomeWindowTitleLabel(title)
        title_label.setStyleSheet(f"color: {'#b9f1d0' if likely_ba else INK}; font-weight: 700;")
        layout.addWidget(title_label, 1)
        size_label = QLabel(size or "—")
        size_label.setObjectName("count")
        size_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        size_label.setMinimumWidth(72)
        layout.addWidget(size_label)


class HomeSectionHost(QWidget):
    """Stable slot that animates sibling sections without layout interference."""

    PULL_MS = 120
    EXIT_MS = 300
    ENTER_MS = 360
    SETTLE_MS = 190

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._pages: list[QWidget] = []
        self._current: QWidget | None = None
        self._animation: QSequentialAnimationGroup | None = None
        self._animation_overlays: list[QLabel] = []

    def addPage(self, page: QWidget, *, initial: bool = False) -> QWidget:
        page.setParent(self)
        page.hide()
        self._pages.append(page)
        if initial:
            if self._current is not None:
                self._current.hide()
            self._current = page
            page.setGeometry(self.rect())
            page.show()
            self._sync_shape_mask()
        return page

    def currentPage(self) -> QWidget | None:
        return self._current

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        if self._animation is None and self._current is not None:
            self._current.setGeometry(self.rect())
        self._sync_shape_mask()

    def _sync_shape_mask(self) -> None:
        page = self._current
        if page is None:
            self.setMask(QRegion())
            return
        shape_builder = getattr(page, "_shape_path", None)
        if not callable(shape_builder):
            self.clearMask()
            return
        path = shape_builder(float(self.width()), float(self.height()))
        region = QRegion(path.toFillPolygon().toPolygon())
        # Leave one device pixel around the structural region so the host mask
        # never trims the painter's antialias fringe.
        padded = QRegion(region)
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            padded = padded.united(region.translated(dx, dy))
        self.setMask(padded)

    def _drop_animation_overlay(self, overlay: QLabel | None) -> None:
        if overlay is None:
            return
        if overlay in self._animation_overlays:
            self._animation_overlays.remove(overlay)
        overlay.deleteLater()

    def _clear_animation_overlays(self) -> None:
        for overlay in self._animation_overlays:
            overlay.deleteLater()
        self._animation_overlays.clear()

    def _snapshot_overlay(self, page: QWidget, local_position: QPoint) -> QLabel | None:
        parent = self.parentWidget()
        if parent is None:
            return None
        page.ensurePolished()
        pixmap = page.grab()
        overlay = QLabel(parent)
        overlay.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        overlay.setAttribute(Qt.WA_TranslucentBackground, True)
        overlay.setPixmap(pixmap)
        overlay.resize(pixmap.size())
        overlay.move(self.mapTo(parent, QPoint(0, 0)) + local_position)
        overlay.show()
        overlay.raise_()
        self._animation_overlays.append(overlay)
        return overlay

    def _offset(self, angle_degrees: float) -> QPoint:
        angle = math.radians(float(angle_degrees) % 360.0)
        unit_x = math.cos(angle)
        # Home motion uses mathematical angles projected onto the monitor:
        # 0=right, 90=up, 180=left, 270=down. Qt's positive Y is downward,
        # so the mathematical Y component must be inverted.
        unit_y = -math.sin(angle)
        clear_width = max(self.width(), 1) + 40
        clear_height = max(self.height(), 1) + 40
        distances: list[float] = []
        if abs(unit_x) > 1e-6:
            distances.append(clear_width / abs(unit_x))
        if abs(unit_y) > 1e-6:
            distances.append(clear_height / abs(unit_y))
        distance = min(distances) if distances else float(clear_height)
        return QPoint(round(unit_x * distance), round(unit_y * distance))

    def stopTransition(self) -> None:
        if self._animation is not None:
            self._animation.stop()
            self._animation = None
        self._clear_animation_overlays()
        for page in self._pages:
            if page is self._current:
                page.setGeometry(self.rect())
                page.show()
            else:
                page.hide()
        self._sync_shape_mask()

    def clear(self) -> None:
        self.stopTransition()
        if self._current is not None:
            self._current.hide()
        self._current = None
        self._sync_shape_mask()

    def transitionTo(
        self,
        incoming: QWidget | None,
        *,
        intro: float = 0.0,
        outro: float = 0.0,
        midpoint: Callable[[], None] | None = None,
    ) -> None:
        if incoming is self._current and midpoint is None:
            return
        self.stopTransition()
        outgoing = self._current
        origin = QPoint(0, 0)
        host_origin = self.mapTo(self.parentWidget(), origin) if self.parentWidget() is not None else origin

        outgoing_overlay = self._snapshot_overlay(outgoing, origin) if outgoing is not None else None
        if outgoing_overlay is not None and outgoing is not None:
            outgoing.hide()

        def reveal() -> None:
            self._drop_animation_overlay(outgoing_overlay)
            if outgoing is not None:
                outgoing.hide()
                outgoing.move(origin)
            if midpoint is not None:
                midpoint()
            self._current = incoming
            if incoming is None:
                self._animation = None
                self._sync_shape_mask()
                return
            incoming.setGeometry(self.rect())
            # On Home section hosts, angle values describe actual movement.
            # Intro 0 therefore starts left of the origin and travels right.
            start = origin - self._offset(intro)
            cruise_end = origin + QPoint(int(start.x() * 0.16), int(start.y() * 0.16))
            incoming_overlay = self._snapshot_overlay(incoming, start)
            animation_target: QWidget = incoming_overlay or incoming
            animation_origin = host_origin if incoming_overlay is not None else origin
            if incoming_overlay is not None:
                incoming.hide()
            else:
                incoming.move(start)
                incoming.show()
                incoming.raise_()

            cruise = QPropertyAnimation(animation_target, b"pos")
            cruise.setDuration(self.ENTER_MS)
            cruise.setStartValue(animation_origin + start)
            cruise.setEndValue(animation_origin + cruise_end)
            cruise.setEasingCurve(QEasingCurve.Linear)
            settle = QPropertyAnimation(animation_target, b"pos")
            settle.setDuration(self.SETTLE_MS)
            settle.setStartValue(animation_origin + cruise_end)
            settle.setEndValue(animation_origin)
            settle.setEasingCurve(QEasingCurve.OutCubic)
            entrance_group = QSequentialAnimationGroup(self)
            entrance_group.addAnimation(cruise)
            entrance_group.addAnimation(settle)

            def finish_entrance() -> None:
                self._drop_animation_overlay(incoming_overlay)
                incoming.move(origin)
                incoming.show()
                incoming.raise_()
                self._animation = None
                self._sync_shape_mask()

            entrance_group.finished.connect(finish_entrance)
            self._animation = entrance_group
            entrance_group.start()

        if outgoing is None:
            reveal()
            return

        pull_offset = self._offset(outro)
        pull_target = origin - QPoint(int(pull_offset.x() * 0.055), int(pull_offset.y() * 0.055))
        exit_target = origin + pull_offset
        animation_target: QWidget = outgoing_overlay or outgoing
        animation_origin = host_origin if outgoing_overlay is not None else origin
        pull = QPropertyAnimation(animation_target, b"pos")
        pull.setDuration(self.PULL_MS)
        pull.setStartValue(animation_origin)
        pull.setEndValue(animation_origin + pull_target)
        pull.setEasingCurve(QEasingCurve.OutCubic)
        exit_animation = QPropertyAnimation(animation_target, b"pos")
        exit_animation.setDuration(self.EXIT_MS)
        exit_animation.setStartValue(animation_origin + pull_target)
        exit_animation.setEndValue(animation_origin + exit_target)
        exit_animation.setEasingCurve(QEasingCurve.InCubic)
        group = QSequentialAnimationGroup(self)
        group.addAnimation(pull)
        group.addAnimation(exit_animation)
        group.finished.connect(reveal)
        self._animation = group
        group.start()

    def refreshCurrent(
        self,
        callback: Callable[[], None],
        *,
        intro: float = 0.0,
        outro: float = 180.0,
    ) -> None:
        current = self._current
        if current is None:
            callback()
            return
        self.transitionTo(current, intro=intro, outro=outro, midpoint=callback)


class HomeTabComponent:
    _HOME_GLASS = _alpha_hex(_mix_hex(BG, PALETTE_PANEL_ALT, 0.64), 0.78)

    def _build_home_tab(self, root: QWidget) -> None:
        root_layout = QVBoxLayout(root)
        root_layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        root_layout.setSpacing(scale_px(14, self._ui_scale))

        self._home_root_stack = QStackedWidget()
        root_layout.addWidget(self._home_root_stack, 1)

        dashboard = HomeDashboardWidget(ui_scale=self._ui_scale)
        dashboard.setObjectName("homeDashboard")

        self._home_menu_host = HomeSectionHost(dashboard)
        self._home_center_host = HomeSectionHost(dashboard)
        self._home_right_host = HomeSectionHost(dashboard)
        self._home_connected: bool | None = None
        self._home_ready = False
        dashboard.setHosts(self._home_menu_host, self._home_center_host, self._home_right_host)
        self._home_dashboard_widget = dashboard
        self._home_root_stack.addWidget(dashboard)
        self._home_dashboard_page = dashboard

        self._home_menu_section = self._build_home_menu_section()
        self._home_menu_host.addPage(self._home_menu_section, initial=True)
        self._home_connection_panel = self._build_home_connection_panel()
        self._home_scan_panel = self._build_home_scan_panel()
        self._home_settings_panel = self._build_home_settings_panel()
        self._home_right_host.addPage(self._home_connection_panel)
        self._home_right_host.addPage(self._home_scan_panel)
        self._home_item_panel = self._build_home_item_panel()
        self._home_resource_panel = self._build_home_resource_panel()
        self._home_center_host.addPage(self._home_item_panel)
        self._home_center_host.addPage(self._home_resource_panel)
        self._home_center_host.addPage(self._home_settings_panel)
        self._home_center_motion_by_page = {
            self._home_settings_panel: HOME_PANEL_MOTION["settings"],
            self._home_item_panel: HOME_PANEL_MOTION["items"],
            self._home_resource_panel: HOME_PANEL_MOTION["resources"],
        }

        scan_workspace = QWidget()
        self._build_scan_tab(scan_workspace)
        self._home_scan_workspace_page = scan_workspace
        self._home_root_stack.addWidget(scan_workspace)

        # Keep the original scan header as the Home tab's persistent header.
        # Only the page body changes between dashboard and scan progress.
        scan_layout = scan_workspace.layout()
        if scan_layout is not None and self._scan_header_section is not None:
            scan_layout.removeWidget(self._scan_header_section)
            self._scan_header_section.setParent(root)
            root_layout.insertWidget(0, self._scan_header_section, 0)

        self._home_connection_timer = QTimer(self)
        self._home_connection_timer.setInterval(1000)
        self._home_connection_timer.timeout.connect(self._sync_settings_labels)
        self._home_connection_timer.start()
        self._home_ready = True
        self._home_connected = None
        QTimer.singleShot(0, self._sync_settings_labels)

    def _show_home_scan_layout_preview(self, mode: str, *, animate: bool = True) -> None:
        self._reset_scan_result_transition()
        if mode == "inventory":
            self._reset_scan_inventory_card(
                "디버그",
                "그리드 스캔 레이아웃 미리보기",
                5,
                4,
            )
            self._set_plana_message(
                "그리드 스캔용 섹션을 미리 보고 있습니다.",
                "UI Component Studio /q",
            )
        else:
            self._reset_scan_student_card(meta="학생 스캔 레이아웃 미리보기")
            self._set_plana_message(
                "학생 스캔용 섹션을 미리 보고 있습니다.",
                "UI Component Studio /w",
            )
        if self._home_root_stack.currentWidget() is self._home_scan_workspace_page:
            return
        self._home_root_stack.setCurrentWidget(self._home_scan_workspace_page)
        if animate:
            self._animate_home_scan_workspace_in()

    def _home_section_layout(self, section: HomeGlassSection, *, extended: bool = False) -> QVBoxLayout:
        layout = QVBoxLayout(section)
        base_margins = (
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(30, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        if extended:
            section.setBaseContentMargins(*base_margins)
        else:
            layout.setContentsMargins(*base_margins)
        layout.setSpacing(scale_px(10, self._ui_scale))
        return layout

    def _build_home_menu_section(self) -> HomeGlassSection:
        menu_shadow = LiftedShadowSpec(
            color=SHADOW,
            offset_x=float(scale_px(2, self._ui_scale)),
            offset_y=float(scale_px(2, self._ui_scale)),
            inset=float(scale_px(3, self._ui_scale)),
            layers=4,
            max_alpha=0.22,
        )
        self._home_menu_shadow = menu_shadow
        section = HomeGlassSection(
            fill=self._HOME_GLASS,
            radius=scale_px(7, self._ui_scale),
            cut_right=True,
            lifted_shadow=menu_shadow,
        )
        section.setObjectName("homeMenuSection")
        layout = self._home_section_layout(section)

        menu_gap = scale_px(10, self._ui_scale)
        corner_radius = scale_px(7, self._ui_scale)

        self._home_primary_button = ParallelogramActionButton(
            "싯딤의 상자와 연결",
            fill=_mix_hex(PALETTE_ACCENT, SURFACE_ALT, 0.28),
            accent=ACCENT,
            slant=menu_gap,
            extend_left=False,
            angle_degrees=HOME_DIAGONAL_ANGLE,
            radius=corner_radius,
            texture_path=HOME_MENU_TEXTURES["싯딤의 상자와 연결"],
            display_text=False,
            lifted_shadow=menu_shadow,
            caption_overlay_ratio=HOME_MENU_CAPTION_RATIO,
            caption_text_enabled=True,
            caption_text_color=HOME_MENU_CAPTION_TEXT_COLOR,
            texture_overscan=HOME_MENU_TEXTURE_OVERSCAN,
            show_focus_outline=False,
        )
        self._home_primary_button.clicked.connect(self._home_primary_action)

        menu_entries = (
            ("학생부 확인", lambda: self._home_navigate_main(getattr(self, "_students_tab", None)), 1, 0),
            ("계획 설정", lambda: self._home_navigate_main(getattr(self, "_plan_tab", None)), 1, 1),
            ("인벤토리", lambda: self._home_navigate_main(getattr(self, "_inventory_tab", None)), 1, 2),
            ("전술대항전", lambda: self._home_navigate_main(getattr(self, "_tactical_tab", None)), 2, 0),
            ("통계", lambda: self._home_show_pending_feature("통계"), 2, 1),
            ("설정", self._home_show_settings, 3, 0),
        )
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
        self._home_menu_buttons: list[ParallelogramActionButton] = []
        self._home_menu_buttons_by_name: dict[str, ParallelogramActionButton] = {}
        row_buttons: list[list[ParallelogramActionButton]] = [[self._home_primary_button], [], [], []]
        for label, callback, row, position in menu_entries:
            button = ParallelogramActionButton(
                label,
                fill=_mix_hex(SURFACE, PALETTE_PANEL_ALT, 0.32),
                accent=ACCENT,
                slant=menu_gap,
                extend_left=position > 0,
                angle_degrees=HOME_DIAGONAL_ANGLE,
                radius=corner_radius,
                texture_path=HOME_MENU_TEXTURES.get(label),
                triangle_texture=settings_texture if label == "설정" else None,
                triangle_visible_ratio=0.52,
                display_text=False,
                lifted_shadow=None if label == "설정" else menu_shadow,
                caption_overlay_ratio=0.0 if label == "설정" else HOME_MENU_CAPTION_RATIO,
                caption_text_enabled=True,
                caption_text_color=(
                    HOME_MENU_SETTINGS_TEXT_COLOR if label == "설정" else HOME_MENU_CAPTION_TEXT_COLOR
                ),
                texture_overscan=HOME_MENU_TEXTURE_OVERSCAN,
                show_focus_outline=False,
                triangle_texture_only=label == "설정",
                state_effects_enabled=label != "설정",
            )
            button.clicked.connect(callback)
            self._home_menu_buttons.append(button)
            self._home_menu_buttons_by_name[label] = button
            row_buttons[row].append(button)

        self._home_menu_rows = [
            HomeMenuButtonRow(
                buttons,
                seam_gap=menu_gap,
                angle_degrees=HOME_DIAGONAL_ANGLE,
                radius=corner_radius,
            )
            for buttons in row_buttons
        ]
        self._home_menu_rows_widget = HomeMenuRowsWidget(
            section,
            self._home_menu_rows,
            row_gap=menu_gap,
        )
        layout.addWidget(self._home_menu_rows_widget, 1)
        return section

    def _build_home_connection_panel(self) -> HomeGlassSection:
        connection_shadow = LiftedShadowSpec(
            color=SHADOW,
            offset_x=float(scale_px(2, self._ui_scale)),
            offset_y=float(scale_px(2, self._ui_scale)),
            inset=float(scale_px(3, self._ui_scale)),
            layers=4,
            max_alpha=0.2,
        )
        section = HomeGlassSection(
            fill=self._HOME_GLASS,
            radius=scale_px(7, self._ui_scale),
            extend_left=scale_px(30, self._ui_scale),
            lifted_shadow=connection_shadow,
            round_extension_corners=True,
        )
        section.setObjectName("homeConnectionSection")
        layout = HomeConnectionLayout(section, left_inset=scale_px(30, self._ui_scale))
        section.setBaseContentMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(30, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        layout.setSpacing(scale_px(10, self._ui_scale))
        title = QLabel("싯딤의 상자와 연결")
        title.setObjectName("title")
        layout.addWidget(title)
        self._home_connection_status_label = QLabel("Blue Archive 창을 선택해 주세요.")
        self._home_connection_status_label.setObjectName("count")
        self._home_connection_status_label.setWordWrap(True)
        layout.addWidget(self._home_connection_status_label)
        self._home_window_selection_label = HomeElidedLabel("현재 선택: 없음")
        self._home_window_selection_label.setObjectName("filterSummary")
        layout.addWidget(self._home_window_selection_label)
        row_fill = _alpha_hex(_mix_hex(SURFACE, PALETTE_PANEL_ALT, 0.36), 0.92)
        selected_fill = _alpha_hex(_mix_hex(PALETTE_ACCENT, SURFACE_ALT, 0.34), 0.96)
        row_texture = _home_candidate_triangle_texture(row_fill)
        self._home_window_list = DiagonalScrollList(
            edge="left",
            mode="extend",
            angle_degrees=HOME_DIAGONAL_ANGLE,
            maximum_depth=scale_px(24, self._ui_scale),
            lock_angle=True,
            radius=scale_px(7, self._ui_scale),
            row_fill=row_fill,
            selected_fill=selected_fill,
            rail_color=_alpha_hex(PALETTE_PANEL_ALT, 0.72),
            handle_color=ACCENT_SOFT,
            handle_border_color=ACCENT,
            row_height=scale_px(58, self._ui_scale),
            row_gap=scale_px(7, self._ui_scale),
            content_padding=scale_px(7, self._ui_scale),
            row_triangle_texture=row_texture,
            row_shadow_color=SHADOW,
            row_shadow_offset=float(scale_px(2, self._ui_scale)),
            row_shadow_inset=float(scale_px(3, self._ui_scale)),
            row_shadow_layers=4,
            row_shadow_alpha=0.2,
        )
        self._home_window_list.setObjectName("homeWindowCandidateList")
        self._home_window_list.currentItemChanged.connect(self._sync_home_window_selection)
        self._home_window_list.itemDoubleClicked.connect(self._apply_home_window_candidate)
        layout.addWidget(self._home_window_list, 1)
        layout.markFullBleed(self._home_window_list)

        buttons = QHBoxLayout()
        buttons.setSpacing(scale_px(7, self._ui_scale))
        button_height = scale_px(50, self._ui_scale)
        refresh = LeftExtendedActionButton(
            "새로고침",
            fill=_mix_hex(PALETTE_ACCENT, SURFACE_ALT, 0.24),
            accent=ACCENT,
            angle_degrees=HOME_DIAGONAL_ANGLE,
            radius=scale_px(7, self._ui_scale),
            lifted_shadow=connection_shadow,
        )
        refresh.setMinimumHeight(button_height)
        refresh.setMinimumWidth(scale_px(144, self._ui_scale))
        refresh.setProperty("uiDesignStableSelectorSegment", "QPushButton[0]")
        refresh.clicked.connect(self._refresh_home_window_candidates)
        cancel = QPushButton("취소")
        cancel.setMinimumHeight(button_height)
        cancel.setProperty("uiDesignStableSelectorSegment", "QPushButton[1]")
        self._home_window_cancel_shadow = _apply_lifted_widget_shadow(cancel, connection_shadow)
        cancel.clicked.connect(self._cancel_home_window_selection)
        self._home_window_confirm_button = QPushButton("선택한 창 사용")
        self._home_window_confirm_button.setMinimumHeight(button_height)
        self._home_window_confirm_button.setProperty("uiDesignStableSelectorSegment", "QPushButton[2]")
        self._home_window_confirm_shadow = _apply_lifted_widget_shadow(
            self._home_window_confirm_button,
            connection_shadow,
        )
        self._home_window_confirm_button.setEnabled(False)
        self._home_window_confirm_button.clicked.connect(self._apply_home_window_candidate)
        buttons.addWidget(refresh)
        buttons.addStretch(1)
        buttons.addWidget(cancel)
        buttons.addWidget(self._home_window_confirm_button)
        layout.addLayout(buttons)
        layout.markFullBleed(buttons)
        QTimer.singleShot(0, self._refresh_home_window_candidates)
        return section

    def _refresh_home_window_candidates(self) -> None:
        list_widget = getattr(self, "_home_window_list", None)
        if list_widget is None:
            return
        saved_hwnd, saved_title = self._saved_target()
        self._home_window_selection_label.setFullText(
            f"현재 선택: {saved_title}" if saved_hwnd and saved_title else "현재 선택: 없음"
        )
        list_widget.blockSignals(True)
        try:
            list_widget.clear()
            selected_item: QListWidgetItem | None = None
            for window in get_all_windows():
                title = str(window.get("title") or "")
                hwnd = int(window.get("hwnd") or 0)
                size = str(window.get("size") or "")
                likely_ba = "blue archive" in title.casefold() or "bluearchive" in title.casefold()
                row = HomeWindowCandidateRow(title=title, size=size, likely_ba=likely_ba)
                item = list_widget.addDiagonalWidget(
                    row,
                    data=window,
                    accessible_text=f"{title}, {size}",
                    tooltip=f"{title}\n{size}\nHWND={hwnd}",
                )
                if hwnd == saved_hwnd:
                    selected_item = item
            if selected_item is not None:
                list_widget.setCurrentItem(selected_item)
                selected_item.setSelected(True)
                list_widget.scrollToItem(selected_item, QAbstractItemView.PositionAtCenter)
        finally:
            list_widget.blockSignals(False)
        list_widget.refreshDiagonalGeometry()
        self._sync_home_window_selection()

    def _sync_home_window_selection(self, *_args) -> None:
        list_widget = getattr(self, "_home_window_list", None)
        confirm = getattr(self, "_home_window_confirm_button", None)
        item = list_widget.currentItem() if list_widget is not None else None
        window = item.data(Qt.UserRole) if item is not None else None
        enabled = isinstance(window, dict) and int(window.get("hwnd") or 0) > 0
        if confirm is not None:
            confirm.setEnabled(enabled)
        if enabled:
            title = str(window.get("title") or "")
            saved_hwnd, _saved_title = self._saved_target()
            prefix = "현재 선택" if int(window.get("hwnd") or 0) == saved_hwnd else "선택 예정"
            self._home_window_selection_label.setFullText(f"{prefix}: {title}")

    def _apply_home_window_candidate(self, item=None) -> None:
        list_widget = getattr(self, "_home_window_list", None)
        if list_widget is None:
            return
        if not isinstance(item, QListWidgetItem):
            item = list_widget.currentItem()
        if item is None:
            return
        window = item.data(Qt.UserRole)
        if not isinstance(window, dict):
            return
        hwnd = int(window.get("hwnd") or 0)
        title = str(window.get("title") or "")
        if self._apply_target_window_selection(hwnd, title):
            self._home_window_selection_label.setFullText(f"현재 선택: {title}")

    def _cancel_home_window_selection(self) -> None:
        self._home_right_host.transitionTo(None, intro=0.0, outro=0.0)

    def _build_home_scan_panel(self) -> HomeGlassSection:
        scan_section_shadow = LiftedShadowSpec(
            color=SHADOW,
            offset_x=float(scale_px(2, self._ui_scale)),
            offset_y=float(scale_px(2, self._ui_scale)),
            inset=float(scale_px(3, self._ui_scale)),
            layers=4,
            max_alpha=0.2,
        )
        scan_button_shadow = replace(scan_section_shadow, max_alpha=0.16)
        scan_button_fill = _alpha_hex(_mix_hex(SURFACE, PALETTE_PANEL_ALT, 0.36), 0.92)
        scan_button_texture = _home_candidate_triangle_texture(scan_button_fill, random_seed=9101)
        self._home_scan_section_shadow = scan_section_shadow
        self._home_scan_button_shadow = scan_button_shadow
        section = HomeGlassSection(
            fill=self._HOME_GLASS,
            radius=scale_px(7, self._ui_scale),
            extend_left=scale_px(30, self._ui_scale),
            round_extension_corners=True,
            lifted_shadow=scan_section_shadow,
        )
        section.setObjectName("homeScanSection")
        layout = self._home_section_layout(section, extended=True)
        menu_gap = scale_px(8, self._ui_scale)
        menu_radius = scale_px(7, self._ui_scale)
        title = QLabel("스캔")
        title.setObjectName("title")
        layout.addWidget(title)
        hint = QLabel("스캔할 보유 정보를 선택하세요.")
        hint.setObjectName("count")
        layout.addWidget(hint)
        self._home_scan_control_slots: list[DiagonalComponentControlSlot] = []
        self._home_scan_menu_rows: list[HomeMenuButtonRow] = []

        def scan_button(
            text: str,
            *,
            texture_seed: int,
            cut_right: bool = True,
        ) -> ParallelogramActionButton:
            button = ParallelogramActionButton(
                text,
                fill=scan_button_fill,
                accent=ACCENT,
                slant=menu_gap,
                extend_left=True,
                angle_degrees=HOME_DIAGONAL_ANGLE,
                radius=menu_radius,
                full_height_slant=True,
                cut_right=cut_right,
                triangle_texture=replace(scan_button_texture, random_seed=texture_seed),
                triangle_visible_ratio=1.0,
                triangle_texture_only=True,
                lifted_shadow=scan_button_shadow,
                state_effects_enabled=True,
                reserve_shadow_inset=True,
            )
            button.setFont(_scaled_font(button.font(), 1.2))
            return button

        def add_row(
            *buttons: ParallelogramActionButton,
            height_multiplier: int = 1,
            width_weights: list[float] | None = None,
        ) -> None:
            row = HomeMenuButtonRow(
                list(buttons),
                seam_gap=menu_gap,
                angle_degrees=HOME_DIAGONAL_ANGLE,
                radius=menu_radius,
                full_height_slant=True,
                width_weights=width_weights,
            )
            base_row_height = max(54, scale_px(54, self._ui_scale))
            row.setFixedHeight(base_row_height * max(1, int(height_multiplier)))
            slot = DiagonalComponentControlSlot(
                section,
                row,
                left_clearance=scale_px(18, self._ui_scale),
                right_clearance=scale_px(24, self._ui_scale),
            )
            self._home_scan_menu_rows.append(row)
            self._home_scan_control_slots.append(slot)
            layout.addWidget(slot)

        student = scan_button("학생", texture_seed=9101)
        single_student = scan_button("단일", texture_seed=9102, cut_right=False)
        item = scan_button("아이템", texture_seed=9103)
        equipment = scan_button("장비", texture_seed=9104, cut_right=False)
        tactical = scan_button("전술대항전", texture_seed=9105, cut_right=False)
        student.clicked.connect(lambda: self._home_start_scan("students"))
        single_student.clicked.connect(lambda: self._home_start_scan("student_current"))
        item.clicked.connect(self._home_show_item_categories)
        equipment.clicked.connect(lambda: self._home_start_scan("equipment"))
        tactical.clicked.connect(lambda: self._home_show_pending_feature("전술대항전 스캔"))
        add_row(student, single_student, height_multiplier=2, width_weights=[4.0, 1.0])
        add_row(item, equipment, height_multiplier=2)
        add_row(tactical)
        layout.addStretch(1)
        return section

    def _build_home_settings_panel(self) -> HomeGlassSection:
        settings_shadow = LiftedShadowSpec(
            color=SHADOW,
            offset_x=float(scale_px(2, self._ui_scale)),
            offset_y=float(scale_px(2, self._ui_scale)),
            inset=float(scale_px(3, self._ui_scale)),
            layers=4,
            max_alpha=0.18,
        )
        self._home_settings_shadow = settings_shadow
        section = HomeGlassSection(
            fill=self._HOME_GLASS,
            radius=scale_px(7, self._ui_scale),
            cut_right=True,
            extend_left=scale_px(30, self._ui_scale),
            round_extension_corners=True,
            lifted_shadow=settings_shadow,
        )
        section.setObjectName("homeSettingsSection")
        # Settings rows calculate both diagonal boundaries independently. Keep
        # the content parent over the full base width so lower rows can consume
        # the space added by the section's left wedge.
        layout = self._home_section_layout(section)
        content = QWidget()
        self._settings_tab = content
        self._build_settings_tab(content, section)
        layout.addWidget(content, 1)
        return section

    def _build_home_item_panel(self) -> HomeGlassSection:
        item_section_shadow = LiftedShadowSpec(
            color=SHADOW,
            offset_x=float(scale_px(2, self._ui_scale)),
            offset_y=float(scale_px(2, self._ui_scale)),
            inset=float(scale_px(3, self._ui_scale)),
            layers=4,
            max_alpha=0.2,
        )
        item_button_shadow = replace(item_section_shadow, max_alpha=0.16)
        self._home_item_section_shadow = item_section_shadow
        self._home_item_button_shadow = item_button_shadow
        section = HomeGlassSection(
            fill=self._HOME_GLASS,
            radius=scale_px(7, self._ui_scale),
            cut_right=True,
            extend_left=scale_px(30, self._ui_scale),
            round_extension_corners=True,
            lifted_shadow=item_section_shadow,
        )
        section.setObjectName("homeItemCategorySection")
        layout = self._home_section_layout(section, extended=True)
        menu_gap = scale_px(8, self._ui_scale)
        menu_radius = scale_px(7, self._ui_scale)
        title = QLabel("아이템 스캔 범위")
        title.setObjectName("title")
        layout.addWidget(title)
        hint = QLabel("스캔할 아이템 종류를 선택하세요.")
        hint.setObjectName("count")
        layout.addWidget(hint)
        self._home_item_control_slots: list[DiagonalComponentControlSlot] = []
        self._home_item_menu_rows: list[HomeMenuButtonRow] = []
        entries = (
            ("오파츠", "ooparts"),
            ("기술 노트", "tech_notes"),
            ("전술 교육 BD", "tactical_bd"),
            ("활동 보고서", "activity_reports"),
            ("엘레프", "student_elephs"),
        )
        item_buttons: list[ParallelogramActionButton] = []
        for texture_seed, (label, profile_id) in enumerate(entries, start=9201):
            button = ParallelogramActionButton(
                label,
                fill=SURFACE,
                accent=ACCENT,
                slant=menu_gap,
                extend_left=True,
                angle_degrees=HOME_DIAGONAL_ANGLE,
                radius=menu_radius,
                full_height_slant=True,
                triangle_texture=_home_candidate_triangle_texture(SURFACE, random_seed=texture_seed),
                triangle_visible_ratio=1.0,
                triangle_texture_only=True,
                lifted_shadow=item_button_shadow,
                reserve_shadow_inset=True,
            )
            button.setFont(_scaled_font(button.font(), 1.2))
            button.clicked.connect(lambda _checked=False, selected=profile_id: self._home_start_scan("items", selected))
            item_buttons.append(button)
        resource = ParallelogramActionButton(
            "자원",
            fill=SURFACE,
            accent=ACCENT,
            slant=menu_gap,
            extend_left=True,
            angle_degrees=HOME_DIAGONAL_ANGLE,
            radius=menu_radius,
            full_height_slant=True,
            triangle_texture=_home_candidate_triangle_texture(
                SURFACE,
                random_seed=9206,
            ),
            triangle_visible_ratio=1.0,
            triangle_texture_only=True,
            lifted_shadow=item_button_shadow,
            reserve_shadow_inset=True,
        )
        resource.setFont(_scaled_font(resource.font(), 1.2))
        resource.clicked.connect(self._home_show_resource_prompt)
        item_buttons.append(resource)
        for index in range(0, len(item_buttons), 2):
            row = HomeMenuButtonRow(
                item_buttons[index:index + 2],
                seam_gap=menu_gap,
                angle_degrees=HOME_DIAGONAL_ANGLE,
                radius=menu_radius,
                full_height_slant=True,
            )
            row.setFixedHeight(max(108, scale_px(108, self._ui_scale)))
            slot = DiagonalComponentControlSlot(
                section,
                row,
                left_clearance=scale_px(18, self._ui_scale),
                right_clearance=scale_px(24, self._ui_scale),
            )
            self._home_item_menu_rows.append(row)
            self._home_item_control_slots.append(slot)
            layout.addWidget(slot)
        layout.addStretch(1)
        return section

    def _build_home_resource_panel(self) -> HomeGlassSection:
        resource_section_shadow = LiftedShadowSpec(
            color=SHADOW,
            offset_x=float(scale_px(2, self._ui_scale)),
            offset_y=float(scale_px(2, self._ui_scale)),
            inset=float(scale_px(3, self._ui_scale)),
            layers=4,
            max_alpha=0.2,
        )
        resource_input_shadow = replace(resource_section_shadow, max_alpha=0.14)
        self._home_resource_section_shadow = resource_section_shadow
        self._home_resource_input_shadow = resource_input_shadow
        section = HomeGlassSection(
            fill=self._HOME_GLASS,
            radius=scale_px(7, self._ui_scale),
            cut_right=True,
            extend_left=scale_px(30, self._ui_scale),
            round_extension_corners=True,
            lifted_shadow=resource_section_shadow,
        )
        section.setObjectName("homeResourcePromptSection")
        layout = self._home_section_layout(section, extended=True)
        title = QLabel("자원 입력")
        title.setObjectName("title")
        layout.addWidget(title)
        hint = QLabel("OCR 대신 현재 보유량을 직접 입력합니다.")
        hint.setObjectName("count")
        hint.setWordWrap(True)
        layout.addWidget(hint)
        control_height = max(48, scale_px(48, self._ui_scale))
        control_radius = scale_px(7, self._ui_scale)
        right_clearance = scale_px(24, self._ui_scale)
        self._home_credit_input = DiagonalLineEdit(
            fill=SURFACE_ALT,
            border=BORDER,
            accent=ACCENT,
            angle_degrees=HOME_DIAGONAL_ANGLE,
            radius=control_radius,
            lifted_shadow=resource_input_shadow,
        )
        self._home_credit_input.setValidator(QIntValidator(0, 2_147_483_647, self._home_credit_input))
        self._home_credit_input.setPlaceholderText("크레딧")
        self._home_credit_input.setFixedHeight(control_height)
        self._home_pyroxene_input = DiagonalLineEdit(
            fill=SURFACE_ALT,
            border=BORDER,
            accent=ACCENT,
            angle_degrees=HOME_DIAGONAL_ANGLE,
            radius=control_radius,
            lifted_shadow=resource_input_shadow,
        )
        self._home_pyroxene_input.setValidator(QIntValidator(0, 2_147_483_647, self._home_pyroxene_input))
        self._home_pyroxene_input.setPlaceholderText("청휘석")
        self._home_pyroxene_input.setFixedHeight(control_height)
        self._home_resource_icon_labels: list[QLabel] = []
        self._home_resource_control_slots: list[DiagonalComponentControlSlot] = []

        def add_resource_row(label_text: str, icon_name: str, line_edit: DiagonalLineEdit) -> None:
            row = QWidget()
            row.setMinimumHeight(control_height)
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(scale_px(10, self._ui_scale))
            icon_label = QLabel()
            icon_label.setAccessibleName(label_text)
            icon_label.setToolTip(label_text)
            icon_size = scale_px(33, self._ui_scale)
            icon_box = scale_px(42, self._ui_scale)
            pixmap = QPixmap(str(BASE_DIR / "templates" / "icons" / "temp" / icon_name))
            icon_label.setPixmap(
                pixmap.scaled(icon_size, icon_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            )
            icon_label.setFixedSize(icon_box, icon_box)
            icon_label.setAlignment(Qt.AlignCenter)
            row_layout.addWidget(icon_label, 0, Qt.AlignVCenter)
            row_layout.addWidget(line_edit, 1)
            slot = DiagonalComponentControlSlot(
                section,
                row,
                left_clearance=scale_px(18, self._ui_scale),
                right_clearance=right_clearance,
            )
            self._home_resource_icon_labels.append(icon_label)
            self._home_resource_control_slots.append(slot)
            layout.addWidget(slot)

        add_resource_row("크레딧", "Currency_Icon_Gold.png", self._home_credit_input)
        add_resource_row("청휘석", "Currency_Icon_Gem.png", self._home_pyroxene_input)

        action_row = QWidget()
        action_row.setMinimumHeight(control_height)
        buttons = QHBoxLayout(action_row)
        buttons.setContentsMargins(0, 0, 0, 0)
        buttons.setSpacing(scale_px(8, self._ui_scale))
        confirm = QPushButton("확인")
        cancel = ParallelogramActionButton(
            "취소",
            fill=SURFACE_ALT,
            accent=ACCENT,
            extend_left=False,
            angle_degrees=HOME_DIAGONAL_ANGLE,
            radius=control_radius,
            full_height_slant=True,
            cut_right=True,
        )
        confirm.setFixedSize(scale_px(112, self._ui_scale), control_height)
        cancel.setFixedSize(scale_px(112, self._ui_scale), control_height)
        confirm.clicked.connect(self._home_save_manual_resources)
        cancel.clicked.connect(self._home_cancel_resource_prompt)
        buttons.addStretch(1)
        buttons.addWidget(confirm)
        buttons.addWidget(cancel)
        action_slot = DiagonalComponentControlSlot(
            section,
            action_row,
            left_clearance=scale_px(18, self._ui_scale),
            right_clearance=right_clearance,
        )
        self._home_resource_confirm_button = confirm
        self._home_resource_cancel_button = cancel
        self._home_resource_action_row = action_row
        self._home_resource_control_slots.append(action_slot)
        layout.addWidget(action_slot)
        layout.addStretch(1)
        return section

    def _home_primary_action(self) -> None:
        self._home_transition_center(None)
        if bool(self._home_connected):
            if self._home_right_host.currentPage() is self._home_scan_panel:
                self._home_right_host.transitionTo(None, intro=180.0, outro=0.0)
                return
            self._home_right_host.transitionTo(self._home_scan_panel, intro=180.0, outro=0.0)
        else:
            self._refresh_home_window_candidates()
            self._home_right_host.transitionTo(self._home_connection_panel, intro=180.0, outro=0.0)

    def _home_show_settings(self) -> None:
        if self._home_center_host.currentPage() is self._home_settings_panel:
            self._home_transition_center(None)
            return
        self._home_dashboard_widget.setCenterDock("menu")
        self._refresh_settings_profiles()
        self._home_right_host.transitionTo(None, intro=45.0, outro=0.0)
        self._home_transition_center(self._home_settings_panel)

    def _home_show_item_categories(self) -> None:
        self._home_dashboard_widget.setCenterDock("right")
        self._home_transition_center(self._home_item_panel)

    def _home_show_resource_prompt(self) -> None:
        self._home_dashboard_widget.setCenterDock("right")
        resources = getattr(self, "_resource_snapshot", {}) or {}
        self._home_credit_input.setText(str(resources.get("credit", "")))
        self._home_pyroxene_input.setText(str(resources.get("pyroxene", "")))
        self._home_transition_center(self._home_resource_panel)

    def _home_cancel_resource_prompt(self) -> None:
        self._home_transition_center(self._home_item_panel)

    def _home_save_manual_resources(self) -> None:
        credit_text = self._home_credit_input.text().strip()
        pyroxene_text = self._home_pyroxene_input.text().strip()
        if not credit_text or not pyroxene_text:
            QMessageBox.information(self, "자원 입력", "크레딧과 청휘석을 모두 입력해 주세요.")
            return
        try:
            credit = int(credit_text)
            pyroxene = int(pyroxene_text)
        except ValueError:
            QMessageBox.warning(self, "자원 입력", "자원 수량은 0 이상의 정수여야 합니다.")
            return
        from core.db_writer import build_scan_meta
        from core.repository import ScanRepository
        from core.scanner import ScanResult

        meta = build_scan_meta()
        meta["source"] = "manual_resource_input"
        ScanRepository().save(ScanResult(resources={"credit": credit, "pyroxene": pyroxene}), meta)
        self._reload_data()
        self._home_transition_center(self._home_item_panel)

    def _home_transition_center(self, incoming: QWidget | None) -> None:
        motions = getattr(self, "_home_center_motion_by_page", {})
        default_motion = (HOME_CENTER_INTRO_ANGLE, HOME_CENTER_OUTRO_ANGLE)
        outgoing = self._home_center_host.currentPage()
        intro = motions.get(incoming, default_motion)[0]
        outro = motions.get(outgoing, default_motion)[1]
        self._home_center_host.transitionTo(incoming, intro=intro, outro=outro)

    def _home_start_scan(self, mode: str, item_filter: str | None = None) -> None:
        if self._launch_scanner(mode, item_filter=item_filter):
            self._home_root_stack.setCurrentWidget(self._home_scan_workspace_page)
            self._animate_home_scan_workspace_in()

    def _animate_home_scan_workspace_in(self) -> None:
        page = self._home_scan_workspace_page
        final_pos = QPoint(0, 0)
        start = QPoint(0, max(1, page.height()) + scale_px(48, self._ui_scale))
        page.move(start)
        page.show()
        cruise = QPropertyAnimation(page, b"pos")
        cruise.setDuration(HomeSectionHost.ENTER_MS)
        cruise.setStartValue(start)
        cruise.setEndValue(QPoint(0, scale_px(56, self._ui_scale)))
        cruise.setEasingCurve(QEasingCurve.Linear)
        settle = QPropertyAnimation(page, b"pos")
        settle.setDuration(HomeSectionHost.SETTLE_MS)
        settle.setStartValue(QPoint(0, scale_px(56, self._ui_scale)))
        settle.setEndValue(final_pos)
        settle.setEasingCurve(QEasingCurve.OutCubic)
        animation = QSequentialAnimationGroup(self)
        animation.addAnimation(cruise)
        animation.addAnimation(settle)
        animation.finished.connect(self._animate_home_scan_sections_from_sides)
        self._home_workspace_animation = animation
        animation.start()

    def _animate_home_scan_sections_from_sides(self) -> None:
        animations = QParallelAnimationGroup(self)
        page_width = max(1, self._home_scan_workspace_page.width())
        for widget, direction in (
            (getattr(self, "_scan_debug_section", None), -1),
            (getattr(self, "_scan_mirror_section", None), -1),
            (getattr(self, "_scan_right_section", None), 1),
        ):
            if widget is None or widget.width() <= 0:
                continue
            final_pos = widget.pos()
            start = final_pos + QPoint(direction * (page_width + scale_px(40, self._ui_scale)), 0)
            widget.move(start)
            widget.show()
            motion = QPropertyAnimation(widget, b"pos")
            motion.setDuration(HomeSectionHost.ENTER_MS + HomeSectionHost.SETTLE_MS)
            motion.setStartValue(start)
            motion.setEndValue(final_pos)
            motion.setEasingCurve(QEasingCurve.OutCubic)
            animations.addAnimation(motion)
        if animations.animationCount() == 0:
            self._home_workspace_animation = None
            return
        animations.finished.connect(lambda: setattr(self, "_home_workspace_animation", None))
        self._home_workspace_animation = animations
        animations.start()

    def _home_return_dashboard(self) -> None:
        if self._home_root_stack.currentWidget() is self._home_dashboard_page:
            return
        page = self._home_scan_workspace_page
        origin = page.pos()
        pull_target = origin + QPoint(0, -scale_px(22, self._ui_scale))
        exit_target = origin + QPoint(0, max(1, page.height()) + scale_px(48, self._ui_scale))
        pull = QPropertyAnimation(page, b"pos")
        pull.setDuration(HomeSectionHost.PULL_MS)
        pull.setStartValue(origin)
        pull.setEndValue(pull_target)
        pull.setEasingCurve(QEasingCurve.OutCubic)
        exit_animation = QPropertyAnimation(page, b"pos")
        exit_animation.setDuration(HomeSectionHost.EXIT_MS)
        exit_animation.setStartValue(pull_target)
        exit_animation.setEndValue(exit_target)
        exit_animation.setEasingCurve(QEasingCurve.InCubic)
        group = QSequentialAnimationGroup(self)
        group.addAnimation(pull)
        group.addAnimation(exit_animation)

        def show_dashboard() -> None:
            page.move(QPoint(0, 0))
            self._home_center_host.clear()
            self._home_right_host.clear()
            self._home_root_stack.setCurrentWidget(self._home_dashboard_page)
            self._home_workspace_animation = None

        group.finished.connect(show_dashboard)
        self._home_workspace_animation = group
        group.start()

    def _home_show_pending_feature(self, feature: str) -> None:
        QMessageBox.information(self, "BA Planner", f"{feature} 기능은 이후 단계에서 연결될 예정입니다.")

    def _home_navigate_main(self, target: QWidget | None) -> None:
        if self._main_tabs is None or target is None:
            return
        self._capture_outgoing_main_tab()
        self._main_tabs.setCurrentWidget(target)

    @staticmethod
    def _layout_item_widgets(item) -> list[QWidget]:
        widget = item.widget()
        if widget is not None:
            return [widget]
        child_layout = item.layout()
        if child_layout is None:
            return []
        widgets: list[QWidget] = []
        for index in range(child_layout.count()):
            widgets.extend(HomeTabComponent._layout_item_widgets(child_layout.itemAt(index)))
        return widgets

    def _tab_transition_parts(self, page: QWidget) -> tuple[QRect, list[QWidget]]:
        layout = page.layout()
        if layout is None:
            return QRect(0, 0, page.width(), page.height()), []
        header_names = {"header", "scanHeaderSection"}
        header: QWidget | None = None
        body_widgets: list[QWidget] = []
        for index in range(layout.count()):
            item = layout.itemAt(index)
            widgets = self._layout_item_widgets(item)
            if len(widgets) == 1 and widgets[0].objectName() in header_names and header is None:
                header = widgets[0]
                continue
            body_widgets.extend(widgets)
        if not body_widgets:
            return QRect(), []
        if header is None:
            body_top = 0
        else:
            body_top = min(
                max(0, widget.mapTo(page, QPoint(0, 0)).y())
                for widget in body_widgets
            )
        body_rect = QRect(0, body_top, page.width(), max(0, page.height() - body_top))
        return body_rect, body_widgets

    def _capture_outgoing_main_tab(self) -> None:
        tabs = self._main_tabs
        if tabs is None or tabs.currentWidget() is None:
            return
        self._reset_main_tab_transition()
        current = tabs.currentWidget()
        specs: list[tuple[QLabel, float]] = []
        if current is getattr(self, "_home_tab", None):
            for widget, _intro, outro in self._home_main_tab_elements():
                overlay = self._main_tab_widget_overlay(widget)
                if overlay is not None:
                    specs.append((overlay, outro))
        if not specs:
            body_rect, _body_widgets = self._tab_transition_parts(current)
            overlay = self._main_tab_rect_overlay(current, body_rect)
            if overlay is not None:
                specs.append((overlay, 270.0))
        self._main_tab_outgoing_specs = specs
        self._main_tab_outgoing_overlay = specs[0][0] if specs else None

    def _home_main_tab_elements(self) -> list[tuple[QWidget, float, float]]:
        root_stack = getattr(self, "_home_root_stack", None)
        dashboard = getattr(self, "_home_dashboard_page", None)
        if root_stack is None or root_stack.currentWidget() is not dashboard:
            return []
        elements: list[tuple[QWidget, float, float]] = []
        menu = self._home_menu_host.currentPage()
        if menu is not None:
            elements.append((menu, HOME_MENU_INTRO_ANGLE, HOME_MENU_OUTRO_ANGLE))
        motions = getattr(self, "_home_center_motion_by_page", {})
        center = self._home_center_host.currentPage()
        if center is not None:
            intro, outro = motions.get(center, (HOME_CENTER_INTRO_ANGLE, HOME_CENTER_OUTRO_ANGLE))
            elements.append((center, intro, outro))
        right = self._home_right_host.currentPage()
        if right is not None:
            # Connection and Scan already enter from intro=180 and leave at
            # outro=0 in their section-host transitions.
            elements.append((right, 180.0, 0.0))
        return elements

    def _main_tab_widget_overlay(self, widget: QWidget) -> QLabel | None:
        tabs = self._main_tabs
        if tabs is None or widget.width() <= 0 or widget.height() <= 0:
            return None
        widget.ensurePolished()
        pixmap = widget.grab()
        if pixmap.isNull():
            return None
        overlay = QLabel(tabs)
        overlay.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        overlay.setAttribute(Qt.WA_TranslucentBackground, True)
        overlay.setPixmap(pixmap)
        overlay.resize(pixmap.size())
        overlay.move(widget.mapTo(tabs, QPoint(0, 0)))
        overlay.show()
        overlay.raise_()
        return overlay

    def _main_tab_rect_overlay(self, page: QWidget, rect: QRect) -> QLabel | None:
        tabs = self._main_tabs
        if tabs is None or rect.isEmpty():
            return None
        pixmap = page.grab(rect)
        if pixmap.isNull():
            return None
        overlay = QLabel(tabs)
        overlay.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        overlay.setAttribute(Qt.WA_TranslucentBackground, True)
        overlay.setPixmap(pixmap)
        origin = page.mapTo(tabs, rect.topLeft())
        overlay.setGeometry(origin.x(), origin.y(), rect.width(), rect.height())
        overlay.show()
        overlay.raise_()
        return overlay

    def _main_tab_motion_offset(self, overlay: QWidget, angle_degrees: float) -> QPoint:
        angle = math.radians(float(angle_degrees) % 360.0)
        unit_x = math.cos(angle)
        unit_y = -math.sin(angle)
        clear_width = max(overlay.width(), 1) + scale_px(40, self._ui_scale)
        clear_height = max(overlay.height(), 1) + scale_px(40, self._ui_scale)
        distances: list[float] = []
        if abs(unit_x) > 1e-6:
            distances.append(clear_width / abs(unit_x))
        if abs(unit_y) > 1e-6:
            distances.append(clear_height / abs(unit_y))
        distance = min(distances) if distances else float(clear_height)
        return QPoint(round(unit_x * distance), round(unit_y * distance))

    def _reset_main_tab_transition(self) -> None:
        animation = getattr(self, "_main_tab_animation", None)
        if animation is not None:
            animation.stop()
        for widget, effect in getattr(self, "_main_tab_faded_widgets", []):
            if widget.graphicsEffect() is effect:
                widget.setGraphicsEffect(None)
        overlays: list[QLabel] = []
        for specs_name in ("_main_tab_incoming_specs", "_main_tab_outgoing_specs"):
            for overlay, _angle in getattr(self, specs_name, []):
                if overlay not in overlays:
                    overlays.append(overlay)
            setattr(self, specs_name, [])
        for overlay in overlays:
            overlay.deleteLater()
        self._main_tab_incoming_overlay = None
        self._main_tab_outgoing_overlay = None
        self._main_tab_faded_widgets = []
        self._main_tab_animation = None

    def _prepare_main_tab_click(self, index: int) -> None:
        if self._main_tabs is None or index == self._main_tabs.currentIndex():
            return
        self._capture_outgoing_main_tab()

    def _animate_main_tab_change(self, _index: int) -> None:
        tabs = self._main_tabs
        if tabs is None:
            return
        incoming = tabs.currentWidget()
        if incoming is None:
            return
        body_rect, body_widgets = self._tab_transition_parts(incoming)
        if body_rect.isEmpty():
            self._reset_main_tab_transition()
            return
        incoming_specs: list[tuple[QLabel, float]] = []
        if incoming is getattr(self, "_home_tab", None):
            for widget, intro, _outro in self._home_main_tab_elements():
                overlay = self._main_tab_widget_overlay(widget)
                if overlay is not None:
                    incoming_specs.append((overlay, intro))
        if not incoming_specs:
            overlay = self._main_tab_rect_overlay(incoming, body_rect)
            if overlay is not None:
                incoming_specs.append((overlay, 90.0))
        if not incoming_specs:
            self._reset_main_tab_transition()
            return
        faded_widgets: list[tuple[QWidget, QGraphicsOpacityEffect]] = []
        for widget in body_widgets:
            effect = QGraphicsOpacityEffect(widget)
            effect.setOpacity(0.0)
            widget.setGraphicsEffect(effect)
            faded_widgets.append((widget, effect))
        self._main_tab_faded_widgets = faded_widgets
        self._main_tab_incoming_specs = incoming_specs
        self._main_tab_incoming_overlay = incoming_specs[0][0]

        group = QSequentialAnimationGroup(self)
        outgoing_specs = list(getattr(self, "_main_tab_outgoing_specs", []))
        if outgoing_specs:
            exits = QParallelAnimationGroup()
            for overlay, outro in outgoing_specs:
                origin = overlay.pos()
                offset = self._main_tab_motion_offset(overlay, outro)
                pull_target = origin - QPoint(round(offset.x() * 0.055), round(offset.y() * 0.055))
                exit_target = origin + offset
                pull = QPropertyAnimation(overlay, b"pos")
                pull.setDuration(HomeSectionHost.PULL_MS)
                pull.setStartValue(origin)
                pull.setEndValue(pull_target)
                pull.setEasingCurve(QEasingCurve.OutCubic)
                leave = QPropertyAnimation(overlay, b"pos")
                leave.setDuration(HomeSectionHost.EXIT_MS)
                leave.setStartValue(pull_target)
                leave.setEndValue(exit_target)
                leave.setEasingCurve(QEasingCurve.InCubic)
                sequence = QSequentialAnimationGroup()
                sequence.addAnimation(pull)
                sequence.addAnimation(leave)
                exits.addAnimation(sequence)
            group.addAnimation(exits)

        entrances = QParallelAnimationGroup()
        for overlay, intro in incoming_specs:
            final_pos = overlay.pos()
            offset = self._main_tab_motion_offset(overlay, intro)
            start = final_pos - offset
            cruise_end = final_pos + QPoint(round((start.x() - final_pos.x()) * 0.16), round((start.y() - final_pos.y()) * 0.16))
            overlay.move(start)
            cruise = QPropertyAnimation(overlay, b"pos")
            cruise.setDuration(HomeSectionHost.ENTER_MS)
            cruise.setStartValue(start)
            cruise.setEndValue(cruise_end)
            cruise.setEasingCurve(QEasingCurve.Linear)
            settle = QPropertyAnimation(overlay, b"pos")
            settle.setDuration(HomeSectionHost.SETTLE_MS)
            settle.setStartValue(cruise_end)
            settle.setEndValue(final_pos)
            settle.setEasingCurve(QEasingCurve.OutCubic)
            sequence = QSequentialAnimationGroup()
            sequence.addAnimation(cruise)
            sequence.addAnimation(settle)
            entrances.addAnimation(sequence)
        group.addAnimation(entrances)

        def finish() -> None:
            for widget, effect in faded_widgets:
                if widget.graphicsEffect() is effect:
                    widget.setGraphicsEffect(None)
            for overlay, _angle in incoming_specs + outgoing_specs:
                overlay.deleteLater()
            self._main_tab_incoming_overlay = None
            self._main_tab_outgoing_overlay = None
            self._main_tab_incoming_specs = []
            self._main_tab_outgoing_specs = []
            self._main_tab_faded_widgets = []
            self._main_tab_animation = None

        group.finished.connect(finish)
        self._main_tab_animation = group
        group.start()

    def _sync_home_connection_state(self, connected: bool, title: str) -> None:
        connected = bool(connected)
        if self._home_connection_status_label is not None:
            self._home_connection_status_label.setText(
                f"연결됨: {title}" if connected else "Blue Archive 창을 선택해 연결해 주세요."
            )
        if not getattr(self, "_home_ready", False):
            return
        if self._home_connected is connected:
            return

        def swap_label() -> None:
            action_name = "스캔" if connected else "싯딤의 상자와 연결"
            self._home_primary_button.setActionName(action_name)
            self._home_primary_button.setTexturePath(HOME_MENU_TEXTURES[action_name])
            if connected and self._home_right_host.currentPage() is self._home_connection_panel:
                self._home_right_host.transitionTo(None, intro=0.0, outro=0.0)
            elif not connected:
                self._home_right_host.transitionTo(None, intro=0.0, outro=0.0)

        if self._home_connected is None:
            self._home_connected = connected
            swap_label()
        else:
            # Commit the logical state before animating so the one-second
            # connection timer cannot restart the same replacement midway.
            self._home_connected = connected
            self._home_menu_host.refreshCurrent(
                swap_label,
                intro=HOME_MENU_INTRO_ANGLE,
                outro=HOME_MENU_OUTRO_ANGLE,
            )
