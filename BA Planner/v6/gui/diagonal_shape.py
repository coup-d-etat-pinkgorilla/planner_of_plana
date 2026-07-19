"""Generic diagonal shape preview, runtime application, and validation."""

from __future__ import annotations

from dataclasses import dataclass
import math

from PySide6.QtCore import QEvent, QObject, QPointF, QRectF, Qt
from PySide6.QtGui import QPainterPath, QRegion
from PySide6.QtWidgets import QAbstractButton, QWidget

from gui.ui_design_spec import DiagonalShapeSpec, UIDesignSpec


VALID_MODES = {"cut", "extend"}
VALID_EDGES = {"left", "right", "top", "bottom"}
VALID_DIRECTIONS = {"forward", "reverse"}
VALID_DEPTH_MODES = {"angle", "fixed"}


@dataclass(frozen=True, slots=True)
class ShapeValidationIssue:
    severity: str
    selector: str
    code: str
    message: str


def resolved_diagonal_depth(width: float, height: float, shape: DiagonalShapeSpec) -> float:
    radius = min(max(0.0, float(shape.radius)), max(0.0, width / 2.0), max(0.0, height / 2.0))
    edge = str(shape.edge).lower()
    if str(shape.depth_mode).lower() == "fixed":
        requested = max(0.0, float(shape.depth))
    else:
        angle = min(89.5, max(0.5, float(shape.angle_degrees)))
        tangent = max(0.01, abs(math.tan(math.radians(angle))))
        if edge in {"left", "right"}:
            requested = max(0.0, height - (2.0 * radius)) / tangent
        else:
            requested = max(0.0, width - (2.0 * radius)) * tangent
    maximum = max(0.0, (width if edge in {"left", "right"} else height) - (2.0 * radius))
    return min(maximum, requested)


def _rounded_polygon_path(points: list[QPointF], radii: list[float]) -> QPainterPath:
    count = len(points)
    if count < 3:
        return QPainterPath()
    entries: list[tuple[QPointF, QPointF, QPointF]] = []
    for index, point in enumerate(points):
        previous = points[(index - 1) % count]
        following = points[(index + 1) % count]
        incoming_x, incoming_y = previous.x() - point.x(), previous.y() - point.y()
        outgoing_x, outgoing_y = following.x() - point.x(), following.y() - point.y()
        incoming_length = math.hypot(incoming_x, incoming_y)
        outgoing_length = math.hypot(outgoing_x, outgoing_y)
        radius = min(max(0.0, radii[index]), incoming_length / 2.0, outgoing_length / 2.0)
        if radius <= 0.0 or incoming_length <= 1e-6 or outgoing_length <= 1e-6:
            entries.append((QPointF(point), QPointF(point), QPointF(point)))
            continue
        before = QPointF(
            point.x() + (incoming_x / incoming_length) * radius,
            point.y() + (incoming_y / incoming_length) * radius,
        )
        after = QPointF(
            point.x() + (outgoing_x / outgoing_length) * radius,
            point.y() + (outgoing_y / outgoing_length) * radius,
        )
        entries.append((before, QPointF(point), after))
    path = QPainterPath(entries[0][0])
    for before, corner, after in entries:
        path.lineTo(before)
        path.quadTo(corner, after)
    path.closeSubpath()
    return path


def diagonal_shape_path(rect: QRectF, shape: DiagonalShapeSpec) -> QPainterPath:
    x, y, width, height = rect.x(), rect.y(), max(1.0, rect.width()), max(1.0, rect.height())
    right, bottom = x + width, y + height
    depth = resolved_diagonal_depth(width, height, shape)
    edge = str(shape.edge).lower()
    reverse = str(shape.direction).lower() == "reverse"
    if str(shape.mode).lower() == "extend":
        reverse = not reverse
    if edge == "left":
        points = [QPointF(x + (0.0 if reverse else depth), y), QPointF(right, y), QPointF(right, bottom), QPointF(x + (depth if reverse else 0.0), bottom)]
        diagonal_indices = (0, 3)
    elif edge == "top":
        points = [QPointF(x, y + (0.0 if reverse else depth)), QPointF(right, y + (depth if reverse else 0.0)), QPointF(right, bottom), QPointF(x, bottom)]
        diagonal_indices = (0, 1)
    elif edge == "bottom":
        points = [QPointF(x, y), QPointF(right, y), QPointF(right, bottom - (0.0 if reverse else depth)), QPointF(x, bottom - (depth if reverse else 0.0))]
        diagonal_indices = (2, 3)
    else:
        points = [QPointF(x, y), QPointF(right - (depth if reverse else 0.0), y), QPointF(right - (0.0 if reverse else depth), bottom), QPointF(x, bottom)]
        diagonal_indices = (1, 2)
    radii = [max(0.0, float(shape.radius))] * 4
    radii[diagonal_indices[0]] = radii[diagonal_indices[0]] if shape.round_start else 0.0
    radii[diagonal_indices[1]] = radii[diagonal_indices[1]] if shape.round_end else 0.0
    return _rounded_polygon_path(points, radii)


