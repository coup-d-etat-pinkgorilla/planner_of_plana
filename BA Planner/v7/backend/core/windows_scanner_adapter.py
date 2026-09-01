from __future__ import annotations

import ctypes
from ctypes import wintypes
from functools import lru_cache
import math
import sys
from threading import Event
from time import monotonic
from typing import Any

from PIL import Image, ImageStat
from core.scanner_matchers import image_similarity
from core.scanner_session import ScannerError


class _BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG),
                ("biHeight", wintypes.LONG), ("biPlanes", wintypes.WORD),
                ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
                ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG),
                ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD),
                ("biClrImportant", wintypes.DWORD)]


class _BITMAPINFO(ctypes.Structure):
    _fields_ = [("bmiHeader", _BITMAPINFOHEADER), ("bmiColors", wintypes.DWORD * 3)]


class _MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", wintypes.LONG), ("dy", wintypes.LONG), ("mouseData", wintypes.DWORD),
                ("dwFlags", wintypes.DWORD), ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class _KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wintypes.WORD), ("wScan", wintypes.WORD), ("dwFlags", wintypes.DWORD),
                ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class _INPUTUNION(ctypes.Union):
    _fields_ = [("mi", _MOUSEINPUT), ("ki", _KEYBDINPUT)]


class _INPUT(ctypes.Structure):
    _anonymous_ = ("data",)
    _fields_ = [("type", wintypes.DWORD), ("data", _INPUTUNION)]


