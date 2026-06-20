from __future__ import annotations

import unittest
from unittest.mock import patch

from PIL import Image

from core.scanner import Scanner


class ScannerWaitTests(unittest.TestCase):
    def _scanner(self) -> Scanner:
        scanner = Scanner.__new__(Scanner)
        scanner._stop_requested = lambda: False
        scanner._panel_transition_history = {}
        scanner._panel_title_score_history = {}
        scanner._basic_level_run_templates = {}
        return scanner

    def test_clock_can_pass_deadline_between_checks(self) -> None:
        scanner = self._scanner()
        sleep_values: list[float] = []

        with (
            patch("core.scanner.time.monotonic", side_effect=[10.0, 10.05, 10.11]),
            patch("core.scanner.time.sleep", side_effect=sleep_values.append),
        ):
            self.assertTrue(scanner._wait(0.1, step=0.05))

        self.assertEqual(len(sleep_values), 1)
        self.assertAlmostEqual(sleep_values[0], 0.05)
        self.assertTrue(all(value >= 0 for value in sleep_values))

    def test_non_positive_wait_does_not_sleep(self) -> None:
        scanner = self._scanner()

        with patch("core.scanner.time.sleep") as sleep:
            self.assertTrue(scanner._wait(-1.0))

        sleep.assert_not_called()

    def test_panel_transition_wait_learns_from_current_run(self) -> None:
        scanner = self._scanner()
        key = "open:skill_menu_button"

        self.assertAlmostEqual(scanner._panel_transition_initial_wait(key), 0.10)
        for elapsed in (0.42, 0.44, 0.46):
            scanner._record_panel_transition(
                key,
                elapsed,
                success=True,
                initial_wait=0.10,
            )

        self.assertAlmostEqual(scanner._panel_transition_initial_wait(key), 0.34)

    def test_failed_transition_does_not_train_wait(self) -> None:
        scanner = self._scanner()
        key = "close:close_skill_menu"

        scanner._record_panel_transition(
            key,
            2.5,
            success=False,
            initial_wait=0.10,
        )

        self.assertEqual(scanner._panel_transition_history[key], [])
        self.assertAlmostEqual(scanner._panel_transition_initial_wait(key), 0.10)

    def test_transition_history_is_reset_between_runs(self) -> None:
        scanner = self._scanner()
        scanner._panel_transition_history["open:skill"] = [0.4, 0.5]

        scanner._reset_panel_transition_history()

        self.assertEqual(scanner._panel_transition_history, {})
        self.assertEqual(scanner._panel_title_score_history, {})
        self.assertEqual(scanner._basic_level_run_templates, {})

    def test_panel_title_threshold_calibrates_per_run(self) -> None:
        scanner = self._scanner()

        self.assertAlmostEqual(scanner._panel_title_score_threshold("weapon"), 0.86)
        scanner._record_panel_title_score("weapon", 0.858)

        self.assertAlmostEqual(scanner._panel_title_score_threshold("weapon"), 0.833)

    def test_panel_title_threshold_has_safety_floor(self) -> None:
        scanner = self._scanner()
        scanner._panel_title_score_history["weapon"] = [0.821, 0.823, 0.824]

        self.assertAlmostEqual(scanner._panel_title_score_threshold("weapon"), 0.82)

    def test_capture_match_can_require_two_stable_frames(self) -> None:
        scanner = self._scanner()
        captures = iter([object(), object()])
        scanner._capture = lambda: next(captures)
        scanner._wait = lambda _seconds: True

        result = scanner._wait_for_capture_match(
            lambda image: image is not None,
            timeout=1.0,
            poll=0.0,
            stable_polls=2,
            label="equipment_tab",
        )

        self.assertIsNotNone(result)

    def test_student_change_waits_for_two_stable_portrait_frames(self) -> None:
        scanner = self._scanner()
        scanner.r = {
            "student": {
                "student_texture_region": {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0}
            }
        }
        old = Image.new("RGB", (32, 32), (0, 0, 0))
        transition = Image.new("RGB", (32, 32), (120, 120, 120))
        new = Image.new("RGB", (32, 32), (255, 255, 255))
        captures = iter([old, transition, new, new])
        scanner._get_student_basic_capture = lambda *, refresh: next(captures)
        scanner._wait = lambda _seconds: True

        result = scanner._wait_for_student_change(
            scanner._student_texture_digest(old),
            timeout=1.0,
            initial_wait=0.0,
            poll=0.0,
        )

        self.assertEqual(result, scanner._student_texture_digest(new))


if __name__ == "__main__":
    unittest.main()
