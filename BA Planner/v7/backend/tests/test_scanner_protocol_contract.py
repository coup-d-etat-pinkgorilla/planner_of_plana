from __future__ import annotations

import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[2]


class ScannerProtocolContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = json.loads((ROOT / "contracts/scanner-protocol-v1.schema.json").read_text(encoding="utf-8"))
        cls.fixture = json.loads((ROOT / "contracts/fixtures/scanner_protocol_v1.json").read_text(encoding="utf-8"))
        cls.validator = Draft202012Validator(cls.schema)

    def test_fixture_version_and_case_counts(self) -> None:
        self.assertEqual(1, self.fixture["version"])
        self.assertEqual(15, len(self.fixture["cases"]))
        self.assertEqual(9, sum(case["valid"] for case in self.fixture["cases"]))

    def test_every_fixture_has_expected_schema_result(self) -> None:
        for case in self.fixture["cases"]:
            with self.subTest(case=case["name"]):
                errors = list(self.validator.iter_errors(case["message"]))
                self.assertEqual(case["valid"], not errors, [error.message for error in errors])

    def test_valid_trace_has_one_terminal_and_strict_sequences(self) -> None:
        messages = [case["message"] for case in self.fixture["cases"] if case["valid"]]
        events = [item for item in messages if item["type"] == "event"]
        by_session: dict[str, list[dict]] = {}
        for event in events:
            by_session.setdefault(event["payload"]["session_id"], []).append(event)
        for session_events in by_session.values():
            sequences = [event["payload"]["sequence"] for event in session_events]
            self.assertEqual(sequences, sorted(set(sequences)))
            self.assertEqual(1, sum(event["payload"]["event_kind"] == "terminal" for event in session_events))
            self.assertEqual("terminal", session_events[-1]["payload"]["event_kind"])


if __name__ == "__main__":
    unittest.main()
