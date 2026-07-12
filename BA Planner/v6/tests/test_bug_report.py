from __future__ import annotations

import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

from core.bug_report import (
    BugReportClient,
    BugReportError,
    build_diagnostic_text,
    build_diagnostic_summary,
    build_report_body,
    build_summary_report_body,
    collect_recent_log_diagnostics,
    get_bug_report_url,
    redact_sensitive_text,
)


class _Response:
    def __init__(self, status: int, payload: dict, headers: dict | None = None):
        self.status = status
        self._body = json.dumps(payload).encode("utf-8")
        self.headers = headers or {}

    def read(self) -> bytes:
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


class BugReportRedactionTests(unittest.TestCase):
    def test_redacts_local_identifiers_and_credentials(self):
        source = "\n".join(
            [
                r"C:\Users\Alice\planner\logs\app.log",
                "alice@example.com",
                "Authorization: Bearer abcdefghijklmnopqrstuvwxyz",
                "github_pat_abcdefghijklmnopqrstuvwxyz0123456789",
                "api_key=abcdefghijklmnop",
                "Profile: MainAccount",
            ]
        )

        result = redact_sensitive_text(
            source,
            home_path=Path(r"C:\Users\Alice"),
            profile_name="MainAccount",
        )

        self.assertNotIn("Alice", result)
        self.assertNotIn("alice@example.com", result)
        self.assertNotIn("abcdefghijklmnopqrstuvwxyz", result)
        self.assertNotIn("MainAccount", result)
        self.assertIn("[REDACTED_HOME]", result)
        self.assertIn("[REDACTED_EMAIL]", result)
        self.assertIn("[REDACTED_SECRET]", result)
        self.assertIn("[REDACTED_PROFILE]", result)