class DiagonalShapeController(QObject):
    def __init__(self, root: QWidget):
        super().__init__(root)
        self._shapes: dict[QWidget, DiagonalShapeSpec] = {}
        self._original_masks: dict[QWidget, QRegion] = {}
        self._base_margins: dict[QWidget, tuple[int, int, int, int]] = {}
        self._native_originals: dict[QWidget, dict[str, object]] = {}

    def apply(self, shapes: dict[QWidget, DiagonalShapeSpec]) -> None:
        self.clear()
        for widget, shape in shapes.items():
            self._shapes[widget] = shape
            self._original_masks[widget] = widget.mask()
            layout = widget.layout()
            if layout is not None:
                margins = layout.contentsMargins()
                self._base_margins[widget] = (margins.left(), margins.top(), margins.right(), margins.bottom())
            widget.installEventFilter(self)
            self._apply_native_shape(widget, shape)
            self._update_widget(widget)

    def clear(self) -> None:
        for widget in tuple(self._shapes):
            try:
                widget.removeEventFilter(self)
                original_mask = self._original_masks.get(widget, QRegion())
                widget.setMask(original_mask) if not original_mask.isEmpty() else widget.clearMask()
                for name, value in self._native_originals.get(widget, {}).items():
                    setattr(widget, name, value)
                widget.updateGeometry()
                widget.update()
                margins = self._base_margins.get(widget)
                if margins is not None and widget.layout() is not None:
                    widget.layout().setContentsMargins(*margins)
            except RuntimeError:
                pass
        self._shapes.clear()
        self._original_masks.clear()
        self._base_margins.clear()
        self._native_originals.clear()

    def eventFilter(self, watched: QObject, event: QEvent) -> bool:
        if isinstance(watched, QWidget) and watched in self._shapes and event.type() == QEvent.Type.Resize:
            self._update_widget(watched)
        return False

    def _update_widget(self, widget: QWidget) -> None:
        shape = self._shapes[widget]
        path = diagonal_shape_path(QRectF(widget.rect()), shape)
        native = _supports_native_shape(widget, shape)
        if shape.hit_mask or not native:
            widget.setMask(QRegion(path.toFillPolygon().toPolygon()))
        else:
            original = self._original_masks.get(widget, QRegion())
            widget.setMask(original) if not original.isEmpty() else widget.clearMask()
        layout = widget.layout()
        margins = self._base_margins.get(widget)
        if layout is None or margins is None:
            return
        safe = max(0, int(shape.content_safe_margin))
        left, top, right, bottom = margins
        edge = str(shape.edge).lower()
        if edge == "left":
            left = max(left, safe)
        elif edge == "top":
            top = max(top, safe)
        elif edge == "bottom":
            bottom = max(bottom, safe)
        else:
            right = max(right, safe)
        layout.setContentsMargins(left, top, right, bottom)

    def _apply_native_shape(self, widget: QWidget, shape: DiagonalShapeSpec) -> None:
        if not _supports_native_shape(widget, shape):
            return
        names = ("_radius", "_angle_degrees", "_cut_right", "_extend_left")
        self._native_originals[widget] = {
            name: getattr(widget, name)
            for name in names
            if hasattr(widget, name)
        }
        if hasattr(widget, "_radius"):
            widget._radius = max(0, int(shape.radius))  # type: ignore[attr-defined]
        if hasattr(widget, "_angle_degrees"):
            widget._angle_degrees = float(shape.angle_degrees)  # type: ignore[attr-defined]
        if type(widget).__name__ == "HomeGlassSection":
            if shape.mode == "cut":
                widget._cut_right = True  # type: ignore[attr-defined]
            else:
                widget._extend_left = max(0, int(round(resolved_diagonal_depth(widget.width(), widget.height(), shape))))  # type: ignore[attr-defined]
        widget.updateGeometry()
        widget.update()


def _supports_native_shape(widget: QWidget, shape: DiagonalShapeSpec) -> bool:
    class_name = type(widget).__name__
    if shape.direction != "forward":
        return False
    if class_name == "DiagonalScanFrame":
        return shape.mode == "cut" and shape.edge == "right"
    if class_name == "HomeGlassSection":
        return (shape.mode == "cut" and shape.edge == "right") or (shape.mode == "extend" and shape.edge == "left")
    return False


def apply_diagonal_shapes(root: QWidget, spec: UIDesignSpec, index: dict[str, QWidget] | None = None) -> None:
    if index is None:
        from gui.ui_design_runtime import widget_index
        resolved_index = widget_index(root)
    else:
        resolved_index = index
    shapes = {
        widget: override.diagonal_shape
        for selector, override in spec.components.items()
        if override.diagonal_shape is not None and (widget := resolved_index.get(selector)) is not None
    }
    controller = getattr(root, "_ui_diagonal_shape_controller", None)
    if not isinstance(controller, DiagonalShapeController):
        controller = DiagonalShapeController(root)
        root._ui_diagonal_shape_controller = controller  # type: ignore[attr-defined]
    controller.apply(shapes)


