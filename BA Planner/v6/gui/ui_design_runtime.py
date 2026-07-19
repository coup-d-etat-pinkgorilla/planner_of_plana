"""Runtime bridge between a live Qt widget tree and the shared UI design spec."""

from __future__ import annotations

from collections.abc import Iterator

from PySide6.QtCore import QEasingCurve, QObject, QPoint, QPropertyAnimation, QRect, QSize, Qt
from PySide6.QtWidgets import (
    QAbstractButton,
    QAbstractSlider,
    QComboBox,
    QDoubleSpinBox,
    QFrame,
    QLabel,
    QLineEdit,
    QPlainTextEdit,
    QProgressBar,
    QPushButton,
    QSpinBox,
    QSplitter,
    QTabWidget,
    QWidget,
)

from gui.ui_design_spec import NewWidgetSpec, UIDesignSpec


_SELECTOR_SEGMENT_PROPERTY = "uiDesignStableSelectorSegment"


class _GeometryOverrideController(QObject):
    """Detach overridden widgets from layouts while retaining their slots."""

    def __init__(self, root: QWidget):
        super().__init__(root)
        self._bindings: list[tuple[QWidget, QWidget]] = []
        self._slot_sizes: dict[QWidget, QSize] = {}

    def slot_size(self, widget: QWidget) -> QSize | None:
        size = self._slot_sizes.get(widget)
        return QSize(size) if size is not None else None

    def set_targets(
        self,
        targets: dict[QWidget, QRect],
        initial_slot_sizes: dict[QWidget, QSize],
    ) -> None:
        self._restore_layout_bindings()
        self._slot_sizes = {
            widget: QSize(self._slot_sizes.get(widget, initial_slot_sizes[widget]))
            for widget in targets
            if widget in self._slot_sizes or widget in initial_slot_sizes
        }
        for widget, target in targets.items():
            parent = widget.parentWidget()
            parent_layout = parent.layout() if parent is not None else None
            if parent is not None and parent_layout is not None:
                placeholder = QWidget(parent)
                placeholder.setProperty("uiDesignGeometryPlaceholder", True)
                placeholder.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
                retained_size = self._slot_sizes.get(widget, _preferred_layout_slot_size(widget))
                placeholder.setFixedSize(retained_size)
                placeholder.setVisible(not widget.isHidden())
                replaced_item = parent_layout.replaceWidget(
                    widget,
                    placeholder,
                    Qt.FindChildOption.FindChildrenRecursively,
                )
                if replaced_item is not None:
                    self._bindings.append((widget, placeholder))
                else:
                    placeholder.deleteLater()
            widget.setGeometry(target)
            widget.raise_()

    def _restore_layout_bindings(self) -> None:
        for widget, placeholder in self._bindings:
            try:
                parent = placeholder.parentWidget()
                parent_layout = parent.layout() if parent is not None else None
                if parent_layout is not None:
                    parent_layout.replaceWidget(
                        placeholder,
                        widget,
                        Qt.FindChildOption.FindChildrenRecursively,
                    )
                placeholder.hide()
                placeholder.deleteLater()
            except RuntimeError:
                pass
        self._bindings.clear()


def _preferred_layout_slot_size(widget: QWidget) -> QSize:
    """Return a real allocation for visible widgets and a hint for unlaid-out ones."""
    if widget.isVisible() and not widget.size().isEmpty():
        return QSize(widget.size())
    for candidate in (widget.sizeHint(), widget.minimumSizeHint(), widget.minimumSize()):
        if candidate.isValid() and not candidate.isEmpty():
            return QSize(max(1, candidate.width()), max(1, candidate.height()))
    return QSize(max(1, widget.width()), max(1, widget.height()))


def _apply_geometry_overrides(
    root: QWidget,
    targets: dict[QWidget, QRect],
    initial_slot_sizes: dict[QWidget, QSize],
) -> None:
    controller = getattr(root, "_ui_design_geometry_controller", None)
    if not isinstance(controller, _GeometryOverrideController):
        controller = _GeometryOverrideController(root)
        root._ui_design_geometry_controller = controller  # type: ignore[attr-defined]
    controller.set_targets(targets, initial_slot_sizes)