class RecentLogDiagnosticsTests(unittest.TestCase):
    def test_does_not_truncate_large_error_record(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            detail = "x" * 40_000
            complete_record = (
                "2026-07-12 01:00:01  ERROR  [MainThread] [ba.app] failure\n"
                f"RuntimeError: {detail}"
            )
            (root / "ba_2026-07-12.log").write_text(complete_record, encoding="utf-8")

            result = collect_recent_log_diagnostics(log_dir=root, db_path=root / "missing.db")

        self.assertIn(complete_record, result.relevant_records)
        self.assertEqual(40_000, result.relevant_records.count("x"))

    def test_reports_log_read_failure_instead_of_hiding_it(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            (root / "ba_2026-07-12.log").write_text("record", encoding="utf-8")
            with patch("core.bug_report._relevant_records", side_effect=OSError("locked")):
                result = collect_recent_log_diagnostics(log_dir=root, db_path=root / "missing.db")

        self.assertIn("[log extraction failed: OSError]", result.relevant_records)

    def test_collects_complete_error_traceback_and_fallback_records(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            (root / "ba_2026-07-12.log").write_text(
                "\n".join(
                    [
                        "2026-07-12 01:00:00  INFO   [MainThread] [ba.app] normal",
                        "2026-07-12 01:00:01  ERROR  [MainThread] [ba.app] scan failed",
                        "Traceback (most recent call last):",
                        '  File "main.py", line 1, in run',
                        "RuntimeError: complete failure detail",
                        "2026-07-12 01:00:02  INFO   [MainThread] [ba.app] done",
                    ]
                ),
                encoding="utf-8",
            )
            (root / "scan_20260712_students_id.log").write_text(
                "\n".join(
                    [
                        "2026-07-12 01:00:00  DEBUG  [ScanThread] [ba.scanner] "
                        "[perf] capture success=true source_size=1920x1080 normalized_size=2560x1440",
                        "2026-07-12 01:00:01  DEBUG  [ScanThread] [ba.matcher] "
                        "texture_topk_fallback: sid=test score=0.9",
                    ]
                ),
                encoding="utf-8",
            )

            result = collect_recent_log_diagnostics(log_dir=root, db_path=root / "missing.db")

        self.assertEqual("1920x1080", result.scan_resolution)
        self.assertIn("Traceback (most recent call last):", result.relevant_records)
        self.assertIn("RuntimeError: complete failure detail", result.relevant_records)
        self.assertIn("texture_topk_fallback", result.relevant_records)
        self.assertNotIn("normal", result.relevant_records)
        self.assertNotIn("done", result.relevant_records)

    def test_uses_latest_saved_scan_resolution_when_scan_log_has_none(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            db_path = root / "planner.db"
            connection = sqlite3.connect(db_path)
            with connection:
                connection.execute(
                    "CREATE TABLE scans (scan_id TEXT, scanned_at TEXT, window_w INTEGER, window_h INTEGER)"
                )
                connection.execute(
                    "INSERT INTO scans VALUES (?, ?, ?, ?)",
                    ("old", "2026-07-11T01:00:00+09:00", 1280, 720),
                )
                connection.execute(
                    "INSERT INTO scans VALUES (?, ?, ?, ?)",
                    ("new", "2026-07-12T01:00:00+09:00", 2560, 1440),
                )
            connection.close()

            result = collect_recent_log_diagnostics(log_dir=root, db_path=db_path)

        self.assertEqual("2560x1440", result.scan_resolution)
        self.assertEqual("(none)", result.relevant_records)

    def test_builds_editable_redacted_diagnostics(self):
        result = build_diagnostic_text(profile_name="PrivateProfile", recent_error="user@example.com failed")
        self.assertIn("BA Planner version:", result)
        self.assertIn("Operating system:", result)
        self.assertIn("[REDACTED_PROFILE]", result)
        self.assertIn("[REDACTED_EMAIL]", result)
        self.assertIn("Scan resolution: unknown", result)

    def test_builds_deterministic_aggregated_summary(self):
        diagnostic = "\n".join(
            [
                "BA Planner version: 0.4.0",
                "Operating system: Windows",
                "Python version: 3.11",
                "Scan resolution: 1920x1080",
                "2026-07-12 01:00:01  ERROR  [MainThread] [ba.app] scan failed",
                "Traceback (most recent call last):",
                '  File "scanner.py", line 10, in run',
                "RuntimeError: same detail",
                "2026-07-12 01:00:02  ERROR  [MainThread] [ba.app] scan failed",
                "Traceback (most recent call last):",
                '  File "scanner.py", line 10, in run',
                "RuntimeError: same detail",
                "2026-07-12 01:00:03  DEBUG  [MainThread] [ba.matcher] texture_topk_fallback: sid=a field=ex_skill score=0.500",
                "2026-07-12 01:00:04  DEBUG  [MainThread] [ba.matcher] texture_topk_fallback: sid=b field=ex_skill score=0.800",
            ]
        )

        summary = build_diagnostic_summary(diagnostic)

        self.assertIn("Scan resolution: 1920x1080", summary)
        self.assertIn("Errors: 2", summary)
        self.assertIn("RuntimeError: same detail", summary)
        self.assertIn("count=2", summary)
        self.assertIn("Fallbacks: 2", summary)
        self.assertEqual(1, summary.count("texture_topk_fallback"))
        self.assertIn("first=2026-07-12 01:00:01", summary)
        self.assertIn("last=2026-07-12 01:00:02", summary)
        self.assertIn("score_range=0.500..0.800", summary)
        self.assertIn("fields=ex_skill", summary)

    def test_summary_report_body_does_not_embed_raw_traceback(self):
        summary = "## Diagnostic summary\nErrors: 1"
        result = build_summary_report_body("User description", summary)
        self.assertIn("User description", result)
        self.assertIn(summary, result)
        self.assertNotIn("```text", result)

    def test_report_body_redacts_user_text_and_includes_diagnostics(self):
        result = build_report_body(
            "Contact user@example.com",
            "Python version: 3.11",
            profile_name="Default",
        )
        self.assertIn("## Diagnostic information", result)
        self.assertIn("[REDACTED_EMAIL]", result)


class BugReportClientTests(unittest.TestCase):
    def test_staging_endpoint_can_be_selected_with_environment(self):
        with patch.dict(
            "os.environ",
            {"BA_PLANNER_BUG_REPORT_URL": "https://staging.example/report"},
        ):
            self.assertEqual("https://staging.example/report", get_bug_report_url())

    def test_submits_expected_json_and_user_agent(self):
        captured = {}

        def opener(request, timeout):
            captured["request"] = request
            captured["timeout"] = timeout
            return _Response(
                201,
                {
                    "issueUrl": "https://github.com/example/repo/issues/7",
                    "issueNumber": 7,
                    "requestId": "request-7",
                },
            )

        result = BugReportClient("https://worker.example/report", opener=opener).submit("Title", "Body")

        request = captured["request"]
        self.assertEqual("POST", request.method)
        self.assertTrue(request.headers["User-agent"].startswith("BA-Planner/"))
        self.assertEqual({"title": "Title", "body": "Body"}, json.loads(request.data.decode("utf-8")))
        self.assertEqual(7, result.issue_number)
        self.assertEqual("request-7", result.request_id)

    def test_submits_diagnostic_records_separately_from_summary(self):
        captured = {}

        def opener(request, timeout):
            captured["payload"] = json.loads(request.data.decode("utf-8"))
            return _Response(
                201,
                {
                    "issueUrl": "https://github.com/example/repo/issues/8",
                    "issueNumber": 8,
                    "requestId": "request-8",
                    "diagnosticsUploaded": True,
                    "warning": None,
                },
            )

        result = BugReportClient("https://worker.example/report", opener=opener).submit(
            "Title",
            "Compact summary",
            diagnostic_records=("complete traceback",),
        )

        self.assertEqual("Compact summary", captured["payload"]["body"])
        self.assertEqual(["complete traceback"], captured["payload"]["diagnosticRecords"])
        self.assertTrue(result.diagnostics_uploaded)

    def test_maps_worker_error_and_retry_after(self):
        def opener(request, timeout):
            payload = json.dumps(
                {"error": {"code": "RATE_LIMITED", "message": "Too many reports"}, "requestId": "req"}
            ).encode("utf-8")
            raise HTTPError(
                request.full_url,
                429,
                "Too Many Requests",
                {"Retry-After": "120"},
                io.BytesIO(payload),
            )

        with self.assertRaises(BugReportError) as caught:
            BugReportClient("https://worker.example/report", opener=opener).submit("Title", "Body")

        self.assertEqual("RATE_LIMITED", caught.exception.code)
        self.assertEqual(429, caught.exception.status)
        self.assertEqual(120, caught.exception.retry_after)

    def test_maps_network_failure(self):
        def opener(request, timeout):
            raise URLError("offline")

        with self.assertRaises(BugReportError) as caught:
            BugReportClient("https://worker.example/report", opener=opener).submit("Title", "Body")
        self.assertEqual("NETWORK_ERROR", caught.exception.code)

    def test_rejects_utf8_payload_over_worker_byte_limit(self):
        with self.assertRaises(BugReportError) as caught:
            BugReportClient("https://worker.example/report").submit("Title", "한" * 12_000)
        self.assertEqual("PAYLOAD_TOO_LARGE", caught.exception.code)


if __name__ == "__main__":
    unittest.main()
