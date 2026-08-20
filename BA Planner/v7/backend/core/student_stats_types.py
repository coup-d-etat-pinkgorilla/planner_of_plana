"""Versioned, UI-free contracts for student stat calculation."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Literal, Mapping


STUDENT_STATS_DTO_VERSION = 1
PRIMARY_STAT_NAMES = ("MaxHP", "AttackPower", "DefensePower", "HealPower")


class StudentStatsDataError(ValueError):
    """Raised when generated static stat data violates the v1 contract."""


@dataclass(frozen=True, slots=True)
class StatRangeV1:
    stat: str
    level_1: int
    level_max: int

    @classmethod
    def from_list(cls, value: object, label: str) -> "StatRangeV1":
        if not isinstance(value, list) or len(value) != 3:
            raise StudentStatsDataError(f"{label} must be [stat, level_1, level_max]")
        stat, level_1, level_max = value
        if not isinstance(stat, str) or not stat:
            raise StudentStatsDataError(f"{label}[0] must be a non-empty stat name")
        if any(not isinstance(item, int) or isinstance(item, bool) for item in (level_1, level_max)):
            raise StudentStatsDataError(f"{label} values must be integers")
        return cls(stat=stat, level_1=level_1, level_max=level_max)


@dataclass(frozen=True, slots=True)
class WeaponStatsV1:
    growth_type: str
    attack: tuple[int, int]
    max_hp: tuple[int, int]
    heal: tuple[int, int]

    @classmethod
    def from_dict(cls, value: object, label: str) -> "WeaponStatsV1":
        data = _object(value, label)
        _strict(data, {"growth_type", "attack", "max_hp", "heal"}, label)
        return cls(
            growth_type=_text(data["growth_type"], f"{label}.growth_type"),
            attack=_int_pair(data["attack"], f"{label}.attack"),
            max_hp=_int_pair(data["max_hp"], f"{label}.max_hp"),
            heal=_int_pair(data["heal"], f"{label}.heal"),
        )


@dataclass(frozen=True, slots=True)
class RelationshipStatsV1:
    stat_types: tuple[str, str]
    values: tuple[tuple[int, int], ...]
    alternate_ids: tuple[int, ...]

    @classmethod
    def from_dict(cls, value: object, label: str) -> "RelationshipStatsV1":
        data = _object(value, label)
        _strict(data, {"stat_types", "values", "alternate_ids"}, label)
        stat_types_raw = data["stat_types"]
        values_raw = data["values"]
        alternate_ids_raw = data["alternate_ids"]
        if (
            not isinstance(stat_types_raw, list)
            or len(stat_types_raw) != 2
            or not all(isinstance(item, str) and item for item in stat_types_raw)
        ):
            raise StudentStatsDataError(f"{label}.stat_types must contain two stat names")
        if not isinstance(values_raw, list) or len(values_raw) != 7:
            raise StudentStatsDataError(f"{label}.values must contain seven relationship ranges")
        values = tuple(_int_pair(item, f"{label}.values") for item in values_raw)
        if not isinstance(alternate_ids_raw, list) or not all(
            isinstance(item, int) and not isinstance(item, bool) and item > 0
            for item in alternate_ids_raw
        ):
            raise StudentStatsDataError(f"{label}.alternate_ids must contain positive integers")
        return cls(
            stat_types=(stat_types_raw[0], stat_types_raw[1]),
            values=values,
            alternate_ids=tuple(alternate_ids_raw),
        )


@dataclass(frozen=True, slots=True)
class StudentStatRecordV1:
    schaledb_id: int
    path: str
    initial_star: int
    growth_type: str
    base_stats: tuple[StatRangeV1, ...]
    equipment: tuple[str, str, str]
    weapon: WeaponStatsV1
    relationship: RelationshipStatsV1
    favorite_gear_released: tuple[bool, bool, bool]
    favorite_gear: tuple[StatRangeV1, ...]

    @classmethod
    def from_dict(cls, value: object, label: str = "student") -> "StudentStatRecordV1":
        data = _object(value, label)
        _strict(
            data,
            {
                "id", "path", "initial_star", "growth_type", "base_stats", "equipment",
                "weapon", "relationship", "favorite_gear_released", "favorite_gear",
            },
            label,
        )
        schaledb_id = _positive_int(data["id"], f"{label}.id")
        initial_star = _positive_int(data["initial_star"], f"{label}.initial_star")
        if initial_star > 5:
            raise StudentStatsDataError(f"{label}.initial_star must be at most 5")
        base_raw = data["base_stats"]
        equipment_raw = data["equipment"]
        released_raw = data["favorite_gear_released"]
        favorite_raw = data["favorite_gear"]
        if not isinstance(base_raw, list):
            raise StudentStatsDataError(f"{label}.base_stats must be an array")
        base_stats = tuple(StatRangeV1.from_list(item, f"{label}.base_stats") for item in base_raw)
        if tuple(item.stat for item in base_stats) != PRIMARY_STAT_NAMES:
            raise StudentStatsDataError(f"{label}.base_stats must use the canonical primary-stat order")
        if not isinstance(equipment_raw, list) or len(equipment_raw) != 3 or not all(
            isinstance(item, str) and item for item in equipment_raw
        ):
            raise StudentStatsDataError(f"{label}.equipment must contain three categories")
        if not isinstance(released_raw, list) or len(released_raw) != 3 or not all(
            isinstance(item, bool) for item in released_raw
        ):
            raise StudentStatsDataError(f"{label}.favorite_gear_released must contain three booleans")
        if not isinstance(favorite_raw, list):
            raise StudentStatsDataError(f"{label}.favorite_gear must be an array")
        return cls(
            schaledb_id=schaledb_id,
            path=_text(data["path"], f"{label}.path"),
            initial_star=initial_star,
            growth_type=_text(data["growth_type"], f"{label}.growth_type"),
            base_stats=base_stats,
            equipment=(equipment_raw[0], equipment_raw[1], equipment_raw[2]),
            weapon=WeaponStatsV1.from_dict(data["weapon"], f"{label}.weapon"),
            relationship=RelationshipStatsV1.from_dict(
                data["relationship"], f"{label}.relationship"
            ),
            favorite_gear_released=(released_raw[0], released_raw[1], released_raw[2]),
            favorite_gear=tuple(
                StatRangeV1.from_list(item, f"{label}.favorite_gear") for item in favorite_raw
            ),
        )


@dataclass(frozen=True, slots=True)
class EquipmentStatRecordV1:
    category: str
    tier: int
    max_level: int
    stats: tuple[StatRangeV1, ...]

    @classmethod
    def from_dict(cls, value: object, label: str = "equipment") -> "EquipmentStatRecordV1":
        data = _object(value, label)
        _strict(data, {"category", "tier", "max_level", "stats"}, label)
        stats_raw = data["stats"]
        if not isinstance(stats_raw, list):
            raise StudentStatsDataError(f"{label}.stats must be an array")
        return cls(
            category=_text(data["category"], f"{label}.category"),
            tier=_positive_int(data["tier"], f"{label}.tier"),
            max_level=_positive_int(data["max_level"], f"{label}.max_level"),
            stats=tuple(StatRangeV1.from_list(item, f"{label}.stats") for item in stats_raw),
        )


@dataclass(frozen=True, slots=True)
class StudentStatCatalogV1:
    students: Mapping[int, StudentStatRecordV1]
    equipment: Mapping[tuple[str, int], EquipmentStatRecordV1]
    paths: Mapping[str, int]
    source: Mapping[str, str]
    version: int = STUDENT_STATS_DTO_VERSION

    @classmethod
    def from_dict(cls, value: object) -> "StudentStatCatalogV1":
        data = _object(value, "student_stat_catalog")
        _strict(data, {"version", "source", "students", "equipment"}, "student_stat_catalog")
        if data["version"] != STUDENT_STATS_DTO_VERSION or isinstance(data["version"], bool):
            raise StudentStatsDataError(
                f"student_stat_catalog.version must be {STUDENT_STATS_DTO_VERSION}"
            )
        source_raw = _object(data["source"], "student_stat_catalog.source")
        if not all(isinstance(key, str) and isinstance(item, str) for key, item in source_raw.items()):
            raise StudentStatsDataError("student_stat_catalog.source must map strings to strings")
        students_raw = data["students"]
        equipment_raw = data["equipment"]
        if not isinstance(students_raw, list) or not isinstance(equipment_raw, list):
            raise StudentStatsDataError("student_stat_catalog students/equipment must be arrays")
        students: dict[int, StudentStatRecordV1] = {}
        paths: dict[str, int] = {}
        for index, raw in enumerate(students_raw):
            record = StudentStatRecordV1.from_dict(raw, f"student_stat_catalog.students[{index}]")
            if record.schaledb_id in students or record.path in paths:
                raise StudentStatsDataError("student_stat_catalog student ids and paths must be unique")
            students[record.schaledb_id] = record
            paths[record.path] = record.schaledb_id
        equipment: dict[tuple[str, int], EquipmentStatRecordV1] = {}
        for index, raw in enumerate(equipment_raw):
            record = EquipmentStatRecordV1.from_dict(
                raw, f"student_stat_catalog.equipment[{index}]"
            )
            key = (record.category, record.tier)
            if key in equipment:
                raise StudentStatsDataError(f"duplicate equipment record: {key}")
            equipment[key] = record
        return cls(students=students, equipment=equipment, paths=paths, source=dict(source_raw))


@dataclass(frozen=True, slots=True)
class EquipmentLevelV1:
    tier: int
    level: int


@dataclass(frozen=True, slots=True)
class UniqueWeaponLevelV1:
    star: int
    level: int


@dataclass(frozen=True, slots=True)
class PotentialLevelsV1:
    max_hp: int = 0
    attack: int = 0
    heal: int = 0


@dataclass(frozen=True, slots=True)
class RelationshipLevelsV1:
    current_rank: int | None
    alternate_ranks: Mapping[int, int | None]
    unowned_alternate_ids: frozenset[int] = frozenset()


@dataclass(frozen=True, slots=True)
class StudentStatBuildV1:
    level: int
    star: int
    equipment: tuple[EquipmentLevelV1 | None, EquipmentLevelV1 | None, EquipmentLevelV1 | None]
    relationship: RelationshipLevelsV1
    weapon: UniqueWeaponLevelV1 | None = None
    favorite_gear_tier: int = 0
    potential: PotentialLevelsV1 = PotentialLevelsV1()


@dataclass(frozen=True, slots=True)
class MissingStatDependencyV1:
    kind: Literal["current_relationship", "alternate_relationship", "alternate_static_data", "equipment"]
    key: str


@dataclass(frozen=True, slots=True)
class StatModifierV1:
    flat: Mapping[str, int]
    coefficient_basis_points: Mapping[str, int]
    separated_flat: Mapping[str, int]


@dataclass(frozen=True, slots=True)
class StudentStatCalculationV1:
    status: Literal["complete", "dependency_missing"]
    values: Mapping[str, int] | None
    partial_values: Mapping[str, int]
    missing_dependencies: tuple[MissingStatDependencyV1, ...]
    contributions: Mapping[str, StatModifierV1]
    version: int = STUDENT_STATS_DTO_VERSION


def _object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise StudentStatsDataError(f"{label} must be an object")
    return value


def _strict(data: Mapping[str, object], fields: set[str], label: str) -> None:
    unknown = set(data) - fields
    missing = fields - set(data)
    if unknown:
        raise StudentStatsDataError(f"{label} contains unknown fields: {sorted(unknown)}")
    if missing:
        raise StudentStatsDataError(f"{label} is missing fields: {sorted(missing)}")


def _text(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise StudentStatsDataError(f"{label} must be a non-empty string")
    return value


def _positive_int(value: object, label: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 1:
        raise StudentStatsDataError(f"{label} must be a positive integer")
    return value


def _int_pair(value: object, label: str) -> tuple[int, int]:
    if not isinstance(value, list) or len(value) != 2 or any(
        not isinstance(item, int) or isinstance(item, bool) for item in value
    ):
        raise StudentStatsDataError(f"{label} must contain two integers")
    return value[0], value[1]