class WindowsCaptureInputAdapter:
    """Selected-window input; bounded capture in a killable, input-free worker."""

    MAX_PIXELS = 16_777_216
    CAPTURE_ROUNDS, MAX_STABLE_FRAMES = 3, 12
    WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0201, 0x0202
    WM_KEYDOWN, WM_KEYUP, WM_MOUSEWHEEL = 0x0100, 0x0101, 0x020A
    VK_LEFT, VK_RIGHT = 0x25, 0x27
    PW_CLIENTONLY, PW_RENDERFULLCONTENT = 1, 2
    SRCCOPY = 0x00CC0020

    def __init__(self, *, title_contains: str = "Blue Archive", isolate_capture: bool = True) -> None:
        self.title_contains = title_contains.casefold()
        self._identities: dict[int, tuple[int, int]] = {}
        self._worker = None
        self._isolate_capture = isolate_capture
        self.last_capture_trace: list[dict[str, Any]] = []
        self.last_input_trace: dict[str, Any] = {}

    @staticmethod
    @lru_cache(maxsize=1)
    def _libraries():
        if sys.platform != "win32":
            raise ScannerError("windows_unsupported", "Windows scanner adapter requires win32")
        u, g = ctypes.WinDLL("user32", use_last_error=True), ctypes.WinDLL("gdi32", use_last_error=True)
        h, i, b = wintypes.HANDLE, ctypes.c_int, wintypes.BOOL
        # Never leave HWND/HDC/HBITMAP restypes at ctypes' truncating 32-bit default.
        specs = {
            "IsWindow": (b, [h]), "IsIconic": (b, [h]), "IsWindowVisible": (b, [h]),
            "GetForegroundWindow": (h, []), "GetWindowTextLengthW": (i, [h]),
            "GetWindowTextW": (i, [h, wintypes.LPWSTR, i]),
            "GetWindowThreadProcessId": (wintypes.DWORD, [h, ctypes.POINTER(wintypes.DWORD)]),
            "GetClientRect": (b, [h, ctypes.POINTER(wintypes.RECT)]),
            "GetWindowRect": (b, [h, ctypes.POINTER(wintypes.RECT)]),
            "ClientToScreen": (b, [h, ctypes.POINTER(wintypes.POINT)]),
            "GetDC": (h, [h]), "ReleaseDC": (i, [h, h]),
            "PrintWindow": (b, [h, h, wintypes.UINT]),
            "SetForegroundWindow": (b, [h]), "BringWindowToTop": (b, [h]),
            "SetCursorPos": (b, [i, i]), "WindowFromPoint": (h, [wintypes.POINT]),
            "GetAncestor": (h, [h, wintypes.UINT]),
            "SendInput": (wintypes.UINT, [wintypes.UINT, ctypes.POINTER(_INPUT), i]),
            "PostMessageW": (b, [h, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]),
            "MapVirtualKeyW": (wintypes.UINT, [wintypes.UINT, wintypes.UINT]),
            "GetAsyncKeyState": (ctypes.c_short, [i]),
        }
        for name, (result, args) in specs.items():
            getattr(u, name).restype, getattr(u, name).argtypes = result, args
        for name, result, args in [
            ("CreateCompatibleDC", h, [h]), ("CreateCompatibleBitmap", h, [h, i, i]),
            ("SelectObject", h, [h, h]), ("DeleteObject", b, [h]), ("DeleteDC", b, [h]),
            ("BitBlt", b, [h, i, i, i, i, h, i, i, wintypes.DWORD]),
            ("GetDIBits", i, [h, h, wintypes.UINT, wintypes.UINT, ctypes.c_void_p, ctypes.POINTER(_BITMAPINFO), wintypes.UINT]),
        ]:
            getattr(g, name).restype, getattr(g, name).argtypes = result, args
        return u, g

    @staticmethod
    def _hwnd(target):
        value = target.get("target_id")
        try:
            if not isinstance(value, str) or not value.startswith("hwnd:"):
                raise ValueError()
            hwnd = int(value[5:], 16)
            if not 0 < hwnd < 2 ** (ctypes.sizeof(ctypes.c_void_p) * 8):
                raise ValueError()
            return hwnd
        except ValueError as exc:
            raise ScannerError("target_not_found", "invalid Windows target id") from exc

    def diagnose(self, target):
        u, _ = self._libraries()
        hwnd = self._hwnd(target)
        if not u.IsWindow(hwnd):
            return {"status": "closed", "foreground": False}
        if u.IsIconic(hwnd):
            return {"status": "minimized", "foreground": False}
        title = ctypes.create_unicode_buffer(max(1, u.GetWindowTextLengthW(hwnd) + 1))
        u.GetWindowTextW(hwnd, title, len(title))
        pid = wintypes.DWORD()
        tid = int(u.GetWindowThreadProcessId(hwnd, ctypes.byref(pid)))
        identity = int(pid.value), tid
        expected = target.get("_window_identity", self._identities.get(hwnd, identity))
        valid = (all(identity) and tuple(expected) == identity and u.IsWindowVisible(hwnd)
                 and (not self.title_contains or self.title_contains in title.value.casefold()))
        if valid:
            self._identities.setdefault(hwnd, identity)
        return {"status": "ready" if valid else "unsupported",
                "foreground": int(u.GetForegroundWindow() or 0) == hwnd}

    def __call__(self):
        u, _ = self._libraries()
        targets = []
        callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

        def visit(hwnd, _lparam):
            title = ctypes.create_unicode_buffer(max(1, u.GetWindowTextLengthW(hwnd) + 1))
            u.GetWindowTextW(hwnd, title, len(title))
            if not title.value or self.title_contains not in title.value.casefold():
                return True
            item = {"target_id": f"hwnd:{int(hwnd):x}", "title": title.value}
            item.update(self.diagnose(item))
            targets.append(item)
            return True

        callback = callback_type(visit)
        u.EnumWindows.argtypes, u.EnumWindows.restype = [callback_type, wintypes.LPARAM], wintypes.BOOL
        ctypes.set_last_error(0)
        if not u.EnumWindows(callback, 0) and ctypes.get_last_error():
            raise ScannerError("target_provider_failed", "EnumWindows failed")
        return targets

    @staticmethod
    def _cancel(target, cancel=None):
        signal = cancel if cancel is not None else target.get("_scanner_cancel")
        if signal is not None and signal.is_set() and not target.get("_scanner_cleanup", False):
            raise ScannerError("cancelled", "scanner operation cancelled")

    def _checked_hwnd(self, target):
        status = self.diagnose(target)["status"]
        if status != "ready":
            raise ScannerError(f"target_{status}", f"scanner target is {status}")
        return self._hwnd(target)

    def _client(self, u, hwnd):
        rect = wintypes.RECT()
        if not u.GetClientRect(hwnd, ctypes.byref(rect)):
            raise ScannerError("capture_failed", "GetClientRect failed")
        width, height = rect.right - rect.left, rect.bottom - rect.top
        if width <= 0 or height <= 0 or width * height > self.MAX_PIXELS:
            raise ScannerError("capture_failed", "invalid or oversized client area")
        return width, height

    @staticmethod
    def _visible_frame(frame):
        thumb = frame.resize((64, 36)).convert("L")
        try:
            stats = ImageStat.Stat(thumb)
            return stats.mean[0] > 2 and stats.stddev[0] > 1
        finally:
            thumb.close()

    def _render(self, target, method):
        """One native render; only the worker calls this in production."""
        u, g = self._libraries()
        hwnd = self._checked_hwnd(target)
        cw, ch = self._client(u, hwnd)
        width, height, left, top = cw, ch, 0, 0
        if method in (2, 0):
            rect, origin = wintypes.RECT(), wintypes.POINT(0, 0)
            if not u.GetWindowRect(hwnd, ctypes.byref(rect)) or not u.ClientToScreen(hwnd, ctypes.byref(origin)):
                raise ScannerError("capture_failed", "window/client geometry unavailable")
            width, height = rect.right - rect.left, rect.bottom - rect.top
            left, top = origin.x - rect.left, origin.y - rect.top
            if not (0 <= left and 0 <= top and left + cw <= width and top + ch <= height):
                raise ScannerError("capture_failed", "client area outside window bounds")
        if width <= 0 or height <= 0 or width * height > self.MAX_PIXELS:
            raise ScannerError("capture_failed", "invalid render size")
        if method == "bitblt" and int(u.GetForegroundWindow() or 0) != hwnd:
            raise ScannerError("capture_failed", "BitBlt requires selected foreground window")
        dc = memory = bitmap = previous = None
        selected = False
        try:
            dc = u.GetDC(hwnd)
            if not dc:
                raise ScannerError("capture_failed", "GetDC failed")
            memory = g.CreateCompatibleDC(dc)
            if not memory:
                raise ScannerError("capture_failed", "CreateCompatibleDC failed")
            bitmap = g.CreateCompatibleBitmap(dc, width, height)
            if not bitmap:
                raise ScannerError("capture_failed", "CreateCompatibleBitmap failed")
            previous = g.SelectObject(memory, bitmap)
            if not previous or previous == ctypes.c_void_p(-1).value:
                raise ScannerError("capture_failed", "SelectObject failed")
            selected = True
            ok = (g.BitBlt(memory, 0, 0, width, height, dc, 0, 0, self.SRCCOPY)
                  if method == "bitblt" else u.PrintWindow(hwnd, memory, method))
            if not ok:
                raise ScannerError("capture_failed", f"render {method} failed")
            # GetDIBits requires the bitmap to be deselected first.
            g.SelectObject(memory, previous)
            selected = False
            info = _BITMAPINFO()
            info.bmiHeader.biSize = ctypes.sizeof(_BITMAPINFOHEADER)
            info.bmiHeader.biWidth, info.bmiHeader.biHeight = width, -height
            info.bmiHeader.biPlanes, info.bmiHeader.biBitCount = 1, 32
            buffer = ctypes.create_string_buffer(width * height * 4)
            if g.GetDIBits(dc, bitmap, 0, height, buffer, ctypes.byref(info), 0) != height:
                raise ScannerError("capture_failed", "GetDIBits returned incomplete frame")
            self._checked_hwnd(target)
            if self._client(u, hwnd) != (cw, ch):
                raise ScannerError("capture_failed", "client resized during capture")
            image = Image.frombytes("RGB", (width, height), buffer.raw, "raw", "BGRX")
            try:
                return image.crop((left, top, left + cw, top + ch))
            finally:
                image.close()
        finally:
            if selected:
                g.SelectObject(memory, previous)
            if bitmap:
                g.DeleteObject(bitmap)
            if memory:
                g.DeleteDC(memory)
            if dc:
                u.ReleaseDC(hwnd, dc)

    def _capture_direct(self, target, cancel, deadline):
        self.last_capture_trace = []
        for attempt in range(self.CAPTURE_ROUNDS):
            for method in (3, 1, 2, 0, "bitblt"):
                self._cancel(target, cancel)
                if monotonic() >= deadline:
                    raise ScannerError("capture_timeout", "capture deadline exceeded")
                try:
                    frame = self._render(target, method)
                    if not self._visible_frame(frame):
                        frame.close()
                        raise ScannerError("capture_failed", "blank render")
                    self.last_capture_trace.append({"round": attempt + 1, "method": method, "ok": True})
                    return frame
                except ScannerError as exc:
                    self.last_capture_trace.append({"round": attempt + 1, "method": method, "ok": False, "code": exc.code})
                    if exc.code != "capture_failed":
                        raise
            if attempt < self.CAPTURE_ROUNDS - 1 and cancel.wait(min(0.1, max(0, deadline - monotonic()))):
                raise ScannerError("cancelled", "capture cancelled")
        raise ScannerError("capture_failed", "capture methods exhausted")

    def capture(self, target, *, cancel=None, timeout=2.0):
        cancel = cancel if cancel is not None else target.get("_scanner_cancel", Event())
        self._cancel(target, cancel)
        hwnd = self._checked_hwnd(target)
        if not math.isfinite(timeout) or timeout <= 0:
            raise ScannerError("capture_timeout", "invalid capture deadline")
        deadline = monotonic() + min(timeout, 5.0)
        if not self._isolate_capture:
            return self._capture_direct(target, cancel, deadline)
        if self._worker is None:
            from core.windows_capture_worker import CaptureWorker
            self._worker = CaptureWorker()
        try:
            frame, self.last_capture_trace = self._worker.capture(
                {"target_id": target["target_id"], "_window_identity": self._identities[hwnd]},
                self.title_contains, cancel, deadline,
            )
            try:
                self._cancel(target, cancel)
                self._checked_hwnd(target)
                return frame
            except Exception:
                frame.close()
                raise
        except ScannerError as exc:
            self.last_capture_trace = exc.details.get("trace", [])
            raise

    def wait_stable(self, target, cancel: Event, timeout: float = 2.0):
        if not math.isfinite(timeout) or timeout <= 0:
            raise ScannerError("capture_timeout", "invalid stable capture deadline")
        deadline = monotonic() + min(timeout, 5.0)
        previous = None
        stable = failures = 0
        try:
            for _ in range(self.MAX_STABLE_FRAMES):
                self._cancel(target, cancel)
                if monotonic() >= deadline:
                    break
                try:
                    current = self.capture(target, cancel=cancel, timeout=deadline - monotonic())
                except ScannerError as exc:
                    if exc.code != "capture_failed":
                        raise
                    failures += 1
                    if previous is not None:
                        previous.close()
                        previous = None
                    stable = 0
                    if failures >= 3:
                        raise
                    cancel.wait(min(0.05, max(0, deadline - monotonic())))
                    continue
                if previous is not None:
                    stable = stable + 1 if previous.size == current.size and image_similarity(previous, current) >= 0.995 else 0
                    previous.close()
                previous = current
                if stable >= 2:
                    self._cancel(target, cancel)
                    result, previous = previous, None
                    return result
                cancel.wait(min(0.05, max(0, deadline - monotonic())))
            raise ScannerError("capture_timeout", "stable frame budget exhausted")
        finally:
            if previous is not None:
                previous.close()

    def _foreground(self, u, target, hwnd):
        self._cancel(target)
        if int(u.GetForegroundWindow() or 0) != hwnd:
            u.BringWindowToTop(hwnd)
            u.SetForegroundWindow(hwnd)
            target.get("_scanner_cancel", Event()).wait(0.05)
        self._cancel(target)
        self._checked_hwnd(target)
        return int(u.GetForegroundWindow() or 0) == hwnd

    @staticmethod
    def _send(u, events):
        count = u.SendInput(len(events), (_INPUT * len(events))(*events), ctypes.sizeof(_INPUT))
        if 0 < count < len(events):
            u.SendInput(1, (_INPUT * 1)(events[-1]), ctypes.sizeof(_INPUT))
            raise ScannerError("input_partial", "input batch partially inserted; released and stopped")
        return count == len(events)

    @staticmethod
    def _modifiers_clear(u):
        return not any(u.GetAsyncKeyState(k) & 0x8000 for k in (0x10, 0x11, 0x12, 0x5B, 0x5C, 0x01, 0x02))

    def click(self, target, x_ratio, y_ratio):
        if any(not isinstance(v, (int, float)) or not math.isfinite(v) or not 0 <= v <= 1 for v in (x_ratio, y_ratio)):
            raise ScannerError("input_failed", "invalid click ratios")
        self._cancel(target)
        u, _ = self._libraries()
        hwnd = self._checked_hwnd(target)
        foreground = self._foreground(u, target, hwnd)
        width, height = self._client(u, hwnd)
        x, y = min(width - 1, round(width * x_ratio)), min(height - 1, round(height * y_ratio))
        self.last_input_trace = {"kind": "click", "client": [x, y], "method": None}
        if foreground:
            point = wintypes.POINT(x, y)
            if not u.ClientToScreen(hwnd, ctypes.byref(point)):
                raise ScannerError("input_failed", "ClientToScreen failed")
            if not self._modifiers_clear(u):
                raise ScannerError("input_busy", "user input is held")
            if u.SetCursorPos(point.x, point.y):
                hit = u.WindowFromPoint(point)
                self._cancel(target)
                self._checked_hwnd(target)
                if (int(u.GetForegroundWindow() or 0) != hwnd or int(u.GetAncestor(hit, 2) or hit or 0) != hwnd):
                    raise ScannerError("input_focus_changed", "click target lost foreground or is occluded")
                refreshed = wintypes.POINT(x, y)
                if (self._client(u, hwnd) != (width, height) or not u.ClientToScreen(hwnd, ctypes.byref(refreshed))
                        or (refreshed.x, refreshed.y) != (point.x, point.y)):
                    raise ScannerError("input_geometry_changed", "click target moved")
                events = [_INPUT(type=0, mi=_MOUSEINPUT(dwFlags=flag)) for flag in (0x0002, 0x0004)]
                self._cancel(target)
                if int(u.GetForegroundWindow() or 0) != hwnd:
                    raise ScannerError("input_focus_changed", "click target lost foreground")
                if self._send(u, events):
                    self.last_input_trace.update(method="send_input", screen=[point.x, point.y])
                    return
        self._cancel(target)
        self._checked_hwnd(target)
        if self._client(u, hwnd) != (width, height):
            raise ScannerError("input_geometry_changed", "click target resized")
        lparam = (y << 16) | x
        if not u.PostMessageW(hwnd, self.WM_LBUTTONDOWN, 1, lparam):
            raise ScannerError("input_failed", "mouse down rejected")
        if not u.PostMessageW(hwnd, self.WM_LBUTTONUP, 0, lparam):
            u.PostMessageW(hwnd, self.WM_LBUTTONUP, 0, lparam)
            raise ScannerError("input_partial", "mouse up rejected")
        self.last_input_trace["method"] = "post_message"

    def press_key(self, target, key):
        if key not in {"left", "right", "escape"}:
            raise ScannerError("input_failed", f"unsupported scanner key: {key}")
        self._cancel(target)
        u, _ = self._libraries()
        hwnd = self._checked_hwnd(target)
        vk = {"left": self.VK_LEFT, "right": self.VK_RIGHT, "escape": 0x1B}[key]
        extended = key in {"left", "right"}
        scan = int(u.MapVirtualKeyW(vk, 0)) & 0xFF
        if not scan:
            raise ScannerError("input_failed", "arrow scan code is unavailable")
        self.last_input_trace = {"kind": "key", "key": key, "method": None}
        if self._foreground(u, target, hwnd):
            if not self._modifiers_clear(u):
                raise ScannerError("input_busy", "user input is held")
            self._cancel(target)
            self._checked_hwnd(target)
            if int(u.GetForegroundWindow() or 0) != hwnd:
                raise ScannerError("input_focus_changed", "key target lost foreground")
            events = [_INPUT(type=1, ki=_KEYBDINPUT(wScan=scan, dwFlags=0x0008 | int(extended) | up)) for up in (0, 0x0002)]
            if self._send(u, events):
                self.last_input_trace["method"] = "send_input"
                return True
        self._cancel(target)
        self._checked_hwnd(target)
        down = 1 | (scan << 16) | (int(extended) << 24)
        if not u.PostMessageW(hwnd, self.WM_KEYDOWN, vk, down):
            return False
        if not u.PostMessageW(hwnd, self.WM_KEYUP, vk, down | (1 << 30) | (1 << 31)):
            u.PostMessageW(hwnd, self.WM_KEYUP, vk, down | (1 << 30) | (1 << 31))
            raise ScannerError("input_partial", "key up rejected")
        self.last_input_trace["method"] = "post_message"
        return True

    def scroll(self, target, delta):
        if not isinstance(delta, int) or not -1200 <= delta <= 1200 or delta == 0:
            raise ScannerError("input_failed", "invalid scanner scroll delta")
        self._cancel(target)
        u, _ = self._libraries()
        hwnd = self._checked_hwnd(target)
        foreground = self._foreground(u, target, hwnd)
        width, height = self._client(u, hwnd)
        scroll_point = target.get("_scanner_scroll_point", (0.78, 0.55))
        if not (isinstance(scroll_point, (tuple, list)) and len(scroll_point) == 2):
            raise ScannerError("input_failed", "invalid scanner scroll point")
        rx, ry = scroll_point
        if not (isinstance(rx, (int, float)) and isinstance(ry, (int, float)) and 0 <= rx <= 1 and 0 <= ry <= 1):
            raise ScannerError("input_failed", "scanner scroll point is outside client bounds")
        point = wintypes.POINT(round(width * rx), round(height * ry))
        if not u.ClientToScreen(hwnd, ctypes.byref(point)):
            raise ScannerError("input_failed", "scroll ClientToScreen failed")
        self.last_input_trace = {"kind":"scroll","delta":delta,"method":None}
        if foreground:
            if not self._modifiers_clear(u):raise ScannerError("input_busy","user input is held")
            if u.SetCursorPos(point.x,point.y):
                hit=u.WindowFromPoint(point)
                self._cancel(target);self._checked_hwnd(target)
                if int(u.GetForegroundWindow() or 0)!=hwnd or int(u.GetAncestor(hit,2) or hit or 0)!=hwnd:
                    raise ScannerError("input_focus_changed","scroll target lost foreground or is occluded")
                event=_INPUT(type=0,mi=_MOUSEINPUT(mouseData=ctypes.c_ulong(delta).value,dwFlags=0x0800))
                if self._send(u,[event]):
                    self.last_input_trace.update(method="send_input",screen=[point.x,point.y]);return
        self._cancel(target);self._checked_hwnd(target)
        if not u.PostMessageW(hwnd, self.WM_MOUSEWHEEL, (ctypes.c_short(delta).value & 0xFFFF) << 16,
                              ((point.y & 0xFFFF) << 16) | (point.x & 0xFFFF)):
            raise ScannerError("input_failed", "mouse wheel rejected")
        self.last_input_trace['method']='post_message'

    def drag_scroll(self,target,start,end):
        values=(*start,*end)
        if any(not isinstance(v,(int,float)) or not math.isfinite(v) or not 0<=v<=1 for v in values):
            raise ScannerError('input_failed','invalid drag ratios')
        self._cancel(target);u,_=self._libraries();hwnd=self._checked_hwnd(target)
        if not self._foreground(u,target,hwnd):raise ScannerError('input_focus_changed','drag target is not foreground')
        if not self._modifiers_clear(u):raise ScannerError('input_busy','user input is held')
        width,height=self._client(u,hwnd)
        points=[]
        for rx,ry in (start,end):
            point=wintypes.POINT(min(width-1,round(width*rx)),min(height-1,round(height*ry)))
            if not u.ClientToScreen(hwnd,ctypes.byref(point)):raise ScannerError('input_failed','drag ClientToScreen failed')
            points.append(point)
        first,last=points;self.last_input_trace={'kind':'drag_scroll','client_start':list(start),'client_end':list(end),'method':None}
        if not u.SetCursorPos(first.x,first.y):raise ScannerError('input_failed','drag cursor placement failed')
        hit=u.WindowFromPoint(first)
        if int(u.GetForegroundWindow() or 0)!=hwnd or int(u.GetAncestor(hit,2) or hit or 0)!=hwnd:
            raise ScannerError('input_focus_changed','drag target lost foreground or is occluded')
        down=_INPUT(type=0,mi=_MOUSEINPUT(dwFlags=0x0002));up=_INPUT(type=0,mi=_MOUSEINPUT(dwFlags=0x0004))
        if not self._send(u,[down]):raise ScannerError('input_failed','drag press insertion failed')
        try:
            remaining_x,remaining_y=last.x-first.x,last.y-first.y
            for step in range(4,0,-1):
                dx=round(remaining_x/step);dy=round(remaining_y/step)
                move=_INPUT(type=0,mi=_MOUSEINPUT(dx=dx,dy=dy,dwFlags=0x0001))
                if not self._send(u,[move]):raise ScannerError('input_failed','drag move insertion failed')
                remaining_x-=dx;remaining_y-=dy
                target.get('_scanner_cancel',Event()).wait(.02)
            self._cancel(target);self._checked_hwnd(target)
        finally:
            self._send(u,[up])
        self.last_input_trace.update(method='send_input',screen_start=[first.x,first.y],screen_end=[last.x,last.y])

    def close(self):
        if self._worker is not None:
            self._worker.close()
            self._worker = None
