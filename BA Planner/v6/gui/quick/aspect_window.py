"""Aspect-ratio constrained QQuickView used by the new Planner shell."""

from __future__ import annotations

import ctypes
import os
from dataclasses import dataclass

from PySide6.QtCore import QSize, QUrl
from PySide6.QtQuick import QQuickView


DESIGN_WIDTH = 1920
DESIGN_HEIGHT = 1080
DESIGN_ASPECT = DESIGN_WIDTH / DESIGN_HEIGHT
MIN_CLIENT_WIDTH = 960
MIN_CLIENT_HEIGHT = 540

WM_SIZING = 0x0214
WMSZ_LEFT = 1
WMSZ_RIGHT = 2
WMSZ_TOP = 3
WMSZ_TOPLEFT = 4
WMSZ_TOPRIGHT = 5
WMSZ_BOTTOM = 6
WMSZ_BOTTOMLEFT = 7
WMSZ_BOTTOMRIGHT = 8

_WIDTH_DRIVEN_EDGES = {WMSZ_LEFT, WMSZ_RIGHT}
_HEIGHT_DRIVEN_EDGES = {WMSZ_TOP, WMSZ_BOTTOM}
_LEFT_EDGES = {WMSZ_LEFT, WMSZ_TOPLEFT, WMSZ_BOTTOMLEFT}
_TOP_EDGES = {WMSZ_TOP, WMSZ_TOPLEFT, WMSZ_TOPRIGHT}


@dataclass(frozen=True, slots=True)
class ConstrainedSize:
    width: int
    height: int


def constrain_client_size(
    width: int,
    height: int,
    edge: int,
    *,
    aspect: float = DESIGN_ASPECT,
    minimum_width: int = MIN_CLIENT_WIDTH,
    minimum_height: int = MIN_CLIENT_HEIGHT,
) -> ConstrainedSize:
    """Fit a proposed client size to one aspect while respecting its dragged edge."""
    safe_aspect = max(0.01, float(aspect))
    proposed_width = max(1, int(width))
    proposed_height = max(1, int(height))
    min_width = max(int(minimum_width), int(round(minimum_height * safe_aspect)))
    min_height = max(int(minimum_height), int(round(minimum_width / safe_aspect)))

    if edge in _WIDTH_DRIVEN_EDGES:
        target_width = max(min_width, proposed_width)
        target_height = max(min_height, int(round(target_width / safe_aspect)))
    elif edge in _HEIGHT_DRIVEN_EDGES:
        target_height = max(min_height, proposed_height)
        target_width = max(min_width, int(round(target_height * safe_aspect)))
    else:
        width_error = abs(proposed_height - (proposed_width / safe_aspect))
        height_error = abs(proposed_width - (proposed_height * safe_aspect))
        if width_error <= height_error:
            target_width = max(min_width, proposed_width)
            target_height = max(min_height, int(round(target_width / safe_aspect)))
        else:
            target_height = max(min_height, proposed_height)
            target_width = max(min_width, int(round(target_height * safe_aspect)))
    return ConstrainedSize(target_width, target_height)


def fit_inside(width: int, height: int, *, aspect: float = DESIGN_ASPECT) -> ConstrainedSize:
    """Return the largest aspect-ratio size that fits inside a rectangle."""
    safe_width = max(1, int(width))
    safe_height = max(1, int(height))
    safe_aspect = max(0.01, float(aspect))
    target_width = min(safe_width, int(round(safe_height * safe_aspect)))
    target_height = min(safe_height, int(round(target_width / safe_aspect)))
    return ConstrainedSize(max(1, target_width), max(1, target_height))


class _RECT(ctypes.Structure):
    _fields_ = (
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long),
    )


class _MSG(ctypes.Structure):
    _fields_ = (
        ("hwnd", ctypes.c_void_p),
        ("message", ctypes.c_uint),
        ("wParam", ctypes.c_size_t),
        ("lParam", ctypes.c_ssize_t),
        ("time", ctypes.c_ulong),
        ("pt_x", ctypes.c_long),
        ("pt_y", ctypes.c_long),
        ("lPrivate", ctypes.c_ulong),
    )


class AspectQuickView(QQuickView):
    """Quick view whose Windows resize rectangle preserves the client aspect."""

    def __init__(self, source: QUrl | None = None) -> None:
        super().__init__()
        self.setResizeMode(QQuickView.SizeRootObjectToView)
        self.setMinimumSize(QSize(MIN_CLIENT_WIDTH, MIN_CLIENT_HEIGHT))
        if source is not None:
            self.setSource(source)

    def nativeEvent(self, event_type, message):  # noqa: N802 - Qt virtual name
        if os.name != "nt":
            return super().nativeEvent(event_type, message)
        try:
            msg = _MSG.from_address(int(message))
            if msg.message != WM_SIZING or not msg.lParam:
                return super().nativeEvent(event_type, message)
            edge = int(msg.wParam)
            rect = _RECT.from_address(int(msg.lParam))

            frame_extra_width = max(0, self.frameGeometry().width() - self.width())
            frame_extra_height = max(0, self.frameGeometry().height() - self.height())
            proposed_client_width = max(1, rect.right - rect.left - frame_extra_width)
            proposed_client_height = max(1, rect.bottom - rect.top - frame_extra_height)
            constrained = constrain_client_size(proposed_client_width, proposed_client_height, edge)
            outer_width = constrained.width + frame_extra_width
            outer_height = constrained.height + frame_extra_height

            if edge in _LEFT_EDGES:
                rect.left = rect.right - outer_width
            else:
                rect.right = rect.left + outer_width
            if edge in _TOP_EDGES:
                rect.top = rect.bottom - outer_height
            else:
                rect.bottom = rect.top + outer_height
            return True, 1
        except (TypeError, ValueError, OSError):
            return super().nativeEvent(event_type, message)

