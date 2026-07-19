"""Data-only bridge for the Qt Quick UI Component Studio."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QObject, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication

from gui.quick.design_registry import (
    QML_SELECTOR_PREFIX,
    QUICK_CONTROL_TARGETS,
    QUICK_COMPONENT_TARGETS,
    QUICK_DELEGATE_TARGETS,
    QUICK_ELEMENT_TARGETS,
    QUICK_OVERLAY_TARGETS,
    QUICK_SURFACE_TOKENS,
    quick_override_issues,
    resolve_quick_component,
    resolve_quick_control,
    resolve_quick_delegate,
    resolve_quick_element,
    resolve_quick_overlay,
)
from gui.ui_design_spec import (
    ComponentOverride,
    DEFAULT_PALETTE,
    DEFAULT_TYPOGRAPHY,
    DiagonalShapeSpec,
    UI_DESIGN_SPEC_PATH,
    UIDesignSpec,
    load_ui_design_spec,
    save_ui_design_spec,
)


class QuickStudioController(QObject):
    changed = Signal()
    statusChanged = Signal()

    def __init__(self, spec_path: Path = UI_DESIGN_SPEC_PATH, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._spec_path = Path(spec_path)
        self._spec = UIDesignSpec()
        self._entries: list[dict[str, object]] = []
        self._status = ""
        self.reload()

    @property
    def spec_path(self) -> Path:
        return self._spec_path

    @Property("QVariantMap", notify=changed)
    def palette(self) -> dict[str, str]:
        return dict(self._spec.palette)

    @Property("QVariantMap", notify=changed)
    def typography(self) -> dict[str, int]:
        return dict(self._spec.typography)

    @Property("QVariantList", notify=changed)
    def entries(self) -> list[dict[str, object]]:
        return list(self._entries)

    @Property(int, notify=changed)
    def entryCount(self) -> int:
        return len(self._entries)

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Slot(str)
    def copyText(self, value: str) -> None:
        text = str(value or "")
        clipboard = QGuiApplication.clipboard()
        if clipboard is not None:
            clipboard.setText(text)
        self._status = "경로를 클립보드에 복사했습니다." if text else "복사할 경로가 없습니다."
        self.statusChanged.emit()

    def _rebuild_entries(self) -> None:
        entries: list[dict[str, object]] = []
        for target in QUICK_COMPONENT_TARGETS:
            component = self._spec.components.get(target.selector)
            resolved = resolve_quick_component(target, component)
            entries.append({
                "entryId": target.selector,
                "title": target.title,
                "kind": "qml_component",
                "widgetType": "PlannerPanel",
                "styleSheet": "",
                "shapeMode": "cut" if resolved["diagonalEdge"] != "none" else "none",
                "shapeEdge": resolved["diagonalEdge"],
                "shapeAngle": resolved["diagonalAngle"],
                "shapeDirection": resolved["diagonalDirection"],
                "shapeDepth": 0,
                "elevation": resolved["elevation"],
                "contentSafeMargin": resolved["contentSafeMargin"],
                "preferredWidth": resolved["preferredWidth"],
                "preferredHeight": resolved["preferredHeight"],
                "paddingLeft": resolved["contentPadding"][0],
                "paddingTop": resolved["contentPadding"][1],
                "paddingRight": resolved["contentPadding"][2],
                "paddingBottom": resolved["contentPadding"][3],
                "variant": resolved["variant"],
                "radius": resolved["radius"],
                "borderWidth": resolved["borderWidth"],
                "contentSpacing": resolved["contentSpacing"],
                "isOverride": resolved["isOverride"],
            })
        for target in QUICK_CONTROL_TARGETS:
            component = self._spec.components.get(target.selector)
            resolved = resolve_quick_control(target, component)
            entries.append({
                "entryId": target.selector,
                "title": target.title,
                "kind": "qml_control",
                "widgetType": "QuickControl",
                "preferredWidth": resolved["preferredWidth"],
                "preferredHeight": resolved["preferredHeight"],
                "radius": resolved["radius"],
                "borderWidth": resolved["borderWidth"],
                "normalSurface": resolved["normalSurface"],
                "hoverSurface": resolved["hoverSurface"],
                "activeSurface": resolved["activeSurface"],
                "pressedSurface": resolved["pressedSurface"],
                "isOverride": resolved["isOverride"],
                "shapeMode": "none",
                "shapeEdge": "none",
                "shapeAngle": 80,
                "shapeDepth": 0,
            })
        for target in QUICK_OVERLAY_TARGETS:
            component = self._spec.components.get(target.selector)
            resolved = resolve_quick_overlay(target, component)
            entries.append({
                "entryId": target.selector,
                "title": target.title,
                "kind": "qml_overlay",
                "widgetType": "PlannerPopup",
                "preferredWidth": resolved["preferredWidth"],
                "preferredHeight": resolved["preferredHeight"],
                "padding": resolved["padding"],
                "radius": resolved["radius"],
                "borderWidth": resolved["borderWidth"],
                "surface": resolved["surface"],
                "borderSurface": resolved["borderSurface"],
                "scrimSurface": resolved["scrimSurface"],
                "scrimOpacityPercent": round(float(resolved["scrimOpacity"]) * 100),
                "isOverride": resolved["isOverride"],
                "shapeMode": "none",
                "shapeEdge": "none",
                "shapeAngle": 80,
                "shapeDepth": 0,
            })
        for target in QUICK_DELEGATE_TARGETS:
            component = self._spec.components.get(target.selector)
            resolved = resolve_quick_delegate(target, component)
            entries.append({
                "entryId": target.selector,
                "title": target.title,
                "kind": "qml_delegate",
                "widgetType": "PlannerDelegateSurface",
                "preferredHeight": resolved["preferredHeight"],
                "paddingLeft": resolved["contentPadding"][0],
                "paddingTop": resolved["contentPadding"][1],
                "paddingRight": resolved["contentPadding"][2],
                "paddingBottom": resolved["contentPadding"][3],
                "radius": resolved["radius"],
                "borderWidth": resolved["borderWidth"],
                "normalSurface": resolved["normalSurface"],
                "alternateSurface": resolved["alternateSurface"],
                "selectedSurface": resolved["selectedSurface"],
                "borderSurface": resolved["borderSurface"],
                "selectedBorderSurface": resolved["selectedBorderSurface"],
                "isOverride": resolved["isOverride"],
                "shapeMode": "none",
                "shapeEdge": "none",
                "shapeAngle": 80,
                "shapeDepth": 0,
            })
        for target in QUICK_ELEMENT_TARGETS:
            component = self._spec.components.get(target.selector)
            resolved = resolve_quick_element(target, component)
            entries.append({
                "entryId": target.selector,
                "title": target.title,
                "kind": "qml_element",
                "widgetType": "PlannerElementSurface",
                "preferredWidth": resolved["preferredWidth"],
                "preferredHeight": resolved["preferredHeight"],
                "radius": resolved["radius"],
                "borderWidth": resolved["borderWidth"],
                "surface": resolved["surface"],
                "borderSurface": resolved["borderSurface"],
                "opacityPercent": round(float(resolved["opacity"]) * 100),
                "isOverride": resolved["isOverride"],
                "shapeMode": "none",
                "shapeEdge": "none",
                "shapeAngle": 80,
                "shapeDepth": 0,
            })
        for selector, component in sorted(self._spec.components.items()):
            if selector.startswith(QML_SELECTOR_PREFIX):
                continue
            shape = component.diagonal_shape
            entries.append({
                "entryId": selector,
                "title": selector.rsplit("/", 1)[-1],
                "kind": "component",
                "widgetType": selector.rsplit("/", 1)[-1].split("#", 1)[0],
                "styleSheet": component.style_sheet or "",
                "shapeMode": shape.mode if shape else "none",
                "shapeEdge": shape.edge if shape else "right",
                "shapeAngle": shape.angle_degrees if shape else 80.0,
                "shapeDepth": shape.depth if shape else 24,
                "shapeDirection": shape.direction if shape else "forward",
                "elevation": 0,
                "contentSafeMargin": shape.content_safe_margin if shape else 0,
                "isOverride": True,
            })
        for gallery_id, style in sorted(self._spec.gallery_styles.items()):
            shape = style.diagonal_shape
            entries.append({
                "entryId": gallery_id,
                "title": style.title,
                "kind": "gallery",
                "widgetType": style.widget_type,
                "styleSheet": style.style_sheet,
                "shapeMode": shape.mode if shape else "none",
                "shapeEdge": shape.edge if shape else "right",
                "shapeAngle": shape.angle_degrees if shape else 80.0,
                "shapeDepth": shape.depth if shape else 24,
                "shapeDirection": shape.direction if shape else "forward",
                "elevation": 0,
                "contentSafeMargin": shape.content_safe_margin if shape else 0,
                "isOverride": True,
            })
        self._entries = entries

    @Slot()
    def reload(self) -> None:
        self._spec = load_ui_design_spec(self._spec_path)
        self._rebuild_entries()
        self._status = f"디자인 명세 {len(self._entries):,}개 항목을 다시 읽었습니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str, str)
    def setPalette(self, key: str, value: str) -> None:
        normalized_key = str(key or "")
        normalized_value = str(value or "").strip().lower()
        if normalized_key not in DEFAULT_PALETTE or len(normalized_value) not in {7, 9} or not normalized_value.startswith("#"):
            self._status = "색상은 #RRGGBB 또는 #AARRGGBB 형식이어야 합니다."
            self.statusChanged.emit()
            return
        try:
            int(normalized_value[1:], 16)
        except ValueError:
            self._status = "올바른 16진수 색상이 아닙니다."
            self.statusChanged.emit()
            return
        self._spec.palette[normalized_key] = normalized_value
        self.changed.emit()

    @Slot(str, int)
    def setTypography(self, key: str, value: int) -> None:
        normalized_key = str(key or "")
        if normalized_key not in DEFAULT_TYPOGRAPHY:
            self._status = "등록되지 않은 타이포그래피 토큰입니다."
            self.statusChanged.emit()
            return
        self._spec.typography[normalized_key] = min(72, max(8, int(value)))
        self._status = "타이포그래피 미리보기 값을 적용했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str, str, str, float, int)
    def setShape(self, entry_id: str, mode: str, edge: str, angle: float, depth: int) -> None:
        component = self._spec.components.get(str(entry_id))
        if component is None:
            self._status = "컴포넌트 명세 항목만 형태를 편집할 수 있습니다."
            self.statusChanged.emit()
            return
        shape = component.diagonal_shape or DiagonalShapeSpec()
        shape.mode = "extend" if mode == "extend" else "cut"
        shape.edge = edge if edge in {"left", "right", "both"} else "right"
        shape.angle_degrees = max(5.0, min(175.0, float(angle)))
        shape.depth = max(0, min(400, int(depth)))
        component.diagonal_shape = shape
        self._rebuild_entries()
        self.changed.emit()

    @Slot(str, str, float, str, float, int)
    def setQuickShape(
        self,
        entry_id: str,
        edge: str,
        angle: float,
        direction: str,
        elevation: float,
        content_safe_margin: int,
    ) -> None:
        selector = str(entry_id or "")
        target = next((item for item in QUICK_COMPONENT_TARGETS if item.selector == selector), None)
        if target is None:
            self._status = "등록되지 않은 QML 컴포넌트입니다."
            self.statusChanged.emit()
            return
        resolved_edge = str(edge or "none").lower()
        if resolved_edge not in {"none", "left", "right", "top", "bottom"}:
            self._status = "QML edge는 none/left/right/top/bottom 중 하나여야 합니다."
            self.statusChanged.emit()
            return
        resolved_direction = str(direction or "forward").lower()
        if resolved_direction not in {"forward", "reverse"}:
            self._status = "direction은 forward 또는 reverse여야 합니다."
            self.statusChanged.emit()
            return
        component = self._spec.components.get(selector) or ComponentOverride(selector=selector)
        component.qml_shape_enabled = resolved_edge != "none"
        component.elevation = min(4.0, max(0.0, float(elevation)))
        component.content_safe_margin = min(200, max(0, int(content_safe_margin)))
        if resolved_edge == "none":
            component.diagonal_shape = None
        else:
            component.diagonal_shape = DiagonalShapeSpec(
                mode="cut",
                edge=resolved_edge,
                angle_degrees=min(89.5, max(5.0, float(angle))),
                direction=resolved_direction,
                depth_mode="angle",
                radius=18,
                round_start=True,
                round_end=True,
                content_safe_margin=component.content_safe_margin,
                hit_mask=False,
            )
        self._spec.components[selector] = component
        self._rebuild_entries()
        self._status = "QML 미리보기 값을 적용했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str, int, int, int, int)
    def setQuickLayout(
        self,
        entry_id: str,
        preferred_width: int,
        preferred_height: int,
        horizontal_padding: int,
        vertical_padding: int,
    ) -> None:
        selector = str(entry_id or "")
        if not any(item.selector == selector for item in QUICK_COMPONENT_TARGETS):
            self._status = "등록되지 않은 QML 컴포넌트입니다."
            self.statusChanged.emit()
            return
        component = self._spec.components.get(selector) or ComponentOverride(selector=selector)
        width = min(1920, max(0, int(preferred_width)))
        height = min(1080, max(0, int(preferred_height)))
        horizontal = min(120, max(0, int(horizontal_padding)))
        vertical = min(120, max(0, int(vertical_padding)))
        component.qml_preferred_size = [width, height]
        component.qml_content_padding = [horizontal, vertical, horizontal, vertical]
        self._spec.components[selector] = component
        self._rebuild_entries()
        self._status = "QML 레이아웃 미리보기 값을 적용했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str, str, int, int, int)
    def setQuickStyle(
        self,
        entry_id: str,
        variant: str,
        radius: int,
        border_width: int,
        content_spacing: int,
    ) -> None:
        selector = str(entry_id or "")
        if not any(item.selector == selector for item in QUICK_COMPONENT_TARGETS):
            self._status = "등록되지 않은 QML 컴포넌트입니다."
            self.statusChanged.emit()
            return
        resolved_variant = str(variant or "panel").lower()
        if resolved_variant not in {"panel", "alt", "raised", "selected"}:
            self._status = "variant는 panel/alt/raised/selected 중 하나여야 합니다."
            self.statusChanged.emit()
            return
        component = self._spec.components.get(selector) or ComponentOverride(selector=selector)
        component.qml_variant = resolved_variant
        component.qml_radius = min(64.0, max(0.0, float(radius)))
        component.qml_border_width = min(6.0, max(0.0, float(border_width)))
        component.qml_content_spacing = min(64, max(0, int(content_spacing)))
        self._spec.components[selector] = component
        self._rebuild_entries()
        self._status = "QML 표면 스타일 미리보기 값을 적용했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str, int, int, int, int, str, str, str, str)
    def setQuickControlStyle(
        self,
        entry_id: str,
        preferred_width: int,
        preferred_height: int,
        radius: int,
        border_width: int,
        normal_surface: str,
        hover_surface: str,
        active_surface: str,
        pressed_surface: str,
    ) -> None:
        selector = str(entry_id or "")
        if not any(item.selector == selector for item in QUICK_CONTROL_TARGETS):
            self._status = "등록되지 않은 QML 컨트롤 스타일입니다."
            self.statusChanged.emit()
            return
        surfaces = [str(value or "") for value in (normal_surface, hover_surface, active_surface, pressed_surface)]
        if any(value not in QUICK_SURFACE_TOKENS for value in surfaces):
            self._status = "지원하지 않는 컨트롤 표면 토큰입니다."
            self.statusChanged.emit()
            return
        component = self._spec.components.get(selector) or ComponentOverride(selector=selector)
        component.qml_preferred_size = [
            min(120, max(0, int(preferred_width))),
            min(120, max(0, int(preferred_height))),
        ]
        component.qml_radius = min(40.0, max(0.0, float(radius)))
        component.qml_border_width = min(6.0, max(0.0, float(border_width)))
        component.qml_normal_surface = surfaces[0]
        component.qml_hover_surface = surfaces[1]
        component.qml_active_surface = surfaces[2]
        component.qml_pressed_surface = surfaces[3]
        self._spec.components[selector] = component
        self._rebuild_entries()
        self._status = "QML 컨트롤 스타일 미리보기 값을 적용했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str, int, int, int, int, int, str, str, str, int)
    def setQuickOverlayStyle(
        self,
        entry_id: str,
        preferred_width: int,
        preferred_height: int,
        padding: int,
        radius: int,
        border_width: int,
        surface: str,
        border_surface: str,
        scrim_surface: str,
        scrim_opacity_percent: int,
    ) -> None:
        selector = str(entry_id or "")
        if not any(item.selector == selector for item in QUICK_OVERLAY_TARGETS):
            self._status = "등록되지 않은 QML 오버레이 스타일입니다."
            self.statusChanged.emit()
            return
        surfaces = [str(value or "") for value in (surface, border_surface, scrim_surface)]
        if any(value not in QUICK_SURFACE_TOKENS for value in surfaces):
            self._status = "지원하지 않는 오버레이 표면 토큰입니다."
            self.statusChanged.emit()
            return
        component = self._spec.components.get(selector) or ComponentOverride(selector=selector)
        component.qml_preferred_size = [
            min(1920, max(0, int(preferred_width))),
            min(1080, max(0, int(preferred_height))),
        ]
        safe_padding = min(120, max(0, int(padding)))
        component.qml_content_padding = [safe_padding] * 4
        component.qml_radius = min(64.0, max(0.0, float(radius)))
        component.qml_border_width = min(6.0, max(0.0, float(border_width)))
        component.qml_surface = surfaces[0]
        component.qml_border_surface = surfaces[1]
        component.qml_scrim_surface = surfaces[2]
        component.qml_scrim_opacity = min(1.0, max(0.0, int(scrim_opacity_percent) / 100.0))
        self._spec.components[selector] = component
        self._rebuild_entries()
        self._status = "QML 오버레이 스타일 미리보기 값을 적용했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str, int, int, int, int, int, int, int, str, str, str, str, str)
    def setQuickDelegateStyle(
        self,
        entry_id: str,
        preferred_height: int,
        padding_left: int,
        padding_top: int,
        padding_right: int,
        padding_bottom: int,
        radius: int,
        border_width: int,
        normal_surface: str,
        alternate_surface: str,
        selected_surface: str,
        border_surface: str,
        selected_border_surface: str,
    ) -> None:
        selector = str(entry_id or "")
        if not any(item.selector == selector for item in QUICK_DELEGATE_TARGETS):
            self._status = "등록되지 않은 QML 반복 표면 스타일입니다."
            self.statusChanged.emit()
            return
        surfaces = [
            str(value or "") for value in (
                normal_surface, alternate_surface, selected_surface,
                border_surface, selected_border_surface,
            )
        ]
        if any(value not in QUICK_SURFACE_TOKENS for value in surfaces):
            self._status = "지원하지 않는 반복 표면 토큰입니다."
            self.statusChanged.emit()
            return
        component = self._spec.components.get(selector) or ComponentOverride(selector=selector)
        component.qml_preferred_size = [0, min(320, max(32, int(preferred_height)))]
        component.qml_content_padding = [
            min(120, max(0, int(value)))
            for value in (padding_left, padding_top, padding_right, padding_bottom)
        ]
        component.qml_radius = min(64.0, max(0.0, float(radius)))
        component.qml_border_width = min(6.0, max(0.0, float(border_width)))
        component.qml_normal_surface = surfaces[0]
        component.qml_alternate_surface = surfaces[1]
        component.qml_selected_surface = surfaces[2]
        component.qml_border_surface = surfaces[3]
        component.qml_selected_border_surface = surfaces[4]
        self._spec.components[selector] = component
        self._rebuild_entries()
        self._status = "QML 반복 표면 미리보기 값을 적용했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str, int, int, int, int, int, str, str)
    def setQuickElementStyle(
        self,
        entry_id: str,
        preferred_width: int,
        preferred_height: int,
        radius: int,
        border_width: int,
        opacity_percent: int,
        surface: str,
        border_surface: str,
    ) -> None:
        selector = str(entry_id or "")
        if not any(item.selector == selector for item in QUICK_ELEMENT_TARGETS):
            self._status = "등록되지 않은 QML 내부 요소 스타일입니다."
            self.statusChanged.emit()
            return
        surfaces = [str(value or "") for value in (surface, border_surface)]
        if any(value not in QUICK_SURFACE_TOKENS for value in surfaces):
            self._status = "지원하지 않는 내부 요소 표면 토큰입니다."
            self.statusChanged.emit()
            return
        component = self._spec.components.get(selector) or ComponentOverride(selector=selector)
        component.qml_preferred_size = [
            min(640, max(0, int(preferred_width))),
            min(640, max(0, int(preferred_height))),
        ]
        component.qml_radius = min(64.0, max(0.0, float(radius)))
        component.qml_border_width = min(6.0, max(0.0, float(border_width)))
        component.qml_opacity = min(1.0, max(0.0, int(opacity_percent) / 100.0))
        component.qml_surface = surfaces[0]
        component.qml_border_surface = surfaces[1]
        self._spec.components[selector] = component
        self._rebuild_entries()
        self._status = "QML 내부 요소 미리보기 값을 적용했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot(str)
    def resetQuickComponent(self, entry_id: str) -> None:
        selector = str(entry_id or "")
        if not selector.startswith(QML_SELECTOR_PREFIX):
            self._status = "QML 컴포넌트만 기본값으로 복원할 수 있습니다."
            self.statusChanged.emit()
            return
        self._spec.components.pop(selector, None)
        self._rebuild_entries()
        self._status = "QML 컴포넌트를 코드 기본값으로 복원했습니다. 디자인 저장 후 Viewer에 반영됩니다."
        self.changed.emit()
        self.statusChanged.emit()

    @Slot()
    def save(self) -> None:
        issues = quick_override_issues(self._spec)
        if issues:
            first_selector = next(iter(issues))
            self._status = f"저장 거부 · {first_selector}: {issues[first_selector][0]}"
            self.statusChanged.emit()
            return
        save_ui_design_spec(self._spec, self._spec_path)
        self._status = f"{self._spec_path.name}에 저장했습니다."
        self.statusChanged.emit()
