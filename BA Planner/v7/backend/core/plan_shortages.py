from __future__ import annotations

from typing import Any

from core.inventory_catalog import resolve_planning_resource
from core.planning import GrowthPlan
from core.planning_calc import PlanCostSummary, calculate_goal_cost, calculate_plan_totals


_MATERIAL_FIELDS = (
    "star_materials", "equipment_materials", "level_exp_items",
    "equipment_exp_items", "weapon_exp_items", "skill_books", "ex_ooparts",
    "skill_ooparts", "favorite_item_materials", "stat_materials",
)


def _materials(summary: PlanCostSummary) -> dict[str, int]:
    result: dict[str, int] = {}
    for field in _MATERIAL_FIELDS:
        for label, amount in getattr(summary, field).items():
            if amount > 0:
                result[label] = result.get(label, 0) + amount
    return result


def derive_plan_shortages(
    records_by_id: dict[str, object],
    plan: GrowthPlan,
    inventory_entries: list[dict[str, Any]],
) -> dict[str, object]:
    owned_by_key: dict[str, int] = {}
    seen: set[str] = set()
    for entry in inventory_entries:
        key = str(entry.get("item_id") or entry.get("key") or "").strip()
        if not key or key in seen:
            raise ValueError("inventory entries must have unique canonical identity")
        seen.add(key)
        quantity = entry.get("quantity")
        if quantity is None:
            continue
        if not isinstance(quantity, str) or not (
            quantity == "0" or (
                bool(quantity) and "1" <= quantity[0] <= "9"
                and all("0" <= char <= "9" for char in quantity)
            )
        ):
            raise ValueError("inventory quantity must be null or a canonical non-negative integer string")
        owned_by_key[key] = int(quantity)

    gross = calculate_plan_totals(records_by_id, plan)
    required_by_label = _materials(gross)
    affected_by_label: dict[str, set[str]] = {}
    for goal in plan.goals:
        record = records_by_id.get(goal.student_id)
        if record is None:
            continue
        for label in _materials(calculate_goal_cost(record, goal)):
            affected_by_label.setdefault(label, set()).add(goal.student_id)

    resolved: dict[str, dict[str, object]] = {}
    unresolved: list[dict[str, object]] = []
    warnings = list(gross.warnings)
    for label in sorted(required_by_label, key=str.casefold):
        catalog = resolve_planning_resource(label)
        if catalog is None:
            warnings.append(f"Unresolved inventory identity: {label}")
            unresolved.append({
                "resource_key": f"unresolved:{label}", "item_id": None,
                "display_name": label, "category": "unresolved",
                "required": required_by_label[label], "owned": None, "shortage": None,
                "affected_student_ids": sorted(affected_by_label.get(label, ())),
                "resolved": False,
            })
            continue
        row = resolved.setdefault(catalog.resource_key, {
            "resource_key": catalog.resource_key,
            "item_id": catalog.item_id,
            "display_name": catalog.display_name,
            "category": catalog.category,
            "required": 0,
            "owned": owned_by_key.get(catalog.resource_key),
            "affected_student_ids": set(),
            "resolved": True,
        })
        row["required"] = int(row["required"]) + required_by_label[label]
        affected_ids = row["affected_student_ids"]
        assert isinstance(affected_ids, set)
        affected_ids.update(affected_by_label.get(label, ()))

    rows = list(resolved.values()) + unresolved
    for row in resolved.values():
        owned = row["owned"]
        required = int(row["required"])
        row["shortage"] = None if owned is None else max(0, required - int(owned))
        row["affected_student_ids"] = sorted(row["affected_student_ids"])
    rows.sort(key=lambda row: (str(row["category"]), str(row["display_name"]).casefold(), str(row["resource_key"])))
    return {"rows": rows, "warnings": warnings}
