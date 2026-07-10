"""Runtime lookup API for student metadata.

Generated values live in core.student_meta_data so callers can inspect or edit
the lookup API without loading the complete generated dataset.
"""

from __future__ import annotations

from functools import lru_cache
import importlib
import re
from typing import Any

from core import student_meta_data as _student_meta_data
from core.student_meta_types import EDITABLE_FIELDS, StudentFormMeta, StudentMeta

_student_meta_data = importlib.reload(_student_meta_data)
FAVORITE_ITEM_MAX_TIER = _student_meta_data.FAVORITE_ITEM_MAX_TIER
FAVORITE_ITEM_STUDENT_IDS = _student_meta_data.FAVORITE_ITEM_STUDENT_IDS
JP_ONLY_STUDENT_IDS = _student_meta_data.JP_ONLY_STUDENT_IDS
MULTI_FORM_STUDENTS = _student_meta_data.MULTI_FORM_STUDENTS
STUDENTS = _student_meta_data.STUDENTS

_FORM_REF_RE = re.compile(r"^(?P<base>.*?)(?:\s*[#:@]\s*(?P<form>[1-9][0-9]*))?$")

def split_form_ref(value: object) -> tuple[str, int]:
    raw = str(value or "").strip()
    if not raw:
        return "", 1
    match = _FORM_REF_RE.match(raw)
    if match is None:
        return raw, 1
    base = str(match.group("base") or "").strip()
    try:
        form_index = int(match.group("form") or 1)
    except (TypeError, ValueError):
        form_index = 1
    return base, max(1, form_index)


def format_form_ref(value: object, form_index: int | None = None) -> str:
    base, parsed_form = split_form_ref(value)
    requested_form = form_index if form_index is not None else parsed_form
    if base in STUDENTS or base in MULTI_FORM_STUDENTS:
        form = normalize_form_index(base, requested_form)
    else:
        try:
            form = max(1, int(requested_form or 1))
        except (TypeError, ValueError):
            form = 1
    if form <= 1:
        return base
    return f"{base}#{form}"


def form_indexes(student_id: str) -> tuple[int, ...]:
    forms = MULTI_FORM_STUDENTS.get(student_id)
    if not forms:
        return (1,)
    return tuple(range(1, len(forms) + 1))


def form_count(student_id: str) -> int:
    return len(form_indexes(student_id))


def is_multi_form(student_id: str) -> bool:
    return form_count(student_id) > 1


def normalize_form_index(student_id: str, form_index: int | None = None) -> int:
    indexes = form_indexes(student_id)
    try:
        value = int(form_index or 1)
    except (TypeError, ValueError):
        value = 1
    if value in indexes:
        return value
    return indexes[0]


def form_meta(student_id: str, form_index: int | None = None) -> StudentFormMeta:
    forms = MULTI_FORM_STUDENTS.get(student_id)
    if not forms:
        return {}
    index = normalize_form_index(student_id, form_index) - 1
    if 0 <= index < len(forms):
        return forms[index]
    return forms[0]


def field_for_form(student_id: str, key: str, form_index: int | None = None, default: Any = None) -> Any:
    meta = STUDENTS.get(student_id)
    if not meta:
        return default
    override = form_meta(student_id, form_index)
    if key in override:
        return override.get(key, default)
    return meta.get(key, default)


def _value_tuple(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()
    if isinstance(value, (list, tuple, set)):
        return tuple(str(item) for item in value if str(item))
    return (str(value),) if str(value) else ()


def field_values(student_id: str, key: str, default: Any = None) -> tuple[str, ...]:
    if not is_multi_form(student_id):
        return _value_tuple(field(student_id, key, default))
    values: list[str] = []
    for form_index in form_indexes(student_id):
        values.extend(_value_tuple(field_for_form(student_id, key, form_index, default)))
    if not values:
        values.extend(_value_tuple(field(student_id, key, default)))
    return tuple(dict.fromkeys(values))


def template_path_for_form(student_id: str, form_index: int | None = None) -> str:
    template = field_for_form(student_id, "template_name", form_index)
    return str(template or f"{student_id}.png")


def get(student_id: str) -> StudentMeta | None:
    """student_id 로 메타데이터 조회. 없으면 None."""
    return STUDENTS.get(student_id)


def display_name(student_id: str) -> str:
    """
    student_id → 표시 이름.
    DB에 없는 미등록 ID는 ID 문자열 그대로 반환.
    """
    meta = STUDENTS.get(student_id)
    return meta["display_name"] if meta else student_id


def template_path(student_id: str) -> str:
    """Return the default portrait template filename for a student."""
    return template_path_for_form(student_id, 1)


def group(student_id: str) -> str | None:
    """같은 캐릭터 그룹 키 반환."""
    meta = STUDENTS.get(student_id)
    return meta["group"] if meta else None


def variant(student_id: str) -> str | None:
    """코스튬/변형 태그 반환. 기본복이거나 미등록이면 None."""
    meta = STUDENTS.get(student_id)
    return meta["variant"] if meta else None


def all_ids() -> list[str]:
    """등록된 모든 student_id 목록."""
    return list(STUDENTS.keys())


def ids_matching_attributes(attributes: dict[str, str]) -> list[str]:
    """Return students matching every supplied normalized basic-card attribute."""
    supported = {"attack_type", "defense_type", "position", "combat_class", "role"}
    normalized = {
        key: str(value).strip().casefold()
        for key, value in attributes.items()
        if key in supported and str(value).strip()
    }
    if not normalized:
        return []
    return [
        sid
        for sid, meta in STUDENTS.items()
        if all(str(meta.get(key, "")).casefold() == value for key, value in normalized.items())
    ]


def ids_in_group(group_name: str) -> list[str]:
    """같은 group 을 가진 모든 student_id 목록."""
    return [sid for sid, m in STUDENTS.items() if m["group"] == group_name]


def field(student_id: str, key: str, default: Any = None) -> Any:
    """학생 메타데이터의 임의 필드 조회."""
    meta = STUDENTS.get(student_id)
    if not meta:
        return default
    return meta.get(key, default)


def search_tags(student_id: str) -> list[str]:
    value = field(student_id, "search_tags", [])
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value]
    return []


