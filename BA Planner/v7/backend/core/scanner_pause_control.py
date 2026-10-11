"""Cooperative FB-10a control; acknowledgements occur only outside active port steps."""
from __future__ import annotations

from contextlib import contextmanager
from threading import Condition, Event, local
from typing import Callable


class ScannerPauseControl:
    def __init__(self, lock, cancel: Event, emit: Callable) -> None:
        self._condition = Condition(lock)
        self._cancel = cancel
        self._emit = emit
        self._local = local()
        self._active = 0
        self.input_detected = Event()
        self.state = 'running'
        self.reason = None
        self.terminal = None

    def wire(self, accepted=False):
        with self._condition:
            return {'accepted': accepted, 'control_state': self.state,
                    'reason': self.reason, 'terminal': self.terminal}

    def pause(self, reason='user'):
        if reason not in {'user', 'input_detected', 'target_minimized'}:
            raise ValueError('invalid pause reason')
        with self._condition:
            accepted = self.state == 'running' and not self._cancel.is_set()
            if accepted:
                self.state, self.reason = 'pause_requested', reason
                self._condition.notify_all()
            return self.wire(accepted)

    def resume(self, ready: bool):
        with self._condition:
            accepted = self.state == 'paused' and ready and not self._cancel.is_set()
            if accepted:
                self.input_detected.clear()
                self.state, self.reason = 'running', None
                self._emit('resumed', {'reason': None})
                self._condition.notify_all()
            elif self.state == 'paused' and not ready:
                self.reason = 'target_minimized'
            return self.wire(accepted)

    def wake(self):
        with self._condition:
            self._condition.notify_all()

    def finish(self, outcome):
        with self._condition:
            self.state, self.reason, self.terminal = 'terminal', None, outcome
            self._condition.notify_all()

    def checkpoint(self):
        with self._condition:
            self._checkpoint_locked()

    def _checkpoint_locked(self):
        if self.input_detected.is_set() and self.state == 'running':
            self.pause('input_detected')
        # Nested capture/progress inside an already admitted input step must unwind
        # before acknowledging pause. Condition.wait releases the shared session lock.
        if getattr(self._local, 'depth', 0):
            return
        while not self._cancel.is_set() and self.state in {'pause_requested', 'paused'}:
            if self.state == 'pause_requested' and self._active == 0:
                self.state = 'paused'
                self._emit('paused', {'reason': self.reason})
                continue
            self._condition.wait()

    @contextmanager
    def operation(self):
        with self._condition:
            self._checkpoint_locked()
            self._active += 1
            self._local.depth = getattr(self._local, 'depth', 0) + 1
        try:
            yield
        finally:
            with self._condition:
                self._local.depth -= 1
                self._active -= 1
                self._condition.notify_all()

    @property
    def nested(self):
        return bool(getattr(self._local, 'depth', 0))


def controlled_call(target, call):
    """Pause on minimization; preserve already performed input without replaying it."""
    control = target.get('_scanner_control')
    if control is None or target.get('_scanner_cleanup', False):
        return call()
    from core.scanner_session import ScannerError
    while True:
        try:
            with control.operation():
                result = call()
            control.checkpoint()
            return result
        except ScannerError as exc:
            reason = {'input_busy': 'input_detected', 'target_minimized': 'target_minimized'}.get(exc.code)
            if reason is None:
                raise
            control.pause(reason)
            # A nested native capture may fail while its outer input lease is still
            # held. Let that outer boundary handle the error after releasing it.
            if control.nested:
                raise
            control.checkpoint()
            cancel = target.get('_scanner_cancel')
            if cancel is not None and cancel.is_set():
                raise ScannerError('cancelled', 'paused scanner operation cancelled') from exc
            if exc.details.get('performed'):
                # Existing recovery observes the screen before deciding what to do.
                # The operation must never be blindly repeated by this boundary.
                raise
