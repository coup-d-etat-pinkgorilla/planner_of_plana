from __future__ import annotations

import ctypes
import json
from pathlib import Path
from queue import Queue
import subprocess
import sys
from threading import Event, Timer
from time import monotonic
from types import MethodType, SimpleNamespace
import unittest
from unittest.mock import patch

from PIL import Image

from core.scanner_matchers import InventoryMatcherAdapter, StudentMatcherAdapter
from core.scanner_session import ScanBatchResult, ScannerError, ScannerSessionService
from core.windows_scanner_adapter import WindowsCaptureInputAdapter, _INPUT
from core.windows_capture_worker import CaptureWorker
from test_scanner_session import FakeRepository


TARGET = {"target_id": "hwnd:1"}


class NativeUser:
    def __init__(self):
        self.exists, self.minimized, self.visible = True, False, True
        self.pid, self.foreground, self.hit = 4, 1, 1
        self.title = "Blue Archive"
        self.accept_flags = {3}
        self.flags, self.posts, self.sent = [], [], []
        self.cursor = None
        self.inserted = 2
        self.activate = False
        self.after_cursor = lambda: None

    def IsWindow(self, _h): return self.exists
    def IsIconic(self, _h): return self.minimized
    def IsWindowVisible(self, _h): return self.visible
    def GetForegroundWindow(self): return self.foreground
    def GetWindowTextLengthW(self, _h): return len(self.title)
    def GetWindowTextW(self, _h, buf, _n): buf.value = self.title; return len(self.title)
    def GetWindowThreadProcessId(self, _h, pid): pid._obj.value = self.pid; return 5
    def GetClientRect(self, _h, r):
        r._obj.left, r._obj.top, r._obj.right, r._obj.bottom = 0, 0, 4, 3
        return True
    def GetWindowRect(self, _h, r):
        r._obj.left, r._obj.top, r._obj.right, r._obj.bottom = 100, 200, 108, 207
        return True
    def ClientToScreen(self, _h, p): p._obj.x += 102; p._obj.y += 202; return True
    def GetDC(self, _h): return 10
    def ReleaseDC(self, _h, _dc): return 1
    def PrintWindow(self, _h, _dc, flag): self.flags.append(flag); return flag in self.accept_flags
    def BringWindowToTop(self, _h): return True
    def SetForegroundWindow(self, h):
        if self.activate: self.foreground = h
        return self.activate
    def SetCursorPos(self, x, y): self.cursor = (x, y); self.after_cursor(); return True
    def WindowFromPoint(self, _p): return self.hit
    def GetAncestor(self, hit, _flag): return hit
    def GetAsyncKeyState(self, _key): return 0
    def MapVirtualKeyW(self, key, _mode): return {0x25: 75, 0x27: 77}[key]
    def SendInput(self, n, array, size):
        assert size == ctypes.sizeof(_INPUT)
        self.sent.append([(array[i].type, array[i].ki.wScan if array[i].type else array[i].mi.dwFlags) for i in range(n)])
        return min(n, self.inserted)
    def PostMessageW(self, h, message, w, l): self.posts.append((h, message, w, l)); return True


class NativeGdi:
    def __init__(self):
        self.size = None
        self.selected = 99
        self.deletes = []
        self.bitblt = False
        self.blank = False
        self.fail_bitmap = False

    def CreateCompatibleDC(self, _dc): return 20
    def CreateCompatibleBitmap(self, _dc, w, h): self.size = (w, h); return 0 if self.fail_bitmap else 30
    def SelectObject(self, _dc, obj): previous, self.selected = self.selected, obj; return previous
    def DeleteObject(self, obj): self.deletes.append(("bitmap", obj)); return True
    def DeleteDC(self, dc): self.deletes.append(("dc", dc)); return True
    def BitBlt(self, *_args): return self.bitblt
    def GetDIBits(self, _dc, _bitmap, _start, height, buffer, _info, _usage):
        assert self.selected == 99, "bitmap must be deselected before GetDIBits"
        w, h = self.size
        raw = bytes(w * h * 4) if self.blank else bytes(v for y in range(h) for x in range(w) for v in (80, y * 30 + 10, x * 30 + 10, 0))
        ctypes.memmove(buffer, raw, len(raw))
        return height


