from __future__ import annotations

from dataclasses import asdict, fields
from types import SimpleNamespace
from typing import Any, Callable
import traceback

from core import student_meta
from core.planning import (
    GrowthPlan,
    MAX_TARGET_EQUIP4_TIER,
    MAX_TARGET_EQUIP_LEVEL,
    MAX_TARGET_EQUIP_TIER,
    MAX_TARGET_EX_SKILL,
    MAX_TARGET_LEVEL,
    MAX_TARGET_SKILL,
    MAX_TARGET_STAR,
    MAX_TARGET_STAT,
    MAX_TARGET_WEAPON_LEVEL,
    MAX_TARGET_WEAPON_STAR,
    StudentGoal,
)
from core.planning_calc import calculate_plan_totals


PROTOCOL_VERSION = 1
METHOD_STUDENT_GET = "planning.student.get"
METHOD_STUDENT_CATALOG = "planning.student.catalog"
METHOD_PLAN_VALIDATE = "planning.plan.validate"
METHOD_PLAN_CALCULATE = "planning.plan.calculate"
KNOWN_METHODS = frozenset(
    {METHOD_STUDENT_GET, METHOD_STUDENT_CATALOG, METHOD_PLAN_VALIDATE, METHOD_PLAN_CALCULATE}
)
_ENVELOPE_KEYS = {"protocol", "id", "type", "method", "payload"}
_GOAL_FIELDS = {item.name for item in fields(StudentGoal)}
_CURRENT_STRING_FIELDS = {"student_id", "weapon_state"}
_CURRENT_NULLABLE_STRING_FIELDS = {"equip1", "equip2", "equip3", "equip4"}
_CURRENT_INTEGER_FIELDS = {
    "level",
    "student_star",
    "weapon_star",
    "weapon_level",
    "ex_skill",
    "skill1",
    "skill2",
    "skill3",
    "equip1_level",
    "equip2_level",
    "equip3_level",
    "stat_hp",
    "stat_atk",
    "stat_heal",
}
_CURRENT_FIELDS = (
    _CURRENT_STRING_FIELDS
    | _CURRENT_NULLABLE_STRING_FIELDS
    | _CURRENT_INTEGER_FIELDS
)
_GOAL_RANGES = {
    "target_level": MAX_TARGET_LEVEL,
    "target_star": MAX_TARGET_STAR,
    "target_weapon_level": MAX_TARGET_WEAPON_LEVEL,
    "target_weapon_star": MAX_TARGET_WEAPON_STAR,
    "target_ex_skill": MAX_TARGET_EX_SKILL,
    "target_skill1": MAX_TARGET_SKILL,
    "target_skill2": MAX_TARGET_SKILL,
    "target_skill3": MAX_TARGET_SKILL,
    "target_equip1_tier": MAX_TARGET_EQUIP_TIER,
    "target_equip2_tier": MAX_TARGET_EQUIP_TIER,
    "target_equip3_tier": MAX_TARGET_EQUIP_TIER,
    "target_equip1_level": MAX_TARGET_EQUIP_LEVEL,
    "target_equip2_level": MAX_TARGET_EQUIP_LEVEL,
    "target_equip3_level": MAX_TARGET_EQUIP_LEVEL,
    "target_equip4_tier": MAX_TARGET_EQUIP4_TIER,
    "target_stat_hp": MAX_TARGET_STAT,
    "target_stat_atk": MAX_TARGET_STAT,
    "target_stat_heal": MAX_TARGET_STAT,
}


class InvalidPayload(ValueError):
    pass


