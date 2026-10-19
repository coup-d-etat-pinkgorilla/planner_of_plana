from __future__ import annotations

from copy import deepcopy
import ctypes
from ctypes import wintypes
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from core.scanner_target_metadata import (
    PROCESS_QUERY_LIMITED_INFORMATION, configure_libraries, target_metadata,
)
from core.windows_scanner_adapter import WindowsCaptureInputAdapter

ROOT = Path(__file__).resolve().parents[2]
NULL = {"client_width": None, "client_height": None, "game": None}
IDENTITY = (101, 202)
HWND = 0x100000001
HANDLE = 0x200000002


class NativeFunction:
    def __init__(self, callback):
        self.callback = callback

    def __call__(self, *args):
        return self.callback(*args)


class FakeWindows:
    """No native calls: rect is logical unless PMv2 thread context is active."""
    def __init__(self, *, scale=1.0, physical=(1280, 720)):
        self.scale, self.physical = scale, physical
        self.pid, self.thread = IDENTITY
        self.exists = self.visible = True
        self.minimized = False
        self.title, self.class_name = "Blue Archive", "UnityWndClass"
        self.path = r"C:\private\never-emit\BlueArchive.exe"
        self.rect_ok = self.process_ok = self.name_ok = self.dpi_ok = True
        self.restore_ok = True
        self.geometry_error = self.name_error = False
        self.after_rect = lambda: None
        self.after_name = lambda: None
        self.context = 0x300000003
        self.original_context = self.context
        self.dpi_calls, self.open_calls, self.closed = [], [], []
        self.rect_calls = 0
        self.user = SimpleNamespace(
            IsWindow=NativeFunction(lambda _: self.exists),
            IsWindowVisible=NativeFunction(lambda _: self.visible),
            IsIconic=NativeFunction(lambda _: self.minimized),
            GetWindowThreadProcessId=NativeFunction(self.identity),
            GetClientRect=NativeFunction(self.rect),
            GetClassNameW=NativeFunction(self.window_class),
            SetThreadDpiAwarenessContext=NativeFunction(self.set_context),
            GetWindowTextLengthW=NativeFunction(lambda _: len(self.title)),
            GetWindowTextW=NativeFunction(self.window_title),
            GetForegroundWindow=NativeFunction(lambda: HWND),
            EnumWindows=NativeFunction(lambda callback, _: callback(HWND, 0)),
        )
        self.kernel = SimpleNamespace(
            OpenProcess=NativeFunction(self.open),
            QueryFullProcessImageNameW=NativeFunction(self.name),
            CloseHandle=NativeFunction(lambda handle: self.closed.append(handle) or True),
        )
        configure_libraries(self.user, self.kernel)

    def identity(self, _hwnd, pid):
        pid._obj.value = self.pid
        return self.thread

    def set_context(self, context):
        requested = context.value if isinstance(context, ctypes.c_void_p) else context
        pmv2 = ctypes.c_void_p(-4).value
        self.dpi_calls.append(requested)
        if not self.dpi_ok and requested == pmv2:
            return None
        if not self.restore_ok and requested == self.original_context:
            return None
        old, self.context = self.context, requested
        return old

    def rect(self, _hwnd, rect):
        self.rect_calls += 1
        if self.geometry_error:
            raise OSError("scripted unreadable rectangle")
        factor = 1 if self.context == ctypes.c_void_p(-4).value else self.scale
        rect._obj.left, rect._obj.top = 0, 0
        rect._obj.right, rect._obj.bottom = (round(value / factor) for value in self.physical)
        self.after_rect()
        return self.rect_ok

    def window_class(self, _hwnd, buffer, _size):
        buffer.value = self.class_name
        return len(self.class_name)

    def window_title(self, _hwnd, buffer, _size):
        buffer.value = self.title
        return len(self.title)

    def open(self, access, inherit, pid):
        self.open_calls.append((access, inherit, pid))
        return HANDLE if self.process_ok else None

    def name(self, handle, flags, buffer, length):
        if self.name_error:
            raise OSError("scripted process permission failure")
        self.assert_query = (handle, flags, length._obj.value)
        buffer.value, length._obj.value = self.path, len(self.path)
        self.after_name()
        return self.name_ok

    def metadata(self, expected=IDENTITY):
        return target_metadata(HWND, expected_identity=expected, libraries=(self.user, self.kernel))


