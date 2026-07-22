from __future__ import annotations

from dataclasses import asdict, dataclass

from core import student_meta
from core.equipment_items import (
    EQUIPMENT_ITEM_ID_TO_NAME,
    EQUIPMENT_ORDERED_ITEM_IDS,
    WEAPON_PART_ITEMS,
)


@dataclass(frozen=True, slots=True)
class InventoryCatalogRow:
    resource_key: str
    item_id: str | None
    display_name: str
    category: str
    profile_id: str
    order_index: int
    zero_fill_allowed: bool

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


def _rows() -> list[InventoryCatalogRow]:
    rows: list[InventoryCatalogRow] = []

    def add(item_id: str, name: str, category: str, profile: str, index: int) -> None:
        rows.append(InventoryCatalogRow(item_id, item_id, name, category, profile, index, True))

    for index, item_id in enumerate(EQUIPMENT_ORDERED_ITEM_IDS):
        name = EQUIPMENT_ITEM_ID_TO_NAME.get(item_id)
        if name is None and item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
            body = item_id.removeprefix("Equipment_Icon_WeaponExpGrowth")
            part, _, tier = body.rpartition("_")
            label = dict(WEAPON_PART_ITEMS).get(part, part)
            name = f"{label} T{int(tier) + 1}" if tier.isdigit() else item_id
        add(item_id, name or item_id, "equipment", "equipment", index)

    for index, name in enumerate(_REPORT_NAMES):
        add(f"Item_Icon_ExpItem_{index}", name, "activity_report", "activity_reports", index)

    for profile, kind, prefix in (
        ("tech_notes", "Note", "Item_Icon_SkillBook"),
        ("tactical_bd", "BD", "Item_Icon_Material_ExSkill"),
    ):
        index = 0
        for school in _SCHOOLS:
            for tier in range(4):
                add(f"{prefix}_{school}_{tier}", f"{school} {kind} T{tier + 1}", profile, profile, index)
                index += 1
        if profile == "tech_notes":
            add("Item_Icon_SkillBook_Ultimate_Piece", "비의서", profile, profile, index)

    index = 0
    for display_base, icon_key in _OPARTS:
        for tier in range(4):
            add(f"Item_Icon_Material_{icon_key}_{tier}", f"{display_base} T{tier + 1}", "oopart", "ooparts", index)
            index += 1
    for item_id, name in _WORKBOOKS:
        add(item_id, name, "workbook", "ooparts", index)
        index += 1

    eleph_ids = sorted(
        (student_id for student_id in student_meta.all_ids() if not student_meta.is_jp_only(student_id)),
        key=lambda student_id: (f"{student_meta.display_name(student_id)}의 엘레프".casefold(), student_id),
    )
    for index, student_id in enumerate(eleph_ids):
        add(
            f"Item_Icon_SecretStone_{student_id}",
            f"{student_meta.display_name(student_id)}의 엘레프",
            "student_eleph", "student_elephs", index,
        )
    return rows


CATALOG: tuple[InventoryCatalogRow, ...] = tuple(_rows())
BY_KEY = {row.resource_key: row for row in CATALOG}


def planning_aliases() -> dict[str, str]:
    aliases = {row.resource_key: row.resource_key for row in CATALOG}
    aliases.update({row.display_name: row.resource_key for row in CATALOG})
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
