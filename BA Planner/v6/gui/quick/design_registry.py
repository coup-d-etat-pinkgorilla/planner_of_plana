"""Stable QML design targets shared by the Viewer and Quick Component Studio."""

from __future__ import annotations

from dataclasses import dataclass

from gui.ui_design_spec import ComponentOverride, UIDesignSpec


QML_SELECTOR_PREFIX = "qml/"


@dataclass(frozen=True, slots=True)
class QuickComponentTarget:
    key: str
    title: str
    diagonal_edge: str = "none"
    diagonal_angle: float = 80.0
    diagonal_direction: str = "forward"
    elevation: float = 3.0
    content_safe_margin: int = 8
    preferred_width: int = 0
    preferred_height: int = 0
    content_padding: tuple[int, int, int, int] = (0, 0, 0, 0)
    variant: str = "panel"
    radius: float = 18.0
    border_width: float = 1.0
    content_spacing: int = 0

    @property
    def selector(self) -> str:
        return QML_SELECTOR_PREFIX + self.key


@dataclass(frozen=True, slots=True)
class QuickControlTarget:
    key: str
    title: str
    preferred_width: int
    preferred_height: int
    radius: float
    border_width: float
    normal_surface: str
    hover_surface: str
    active_surface: str
    pressed_surface: str

    @property
    def selector(self) -> str:
        return QML_SELECTOR_PREFIX + self.key


@dataclass(frozen=True, slots=True)
class QuickOverlayTarget:
    key: str
    title: str
    preferred_width: int
    preferred_height: int
    padding: int
    radius: float
    border_width: float
    surface: str
    border_surface: str
    scrim_surface: str
    scrim_opacity: float

    @property
    def selector(self) -> str:
        return QML_SELECTOR_PREFIX + self.key


@dataclass(frozen=True, slots=True)
class QuickDelegateTarget:
    key: str
    title: str
    preferred_height: int
    content_padding: tuple[int, int, int, int]
    radius: float
    border_width: float
    normal_surface: str
    alternate_surface: str
    selected_surface: str
    border_surface: str
    selected_border_surface: str

    @property
    def selector(self) -> str:
        return QML_SELECTOR_PREFIX + self.key


@dataclass(frozen=True, slots=True)
class QuickElementTarget:
    key: str
    title: str
    preferred_width: int
    preferred_height: int
    radius: float
    border_width: float
    surface: str
    border_surface: str
    opacity: float

    @property
    def selector(self) -> str:
        return QML_SELECTOR_PREFIX + self.key


QUICK_COMPONENT_TARGETS = (
    QuickComponentTarget("main/header", "메인 내비게이션 헤더", preferred_height=62, variant="alt", content_spacing=8, radius=5),
    QuickComponentTarget("main/profile", "메인 프로필 패널", elevation=2.0, preferred_width=250, preferred_height=54, variant="raised", radius=12),
    QuickComponentTarget("home/menu", "홈 · 메인 메뉴", preferred_width=560, diagonal_edge="right", diagonal_angle=80, content_safe_margin=18, content_spacing=10, radius=7),
    QuickComponentTarget("home/header-active", "홈 · 활성 헤더 영역", variant="selected", diagonal_edge="right", diagonal_angle=80, content_safe_margin=18, radius=5),
    QuickComponentTarget("home/header-content", "홈 · 인사말 헤더", variant="raised", diagonal_edge="right", diagonal_angle=80, content_safe_margin=18, radius=14),
    QuickComponentTarget("home/header-connector", "홈 · 활성 탭 연결부", variant="selected", radius=0, elevation=0),
    QuickComponentTarget("home/scan", "홈 · 스캔 제어", preferred_width=560, diagonal_edge="left", diagonal_angle=80, content_safe_margin=18, content_spacing=16, radius=7),
    QuickComponentTarget("home/connection", "홈 · 창 연결", preferred_width=560, variant="alt", diagonal_edge="left", diagonal_angle=80, content_safe_margin=18, content_spacing=12, radius=7),
    QuickComponentTarget("students/header", "학생 · 헤더", diagonal_edge="right", preferred_height=174, content_spacing=10),
    QuickComponentTarget("students/body", "학생 · 본문", variant="alt", content_spacing=12),
    QuickComponentTarget("plan/header", "플랜 · 헤더", diagonal_edge="right", preferred_height=154, content_spacing=6),
    QuickComponentTarget("plan/body", "플랜 · 본문", variant="alt", content_spacing=12),
    QuickComponentTarget("inventory/header", "인벤토리 · 헤더", diagonal_edge="right", preferred_height=104, content_spacing=16),
    QuickComponentTarget("inventory/body", "인벤토리 · 본문", variant="alt", content_spacing=8),
    QuickComponentTarget("tactical/input", "전술대항전 · 입력", preferred_width=610, content_spacing=12),
    QuickComponentTarget("tactical/history", "전술대항전 · 기록", variant="alt", content_spacing=8),
    QuickComponentTarget("statistics/header", "통계 · 헤더", diagonal_edge="right", preferred_height=140, content_spacing=8),
    QuickComponentTarget("statistics/body", "통계 · 본문", variant="alt", content_spacing=6),
    QuickComponentTarget("settings/account", "설정 · 계정", preferred_width=720, content_spacing=18),
    QuickComponentTarget("settings/window", "설정 · 창 연결", variant="alt", content_spacing=18),
)
QUICK_COMPONENT_TARGET_BY_KEY = {target.key: target for target in QUICK_COMPONENT_TARGETS}

