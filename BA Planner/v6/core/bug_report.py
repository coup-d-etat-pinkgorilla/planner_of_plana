"""Privacy-safe bug report payload construction and Worker transport."""

from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import platform
import re
import sqlite3
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from core.db import APP_VERSION
from core.config import APP_DIR, BASE_DIR, get_storage_paths


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
_LOG_RECORD_START = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:,\d+)?\s+")
_ERROR_LEVEL = re.compile(r"^\d{4}-\d{2}-\d{2} .*?\s+(?:ERROR|CRITICAL)\s+")
_FALLBACK_MARKER = re.compile(r"fallback|폴백", re.IGNORECASE)
_CAPTURE_SOURCE_SIZE = re.compile(r"\bsource_size=(\d+)x(\d+)\b")


@dataclass(frozen=True)
class BugReportResult:
    issue_url: str
    issue_number: int | None
    request_id: str
    diagnostics_uploaded: bool = True
    warning: str = ""


@dataclass(frozen=True)
class RecentLogDiagnostics:
    scan_resolution: str
    relevant_records: str
    source_files: tuple[str, ...]


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
    scan_resolution: str | None = None,
) -> str:
    """Build an editable, already-redacted diagnostic summary."""

    details = [
        f"BA Planner version: {APP_VERSION}",
        f"Operating system: {platform.platform()}",
        f"Python version: {platform.python_version()}",
        f"Active profile: {profile_name or '(none)'}",
        f"Scan resolution: {scan_resolution or 'unknown'}",
        "Relevant recent log records:",
        recent_error or "(none)",
    ]
    return redact_sensitive_text("\n".join(details), profile_name=profile_name)


def _latest_matching_file(log_dirs: list[Path], pattern: str) -> Path | None:
    candidates = [
        path
        for log_dir in log_dirs
        for path in log_dir.glob(pattern)
        if path.is_file()
    ]
    if not candidates:
        return None
    timestamps: list[tuple[int, str, Path]] = []
    for path in candidates:
        try:
            timestamps.append((path.stat().st_mtime_ns, path.name, path))
        except OSError:
            continue
    return max(timestamps, key=lambda item: (item[0], item[1]))[2] if timestamps else None


def _iter_log_records(path: Path):
    current: list[str] = []
    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\r\n")
            if _LOG_RECORD_START.match(line) and current:
                yield "\n".join(current)
                current = [line]
            else:
                current.append(line)
    if current:
        yield "\n".join(current)


def _relevant_records(path: Path) -> list[str]:
    selected: list[str] = []
    for record in _iter_log_records(path):
        if _ERROR_LEVEL.match(record) or _FALLBACK_MARKER.search(record):
            selected.append(record)
    return selected


def _resolution_from_scan_log(path: Path | None) -> str | None:
    if path is None:
        return None
    latest: tuple[str, str] | None = None
    try:
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                match = _CAPTURE_SOURCE_SIZE.search(line)
                if match:
                    latest = (match.group(1), match.group(2))
    except (OSError, UnicodeError):
        return None
    return f"{latest[0]}x{latest[1]}" if latest else None


def _resolution_from_database(path: Path) -> str | None:
    if not path.is_file():
        return None
    try:
        connection = sqlite3.connect(f"file:{path.resolve().as_posix()}?mode=ro", uri=True)
    except sqlite3.Error:
        return None
    try:
        row = connection.execute(
            """
            SELECT window_w, window_h
            FROM scans
            WHERE window_w IS NOT NULL AND window_h IS NOT NULL
            ORDER BY scanned_at DESC, scan_id DESC
            LIMIT 1
            """
        ).fetchone()
    except sqlite3.Error:
        return None
    finally:
        connection.close()
    if not row:
        return None
    return f"{int(row[0])}x{int(row[1])}"


