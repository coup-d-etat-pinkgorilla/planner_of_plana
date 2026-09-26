from __future__ import annotations

from pathlib import Path
import hashlib
import json
from threading import Event
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_session import ScannerError
from core.student_scan_recognizer import Observation
from core.student_panel_recovery import StudentPanelRecovery, StudentPanelRecognizer, merge_observation, read_panel_fields
from core.windows_scanner_adapter import WindowsCaptureInputAdapter
from test_scanner_fallback_f1 import NativeUser, NativeGdi, TARGET


class FastEvent:
    def __init__(self): self.stopped = False
    def is_set(self): return self.stopped
    def set(self): self.stopped = True
    def wait(self, _seconds): return self.stopped


class ScriptedUI:
    def __init__(self, states, cancel=None, cancel_on=None):
        self.states = iter(states)
        self.actions, self.frames = [], []
        self.cancel, self.cancel_on = cancel, cancel_on

    def wait_stable(self, target, cancel, timeout=2):
        if cancel.is_set(): raise ScannerError("cancelled", "cancelled")
        state = next(self.states)
        if isinstance(state, Exception): raise state
        frame = Image.new("RGB", (8, 8), "white")
        frame.info["state"] = state
        self.frames.append(frame)
        if self.cancel and len(self.frames) == self.cancel_on: self.cancel.set()
        return frame

    def click(self, target, x, y):
        if target.get("_scanner_cancel", FastEvent()).is_set() and not target.get("_scanner_cleanup"):
            raise ScannerError("cancelled", "cancelled")
        self.actions.append(("click", x, y))

    def press_key(self, target, key):
        self.actions.append(("key", key))
        return True


class FakeRecognizer:
    def __init__(self):
        self.regions = RecognitionAssetCatalog().region_for_purpose("student", "student-panel-regions")
        self.scores = {}
    def classify(self, frame): return "basic" if frame.info["state"] == "other-student" else frame.info["state"]
    def identity(self, frame): return [frame.copy()]
    def same_student(self, frame, _baseline): return frame.info["state"] != "other-student"
    def close(self): pass


def observation(value, confidence=.95, status=None):
    return Observation(value, confidence, status or ("ok" if value is not None else "uncertain"), "fixture", "")