QUICK_CONTROL_TARGETS = (
    QuickControlTarget("controls/button", "컨트롤 · 버튼", 0, 54, 8, 1, "panel", "panelRaised", "accent", "accentStrong"),
    QuickControlTarget("controls/input", "컨트롤 · 텍스트 입력", 0, 48, 8, 1, "backgroundDeep", "panelRaised", "panelRaised", "panelRaised"),
    QuickControlTarget("controls/combo", "컨트롤 · 콤보박스", 0, 48, 8, 1, "backgroundDeep", "panelRaised", "panelRaised", "accentStrong"),
    QuickControlTarget("controls/checkbox", "컨트롤 · 체크박스", 24, 24, 6, 1, "backgroundDeep", "panelRaised", "accent", "accentStrong"),
    QuickControlTarget("controls/scrollbar", "컨트롤 · 스크롤바", 10, 0, 5, 0, "border", "accent", "accent", "accentStrong"),
    QuickControlTarget("controls/progress", "컨트롤 · 진행 표시줄", 0, 12, 6, 1, "backgroundDeep", "accent", "accent", "accentStrong"),
)
QUICK_CONTROL_TARGET_BY_KEY = {target.key: target for target in QUICK_CONTROL_TARGETS}
QUICK_OVERLAY_TARGETS = (
    QuickOverlayTarget("overlays/dialog", "오버레이 · 대화상자", 0, 0, 12, 18, 2, "panelAlt", "accent", "backgroundDeep", 0.5),
    QuickOverlayTarget("overlays/dropdown", "오버레이 · 드롭다운", 0, 360, 4, 8, 1, "panelAlt", "border", "backgroundDeep", 0.0),
)
QUICK_OVERLAY_TARGET_BY_KEY = {target.key: target for target in QUICK_OVERLAY_TARGETS}
QUICK_DELEGATE_TARGETS = (
    QuickDelegateTarget("delegates/student-card", "반복 표면 · 학생 카드", 226, (10, 10, 10, 10), 14, 1, "panel", "panel", "surfaceSelected", "border", "accent"),
    QuickDelegateTarget("delegates/inventory-row", "반복 표면 · 인벤토리 행", 82, (14, 0, 18, 0), 8, 1, "panel", "panelRaised", "panel", "border", "border"),
    QuickDelegateTarget("delegates/plan-row", "반복 표면 · 플랜 행", 112, (12, 12, 12, 12), 12, 1, "panelRaised", "panelRaised", "panelRaised", "border", "border"),
    QuickDelegateTarget("delegates/home-window-row", "반복 표면 · 창 후보 행", 62, (10, 10, 10, 10), 9, 1, "panel", "panel", "surfaceSelected", "border", "accent"),
    QuickDelegateTarget("delegates/plan-resource-row", "반복 표면 · 플랜 재화 행", 58, (10, 10, 10, 10), 8, 0, "panelRaised", "panelRaised", "panelRaised", "border", "border"),
    QuickDelegateTarget("delegates/tactical-jokbo-row", "반복 표면 · 전술 족보 행", 78, (9, 9, 9, 9), 8, 0, "panelRaised", "panelRaised", "panelRaised", "border", "border"),
    QuickDelegateTarget("delegates/tactical-match-row", "반복 표면 · 전술 전적 행", 106, (12, 12, 12, 12), 10, 0, "panelRaised", "panelRaised", "panelRaised", "border", "border"),
    QuickDelegateTarget("delegates/statistics-row", "반복 표면 · 통계 행", 58, (12, 12, 12, 12), 9, 0, "panelRaised", "panelRaised", "panelRaised", "border", "border"),
)
QUICK_DELEGATE_TARGET_BY_KEY = {target.key: target for target in QUICK_DELEGATE_TARGETS}
QUICK_ELEMENT_TARGETS = (
    QuickElementTarget("elements/student-portrait", "내부 요소 · 학생 초상 프레임", 0, 0, 10, 0, "backgroundDeep", "border", 1.0),
    QuickElementTarget("elements/student-status-badge", "내부 요소 · 학생 상태 배지", 0, 34, 0, 0, "backgroundDeep", "border", 0.78),
    QuickElementTarget("elements/inventory-icon", "내부 요소 · 인벤토리 아이콘", 58, 58, 10, 0, "backgroundDeep", "border", 1.0),
    QuickElementTarget("elements/plan-portrait", "내부 요소 · 플랜 초상 프레임", 82, 0, 9, 0, "backgroundDeep", "border", 1.0),
    QuickElementTarget("elements/statistics-meter", "내부 요소 · 통계 막대", 0, 12, 6, 0, "accent", "border", 1.0),
    QuickElementTarget("elements/student-detail-panel", "보조 표면 · 학생 상세 패널", 410, 0, 14, 1, "panel", "border", 1.0),
    QuickElementTarget("elements/plan-resource-summary", "보조 표면 · 플랜 재화 요약", 430, 0, 12, 1, "panel", "border", 1.0),
    QuickElementTarget("elements/statistics-summary-card", "보조 표면 · 통계 요약 카드", 230, 90, 12, 1, "panelAlt", "border", 1.0),
    QuickElementTarget("elements/divider", "내부 요소 · 구분선", 0, 1, 0, 0, "border", "border", 1.0),
    QuickElementTarget("elements/home-header-portrait", "홈 헤더 · 계정 초상", 188, 0, 10, 1, "backgroundDeep", "border", 1.0),
)
QUICK_ELEMENT_TARGET_BY_KEY = {target.key: target for target in QUICK_ELEMENT_TARGETS}
QUICK_SURFACE_TOKENS = {
    "backgroundDeep",
    "panel",
    "panelAlt",
    "panelRaised",
    "surfaceSelected",
    "accent",
    "accentStrong",
    "border",
    "danger",
}


