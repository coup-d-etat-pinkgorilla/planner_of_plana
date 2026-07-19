"""Per-window UI scaling contract for the Qt Planner surfaces."""

from __future__ import annotations

import ctypes
import os
import tkinter as tk
from dataclasses import dataclass


UI_BASE_WIDTH = 1920
UI_BASE_HEIGHT = 1080
UI_BASE_FONT_POINT_SIZE = 11.0
UI_MIN_SCALE = 0.5
UI_MAX_SCALE = 1.8
UI_ASPECT_RATIO = UI_BASE_WIDTH / UI_BASE_HEIGHT


class _RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long), ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


def _windows_work_area_size() -> tuple[int, int] | None:
    if os.name != "nt":
        return None
    try:
        work = _RECT()
        if not ctypes.windll.user32.SystemParametersInfoW(48, 0, ctypes.byref(work), 0):
            return None
        return max(1, int(work.right - work.left)), max(1, int(work.bottom - work.top))
    except Exception:
        return None


def get_work_area_size(root: tk.Misc) -> tuple[int, int]:
    """Return the usable screen size for fitting legacy Tk dialogs."""
    work_area = _windows_work_area_size()
    if work_area is not None:
        return work_area
    try:
        screen_w = max(1, int(root.winfo_screenwidth()))
    except Exception:
        screen_w = 1
    try:
        screen_h = max(1, int(root.winfo_screenheight()))
    except Exception:
        screen_h = 1
    return screen_w, screen_h


def get_ui_scale(
    root: tk.Misc,
    *,
    base_width: int | None = None,
    base_height: int = UI_BASE_HEIGHT,
    min_scale: float = 0.8,
    max_scale: float = UI_MAX_SCALE,
) -> float:
    """Compute the existing screen-based scale used by legacy Tk windows."""
    raw = os.getenv("BA_UI_SCALE")
    if raw:
        try:
            value = float(raw)
            if value > 0:
                return value
        except ValueError:
            pass

    work_area = _windows_work_area_size()
    if work_area is not None:
        screen_w, screen_h = work_area
    else:
        try:
            screen_h = max(1, int(root.winfo_screenheight()))
        except Exception:
            screen_h = base_height
        try:
            screen_w = max(1, int(root.winfo_screenwidth()))
        except Exception:
            screen_w = base_width or base_height

    scale = screen_h / float(base_height)
    if base_width:
        scale = min(scale, screen_w / float(base_width))
    return max(min_scale, min(max_scale, scale))


def scale_px(value: int | float, scale: float) -> int:
    """Scale a legacy Tk pixel metric while keeping it visible."""
    return max(1, int(round(float(value) * scale)))


def scale_font(font: tuple, scale: float) -> tuple:
    """Scale the size member of a Tk font tuple."""
    if len(font) < 2:
        return font
    family, size, *rest = font
    try:
        size_i = int(size)
    except Exception:
        return font
    return (family, max(1, int(round(size_i * scale))), *rest)


@dataclass(frozen=True, slots=True)
class UIScaleContext:
    """Resolved visual metrics for one top-level window."""

    scale: float
    width: int
    height: int
    base_width: int = UI_BASE_WIDTH
    base_height: int = UI_BASE_HEIGHT
    base_font_point_size: float = UI_BASE_FONT_POINT_SIZE

    @classmethod
    def from_size(
        cls,
        width: int,
        height: int,
        *,
        base_width: int = UI_BASE_WIDTH,
        base_height: int = UI_BASE_HEIGHT,
        min_scale: float = UI_MIN_SCALE,
        max_scale: float = UI_MAX_SCALE,
    ) -> "UIScaleContext":
        safe_width = max(1, int(width))
        safe_height = max(1, int(height))
        scale = min(safe_width / float(base_width), safe_height / float(base_height))
        scale = max(float(min_scale), min(float(max_scale), scale))
        return cls(scale, safe_width, safe_height, base_width, base_height)

    @property
    def font_point_size(self) -> float:
        return max(1.0, self.base_font_point_size * self.scale)

    def differs_from(self, other: "UIScaleContext", *, tolerance: float = 0.01) -> bool:
        return abs(self.scale - other.scale) >= max(0.0, float(tolerance))


def aspect_ratio_from_size(width: int, height: int, fallback: float = UI_ASPECT_RATIO) -> float:
    """Resolve a stable aspect ratio from a monitor or emulated screen size."""
    safe_width = int(width)
    safe_height = int(height)
    if safe_width <= 0 or safe_height <= 0:
        return float(fallback)
    return safe_width / float(safe_height)


def fit_size_to_aspect(width: int, height: int, aspect_ratio: float = UI_ASPECT_RATIO) -> tuple[int, int]:
    """Return the nearest positive size with the requested aspect ratio."""
    safe_width = max(1, int(width))
    safe_height = max(1, int(height))
    width_from_height = max(1, int(round(safe_height * aspect_ratio)))
    height_from_width = max(1, int(round(safe_width / aspect_ratio)))
    if abs(width_from_height - safe_width) <= abs(height_from_width - safe_height):
        return width_from_height, safe_height
    return safe_width, height_from_width
