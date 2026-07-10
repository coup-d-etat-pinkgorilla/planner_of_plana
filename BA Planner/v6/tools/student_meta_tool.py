from __future__ import annotations

import argparse
import ast
import importlib
import json
import pprint
import re
import sys
import tkinter as tk
from collections import Counter
from pathlib import Path
from tkinter import messagebox, ttk

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from core.config import get_storage_paths
import core.student_meta as student_meta
import tools.schaledb_sync as schaledb_sync
from gui.ui_scale import get_ui_scale, scale_px
from tools.schaledb_sync import SYNC_FIELDS, build_student_meta_from_schale, local_id_to_schale_path, parse_student_source
from tools.student_meta_options import FIELD_OPTIONS

MODULE_NAME = "core.student_meta"
MODULE_PATH = ROOT_DIR / "core" / "student_meta_data.py"
SCHALE_SYNC_MODULE_PATH = ROOT_DIR / "tools" / "schaledb_sync.py"
PLAN_FILE = "item_plan_adjustments.json"
STUDENT_TEMPLATE_DIR = ROOT_DIR / "templates" / "students"
PORTRAIT_TEMPLATE_DIR = ROOT_DIR / "templates" / "students_portraits"
STUDENT_ELEPH_DIR = ROOT_DIR / "templates" / "students_elephs"

FIELD_SPECS: list[dict[str, object]] = [
    {"name": "student_id", "label": "Student ID", "required": True},
    {"name": "display_name", "label": "Display Name", "required": True},
    {"name": "template_name", "label": "Template File", "required": True},
    {"name": "group", "label": "Group", "required": True},
    {"name": "variant", "label": "Variant"},
    {"name": "search_tags", "label": "Search Tags"},
    {"name": "kr_search_tags", "label": "KR Search Tags"},
    {"name": "school", "label": "School"},
    {"name": "rarity", "label": "Rarity"},
    {"name": "recruit_type", "label": "Recruit Type"},
    {"name": "attack_type", "label": "Attack Type"},
    {"name": "attack_type_trait", "label": "Attack Type Trait"},
    {"name": "defense_type", "label": "Defense Type"},
    {"name": "growth_material_main", "label": "Main Growth Mat"},
    {"name": "growth_material_sub", "label": "Sub Growth Mat"},
    {"name": "raw_skill_ex_material", "label": "Raw Skill EX Material"},
    {"name": "raw_skill_ex_material_amount", "label": "Raw Skill EX Amount"},
    {"name": "raw_skill_material", "label": "Raw Skill Material"},
    {"name": "raw_skill_material_amount", "label": "Raw Skill Amount"},
    {"name": "mapped_skill_ex_material_rows", "label": "Mapped Skill EX Rows"},
    {"name": "mapped_skill_material_rows", "label": "Mapped Skill Rows"},
    {"name": "equipment_slot_1", "label": "Equipment 1"},
    {"name": "equipment_slot_2", "label": "Equipment 2"},
    {"name": "equipment_slot_3", "label": "Equipment 3"},
    {"name": "combat_class", "label": "Class"},
    {"name": "cover_type", "label": "Cover"},
    {"name": "range_type", "label": "Range"},
    {"name": "role", "label": "Role"},
    {"name": "weapon_type", "label": "Weapon"},
    {"name": "position", "label": "Position"},
    {"name": "terrain_outdoor", "label": "Outdoor"},
    {"name": "terrain_urban", "label": "Urban"},
    {"name": "terrain_indoor", "label": "Indoor"},
    {"name": "weapon3_terrain_boost", "label": "Weapon 3* Terrain Boost"},
    {"name": "has_favorite_item", "label": "Favorite Item (Legacy Fallback)"},
    {"name": "has_favorite_item_jp", "label": "Favorite Item (JP)"},
    {"name": "has_favorite_item_kr", "label": "Favorite Item (KR)"},
    {"name": "farmable", "label": "Farmable"},
    {"name": "passive_stat", "label": "Passive Stat"},
    {"name": "weapon_passive_stat", "label": "Weapon Passive Stat"},
    {"name": "extra_passive_stat", "label": "Extra Passive Stat"},
    {"name": "skill_buff", "label": "Buff Skill"},
    {"name": "skill_debuff", "label": "Debuff Skill"},
    {"name": "skill_cc", "label": "Crowd Control"},
    {"name": "skill_special", "label": "Special Effect"},
    {"name": "skill_heal_targets", "label": "Heal Targets"},
    {"name": "skill_dispel_targets", "label": "Dispel Targets"},
    {"name": "skill_reposition_targets", "label": "Move Skill"},
    {"name": "skill_summon_types", "label": "Summon Skill"},
    {"name": "skill_ignore_cover", "label": "EX Ignore Cover"},
    {"name": "skill_is_area_damage", "label": "EX Area Damage"},
    {"name": "skill_buff_specials", "label": "Special Student Buff"},
    {"name": "skill_knockback", "label": "Knockback / Pull"},
]

LABELS = {str(s["name"]): str(s["label"]) for s in FIELD_SPECS} | {
    "match_template_asset": "Match Template Asset",
    "portrait_asset": "Portrait Asset",
    "eleph_asset": "Eleph Asset",
    "passive_stat": "Passive Stat",
    "weapon_passive_stat": "Weapon Passive Stat",
    "extra_passive_stat": "Extra Passive Stat",
    "skill_buff": "Buff Skill",
    "skill_debuff": "Debuff Skill",
    "skill_cc": "Crowd Control",
    "skill_special": "Special Effect",
    "skill_heal_targets": "Heal Targets",
    "skill_dispel_targets": "Dispel Targets",
    "skill_reposition_targets": "Move Skill",
    "skill_summon_types": "Summon Skill",
    "skill_ignore_cover": "EX Ignore Cover",
    "skill_is_area_damage": "EX Area Damage",
    "skill_buff_specials": "Special Student Buff",
    "skill_knockback": "Knockback / Pull",
}
LIST_FIELDS = {
    "search_tags",
    "kr_search_tags",
    "passive_stat", "weapon_passive_stat", "extra_passive_stat", "skill_buff", "skill_debuff",
    "skill_cc", "skill_special", "skill_heal_targets", "skill_dispel_targets",
    "skill_reposition_targets", "skill_summon_types", "skill_buff_specials",
}
STRUCTURED_FIELDS = {
    "raw_skill_ex_material",
    "raw_skill_ex_material_amount",
    "raw_skill_material",
    "raw_skill_material_amount",
    "mapped_skill_ex_material_rows",
    "mapped_skill_material_rows",
}
FREE_TEXT_COMBO_FIELDS = {"student_id", "display_name", "group"}
ANALYTICS_FIELDS = (
    "search_tags", "kr_search_tags", "school", "rarity", "recruit_type", "attack_type", "attack_type_trait", "defense_type",
    "growth_material_main", "growth_material_sub", "equipment_slot_1", "equipment_slot_2",
    "equipment_slot_3", "combat_class", "cover_type", "range_type", "role", "weapon_type",
    "position", "terrain_outdoor", "terrain_urban", "terrain_indoor", "weapon3_terrain_boost",
    "has_favorite_item", "has_favorite_item_jp", "has_favorite_item_kr", "farmable", "passive_stat", "weapon_passive_stat", "extra_passive_stat",
    "skill_buff", "skill_debuff", "skill_cc", "skill_special", "skill_heal_targets",
    "skill_dispel_targets", "skill_reposition_targets", "skill_summon_types",
    "skill_ignore_cover", "skill_is_area_damage", "skill_buff_specials", "skill_knockback",
)
STUDENT_SORTS = ("Value A-Z", "Value Z-A", "Match First")
ITEM_SORTS = ("Shortage First", "Adjusted Asc", "Adjusted Desc", "Name A-Z")
ITEM_FILTERS = ("All Items", "Shortage Only", "Zero Or Less", "Positive Only")
SERVER_FILTERS = ("All", "KR", "JP Only")
EDITOR_VALUE_FIELD_CHARS = 96
METADATA_TABLE_COLUMNS: tuple[tuple[str, str, int], ...] = (
    ("student_id", "Student ID", 170),
    ("display_name", "Name", 170),
    ("server", "Server", 90),
    ("favorite_item_jp", "Fav JP", 70),
    ("favorite_item_kr", "Fav KR", 70),
    ("match_template_asset", "Match", 70),
    ("portrait_asset", "Portrait", 70),
    ("eleph_asset", "Eleph", 70),
    ("group", "Group", 140),
    ("variant", "Variant", 110),
    ("search_tags", "Search Tags", 180),
    ("kr_search_tags", "KR Search Tags", 180),
    ("school", "School", 120),
    ("rarity", "Rarity", 60),
    ("attack_type", "Attack", 90),
    ("defense_type", "Defense", 90),
    ("role", "Role", 90),
    ("position", "Position", 90),
    ("weapon_type", "Weapon", 90),
    ("template_name", "Template", 160),
)
DETAIL_FIELD_ORDER: tuple[str, ...] = (
    "match_template_asset",
    "portrait_asset",
    "eleph_asset",
    "display_name",
    "template_name",
    "group",
    "variant",
    "search_tags",
    "kr_search_tags",
    "school",
    "rarity",
    "recruit_type",
    "attack_type",
    "attack_type_trait",
    "defense_type",
    "growth_material_main",
    "growth_material_sub",
    "raw_skill_ex_material",
    "raw_skill_ex_material_amount",
    "raw_skill_material",
    "raw_skill_material_amount",
    "mapped_skill_ex_material_rows",
    "mapped_skill_material_rows",
    "equipment_slot_1",
    "equipment_slot_2",
    "equipment_slot_3",
    "combat_class",
    "cover_type",
    "range_type",
    "role",
    "weapon_type",
    "position",
    "terrain_outdoor",
    "terrain_urban",
    "terrain_indoor",
    "weapon3_terrain_boost",
    "has_favorite_item",
    "has_favorite_item_jp",
    "has_favorite_item_kr",
    "farmable",
    "passive_stat",
    "weapon_passive_stat",
    "extra_passive_stat",
    "skill_buff",
    "skill_debuff",
    "skill_cc",
    "skill_special",
    "skill_heal_targets",
    "skill_dispel_targets",
    "skill_reposition_targets",
    "skill_summon_types",
    "skill_ignore_cover",
    "skill_is_area_damage",
    "skill_buff_specials",
    "skill_knockback",
)


def _load_module():
    return importlib.import_module(MODULE_NAME)


def _reload_module():
    return importlib.reload(_load_module())


