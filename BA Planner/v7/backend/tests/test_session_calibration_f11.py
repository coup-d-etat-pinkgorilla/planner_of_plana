from __future__ import annotations

from json import loads
from pathlib import Path
from threading import Event
from types import MethodType, SimpleNamespace
import unittest

from PIL import Image

from core.scanner_matchers import StudentMatcherAdapter
from core.session_calibration import SessionCalibrationStore
from core.student_scan_recognizer import StudentBasicRecognizer
from core.studio_numeric_bank import StudioNumericBank


PROFILE_A = "a" * 24
PROFILE_B = "b" * 24
FIXTURE = Path(__file__).parent / "fixtures" / "session_calibration_f11_v6_parity.json"


def light_cell(points: set[tuple[int, int]]) -> Image.Image:
    image = Image.new("RGB", (8, 12), (30, 30, 30))
    for point in points:
        image.putpixel(point, (245, 245, 245))
    return image


def mask(points: set[tuple[int, int]]) -> Image.Image:
    image = Image.new("L", (8, 12))
    for point in points:
        image.putpixel(point, 255)
    return image


VERTICAL = {(3, y) for y in range(2, 10)}
HORIZONTAL = {(x, 6) for x in range(1, 7)}


class SessionCalibrationStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.store = SessionCalibrationStore("session-a", 7)
        self.addCleanup(self.store.close)

    def _add(self, **overrides) -> int:
        first = light_cell(VERTICAL)
        second = light_cell(HORIZONTAL)
        self.addCleanup(first.close)
        self.addCleanup(second.close)
        values = dict(
            profile_id=PROFILE_A,
            source_size=(1280, 720),
            student_ref="mika:0",
            field="student_level",
            value=90,
            cells=(first, second),
            roi_names=("studentlevel_digit1", "studentlevel_digit2"),
            detail_source="level_tab_template",
            detail_panel_verified=True,
            value_confirmed=True,
            conflict=False,
        )
        values.update(overrides)
        return self.store.add_numeric(**values)

    def test_fixture_freezes_approved_d1_scope_precedence_and_discard(self) -> None:
        payload = loads(FIXTURE.read_text(encoding="utf-8"))
        policy = payload["v7_policy"]
        self.assertEqual("R24", payload["requirement"])
        self.assertEqual(
            ["user_confirmed", "session_calibrated", "bundled"],
            policy["precedence"],
        )
        self.assertIn("student_ref", policy["scope_key"])
        self.assertEqual(
            {"cancel", "terminal", "profile_change", "capture_resolution_change"},
            set(policy["discard_on"]),
        )

    def test_verified_detail_truth_is_scoped_to_same_profile_resolution_and_form(self) -> None:
        self.assertEqual(2, self._add())
        matching = self.store.numeric_samples(
            profile_id=PROFILE_A, source_size=(1280, 720), student_ref="mika:0",
        )
        self.assertEqual(("9", "0"), tuple(sample.digit for sample in matching))
        self.assertEqual((), self.store.numeric_samples(
            profile_id=PROFILE_A, source_size=(1280, 720), student_ref="mika:1",
        ))
        self.assertEqual((), self.store.numeric_samples(
            profile_id=PROFILE_B, source_size=(1280, 720), student_ref="mika:0",
        ))
        self.assertEqual((), self.store.numeric_samples(
            profile_id=PROFILE_A, source_size=(2560, 1440), student_ref="mika:0",
        ))

    def test_detail_error_conflict_and_self_output_are_rejected(self) -> None:
        self.assertEqual(0, self._add(value_confirmed=False))
        self.assertEqual(0, self._add(conflict=True))
        self.assertEqual(0, self._add(detail_panel_verified=False))
        self.assertEqual(0, self._add(detail_source="student_level_studio_position_bank_session_calibrated"))
        self.assertEqual(0, self.store.sample_count)

    def test_profile_or_resolution_change_and_terminal_discard_close_the_bank(self) -> None:
        self.assertEqual(2, self._add())
        self.assertTrue(self.store.bind_scope(PROFILE_A, (2560, 1440)))
        self.assertEqual(0, self.store.sample_count)
        self.assertEqual(2, self._add(source_size=(2560, 1440)))
        self.store.discard()
        self.assertEqual(0, self.store.sample_count)
        self.assertIsNone(self.store.scope)

    def test_session_and_generation_are_independent_owners(self) -> None:
        self.assertEqual(2, self._add())
        other = SessionCalibrationStore("session-a", 8)
        self.addCleanup(other.close)
        self.assertEqual(0, other.sample_count)
        self.assertEqual((), other.numeric_samples(
            profile_id=PROFILE_A, source_size=(1280, 720), student_ref="mika:0",
        ))


