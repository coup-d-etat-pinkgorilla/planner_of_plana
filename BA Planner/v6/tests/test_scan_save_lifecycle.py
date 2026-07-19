from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import Mock

from main import App
from core.states import AppState


class ScanSaveLifecycleTests(unittest.TestCase):
    def test_auto_item_filter_cancel_closes_scanner_bridge(self) -> None:
        app = App.__new__(App)
        app._auto_scan_mode = "items"
        app._sm = SimpleNamespace(state=AppState.WATCHING)
        app._is_scanning = lambda: False
        app._is_stopping = lambda: False
        app._can_scan = lambda: True
        app._choose_item_scan_filter = lambda: None
        app._finish_shutdown = Mock()
        app._overlay = SimpleNamespace(add_log=lambda _message: None)

        app._request_scan("items")

        app._finish_shutdown.assert_called_once_with(reason="auto_scan_filter_cancelled")

    def test_scan_completion_waits_for_save_completion_callback(self) -> None:
        app = App.__new__(App)
        app._scanner = object()
        app._scan_thread = object()
        # The worker may already have exited while its UI completion callback is
        # still queued, so thread presence—not is_alive()—guards the lifecycle.
        app._save_thread = SimpleNamespace(is_alive=lambda: False)
        app._scan_worker_finished = False
        app._overlay = SimpleNamespace(reset_scan_progress=lambda: None)
        app._complete_scan_lifecycle = Mock()

        app._on_scan_finished()

        self.assertTrue(app._scan_worker_finished)
        self.assertIsNone(app._scanner)
        self.assertIsNone(app._scan_thread)
        app._complete_scan_lifecycle.assert_not_called()

    def test_successful_save_completion_resumes_scan_lifecycle(self) -> None:
        messages: list[str] = []
        app = App.__new__(App)
        app._save_thread = object()
        app._overlay = SimpleNamespace(add_log=messages.append)
        app._complete_scan_lifecycle = Mock()

        app._on_save_finished(True, "scan-1", ["summary"], "")

        self.assertIsNone(app._save_thread)
        self.assertEqual(messages, ["저장 완료 (scan-1)", "summary"])
        app._complete_scan_lifecycle.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
