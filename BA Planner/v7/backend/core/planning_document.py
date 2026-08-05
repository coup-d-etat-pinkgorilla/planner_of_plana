from __future__ import annotations

from dataclasses import asdict, dataclass
from types import SimpleNamespace
from typing import Any

from core.inventory_catalog import resolve_planning_resource
from core.planning import StudentGoal
from core.planning_calc import PlanCostSummary, calculate_goal_cost
from core.planning_growth_rules import growth_rule_violation
from core.repository_dto import InventorySnapshot


TARGET_MAXIMUMS = {
    "level": 90,
    "bond_rank": 100,
    "student_star": 5,
    "weapon_level": 60,
    "weapon_star": 4,
    "ex_skill": 5,
    "skill1": 10,
    "skill2": 10,
    "skill3": 10,
    "equip1_tier": 10,
    "equip2_tier": 10,
    "equip3_tier": 10,
    "equip1_level": 70,
    "equip2_level": 70,
    "equip3_level": 70,
    "equip4_tier": 2,
    "stat_hp": 25,
    "stat_atk": 25,
    "stat_heal": 25,
}
TARGET_TO_GOAL = {
    "level": "target_level",
    "student_star": "target_star",
    "weapon_level": "target_weapon_level",
    "weapon_star": "target_weapon_star",
    "ex_skill": "target_ex_skill",
    "skill1": "target_skill1",
    "skill2": "target_skill2",
    "skill3": "target_skill3",
    "equip1_tier": "target_equip1_tier",
    "equip2_tier": "target_equip2_tier",
    "equip3_tier": "target_equip3_tier",
    "equip1_level": "target_equip1_level",
    "equip2_level": "target_equip2_level",
    "equip3_level": "target_equip3_level",
    "equip4_tier": "target_equip4_tier",
    "stat_hp": "target_stat_hp",
    "stat_atk": "target_stat_atk",
    "stat_heal": "target_stat_heal",
}
_MATERIAL_FIELDS = (
    "star_materials", "equipment_materials", "level_exp_items",
    "equipment_exp_items", "weapon_exp_items", "skill_books", "ex_ooparts",
    "skill_ooparts", "favorite_item_materials", "stat_materials",
)


class PlanningDocumentError(ValueError):
    pass


@dataclass(frozen=True, slots=True)
class PlanningStage:
    stage_id: str
    student_id: str
    name: str
    targets: dict[str, int]


@dataclass(frozen=True, slots=True)
class PlanningPhase:
    phase_id: str
    name: str
    stages: tuple[PlanningStage, ...]


@dataclass(frozen=True, slots=True)
class PlanningDocument:
    document_id: str
    name: str
    kind: str
    phases: tuple[PlanningPhase, ...]


def planning_document_to_wire(document: PlanningDocument) -> dict[str, Any]:
    return {
        "version": 1,
        "document_id": document.document_id,
        "name": document.name,
        "kind": document.kind,
        "phases": [
            {
                "phase_id": phase.phase_id,
                "name": phase.name,
                "stages": [
                    {
                        "stage_id": stage.stage_id,
                        "student_id": stage.student_id,
                        "name": stage.name,
                        "targets": dict(stage.targets),
                    }
                    for stage in phase.stages
                ],
            }
            for phase in document.phases
        ],
    }


