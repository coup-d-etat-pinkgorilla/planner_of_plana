"""Pure Schale-compatible HP/ATK/DEF/HEAL calculation for student builds."""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_CEILING, ROUND_HALF_UP
from typing import Iterable

from core.planning_growth_rules import (
    EQUIPMENT_SLOT_UNLOCK_LEVEL,
    FAVORITE_ITEM_UNLOCK_BOND_RANK,
    STUDENT_STAR_MAX_BOND_RANK,
    WEAPON_STAR_MAX_LEVEL,
)
from core.student_stats_types import (
    EquipmentLevelV1,
    MissingStatDependencyV1,
    PRIMARY_STAT_NAMES,
    StatModifierV1,
    StatRangeV1,
    StudentStatBuildV1,
    StudentStatCalculationV1,
    StudentStatCatalogV1,
    StudentStatRecordV1,
)


_FOUR_PLACES = Decimal("0.0001")
_STAR_TRANSCENDENCE_BASIS_POINTS = {
    "AttackPower": (0, 1000, 1200, 1400, 1700),
    "MaxHP": (0, 500, 700, 900, 1400),
    "HealPower": (0, 750, 1000, 1200, 1500),
    "DefensePower": (0, 0, 0, 0, 0),
}


def _decimal(value: int | str | Decimal) -> Decimal:
    return value if isinstance(value, Decimal) else Decimal(str(value))


def _fixed4(value: Decimal) -> Decimal:
    return value.quantize(_FOUR_PLACES, rounding=ROUND_HALF_UP)


def _js_round_positive(value: Decimal) -> int:
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _schale_scale(level: int, maximum: int) -> Decimal:
    if maximum <= 1:
        return Decimal(0)
    return _fixed4(_decimal(level - 1) / _decimal(maximum - 1))


def interpolate_student_stat(
    level_1: int,
    level_100: int,
    level: int,
    transcendence_basis_points: int = 0,
) -> int:
    """Match Schale's toFixed(4) -> Math.round -> multiplier -> ceil order."""

    if not 1 <= level <= 100:
        raise ValueError("student level must be from 1 to 100")
    scale = _schale_scale(level, 100)
    interpolated = _fixed4(_decimal(level_1) + _decimal(level_100 - level_1) * scale)
    rounded = _js_round_positive(interpolated)
    multiplier = Decimal(1) + _decimal(transcendence_basis_points) / Decimal(10000)
    return int(_fixed4(_decimal(rounded) * multiplier).to_integral_value(rounding=ROUND_CEILING))


def interpolate_equipment_stat(stat: StatRangeV1, level: int, max_level: int) -> int:
    """Interpolate a tier's start/end stat using Schale's four-decimal scale."""

    if not 1 <= level <= max_level:
        raise ValueError(f"equipment level must be from 1 to {max_level}")
    scale = _schale_scale(level, max_level)
    value = _fixed4(_decimal(stat.level_1) + _decimal(stat.level_max - stat.level_1) * scale)
    return _js_round_positive(value)


def interpolate_weapon_stat(level_1: int, level_100: int, level: int, growth_type: str) -> int:
    if not 1 <= level <= 100:
        raise ValueError("weapon level must be from 1 to 100")
    scale = _decimal(level - 1) / Decimal(99)
    if growth_type == "Standard":
        scale = _fixed4(scale)
    return _js_round_positive(_decimal(level_1) + _decimal(level_100 - level_1) * scale)


def relationship_stat_values(student: StudentStatRecordV1, rank: int) -> dict[str, int]:
    if not 1 <= rank <= 100:
        raise ValueError("relationship rank must be from 1 to 100")
    totals = [0, 0]
    for index in range(1, min(rank, 50)):
        range_index = index // 5 if index < 20 else 2 + index // 10
        totals[0] += student.relationship.values[range_index][0]
        totals[1] += student.relationship.values[range_index][1]
    result: dict[str, int] = {}
    for stat, amount in zip(student.relationship.stat_types, totals, strict=True):
        result[stat] = result.get(stat, 0) + amount
    return result


@dataclass(slots=True)
class _MutableModifier:
    flat: dict[str, int] = field(default_factory=dict)
    coefficient_basis_points: dict[str, int] = field(default_factory=dict)
    separated_flat: dict[str, int] = field(default_factory=dict)

    def add(self, stat: str, amount: int) -> None:
        if stat.endswith("_Coefficient"):
            target = self.coefficient_basis_points
            key = stat.removesuffix("_Coefficient")
        elif stat.endswith("_Base"):
            target = self.separated_flat
            key = stat.removesuffix("_Base")
        else:
            target = self.flat
            key = stat
        target[key] = target.get(key, 0) + amount

    def freeze(self) -> StatModifierV1:
        return StatModifierV1(
            flat=dict(self.flat),
            coefficient_basis_points=dict(self.coefficient_basis_points),
            separated_flat=dict(self.separated_flat),
        )


