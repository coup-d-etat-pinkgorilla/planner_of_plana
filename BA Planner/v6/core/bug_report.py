"""Privacy-safe bug report payload construction and Worker transport."""

from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import platform
import re
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from core.db import APP_VERSION


DEFAULT_BUG_REPORT_URL = "https://bug-report-worker.pyrosoda.workers.dev/report"
BUG_REPORT_URL_ENV = "BA_PLANNER_BUG_REPORT_URL"
MAX_TITLE_LENGTH = 200
MAX_BODY_LENGTH = 20_000
MAX_REQUEST_BYTES = 32 * 1024

_TOKEN_PATTERNS = (
    re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"),
    re.compile(r"(?i)\b(Bearer|token)\s+[A-Za-z0-9._~+\-/=]{12,}"),
    re.compile(r"(?im)^(\s*Authorization\s*:\s*).+$"),
    re.compile(r"(?im)^(\s*(?:api[_-]?key|access[_-]?token|secret)\s*[=:]\s*).+$"),
)
_EMAIL_PATTERN = re.compile(r"(?<![\w.+-])[\w.+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}(?![\w.-])")
_WINDOWS_USER_PATH = re.compile(r"(?i)\b([A-Z]:\\Users\\)[^\\\s/:*?\"<>|]+")


@dataclass(frozen=True)
class BugReportResult:
    issue_url: str
    issue_number: int | None
    request_id: str


class BugReportError(RuntimeError):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        status: int | None = None,
        request_id: str = "",
        retry_after: int | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.status = status
        self.request_id = request_id
        self.retry_after = retry_after


def redact_sensitive_text(
    text: str,
    *,
    home_path: str | Path | None = None,
    profile_name: str | None = None,
) -> str:
    """Remove known local identifiers and credential-like values from text."""

    result = str(text or "")
    resolved_home = str(home_path or Path.home()).rstrip("\\/")
    if resolved_home:
        result = re.sub(re.escape(resolved_home), "[REDACTED_HOME]", result, flags=re.IGNORECASE)
    result = _WINDOWS_USER_PATH.sub(r"\1[REDACTED_USER]", result)
    result = _EMAIL_PATTERN.sub("[REDACTED_EMAIL]", result)
    for pattern in _TOKEN_PATTERNS:
        if pattern.pattern.startswith("(?im)^("):
            result = pattern.sub(r"\1[REDACTED_SECRET]", result)
        else:
            result = pattern.sub("[REDACTED_SECRET]", result)
    normalized_profile = str(profile_name or "").strip()
    if normalized_profile:
        result = re.sub(
            re.escape(normalized_profile),
            "[REDACTED_PROFILE]",
            result,
            flags=re.IGNORECASE,
        )
    return result


def build_diagnostic_text(
    *,
    profile_name: str | None,
    recent_error: str | None = None,
) -> str:
    """Build an editable, already-redacted diagnostic summary."""

    details = [
        f"BA Planner version: {APP_VERSION}",
        f"Operating system: {platform.platform()}",
        f"Python version: {platform.python_version()}",
        f"Active profile: {profile_name or '(none)'}",
        f"Recent error: {recent_error or '(none)'}",
    ]
    return redact_sensitive_text("\n".join(details), profile_name=profile_name)


def build_report_body(
    description: str,
    diagnostic_text: str,
    *,
    profile_name: str | None = None,
) -> str:
    description = str(description or "").strip()
    diagnostic_text = str(diagnostic_text or "").strip()
    sections = [description]
    if diagnostic_text:
        sections.append(f"## Diagnostic information\n\n```text\n{diagnostic_text}\n```")
    return redact_sensitive_text("\n\n".join(sections), profile_name=profile_name)


def get_bug_report_url() -> str:
    return os.environ.get(BUG_REPORT_URL_ENV, DEFAULT_BUG_REPORT_URL).strip() or DEFAULT_BUG_REPORT_URL


class BugReportClient:
    def __init__(
        self,
        endpoint: str | None = None,
        *,
        timeout: float = 15.0,
        opener: Callable[..., object] = urlopen,
    ) -> None:
        self.endpoint = endpoint or get_bug_report_url()
        self.timeout = timeout
        self._opener = opener

    def submit(self, title: str, body: str) -> BugReportResult:
        title = str(title or "").strip()
        body = str(body or "").strip()
        if not title or len(title) > MAX_TITLE_LENGTH:
            raise BugReportError("INVALID_TITLE", f"제목은 1~{MAX_TITLE_LENGTH}자여야 합니다.")
        if not body or len(body) > MAX_BODY_LENGTH:
            raise BugReportError("INVALID_BODY", f"설명은 1~{MAX_BODY_LENGTH}자여야 합니다.")

        payload = json.dumps({"title": title, "body": body}, ensure_ascii=False).encode("utf-8")
        if len(payload) > MAX_REQUEST_BYTES:
            raise BugReportError(
                "PAYLOAD_TOO_LARGE",
                "제목과 설명을 합친 전송 크기는 32KiB 이하여야 합니다.",
            )
        request = Request(
            self.endpoint,
            data=payload,
            headers={
                "Content-Type": "application/json; charset=utf-8",
                "User-Agent": f"BA-Planner/{APP_VERSION}",
            },
            method="POST",
        )
        try:
            response = self._opener(request, timeout=self.timeout)
            with response:
                status = int(getattr(response, "status", 200))
                raw = response.read()
                headers = response.headers
        except HTTPError as exc:
            status = exc.code
            raw = exc.read()
            headers = exc.headers
        except (URLError, TimeoutError, OSError) as exc:
            raise BugReportError("NETWORK_ERROR", "문제 신고 서버에 연결하지 못했습니다.") from exc

        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise BugReportError("INVALID_RESPONSE", "문제 신고 서버가 잘못된 응답을 반환했습니다.", status=status) from exc

        request_id = str(decoded.get("requestId") or headers.get("X-Request-ID") or "")
        if status != 201:
            error = decoded.get("error") if isinstance(decoded, dict) else None
            code = str(error.get("code") or "REQUEST_FAILED") if isinstance(error, dict) else "REQUEST_FAILED"
            message = str(error.get("message") or "문제 신고를 전송하지 못했습니다.") if isinstance(error, dict) else "문제 신고를 전송하지 못했습니다."
            retry_value = headers.get("Retry-After")
            try:
                retry_after = int(retry_value) if retry_value is not None else None
            except (TypeError, ValueError):
                retry_after = None
            raise BugReportError(
                code,
                message,
                status=status,
                request_id=request_id,
                retry_after=retry_after,
            )

        return BugReportResult(
            issue_url=str(decoded.get("issueUrl") or ""),
            issue_number=int(decoded["issueNumber"]) if decoded.get("issueNumber") is not None else None,
            request_id=request_id,
        )