class TargetMetadataTests(unittest.TestCase):
    def test_pointer_safe_signatures_and_large_handle_closed(self):
        native = FakeWindows()
        self.assertIs(native.kernel.OpenProcess.restype, ctypes.c_void_p)
        self.assertEqual([ctypes.c_void_p], native.kernel.CloseHandle.argtypes)
        self.assertEqual([ctypes.c_void_p], native.user.SetThreadDpiAwarenessContext.argtypes)
        self.assertIs(native.user.SetThreadDpiAwarenessContext.restype, ctypes.c_void_p)
        self.assertIs(native.kernel.QueryFullProcessImageNameW.argtypes[0], ctypes.c_void_p)
        self.assertIs(native.user.GetClientRect.argtypes[1]._type_, wintypes.RECT)
        self.assertEqual("blue_archive", native.metadata()["game"])
        self.assertEqual([(PROCESS_QUERY_LIMITED_INFORMATION, False, IDENTITY[0])], native.open_calls)
        self.assertEqual([HANDLE], native.closed)
        self.assertNotIn(native.path, json.dumps(native.metadata()))

    def test_physical_pixels_under_125_150_percent_and_thread_restore(self):
        for scale, dimensions in ((1.25, (1280, 720)), (1.5, (2560, 1440))):
            with self.subTest(scale=scale):
                native = FakeWindows(scale=scale, physical=dimensions)
                self.assertEqual({"client_width": dimensions[0], "client_height": dimensions[1], "game": "blue_archive"}, native.metadata())
                self.assertEqual(native.original_context, native.context)
                self.assertEqual([ctypes.c_void_p(-4).value, native.original_context], native.dpi_calls)

    def test_unavailable_dpi_never_guesses_size_but_keeps_game(self):
        native = FakeWindows(scale=1.5)
        native.dpi_ok = False
        self.assertEqual({**NULL, "game": "blue_archive"}, native.metadata())
        self.assertEqual(0, native.rect_calls)
        self.assertEqual(native.original_context, native.context)
        del native.user.SetThreadDpiAwarenessContext
        self.assertEqual({**NULL, "game": "blue_archive"}, native.metadata())
        self.assertEqual(0, native.rect_calls)

    def test_geometry_failure_invalid_zero_and_restore_failure(self):
        for setting, value in (("rect_ok", False), ("geometry_error", True),
                               ("physical", (0, 720)), ("physical", (-1, 720)),
                               ("restore_ok", False)):
            with self.subTest(setting=setting, value=value):
                native = FakeWindows(scale=1.5)
                setattr(native, setting, value)
                self.assertEqual({**NULL, "game": "blue_archive"}, native.metadata())
                self.assertEqual(native.original_context, native.dpi_calls[-1])
                if native.restore_ok:
                    self.assertEqual(native.original_context, native.context)

    def test_basename_case_insensitive_but_title_impostor_and_class_mismatch_unknown(self):
        native = FakeWindows()
        native.path = r"D:\other-server\BLUEARCHIVE.EXE"
        self.assertEqual("blue_archive", native.metadata()["game"])
        for path, class_name in ((r"C:\BlueArchive.exe\Editor.exe", "UnityWndClass"),
                                 (r"C:\BlueArchive.exe", "EditorClass")):
            native = FakeWindows()
            native.path, native.class_name = path, class_name
            self.assertIsNone(native.metadata()["game"])
            self.assertEqual("Blue Archive", native.title)
            if class_name != "UnityWndClass":
                self.assertEqual([], native.open_calls)

    def test_hidden_window_game_unknown(self):
        native = FakeWindows()
        native.visible = False
        self.assertIsNone(native.metadata()["game"])
        self.assertEqual([], native.open_calls)

    def test_process_permission_or_query_failure_preserves_geometry_and_closes_handle(self):
        for flag in ("process_ok", "name_ok", "name_error"):
            with self.subTest(flag=flag):
                native = FakeWindows()
                setattr(native, flag, flag == "name_error")
                self.assertEqual({"client_width": 1280, "client_height": 720, "game": None}, native.metadata())
                self.assertEqual([] if flag == "process_ok" else [HANDLE], native.closed)

    def test_minimized_closed_unknown_identity_no_stale_geometry(self):
        native = FakeWindows()
        native.minimized = True
        self.assertEqual({**NULL, "game": "blue_archive"}, native.metadata())
        self.assertEqual([], native.dpi_calls)
        native.exists = False
        self.assertEqual(NULL, native.metadata())
        self.assertEqual(NULL, FakeWindows().metadata(expected=None))
        self.assertEqual(NULL, FakeWindows().metadata(expected=(999, 202)))

    def test_recycled_pid_or_thread_and_closure_during_query_suppress_all_metadata(self):
        for field, value in (("pid", 303), ("thread", 404), ("exists", False)):
            for after in ("after_rect", "after_name"):
                with self.subTest(field=field, after=after):
                    native = FakeWindows()
                    setattr(native, after, lambda: setattr(native, field, value))
                    self.assertEqual(NULL, native.metadata())
                    self.assertEqual([HANDLE], native.closed)
                    self.assertEqual(native.original_context, native.context)

    def test_minimization_during_name_query_discards_only_geometry(self):
        native = FakeWindows()
        native.after_name = lambda: setattr(native, "minimized", True)
        self.assertEqual({**NULL, "game": "blue_archive"}, native.metadata())

    def test_reuse_during_final_minimized_query_is_inside_identity_bracket(self):
        native = FakeWindows()
        calls = 0
        def minimized(_hwnd):
            nonlocal calls
            calls += 1
            if calls == 2:
                native.pid += 1
            return False
        native.user.IsIconic.callback = minimized
        self.assertEqual(NULL, native.metadata())
        self.assertEqual([HANDLE], native.closed)

    def test_missing_libraries_is_null_metadata_without_error(self):
        with patch("core.scanner_target_metadata._libraries", return_value=None):
            self.assertEqual(NULL, target_metadata(HWND, expected_identity=IDENTITY))

    def test_adapter_enumwindows_preserves_filter_status_foreground_and_cached_identity(self):
        native = FakeWindows(physical=(1600, 1000))
        # CF may label non-16:9 unsupported; adapter readiness stays unchanged.
        adapter = WindowsCaptureInputAdapter()
        callback_factory = getattr(ctypes, "WINFUNCTYPE", ctypes.CFUNCTYPE)
        with patch.object(adapter, "_libraries", return_value=(native.user, None)), \
                patch("core.scanner_target_metadata._libraries", return_value=(native.user, native.kernel)), \
                patch.object(ctypes, "WINFUNCTYPE", callback_factory, create=True), \
                patch.object(ctypes, "set_last_error", create=True), \
                patch.object(ctypes, "get_last_error", return_value=0, create=True):
            row = adapter()[0]
            self.assertEqual("ready", row["status"])
            self.assertTrue(row["foreground"])
            self.assertEqual((1600, 1000, "blue_archive"), (row["client_width"], row["client_height"], row["game"]))
            native.pid += 1
            row = adapter()[0]
            self.assertEqual("unsupported", row["status"])
            self.assertEqual(NULL, {name: row[name] for name in NULL})
            native.title = "Unrelated app"
            self.assertEqual([], adapter())

    def test_adapter_metadata_denial_does_not_fail_list_or_change_diagnose(self):
        native = FakeWindows()
        adapter = WindowsCaptureInputAdapter()
        callback_factory = getattr(ctypes, "WINFUNCTYPE", ctypes.CFUNCTYPE)
        with patch.object(adapter, "_libraries", return_value=(native.user, None)), \
                patch("core.scanner_target_metadata._libraries", side_effect=OSError("DLL denied")), \
                patch.object(ctypes, "WINFUNCTYPE", callback_factory, create=True), \
                patch.object(ctypes, "set_last_error", create=True), \
                patch.object(ctypes, "get_last_error", return_value=0, create=True):
            row = adapter()[0]
            self.assertEqual("ready", row["status"])
            self.assertEqual(NULL, {name: row[name] for name in NULL})