def resolve_quick_component(target: QuickComponentTarget, override: ComponentOverride | None) -> dict[str, object]:
    shape = override.diagonal_shape if override is not None else None
    enabled = override.qml_shape_enabled if override is not None else None
    if enabled is False:
        edge = "none"
    elif shape is not None:
        edge = shape.edge if shape.edge in {"left", "right", "top", "bottom"} else target.diagonal_edge
    else:
        edge = target.diagonal_edge
    preferred_size = override.qml_preferred_size if override is not None and override.qml_preferred_size else None
    padding = override.qml_content_padding if override is not None and override.qml_content_padding else None
    return {
        "diagonalEdge": edge,
        "diagonalAngle": float(shape.angle_degrees if shape is not None else target.diagonal_angle),
        "diagonalDirection": str(shape.direction if shape is not None else target.diagonal_direction),
        "elevation": float(override.elevation if override is not None and override.elevation is not None else target.elevation),
        "contentSafeMargin": int(
            override.content_safe_margin
            if override is not None and override.content_safe_margin is not None
            else target.content_safe_margin
        ),
        "preferredWidth": int(preferred_size[0] if preferred_size and len(preferred_size) >= 2 else target.preferred_width),
        "preferredHeight": int(preferred_size[1] if preferred_size and len(preferred_size) >= 2 else target.preferred_height),
        "contentPadding": list(padding[:4] if padding and len(padding) >= 4 else target.content_padding),
        "variant": str(override.qml_variant if override is not None and override.qml_variant is not None else target.variant),
        "radius": float(override.qml_radius if override is not None and override.qml_radius is not None else target.radius),
        "borderWidth": float(override.qml_border_width if override is not None and override.qml_border_width is not None else target.border_width),
        "contentSpacing": int(override.qml_content_spacing if override is not None and override.qml_content_spacing is not None else target.content_spacing),
        "isOverride": override is not None,
    }


