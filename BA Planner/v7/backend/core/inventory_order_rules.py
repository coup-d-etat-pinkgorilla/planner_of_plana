"""D23: the client's default inventory order, computed from ExcelDB item metadata.

Read from the disassembled comparers (orchestrator log 2026-09-27): the item "default" comparer orders by
ItemExcel Id and ``UINonEquipmentInventory.OnSort`` then groups by tag (school), groups ordered by their first
(smallest) Id; equipment uses ``EquipmentSortingService.CompareCategory``'s static category ranks. The grouping
LINQ body has no symbols, so group order and in-group Quality order are still checked against the live C5b scans
(tech notes 45, presents 56, equipment 95 + 9 universal blueprints) and re-verified on every scan by the order
check. Metadata comes from ``spec/item-rarity-v1.json``.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
from typing import Any

SPEC = Path(__file__).resolve().parents[1] / "assets/recognition/spec/item-rarity-v1.json"
RARITY = {"N": 0, "R": 1, "SR": 2, "SSR": 3}
EQUIPMENT_CATEGORIES = ("Necklace", "Watch", "Charm", "Hairpin", "Badge", "Bag", "Shoes", "Gloves", "Hat")
WEAPON_GROWTH = "ZCBA"


def load_metadata(path: Path = SPEC) -> dict[str, dict[str, Any]]:
    """icon identity -> ExcelDB row (items and equipment); empty when the spec is not installed."""
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {**data.get("items", {}), **data.get("equipment", {})}


def _tech_note_group(item_id: str) -> str:
    """School tag of a tech note (secret notes form their own group); the spec carries no tags, the icon does."""
    if item_id.startswith("Item_Icon_SkillBook_Ultimate"):
        return "Ultimate"
    return re.fullmatch(r"Item_Icon_SkillBook_(\w+?)_\d+", item_id).group(1)


def _group_firsts(metadata: dict[str, dict[str, Any]]) -> dict[str, int]:
    firsts: dict[str, int] = {}
    for item_id, row in metadata.items():
        if re.fullmatch(r"Item_Icon_SkillBook_(\w+?_\d+|Ultimate(_Piece)?)", item_id):
            group = _tech_note_group(item_id)
            firsts[group] = min(firsts.get(group, row["id"]), row["id"])
    return firsts


def order_key(profile: str, item_id: str, metadata: dict[str, dict[str, Any]]) -> tuple:
    """Sort key of item_id in the profile's default list order; raises KeyError/ValueError when unknown.

    ``metadata`` is the whole ``load_metadata()`` table: tech-note groups are ordered by their smallest Id.
    """
    meta = metadata[item_id]
    if profile == "tech_notes":
        # School group (by its first Id) x Quality; new T1 notes (Id 6001x) sit inside their school's group,
        # which is why the key is the group, not the item's own Id. Secret notes (9998/9999) are the last group.
        group = _tech_note_group(item_id)
        return (_group_firsts(metadata)[group], meta["quality"], meta["id"])
    if profile == "presents":
        # Id only: SR (5000s) < SSR (5100s) < 91000xxx is an Id coincidence, not a rarity key.
        return (meta["id"],)
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