def _is_integer(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _require_object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise InvalidPayload(f"{label} must be an object")
    return value


def _plan_from_wire(value: object) -> GrowthPlan:
    plan = _require_object(value, "plan")
    if plan.get("version") != 1 or not _is_integer(plan.get("version")):
        raise InvalidPayload("plan.version must be 1")
    goals = plan.get("goals")
    if not isinstance(goals, list):
        raise InvalidPayload("plan.goals must be an array")

    canonical_goals: list[StudentGoal] = []
    for index, raw_goal in enumerate(goals):
        goal = _require_object(raw_goal, f"plan.goals[{index}]")
        student_id = goal.get("student_id")
        if not isinstance(student_id, str) or not student_id:
            raise InvalidPayload(f"plan.goals[{index}].student_id must be non-empty")
        if "favorite" in goal and not isinstance(goal["favorite"], bool):
            raise InvalidPayload(f"plan.goals[{index}].favorite must be a boolean")
        if "notes" in goal and not isinstance(goal["notes"], str):
            raise InvalidPayload(f"plan.goals[{index}].notes must be a string")
        for key, maximum in _GOAL_RANGES.items():
            if key not in goal or goal[key] is None:
                continue
            if not _is_integer(goal[key]) or not 0 <= goal[key] <= maximum:
                raise InvalidPayload(
                    f"plan.goals[{index}].{key} must be null or an integer from 0 to {maximum}"
                )
        canonical_goals.append(
            StudentGoal(**{key: value for key, value in goal.items() if key in _GOAL_FIELDS})
        )
    return GrowthPlan(version=1, goals=canonical_goals)


def _current_students_from_wire(value: object) -> dict[str, SimpleNamespace]:
    if not isinstance(value, list):
        raise InvalidPayload("current_students must be an array")
    result: dict[str, SimpleNamespace] = {}
    for index, raw_student in enumerate(value):
        student = _require_object(raw_student, f"current_students[{index}]")
        if set(student) - _CURRENT_FIELDS:
            raise InvalidPayload(f"current_students[{index}] contains unknown fields")
        student_id = student.get("student_id")
        if not isinstance(student_id, str) or not student_id:
            raise InvalidPayload(
                f"current_students[{index}].student_id must be non-empty"
            )
        for key in _CURRENT_STRING_FIELDS - {"student_id"}:
            if key in student and not isinstance(student[key], str):
                raise InvalidPayload(f"current_students[{index}].{key} must be a string")
        for key in _CURRENT_NULLABLE_STRING_FIELDS:
            if key in student and student[key] is not None and not isinstance(student[key], str):
                raise InvalidPayload(
                    f"current_students[{index}].{key} must be a string or null"
                )
        for key in _CURRENT_INTEGER_FIELDS:
            if key in student and (
                not _is_integer(student[key]) or student[key] < 0
            ):
                raise InvalidPayload(
                    f"current_students[{index}].{key} must be a non-negative integer"
                )
        result[student_id] = SimpleNamespace(**student)
    return result


def _success(request: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "protocol": PROTOCOL_VERSION,
        "id": request["id"],
        "type": "response",
        "method": request["method"],
        "payload": payload,
    }


def error_response(
    request: dict[str, Any], code: str, message: str, *, details: dict[str, Any] | None = None
) -> dict[str, Any]:
    error: dict[str, Any] = {"code": code, "message": message}
    if details:
        error["details"] = details
    return _success(request, {"error": error})


class PlanningProtocolV1:
    def __init__(
        self,
        *,
        student_lookup: Callable[[str], dict[str, Any] | None] = student_meta.get,
        student_ids: Callable[[], list[str]] = student_meta.all_ids,
        calculator: Callable[[dict[str, object], GrowthPlan], object] = calculate_plan_totals,
        diagnostic: Callable[[str], None] | None = None,
    ) -> None:
        self._student_lookup = student_lookup
        self._student_ids = student_ids
        self._calculator = calculator
        self._diagnostic = diagnostic or (lambda _message: None)

    def handle(self, message: object) -> dict[str, Any] | None:
        request = self._trusted_request(message)
        if request is None:
            return None
        if request["method"] not in KNOWN_METHODS:
            return error_response(
                request,
                "unknown_method",
                f"Unknown protocol method: {request['method']}",
            )
        try:
            if request["method"] == METHOD_STUDENT_GET:
                return self._student_get(request)
            if request["method"] == METHOD_STUDENT_CATALOG:
                return self._student_catalog(request)
            if request["method"] == METHOD_PLAN_VALIDATE:
                return self._plan_validate(request)
            return self._plan_calculate(request)
        except InvalidPayload as error:
            return error_response(request, "invalid_payload", str(error))

    @staticmethod
    def _trusted_request(message: object) -> dict[str, Any] | None:
        if not isinstance(message, dict) or set(message) != _ENVELOPE_KEYS:
            return None
        if message.get("protocol") != PROTOCOL_VERSION:
            return None
        if message.get("type") != "request":
            return None
        if not isinstance(message.get("id"), str) or not message["id"]:
            return None
        if not isinstance(message.get("method"), str) or not message["method"]:
            return None
        if not isinstance(message.get("payload"), dict):
            return None
        return message

    def _student_get(self, request: dict[str, Any]) -> dict[str, Any]:
        payload = request["payload"]
        if set(payload) != {"student_id"}:
            raise InvalidPayload("payload must contain only student_id")
        student_id = payload["student_id"]
        if not isinstance(student_id, str) or not student_id:
            raise InvalidPayload("student_id must be a non-empty string")
        try:
            metadata = self._student_lookup(student_id)
        except Exception:
            self._diagnostic(traceback.format_exc())
            return error_response(
                request, "metadata_lookup_failed", "Student metadata lookup failed"
            )
        wire = None if metadata is None else {**metadata, "student_id": student_id}
        return _success(request, {"student": wire})

    def _student_catalog(self, request: dict[str, Any]) -> dict[str, Any]:
        if request["payload"]:
            raise InvalidPayload("catalog payload must be empty")
        try:
            students = []
            for student_id in self._student_ids():
                metadata = self._student_lookup(student_id) or {}
                students.append({
                    "student_id": student_id,
                    "display_name": str(metadata.get("display_name") or student_id),
                    "template_name": str(metadata.get("template_name") or f"{student_id}.png"),
                    "group": str(metadata.get("group") or student_id),
                    "variant": metadata.get("variant") if isinstance(metadata.get("variant"), str) else None,
                    "school": metadata.get("school") if isinstance(metadata.get("school"), str) else None,
                    "rarity": metadata.get("rarity") if isinstance(metadata.get("rarity"), str) else None,
                    "attack_type": metadata.get("attack_type") if isinstance(metadata.get("attack_type"), str) else None,
                    "defense_type": metadata.get("defense_type") if isinstance(metadata.get("defense_type"), str) else None,
                    "combat_class": metadata.get("combat_class") if isinstance(metadata.get("combat_class"), str) else None,
                    "role": metadata.get("role") if isinstance(metadata.get("role"), str) else None,
                    "position": metadata.get("position") if isinstance(metadata.get("position"), str) else None,
                    "search_tags": [str(item) for item in metadata.get("search_tags", []) if str(item).strip()] if isinstance(metadata.get("search_tags", []), list) else [],
                    "kr_search_tags": [str(item) for item in metadata.get("kr_search_tags", []) if str(item).strip()] if isinstance(metadata.get("kr_search_tags", []), list) else [],
                })
        except Exception:
            self._diagnostic(traceback.format_exc())
            return error_response(request, "metadata_lookup_failed", "Student catalog lookup failed")
        students.sort(key=lambda item: (item["display_name"].casefold(), item["student_id"]))
        return _success(request, {"students": students, "sort": "display_name_then_id"})

    @staticmethod
    def _plan_validate(request: dict[str, Any]) -> dict[str, Any]:
        payload = request["payload"]
        if set(payload) != {"plan"}:
            raise InvalidPayload("payload must contain only plan")
        plan = _plan_from_wire(payload["plan"])
        return _success(request, {"valid": True, "plan": asdict(plan)})

    def _plan_calculate(self, request: dict[str, Any]) -> dict[str, Any]:
        payload = request["payload"]
        if set(payload) != {"current_students", "plan"}:
            raise InvalidPayload("payload must contain current_students and plan")
        records = _current_students_from_wire(payload["current_students"])
        plan = _plan_from_wire(payload["plan"])
        try:
            totals = self._calculator(records, plan)
            wire_totals = asdict(totals)
        except Exception:
            self._diagnostic(traceback.format_exc())
            return error_response(
                request, "calculation_failed", "Plan calculation failed"
            )
        return _success(request, {"totals": wire_totals})
