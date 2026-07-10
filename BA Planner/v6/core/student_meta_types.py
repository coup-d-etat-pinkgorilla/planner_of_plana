"""Shared type contracts for generated student metadata."""

from __future__ import annotations

from typing import NotRequired, TypedDict

class StudentMeta(TypedDict):
    display_name: str            # UI 표시용 최종 이름 ("시즈코(수영복)" 등)
    template_name: str           # 학생 텍스처/초상화 파일명
    group: str                   # 같은 캐릭터임을 나타내는 그룹 키 ("시즈코")
    variant: str | None          # 코스튬/변형 태그 (없으면 None)
    search_tags: NotRequired[list[str]]
    kr_search_tags: NotRequired[list[str]]
    school: NotRequired[str | None]
    rarity: NotRequired[str | None]
    recruit_type: NotRequired[str | None]
    attack_type: NotRequired[str | None]
    attack_type_trait: NotRequired[str | None]
    defense_type: NotRequired[str | None]
    growth_material_main: NotRequired[str | None]
    growth_material_sub: NotRequired[str | None]
    raw_skill_ex_material: NotRequired[list[list[int]]]
    raw_skill_ex_material_amount: NotRequired[list[list[int]]]
    raw_skill_material: NotRequired[list[list[int]]]
    raw_skill_material_amount: NotRequired[list[list[int]]]
    mapped_skill_ex_material_rows: NotRequired[list[dict[str, int]]]
    mapped_skill_material_rows: NotRequired[list[dict[str, int]]]
    equipment_slot_1: NotRequired[str | None]
    equipment_slot_2: NotRequired[str | None]
    equipment_slot_3: NotRequired[str | None]
    combat_class: NotRequired[str | None]   # striker / special
    cover_type: NotRequired[str | None]     # cover / no_cover
    range_type: NotRequired[str | None]     # short / mid / long
    role: NotRequired[str | None]           # tanker / dealer / healer / supporter / t_s
    weapon_type: NotRequired[str | None]
    position: NotRequired[str | None]       # front / middle / back
    terrain_outdoor: NotRequired[str | None]
    terrain_urban: NotRequired[str | None]
    terrain_indoor: NotRequired[str | None]
    weapon3_terrain_boost: NotRequired[str | None]
    has_favorite_item: NotRequired[str | None]
    has_favorite_item_jp: NotRequired[str | None]
    has_favorite_item_kr: NotRequired[str | None]
    farmable: NotRequired[str | None]
    passive_stat: NotRequired[list[str]]
    weapon_passive_stat: NotRequired[list[str]]
    extra_passive_stat: NotRequired[list[str]]
    skill_buff: NotRequired[list[str]]
    skill_debuff: NotRequired[list[str]]
    skill_cc: NotRequired[list[str]]
    skill_special: NotRequired[list[str]]
    skill_heal_targets: NotRequired[list[str]]
    skill_dispel_targets: NotRequired[list[str]]
    skill_reposition_targets: NotRequired[list[str]]
    skill_summon_types: NotRequired[list[str]]
    skill_ignore_cover: NotRequired[str | None]
    skill_is_area_damage: NotRequired[str | None]
    skill_buff_specials: NotRequired[list[str]]
    skill_knockback: NotRequired[str | None]

class StudentFormMeta(TypedDict, total=False):
    label: str
    template_name: str
    attack_type: str | None
    attack_type_trait: str | None
    defense_type: str | None
    combat_class: str | None
    cover_type: str | None
    range_type: str | None
    role: str | None
    weapon_type: str | None
    position: str | None
    terrain_outdoor: str | None
    terrain_urban: str | None
    terrain_indoor: str | None
    weapon3_terrain_boost: str | None
    passive_stat: list[str]
    weapon_passive_stat: list[str]
    extra_passive_stat: list[str]
    skill_buff: list[str]
    skill_debuff: list[str]
    skill_cc: list[str]
    skill_special: list[str]
    skill_heal_targets: list[str]
    skill_dispel_targets: list[str]
    skill_reposition_targets: list[str]
    skill_summon_types: list[str]
    skill_ignore_cover: str | None
    skill_is_area_damage: str | None
    skill_buff_specials: list[str]
    skill_knockback: str | None

EDITABLE_FIELDS: tuple[str, ...] = (
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
