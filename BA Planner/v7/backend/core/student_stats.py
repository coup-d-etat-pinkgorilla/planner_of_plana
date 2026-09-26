"""Pure HP/ATK/DEF/HEAL calculation for student builds, using the in-client formulas.

The formulas were read from the JP client (1.73) and are documented with their source methods in
data/extracted/GAME_RULES.md section 4 (BattleEntityStatFactory.CalcLevelStat / CalcEquipmentLevelStat,
StatService.StatPerLevel, StatService.HeroStatProcessorGetDefaultValueFloatCalculation).
They replace the earlier SchaleDB-style four-decimal interpolation, which drifted from the game by 1-3
points at mid equipment levels, with combined star+potential rounding and for non-Standard weapons
(verified in game 2026-09-26: Bag T1 Lv2 MaxHP 418; SchaleDB style gave 400).

Arithmetic mirrors the client: 32-bit float products, Math.Round(MidpointRounding.AwayFromZero)
and a single ceiling for the star + potential bonus.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import math
import struct
from typing import Iterable

from core.planning_growth_rules import (
    EQUIPMENT_SLOT_UNLOCK_LEVEL,
    FAVORITE_ITEM_UNLOCK_BOND_RANK,
    STUDENT_STAR_MAX_BOND_RANK,
    WEAPON_STAR_MAX_LEVEL,
)
from core.student_stats_types import (
    EquipmentAbsentV1,
    EquipmentLevelV1,
    MissingStatDependencyV1,
    PRIMARY_STAT_NAMES,
    StatModifierV1,
    StatRangeV1,
    StudentStatBuildV1,
    StudentStatCalculationV1,
    StudentStatCatalogV1,
    StudentStatFormulaV1,
    StudentStatRecordV1,
)


_POTENTIAL_STAT_BY_BUILD_FIELD = {"max_hp": "MaxHP", "attack": "AttackPower", "heal": "HealPower"}


def _f32(value: float) -> float:
    """Round a Python float to IEEE-754 single precision (the client computes in float)."""

    return struct.unpack("<f", struct.pack("<f", value))[0]


_F32_TEN_THOUSANDTH = _f32(0.0001)


def _round_away(value: float) -> int:
    """C# Math.Round(value, MidpointRounding.AwayFromZero)."""

    return int(math.floor(value + 0.5)) if value >= 0 else -int(math.floor(-value + 0.5))


def default_formula() -> StudentStatFormulaV1:
    from core.student_stats_catalog import load_student_stat_formula

    return load_student_stat_formula()


def _growth_index(formula: StudentStatFormulaV1, growth_type: str) -> int:
    try:
        return formula.growth_types[growth_type]
    except KeyError as exc:
        raise ValueError(f"unknown stat growth type: {growth_type}") from exc


def level_ratio(formula: StudentStatFormulaV1, growth_type: str, level: int) -> float:
    """StatLevelInterpolationData.GetStatRatio: idx[level] / idx[end] as float, 0 if no row."""

    column = _growth_index(formula, growth_type)
    row = formula.level_interpolation.get(level)
    end = formula.level_interpolation[formula.end_level]
    if row is None or column >= len(row) or column >= len(end) or end[column] == 0:
        return 0.0
    return _f32(_f32(float(row[column])) / _f32(float(end[column])))


def _level_stat(formula: StudentStatFormulaV1, growth_type: str, level_1: int, level_100: int, level: int) -> int:
    if level == 1:
        return level_1
    ratio = level_ratio(formula, growth_type, level)
    return level_1 + _round_away(_f32(_f32(float(level_100 - level_1)) * ratio))


def _bonus_rate_basis_points(
    formula: StudentStatFormulaV1, student_id: int, stat: str, star: int, potential_level: int
) -> int:
    trans = formula.transcendence.get(student_id, {}).get(stat, formula.transcendence_default.get(stat, ()))
    rate = sum(trans[:star])
    if potential_level:
        levels = formula.potential.get(student_id, {}).get(stat, formula.potential_default.get(stat, ()))
        if potential_level >= len(levels):
            raise ValueError(f"potential level {potential_level} has no rate for {stat}")
        rate += levels[potential_level]
    return rate


def _apply_bonus_rate(base: int, rate_basis_points: int) -> int:
    """StatService.StatPerLevel: base + ceil(float(base * rate) * 0.0001f)."""

    if not rate_basis_points:
        return base
    return base + int(math.ceil(_f32(_f32(float(base * rate_basis_points)) * _F32_TEN_THOUSANDTH)))


def interpolate_student_stat(
    level_1: int,
    level_100: int,
    level: int,
    transcendence_basis_points: int = 0,
    *,
    growth_type: str = "Standard",
    formula: StudentStatFormulaV1 | None = None,
) -> int:
    """In-client level stat with an optional star/potential bonus rate (basis points)."""

    if not 1 <= level <= 100:
        raise ValueError("student level must be from 1 to 100")
    formula = formula or default_formula()
    return _apply_bonus_rate(_level_stat(formula, growth_type, level_1, level_100, level), transcendence_basis_points)