class F1NativeTests(unittest.TestCase):
    def setUp(self):
        self.u, self.g = NativeUser(), NativeGdi()
        self.adapter = WindowsCaptureInputAdapter(isolate_capture=False)
        self.mock = patch.object(self.adapter, "_libraries", return_value=(self.u, self.g))
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def test_real_ctypes_input_layout_is_pointer_sized(self):
        self.assertEqual(40 if ctypes.sizeof(ctypes.c_void_p) == 8 else 28, ctypes.sizeof(_INPUT))

    def test_printwindow_flags_and_full_window_crop(self):
        for accepted, expected in [(3, [3]), (1, [3, 1]), (2, [3, 1, 2]), (0, [3, 1, 2, 0])]:
            with self.subTest(accepted=accepted):
                self.u.flags = []
                self.u.accept_flags = {accepted}
                frame = self.adapter.capture(TARGET)
                self.assertEqual(expected, self.u.flags)
                self.assertEqual((4, 3), frame.size)
                self.assertEqual((70, 70, 80) if accepted in (0, 2) else (10, 10, 80), frame.getpixel((0, 0)))
                frame.close()
        self.assertEqual(99, self.g.selected)

    def test_bitblt_last_and_never_background(self):
        self.u.accept_flags = set()
        self.g.bitblt = True
        self.adapter.capture(TARGET).close()
        self.assertEqual("bitblt", self.adapter.last_capture_trace[-1]["method"])
        self.u.foreground = 9
        with self.assertRaises(ScannerError): self.adapter.capture(TARGET)
        self.assertEqual(15, len(self.adapter.last_capture_trace))

    def test_blank_success_is_rejected_and_retries_are_bounded(self):
        self.u.accept_flags = {0, 1, 2, 3}
        self.g.blank = True
        with self.assertRaisesRegex(ScannerError, "exhausted"):
            self.adapter.capture(TARGET)
        self.assertEqual(15, len(self.adapter.last_capture_trace))
        self.assertEqual(15, sum(kind == "bitmap" for kind, _ in self.g.deletes))

    def test_gdi_allocation_failure_releases_prior_resources(self):
        self.g.fail_bitmap = True
        with self.assertRaises(ScannerError): self.adapter.capture(TARGET)
        self.assertEqual([("dc", 20)] * 15, self.g.deletes)

    def test_closed_minimized_hidden_and_wrong_title_never_input(self):
        for field, value in [("exists", False), ("minimized", True), ("visible", False), ("title", "Other app")]:
            with self.subTest(field=field):
                original = getattr(self.u, field)
                setattr(self.u, field, value)
                with self.assertRaises(ScannerError): self.adapter.click(TARGET, .5, .5)
                with self.assertRaises(ScannerError): self.adapter.capture(TARGET)
                self.assertEqual([], self.u.sent)
                self.assertEqual([], self.u.posts)
                setattr(self.u, field, original)

    def test_recycled_hwnd_is_rejected(self):
        self.assertEqual("ready", self.adapter.diagnose(TARGET)["status"])
        self.u.pid += 1
        with self.assertRaises(ScannerError): self.adapter.press_key(TARGET, "right")
        self.assertEqual([], self.u.sent)

    def test_left_and_right_physical_keys(self):
        self.assertTrue(self.adapter.press_key(TARGET, "left"))
        self.assertTrue(self.adapter.press_key(TARGET, "right"))
        self.assertEqual([[(1, 75), (1, 75)], [(1, 77), (1, 77)]], self.u.sent)
        self.assertEqual([], self.u.posts)

    def test_client_to_screen_and_physical_click(self):
        self.adapter.click(TARGET, .5, .5)
        self.assertEqual((104, 204), self.u.cursor)
        self.assertEqual([[(0, 2), (0, 4)]], self.u.sent)
        self.assertEqual("send_input", self.adapter.last_input_trace["method"])

    def test_background_activation_denied_posts_only_to_selected_hwnd(self):
        self.u.foreground = 9
        self.adapter.click(TARGET, .5, .5)
        self.adapter.press_key(TARGET, "left")
        self.assertIsNone(self.u.cursor)
        self.assertEqual([], self.u.sent)
        self.assertEqual([1] * 4, [r[0] for r in self.u.posts])

    def test_activation_success_uses_physical_input(self):
        self.u.foreground, self.u.activate = 9, True
        self.adapter.click(TARGET, .5, .5)
        self.assertEqual(1, len(self.u.sent))

    def test_physical_rejected_before_insertion_uses_message_fallback(self):
        self.u.inserted = 0
        self.adapter.click(TARGET, .5, .5)
        self.assertEqual(2, len(self.u.posts))

    def test_partial_physical_insertion_releases_without_duplicate_down(self):
        self.u.inserted = 1
        with self.assertRaises(ScannerError) as caught: self.adapter.click(TARGET, .5, .5)
        self.assertEqual("input_partial", caught.exception.code)
        self.assertEqual([(0, 4)], self.u.sent[-1])
        self.assertEqual([], self.u.posts)

    def test_focus_change_or_occlusion_never_clicks_other_app(self):
        for field in ("foreground", "hit"):
            setattr(self.u, field, 1)
            self.u.after_cursor = lambda field=field: setattr(self.u, field, 9)
            with self.assertRaises(ScannerError): self.adapter.click(TARGET, .5, .5)
            self.assertEqual([], self.u.sent)
            self.assertEqual([], self.u.posts)
            setattr(self.u, field, 1)

    def test_cancel_before_input_and_explicit_cleanup(self):
        signal = Event(); signal.set()
        target = {**TARGET, "_scanner_cancel": signal}
        with self.assertRaises(ScannerError): self.adapter.click(target, .5, .5)
        self.assertEqual([], self.u.sent)
        self.adapter.click({**target, "_scanner_cleanup": True}, .5, .5)
        self.assertEqual(1, len(self.u.sent))

    def test_invalid_coordinates_and_handles_never_input(self):
        for value in (-1, 2, float("nan"), float("inf")):
            with self.assertRaises(ScannerError): self.adapter.click(TARGET, value, .5)
        for value in ("hwnd:0", "hwnd:-1", "hwnd:xyz", "x", None):
            with self.assertRaises(ScannerError): self.adapter.click({"target_id": value}, .5, .5)
        self.assertEqual([], self.u.sent)

    def test_capture_recovers_second_round_and_cancel_stops_all_methods(self):
        calls = []
        def render(_target, method):
            calls.append(method)
            if len(calls) <= 5: raise ScannerError("capture_failed", "injected")
            return Image.effect_noise((32, 32), 100).convert("RGB")
        with patch.object(self.adapter, "_render", side_effect=render):
            self.adapter.capture(TARGET).close()
        self.assertEqual([3, 1, 2, 0, "bitblt", 3], calls)
        signal = Event()
        def cancel_render(_target, _method):
            signal.set()
            raise ScannerError("capture_failed", "injected")
        with patch.object(self.adapter, "_render", side_effect=cancel_render) as render:
            with self.assertRaises(ScannerError): self.adapter.capture(TARGET, cancel=signal)
            self.assertEqual(1, render.call_count)

    def test_stable_recovery_and_image_lifetime(self):
        frames = [Image.new("RGB", (32, 32), "white") for _ in range(3)]
        with patch.object(self.adapter, "capture", side_effect=[ScannerError("capture_failed", "once"), *frames]):
            result = self.adapter.wait_stable(TARGET, Event())
        for frame in frames[:-1]:
            with self.assertRaises(ValueError): frame.getpixel((0, 0))
        self.assertIs(result, frames[-1]); result.close()

    def test_stable_exhaustion_and_cancel_release_frames(self):
        frames = [Image.new("RGB", (32, 32), "white" if i % 2 else "black") for i in range(12)]
        with patch.object(self.adapter, "capture", side_effect=frames) as capture:
            with self.assertRaises(ScannerError): self.adapter.wait_stable(TARGET, Event())
            self.assertEqual(12, capture.call_count)
        for frame in frames:
            with self.assertRaises(ValueError): frame.getpixel((0, 0))


