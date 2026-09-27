"""D23: the client's default inventory order, computed from ExcelDB item metadata.

The client's sorting code (``ItemSortingService.GetDefaultSortingOrder``) is not in the dumps, so these
rules are induced from the live C5b scans (tech notes 45, presents 56, equipment 95 + 9 universal blueprints
identified in C5e-4, all monotonic) and are
re-verified on every scan by the order check. Metadata comes from ``spec/item-rarity-v1.json``.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
from typing import Any

SPEC = Path(__file__).resolve().parents[1] / "assets/recognition/spec/item-rarity-v1.json"
RARITY = {"N": 0, "R": 1, "SR": 2, "SSR": 3}
SCHOOLS = ("Hyakkiyako", "RedWinter", "Trinity", "Gehenna", "Abydos", "Millennium", "Arius",
           "Shanhaijing", "Valkyrie", "Highlander", "Wildhunt")
EQUIPMENT_CATEGORIES = ("Necklace", "Watch", "Charm", "Hairpin", "Badge", "Bag", "Shoes", "Gloves", "Hat")
WEAPON_GROWTH = "ZCBA"


def load_metadata(path: Path = SPEC) -> dict[str, dict[str, Any]]:
    """icon identity -> ExcelDB row (items and equipment); empty when the spec is not installed."""
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {**data.get("items", {}), **data.get("equipment", {})}


def order_key(profile: str, item_id: str, meta: dict[str, Any]) -> tuple:
    """Sort key of item_id in the profile's default list order; raises KeyError/ValueError when unknown."""
    if profile == "tech_notes":
        # School enum x tier; secret notes last. New T1 notes (id 6001x) sit with their school, so the key
        # is the school in the icon name, not the ExcelDB id.
        if item_id.startswith("Item_Icon_SkillBook_Ultimate"):
            return (len(SCHOOLS), 0 if item_id.endswith("_Piece") else 1)
        school, tier = re.fullmatch(r"Item_Icon_SkillBook_(\w+?)_(\d+)", item_id).groups()
        return (SCHOOLS.index(school), int(tier))
    if profile == "presents":
        return (RARITY[meta["rarity"]], meta["id"])
    if profile == "equipment":
        category, rarity = meta["category"], RARITY[meta["rarity"]]
        if category == "Exp":
            return (0, -rarity)
        if item_id.endswith("_Useall_Piece") and category in EQUIPMENT_CATEGORIES:
            return (1, EQUIPMENT_CATEGORIES.index(category))  # universal blueprints (C5e-4 live order)
        if category in EQUIPMENT_CATEGORIES:
            tier = meta["tier"]
            return (2, EQUIPMENT_CATEGORIES.index(category), -tier) if tier >= 2 else (3, EQUIPMENT_CATEGORIES.index(category))
        growth = re.fullmatch(r"Equipment_Icon_WeaponExpGrowth([ZCBA])_\d+", item_id)
        if growth:
            return (4, WEAPON_GROWTH.index(growth.group(1)), -rarity)
    raise ValueError(f"no default-order rule for {item_id} in {profile}")


def increasing_run(orders: list[int | None]) -> set[int]:
    """Positions of one longest strictly increasing subsequence of orders (None never belongs).

    D23: an out-of-order or unknown tile is one slot to review, not a reason to distrust the whole scan.
    """
    tails: list[int] = []      # position ending the best run of each length
    previous: dict[int, int | None] = {}
    for position, order in enumerate(orders):
        if order is None:
            continue
        low, high = 0, len(tails)
        while low < high:
            middle = (low + high) // 2
            if orders[tails[middle]] < order:
                low = middle + 1
            else:
                high = middle
        previous[position] = tails[low - 1] if low else None
        if low == len(tails):
            tails.append(position)
        else:
            tails[low] = position
    run: set[int] = set()
    position = tails[-1] if tails else None
    while position is not None:
        run.add(position)
        position = previous[position]
    return run