def _equipment_level_value(
    formula: StudentStatFormulaV1, growth_type: str, minimum: int, maximum: int, level: int, max_level: int
) -> int:
    """BattleEntityStatFactory.CalcEquipmentLevelStat: the item level is mapped onto the 1..100
    interpolation table with RoundAway(level * (end / max_level)) before the level ratio is used."""

    if level == 1:
        return minimum
    step = _f32(_f32(float(formula.end_level)) / _f32(float(max_level)))
    scaled_level = _round_away(_f32(_f32(float(level)) * step))
    ratio = level_ratio(formula, growth_type, scaled_level)
    return minimum + _round_away(_f32(_f32(float(maximum - minimum)) * ratio))


def interpolate_equipment_stat(
    stat: StatRangeV1, level: int, max_level: int, *, formula: StudentStatFormulaV1 | None = None
) -> int:
    """In-client equipment stat for an item level (equipment uses the Standard growth column)."""

    if not 1 <= level <= max_level:
        raise ValueError(f"equipment level must be from 1 to {max_level}")
    formula = formula or default_formula()
    return _equipment_level_value(formula, "Standard", stat.level_1, stat.level_max, level, max_level)


def interpolate_weapon_stat(
    level_1: int,
    level_100: int,
    level: int,
    growth_type: str,
    *,
    formula: StudentStatFormulaV1 | None = None,
) -> int:
    """In-client unique weapon stat (the equipment formula with a 100-level scale)."""

    if not 1 <= level <= 100:
        raise ValueError("weapon level must be from 1 to 100")
    formula = formula or default_formula()
    return _equipment_level_value(formula, growth_type, level_1, level_100, level, formula.end_level)


