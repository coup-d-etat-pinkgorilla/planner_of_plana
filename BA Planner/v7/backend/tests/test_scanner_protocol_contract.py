from __future__ import annotations

import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from core.inventory_catalog import SCAN_PROFILES


ROOT = Path(__file__).resolve().parents[2]


class ScannerProtocolContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = json.loads((ROOT / "contracts/scanner-protocol-v1.schema.json").read_text(encoding="utf-8"))
        cls.fixture = json.loads((ROOT / "contracts/fixtures/scanner_protocol_v1.json").read_text(encoding="utf-8"))
        cls.validator = Draft202012Validator(cls.schema)

    def test_fixture_version_and_case_counts(self) -> None:
        self.assertEqual(1, self.fixture["version"])
        self.assertEqual(17, len(self.fixture["cases"]))
        self.assertEqual(10, sum(case["valid"] for case in self.fixture["cases"]))

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

    def test_field_feedback_event_is_part_of_protocol_v1(self) -> None:
        event = {
            "protocol": 1,
            "type": "event",
            "method": "scanner.session.event",
            "payload": {
                "session_id": "session-feedback",
                "generation": 1,
                "sequence": 2,
                "scan_kind": "student",
                "event_kind": "feedback",
                "student_id": "shiroko",
                "field": "level",
                "values": {"level": 90},
            },
        }
        self.assertEqual([], list(self.validator.iter_errors(event)))

    def test_inventory_scan_profile_enum_is_the_catalog_single_source(self) -> None:
        request = next(
            item for item in self.schema["$defs"]["request"]["allOf"][1]["oneOf"]
            if item["properties"]["method"].get("const") == "scanner.session.start"
        )
        enum = request["properties"]["payload"]["properties"]["inventory_scan_profile"]["enum"]
        self.assertEqual(list(SCAN_PROFILES), enum)

    def test_real_replay_candidates_including_shadow_evidence_match_schema(self) -> None:
        candidate_validator = Draft202012Validator({"$ref": "#/$defs/candidate", "$defs": self.schema["$defs"]})
        statuses: set[str] = set()
        goldens = sorted((ROOT / "backend/tests/fixtures/scanner_consolidation/golden").glob("*.json"))
        self.assertTrue(goldens)
        for path in goldens:
            result = json.loads(path.read_text(encoding="utf-8"))["result"]
            rows = result if isinstance(result, list) else result.get("candidates", [])
            scan_kind = "student" if path.stem.startswith("student_") else "inventory"
            for index, row in enumerate(rows):
                candidate = {
                    "candidate_id": f"{path.stem}-{index}", "session_id": "c0-golden", "generation": 1,
                    "revision": 1, "scan_kind": scan_kind, "payload": row["payload"],
                    "evidence": row["evidence"], "review_required": row["review_required"],
                    "approved": False, "audit": [],
                }
                statuses.update(item["status"] for item in row["evidence"])
                with self.subTest(golden=path.stem, candidate=index):
                    errors = [error.message for error in candidate_validator.iter_errors(candidate)]
                    self.assertEqual([], errors)
        self.assertIn("shadow", statuses)


if __name__ == "__main__":
    unittest.main()
