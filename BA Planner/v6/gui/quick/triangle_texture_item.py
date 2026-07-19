"""Qt Quick adapter for the shared image-free BA triangle texture renderer."""

from __future__ import annotations

from PySide6.QtCore import Property, QRectF, Signal
from PySide6.QtGui import QPainter
from PySide6.QtQuick import QQuickPaintedItem

from gui.triangle_texture import TriangleTextureConfig, paint_triangle_texture


class TriangleTextureItem(QQuickPaintedItem):
    """Paint the existing QWidget-era texture renderer inside the QML scene graph."""

    themePaletteChanged = Signal()

    def __init__(self, parent: QQuickPaintedItem | None = None) -> None:
        super().__init__(parent)
        self._palette: dict[str, object] = {}
        self.setAntialiasing(False)
        self.setOpaquePainting(True)

    @Property("QVariantMap", notify=themePaletteChanged)
    def themePalette(self) -> dict[str, object]:
        return dict(self._palette)

    @themePalette.setter
    def themePalette(self, value: dict[str, object]) -> None:
        resolved = dict(value or {})
        if resolved != self._palette:
            self._palette = resolved
            self.themePaletteChanged.emit()
            self.update()

    def _color(self, key: str, fallback: str) -> str:
        value = str(self._palette.get(key, fallback))
        return value if value.startswith("#") else fallback

    def texture_config(self) -> TriangleTextureConfig:
        return TriangleTextureConfig(
            base_color=self._color("background", "#171c2b"),
            panel_color=self._color("panel", "#313b59"),
            soft_color=self._color("accentPale", "#9a8c9d"),
            accent_color=self._color("accent", "#f266b3"),
            triangle_size=138.0,
            tessellation_contrast=0.032,
            random_seed=7319,
            macro_triangle_chance=0.075,
            macro_triangle_scale=3.0,
            macro_triangle_contrast=0.024,
            light_strength=0.13,
            light_center_x=0.52,
            light_center_y=0.46,
            edge_vignette_strength=0.20,
            fog_direction_degrees=18.0,
            fog_strength=0.10,
        )

    def paint(self, painter: QPainter) -> None:
        paint_triangle_texture(
            painter,
            QRectF(0.0, 0.0, float(self.width()), float(self.height())),
            self.texture_config(),
        )
