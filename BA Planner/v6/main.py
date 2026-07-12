"""
Blue Archive Analyzer v6 entry point.
"""

import ctypes
import argparse
import hashlib
import importlib.util
import json
import os
import queue
import sys
import threading
import time
import traceback
import webbrowser
from datetime import datetime
from pathlib import Path
from tkinter import TclError, messagebox, ttk

import tkinter as tk
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

_SCANNER_MODE = "--scanner" in sys.argv[1:]

_ERROR_ALREADY_EXISTS = 183
SCANNER_CLOSE_GRACE_SECONDS = 5.0
_kernel32 = None

if sys.platform == "win32":
    _kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _kernel32.CreateMutexW.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_wchar_p]
    _kernel32.CreateMutexW.restype = ctypes.c_void_p
    _kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
    _kernel32.CloseHandle.restype = ctypes.c_bool


class SingleInstanceGuard:
    def __init__(self, name: str):
        self._name = name
        self._handle = None

    def acquire(self) -> bool:
        if _kernel32 is None:
            return True
        if self._handle is not None:
            return True

        handle = _kernel32.CreateMutexW(None, False, self._name)
        if not handle:
            raise OSError(ctypes.get_last_error(), "CreateMutexW failed")
        if ctypes.get_last_error() == _ERROR_ALREADY_EXISTS:
            _kernel32.CloseHandle(handle)
            return False

        self._handle = handle
        return True

    def release(self) -> None:
        if _kernel32 is None or self._handle is None:
            return
        _kernel32.CloseHandle(self._handle)
        self._handle = None


def _build_single_instance_name() -> str:
    script_path = os.path.abspath(__file__).encode("utf-8")
    digest = hashlib.sha1(script_path).hexdigest()[:12]
    return f"Local\\BAAnalyzerV6Main_{digest}"


_STARTUP_INSTANCE_GUARD: SingleInstanceGuard | None = None


def _ensure_single_instance() -> bool:
    global _STARTUP_INSTANCE_GUARD
    if _STARTUP_INSTANCE_GUARD is not None:
        return True

    guard = SingleInstanceGuard(_build_single_instance_name())
    if not guard.acquire():
        return False

    _STARTUP_INSTANCE_GUARD = guard
    return True


if __name__ == "__main__" and _SCANNER_MODE and not _ensure_single_instance():
    print("BA Analyzer v6 is already running. Closing the new instance.")
    sys.exit(0)

REQUIRED = {
    "cv2": "opencv-python",
    "PIL": "pillow",
    "pygetwindow": "pygetwindow",
    "pyautogui": "pyautogui",
    "easyocr": "easyocr",
    "numpy": "numpy",
}
missing = [pkg for mod, pkg in REQUIRED.items() if not importlib.util.find_spec(mod)]
if missing:
    print(f"Missing required packages: {', '.join(missing)}")
    print(f"Run: {sys.executable} -m pip install {' '.join(missing)}")
    print(f"Or:  {sys.executable} -m pip install -r requirements.txt")
    sys.exit(1)