def _modifier(contributions: dict[str, _MutableModifier], source: str) -> _MutableModifier:
    return contributions.setdefault(source, _MutableModifier())


def _add_values(modifier: _MutableModifier, values: dict[str, int], suffix: str = "") -> None:
    for stat, amount in values.items():
        modifier.add(stat + suffix, amount)


def _star_basis_points(stat: str, star: int) -> int:
    return sum(_STAR_TRANSCENDENCE_BASIS_POINTS[stat][:star])


def _base_values(student: StudentStatRecordV1, build: StudentStatBuildV1) -> dict[str, int]:
    return {
        item.stat: interpolate_student_stat(
            item.level_1,
            item.level_max,
            build.level,
            _star_basis_points(item.stat, build.star),
        )
        for item in student.base_stats
    }


def _validate_build(student: StudentStatRecordV1, build: StudentStatBuildV1) -> None:
    if not 1 <= build.level <= 100:
        raise ValueError("student level must be from 1 to 100")
    if not student.initial_star <= build.star <= 5:
        raise ValueError(f"student star must be from {student.initial_star} to 5")
    if build.relationship.current_rank is not None:
        rank = build.relationship.current_rank
        if not 1 <= rank <= STUDENT_STAR_MAX_BOND_RANK[build.star]:
            raise ValueError("current relationship rank exceeds the student-star cap")
    for alternate_id, rank in build.relationship.alternate_ranks.items():
        if not isinstance(alternate_id, int) or alternate_id < 1:
            raise ValueError("alternate relationship ids must be positive integers")
        if rank is not None and not 1 <= rank <= 100:
            raise ValueError("alternate relationship ranks must be from 1 to 100")
    if build.weapon is not None:
        maximum = WEAPON_STAR_MAX_LEVEL.get(build.weapon.star)
        if maximum is None or build.weapon.star < 1:
            raise ValueError("weapon star must be from 1 to 4")
        if build.star < 5:
            raise ValueError("unique weapon requires a 5-star student")
        if not 1 <= build.weapon.level <= maximum:
            raise ValueError(f"weapon level exceeds the {build.weapon.star}-star cap")
    if not 0 <= build.favorite_gear_tier <= 2:
        raise ValueError("favorite gear tier must be from 0 to 2")
    potential = build.potential
    if any(not 0 <= value <= 25 for value in (potential.max_hp, potential.attack, potential.heal)):
        raise ValueError("potential levels must be from 0 to 25")
    if any((potential.max_hp, potential.attack, potential.heal)) and (
        build.level < 90 or build.star < 5
    ):
        raise ValueError("potential requires a level 90, 5-star student")


def _equipment_contributions(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    catalog: StudentStatCatalogV1,
    contributions: dict[str, _MutableModifier],
    missing: list[MissingStatDependencyV1],
) -> None:
    for slot, (category, equipped) in enumerate(zip(student.equipment, build.equipment, strict=True), 1):
        unlock_level = EQUIPMENT_SLOT_UNLOCK_LEVEL.get(slot, 1)
        if build.level < unlock_level:
            if equipped is not None:
                raise ValueError(f"equipment slot {slot} is locked until student level {unlock_level}")
            continue
        if equipped is None:
            missing.append(MissingStatDependencyV1("equipment", f"slot:{slot}"))
            continue
        record = catalog.equipment.get((category, equipped.tier))
        if record is None:
            raise ValueError(f"equipment static data is missing for {category} Tier{equipped.tier}")
        if equipped.level < 1 or equipped.level > record.max_level:
            raise ValueError(
                f"equipment slot {slot} level must be from 1 to {record.max_level}"
            )
        target = _modifier(contributions, f"equipment_{slot}")
        for stat in record.stats:
            target.add(stat.stat, interpolate_equipment_stat(stat, equipped.level, record.max_level))


def _weapon_contribution(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    contributions: dict[str, _MutableModifier],
) -> None:
    if build.weapon is None:
        return
    weapon = student.weapon
    level = build.weapon.level
    target = _modifier(contributions, "unique_weapon")
    for stat, values in (
        ("AttackPower_Base", weapon.attack),
        ("MaxHP_Base", weapon.max_hp),
        ("HealPower_Base", weapon.heal),
    ):
        target.add(stat, interpolate_weapon_stat(values[0], values[1], level, weapon.growth_type))