class PanelTransitions(unittest.TestCase):
    def machine(self, states, **kwargs):
        ui = ScriptedUI(states, **kwargs)
        machine = StudentPanelRecovery(ui, None, recognizer=FakeRecognizer())
        self.addCleanup(machine.close)
        # Real cancellation tests use the actual token for open; cleanup has its own token.
        self.patch = patch("core.student_panel_recovery.Event", FastEvent)
        self.patch.start(); self.addCleanup(self.patch.stop)
        return ui, machine

    def open(self, machine, cancel=None):
        return machine.open(TARGET, cancel or FastEvent(), "weapon", dict(x1=.8,x2=.9,y1=.6,y2=.7))

    def test_open_delayed_final_capture_and_verified_return(self):
        ui, m = self.machine(["basic", "basic", "unknown", "basic", "weapon", "weapon", "basic"])
        self.open(m).close(); m.restore(TARGET)
        self.assertEqual("basic", m.state)
        self.assertEqual(2, len(ui.actions))
        self.assertIsNone(m.baseline)
        for frame in ui.frames:
            with self.assertRaises(ValueError): frame.getpixel((0,0))

    def test_ignored_open_preserves_basic_without_extra_click(self):
        ui, m = self.machine(["basic"]*6)
        with self.assertRaises(ScannerError) as caught: self.open(m)
        self.assertEqual("panel_open_failed", caught.exception.code)
        self.assertEqual("basic", caught.exception.details["screen_state"])
        self.assertEqual(1, len(ui.actions))

    def test_wrong_panel_is_not_read_and_uses_its_own_close(self):
        ui, m = self.machine(["basic"]+["equipment"]*5+["basic"])
        with self.assertRaises(ScannerError) as caught: self.open(m)
        self.assertEqual("panel_open_failed", caught.exception.code)
        self.assertAlmostEqual(.93775, ui.actions[-1][1])

    def test_primary_close_ignored_uses_alternate_then_escape(self):
        ui, m = self.machine(["basic", "weapon"]+["weapon"]*5+["basic"])
        self.open(m).close(); m.restore(TARGET)
        self.assertEqual(4, len(ui.actions))
        self.assertNotEqual(ui.actions[1], ui.actions[2])
        self.assertEqual(("key", "escape"), ui.actions[3])

    def test_unknown_state_never_uses_blind_close_coordinates(self):
        ui, m = self.machine(["basic", "weapon", "unknown", "basic"])
        self.open(m).close(); m.restore(TARGET)
        self.assertEqual(("key", "escape"), ui.actions[1])

    def test_close_exhaustion_is_fatal_and_bounded(self):
        ui, m = self.machine(["basic"]+["weapon"]*8)
        self.open(m).close()
        with self.assertRaises(ScannerError) as caught: m.restore(TARGET)
        self.assertEqual("panel_restore_failed", caught.exception.code)
        self.assertEqual(4, len(ui.actions))
        self.assertIsNone(m.baseline)

    def test_changed_student_return_stops_without_further_input(self):
        ui, m = self.machine(["basic", "weapon", "other-student"])
        self.open(m).close()
        with self.assertRaises(ScannerError): m.restore(TARGET)
        self.assertEqual(1, len(ui.actions))

    def test_cancel_before_open_has_no_input(self):
        signal = FastEvent(); signal.set()
        ui, m = self.machine([])
        with self.assertRaises(ScannerError): self.open(m, signal)
        self.assertEqual([], ui.actions)

    def test_cancel_during_open_still_verifies_cleanup(self):
        signal = FastEvent()
        ui, m = self.machine(["basic", "weapon", "weapon", "basic"], cancel=signal, cancel_on=2)
        # _observe must reject a cancellation that arrives during capture/classification.
        with self.assertRaises(ScannerError) as caught:
            self.open(m, signal)
        self.assertEqual("cancelled", caught.exception.code)
        self.assertEqual("basic", m.state)
        self.assertEqual(2, len(ui.actions))

    def test_recapture_rechecks_panel_and_cancel(self):
        ui, m = self.machine(["basic", "weapon", "basic", "basic", "basic"])
        self.open(m).close()
        with self.assertRaises(ScannerError): m.recapture(TARGET, FastEvent(), "weapon")
        m.restore(TARGET)
        self.assertEqual(1, len(ui.actions))


class PanelValues(unittest.TestCase):
    def test_confirmed_is_not_replaced_by_higher_confidence_unknown(self):
        known = observation(60, .7)
        self.assertIs(known, merge_observation(known, observation(None, .99)))

    def test_conflicting_values_are_sticky_and_preserve_first_value(self):
        conflict = merge_observation(observation(60), observation(50))
        self.assertEqual(60, conflict.value)
        self.assertEqual("uncertain", conflict.status)
        self.assertEqual("panel_value_conflict", conflict.source)
        self.assertIs(conflict, merge_observation(conflict, observation(50, 1)))

    def test_read_retry_recovers_one_field_without_losing_other(self):
        frames, closes = [], []
        def frame(*_a):
            image = Image.new("RGB", (8,8)); frames.append(image); return image
        menu = SimpleNamespace(capture=frame, recapture=frame,
                               close=lambda *_a: closes.append(1))
        reads = iter([{"level":observation(60,.7),"star":observation(None)},
                      {"level":observation(None,.99),"star":observation(4)}])
        result = read_panel_fields(menu,"weapon",TARGET,FastEvent(),{},("level","star"),lambda _f:next(reads),attempts=3)
        self.assertEqual(60, result["level"].value); self.assertEqual(4, result["star"].value)
        self.assertEqual(2,len(frames));self.assertEqual([1],closes)

    def test_read_failure_is_partial_only_after_verified_return(self):
        def fail(_frame): raise ValueError("bad digits")
        def frame(*_a): return Image.new("RGB", (8,8))
        menu = SimpleNamespace(capture=frame, close=lambda *_a:None,
                               recovery=SimpleNamespace(state="basic"))
        result=read_panel_fields(menu,"weapon",TARGET,FastEvent(),{"level":observation(60)},("level",),fail)
        self.assertEqual(60,result["level"].value)
        self.assertEqual("partial",result["weapon_panel"].status)
        def bad_close(*_a): raise ScannerError("panel_restore_failed","lost")
        menu.close=bad_close
        with self.assertRaises(ScannerError): read_panel_fields(menu,"weapon",TARGET,FastEvent(),{},("level",),fail)

    def test_escape_is_not_an_extended_key(self):
        u = NativeUser()
        u.MapVirtualKeyW = lambda *_a: 1
        flags = []
        def send(n, events, _size):
            flags.extend(events[i].ki.dwFlags for i in range(n))
            return n
        u.SendInput = send
        with patch.object(WindowsCaptureInputAdapter,"_libraries",return_value=(u,NativeGdi())):
            WindowsCaptureInputAdapter().press_key(TARGET,"escape")
        self.assertEqual([8,10], flags)


