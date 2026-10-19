"""Read-only favor experience and independent gift alternatives (FD-163..165)."""
from __future__ import annotations

from core import gift_meta, student_meta
from core.repository_dto import InventorySnapshot
from core.student_bond_data import FAVOR_EXP_BY_RANK, GIFT_IDENTITIES, GROUP_BY_CHARACTER, SOURCE_VERSION

UNIVERSAL_GIFT_TAGS = frozenset({"BC", "Bc", "ew"})


def gift_affinity(student_id: str, gift_id: int) -> tuple[int, bool]:
    """Port of developer_tools._student_gift_affinities; no tool/runtime import."""
    general = set(student_meta.favor_item_tags(student_id))
    unique = set(student_meta.favor_item_unique_tags(student_id))
    tags = set(gift_meta.tags(gift_id))
    preferred = bool(tags & (general | unique))
    matches = min(3, len(tags & (general | unique | UNIVERSAL_GIFT_TAGS))) if preferred else 0
    return 1 + matches, preferred


def required_experience(current_rank: int, target_rank: int, group: int) -> int:
    if not 1 <= current_rank <= 100 or not 1 <= target_rank <= 100:
        raise ValueError("bond ranks must be 1..100")
    if type(group) is not int or group < 1:
        raise ValueError("unknown FavorLevelupType")
    rows = FAVOR_EXP_BY_RANK[current_rank - 1:target_rank - 1]
    if any(group > len(row) for row in rows):
        raise ValueError("FavorLevelupType exceeds ExpType vector")
    return sum(row[group - 1] for row in rows)


def _gift_plan(student_id: str, required: int | None, holdings: dict[str, int | None], *, large: bool) -> dict:
    candidates = []
    for gift_id in gift_meta.all_ids():
        identity = GIFT_IDENTITIES.get(gift_id)
        if identity is None or gift_meta.exp_value(gift_id) <= 0:
            continue
        key, name, rarity = identity
        multiplier, preferred = gift_affinity(student_id, gift_id)
        if (large and (rarity != "SSR" or not preferred)) or (not large and rarity != "SR"):
            continue
        candidates.append({
            "gift_id": gift_id, "resource_key": key, "display_name": name,
            "base_exp": gift_meta.exp_value(gift_id), "multiplier": multiplier,
            "exp_per_gift": gift_meta.exp_value(gift_id) * multiplier,
            "owned": holdings.get(key),
        })
    complete = all(g["owned"] is not None for g in candidates)
    if required is None or (required > 0 and not candidates):
        return {"available": False, "inventory_complete": complete, "provided_exp": 0, "shortage": None, "gifts": []}
    remaining = required
    allocated = {}
    # FD-164: quantity first; deterministic ties by per-item exp, then numeric ID.
    for gift in sorted(candidates, key=lambda g: (-(g["owned"] or 0), -g["exp_per_gift"], g["gift_id"])):
        if remaining <= 0:
            break
        used = min(gift["owned"] or 0, (remaining + gift["exp_per_gift"] - 1) // gift["exp_per_gift"])
        if used:
            allocated[gift["gift_id"]] = {**gift, "required": used, "used_owned": used, "shortage": 0}
            remaining -= used * gift["exp_per_gift"]
    if remaining > 0:
        best = min(candidates, key=lambda g: (-g["exp_per_gift"], g["gift_id"]))
        extra = (remaining + best["exp_per_gift"] - 1) // best["exp_per_gift"]
        row = allocated.setdefault(best["gift_id"], {**best, "required": 0, "used_owned": 0, "shortage": 0})
        row["required"] += extra
        row["shortage"] = None if best["owned"] is None else extra
    gifts = list(allocated.values())
    return {
        "available": True, "inventory_complete": complete,
        "provided_exp": sum(g["required"] * g["exp_per_gift"] for g in gifts),
        "shortage": None if any(g["shortage"] is None for g in gifts) else sum(g["shortage"] for g in gifts),
        "gifts": gifts,
    }


def calculate_bond(student_id: str, current_rank: int | None, target_rank: int, inventory: InventorySnapshot) -> dict:
    group = GROUP_BY_CHARACTER.get(student_meta.schaledb_id(student_id))
    warnings = []
    required = None
    if current_rank is None:
        warnings.append("Current bond rank is unknown; required experience is unavailable.")
    elif target_rank <= current_rank:
        required = 0
    elif group is None:
        warnings.append("Student FavorLevelupType is unknown; no default group was invented.")
    else:
        try:
            required = required_experience(current_rank, target_rank, group)
        except ValueError as error:
            warnings.append(str(error))
    holdings = {entry.item_id or entry.key: None if entry.quantity is None else int(entry.quantity) for entry in inventory.entries}
    large, normal = (_gift_plan(student_id, required, holdings, large=large) for large in (True, False))
    if required and not large["available"]:
        warnings.append("No preferred large gift metadata is available for this student.")
    if required and any(not plan["inventory_complete"] for plan in (large, normal)):
        warnings.append("Unknown present holdings are not allocated; shortage stays unknown for an unscanned fallback gift.")
    count = None if required is None else (required + 14) // 15
    return {
        "current_rank": current_rank, "target_rank": target_rank,
        "assumption": "current_rank_start", "source_version": SOURCE_VERSION,
        "favor_levelup_type": group, "required_exp": required,
        "plans": {
            "preferred_large": large, "normal": normal,
            "petting": {
                "exp_per_interaction": 15, "interval_hours": 3,
                "required_count": count, "minimum_hours": None if count is None else max(count - 1, 0) * 3,
                "first_interaction": "immediate", "available_count": None,
            },
        },
        "warnings": warnings,
    }
