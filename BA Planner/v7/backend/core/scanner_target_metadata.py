"""Best-effort, read-only OS metadata for existing scanner target rows.

No capture, input, process memory or server inference. A PID/thread identity
brackets queries so a closed/reused HWND never returns the collected metadata.
"""
from __future__ import annotations

import ctypes
from ctypes import wintypes
from functools import lru_cache
import ntpath
import sys

PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4


def configure_libraries(user32, kernel32) -> None:
    """Set pointer-safe signatures before any native call; injectable for tests."""
    handle = ctypes.c_void_p
    specs = {
        "IsWindow": (wintypes.BOOL, [handle]),
        "IsIconic": (wintypes.BOOL, [handle]),
        "IsWindowVisible": (wintypes.BOOL, [handle]),
        "GetWindowThreadProcessId": (wintypes.DWORD, [handle, ctypes.POINTER(wintypes.DWORD)]),
        "GetClientRect": (wintypes.BOOL, [handle, ctypes.POINTER(wintypes.RECT)]),
        "GetClassNameW": (ctypes.c_int, [handle, wintypes.LPWSTR, ctypes.c_int]),
    }
    for name, (result, args) in specs.items():
        function = getattr(user32, name)
        function.restype, function.argtypes = result, args
    # Older Windows can still supply identity metadata without physical sizes.
    setter = getattr(user32, "SetThreadDpiAwarenessContext", None)
    if setter is not None:
        setter.restype, setter.argtypes = handle, [handle]
    for name, result, args in (
        ("OpenProcess", handle, [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]),
        ("QueryFullProcessImageNameW", wintypes.BOOL,
         [handle, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]),
        ("CloseHandle", wintypes.BOOL, [handle]),
    ):
        function = getattr(kernel32, name)
        function.restype, function.argtypes = result, args


@lru_cache(maxsize=1)
def _libraries():
    if sys.platform != "win32":
        return None
    try:
        user32 = ctypes.WinDLL("user32", use_last_error=True)
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        configure_libraries(user32, kernel32)
        return user32, kernel32
    except (OSError, AttributeError):
        return None


def window_identity(user32, hwnd: int) -> tuple[int, int] | None:
    """Read only the owning PID/thread, including minimized windows."""
    try:
        if not user32.IsWindow(hwnd):
            return None
        pid = wintypes.DWORD()
        thread = int(user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid)))
        return (int(pid.value), thread) if pid.value and thread else None
    except Exception:
        return None


def _physical_size(user32, hwnd: int) -> tuple[int | None, int | None]:
    setter = getattr(user32, "SetThreadDpiAwarenessContext", None)
    if setter is None or user32.IsIconic(hwnd):
        return None, None
    old_context = setter(ctypes.c_void_p(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2))
    if not old_context:
        return None, None
    size = (None, None)
    restored = False
    try:
        rect = wintypes.RECT()
        if user32.GetClientRect(hwnd, ctypes.byref(rect)):
            width, height = int(rect.right - rect.left), int(rect.bottom - rect.top)
            if width > 0 and height > 0:
                size = width, height
    finally:
        # Never change process-global DPI awareness or manufacture scaled sizes.
        restored = bool(setter(old_context))
    return size if restored else (None, None)


def _game(user32, kernel32, hwnd: int, pid: int) -> str | None:
    if not user32.IsWindowVisible(hwnd):
        return None
    class_name = ctypes.create_unicode_buffer(256)
    if not user32.GetClassNameW(hwnd, class_name, len(class_name)) or class_name.value != "UnityWndClass":
        return None
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        return None
    try:
        # Full path exists only in this transient buffer; never emit/log/store it.
        path = ctypes.create_unicode_buffer(32768)
        length = wintypes.DWORD(len(path))
        if not kernel32.QueryFullProcessImageNameW(handle, 0, path, ctypes.byref(length)):
            return None
        if not 0 < length.value < len(path):
            return None
        return "blue_archive" if ntpath.basename(path.value).casefold() == "bluearchive.exe" else None
    finally:
        kernel32.CloseHandle(handle)


def target_metadata(hwnd: int, *, expected_identity: tuple[int, int] | None = None,
                    libraries=None) -> dict[str, int | str | None]:
    """Independent optional metadata; failures do not change target status.

    Callers enumerating windows supply the identity sampled before title/status
    queries. Unknown identity means no metadata may be attached to that row.
    """
    empty = {"client_width": None, "client_height": None, "game": None}
    try:
        native = libraries if libraries is not None else _libraries()
        if native is None:
            return empty
        user32, kernel32 = native
        before = window_identity(user32, hwnd)
        if before is None or expected_identity is None or before != expected_identity:
            return empty
        try:
            width, height = _physical_size(user32, hwnd)
        except Exception:
            width, height = None, None
        try:
            game = _game(user32, kernel32, hwnd, before[0])
        except Exception:
            game = None
        # Include the last minimized-state query inside the identity bracket.
        if user32.IsIconic(hwnd):
            width, height = None, None
        if window_identity(user32, hwnd) != before:
            return empty
        return {"client_width": width, "client_height": height, "game": game}
    except Exception:
        return empty
