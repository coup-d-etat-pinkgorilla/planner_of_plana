from __future__ import annotations

import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from core.repository_dto import ConfirmedStudent, InventorySnapshot, StudentGoalRecord


ROOT = Path(__file__).parents[2]


class RepositoryProtocolContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = json.loads((ROOT / "contracts/repository-protocol-v1.schema.json").read_text(encoding="utf-8"))
        cls.validator = Draft202012Validator(cls.schema)

    def test_shared_fixture_matches_repository_schema(self) -> None:
        fixture = json.loads((ROOT / "contracts/fixtures/repository_protocol_v1.json").read_text(encoding="utf-8"))
        self.assertEqual(fixture["version"], 1)
        self.assertGreaterEqual(len(fixture["cases"]), 12)
        for case in fixture["cases"]:
            with self.subTest(case_id=case["id"]):
                self.assertEqual(not bool(list(self.validator.iter_errors(case["message"]))), case["valid"])

    def test_nested_schema_matches_python_dto_owners(self) -> None:
        profile_id = "a" * 24

        def request(method: str, field: str, value: object) -> dict:
            return {
                "protocol": 1,
                "id": method,
                "type": "request",
                "method": method,
                "payload": {
                    "profile_id": profile_id,
                    "expected_revision": 0,
                    "idempotency_key": "drift-check",
                    field: value,
                },
            }

        cases = [
            ("confirmed-valid", request("repository.students.update", "students", [{"version": 1, "student_id": "s1", "values": {"level": 80}}]), lambda: ConfirmedStudent.from_dict({"version": 1, "student_id": "s1", "values": {"level": 80}}), True),
            ("confirmed-forbidden", request("repository.students.update", "students", [{"version": 1, "student_id": "s1", "values": {"display_name": "Bad"}}]), lambda: ConfirmedStudent.from_dict({"version": 1, "student_id": "s1", "values": {"display_name": "Bad"}}), False),
            ("confirmed-bool", request("repository.students.update", "students", [{"version": 1, "student_id": "s1", "values": {"level": True}}]), lambda: ConfirmedStudent.from_dict({"version": 1, "student_id": "s1", "values": {"level": True}}), False),
            ("inventory-valid", request("repository.inventory.update", "inventory", {"version": 1, "entries": []}), lambda: InventorySnapshot.from_dict({"version": 1, "entries": []}), True),
            ("inventory-empty", request("repository.inventory.update", "inventory", {}), lambda: InventorySnapshot.from_dict({}), False),
            ("goal-valid", request("repository.goals.save", "goals", {"version": 1, "goals": [{"student_id": "s1", "target_level": 90}]}), lambda: StudentGoalRecord.from_dict({"version": 1, "goal": {"student_id": "s1", "target_level": 90}}), True),
            ("goal-over-maximum", request("repository.goals.save", "goals", {"version": 1, "goals": [{"student_id": "s1", "target_level": 91}]}), lambda: StudentGoalRecord.from_dict({"version": 1, "goal": {"student_id": "s1", "target_level": 91}}), False),
        ]
        for case_id, message, dto_check, expected in cases:
            with self.subTest(case_id=case_id):
                schema_valid = self.validator.is_valid(message)
                try:
                    dto_check()
                    dto_valid = True
                except (TypeError, ValueError):
                    dto_valid = False
                self.assertEqual(schema_valid, expected)
                self.assertEqual(dto_valid, expected)
                self.assertEqual(schema_valid, dto_valid)


if __name__ == "__main__":
    unittest.main()
