from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable, Mapping, Sequence


STUDENT_FIELDS = (
    "display_name", "level", "student_star", "weapon_state", "weapon_star", "weapon_level",
    "ex_skill", "skill1", "skill2", "skill3", "equip1", "equip2", "equip3", "equip4",
    "equip1_level", "equip2_level", "equip3_level", "combat_hp", "combat_atk", "combat_def",
    "combat_heal", "form_combat_stats", "stat_hp", "stat_atk", "stat_heal",
)
MAX_FIELDS = {"level", "student_star", "weapon_star", "weapon_level", "equip1_level", "equip2_level", "equip3_level"}
EQUIP_FIELDS = {"equip1", "equip2", "equip3", "equip4"}
STAT_FIELDS = {"stat_hp", "stat_atk", "stat_heal"}


@dataclass(frozen=True, slots=True)
class FieldDiff:
    field: str
    old: Any
    new: Any

    def to_dict(self) -> dict[str, Any]:
        return {"field": self.field, "old": self.old, "new": self.new}


@dataclass(frozen=True, slots=True)
class SnapshotResolution:
    snapshot: dict[str, dict[str, Any]]
    source: str
    sqlite_error: str | None = None


def _integer(value: Any) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _form_stats(old_value: Any, new_value: Any) -> dict[str, dict[str, Any]]:
    old = old_value if isinstance(old_value, dict) else {}
    new = new_value if isinstance(new_value, dict) else {}
    merged = {str(key): dict(value) for key, value in old.items() if isinstance(value, dict)}
    for key, stats in new.items():
        if not isinstance(stats, dict):
            continue
        current = dict(merged.get(str(key), {}))
        for field in ("combat_hp", "combat_atk", "combat_def", "combat_heal"):
            if stats.get(field) is not None:
                current[field] = stats[field]
            elif field not in current:
                current[field] = None
        if any(current.get(field) is not None for field in ("combat_hp", "combat_atk", "combat_def", "combat_heal")):
            merged[str(key)] = current
    return dict(sorted(merged.items()))


def merge_student(old: Mapping[str, Any], new: Mapping[str, Any], *, authoritative_fields: Iterable[str] = (), replace: bool = False) -> dict[str, Any]:
    authoritative = set(authoritative_fields)
    if replace:
        return {field: new.get(field) for field in STUDENT_FIELDS}
    result = dict(old)
    for field in STUDENT_FIELDS:
        old_value, new_value = old.get(field), new.get(field)
        if field == "form_combat_stats":
            result[field] = _form_stats(old_value, new_value)
        elif field == "weapon_state":
            if new_value is None or {old_value, new_value} == {"no_weapon_system", "weapon_equipped"}:
                result[field] = old_value
            else:
                result[field] = str(new_value)
        elif new_value is None:
            result[field] = old_value
        elif field in STAT_FIELDS:
            parsed = _integer(new_value)
            result[field] = parsed if parsed is not None and 0 <= parsed <= 25 else old_value
        elif field in EQUIP_FIELDS:
            result[field] = old_value if str(new_value) == "unknown" else str(new_value)
        elif field in MAX_FIELDS:
            old_int, new_int = _integer(old_value), _integer(new_value)
            if old_int is None:
                result[field] = new_int
            elif new_int is None:
                result[field] = old_int
            else:
                result[field] = new_int if field in authoritative else max(old_int, new_int)
        else:
            result[field] = new_value
    return result


def student_diff(old: Mapping[str, Any], merged: Mapping[str, Any]) -> list[FieldDiff]:
    return [FieldDiff(field, old.get(field), merged.get(field)) for field in STUDENT_FIELDS if old.get(field) != merged.get(field)]


def inventory_key(entry: Mapping[str, Any], fallback: str = "") -> str:
    return str(entry.get("item_id") or entry.get("name") or fallback).strip()


def _rank(entry: Mapping[str, Any]) -> tuple[int, int, int]:
    quantity = entry.get("quantity")
    return (int(quantity not in (None, "", "0")), int(bool(entry.get("item_id"))), len(str(quantity or "")))


def normalize_inventory(entries: Mapping[str, Mapping[str, Any]] | Sequence[Mapping[str, Any]]) -> dict[str, dict[str, Any]]:
    pairs = entries.items() if isinstance(entries, Mapping) else (("", item) for item in entries)
    result: dict[str, dict[str, Any]] = {}
    for fallback, raw in pairs:
        entry = dict(raw)
        key = inventory_key(entry, str(fallback))
        if not key:
            continue
        entry["key"] = key
        if key not in result or _rank(entry) > _rank(result[key]):
            result[key] = entry
    return {key: result[key] for key in sorted(result)}


def merge_inventory(old: Mapping[str, Mapping[str, Any]], new: Mapping[str, Mapping[str, Any]] | Sequence[Mapping[str, Any]], *, replace_profiles: Iterable[str] = (), scanned_profiles: Iterable[str] = ()) -> dict[str, dict[str, Any]]:
    current = normalize_inventory(old)
    incoming = normalize_inventory(new)
    profiles = set(replace_profiles) & set(scanned_profiles)
    if profiles:
        current = {key: entry for key, entry in current.items() if entry.get("profile_id") not in profiles}
    for key, entry in incoming.items():
        if entry.get("quantity") in (None, ""):
            continue
        previous = current.get(key, {})
        current[key] = {name: entry.get(name, previous.get(name)) for name in ("key", "item_id", "name", "quantity", "index", "profile_id")}
        current[key]["key"] = key
    return {key: current[key] for key in sorted(current)}


def order_inventory(snapshot: Mapping[str, Mapping[str, Any]], profile_order: Mapping[str, Sequence[str]]) -> list[dict[str, Any]]:
    normalized = normalize_inventory(snapshot)
    ordered: list[dict[str, Any]] = []
    consumed: set[str] = set()
    for profile_id, keys in profile_order.items():
        for index, key in enumerate(keys):
            entry = dict(normalized.get(key, {"key": key, "item_id": key, "name": None, "quantity": "0"}))
            entry["profile_id"] = profile_id
            entry["index"] = index
            ordered.append(entry)
            consumed.add(key)
    ordered.extend(normalized[key] for key in sorted(set(normalized) - consumed))
    return ordered


def inventory_diff(old: Mapping[str, Mapping[str, Any]], merged: Mapping[str, Mapping[str, Any]]) -> list[FieldDiff]:
    before, after = normalize_inventory(old), normalize_inventory(merged)
    result = []
    for key in sorted(after):
        old_quantity = before.get(key, {}).get("quantity")
        new_quantity = after[key].get("quantity")
        if old_quantity != new_quantity:
            result.append(FieldDiff(key, old_quantity, new_quantity))
    return result


def resolve_inventory_snapshot(sqlite_rows: Sequence[Mapping[str, Any]] | None, json_snapshot: Mapping[str, Mapping[str, Any]] | Sequence[Mapping[str, Any]] | None, *, sqlite_error: str | None = None) -> SnapshotResolution:
    sqlite = normalize_inventory(sqlite_rows or ())
    if sqlite:
        return SnapshotResolution(sqlite, "sqlite", sqlite_error)
    return SnapshotResolution(normalize_inventory(json_snapshot or {}), "json", sqlite_error)
