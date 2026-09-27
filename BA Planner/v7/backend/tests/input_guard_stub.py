"""No-op D21 input guard for adapter unit tests.

The real ``UserInputGuard`` hooks the live mouse and keyboard, so a test that drives a mocked
``WindowsCaptureInputAdapter`` would fail as ``input_busy`` whenever someone uses the PC. The guard
itself is covered by ``test_user_input_guard_d21``.
"""
from contextlib import nullcontext
from unittest.mock import patch


class NoInputGuard:
    available = False

    def step(self, cancel=None):
        return nullcontext()

    def stop(self):
        pass


def patch_input_guard():
    """Patcher replacing the adapter's guard class; start it in ``setUpModule``."""
    return patch("core.windows_scanner_adapter.UserInputGuard", NoInputGuard)