def collect_recent_log_diagnostics(
    *,
    log_dir: str | Path | None = None,
    db_path: str | Path | None = None,
) -> RecentLogDiagnostics:
    """Collect complete recent error/fallback records without truncation."""

    if log_dir is not None:
        log_dirs = [Path(log_dir)]
    else:
        log_dirs = list(dict.fromkeys((APP_DIR / "logs", BASE_DIR / "logs")))
    app_log = _latest_matching_file(log_dirs, "ba_*.log")
    scan_log = _latest_matching_file(log_dirs, "scan_*.log")
    paths = [path for path in (app_log, scan_log) if path is not None]

    sections: list[str] = []
    seen_records: set[str] = set()
    for path in paths:
        try:
            records = [
                record
                for record in _relevant_records(path)
                if record not in seen_records
            ]
        except (OSError, UnicodeError) as exc:
            sections.append(f"--- {path.name} ---\n[log extraction failed: {type(exc).__name__}]")
            continue
        if records:
            sections.append(f"--- {path.name} ---\n" + "\n\n".join(records))
            seen_records.update(records)

    resolution = _resolution_from_scan_log(scan_log)
    if resolution is None:
        resolved_db_path = Path(db_path) if db_path is not None else get_storage_paths().db_path
        resolution = _resolution_from_database(resolved_db_path)

    return RecentLogDiagnostics(
        scan_resolution=resolution or "unknown",
        relevant_records="\n\n".join(sections) or "(none)",
        source_files=tuple(path.name for path in paths),
    )


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


def _records_from_text(text: str) -> list[str]:
    records: list[str] = []
    current: list[str] = []
    for line in str(text or "").splitlines():
        if _LOG_RECORD_START.match(line):
            if current and _LOG_RECORD_START.match(current[0]):
                records.append("\n".join(current))
            current = [line]
        elif current:
            current.append(line)
    if current and _LOG_RECORD_START.match(current[0]):
        records.append("\n".join(current))
    return records


def _record_message(record: str) -> str:
    first_line = record.splitlines()[0] if record else ""
    match = re.match(
        r"^\S+\s+\S+\s+\S+\s+\[[^]]+\]\s+\[([^]]+)\]\s+(.*)$",
        first_line,
    )
    if match:
        return f"[{match.group(1)}] {match.group(2)}"
    return first_line


def _error_fingerprint(record: str) -> str:
    lines = [line.strip() for line in record.splitlines() if line.strip()]
    exception_line = next(
        (
            line
            for line in reversed(lines)
            if re.match(r"^[A-Za-z_][\w.]*?(?:Error|Exception)(?::|$)", line)
        ),
        "",
    )
    frame_line = next(
        (line for line in reversed(lines) if line.startswith('File "')),
        "",
    )
    parts = [part for part in (exception_line, frame_line, _record_message(record)) if part]
    return " | ".join(parts[:2] if exception_line else parts[:1])


def _fallback_fingerprint(record: str) -> str:
    message = _record_message(record)
    marker = re.search(r"[A-Za-z0-9_.:-]*fallback[A-Za-z0-9_.:-]*|폴백", message, re.IGNORECASE)
    if marker:
        logger = message.split("]", 1)[0] + "]" if message.startswith("[") else ""
        return f"{logger} {marker.group(0)}".strip()
    return message


def _record_timestamp(record: str) -> str:
    match = re.match(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:,\d+)?)", record)
    return match.group(1) if match else "unknown"


def _new_summary_group(timestamp: str) -> dict[str, object]:
    return {
        "count": 0,
        "first": timestamp,
        "last": timestamp,
        "scores": [],
        "fields": set(),
        "reasons": set(),
    }


def _update_summary_group(group: dict[str, object], record: str) -> None:
    group["count"] = int(group["count"]) + 1
    timestamp = _record_timestamp(record)
    if group["first"] == "unknown" and timestamp != "unknown":
        group["first"] = timestamp
    group["last"] = timestamp
    scores = group["scores"]
    fields = group["fields"]
    reasons = group["reasons"]
    assert isinstance(scores, list)
    assert isinstance(fields, set)
    assert isinstance(reasons, set)
    scores.extend(
        float(value)
        for value in re.findall(r"\b(?:score|margin)=(-?\d+(?:\.\d+)?)", record)
    )
    fields.update(re.findall(r"\bfield=([^\s,]+)", record))
    reasons.update(re.findall(r"\breason=([^\s,]+)", record))