class HangingWorker(CaptureWorker):
    def _start(self):
        self.process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
        self._results = Queue(maxsize=1)
        self.child = self.process


class F1WorkerTests(unittest.TestCase):
    def test_real_worker_protocol_survives_rejected_requests(self):
        worker = CaptureWorker()
        self.addCleanup(worker.close)
        for _ in range(2):
            with self.assertRaises(ScannerError) as caught:
                worker.capture({"target_id": "hwnd:0"}, "Blue Archive", Event(), monotonic() + 5)
            self.assertEqual("target_not_found" if sys.platform == "win32" else "windows_unsupported", caught.exception.code)
            self.assertIsNone(worker.process.poll())

    def test_hung_native_process_is_killed_at_deadline(self):
        worker = HangingWorker()
        self.addCleanup(worker.close)
        started = monotonic()
        with self.assertRaises(ScannerError) as caught:
            worker.capture(TARGET, "Blue Archive", Event(), monotonic() + .15)
        self.assertEqual("capture_timeout", caught.exception.code)
        self.assertLess(monotonic() - started, 2)
        self.assertIsNotNone(worker.child.poll())

    def test_cancel_kills_worker_without_waiting_for_native_return(self):
        worker, cancel = HangingWorker(), Event()
        self.addCleanup(worker.close)
        timer = Timer(.1, cancel.set); timer.start(); self.addCleanup(timer.cancel)
        with self.assertRaises(ScannerError) as caught:
            worker.capture(TARGET, "Blue Archive", cancel, monotonic() + 5)
        self.assertEqual("cancelled", caught.exception.code)
        self.assertIsNotNone(worker.child.poll())


