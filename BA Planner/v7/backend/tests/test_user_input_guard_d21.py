"""C5e-1d (D21): the scanner notices the user's own input during a scanner input step."""
import sys
from threading import Event
from time import monotonic
import unittest
from unittest.mock import patch

from PIL import Image

from core.inventory_detail_recovery import InventoryDetailRecovery
from core.inventory_navigation import InventoryNavigation
from core.scanner_session import ScannerError
from core.user_input_guard import UserInputGuard


def quick(name):
    return {"input.guard.idle_s": 0.05, "input.guard.wait_s": 0.2}[name]


class GuardStepTests(unittest.TestCase):
    def guard(self):
        guard = UserInputGuard()
        guard.available = True  # as if the hooks were installed
        guard.start = lambda: True
        return guard

    def test_user_input_during_a_step_is_input_busy_after_it_was_performed(self):
        guard = self.guard()
        with patch("core.user_input_guard.rt.value", quick):
            with self.assertRaises(ScannerError) as exc:
                with guard.step():
                    guard._note()
        self.assertEqual("input_busy", exc.exception.code)
        self.assertTrue(exc.exception.details["performed"])

    def test_a_quiet_step_passes_and_recent_input_is_waited_out(self):
        guard = self.guard()
        with patch("core.user_input_guard.rt.value", quick):
            guard.last_input = monotonic()
            started = monotonic()
            with guard.step():
                pass
            self.assertGreaterEqual(monotonic() - started, 0.04)

    def test_a_user_still_busy_after_the_budget_is_input_busy_without_sending(self):
        guard = self.guard()
        busy = Event()

        def keep_busy():
            while not busy.is_set():
                guard._note()
                busy.wait(.01)

        from threading import Thread
        worker = Thread(target=keep_busy)
        worker.start()
        try:
            with patch("core.user_input_guard.rt.value", quick), self.assertRaises(ScannerError) as exc:
                with guard.step():
                    self.fail("step body must not run while the user is busy")
        finally:
            busy.set()
            worker.join()
        self.assertFalse(exc.exception.details["performed"])

    def test_unavailable_hooks_never_block_input(self):
        guard = UserInputGuard()
        guard.start = lambda: False
        guard.last_input = monotonic()
        with guard.step():
            guard._note()

    @unittest.skipUnless(sys.platform == "win32", "low-level hooks are Windows only")
    def test_hooks_install_and_stop(self):
        guard = UserInputGuard()
        try:
            self.assertTrue(guard.start())
        finally:
            guard.stop()
        self.assertFalse(guard.available)


class BusyClickCapture:
    """Selection fixture whose first click is disturbed by user input (D21) and never lands."""
    def __init__(self):
        self.selected = 0
        self.clicks = 0

    def wait_stable(self, target, cancel, timeout=2):
        frame = Image.new("RGB", (40, 40), "white")
        frame.putpixel((0, 0), (self.selected, 0, 0))
        return frame

    def click(self, target, x, y):
        self.clicks += 1
        if self.clicks == 1:
            raise ScannerError("input_busy", "fixture", details={"performed": False})
        self.selected = 1


class BusyRecoveryTests(unittest.TestCase):
    def test_disturbed_detail_click_counts_as_a_retry_and_is_verified_by_observation(self):
        slots = [dict(x1=0, x2=.5, y1=.2, y2=.8, cx=.25, cy=.5), dict(x1=.5, x2=1, y1=.2, y2=.8, cx=.75, cy=.5)]
        from types import SimpleNamespace
        from unittest.mock import Mock
        from core.inventory_detail_recovery import DetailCount, DetailResult
        capture = BusyClickCapture()
        reader = SimpleNamespace(regions={"sources": {"item": {"grid_slots": slots}}}, classify=lambda f: "item",
                                 selected=lambda f, s, _slots=None: f.getpixel((0, 0))[0],
                                 read=Mock(return_value=DetailResult("Item_Icon_SkillBook_Hyakkiyako_0", .95, .1, DetailCount("4", .9))))
        recovery = InventoryDetailRecovery(capture, reader)
        with capture.wait_stable({}, Event()) as frame:
            recovery.begin_page({}, Event(), frame)
        with patch("core.inventory_detail_recovery.Event.wait", return_value=False):
            outcome = recovery.read({}, Event(), 1, "Item_Icon_SkillBook_Hyakkiyako_0", None, False)
        recovery.close()
        self.assertIsNone(outcome.failure)
        self.assertEqual(2, capture.clicks)
        self.assertEqual([1], [row["input_busy"] for row in recovery.trace if "input_busy" in row])


class BusyDragCapture:
    def __init__(self, outcomes):
        self.outcomes = list(outcomes)
        self.drags = 0
        self.frame = Image.new("RGB", (1280, 720), "#789abc")

    def drag_path(self, target, path, hold):
        self.drags += 1
        outcome = self.outcomes.pop(0)
        if outcome is not None:
            raise ScannerError("input_busy", "fixture", details={"performed": outcome})

    def wait_stable(self, target, cancel, timeout=2):
        return self.frame.copy()


class BusyDragTests(unittest.TestCase):
    def navigation(self, outcomes, shifts):
        nav = object.__new__(InventoryNavigation)
        nav.capture = BusyDragCapture(outcomes)
        nav.trace = []
        nav.regions = {"scroll_track": dict(x=.975, start_y=.75, end_y=[.65, .58])}
        shifts = iter(shifts)
        nav.measure_shift = lambda before, after, source, expected=None: next(shifts)
        return nav

    def test_unsent_drag_is_retried_and_a_disturbed_drag_that_moved_is_measured(self):
        nav = self.navigation([False, None], [(.4, 1.0)])
        moved = nav.advance({}, Event(), nav.capture.frame, "item", .4)
        self.assertEqual(2, nav.capture.drags)
        self.assertAlmostEqual(.4, moved.shift)
        nav = self.navigation([True], [(.3, 1.0)])
        moved = nav.advance({}, Event(), nav.capture.frame, "item", .4)
        self.assertEqual(1, nav.capture.drags)
        self.assertAlmostEqual(.3, moved.shift)

    def test_a_disturbed_no_motion_drag_is_never_end_evidence(self):
        nav = self.navigation([True, None, None], [(0.0, .1), (0.0, .1), (0.0, .1)])
        moved = nav.advance({}, Event(), nav.capture.frame, "item", .4)
        self.assertTrue(moved.terminal)
        self.assertEqual(3, nav.capture.drags)

    def test_more_than_two_disturbed_drags_stop_the_scan(self):
        nav = self.navigation([False, False, False], [])
        with self.assertRaises(ScannerError) as exc:
            nav.advance({}, Event(), nav.capture.frame, "item", .4)
        self.assertEqual("input_busy", exc.exception.code)


if __name__ == "__main__":
    unittest.main()