def validate_diagonal_shapes(root: QWidget, spec: UIDesignSpec) -> list[ShapeValidationIssue]:
    from gui.ui_design_runtime import widget_index
    index = widget_index(root)
    issues: list[ShapeValidationIssue] = []
    for selector, override in spec.components.items():
        shape = override.diagonal_shape
        if shape is None:
            continue
        widget = index.get(selector)
        if widget is None:
            issues.append(ShapeValidationIssue("error", selector, "selector_missing", "컴포넌트 selector를 Preview에서 찾을 수 없습니다."))
            continue
        if shape.mode not in VALID_MODES:
            issues.append(ShapeValidationIssue("error", selector, "mode", f"지원하지 않는 mode: {shape.mode}"))
        if shape.edge not in VALID_EDGES:
            issues.append(ShapeValidationIssue("error", selector, "edge", f"지원하지 않는 edge: {shape.edge}"))
        if shape.direction not in VALID_DIRECTIONS:
            issues.append(ShapeValidationIssue("error", selector, "direction", f"지원하지 않는 direction: {shape.direction}"))
        if shape.depth_mode not in VALID_DEPTH_MODES:
            issues.append(ShapeValidationIssue("error", selector, "depth_mode", f"지원하지 않는 depth mode: {shape.depth_mode}"))
        if not 0.5 <= float(shape.angle_degrees) <= 89.5:
            issues.append(ShapeValidationIssue("error", selector, "angle", "각도는 0.5° 이상 89.5° 이하여야 합니다."))
        width, height = max(1, widget.width()), max(1, widget.height())
        if int(shape.radius) < 0 or int(shape.radius) * 2 >= min(width, height):
            issues.append(ShapeValidationIssue("error", selector, "radius", "반지름이 음수이거나 컴포넌트의 절반 이상입니다."))
        depth = resolved_diagonal_depth(width, height, shape)
        if depth <= 0.0:
            issues.append(ShapeValidationIssue("error", selector, "depth", "계산된 절단/연장 깊이가 0입니다."))
        if int(shape.content_safe_margin) < math.ceil(depth):
            issues.append(ShapeValidationIssue("warning", selector, "safe_margin", f"콘텐츠 안전 여백 {shape.content_safe_margin}px이 계산 깊이 {math.ceil(depth)}px보다 작습니다."))
        if shape.hit_mask:
            issues.append(ShapeValidationIssue("warning", selector, "hit_mask", "hit mask는 클릭 영역을 맞추지만 가장자리 antialiasing이 거칠 수 있습니다."))
        if isinstance(widget, QAbstractButton):
            issues.append(ShapeValidationIssue("warning", selector, "interactive", "버튼 절단 후 hover, focus ring, 클릭 영역을 실제 창에서 확인해야 합니다."))
        native = _supports_native_shape(widget, shape)
        if not native and not shape.hit_mask:
            issues.append(ShapeValidationIssue("error", selector, "generic_requires_mask", "일반 QWidget 형상은 클릭 영역 mask를 켜야 Preview에 적용할 수 있습니다."))
        elif not native:
            issues.append(ShapeValidationIssue("warning", selector, "generic_mask", "일반 QWidget은 binary mask fallback을 사용합니다. 최종 도입 전 source-native antialias 경로를 검토하세요."))
        if int(shape.seam_gap) > 0 and int(shape.overlap) > 0:
            issues.append(ShapeValidationIssue("error", selector, "seam", "seam gap과 overlap을 동시에 양수로 지정할 수 없습니다."))
        if shape.linked_selector:
            linked_override = spec.components.get(shape.linked_selector)
            linked_shape = linked_override.diagonal_shape if linked_override is not None else None
            if linked_shape is None or shape.linked_selector not in index:
                issues.append(ShapeValidationIssue("error", selector, "linked_selector", "연결 대상 selector 또는 대각선 명세를 찾을 수 없습니다."))
            else:
                if shape.link_angle and abs(float(shape.angle_degrees) - float(linked_shape.angle_degrees)) > 0.01:
                    issues.append(ShapeValidationIssue("error", selector, "linked_angle", "연결된 컴포넌트와 angle이 일치하지 않습니다."))
                if shape.link_direction and shape.direction != linked_shape.direction:
                    issues.append(ShapeValidationIssue("error", selector, "linked_direction", "연결된 컴포넌트와 direction이 일치하지 않습니다."))
    return sorted(issues, key=lambda issue: (0 if issue.severity == "error" else 1, issue.selector, issue.code))


def format_shape_validation(issues: list[ShapeValidationIssue]) -> str:
    if not issues:
        return "대각선 형상 검사 통과"
    return "\n".join(
        f"[{issue.severity.upper()}] {issue.code} · {issue.selector}\n  {issue.message}"
        for issue in issues
    )
