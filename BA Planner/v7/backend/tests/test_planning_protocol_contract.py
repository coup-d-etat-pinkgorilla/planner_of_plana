from __future__ import annotations

import json
import unittest
from dataclasses import asdict, fields
from pathlib import Path
from types import SimpleNamespace
from typing import Any

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError
from referencing import Registry, Resource

from core import student_meta
from core.planning import GrowthPlan, StudentGoal
from core.planning_calc import calculate_plan_totals


CONTRACTS = Path(__file__).parents[2] / "contracts"
FIXTURE = CONTRACTS / "fixtures" / "planning_protocol_v1.json"
METHOD_SCHEMAS = {
    "planning.student.get": "planning-student-get-v1.schema.json",
    "planning.plan.validate": "planning-plan-validate-v1.schema.json",
    "planning.plan.calculate": "planning-plan-calculate-v1.schema.json",
}
class PlanningProtocolContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
        cls.schemas = {
            path.name: json.loads(path.read_text(encoding="utf-8"))
            for path in CONTRACTS.glob("*.schema.json")
        }
        resources = [
            (schema["$id"], Resource.from_contents(schema))
            for schema in cls.schemas.values()
        ]
        cls.registry = Registry().with_resources(resources)
        cls.validator = Draft202012Validator(
            cls.schemas["planning-protocol-v1.schema.json"],
            registry=cls.registry,
        )

    @staticmethod
    def _plan_from_wire(plan: dict[str, Any]) -> GrowthPlan:
        goal_fields = {item.name for item in fields(StudentGoal)}
        goals = [
            StudentGoal(**{key: value for key, value in goal.items() if key in goal_fields})
            for goal in plan["goals"]
        ]
        return GrowthPlan(version=plan["version"], goals=goals)

    @classmethod
    def _case(cls, name: str) -> dict[str, Any]:
        return next(case for case in cls.fixture["cases"] if case["name"] == name)

    def test_schema_documents_use_draft_2020_12(self) -> None:
        for name, schema in self.schemas.items():
            with self.subTest(schema=name):
                self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
                Draft202012Validator.check_schema(schema)

        expected = {
            "protocol-envelope-v1.schema.json", "planning-types-v1.schema.json",
            "planning-protocol-v1.schema.json", "protocol-error-v1.schema.json",
            "repository-protocol-v1.schema.json",
            *METHOD_SCHEMAS.values(),
        }
        self.assertEqual(set(self.schemas), expected)

    def test_shared_fixture_messages(self) -> None:
        self.assertEqual(self.fixture["protocol"], 1)
        for case in self.fixture["cases"]:
            with self.subTest(case=case["name"]):
                if case["valid"]:
                    self.validator.validate(case["message"])
                else:
                    with self.assertRaises(ValidationError):
                        self.validator.validate(case["message"])

    def test_shared_fixture_request_response_correlation(self) -> None:
        for case in self.fixture["correlations"]:
            with self.subTest(case=case["name"]):
                request, response = case["request"], case["response"]
                self.validator.validate(request)
                self.validator.validate(response)
                correlated = (
                    request["type"] == "request" and response["type"] == "response"
                    and request["id"] == response["id"] and request["method"] == response["method"]
                )
                self.assertEqual(correlated, case["matches"])

    def test_plan_round_trip_correlations_preserve_semantics(self) -> None:
        correlations = [
            case for case in self.fixture["correlations"]
            if case.get("semantic") == "canonical_plan"
        ]
        self.assertEqual(len(correlations), 3)
        known_goal_fields = {item.name for item in fields(StudentGoal)}
        for case in correlations:
            with self.subTest(case=case["name"]):
                request_plan = case["request"]["payload"]["plan"]
                response_plan = case["response"]["payload"]["plan"]
                self.assertEqual(
                    self._plan_from_wire(request_plan),
                    self._plan_from_wire(response_plan),
                )
                self.assertLessEqual(set(response_plan), {"version", "goals"})
                self.assertTrue(
                    all(set(goal) <= known_goal_fields for goal in response_plan["goals"])
                )

    def test_calculation_correlations_match_backend_results(self) -> None:
        correlations = [
            case for case in self.fixture["correlations"]
            if case.get("semantic") == "calculation"
        ]
        self.assertEqual(len(correlations), 2)
        for case in correlations:
            with self.subTest(case=case["name"]):
                payload = case["request"]["payload"]
                records = {
                    record["student_id"]: SimpleNamespace(**record)
                    for record in payload["current_students"]
                }
                actual = asdict(
                    calculate_plan_totals(records, self._plan_from_wire(payload["plan"]))
                )
                self.assertEqual(actual, case["response"]["payload"]["totals"])

        empty = next(case for case in correlations if "empty targets" in case["name"])
        self.assertTrue(
            all(
                value == 0 or value == {} or value == []
                for value in empty["response"]["payload"]["totals"].values()
            )
        )

    def test_student_metadata_fixture_matches_backend(self) -> None:
        wire = self._case("student metadata response")["message"]["payload"]["student"]
        backend = student_meta.get("ayane")
        self.assertIsNotNone(backend)
        self.assertEqual(wire["student_id"], "ayane")
        for key, value in wire.items():
            if key != "student_id":
                self.assertEqual(value, backend[key], key)


if __name__ == "__main__":
    unittest.main()
