from __future__ import annotations

import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

from core.bug_report import (
    BugReportClient,
    BugReportError,
    build_diagnostic_text,
    build_report_body,
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

    def test_builds_editable_redacted_diagnostics(self):
        result = build_diagnostic_text(profile_name="PrivateProfile", recent_error="user@example.com failed")
        self.assertIn("BA Planner version:", result)
        self.assertIn("Operating system:", result)
        self.assertIn("[REDACTED_PROFILE]", result)
        self.assertIn("[REDACTED_EMAIL]", result)

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
