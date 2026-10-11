"""D21 input guard: notice the user's own mouse and keyboard input while the scanner sends input.

Low-level hooks (``WH_MOUSE_LL``/``WH_KEYBOARD_LL``) count events that Windows did not mark as injected,
so the scanner's own ``SendInput`` never counts. Input is always passed on (never swallowed); the hook
procedures only increment a counter and return, so they add no noticeable latency to the user's input.
"""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import sys
from threading import Event, Lock, Thread
from time import monotonic

from core import recognition_thresholds as rt
from core.scanner_session import ScannerError

WH_KEYBOARD_LL, WH_MOUSE_LL, WM_QUIT = 13, 14, 0x0012
PM_REMOVE, QS_ALLINPUT = 0x0001, 0x04FF
# The hooks exist only while the scanner is sending input: without a scanner step for this long the
# hook thread unhooks and ends, and the next step starts it again.
IDLE_STOP_SECONDS = 30.0
LLMHF_INJECTED, LLKHF_INJECTED = 0x01, 0x10
_HOOKPROC = ctypes.WINFUNCTYPE(ctypes.c_ssize_t, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM)


class _MSLLHOOKSTRUCT(ctypes.Structure):
    _fields_ = [("pt", wintypes.POINT), ("mouseData", wintypes.DWORD), ("flags", wintypes.DWORD),
                ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class _KBDLLHOOKSTRUCT(ctypes.Structure):
    _fields_ = [("vkCode", wintypes.DWORD), ("scanCode", wintypes.DWORD), ("flags", wintypes.DWORD),
                ("time", wintypes.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class UserInputGuard:
    """Counts non-injected user input on a hook thread; ``step()`` brackets one scanner input."""

    def __init__(self) -> None:
        self.count = 0
        self.last_input = 0.0
        self.last_step = 0.0
        self.waits = 0
        self.busy = 0
        self.available = False
        self._lock = Lock()
        self._ready = Event()
        self._thread: Thread | None = None
        self._thread_id = 0
        self._pause_signal: Event | None = None

    def _note(self) -> None:
        with self._lock:
            self.count += 1
            self.last_input = monotonic()
            if self._pause_signal is not None:
                self._pause_signal.set()

    def start(self) -> bool:
        if sys.platform != "win32":
            return False
        self.last_step = monotonic()
        if self._thread is not None and not self._thread.is_alive():
            self._thread, self._thread_id, self.available = None, 0, False
            self._ready.clear()
        if self._thread is None:
            self._thread = Thread(target=self._run, name="scanner-input-guard", daemon=True)
            self._thread.start()
            self._ready.wait(1.0)
        return self.available

    def _run(self) -> None:
        user = ctypes.WinDLL("user32", use_last_error=True)
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        user.SetWindowsHookExW.restype, user.SetWindowsHookExW.argtypes = (
            wintypes.HHOOK, [ctypes.c_int, _HOOKPROC, wintypes.HINSTANCE, wintypes.DWORD])
        user.CallNextHookEx.restype, user.CallNextHookEx.argtypes = (
            ctypes.c_ssize_t, [wintypes.HHOOK, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM])
        user.UnhookWindowsHookEx.argtypes = [wintypes.HHOOK]
        user.PeekMessageW.argtypes = [ctypes.POINTER(wintypes.MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT, wintypes.UINT]
        user.MsgWaitForMultipleObjects.restype = wintypes.DWORD
        user.MsgWaitForMultipleObjects.argtypes = [wintypes.DWORD, ctypes.c_void_p, wintypes.BOOL, wintypes.DWORD, wintypes.DWORD]
        kernel.GetModuleHandleW.restype, kernel.GetModuleHandleW.argtypes = wintypes.HMODULE, [wintypes.LPCWSTR]

        def mouse(code, wparam, lparam):
            if code >= 0 and not ctypes.cast(lparam, ctypes.POINTER(_MSLLHOOKSTRUCT)).contents.flags & LLMHF_INJECTED:
                self._note()
            return user.CallNextHookEx(None, code, wparam, lparam)

        def keyboard(code, wparam, lparam):
            if code >= 0 and not ctypes.cast(lparam, ctypes.POINTER(_KBDLLHOOKSTRUCT)).contents.flags & LLKHF_INJECTED:
                self._note()
            return user.CallNextHookEx(None, code, wparam, lparam)

        self._procs = (_HOOKPROC(mouse), _HOOKPROC(keyboard))
        self._thread_id = kernel.GetCurrentThreadId()
        module = kernel.GetModuleHandleW(None)
        hooks = [user.SetWindowsHookExW(WH_MOUSE_LL, self._procs[0], module, 0),
                 user.SetWindowsHookExW(WH_KEYBOARD_LL, self._procs[1], module, 0)]
        self.available = all(hooks)
        self._ready.set()
        try:
            # Hook callbacks run while this thread pumps messages; stop when asked or when idle.
            message = wintypes.MSG()
            running = self.available
            while running:
                user.MsgWaitForMultipleObjects(0, None, False, 500, QS_ALLINPUT)
                while user.PeekMessageW(ctypes.byref(message), None, 0, 0, PM_REMOVE):
                    if message.message == WM_QUIT:
                        running = False
                if monotonic() - self.last_step > IDLE_STOP_SECONDS:
                    running = False
        finally:
            self.available = False
            for hook in hooks:
                if hook:
                    user.UnhookWindowsHookEx(hook)

    def wait_idle(self, cancel: Event | None = None) -> None:
        """Wait until the user has been idle briefly; a user still busy after the budget is input_busy."""
        if not self.available:
            return
        idle, budget = rt.value("input.guard.idle_s"), rt.value("input.guard.wait_s")
        deadline = monotonic() + budget
        if monotonic() - self.last_input < idle:
            self.waits += 1
        while monotonic() - self.last_input < idle:
            if monotonic() >= deadline:
                self.busy += 1
                raise ScannerError("input_busy", "user input in progress; scanner input not sent",
                                   details={"performed": False})
            if cancel is not None and cancel.wait(.05):
                raise ScannerError("cancelled", "input wait cancelled")
            if cancel is None:
                Event().wait(.05)

    def step(self, cancel: Event | None = None, *, pause_on_input: bool = False,
             input_detected: Event | None = None) -> "_Step":
        self._pause_signal = input_detected if pause_on_input else None
        self.start()
        if pause_on_input and self.available and self._pause_input_pending(input_detected):
            self.busy += 1
            raise ScannerError("input_busy", "user input detected; explicit resume required",
                               details={"performed": False})
        if not pause_on_input:
            self.wait_idle(cancel)
        return _Step(self, pause_on_input, input_detected)

    def _pause_input_pending(self, signal: Event | None) -> bool:
        # An explicit start/resume consumes input already noted by that control.
        # A recent timestamp alone would immediately re-pause on the button click.
        return signal.is_set() if signal is not None else monotonic() - self.last_input < rt.value('input.guard.idle_s')

    def stop(self) -> None:
        if self._thread is not None and self._thread_id:
            ctypes.WinDLL("user32").PostThreadMessageW(self._thread_id, WM_QUIT, 0, 0)
            self._thread.join(1.0)
        self._thread = None
        self._thread_id = 0
        self.available = False
        self._ready.clear()
        self._pause_signal = None


class _Step:
    """Context for one scanner input: user input during it makes the step ``input_busy`` (performed)."""

    def __init__(self, guard: UserInputGuard, pause_on_input: bool = False,
                 input_detected: Event | None = None) -> None:
        self.guard = guard
        self.pause_on_input = pause_on_input
        self.input_detected = input_detected

    def __enter__(self) -> "_Step":
        with self.guard._lock:
            self.before = self.guard.count
            if self.pause_on_input and self.guard.available and self.guard._pause_input_pending(self.input_detected):
                self.guard.busy += 1
                raise ScannerError('input_busy', 'user input detected before scanner step',
                                   details={'performed': False})
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        if exc_type is None and self.guard.available and self.guard.count != self.before:
            self.guard.busy += 1
            raise ScannerError("input_busy", "user input arrived while the scanner was sending input",
                               details={"performed": True})
        return False
