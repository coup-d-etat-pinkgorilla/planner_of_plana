"""Palette-aware rounded and diagonal QML panel surfaces with restrained shadows."""

from __future__ import annotations

from PySide6.QtCore import Property, QRectF, Signal, Qt
from PySide6.QtGui import QColor, QPainter, QPainterPath, QPen, QTransform
from PySide6.QtQuick import QQuickPaintedItem

from gui.diagonal_shape import diagonal_shape_path
from gui.ui_design_spec import DiagonalShapeSpec


class PlannerSurfaceItem(QQuickPaintedItem):
    """Paint only the visual surface; layout and hit testing remain owned by QML."""

    appearanceChanged = Signal()

    def __init__(self, parent: QQuickPaintedItem | None = None) -> None:
        super().__init__(parent)
        self._palette: dict[str, object] = {}
        self._variant = "panel"
        self._radius = 18.0
        self._diagonal_edge = "none"
        self._diagonal_angle = 80.0
        self._diagonal_direction = "forward"
        self._shadow_depth = 3.0
        self._border_width = 1.0
        self.setAntialiasing(True)

    def _set_value(self, name: str, value: object) -> None:
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
        self._set_value("palette", dict(value or {}))

    @Property(str, notify=appearanceChanged)
    def variant(self) -> str:
        return self._variant

    @variant.setter
    def variant(self, value: str) -> None:
        self._set_value("variant", str(value or "panel"))

    @Property(float, notify=appearanceChanged)
    def radius(self) -> float:
        return self._radius

    @radius.setter
    def radius(self, value: float) -> None:
        self._set_value("radius", max(0.0, float(value)))

    @Property(str, notify=appearanceChanged)
    def diagonalEdge(self) -> str:
        return self._diagonal_edge

    @diagonalEdge.setter
    def diagonalEdge(self, value: str) -> None:
        edge = str(value or "none").lower()
        self._set_value("diagonal_edge", edge if edge in {"none", "left", "right", "top", "bottom"} else "none")

    @Property(float, notify=appearanceChanged)
    def diagonalAngle(self) -> float:
        return self._diagonal_angle

    @diagonalAngle.setter
    def diagonalAngle(self, value: float) -> None:
        self._set_value("diagonal_angle", min(89.5, max(0.5, float(value))))

    @Property(str, notify=appearanceChanged)
    def diagonalDirection(self) -> str:
        return self._diagonal_direction

    @diagonalDirection.setter
    def diagonalDirection(self, value: str) -> None:
        direction = str(value or "forward").lower()
        self._set_value("diagonal_direction", direction if direction in {"forward", "reverse"} else "forward")

    @Property(float, notify=appearanceChanged)
    def shadowDepth(self) -> float:
        return self._shadow_depth

    @shadowDepth.setter
    def shadowDepth(self, value: float) -> None:
        self._set_value("shadow_depth", min(4.0, max(0.0, float(value))))

    @Property(float, notify=appearanceChanged)
    def borderWidth(self) -> float:
        return self._border_width

    @borderWidth.setter
    def borderWidth(self, value: float) -> None:
        self._set_value("border_width", min(6.0, max(0.0, float(value))))

    def _color(self, key: str, fallback: str) -> QColor:
        return QColor(str(self._palette.get(key, fallback)))

    def _surface_color(self) -> QColor:
        key = {
            "alt": "panelAlt",
            "raised": "panelRaised",
            "selected": "surfaceSelected",
        }.get(self._variant, "panel")
        return self._color(key, "#313b59")

    def surface_path(self) -> QPainterPath:
        extent = self._shadow_depth + 1.0 if self._shadow_depth > 0 else 1.0
        rect = QRectF(0.5, 0.5, max(1.0, self.width() - extent - 0.5), max(1.0, self.height() - extent - 0.5))
        radius = min(self._radius, rect.width() / 2.0, rect.height() / 2.0)
        if self._diagonal_edge == "none":
            path = QPainterPath()
            path.addRoundedRect(rect, radius, radius)
            return path
        return diagonal_shape_path(
            rect,
            DiagonalShapeSpec(
                mode="cut",
                edge=self._diagonal_edge,
                angle_degrees=self._diagonal_angle,
                direction=self._diagonal_direction,
                depth_mode="angle",
                radius=int(round(radius)),
                round_start=True,
                round_end=True,
                hit_mask=False,
            ),
        )

    def paint(self, painter: QPainter) -> None:
        path = self.surface_path()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setPen(Qt.PenStyle.NoPen)
        if self._shadow_depth > 0:
            shadow = self._color("shadow", "#151923")
            layers = (
                (0.8, 0.7, 0.20),
                (1.6, 1.4, 0.12),
                (2.4, 2.1, 0.07),
                (3.2, 2.8, 0.035),
            )
            for dx, dy, alpha in layers:
                if max(dx, dy) > self._shadow_depth + 0.25:
                    continue
                layer_color = QColor(shadow)
                layer_color.setAlphaF(alpha)
                painter.setBrush(layer_color)
                painter.drawPath(QTransform.fromTranslate(dx, dy).map(path))
        painter.setBrush(self._surface_color())
        if self._border_width > 0:
            border = QPen(self._color("border", "#5c5960"), self._border_width)
            border.setCosmetic(True)
            painter.setPen(border)
        else:
            painter.setPen(Qt.PenStyle.NoPen)
        painter.drawPath(path)