def _format_summary_group(group: dict[str, object], *, fallback: bool) -> str:
    parts = [
        f"count={group['count']}",
        f"first={group['first']}",
        f"last={group['last']}",
    ]
    if fallback:
        scores = group["scores"]
        fields = group["fields"]
        reasons = group["reasons"]
        assert isinstance(scores, list)
        assert isinstance(fields, set)
        assert isinstance(reasons, set)
        if scores:
            parts.append(f"score_range={min(scores):.3f}..{max(scores):.3f}")
        if fields:
            parts.append(f"fields={','.join(sorted(fields))}")
        if reasons:
            parts.append(f"reasons={','.join(sorted(reasons))}")
    return ", ".join(parts)


def build_diagnostic_summary(diagnostic_text: str) -> str:
    """Create a deterministic compact summary from the editable diagnostics."""

    text = str(diagnostic_text or "")
    metadata_prefixes = (
        "BA Planner version:",
        "Operating system:",
        "Python version:",
        "Scan resolution:",
    )
    metadata = [
        line.strip()
        for line in text.splitlines()
        if line.strip().startswith(metadata_prefixes)
    ]
    if not any(line.startswith("Scan resolution:") for line in metadata):
        metadata.append("Scan resolution: unknown")

    error_groups: dict[str, dict[str, object]] = {}
    fallback_groups: dict[str, dict[str, object]] = {}
    for record in _records_from_text(text):
        if _ERROR_LEVEL.match(record):
            fingerprint = _error_fingerprint(record) or "unclassified error"
            group = error_groups.setdefault(
                fingerprint,
                _new_summary_group(_record_timestamp(record)),
            )
            _update_summary_group(group, record)
        if _FALLBACK_MARKER.search(record):
            fingerprint = _fallback_fingerprint(record) or "unclassified fallback"
            group = fallback_groups.setdefault(
                fingerprint,
                _new_summary_group(_record_timestamp(record)),
            )
            _update_summary_group(group, record)

    lines = ["## Diagnostic summary", *metadata]
    lines.append(f"Errors: {sum(int(group['count']) for group in error_groups.values())}")
    lines.extend(
        f"- {fingerprint} ({_format_summary_group(group, fallback=False)})"
        for fingerprint, group in error_groups.items()
    )
    lines.append(f"Fallbacks: {sum(int(group['count']) for group in fallback_groups.values())}")
    lines.extend(
        f"- {fingerprint} ({_format_summary_group(group, fallback=True)})"
        for fingerprint, group in fallback_groups.items()
    )
    return "\n".join(lines)


def build_summary_report_body(
    description: str,
    diagnostic_summary: str,
    *,
    profile_name: str | None = None,
) -> str:
    sections = [str(description or "").strip(), str(diagnostic_summary or "").strip()]
    return redact_sensitive_text(
        "\n\n".join(section for section in sections if section),
        profile_name=profile_name,
    )


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

    def submit(
        self,
        title: str,
        body: str,
        *,
        diagnostic_records: tuple[str, ...] | list[str] = (),
    ) -> BugReportResult:
        title = str(title or "").strip()
        body = str(body or "").strip()
        if not title or len(title) > MAX_TITLE_LENGTH:
            raise BugReportError("INVALID_TITLE", f"제목은 1~{MAX_TITLE_LENGTH}자여야 합니다.")
        if not body:
            raise BugReportError("INVALID_BODY", "설명을 입력해 주세요.")
        if len(body) > MAX_BODY_LENGTH:
            raise BugReportError(
                "PAYLOAD_TOO_LARGE",
                "오류 로그를 자동으로 자르지 않았습니다. 진단정보가 서버 한도를 넘으므로 내용을 직접 검토해 주세요.",
            )

        records = [str(record).strip() for record in diagnostic_records if str(record).strip()]
        payload_data: dict[str, object] = {"title": title, "body": body}
        if records:
            payload_data["diagnosticRecords"] = records
        payload = json.dumps(payload_data, ensure_ascii=False).encode("utf-8")
        if len(payload) > MAX_REQUEST_BYTES:
            raise BugReportError(
                "PAYLOAD_TOO_LARGE",
                "오류 로그를 자동으로 자르지 않았습니다. 전체 전송 크기가 32KiB를 넘으므로 진단정보를 직접 검토해 주세요.",
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
            diagnostics_uploaded=bool(decoded.get("diagnosticsUploaded", True)),
            warning=str(decoded.get("warning") or ""),
        )