def _segment(obj: QObject) -> str:
    stable_segment = obj.property(_SELECTOR_SEGMENT_PROPERTY)
    if isinstance(stable_segment, str) and stable_segment:
        return stable_segment
    class_name = type(obj).__name__
    object_name = obj.objectName().strip() if hasattr(obj, "objectName") else ""
    stem = f"{class_name}#{object_name}" if object_name else class_name
    parent = obj.parent()
    if parent is None:
        return stem
    siblings = [
        child for child in parent.children()
        if not bool(child.property("uiDesignGeometryPlaceholder"))
        if type(child).__name__ == class_name
        and (child.objectName().strip() if hasattr(child, "objectName") else "") == object_name
    ]
    segment = f"{stem}[{siblings.index(obj)}]" if len(siblings) > 1 else stem
    obj.setProperty(_SELECTOR_SEGMENT_PROPERTY, segment)
    return segment


def object_selector(obj: QObject, root: QObject) -> str:
    parts: list[str] = []
    current: QObject | None = obj
    while current is not None:
        parts.append(_segment(current))
        if current is root:
            break
        current = current.parent()
    if not parts or current is None:
        return ""
    return "/".join(reversed(parts))


def iter_widget_tree(root: QWidget) -> Iterator[tuple[QWidget, str]]:
    yield root, object_selector(root, root)
    for child in root.findChildren(QWidget):
        if bool(child.property("uiDesignGeometryPlaceholder")):
            continue
        selector = object_selector(child, root)
        if selector:
            yield child, selector


def widget_index(root: QWidget) -> dict[str, QWidget]:
    return {selector: widget for widget, selector in iter_widget_tree(root)}


def resolve_widget_selector(root: QWidget, selector: str) -> QWidget | None:
    """Resolve one stable selector without indexing the complete QObject tree."""
    parts = [part for part in selector.split("/") if part]
    if not parts or _segment(root) != parts[0]:
        return None
    current: QObject = root
    for expected in parts[1:]:
        match = next(
            (
                child
                for child in current.children()
                if isinstance(child, QWidget)
                and not bool(child.property("uiDesignGeometryPlaceholder"))
                and _segment(child) == expected
            ),
            None,
        )
        if match is None:
            return None
        current = match
    return current if isinstance(current, QWidget) else None


def targeted_widget_index(root: QWidget, selectors: set[str]) -> dict[str, QWidget]:
    index: dict[str, QWidget] = {}
    for selector in selectors:
        widget = resolve_widget_selector(root, selector)
        if widget is not None:
            index[selector] = widget
    return index


def _apply_gallery_styles(root: QWidget, spec: UIDesignSpec) -> None:
    """Apply opt-in class styles as one QSS layer, without walking child widgets."""
    base = root.property("uiDesignBaseStyleSheet")
    if not isinstance(base, str):
        base = root.styleSheet()
        root.setProperty("uiDesignBaseStyleSheet", base)
    gallery_qss = "\n".join(
        f"{style.widget_type} {{\n{style.style_sheet}\n}}"
        for style in spec.gallery_styles.values()
        if style.style_sheet.strip()
    )
    combined = base if not gallery_qss else f"{base}\n/* UCS gallery styles */\n{gallery_qss}"
    if root.styleSheet() != combined:
        root.setStyleSheet(combined)


def capture_transient_widget_state(root: QWidget) -> dict[str, dict[str, object]]:
    """Capture editable/navigation state without touching application data."""
    state: dict[str, dict[str, object]] = {}
    focus = root.focusWidget()
    for widget, selector in iter_widget_tree(root):
        payload: dict[str, object] = {}
        if isinstance(widget, QLineEdit):
            payload.update(text=widget.text(), cursor=widget.cursorPosition())
        elif isinstance(widget, QPlainTextEdit):
            payload.update(text=widget.toPlainText(), scroll=widget.verticalScrollBar().value())
        elif isinstance(widget, QComboBox):
            payload.update(index=widget.currentIndex(), text=widget.currentText())
        elif isinstance(widget, (QSpinBox, QDoubleSpinBox)):
            payload["value"] = widget.value()
        elif isinstance(widget, QAbstractButton) and widget.isCheckable():
            payload["checked"] = widget.isChecked()
        elif isinstance(widget, QAbstractSlider):
            payload["value"] = widget.value()
        elif isinstance(widget, QSplitter):
            payload["sizes"] = widget.sizes()
        elif isinstance(widget, QTabWidget):
            payload["index"] = widget.currentIndex()
        if widget is focus:
            payload["focus"] = True
        if payload:
            state[selector] = payload
    return state