def resolve_quick_control(target: QuickControlTarget, override: ComponentOverride | None) -> dict[str, object]:
    preferred_size = override.qml_preferred_size if override is not None and override.qml_preferred_size else None
    return {
        "preferredWidth": int(preferred_size[0] if preferred_size and len(preferred_size) >= 2 else target.preferred_width),
        "preferredHeight": int(preferred_size[1] if preferred_size and len(preferred_size) >= 2 else target.preferred_height),
        "radius": float(override.qml_radius if override is not None and override.qml_radius is not None else target.radius),
        "borderWidth": float(override.qml_border_width if override is not None and override.qml_border_width is not None else target.border_width),
        "normalSurface": str(override.qml_normal_surface if override is not None and override.qml_normal_surface else target.normal_surface),
        "hoverSurface": str(override.qml_hover_surface if override is not None and override.qml_hover_surface else target.hover_surface),
        "activeSurface": str(override.qml_active_surface if override is not None and override.qml_active_surface else target.active_surface),
        "pressedSurface": str(override.qml_pressed_surface if override is not None and override.qml_pressed_surface else target.pressed_surface),
        "isOverride": override is not None,
    }


def resolve_quick_overlay(target: QuickOverlayTarget, override: ComponentOverride | None) -> dict[str, object]:
    preferred_size = override.qml_preferred_size if override is not None and override.qml_preferred_size else None
    padding = override.qml_content_padding if override is not None and override.qml_content_padding else None
    return {
        "preferredWidth": int(preferred_size[0] if preferred_size and len(preferred_size) >= 2 else target.preferred_width),
        "preferredHeight": int(preferred_size[1] if preferred_size and len(preferred_size) >= 2 else target.preferred_height),
        "padding": int(padding[0] if padding and len(padding) >= 4 else target.padding),
        "radius": float(override.qml_radius if override is not None and override.qml_radius is not None else target.radius),
        "borderWidth": float(override.qml_border_width if override is not None and override.qml_border_width is not None else target.border_width),
        "surface": str(override.qml_surface if override is not None and override.qml_surface else target.surface),
        "borderSurface": str(override.qml_border_surface if override is not None and override.qml_border_surface else target.border_surface),
        "scrimSurface": str(override.qml_scrim_surface if override is not None and override.qml_scrim_surface else target.scrim_surface),
        "scrimOpacity": float(override.qml_scrim_opacity if override is not None and override.qml_scrim_opacity is not None else target.scrim_opacity),
        "isOverride": override is not None,
    }


def resolve_quick_delegate(target: QuickDelegateTarget, override: ComponentOverride | None) -> dict[str, object]:
    preferred_size = override.qml_preferred_size if override is not None and override.qml_preferred_size else None
    padding = override.qml_content_padding if override is not None and override.qml_content_padding else None
    return {
        "preferredHeight": int(preferred_size[1] if preferred_size and len(preferred_size) >= 2 else target.preferred_height),
        "contentPadding": list(padding[:4] if padding and len(padding) >= 4 else target.content_padding),
        "radius": float(override.qml_radius if override is not None and override.qml_radius is not None else target.radius),
        "borderWidth": float(override.qml_border_width if override is not None and override.qml_border_width is not None else target.border_width),
        "normalSurface": str(override.qml_normal_surface if override is not None and override.qml_normal_surface else target.normal_surface),
        "alternateSurface": str(override.qml_alternate_surface if override is not None and override.qml_alternate_surface else target.alternate_surface),
        "selectedSurface": str(override.qml_selected_surface if override is not None and override.qml_selected_surface else target.selected_surface),
        "borderSurface": str(override.qml_border_surface if override is not None and override.qml_border_surface else target.border_surface),
        "selectedBorderSurface": str(
            override.qml_selected_border_surface
            if override is not None and override.qml_selected_border_surface
            else target.selected_border_surface
        ),
        "isOverride": override is not None,
    }


