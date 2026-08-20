"""Generate the compact v1 student-stat catalog from SchaleDB JSON sources."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
from typing import Any
from urllib.parse import urlparse
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "data" / "student_stats" / "v1" / "catalog.json"
DEFAULT_STUDENTS_URL = "https://schaledb.com/data/en/students.min.json"
DEFAULT_EQUIPMENT_URL = "https://schaledb.com/data/en/equipment.min.json"
EQUIPMENT_TIER_MAX_LEVEL = {1: 10, 2: 20, 3: 30, 4: 40, 5: 45, 6: 50, 7: 55, 8: 60, 9: 65, 10: 70}
EQUIPMENT_CATEGORY_BASE_ID = {
    "Hat": 1000,
    "Gloves": 2000,
    "Shoes": 3000,
    "Bag": 4000,
    "Badge": 5000,
    "Hairpin": 6000,
    "Charm": 7000,
    "Watch": 8000,
    "Necklace": 9000,
}
PRIMARY_STAT_SOURCE_FIELDS = (
    ("MaxHP", "MaxHP1", "MaxHP100"),
    ("AttackPower", "AttackPower1", "AttackPower100"),
    ("DefensePower", "DefensePower1", "DefensePower100"),
    ("HealPower", "HealPower1", "HealPower100"),
)


def _read_source(source: str) -> tuple[bytes, str]:
    parsed = urlparse(source)
    if parsed.scheme in {"http", "https"}:
        request = Request(
            source,
            headers={"User-Agent": "BA-Planner-v7/1", "Accept": "application/json"},
        )
        with urlopen(request, timeout=60) as response:
            return response.read(), source
    path = Path(source).resolve()
    return path.read_bytes(), str(path)


def _records(payload: object, label: str) -> list[dict[str, Any]]:
    values = list(payload.values()) if isinstance(payload, dict) else payload
    if not isinstance(values, list) or not all(isinstance(item, dict) for item in values):
        raise ValueError(f"{label} must be an object or array of objects")
    return values


def _int(raw: dict[str, Any], key: str, label: str) -> int:
    value = raw.get(key)
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError(f"{label}.{key} must be an integer")
    return value


def _stat_ranges(stat_types: object, stat_values: object, label: str) -> list[list[object]]:
    if not isinstance(stat_types, list) or not isinstance(stat_values, list):
        raise ValueError(f"{label} StatType/StatValue must be arrays")
    if len(stat_types) != len(stat_values):
        raise ValueError(f"{label} StatType/StatValue lengths differ")
    result: list[list[object]] = []
    for stat, values in zip(stat_types, stat_values, strict=True):
        if (
            not isinstance(stat, str)
            or not stat
            or not isinstance(values, list)
            or len(values) != 2
            or any(not isinstance(item, int) or isinstance(item, bool) for item in values)
        ):
            raise ValueError(f"{label} contains an invalid stat range")
        result.append([stat, values[0], values[1]])
    return result


def _normalize_student(raw: dict[str, Any]) -> dict[str, object]:
    student_id = _int(raw, "Id", "student")
    path = str(raw.get("PathName") or "").strip().casefold()
    if not path:
        raise ValueError(f"student {student_id} has no PathName")
    equipment = raw.get("Equipment")
    if not isinstance(equipment, list) or len(equipment) != 3 or not all(
        isinstance(item, str) and item in EQUIPMENT_CATEGORY_BASE_ID for item in equipment
    ):
        raise ValueError(f"student {student_id} has invalid equipment categories")
    weapon = raw.get("Weapon")
    if not isinstance(weapon, dict):
        raise ValueError(f"student {student_id} has no weapon data")
    favor_types = raw.get("FavorStatType")
    favor_values = raw.get("FavorStatValue")
    favor_alts = raw.get("FavorAlts") or []
    if not isinstance(favor_types, list) or len(favor_types) != 2 or not all(
        isinstance(item, str) and item for item in favor_types
    ):
        raise ValueError(f"student {student_id} has invalid FavorStatType")
    if not isinstance(favor_values, list) or len(favor_values) != 7:
        raise ValueError(f"student {student_id} has invalid FavorStatValue")
    normalized_favor_values = []
    for pair in favor_values:
        if not isinstance(pair, list) or len(pair) != 2 or any(
            not isinstance(item, int) or isinstance(item, bool) for item in pair
        ):
            raise ValueError(f"student {student_id} has invalid FavorStatValue pair")
        normalized_favor_values.append(pair)
    if not isinstance(favor_alts, list) or not all(
        isinstance(item, int) and not isinstance(item, bool) for item in favor_alts
    ):
        raise ValueError(f"student {student_id} has invalid FavorAlts")
    gear = raw.get("Gear") if isinstance(raw.get("Gear"), dict) else {}
    released = gear.get("Released") if isinstance(gear, dict) else None
    released_values = list(released[:3]) if isinstance(released, list) else []
    released_values.extend([False] * (3 - len(released_values)))
    if not all(isinstance(item, bool) for item in released_values):
        raise ValueError(f"student {student_id} has invalid Gear.Released")
    favorite_gear = _stat_ranges(
        gear.get("StatType", []), gear.get("StatValue", []), f"student {student_id}.Gear"
    )
    return {
        "id": student_id,
        "path": path,
        "initial_star": _int(raw, "StarGrade", f"student {student_id}"),
        "growth_type": str(raw.get("StatGrowthType") or "Standard"),
        "base_stats": [
            [stat, _int(raw, level_1, f"student {student_id}"), _int(raw, level_100, f"student {student_id}")]
            for stat, level_1, level_100 in PRIMARY_STAT_SOURCE_FIELDS
        ],
        "equipment": equipment,
        "weapon": {
            "growth_type": str(weapon.get("StatLevelUpType") or "Standard"),
            "attack": [_int(weapon, "AttackPower1", "weapon"), _int(weapon, "AttackPower100", "weapon")],
            "max_hp": [_int(weapon, "MaxHP1", "weapon"), _int(weapon, "MaxHP100", "weapon")],
            "heal": [_int(weapon, "HealPower1", "weapon"), _int(weapon, "HealPower100", "weapon")],
        },
        "relationship": {
            "stat_types": favor_types,
            "values": normalized_favor_values,
            "alternate_ids": favor_alts,
        },
        "favorite_gear_released": released_values,
        "favorite_gear": favorite_gear,
    }


def _normalize_equipment(raw_records: list[dict[str, Any]]) -> list[dict[str, object]]:
    by_id = {
        item.get("Id"): item
        for item in raw_records
        if isinstance(item.get("Id"), int) and not isinstance(item.get("Id"), bool)
    }
    result: list[dict[str, object]] = []
    for category, base_id in EQUIPMENT_CATEGORY_BASE_ID.items():
        for tier, max_level in EQUIPMENT_TIER_MAX_LEVEL.items():
            item_id = base_id + tier - 1
            raw = by_id.get(item_id)
            if raw is None or raw.get("Category") != category or raw.get("Tier") != tier:
                raise ValueError(f"equipment source is missing canonical {category} Tier{tier}")
            result.append({
                "category": category,
                "tier": tier,
                "max_level": max_level,
                "stats": _stat_ranges(raw.get("StatType"), raw.get("StatValue"), f"equipment {item_id}"),
            })
    return result


def build_catalog(students_bytes: bytes, equipment_bytes: bytes, source: dict[str, str]) -> dict[str, object]:
    students_payload = json.loads(students_bytes)
    equipment_payload = json.loads(equipment_bytes)
    students = sorted(
        (_normalize_student(item) for item in _records(students_payload, "students")),
        key=lambda item: int(item["id"]),
    )
    return {
        "version": 1,
        "source": source,
        "students": students,
        "equipment": _normalize_equipment(_records(equipment_payload, "equipment")),
    }


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--students", default=DEFAULT_STUDENTS_URL)
    parser.add_argument("--equipment", default=DEFAULT_EQUIPMENT_URL)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    students_bytes, students_source = _read_source(args.students)
    equipment_bytes, equipment_source = _read_source(args.equipment)
    source = {
        "students": students_source,
        "students_sha256": hashlib.sha256(students_bytes).hexdigest(),
        "equipment": equipment_source,
        "equipment_sha256": hashlib.sha256(equipment_bytes).hexdigest(),
        "generator": "backend/tools/sync_student_stats_from_schaledb.py:v1",
    }
    catalog = build_catalog(students_bytes, equipment_bytes, source)
    rendered = json.dumps(catalog, ensure_ascii=False, separators=(",", ":"), sort_keys=True) + "\n"
    _atomic_write(args.output.resolve(), rendered)
    print(f"wrote {args.output}: {len(catalog['students'])} students, {len(catalog['equipment'])} equipment rows, {len(rendered.encode('utf-8'))} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
