from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
from typing import Any

from core.repository_dto import ConfirmedStudent, InventorySnapshot, StudentGoalRecord


_PROFILE_KEY = re.compile(r"profile_[0-9a-f]{8,64}")
_CURRENT_INTEGER_FIELDS = {
    "level", "bond_rank", "student_star", "weapon_star", "weapon_level",
    "ex_skill", "skill1", "skill2", "skill3", "equip1_level",
    "equip2_level", "equip3_level", "combat_hp", "combat_atk",
    "combat_def", "combat_heal", "stat_hp", "stat_atk", "stat_heal",
}
_CURRENT_STRING_FIELDS = {
    "weapon_state", "equip1", "equip2", "equip3", "equip4",
}


class V6MigrationError(ValueError):
    pass


@dataclass(frozen=True, slots=True)
class V6Account:
    profile_key: str
    display_name: str
    avatar_student_id: str
    students: tuple[dict[str, Any], ...]
    inventory: dict[str, Any]
    goals: dict[str, Any]
    warnings: tuple[str, ...]

    def preview(self) -> dict[str, Any]:
        return {
            "source_profile_key": self.profile_key,
            "display_name": self.display_name,
            "avatar_student_id": self.avatar_student_id,
            "student_count": len(self.students),
            "inventory_count": len(self.inventory["entries"]),
            "goal_count": len(self.goals["goals"]),
            "warnings": list(self.warnings),
        }


def _read_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise V6MigrationError(f"{label} is missing") from error
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise V6MigrationError(f"{label} cannot be read: {type(error).__name__}") from error
    if not isinstance(value, dict):
        raise V6MigrationError(f"{label} must be an object")
    return value


def _registry(v6_root: Path) -> dict[str, tuple[str, str]]:
    config = _read_object(v6_root / "config.json", "v6 config")
    result: dict[str, tuple[str, str]] = {}
    raw_profiles = config.get("profiles", [])
    if not isinstance(raw_profiles, list):
        raise V6MigrationError("v6 config profiles must be an array")
    for raw in raw_profiles:
        if not isinstance(raw, dict):
            continue
        key = raw.get("key")
        name = raw.get("name")
        avatar = raw.get("account_portrait_student_id", "hasumi")
        if (
            isinstance(key, str)
            and _PROFILE_KEY.fullmatch(key)
            and isinstance(name, str)
            and name.strip()
            and isinstance(avatar, str)
            and avatar.strip()
        ):
            result[key] = (name.strip(), avatar.strip())
    return result


def _students(value: dict[str, Any], warnings: list[str]) -> tuple[dict[str, Any], ...]:
    result: list[dict[str, Any]] = []
    for map_key, raw in value.items():
        if not isinstance(raw, dict):
            warnings.append(f"학생 {map_key}: 객체가 아니어서 제외됨")
            continue
        student_id = raw.get("student_id", map_key)
        if not isinstance(student_id, str) or not student_id:
            warnings.append(f"학생 {map_key}: student_id가 없어 제외됨")
            continue
        current: dict[str, Any] = {}
        for key in _CURRENT_INTEGER_FIELDS:
            item = raw.get(key)
            if isinstance(item, int) and not isinstance(item, bool) and item >= 0:
                current[key] = item
        for key in _CURRENT_STRING_FIELDS:
            item = raw.get(key)
            if item is None or isinstance(item, str):
                if key in raw:
                    current[key] = item
        form_stats = raw.get("form_combat_stats")
        if isinstance(form_stats, dict):
            current["form_combat_stats"] = form_stats
        try:
            canonical = ConfirmedStudent.from_dict({
                "version": 1,
                "student_id": student_id,
                "values": current,
            }).to_dict()
        except (TypeError, ValueError, KeyError, AttributeError) as error:
            warnings.append(f"학생 {student_id}: {error}")
            continue
        result.append(canonical)
    return tuple(result)


def _inventory(value: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    for map_key, raw in value.items():
        if not isinstance(raw, dict):
            warnings.append(f"인벤토리 {map_key}: 객체가 아니어서 제외됨")
            continue
        item_id = raw.get("item_id")
        key = item_id if isinstance(item_id, str) and item_id else map_key
        quantity = raw.get("quantity")
        if isinstance(quantity, int) and not isinstance(quantity, bool) and quantity >= 0:
            quantity = str(quantity)
        elif quantity is not None and not (
            isinstance(quantity, str)
            and (quantity == "0" or (quantity and quantity[0] in "123456789" and quantity.isascii() and quantity.isdigit()))
        ):
            warnings.append(f"인벤토리 {key}: 수량 형식이 잘못되어 미확정으로 가져옴")
            quantity = None
        entry: dict[str, Any] = {"key": key, "quantity": quantity}
        if isinstance(item_id, str) and item_id:
            entry["item_id"] = item_id
        if isinstance(raw.get("name"), str):
            entry["name"] = raw["name"]
        if isinstance(raw.get("index"), int) and not isinstance(raw.get("index"), bool):
            entry["index"] = raw["index"]
        entries.append(entry)
    try:
        return InventorySnapshot.from_dict({"version": 1, "entries": entries}).to_dict()
    except (TypeError, ValueError, KeyError, AttributeError) as error:
        raise V6MigrationError(f"v6 inventory cannot be normalized: {error}") from error


def _goals(value: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    raw_goals = value.get("goals", [])
    if value.get("version", 1) != 1 or not isinstance(raw_goals, list):
        raise V6MigrationError("v6 growth plan must be version 1")
    goals: list[dict[str, Any]] = []
    for index, raw in enumerate(raw_goals):
        if not isinstance(raw, dict):
            warnings.append(f"계획 목표 {index + 1}: 객체가 아니어서 제외됨")
            continue
        try:
            goals.append(StudentGoalRecord.from_dict({"version": 1, "goal": raw}).to_dict()["goal"])
        except (TypeError, ValueError, KeyError, AttributeError) as error:
            warnings.append(f"계획 목표 {index + 1}: {error}")
    return {"version": 1, "goals": goals}


def load_v6_accounts(v6_root: Path) -> tuple[V6Account, ...]:
    root = Path(v6_root).resolve()
    registry = _registry(root)
    accounts: list[V6Account] = []
    for profile_key, (display_name, avatar) in registry.items():
        profile_root = (root / "profiles" / profile_key).resolve()
        if profile_root.parent != (root / "profiles").resolve() or not profile_root.is_dir():
            continue
        current = profile_root / "data" / "current"
        warnings: list[str] = []
        accounts.append(V6Account(
            profile_key=profile_key,
            display_name=display_name,
            avatar_student_id=avatar,
            students=_students(_read_object(current / "students.json", "v6 students"), warnings),
            inventory=_inventory(_read_object(current / "inventory.json", "v6 inventory"), warnings),
            goals=_goals(_read_object(current / "growth_plan.json", "v6 growth plan"), warnings),
            warnings=tuple(warnings),
        ))
    return tuple(accounts)