def resolve_quick_element(target: QuickElementTarget, override: ComponentOverride | None) -> dict[str, object]:
    preferred_size = override.qml_preferred_size if override is not None and override.qml_preferred_size else None
    return {
        "preferredWidth": int(preferred_size[0] if preferred_size and len(preferred_size) >= 2 else target.preferred_width),
        "preferredHeight": int(preferred_size[1] if preferred_size and len(preferred_size) >= 2 else target.preferred_height),
        "radius": float(override.qml_radius if override is not None and override.qml_radius is not None else target.radius),
        "borderWidth": float(override.qml_border_width if override is not None and override.qml_border_width is not None else target.border_width),
        "surface": str(override.qml_surface if override is not None and override.qml_surface else target.surface),
        "borderSurface": str(override.qml_border_surface if override is not None and override.qml_border_surface else target.border_surface),
        "opacity": float(override.qml_opacity if override is not None and override.qml_opacity is not None else target.opacity),
        "isOverride": override is not None,
    }


def build_quick_component_map(spec: UIDesignSpec) -> dict[str, dict[str, object]]:
    resolved: dict[str, dict[str, object]] = {}
    for target in QUICK_COMPONENT_TARGETS:
        override = spec.components.get(target.selector)
        if override is not None and validate_quick_component_override(target.selector, override):
            override = None
        resolved[target.key] = resolve_quick_component(target, override)
    for target in QUICK_CONTROL_TARGETS:
        override = spec.components.get(target.selector)
        if override is not None and validate_quick_component_override(target.selector, override):
            override = None
        resolved[target.key] = resolve_quick_control(target, override)
    for target in QUICK_OVERLAY_TARGETS:
        override = spec.components.get(target.selector)
        if override is not None and validate_quick_component_override(target.selector, override):
            override = None
        resolved[target.key] = resolve_quick_overlay(target, override)
    for target in QUICK_DELEGATE_TARGETS:
        override = spec.components.get(target.selector)
        if override is not None and validate_quick_component_override(target.selector, override):
            override = None
        resolved[target.key] = resolve_quick_delegate(target, override)
    for target in QUICK_ELEMENT_TARGETS:
        override = spec.components.get(target.selector)
        if override is not None and validate_quick_component_override(target.selector, override):
            override = None
        resolved[target.key] = resolve_quick_element(target, override)
    return resolved


def quick_override_issues(spec: UIDesignSpec) -> dict[str, list[str]]:
    return {
        selector: issues
        for selector, override in spec.components.items()
        if selector.startswith(QML_SELECTOR_PREFIX)
        if (issues := validate_quick_component_override(selector, override))
    }