class SessionCalibrationPrecedenceTests(unittest.TestCase):
    def setUp(self) -> None:
        bundled_one = mask(VERTICAL)
        bundled_two = mask(HORIZONTAL)
        self.bank = StudioNumericBank({"roi": {"1": bundled_one, "2": bundled_two}})
        self.addCleanup(self.bank.close)

    def test_session_sample_beats_equally_shaped_bundled_template_with_distinct_provenance(self) -> None:
        source = light_cell(VERTICAL)
        session = mask(VERTICAL)
        self.addCleanup(source.close)
        self.addCleanup(session.close)
        self.bank.add_session_template("roi", "2", session, sample_id="session:1")
        result = self.bank.match((source,), field="student_level", roi_names=("roi",))
        self.assertEqual(2, result.value)
        self.assertTrue(result.used_session_sample)
        self.assertFalse(result.used_user_sample)
        observation = StudentBasicRecognizer._studio_numeric_observation(
            result, minimum=1, maximum=100, score_gate=.5, margin_gate=.01,
            source="student_level_studio_position_bank",
        )
        self.assertEqual(
            "student_level_studio_position_bank_session_calibrated",
            observation.source,
        )

    def test_user_sample_has_priority_over_session_sample(self) -> None:
        source = light_cell(VERTICAL)
        session = mask(VERTICAL)
        user = mask(VERTICAL)
        self.addCleanup(source.close)
        self.addCleanup(session.close)
        self.addCleanup(user.close)
        self.bank.add_session_template("roi", "2", session, sample_id="session:1")
        self.bank.add_user_template("roi", "1", user, sample_id="user:1")
        result = self.bank.match((source,), field="student_level", roi_names=("roi",))
        self.assertEqual(1, result.value)
        self.assertTrue(result.used_user_sample)
        self.assertFalse(result.used_session_sample)


class SessionCalibrationLifecycleTests(unittest.TestCase):
    def test_matcher_terminal_discards_samples_and_active_templates(self) -> None:
        class Bank:
            def __init__(self) -> None:
                self.clears = 0

            def clear_session_templates(self) -> None:
                self.clears += 1

        adapter = StudentMatcherAdapter.__new__(StudentMatcherAdapter)
        basic_bank = Bank()
        equipment_bank = Bank()
        adapter.basic_recognizer = SimpleNamespace(studio_numeric_bank=basic_bank)
        adapter.equipment_recognizer = SimpleNamespace(studio_numeric_bank=equipment_bank)
        observed = {}

        def scan(_self, target, _cancel, _progress):
            observed["session_id"] = _self.session_calibration.session_id
            observed["generation"] = _self.session_calibration.generation
            self.assertTrue(_self.session_calibration.bind_scope(PROFILE_A, (1280, 720)))
            return []

        adapter._scan_with_forms = MethodType(scan, adapter)
        result = adapter(
            {
                "_scanner_session_id": "session-owned",
                "_scanner_generation": 3,
                "profile_id": PROFILE_A,
                "student_scan_mode": "single",
            },
            Event(),
            lambda *_args: None,
        )
        self.assertEqual([], result)
        self.assertEqual({"session_id": "session-owned", "generation": 3}, observed)
        self.assertIsNone(adapter.session_calibration)
        self.assertEqual(1, basic_bank.clears)
        self.assertEqual(1, equipment_bank.clears)


if __name__ == "__main__":
    unittest.main()