class TargetMetadataSchemaTests(unittest.TestCase):
    def test_shared_new_and_old_fixtures_validate(self):
        schema = json.loads((ROOT / "contracts/scanner-protocol-v1.schema.json").read_text(encoding="utf-8"))
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        fixture = json.loads((ROOT / "contracts/fixtures/scanner_target_metadata_fb4_v1.json").read_text(encoding="utf-8"))
        self.assertEqual(1, fixture["version"])
        for filename in ("scanner_target_metadata_fb4_v1.json", "scanner_protocol_v1.json"):
            cases = json.loads((ROOT / "contracts/fixtures" / filename).read_text(encoding="utf-8"))["cases"]
            for case in cases:
                with self.subTest(fixture=filename, case=case["name"]):
                    self.assertEqual(case["valid"], not list(validator.iter_errors(case["message"])))
        row = deepcopy(fixture["cases"][0]["message"])
        target = row["payload"]["targets"][0]
        for name in ("client_width", "client_height"):
            for invalid in (True, False, -1, 0, "1280", 1.5):
                with self.subTest(field=name, value=invalid):
                    target[name] = invalid
                    self.assertTrue(list(validator.iter_errors(row)))
            target[name] = None
        target["game"] = "kr_steam"
        self.assertTrue(list(validator.iter_errors(row)))


if __name__ == "__main__":
    unittest.main()