def validate_quick_component_override(selector: str, override: ComponentOverride) -> list[str]:
    key = selector.removeprefix(QML_SELECTOR_PREFIX)
    is_panel = key in QUICK_COMPONENT_TARGET_BY_KEY
    is_control = key in QUICK_CONTROL_TARGET_BY_KEY
    is_overlay = key in QUICK_OVERLAY_TARGET_BY_KEY
    is_delegate = key in QUICK_DELEGATE_TARGET_BY_KEY
    is_element = key in QUICK_ELEMENT_TARGET_BY_KEY
    if not is_panel and not is_control and not is_overlay and not is_delegate and not is_element:
        return [f"알 수 없는 QML 컴포넌트 selector입니다: {selector}"]
    issues: list[str] = []
    shape = override.diagonal_shape
    if (is_control or is_overlay or is_delegate or is_element) and (override.qml_shape_enabled or shape is not None):
        issues.append("공통 컨트롤 스타일에는 대각선 형상을 적용할 수 없습니다.")
    if override.qml_shape_enabled and shape is None:
        issues.append("대각선 활성화 상태에 shape 값이 없습니다.")
    if shape is not None:
        if shape.mode != "cut":
            issues.append("QML 패널은 현재 cut 모드만 지원합니다.")
        if shape.edge not in {"left", "right", "top", "bottom"}:
            issues.append(f"지원하지 않는 edge입니다: {shape.edge}")
        if shape.direction not in {"forward", "reverse"}:
            issues.append(f"지원하지 않는 direction입니다: {shape.direction}")
        if not 5.0 <= float(shape.angle_degrees) <= 89.5:
            issues.append("angle_degrees는 5.0~89.5 범위여야 합니다.")
        if shape.seam_gap > 0 and shape.overlap > 0:
            issues.append("seam_gap과 overlap을 동시에 사용할 수 없습니다.")
        if shape.hit_mask:
            issues.append("QML 패널은 시각 절삭과 별개로 직사각형 히트 영역을 유지해야 합니다.")
    if override.elevation is not None and not 0.0 <= float(override.elevation) <= 4.0:
        issues.append("elevation은 0.0~4.0 범위여야 합니다.")
    if override.content_safe_margin is not None and not 0 <= int(override.content_safe_margin) <= 200:
        issues.append("content_safe_margin은 0~200 범위여야 합니다.")
    if override.qml_preferred_size is not None:
        size = override.qml_preferred_size
        if len(size) != 2 or not 0 <= int(size[0]) <= 1920 or not 0 <= int(size[1]) <= 1080:
            issues.append("qml_preferred_size는 [0~1920, 0~1080] 범위여야 합니다.")
    if override.qml_content_padding is not None:
        padding = override.qml_content_padding
        if len(padding) != 4 or any(not 0 <= int(value) <= 120 for value in padding):
            issues.append("qml_content_padding은 네 방향 모두 0~120 범위여야 합니다.")
    if override.qml_variant is not None and override.qml_variant not in {"panel", "alt", "raised", "selected"}:
        issues.append(f"지원하지 않는 qml_variant입니다: {override.qml_variant}")
    if override.qml_radius is not None and not 0.0 <= float(override.qml_radius) <= 64.0:
        issues.append("qml_radius는 0.0~64.0 범위여야 합니다.")
    if override.qml_border_width is not None and not 0.0 <= float(override.qml_border_width) <= 6.0:
        issues.append("qml_border_width는 0.0~6.0 범위여야 합니다.")
    if override.qml_content_spacing is not None and not 0 <= int(override.qml_content_spacing) <= 64:
        issues.append("qml_content_spacing은 0~64 범위여야 합니다.")
    for field_name, surface in (
        ("qml_normal_surface", override.qml_normal_surface),
        ("qml_hover_surface", override.qml_hover_surface),
        ("qml_active_surface", override.qml_active_surface),
        ("qml_pressed_surface", override.qml_pressed_surface),
        ("qml_surface", override.qml_surface),
        ("qml_border_surface", override.qml_border_surface),
        ("qml_scrim_surface", override.qml_scrim_surface),
        ("qml_alternate_surface", override.qml_alternate_surface),
        ("qml_selected_surface", override.qml_selected_surface),
        ("qml_selected_border_surface", override.qml_selected_border_surface),
    ):
        if surface is not None and surface not in QUICK_SURFACE_TOKENS:
            issues.append(f"{field_name}에 지원하지 않는 표면 토큰이 지정됐습니다: {surface}")
    if override.qml_scrim_opacity is not None and not 0.0 <= float(override.qml_scrim_opacity) <= 1.0:
        issues.append("qml_scrim_opacity는 0.0~1.0 범위여야 합니다.")
    if override.qml_opacity is not None and not 0.0 <= float(override.qml_opacity) <= 1.0:
        issues.append("qml_opacity는 0.0~1.0 범위여야 합니다.")
    return issues
