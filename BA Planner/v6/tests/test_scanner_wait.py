from __future__ import annotations

import unittest
from unittest.mock import patch

from PIL import Image

from core.scanner import INVENTORY_GRID_ORDER_HINT_PROFILES, Scanner


class ScannerWaitTests(unittest.TestCase):
    def _scanner(self) -> Scanner:
        scanner = Scanner.__new__(Scanner)
        scanner._stop_requested = lambda: False
        scanner._panel_transition_history = {}
        scanner._panel_title_score_history = {}
        scanner._basic_level_run_templates = {}
        scanner._on_progress = None
        scanner._status = lambda *_args, **_kwargs: None
        scanner._stop = False
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

    def test_inventory_filter_panel_retries_until_title_is_recognized(self) -> None:
        scanner = self._scanner()
        clicks: list[str] = []
        scanner._click_region_capture = lambda _name, *, label="", delay=0.0: clicks.append(label) or True
        outcomes = iter([False, True])
        scanner._wait_for_inventory_filter_menu_open = lambda **_kwargs: next(outcomes)

        self.assertTrue(
            scanner._open_inventory_filter_panel(
                "filtermenu_button",
                label="filtermenu_button",
                max_attempts=2,
            )
        )
        self.assertEqual(clicks, ["filtermenu_button", "filtermenu_button"])
        self.assertFalse(scanner._stop)

    def test_inventory_filter_panel_stops_when_title_is_not_recognized(self) -> None:
        scanner = self._scanner()
        scanner._click_region_capture = lambda _name, *, label="", delay=0.0: True
        scanner._wait_for_inventory_filter_menu_open = lambda **_kwargs: False

        self.assertFalse(
            scanner._open_inventory_filter_panel(
                "filtermenu_button",
                label="filtermenu_button",
                max_attempts=2,
            )
        )
        self.assertTrue(scanner._stop)

    def test_prepare_item_inventory_applies_filter_before_sort_rule(self) -> None:
        scanner = self._scanner()
        events: list[str] = []
        scanner._wait = lambda *_args, **_kwargs: True
        scanner._open_item_inventory_filter_panel = lambda **_kwargs: events.append("open:filtermenu_button") or True
        scanner._click_region_capture = lambda name, *, label="", delay=0.0: events.append(f"click:{name}") or True
        scanner._ensure_region_matches_reference = lambda name, **_kwargs: events.append(f"ensure:{name}") or True

        self.assertTrue(scanner._prepare_item_inventory("ooparts", ensure_sort_rule=False))
        self.assertEqual(
            events,
            [
                "open:filtermenu_button",
                "click:filter_tab",
                "click:filter_tab",
                "click:filter_reset_button",
                "click:ooparts_filter",
                "click:sort_tab",
                "click:sort_tab",
                "ensure:sort_rule_check",
                "click:filter_confirm_button",
            ],
        )

    def test_prepare_item_inventory_uses_name_sort_for_elephs(self) -> None:
        scanner = self._scanner()
        events: list[str] = []
        scanner._wait = lambda *_args, **_kwargs: True
        scanner._open_item_inventory_filter_panel = lambda **_kwargs: events.append("open:filtermenu_button") or True
        scanner._click_region_capture = lambda name, *, label="", delay=0.0: events.append(f"click:{name}") or True
        scanner._ensure_region_matches_reference = lambda name, **_kwargs: events.append(f"ensure:{name}") or True

        self.assertTrue(scanner._prepare_item_inventory("student_elephs", ensure_sort_rule=True))
        self.assertEqual(
            events,
            [
                "open:filtermenu_button",
                "click:filter_tab",
                "click:filter_tab",
                "click:filter_reset_button",
                "click:eleph_filter",
                "click:sort_tab",
                "click:sort_tab",
                "ensure:sort_name_rule_check",
                "click:filter_confirm_button",
            ],
        )

    def test_presents_use_grid_order_hint_profile(self) -> None:
        self.assertIn("presents", INVENTORY_GRID_ORDER_HINT_PROFILES)

    def test_prepare_item_inventory_uses_ooparts_filter_and_default_sort_for_presents(self) -> None:
        scanner = self._scanner()
        events: list[str] = []
        scanner._wait = lambda *_args, **_kwargs: True
        scanner._open_item_inventory_filter_panel = lambda **_kwargs: events.append("open:filtermenu_button") or True
        scanner._click_region_capture = lambda name, *, label="", delay=0.0: events.append(f"click:{name}") or True
        scanner._ensure_region_matches_reference = lambda name, **_kwargs: events.append(f"ensure:{name}") or True

        self.assertTrue(scanner._prepare_item_inventory("presents", ensure_sort_rule=True))
        self.assertEqual(
            events,
            [
                "open:filtermenu_button",
                "click:filter_tab",
                "click:filter_tab",
                "click:filter_reset_button",
                "click:ooparts_filter",
                "click:sort_tab",
                "click:sort_tab",
                "ensure:sort_rule_check",
                "click:filter_confirm_button",
            ],
        )

    def test_prepare_equipment_inventory_keeps_sort_default_then_confirms(self) -> None:
        scanner = self._scanner()
        events: list[str] = []
        scanner._wait = lambda *_args, **_kwargs: True
        scanner._open_equipment_inventory_filter_panel = lambda **_kwargs: events.append("open:eq_filtermenu_button") or True
        scanner._click_region_capture = lambda name, *, label="", delay=0.0: events.append(f"click:{name}") or True
        scanner._ensure_region_matches_reference = lambda name, **_kwargs: events.append(f"ensure:{name}") or True

        self.assertTrue(scanner._prepare_equipment_inventory())
        self.assertEqual(
            events,
            [
                "open:eq_filtermenu_button",
                "ensure:eq_sort_rule_check",
                "click:eq_filter_confirm_button",
            ],
        )

    def test_equipment_filter_menu_open_accepts_equipment_sort_reference(self) -> None:
        scanner = self._scanner()
        scanner._wait = lambda *_args, **_kwargs: True
        scanner._capture = lambda: object()
        scanner._inventory_filter_title_score = lambda _img: 0.0
        scanner._region_capture_match_score = lambda name: 0.71 if name == "eq_sort_rule_check" else 0.0
        scanner._debug = lambda *_args, **_kwargs: None

        self.assertTrue(scanner._wait_for_equipment_inventory_filter_menu_open(initial_wait=0.0))

    def test_prepare_item_inventory_reselects_tabs_without_sort_probe_during_filtering(self) -> None:
        scanner = self._scanner()
        events: list[str] = []
        scanner._wait = lambda *_args, **_kwargs: True
        scanner._open_item_inventory_filter_panel = lambda **_kwargs: events.append("open:filtermenu_button") or True
        scanner._click_region_capture = lambda name, *, label="", delay=0.0: events.append(f"click:{name}") or True
        scanner._ensure_region_matches_reference = lambda name, **_kwargs: events.append(f"ensure:{name}") or True

        self.assertTrue(scanner._prepare_item_inventory("ooparts", ensure_sort_rule=False))
        self.assertEqual(events.index("ensure:sort_rule_check"), len(events) - 2)
        self.assertNotIn("ensure:eq_sort_rule_check", events)

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
