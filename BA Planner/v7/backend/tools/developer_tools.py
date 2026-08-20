"""Versioned, short-lived backend for the standalone v7 developer tools."""

from __future__ import annotations

import ast
import hashlib
import importlib
import json
import os
import pprint
import re
import sys
import tempfile
from urllib.request import Request, urlopen
from datetime import datetime
from pathlib import Path
from typing import Any

BACKEND_DIR = Path(__file__).resolve().parents[1]
V7_DIR = BACKEND_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from core.student_meta_types import StudentFormMeta

PROTOCOL_VERSION = 1
METADATA_PATH = BACKEND_DIR / "core" / "student_meta_data.py"
GIFT_METADATA_PATH = BACKEND_DIR / "core" / "gift_meta_data.py"
SCHALE_MERGE_PATHS_PATH = BACKEND_DIR / "core" / "schale_merge_paths.py"
EXTRACTION_METADATA_DIR = V7_DIR / "debug" / "student_template_extractor"
SCHALE_STUDENTS_URL = "https://schaledb.com/data/en/students.min.json"
SCHALE_ITEMS_URL = "https://schaledb.com/data/en/items.min.json"
UNIVERSAL_GIFT_TAGS = frozenset({"BC", "Bc", "ew"})

# This process is consumed by Dart as a UTF-8 JSON transport. Windows otherwise
# inherits a legacy console code page even when stdout is redirected to a pipe.
for _stream in (sys.stdin, sys.stdout, sys.stderr):
    reconfigure = getattr(_stream, "reconfigure", None)
    if callable(reconfigure):
        reconfigure(encoding="utf-8")

FIELD_SPECS: tuple[tuple[str, str, str], ...] = (
    ("student_id", "Student ID", "text"),
    ("display_name", "Display Name", "text"),
    ("template_name", "Template File", "text"),
    ("group", "Group", "text"),
    ("variant", "Variant", "text"),
    ("schaledb_id", "SchaleDB ID", "integer"),
    ("favor_item_tags", "Gift Preference Tags", "list"),
    ("favor_item_unique_tags", "Unique Gift Tags", "list"),
    ("search_tags", "Search Tags", "list"),
    ("kr_search_tags", "KR Search Tags", "list"),
    ("school", "School", "text"),
    ("rarity", "Rarity", "text"),
    ("recruit_type", "Recruit Type", "text"),
    ("attack_type", "Attack Type", "text"),
    ("attack_type_trait", "Attack Type Trait", "text"),
    ("defense_type", "Defense Type", "text"),
    ("growth_material_main", "Main Growth Material", "text"),
    ("growth_material_sub", "Sub Growth Material", "text"),
    ("raw_skill_ex_material", "Raw Skill EX Material", "json"),
    ("raw_skill_ex_material_amount", "Raw Skill EX Amount", "json"),
    ("raw_skill_material", "Raw Skill Material", "json"),
    ("raw_skill_material_amount", "Raw Skill Amount", "json"),
    ("mapped_skill_ex_material_rows", "Mapped Skill EX Rows", "json"),
    ("mapped_skill_material_rows", "Mapped Skill Rows", "json"),
    ("equipment_slot_1", "Equipment 1", "text"),
    ("equipment_slot_2", "Equipment 2", "text"),
    ("equipment_slot_3", "Equipment 3", "text"),
    ("combat_class", "Class", "text"),
    ("cover_type", "Cover", "text"),
    ("range_type", "Range", "text"),
    ("role", "Role", "text"),
    ("weapon_type", "Weapon", "text"),
    ("position", "Position", "text"),
    ("terrain_outdoor", "Outdoor", "text"),
    ("terrain_urban", "Urban", "text"),
    ("terrain_indoor", "Indoor", "text"),
    ("weapon3_terrain_boost", "Weapon 3* Terrain Boost", "text"),
    ("has_favorite_item", "Favorite Item (Legacy)", "text"),
    ("has_favorite_item_jp", "Favorite Item (JP)", "text"),
    ("has_favorite_item_kr", "Favorite Item (KR)", "text"),
    ("farmable", "Farmable", "text"),
    ("passive_stat", "Passive Stat", "list"),
    ("weapon_passive_stat", "Weapon Passive Stat", "list"),
    ("extra_passive_stat", "Extra Passive Stat", "list"),
    ("skill_buff", "Buff Skill", "list"),
    ("skill_debuff", "Debuff Skill", "list"),
    ("skill_cc", "Crowd Control", "list"),
    ("skill_special", "Special Effect", "list"),
    ("skill_heal_targets", "Heal Targets", "list"),
    ("skill_dispel_targets", "Dispel Targets", "list"),
    ("skill_reposition_targets", "Move Skill", "list"),
    ("skill_summon_types", "Summon Skill", "list"),
    ("skill_ignore_cover", "EX Ignore Cover", "text"),
    ("skill_is_area_damage", "EX Area Damage", "text"),
    ("skill_buff_specials", "Special Student Buff", "list"),
    ("skill_knockback", "Knockback / Pull", "text"),
)
FIELD_TYPES = {name: kind for name, _label, kind in FIELD_SPECS}
EDITABLE_FIELDS = frozenset(FIELD_TYPES) - {"student_id"}
REQUIRED_FIELDS = frozenset({"display_name", "template_name", "group"})
MULTI_FORM_FIELDS = frozenset(StudentFormMeta.__annotations__)


def _atomic_text_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    except BaseException:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _replace_assignment(source: str, name: str, rendered: str) -> str:
    tree = ast.parse(source)
    target: ast.Assign | ast.AnnAssign | None = None
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(item, ast.Name) and item.id == name for item in node.targets):
            target = node
            break
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and node.target.id == name:
            target = node
            break
    if target is None or target.end_lineno is None:
        raise ValueError(f"assignment not found: {name}")
    lines = source.splitlines(keepends=True)
    replacement = rendered + ("\n" if lines[target.end_lineno - 1].endswith("\n") else "")
    return "".join(lines[: target.lineno - 1]) + replacement + "".join(lines[target.end_lineno :])


def _metadata_module():
    from core import student_meta_data
    return importlib.reload(student_meta_data)


def _merge_paths_module():
    from core import schale_merge_paths
    return importlib.reload(schale_merge_paths)


def _get_schale_merge_paths() -> dict[str, tuple[str, ...]]:
    return {
        str(student_id): tuple(str(path) for path in paths)
        for student_id, paths in _merge_paths_module().SCHALE_MERGE_PATHS.items()
    }


