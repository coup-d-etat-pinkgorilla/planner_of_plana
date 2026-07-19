"""Shared UI design specification used by Planner and UI Component Studio."""

from __future__ import annotations

from dataclasses import dataclass, field
import json
from pathlib import Path
from typing import Any


BASE_DIR = Path(__file__).resolve().parents[1]
UI_DESIGN_SPEC_PATH = BASE_DIR / "gui" / "ui_design_spec.json"
DEFAULT_PALETTE = {
    "accent": "#f266b3",
    "soft": "#efe4f2",
    "panel": "#313b59",
    "panel_alt": "#2c3140",
    "text": "#f2f2f2",
}
DEFAULT_TYPOGRAPHY = {
    "font_caption": 14,
    "font_body": 18,
    "font_section": 24,
    "font_title": 34,
}
SUPPORTED_WIDGET_TYPES = (
    "QLabel",
    "QPushButton",
    "QFrame",
    "QLineEdit",
    "QComboBox",
    "QProgressBar",
    "QPlainTextEdit",
)


@dataclass
class DiagonalShapeSpec:
    mode: str = "cut"
    edge: str = "right"
    angle_degrees: float = 80.0
    direction: str = "forward"
    depth_mode: str = "angle"
    depth: int = 24
    radius: int = 7
    round_start: bool = True
    round_end: bool = True
    content_safe_margin: int = 24
    hit_mask: bool = True
    seam_gap: int = 0
    overlap: int = 0
    linked_selector: str = ""
    link_angle: bool = False
    link_direction: bool = False


@dataclass
class ComponentOverride:
    selector: str
    geometry: list[int] | None = None
    minimum_size: list[int] | None = None
    maximum_size: list[int] | None = None
    fixed_size: list[int] | None = None
    visible: bool | None = None
    enabled: bool | None = None
    style_sheet: str | None = None
    layout_margins: list[int] | None = None
    layout_spacing: int | None = None
    diagonal_shape: DiagonalShapeSpec | None = None
    qml_shape_enabled: bool | None = None
    elevation: float | None = None
    content_safe_margin: int | None = None
    qml_preferred_size: list[int] | None = None
    qml_content_padding: list[int] | None = None
    qml_variant: str | None = None
    qml_radius: float | None = None
    qml_border_width: float | None = None
    qml_content_spacing: int | None = None
    qml_normal_surface: str | None = None
    qml_hover_surface: str | None = None
    qml_active_surface: str | None = None
    qml_pressed_surface: str | None = None
    qml_surface: str | None = None
    qml_border_surface: str | None = None
    qml_scrim_surface: str | None = None
    qml_scrim_opacity: float | None = None
    qml_alternate_surface: str | None = None
    qml_selected_surface: str | None = None
    qml_selected_border_surface: str | None = None
    qml_opacity: float | None = None


@dataclass
class GalleryStyleSpec:
    """Design-only style edited from an isolated Studio sample card."""

    gallery_id: str
    title: str
    widget_type: str
    style_sheet: str = ""
    diagonal_shape: DiagonalShapeSpec | None = None


@dataclass
class NewWidgetSpec:
    widget_id: str
    parent_selector: str
    widget_type: str
    object_name: str
    text: str = ""
    geometry: list[int] = field(default_factory=lambda: [20, 20, 180, 48])
    style_sheet: str = ""
    palette_token: str = ""


@dataclass
class AnimationSpec:
    animation_id: str
    selector: str
    property_name: str = "pos"
    duration_ms: int = 450
    start_value: list[int] = field(default_factory=lambda: [0, 0])
    end_value: list[int] = field(default_factory=lambda: [120, 0])
    easing: str = "OutCubic"
    trigger: str = "manual"


@dataclass
class UIDesignSpec:
    version: int = 2
    palette: dict[str, str] = field(default_factory=lambda: dict(DEFAULT_PALETTE))
    typography: dict[str, int] = field(default_factory=lambda: dict(DEFAULT_TYPOGRAPHY))
    gallery_styles: dict[str, GalleryStyleSpec] = field(default_factory=dict)
    components: dict[str, ComponentOverride] = field(default_factory=dict)
    new_widgets: list[NewWidgetSpec] = field(default_factory=list)
    animations: list[AnimationSpec] = field(default_factory=list)


