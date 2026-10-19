from __future__ import annotations

from typing import Mapping


EQUIPMENT_TIER_MAX_LEVEL = {
    0: 0,
    1: 10,
    2: 20,
    3: 30,
    4: 40,
    5: 45,
    6: 50,
    7: 55,
    8: 60,
    9: 65,
    10: 70,
}
WEAPON_STAR_MAX_LEVEL = {0: 0, 1: 30, 2: 40, 3: 50, 4: 60}
STUDENT_STAR_MAX_BOND_RANK = {1: 10, 2: 10, 3: 20, 4: 30, 5: 100}
EQUIPMENT_SLOT_UNLOCK_LEVEL = {2: 10, 3: 20}
FAVORITE_ITEM_UNLOCK_BOND_RANK = {1: 15, 2: 20}

# Shared by document conversion and the calculation transition; no wire targets are rewritten.
TARGET_TO_GOAL = {
    "level": "target_level", "student_star": "target_star",
    "weapon_level": "target_weapon_level", "weapon_star": "target_weapon_star",
    "ex_skill": "target_ex_skill", "skill1": "target_skill1",
    "skill2": "target_skill2", "skill3": "target_skill3",
    **{f"equip{i}_tier": f"target_equip{i}_tier" for i in range(1, 5)},
    **{f"equip{i}_level": f"target_equip{i}_level" for i in range(1, 4)},
    **{f"stat_{key}": f"target_stat_{key}" for key in ("hp", "atk", "heal")},
}


def equipment_growth_target(current_tier: int, current_level: int, tier: int, level: int) -> tuple[int, int]:
    """The existing cost core's effective tier/level, also used for the next stage."""
    level = min(max(level, current_level), EQUIPMENT_TIER_MAX_LEVEL[10])
    required = next(t for t, maximum in EQUIPMENT_TIER_MAX_LEVEL.items() if level <= maximum)
    tier = min(max(tier, required, current_tier), 10)
    return tier, min(max(level, current_level), EQUIPMENT_TIER_MAX_LEVEL[tier])


def student_star_growth_target(current: int, target: int, weapon_star: int, weapon_level: int) -> int:
    """The existing cost core's student-star floor, shared with projected growth."""
    return min(max(current, target, 5 if weapon_star > 0 or weapon_level > 0 else current), 5)


def resolve_growth_state(current: Mapping[str, int | None], requested: Mapping[str, int | None]) -> dict[str, int | None]:
    """Resolve current floors and mandatory growth for v2 calculation only.

    An unknown bond stays unknown unless an explicit goal or favorite-item prerequisite
    establishes a projected value. The caller reports unpriced/unknown dependencies.
    """
    state = {}
    for key, value in requested.items():
        if current[key] is None:
            state[key] = value
        elif value is None:
            state[key] = current[key]
        else:
            state[key] = max(current[key], value)
    for slot in range(1, 4):
        tier_key, level_key = f"equip{slot}_tier", f"equip{slot}_level"
        tier, level = equipment_growth_target(
            int(current[tier_key] or 0), int(current[level_key] or 0),
            int(state[tier_key] or 0), int(state[level_key] or 0),
        )
        state[tier_key], state[level_key] = tier, max(level, 1 if tier else 0)
        equipment_grows = tier > int(current[tier_key] or 0) or level > int(current[level_key] or 0)
        if tier and slot in EQUIPMENT_SLOT_UNLOCK_LEVEL and equipment_grows:
            state["level"] = max(int(state["level"] or 0), EQUIPMENT_SLOT_UNLOCK_LEVEL[slot])
    weapon_level, weapon_star = int(state["weapon_level"] or 0), int(state["weapon_star"] or 0)
    if weapon_level > int(current["weapon_level"] or 0) or weapon_star > int(current["weapon_star"] or 0):
        needed = next(star for star, maximum in WEAPON_STAR_MAX_LEVEL.items() if weapon_level <= maximum)
        state["weapon_star"] = max(weapon_star, needed, 1)
        state["weapon_level"] = max(weapon_level, 1)
        state["student_star"] = student_star_growth_target(
            int(current["student_star"] or 0), int(state["student_star"] or 0),
            int(state["weapon_star"]), int(state["weapon_level"]),
        )
    for skill, star in (("skill2", 2), ("skill3", 3)):
        if int(state[skill] or 0) > int(current[skill] or 0):
            state["student_star"] = max(int(state["student_star"] or 0), star)
    if any(int(state[key] or 0) > int(current[key] or 0) for key in ("stat_hp", "stat_atk", "stat_heal")):
        state["level"], state["student_star"] = 90, 5
    favorite = int(state["equip4_tier"] or 0)
    if favorite > int(current["equip4_tier"] or 0):
        state["bond_rank"] = max(int(state["bond_rank"] or 0), FAVORITE_ITEM_UNLOCK_BOND_RANK[favorite])
    if state["bond_rank"] is not None and state["bond_rank"] != current["bond_rank"]:
        needed = next(star for star, maximum in STUDENT_STAR_MAX_BOND_RANK.items() if state["bond_rank"] <= maximum)
        state["student_star"] = max(int(state["student_star"] or 0), needed)
    for skill, star in (("skill2", 2), ("skill3", 3)):
        if int(state["student_star"] or 0) > int(current["student_star"] or 0) and int(state["student_star"] or 0) >= star:
            state[skill] = max(int(state[skill] or 0), 1)
    return state


def growth_rule_violation(targets: Mapping[str, int]) -> str | None:
    for slot in range(1, 4):
        tier = targets[f"equip{slot}_tier"]
        level = targets[f"equip{slot}_level"]
        maximum = EQUIPMENT_TIER_MAX_LEVEL.get(tier)
        if maximum is None or level > maximum:
            return f"equip{slot}_level {level} exceeds the Tier{tier} cap"

    weapon_star = targets["weapon_star"]
    weapon_level = targets["weapon_level"]
    if weapon_level > WEAPON_STAR_MAX_LEVEL.get(weapon_star, 0):
        return f"weapon_level {weapon_level} exceeds the {weapon_star}-star cap"
    if (weapon_star > 0 or weapon_level > 0) and targets["student_star"] < 5:
        return "weapon targets require student_star 5"

    student_star = targets["student_star"]
    student_level = targets["level"]
    bond_rank = targets["bond_rank"]
    if bond_rank > STUDENT_STAR_MAX_BOND_RANK.get(student_star, 0):
        return f"bond_rank {bond_rank} exceeds the {student_star}-star cap"
    if (student_star < 2 and targets["skill2"] > 0) or (
        student_star >= 2 and targets["skill2"] < 1
    ):
        return "skill2 does not match its 2-star unlock state"
    if (student_star < 3 and targets["skill3"] > 0) or (
        student_star >= 3 and targets["skill3"] < 1
    ):
        return "skill3 does not match its 3-star unlock state"
    for slot, unlock_level in EQUIPMENT_SLOT_UNLOCK_LEVEL.items():
        if student_level >= unlock_level:
            continue
        if targets[f"equip{slot}_tier"] > 0 or targets[f"equip{slot}_level"] > 0:
            return f"equipment slot {slot} requires student level {unlock_level}"
    if any(targets[key] > 0 for key in ("stat_hp", "stat_atk", "stat_heal")) and (
        student_level < 90 or student_star < 5
    ):
        return "ability release targets require level 90 and student_star 5"
    favorite_tier = targets["equip4_tier"]
    if favorite_tier > 0 and bond_rank < FAVORITE_ITEM_UNLOCK_BOND_RANK.get(favorite_tier, 101):
        return f"favorite item Tier{favorite_tier} requires a higher bond_rank"
    return None
