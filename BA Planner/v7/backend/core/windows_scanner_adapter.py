from __future__ import annotations

import ctypes
from ctypes import wintypes
import sys
from threading import Event
from time import monotonic, sleep
from typing import Any

from PIL import Image

from core.scanner_matchers import image_similarity
from core.scanner_session import ScannerError


class _BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG),
        ("biHeight", wintypes.LONG), ("biPlanes", wintypes.WORD),
        ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
        ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG),
        ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD),
        ("biClrImportant", wintypes.DWORD),
    ]


class _BITMAPINFO(ctypes.Structure):
    _fields_ = [("bmiHeader", _BITMAPINFOHEADER), ("bmiColors", wintypes.DWORD * 3)]


class WindowsCaptureInputAdapter:
    """Lazy Win32 target, client capture and input adapter with no import side effects."""

    WM_LBUTTONDOWN = 0x0201
    WM_LBUTTONUP = 0x0202
    WM_MOUSEWHEEL = 0x020A
    MK_LBUTTON = 0x0001
    PW_CLIENTONLY = 0x00000001
    PW_RENDERFULLCONTENT = 0x00000002
    DIB_RGB_COLORS = 0
    BI_RGB = 0
    SRCCOPY = 0x00CC0020

    def __init__(self, *, title_contains: str = "Blue Archive") -> None:
        self.title_contains = title_contains.casefold()

    @staticmethod
    def _libraries():
        if sys.platform != "win32":
            raise ScannerError("windows_unsupported", "Windows scanner adapter requires win32")
        return ctypes.windll.user32, ctypes.windll.gdi32

    def __call__(self) -> list[dict[str, Any]]:
        user32, _gdi32 = self._libraries()
        targets: list[dict[str, Any]] = []
        callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

        def visit(hwnd, _lparam):
            length = user32.GetWindowTextLengthW(hwnd)
            if length <= 0:
                return True
            buffer = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buffer, length + 1)
            title = buffer.value
            if self.title_contains and self.title_contains not in title.casefold():
                return True
            status = "minimized" if user32.IsIconic(hwnd) else ("ready" if user32.IsWindowVisible(hwnd) else "unsupported")
            targets.append({
                "target_id": f"hwnd:{int(hwnd or 0):x}", "title": title, "status": status,
                "foreground": int(user32.GetForegroundWindow() or 0) == int(hwnd or 0),
            })
            return True

        callback = callback_type(visit)
        enumerated = user32.EnumWindows(callback, 0)
        # Headless Windows stations can return zero with no Win32 error and no
        # callback invocations; that is an empty target list, not a crash.
        if not enumerated and ctypes.get_last_error():
            raise ScannerError("target_provider_failed", "EnumWindows failed")
        return targets

    @staticmethod
    def _hwnd(target: dict[str, Any]) -> int:
        target_id = target.get("target_id")
        if not isinstance(target_id, str) or not target_id.startswith("hwnd:"):
            raise ScannerError("target_not_found", "invalid Windows target id")
        try:
            return int(target_id[5:], 16)
        except ValueError as exc:
            raise ScannerError("target_not_found", "invalid Windows target id") from exc

    def diagnose(self, target: dict[str, Any]) -> dict[str, Any]:
        user32, _gdi32 = self._libraries()
        hwnd = self._hwnd(target)
        if not user32.IsWindow(hwnd):
            return {"status": "closed", "foreground": False}
        if user32.IsIconic(hwnd):
            return {"status": "minimized", "foreground": False}
        return {"status": "ready", "foreground": int(user32.GetForegroundWindow() or 0) == hwnd}

    def capture(self, target: dict[str, Any]) -> Image.Image:
        user32, gdi32 = self._libraries()
        hwnd = self._hwnd(target)
        diagnostic = self.diagnose(target)
        if diagnostic["status"] != "ready":
            raise ScannerError(f"target_{diagnostic['status']}", f"capture target is {diagnostic['status']}")
        rect = wintypes.RECT()
        if not user32.GetClientRect(hwnd, ctypes.byref(rect)):
            raise ScannerError("capture_failed", "GetClientRect failed")
        width, height = rect.right - rect.left, rect.bottom - rect.top
        if width <= 0 or height <= 0:
            raise ScannerError("capture_failed", "capture target has an empty client area")
        window_dc = user32.GetDC(hwnd)
        memory_dc = gdi32.CreateCompatibleDC(window_dc)
        bitmap = gdi32.CreateCompatibleBitmap(window_dc, width, height)
        previous = gdi32.SelectObject(memory_dc, bitmap)
        try:
            printed = user32.PrintWindow(hwnd, memory_dc, self.PW_CLIENTONLY | self.PW_RENDERFULLCONTENT)
            if not printed:
                if not gdi32.BitBlt(memory_dc, 0, 0, width, height, window_dc, 0, 0, self.SRCCOPY):
                    raise ScannerError("capture_failed", "PrintWindow and BitBlt failed")
            info = _BITMAPINFO()
            info.bmiHeader.biSize = ctypes.sizeof(_BITMAPINFOHEADER)
            info.bmiHeader.biWidth = width
            info.bmiHeader.biHeight = -height
            info.bmiHeader.biPlanes = 1
            info.bmiHeader.biBitCount = 32
            info.bmiHeader.biCompression = self.BI_RGB
            buffer = ctypes.create_string_buffer(width * height * 4)
            rows = gdi32.GetDIBits(memory_dc, bitmap, 0, height, buffer, ctypes.byref(info), self.DIB_RGB_COLORS)
            if rows != height:
                raise ScannerError("capture_failed", "GetDIBits returned an incomplete frame")
            return Image.frombuffer("RGB", (width, height), buffer, "raw", "BGRX", 0, 1).copy()
        finally:
            if previous:
                gdi32.SelectObject(memory_dc, previous)
            if bitmap:
                gdi32.DeleteObject(bitmap)
            if memory_dc:
                gdi32.DeleteDC(memory_dc)
            if window_dc:
                user32.ReleaseDC(hwnd, window_dc)

    def wait_stable(self, target: dict[str, Any], cancel: Event, timeout: float = 2.0) -> Image.Image:
        deadline = monotonic() + timeout
        previous: Image.Image | None = None
        stable = 0
        while monotonic() < deadline:
            if cancel.is_set():
                raise ScannerError("cancelled", "capture cancelled")
            current = self.capture(target)
            if previous is not None and image_similarity(previous, current) >= 0.995:
                stable += 1
                if stable >= 2:
                    return current
            else:
                stable = 0
            previous = current
            cancel.wait(0.05)
        raise ScannerError("capture_timeout", "stable frame timeout")

    def click(self, target: dict[str, Any], x_ratio: float, y_ratio: float) -> None:
        user32, _gdi32 = self._libraries()
        hwnd = self._hwnd(target)
        rect = wintypes.RECT()
        if not user32.GetClientRect(hwnd, ctypes.byref(rect)):
            raise ScannerError("input_failed", "GetClientRect failed")
        x = max(0, min(rect.right - 1, round(rect.right * x_ratio)))
        y = max(0, min(rect.bottom - 1, round(rect.bottom * y_ratio)))
        lparam = (y << 16) | (x & 0xFFFF)
        if not user32.PostMessageW(hwnd, self.WM_LBUTTONDOWN, self.MK_LBUTTON, lparam):
            raise ScannerError("input_failed", "mouse down failed")
        if not user32.PostMessageW(hwnd, self.WM_LBUTTONUP, 0, lparam):
            raise ScannerError("input_failed", "mouse up failed")

    def scroll(self, target: dict[str, Any], delta: int) -> None:
        user32, _gdi32 = self._libraries()
        hwnd = self._hwnd(target)
        wheel = ctypes.c_short(delta).value & 0xFFFF
        if not user32.PostMessageW(hwnd, self.WM_MOUSEWHEEL, wheel << 16, 0):
            raise ScannerError("input_failed", "mouse wheel failed")
