from __future__ import annotations

from concurrent.futures import Future
from contextlib import contextmanager
from copy import deepcopy
import json
from pathlib import Path
from queue import Queue
import subprocess
import sys
import tempfile
from threading import Event, Thread
from time import monotonic
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator

from core.scan_context import ScanContext
from core.scanner_protocol_v1 import ScannerProtocolV1
from core.scanner_session import ScannerError, ScannerSessionService, ScannerEventCursor
from core.user_input_guard import UserInputGuard
from core.windows_scanner_adapter import _controlled, _guarded
from test_scanner_session import FakeRepository, STUDENT

ROOT = Path(__file__).resolve().parents[2]


class DeferredExecutor:
    def submit(self, fn, *args):
        self.future = Future()
        def run():
            try:
                fn(*args)
                self.future.set_result(None)
            except BaseException as exc:
                self.future.set_exception(exc)
        self.thread = Thread(target=run)
        return self.future


class PauseTests(unittest.TestCase):
    def make(self, matcher, executor=None):
        self.events = []
        self.paused = Event()
        self.targets = [{'target_id': 'w1', 'title': 'Blue Archive', 'status': 'ready'}]
        def sink(message):
            self.events.append(message)
            if message['payload']['event_kind'] == 'paused':
                self.paused.set()
        service = ScannerSessionService(
            target_provider=lambda: deepcopy(self.targets), student_matcher=matcher,
            inventory_matcher=matcher, repository=FakeRepository(),
            asset_status=lambda: {'ready': True, 'manifest_version': 1, 'missing': []},
            event_sink=sink, executor=executor,
        )
        self.service = service
        self.addCleanup(service.close)
        started = service.start('student', 'w1')
        self.ref = (started['session_id'], started['generation'])
        return service

    def snap(self):
        return self.service.snapshot(*self.ref)

    def test_pause_before_worker_start_is_acknowledged_before_matcher(self):
        entered = Event(); executor = DeferredExecutor()
        service = self.make(lambda *args: (entered.set(), [])[1], executor)
        self.assertTrue(service.pause(*self.ref)['accepted'])
        self.assertFalse(service.resume(*self.ref)['accepted'])
        executor.thread.start()
        self.assertTrue(self.paused.wait(2))
        self.assertFalse(entered.is_set())
        self.assertEqual('paused', self.snap()['control_state'])
        self.assertTrue(service.resume(*self.ref)['accepted'])
        service.wait(self.ref[0]); executor.thread.join(2)
        self.assertTrue(entered.is_set())
        self.assertEqual('terminal', self.snap()['control_state'])

    def test_mid_capture_finishes_before_ack_and_blocks_next_input_and_candidate(self):
        entered = Event(); release = Event(); input_started = Event()
        class Ports:
            @_controlled
            def capture(self, target):
                entered.set(); release.wait(2)
            @_controlled
            def click(self, target):
                input_started.set()
        ports = Ports()
        def matcher(target, cancel, progress):
            ports.capture(target); ports.click(target)
            return [{'payload': deepcopy(STUDENT), 'evidence': []}]
        service = self.make(matcher)
        self.addCleanup(release.set)
        self.assertTrue(entered.wait(2))
        self.assertEqual('pause_requested', service.pause(*self.ref)['control_state'])
        self.assertFalse(self.paused.is_set())
        release.set(); self.assertTrue(self.paused.wait(2))
        self.assertFalse(input_started.is_set())
        self.assertEqual([], self.snap()['candidates'])
        service.resume(*self.ref); service.wait(self.ref[0])
        self.assertTrue(input_started.is_set())
        self.assertEqual(1, len(self.snap()['candidates']))

    def checkpoint_service(self):
        entered = Event(); release = Event()
        def matcher(target, cancel, progress):
            entered.set(); release.wait(2); progress(1, 2, 'fixture')
            return []
        service = self.make(matcher)
        self.addCleanup(release.set)
        self.assertTrue(entered.wait(2))
        service.pause(*self.ref); release.set(); self.assertTrue(self.paused.wait(2))
        return service

    def test_duplicate_pause_resume_do_not_emit_duplicate_transitions(self):
        service = self.checkpoint_service()
        self.assertFalse(service.pause(*self.ref)['accepted'])
        self.assertTrue(service.resume(*self.ref)['accepted'])
        self.assertFalse(service.resume(*self.ref)['accepted'])
        service.wait(self.ref[0])
        kinds = [e['payload']['event_kind'] for e in self.events]
        self.assertEqual(1, kinds.count('paused')); self.assertEqual(1, kinds.count('resumed'))

    def test_minimized_resume_remains_paused_and_requires_another_user_request(self):
        service = self.checkpoint_service()
        self.targets[0]['status'] = 'minimized'
        self.assertEqual({'accepted': False, 'control_state': 'paused', 'reason': 'target_minimized', 'terminal': None}, service.resume(*self.ref))
        self.targets[0]['status'] = 'ready'
        self.assertEqual('paused', self.snap()['control_state'])
        self.assertTrue(service.resume(*self.ref)['accepted'])
        service.wait(self.ref[0])

    def test_missing_target_resume_does_not_use_stale_start_status(self):
        service = self.checkpoint_service(); self.targets.clear()
        self.assertFalse(service.resume(*self.ref)['accepted'])
        self.assertEqual('target_minimized', self.snap()['reason'])

    def test_cancel_wakes_paused_worker_and_emits_one_terminal(self):
        service = self.checkpoint_service(); service.cancel(*self.ref); service.wait(self.ref[0])
        self.assertEqual('cancelled', self.snap()['terminal'])
        self.assertEqual(1, sum(e['payload']['event_kind'] == 'terminal' for e in self.events))
        self.assertEqual('terminal', service.pause(*self.ref)['control_state'])
        self.assertFalse(service.resume(*self.ref)['accepted'])

    def test_close_wakes_paused_worker(self):
        service = self.checkpoint_service()
        done = Event()
        closer = Thread(target=lambda: (service.close(), done.set()))
        closer.start(); self.assertTrue(done.wait(2)); closer.join(2)
        self.assertEqual('cancelled', self.snap()['terminal'])

    def test_old_generation_and_unknown_session_use_existing_errors(self):
        service = self.checkpoint_service()
        for call in (service.pause, service.resume):
            for ref, code in [((self.ref[0], 99), 'stale_generation'), (('unknown', 1), 'session_not_found')]:
                with self.assertRaises(ScannerError) as caught: call(*ref)
                self.assertEqual(code, caught.exception.code)

    def test_pause_snapshot_gap_preserves_strict_sequence(self):
        service = self.checkpoint_service(); snapshot = self.snap()
        self.assertEqual('user', snapshot['reason'])
        self.assertEqual('paused', snapshot['events'][-1]['payload']['event_kind'])
        cursor = ScannerEventCursor(*self.ref)
        self.assertEqual('snapshot_required', cursor.consume(snapshot['events'][-1]))
        for event in snapshot['events']:
            self.assertEqual('accepted', cursor.consume(event))
        self.assertEqual('duplicate_or_out_of_order', cursor.consume(snapshot['events'][-1]))
        service.resume(*self.ref); service.wait(self.ref[0])
        seq = [e['payload']['sequence'] for e in self.snap()['events']]
        self.assertEqual(list(range(1, len(seq) + 1)), seq)

    def test_input_detected_waits_for_explicit_resume_before_unsent_input(self):
        sent = Event()
        class Guard:
            calls = 0
            def step(self, cancel, *, pause_on_input=False, input_detected=None):
                self.calls += 1
                if self.calls == 1:
                    raise ScannerError('input_busy', 'fixture', details={'performed': False})
                @contextmanager
                def quiet(): yield
                return quiet()
        class Ports:
            _guard = Guard()
            @_guarded
            def click(self, target): sent.set()
        ports = Ports()
        service = self.make(lambda target, *args: (ports.click(target), [])[1])
        self.assertTrue(self.paused.wait(2)); self.assertEqual('input_detected', self.snap()['reason'])
        self.assertFalse(sent.wait(.05)); self.assertEqual(1, ports._guard.calls)
        service.resume(*self.ref); service.wait(self.ref[0]); self.assertTrue(sent.is_set())

    def test_performed_input_is_not_repeated_and_keeps_return_value(self):
        returned = []; calls = []
        class Guard:
            @contextmanager
            def step(self, cancel, *, pause_on_input=False, input_detected=None):
                yield
                raise ScannerError('input_busy', 'fixture', details={'performed': True})
        class Ports:
            _guard = Guard()
            @_guarded
            def press_key(self, target): calls.append('sent'); return True
        ports = Ports()
        service = self.make(lambda target, *args: (returned.append(ports.press_key(target)), [])[1])
        self.assertTrue(self.paused.wait(2)); self.assertEqual([], returned)
        service.resume(*self.ref); service.wait(self.ref[0])
        self.assertEqual(['sent'], calls); self.assertEqual([True], returned)

    def test_nested_capture_minimization_unwinds_input_lease_before_pausing(self):
        attempts = []
        class Ports:
            @_controlled
            def capture(self, target):
                attempts.append('capture')
                if len(attempts) == 1: raise ScannerError('target_minimized', 'fixture')
            @_controlled
            def input(self, target): self.capture(target)
        ports = Ports()
        service = self.make(lambda target, *args: (ports.input(target), [])[1])
        self.assertTrue(self.paused.wait(2)); self.assertEqual('target_minimized', self.snap()['reason'])
        service.resume(*self.ref); service.wait(self.ref[0]); self.assertEqual(2, len(attempts))

    def test_signal_between_steps_is_not_automatically_cleared_by_time(self):
        proceeded = Event()
        def matcher(target, cancel, progress):
            target.control.input_detected.set()
            target.control.checkpoint()
            proceeded.set()
            return []
        service = self.make(matcher)
        self.assertTrue(self.paused.wait(2)); self.assertEqual('input_detected', self.snap()['reason'])
        self.assertFalse(proceeded.wait(.05))
        service.resume(*self.ref); service.wait(self.ref[0]); self.assertTrue(proceeded.is_set())

    def test_synchronous_cancel_on_paused_event_cannot_lose_wakeup(self):
        service = self.checkpoint_service()
        service.resume(*self.ref); service.wait(self.ref[0])
        # Exercise the condition transition with a sink that cancels inline.
        from core.scanner_pause_control import ScannerPauseControl
        from threading import RLock
        cancel = Event()
        control = ScannerPauseControl(RLock(), cancel, lambda *args: (cancel.set(), control.wake()))
        control.pause(); done = Event()
        thread = Thread(target=lambda: (control.checkpoint(), done.set()))
        thread.start(); self.assertTrue(done.wait(2)); thread.join(2)


class PauseContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.validator = Draft202012Validator(json.loads((ROOT / 'contracts/scanner-protocol-v1.schema.json').read_text(encoding='utf-8')))

    def test_positive_and_negative_fixture(self):
        fixture = json.loads((ROOT / 'contracts/fixtures/scanner_pause_fb10a_v1.json').read_text(encoding='utf-8'))
        self.assertEqual(41, len(fixture['cases']))
        for case in fixture['cases']:
            with self.subTest(case=case['name']):
                self.assertEqual(case['valid'], self.validator.is_valid(case['message']))

    def test_guard_pause_mode_does_not_wait_until_user_becomes_idle(self):
        guard = UserInputGuard(); guard.start = lambda: True; guard.available = True
        guard.last_input = monotonic()
        with patch.object(guard, 'wait_idle') as wait, self.assertRaises(ScannerError) as caught:
            guard.step(pause_on_input=True)
        self.assertFalse(caught.exception.details['performed']); wait.assert_not_called()

    def test_quiet_pause_guard_also_skips_idle_wait(self):
        guard = UserInputGuard(); guard.start = lambda: True; guard.available = True
        with patch.object(guard, 'wait_idle') as wait:
            with guard.step(pause_on_input=True): pass
        wait.assert_not_called()

    def test_input_between_guard_creation_and_admission_is_not_missed(self):
        guard = UserInputGuard(); guard.start = lambda: True; guard.available = True
        signal = Event(); step = guard.step(pause_on_input=True, input_detected=signal)
        guard._note(); self.assertTrue(signal.is_set())
        with self.assertRaises(ScannerError) as caught:
            with step: self.fail('no input may be sent')
        self.assertFalse(caught.exception.details['performed'])

    def test_explicit_resume_consumes_recent_button_input_but_not_new_input(self):
        guard = UserInputGuard(); guard.start = lambda: True; guard.available = True
        signal = Event(); guard._pause_signal = signal
        guard._note()  # the user's resume-button click arrived before the RPC
        self.assertTrue(signal.is_set())
        signal.clear()  # ScannerPauseControl.resume consumes that input
        with guard.step(pause_on_input=True, input_detected=signal): pass
        guard._note()  # a later input must still prevent a scanner step
        with self.assertRaises(ScannerError) as caught:
            guard.step(pause_on_input=True, input_detected=signal)
        self.assertFalse(caught.exception.details['performed'])

    def test_explicit_start_consumes_earlier_click_even_when_hooks_are_still_active(self):
        guard = UserInputGuard(); guard.start = lambda: True; guard.available = True
        guard._note()  # previous control still owns the idle hook
        signal = Event()  # the new scanner control starts after the command
        with guard.step(pause_on_input=True, input_detected=signal): pass

    def test_native_cleanup_uses_existing_guard_without_awaiting_resume(self):
        modes = []
        class Guard:
            @contextmanager
            def step(self, cancel, *, pause_on_input=False, input_detected=None):
                modes.append(pause_on_input)
                yield
        class Ports:
            _guard = Guard()
            @_guarded
            def escape(self, target): return True
        # Cleanup may release a held key/modal after cancel; it must not wait on
        # the session pause that cancellation is unwinding.
        self.assertTrue(Ports().escape({'_scanner_control': object(), '_scanner_cleanup': True}))
        self.assertEqual([False], modes)

    def test_context_keeps_control_through_typed_replacements(self):
        control = object()
        context = ScanContext.of({'target_id': 'w1'}).replace(control=control, generation=1)
        self.assertIs(control, context.replace(cleanup=True).control)
        self.assertIs(control, ScanContext.of(dict(context)).control)

    def test_real_jsonl_process_pause_snapshot_resume_cancel(self):
        script = '''import sys
from threading import Event
from core.application_protocol_v1 import ApplicationProtocolV1
from core.scanner_session import ScannerSessionService
from core.repository_store import JsonRepository
from core.stdio_server import serve
from pathlib import Path
root=Path(sys.argv[1])
def matcher(target,cancel,progress):
    while not cancel.is_set():
        progress(0,None,'fixture')
        cancel.wait(.02)
    return []
service=ScannerSessionService(target_provider=lambda:[{'target_id':'w1','title':'fixture','status':'ready'}],student_matcher=matcher,inventory_matcher=matcher,repository=JsonRepository(root),asset_status=lambda:{'ready':True,'manifest_version':1,'missing':[]})
serve(protocol=ApplicationProtocolV1(storage_root=root,scanner_service=service))
'''
        with tempfile.TemporaryDirectory() as temp:
            process = subprocess.Popen([sys.executable, '-u', '-c', script, temp], cwd=ROOT / 'backend', stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8')
            rows = Queue(); observed = []
            reader = Thread(target=lambda: [rows.put(json.loads(line)) for line in process.stdout], daemon=True)
            reader.start()
            def send(method, payload, ident):
                process.stdin.write(json.dumps({'protocol': 1, 'type': 'request', 'id': ident, 'method': method, 'payload': payload}) + '\n'); process.stdin.flush()
            def until(predicate):
                deadline = monotonic() + 8
                while True:
                    row = rows.get(timeout=max(.01, deadline - monotonic())); observed.append(row)
                    self.validator.validate(row)
                    if predicate(row): return row
            try:
                send('scanner.session.start', {'scan_kind': 'student', 'target_id': 'w1'}, 'start')
                start = until(lambda r: r.get('id') == 'start')['payload']
                ref = {k: start[k] for k in ('session_id', 'generation')}
                send('scanner.session.pause', ref, 'pause')
                got_response = got_event = False
                while not (got_response and got_event):
                    row = until(lambda r: r.get('id') == 'pause' or r['payload'].get('event_kind') == 'paused')
                    got_response |= row.get('id') == 'pause'; got_event |= row['payload'].get('event_kind') == 'paused'
                send('scanner.session.snapshot', ref, 'snapshot')
                snap = until(lambda r: r.get('id') == 'snapshot')['payload']
                self.assertEqual('paused', snap['control_state'])
                send('scanner.session.resume', ref, 'resume')
                self.assertTrue(until(lambda r: r.get('id') == 'resume')['payload']['accepted'])
                send('scanner.session.cancel', ref, 'cancel')
                terminal = until(lambda r: r['payload'].get('event_kind') == 'terminal')
                self.assertEqual('cancelled', terminal['payload']['outcome'])
                process.stdin.close(); self.assertEqual(0, process.wait(timeout=8)); reader.join(2)
                self.assertEqual('', process.stderr.read())
            finally:
                if process.poll() is None: process.kill(); process.wait(timeout=3)
                process.stdout.close(); process.stderr.close()


if __name__ == '__main__':
    unittest.main()