def kr_search_tags(student_id: str) -> list[str]:
    value = field(student_id, "kr_search_tags", [])
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value]
    return []


@lru_cache(maxsize=None)
def _base_search_blob(student_id: str) -> str:
    terms = [student_id, display_name(student_id)]
    terms.extend(search_tags(student_id))
    terms.extend(kr_search_tags(student_id))
    return " ".join(term for term in terms if term).casefold()


def search_blob(student_id: str, *extra_terms: object) -> str:
    base = _base_search_blob(student_id)
    extras = " ".join(str(term) for term in extra_terms if term).casefold().strip()
    if not extras:
        return base
    if not base:
        return extras
    return f"{base} {extras}"


def school(student_id: str) -> str | None:
    return field(student_id, "school")


def rarity(student_id: str) -> str | None:
    return field(student_id, "rarity")


def recruit_type(student_id: str) -> str | None:
    return field(student_id, "recruit_type")


def attack_type(student_id: str) -> str | None:
    return field(student_id, "attack_type")


def attack_type_trait(student_id: str) -> str | None:
    return field(student_id, "attack_type_trait")


def defense_type(student_id: str) -> str | None:
    return field(student_id, "defense_type")


def growth_material_main(student_id: str) -> str | None:
    return field(student_id, "growth_material_main")


def growth_material_sub(student_id: str) -> str | None:
    return field(student_id, "growth_material_sub")


def raw_skill_ex_material(student_id: str) -> list[list[int]]:
    return field(student_id, "raw_skill_ex_material", []) or []


def raw_skill_ex_material_amount(student_id: str) -> list[list[int]]:
    return field(student_id, "raw_skill_ex_material_amount", []) or []


def raw_skill_material(student_id: str) -> list[list[int]]:
    return field(student_id, "raw_skill_material", []) or []


def raw_skill_material_amount(student_id: str) -> list[list[int]]:
    return field(student_id, "raw_skill_material_amount", []) or []


def mapped_skill_ex_material_rows(student_id: str) -> list[dict[str, int]]:
    return field(student_id, "mapped_skill_ex_material_rows", []) or []


def mapped_skill_material_rows(student_id: str) -> list[dict[str, int]]:
    return field(student_id, "mapped_skill_material_rows", []) or []


def equipment_slots(student_id: str) -> tuple[str | None, str | None, str | None]:
    return (
        field(student_id, "equipment_slot_1"),
        field(student_id, "equipment_slot_2"),
        field(student_id, "equipment_slot_3"),
    )


def combat_class(student_id: str) -> str | None:
    return field(student_id, "combat_class")


def cover_type(student_id: str) -> str | None:
    return field(student_id, "cover_type")


def range_type(student_id: str) -> str | None:
    return field(student_id, "range_type")


def role(student_id: str) -> str | None:
    return field(student_id, "role")


def weapon_type(student_id: str) -> str | None:
    return field(student_id, "weapon_type")


def position(student_id: str) -> str | None:
    return field(student_id, "position")


def terrain_outdoor(student_id: str) -> str | None:
    return field(student_id, "terrain_outdoor")


def terrain_urban(student_id: str) -> str | None:
    return field(student_id, "terrain_urban")


def terrain_indoor(student_id: str) -> str | None:
    return field(student_id, "terrain_indoor")


def weapon3_terrain_boost(student_id: str) -> str | None:
    return field(student_id, "weapon3_terrain_boost")


