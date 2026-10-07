"""FB-12: 계획 계산 현재 성급 읽기와 장비 티어 이월 형식."""
from __future__ import annotations

from dataclasses import asdict
from types import SimpleNamespace
import unittest

from core.planning import StudentGoal
from core.planning_calc import _parse_tier_number, calculate_goal_cost
from core.planning_document import (
    _advance,
    calculate_document_projection,
    planning_document_from_wire,
)
from core.protocol_v1 import PlanningProtocolV1
from core.repository_dto import InventorySnapshot


STUDENT_ID = "ayane"


def _record(**updates: object) -> dict[str, object]:
    """protocol_v1 `current_students` 항목 모양(성장 규칙에 맞는 ★3 학생)."""
    record: dict[str, object] = {
        "student_id": STUDENT_ID,
        "level": 30,
        "student_star": 3,
        "weapon_state": "weapon_locked",
        "weapon_star": 0,
        "weapon_level": 0,
        "ex_skill": 1,
        "skill1": 1,
        "skill2": 1,
        "skill3": 1,
        "equip1": "T1",
        "equip2": None,
        "equip3": None,
        "equip4": None,
        "equip1_level": 1,
        "equip2_level": 0,
        "equip3_level": 0,
        "stat_hp": 0,
        "stat_atk": 0,
        "stat_heal": 0,
    }
    record.update(updates)
    return record


def _targets(**updates: int) -> dict[str, int]:
    """_record()와 같은 상태의 문서 목표 19 key."""
    targets = {
        "level": 30,
        "bond_rank": 1,
        "student_star": 3,
        "weapon_level": 0,
        "weapon_star": 0,
        "ex_skill": 1,
        "skill1": 1,
        "skill2": 1,
        "skill3": 1,
        "equip1_tier": 1,
        "equip2_tier": 0,
        "equip3_tier": 0,
        "equip1_level": 1,
        "equip2_level": 0,
        "equip3_level": 0,
        "equip4_tier": 0,
        "stat_hp": 0,
        "stat_atk": 0,
        "stat_heal": 0,
    }
    targets.update(updates)
    return targets


def _two_phase_document(first: dict[str, int], second: dict[str, int]) -> dict:
    return {
        "version": 1,
        "document_id": "fb12",
        "name": "FB-12",
        "kind": "scenario",
        "phases": [
            {
                "phase_id": "phase-1",
                "name": "1단계",
                "stages": [{"stage_id": "stage-1", "student_id": STUDENT_ID, "name": "1", "targets": first}],
            },
            {
                "phase_id": "phase-2",
                "name": "2단계",
                "stages": [{"stage_id": "stage-2", "student_id": STUDENT_ID, "name": "2", "targets": second}],
            },
        ],
    }


def _project(record: dict[str, object], document: dict) -> dict:
    return calculate_document_projection(
        {STUDENT_ID: SimpleNamespace(**record)},
        planning_document_from_wire(document),
        InventorySnapshot.from_dict({"version": 1, "entries": []}),
    )


def _star_cost(current_star: int, target_star: int, **record: object) -> tuple[int, dict[str, int]]:
    summary = calculate_goal_cost(
        SimpleNamespace(**_record(student_star=current_star, **record)),
        StudentGoal(student_id=STUDENT_ID, target_star=target_star),
    )
    return summary.credits, summary.star_materials


