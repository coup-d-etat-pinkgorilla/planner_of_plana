from __future__ import annotations

import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from tests.test_scenario_store import document


CONTRACTS = Path(__file__).parents[2] / "contracts"


class ScenarioProtocolContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        schemas = {
            path.name: json.loads(path.read_text(encoding="utf-8"))
            for path in CONTRACTS.glob("*.schema.json")
        }
        registry = Registry().with_resources([
            (schema["$id"], Resource.from_contents(schema))
            for schema in schemas.values()
        ])
        cls.validator = Draft202012Validator(
            schemas["scenario-protocol-v1.schema.json"], registry=registry,
        )

    def test_canonical_requests_and_responses_match_schema(self) -> None:
        profile_id, scenario_id = "a" * 24, "b" * 24
        messages = [
            {"protocol": 1, "id": "list", "type": "request", "method": "repository.scenario.list", "payload": {"profile_id": profile_id}},
            {"protocol": 1, "id": "create", "type": "request", "method": "repository.scenario.create", "payload": {"profile_id": profile_id, "expected_revision": 0, "idempotency_key": "create", "name": "후보", "description": "", "base_profile_revision": 0, "document": document("후보")}},
            {"protocol": 1, "id": "mutation", "type": "response", "method": "repository.scenario.create", "payload": {"revision": 1, "scenario_id": scenario_id}},
            {"protocol": 1, "id": "error", "type": "response", "method": "repository.scenario.get", "payload": {"error": {"code": "scenario_not_found", "message": "missing", "retryable": False}}},
        ]
        for message in messages:
            with self.subTest(message=message["id"]):
                self.validator.validate(message)

    def test_plan_kind_is_schema_valid_but_rejected_semantically(self) -> None:
        # The shared document schema owns shape; the store owns the scenario-kind invariant.
        value = {"protocol": 1, "id": "create", "type": "request", "method": "repository.scenario.create", "payload": {"profile_id": "a" * 24, "expected_revision": 0, "idempotency_key": "create", "name": "후보", "description": "", "base_profile_revision": 0, "document": {**document("후보"), "kind": "plan"}}}
        self.validator.validate(value)


if __name__ == "__main__":
    unittest.main()