def _clean_color(value: object, fallback: str) -> str:
    text = str(value or "").strip().lower()
    if len(text) in {7, 9} and text.startswith("#"):
        try:
            int(text[1:], 16)
        except ValueError:
            return fallback
        return text
    return fallback


def load_ui_design_spec(path: Path = UI_DESIGN_SPEC_PATH) -> UIDesignSpec:
    if not path.exists():
        return UIDesignSpec()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError):
        return UIDesignSpec()
    if not isinstance(raw, dict):
        return UIDesignSpec()
    palette_raw = raw.get("palette")
    palette = {
        key: _clean_color((palette_raw or {}).get(key), fallback)
        for key, fallback in DEFAULT_PALETTE.items()
    }
    typography_raw = raw.get("typography")
    typography = {
        key: max(8, min(72, int((typography_raw or {}).get(key, fallback))))
        if str((typography_raw or {}).get(key, fallback)).lstrip("-").isdigit()
        else fallback
        for key, fallback in DEFAULT_TYPOGRAPHY.items()
    }
    components: dict[str, ComponentOverride] = {}
    for selector, payload in (raw.get("components") or {}).items():
        if not isinstance(payload, dict):
            continue
        component_values = {
            key: value
            for key, value in payload.items()
            if key in ComponentOverride.__dataclass_fields__ and key not in {"selector", "diagonal_shape"}
        }
        shape_payload = payload.get("diagonal_shape")
        if isinstance(shape_payload, dict):
            component_values["diagonal_shape"] = DiagonalShapeSpec(**{
                key: value
                for key, value in shape_payload.items()
                if key in DiagonalShapeSpec.__dataclass_fields__
            })
        components[str(selector)] = ComponentOverride(selector=str(selector), **component_values)
    gallery_styles: dict[str, GalleryStyleSpec] = {}
    for gallery_id, payload in (raw.get("gallery_styles") or {}).items():
        if not isinstance(payload, dict):
            continue
        widget_type = str(payload.get("widget_type") or "")
        if widget_type not in SUPPORTED_WIDGET_TYPES:
            continue
        shape = None
        shape_payload = payload.get("diagonal_shape")
        if isinstance(shape_payload, dict):
            shape = DiagonalShapeSpec(**{
                key: value
                for key, value in shape_payload.items()
                if key in DiagonalShapeSpec.__dataclass_fields__
            })
        gallery_styles[str(gallery_id)] = GalleryStyleSpec(
            gallery_id=str(gallery_id),
            title=str(payload.get("title") or widget_type),
            widget_type=widget_type,
            style_sheet=str(payload.get("style_sheet") or ""),
            diagonal_shape=shape,
        )
    new_widgets: list[NewWidgetSpec] = []
    for item in raw.get("new_widgets") or []:
        if not isinstance(item, dict) or item.get("widget_type") not in SUPPORTED_WIDGET_TYPES:
            continue
        try:
            new_widgets.append(NewWidgetSpec(**{
                key: value for key, value in item.items() if key in NewWidgetSpec.__dataclass_fields__
            }))
        except TypeError:
            continue
    animations: list[AnimationSpec] = []
    for item in raw.get("animations") or []:
        if not isinstance(item, dict):
            continue
        try:
            animations.append(AnimationSpec(**{
                key: value for key, value in item.items() if key in AnimationSpec.__dataclass_fields__
            }))
        except TypeError:
            continue
    return UIDesignSpec(
        version=max(2, int(raw.get("version") or 1)),
        palette=palette,
        typography=typography,
        gallery_styles=gallery_styles,
        components=components,
        new_widgets=new_widgets,
        animations=animations,
    )


def save_ui_design_spec(spec: UIDesignSpec, path: Path = UI_DESIGN_SPEC_PATH) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload: dict[str, Any] = {
        "version": max(2, spec.version),
        "palette": spec.palette,
        "typography": spec.typography,
        "gallery_styles": {
            gallery_id: {
                key: vars(value) if key == "diagonal_shape" else value
                for key, value in vars(style).items()
                if key != "gallery_id" and value is not None
            }
            for gallery_id, style in sorted(spec.gallery_styles.items())
        },
        "components": {
            selector: {
                key: vars(value) if key == "diagonal_shape" else value
                for key, value in vars(override).items()
                if key != "selector" and value is not None
            }
            for selector, override in sorted(spec.components.items())
        },
        "new_widgets": [vars(item) for item in spec.new_widgets],
        "animations": [vars(item) for item in spec.animations],
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
