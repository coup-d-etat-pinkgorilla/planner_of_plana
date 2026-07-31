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
from datetime import datetime
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

BACKEND_DIR = Path(__file__).resolve().parents[1]
V7_DIR = BACKEND_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from core.recognition_assets import RecognitionAssetCatalog
from core.runtime_paths import resolve_recognition_asset_dir
from core.scanner_matchers import TemplateMatcher, image_has_visible_content, ratio_crop

PROTOCOL_VERSION = 1
METADATA_PATH = BACKEND_DIR / "core" / "student_meta_data.py"
EXTRACTION_METADATA_DIR = V7_DIR / "debug" / "student_template_extractor"

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