def relationship_stat_values(student: StudentStatRecordV1, rank: int) -> dict[str, int]:
    if not 1 <= rank <= 100:
        raise ValueError("relationship rank must be from 1 to 100")
    totals = [0, 0]
    increments = student.relationship.increments
    for index in range(1, min(rank, 50)):
        if increments is not None:
            pair = increments[index - 1]          # reaching rank index + 1
        else:
            pair = student.relationship.values[index // 5 if index < 20 else 2 + index // 10]
        totals[0] += pair[0]
        totals[1] += pair[1]
    result: dict[str, int] = {}
    for stat, amount in zip(student.relationship.stat_types, totals, strict=True):
        result[stat] = result.get(stat, 0) + amount
    return result


@dataclass(slots=True)
class _MutableModifier:
    flat: dict[str, int] = field(default_factory=dict)
    coefficient_basis_points: dict[str, int] = field(default_factory=dict)
    separated_flat: dict[str, int] = field(default_factory=dict)

    def add(self, stat: str, amount: int, *, separated_flat: bool = False) -> None:
        if stat.endswith("_Coefficient"):
            target = self.coefficient_basis_points
            key = stat.removesuffix("_Coefficient")
        elif stat.endswith("_Base"):
            # The game's ``*_Base`` values join the multiplier-eligible flat
            # bucket.  This includes equipment, unique-weapon and potential
            # bonuses.  A non-multiplying flat value is an explicit call-site
            # property; it is not implied by the ``_Base`` suffix.
            target = self.separated_flat if separated_flat else self.flat
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


def _potential_levels(build: StudentStatBuildV1) -> dict[str, int]:
    return {stat: getattr(build.potential, field) for field, stat in _POTENTIAL_STAT_BY_BUILD_FIELD.items()}


def _base_values(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    formula: StudentStatFormulaV1,
    *,
    include_potential: bool,
) -> dict[str, int]:
    """Level stat plus the star bonus (and, when asked, the potential bonus) rounded up once."""

    potential = _potential_levels(build) if include_potential else {}
    result = {}
    for item in student.base_stats:
        level_value = _level_stat(formula, student.growth_type, item.level_1, item.level_max, build.level)
        rate = _bonus_rate_basis_points(
            formula, student.schaledb_id, item.stat, build.star, potential.get(item.stat, 0)
        )
        result[item.stat] = _apply_bonus_rate(level_value, rate)
    return result


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
    if build.passive_skill_level is not None and not 1 <= build.passive_skill_level <= 10:
        raise ValueError("passive skill level must be from 1 to 10")


def _equipment_contributions(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    catalog: StudentStatCatalogV1,
    contributions: dict[str, _MutableModifier],
    missing: list[MissingStatDependencyV1],
    formula: StudentStatFormulaV1,
) -> None:
    for slot, (category, equipped) in enumerate(zip(student.equipment, build.equipment, strict=True), 1):
        unlock_level = EQUIPMENT_SLOT_UNLOCK_LEVEL.get(slot, 1)
        if build.level < unlock_level:
            if equipped is not None and not isinstance(equipped, EquipmentAbsentV1):
                raise ValueError(f"equipment slot {slot} is locked until student level {unlock_level}")
            continue
        if isinstance(equipped, EquipmentAbsentV1):
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
            target.add(stat.stat, interpolate_equipment_stat(stat, equipped.level, record.max_level, formula=formula))


def _weapon_contribution(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    contributions: dict[str, _MutableModifier],
    formula: StudentStatFormulaV1,
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
        target.add(stat, interpolate_weapon_stat(values[0], values[1], level, weapon.growth_type, formula=formula))


def _relationship_contributions(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    catalog: StudentStatCatalogV1,
    contributions: dict[str, _MutableModifier],
    missing: list[MissingStatDependencyV1],
) -> None:
    if build.relationship.current_rank is None:
        missing.append(MissingStatDependencyV1("current_relationship", str(student.schaledb_id)))
    else:
        _add_values(
            _modifier(contributions, f"relationship_current_{student.schaledb_id}"),
            relationship_stat_values(student, build.relationship.current_rank),
        )

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
        _add_values(
            _modifier(contributions, f"relationship_alternate_{alternate_id}"),
            relationship_stat_values(alternate, rank),
        )


def _passive_skill_contribution(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    contributions: dict[str, _MutableModifier],
    missing: list[MissingStatDependencyV1],
    *,
    include_skill_buffs: bool,
) -> None:
    if not include_skill_buffs:
        return
    if build.star < 2:
        return
    level = build.passive_skill_level
    if level is None:
        missing.append(MissingStatDependencyV1("passive_skill", "skill2"))
        return
    target = _modifier(contributions, "passive_skill")
    for effect in student.passive_skill:
        target.add(effect.stat, effect.values[level - 1])
    if build.weapon is not None and build.weapon.star >= 2:
        weapon_target = _modifier(contributions, "weapon_passive_skill")
        for effect in student.weapon_passive_skill:
            weapon_target.add(effect.stat, effect.values[level - 1])


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
    formula: StudentStatFormulaV1,
    base_without_potential: dict[str, int],
) -> None:
    """Potential (ability release) adds its rate to the star rate before the single ceiling.

    The combined base is split into ``base`` (star only) and this ``potential`` part so evidence
    still shows the potential share; both land in the same multiplier-eligible flat bucket.
    """

    if not any(_potential_levels(build).values()):
        return
    combined = _base_values(student, build, formula, include_potential=True)
    target = _modifier(contributions, "potential")
    for stat, value in combined.items():
        amount = value - base_without_potential[stat]
        if amount:
            target.add(stat + "_Base", amount)


def _totals(contributions: Iterable[_MutableModifier]) -> dict[str, int]:
    """HeroStatProcessorGetDefaultValueFloatCalculation, then RoundAway:
    final = RoundAway(float((A + B) + float(C * (A + B)) * 0.0001f)) + separated flat,
    with A + B the multiplier-eligible flat sum and C the coefficient sum above 100%."""

    flat = {stat: 0 for stat in PRIMARY_STAT_NAMES}
    coefficient = {stat: 0 for stat in PRIMARY_STAT_NAMES}
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
    result = {}
    for stat in PRIMARY_STAT_NAMES:
        total = _f32(float(flat[stat]))
        value = _f32(_f32(_f32(float(coefficient[stat])) * total) * _F32_TEN_THOUSANDTH + total)
        result[stat] = max(0, _round_away(value) + separated[stat])
    return result


def calculate_student_stats(
    student: StudentStatRecordV1,
    build: StudentStatBuildV1,
    catalog: StudentStatCatalogV1,
    *,
    include_skill_buffs: bool = True,
    formula: StudentStatFormulaV1 | None = None,
) -> StudentStatCalculationV1:
    """Calculate exact totals or an explicitly non-exact partial when inputs are missing."""

    _validate_build(student, build)
    contributions: dict[str, _MutableModifier] = {}
    missing: list[MissingStatDependencyV1] = []
    formula = formula or default_formula()
    base = _base_values(student, build, formula, include_potential=False)
    _add_values(_modifier(contributions, "base"), base)
    _equipment_contributions(student, build, catalog, contributions, missing, formula)
    _weapon_contribution(student, build, contributions, formula)
    _relationship_contributions(student, build, catalog, contributions, missing)
    _passive_skill_contribution(
        student,
        build,
        contributions,
        missing,
        include_skill_buffs=include_skill_buffs,
    )
    _favorite_gear_contribution(student, build, contributions)
    _potential_contribution(student, build, contributions, formula, base)
    partial_values = _totals(contributions.values())
    return StudentStatCalculationV1(
        status="dependency_missing" if missing else "complete",
        values=None if missing else partial_values,
        partial_values=partial_values,
        missing_dependencies=tuple(missing),
        contributions={name: value.freeze() for name, value in contributions.items()},
    )
