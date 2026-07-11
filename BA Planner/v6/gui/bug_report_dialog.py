"""Qt dialog for submitting privacy-scrubbed bug reports."""

from __future__ import annotations

from PySide6.QtCore import QObject, QRunnable, QThreadPool, QUrl, Signal
from PySide6.QtGui import QDesktopServices
from PySide6.QtWidgets import (
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPlainTextEdit,
    QVBoxLayout,
)

from core.bug_report import (
    BugReportClient,
    BugReportError,
    BugReportResult,
    build_diagnostic_text,
    build_report_body,
)


class _SubmitSignals(QObject):
    succeeded = Signal(object)
    failed = Signal(object)


class _SubmitTask(QRunnable):
    def __init__(self, client: BugReportClient, title: str, body: str) -> None:
        super().__init__()
        self.client = client
        self.title = title
        self.body = body
        self.signals = _SubmitSignals()

    def run(self) -> None:
        try:
            result = self.client.submit(self.title, self.body)
        except Exception as exc:
            self.signals.failed.emit(exc)
        else:
            self.signals.succeeded.emit(result)


class BugReportDialog(QDialog):
    def __init__(
        self,
        *,
        profile_name: str | None,
        recent_error: str | None = None,
        client: BugReportClient | None = None,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self._profile_name = profile_name
        self._client = client or BugReportClient()
        self._task: _SubmitTask | None = None

        self.setWindowTitle("문제 신고")
        self.setModal(True)
        self.resize(680, 620)

        layout = QVBoxLayout(self)
        intro = QLabel("문제의 제목과 재현 상황을 작성해 주세요. 진단정보는 전송 전에 수정하거나 삭제할 수 있습니다.")
        intro.setWordWrap(True)
        layout.addWidget(intro)

        form = QFormLayout()
        self.title_input = QLineEdit()
        self.title_input.setMaxLength(200)
        self.title_input.setPlaceholderText("문제를 한 문장으로 요약해 주세요")
        form.addRow("제목", self.title_input)

        self.description_input = QPlainTextEdit()
        self.description_input.setPlaceholderText("발생한 문제와 재현 절차를 자세히 적어 주세요")
        form.addRow("설명", self.description_input)

        self.diagnostic_input = QPlainTextEdit()
        self.diagnostic_input.setPlainText(
            build_diagnostic_text(profile_name=profile_name, recent_error=recent_error)
        )
        self.diagnostic_input.setPlaceholderText("함께 보낼 진단정보")
        form.addRow("진단정보", self.diagnostic_input)
        layout.addLayout(form, 1)

        self.status_label = QLabel("")
        self.status_label.setWordWrap(True)
        layout.addWidget(self.status_label)

        self.buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel
        )
        self.send_button = self.buttons.button(QDialogButtonBox.StandardButton.Save)
        self.send_button.setText("신고 전송")
        self.buttons.button(QDialogButtonBox.StandardButton.Cancel).setText("취소")
        self.buttons.accepted.connect(self._submit)
        self.buttons.rejected.connect(self.reject)
        layout.addWidget(self.buttons)

    def _submit(self) -> None:
        title = self.title_input.text().strip()
        description = self.description_input.toPlainText().strip()
        if not title:
            self.status_label.setText("제목을 입력해 주세요.")
            self.title_input.setFocus()
            return
        if not description:
            self.status_label.setText("설명을 입력해 주세요.")
            self.description_input.setFocus()
            return

        body = build_report_body(
            description,
            self.diagnostic_input.toPlainText(),
            profile_name=self._profile_name,
        )
        self._set_submitting(True)
        task = _SubmitTask(self._client, title, body)
        task.signals.succeeded.connect(self._on_success)
        task.signals.failed.connect(self._on_failure)
        self._task = task
        QThreadPool.globalInstance().start(task)

    def _set_submitting(self, active: bool) -> None:
        self.title_input.setEnabled(not active)
        self.description_input.setEnabled(not active)
        self.diagnostic_input.setEnabled(not active)
        self.send_button.setEnabled(not active)
        self.buttons.button(QDialogButtonBox.StandardButton.Cancel).setEnabled(not active)
        self.status_label.setText("문제 신고를 전송하고 있습니다…" if active else "")

    def _on_success(self, result: BugReportResult) -> None:
        self._task = None
        self._set_submitting(False)
        number = f"#{result.issue_number}" if result.issue_number is not None else ""
        message = QMessageBox(self)
        message.setWindowTitle("문제 신고 완료")
        message.setIcon(QMessageBox.Icon.Information)
        message.setText(f"문제 신고 {number}가 등록되었습니다.")
        message.setInformativeText("생성된 페이지를 브라우저에서 열 수 있습니다.")
        message.setStandardButtons(QMessageBox.StandardButton.Open | QMessageBox.StandardButton.Ok)
        message.button(QMessageBox.StandardButton.Open).setText("브라우저에서 열기")
        if message.exec() == QMessageBox.StandardButton.Open and result.issue_url:
            QDesktopServices.openUrl(QUrl(result.issue_url))
        self.accept()

    def _on_failure(self, failure: object) -> None:
        self._task = None
        self._set_submitting(False)
        if isinstance(failure, BugReportError):
            detail = str(failure)
            if failure.retry_after:
                detail += f"\n\n약 {failure.retry_after}초 후 다시 시도해 주세요."
            if failure.request_id:
                detail += f"\n\n요청 ID: {failure.request_id}"
        else:
            detail = "문제 신고를 전송하지 못했습니다. 잠시 후 다시 시도해 주세요."
        QMessageBox.warning(self, "문제 신고 실패", detail)