def restore_transient_widget_state(root: QWidget, state: dict[str, dict[str, object]]) -> None:
    """Restore captured state with widget signals blocked."""
    index = widget_index(root)
    focus_widget: QWidget | None = None
    for selector, payload in state.items():
        widget = index.get(selector)
        if widget is None:
            continue
        previous = widget.blockSignals(True)
        try:
            if isinstance(widget, QLineEdit) and "text" in payload:
                widget.setText(str(payload["text"]))
                widget.setCursorPosition(min(len(widget.text()), int(payload.get("cursor", 0))))
            elif isinstance(widget, QPlainTextEdit) and "text" in payload:
                widget.setPlainText(str(payload["text"]))
                widget.verticalScrollBar().setValue(int(payload.get("scroll", 0)))
            elif isinstance(widget, QComboBox) and "index" in payload:
                old_text = str(payload.get("text", ""))
                text_index = widget.findText(old_text)
                widget.setCurrentIndex(text_index if text_index >= 0 else int(payload["index"]))
            elif isinstance(widget, (QSpinBox, QDoubleSpinBox)) and "value" in payload:
                widget.setValue(payload["value"])
            elif isinstance(widget, QAbstractButton) and "checked" in payload:
                widget.setChecked(bool(payload["checked"]))
            elif isinstance(widget, QAbstractSlider) and "value" in payload:
                widget.setValue(int(payload["value"]))
            elif isinstance(widget, QSplitter) and "sizes" in payload:
                widget.setSizes([int(value) for value in payload["sizes"]])
            elif isinstance(widget, QTabWidget) and "index" in payload:
                widget.setCurrentIndex(max(0, min(int(payload["index"]), widget.count() - 1)))
            if payload.get("focus"):
                focus_widget = widget
        finally:
            widget.blockSignals(previous)
    if focus_widget is not None:
        focus_widget.setFocus(Qt.OtherFocusReason)


def _set_widget_text(widget: QWidget, text: str) -> None:
    if isinstance(widget, (QLabel, QPushButton, QLineEdit)):
        widget.setText(text)
    elif isinstance(widget, QPlainTextEdit):
        widget.setPlainText(text)
    elif isinstance(widget, QComboBox):
        widget.addItems([part.strip() for part in text.split("|") if part.strip()] or ["항목"])
    elif isinstance(widget, QProgressBar):
        try:
            widget.setValue(int(text))
        except ValueError:
            widget.setValue(50)


def create_widget(spec: NewWidgetSpec, parent: QWidget, palette: dict[str, str]) -> QWidget:
    widget_types = {
        "QLabel": QLabel,
        "QPushButton": QPushButton,
        "QFrame": QFrame,
        "QLineEdit": QLineEdit,
        "QComboBox": QComboBox,
        "QProgressBar": QProgressBar,
        "QPlainTextEdit": QPlainTextEdit,
    }
    widget = widget_types[spec.widget_type](parent)
    widget.setObjectName(spec.object_name or f"studio_{spec.widget_id}")
    widget.setProperty("uiStudioWidgetId", spec.widget_id)
    _set_widget_text(widget, spec.text)
    x, y, width, height = (list(spec.geometry) + [20, 20, 180, 48])[:4]
    widget.setGeometry(int(x), int(y), max(1, int(width)), max(1, int(height)))
    style = spec.style_sheet
    if spec.palette_token and spec.palette_token in palette:
        style = f"background-color: {palette[spec.palette_token]};\n{style}"
    widget.setStyleSheet(style)
    widget.show()
    return widget


def apply_ui_design_spec(
    root: QWidget,
    spec: UIDesignSpec,
    *,
    play_animations: bool = False,
) -> dict[str, QWidget]:
    # UCS v2 is deliberately design-only. It no longer inserts widgets or
    # changes runtime geometry/layout/visibility. Resolve only explicit legacy
    # selectors so a small design spec does not scan tens of thousands of
    # data-backed widgets during Planner startup.
    selectors = set(spec.components)
    index = targeted_widget_index(root, selectors)
    _apply_gallery_styles(root, spec)
    for selector, override in spec.components.items():
        widget = index.get(selector)
        if widget is None:
            continue
        if override.style_sheet is not None:
            widget.setStyleSheet(override.style_sheet)
    from gui.diagonal_shape import apply_diagonal_shapes
    apply_diagonal_shapes(root, spec, index)
    return index