def _text(value: object, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise PlanningDocumentError(f"{label} must be a non-empty string")
    return value.strip()


def planning_document_from_wire(value: object) -> PlanningDocument:
    if not isinstance(value, dict) or set(value) != {"version", "document_id", "name", "kind", "phases"}:
        raise PlanningDocumentError("document has an invalid shape")
    if value["version"] != 1 or isinstance(value["version"], bool):
        raise PlanningDocumentError("document.version must be 1")
    if value["kind"] not in {"plan", "scenario"}:
        raise PlanningDocumentError("document.kind must be plan or scenario")
    raw_phases = value["phases"]
    if not isinstance(raw_phases, list):
        raise PlanningDocumentError("document.phases must be an array")
    phases: list[PlanningPhase] = []
    phase_ids: set[str] = set()
    stage_ids: set[str] = set()
    last_step_by_student: dict[str, dict[str, int]] = {}
    for phase_index, raw_phase in enumerate(raw_phases):
        if not isinstance(raw_phase, dict) or set(raw_phase) != {"phase_id", "name", "stages"}:
            raise PlanningDocumentError(f"document.phases[{phase_index}] has an invalid shape")
        phase_id = _text(raw_phase["phase_id"], f"document.phases[{phase_index}].phase_id")
        if phase_id in phase_ids:
            raise PlanningDocumentError("document phase IDs must be unique")
        phase_ids.add(phase_id)
        if not isinstance(raw_phase["stages"], list):
            raise PlanningDocumentError(f"document.phases[{phase_index}].stages must be an array")
        stages: list[PlanningStage] = []
        for stage_index, raw_stage in enumerate(raw_phase["stages"]):
            label = f"document.phases[{phase_index}].stages[{stage_index}]"
            if not isinstance(raw_stage, dict) or set(raw_stage) != {"stage_id", "student_id", "name", "targets"}:
                raise PlanningDocumentError(f"{label} has an invalid shape")
            stage_id = _text(raw_stage["stage_id"], f"{label}.stage_id")
            if stage_id in stage_ids:
                raise PlanningDocumentError("document stage IDs must be unique")
            stage_ids.add(stage_id)
            student_id = _text(raw_stage["student_id"], f"{label}.student_id")
            raw_targets = raw_stage["targets"]
            if not isinstance(raw_targets, dict) or set(raw_targets) != set(TARGET_MAXIMUMS):
                raise PlanningDocumentError(f"{label}.targets must contain the complete target set")
            targets: dict[str, int] = {}
            previous = last_step_by_student.get(student_id)
            for key, maximum in TARGET_MAXIMUMS.items():
                item = raw_targets[key]
                minimum = 1 if key == "bond_rank" else 0
                if not isinstance(item, int) or isinstance(item, bool) or not minimum <= item <= maximum:
                    raise PlanningDocumentError(f"{label}.targets.{key} is outside its valid range")
                if previous is not None and item < previous[key]:
                    raise PlanningDocumentError(f"{label}.targets.{key} regresses from the previous student stage")
                targets[key] = item
            violation = growth_rule_violation(targets)
            if violation is not None:
                raise PlanningDocumentError(f"{label}.targets {violation}")
            last_step_by_student[student_id] = targets
            stages.append(PlanningStage(stage_id, student_id, _text(raw_stage["name"], f"{label}.name"), targets))
        phases.append(PlanningPhase(phase_id, _text(raw_phase["name"], f"document.phases[{phase_index}].name"), tuple(stages)))
    return PlanningDocument(
        _text(value["document_id"], "document.document_id"),
        _text(value["name"], "document.name"),
        value["kind"],
        tuple(phases),
    )


def _goal(stage: PlanningStage) -> StudentGoal:
    values: dict[str, Any] = {"student_id": stage.student_id, "notes": stage.name}
    for target_key, goal_key in TARGET_TO_GOAL.items():
        values[goal_key] = stage.targets[target_key]
    return StudentGoal(**values)


def _advance(record: SimpleNamespace, stage: PlanningStage) -> None:
    for key, value in stage.targets.items():
        if key == "bond_rank":
            continue
        if key.endswith("_tier") and key.startswith("equip"):
            setattr(record, key.removesuffix("_tier"), None if value <= 0 else f"Tier{value}")
        else:
            setattr(record, key, value)
    if stage.targets["weapon_level"] > 0 or stage.targets["weapon_star"] > 0:
        record.weapon_state = "weapon_equipped"


def _resource_requirements(summary: PlanCostSummary) -> dict[str, tuple[str | None, str, str, int]]:
    result: dict[str, tuple[str | None, str, str, int]] = {}
    if summary.credits > 0:
        result["credits"] = (None, "크레딧", "credits", summary.credits)
    for field in _MATERIAL_FIELDS:
        for label, amount in getattr(summary, field).items():
            if amount <= 0:
                continue
            catalog = resolve_planning_resource(label)
            if catalog is None:
                key, item_id, name, category = f"unresolved:{label}", None, label, "unresolved"
            else:
                key, item_id, name, category = catalog.resource_key, catalog.item_id, catalog.display_name, catalog.category
            old = result.get(key)
            result[key] = (item_id, name, category, amount + (old[3] if old else 0))
    return result


def calculate_document_projection(
    records_by_id: dict[str, SimpleNamespace],
    document: PlanningDocument,
    inventory: InventorySnapshot,
) -> dict[str, Any]:
    records = {key: SimpleNamespace(**vars(value)) for key, value in records_by_id.items()}
    owned = {
        str(entry.item_id or entry.key): (None if entry.quantity is None else int(entry.quantity))
        for entry in inventory.entries
    }
    remaining = dict(owned)
    overall = PlanCostSummary()
    stage_results: list[dict[str, Any]] = []
    phase_results: list[dict[str, Any]] = []
    warnings: list[str] = []
    affected: dict[str, list[str]] = {}
    bottlenecks: list[dict[str, Any]] = []
    first_bottleneck_keys: set[str] = set()

    for phase_index, phase in enumerate(document.phases):
        phase_remaining = dict(remaining)
        phase_affected: dict[str, list[str]] = {}
        phase_total = PlanCostSummary()
        phase_stage_ids: list[str] = []
        for stage_index, stage in enumerate(phase.stages):
            phase_stage_ids.append(stage.stage_id)
            record = records.get(stage.student_id)
            if record is None:
                warnings.append(f"현재 상태가 없는 학생 단계 제외: {stage.student_id}/{stage.stage_id}")
                summary = PlanCostSummary(warnings=["Current student state is missing."])
            else:
                summary = calculate_goal_cost(record, _goal(stage))
                _advance(record, stage)
            phase_total.merge(summary)
            overall.merge(summary)
            resources: list[dict[str, Any]] = []
            for key, (item_id, name, category, required) in _resource_requirements(summary).items():
                affected.setdefault(key, []).append(stage.stage_id)
                phase_affected.setdefault(key, []).append(stage.stage_id)
                before = remaining.get(key)
                shortage = None if before is None else max(0, required - before)
                resources.append({
                    "resource_key": key, "item_id": item_id, "display_name": name,
                    "category": category, "required": required, "owned_at_entry": before,
                    "shortage_at_entry": shortage,
                })
                if before is not None:
                    remaining[key] = max(0, before - required)
                    if shortage and key not in first_bottleneck_keys:
                        first_bottleneck_keys.add(key)
                        bottlenecks.append({
                            "resource_key": key, "item_id": item_id, "display_name": name,
                            "category": category, "remaining_at_entry": before,
                            "required_at_entry": required, "shortage": shortage,
                            "phase_id": phase.phase_id, "phase_number": phase_index + 1,
                            "stage_id": stage.stage_id, "student_id": stage.student_id,
                            "student_step": stage_index + 1, "stage_name": stage.name,
                        })
            stage_results.append({
                "stage_id": stage.stage_id, "phase_id": phase.phase_id,
                "student_id": stage.student_id, "name": stage.name,
                "cost": asdict(summary), "resources": resources,
            })
        phase_resources = _resource_requirements(phase_total)
        phase_results.append({
            "phase_id": phase.phase_id, "name": phase.name, "stage_ids": phase_stage_ids,
            "cost": asdict(phase_total),
            "resources": [
                {
                    "resource_key": key, "item_id": item_id, "display_name": name,
                    "category": category, "required": required, "owned": phase_remaining.get(key),
                    "shortage": None if phase_remaining.get(key) is None else max(0, required - int(phase_remaining[key])),
                    "affected_stage_ids": phase_affected.get(key, []),
                }
                for key, (item_id, name, category, required) in phase_resources.items()
            ],
        })

    overall_resources = _resource_requirements(overall)
    for event in bottlenecks:
        event["affected_stage_ids"] = affected.get(event["resource_key"], [])
    return {
        "document_id": document.document_id,
        "kind": document.kind,
        "stage_results": stage_results,
        "phase_results": phase_results,
        "overall": {
            "cost": asdict(overall),
            "resources": [
                {
                    "resource_key": key, "item_id": item_id, "display_name": name,
                    "category": category, "required": required, "owned": owned.get(key),
                    "shortage": None if owned.get(key) is None else max(0, required - int(owned[key])),
                    "affected_stage_ids": affected.get(key, []),
                }
                for key, (item_id, name, category, required) in overall_resources.items()
            ],
        },
        "bottlenecks": bottlenecks,
        "warnings": warnings + list(overall.warnings),
    }


def compare_document_projections(
    document_a: PlanningDocument,
    projection_a: dict[str, Any],
    document_b: PlanningDocument,
    projection_b: dict[str, Any],
) -> dict[str, Any]:
    """Return deterministic trade-off data without declaring a winner."""

    def resources(projection: dict[str, Any]) -> dict[str, dict[str, Any]]:
        return {
            str(item["resource_key"]): item
            for item in projection["overall"]["resources"]
        }

    resources_a, resources_b = resources(projection_a), resources(projection_b)
    resource_rows: list[dict[str, Any]] = []
    for key in sorted(set(resources_a) | set(resources_b)):
        left, right = resources_a.get(key), resources_b.get(key)
        representative = left or right
        assert representative is not None
        required_a = int(left["required"]) if left else 0
        required_b = int(right["required"]) if right else 0
        owned = (left or {}).get("owned", (right or {}).get("owned"))
        shortage_a = None if owned is None else max(0, required_a - int(owned))
        shortage_b = None if owned is None else max(0, required_b - int(owned))
        resource_rows.append({
            "resource_key": key,
            "item_id": representative.get("item_id"),
            "display_name": representative["display_name"],
            "category": representative["category"],
            "owned": owned,
            "required_a": required_a,
            "required_b": required_b,
            "required_delta_b_minus_a": required_b - required_a,
            "shortage_a": shortage_a,
            "shortage_b": shortage_b,
            "shortage_delta_b_minus_a": None
            if shortage_a is None or shortage_b is None
            else shortage_b - shortage_a,
        })

    def final_targets(document: PlanningDocument) -> dict[str, dict[str, int]]:
        result: dict[str, dict[str, int]] = {}
        for phase in document.phases:
            for stage in phase.stages:
                result[stage.student_id] = dict(stage.targets)
        return result

    targets_a, targets_b = final_targets(document_a), final_targets(document_b)
    students: list[dict[str, Any]] = []
    for student_id in sorted(set(targets_a) | set(targets_b)):
        left, right = targets_a.get(student_id), targets_b.get(student_id)
        differences = {
            key: {"a": left.get(key) if left else None, "b": right.get(key) if right else None}
            for key in TARGET_MAXIMUMS
            if (left.get(key) if left else None) != (right.get(key) if right else None)
        }
        students.append({
            "student_id": student_id,
            "presence": "both" if left is not None and right is not None else "a_only" if left is not None else "b_only",
            "target_differences": differences,
        })

    def first_bottlenecks(projection: dict[str, Any]) -> dict[str, dict[str, Any]]:
        return {str(item["resource_key"]): item for item in projection["bottlenecks"]}

    bottlenecks_a, bottlenecks_b = first_bottlenecks(projection_a), first_bottlenecks(projection_b)
    bottleneck_rows = []
    for key in sorted(set(bottlenecks_a) | set(bottlenecks_b)):
        left, right = bottlenecks_a.get(key), bottlenecks_b.get(key)
        bottleneck_rows.append({
            "resource_key": key,
            "first_phase_a": left.get("phase_number") if left else None,
            "first_phase_b": right.get("phase_number") if right else None,
            "first_stage_a": left.get("stage_id") if left else None,
            "first_stage_b": right.get("stage_id") if right else None,
            "shortage_a": left.get("shortage") if left else 0,
            "shortage_b": right.get("shortage") if right else 0,
        })

    cost_a = projection_a["overall"]["cost"]
    cost_b = projection_b["overall"]["cost"]
    return {
        "credits_a": int(cost_a["credits"]),
        "credits_b": int(cost_b["credits"]),
        "credits_delta_b_minus_a": int(cost_b["credits"]) - int(cost_a["credits"]),
        "resource_type_count_a": len(resources_a),
        "resource_type_count_b": len(resources_b),
        "known_shortage_type_count_a": sum(1 for item in resource_rows if item["shortage_a"] not in (None, 0)),
        "known_shortage_type_count_b": sum(1 for item in resource_rows if item["shortage_b"] not in (None, 0)),
        "students": students,
        "resources": resource_rows,
        "bottlenecks": bottleneck_rows,
    }