class PanelPixels(unittest.TestCase):
    def test_live_1280_states_and_same_student_return(self):
        folder = Path(__file__).parent / "fixtures/student_panel_f2_live"
        manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        recognizer = StudentPanelRecognizer(RecognitionAssetCatalog()); self.addCleanup(recognizer.close)
        for row in manifest["records"]:
            with self.subTest(file=row["file"]):
                path = folder / row["file"]
                self.assertEqual(row["sha256"],hashlib.sha256(path.read_bytes()).hexdigest())
                with Image.open(path) as frame:
                    self.assertEqual((1280,720),frame.size)
                    self.assertEqual(row["expected"],recognizer.classify(frame))
        with Image.open(folder/"basic.png") as frame: baseline=recognizer.identity(frame)
        try:
            with Image.open(folder/"basic_return.png") as frame: self.assertTrue(recognizer.same_student(frame,baseline))
            with Image.open(folder/"other_student.png") as frame: self.assertFalse(recognizer.same_student(frame,baseline))
        finally:
            for image in baseline:image.close()

    def test_four_competing_titles_are_not_interchangeable(self):
        recognizer = StudentPanelRecognizer(RecognitionAssetCatalog()); self.addCleanup(recognizer.close)
        region = recognizer.regions["title"]
        box = tuple(round(value * scale) for value,scale in zip(
            (region["x1"],region["y1"],region["x2"],region["y2"]),(1280,720,1280,720)))
        for name in ("equipment","weapon","skill","stat"):
            with Image.new("RGB",(1280,720),"black") as frame:
                template = recognizer.templates[name].resize((box[2]-box[0],box[3]-box[1]))
                frame.paste(template,box); template.close()
                self.assertEqual(name,recognizer.classify(frame))

    def test_missing_templates_are_not_permissive(self):
        catalog=RecognitionAssetCatalog()
        with patch.object(catalog,"assets", wraps=catalog.assets) as assets:
            original=catalog.assets.__wrapped__ if hasattr(catalog.assets,"__wrapped__") else assets._mock_wraps
            assets.side_effect=lambda kind,purpose: [] if purpose=="student-panel-template" else original(kind,purpose)
            with self.assertRaises(ScannerError): StudentPanelRecognizer(catalog)

    def test_real_basic_and_blank_are_distinct(self):
        recognizer=StudentPanelRecognizer(RecognitionAssetCatalog());self.addCleanup(recognizer.close)
        with Image.open(Path(__file__).parent/'fixtures/student_scan_s2_serika_new_year.png') as frame:
            self.assertEqual("basic",recognizer.classify(frame))
        for color in ("black","white","gray"):
            with Image.new("RGB",(1280,720),color) as frame:
                self.assertEqual("unknown",recognizer.classify(frame))