class StudentStarCostTests(unittest.TestCase):
    def test_star_cost_starts_from_the_wire_student_star(self) -> None:
        credits, materials = _star_cost(3, 5)
        from_zero_credits, from_zero_materials = _star_cost(0, 5)
        eleph = f"Item_Icon_SecretStone_{STUDENT_ID}"
        self.assertLess(credits, from_zero_credits)
        self.assertLess(materials[eleph], from_zero_materials[eleph])
        # ★3→★4 + ★4→★5 단계 비용의 합과 같다.
        three_four = _star_cost(3, 4)
        four_five = _star_cost(4, 5)
        self.assertEqual(credits, three_four[0] + four_five[0])
        self.assertEqual(materials[eleph], three_four[1][eleph] + four_five[1][eleph])
        # 표 값: 크레딧 200,000 + 1,000,000, 엘레프 100 + 120.
        self.assertEqual(credits, 1_200_000)
        self.assertEqual(materials, {eleph: 220})

    def test_reaching_the_current_star_costs_nothing(self) -> None:
        self.assertEqual(_star_cost(5, 5), (0, {}))
        self.assertEqual(_star_cost(4, 2), (0, {}))

    def test_legacy_star_attribute_is_read_only_when_student_star_is_missing(self) -> None:
        legacy = _record()
        del legacy["student_star"]
        legacy["star"] = 4
        summary = calculate_goal_cost(SimpleNamespace(**legacy), StudentGoal(student_id=STUDENT_ID, target_star=5))
        self.assertEqual(summary.credits, 1_000_000)
        # 둘 다 있으면 wire 이름(student_star)을 쓴다.
        both = calculate_goal_cost(
            SimpleNamespace(**_record(student_star=4, star=1)),
            StudentGoal(student_id=STUDENT_ID, target_star=5),
        )
        self.assertEqual(both.credits, 1_000_000)

    def test_plan_calculate_protocol_uses_student_star(self) -> None:
        response = PlanningProtocolV1().handle({
            "protocol": 1,
            "id": "fb12-star",
            "type": "request",
            "method": "planning.plan.calculate",
            "payload": {
                "current_students": [_record()],
                "plan": {"version": 1, "goals": [{"student_id": STUDENT_ID, "target_star": 5}]},
            },
        })
        totals = response["payload"]["totals"]
        self.assertEqual(totals["credits"], 1_200_000)
        self.assertEqual(totals["star_materials"], {f"Item_Icon_SecretStone_{STUDENT_ID}": 220})

    def test_later_stage_star_cost_starts_from_the_previous_stage(self) -> None:
        projection = _project(
            _record(),
            _two_phase_document(_targets(student_star=4), _targets(student_star=5)),
        )
        first, second = projection["stage_results"]
        self.assertEqual(first["cost"]["credits"], 200_000)
        self.assertEqual(second["cost"]["credits"], 1_000_000)
        self.assertEqual(projection["overall"]["cost"]["credits"], _star_cost(3, 5)[0])


class EquipmentTierCarryOverTests(unittest.TestCase):
    def test_second_stage_equipment_cost_covers_only_t5_to_t7(self) -> None:
        projection = _project(
            _record(),
            _two_phase_document(
                _targets(equip1_tier=5, equip1_level=45),
                _targets(equip1_tier=7, equip1_level=55),
            ),
        )
        second = projection["stage_results"][1]["cost"]
        goal = StudentGoal(student_id=STUDENT_ID, target_equip1_tier=7, target_equip1_level=55)
        t5_to_t7 = asdict(calculate_goal_cost(SimpleNamespace(**_record(equip1="T5", equip1_level=45)), goal))
        t0_to_t7 = asdict(calculate_goal_cost(SimpleNamespace(**_record(equip1=None, equip1_level=0)), goal))
        for key in ("credits", "equipment_exp", "equipment_materials", "equipment_exp_items"):
            with self.subTest(key=key):
                self.assertEqual(second[key], t5_to_t7[key])
        self.assertLess(second["credits"], t0_to_t7["credits"])
        self.assertLess(second["equipment_exp"], t0_to_t7["equipment_exp"])
        # 1단계 + 2단계 = T1 → T7 한 번에.
        t1_to_t7 = calculate_goal_cost(SimpleNamespace(**_record()), goal)
        self.assertEqual(projection["overall"]["cost"]["credits"], t1_to_t7.credits)
        self.assertEqual(projection["overall"]["cost"]["equipment_exp"], t1_to_t7.equipment_exp)

    def test_advance_writes_the_canonical_tier_format(self) -> None:
        document = planning_document_from_wire(
            _two_phase_document(
                _targets(equip1_tier=5, equip1_level=45, equip4_tier=0),
                _targets(equip1_tier=7, equip1_level=55),
            )
        )
        record = SimpleNamespace(**_record())
        _advance(record, document.phases[0].stages[0])
        self.assertEqual(record.equip1, "T5")
        self.assertIsNone(record.equip2)
        self.assertIsNone(record.equip4)
        self.assertEqual(record.equip1_level, 45)
        self.assertEqual(record.student_star, 3)


class TierParserTests(unittest.TestCase):
    def test_accepts_t_and_tier_prefixes_in_any_case_with_spaces(self) -> None:
        for raw, expected in (
            ("T7", 7),
            ("t7", 7),
            ("Tier7", 7),
            ("TIER7", 7),
            ("tier10", 10),
            (" T 7 ", 7),
            ("Tier 10", 10),
            ("T0", 0),
        ):
            with self.subTest(raw=raw):
                self.assertEqual(_parse_tier_number(raw), expected)

    def test_unexpected_values_are_zero(self) -> None:
        for raw in (None, "", "T", "Tier", "7", "love_locked", "T-1", "T+3", "T7a", "T１", "Tier7.5", 7):
            with self.subTest(raw=raw):
                self.assertEqual(_parse_tier_number(raw), 0)  # type: ignore[arg-type]


if __name__ == "__main__":
    unittest.main()
