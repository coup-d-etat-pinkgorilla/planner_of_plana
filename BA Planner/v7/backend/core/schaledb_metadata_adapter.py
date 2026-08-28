"""Pure SchaleDB-to-BA-Planner canonical metadata adapter."""

from __future__ import annotations

from pathlib import Path
import re
from typing import Any, Iterable, Mapping


PATH_EXCEPTIONS = {
    "hoshino_battle": "hoshino_battle_tank",
    "shiroko_riding": "shiroko_cycling",
    "shoukouhou_misaki": "shokuhou_misaki",
    "shun_kid": "shun_small",
}
PATH_REPLACEMENTS = (
    ("_bunny_girl", "_bunnygirl"),
    ("_school_uniform", "_uniform"),
    ("_new_year", "_newyear"),
    ("_hot_springs", "_onsen"),
    ("_sportswear", "_track"),
    ("_camping", "_camp"),
    ("_part_timer", "_parttime"),
)


def normalized_path(value: object) -> str:
    return re.sub(r"[^a-z0-9]+", "", str(value or "").casefold())


def path_for_local_id(student_id: str, merge_paths: Mapping[str, Iterable[str]]) -> str:
    paths = tuple(merge_paths.get(student_id, ()))
    if paths:
        return paths[0]
    path = PATH_EXCEPTIONS.get(student_id, student_id)
    for old, new in PATH_REPLACEMENTS:
        path = path.replace(old, new)
    return path


def local_id_for_path(
    path_name: str,
    student_ids: Iterable[str],
    merge_paths: Mapping[str, Iterable[str]],
) -> str | None:
    candidates = tuple(student_ids)
    normalized = normalized_path(path_name)
    for student_id, paths in merge_paths.items():
        if student_id in candidates and any(normalized_path(path) == normalized for path in paths):
            return student_id
    return next(
        (student_id for student_id in candidates if normalized_path(path_for_local_id(student_id, merge_paths)) == normalized),
        None,
    )


def parse_student_source(source: object) -> str:
    text = str(source or "").strip().rstrip("/")
    if not text:
        raise ValueError("SchaleDB URL or student slug is required")
    match = re.search(r"/students?/([^/?#]+)", text, re.IGNORECASE)
    if match:
        return match.group(1).strip().lower()
    match = re.search(r"([a-z0-9_]+)$", text, re.IGNORECASE)
    if match:
        return match.group(1).strip().lower()
    raise ValueError(f"could not parse a student slug from: {source}")


def student_index(raw_students: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        normalized_path(raw.get("PathName")): raw
        for raw in raw_students.values()
        if isinstance(raw, dict) and raw.get("PathName")
    }


def adapt_student(raw: Mapping[str, Any]) -> dict[str, Any]:
    external_id = raw.get("Id")
    if not isinstance(external_id, int) or isinstance(external_id, bool):
        raise ValueError("SchaleDB student Id must be an integer")
    return {
        "schaledb_id": external_id,
        "favor_item_tags": [str(tag) for tag in raw.get("FavorItemTags") or []],
        "favor_item_unique_tags": [str(tag) for tag in raw.get("FavorItemUniqueTags") or []],
    }


def adapt_gifts(raw_items: Mapping[str, Any], gift_asset_dir: Path) -> list[dict[str, Any]]:
    gifts: list[dict[str, Any]] = []
    for raw in raw_items.values():
        if not isinstance(raw, dict) or raw.get("Category") != "Favor":
            continue
        icon_name = str(raw.get("Icon") or "")
        gifts.append({
            "id": int(raw["Id"]),
            "category": "Favor",
            "tags": [str(tag) for tag in raw.get("Tags") or []],
            "exp_value": int(raw.get("ExpValue") or 0),
            "name": str(raw.get("Name") or raw["Id"]),
            "icon_asset": f"assets/item_icons/presents/{icon_name}.png"
            if (gift_asset_dir / f"{icon_name}.png").is_file()
            else None,
        })
    gifts.sort(key=lambda row: (row["exp_value"], row["id"]))
    return gifts