def has_favorite_item(student_id: str, server: str = "kr") -> str | None:
    normalized_server = str(server or "kr").strip().casefold()
    if normalized_server not in {"jp", "kr"}:
        raise ValueError(f"unsupported server: {server}")
    explicit = field(student_id, f"has_favorite_item_{normalized_server}")
    if explicit is not None:
        return explicit
    # Older metadata only has the shared field. Keep it as a fallback so
    # existing asset bundles continue to work while server-specific values
    # are introduced incrementally.
    explicit = field(student_id, "has_favorite_item")
    if explicit is not None:
        return explicit
    return "yes" if student_id in FAVORITE_ITEM_STUDENT_IDS else "no"


def has_favorite_item_jp(student_id: str) -> str | None:
    return has_favorite_item(student_id, server="jp")


def has_favorite_item_kr(student_id: str) -> str | None:
    return has_favorite_item(student_id, server="kr")


def favorite_item_enabled(student_id: str, server: str = "kr") -> bool:
    return has_favorite_item(student_id, server=server) == "yes"


def is_jp_only(student_id: str) -> bool:
    return student_id in JP_ONLY_STUDENT_IDS


def passive_stat(student_id: str) -> list[str]:
    return field(student_id, "passive_stat", []) or []


def weapon_passive_stat(student_id: str) -> list[str]:
    return field(student_id, "weapon_passive_stat", []) or []


def extra_passive_stat(student_id: str) -> list[str]:
    return field(student_id, "extra_passive_stat", []) or []


def skill_buff(student_id: str) -> list[str]:
    return field(student_id, "skill_buff", []) or []


def skill_debuff(student_id: str) -> list[str]:
    return field(student_id, "skill_debuff", []) or []


def skill_cc(student_id: str) -> list[str]:
    return field(student_id, "skill_cc", []) or []


def skill_special(student_id: str) -> list[str]:
    return field(student_id, "skill_special", []) or []


def skill_heal_targets(student_id: str) -> list[str]:
    return field(student_id, "skill_heal_targets", []) or []


def skill_dispel_targets(student_id: str) -> list[str]:
    return field(student_id, "skill_dispel_targets", []) or []


def skill_reposition_targets(student_id: str) -> list[str]:
    return field(student_id, "skill_reposition_targets", []) or []


def skill_summon_types(student_id: str) -> list[str]:
    return field(student_id, "skill_summon_types", []) or []


def skill_ignore_cover(student_id: str) -> str | None:
    return field(student_id, "skill_ignore_cover")


def skill_is_area_damage(student_id: str) -> str | None:
    return field(student_id, "skill_is_area_damage")


def skill_buff_specials(student_id: str) -> list[str]:
    return field(student_id, "skill_buff_specials", []) or []


def skill_knockback(student_id: str) -> str | None:
    return field(student_id, "skill_knockback")


_TERRAIN_ORDER: tuple[str, ...] = ("D", "C", "B", "A", "S", "SS")


def upgraded_terrain_rank(rank: str | None) -> str | None:
    if rank is None:
        return None
    try:
        idx = _TERRAIN_ORDER.index(rank)
    except ValueError:
        return rank
    return _TERRAIN_ORDER[min(idx + 1, len(_TERRAIN_ORDER) - 1)]


def terrain_with_weapon3(student_id: str, terrain_key: str) -> str | None:
    current = field(student_id, terrain_key)
    boosted = weapon3_terrain_boost(student_id)
    if boosted != terrain_key:
        return current
    return upgraded_terrain_rank(current)


def _load_external_student_meta() -> None:
    try:
        from pathlib import Path
        import runpy

        from core.config import DEFAULT_ASSET_DIR

        candidates = (
            DEFAULT_ASSET_DIR / "core" / "student_meta_data.py",
            DEFAULT_ASSET_DIR / "core" / "student_meta.py",
        )
        external_path = next((path for path in candidates if path.exists()), None)
        if external_path is None or external_path.resolve() == Path(__file__).resolve():
            return
        namespace = runpy.run_path(str(external_path))
        global FAVORITE_ITEM_MAX_TIER
        global FAVORITE_ITEM_STUDENT_IDS
        global JP_ONLY_STUDENT_IDS
        global MULTI_FORM_STUDENTS
        global STUDENTS
        if isinstance(namespace.get("STUDENTS"), dict):
            STUDENTS = namespace["STUDENTS"]
        if isinstance(namespace.get("MULTI_FORM_STUDENTS"), dict):
            MULTI_FORM_STUDENTS = namespace["MULTI_FORM_STUDENTS"]
        if isinstance(namespace.get("FAVORITE_ITEM_STUDENT_IDS"), (set, frozenset)):
            FAVORITE_ITEM_STUDENT_IDS = frozenset(namespace["FAVORITE_ITEM_STUDENT_IDS"])
        if isinstance(namespace.get("JP_ONLY_STUDENT_IDS"), (set, frozenset)):
            JP_ONLY_STUDENT_IDS = frozenset(namespace["JP_ONLY_STUDENT_IDS"])
        if namespace.get("FAVORITE_ITEM_MAX_TIER") is not None:
            FAVORITE_ITEM_MAX_TIER = str(namespace["FAVORITE_ITEM_MAX_TIER"])
    except Exception:
        return


_load_external_student_meta()
