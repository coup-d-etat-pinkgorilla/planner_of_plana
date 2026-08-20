from __future__ import annotations

import json
from pathlib import Path
from types import SimpleNamespace
import unittest

from core.planning_document import (
    PlanningDocumentError,
    calculate_document_projection,
    compare_document_projections,
    planning_document_from_wire,
)
from core.repository_dto import InventorySnapshot
from core.protocol_v1 import PlanningProtocolV1


FIXTURE = Path(__file__).parents[2] / "contracts" / "fixtures" / "planning_v6_parity.json"


def _targets(level: int) -> dict[str, int]:
    return {
        "level": level,
        "bond_rank": 1,
        "student_star": 1,
        "weapon_level": 0,
        "weapon_star": 0,
        "ex_skill": 1,
        "skill1": 1,
        "skill2": 0,
        "skill3": 0,
        "equip1_tier": 1,
        "equip2_tier": 1 if level >= 10 else 0,
        "equip3_tier": 1 if level >= 20 else 0,
        "equip1_level": 1,
        "equip2_level": 1 if level >= 10 else 0,
        "equip3_level": 1 if level >= 20 else 0,
        "equip4_tier": 0,
        "stat_hp": 0,
        "stat_atk": 0,
        "stat_heal": 0,
    }


def _document(second_level: int = 10) -> dict:
    return {
        "version": 1,
        "document_id": "scenario-1",
        "name": "시나리오",
        "kind": "scenario",
        "phases": [
            {
                "phase_id": "phase-1",
                "name": "1단계",
                "stages": [{"stage_id": "stage-1", "student_id": "ayane", "name": "Lv.5", "targets": _targets(5)}],
            },
            {
                "phase_id": "phase-2",
                "name": "2단계",
                "stages": [{"stage_id": "stage-2", "student_id": "ayane", "name": "Lv.10", "targets": _targets(second_level)}],
            },
        ],
    }


