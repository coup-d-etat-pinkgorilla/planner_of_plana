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
STUDENT_STAR_MAX_BOND_RANK = {1: 10, 2: 10, 3: 20, 4: 20, 5: 100}
EQUIPMENT_SLOT_UNLOCK_LEVEL = {2: 10, 3: 20}
FAVORITE_ITEM_UNLOCK_BOND_RANK = {1: 20, 2: 25}


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
