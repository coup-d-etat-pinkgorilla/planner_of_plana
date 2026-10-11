from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import json
from typing import Callable, Iterable

from core import student_meta
from core.equipment_items import (
    EQUIPMENT_ITEM_ID_TO_NAME,
    EQUIPMENT_ORDERED_ITEM_IDS,
    EQUIPMENT_SERIES,
    EQUIPMENT_EXP_ITEMS,
    EQUIPMENT_USEALL_ITEMS,
    WEAPON_PART_ITEMS,
)
from core.inventory_present_items import PRESENT_ORDERED_ITEMS


@dataclass(frozen=True, slots=True)
class InventoryCatalogRow:
    resource_key: str
    item_id: str | None
    display_name: str
    category: str
    profile_id: str
    order_index: int
    zero_fill_allowed: bool
    school: str | None = None
    family: str | None = None
    tier: int | None = None

    def __post_init__(self) -> None:
        # Only new metadata scalars: do not tighten stored inventory/history/loader validators.
        for name in ("school", "family"):
            value = getattr(self, name)
            if value is not None:
                if not isinstance(value, str):
                    raise ValueError(f"{name} must be a string or null")
                try:
                    value.encode("utf-8")
                except UnicodeEncodeError as exc:
                    raise ValueError(f"{name} must be valid Unicode") from exc
        if self.tier is not None and (type(self.tier) is not int or self.tier < 1):
            raise ValueError("tier must be an exact integer >= 1 or null")

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


_SCHOOLS = (
    "Hyakkiyako", "RedWinter", "Trinity", "Gehenna", "Abydos",
    "Millennium", "Arius", "Shanhaijing", "Valkyrie", "Highlander",
    "Wildhunt",
)
_OPARTS = (
    ("Nebra Disk", "Nebra"), ("Phaistos Disc", "Phaistos"),
    ("Wolfsegg Steel", "Wolfsegg"), ("Nimrud Lens", "Nimrud"),
    ("Madrake Extract", "Mandragora"), ("Rohonc Codex", "Rohonc"),
    ("Aether Essence", "Ether"), ("Antikythera Mechanism", "Antikythera"),
    ("Voynich Manuscript", "Voynich"), ("Crystal Haniwa", "CrystalHaniwa"),
    ("Totem Pole", "TotemPole"), ("Ancient Battery", "Baghdad"),
    ("Golden Fleece", "GoldenFleece"), ("Okiku Doll", "Kikuko"),
    ("Disco Colgante", "DiscoColgante"), ("Atlantis Medal", "AtlantisMedal"),
    ("Roman Dodecahedron", "RomanDice"), ("Quimbaya Relic", "Quimbaya"),
    ("Istanbul Rocket", "Rocket"), ("Mystery Stone", "WinniStone"),
)
_WORKBOOKS = (
    ("Item_Icon_WorkBook_PotentialMaxHP", "Max HP workbook"),
    ("Item_Icon_WorkBook_PotentialAttack", "Attack workbook"),
    ("Item_Icon_WorkBook_PotentialHealPower", "Heal workbook"),
)
_REPORT_NAMES = ("초급 활동 보고서", "일반 활동 보고서", "상급 활동 보고서", "최상급 활동 보고서")


# Scanner support is reviewed independently of which profiles the catalog contains.
# Keep the existing protocol/session order; equipment uses a separate navigation page.
_SUPPORTED_SCAN_PROFILES = (
    "equipment", "activity_reports", "tech_notes", "tactical_bd",
    "ooparts", "presents", "student_elephs",
)
_SUPPORTED_ITEM_SCAN_PROFILES = tuple(
    profile for profile in _SUPPORTED_SCAN_PROFILES if profile != "equipment"
)


