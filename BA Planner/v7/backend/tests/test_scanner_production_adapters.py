from __future__ import annotations

from pathlib import Path
from threading import Event
import unittest
from unittest.mock import patch

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import InventoryMatcherAdapter, SlotCountMatcher, StudentMatcherAdapter
from core.scanner_session import ScannerError
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


ASSETS = Path(__file__).parents[1] / "core" / "recognition_assets"


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


class UnstableWindowsAdapter(WindowsCaptureInputAdapter):
    def __init__(self) -> None:
        super().__init__()
        self.frame = 0

    def capture(self, _target):
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
        self.assertFalse(result["review_required"])
        self.assertGreaterEqual(result["evidence"][0]["confidence"], 0.99)

    def test_inventory_adapter_matches_real_icon_and_count_glyphs(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        slot = self.catalog.region("inventory")["item"]["grid_slots"][0]
        template = Image.open(ASSETS / "templates/inventory/Item_Icon_Material_Mandragora_0.png")
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
        self.assertFalse(result["review_required"])
        self.assertIn("slot_count_glyph", {item["source"] for item in result["evidence"]})
        self.assertTrue(any(item["source"] in {"grid_icon_template", "detail_template_fallback"} for item in result["evidence"]))
        self.assertIn("stable_frame_overlap", {item["source"] for item in result["evidence"]})

    def test_inventory_adapter_never_zero_fills_missing_count(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        slot = self.catalog.region("inventory")["item"]["grid_slots"][0]
        template = Image.open(ASSETS / "templates/inventory/Item_Icon_Material_Mandragora_0.png")
        paste_ratio(frame, template, slot)
        result = InventoryMatcherAdapter(ScriptedCapture(frame), self.catalog)({"target_id": "fixture"}, Event(), lambda *_args: None)[0]
        self.assertIsNone(result["payload"]["entries"][0]["quantity"])
        self.assertTrue(result["review_required"])

    def test_inventory_low_margin_uses_detail_fallback(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        slot = self.catalog.region("inventory")["item"]["grid_slots"][0]
        template = Image.open(ASSETS / "templates/inventory/Item_Icon_Material_Mandragora_0.png")
        paste_ratio(frame, template, slot)
        result = InventoryMatcherAdapter(ScriptedCapture(frame), self.catalog, threshold=1.1)({"target_id": "fixture"}, Event(), lambda *_args: None)[0]
        item_evidence = next(item for item in result["evidence"] if item["field"].endswith(".item_id"))
        self.assertEqual("detail_template_fallback", item_evidence["source"])
        self.assertTrue(result["review_required"])

    def test_cancellation_and_import_safe_windows_boundary(self) -> None:
        frame = Image.new("RGB", (1280, 720), "black")
        cancel = Event()
        cancel.set()
        student = StudentMatcherAdapter(ScriptedCapture(frame), self.catalog)
        self.assertEqual([], student({"target_id": "fixture"}, cancel, lambda *_args: None))
        adapter = WindowsCaptureInputAdapter()
        self.assertEqual([], [item for item in adapter() if "definitely-not-a-window" in item["title"]])

    def test_windows_diagnostics_capture_failure_timeout_and_cancel(self) -> None:
        adapter = WindowsCaptureInputAdapter()
        with patch.object(WindowsCaptureInputAdapter, "_libraries", return_value=(FakeUser32(exists=False), object())):
            self.assertEqual("closed", adapter.diagnose({"target_id": "hwnd:1"})["status"])
        with patch.object(WindowsCaptureInputAdapter, "_libraries", return_value=(FakeUser32(minimized=True), object())):
            self.assertEqual("minimized", adapter.diagnose({"target_id": "hwnd:1"})["status"])
        with patch.object(WindowsCaptureInputAdapter, "_libraries", return_value=(FakeUser32(client_rect=False), object())):
            with self.assertRaisesRegex(ScannerError, "GetClientRect failed") as failure:
                adapter.capture({"target_id": "hwnd:1"})
            self.assertEqual("capture_failed", failure.exception.code)
        unstable = UnstableWindowsAdapter()
        with self.assertRaises(ScannerError) as timeout:
            unstable.wait_stable({"target_id": "fixture"}, Event(), timeout=0.01)
        self.assertEqual("capture_timeout", timeout.exception.code)
        cancel = Event()
        cancel.set()
        with self.assertRaises(ScannerError) as cancelled:
            unstable.wait_stable({"target_id": "fixture"}, cancel)
        self.assertEqual("cancelled", cancelled.exception.code)


if __name__ == "__main__":
    unittest.main()