def _ensure_assets_with_startup_ui() -> None:
    from core.asset_manager import ensure_assets_ready

    state: dict[str, object] = {
        "root": None,
        "status": None,
        "detail": None,
        "bar": None,
        "indeterminate": False,
    }

    stage_text = {
        "download": "BA Planner 데이터를 다운로드하고 있습니다.",
        "verify": "다운로드한 데이터를 확인하고 있습니다.",
        "extract": "데이터를 설치할 준비를 하고 있습니다.",
        "install": "데이터를 설치하고 있습니다.",
        "done": "데이터 설치가 완료되었습니다.",
    }

    def format_bytes(value: int) -> str:
        if value >= 1024 * 1024:
            return f"{value / (1024 * 1024):.1f} MB"
        if value >= 1024:
            return f"{value / 1024:.1f} KB"
        return f"{value} B"

    def ensure_window() -> tuple[tk.Tk, tk.StringVar, tk.StringVar, ttk.Progressbar]:
        root = state.get("root")
        if root is not None:
            return (
                root,
                state["status"],
                state["detail"],
                state["bar"],
            )

        root = tk.Tk()
        root.title("BA Planner")
        root.resizable(False, False)
        root.attributes("-topmost", True)
        root.protocol("WM_DELETE_WINDOW", lambda: None)

        frame = ttk.Frame(root, padding=18)
        frame.pack(fill="both", expand=True)
        status = tk.StringVar(value="BA Planner 데이터를 준비하고 있습니다.")
        detail = tk.StringVar(value="첫 실행에는 잠시 시간이 걸릴 수 있습니다.")
        ttk.Label(frame, textvariable=status, width=46).pack(anchor="w")
        ttk.Label(frame, textvariable=detail, width=46).pack(anchor="w", pady=(6, 10))
        bar = ttk.Progressbar(frame, mode="indeterminate", length=360)
        bar.pack(fill="x")

        root.update_idletasks()
        width = root.winfo_width()
        height = root.winfo_height()
        x = max(0, (root.winfo_screenwidth() - width) // 2)
        y = max(0, (root.winfo_screenheight() - height) // 2)
        root.geometry(f"+{x}+{y}")
        root.deiconify()

        state["root"] = root
        state["status"] = status
        state["detail"] = detail
        state["bar"] = bar
        return root, status, detail, bar

    def progress(stage: str, current: int, total: int) -> None:
        root, status, detail, bar = ensure_window()
        status.set(stage_text.get(stage, "BA Planner 데이터를 준비하고 있습니다."))
        if total > 0:
            if state.get("indeterminate"):
                bar.stop()
                state["indeterminate"] = False
            bar.configure(mode="determinate", maximum=total, value=current)
            percent = min(100, int((current / total) * 100)) if total else 0
            detail.set(f"{format_bytes(current)} / {format_bytes(total)} ({percent}%)")
        else:
            bar.configure(mode="indeterminate")
            if not state.get("indeterminate"):
                bar.start(12)
                state["indeterminate"] = True
            detail.set("잠시만 기다려 주세요.")
        root.update_idletasks()
        root.update()

    try:
        ensure_assets_ready(progress=progress)
    finally:
        root = state.get("root")
        if root is not None:
            try:
                state["bar"].stop()
                root.destroy()
            except TclError:
                pass


try:
    _ensure_assets_with_startup_ui()
except Exception as exc:
    print(f"Asset setup failed: {exc}")
    try:
        messagebox.showerror("BA Planner", f"BA Planner 데이터를 준비하지 못했습니다.\n\n{exc}")
    except Exception:
        pass
    sys.exit(1)

if __name__ == "__main__" and not _SCANNER_MODE:
    from gui.viewer_app_qt import main as planner_main

    raise SystemExit(planner_main())

try:
    from core.analyzer import analyze_scan_summary
    from core.capture import (
        activate_target_window,
        clear_target,
        find_target_hwnd,
        get_target_info,
        is_target_foreground,
        set_target_window,
    )
    from core.config import (
        activate_profile,
        get_active_profile_name,
        get_storage_paths,
        list_profiles,
        load_config,
        load_regions,
        save_config,
    )
    from core.db_writer import build_scan_meta
    from core.inventory_profiles import inventory_profile_labels, normalize_inventory_profile_ids
    from core.inventory_answer_samples import inventory_resolution_key, resolution_sample_dir
    from core.lobby_watcher import LobbyWatcher, WatcherState
    from core.log_context import set_debug_dump
    from core.logger import LOG_APP, enable_scan_debug_log, get_logger, setup_logging
    from core.repository import ScanRepository
    from core.scan_status import make_status_event, read_status_ack, reset_status_log, write_status_ack, write_status_event
    from core.scanner import ItemEntry, ScanResult, Scanner
    from core.states import AppState, StateMachine, can_transition
    from core.template_cache import warmup_all
    from gui.floating import FloatingOverlay
    from gui.input_test_overlay import InputTestOverlay
    from gui.profile_dialog import choose_profile
    from gui.viewer_launcher import open_student_viewer
    from gui.window_picker import WindowPicker
except ModuleNotFoundError as exc:
    missing_module = exc.name or "unknown module"
    print(f"Startup import failed: missing module '{missing_module}'")
    print(f"Run: {sys.executable} -m pip install -r requirements.txt")
    traceback.print_exc()
    sys.exit(1)

_log = get_logger(LOG_APP)

_ITEM_SCAN_FILTER_OPTIONS: list[tuple[str, str]] = [
    ("all", "전체"),
    ("tech_notes", "기술 노트"),
    ("tactical_bd", "전술 교육 BD"),
    ("ooparts", "오파츠"),
    ("student_elephs", "엘레프"),
    ("presents", "선물"),
    ("activity_reports", "활동 보고서"),
]
_FULL_SCAN_ITEM_FILTERS: tuple[str, ...] = (
    "student_elephs",
    "presents",
    "ooparts",
    "tactical_bd",
    "tech_notes",
    "activity_reports",
)


class ScanReviewDialog(tk.Toplevel):
    def __init__(self, master, rows: list[dict]):
        super().__init__(master)
        self.title("Scan Review")
        self.result = False
        self._rows = rows
        self._quantity_var = tk.StringVar()
        self.transient(master)
        self.attributes("-topmost", True)
        self.grab_set()
        self.geometry("920x520")
        self.minsize(780, 420)

        root = ttk.Frame(self, padding=12)
        root.pack(fill="both", expand=True)

        summary = ttk.Label(
            root,
            text=(
                "Review highlighted scan results. Edit the selected quantity, "
                "then save to commit the scan."
            ),
        )
        summary.pack(anchor="w", pady=(0, 8))

        tree_frame = ttk.Frame(root)
        tree_frame.pack(fill="both", expand=True)

        columns = ("kind", "status", "name", "old", "quantity", "reason")
        self._tree = ttk.Treeview(tree_frame, columns=columns, show="headings", height=14)
        headings = {
            "kind": "Kind",
            "status": "Status",
            "name": "Item",
            "old": "Previous",
            "quantity": "Commit Qty",
            "reason": "Reason",
        }
        widths = {
            "kind": 90,
            "status": 130,
            "name": 260,
            "old": 90,
            "quantity": 90,
            "reason": 260,
        }
        for column in columns:
            self._tree.heading(column, text=headings[column])
            self._tree.column(column, width=widths[column], stretch=(column in {"name", "reason"}))

        self._tree.tag_configure("zero_filled", background="#ffd6d6")
        self._tree.tag_configure("dp_aligned", background="#fff0bf")
        self._tree.tag_configure("order_inferred", background="#fff0bf")
        self._tree.tag_configure("sequence_inferred", background="#fff0bf")
        self._tree.tag_configure("weapon_sequence_checked", background="#fff0bf")
        self._tree.tag_configure("weapon_sequence_inferred", background="#fff0bf")
        self._tree.tag_configure("gap_recovered", background="#ffe0b8")
        self._tree.tag_configure("edited", background="#d8edff")

        scroll = ttk.Scrollbar(tree_frame, orient="vertical", command=self._tree.yview)
        self._tree.configure(yscrollcommand=scroll.set)
        self._tree.pack(fill="both", expand=True, side="left")
        scroll.pack(side="right", fill="y")

        editor = ttk.Frame(root)
        editor.pack(fill="x", pady=(10, 0))
        ttk.Label(editor, text="Selected quantity").pack(side="left")
        self._quantity_entry = ttk.Entry(editor, textvariable=self._quantity_var, width=14)
        self._quantity_entry.pack(side="left", padx=(8, 8))
        ttk.Button(editor, text="Apply edit", command=self._apply_selected).pack(side="left")
        ttk.Button(editor, text="Use scanned", command=self._use_scanned).pack(side="left", padx=(8, 0))

        buttons = ttk.Frame(root)
        buttons.pack(fill="x", pady=(12, 0))
        ttk.Button(buttons, text="Do not save", command=self._cancel).pack(side="left")
        ttk.Button(buttons, text="Save scan", command=self._accept).pack(side="right")

        self._tree.bind("<<TreeviewSelect>>", lambda _event: self._load_selected())
        self._tree.bind("<Double-Button-1>", lambda _event: self._focus_quantity())
        self._quantity_entry.bind("<Return>", lambda _event: self._apply_selected())
        self.protocol("WM_DELETE_WINDOW", self._cancel)

        for idx, row in enumerate(self._rows):
            self._insert_or_update_row(idx)
        if self._rows:
            first = "0"
            self._tree.selection_set(first)
            self._tree.focus(first)
            self._load_selected()
        self.after(50, self._raise_window)

    def _raise_window(self) -> None:
        try:
            self.deiconify()
            self.lift()
            self.focus_force()
            self._quantity_entry.focus_set()
        except TclError:
            pass

    def _row_values(self, row: dict) -> tuple[str, str, str, str, str, str]:
        item: ItemEntry = row["item"]
        meta = getattr(item, "scan_meta", {}) or {}
        return (
            row.get("kind", ""),
            str(meta.get("status") or "review"),
            str(item.name or item.item_id or ""),
            str(row.get("old_quantity") or ""),
            str(item.quantity or ""),
            str(meta.get("reason") or ""),
        )

    def _insert_or_update_row(self, idx: int) -> None:
        row = self._rows[idx]
        item: ItemEntry = row["item"]
        meta = getattr(item, "scan_meta", {}) or {}
        status = str(meta.get("status") or "review")
        tags = [status]
        if meta.get("user_edited"):
            tags.append("edited")
        iid = str(idx)
        values = self._row_values(row)
        if self._tree.exists(iid):
            self._tree.item(iid, values=values, tags=tags)
        else:
            self._tree.insert("", "end", iid=iid, values=values, tags=tags)

    def _selected_index(self) -> int | None:
        selected = self._tree.selection()
        if not selected:
            return None
        try:
            return int(selected[0])
        except ValueError:
            return None

    def _load_selected(self) -> None:
        idx = self._selected_index()
        if idx is None:
            self._quantity_var.set("")
            return
        self._quantity_var.set(str(self._rows[idx]["item"].quantity or ""))

    def _focus_quantity(self) -> None:
        self._quantity_entry.focus_set()
        self._quantity_entry.select_range(0, "end")

    def _apply_selected(self) -> None:
        idx = self._selected_index()
        if idx is None:
            return
        value = self._quantity_var.get().strip()
        item: ItemEntry = self._rows[idx]["item"]
        item.quantity = value
        item.scan_meta = dict(getattr(item, "scan_meta", {}) or {})
        item.scan_meta["user_edited"] = True
        item.scan_meta["review_required"] = False
        self._insert_or_update_row(idx)

    def _use_scanned(self) -> None:
        idx = self._selected_index()
        if idx is None:
            return
        item: ItemEntry = self._rows[idx]["item"]
        meta = getattr(item, "scan_meta", {}) or {}
        scanned = meta.get("scanned_quantity")
        if scanned is None:
            return
        self._quantity_var.set(str(scanned))
        self._apply_selected()

    def _accept(self) -> None:
        self._apply_selected()
        for row in self._rows:
            item: ItemEntry = row["item"]
            item.scan_meta = dict(getattr(item, "scan_meta", {}) or {})
            item.scan_meta["review_confirmed"] = True
            item.scan_meta["review_required"] = False
        self.result = True
        self.destroy()

    def _cancel(self) -> None:
        self.result = False
        self.destroy()


class App(tk.Tk):
    def __init__(
        self,
        *,
        use_saved_target: bool = False,
        auto_scan_mode: str = "",
        suppress_overlay: bool = False,
    ):
        super().__init__()
        self.withdraw()
        self.title("BA Analyzer v6")
        self.protocol("WM_DELETE_WINDOW", self._on_close_requested)
        self._use_saved_target = bool(use_saved_target)
        self._auto_scan_mode = str(auto_scan_mode or "").strip()
        self._suppress_overlay = bool(suppress_overlay)

        setup_logging()
        _log.info("app init: loading regions")
        self._regions = load_regions()
        profiles = list_profiles()
        last_profile = get_active_profile_name()
        _log.info(
            "app init: opening profile dialog (profiles=%d, last_profile=%s)",
            len(profiles),
            last_profile or "<none>",
        )
        if self._use_saved_target:
            selected_profile = last_profile or (profiles[0] if profiles else "Default")
        else:
            selected_profile = choose_profile(
                self,
                profiles,
                last_profile=last_profile,
            )
        if not selected_profile:
            _log.info("app init: profile selection cancelled")
            self._destroyed = True
            self.destroy()
            return

        _log.info("app init: selected profile '%s'", selected_profile)
        self._storage = activate_profile(selected_profile)
        self._config = load_config()
        self._profile_name = self._storage.profile_name
        self.title(f"BA Analyzer v6 - {self._profile_name}")
        self._repo = ScanRepository(base_dir=self._storage.data_dir)

        if self._config.get("debug_dump", False):
            from core.config import BASE_DIR

            set_debug_dump(enabled=True, dump_dir=BASE_DIR / "debug_dump")
            _log.info("debug dump enabled")

        warmup_all()

        self._sm = StateMachine(AppState.INIT, name="App")
        self._scanner: Scanner | None = None
        self._watcher: LobbyWatcher | None = None
        self._result: ScanResult | None = None
        self._scan_thread: threading.Thread | None = None
        self._asv = None
        self._closing = False
        self._shutdown_requested = False
        self._shutdown_deadline: float | None = None
        self._destroyed = False
        self._target_close_handled = False
        self._ui_queue: queue.Queue[tuple] = queue.Queue()
        self._scan_status_write_lock = threading.Lock()
        self._last_item_scan_filter: tuple[str, ...] = ("all",)

        self._overlay = FloatingOverlay(
            self,
            on_scan_items=lambda: self._request_scan("items"),
            on_scan_resources=lambda: self._request_scan("resources"),
            on_scan_equipment=lambda: self._request_scan("equipment"),
            on_scan_students=lambda: self._request_scan("students"),
            on_scan_current_student=lambda: self._request_scan("student_current"),
            on_scan_all=lambda: self._request_scan("all"),
            on_stop=self._stop_scan,
            on_input_test=self._open_input_test,
            on_settings=self._open_settings,
            on_view_students=lambda: open_student_viewer(self),
        )
        self._input_test_overlay = InputTestOverlay(self)
        self.bind_all("<space>", self._on_spacebar_stop, add="+")
        self.bind_all("<KeyPress-space>", self._on_spacebar_stop, add="+")

        self._transition_to(AppState.IDLE, reason="startup_ready")
        self.after(50, self._drain_ui_queue)
        self.after(500, self._poll_target_window)
        self.after(500, self._poll_scan_stop_request)
        if self._use_saved_target and self._config.get("target_hwnd"):
            set_target_window(
                int(self._config.get("target_hwnd") or 0),
                str(self._config.get("target_title") or ""),
            )
            self._transition_to(AppState.WATCHING, reason="saved_window_selected")
            if self._auto_scan_mode:
                self.after(800, lambda: self._request_scan(self._auto_scan_mode))
        else:
            clear_target()
            self.after(300, self._open_window_picker)
        self.after(1500, self._check_app_update_notice)

    @property
    def state(self) -> AppState:
        return self._sm.state

    def _set_state(self, new: AppState, reason: str = "") -> bool:
        return self._sm.transition(new, reason=reason)

    def _force_state(self, new: AppState, reason: str = "") -> None:
        self._sm.force(new, reason=reason)

    def can_transition(self, from_state: AppState, to_state: AppState) -> bool:
        return can_transition(from_state, to_state)

    def _transition_to(self, new: AppState, reason: str = "", *, force: bool = False) -> bool:
        old = self.state
        ok = True
        if force:
            self._force_state(new, reason)
        else:
            ok = self._set_state(new, reason)
        if ok:
            self._apply_state_effects(old, new, reason)
        return ok

    def _show_overlay_unless_suppressed(self) -> None:
        if self._suppress_overlay:
            self._overlay.hide()
        else:
            self._overlay.show()

    def _apply_state_effects(self, old: AppState, new: AppState, reason: str) -> None:
        self._overlay.set_app_state(new)

        if new == AppState.IDLE:
            self._stop_watcher()
            self._input_test_overlay.hide()
            self._overlay.hide()
            return

        if new == AppState.WATCHING:
            self._ensure_watcher_running()
            self._overlay.set_lobby_state(bool(self._watcher and self._watcher.in_lobby))
            if (not self._suppress_overlay) and self._should_show_watching_overlay():
                self._show_overlay_unless_suppressed()
            else:
                self._overlay.hide()
            return

        if new == AppState.SCANNING:
            self._pause_watcher()
            self._input_test_overlay.hide()
            if self._suppress_overlay:
                self._overlay.hide()
            else:
                self._show_overlay_unless_suppressed()
            return

        if new == AppState.ERROR:
            if self._scanner:
                self._scanner.stop()
            self._pause_watcher()
            self._overlay.add_log("오류 상태 진입. 복구 동작만 허용됩니다.")
            self._show_overlay_unless_suppressed()
            return

        if new == AppState.STOPPING:
            if self._scanner:
                self._scanner.stop()
            self._pause_watcher()
            self._input_test_overlay.hide()
            self._overlay.add_log("정리 중...")
            self._show_overlay_unless_suppressed()

    def _is_scanning(self) -> bool:
        return self.state == AppState.SCANNING

    def _is_stopping(self) -> bool:
        return self.state == AppState.STOPPING

    def _can_scan(self) -> bool:
        return self.state == AppState.WATCHING

    def _create_watcher(self) -> LobbyWatcher:
        lobby_region = self._regions["lobby"]["detect_flag"]
        return LobbyWatcher(
            lobby_region=lobby_region,
            on_enter=lambda: self._dispatch_ui(self._on_lobby_enter),
            on_leave=lambda: self._dispatch_ui(self._on_lobby_leave),
            on_window_move=lambda *_a: self._dispatch_ui(self._overlay._reposition),
            on_target_closed=lambda: self._dispatch_ui(self._on_target_window_closed, "watcher"),
        )

    def _dispatch_ui(self, callback, *args, **kwargs) -> bool:
        if self._destroyed or self._shutdown_requested:
            return False
        self._ui_queue.put((callback, args, kwargs))
        return True

    def _check_app_update_notice(self) -> None:
        def task() -> None:
            try:
                from core.app_update import check_for_app_update

                update = check_for_app_update()
            except Exception:
                return
            if update:
                self._dispatch_ui(self._show_app_update_notice, update)

        threading.Thread(target=task, name="AppUpdateCheck", daemon=True).start()

    def _show_app_update_notice(self, update: dict) -> None:
        version = str(update.get("app_version") or "").strip()
        url = str(update.get("url") or update.get("release_url") or "").strip()
        if not version or not url:
            return
        if messagebox.askyesno(
            "BA Planner Update",
            f"새 BA Planner 버전이 있습니다: {version}\n\n다운로드 페이지를 열까요?",
            parent=self,
        ):
            webbrowser.open(url)

    def _drain_ui_queue(self) -> None:
        if self._destroyed:
            return
        while True:
            try:
                callback, args, kwargs = self._ui_queue.get_nowait()
            except queue.Empty:
                break
            try:
                callback(*args, **kwargs)
            except TclError:
                if not self._destroyed:
                    raise
            except Exception:
                _log.exception("ui callback failed")
        self.after(50, self._drain_ui_queue)

    def _poll_target_window(self) -> None:
        if self._destroyed:
            return
        try:
            self._check_target_window_closed(source="poll")
            self._sync_watching_overlay_visibility()
        finally:
            if not self._destroyed:
                self.after(500, self._poll_target_window)

    def _ensure_watcher_running(self) -> None:
        if self._is_stopping():
            return
        if self._watcher is None:
            self._watcher = self._create_watcher()
            self._watcher.start()
            return
        if self._watcher.state == WatcherState.PAUSED:
            self._watcher.resume()
        elif self._watcher.state == WatcherState.RUNNING and self._watcher.is_alive:
            return
        elif self._watcher.state not in (WatcherState.RUNNING,):
            self._watcher.start()

    def _stop_watcher(self) -> None:
        if self._watcher is not None:
            stopped = self._watcher.stop()
            if stopped:
                self._watcher = None

    def _pause_watcher(self) -> None:
        if self._watcher and self._watcher.state == WatcherState.RUNNING:
            self._watcher.pause()

    def _should_show_watching_overlay(self) -> bool:
        if self._suppress_overlay:
            return False
        return bool(
            self.state == AppState.WATCHING
            and self._watcher
            and is_target_foreground()
        )

    def _sync_watching_overlay_visibility(self) -> None:
        if self.state != AppState.WATCHING:
            return
        if self._should_show_watching_overlay():
            self._overlay.set_lobby_state(bool(self._watcher and self._watcher.in_lobby))
            self._show_overlay_unless_suppressed()
        else:
            self._overlay.set_lobby_state(bool(self._watcher and self._watcher.in_lobby))
            self._overlay.hide()

    def _on_lobby_enter(self) -> None:
        self._overlay.set_lobby_state(True)
        if self.state == AppState.WATCHING:
            self._sync_watching_overlay_visibility()
        elif self.state == AppState.ERROR:
            self._show_overlay_unless_suppressed()

    def _on_lobby_leave(self) -> None:
        self._overlay.set_lobby_state(False)
        if self.state == AppState.WATCHING:
            self._sync_watching_overlay_visibility()
        elif self.state != AppState.SCANNING:
            self._overlay.hide()

    def _check_target_window_closed(self, *, source: str) -> None:
        if self._destroyed or self._shutdown_requested:
            return
        target_hwnd, target_title = get_target_info()
        if not target_hwnd:
            return
        if find_target_hwnd() is not None:
            return
        self._on_target_window_closed(source, target_title)

    def _on_target_window_closed(self, source: str, title: str = "") -> None:
        if self._destroyed or self._shutdown_requested or self._target_close_handled:
            return
        self._target_close_handled = True
        target_name = title or self._config.get("target_title", "") or "selected target window"
        _log.info("target window closed; shutting down app (source=%s, title=%s)", source, target_name)
        self._overlay.add_log(f"타겟 창이 닫혀서 BA Analyzer도 함께 종료합니다: {target_name}")
        self._on_close_requested()

    def _scan_status_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_status.jsonl"

    def _scan_stop_request_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_stop_requested.flag"

    def _scan_status_ack_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_status_ack.json"

    def _reset_scan_status_log(self) -> None:
        try:
            reset_status_log(self._scan_status_path())
            write_status_ack(self._scan_status_ack_path(), 0)
        except Exception:
            _log.exception("failed to reset scan status log")

    def _clear_scan_stop_request(self) -> None:
        try:
            self._scan_stop_request_path().unlink(missing_ok=True)
        except Exception:
            _log.exception("failed to clear scan stop request")

    def _poll_scan_stop_request(self) -> None:
        if self._destroyed:
            return
        try:
            path = self._scan_stop_request_path()
            if path.exists() and self.state in (AppState.SCANNING, AppState.PAUSED):
                try:
                    path.unlink(missing_ok=True)
                except Exception:
                    pass
                self._stop_scan()
        except Exception:
            _log.exception("failed to poll scan stop request")
        finally:
            if not self._destroyed:
                self.after(500, self._poll_scan_stop_request)

    def _write_scan_status_event(self, event: dict) -> None:
        try:
            with self._scan_status_write_lock:
                write_status_event(self._scan_status_path(), event)
        except Exception:
            _log.exception("failed to write scan status event")

    def _wait_scan_status_ack(self, seq: int, timeout: float = 0.55) -> bool:
        if not seq or seq <= 0:
            return True
        deadline = time.monotonic() + max(0.0, timeout)
        ack_path = self._scan_status_ack_path()
        while time.monotonic() < deadline:
            if self._destroyed or self._shutdown_requested:
                return False
            if read_status_ack(ack_path) >= seq:
                return True
            time.sleep(0.025)
        _log.debug("scan status ack timeout: seq=%s ack=%s", seq, read_status_ack(ack_path))
        return False

    def _handle_scan_progress_state(self, state: dict) -> None:
        self._overlay.set_scan_progress(
            state.get("current"),
            state.get("total"),
            state.get("note", ""),
        )
        self._write_scan_status_event(make_status_event("progress.update", data=state))

    def _build_scanner(self, meta: dict) -> Scanner:
        from core.autosave import AutoSaveManager

        scan_id = meta.get("scan_id", "unknown")
        self._asv = AutoSaveManager(
            scan_id=scan_id,
            save_dir=self._storage.scans_dir,
            on_save_ok=lambda msg: self._dispatch_ui(self._overlay.add_log, msg),
            on_save_fail=lambda msg: self._dispatch_ui(self._overlay.add_log, msg),
        )

        return Scanner(
            self._regions,
            on_progress=lambda msg: self._dispatch_ui(self._overlay.add_log, msg),
            on_progress_state=lambda state: self._dispatch_ui(self._handle_scan_progress_state, dict(state)),
            on_status_event=self._write_scan_status_event,
            on_status_ack_wait=self._wait_scan_status_ack,
            student_saved_data={},
            student_total_hint=None,
            autosave_manager=self._asv,
            inventory_profile_id=meta.get("item_scan_filter_profile") or None,
            inventory_detail_override_dir=self._inventory_detail_override_dir(),
            inventory_capture_resolution=meta.get("window_size"),
        )

    def _choose_item_scan_filter(self) -> str | list[str] | None:
        dialog = tk.Toplevel(self)
        dialog.title("아이템 스캔 필터")
        dialog.resizable(False, False)
        try:
            if bool(self.winfo_viewable()):
                dialog.transient(self)
        except Exception:
            pass
        dialog.grab_set()

        current_selection = set(normalize_inventory_profile_ids(self._last_item_scan_filter))
        if not current_selection:
            current_selection = {"all"}
        selected: dict[str, tk.BooleanVar] = {}
        result: dict[str, str | list[str] | None] = {"value": None}

        frame = tk.Frame(dialog, padx=14, pady=14)
        frame.pack(fill="both", expand=True)

        tk.Label(
            frame,
            text="이번 아이템 스캔에서 사용할 필터를 선택하세요.",
            anchor="w",
            justify="left",
        ).pack(fill="x", pady=(0, 10))

        def on_toggle(value: str) -> None:
            if value == "all":
                if selected["all"].get():
                    for other, _ in _ITEM_SCAN_FILTER_OPTIONS:
                        if other != "all":
                            selected[other].set(False)
                return
            if selected[value].get():
                selected["all"].set(False)

        for value, label in _ITEM_SCAN_FILTER_OPTIONS:
            selected[value] = tk.BooleanVar(value=value in current_selection)
            tk.Checkbutton(
                frame,
                text=label,
                variable=selected[value],
                onvalue=True,
                offvalue=False,
                anchor="w",
                justify="left",
                command=lambda option=value: on_toggle(option),
            ).pack(fill="x", pady=1)

        buttons = tk.Frame(frame)
        buttons.pack(fill="x", pady=(12, 0))

        def submit() -> None:
            chosen = [value for value, _ in _ITEM_SCAN_FILTER_OPTIONS if selected[value].get()]
            if not chosen:
                messagebox.showinfo("Item Scan Filter", "Select at least one filter.", parent=dialog)
                return
            if "all" in chosen:
                result["value"] = "all"
            elif len(chosen) == 1:
                result["value"] = chosen[0]
            else:
                result["value"] = chosen
            dialog.destroy()

        def cancel() -> None:
            result["value"] = None
            dialog.destroy()

        tk.Button(buttons, text="취소", command=cancel).pack(side="right", padx=(8, 0))
        tk.Button(buttons, text="확인", command=submit).pack(side="right")

        dialog.protocol("WM_DELETE_WINDOW", cancel)
        dialog.update_idletasks()
        width = dialog.winfo_reqwidth()
        height = dialog.winfo_reqheight()
        sw = dialog.winfo_screenwidth()
        sh = dialog.winfo_screenheight()
        dialog.geometry(f"+{(sw - width) // 2}+{(sh - height) // 2}")
        dialog.deiconify()
        dialog.lift()
        dialog.attributes("-topmost", True)
        dialog.after(250, lambda: dialog.attributes("-topmost", False))
        dialog.focus_force()
        dialog.wait_window()
        choice = result["value"]
        normalized_choice = normalize_inventory_profile_ids(choice)
        if normalized_choice:
            self._last_item_scan_filter = normalized_choice
        return choice

    def _student_scan_options(self) -> dict:
        return {"student_merge_mode": "replace"}

    def _request_scan(self, mode: str) -> None:
        if self._is_scanning():
            self._overlay.add_log("이미 스캔 중입니다.")
            return
        if self._is_stopping():
            self._overlay.add_log("정리 중에는 새 작업을 시작할 수 없습니다.")
            return
        if self.state == AppState.ERROR:
            self._overlay.add_log("오류 상태에서는 복구 후 다시 시도해 주세요.")
            return
        if not self._can_scan():
            self._overlay.add_log(
                "창을 먼저 선택해 주세요." if self.state == AppState.IDLE else "현재 상태에서는 스캔할 수 없습니다."
            )
            return
        activate_target_window()
        item_scan_filter: str | list[str] | None = None
        if mode == "items":
            item_scan_filter = self._choose_item_scan_filter()
            if item_scan_filter is None:
                self._overlay.add_log("아이템 스캔 필터 선택이 취소되었습니다.")
                return
        elif mode == "all":
            item_scan_filter = list(_FULL_SCAN_ITEM_FILTERS)
        student_scan_options: dict | None = None
        if mode in ("students", "student_current", "all"):
            student_scan_options = self._student_scan_options()
        self._scan(
            mode,
            item_scan_filter=item_scan_filter,
            student_scan_options=student_scan_options,
        )

    def _scan(
        self,
        mode: str,
        item_scan_filter: str | list[str] | None = None,
        student_scan_options: dict | None = None,
    ) -> None:
        meta = build_scan_meta()
        if item_scan_filter is not None:
            normalized_filters = normalize_inventory_profile_ids(item_scan_filter)
            if normalized_filters and normalized_filters != ("all",):
                meta["item_scan_filter_profile"] = (
                    list(normalized_filters) if len(normalized_filters) > 1 else normalized_filters[0]
                )
            else:
                meta["item_scan_filter_profile"] = None
            meta["item_scan_filter_label"] = inventory_profile_labels(item_scan_filter)
        if mode in ("items", "equipment"):
            meta["direct_inventory_scan"] = bool(self._watcher and not self._watcher.in_lobby)
        if mode in ("students", "student_current", "all"):
            meta["student_force_full_measure"] = True
            meta.update(self._student_scan_options())
        if student_scan_options:
            meta.update(student_scan_options)
        debug_log_path = enable_scan_debug_log(str(meta.get("scan_id") or "unknown"), mode)
        meta["scan_debug_log_path"] = str(debug_log_path)
        self._overlay.add_log(f"스캔 디버그 로그: {debug_log_path}")
        self._result = None
        self._reset_scan_status_log()
        self._clear_scan_stop_request()
        self._overlay.reset_scan_progress()
        self._scanner = self._build_scanner(meta)
        if self._scanner:
            self._scanner.clear_stop()

        if not self._transition_to(AppState.SCANNING, reason=f"scan_requested:{mode}"):
            _log.error("failed to enter scanning state")
            return

        self.update_idletasks()

        def task():
            try:
                self._run_scan_task(mode, meta)
            finally:
                self._dispatch_ui(self._on_scan_finished)

        self._scan_thread = threading.Thread(target=task, name=f"Scanner-{mode}", daemon=True)
        self._scan_thread.start()

    def _run_scan_task(self, mode: str, meta: dict) -> None:
        result = ScanResult()
        scanner = self._scanner
        if scanner is None:
            return

        def not_stopped() -> bool:
            return not scanner._stop

        try:
            students_done = False
            if mode == "all" and not_stopped():
                result.students = scanner.scan_students()
                students_done = True
                skipped = sum(1 for s in result.students if s.skipped)
                self._dispatch_ui(
                    self._overlay.add_log,
                    f"학생 {len(result.students)}명 (스킵 {skipped})",
                )
                scanner._return_lobby()

            if mode in ("resources", "all"):
                result.resources = scanner.scan_resources()
                self._dispatch_ui(self._overlay.update_resources, result.resources)
                self._dispatch_ui(self._overlay.add_log, "자원 스캔 완료")

            if mode in ("items", "all"):
                selected_filter = meta.get("item_scan_filter_label")
                if selected_filter:
                    self._dispatch_ui(self._overlay.add_log, f"아이템 필터: {selected_filter}")
                direct_inventory_scan = bool(meta.get("direct_inventory_scan"))
                result.items = scanner.scan_items(
                    meta.get("item_scan_filter_profile"),
                    navigate_from_menu=not direct_inventory_scan,
                    return_to_lobby=not direct_inventory_scan,
                )
                self._dispatch_ui(self._overlay.add_log, f"아이템 {len(result.items)}개")

            if mode in ("equipment", "all") and not_stopped():
                direct_inventory_scan = bool(meta.get("direct_inventory_scan"))
                result.equipment = scanner.scan_equipment(
                    navigate_from_menu=not direct_inventory_scan,
                    return_to_lobby=not direct_inventory_scan,
                )
                self._dispatch_ui(self._overlay.add_log, f"장비 {len(result.equipment)}개")

            if mode in ("students", "all") and not students_done and not_stopped():
                result.students = scanner.scan_students()
                skipped = sum(1 for s in result.students if s.skipped)
                self._dispatch_ui(
                    self._overlay.add_log,
                    f"학생 {len(result.students)}명 (스킵 {skipped})",
                )

            if mode == "student_current" and not_stopped():
                result.students = scanner.scan_current_student()
                skipped = sum(1 for s in result.students if s.skipped)
                self._dispatch_ui(
                    self._overlay.add_log,
                    f"현재 학생 {len(result.students)}명 (스킵 {skipped})",
                )

            self._result = result
            self._dispatch_ui(self._review_and_auto_save, result, meta)
        except Exception as exc:
            import traceback

            traceback.print_exc()
            if self._asv:
                self._asv.emergency_save(result, meta)
            self._dispatch_ui(
                self._write_scan_status_event,
                make_status_event("scan.exception", error=str(exc)),
            )
            self._dispatch_ui(self._overlay.add_log, f"스캔 오류: {exc}")
            self._dispatch_ui(self._transition_to, AppState.ERROR, str(exc))

    def _inventory_key_for_review(self, item: ItemEntry) -> str:
        return str(item.item_id or item.name or "")

    def _inventory_detail_override_dir(self) -> Path:
        return self._storage.root / "templates" / "inventory_detail"

    def _inventory_detail_name_override_dir(self) -> Path:
        return self._storage.root / "templates" / "inventory_detail_names"

    def _safe_template_name(self, value: str) -> str:
        return "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in value).strip("._")

    def _save_confirmed_inventory_templates(self, rows: list[dict], meta: dict) -> int:
        saved = 0
        override_root = self._inventory_detail_override_dir()
        name_override_root = self._inventory_detail_name_override_dir()
        scan_id = str(meta.get("scan_id") or "unknown")
        for row in rows:
            item: ItemEntry = row["item"]
            item_id = str(item.item_id or "").strip()
            if not item_id:
                continue
            if item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
                continue
            crop = getattr(item, "detail_crop", None)
            if crop is None:
                continue
            scan_meta = dict(getattr(item, "scan_meta", {}) or {})
            if not scan_meta.get("review_confirmed"):
                continue
            profile_id = str(scan_meta.get("profile_id") or "").strip()
            if not profile_id:
                continue
            resolution = inventory_resolution_key(
                scan_meta.get("capture_resolution") or meta.get("window_size")
            )
            if resolution is None:
                continue

            safe_name = self._safe_template_name(item_id)
            if not safe_name:
                continue
            target_dir = resolution_sample_dir(override_root, resolution, profile_id, safe_name)
            if target_dir is None:
                continue
            target_dir.mkdir(parents=True, exist_ok=True)
            sample_stem = self._safe_template_name(scan_id) or "sample"
            sample_name = sample_stem
            suffix = 2
            while (target_dir / f"{sample_name}.png").exists():
                sample_name = f"{sample_stem}_{suffix}"
                suffix += 1
            image_path = target_dir / f"{sample_name}.png"
            json_path = target_dir / f"{sample_name}.json"

            crop.save(image_path)
            name_crop = getattr(item, "detail_name_crop", None)
            name_image_path = None
            if name_crop is not None:
                name_target_dir = resolution_sample_dir(name_override_root, resolution, profile_id, safe_name)
                if name_target_dir is None:
                    continue
                name_target_dir.mkdir(parents=True, exist_ok=True)
                name_image_path = name_target_dir / f"{sample_name}.png"
                name_crop.save(name_image_path)

            payload = {
                "name": item_id,
                "profile_id": profile_id,
                "source": item.source,
                "item_id": item_id,
                "display_name": item.name,
                "quantity": item.quantity,
                "scan_id": scan_id,
                "confirmed_at": datetime.now().astimezone().isoformat(),
                "image_path": str(image_path),
                "name_image_path": str(name_image_path) if name_image_path else None,
                "template_source": "user_confirmed_scan",
                "capture_resolution": resolution,
                "sample_schema_version": 2,
                "roi_version": "inventory_detail_ratio_v1",
                "app_version": meta.get("app_version"),
                "scan_meta": scan_meta,
            }
            json_path.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            if name_image_path is not None:
                name_payload = dict(payload)
                name_payload["image_path"] = str(name_image_path)
                name_payload["detail_image_path"] = str(image_path)
                name_payload["template_kind"] = "detail_name"
                (name_image_path.with_suffix(".json")).write_text(
                    json.dumps(name_payload, ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )
            item.scan_meta["user_template_path"] = str(image_path)
            if name_image_path is not None:
                item.scan_meta["user_name_template_path"] = str(name_image_path)
            saved += 1
        if saved:
            _log.info("saved confirmed inventory detail templates: %d", saved)
            self._overlay.add_log(f"Saved {saved} confirmed inventory templates")
        return saved

    def _scan_review_rows(self, result: ScanResult) -> list[dict]:
        try:
            current_inventory = self._repo.load_current_inventory()
        except Exception:
            current_inventory = {}

        rows: list[dict] = []
        sections = (("item", result.items or []), ("equipment", result.equipment or []))
        for kind, entries in sections:
            for item in entries:
                meta = dict(getattr(item, "scan_meta", {}) or {})
                status = str(meta.get("status") or "ok")
                if not meta.get("review_required"):
                    continue

                key = self._inventory_key_for_review(item)
                old_entry = current_inventory.get(key, {})
                old_quantity = old_entry.get("quantity")
                scanned_quantity = str(item.quantity or "")
                item.scan_meta = meta
                item.scan_meta.setdefault("scanned_quantity", scanned_quantity)

                if (
                    status == "zero_filled"
                    and old_quantity not in (None, "", "0")
                    and scanned_quantity == "0"
                ):
                    item.quantity = str(old_quantity)
                    item.scan_meta["suggested_quantity"] = str(old_quantity)
                    item.scan_meta["reason"] = (
                        f"{item.scan_meta.get('reason') or 'zero_filled'}; "
                        "previous_nonzero_preserved"
                    )

                rows.append(
                    {
                        "kind": kind,
                        "item": item,
                        "old_quantity": old_quantity,
                    }
                )
        return rows

    def _review_and_auto_save(self, result: ScanResult, meta: dict) -> None:
        rows = self._scan_review_rows(result)
        _log.info("scan review rows: %d", len(rows))
        if rows:
            _log.info("opening scan review dialog")
            self._overlay.add_log(f"Review needed: {len(rows)} inventory entries")
            parent = self
            try:
                if self._overlay.winfo_exists():
                    parent = self._overlay
            except TclError:
                parent = self
            dialog = ScanReviewDialog(parent, rows)
            self.wait_window(dialog)
            if not dialog.result:
                scan_id = meta.get("scan_id", "unknown")
                _log.info("scan save skipped by review: %s", scan_id)
                self._overlay.add_log(f"Scan save skipped by review ({scan_id})")
                return
            self._save_confirmed_inventory_templates(rows, meta)

        _log.info("scan review accepted or not needed; saving")
        self._auto_save(result, meta)

    def _on_scan_finished(self) -> None:
        self._scanner = None
        self._scan_thread = None
        self._overlay.reset_scan_progress()

        if self._shutdown_requested:
            self._finish_shutdown(reason="scan_thread_finished")
            return

        if self._auto_scan_mode:
            self._finish_shutdown(reason="auto_scan_finished")
            return

        if self.state == AppState.STOPPING:
            next_state = AppState.WATCHING if self._config.get("target_hwnd") else AppState.IDLE
            self._transition_to(next_state, reason="stop_cleanup_finished")
            return

        if self.state == AppState.SCANNING:
            self._transition_to(AppState.WATCHING, reason="scan_finished")
            return

    def _stop_scan(self) -> None:
        if self.state not in (AppState.SCANNING, AppState.PAUSED):
            return
        self._overlay.add_log("스캔 중지 요청...")
        self._transition_to(AppState.STOPPING, reason="user_stop_requested")

    def _on_spacebar_stop(self, _event=None):
        if self.state not in (AppState.SCANNING, AppState.PAUSED):
            return None
        self._stop_scan()
        return "break"

    def _auto_save(self, result: ScanResult, meta: dict) -> None:
        from core.serializer import make_status_report, save_scan_json

        scan_id = meta.get("scan_id", "unknown")
        try:
            if self._asv:
                if not self._asv.final_save(result, meta):
                    raise RuntimeError("최종 저장 파일 작성 실패")
            else:
                json_path = self._storage.scans_dir / f"{scan_id}.json"
                save_scan_json(result, json_path, meta)
                _log.info(f"scan json saved: {json_path}")
            self._repo.save(result, meta)
            self._dispatch_ui(self._overlay.add_log, f"저장 완료 ({scan_id})")

            for line in make_status_report(result):
                self._dispatch_ui(self._overlay.add_log, line)

            if not result.students:
                return

            current_students = [student.to_dict() for student in result.students]
            all_changes = self._repo.load_student_changes()
            this_changes = [c for c in all_changes if c.get("scan_id") == scan_id]
            summary = analyze_scan_summary(current_students, this_changes, scan_id)

            if summary.total_field_changes:
                self._dispatch_ui(
                    self._overlay.add_log,
                    f"변경 {summary.total_field_changes}건 ({summary.changed_students}명)",
                )

            if summary.low_confidence:
                self._dispatch_ui(
                    self._overlay.add_log,
                    f"낮은 신뢰도 학생 {len(summary.low_confidence)}명",
                )
        except Exception as exc:
            import traceback

            traceback.print_exc()
            self._dispatch_ui(self._overlay.add_log, f"저장 실패: {exc}")
            self._dispatch_ui(self._transition_to, AppState.ERROR, f"save_failed:{exc}")

    def _open_window_picker(self) -> None:
        if self.state in (AppState.SCANNING, AppState.STOPPING):
            self._overlay.add_log("스캔/정리 중에는 창을 다시 선택할 수 없습니다.")
            return

        previous_hwnd = self._config.get("target_hwnd")
        previous_title = self._config.get("target_title", "")

        self._transition_to(AppState.IDLE, reason="window_picker_open")
        clear_target()

        def on_select(hwnd: int, title: str) -> None:
            self._config["target_hwnd"] = hwnd
            self._config["target_title"] = title
            self._target_close_handled = False
            save_config(self._config)
            set_target_window(hwnd, title)
            self._overlay.add_log(f"창 설정: {title}")
            self._transition_to(AppState.WATCHING, reason="window_selected")

        def on_cancel() -> None:
            if previous_hwnd:
                self._target_close_handled = False
                set_target_window(previous_hwnd, previous_title)
                self._transition_to(AppState.WATCHING, reason="window_picker_cancelled")
            else:
                self.destroy()

        WindowPicker(self, on_select=on_select, on_cancel=on_cancel)

    def _open_settings(self) -> None:
        self._open_window_picker()

    def _open_input_test(self) -> None:
        if self.state in (AppState.SCANNING, AppState.STOPPING):
            self._overlay.add_log("스캔/정리 중에는 입력 테스트를 열 수 없습니다.")
            return
        if not self._config.get("target_hwnd"):
            self._overlay.add_log("먼저 대상 게임 창을 선택해 주세요.")
            return
        self._input_test_overlay.show()

    def _on_close_requested(self) -> None:
        if self._closing:
            return
        self._closing = True
        self._shutdown_requested = True
        self._shutdown_deadline = time.monotonic() + SCANNER_CLOSE_GRACE_SECONDS
        self._transition_to(AppState.STOPPING, reason="app_close")
        self._wait_for_shutdown()

    def _wait_for_shutdown(self) -> None:
        if self._destroyed:
            return

        thread = self._scan_thread
        if thread and thread.is_alive():
            if self._shutdown_deadline is None or time.monotonic() < self._shutdown_deadline:
                self.after(100, self._wait_for_shutdown)
                return
            _log.warning("scanner shutdown grace expired; closing app with scan thread still alive")
            self._scanner = None
            self._scan_thread = None
            self._overlay.reset_scan_progress()

        self._finish_shutdown(reason="shutdown_ready")

    def _finish_shutdown(self, reason: str) -> None:
        if self._destroyed:
            return

        if self.state != AppState.STOPPING:
            self._transition_to(AppState.STOPPING, reason=reason)

        self._stop_watcher()
        self._destroyed = True
        try:
            self._input_test_overlay.destroy()
        except TclError:
            pass
        try:
            self._overlay.destroy()
        except TclError:
            pass
        self.destroy()

    def run(self) -> None:
        self.mainloop()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="BA Planner scanner bridge")
    parser.add_argument("--scanner", action="store_true", help="run the legacy scanner overlay")
    parser.add_argument("--use-saved-target", action="store_true", help="use the saved profile and game window")
    parser.add_argument("--suppress-overlay", action="store_true", help="hide the legacy scanner overlay during planner-launched scans")
    parser.add_argument(
        "--auto-scan",
        choices=("", "resources", "items", "equipment", "students", "student_current", "all"),
        default="",
        help="start this scan mode after the scanner overlay initializes",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        App(
            use_saved_target=args.use_saved_target,
            auto_scan_mode=args.auto_scan,
            suppress_overlay=args.suppress_overlay,
        ).run()
        return 0
    finally:
        if _STARTUP_INSTANCE_GUARD is not None:
            _STARTUP_INSTANCE_GUARD.release()


if __name__ == "__main__":
    raise SystemExit(main())