class PlanningDocumentTests(unittest.TestCase):
    def test_stages_are_calculated_sequentially_and_phase_inventory_rolls_forward(self) -> None:
        record = json.loads(FIXTURE.read_text(encoding="utf-8"))["record"]
        projection = calculate_document_projection(
            {"ayane": SimpleNamespace(**record)},
            planning_document_from_wire(_document()),
            InventorySnapshot.from_dict({
                "version": 1,
                "entries": [{"key": "credits", "quantity": "0"}],
            }),
        )
        first, second = projection["stage_results"]
        self.assertGreater(first["cost"]["credits"], 0)
        self.assertGreater(second["cost"]["credits"], 0)
        self.assertEqual(
            projection["overall"]["cost"]["credits"],
            first["cost"]["credits"] + second["cost"]["credits"],
        )
        self.assertEqual(projection["kind"], "scenario")
        self.assertEqual([item["phase_number"] for item in projection["bottlenecks"] if item["resource_key"] == "credits"], [1])
        second_credits = next(item for item in projection["phase_results"][1]["resources"] if item["resource_key"] == "credits")
        self.assertEqual(second_credits["owned"], 0)
        self.assertEqual(second_credits["affected_stage_ids"], ["stage-2"])

    def test_a_later_stage_cannot_regress_the_same_student(self) -> None:
        with self.assertRaisesRegex(PlanningDocumentError, "regresses"):
            planning_document_from_wire(_document(second_level=4))

    def test_equipment_level_must_fit_its_tier(self) -> None:
        document = _document()
        document["phases"][0]["stages"][0]["targets"].update(
            {"equip1_tier": 9, "equip1_level": 70}
        )
        with self.assertRaisesRegex(PlanningDocumentError, "Tier9 cap"):
            planning_document_from_wire(document)

    def test_weapon_level_must_fit_its_star_and_requires_student_star_five(self) -> None:
        over_cap = _document()
        over_cap["phases"][0]["stages"][0]["targets"].update(
            {"student_star": 5, "weapon_star": 1, "weapon_level": 40}
        )
        with self.assertRaisesRegex(PlanningDocumentError, "1-star cap"):
            planning_document_from_wire(over_cap)

        locked_student = _document()
        locked_student["phases"][0]["stages"][0]["targets"].update(
            {"student_star": 4, "weapon_star": 1, "weapon_level": 30}
        )
        with self.assertRaisesRegex(PlanningDocumentError, "student_star 5"):
            planning_document_from_wire(locked_student)

    def test_growth_rule_boundaries_are_accepted(self) -> None:
        document = _document()
        for phase in document["phases"]:
            phase["stages"][0]["targets"].update(
                {
                    "student_star": 5,
                    "skill2": 1,
                    "skill3": 1,
                    "weapon_star": 2,
                    "weapon_level": 40,
                    "equip1_tier": 9,
                    "equip1_level": 65,
                }
            )
        parsed = planning_document_from_wire(document)
        self.assertEqual(parsed.phases[0].stages[0].targets["equip1_level"], 65)

    def test_game_unlock_combinations_are_rejected(self) -> None:
        invalid_updates = (
            ({"student_star": 1, "skill2": 1}, "2-star unlock"),
            ({"student_star": 2, "skill2": 1, "skill3": 1}, "3-star unlock"),
            ({"level": 9, "equip2_tier": 1, "equip2_level": 1}, "level 10"),
            ({"level": 19, "equip3_tier": 1, "equip3_level": 1}, "level 20"),
            (
                {
                    "level": 89,
                    "student_star": 5,
                    "skill2": 1,
                    "skill3": 1,
                    "stat_hp": 1,
                },
                "level 90",
            ),
            (
                {
                    "student_star": 4,
                    "skill2": 1,
                    "skill3": 1,
                    "bond_rank": 21,
                },
                "4-star cap",
            ),
            (
                {
                    "student_star": 3,
                    "skill2": 1,
                    "skill3": 1,
                    "bond_rank": 20,
                    "equip4_tier": 2,
                },
                "higher bond_rank",
            ),
        )
        for updates, message in invalid_updates:
            with self.subTest(updates=updates):
                document = _document()
                document["phases"][0]["stages"][0]["targets"].update(updates)
                with self.assertRaisesRegex(PlanningDocumentError, message):
                    planning_document_from_wire(document)

    def test_scenario_comparison_reports_tradeoffs_without_a_winner(self) -> None:
        record = json.loads(FIXTURE.read_text(encoding="utf-8"))["record"]
        inventory = InventorySnapshot.from_dict({
            "version": 1,
            "entries": [{"key": "credits", "quantity": "100"}],
        })
        document_a = planning_document_from_wire(_document(second_level=8))
        document_b = planning_document_from_wire(_document(second_level=10))
        projection_a = calculate_document_projection({"ayane": SimpleNamespace(**record)}, document_a, inventory)
        projection_b = calculate_document_projection({"ayane": SimpleNamespace(**record)}, document_b, inventory)
        comparison = compare_document_projections(document_a, projection_a, document_b, projection_b)
        self.assertGreater(comparison["credits_delta_b_minus_a"], 0)
        credits = next(item for item in comparison["resources"] if item["resource_key"] == "credits")
        self.assertGreater(credits["required_delta_b_minus_a"], 0)
        self.assertEqual(comparison["students"][0]["presence"], "both")
        self.assertNotIn("winner", comparison)

    def test_scenario_compare_protocol_accepts_active_plan_and_scenario(self) -> None:
        record = json.loads(FIXTURE.read_text(encoding="utf-8"))["record"]
        request = {
            "protocol": 1,
            "id": "compare",
            "type": "request",
            "method": "planning.scenario.compare",
            "payload": {
                "current_students": [record],
                "inventory": {"version": 1, "entries": []},
                "document_a": _document(second_level=8),
                "document_b": {
                    **_document(second_level=10),
                    "document_id": "scenario-b",
                    "name": "Scenario B",
                },
            },
        }
        response = PlanningProtocolV1().handle(request)
        self.assertEqual(set(response["payload"]), {"projection_a", "projection_b", "comparison"})
        active_plan = PlanningProtocolV1().handle({
            **request,
            "payload": {
                **request["payload"],
                "document_b": {**_document(), "document_id": "active-plan", "kind": "plan"},
            },
        })
        self.assertEqual(set(active_plan["payload"]), {"projection_a", "projection_b", "comparison"})
        invalid = PlanningProtocolV1().handle({
            **request,
            "payload": {**request["payload"], "document_b": request["payload"]["document_a"]},
        })
        self.assertEqual(invalid["payload"]["error"]["code"], "invalid_payload")


if __name__ == "__main__":
    unittest.main()