def _relationship_contributions(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    catalog: StudentStatCatalogV1,
    contributions: dict[str, _MutableModifier],
    missing: list[MissingStatDependencyV1],
) -> None:
    target = _modifier(contributions, "relationship")
    if build.relationship.current_rank is None:
        missing.append(MissingStatDependencyV1("current_relationship", str(student.schaledb_id)))
    else:
        _add_values(target, relationship_stat_values(student, build.relationship.current_rank))

    expected_alternates = set(student.relationship.alternate_ids)
    unknown_inputs = (
        set(build.relationship.alternate_ranks) | set(build.relationship.unowned_alternate_ids)
    ) - expected_alternates
    if unknown_inputs:
        raise ValueError(f"relationship input contains unrelated alternate ids: {sorted(unknown_inputs)}")
    for alternate_id in student.relationship.alternate_ids:
        if alternate_id in build.relationship.unowned_alternate_ids:
            continue
        rank = build.relationship.alternate_ranks.get(alternate_id)
        if rank is None:
            missing.append(
                MissingStatDependencyV1("alternate_relationship", str(alternate_id))
            )
            continue
        alternate = catalog.students.get(alternate_id)
        if alternate is None:
            missing.append(MissingStatDependencyV1("alternate_static_data", str(alternate_id)))
            continue
        _add_values(target, relationship_stat_values(alternate, rank))


def _favorite_gear_contribution(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    contributions: dict[str, _MutableModifier],
) -> None:
    if build.favorite_gear_tier == 0:
        return
    if not student.favorite_gear or not any(student.favorite_gear_released):
        raise ValueError("favorite gear is not available for this student")
    current_rank = build.relationship.current_rank
    minimum_rank = FAVORITE_ITEM_UNLOCK_BOND_RANK[build.favorite_gear_tier]
    if current_rank is not None and current_rank < minimum_rank:
        raise ValueError(
            f"favorite gear Tier{build.favorite_gear_tier} requires relationship rank {minimum_rank}"
        )
    target = _modifier(contributions, "favorite_gear")
    for stat in student.favorite_gear:
        target.add(stat.stat, stat.level_max)


def _potential_contribution(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    contributions: dict[str, _MutableModifier],
) -> None:
    levels = {
        "MaxHP": build.potential.max_hp,
        "AttackPower": build.potential.attack,
        "HealPower": build.potential.heal,
    }
    target = _modifier(contributions, "potential")
    base_by_stat = {item.stat: item for item in student.base_stats}
    for stat, potential_level in levels.items():
        if potential_level == 0:
            continue
        raw = base_by_stat[stat]
        level_value = interpolate_student_stat(raw.level_1, raw.level_max, build.level)
        amount = _js_round_positive(_decimal(level_value) * _decimal(potential_level) * Decimal("0.002"))
        target.add(stat + "_Base", amount)


def _totals(contributions: Iterable[_MutableModifier]) -> dict[str, int]:
    flat = {stat: 0 for stat in PRIMARY_STAT_NAMES}
    coefficient = {stat: 10000 for stat in PRIMARY_STAT_NAMES}
    separated = {stat: 0 for stat in PRIMARY_STAT_NAMES}
    for source in contributions:
        for stat, value in source.flat.items():
            if stat in flat:
                flat[stat] += value
        for stat, value in source.coefficient_basis_points.items():
            if stat in coefficient:
                coefficient[stat] += value
        for stat, value in source.separated_flat.items():
            if stat in separated:
                separated[stat] += value
    return {
        stat: max(
            0,
            _js_round_positive(
                _fixed4(_decimal(flat[stat]) * _decimal(coefficient[stat]) / Decimal(10000))
            )
            + separated[stat],
        )
        for stat in PRIMARY_STAT_NAMES
    }


def calculate_student_stats(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    catalog: StudentStatCatalogV1,
) -> StudentStatCalculationV1:
    """Calculate exact totals or an explicitly non-exact partial when inputs are missing."""

    _validate_build(student, build)
    contributions: dict[str, _MutableModifier] = {}
    missing: list[MissingStatDependencyV1] = []
    _add_values(_modifier(contributions, "base"), _base_values(student, build))
    _equipment_contributions(student, build, catalog, contributions, missing)
    _weapon_contribution(student, build, contributions)
    _relationship_contributions(student, build, catalog, contributions, missing)
    _favorite_gear_contribution(student, build, contributions)
    _potential_contribution(student, build, contributions)
    partial_values = _totals(contributions.values())
    return StudentStatCalculationV1(
        status="dependency_missing" if missing else "complete",
        values=None if missing else partial_values,
        partial_values=partial_values,
        missing_dependencies=tuple(missing),
        contributions={name: value.freeze() for name, value in contributions.items()},
    )