def _write_schale_merge_paths(merge_paths: dict[str, tuple[str, ...]]) -> None:
    rendered = "SCHALE_MERGE_PATHS: dict[str, tuple[str, ...]] = " + pprint.pformat(
        merge_paths,
        width=100,
        sort_dicts=False,
    )
    source = SCHALE_MERGE_PATHS_PATH.read_text(encoding="utf-8")
    _atomic_text_write(
        SCHALE_MERGE_PATHS_PATH,
        _replace_assignment(source, "SCHALE_MERGE_PATHS", rendered),
    )
    importlib.invalidate_caches()


def _write_metadata_assignment(name: str, rendered: str) -> None:
    source = METADATA_PATH.read_text(encoding="utf-8")
    _atomic_text_write(METADATA_PATH, _replace_assignment(source, name, rendered))
    importlib.invalidate_caches()


def _json_value(value: Any) -> Any:
    if isinstance(value, tuple):
        return [_json_value(item) for item in value]
    if isinstance(value, frozenset):
        return sorted(_json_value(item) for item in value)
    if isinstance(value, dict):
        return {str(key): _json_value(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_value(item) for item in value]
    return value


def metadata_list(params: dict[str, Any]) -> dict[str, Any]:
    module = _metadata_module()
    query = str(params.get("query") or "").strip().casefold()
    server = str(params.get("server") or "all").lower()
    jp_only = set(module.JP_ONLY_STUDENT_IDS)
    rows = []
    for student_id, raw in module.STUDENTS.items():
        meta = dict(raw)
        is_jp = student_id in jp_only
        if server == "kr" and is_jp or server == "jp" and not is_jp:
            continue
        search = " ".join([student_id, *[str(value) for value in meta.values()]]).casefold()
        if query and query not in search:
            continue
        rows.append({
            "student_id": student_id,
            "display_name": str(meta.get("display_name") or ""),
            "group": str(meta.get("group") or ""),
            "template_name": str(meta.get("template_name") or ""),
            "jp_only": is_jp,
        })
    rows.sort(key=lambda row: (row["display_name"].casefold(), row["student_id"].casefold()))
    return {
        "fields": [{"name": name, "label": label, "type": kind} for name, label, kind in FIELD_SPECS],
        "students": rows,
        "total": len(module.STUDENTS),
    }


def metadata_get(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    module = _metadata_module()
    if student_id not in module.STUDENTS:
        raise KeyError(f"student not found: {student_id}")
    return {
        "student_id": student_id,
        "jp_only": student_id in module.JP_ONLY_STUDENT_IDS,
        "metadata": _json_value(dict(module.STUDENTS[student_id])),
    }


def metadata_save(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    if not re.fullmatch(r"[a-z0-9_]+", student_id):
        raise ValueError("student_id must contain only lowercase letters, digits, and underscores")
    raw_updates = params.get("metadata")
    if not isinstance(raw_updates, dict):
        raise ValueError("metadata must be an object")
    unknown = set(raw_updates) - EDITABLE_FIELDS
    if unknown:
        raise ValueError(f"unknown metadata fields: {', '.join(sorted(unknown))}")
    module = _metadata_module()
    students = {key: dict(value) for key, value in module.STUDENTS.items()}
    candidate = {key: value for key, value in raw_updates.items() if value not in (None, "", [])}
    missing = REQUIRED_FIELDS - set(candidate)
    if missing:
        raise ValueError(f"required fields missing: {', '.join(sorted(missing))}")
    candidate.setdefault("variant", None)
    students[student_id] = candidate
    jp_only_ids = set(module.JP_ONLY_STUDENT_IDS)
    if bool(params.get("jp_only")):
        jp_only_ids.add(student_id)
    else:
        jp_only_ids.discard(student_id)
    _write_students_and_jp_only(students, jp_only_ids)
    return metadata_get({"student_id": student_id})


def _set_jp_only(student_id: str, enabled: bool) -> None:
    ids = set(_metadata_module().JP_ONLY_STUDENT_IDS)
    ids.add(student_id) if enabled else ids.discard(student_id)
    rendered = "JP_ONLY_STUDENT_IDS: frozenset[str] = frozenset(" + pprint.pformat(tuple(sorted(ids)), width=100) + ")"
    _write_metadata_assignment("JP_ONLY_STUDENT_IDS", rendered)


def _write_students_and_jp_only(students: dict[str, dict], jp_only_ids: set[str]) -> None:
    source = METADATA_PATH.read_text(encoding="utf-8")
    rendered_students = "STUDENTS: dict[str, StudentMeta] = " + pprint.pformat(
        students, width=100, sort_dicts=False
    )
    rendered_jp_only = "JP_ONLY_STUDENT_IDS: frozenset[str] = frozenset(" + pprint.pformat(
        tuple(sorted(jp_only_ids)), width=100
    ) + ")"
    source = _replace_assignment(source, "STUDENTS", rendered_students)
    source = _replace_assignment(source, "JP_ONLY_STUDENT_IDS", rendered_jp_only)
    _atomic_text_write(METADATA_PATH, source)
    importlib.invalidate_caches()


def _write_multi_forms(forms: dict[str, tuple[dict[str, Any], ...]]) -> None:
    rendered = "MULTI_FORM_STUDENTS: dict[str, tuple[StudentFormMeta, ...]] = " + pprint.pformat(
        forms,
        width=100,
        sort_dicts=False,
    )
    _write_metadata_assignment("MULTI_FORM_STUDENTS", rendered)


def metadata_forms_get(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    if not student_id:
        raise ValueError("student_id is required")
    module = _metadata_module()
    forms = tuple(dict(form) for form in getattr(module, "MULTI_FORM_STUDENTS", {}).get(student_id, ()))
    return {
        "student_id": student_id,
        "forms": _json_value(forms),
        "form_count": len(forms),
    }


def metadata_forms_save(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    if not student_id:
        raise ValueError("student_id is required")
    raw_forms = params.get("forms")
    if not isinstance(raw_forms, list):
        raise ValueError("forms must be a JSON array")

    module = _metadata_module()
    if student_id not in module.STUDENTS:
        raise KeyError(f"student not found: {student_id}")

    normalized: list[dict[str, Any]] = []
    for index, raw in enumerate(raw_forms, start=1):
        if not isinstance(raw, dict):
            raise ValueError(f"form {index} must be an object")
        unknown = set(raw) - MULTI_FORM_FIELDS
        if unknown:
            raise ValueError(f"form {index} has unknown fields: {', '.join(sorted(unknown))}")
        form = {str(key): value for key, value in raw.items() if value not in (None, "", [])}
        form["label"] = str(form.get("label") or index)
        template_name = str(form.get("template_name") or "").strip()
        if not template_name:
            raise ValueError(f"form {index} requires template_name")
        form["template_name"] = template_name
        normalized.append(form)

    all_forms = {
        key: tuple(dict(form) for form in forms)
        for key, forms in getattr(module, "MULTI_FORM_STUDENTS", {}).items()
    }
    if normalized:
        all_forms[student_id] = tuple(normalized)
    else:
        all_forms.pop(student_id, None)
    _write_multi_forms(all_forms)
    return {
        "student_id": student_id,
        "forms": _json_value(tuple(normalized)),
        "form_count": len(normalized),
    }


def _metadata_asset_status(student_id: str, meta: dict[str, Any], forms: tuple[dict[str, Any], ...]) -> dict[str, Any]:
    template_name = str(meta.get("template_name") or f"{student_id}.png")
    portrait_path = V7_DIR / "frontend" / "assets" / "student_portraits" / template_name
    eleph_name = f"Item_Icon_SecretStone_{student_id}.png"
    eleph_path = V7_DIR / "frontend" / "assets" / "student_elephs" / eleph_name
    match_names = [str(form.get("template_name") or "") for form in forms] or [template_name]
    match_dir = BACKEND_DIR / "assets" / "recognition" / "v1" / "templates" / "students"
    match_found = sum(bool(name) and (match_dir / name).is_file() for name in match_names)
    return {
        "portrait": portrait_path.is_file(),
        "portrait_asset": f"assets/student_portraits/{template_name}" if portrait_path.is_file() else None,
        "eleph": eleph_path.is_file(),
        "eleph_asset": f"assets/student_elephs/{eleph_name}" if eleph_path.is_file() else None,
        "match_found": match_found,
        "match_total": len(match_names),
    }


def _debug_display(value: Any) -> str:
    if value in (None, "", [], (), {}):
        return "—"
    if isinstance(value, (list, tuple, set, frozenset)):
        return ", ".join(str(item) for item in value) or "—"
    if isinstance(value, dict):
        return json.dumps(_json_value(value), ensure_ascii=False, separators=(",", ":"))
    return str(value)


def _resolved_debug_value(meta: dict[str, Any], field_name: str) -> Any:
    value = meta.get(field_name)
    if value not in (None, ""):
        return value
    if field_name in {"has_favorite_item_jp", "has_favorite_item_kr"}:
        return meta.get("has_favorite_item")
    return value


def metadata_debug_list(params: dict[str, Any]) -> dict[str, Any]:
    module = _metadata_module()
    query = str(params.get("query") or "").strip().casefold()
    server = str(params.get("server") or "all").strip().lower()
    if server not in {"all", "kr", "jp"}:
        raise ValueError("server must be one of: all, kr, jp")
    jp_only = set(module.JP_ONLY_STUDENT_IDS)
    all_forms = getattr(module, "MULTI_FORM_STUDENTS", {})
    rows: list[dict[str, Any]] = []
    counts = {"all": len(module.STUDENTS), "kr": 0, "jp": 0}
    for student_id, raw in module.STUDENTS.items():
        meta = dict(raw)
        is_jp = student_id in jp_only
        counts["jp" if is_jp else "kr"] += 1
        if server == "jp" and not is_jp or server == "kr" and is_jp:
            continue
        forms = tuple(dict(form) for form in all_forms.get(student_id, ()))
        assets = _metadata_asset_status(student_id, meta, forms)
        row = {
            "student_id": student_id,
            "display_name": str(meta.get("display_name") or ""),
            "server": "JP" if is_jp else "KR",
            "group": str(meta.get("group") or ""),
            "variant": _debug_display(meta.get("variant")),
            "school": _debug_display(meta.get("school")),
            "rarity": _debug_display(meta.get("rarity")),
            "attack_type": _debug_display(meta.get("attack_type")),
            "defense_type": _debug_display(meta.get("defense_type")),
            "role": _debug_display(meta.get("role")),
            "position": _debug_display(meta.get("position")),
            "weapon_type": _debug_display(meta.get("weapon_type")),
            "favorite_item_jp": _debug_display(_resolved_debug_value(meta, "has_favorite_item_jp")),
            "favorite_item_kr": _debug_display(_resolved_debug_value(meta, "has_favorite_item_kr")),
            "multi_form_count": len(forms),
            **assets,
        }
        haystack = " ".join([student_id, *[str(value) for value in meta.values()], *[str(value) for value in row.values()]]).casefold()
        if query and query not in haystack:
            continue
        rows.append(row)
    rows.sort(key=lambda row: (row["display_name"].casefold(), row["student_id"].casefold()))
    return {"rows": rows, "counts": counts, "visible_count": len(rows)}


def metadata_debug_get(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    module = _metadata_module()
    if student_id not in module.STUDENTS:
        raise KeyError(f"student not found: {student_id}")
    meta = dict(module.STUDENTS[student_id])
    forms = tuple(dict(form) for form in getattr(module, "MULTI_FORM_STUDENTS", {}).get(student_id, ()))
    labels = {name: label for name, label, _kind in FIELD_SPECS}
    fields = [
        {"name": "student_id", "label": "Student ID", "value": student_id},
        {"name": "server", "label": "Server", "value": "JP" if student_id in set(module.JP_ONLY_STUDENT_IDS) else "KR"},
        *[
            {
                "name": name,
                "label": labels[name],
                "value": _debug_display(_resolved_debug_value(meta, name)),
            }
            for name, _label, _kind in FIELD_SPECS
            if name != "student_id"
        ],
    ]
    return {
        "student_id": student_id,
        "display_name": str(meta.get("display_name") or ""),
        "template_name": str(meta.get("template_name") or ""),
        "server": "JP" if student_id in set(module.JP_ONLY_STUDENT_IDS) else "KR",
        "assets": _metadata_asset_status(student_id, meta, forms),
        "forms": _json_value(forms),
        "form_count": len(forms),
        "fields": fields,
    }


def metadata_server_set(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    server = str(params.get("server") or "").strip().lower()
    if server not in {"kr", "jp"}:
        raise ValueError("server must be one of: kr, jp")
    module = _metadata_module()
    if student_id not in module.STUDENTS:
        raise KeyError(f"student not found: {student_id}")
    ids = set(module.JP_ONLY_STUDENT_IDS)
    previous = "jp" if student_id in ids else "kr"
    if server == "jp":
        ids.add(student_id)
    else:
        ids.discard(student_id)
    changed = previous != server
    if changed:
        rendered = "JP_ONLY_STUDENT_IDS: frozenset[str] = frozenset(" + pprint.pformat(
            tuple(sorted(ids)), width=100
        ) + ")"
        _write_metadata_assignment("JP_ONLY_STUDENT_IDS", rendered)

    meta = dict(module.STUDENTS[student_id])
    forms = tuple(dict(form) for form in getattr(module, "MULTI_FORM_STUDENTS", {}).get(student_id, ()))
    assets = _metadata_asset_status(student_id, meta, forms)
    warnings: list[str] = []
    if server == "kr" and not assets["portrait"]:
        warnings.append("KR 전환 후 사용할 학생 초상이 없습니다.")
    if server == "kr" and assets["match_found"] < assets["match_total"]:
        warnings.append("KR 전환 후 사용할 인식 템플릿이 일부 없습니다.")
    return {
        "student_id": student_id,
        "previous_server": previous.upper(),
        "server": server.upper(),
        "changed": changed,
        "warnings": warnings,
    }


def metadata_merge_paths_list(_params: dict[str, Any]) -> dict[str, Any]:
    module = _metadata_module()
    rows = [
        {
            "student_id": student_id,
            "display_name": str(module.STUDENTS.get(student_id, {}).get("display_name") or student_id),
            "template_name": str(module.STUDENTS.get(student_id, {}).get("template_name") or ""),
            "paths": list(paths),
            "path_count": len(paths),
        }
        for student_id, paths in sorted(_get_schale_merge_paths().items())
    ]
    return {"rows": rows, "rule_count": len(rows)}


def metadata_merge_paths_save(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    raw_paths = params.get("paths")
    if not student_id:
        raise ValueError("student_id is required")
    if not isinstance(raw_paths, list):
        raise ValueError("paths must be an array")
    module = _metadata_module()
    if student_id not in module.STUDENTS:
        raise KeyError(f"student not found: {student_id}")
    paths = tuple(dict.fromkeys(_parse_schale_student_source(path) for path in raw_paths))
    if len(paths) < 2:
        raise ValueError("at least two distinct SchaleDB slugs are required")

    merge_paths = _get_schale_merge_paths()
    for other_id, other_paths in merge_paths.items():
        if other_id == student_id:
            continue
        used = {_normalized_schale_path(path) for path in other_paths}
        duplicate = next((path for path in paths if _normalized_schale_path(path) in used), None)
        if duplicate is not None:
            raise ValueError(f"SchaleDB slug '{duplicate}' is already used by {other_id}")
    merge_paths[student_id] = paths
    normalized = {key: merge_paths[key] for key in sorted(merge_paths)}
    _write_schale_merge_paths(normalized)
    return {
        "student_id": student_id,
        "paths": list(paths),
        "path_count": len(paths),
    }


def metadata_merge_paths_delete(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    if not student_id:
        raise ValueError("student_id is required")
    merge_paths = _get_schale_merge_paths()
    removed = merge_paths.pop(student_id, None)
    if removed is not None:
        _write_schale_merge_paths({key: merge_paths[key] for key in sorted(merge_paths)})
    return {
        "student_id": student_id,
        "deleted": removed is not None,
    }


def _read_json_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise ValueError(f"{label} file does not exist: {path}") from error
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"{label} file cannot be read: {path}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def _selected_repository_inventory() -> tuple[dict[str, Any], str, str | None]:
    from core.runtime_paths import resolve_repository_root

    root = resolve_repository_root()
    catalog_path = root / "catalog.json"
    if not catalog_path.is_file():
        return {"version": 1, "entries": []}, "선택된 v7 계정 없음", None
    catalog = _read_json_object(catalog_path, "repository catalog")
    selected = catalog.get("selected_profile_id")
    if not isinstance(selected, str) or not selected:
        return {"version": 1, "entries": []}, "선택된 v7 계정 없음", str(catalog_path)
    profile_path = root / "profiles" / f"{selected}.json"
    profile = _read_json_object(profile_path, "repository profile")
    inventory = profile.get("inventory")
    if not isinstance(inventory, dict):
        raise ValueError("selected repository profile has no inventory snapshot")
    summaries = catalog.get("profiles") if isinstance(catalog.get("profiles"), list) else []
    summary = next(
        (row for row in summaries if isinstance(row, dict) and row.get("profile_id") == selected),
        {},
    )
    name = str(summary.get("display_name") or selected)
    return inventory, f"v7 선택 계정 · {name}", str(profile_path)


def _inventory_entries(raw: dict[str, Any]) -> list[dict[str, Any]]:
    if isinstance(raw.get("inventory"), dict):
        raw = raw["inventory"]
    entries = raw.get("entries")
    if isinstance(entries, list):
        return [dict(entry) for entry in entries if isinstance(entry, dict)]
    if "version" in raw:
        raise ValueError("inventory snapshot entries must be an array")
    legacy: list[dict[str, Any]] = []
    for key, value in raw.items():
        if isinstance(value, dict):
            legacy.append(
                {
                    "key": str(value.get("item_id") or value.get("key") or key),
                    "item_id": value.get("item_id"),
                    "name": value.get("name") or key,
                    "quantity": value.get("quantity"),
                    "index": value.get("index"),
                }
            )
        else:
            legacy.append({"key": str(key), "name": str(key), "quantity": value})
    return legacy


def _inventory_quantity(value: Any) -> int | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        raise ValueError("inventory quantity must be a non-negative integer or null")
    try:
        quantity = int(value)
    except (TypeError, ValueError) as error:
        raise ValueError("inventory quantity must be a non-negative integer or null") from error
    if quantity < 0 or str(quantity) != str(value).strip():
        raise ValueError("inventory quantity must be a canonical non-negative integer or null")
    return quantity


def _item_plan_adjustments(path_text: str) -> tuple[dict[str, int], str | None]:
    if not path_text.strip():
        return {}, None
    path = Path(path_text).expanduser().resolve()
    raw = _read_json_object(path, "plan adjustment")
    adjustments: dict[str, int] = {}
    for key, value in raw.items():
        delta = value.get("delta") if isinstance(value, dict) else value
        if isinstance(delta, bool):
            raise ValueError(f"plan delta for {key} must be an integer")
        try:
            adjustments[str(key)] = int(delta)
        except (TypeError, ValueError) as error:
            raise ValueError(f"plan delta for {key} must be an integer") from error
    return adjustments, str(path)


def _inventory_icon_asset(item_id: str | None, category: str) -> str | None:
    if not item_id:
        return None
    folder = {
        "equipment": "equipment",
        "oopart": "ooparts",
        "workbook": "ooparts",
        "tactical_bd": "tactical_bd",
        "tech_notes": "skill_book",
        "student_eleph": "../../student_elephs",
    }.get(category)
    if folder is None:
        return None
    asset = f"assets/item_icons/{folder}/{item_id}.png"
    normalized = asset.replace("item_icons/../../", "")
    return normalized if (V7_DIR / "frontend" / normalized).is_file() else None


def metadata_items_analyze(params: dict[str, Any]) -> dict[str, Any]:
    from core.inventory_catalog import BY_KEY, CATALOG, resolve_planning_resource

    source_text = str(params.get("inventory_path") or "").strip()
    if source_text:
        source_path = Path(source_text).expanduser().resolve()
        raw_inventory = _read_json_object(source_path, "inventory")
        source_label = source_path.name
        resolved_source_path: str | None = str(source_path)
    else:
        raw_inventory, source_label, resolved_source_path = _selected_repository_inventory()
    raw_entries = _inventory_entries(raw_inventory)
    raw_adjustments, adjustment_path = _item_plan_adjustments(
        str(params.get("plan_path") or "")
    )

    entries: dict[str, dict[str, Any]] = {}
    for entry in raw_entries:
        raw_identity = str(entry.get("item_id") or entry.get("key") or entry.get("name") or "").strip()
        if not raw_identity:
            raise ValueError("inventory entry identity must be non-empty")
        catalog_row = resolve_planning_resource(raw_identity)
        identity = catalog_row.resource_key if catalog_row is not None else raw_identity
        if identity in entries:
            raise ValueError(f"duplicate inventory identity: {identity}")
        entries[identity] = {
            "raw": entry,
            "quantity": _inventory_quantity(entry.get("quantity")),
        }

    adjustments: dict[str, int] = {}
    for raw_identity, delta in raw_adjustments.items():
        catalog_row = resolve_planning_resource(raw_identity)
        identity = catalog_row.resource_key if catalog_row is not None else raw_identity
        adjustments[identity] = adjustments.get(identity, 0) + delta

    identities = sorted(set(entries) | set(adjustments), key=str.casefold)
    rows: list[dict[str, Any]] = []
    for identity in identities:
        catalog_row = BY_KEY.get(identity)
        stored = entries.get(identity)
        raw = stored["raw"] if stored is not None else {}
        quantity = stored["quantity"] if stored is not None else None
        delta = adjustments.get(identity, 0)
        adjusted = None if quantity is None else quantity + delta
        status = (
            "absent"
            if stored is None
            else "unknown"
            if quantity is None
            else "negative"
            if adjusted < 0
            else "zero"
            if adjusted == 0
            else "positive"
        )
        category = catalog_row.category if catalog_row is not None else "missing_catalog"
        item_id = catalog_row.item_id if catalog_row is not None else raw.get("item_id")
        rows.append(
            {
                "resource_key": identity,
                "item_id": item_id,
                "display_name": (
                    catalog_row.display_name
                    if catalog_row is not None
                    else str(raw.get("name") or identity)
                ),
                "category": category,
                "current_qty": quantity,
                "plan_delta": delta,
                "adjusted_qty": adjusted,
                "status": status,
                "index": catalog_row.order_index if catalog_row is not None else raw.get("index"),
                "icon_asset": _inventory_icon_asset(item_id, category),
            }
        )

    catalog_keys = {row.resource_key for row in CATALOG}
    snapshot_keys = set(entries)
    known_keys = {key for key, value in entries.items() if value["quantity"] is not None}
    status_counts = {
        status: sum(row["status"] == status for row in rows)
        for status in ("negative", "zero", "positive", "unknown", "absent")
    }
    categories: list[dict[str, Any]] = []
    category_names = sorted({row.category for row in CATALOG})
    for category in category_names:
        keys = {row.resource_key for row in CATALOG if row.category == category}
        present = keys & snapshot_keys
        known = keys & known_keys
        categories.append(
            {
                "category": category,
                "catalog_count": len(keys),
                "snapshot_count": len(present),
                "known_count": len(known),
                "unknown_count": len(present - known),
                "absent_count": len(keys - snapshot_keys),
                "coverage_percent": len(present) / len(keys) * 100.0 if keys else 0.0,
            }
        )
    missing_catalog = sorted(snapshot_keys - catalog_keys, key=str.casefold)
    if missing_catalog:
        categories.append(
            {
                "category": "missing_catalog",
                "catalog_count": 0,
                "snapshot_count": len(missing_catalog),
                "known_count": len(set(missing_catalog) & known_keys),
                "unknown_count": len(set(missing_catalog) - known_keys),
                "absent_count": 0,
                "coverage_percent": 0.0,
            }
        )
    return {
        "source_label": source_label,
        "inventory_path": resolved_source_path,
        "plan_path": adjustment_path,
        "summary": {
            "catalog_count": len(CATALOG),
            "snapshot_count": len(entries),
            "known_count": len(known_keys),
            "unknown_count": len(snapshot_keys - known_keys),
            "absent_count": len(catalog_keys - snapshot_keys),
            "missing_catalog_count": len(missing_catalog),
            **{f"{key}_count": value for key, value in status_counts.items()},
        },
        "buckets": [
            {"status": key, "count": value, "percent": value / len(rows) * 100.0 if rows else 0.0}
            for key, value in status_counts.items()
        ],
        "categories": categories,
        "rows": rows,
    }


def _fetch_schaledb_json(url: str) -> dict[str, Any]:
    request = Request(
        url,
        headers={"User-Agent": "BA-Planner-v7/1", "Accept": "application/json"},
    )
    with urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if not isinstance(payload, dict):
        raise ValueError(f"SchaleDB returned a non-object payload: {url}")
    return payload


_PATH_EXCEPTIONS = {
    "hoshino_battle": "hoshino_battle_tank",
    "shiroko_riding": "shiroko_cycling",
    "shoukouhou_misaki": "shokuhou_misaki",
    "shun_kid": "shun_small",
}
_PATH_REPLACEMENTS = (
    ("_bunny_girl", "_bunnygirl"),
    ("_school_uniform", "_uniform"),
    ("_new_year", "_newyear"),
    ("_hot_springs", "_onsen"),
    ("_sportswear", "_track"),
    ("_camping", "_camp"),
    ("_part_timer", "_parttime"),
)


def _normalized_schale_path(value: object) -> str:
    return re.sub(r"[^a-z0-9]+", "", str(value or "").casefold())


def _schale_path_for_local_id(student_id: str) -> str:
    merge_paths = _get_schale_merge_paths().get(student_id)
    if merge_paths:
        return merge_paths[0]
    path = _PATH_EXCEPTIONS.get(student_id, student_id)
    for old, new in _PATH_REPLACEMENTS:
        path = path.replace(old, new)
    return path


def _local_id_for_schale_path(path_name: str, student_ids: Any) -> str | None:
    normalized = _normalized_schale_path(path_name)
    for student_id, paths in _get_schale_merge_paths().items():
        if student_id in student_ids and any(_normalized_schale_path(path) == normalized for path in paths):
            return student_id
    return next(
        (
            student_id
            for student_id in student_ids
            if _normalized_schale_path(_schale_path_for_local_id(student_id)) == normalized
        ),
        None,
    )


def _parse_schale_student_source(source: object) -> str:
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


def _minimal_schale_gifts(raw_items: dict[str, Any]) -> list[dict[str, Any]]:
    gifts: list[dict[str, Any]] = []
    gift_asset_dir = V7_DIR / "frontend" / "assets" / "item_icons" / "presents"
    for raw in raw_items.values():
        if not isinstance(raw, dict) or raw.get("Category") != "Favor":
            continue
        icon_name = str(raw.get("Icon") or "")
        icon_asset = f"assets/item_icons/presents/{icon_name}.png"
        gifts.append({
            "id": int(raw["Id"]),
            "category": "Favor",
            "tags": [str(tag) for tag in raw.get("Tags") or []],
            "exp_value": int(raw.get("ExpValue") or 0),
            "name": str(raw.get("Name") or raw["Id"]),
            "icon_asset": icon_asset if (gift_asset_dir / f"{icon_name}.png").is_file() else None,
        })
    gifts.sort(key=lambda row: (row["exp_value"], row["id"]))
    return gifts


def _student_gift_affinities(incoming: dict[str, Any], gifts: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    general_tags = set(incoming["favor_item_tags"])
    unique_tags = set(incoming["favor_item_unique_tags"])
    special_gifts: list[dict[str, Any]] = []
    preferred_gifts: list[dict[str, Any]] = []
    for gift in gifts:
        gift_tags = set(gift["tags"])
        unique_matches = len(gift_tags & unique_tags)
        general_matches = len(gift_tags & general_tags)
        if not unique_matches and not general_matches:
            continue
        accepted_tags = general_tags | unique_tags | UNIVERSAL_GIFT_TAGS
        match_count = min(3, len(gift_tags & accepted_tags))
        result = {
            "id": gift["id"],
            "name": gift["name"],
            "icon_asset": gift["icon_asset"],
            "exp_value": gift["exp_value"],
            "match_count": match_count,
            "multiplier": 1 + match_count,
            "points": gift["exp_value"] * (1 + match_count),
        }
        (special_gifts if unique_matches else preferred_gifts).append(result)
    affinity_sort = lambda gift: (
        -gift["match_count"],
        -gift["points"],
        str(gift["name"]).casefold(),
    )
    special_gifts.sort(key=affinity_sort)
    preferred_gifts.sort(key=affinity_sort)
    return special_gifts, preferred_gifts


def _minimal_schale_snapshot() -> dict[str, Any]:
    module = _metadata_module()
    raw_students = _fetch_schaledb_json(SCHALE_STUDENTS_URL)
    raw_items = _fetch_schaledb_json(SCHALE_ITEMS_URL)
    path_lookup = {
        _normalized_schale_path(raw.get("PathName")): raw
        for raw in raw_students.values()
        if isinstance(raw, dict) and raw.get("PathName")
    }

    students: list[dict[str, Any]] = []
    missing: list[str] = []
    for student_id, current in module.STUDENTS.items():
        raw = path_lookup.get(_normalized_schale_path(_schale_path_for_local_id(student_id)))
        if raw is None:
            missing.append(student_id)
            continue
        incoming = {
            "schaledb_id": int(raw["Id"]),
            "favor_item_tags": [str(tag) for tag in raw.get("FavorItemTags") or []],
            "favor_item_unique_tags": [str(tag) for tag in raw.get("FavorItemUniqueTags") or []],
        }
        changed_fields = [name for name, value in incoming.items() if current.get(name) != value]
        students.append({
            "student_id": student_id,
            "display_name": str(current.get("display_name") or student_id),
            "template_name": str(current.get("template_name") or f"{student_id}.png"),
            "jp_only": student_id in module.JP_ONLY_STUDENT_IDS,
            "current": {name: _json_value(current.get(name)) for name in incoming},
            "incoming": incoming,
            "changed_fields": changed_fields,
        })

    gifts = _minimal_schale_gifts(raw_items)
    students.sort(key=lambda row: (row["display_name"].casefold(), row["student_id"]))
    for student in students:
        special_gifts, preferred_gifts = _student_gift_affinities(student["incoming"], gifts)
        student["special_gifts"] = special_gifts
        student["preferred_gifts"] = preferred_gifts
    return {"students": students, "gifts": gifts, "missing_student_ids": sorted(missing)}


def metadata_schaledb_preview(_params: dict[str, Any]) -> dict[str, Any]:
    snapshot = _minimal_schale_snapshot()
    return {
        **snapshot,
        "student_count": len(snapshot["students"]),
        "changed_student_count": sum(bool(row["changed_fields"]) for row in snapshot["students"]),
        "gift_count": len(snapshot["gifts"]),
        "persisted_fields": [
            "student.Id",
            "student.FavorItemTags",
            "student.FavorItemUniqueTags",
            "gift.Id",
            "gift.Category",
            "gift.Tags",
            "gift.ExpValue",
        ],
    }


def _single_schale_snapshot(params: dict[str, Any]) -> dict[str, Any]:
    module = _metadata_module()
    preferred_id = str(params.get("student_id") or "").strip()
    source = str(params.get("source") or "").strip()
    if not source and preferred_id:
        source = _schale_path_for_local_id(preferred_id)
    slug = _parse_schale_student_source(source)
    raw_students = _fetch_schaledb_json(SCHALE_STUDENTS_URL)
    raw_items = _fetch_schaledb_json(SCHALE_ITEMS_URL)
    path_lookup = {
        _normalized_schale_path(raw.get("PathName")): raw
        for raw in raw_students.values()
        if isinstance(raw, dict) and raw.get("PathName")
    }
    raw = path_lookup.get(_normalized_schale_path(slug))
    if raw is None:
        raw = path_lookup.get(_normalized_schale_path(_schale_path_for_local_id(slug)))
    if raw is None:
        raise KeyError(f"SchaleDB student not found: {slug}")
    resolved_slug = str(raw.get("PathName") or slug).strip().lower()

    matched_local_id = _local_id_for_schale_path(resolved_slug, module.STUDENTS)
    local_id = preferred_id or matched_local_id or re.sub(r"[^a-z0-9]+", "_", resolved_slug).strip("_")
    if not re.fullmatch(r"[a-z0-9_]+", local_id):
        raise ValueError("student_id must contain only lowercase letters, digits, and underscores")
    current = dict(module.STUDENTS.get(local_id, {}))
    incoming = {
        "schaledb_id": int(raw["Id"]),
        "favor_item_tags": [str(tag) for tag in raw.get("FavorItemTags") or []],
        "favor_item_unique_tags": [str(tag) for tag in raw.get("FavorItemUniqueTags") or []],
    }
    gifts = _minimal_schale_gifts(raw_items)
    special_gifts, preferred_gifts = _student_gift_affinities(incoming, gifts)
    return {
        "source_slug": resolved_slug,
        "student_id": local_id,
        "exists": local_id in module.STUDENTS,
        "matched_local_id": matched_local_id,
        "display_name": str(current.get("display_name") or local_id),
        "template_name": str(current.get("template_name") or f"{local_id}.png"),
        "current": {name: _json_value(current.get(name)) for name in incoming},
        "incoming": incoming,
        "changed_fields": [name for name, value in incoming.items() if current.get(name) != value],
        "special_gifts": special_gifts,
        "preferred_gifts": preferred_gifts,
        "gifts": gifts,
    }


def metadata_schaledb_single_preview(params: dict[str, Any]) -> dict[str, Any]:
    snapshot = _single_schale_snapshot(params)
    return {
        **snapshot,
        "gift_count": len(snapshot["gifts"]),
        "persisted_fields": [
            "student.Id",
            "student.FavorItemTags",
            "student.FavorItemUniqueTags",
            "gift.Id",
            "gift.Category",
            "gift.Tags",
            "gift.ExpValue",
        ],
    }


def metadata_schaledb_single_apply(params: dict[str, Any]) -> dict[str, Any]:
    snapshot = _single_schale_snapshot(params)
    if not snapshot["exists"]:
        raise ValueError("new students must be loaded into the editor and completed before saving")
    module = _metadata_module()
    students = {key: dict(value) for key, value in module.STUDENTS.items()}
    students[snapshot["student_id"]].update(snapshot["incoming"])
    _write_students_and_jp_only(students, set(module.JP_ONLY_STUDENT_IDS))
    _write_gift_metadata(snapshot["gifts"])
    return {
        "student_id": snapshot["student_id"],
        "updated_fields": snapshot["changed_fields"],
        "gift_count": len(snapshot["gifts"]),
    }


def _write_gift_metadata(gifts: list[dict[str, Any]]) -> None:
    gift_rows = {
        int(gift["id"]): {
            "id": int(gift["id"]),
            "category": str(gift["category"]),
            "tags": [str(tag) for tag in gift["tags"]],
            "exp_value": int(gift["exp_value"]),
        }
        for gift in gifts
    }
    source = GIFT_METADATA_PATH.read_text(encoding="utf-8")
    rendered = "GIFT_ITEMS: dict[int, GiftMeta] = " + pprint.pformat(
        gift_rows, width=100, sort_dicts=False
    )
    _atomic_text_write(GIFT_METADATA_PATH, _replace_assignment(source, "GIFT_ITEMS", rendered))


def metadata_schaledb_apply(_params: dict[str, Any]) -> dict[str, Any]:
    snapshot = _minimal_schale_snapshot()
    module = _metadata_module()
    students = {key: dict(value) for key, value in module.STUDENTS.items()}
    updated = 0
    for row in snapshot["students"]:
        if not row["changed_fields"]:
            continue
        students[row["student_id"]].update(row["incoming"])
        updated += 1
    _write_students_and_jp_only(students, set(module.JP_ONLY_STUDENT_IDS))
    _write_gift_metadata(snapshot["gifts"])
    return {
        "updated_students": updated,
        "gift_count": len(snapshot["gifts"]),
        "missing_student_ids": snapshot["missing_student_ids"],
    }


def metadata_delete(params: dict[str, Any]) -> dict[str, Any]:
    student_id = str(params.get("student_id") or "").strip()
    module = _metadata_module()
    students = {key: dict(value) for key, value in module.STUDENTS.items()}
    if student_id not in students:
        raise KeyError(f"student not found: {student_id}")
    del students[student_id]
    jp_only_ids = set(module.JP_ONLY_STUDENT_IDS)
    jp_only_ids.discard(student_id)
    _write_students_and_jp_only(students, jp_only_ids)
    return {"deleted": student_id}


def _student_region() -> tuple[dict[str, float], Path]:
    from core.recognition_assets import RecognitionAssetCatalog

    catalog = RecognitionAssetCatalog()
    region = catalog.region("student").get("student_texture_region")
    if not isinstance(region, dict):
        raise ValueError("student_texture_region is missing")
    return ({key: float(region[key]) for key in ("x1", "y1", "x2", "y2")}, catalog.root)


def _crop_box(size: tuple[int, int], region: dict[str, float]) -> tuple[int, int, int, int]:
    width, height = size
    left = max(0, min(round(width * region["x1"]), width - 1))
    top = max(0, min(round(height * region["y1"]), height - 1))
    right = max(left + 1, min(round(width * region["x2"]), width))
    bottom = max(top + 1, min(round(height * region["y2"]), height))
    return left, top, right, bottom


def template_preview(params: dict[str, Any]) -> dict[str, Any]:
    from PIL import Image, ImageDraw

    image_path = Path(str(params.get("image_path") or "")).expanduser().resolve()
    with Image.open(image_path) as image:
        region, _root = _student_region()
        box = _crop_box(image.size, region)
        preview_dir = Path(tempfile.gettempdir()) / "ba-planner-v7-developer-tools"
        preview_dir.mkdir(parents=True, exist_ok=True)
        preview_path = preview_dir / "student-template-preview.png"
        overlay = image.convert("RGBA")
        ImageDraw.Draw(overlay).rectangle(box, outline=(55, 225, 255, 255), width=max(2, image.width // 600))
        overlay.save(preview_path)
        return {
            "image_path": str(image_path),
            "preview_path": str(preview_path),
            "width": image.width,
            "height": image.height,
            "crop": list(box),
        }


def _update_student_manifest(root: Path, student_id: str, path: Path) -> None:
    manifest_path = root / "manifest.json"
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    relative = path.relative_to(root).as_posix()
    content = path.read_bytes()
    entry = {
        "path": relative,
        "scan_kind": "student",
        "purpose": "student-template",
        "required": False,
        "bytes": len(content),
        "sha256": hashlib.sha256(content).hexdigest(),
        "student_id": student_id,
    }
    assets = [item for item in payload["assets"] if not (
        item.get("scan_kind") == "student" and item.get("purpose") == "student-template"
        and item.get("student_id") == student_id
    )]
    assets.append(entry)
    assets.sort(key=lambda item: str(item.get("path") or ""))
    payload["assets"] = assets
    _atomic_text_write(manifest_path, json.dumps(payload, ensure_ascii=False, indent=2) + "\n")


def template_save(params: dict[str, Any]) -> dict[str, Any]:
    from PIL import Image

    from core.runtime_paths import resolve_recognition_asset_dir

    student_id = str(params.get("student_id") or "").strip()
    if not re.fullmatch(r"[a-z0-9_]+", student_id):
        raise ValueError("student_id must contain only lowercase letters, digits, and underscores")
    image_path = Path(str(params.get("image_path") or "")).expanduser().resolve()
    with Image.open(image_path) as image:
        raw_crop = params.get("crop")
        if isinstance(raw_crop, list) and len(raw_crop) == 4:
            box = tuple(int(value) for value in raw_crop)
        else:
            region, _root = _student_region()
            box = _crop_box(image.size, region)
        left, top, right, bottom = box
        if not (0 <= left < right <= image.width and 0 <= top < bottom <= image.height):
            raise ValueError("crop is outside the source image")
        root = resolve_recognition_asset_dir().resolve()
        destination = root / "templates" / "students" / f"{student_id}.png"
        if destination.exists() and not bool(params.get("overwrite")):
            raise FileExistsError(f"template already exists: {destination}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        image.convert("RGBA").crop(box).save(destination)
        _update_student_manifest(root, student_id, destination)
        EXTRACTION_METADATA_DIR.mkdir(parents=True, exist_ok=True)
        metadata_path = EXTRACTION_METADATA_DIR / f"{student_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        metadata = {
            "version": 1,
            "student_id": student_id,
            "captured_at": datetime.now().isoformat(timespec="seconds"),
            "source_image_path": str(image_path),
            "source_size": {"width": image.width, "height": image.height},
            "crop_box_image": {"left": left, "top": top, "right": right, "bottom": bottom},
            "output_path": str(destination),
            "recognition_manifest_path": str(root / "manifest.json"),
        }
        _atomic_text_write(metadata_path, json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    return {"output_path": str(destination), "metadata_path": str(metadata_path), "crop": list(box)}


def inspector_inspect(params: dict[str, Any]) -> dict[str, Any]:
    from PIL import Image

    from core.recognition_assets import RecognitionAssetCatalog
    from core.scanner_matchers import TemplateMatcher, image_has_visible_content, ratio_crop

    image_path = Path(str(params.get("image_path") or "")).expanduser().resolve()
    threshold = float(params.get("threshold", 0.80))
    margin_threshold = float(params.get("margin", 0.03))
    catalog = RecognitionAssetCatalog()
    matcher = TemplateMatcher(catalog, "inventory", "inventory-template")
    section = catalog.region("inventory").get("item", {})
    slots = section.get("grid_slots")
    if not isinstance(slots, list) or not slots:
        raise ValueError("inventory grid slots are missing")
    with Image.open(image_path) as source:
        image = source.convert("RGB")
        rows = []
        for index, region in enumerate(slots):
            crop = ratio_crop(image, region)
            if not image_has_visible_content(crop):
                rows.append({"slot": index + 1, "empty": True})
                continue
            match = matcher.match(crop, center_trim=0.15)
            rows.append({
                "slot": index + 1,
                "empty": False,
                "item_id": match.identity,
                "score": match.score,
                "margin": match.margin,
                "confident": match.score >= threshold and match.margin >= margin_threshold,
                "region": {key: float(region[key]) for key in ("x1", "y1", "x2", "y2")},
            })
    return {
        "image_path": str(image_path),
        "template_count": len(matcher.templates),
        "threshold": threshold,
        "margin_threshold": margin_threshold,
        "slots": rows,
    }


METHODS = {
    "metadata.list": metadata_list,
    "metadata.get": metadata_get,
    "metadata.save": metadata_save,
    "metadata.delete": metadata_delete,
    "metadata.forms.get": metadata_forms_get,
    "metadata.forms.save": metadata_forms_save,
    "metadata.debug.list": metadata_debug_list,
    "metadata.debug.get": metadata_debug_get,
    "metadata.server.set": metadata_server_set,
    "metadata.merge_paths.list": metadata_merge_paths_list,
    "metadata.merge_paths.save": metadata_merge_paths_save,
    "metadata.merge_paths.delete": metadata_merge_paths_delete,
    "metadata.items.analyze": metadata_items_analyze,
    "metadata.schaledb.preview": metadata_schaledb_preview,
    "metadata.schaledb.apply": metadata_schaledb_apply,
    "metadata.schaledb.single.preview": metadata_schaledb_single_preview,
    "metadata.schaledb.single.apply": metadata_schaledb_single_apply,
    "template.preview": template_preview,
    "template.save": template_save,
    "inspector.inspect": inspector_inspect,
}


def dispatch(request: dict[str, Any]) -> dict[str, Any]:
    if request.get("version") != PROTOCOL_VERSION:
        raise ValueError(f"protocol version must be {PROTOCOL_VERSION}")
    method = str(request.get("method") or "")
    handler = METHODS.get(method)
    if handler is None:
        raise ValueError(f"unknown method: {method}")
    params = request.get("params") or {}
    if not isinstance(params, dict):
        raise ValueError("params must be an object")
    return {"version": PROTOCOL_VERSION, "ok": True, "result": handler(params)}


def main() -> int:
    try:
        request = json.loads(sys.stdin.read())
        if not isinstance(request, dict):
            raise ValueError("request must be an object")
        response = dispatch(request)
    except Exception as exc:
        response = {
            "version": PROTOCOL_VERSION,
            "ok": False,
            "error": {"type": type(exc).__name__, "message": str(exc)},
        }
    sys.stdout.write(json.dumps(response, ensure_ascii=False))
    return 0 if response["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