def _scan_profiles_for_catalog(catalog: Iterable[InventoryCatalogRow]) -> tuple[str, ...]:
    """Require catalog rows for supported scans; extra catalog profiles remain unscannable."""
    catalog_profiles = {row.profile_id for row in catalog}
    missing = tuple(profile for profile in _SUPPORTED_SCAN_PROFILES if profile not in catalog_profiles)
    if missing:
        raise RuntimeError("supported scan profiles are missing from catalog: " + ", ".join(missing))
    return _SUPPORTED_SCAN_PROFILES


def ordered_student_eleph_ids(
    student_ids: Iterable[str],
    display_name: Callable[[str], str],
    is_jp_only: Callable[[str], bool],
) -> list[str]:
    """Return the version-scoped in-game order; IDs remain stable identity."""
    return sorted(
        (student_id for student_id in student_ids if not is_jp_only(student_id)),
        key=lambda student_id: (
            f"{display_name(student_id)}의 엘레프".casefold(),
            student_id,
        ),
    )


def _equipment_row_metadata() -> dict[str, tuple[str, int | None]]:
    """Exact reviewed IDs only; labels and arbitrary suffixes never infer metadata."""
    metadata: dict[str, tuple[str, int | None]] = {}
    useall_ids = {item_id for item_id, _name in EQUIPMENT_USEALL_ITEMS}
    for series in EQUIPMENT_SERIES:
        family = f"equipment:{series.icon_key}"
        for tier in range(1, 11):
            metadata[f"Equipment_Icon_{series.icon_key}_Tier{tier}"] = (family, tier)
        useall_id = f"Equipment_Icon_{series.icon_key}_Useall_Piece"
        if useall_id in useall_ids:
            metadata[useall_id] = (family, None)
    exp_ids = {item_id for item_id, _name in EQUIPMENT_EXP_ITEMS}
    for tier in range(1, 5):
        item_id = f"Equipment_Icon_Exp_{tier - 1}"
        if item_id in exp_ids:
            metadata[item_id] = ("equipment_exp", tier)
    for part, _label in WEAPON_PART_ITEMS:
        for tier in range(1, 5):
            metadata[f"Equipment_Icon_WeaponExpGrowth{part}_{tier - 1}"] = (f"weapon_exp:{part}", tier)
    return metadata


def _rows() -> list[InventoryCatalogRow]:
    rows: list[InventoryCatalogRow] = []

    def add(
        item_id: str, name: str, category: str, profile: str, index: int,
        school: str | None = None, family: str | None = None, tier: int | None = None,
    ) -> None:
        rows.append(InventoryCatalogRow(
            item_id, item_id, name, category, profile, index, True, school, family, tier,
        ))

    equipment_metadata = _equipment_row_metadata()
    for index, item_id in enumerate(EQUIPMENT_ORDERED_ITEM_IDS):
        name = EQUIPMENT_ITEM_ID_TO_NAME.get(item_id)
        if name is None and item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
            body = item_id.removeprefix("Equipment_Icon_WeaponExpGrowth")
            part, _, tier = body.rpartition("_")
            label = dict(WEAPON_PART_ITEMS).get(part, part)
            name = f"{label} T{int(tier) + 1}" if tier.isdigit() else item_id
        family, tier = equipment_metadata.get(item_id, (None, None))
        add(item_id, name or item_id, "equipment", "equipment", index, family=family, tier=tier)

    for index, name in enumerate(_REPORT_NAMES):
        add(f"Item_Icon_ExpItem_{index}", name, "activity_report", "activity_reports", index, family="activity_report", tier=index + 1)

    for profile, kind, prefix in (
        ("tech_notes", "Note", "Item_Icon_SkillBook"),
        ("tactical_bd", "BD", "Item_Icon_Material_ExSkill"),
    ):
        index = 0
        for school in _SCHOOLS:
            for tier in range(4):
                add(f"{prefix}_{school}_{tier}", f"{school} {kind} T{tier + 1}", profile, profile, index, school=school, family=profile, tier=tier + 1)
                index += 1
        if profile == "tech_notes":
            add("Item_Icon_SkillBook_Ultimate", "비의서", profile, profile, index)

    index = 0
    for display_base, icon_key in _OPARTS:
        for tier in range(4):
            add(f"Item_Icon_Material_{icon_key}_{tier}", f"{display_base} T{tier + 1}", "oopart", "ooparts", index, family=f"oopart:{icon_key}", tier=tier + 1)
            index += 1
    for item_id, name in _WORKBOOKS:
        add(item_id, name, "workbook", "ooparts", index, family="workbook:" + item_id.removeprefix("Item_Icon_WorkBook_"))
        index += 1

    for index, (item_id, name) in enumerate(PRESENT_ORDERED_ITEMS):
        add(item_id, name, "present", "presents", index)

    eleph_ids = ordered_student_eleph_ids(
        student_meta.all_ids(), student_meta.display_name, student_meta.is_jp_only
    )
    for index, student_id in enumerate(eleph_ids):
        add(
            f"Item_Icon_SecretStone_{student_id}",
            f"{student_meta.display_name(student_id)}의 엘레프",
            "student_eleph", "student_elephs", index,
        )
    # Catalog-only currency rows: scanner admission remains the reviewed seven profiles.
    rows.extend((
        InventoryCatalogRow(
            resource_key="credits", item_id=None, display_name="크레딧",
            category="credits", profile_id="currencies", order_index=0,
            zero_fill_allowed=False, school=None, family=None, tier=None,
        ),
        InventoryCatalogRow(
            resource_key="Item_Icon_SecretStone", item_id="Item_Icon_SecretStone",
            display_name="엘리그마", category="eligma", profile_id="currencies", order_index=1,
            zero_fill_allowed=False, school=None, family=None, tier=None,
        ),
    ))
    return rows


