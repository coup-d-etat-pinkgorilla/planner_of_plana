from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError
from referencing import Registry, Resource

from core.planning import StudentGoal
from core.planning_calc import calculate_goal_cost, calculate_goal_transition
from core.planning_document import (
    PlanningDocumentError, calculate_document_projection, compare_document_projections,
    planning_document_from_wire, planning_document_to_wire,
)
from core.protocol_v1 import PlanningProtocolV1
from core.repository_dto import InventorySnapshot
from core.scenario_store import ScenarioStore

CONTRACTS = Path(__file__).parents[2] / "contracts"
FIXTURES = CONTRACTS / "fixtures"


class PlanningDocumentV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = json.loads((FIXTURES / "planning_document_v2.json").read_text(encoding="utf-8"))["cases"]
        schemas = [json.loads(path.read_text(encoding="utf-8")) for path in CONTRACTS.glob("*.schema.json")]
        cls.registry = Registry().with_resources((schema["$id"], Resource.from_contents(schema)) for schema in schemas)
        cls.schema = next(schema for schema in schemas if schema["$id"].endswith("planning-document-calculate-v1.schema.json"))
        cls.document_validator = Draft202012Validator({"$ref": cls.schema["$id"] + "#/$defs/document"}, registry=cls.registry)

    def case(self, name):
        return next(case for case in self.cases if case["name"] == name)

    def project(self, case):
        return calculate_document_projection(
            {record["student_id"]: SimpleNamespace(**record) for record in case["current_students"]},
            planning_document_from_wire(case["document"]), InventorySnapshot.from_dict(case["inventory"]),
        )

    def test_approved_policy_fixtures_round_trip_without_rewriting_targets(self):
        for case in self.cases:
            with self.subTest(case=case["name"]):
                original = copy.deepcopy(case)
                if not case["valid"]:
                    with self.assertRaisesRegex(PlanningDocumentError, "regresses"):
                        planning_document_from_wire(case["document"])
                    continue
                self.document_validator.validate(case["document"])
                document = planning_document_from_wire(case["document"])
                self.assertEqual(case["document"], planning_document_to_wire(document))
                projection = self.project(case)
                if "credits" in case["expected"]:
                    self.assertEqual(case["expected"]["credits"], projection["overall"]["cost"]["credits"])
                if "warnings" in case["expected"]:
                    self.assertEqual(case["expected"]["warnings"], len(projection["warnings"]))
                if "warning_contains" in case["expected"]:
                    self.assertIn(case["expected"]["warning_contains"], " ".join(projection["warnings"]))
                self.assertEqual(original, case)
                self.assertEqual(case["document"], planning_document_to_wire(document))

    def test_weapon_and_equipment_effective_state_is_carried_once(self):
        for name in ("partial_weapon", "partial_equipment"):
            case = self.case(name)
            staged = self.project(case)
            single = copy.deepcopy(case)
            single["document"]["phases"][0]["stages"] = [single["document"]["phases"][0]["stages"][-1]]
            self.assertEqual(staged["overall"]["cost"]["credits"], self.project(single)["overall"]["cost"]["credits"])
        weapon = self.project(self.case("partial_weapon"))
        self.assertTrue(weapon["stage_results"][0]["cost"]["star_materials"])
        self.assertFalse(weapon["stage_results"][1]["cost"]["star_materials"])
        equipment = self.project(self.case("partial_equipment"))
        self.assertFalse(equipment["stage_results"][1]["cost"]["equipment_materials"])

    def test_original_nullable_goal_reaches_core_and_unknown_bond_is_not_invented(self):
        from core import planning_calc
        case = self.case("null_bond_unknown")
        record = SimpleNamespace(**case["current_students"][0])
        goal = StudentGoal(student_id="aru")
        with patch.object(planning_calc, "calculate_goal_cost", wraps=calculate_goal_cost) as pricing:
            _, projected = calculate_goal_transition(record, goal, bond_target=None)
            self.assertIs(pricing.call_args.args[1], goal)
            self.assertIsNone(pricing.call_args.args[1].target_level)
        self.assertFalse(hasattr(projected, "bond_rank"))
        self.assertFalse(hasattr(record, "bond_rank"))
        self.assertIsNone(goal.target_level)

    def test_strict_metadata_and_nullable_target_shape(self):
        base = self.case("all_null")["document"]
        mutations = [
            lambda d: d.pop("goal_metadata"),
            lambda d: d["goal_metadata"].clear(),
            lambda d: d["goal_metadata"].update(extra={"favorite": True, "notes": ""}),
            lambda d: d["goal_metadata"]["aru"].update(favorite="yes"),
            lambda d: d["goal_metadata"]["aru"].update(notes=None),
            lambda d: d["goal_metadata"]["aru"].update(extra=0),
            lambda d: d["goal_metadata"]["aru"].pop("favorite"),
            lambda d: d["phases"][0]["stages"][0]["targets"].pop("level"),
            lambda d: d["phases"][0]["stages"][0]["targets"].update(level=True),
            lambda d: d["phases"][0]["stages"][0]["targets"].update(bond_rank=0),
            lambda d: d["phases"][0]["stages"][0]["targets"].update(level="30"),
        ]
        for mutate in mutations:
            invalid = copy.deepcopy(base)
            mutate(invalid)
            with self.subTest(document=invalid), self.assertRaises(PlanningDocumentError):
                planning_document_from_wire(invalid)
        # Semantic student-map coverage is checked by the parser, not JSON Schema.
        for mutate in mutations[:1] + mutations[3:]:
            invalid = copy.deepcopy(base)
            mutate(invalid)
            with self.assertRaises(ValidationError):
                self.document_validator.validate(invalid)

    def test_v1_projection_comparison_and_wire_match_frozen_outputs(self):
        fixed = json.loads((FIXTURES / "planning_document_v1_fb1a_parity.json").read_text(encoding="utf-8"))
        records = {record["student_id"]: SimpleNamespace(**record) for record in fixed["current_students"]}
        inventory = InventorySnapshot.from_dict(fixed["inventory"])
        a, b = (planning_document_from_wire(fixed[f"document_{key}"]) for key in "ab")
        pa, pb = (calculate_document_projection(records, doc, inventory) for doc in (a, b))
        self.assertEqual(fixed["projection_a"], pa)
        self.assertEqual(fixed["projection_b"], pb)
        self.assertEqual(fixed["comparison"], compare_document_projections(a, pa, b, pb))
        self.assertEqual(fixed["document_a"], planning_document_to_wire(a))
        self.assertEqual(fixed["document_b"], planning_document_to_wire(b))

    def test_v1_scenario_file_and_results_are_byte_preserved(self):
        fixed = json.loads((FIXTURES / "scenario_v1_fb1a_parity.json").read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory() as temporary:
            store = ScenarioStore(Path(temporary), profile_revision=lambda _: 0, id_factory=lambda: "b" * 32, clock=lambda: "2026-10-08T14:05:00Z")
            profile = "a" * 24
            created = store.create(profile, 0, "freeze", "Scenario", "old notes", 0, fixed["document"])
            self.assertEqual(fixed["created"], created)
            self.assertEqual(fixed["loaded"], store.get(profile, created["scenario_id"]))
            self.assertEqual(fixed["listed"], store.list(profile))
            self.assertEqual(fixed["file_text"].encode(), store._path(profile).read_bytes())

    def test_v2_scenario_restarts_and_keeps_goal_metadata_and_nulls(self):
        case = self.case("partial_weapon")
        with tempfile.TemporaryDirectory() as temporary:
            store = ScenarioStore(Path(temporary), profile_revision=lambda _: 0)
            created = store.create("a" * 24, 0, "create-v2", "V2", "", 0, case["document"])
            restarted = ScenarioStore(Path(temporary), profile_revision=lambda _: 0)
            loaded = restarted.get("a" * 24, created["scenario_id"])["scenario"]["document"]
            self.assertEqual(case["document"], loaded)

    def test_document_bond_context_is_local_and_fb11a_stays_integer_v1(self):
        case = self.case("null_bond_known")
        payload = {key: copy.deepcopy(case[key]) for key in ("current_students", "document", "inventory")}
        request = {"protocol": 1, "id": "v2", "type": "request", "method": "planning.document.calculate", "payload": payload}
        validator = Draft202012Validator(self.schema, registry=self.registry)
        validator.validate(request)
        self.assertNotIn("error", PlanningProtocolV1().handle(request)["payload"])
        legacy_targets = json.loads((FIXTURES / "planning_document_v1_fb1a_parity.json").read_text(encoding="utf-8"))["document_a"]["phases"][0]["stages"][0]["targets"]
        single = {**request, "method": "planning.student.calculate", "payload": {"current_student": case["current_students"][0], "targets": legacy_targets}}
        self.assertEqual("invalid_payload", PlanningProtocolV1().handle(single)["payload"]["error"]["code"])
        single["payload"]["current_student"] = {"student_id": "aru"}
        single["payload"]["targets"] = case["document"]["phases"][0]["stages"][0]["targets"]
        self.assertEqual("invalid_payload", PlanningProtocolV1().handle(single)["payload"]["error"]["code"])


if __name__ == "__main__":
    unittest.main()
