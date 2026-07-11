from __future__ import annotations

import os
import unittest
from unittest.mock import Mock, patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtWidgets import QApplication

from core.bug_report import BugReportClient
from gui.bug_report_dialog import BugReportDialog


def _app() -> QApplication:
    return QApplication.instance() or QApplication([])


class BugReportDialogTests(unittest.TestCase):
    def setUp(self) -> None:
        _app()
        self.dialog = BugReportDialog(
            profile_name="PrivateProfile",
            client=BugReportClient("https://worker.example/report"),
        )

    def tearDown(self) -> None:
        self.dialog.close()

    def test_diagnostics_are_redacted_and_editable(self) -> None:
        diagnostics = self.dialog.diagnostic_input.toPlainText()
        self.assertIn("[REDACTED_PROFILE]", diagnostics)
        self.assertNotIn("PrivateProfile", diagnostics)
        self.assertFalse(self.dialog.diagnostic_input.isReadOnly())

    def test_requires_title_and_description(self) -> None:
        self.dialog._submit()
        self.assertEqual("제목을 입력해 주세요.", self.dialog.status_label.text())

        self.dialog.title_input.setText("Title")
        self.dialog._submit()
        self.assertEqual("설명을 입력해 주세요.", self.dialog.status_label.text())

    def test_submit_builds_redacted_payload_and_uses_background_pool(self) -> None:
        self.dialog.title_input.setText("Problem")
        self.dialog.description_input.setPlainText("Contact user@example.com in PrivateProfile")
        pool = Mock()

        with patch("gui.bug_report_dialog.QThreadPool.globalInstance", return_value=pool):
            self.dialog._submit()

        pool.start.assert_called_once()
        task = pool.start.call_args.args[0]
        self.assertEqual("Problem", task.title)
        self.assertIn("[REDACTED_EMAIL]", task.body)
        self.assertIn("[REDACTED_PROFILE]", task.body)
        self.assertNotIn("user@example.com", task.body)
        self.assertFalse(self.dialog.send_button.isEnabled())


if __name__ == "__main__":
    unittest.main()