def raw(student):
    return {"payload": {"version": 1, "student_id": student, "values": {"level": 90}},
            "evidence": [], "review_required": False}


class ImmediateEvent:
    def is_set(self): return False
    def wait(self, _seconds): return False


class F1HandoffTests(unittest.TestCase):
    def test_inventory_interruption_retains_slots_and_unknown_quantity(self):
        for cancelled in (False, True):
            with self.subTest(cancelled=cancelled):
                signal = Event()
                frame = Image.new("RGB", (32, 32), "white")
                adapter = object.__new__(InventoryMatcherAdapter)
                def scroll(*_args):
                    raise ScannerError("capture_failed", "lost next page")
                adapter.capture = SimpleNamespace(wait_stable=lambda *_a: frame, scroll=scroll)
                adapter.slots = [{"x1": 0, "y1": 0, "x2": 1, "y2": 1}]
                adapter.max_pages, adapter.threshold, adapter.margin = 2, .8, .1
                adapter.answer_samples = None
                adapter.matcher = SimpleNamespace(templates=[1, 2], replace_user_templates=lambda *_a: None,
                    match=lambda *_a, **_k: SimpleNamespace(identity="item", score=.99, margin=.5, source="template"))
                adapter.count_matcher = SimpleNamespace(match=lambda *_a: SimpleNamespace(value=None, score=0, margin=0))
                with patch("core.scanner_matchers.image_has_visible_content", return_value=True):
                    result = adapter({}, signal, lambda *_a: signal.set() if cancelled else None)
                self.assertEqual("cancelled" if cancelled else "failed", result.outcome)
                self.assertFalse(result.coverage_complete)
                candidate = result.candidates[0]
                self.assertEqual(1, len(candidate["payload"]["entries"]))
                self.assertIsNone(candidate["payload"]["entries"][0]["quantity"])
                self.assertTrue(candidate["review_required"])
                self.assertEqual("partial", candidate["evidence"][-1]["status"])
                with self.assertRaises(ValueError): frame.getpixel((0, 0))
                specimen = candidate["_answer_specimen"]["slot_crops"][0]
                self.assertEqual((255, 255, 255), specimen.getpixel((0, 0)))
                specimen.close()

    def test_bad_later_candidate_keeps_transferred_specimen_and_closes_remainder(self):
        frames = [Image.new("RGB", (4, 4), "white") for _ in range(3)]
        rows = [raw("aru"), {"payload": None}, raw("shiroko")]
        for row, frame in zip(rows, frames):
            row["_answer_specimen"] = {"image": frame}
        ids = iter(["s", "a"])
        service = ScannerSessionService(target_provider=lambda: [{"target_id": "w1"}],
            student_matcher=lambda *_a: rows, inventory_matcher=lambda *_a: [], repository=FakeRepository(),
            asset_status=lambda: {"ready": True}, id_factory=lambda: next(ids))
        self.addCleanup(service.close)
        service.start("student", "w1"); service.wait("s")
        self.assertEqual("failed", service.snapshot("s", 1)["terminal"])
        self.assertEqual((255, 255, 255), frames[0].getpixel((0, 0)))
        for frame in frames[1:]:
            with self.assertRaises(ValueError): frame.getpixel((0, 0))
        service.close()
        with self.assertRaises(ValueError): frames[0].getpixel((0, 0))

    def adapter(self, rows, input_failure=False):
        adapter = object.__new__(StudentMatcherAdapter)
        class Input:
            points = []
            def press_key(self, _target, _key):
                if input_failure: raise ScannerError("input_failed", "API rejected before insertion")
                return True
            def click(self, _target, x, y): self.points.append((x, y))
        adapter.capture = Input()
        iterator = iter(rows)
        def scan(_self, *_args):
            result = next(iterator)
            if isinstance(result, Exception): raise result
            return [raw(result)]
        adapter._scan_current = MethodType(scan, adapter)
        return adapter

    def test_key_api_failure_uses_button_and_cycle_completes(self):
        adapter = self.adapter(["aru", "shiroko", "aru"], input_failure=True)
        result = adapter({"student_scan_mode": "full"}, ImmediateEvent(), lambda *_a: None)
        self.assertEqual("completed", result.outcome)
        self.assertEqual(2, len(result.candidates))
        self.assertEqual(2, len(adapter.capture.points))

    def test_capture_error_returns_previously_collected_students(self):
        adapter = self.adapter(["aru", "shiroko", ScannerError("capture_failed", "lost")])
        result = adapter({"student_scan_mode": "full"}, ImmediateEvent(), lambda *_a: None)
        self.assertEqual("failed", result.outcome)
        self.assertEqual("capture_failed", result.error.code)
        self.assertEqual(["aru", "shiroko"], [c["payload"]["student_id"] for c in result.candidates])

    def test_unchanged_key_and_button_are_not_proof_of_end(self):
        adapter = self.adapter(["aru"] * 5)
        result = adapter({"student_scan_mode": "full"}, ImmediateEvent(), lambda *_a: None)
        self.assertEqual("failed", result.outcome)
        self.assertEqual("navigation_unconfirmed", result.error.code)
        self.assertFalse(result.coverage_complete)
        self.assertEqual(1, len(result.candidates))

    def test_session_publishes_retained_before_failed_and_rejects_commit(self):
        repository, events = FakeRepository(), []
        ids = iter(["s", "a", "b"])
        batch = ScanBatchResult([raw("aru"), raw("shiroko")], "failed", ScannerError("capture_failed", "lost"))
        service = ScannerSessionService(target_provider=lambda: [{"target_id": "w1"}],
            student_matcher=lambda *_a: batch, inventory_matcher=lambda *_a: [], repository=repository,
            asset_status=lambda: {"ready": True}, id_factory=lambda: next(ids), event_sink=events.append)
        self.addCleanup(service.close)
        service.start("student", "w1"); service.wait("s")
        snapshot = service.snapshot("s", 1)
        self.assertEqual("failed", snapshot["terminal"])
        self.assertEqual(2, len(snapshot["candidates"]))
        self.assertEqual(["candidate", "candidate", "terminal"], [e["payload"]["event_kind"] for e in events[-3:]])
        with self.assertRaisesRegex(ScannerError, "completed"):
            service.commit(session_id="s", generation=1, candidate_id="a", candidate_revision=1,
                           profile_id="p1", expected_repository_revision=0, idempotency_key="x")
        self.assertEqual(0, repository.state["revision"])

    def test_parity_fixture_matches_chosen_limits(self):
        fixture = json.loads((Path(__file__).parent / "fixtures/scanner_fallback_restoration/f1-capture-input-parity.json").read_text(encoding="utf-8"))
        self.assertEqual(fixture["v7_contract"]["capture"]["rounds"], WindowsCaptureInputAdapter.CAPTURE_ROUNDS)
        self.assertEqual(fixture["v7_contract"]["capture"]["stable"]["max_frames"], WindowsCaptureInputAdapter.MAX_STABLE_FRAMES)
