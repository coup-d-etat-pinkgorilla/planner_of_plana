"""FB-11a: single-student costs, document parity, strict additive contract."""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import random
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError
from referencing import Registry, Resource

from core.planning_calc import CREDIT_CATEGORIES
from core.protocol_v1 import PlanningProtocolV1


CONTRACTS = Path(__file__).parents[2] / "contracts"
FIXTURE = CONTRACTS / "fixtures/planning_student_calculate_v1.json"


def _document_payload(payload: dict) -> dict:
    return {
        "current_students": [payload["current_student"]],
        "inventory": payload.get("inventory", {"version": 1, "entries": []}),
        "document": {
            "version": 1, "document_id": "growth-calculator", "name": "성장 계산기",
            "kind": "scenario", "phases": [{
                "phase_id": "growth-calculator-phase", "name": "성장 계산기",
                "stages": [{
                    "stage_id": "growth-calculator-stage",
                    "student_id": payload["current_student"]["student_id"],
                    "name": "계산기 목표", "targets": payload["targets"],
                }],
            }],
        },
    }


class StudentCalculationFB11aTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = json.loads(FIXTURE.read_text(encoding="utf-8"))["cases"]
        schemas = [json.loads(path.read_text(encoding="utf-8")) for path in CONTRACTS.glob("*.schema.json")]
        registry = Registry().with_resources([(schema["$id"], Resource.from_contents(schema)) for schema in schemas])
        cls.validator = Draft202012Validator(
            next(schema for schema in schemas if schema["$id"].endswith("/planning-protocol-v1.schema.json")),
            registry=registry,
        )

    def _request(self, payload: dict) -> dict:
        return {"protocol": 1, "id": "fb11a", "type": "request", "method": "planning.student.calculate", "payload": payload}

    def _parity(self, payload: dict) -> dict:
        request = self._request(deepcopy(payload))
        before = deepcopy(request)
        protocol = PlanningProtocolV1()
        response = protocol.handle(request)
        self.assertEqual(request, before, "calculation must not mutate any caller input")
        self.validator.validate(response)
        result = response["payload"]
        self.assertNotIn("error", result)
        document = protocol.handle({**self._request(_document_payload(payload)), "method": "planning.document.calculate"})["payload"]["projection"]
        self.assertEqual(result["totals"]["credits"], document["overall"]["cost"]["credits"])
        self.assertEqual(result["resources"], document["overall"]["resources"])
        self.assertEqual(result["warnings"], document["warnings"])
        self.assertEqual(set(result["credit_breakdown"]), set(CREDIT_CATEGORIES))
        self.assertEqual(sum(result["credit_breakdown"].values()), result["totals"]["credits"])
        self.assertNotIn("bond", result)
        return result

    def test_shared_fixture_replays_and_matches_document_calculation(self) -> None:
        for case in self.cases:
            with self.subTest(case=case["name"]):
                self.validator.validate(case["request"])
                self.validator.validate(case["response"])
                self.assertEqual(PlanningProtocolV1().handle(case["request"]), case["response"])
                self._parity(case["request"]["payload"])

    def test_mixed_growth_locks_each_category_amount(self) -> None:
        result = self._parity(self.cases[2]["request"]["payload"])
        self.assertEqual(result["credit_breakdown"], {
            "level": 8_683_465, "student_star": 1_200_000, "weapon_star": 1_000_000,
            "favorite_item": 500_000, "equipment": 31_164, "ex_skill": 80_000,
            "weapon_level": 2_115_900, "skill": 90_000, "potential": 300_000,
        })
        self.assertEqual(result["totals"], {"credits": 14_000_529})

    def test_no_growth_and_lower_targets_have_zero_cost(self) -> None:
        payload = deepcopy(self.cases[0]["request"]["payload"])
        payload["targets"].update(level=20, equip1_tier=0, equip1_level=0)
        result = self._parity(payload)
        self.assertEqual(result["totals"], {"credits": 0})
        self.assertEqual(result["resources"], [])
        self.assertTrue(all(value == 0 for value in result["credit_breakdown"].values()))

    def test_unlocked_weapon_and_equipment_tier_alias_current_values(self) -> None:
        payload = deepcopy(self.cases[2]["request"]["payload"])
        payload["current_student"].update(
            student_star=5, weapon_state="weapon_unlocked_not_equipped", weapon_star=2,
            weapon_level=30, equip1="Tier2", equip1_level=20, equip4="T2",
        )
        result = self._parity(payload)
        self.assertEqual(result["credit_breakdown"]["student_star"], 0)
        self.assertEqual(result["credit_breakdown"]["weapon_star"], 0)
        self.assertEqual(result["credit_breakdown"]["favorite_item"], 0)
        self.assertGreater(result["credit_breakdown"]["weapon_level"], 0)

    def test_max_targets_and_repeated_random_valid_targets(self) -> None:
        rng = random.Random(11)
        payload = deepcopy(self.cases[2]["request"]["payload"])
        for index in range(51):
            targets = payload["targets"]
            targets.update(bond_rank=100, weapon_star=4, weapon_level=60,
                           ex_skill=5, skill1=10, skill2=10, skill3=10,
                           stat_hp=25, stat_atk=25, stat_heal=25)
            for slot in range(1, 4):
                targets[f"equip{slot}_tier"] = 10
                targets[f"equip{slot}_level"] = 70 if index == 0 else rng.randrange(71)
            if index:
                targets.update(weapon_star=2, weapon_level=rng.randrange(41),
                               ex_skill=rng.randrange(1, 6), skill1=rng.randrange(1, 11),
                               skill2=rng.randrange(1, 11), skill3=rng.randrange(1, 11),
                               stat_hp=rng.randrange(26), stat_atk=rng.randrange(26), stat_heal=rng.randrange(26))
            with self.subTest(index=index):
                self._parity(payload)

    def test_inventory_unknown_zero_and_surplus_do_not_change_gross_cost(self) -> None:
        unknown = self._parity(self.cases[2]["request"]["payload"])
        known = self._parity(self.cases[3]["request"]["payload"])
        self.assertEqual(unknown["totals"], known["totals"])
        self.assertEqual(unknown["credit_breakdown"], known["credit_breakdown"])
        rows = {row["resource_key"]: row for row in known["resources"]}
        self.assertEqual(rows["credits"]["owned"], 0)
        self.assertEqual(rows["credits"]["shortage"], known["totals"]["credits"])
        self.assertEqual(rows["Item_Icon_ExpItem_3"]["shortage"], 0)
        self.assertIsNone(rows["Equipment_Icon_Shoes_Tier2"]["owned"])
        self.assertIsNone(rows["Equipment_Icon_Shoes_Tier2"]["shortage"])
        self.assertTrue(all(row["owned"] is None for row in unknown["resources"]))

    def test_unknown_metadata_warnings_and_unresolved_resources_are_preserved(self) -> None:
        payload = deepcopy(self.cases[2]["request"]["payload"])
        payload["current_student"]["student_id"] = "fb11a-unknown-student"
        result = self._parity(payload)
        self.assertIn("No ooparts metadata found in student_meta.", result["warnings"])
        self.assertTrue(any(row["resource_key"].startswith("unresolved:") for row in result["resources"]))

    def test_payloads_and_growth_rules_are_rejected(self) -> None:
        base = self.cases[0]["request"]["payload"]
        bad_payloads = [
            {**base, "document_id": "saved-id"}, {"targets": base["targets"]},
            {**base, "current_student": []}, {**base, "inventory": None},
            {**base, "current_student": {**base["current_student"], "bond_rank": 1}},
            {**base, "current_student": {**base["current_student"], "level": True}},
            {**base, "targets": {key: value for key, value in base["targets"].items() if key != "bond_rank"}},
            {**base, "targets": {**base["targets"], "level": True}},
            {**base, "targets": {**base["targets"], "extra": 0}},
            {**base, "targets": {**base["targets"], "weapon_star": 2}},
            {**base, "targets": {**base["targets"], "equip1_level": 70}},
        ]
        for payload in bad_payloads:
            with self.subTest(payload=payload):
                response = PlanningProtocolV1().handle(self._request(payload))
                self.assertEqual(response["payload"]["error"]["code"], "invalid_payload")
                self.validator.validate(response)

    def test_calculation_exception_returns_correlated_error(self) -> None:
        request = self.cases[0]["request"]
        with patch("core.protocol_v1.calculate_document_projection", side_effect=RuntimeError("test")):
            response = PlanningProtocolV1().handle(request)
        self.assertEqual(response["id"], request["id"])
        self.assertEqual(response["method"], request["method"])
        self.assertEqual(response["payload"]["error"]["code"], "calculation_failed")
        self.validator.validate(response)

    def test_bond_contract_is_strict_after_fb11b_and_growth_keys_stay_strict(self) -> None:
        response = deepcopy(self.cases[0]["response"])
        fixture = json.loads((CONTRACTS / "fixtures/planning_student_bond_v1.json").read_text(encoding="utf-8"))
        response["payload"]["bond"] = fixture["cases"][0]["response"]["payload"]["bond"]
        self.validator.validate(response)
        for value in (None, [], 1, {"future": {"value": 1}}):
            response["payload"]["bond"] = value
            with self.assertRaises(ValidationError):
                self.validator.validate(response)
        response["payload"].pop("bond")
        response["payload"]["bonds"] = {}
        with self.assertRaises(ValidationError):
            self.validator.validate(response)


if __name__ == "__main__":
    unittest.main()
