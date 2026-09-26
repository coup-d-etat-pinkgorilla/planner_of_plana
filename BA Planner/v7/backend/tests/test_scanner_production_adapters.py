from __future__ import annotations

from pathlib import Path
from threading import Event
from types import MethodType
import unittest
from unittest.mock import patch

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import InventoryMatcherAdapter, SlotCountMatcher, StudentMatcherAdapter
from core.scanner_session import ScannerError
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


ASSETS = Path(__file__).parents[1] / "assets" / "recognition" / "v1"


class ScriptedCapture:
    def __init__(self, image: Image.Image) -> None:
        self.image = image
        self.scrolls: list[int] = []

    def capture(self, _target):
        return self.image.copy()

    def wait_stable(self, _target, cancel, timeout=2.0):
        if cancel.is_set():
            raise ScannerError("cancelled", "cancelled")
        return self.capture(_target)

    def scroll(self, _target, delta):
        self.scrolls.append(delta)


class FakeUser32:
    def __init__(self, *, exists: bool = True, minimized: bool = False, client_rect: bool = True) -> None:
        self.exists = exists
        self.minimized = minimized
        self.client_rect = client_rect

    def IsWindow(self, _hwnd):
        return self.exists

    def IsIconic(self, _hwnd):
        return self.minimized

    def GetForegroundWindow(self):
        return 0

    def GetClientRect(self, _hwnd, _rect):
        return self.client_rect

    def GetWindowTextLengthW(self, _hwnd):
        return 12

    def GetWindowTextW(self, _hwnd, buffer, _length):
        buffer.value = "Blue Archive"
        return 12

    def GetWindowThreadProcessId(self, _hwnd, pid):
        pid._obj.value = 100
        return 200

    def IsWindowVisible(self, _hwnd):
        return True


class UnstableWindowsAdapter(WindowsCaptureInputAdapter):
    def __init__(self) -> None:
        super().__init__()
        self.frame = 0

    def capture(self, _target, **_kwargs):
        self.frame += 1
        return Image.new("RGB", (32, 32), (self.frame % 255, 0, 0))


def paste_ratio(frame: Image.Image, source: Image.Image, region: dict) -> None:
    box = (
        round(frame.width * region["x1"]), round(frame.height * region["y1"]),
        round(frame.width * region["x2"]), round(frame.height * region["y2"]),
    )
    frame.paste(source.convert("RGB").resize((box[2] - box[0], box[3] - box[1])), box)


def paste_count(slot: Image.Image, value: str) -> None:
    ink = Image.new("RGB", slot.size, (45, 70, 99))
    for position, digit in enumerate(value):
        box = SlotCountMatcher.digit_box(slot, position)
        mask = Image.open(ASSETS / f"templates/inventory_count/{digit}.png").convert("L")
        mask = mask.resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.NEAREST)
        slot.paste(ink.crop(box), box, mask)


class ScannerProductionAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = RecognitionAssetCatalog(ASSETS)
        self.assertTrue(self.catalog.verify()["ready"])

    def test_student_adapter_matches_real_production_template(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        region = self.catalog.region("student")["student_texture_region"]
        template = Image.open(ASSETS / "templates/students/aru.png")
        paste_ratio(frame, template, region)
        adapter = StudentMatcherAdapter(ScriptedCapture(frame), self.catalog)
        result = adapter({"target_id": "fixture"}, Event(), lambda *_args: None)[0]
        self.assertEqual("aru", result["payload"]["student_id"])
        self.assertEqual({}, result["payload"]["values"])
        self.assertTrue(result["review_required"])
        self.assertGreaterEqual(result["evidence"][0]["confidence"], 0.99)

    def test_full_student_adapter_buffers_until_identity_repeats(self) -> None:
        class Clicks:
            def __init__(self) -> None:
                self.points = []

            def click(self, _target, x_ratio, y_ratio):
                self.points.append((x_ratio, y_ratio))

        adapter = object.__new__(StudentMatcherAdapter)
        adapter.capture = Clicks()
        identities = iter(("hoshino", "hoshino_swimsuit", "hoshino"))

        def scan_current(_self, _target, _cancel, _progress):
            return [{
                "payload": {
                    "version": 1, "student_id": next(identities),
                    "values": {}, "provenance": {},
                },
                "evidence": [], "review_required": False,
            }]

        adapter._scan_current = MethodType(scan_current, adapter)
        result = adapter(
            {"target_id": "fixture", "student_scan_mode": "full"},
            Event(),
            lambda *_args: None,
        )
        self.assertEqual(
            ["hoshino", "hoshino_swimsuit"],
            [item["payload"]["student_id"] for item in result.candidates],
        )
        self.assertEqual([(0.9777, 0.53465), (0.9777, 0.53465)], adapter.capture.points)

    def test_full_student_adapter_prefers_right_key_navigation(self) -> None:
        class Inputs:
            def __init__(self) -> None:
                self.keys = []
                self.points = []

            def press_key(self, _target, key):
                self.keys.append(key)
                return True

            def click(self, _target, x_ratio, y_ratio):
                self.points.append((x_ratio, y_ratio))

        adapter = object.__new__(StudentMatcherAdapter)
        adapter.capture = Inputs()
        identities = iter(("hoshino", "hoshino_swimsuit", "hoshino"))

        def scan_current(_self, _target, _cancel, _progress):
            return [{
                "payload": {
                    "version": 1, "student_id": next(identities),
                    "values": {}, "provenance": {},
                },
                "evidence": [], "review_required": False,
            }]

        adapter._scan_current = MethodType(scan_current, adapter)
        result = adapter(
            {"target_id": "fixture", "student_scan_mode": "full"},
            Event(),
            lambda *_args: None,
        )
        self.assertEqual(
            ["hoshino", "hoshino_swimsuit"],
            [item["payload"]["student_id"] for item in result.candidates],
        )
        self.assertEqual(["right", "right"], adapter.capture.keys)
        self.assertEqual([], adapter.capture.points)

    def test_full_student_adapter_navigates_without_visual_transition_feedback_or_wait(self) -> None:
        timeline: list[str] = []

        class RecordingCancel:
            def __init__(self) -> None:
                self.waits: list[float] = []

            def is_set(self) -> bool:
                return False

            def wait(self, timeout: float) -> bool:
                self.waits.append(timeout)
                return False

        class Inputs:
            def press_key(self, _target, key):
                timeline.append(f"navigate:{key}")
                return True

            def click(self, _target, _x_ratio, _y_ratio):
                timeline.append("navigate:click")

        class FeedbackProgress:
            supports_feedback = True

            def __call__(self, _current, _total, _message, feedback=None):
                if feedback:
                    timeline.append(f"feedback:{feedback['field']}")

        adapter = object.__new__(StudentMatcherAdapter)
        adapter.capture = Inputs()
        identities = iter(("aru", "aru_dress", "aru"))

        def scan_current(_self, _target, _cancel, _progress):
            student_id = next(identities)
            timeline.append(f"scan:{student_id}")
            return [{
                "payload": {
                    "version": 1,
                    "student_id": student_id,
                    "values": {},
                    "provenance": {},
                },
                "evidence": [],
                "review_required": False,
            }]

        adapter._scan_current = MethodType(scan_current, adapter)
        cancel = RecordingCancel()
        adapter(
            {"student_scan_mode": "full"},
            cancel,
            FeedbackProgress(),
        )

        self.assertEqual(
            [
                "scan:aru",
                "navigate:right",
                "scan:aru_dress",
                "navigate:right",
                "scan:aru",
            ],
            timeline,
        )
        self.assertNotIn(0.32, cancel.waits)

    def test_full_student_adapter_retries_button_after_unchanged_key(self) -> None:
        class Inputs:
            def __init__(self) -> None:
                self.keys = []
                self.points = []

            def press_key(self, _target, key):
                self.keys.append(key)
                return True

            def click(self, _target, x_ratio, y_ratio):
                self.points.append((x_ratio, y_ratio))

        adapter = object.__new__(StudentMatcherAdapter)
        adapter.capture = Inputs()
        identities = iter(("aru", "aru", "aru_dress", "aru"))

        def scan_current(_self, _target, _cancel, _progress):
            return [{
                "payload": {
                    "version": 1, "student_id": next(identities),
                    "values": {}, "provenance": {},
                },
                "evidence": [], "review_required": False,
            }]

        adapter._scan_current = MethodType(scan_current, adapter)
        result = adapter(
            {"target_id": "fixture", "student_scan_mode": "full"},
            Event(),
            lambda *_args: None,
        )
        self.assertEqual(
            ["aru", "aru_dress"],
            [item["payload"]["student_id"] for item in result.candidates],
        )
        self.assertEqual(["right", "right"], adapter.capture.keys)
        self.assertEqual([(0.9777, 0.53465)], adapter.capture.points)

    def test_full_student_adapter_reverses_at_right_edge(self) -> None:
        class Inputs:
            def __init__(self) -> None:
                self.keys = []
                self.points = []

            def press_key(self, _target, key):
                self.keys.append(key)
                return True

            def click(self, _target, x_ratio, y_ratio):
                self.points.append((x_ratio, y_ratio))

        adapter = object.__new__(StudentMatcherAdapter)
        adapter.capture = Inputs()
        identities = iter(
            ("last", "last", "last", "middle", "first", "first", "first")
        )

        def scan_current(_self, _target, _cancel, _progress):
            return [{
                "payload": {
                    "version": 1,
                    "student_id": next(identities),
                    "values": {},
                    "provenance": {},
                },
                "evidence": [],
                "review_required": False,
            }]

        adapter._scan_current = MethodType(scan_current, adapter)
        result = adapter(
            {"student_scan_mode": "full"}, Event(), lambda *_args: None
        )

        self.assertEqual(
            ["last", "middle", "first"],
            [item["payload"]["student_id"] for item in result.candidates],
        )
        self.assertIn("left", adapter.capture.keys)
        self.assertIn((0.0223, 0.53465), adapter.capture.points)
        self.assertEqual("failed", result.outcome)
        self.assertEqual("navigation_unconfirmed", result.error.code)

    def test_inventory_adapter_matches_real_icon_and_count_glyphs(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        slot = self.catalog.region("inventory")["item"]["grid_slots"][0]
        template = Image.open(ASSETS / "templates/inventory/ooparts/Item_Icon_Material_Mandragora_0.png")
        slot_box = (
            round(frame.width * slot["x1"]), round(frame.height * slot["y1"]),
            round(frame.width * slot["x2"]), round(frame.height * slot["y2"]),
        )
        slot_image = template.convert("RGB").resize((slot_box[2] - slot_box[0], slot_box[3] - slot_box[1]))
        paste_count(slot_image, "42")
        frame.paste(slot_image, slot_box)
        adapter = InventoryMatcherAdapter(ScriptedCapture(frame), self.catalog)
        result = adapter({"target_id": "fixture"}, Event(), lambda *_args: None)[0]
        entries = result["payload"]["entries"]
        self.assertEqual("Item_Icon_Material_Mandragora_0", entries[0]["item_id"])
        self.assertEqual("42", entries[0]["quantity"])
        self.assertEqual(0, entries[0]["observed_slot"])
        self.assertNotIn("index", entries[0])
        self.assertFalse(result["review_required"])
        self.assertIn("slot_count_glyph", {item["source"] for item in result["evidence"]})
        self.assertTrue(any(item["source"] in {"grid_icon_template", "grid_same_crop_rematch"} for item in result["evidence"]))
        self.assertIn("stable_frame_overlap", {item["source"] for item in result["evidence"]})

    def test_inventory_adapter_never_zero_fills_missing_count(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        slot = self.catalog.region("inventory")["item"]["grid_slots"][0]
        template = Image.open(ASSETS / "templates/inventory/ooparts/Item_Icon_Material_Mandragora_0.png")
        paste_ratio(frame, template, slot)
        result = InventoryMatcherAdapter(ScriptedCapture(frame), self.catalog)({"target_id": "fixture"}, Event(), lambda *_args: None)[0]
        self.assertIsNone(result["payload"]["entries"][0]["quantity"])
        self.assertTrue(result["review_required"])

    def test_inventory_low_margin_uses_detail_fallback(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        slot = self.catalog.region("inventory")["item"]["grid_slots"][0]
        template = Image.open(ASSETS / "templates/inventory/ooparts/Item_Icon_Material_Mandragora_0.png")
        paste_ratio(frame, template, slot)
        result = InventoryMatcherAdapter(ScriptedCapture(frame), self.catalog, threshold=1.1)({"target_id": "fixture"}, Event(), lambda *_args: None)[0]
        item_evidence = next(item for item in result["evidence"] if item["field"].endswith(".item_id"))
        self.assertEqual("grid_same_crop_rematch", item_evidence["source"])
        self.assertTrue(result["review_required"])

    def test_inventory_profile_never_relabels_a_confident_foreign_item(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        slot = self.catalog.region("inventory")["item"]["grid_slots"][0]
        template = Image.open(ASSETS / "templates/inventory/ooparts/Item_Icon_Material_Mandragora_0.png")
        paste_ratio(frame, template, slot)
        grid_slots = self.catalog.region("inventory")["item"]["grid_slots"]

        class Navigation:
            def prepare(self, _target, _cancel, _frame):
                return type("Prepared", (), {"source": "item", "profile_id": "tech_notes"})()

            def page_slots(self, _source, _offset):
                return dict(enumerate(grid_slots))

            def advance(self, _target, _cancel, current, _source):
                return type("Moved", (), {
                    "frame": current.copy(), "shift": 0.0, "terminal": True,
                    "reason": "verified_no_motion",
                })()

            def verify_profile_order(self, _profile, item_ids):
                return bool(item_ids)

        result = InventoryMatcherAdapter(
            ScriptedCapture(frame), self.catalog, navigation=Navigation(),
        )({"target_id": "fixture", "inventory_scan_profile": "tech_notes"}, Event(), lambda *_args: None)[0]
        self.assertEqual([], result["payload"]["entries"])
        self.assertTrue(any(
            item["source"] == "inventory_profile_catalog" and item["status"] == "skipped"
            for item in result["evidence"]
        ))

    def test_cancellation_and_import_safe_windows_boundary(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        cancel = Event()
        cancel.set()
        student = StudentMatcherAdapter(ScriptedCapture(frame), self.catalog)
        self.assertEqual([], student({"target_id": "fixture"}, cancel, lambda *_args: None))
        adapter = WindowsCaptureInputAdapter(isolate_capture=False)
        self.assertEqual([], [item for item in adapter() if "definitely-not-a-window" in item["title"]])

    def test_windows_diagnostics_capture_failure_timeout_and_cancel(self) -> None:
        adapter = WindowsCaptureInputAdapter(isolate_capture=False)
        with patch.object(WindowsCaptureInputAdapter, "_libraries", return_value=(FakeUser32(exists=False), object())):
            self.assertEqual("closed", adapter.diagnose({"target_id": "hwnd:1"})["status"])
        with patch.object(WindowsCaptureInputAdapter, "_libraries", return_value=(FakeUser32(minimized=True), object())):
            self.assertEqual("minimized", adapter.diagnose({"target_id": "hwnd:1"})["status"])
        with patch.object(WindowsCaptureInputAdapter, "_libraries", return_value=(FakeUser32(client_rect=False), object())):
            with self.assertRaisesRegex(ScannerError, "capture methods exhausted") as failure:
                adapter.capture({"target_id": "hwnd:1"})
            self.assertEqual("capture_failed", failure.exception.code)
            self.assertEqual(15, len(adapter.last_capture_trace))
        unstable = UnstableWindowsAdapter()
        with self.assertRaises(ScannerError) as timeout:
            unstable.wait_stable({"target_id": "fixture"}, Event(), timeout=0.01)
        self.assertEqual("capture_timeout", timeout.exception.code)
        cancel = Event()
        cancel.set()
        with self.assertRaises(ScannerError) as cancelled:
            unstable.wait_stable({"target_id": "fixture"}, cancel)
        self.assertEqual("cancelled", cancelled.exception.code)

    def test_drag_scroll_releases_mouse_when_a_move_is_rejected(self) -> None:
        class DragUser32:
            def __init__(self):self.flags=[];self.calls=0
            def GetAsyncKeyState(self,_key):return 0
            def ClientToScreen(self,_hwnd,_point):return True
            def SetCursorPos(self,_x,_y):return True
            def WindowFromPoint(self,_point):return 1
            def GetAncestor(self,_hwnd,_flag):return 1
            def GetForegroundWindow(self):return 1
            def SendInput(self,count,events,_size):
                self.calls+=1
                self.flags.extend(int(events[index].mi.dwFlags) for index in range(count))
                return 0 if self.calls==3 else count

        user32=DragUser32();adapter=WindowsCaptureInputAdapter(isolate_capture=False)
        adapter._checked_hwnd=lambda _target:1
        adapter._foreground=lambda _u,_target,_hwnd:True
        adapter._client=lambda _u,_hwnd:(1280,720)
        with patch.object(WindowsCaptureInputAdapter,"_libraries",return_value=(user32,object())):
            with self.assertRaises(ScannerError) as failure:
                adapter.drag_scroll({"_scanner_cancel":Event()},(.78,.75),(.78,.65))
        self.assertEqual("input_failed",failure.exception.code)
        self.assertEqual(0x0002,user32.flags[0])
        self.assertEqual(0x0004,user32.flags[-1])


if __name__ == "__main__":
    unittest.main()
