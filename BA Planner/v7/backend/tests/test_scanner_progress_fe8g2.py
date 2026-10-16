from copy import deepcopy
from pathlib import Path
import json
from threading import Event
from types import SimpleNamespace
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from core.scanner_session import _SessionProgress, ScannerEventCursor


ROOT = Path(__file__).resolve().parents[2]
CONTRACTS = ROOT / 'contracts'


class ScannerProgressFE8G2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base = json.loads((CONTRACTS / 'scanner-protocol-v1.schema.json').read_text(encoding='utf-8'))
        fixed = json.loads((CONTRACTS / 'scanner-student-progress-fe8g2-v1.schema.json').read_text(encoding='utf-8'))
        cls.fixture = json.loads((CONTRACTS / 'fixtures/scanner_student_progress_fe8g2_v1.json').read_text(encoding='utf-8'))
        registry = Registry().with_resources([(base['$id'], Resource.from_contents(base)), (fixed['$id'], Resource.from_contents(fixed))])
        cls.base = Draft202012Validator(base, registry=registry)
        cls.fixed = Draft202012Validator(fixed, registry=registry)

    def test_all_fixed_events_already_satisfy_existing_wire(self):
        for event in self.fixture['events']:
            with self.subTest(kind=event['payload']['event_kind']):
                self.base.validate(event)
                self.fixed.validate(event)

    def test_total_unknown_and_known_zero_remain_distinct(self):
        event = deepcopy(self.fixture['events'][2])
        self.assertIsNone(event['payload']['total'])
        self.fixed.validate(event)
        event['payload']['total'] = 0
        self.fixed.validate(event)
        self.assertEqual(0, event['payload']['total'])

    def test_student_subset_does_not_freeze_inventory_schema(self):
        event = deepcopy(self.fixture['events'][2])
        event['payload']['scan_kind'] = 'inventory'
        self.base.validate(event)
        self.assertTrue(list(self.fixed.iter_errors(event)))

    def test_invalid_counters_fail(self):
        for value in (None, True, -1, 1.5, '1'):
            event = deepcopy(self.fixture['events'][2])
            event['payload']['current'] = value
            with self.subTest(value=value):
                self.assertTrue(list(self.fixed.iter_errors(event)))

    def test_invalid_total_fails(self):
        for value in (False, -1, 1.5, 'unknown'):
            event = deepcopy(self.fixture['events'][2])
            event['payload']['total'] = value
            with self.subTest(value=value):
                self.assertTrue(list(self.fixed.iter_errors(event)))

    def test_unknown_wire_key_still_fails(self):
        event = deepcopy(self.fixture['events'][2])
        event['payload']['live_level'] = 90
        self.assertTrue(list(self.fixed.iter_errors(event)))

    def test_identify_feedback_has_no_invented_growth_values(self):
        feedback = self.fixture['events'][3]['payload']
        self.assertEqual('student_id', feedback['field'])
        self.assertEqual({}, feedback['values'])
        self.assertNotIn('candidate', feedback)

    def test_pause_reason_is_not_optional(self):
        event = deepcopy(self.fixture['events'][5])
        self.assertEqual('paused', event['payload']['event_kind'])
        del event['payload']['reason']
        self.assertTrue(list(self.fixed.iter_errors(event)))

    def test_resume_reason_is_explicit_null(self):
        event = deepcopy(self.fixture['events'][6])
        self.assertIsNone(event['payload']['reason'])
        event['payload']['reason'] = 'user'
        self.assertTrue(list(self.fixed.iter_errors(event)))

    def test_cursor_rejects_stale_duplicate_gap_and_after_terminal(self):
        cursor = ScannerEventCursor('synthetic-fe8g2', 1)
        events = self.fixture['events']
        self.assertEqual('accepted', cursor.consume(events[0]))
        self.assertEqual('duplicate_or_out_of_order', cursor.consume(events[0]))
        self.assertEqual('snapshot_required', cursor.consume(events[2]))
        stale = deepcopy(events[1]); stale['payload']['generation'] = 2
        self.assertEqual('stale', cursor.consume(stale))
        for event in events[1:]:
            self.assertEqual('accepted', cursor.consume(event))
        after = deepcopy(events[-1]); after['payload']['sequence'] += 1
        self.assertEqual('after_terminal', cursor.consume(after))

    def _progress(self):
        calls = []
        service = SimpleNamespace(_emit=lambda session, kind, data: calls.append((kind, data)))
        session = SimpleNamespace(cancel=Event())
        return _SessionProgress(service, session), session, calls

    def test_actual_callback_emits_the_same_progress_and_identify_payload(self):
        progress, _, calls = self._progress()
        progress(0, None, 'scanner.student.identify', {'student_id': 'shiroko', 'field': 'student_id', 'values': {}})
        self.assertEqual([('progress', {'current': 0, 'total': None, 'message_key': 'scanner.student.identify'}),
                          ('feedback', {'student_id': 'shiroko', 'field': 'student_id', 'values': {}})], calls)
        for index, (kind, data) in enumerate(calls, 3):
            expected = self.fixture['events'][index-1]['payload']
            self.assertEqual({k: v for k, v in expected.items() if k not in ('session_id', 'generation', 'sequence', 'scan_kind', 'event_kind')}, data)
            self.assertEqual(expected['event_kind'], kind)

    def test_cancelled_callback_emits_nothing(self):
        progress, session, calls = self._progress()
        session.cancel.set()
        progress(1, None, 'scanner.student.identify', {'student_id': 'shiroko', 'field': 'student_id', 'values': {}})
        self.assertEqual([], calls)

    def test_invalid_feedback_never_becomes_a_student_event(self):
        for feedback in ({'student_id': '', 'field': 'student_id', 'values': {}},
                         {'student_id': 'shiroko', 'field': '', 'values': {}},
                         {'student_id': 'shiroko', 'field': 'student_id', 'values': []}):
            progress, _, calls = self._progress()
            progress(1, None, 'scanner.student.identify', feedback)
            self.assertEqual(['progress'], [kind for kind, _ in calls])

    def test_callback_copies_feedback_values(self):
        progress, _, calls = self._progress()
        values = {'opaque_future_value': None}
        progress(1, None, 'scanner.student.extra', {'student_id': 'shiroko', 'field': 'extra', 'values': values})
        values['opaque_future_value'] = 1
        self.assertIsNone(calls[1][1]['values']['opaque_future_value'])


if __name__ == '__main__':
    unittest.main()