CATALOG: tuple[InventoryCatalogRow, ...] = tuple(_rows())
BY_KEY = {row.resource_key: row for row in CATALOG}
# D18: v6 stored 비의서 (ExcelDB 9999, Item_Icon_SkillBook_Ultimate) under the icon name of
# 비의서 조각 (9998, *_Piece). Stored inventories and v6 imports keep the old key; map it forward.
LEGACY_RESOURCE_KEYS = {"Item_Icon_SkillBook_Ultimate_Piece": "Item_Icon_SkillBook_Ultimate"}


def canonical_resource_key(key: str) -> str:
    """Current catalog key for a stored or imported inventory key."""
    return LEGACY_RESOURCE_KEYS.get(key, key)
# Reviewed scanner support stays independent of catalog-only profiles. Equipment has its own page.
SCAN_PROFILES: tuple[str, ...] = _scan_profiles_for_catalog(CATALOG)
ITEM_SCAN_PROFILES: tuple[str, ...] = _SUPPORTED_ITEM_SCAN_PROFILES


def planning_aliases() -> dict[str, str]:
    aliases = {row.resource_key: row.resource_key for row in CATALOG}
    aliases.update({row.display_name: row.resource_key for row in CATALOG})
    aliases.update(LEGACY_RESOURCE_KEYS)
    for tier in range(1, 5):
        aliases[f"Item_Icon_ExpItem_0 T{tier}"] = f"Item_Icon_ExpItem_{tier - 1}"
        aliases[f"Equipment_Icon_Exp_0 T{tier}"] = f"Equipment_Icon_Exp_{tier - 1}"
        for part, _label in WEAPON_PART_ITEMS:
            aliases[f"Equipment_Icon_WeaponExpGrowth{part}_0 T{tier}"] = (
                f"Equipment_Icon_WeaponExpGrowth{part}_{tier - 1}"
            )
    return aliases


ALIASES = planning_aliases()


def resolve_planning_resource(label: str) -> InventoryCatalogRow | None:
    key = ALIASES.get(label)
    return None if key is None else BY_KEY.get(key)


def catalog_payload() -> list[dict[str, object]]:
    return [row.to_dict() for row in CATALOG]


def _catalog_revision(rows: list[dict[str, object]]) -> str:
    content = json.dumps(rows, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


CATALOG_REVISION = _catalog_revision(catalog_payload())
