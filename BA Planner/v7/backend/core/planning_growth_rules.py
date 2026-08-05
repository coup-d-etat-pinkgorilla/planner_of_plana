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
    return None