def _normalize_value(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    if not value or value.lower() in {"none", "null", "-"}:
        return None
    return value


def _as_list(value: object) -> list[str]:
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return [str(x).strip() for x in value if str(x).strip()]
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return []
        if text.startswith("[") and text.endswith("]"):
            try:
                parsed = ast.literal_eval(text)
            except Exception:
                parsed = None
            if isinstance(parsed, (list, tuple)):
                return [str(x).strip() for x in parsed if str(x).strip()]
        return [x.strip() for x in text.split(",") if x.strip()]
    return [str(value).strip()]


def _display(field_name: str, value: object) -> str:
    if field_name in STRUCTURED_FIELDS:
        return "" if value is None else pprint.pformat(value, width=100, sort_dicts=False)
    if field_name in LIST_FIELDS:
        return ", ".join(_as_list(value))
    return "" if value is None else str(value)


def _student_search_blob(student_id: str, meta: dict[str, object]) -> str:
    terms = [student_id, str(meta.get("display_name") or "")]
    terms.extend(_as_list(meta.get("search_tags")))
    terms.extend(_as_list(meta.get("kr_search_tags")))
    return " ".join(term for term in terms if term).casefold()


def _form_value(field_name: str, raw: str) -> object | None:
    value = _normalize_value(raw)
    if value is None:
        return None
    if field_name in STRUCTURED_FIELDS:
        parsed = ast.literal_eval(value)
        if not isinstance(parsed, list):
            raise ValueError(f"{field_name} must be a list value.")
        return parsed
    if field_name in LIST_FIELDS:
        return _as_list(value)
    return value


def _sorted_unique(values: list[str]) -> tuple[str, ...]:
    return tuple(sorted({v for v in values if v}))


def _collect_field_values(students: dict[str, dict], field_name: str) -> tuple[str, ...]:
    if field_name in STRUCTURED_FIELDS:
        return ("",)
    if field_name == "student_id":
        return _sorted_unique(list(students))
    out: list[str] = []
    for meta in students.values():
        raw = meta.get(field_name)
        out.extend(_as_list(raw) if field_name in LIST_FIELDS else ([str(raw)] if raw else []))
    return _sorted_unique(out)


def build_field_options(students: dict[str, dict]) -> dict[str, tuple[str, ...]]:
    options: dict[str, tuple[str, ...]] = {}
    for spec in FIELD_SPECS:
        name = str(spec["name"])
        merged = _sorted_unique(list(FIELD_OPTIONS.get(name, ())) + list(_collect_field_values(students, name)))
        options[name] = ("",) + merged
    return options


def _replace_named_assignment(source: str, assignment_name: str, rendered_assignment: str) -> str:
    tree = ast.parse(source)
    target = None
    for node in tree.body:
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and node.target.id == assignment_name:
            target = node
            break
        if isinstance(node, ast.Assign):
            for single_target in node.targets:
                if isinstance(single_target, ast.Name) and single_target.id == assignment_name:
                    target = node
                    break
    if target is None:
        raise RuntimeError(f"{assignment_name} assignment not found in core.student_meta_data")
    lines = source.splitlines()
    return "\n".join(lines[: target.lineno - 1] + rendered_assignment.rstrip("\n").splitlines() + lines[target.end_lineno :]) + "\n"


def resolve_portrait_template_path(template_name: object) -> Path | None:
    name = str(template_name or "").strip()
    if not name:
        return None
    direct_path = PORTRAIT_TEMPLATE_DIR / name
    if direct_path.exists():
        return direct_path
    if Path(name).suffix:
        return None
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        candidate = PORTRAIT_TEMPLATE_DIR / f"{name}{ext}"
        if candidate.exists():
            return candidate
    return None


def _resolve_student_asset_path(base_dir: Path, stem: str) -> Path | None:
    name = str(stem or "").strip()
    if not name:
        return None
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        candidate = base_dir / f"{name}{ext}"
        if candidate.exists():
            return candidate
    return None


def resolve_match_template_path(student_id: str) -> Path | None:
    return _resolve_student_asset_path(STUDENT_TEMPLATE_DIR, student_id)


def resolve_match_template_paths(student_id: str) -> tuple[Path | None, ...]:
    indexes = getattr(student_meta, "form_indexes", lambda value: (1,))(student_id)
    paths: list[Path | None] = []
    for form_index in indexes:
        template_name = getattr(student_meta, "template_path_for_form", lambda value, _form=None: f"{value}.png")(student_id, form_index)
        stem = Path(str(template_name)).stem
        paths.append(_resolve_student_asset_path(STUDENT_TEMPLATE_DIR, stem))
    if not paths:
        paths.append(resolve_match_template_path(student_id))
    return tuple(paths)


def resolve_student_portrait_path(student_id: str) -> Path | None:
    template_name = getattr(student_meta, "template_path", lambda value: f"{value}.png")(student_id)
    return resolve_portrait_template_path(template_name) or _resolve_student_asset_path(PORTRAIT_TEMPLATE_DIR, student_id)


def resolve_student_portrait_paths(student_id: str) -> tuple[Path | None, ...]:
    indexes = getattr(student_meta, "form_indexes", lambda value: (1,))(student_id)
    paths: list[Path | None] = []
    for form_index in indexes:
        template_name = getattr(student_meta, "template_path_for_form", lambda value, _form=None: f"{value}.png")(student_id, form_index)
        paths.append(resolve_portrait_template_path(template_name))
    if not paths:
        paths.append(resolve_student_portrait_path(student_id))
    return tuple(paths)


def resolve_student_eleph_path(student_id: str) -> Path | None:
    return _resolve_student_asset_path(STUDENT_ELEPH_DIR, f"Item_Icon_SecretStone_{student_id}")


def _asset_status(path: Path | None) -> str:
    return "OK" if path is not None else "Missing"


def _multi_asset_status(paths: tuple[Path | None, ...]) -> str:
    missing = sum(1 for path in paths if path is None)
    if missing:
        return f"Missing ({len(paths) - missing}/{len(paths)})" if len(paths) > 1 else "Missing"
    return f"OK ({len(paths)})" if len(paths) > 1 else "OK"


def build_student_asset_status(student_id: str) -> dict[str, str]:
    return {
        "match_template_asset": _multi_asset_status(resolve_match_template_paths(student_id)),
        "portrait_asset": _multi_asset_status(resolve_student_portrait_paths(student_id)),
        "eleph_asset": _asset_status(resolve_student_eleph_path(student_id)),
    }

def warn_missing_portrait_template(student_id: str, meta: dict[str, object]) -> bool:
    template_name = str(meta.get("template_name") or "").strip()
    if all(path is not None for path in resolve_student_portrait_paths(student_id)):
        return False
    display_name = str(meta.get("display_name") or student_id)
    messagebox.showwarning(
        "Missing Student Template",
        "\n".join(
            (
                f"{display_name} ({student_id}) was moved to KR, but its portrait template is missing.",
                "",
                f"Expected template: {template_name or '(empty)'}",
                f"Template folder: {PORTRAIT_TEMPLATE_DIR}",
            )
        ),
    )
    return True


def _write_students(students: dict[str, dict]) -> None:
    source = MODULE_PATH.read_text(encoding="utf-8")
    rendered = "STUDENTS: dict[str, StudentMeta] = " + pprint.pformat(students, width=100, sort_dicts=False)
    MODULE_PATH.write_text(_replace_named_assignment(source, "STUDENTS", rendered), encoding="utf-8")


def get_multi_form_students() -> dict[str, tuple[dict[str, object], ...]]:
    module = _reload_module()
    return {
        student_id: tuple(dict(form) for form in forms)
        for student_id, forms in getattr(module, "MULTI_FORM_STUDENTS", {}).items()
    }


def _write_multi_form_students(forms: dict[str, tuple[dict[str, object], ...]]) -> None:
    source = MODULE_PATH.read_text(encoding="utf-8")
    rendered = (
        "MULTI_FORM_STUDENTS: dict[str, tuple[StudentFormMeta, ...]] = "
        + pprint.pformat(forms, width=100, sort_dicts=False)
    )
    MODULE_PATH.write_text(_replace_named_assignment(source, "MULTI_FORM_STUDENTS", rendered), encoding="utf-8")



def get_schale_merge_paths() -> dict[str, tuple[str, ...]]:
    module = importlib.reload(schaledb_sync)
    return {
        student_id: tuple(str(path).strip() for path in paths if str(path).strip())
        for student_id, paths in getattr(module, "SCHALE_MERGE_PATHS", {}).items()
    }


def _write_schale_merge_paths(merge_paths: dict[str, tuple[str, ...]]) -> None:
    normalized = {
        str(student_id).strip(): tuple(str(path).strip() for path in paths if str(path).strip())
        for student_id, paths in merge_paths.items()
        if str(student_id).strip()
    }
    normalized = {student_id: paths for student_id, paths in sorted(normalized.items()) if paths}
    seen_paths: dict[str, str] = {}
    for student_id, paths in normalized.items():
        for path in paths:
            key = path.casefold()
            previous = seen_paths.get(key)
            if previous and previous != student_id:
                raise ValueError(f"SchaleDB slug '{path}' is already used by {previous}.")
            seen_paths[key] = student_id
    source = SCHALE_SYNC_MODULE_PATH.read_text(encoding="utf-8")
    rendered = "SCHALE_MERGE_PATHS: dict[str, tuple[str, ...]] = " + pprint.pformat(
        normalized,
        width=100,
        sort_dicts=False,
    )
    SCHALE_SYNC_MODULE_PATH.write_text(
        _replace_named_assignment(source, "SCHALE_MERGE_PATHS", rendered),
        encoding="utf-8",
    )
    importlib.reload(schaledb_sync)


def get_jp_only_ids() -> set[str]:
    module = _reload_module()
    return set(module.JP_ONLY_STUDENT_IDS)


def _write_jp_only_ids(student_ids: set[str]) -> None:
    source = MODULE_PATH.read_text(encoding="utf-8")
    rendered = "JP_ONLY_STUDENT_IDS: frozenset[str] = frozenset(" + pprint.pformat(tuple(sorted(student_ids)), width=100) + ")"
    MODULE_PATH.write_text(_replace_named_assignment(source, "JP_ONLY_STUDENT_IDS", rendered), encoding="utf-8")


def set_jp_only(student_id: str, enabled: bool) -> set[str]:
    student_ids = get_jp_only_ids()
    if enabled:
        student_ids.add(student_id)
    else:
        student_ids.discard(student_id)
    _write_jp_only_ids(student_ids)
    return get_jp_only_ids()


def get_students() -> dict[str, dict]:
    module = _reload_module()
    return {sid: dict(meta) for sid, meta in module.STUDENTS.items()}


def upsert_student(student_id: str, updates: dict[str, object | None]) -> dict[str, object]:
    module = _reload_module()
    students = dict(module.STUDENTS)
    current = dict(students.get(student_id, {}))
    candidate = dict(current) | updates
    required = {"display_name", "template_name", "group"}
    if not required.issubset(candidate):
        raise ValueError(f"required fields missing: {', '.join(sorted(required - set(candidate)))}")
    candidate.setdefault("variant", None)
    students[student_id] = candidate
    _write_students(students)
    return dict(_reload_module().STUDENTS[student_id])


def delete_student(student_id: str) -> None:
    module = _reload_module()
    students = dict(module.STUDENTS)
    if student_id not in students:
        raise KeyError(student_id)
    students.pop(student_id)
    _write_students(students)
    if student_id in get_jp_only_ids():
        set_jp_only(student_id, False)


def _safe_int(value: object, default: int = 0) -> int:
    try:
        return int(str(value).strip())
    except Exception:
        return default


def _read_json(path: Path, default: object) -> object:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def _candidate_inventory_paths() -> list[Path]:
    paths: list[Path] = []
    try:
        paths.append(get_storage_paths().current_inventory_json)
    except Exception:
        pass
    paths.append(ROOT_DIR / "data" / "current" / "inventory.json")
    return list(dict.fromkeys(paths))


def _candidate_plan_paths() -> list[Path]:
    paths: list[Path] = []
    try:
        paths.append(get_storage_paths().current_inventory_json.with_name(PLAN_FILE))
    except Exception:
        pass
    paths.append(ROOT_DIR / "data" / "current" / PLAN_FILE)
    return list(dict.fromkeys(paths))


def _pick_path(candidates: list[Path]) -> Path:
    for path in candidates:
        if path.exists():
            return path
    return candidates[0]


def load_inventory_snapshot(path: Path) -> dict[str, dict]:
    raw = _read_json(path, {})
    return raw if isinstance(raw, dict) else {}


def load_item_plan_adjustments(path: Path) -> dict[str, int]:
    raw = _read_json(path, {})
    if not isinstance(raw, dict):
        return {}
    result: dict[str, int] = {}
    for name, value in raw.items():
        result[str(name)] = _safe_int(value.get("delta") if isinstance(value, dict) else value, 0)
    return result


def _resolved_field_value(student_id: str, meta: dict[str, object], field_name: str) -> object:
    value = meta.get(field_name)
    if value not in (None, ""):
        return value
    if field_name in {"has_favorite_item_jp", "has_favorite_item_kr"}:
        legacy = meta.get("has_favorite_item")
        if legacy not in (None, ""):
            return legacy
    module = _load_module()
    getter = getattr(module, field_name, None)
    if callable(getter):
        try:
            return getter(student_id)
        except Exception:
            pass
    return value


def collect_attribute_value_options(students: dict[str, dict], field_name: str) -> tuple[str, ...]:
    return ("",) + _sorted_unique(list(FIELD_OPTIONS.get(field_name, ())) + list(_collect_field_values(students, field_name)))


def build_attribute_stats(students: dict[str, dict], field_name: str) -> list[dict[str, object]]:
    total = len(students)
    counts: Counter[str] = Counter()
    missing = 0
    for student_id, meta in students.items():
        raw = _resolved_field_value(student_id, meta, field_name)
        if field_name in LIST_FIELDS:
            values = sorted(set(_as_list(raw)))
        else:
            value = _normalize_value(_display(field_name, raw))
            values = [value] if value else []
        if not values:
            missing += 1
            continue
        for value in values:
            counts[value] += 1
    rows = [{"value": v, "count": c, "percent": (c / total * 100.0) if total else 0.0} for v, c in sorted(counts.items(), key=lambda x: (-x[1], x[0].casefold()))]
    if missing:
        rows.append({"value": "(missing)", "count": missing, "percent": (missing / total * 100.0) if total else 0.0})
    return rows


def build_student_attribute_rows(students: dict[str, dict], field_name: str, selected_value: str = "", sort_mode: str = "Value A-Z", search_query: str = "") -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    query = search_query.strip().casefold()
    for sid, meta in students.items():
        name = str(meta.get("display_name", ""))
        if query and query not in _student_search_blob(sid, meta):
            continue
        raw = _resolved_field_value(sid, meta, field_name)
        values = _as_list(raw) if field_name in LIST_FIELDS else []
        if field_name not in LIST_FIELDS:
            value = _normalize_value(_display(field_name, raw))
            values = [value] if value else []
        rows.append({
            "student_id": sid,
            "display_name": name,
            "display_value": ", ".join(values) if values else "-",
            "has_value": bool(values),
            "matches": (selected_value in values) if selected_value else bool(values),
        })
    if sort_mode == "Match First":
        matched = [r for r in rows if r["matches"]]
        rest = [r for r in rows if not r["matches"]]
        matched.sort(key=lambda r: (str(r["display_value"]).casefold(), str(r["student_id"]).casefold()))
        rest.sort(key=lambda r: (str(r["display_value"]).casefold(), str(r["student_id"]).casefold()))
        return matched + rest
    present = [r for r in rows if r["has_value"]]
    missing = [r for r in rows if not r["has_value"]]
    present.sort(key=lambda r: (str(r["display_value"]).casefold(), str(r["student_id"]).casefold()), reverse=(sort_mode == "Value Z-A"))
    missing.sort(key=lambda r: str(r["student_id"]).casefold())
    return present + missing


def build_item_rows(inventory: dict[str, dict], plan_adjustments: dict[str, int]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for name in sorted(set(inventory) | set(plan_adjustments), key=str.casefold):
        entry = inventory.get(name, {})
        current = _safe_int(entry.get("quantity"), 0)
        delta = _safe_int(plan_adjustments.get(name), 0)
        rows.append({
            "item": name,
            "current_qty": current,
            "plan_delta": delta,
            "adjusted_qty": current + delta,
            "index": _safe_int(entry.get("index"), -1),
        })
    return rows


def filter_and_sort_item_rows(rows: list[dict[str, object]], filter_mode: str = "All Items", sort_mode: str = "Shortage First") -> list[dict[str, object]]:
    if filter_mode == "Shortage Only":
        rows = [r for r in rows if int(r["adjusted_qty"]) < 0]
    elif filter_mode == "Zero Or Less":
        rows = [r for r in rows if int(r["adjusted_qty"]) <= 0]
    elif filter_mode == "Positive Only":
        rows = [r for r in rows if int(r["adjusted_qty"]) > 0]
    if sort_mode == "Adjusted Asc":
        rows.sort(key=lambda r: (int(r["adjusted_qty"]), str(r["item"]).casefold()))
    elif sort_mode == "Adjusted Desc":
        rows.sort(key=lambda r: (-int(r["adjusted_qty"]), str(r["item"]).casefold()))
    elif sort_mode == "Name A-Z":
        rows.sort(key=lambda r: str(r["item"]).casefold())
    else:
        rows.sort(key=lambda r: (int(r["adjusted_qty"]) > 0, int(r["adjusted_qty"]), str(r["item"]).casefold()))
    return rows


def build_item_stats(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    total = len(rows)
    if not total:
        return []
    buckets = [
        ("Negative", len([r for r in rows if int(r["adjusted_qty"]) < 0])),
        ("Zero", len([r for r in rows if int(r["adjusted_qty"]) == 0])),
        ("Positive", len([r for r in rows if int(r["adjusted_qty"]) > 0])),
    ]
    return [{"value": label, "count": count, "percent": count / total * 100.0} for label, count in buckets]


def _server_label(student_id: str) -> str:
    module = _load_module()
    return "JP Only" if module.is_jp_only(student_id) else "KR"


def build_metadata_table_rows(
    students: dict[str, dict],
    *,
    search_query: str = "",
    server_filter: str = "All",
) -> list[dict[str, object]]:
    query = search_query.strip().casefold()
    rows: list[dict[str, object]] = []
    for student_id, meta in students.items():
        asset_status = build_student_asset_status(student_id)
        row = {
            "student_id": student_id,
            "display_name": str(meta.get("display_name", "")),
            "server": _server_label(student_id),
            "favorite_item_jp": _display("has_favorite_item_jp", _resolved_field_value(student_id, meta, "has_favorite_item_jp")),
            "favorite_item_kr": _display("has_favorite_item_kr", _resolved_field_value(student_id, meta, "has_favorite_item_kr")),
            **asset_status,
            "group": str(meta.get("group", "") or ""),
            "variant": _display("variant", meta.get("variant")),
            "search_tags": _display("search_tags", meta.get("search_tags")),
            "kr_search_tags": _display("kr_search_tags", meta.get("kr_search_tags")),
            "school": _display("school", meta.get("school")),
            "rarity": _display("rarity", meta.get("rarity")),
            "attack_type": _display("attack_type", meta.get("attack_type")),
            "defense_type": _display("defense_type", meta.get("defense_type")),
            "role": _display("role", meta.get("role")),
            "position": _display("position", meta.get("position")),
            "weapon_type": _display("weapon_type", meta.get("weapon_type")),
            "template_name": _display("template_name", meta.get("template_name")),
        }
        haystack = " ".join(str(row[key]) for key, *_rest in METADATA_TABLE_COLUMNS).casefold()
        if query and query not in haystack:
            continue
        if server_filter == "KR" and row["server"] != "KR":
            continue
        if server_filter == "JP Only" and row["server"] != "JP Only":
            continue
        rows.append(row)
    rows.sort(key=lambda row: (str(row["display_name"]).casefold(), str(row["student_id"]).casefold()))
    return rows


def build_metadata_detail_rows(student_id: str, students: dict[str, dict]) -> list[tuple[str, str, str]]:
    meta = students.get(student_id)
    if meta is None:
        return []
    rows = [("student_id", "Student ID", student_id), ("server", "Server", _server_label(student_id))]
    for field_name, value in build_student_asset_status(student_id).items():
        rows.append((field_name, LABELS.get(field_name, field_name), value))
    forms = get_multi_form_students().get(student_id, ())
    rows.append(("multi_form_count", "Multi Forms", str(len(forms)) if forms else "single"))
    for index, form in enumerate(forms, start=1):
        summary_bits = [
            f"template={form.get('template_name', '')}",
            f"role={form.get('role', '')}",
            f"atk={form.get('attack_type', '')}",
            f"def={form.get('defense_type', '')}",
        ]
        passive = form.get("passive_stat")
        if passive:
            summary_bits.append(f"passive={_display('passive_stat', passive)}")
        rows.append((f"form_{index}", f"Form {form.get('label') or index}", "  ".join(summary_bits)))
    for field_name in DETAIL_FIELD_ORDER:
        if field_name in {"match_template_asset", "portrait_asset", "eleph_asset"}:
            continue
        rows.append((field_name, LABELS.get(field_name, field_name), _display(field_name, _resolved_field_value(student_id, meta, field_name))))
    return rows


def build_preview_diff_rows(current_meta: dict[str, object], next_meta: dict[str, object]) -> list[tuple[str, str, str, str]]:
    field_names = ["display_name", "template_name", "group", "variant", *SYNC_FIELDS]
    rows: list[tuple[str, str, str, str]] = []
    for field_name in field_names:
        current_value = _display(field_name, current_meta.get(field_name))
        next_value = _display(field_name, next_meta.get(field_name))
        status = "changed" if current_value != next_value else ""
        rows.append((LABELS.get(field_name, field_name), current_value, next_value, status))
    return rows


def command_get(args: argparse.Namespace) -> int:
    module = _reload_module()
    meta = module.get(args.student_id)
    if meta is None:
        print(f"student_id not found: {args.student_id}")
        return 1
    pprint.pprint(dict(meta), sort_dicts=False)
    return 0


def command_upsert(args: argparse.Namespace) -> int:
    updates: dict[str, object | None] = {}
    for spec in FIELD_SPECS:
        name = spec["name"]
        if name == "student_id":
            continue
        raw = getattr(args, name)
        if raw is not None:
            updates[name] = _form_value(str(name), raw)
    pprint.pprint(upsert_student(args.student_id, updates), sort_dicts=False)
    print(f"saved: {args.student_id}")
    return 0


def command_delete(args: argparse.Namespace) -> int:
    try:
        delete_student(args.student_id)
    except KeyError:
        print(f"student_id not found: {args.student_id}")
        return 1
    print(f"deleted: {args.student_id}")
    return 0


class StudentMetaToolApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("Student Metadata Debug Tool")
        self._ui_scale = get_ui_scale(self.root, base_width=1600, base_height=980)
        self.root.geometry(f"{scale_px(1720, self._ui_scale)}x{scale_px(1040, self._ui_scale)}")
        self.students = get_students()
        self.field_options = build_field_options(self.students)
        self.selected_student_id: str | None = None
        self.vars: dict[str, tk.StringVar] = {}
        self.widgets: dict[str, ttk.Widget] = {}
        self._editor_canvas: tk.Canvas | None = None
        self._editor_form: ttk.Frame | None = None
        self._wheel_target: tk.Misc | None = None
        self.attribute_var = tk.StringVar(value=LABELS[ANALYTICS_FIELDS[0]])
        self.attribute_value_var = tk.StringVar(value="")
        self.student_sort_var = tk.StringVar(value=STUDENT_SORTS[0])
        self.student_search_var = tk.StringVar()
        self.inventory_path = _pick_path(_candidate_inventory_paths())
        self.plan_path_var = tk.StringVar(value=str(_pick_path(_candidate_plan_paths())))
        self.item_sort_var = tk.StringVar(value=ITEM_SORTS[0])
        self.item_filter_var = tk.StringVar(value=ITEM_FILTERS[0])
        self.inventory: dict[str, dict] = {}
        self.plan_adjustments: dict[str, int] = {}
        self.attribute_value_combo: ttk.Combobox | None = None
        self.stats_tree: ttk.Treeview | None = None
        self.student_tree: ttk.Treeview | None = None
        self.item_stats_tree: ttk.Treeview | None = None
        self.item_tree: ttk.Treeview | None = None
        self.item_summary_var = tk.StringVar(value="")
        self.metadata_search_var = tk.StringVar()
        self.metadata_server_filter_var = tk.StringVar(value=SERVER_FILTERS[0])
        self.metadata_tree: ttk.Treeview | None = None
        self.detail_tree: ttk.Treeview | None = None
        self.detail_title_var = tk.StringVar(value="Select a student to inspect")
        self.preview_source_var = tk.StringVar()
        self.preview_student_id_var = tk.StringVar()
        self.preview_mark_jp_only_var = tk.BooleanVar(value=True)
        self.preview_summary_var = tk.StringVar(value="Enter a SchaleDB URL or slug to preview a student.")
        self.preview_tree: ttk.Treeview | None = None
        self.preview_payload: dict[str, object] | None = None
        self.form_summary_var = tk.StringVar(value="No student loaded")
        self.form_text: tk.Text | None = None
        self.merge_local_id_var = tk.StringVar()
        self.merge_paths_var = tk.StringVar()
        self.merge_summary_var = tk.StringVar(value="Manage SchaleDB merge paths for multi-form imports.")
        self.merge_tree: ttk.Treeview | None = None
        self._build_ui()
        self._refresh_student_list()
        self._new_student()
        self._refresh_attribute_value_options()
        self._refresh_student_analysis()
        self._reload_inventory_analysis()
        self._refresh_metadata_debug()
        self._refresh_schale_merge_path_list()

    def _build_ui(self) -> None:
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        notebook = ttk.Notebook(self.root)
        notebook.grid(row=0, column=0, sticky="nsew")
        editor_tab = ttk.Frame(notebook, padding=10)
        student_tab = ttk.Frame(notebook, padding=10)
        item_tab = ttk.Frame(notebook, padding=10)
        debug_tab = ttk.Frame(notebook, padding=10)
        notebook.add(editor_tab, text="Editor")
        notebook.add(student_tab, text="Student Stats")
        notebook.add(item_tab, text="Item Stats")
        notebook.add(debug_tab, text="DB Debug")
        self._build_editor_tab(editor_tab)
        self._build_student_tab(student_tab)
        self._build_item_tab(item_tab)
        self._build_debug_tab(debug_tab)

    def _build_editor_tab(self, parent: ttk.Frame) -> None:
        parent.columnconfigure(0, weight=0)
        parent.columnconfigure(1, weight=1)
        parent.rowconfigure(0, weight=1)
        left = ttk.Frame(parent, padding=(0, 0, 12, 0))
        left.grid(row=0, column=0, sticky="ns")
        left.columnconfigure(0, weight=1)
        left.rowconfigure(2, weight=1)
        ttk.Label(left, text="Students").grid(row=0, column=0, sticky="w")
        self.search_var = tk.StringVar()
        search_entry = ttk.Entry(left, textvariable=self.search_var, width=36)
        search_entry.grid(row=1, column=0, sticky="ew", pady=(6, 8))
        search_entry.bind("<KeyRelease>", lambda _e: self._refresh_student_list())
        list_frame = ttk.Frame(left)
        list_frame.grid(row=2, column=0, sticky="nsew")
        list_frame.columnconfigure(0, weight=1)
        list_frame.rowconfigure(0, weight=1)
        self.student_list = tk.Listbox(list_frame, width=40, exportselection=False)
        self.student_list.grid(row=0, column=0, sticky="nsew")
        list_scrollbar = ttk.Scrollbar(list_frame, orient="vertical", command=self.student_list.yview)
        list_scrollbar.grid(row=0, column=1, sticky="ns")
        self.student_list.configure(yscrollcommand=list_scrollbar.set)
        self.student_list.bind("<<ListboxSelect>>", self._on_select_student)
        self.student_list.bind("<Enter>", lambda _e: self._set_wheel_target(self.student_list))
        self.student_list.bind("<Leave>", lambda _e: self._set_wheel_target(None))
        left_buttons = ttk.Frame(left)
        left_buttons.grid(row=3, column=0, sticky="ew", pady=(8, 0))
        ttk.Button(left_buttons, text="New", command=self._new_student).grid(row=0, column=0, padx=(0, 6))
        ttk.Button(left_buttons, text="Reload", command=self._reload_students).grid(row=0, column=1)
        right = ttk.Frame(parent)
        right.grid(row=0, column=1, sticky="nsew")
        right.columnconfigure(0, weight=1)
        right.rowconfigure(1, weight=1)
        ttk.Label(right, text="Editor").grid(row=0, column=0, sticky="w")
        canvas = tk.Canvas(right, highlightthickness=0)
        canvas.grid(row=1, column=0, sticky="nsew")
        scrollbar = ttk.Scrollbar(right, orient="vertical", command=canvas.yview)
        scrollbar.grid(row=1, column=1, sticky="ns")
        canvas.configure(yscrollcommand=scrollbar.set)
        form = ttk.Frame(canvas, padding=(0, 8, 0, 8))
        form.columnconfigure(1, weight=1)
        form_window = canvas.create_window((0, 0), window=form, anchor="nw")
        form.bind("<Configure>", lambda _e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.bind(
            "<Configure>",
            lambda event: canvas.itemconfigure(form_window, width=max(event.width, scale_px(900, self._ui_scale))),
            add="+",
        )
        self._editor_canvas = canvas
        self._editor_form = form
        self._bind_scroll_region(canvas)
        self._bind_scroll_region(form)
        for row, spec in enumerate(FIELD_SPECS):
            name = str(spec["name"])
            label = str(spec["label"])
            display = f"{label} *" if spec.get("required") else label
            ttk.Label(form, text=display, width=22).grid(row=row, column=0, sticky="w", padx=(0, 12), pady=4)
            var = tk.StringVar()
            self.vars[name] = var
            if name in LIST_FIELDS or name in STRUCTURED_FIELDS:
                widget = ttk.Entry(form, textvariable=var, width=EDITOR_VALUE_FIELD_CHARS)
            else:
                combo_state = "normal" if name in FREE_TEXT_COMBO_FIELDS else "readonly"
                widget = ttk.Combobox(
                    form,
                    textvariable=var,
                    values=self.field_options.get(name, ("",)),
                    state=combo_state,
                    width=EDITOR_VALUE_FIELD_CHARS,
                )
            widget.grid(row=row, column=1, sticky="ew", pady=4)
            if isinstance(widget, ttk.Combobox):
                widget.bind("<MouseWheel>", self._on_combobox_mousewheel)
                widget.bind("<Button-4>", self._on_combobox_mousewheel)
                widget.bind("<Button-5>", self._on_combobox_mousewheel)
            self._bind_scroll_region(widget)
            self.widgets[name] = widget
        action_bar = ttk.Frame(right)
        action_bar.grid(row=2, column=0, sticky="ew", pady=(10, 0))
        ttk.Button(action_bar, text="Save", command=self._save_current).grid(row=0, column=0, padx=(0, 6))
        ttk.Button(action_bar, text="Delete", command=self._delete_current).grid(row=0, column=1, padx=(0, 6))
        ttk.Button(action_bar, text="Duplicate as New", command=self._duplicate_current).grid(row=0, column=2)
        self.status_var = tk.StringVar(value="Ready")
        ttk.Label(right, textvariable=self.status_var).grid(row=3, column=0, sticky="w", pady=(10, 0))

        form_frame = ttk.LabelFrame(right, text="Multi Form Overrides", padding=8)
        form_frame.grid(row=4, column=0, sticky="ew", pady=(10, 0))
        form_frame.columnconfigure(0, weight=1)
        ttk.Label(form_frame, textvariable=self.form_summary_var).grid(row=0, column=0, sticky="w")
        form_buttons = ttk.Frame(form_frame)
        form_buttons.grid(row=0, column=1, sticky="e", padx=(8, 0))
        ttk.Button(form_buttons, text="Load", command=self._load_multi_form_editor).grid(row=0, column=0, padx=(0, 6))
        ttk.Button(form_buttons, text="Seed 2 Forms", command=self._seed_multi_form_editor).grid(row=0, column=1, padx=(0, 6))
        ttk.Button(form_buttons, text="Save Forms", command=self._save_multi_form_editor).grid(row=0, column=2, padx=(0, 6))
        ttk.Button(form_buttons, text="Clear Forms", command=self._clear_multi_form_editor).grid(row=0, column=3)
        self.form_text = tk.Text(form_frame, height=8, width=96, wrap="none")
        self.form_text.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(8, 0))
        self._bind_scroll_region(self.form_text)

    def _build_student_tab(self, parent: ttk.Frame) -> None:
        parent.columnconfigure(0, weight=1)
        parent.rowconfigure(1, weight=1)
        controls = ttk.Frame(parent)
        controls.grid(row=0, column=0, sticky="ew", pady=(0, 10))
        for col in range(8):
            controls.columnconfigure(col, weight=1 if col in {1, 3, 5, 7} else 0)
        ttk.Label(controls, text="Attribute").grid(row=0, column=0, sticky="w")
        combo = ttk.Combobox(controls, textvariable=self.attribute_var, values=[LABELS[f] for f in ANALYTICS_FIELDS], state="readonly")
        combo.grid(row=0, column=1, sticky="ew", padx=(6, 12))
        combo.bind("<<ComboboxSelected>>", self._on_attribute_changed)
        ttk.Label(controls, text="Value").grid(row=0, column=2, sticky="w")
        self.attribute_value_combo = ttk.Combobox(controls, textvariable=self.attribute_value_var, values=("",), state="readonly")
        self.attribute_value_combo.grid(row=0, column=3, sticky="ew", padx=(6, 12))
        self.attribute_value_combo.bind("<<ComboboxSelected>>", lambda _e: self._refresh_student_analysis())
        ttk.Label(controls, text="Sort").grid(row=0, column=4, sticky="w")
        sort_combo = ttk.Combobox(controls, textvariable=self.student_sort_var, values=STUDENT_SORTS, state="readonly")
        sort_combo.grid(row=0, column=5, sticky="ew", padx=(6, 12))
        sort_combo.bind("<<ComboboxSelected>>", lambda _e: self._refresh_student_analysis())
        ttk.Label(controls, text="Search").grid(row=0, column=6, sticky="w")
        search_entry = ttk.Entry(controls, textvariable=self.student_search_var)
        search_entry.grid(row=0, column=7, sticky="ew")
        search_entry.bind("<KeyRelease>", lambda _e: self._refresh_student_analysis())
        panes = ttk.Panedwindow(parent, orient="horizontal")
        panes.grid(row=1, column=0, sticky="nsew")
        stats_frame = ttk.Frame(panes, padding=4)
        stats_frame.columnconfigure(0, weight=1)
        stats_frame.rowconfigure(1, weight=1)
        ttk.Label(stats_frame, text="Attribute Breakdown").grid(row=0, column=0, sticky="w", pady=(0, 6))
        self.stats_tree = ttk.Treeview(stats_frame, columns=("value", "count", "percent"), show="headings", height=20)
        for key, text, width in (("value", "Value", 220), ("count", "Students", 90), ("percent", "Percent", 100)):
            self.stats_tree.heading(key, text=text)
            self.stats_tree.column(key, width=width, anchor="w" if key == "value" else "e")
        self.stats_tree.grid(row=1, column=0, sticky="nsew")
        self.stats_tree.bind("<<TreeviewSelect>>", self._on_stat_row_selected)
        panes.add(stats_frame, weight=1)
        students_frame = ttk.Frame(panes, padding=4)
        students_frame.columnconfigure(0, weight=1)
        students_frame.rowconfigure(1, weight=1)
        ttk.Label(students_frame, text="Sorted Students").grid(row=0, column=0, sticky="w", pady=(0, 6))
        self.student_tree = ttk.Treeview(students_frame, columns=("student_id", "display_name", "value", "match"), show="headings", height=20)
        for key, text, width in (("student_id", "Student ID", 180), ("display_name", "Name", 180), ("value", "Attribute Value", 260), ("match", "Match", 80)):
            self.student_tree.heading(key, text=text)
            self.student_tree.column(key, width=width, anchor="center" if key == "match" else "w")
        self.student_tree.grid(row=1, column=0, sticky="nsew")
        panes.add(students_frame, weight=2)

    def _build_item_tab(self, parent: ttk.Frame) -> None:
        parent.columnconfigure(0, weight=1)
        parent.rowconfigure(2, weight=1)
        paths_frame = ttk.Frame(parent)
        paths_frame.grid(row=0, column=0, sticky="ew")
        paths_frame.columnconfigure(1, weight=1)
        paths_frame.columnconfigure(3, weight=1)
        ttk.Label(paths_frame, text="Inventory").grid(row=0, column=0, sticky="w")
        ttk.Label(paths_frame, text=str(self.inventory_path)).grid(row=0, column=1, sticky="ew", padx=(6, 12))
        ttk.Label(paths_frame, text="Plan Delta JSON").grid(row=0, column=2, sticky="w")
        ttk.Entry(paths_frame, textvariable=self.plan_path_var).grid(row=0, column=3, sticky="ew", padx=(6, 12))
        ttk.Button(paths_frame, text="Reload Items", command=self._reload_inventory_analysis).grid(row=0, column=4)
        controls = ttk.Frame(parent)
        controls.grid(row=1, column=0, sticky="ew", pady=(10, 10))
        controls.columnconfigure(1, weight=1)
        controls.columnconfigure(3, weight=1)
        ttk.Label(controls, text="Sort").grid(row=0, column=0, sticky="w")
        sort_combo = ttk.Combobox(controls, textvariable=self.item_sort_var, values=ITEM_SORTS, state="readonly")
        sort_combo.grid(row=0, column=1, sticky="ew", padx=(6, 12))
        sort_combo.bind("<<ComboboxSelected>>", lambda _e: self._refresh_item_analysis())
        ttk.Label(controls, text="Filter").grid(row=0, column=2, sticky="w")
        filter_combo = ttk.Combobox(controls, textvariable=self.item_filter_var, values=ITEM_FILTERS, state="readonly")
        filter_combo.grid(row=0, column=3, sticky="ew")
        filter_combo.bind("<<ComboboxSelected>>", lambda _e: self._refresh_item_analysis())
        panes = ttk.Panedwindow(parent, orient="horizontal")
        panes.grid(row=2, column=0, sticky="nsew")
        item_stats_frame = ttk.Frame(panes, padding=4)
        item_stats_frame.columnconfigure(0, weight=1)
        item_stats_frame.rowconfigure(2, weight=1)
        ttk.Label(item_stats_frame, text="Adjusted Inventory State").grid(row=0, column=0, sticky="w", pady=(0, 6))
        ttk.Label(item_stats_frame, textvariable=self.item_summary_var).grid(row=1, column=0, sticky="w", pady=(0, 8))
        self.item_stats_tree = ttk.Treeview(item_stats_frame, columns=("value", "count", "percent"), show="headings", height=12)
        for key, text, width in (("value", "Bucket", 160), ("count", "Items", 90), ("percent", "Percent", 100)):
            self.item_stats_tree.heading(key, text=text)
            self.item_stats_tree.column(key, width=width, anchor="w" if key == "value" else "e")
        self.item_stats_tree.grid(row=2, column=0, sticky="nsew")
        panes.add(item_stats_frame, weight=1)
        item_rows_frame = ttk.Frame(panes, padding=4)
        item_rows_frame.columnconfigure(0, weight=1)
        item_rows_frame.rowconfigure(1, weight=1)
        ttk.Label(item_rows_frame, text="Items").grid(row=0, column=0, sticky="w", pady=(0, 6))
        self.item_tree = ttk.Treeview(item_rows_frame, columns=("item", "current_qty", "plan_delta", "adjusted_qty", "index"), show="headings", height=20)
        for key, text, width in (("item", "Item", 280), ("current_qty", "Current", 90), ("plan_delta", "Plan Delta", 90), ("adjusted_qty", "Adjusted", 90), ("index", "Index", 70)):
            self.item_tree.heading(key, text=text)
            self.item_tree.column(key, width=width, anchor="w" if key == "item" else "e")
        self.item_tree.grid(row=1, column=0, sticky="nsew")
        panes.add(item_rows_frame, weight=2)

    def _build_debug_tab(self, parent: ttk.Frame) -> None:
        parent.columnconfigure(0, weight=1)
        parent.rowconfigure(1, weight=1)
        sync_frame = ttk.LabelFrame(parent, text="SchaleDB Import / Server Control", padding=10)
        sync_frame.grid(row=0, column=0, sticky="ew", pady=(0, 10))
        for col in range(8):
            sync_frame.columnconfigure(col, weight=1 if col in {1, 3, 5} else 0)
        ttk.Label(sync_frame, text="SchaleDB URL / slug").grid(row=0, column=0, sticky="w")
        preview_entry = ttk.Entry(sync_frame, textvariable=self.preview_source_var)
        preview_entry.grid(row=0, column=1, sticky="ew", padx=(6, 12))
        ttk.Label(sync_frame, text="Local Student ID").grid(row=0, column=2, sticky="w")
        ttk.Entry(sync_frame, textvariable=self.preview_student_id_var).grid(row=0, column=3, sticky="ew", padx=(6, 12))
        ttk.Checkbutton(sync_frame, text="Mark as JP-only after save", variable=self.preview_mark_jp_only_var).grid(row=0, column=4, columnspan=2, sticky="w")
        ttk.Button(sync_frame, text="Preview Pull", command=self._preview_schale_import).grid(row=0, column=6, padx=(0, 6))
        ttk.Button(sync_frame, text="Import & Save", command=self._save_preview_to_db).grid(row=0, column=7)
        ttk.Label(sync_frame, textvariable=self.preview_summary_var).grid(row=1, column=0, columnspan=8, sticky="w", pady=(8, 8))
        preview_buttons = ttk.Frame(sync_frame)
        preview_buttons.grid(row=2, column=0, columnspan=8, sticky="w")
        ttk.Button(preview_buttons, text="Load Preview Into Editor", command=self._apply_preview_to_editor).grid(row=0, column=0, padx=(0, 6))
        ttk.Button(preview_buttons, text="Use Selected Student", command=self._prefill_preview_from_selection).grid(row=0, column=1, padx=(0, 6))
        ttk.Button(preview_buttons, text="Set Selected To JP-only", command=lambda: self._set_selected_server_state(True)).grid(row=0, column=2, padx=(0, 6))
        ttk.Button(preview_buttons, text="Transfer Selected JP -> KR", command=lambda: self._set_selected_server_state(False)).grid(row=0, column=3)
        self.preview_tree = ttk.Treeview(sync_frame, columns=("field", "current", "new", "status"), show="headings", height=8)
        for key, text, width in (("field", "Field", 180), ("current", "Current", 240), ("new", "Preview", 240), ("status", "Changed", 70)):
            self.preview_tree.heading(key, text=text)
            self.preview_tree.column(key, width=width, anchor="center" if key == "status" else "w")
        self.preview_tree.grid(row=3, column=0, columnspan=8, sticky="ew", pady=(8, 0))

        merge_frame = ttk.LabelFrame(sync_frame, text="SchaleDB Merge Paths", padding=8)
        merge_frame.grid(row=4, column=0, columnspan=8, sticky="ew", pady=(10, 0))
        merge_frame.columnconfigure(1, weight=1)
        merge_frame.columnconfigure(3, weight=1)
        ttk.Label(merge_frame, text="Local ID").grid(row=0, column=0, sticky="w")
        ttk.Entry(merge_frame, textvariable=self.merge_local_id_var, width=28).grid(row=0, column=1, sticky="ew", padx=(6, 12))
        ttk.Label(merge_frame, text="SchaleDB slugs").grid(row=0, column=2, sticky="w")
        ttk.Entry(merge_frame, textvariable=self.merge_paths_var).grid(row=0, column=3, sticky="ew", padx=(6, 12))
        merge_buttons = ttk.Frame(merge_frame)
        merge_buttons.grid(row=0, column=4, sticky="e")
        ttk.Button(merge_buttons, text="Use Selected", command=self._prefill_merge_path_from_selection).grid(row=0, column=0, padx=(0, 6))
        ttk.Button(merge_buttons, text="Load", command=self._load_merge_path_editor).grid(row=0, column=1, padx=(0, 6))
        ttk.Button(merge_buttons, text="Save", command=self._save_merge_path_editor).grid(row=0, column=2, padx=(0, 6))
        ttk.Button(merge_buttons, text="Clear", command=self._clear_merge_path_editor).grid(row=0, column=3)
        ttk.Label(merge_frame, textvariable=self.merge_summary_var).grid(row=1, column=0, columnspan=5, sticky="w", pady=(6, 6))
        self.merge_tree = ttk.Treeview(merge_frame, columns=("local_id", "paths"), show="headings", height=4)
        for key, text, width in (("local_id", "Local ID", 180), ("paths", "SchaleDB slugs", 520)):
            self.merge_tree.heading(key, text=text)
            self.merge_tree.column(key, width=width, anchor="w")
        self.merge_tree.grid(row=2, column=0, columnspan=5, sticky="ew")
        self.merge_tree.bind("<<TreeviewSelect>>", self._on_merge_path_selected)

        body = ttk.Panedwindow(parent, orient="horizontal")
        body.grid(row=1, column=0, sticky="nsew")
        table_frame = ttk.Frame(body, padding=4)
        table_frame.columnconfigure(0, weight=1)
        table_frame.rowconfigure(2, weight=1)
        filters = ttk.Frame(table_frame)
        filters.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        filters.columnconfigure(1, weight=1)
        filters.columnconfigure(3, weight=1)
        ttk.Label(filters, text="Search").grid(row=0, column=0, sticky="w")
        search_entry = ttk.Entry(filters, textvariable=self.metadata_search_var)
        search_entry.grid(row=0, column=1, sticky="ew", padx=(6, 12))
        search_entry.bind("<KeyRelease>", lambda _e: self._refresh_metadata_debug())
        ttk.Label(filters, text="Server").grid(row=0, column=2, sticky="w")
        server_combo = ttk.Combobox(filters, textvariable=self.metadata_server_filter_var, values=SERVER_FILTERS, state="readonly")
        server_combo.grid(row=0, column=3, sticky="ew")
        server_combo.bind("<<ComboboxSelected>>", lambda _e: self._refresh_metadata_debug())
        ttk.Label(table_frame, text="Student Metadata Table").grid(row=1, column=0, sticky="w", pady=(0, 6))
        self.metadata_tree = ttk.Treeview(
            table_frame,
            columns=tuple(key for key, _text, _width in METADATA_TABLE_COLUMNS),
            show="headings",
            height=18,
        )
        for key, text, width in METADATA_TABLE_COLUMNS:
            self.metadata_tree.heading(key, text=text)
            self.metadata_tree.column(key, width=width, anchor="w")
        self.metadata_tree.grid(row=2, column=0, sticky="nsew")
        self.metadata_tree.bind("<<TreeviewSelect>>", self._on_metadata_selected)
        body.add(table_frame, weight=3)

        detail_frame = ttk.Frame(body, padding=4)
        detail_frame.columnconfigure(0, weight=1)
        detail_frame.rowconfigure(1, weight=1)
        ttk.Label(detail_frame, textvariable=self.detail_title_var).grid(row=0, column=0, sticky="w", pady=(0, 6))
        self.detail_tree = ttk.Treeview(detail_frame, columns=("field", "label", "value"), show="headings", height=18)
        for key, text, width in (("field", "Field", 160), ("label", "Label", 180), ("value", "Value", 280)):
            self.detail_tree.heading(key, text=text)
            self.detail_tree.column(key, width=width, anchor="w")
        self.detail_tree.grid(row=1, column=0, sticky="nsew")
        body.add(detail_frame, weight=2)

    def _refresh_schale_merge_path_list(self, *, select_student_id: str | None = None) -> None:
        merge_paths = get_schale_merge_paths()
        if self.merge_tree is not None:
            for item_id in self.merge_tree.get_children():
                self.merge_tree.delete(item_id)
            for student_id, paths in merge_paths.items():
                self.merge_tree.insert("", "end", iid=student_id, values=(student_id, ", ".join(paths)))
        if select_student_id and self.merge_tree is not None and self.merge_tree.exists(select_student_id):
            self.merge_tree.selection_set(select_student_id)
            self.merge_tree.focus(select_student_id)
        self.merge_summary_var.set(f"{len(merge_paths)} merge path rules loaded.")

    def _selected_merge_local_id(self) -> str | None:
        if self.merge_tree is None:
            return None
        selection = self.merge_tree.selection()
        return str(selection[0]) if selection else None

    def _on_merge_path_selected(self, _event=None) -> None:
        student_id = self._selected_merge_local_id()
        if student_id:
            self._load_merge_path_editor(student_id)

    def _load_merge_path_editor(self, student_id: str | None = None) -> None:
        student_id = student_id or self.merge_local_id_var.get().strip()
        if not student_id:
            messagebox.showinfo("Merge Paths", "Enter or select a local student ID first.")
            return
        merge_paths = get_schale_merge_paths()
        paths = merge_paths.get(student_id, ())
        self.merge_local_id_var.set(student_id)
        self.merge_paths_var.set(", ".join(paths))
        label = ", ".join(paths) if paths else "no merge rule"
        self.merge_summary_var.set(f"{student_id}: {label}")

    def _prefill_merge_path_from_selection(self) -> None:
        student_id = self._selected_metadata_student_id() or self.vars["student_id"].get().strip()
        if not student_id:
            messagebox.showinfo("Merge Paths", "Select a student from the table or editor first.")
            return
        merge_paths = get_schale_merge_paths()
        paths = merge_paths.get(student_id) or (local_id_to_schale_path(student_id),)
        self.merge_local_id_var.set(student_id)
        self.merge_paths_var.set(", ".join(paths))
        self.merge_summary_var.set(f"Editing merge rule for {student_id}.")

    def _parse_merge_path_editor(self) -> tuple[str, tuple[str, ...]]:
        student_id = self.merge_local_id_var.get().strip()
        if not student_id:
            raise ValueError("Local ID is required.")
        paths = tuple(part.strip().lower() for part in re.split(r"[,\s]+", self.merge_paths_var.get()) if part.strip())
        if len(paths) < 2:
            raise ValueError("Enter at least two SchaleDB slugs for a merge rule.")
        return student_id, paths

    def _save_merge_path_editor(self) -> None:
        try:
            student_id, paths = self._parse_merge_path_editor()
            merge_paths = get_schale_merge_paths()
            merge_paths[student_id] = paths
            _write_schale_merge_paths(merge_paths)
        except Exception as exc:
            messagebox.showerror("Merge Path Save Failed", str(exc))
            return
        self._refresh_schale_merge_path_list(select_student_id=student_id)
        self.merge_summary_var.set(f"Saved {student_id}: {', '.join(paths)}")
        self.status_var.set(f"Saved SchaleDB merge paths: {student_id}")

    def _clear_merge_path_editor(self) -> None:
        student_id = self.merge_local_id_var.get().strip() or self._selected_merge_local_id()
        if not student_id:
            self.merge_paths_var.set("")
            return
        try:
            merge_paths = get_schale_merge_paths()
            removed = merge_paths.pop(student_id, None)
            _write_schale_merge_paths(merge_paths)
        except Exception as exc:
            messagebox.showerror("Merge Path Clear Failed", str(exc))
            return
        self.merge_local_id_var.set(student_id)
        self.merge_paths_var.set("")
        self._refresh_schale_merge_path_list()
        self.merge_summary_var.set(f"Cleared {student_id}." if removed else f"No merge rule existed for {student_id}.")
        self.status_var.set(f"Cleared SchaleDB merge paths: {student_id}")

    def _current_attribute_name(self) -> str:
        for field_name in ANALYTICS_FIELDS:
            if LABELS[field_name] == self.attribute_var.get():
                return field_name
        return ANALYTICS_FIELDS[0]

    def _populate_tree(self, tree: ttk.Treeview | None, rows: list[tuple[object, ...]]) -> None:
        if tree is None:
            return
        for item_id in tree.get_children():
            tree.delete(item_id)
        for row in rows:
            tree.insert("", "end", values=row)

    def _refresh_student_list(self) -> None:
        query = self.search_var.get().strip().lower()
        previous_selection = self.vars.get("student_id").get().strip() if self.vars.get("student_id") else ""
        first_visible = self.student_list.nearest(0) if self.student_list.size() else 0
        self.student_list.delete(0, tk.END)
        self._list_ids: list[str] = []
        for sid in sorted(self.students):
            name = str(self.students[sid].get("display_name", ""))
            if query and query not in _student_search_blob(sid, self.students[sid]):
                continue
            self._list_ids.append(sid)
            self.student_list.insert(tk.END, f"{sid} | {name}")
        if previous_selection and previous_selection in self._list_ids:
            index = self._list_ids.index(previous_selection)
            self.student_list.selection_clear(0, tk.END)
            self.student_list.selection_set(index)
            self.student_list.activate(index)
        if self.student_list.size():
            max_index = max(0, min(first_visible, self.student_list.size() - 1))
            self.student_list.yview(max_index)

    def _clear_form(self) -> None:
        for var in self.vars.values():
            var.set("")


    def _current_editor_student_id(self) -> str:
        return self.vars.get("student_id", tk.StringVar()).get().strip()

    def _set_multi_form_editor_text(self, text: str) -> None:
        if self.form_text is None:
            return
        self.form_text.delete("1.0", tk.END)
        if text:
            self.form_text.insert("1.0", text)

    def _multi_form_text_for_student(self, student_id: str) -> str:
        forms = get_multi_form_students().get(student_id, ())
        if not forms:
            return ""
        return pprint.pformat(tuple(dict(form) for form in forms), width=100, sort_dicts=False)

    def _refresh_multi_form_summary(self, student_id: str | None = None) -> None:
        student_id = student_id or self._current_editor_student_id()
        if not student_id:
            self.form_summary_var.set("No student loaded")
            return
        forms = get_multi_form_students().get(student_id, ())
        if not forms:
            self.form_summary_var.set(f"{student_id}: single form")
            return
        labels = ", ".join(str(form.get("label") or index) for index, form in enumerate(forms, start=1))
        self.form_summary_var.set(f"{student_id}: {len(forms)} forms ({labels})")

    def _load_multi_form_editor(self, student_id: str | None = None) -> None:
        student_id = student_id or self._current_editor_student_id()
        self._set_multi_form_editor_text(self._multi_form_text_for_student(student_id) if student_id else "")
        self._refresh_multi_form_summary(student_id)

    def _seed_multi_form_editor(self) -> None:
        student_id = self._current_editor_student_id()
        if not student_id:
            messagebox.showinfo("Multi Form", "Set a student_id first.")
            return
        template_name = self.vars.get("template_name", tk.StringVar(value=f"{student_id}.png")).get().strip() or f"{student_id}.png"
        stem = Path(template_name).stem
        suffix = Path(template_name).suffix or ".png"
        forms = (
            {"label": "1", "template_name": template_name},
            {"label": "2", "template_name": f"{stem}_1{suffix}"},
        )
        self._set_multi_form_editor_text(pprint.pformat(forms, width=100, sort_dicts=False))
        self.form_summary_var.set(f"{student_id}: seeded 2 forms")

    def _parse_multi_form_editor(self) -> tuple[dict[str, object], ...]:
        if self.form_text is None:
            return ()
        raw = self.form_text.get("1.0", tk.END).strip()
        if not raw:
            return ()
        parsed = ast.literal_eval(raw)
        if isinstance(parsed, dict):
            parsed_forms = (parsed,)
        elif isinstance(parsed, (list, tuple)):
            parsed_forms = tuple(parsed)
        else:
            raise ValueError("Forms must be a dict, list, or tuple of dicts.")
        forms: list[dict[str, object]] = []
        for index, value in enumerate(parsed_forms, start=1):
            if not isinstance(value, dict):
                raise ValueError(f"Form {index} must be a dict.")
            form = dict(value)
            form.setdefault("label", str(index))
            template_name = str(form.get("template_name") or "").strip()
            if not template_name:
                raise ValueError(f"Form {index} requires template_name.")
            form["template_name"] = template_name
            forms.append(form)
        return tuple(forms)

    def _save_multi_form_editor(self) -> None:
        student_id = self._current_editor_student_id()
        if not student_id:
            messagebox.showinfo("Multi Form", "Set a student_id first.")
            return
        try:
            forms = self._parse_multi_form_editor()
            all_forms = get_multi_form_students()
            if forms:
                all_forms[student_id] = forms
            else:
                all_forms.pop(student_id, None)
            _write_multi_form_students(all_forms)
        except Exception as exc:
            messagebox.showerror("Multi Form Save Failed", str(exc))
            return
        self._refresh_multi_form_summary(student_id)
        self._refresh_metadata_debug(select_student_id=student_id)
        self.status_var.set(f"Saved forms: {student_id}")

    def _clear_multi_form_editor(self) -> None:
        student_id = self._current_editor_student_id()
        self._set_multi_form_editor_text("")
        if student_id:
            self.form_summary_var.set(f"{student_id}: forms cleared in editor")
        else:
            self.form_summary_var.set("No student loaded")

    def _load_student_into_form(self, student_id: str) -> None:
        self.selected_student_id = student_id
        meta = self.students[student_id]
        self._clear_form()
        self.vars["student_id"].set(student_id)
        for spec in FIELD_SPECS:
            name = str(spec["name"])
            if name != "student_id":
                self.vars[name].set(_display(name, _resolved_field_value(student_id, meta, name)))
        self._load_multi_form_editor(student_id)
        self.status_var.set(f"Loaded: {student_id}")

    def _on_select_student(self, _event=None) -> None:
        selection = self.student_list.curselection()
        if selection:
            self._load_student_into_form(self._list_ids[selection[0]])

    def _new_student(self) -> None:
        self.selected_student_id = None
        self._clear_form()
        self._set_multi_form_editor_text("")
        self._refresh_multi_form_summary("")
        self.status_var.set("New student form")

    def _refresh_field_options(self) -> None:
        self.field_options = build_field_options(self.students)
        for field_name, widget in self.widgets.items():
            if isinstance(widget, ttk.Combobox):
                widget["values"] = self.field_options.get(field_name, ("",))

    def _duplicate_current(self) -> None:
        current_id = self.vars["student_id"].get().strip()
        if not current_id:
            messagebox.showinfo("Duplicate", "Load a student first.")
            return
        self.vars["student_id"].set(f"{current_id}_copy")
        self._seed_multi_form_editor() if get_multi_form_students().get(current_id) else self._set_multi_form_editor_text("")
        self.status_var.set("Duplicated into new draft")

    def _collect_form_data(self) -> tuple[str, dict[str, object | None]]:
        student_id = self.vars["student_id"].get().strip()
        if not student_id:
            raise ValueError("student_id is required")
        updates: dict[str, object | None] = {}
        for spec in FIELD_SPECS:
            name = str(spec["name"])
            if name == "student_id":
                continue
            value = _form_value(name, self.vars[name].get())
            if spec.get("required") and value is None:
                raise ValueError(f"{spec['label']} is required")
            if value is not None:
                updates[name] = value
        return student_id, updates

    def _save_current(self) -> None:
        try:
            student_id, updates = self._collect_form_data()
            upsert_student(student_id, updates)
        except Exception as exc:
            messagebox.showerror("Save failed", str(exc))
            return
        self._refresh_all_views(preserve_student_id=student_id)
        self.status_var.set(f"Saved: {student_id}")
        messagebox.showinfo("Saved", f"{student_id} saved successfully.")

    def _delete_current(self) -> None:
        student_id = self.vars["student_id"].get().strip()
        if not student_id:
            messagebox.showinfo("Delete", "No student selected.")
            return
        if student_id not in self.students:
            messagebox.showinfo("Delete", "Student does not exist.")
            return
        if not messagebox.askyesno("Delete", f"Delete '{student_id}'?"):
            return
        try:
            delete_student(student_id)
        except Exception as exc:
            messagebox.showerror("Delete failed", str(exc))
            return
        self._refresh_all_views()
        self._new_student()
        self.status_var.set(f"Deleted: {student_id}")

    def _reload_students(self) -> None:
        self._refresh_all_views(preserve_student_id=self.vars["student_id"].get().strip() or None)
        self.status_var.set("Reloaded from core.student_meta")

    def _on_attribute_changed(self, _event=None) -> None:
        self._refresh_attribute_value_options()
        self._refresh_student_analysis()

    def _on_stat_row_selected(self, _event=None) -> None:
        if self.stats_tree is None or not self.stats_tree.selection():
            return
        value = str(self.stats_tree.item(self.stats_tree.selection()[0], "values")[0])
        self.attribute_value_var.set("" if value == "(missing)" else value)
        self._refresh_student_analysis()

    def _refresh_attribute_value_options(self) -> None:
        options = collect_attribute_value_options(self.students, self._current_attribute_name())
        if self.attribute_value_combo is not None:
            self.attribute_value_combo["values"] = options
        if self.attribute_value_var.get() not in options:
            self.attribute_value_var.set("")

    def _refresh_student_analysis(self) -> None:
        field_name = self._current_attribute_name()
        stats = build_attribute_stats(self.students, field_name)
        self._populate_tree(self.stats_tree, [(r["value"], r["count"], f"{float(r['percent']):.1f}%") for r in stats])
        rows = build_student_attribute_rows(self.students, field_name, self.attribute_value_var.get().strip(), self.student_sort_var.get(), self.student_search_var.get())
        self._populate_tree(self.student_tree, [(r["student_id"], r["display_name"], r["display_value"], "yes" if r["matches"] else "") for r in rows])

    def _reload_inventory_analysis(self) -> None:
        self.inventory = load_inventory_snapshot(self.inventory_path)
        self.plan_adjustments = load_item_plan_adjustments(Path(self.plan_path_var.get().strip()))
        self._refresh_item_analysis()

    def _refresh_item_analysis(self) -> None:
        rows = build_item_rows(self.inventory, self.plan_adjustments)
        stats = build_item_stats(rows)
        filtered = filter_and_sort_item_rows(rows, self.item_filter_var.get(), self.item_sort_var.get())
        total_unique = len(rows)
        negative = len([r for r in rows if int(r["adjusted_qty"]) < 0])
        zero_or_less = len([r for r in rows if int(r["adjusted_qty"]) <= 0])
        current_sum = sum(int(r["current_qty"]) for r in rows)
        delta_sum = sum(int(r["plan_delta"]) for r in rows)
        adjusted_sum = sum(int(r["adjusted_qty"]) for r in rows)
        self.item_summary_var.set(
            f"Unique={total_unique}  Negative={negative}  ZeroOrLess={zero_or_less}  "
            f"CurrentSum={current_sum}  PlanDeltaSum={delta_sum}  AdjustedSum={adjusted_sum}"
        )
        self._populate_tree(self.item_stats_tree, [(r["value"], r["count"], f"{float(r['percent']):.1f}%") for r in stats])
        self._populate_tree(self.item_tree, [(r["item"], r["current_qty"], r["plan_delta"], r["adjusted_qty"], "" if int(r["index"]) < 0 else r["index"]) for r in filtered])

    def _refresh_all_views(self, *, preserve_student_id: str | None = None) -> None:
        list_first_visible = self.student_list.nearest(0) if hasattr(self, "student_list") and self.student_list.size() else 0
        self.students = get_students()
        self._refresh_field_options()
        self._refresh_student_list()
        if hasattr(self, "student_list") and self.student_list.size():
            self.student_list.yview(max(0, min(list_first_visible, self.student_list.size() - 1)))
        self._refresh_attribute_value_options()
        self._refresh_student_analysis()
        self._refresh_metadata_debug(select_student_id=preserve_student_id)
        self._refresh_schale_merge_path_list(select_student_id=preserve_student_id)
        if preserve_student_id and preserve_student_id in self.students:
            self._load_student_into_form(preserve_student_id)
        elif preserve_student_id is None:
            self._new_student()

    def _refresh_metadata_debug(self, *, select_student_id: str | None = None) -> None:
        rows = build_metadata_table_rows(
            self.students,
            search_query=self.metadata_search_var.get(),
            server_filter=self.metadata_server_filter_var.get(),
        )
        if self.metadata_tree is not None:
            for item_id in self.metadata_tree.get_children():
                self.metadata_tree.delete(item_id)
            for row in rows:
                item_id = str(row["student_id"])
                values = tuple(row[key] for key, _text, _width in METADATA_TABLE_COLUMNS)
                self.metadata_tree.insert("", "end", iid=item_id, values=values)

        target_id = select_student_id
        if target_id is None and self.metadata_tree is not None:
            selection = self.metadata_tree.selection()
            if selection:
                target_id = selection[0]
        if target_id and self.metadata_tree is not None and self.metadata_tree.exists(target_id):
            self.metadata_tree.selection_set(target_id)
            self.metadata_tree.focus(target_id)
            self._populate_detail_for_student(target_id)
        elif rows:
            self._populate_detail_for_student(str(rows[0]["student_id"]))
        else:
            self.detail_title_var.set("No students match the current filter")
            self._populate_tree(self.detail_tree, [])

    def _set_wheel_target(self, widget: tk.Misc | None) -> None:
        self._wheel_target = widget

    def _bind_scroll_region(self, widget: tk.Misc) -> None:
        widget.bind("<Enter>", lambda _e, target=widget: self._set_wheel_target(target))
        widget.bind("<Leave>", lambda _e: self._set_wheel_target(None))
        widget.bind("<MouseWheel>", self._on_mousewheel)
        widget.bind("<Button-4>", self._on_mousewheel)
        widget.bind("<Button-5>", self._on_mousewheel)

    def _mousewheel_steps(self, event) -> int:
        if getattr(event, "num", None) == 4:
            return -1
        if getattr(event, "num", None) == 5:
            return 1
        delta = int(getattr(event, "delta", 0))
        if delta == 0:
            return 0
        return -1 if delta > 0 else 1

    def _scroll_widget(self, widget: tk.Misc, steps: int) -> bool:
        if steps == 0:
            return False
        try:
            if isinstance(widget, tk.Listbox):
                widget.yview_scroll(steps, "units")
                return True
            if widget is self._editor_canvas:
                widget.yview_scroll(steps, "units")
                return True
        except tk.TclError:
            return False
        return False

    def _on_mousewheel(self, event):
        steps = self._mousewheel_steps(event)
        widget = self._wheel_target
        while widget is not None:
            if self._scroll_widget(widget, steps):
                return "break"
            widget = getattr(widget, "master", None)
        return None

    def _on_combobox_mousewheel(self, event):
        widget = event.widget
        if self.root.focus_get() is widget:
            return None
        return self._on_mousewheel(event) or "break"

    def _populate_detail_for_student(self, student_id: str) -> None:
        rows = build_metadata_detail_rows(student_id, self.students)
        name = self.students.get(student_id, {}).get("display_name", "")
        self.detail_title_var.set(f"{student_id} | {name}")
        self._populate_tree(self.detail_tree, rows)

    def _selected_metadata_student_id(self) -> str | None:
        if self.metadata_tree is None:
            return None
        selection = self.metadata_tree.selection()
        return selection[0] if selection else None

    def _on_metadata_selected(self, _event=None) -> None:
        student_id = self._selected_metadata_student_id()
        if student_id:
            self._populate_detail_for_student(student_id)

    def _prefill_preview_from_selection(self) -> None:
        student_id = self._selected_metadata_student_id() or self.vars["student_id"].get().strip()
        if not student_id:
            messagebox.showinfo("SchaleDB Preview", "Select a student from the table or editor first.")
            return
        self.preview_student_id_var.set(student_id)
        self.preview_source_var.set(local_id_to_schale_path(student_id))
        self.preview_mark_jp_only_var.set(student_id in get_jp_only_ids())
        self._preview_schale_import()

    def _preview_schale_import(self) -> None:
        source = self.preview_source_var.get().strip()
        preferred_student_id = self.preview_student_id_var.get().strip()
        if not source and preferred_student_id:
            source = local_id_to_schale_path(preferred_student_id)
            self.preview_source_var.set(source)
        if not source:
            messagebox.showinfo("SchaleDB Preview", "Enter a SchaleDB URL or student slug first.")
            return
        try:
            payload = build_student_meta_from_schale(
                source,
                existing_students=self.students,
                existing_multi_form_students=get_multi_form_students(),
                preferred_student_id=preferred_student_id or None,
            )
        except Exception as exc:
            messagebox.showerror("SchaleDB Preview Failed", str(exc))
            return

        self.preview_payload = payload
        resolved_student_id = str(payload["student_id"])
        is_new = bool(payload["is_new"])
        slug = str(payload["slug"])
        changed = len(payload["changed_fields"])
        form_count = len(payload.get("multi_form_meta") or ())
        form_changed = bool(payload.get("multi_form_changed"))
        try:
            parsed_slug = parse_student_source(source)
        except Exception:
            parsed_slug = slug
        self.preview_source_var.set(parsed_slug)
        self.preview_student_id_var.set(resolved_student_id)
        if is_new and resolved_student_id not in get_jp_only_ids():
            self.preview_mark_jp_only_var.set(True)
        current_meta = payload["current_meta"]
        next_meta = payload["meta"]
        form_note = f"  forms={form_count}{' changed' if form_changed else ''}" if form_count else ""
        self.preview_summary_var.set(
            f"Preview ready: slug={slug}  local_id={resolved_student_id}  "
            f"{'new student' if is_new else 'existing student'}  changed_fields={changed}{form_note}"
        )
        self._populate_tree(self.preview_tree, build_preview_diff_rows(current_meta, next_meta))

    def _apply_preview_to_editor(self) -> None:
        if not self.preview_payload:
            messagebox.showinfo("Load Preview", "Preview a SchaleDB student first.")
            return
        student_id = str(self.preview_payload["student_id"])
        meta = dict(self.preview_payload["meta"])
        self.selected_student_id = None
        self._clear_form()
        self.vars["student_id"].set(student_id)
        for field_name, value in meta.items():
            if field_name in self.vars:
                self.vars[field_name].set(_display(field_name, value))
        forms = tuple(dict(form) for form in (self.preview_payload.get("multi_form_meta") or ()))
        if forms:
            self._set_multi_form_editor_text(pprint.pformat(forms, width=100, sort_dicts=False))
            self.form_summary_var.set(f"{student_id}: preview loaded with {len(forms)} forms")
        else:
            self._set_multi_form_editor_text("")
            self._refresh_multi_form_summary(student_id)
        self.status_var.set(f"Preview loaded into editor: {student_id}")

    def _save_preview_to_db(self) -> None:
        if not self.preview_payload:
            self._preview_schale_import()
            if not self.preview_payload:
                return
        student_id = str(self.preview_payload["student_id"])
        meta = dict(self.preview_payload["meta"])
        was_jp_only = student_id in get_jp_only_ids()
        next_is_jp_only = self.preview_mark_jp_only_var.get()
        try:
            upsert_student(student_id, meta)
            forms = tuple(dict(form) for form in (self.preview_payload.get("multi_form_meta") or ()))
            if forms:
                all_forms = get_multi_form_students()
                all_forms[student_id] = forms
                _write_multi_form_students(all_forms)
            set_jp_only(student_id, next_is_jp_only)
        except Exception as exc:
            messagebox.showerror("Import Failed", str(exc))
            return
        self.preview_summary_var.set(f"Saved {student_id} from SchaleDB.")
        self._refresh_all_views(preserve_student_id=student_id)
        if was_jp_only and not next_is_jp_only:
            warn_missing_portrait_template(student_id, meta)
        messagebox.showinfo("Imported", f"{student_id} saved successfully.")

    def _set_selected_server_state(self, jp_only: bool) -> None:
        student_id = self._selected_metadata_student_id() or self.vars["student_id"].get().strip()
        if not student_id:
            messagebox.showinfo("Server State", "Select a student from the table or editor first.")
            return
        if student_id not in self.students:
            messagebox.showinfo("Server State", f"Student does not exist: {student_id}")
            return
        was_jp_only = student_id in get_jp_only_ids()
        try:
            set_jp_only(student_id, jp_only)
        except Exception as exc:
            messagebox.showerror("Server State Failed", str(exc))
            return
        self.preview_mark_jp_only_var.set(jp_only)
        self._refresh_all_views(preserve_student_id=student_id)
        if was_jp_only and not jp_only:
            warn_missing_portrait_template(student_id, self.students.get(student_id, {}))
        label = "JP-only" if jp_only else "KR"
        self.status_var.set(f"Server state updated: {student_id} -> {label}")

    def run(self) -> int:
        self.root.mainloop()
        return 0


def command_gui(_args: argparse.Namespace | None = None) -> int:
    return StudentMetaToolApp().run()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Add, edit, or inspect student metadata.")
    subparsers = parser.add_subparsers(dest="command")
    gui_parser = subparsers.add_parser("gui", help="Open the metadata editor UI.")
    gui_parser.set_defaults(func=command_gui)
    get_parser = subparsers.add_parser("get", help="Show metadata for one student.")
    get_parser.add_argument("student_id")
    get_parser.set_defaults(func=command_get)
    upsert_parser = subparsers.add_parser("upsert", help="Create or update student metadata.")
    upsert_parser.add_argument("student_id")
    for spec in FIELD_SPECS:
        name = str(spec["name"])
        if name != "student_id":
            upsert_parser.add_argument(f"--{name.replace('_', '-')}")
    upsert_parser.set_defaults(func=command_upsert)
    delete_parser = subparsers.add_parser("delete", help="Delete student metadata.")
    delete_parser.add_argument("student_id")
    delete_parser.set_defaults(func=command_delete)
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv:
        return command_gui()
    parser = build_parser()
    args = parser.parse_args(argv)
    return command_gui() if not hasattr(args, "func") else args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
