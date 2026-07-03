"""
Student scanning pipeline for BA Analyzer v6.

This module coordinates student navigation, recognition, and data collection.
Broken legacy comments and UI strings were cleaned up for readability.
"""

import ctypes
import os
import sys
import time
import json
import hashlib
import numpy as np
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Iterable, Iterator, Optional
from PIL import Image, ImageDraw


from core.logger import get_logger, log_section, LOG_SCANNER
from core.log_context import (
    ScanCtx, log_exc, EXC_WARNING, EXC_ERROR, EXC_FATAL,
    dump_roi,
)

# Module logger
_log = get_logger(LOG_SCANNER)


from core.capture import (
    capture_window_background,
    crop_region,
    get_window_rect,
    find_target_hwnd,
)
from core.input import (
    click_center,
    safe_click,
    drag_scroll,
    press_esc,
    click_point,
    send_escape,
    send_key,
    client_to_screen,
    move_cursor_to_screen,
    ratio_to_client,
)


from core.matcher import (
    WeaponState,
    CheckFlag,
    EquipSlotFlag,
    match_score_resized,
    match_score_resized_raw,
    match_score_textonly,
    match_student_texture,
    is_lobby,
    is_student_menu,
    is_student_additional_menu_on,
    is_level_tab_on,
    is_basic_info_tab_on,
    is_star_tab_on,
    detect_weapon_state,
    read_skill_check,
    read_equip_check,
    read_equip_check_inside,
    read_equip_slot_flag,
    rank_equip_tier_candidates,
    read_stat_value,
    read_student_star_v5,
    read_weapon_star_v5,
    read_skill,
    read_basic_skill_result,
    read_basic_student_level_result,
    read_basic_student_star_result,
    read_basic_student_attribute_result,
    read_basic_weapon_level_result,
    read_basic_weapon_star_result,
    read_basic_equipment_level_result,
    read_basic_equipment_generated_level_result,
    read_basic_equipment_icon_tier_result,
    read_basic_favorite_tier_result,
    learn_basic_equipment_level,
    extract_basic_student_level_glyphs,
    read_equip_level,
    read_weapon_level,
    read_student_level_v5,
)

import core.ocr as ocr
import core.student_meta as student_meta
from core.config import ASSET_DIR, BASE_DIR, TEMPLATE_DIR
from core.inventory_profiles import (
    find_inventory_profile_duplicate,
    get_inventory_profile,
    infer_inventory_scan_profile,
    inventory_item_display_name,
    inventory_profile_ordered_item_ids,
    is_inventory_profile_complete,
    is_inventory_profile_terminal_seen,
    next_inventory_profile_name,
    normalize_inventory_profile_ids,
    resolve_inventory_profile_name,
)
from core.inventory_count_matcher import (
    read_equipment_count_from_detail,
    read_item_count_from_detail,
)
from core.equipment_items import canonical_equipment_item_id
from core.inventory_grid_matcher import (
    InventoryGridRowAnchorState,
    detect_inventory_grid_tier_hint,
    match_inventory_grid_template,
)
from core.inventory_input import (
    InventoryGridInput,
    InventoryInputUnavailable,
    create_inventory_input_backend,
)
from core.inventory_slot_count_matcher import (
    estimate_item_slot_count_row_y_offset,
    read_item_slot_count,
)
from core.scan_status import make_status_event
from core.screen_crop_set import PreparedScreenRegion, ScreenCropSet



# Constants


MAX_SCROLLS          = 60
SAME_THRESH          = 0.97
STUDENT_MENU_WAIT    = 3.0
MAX_CONSECUTIVE_DUP  = 3
MAX_STUDENT_LEVEL    = 90
MAX_EQUIP_LEVEL      = 70
SKILL3_UNLOCK_STAR   = 3
SKILL2_UNLOCK_STAR   = 2
WEAPON_UNLOCK_STAR   = 5
EQUIP2_UNLOCK_LEVEL  = 10
EQUIP3_UNLOCK_LEVEL  = 20
STAT_UNLOCK_LEVEL    = 90
STAT_UNLOCK_STAR     = 5
BASIC_EQUIP_EMPTY_DOT_REGIONS = {
    1: {"x1": 0.5980, "y1": 0.7650, "x2": 0.6170, "y2": 0.7900},
    2: {"x1": 0.6760, "y1": 0.7650, "x2": 0.6950, "y2": 0.7900},
    3: {"x1": 0.7540, "y1": 0.7650, "x2": 0.7730, "y2": 0.7900},
    4: {"x1": 0.8120, "y1": 0.7550, "x2": 0.8400, "y2": 0.7950},
}
BASIC_EQUIP_EMPTY_DOT_MIN_PIXELS = 40
BASIC_EQUIP_EMPTY_DOT_MIN_RATIO = 0.035
EQUIPMENT_GROWTH_ACTIVE_BLUE_MIN_RATIO = 0.25
STUDENT_PANEL_TITLE_REGION = {"x1": 1030 / 2560, "y1": 145 / 1440, "x2": 1530 / 2560, "y2": 285 / 1440}
STUDENT_PANEL_TITLE_MIN_SCORE = 0.86
STUDENT_PANEL_TITLE_MIN_MARGIN = 0.04
STUDENT_PANEL_TITLE_BOOTSTRAP_SCORE = 0.82
STUDENT_PANEL_TITLE_BOOTSTRAP_MARGIN = 0.10
STUDENT_PANEL_TITLE_ADAPTIVE_FLOOR = 0.82
STUDENT_PANEL_TITLE_ADAPTIVE_LEAD = 0.025
STUDENT_PANEL_TITLE_HISTORY_SIZE = 20
INVENTORY_FILTER_TITLE_REGION = STUDENT_PANEL_TITLE_REGION
INVENTORY_FILTER_TITLE_TEMPLATE = TEMPLATE_DIR / "menu_detect_flag" / "inventory_filter_title_display_settings.png"
INVENTORY_FILTER_TITLE_MIN_SCORE = 0.85
INVENTORY_FILTER_TITLE_STABLE_POLLS = 1
STUDENT_PANEL_TITLE_TEMPLATES = {
    "equipment": TEMPLATE_DIR / "menu_detect_flag" / "student_panel_title_equipment.png",
    "weapon": TEMPLATE_DIR / "menu_detect_flag" / "student_panel_title_weapon.png",
    "skill": TEMPLATE_DIR / "menu_detect_flag" / "student_panel_title_skill.png",
    "stat": TEMPLATE_DIR / "menu_detect_flag" / "student_panel_title_stat.png",
}
DETAIL_READY_SCORE   = 0.80
DETAIL_READY_WAIT    = 6.0
DETAIL_READY_STABLE_POLLS = 1
LOBBY_EXIT_WAIT      = 5.5
MENU_CLICK_SETTLE_WAIT = 1.2
STUDENT_MENU_READY_STABLE_POLLS = 2
STUDENT_MENU_READY_SETTLE_WAIT = 0.45
FIRST_STUDENT_PRECLICK_WAIT = 0.45
DETAIL_CLICK_SETTLE_WAIT = 1.0
PANEL_CLOSE_SETTLE_WAIT = 0.55
BASIC_TAB_SETTLE_WAIT = 0.45
LEVEL_CAPTURE_RETRY_WAIT = 0.40
WEAPON_CAPTURE_RETRY_WAIT = 0.40
MENU_CLOSE_DETAIL_WAIT = 0.35
EQUIP_CHECK_RETRY_WAIT = 0.25
EQUIP_TIER_ACCEPT_SCORE = 0.72
EQUIP_T10_LEVEL70_FALLBACK_SCORE = 0.66
UI_FLAG_POLL = 0.12
ADDITIONAL_PANEL_READY_WAIT = 1.8
TAB_ON_READY_WAIT = 1.5
UI_FLAG_MATCH_DELAY = 0.10
STAT_PANEL_MATCH_DELAY = 0.22
PANEL_TRANSITION_INITIAL_WAIT = 0.10
PANEL_TRANSITION_MIN_WAIT = 0.08
PANEL_TRANSITION_MAX_WAIT = 0.35
PANEL_TRANSITION_LEAD = 0.10
PANEL_TRANSITION_POLL = 0.08
PANEL_TRANSITION_HISTORY_SIZE = 20
CAPTURED_CLICK_POINTS_FILE = BASE_DIR / "debug" / "captured_click_points.json"
REGION_CAPTURE_DIR = BASE_DIR / "debug" / "region_captures"
INVENTORY_SORT_RULE_MATCH_THRESHOLD = 0.78
ITEM_SORT_RULE_MATCH_THRESHOLD = 0.68
EQUIPMENT_SORT_RULE_MATCH_THRESHOLD = 0.70
INVENTORY_SORT_RULE_MAX_ATTEMPTS = 3
INVENTORY_FILTER_MENU_SETTLE_WAIT = 0.65
INVENTORY_FILTER_TAB_SETTLE_WAIT = 0.45
INVENTORY_SORT_RULE_CHECK_WAIT = 0.75
INVENTORY_SORT_RULE_RETRY_WAIT = 0.45
INVENTORY_PANEL_READY_THRESHOLD = 0.35
INVENTORY_PANEL_OPEN_TIMEOUT = 1.8
INVENTORY_PANEL_OPEN_ATTEMPTS = 3
INVENTORY_FILTER_CONFIRM_WAIT = 0.65
INVENTORY_PROFILE_MAX_UNIQUE_ITEMS = {
    "activity_reports": 4,
    "tech_notes": 45,
    "tactical_bd": 44,
    "ooparts": 83,
    "equipment": 110,
}
PROFILE_DIRECT_MATCH_THRESHOLD = 0.82
INVENTORY_DETAIL_ICON_MATCH_WEIGHT = 0.40
INVENTORY_DETAIL_NAME_MATCH_WEIGHT = 0.60
STRICT_DETAIL_FAMILY_THRESHOLDS: dict[str, tuple[float, float, float]] = {
    "Equipment_Icon_WeaponExpGrowth": (0.92, 0.025, 0.03),
}


def _combine_inventory_detail_scores(icon_score: float, name_score: float) -> float:
    if name_score <= 0.0:
        return icon_score
    return (
        INVENTORY_DETAIL_ICON_MATCH_WEIGHT * icon_score
        + INVENTORY_DETAIL_NAME_MATCH_WEIGHT * name_score
    )


def _inventory_detail_strict_family(item_id: str | None) -> str | None:
    if not item_id:
        return None
    for prefix in STRICT_DETAIL_FAMILY_THRESHOLDS:
        if item_id.startswith(prefix):
            return prefix
    return None


def _inventory_detail_strict_family_position(
    item_id: str | None,
) -> tuple[str, int, int] | None:
    family_key = _inventory_detail_strict_family(item_id)
    if family_key != "Equipment_Icon_WeaponExpGrowth" or not item_id:
        return None
    suffix = item_id.removeprefix("Equipment_Icon_WeaponExpGrowth")
    parts = suffix.split("_")
    if len(parts) != 2:
        return None
    group_token = parts[0]
    try:
        tier_token = int(parts[1])
    except ValueError:
        return None
    group_rank = {"Z": 0, "C": 1, "B": 2, "A": 3}.get(group_token)
    tier_rank = {3: 0, 2: 1, 1: 2, 0: 3}.get(tier_token)
    if group_rank is None or tier_rank is None:
        return None
    return family_key, group_rank, tier_rank
PROFILE_SEARCH_MATCH_THRESHOLD = 0.88
VK_SPACE = 0x20
VK_LEFT = 0x25
VK_RIGHT = 0x27
_USER32 = ctypes.windll.user32 if sys.platform == "win32" else None

# Retry policy
RETRY_IDENTIFY   = 2      # max student identify retries
RETRY_CAPTURE    = 2      # capture retry count
DELAY_AFTER_CLICK = 0.22  # generic click settle
DELAY_TAB_SWITCH  = 0.55  # tab switch settle
DELAY_NEXT        = 1.20  # next student settle
DELAY_ESC         = 0.35  # escape settle
STUDENT_CHANGE_INITIAL_WAIT = 0.10
STUDENT_CHANGE_POLL = 0.08
STUDENT_CHANGE_STABLE_POLLS = 2
STUDENT_CHANGE_STABLE_DELTA = 0.035


@dataclass(frozen=True)
class InventoryDragConfig:
    start_base_x: int
    start_base_y: int
    delta_px: int
    duration: float
    end_hold: float = 0.30
    retry_scale: float = 1.05
    base_width: int = 2560
    base_height: int = 1440

    @property
    def start_rx(self) -> float:
        return self.start_base_x / max(1, self.base_width)

    @property
    def start_ry(self) -> float:
        return self.start_base_y / max(1, self.base_height)

    def delta_ry(self, amount_px: int) -> float:
        return amount_px / max(1, self.base_height)


ITEM_INVENTORY_DRAG = InventoryDragConfig(
    start_base_x=1496,
    start_base_y=1021,
    delta_px=-656,
    duration=0.65,
    end_hold=0.40,
    retry_scale=1.0,
)

EQUIPMENT_INVENTORY_DRAG = InventoryDragConfig(
    start_base_x=1492,
    start_base_y=1223,
    delta_px=-874,
    duration=0.65,
    end_hold=0.40,
    retry_scale=1.0,
)




@dataclass
class ItemEntry:
    name:     Optional[str]
    quantity: Optional[str]
    item_id:  Optional[str] = None
    source:   str = "item"
    index:    int = 0
    scan_meta: dict = field(default_factory=dict)
    detail_crop: Optional[Image.Image] = field(default=None, repr=False, compare=False)
    detail_name_crop: Optional[Image.Image] = field(default=None, repr=False, compare=False)

    def key(self) -> str:
        stable = (self.item_id or self.name or "").strip().lower()
        return f"{self.source}:{stable}"






class FieldStatus:
    """Status marker for each tracked student field."""









    OK              = "ok"
    INFERRED        = "inferred"
    UNCERTAIN       = "uncertain"
    FAILED          = "failed"
    SKIPPED         = "skipped"
    REGION_MISSING  = "region_missing"


class FieldSource:
    """Source marker for each tracked student field."""








    TEMPLATE = "template"
    OCR      = "ocr"
    INFERRED = "inferred"
    CACHED   = "cached"
    DEFAULT  = "default"


@dataclass
class FieldMeta:
    """Metadata captured for each scanned field."""









    status: str            = FieldStatus.OK
    source: str            = FieldSource.TEMPLATE
    score:  Optional[float] = None
    note:   str            = ""

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "source": self.source,
            "score":  round(self.score, 3) if self.score is not None else None,
            "note":   self.note,
        }

    @classmethod
    def ok(cls, source: str, score: Optional[float] = None) -> "FieldMeta":
        return cls(status=FieldStatus.OK, source=source, score=score)

    @classmethod
    def inferred(cls, note: str = "") -> "FieldMeta":
        return cls(status=FieldStatus.INFERRED,
                   source=FieldSource.INFERRED, note=note)

    @classmethod
    def uncertain(cls, source: str, score: Optional[float] = None,
                  note: str = "") -> "FieldMeta":
        return cls(status=FieldStatus.UNCERTAIN,
                   source=source, score=score, note=note)

    @classmethod
    def failed(cls, source: str, note: str = "") -> "FieldMeta":
        return cls(status=FieldStatus.FAILED, source=source, note=note)

    @classmethod
    def skipped(cls, note: str = "") -> "FieldMeta":
        return cls(status=FieldStatus.SKIPPED,
                   source=FieldSource.DEFAULT, note=note)

    @classmethod
    def region_missing(cls, note: str = "") -> "FieldMeta":
        return cls(status=FieldStatus.REGION_MISSING,
                   source=FieldSource.DEFAULT, note=note)




class ScanState:
    """Lifecycle state for a student entry while scanning."""






    TEMP      = "temp"
    PARTIAL   = "partial"
    COMMITTED = "committed"
    SKIPPED   = "skipped"
    FAILED    = "failed"


_COMBAT_STAT_FIELDS: tuple[str, ...] = ("combat_hp", "combat_atk", "combat_def", "combat_heal")


def _normalize_form_combat_stats(raw: object) -> dict[str, dict[str, Optional[int]]]:
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except Exception:
            raw = {}
    if not isinstance(raw, dict):
        return {}
    normalized: dict[str, dict[str, Optional[int]]] = {}
    for form_key, values in raw.items():
        try:
            form_index = int(str(form_key).replace("form_", ""))
        except (TypeError, ValueError):
            continue
        if form_index < 1 or not isinstance(values, dict):
            continue
        stats: dict[str, Optional[int]] = {}
        for field_name in _COMBAT_STAT_FIELDS:
            value = values.get(field_name)
            if value is None or value == "":
                stats[field_name] = None
                continue
            try:
                stats[field_name] = int(value)
            except (TypeError, ValueError):
                stats[field_name] = None
        if any(value is not None for value in stats.values()):
            normalized[str(form_index)] = stats
    return normalized


def _entry_combat_stats(entry: "StudentEntry") -> dict[str, Optional[int]]:
    return {field_name: getattr(entry, field_name, None) for field_name in _COMBAT_STAT_FIELDS}


def _store_entry_form_combat_stats(entry: "StudentEntry", form_index: int) -> None:
    if form_index < 1:
        return
    stats = _entry_combat_stats(entry)
    if not any(value is not None for value in stats.values()):
        return
    entry.form_combat_stats[str(form_index)] = stats


@dataclass
class StudentEntry:
    student_id:   Optional[str] = None
    display_name: Optional[str] = None
    level:        Optional[int] = None
    student_star: Optional[int] = None
    # Weapon
    weapon_state: Optional[WeaponState] = None
    weapon_star:  Optional[int]         = None
    weapon_level: Optional[int]         = None
    # Skills
    ex_skill: Optional[int] = None
    skill1:   Optional[int] = None
    skill2:   Optional[int] = None
    skill3:   Optional[int] = None
    # Equipment tiers
    equip1:   Optional[str] = None
    equip2:   Optional[str] = None
    equip3:   Optional[str] = None
    equip4:   Optional[str] = None
    # Equipment levels
    equip1_level: Optional[int] = None
    equip2_level: Optional[int] = None
    equip3_level: Optional[int] = None

    # Basic-screen combat values (separate from additional-stat levels).
    combat_hp:   Optional[int] = None
    combat_atk:  Optional[int] = None
    combat_def:  Optional[int] = None
    combat_heal: Optional[int] = None
    form_combat_stats: dict[str, dict[str, Optional[int]]] = field(default_factory=dict)

    stat_hp:   Optional[int] = None
    stat_atk:  Optional[int] = None
    stat_heal: Optional[int] = None
    _basic_additional_badges: dict[str, Optional[bool]] = field(default_factory=dict, repr=False)
    _basic_additional_values: dict[str, Optional[int]] = field(default_factory=dict, repr=False)
    # Scan bookkeeping
    skipped:    bool = False
    scan_state: str  = ScanState.TEMP



    #   level / student_star / weapon_state / weapon_star / weapon_level
    #   ex_skill / skill1~3 / equip1~4 / equip1~3_level
    #   stat_hp / stat_atk / stat_heal
    _meta: dict = field(default_factory=dict)

    def label(self) -> str:
        return self.display_name or self.student_id or "?"

    def is_committed(self) -> bool:
        return self.scan_state == ScanState.COMMITTED

    def is_partial(self) -> bool:
        return self.scan_state == ScanState.PARTIAL

    def set_meta(self, field_name: str, meta: FieldMeta) -> None:
        """Store metadata for a specific field."""
        self._meta[field_name] = meta

    def get_meta(self, field_name: str) -> Optional[FieldMeta]:
        """Return field metadata or None if it does not exist."""
        return self._meta.get(field_name)

    def meta_summary(self) -> dict[str, dict]:
        """Return every field metadata entry as a serializable dict."""
        return {k: v.to_dict() for k, v in self._meta.items()}

    def uncertain_fields(self) -> list[str]:
        """List fields currently marked as uncertain."""
        return [k for k, v in self._meta.items()
                if v.status == FieldStatus.UNCERTAIN]

    def failed_fields(self) -> list[str]:
        """List fields currently marked as failed."""
        return [k for k, v in self._meta.items()
                if v.status == FieldStatus.FAILED]

    def missing_fields(self) -> list[str]:
        """List required fields that are still missing."""
        required = [
            "level", "student_star", "weapon_state",
            "ex_skill", "skill1",
            "equip1",
        ]
        if self.student_star is None or self.student_star >= SKILL2_UNLOCK_STAR:
            required.append("skill2")
        if self.student_star is None or self.student_star >= SKILL3_UNLOCK_STAR:
            required.append("skill3")
        if self.level is None or self.level >= EQUIP2_UNLOCK_LEVEL:
            required.append("equip2")
        if self.level is None or self.level >= EQUIP3_UNLOCK_LEVEL:
            required.append("equip3")
        if self.weapon_state == WeaponState.WEAPON_EQUIPPED:
            required.extend(("weapon_star", "weapon_level"))
        for slot in (1, 2, 3):
            equip_value = getattr(self, f"equip{slot}")
            if equip_value in (
                EquipSlotFlag.EMPTY.value,
                EquipSlotFlag.LEVEL_LOCKED.value,
                EquipSlotFlag.LOVE_LOCKED.value,
                EquipSlotFlag.NULL.value,
            ):
                continue
            if equip_value not in (None, "unknown"):
                required.append(f"equip{slot}_level")
        return [f for f in required if getattr(self, f) is None]

    def confidence(self) -> float:
        """Return the fraction of required fields that are filled."""
        required_all = [
            "level", "student_star", "weapon_state",
            "ex_skill", "skill1",
            "equip1",
        ]
        if self.student_star is None or self.student_star >= SKILL2_UNLOCK_STAR:
            required_all.append("skill2")
        if self.student_star is None or self.student_star >= SKILL3_UNLOCK_STAR:
            required_all.append("skill3")
        if self.level is None or self.level >= EQUIP2_UNLOCK_LEVEL:
            required_all.append("equip2")
        if self.level is None or self.level >= EQUIP3_UNLOCK_LEVEL:
            required_all.append("equip3")
        if self.weapon_state == WeaponState.WEAPON_EQUIPPED:
            required_all.extend(("weapon_star", "weapon_level"))
        for slot in (1, 2, 3):
            equip_value = getattr(self, f"equip{slot}")
            if equip_value in (
                EquipSlotFlag.EMPTY.value,
                EquipSlotFlag.LEVEL_LOCKED.value,
                EquipSlotFlag.LOVE_LOCKED.value,
                EquipSlotFlag.NULL.value,
            ):
                continue
            if equip_value not in (None, "unknown"):
                required_all.append(f"equip{slot}_level")
        filled = sum(1 for f in required_all if getattr(self, f) is not None)
        return round(filled / len(required_all), 3)

    def to_dict(self) -> dict:
        """Serialize the student entry and tracked metadata to a dict."""

























        ws = self.weapon_state
        d: dict = {
            "student_id":   self.student_id,
            "display_name": self.display_name,
            "level":        self.level,
            "student_star": self.student_star,
            "weapon_state": ws.value if ws else None,
            "weapon_star":  self.weapon_star,
            "weapon_level": self.weapon_level,
            "ex_skill":     self.ex_skill,
            "skill1":       self.skill1,
            "skill2":       self.skill2,
            "skill3":       self.skill3,
            "equip1":       self.equip1,
            "equip2":       self.equip2,
            "equip3":       self.equip3,
            "equip4":       self.equip4,
            "equip1_level": self.equip1_level,
            "equip2_level": self.equip2_level,
            "equip3_level": self.equip3_level,
            "combat_hp":    self.combat_hp,
            "combat_atk":   self.combat_atk,
            "combat_def":   self.combat_def,
            "combat_heal":  self.combat_heal,
            "form_combat_stats": _normalize_form_combat_stats(self.form_combat_stats),
            "stat_hp":      self.stat_hp,
            "stat_atk":     self.stat_atk,
            "stat_heal":    self.stat_heal,
            "skipped":      self.skipped,
            "scan_state":   self.scan_state,
            "confidence":   self.confidence(),
        }

        # Expand tracked field metadata for downstream consumers.
        _TRACKED = [
            "level", "student_star",
            "weapon_state", "weapon_star", "weapon_level",
            "ex_skill", "skill1", "skill2", "skill3",
            "equip1", "equip2", "equip3", "equip4",
            "equip1_level", "equip2_level", "equip3_level",
            "combat_hp", "combat_atk", "combat_def", "combat_heal",
            "stat_hp", "stat_atk", "stat_heal",
        ]
        for fname in _TRACKED:
            meta = self._meta.get(fname)
            if meta:
                d[f"{fname}_status"] = meta.status
                d[f"{fname}_source"] = meta.source
                if meta.score is not None:
                    d[f"{fname}_score"] = round(meta.score, 3)
                if meta.note:
                    d[f"{fname}_note"] = meta.note
            else:

                val = getattr(self, fname, None)
                d[f"{fname}_status"] = (
                    FieldStatus.OK if val is not None else FieldStatus.FAILED
                )

        # Keep the raw metadata backup for later restore/debugging.
        if self._meta:
            d["_field_meta"] = self.meta_summary()

        return d

    @classmethod
    def from_dict(cls, d: dict) -> "StudentEntry":
        """Restore a StudentEntry from serialized data."""



        ws_raw = d.get("weapon_state")
        try:
            ws = WeaponState(ws_raw) if ws_raw else None
        except ValueError:
            ws = None

        entry = cls(
            student_id=d.get("student_id"),
            display_name=d.get("display_name"),
            level=d.get("level"),
            student_star=d.get("student_star"),
            weapon_state=ws,
            weapon_star=d.get("weapon_star"),
            weapon_level=d.get("weapon_level"),
            ex_skill=d.get("ex_skill"),
            skill1=d.get("skill1"),
            skill2=d.get("skill2"),
            skill3=d.get("skill3"),
            equip1=d.get("equip1"),
            equip2=d.get("equip2"),
            equip3=d.get("equip3"),
            equip4=d.get("equip4"),
            equip1_level=d.get("equip1_level"),
            equip2_level=d.get("equip2_level"),
            equip3_level=d.get("equip3_level"),
            combat_hp=d.get("combat_hp"),
            combat_atk=d.get("combat_atk"),
            combat_def=d.get("combat_def"),
            combat_heal=d.get("combat_heal"),
            form_combat_stats=_normalize_form_combat_stats(d.get("form_combat_stats")),
            stat_hp=d.get("stat_hp"),
            stat_atk=d.get("stat_atk"),
            stat_heal=d.get("stat_heal"),
            skipped=d.get("skipped", False),
            scan_state=d.get("scan_state", ScanState.COMMITTED),
        )

        # Restore per-field metadata when present.
        raw_meta = d.get("_field_meta", {})
        for fname, md in raw_meta.items():
            entry.set_meta(fname, FieldMeta(
                status=md.get("status", FieldStatus.OK),
                source=md.get("source", FieldSource.TEMPLATE),
                score=md.get("score"),
                note=md.get("note", ""),
            ))

        return entry


@dataclass
class EntryCommitResult:
    """Result of validating one student entry before commit."""










    entry:      StudentEntry
    committed:  bool
    missing:    list[str]
    confidence: float
    reason:     str = ""


@dataclass
class ScanResult:
    items:     list[ItemEntry]    = field(default_factory=list)
    equipment: list[ItemEntry]    = field(default_factory=list)
    students:  list[StudentEntry] = field(default_factory=list)
    resources: dict               = field(default_factory=dict)
    errors:    list[str]          = field(default_factory=list)


@dataclass
class InventorySlotSnapshot:
    slot_index: int
    icon_hash: str


@dataclass
class InventoryPageSnapshot:
    page_index: int
    grid_hash: str
    last_row_hashes: list[str]
    slots: list[InventorySlotSnapshot]



@dataclass
class InventoryMotionEstimate:
    expected_step_px: int
    actual_move_px: int
    y_offset_px: int
    score: float
    search_min_px: int
    search_max_px: int
    method: str = "row_feature_shift"

@dataclass
class InventoryVerification:
    name: Optional[str]
    count: str
    item_id: Optional[str] = None
    match_score: float = 0.0
    detail_crop: Optional[Image.Image] = None
    detail_name_crop: Optional[Image.Image] = None




# Utility helpers


def _space_key_down() -> bool:
    if _USER32 is None:
        return False
    try:
        return bool(_USER32.GetAsyncKeyState(VK_SPACE) & 0x8000)
    except Exception:
        return False


def _img_hash(img: Image.Image) -> str:
    small = img.convert("L").resize((16, 16))
    return hashlib.md5(small.tobytes()).hexdigest()


def _images_similar(a: Image.Image, b: Image.Image, thresh: float = SAME_THRESH) -> bool:
    try:
        a2 = np.array(a.convert("L").resize((64, 64))).flatten().astype(float)
        b2 = np.array(b.convert("L").resize((64, 64))).flatten().astype(float)
        return float(np.corrcoef(a2, b2)[0, 1]) >= thresh
    except Exception:
        return False


def _grid_region(slots: list[dict]) -> dict:
    return {
        "x1": min(s["x1"] for s in slots),
        "y1": min(s["y1"] for s in slots),
        "x2": max(s["x2"] for s in slots),
        "y2": max(s["y2"] for s in slots),
    }


def _expand_region(
    region: dict,
    *,
    left: float = 0.0,
    top: float = 0.0,
    right: float = 0.0,
    bottom: float = 0.0,
) -> dict:
    return {
        "x1": max(0.0, region["x1"] - left),
        "y1": max(0.0, region["y1"] - top),
        "x2": min(1.0, region["x2"] + right),
        "y2": min(1.0, region["y2"] + bottom),
    }


def _slot_icon_region(slot: dict) -> dict:
    width = slot["x2"] - slot["x1"]
    height = slot["y2"] - slot["y1"]
    return {
        "x1": slot["x1"] + width * 0.10,
        "y1": slot["y1"] + height * 0.07,
        "x2": slot["x2"] - width * 0.10,
        "y2": slot["y2"] - height * 0.24,
    }


def _count_row_overlap(
    before_hashes: list[str],
    after_hashes: list[str],
    grid_cols: int,
) -> int:
    if grid_cols <= 0:
        return 0
    before_rows = [
        tuple(before_hashes[i:i + grid_cols])
        for i in range(0, len(before_hashes), grid_cols)
        if len(before_hashes[i:i + grid_cols]) == grid_cols
    ]
    after_rows = [
        tuple(after_hashes[i:i + grid_cols])
        for i in range(0, len(after_hashes), grid_cols)
        if len(after_hashes[i:i + grid_cols]) == grid_cols
    ]
    max_rows = min(len(before_rows), len(after_rows))
    for overlap in range(max_rows, 0, -1):
        if before_rows[-overlap:] == after_rows[:overlap]:
            return overlap
    return 0


def _new_inventory_slot_indices(
    total_slots: int,
    grid_cols: int,
    grid_rows: int,
    overlap_rows: int,
) -> set[int] | None:
    if total_slots <= 0 or grid_cols <= 0 or grid_rows <= 0:
        return None
    new_rows = grid_rows - max(0, min(grid_rows, overlap_rows))
    if new_rows <= 0:
        return set()
    if new_rows >= grid_rows:
        return None
    start_row = max(0, grid_rows - new_rows)
    start = min(total_slots, start_row * grid_cols)
    return set(range(start, total_slots))



def _shift_region_y(region: dict, y_offset_px: int, image_height: int) -> dict:
    if y_offset_px == 0 or image_height <= 0:
        return dict(region)
    dy = y_offset_px / max(1, image_height)
    shifted = dict(region)
    region_h = float(region["y2"]) - float(region["y1"])
    y1 = float(region["y1"]) + dy
    y1 = max(0.0, min(1.0 - region_h, y1))
    y2 = y1 + region_h
    shifted["y1"] = y1
    shifted["y2"] = y2
    if "cy" in shifted:
        shifted["cy"] = max(0.0, min(1.0, float(region["cy"]) + dy))
    return shifted


def _shift_slots_y(slots: list[dict], y_offset_px: int, image_size: tuple[int, int]) -> list[dict]:
    return [_shift_region_y(slot, y_offset_px, image_size[1]) for slot in slots]




def _inventory_debug_region_box(region: dict, size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = size
    return (
        int(round(float(region["x1"]) * width)),
        int(round(float(region["y1"]) * height)),
        int(round(float(region["x2"]) * width)),
        int(round(float(region["y2"]) * height)),
    )


def _inventory_debug_label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill: str) -> None:
    x, y = xy
    draw.rectangle((x, y, x + max(30, len(text) * 7), y + 14), fill=(0, 0, 0, 170))
    draw.text((x + 2, y + 1), text, fill=fill)


def _draw_inventory_scroll_debug_overlay(
    image: Image.Image,
    slots: list[dict],
    *,
    title: str,
    output_path: Path,
    grid_cols: int,
    overlap_rows: int | None = None,
    scan_indices: set[int] | None = None,
    carried_rows: int = 0,
) -> None:
    canvas = image.convert("RGBA")
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    size = canvas.size
    draw.rectangle(_inventory_debug_region_box(_grid_region(slots), size), outline=(255, 255, 255, 220), width=3)

    for idx, slot in enumerate(slots):
        slot_box = _inventory_debug_region_box(slot, size)
        icon_box = _inventory_debug_region_box(_slot_icon_region(slot), size)
        is_scan_target = scan_indices is not None and idx in scan_indices
        color = (255, 76, 210, 235) if is_scan_target else (80, 255, 120, 210)
        draw.rectangle(slot_box, outline=color, width=4 if is_scan_target else 2)
        draw.rectangle(icon_box, outline=(60, 220, 255, 180), width=1)
        label = str(idx + 1)
        if carried_rows > 0 and idx < carried_rows * max(1, grid_cols):
            label = f"{idx + 1} old"
        _inventory_debug_label(draw, (slot_box[0] + 3, slot_box[1] + 3), label, "white")

    lines = [title]
    if overlap_rows is not None:
        target_count = len(scan_indices) if scan_indices is not None else len(slots)
        lines.append(f"overlap_rows={overlap_rows} scan_slots={target_count}/{len(slots)}")
    lines.append("green=slot, cyan=icon hash, magenta=next scan window")
    header_h = 22 * len(lines) + 8
    draw.rectangle((8, 8, min(size[0] - 8, 900), 8 + header_h), fill=(0, 0, 0, 185))
    for i, line in enumerate(lines):
        draw.text((16, 14 + i * 22), line, fill=(255, 255, 255, 255))
    Image.alpha_composite(canvas, overlay).convert("RGB").save(output_path, quality=95)


def _safe_debug_token(value: object) -> str:
    text = str(value or "").strip()
    cleaned = "".join(ch if ch.isalnum() or ch in "_.-" else "_" for ch in text)
    return cleaned.strip("_") or "none"


def _inventory_scroll_debug_dir(source: str, profile_id: str | None) -> Path | None:
    if source != "item" or os.environ.get("BA_INVENTORY_SCROLL_DEBUG", "1") == "0":
        return None
    stamp = time.strftime("%Y%m%d_%H%M%S")
    suffix = f"{_safe_debug_token(source)}_{_safe_debug_token(profile_id or 'auto')}"
    path = BASE_DIR / "debug" / "inventory_scroll_scan" / f"{stamp}_{suffix}"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _save_inventory_scroll_debug(
    debug_dir: Path | None,
    *,
    before_img: Image.Image | None,
    after_img: Image.Image | None,
    slots: list[dict],
    grid_cols: int,
    grid_rows: int,
    scroll_index: int,
    attempt_index: int,
    amount: int,
    scroll_ok: bool,
    moved: bool,
    image_changed: bool,
    hash_changed: bool,
    slot_sequence_changed: bool,
    row_step_px: int,
    expected_move_px: int,
    search_margin_px: int,
    motion: InventoryMotionEstimate | None,
    overlap_rows: int,
    moved_rows: int | None,
    y_offset_px: int,
    before_grid_hash: str,
    after_grid_hash: str,
    before_hashes: list[str],
    after_hashes: list[str],
    cursor_moved: bool = False,
    before_y_offset_px: int = 0,
    before_slots: list[dict] | None = None,
    tail_scroll: bool = False
) -> None:
    if debug_dir is None or before_img is None or after_img is None:
        return
    try:
        case_dir = debug_dir / f"scroll_{scroll_index + 1:02d}_try_{attempt_index:02d}"
        case_dir.mkdir(parents=True, exist_ok=True)
        before_path = case_dir / "before_capture.png"
        after_path = case_dir / "after_capture.png"
        before_overlay = case_dir / "before_overlay.png"
        after_overlay = case_dir / "after_overlay.png"
        before_img.convert("RGB").save(before_path, quality=95)
        after_img.convert("RGB").save(after_path, quality=95)

        scan_indices = _new_inventory_slot_indices(len(slots), grid_cols, grid_rows, overlap_rows)
        if scan_indices is None:
            scan_indices = set(range(len(slots)))
        debug_before_slots = before_slots if before_slots is not None else slots
        adjusted_slots = _shift_slots_y(slots, y_offset_px, after_img.size) if y_offset_px else slots
        title = (
            f"scroll={scroll_index + 1} try={attempt_index} moved={moved} "
            f"amount={amount}px before_y={before_y_offset_px:+d}px y_offset={y_offset_px:+d}px"
        )
        _draw_inventory_scroll_debug_overlay(
            before_img,
            debug_before_slots,
            title=f"before {title}",
            output_path=before_overlay,
            grid_cols=grid_cols,
        )
        _draw_inventory_scroll_debug_overlay(
            after_img,
            adjusted_slots,
            title=f"after {title}",
            output_path=after_overlay,
            grid_cols=grid_cols,
            overlap_rows=overlap_rows,
            scan_indices=scan_indices,
            carried_rows=overlap_rows,
        )
        motion_summary = None
        if motion is not None:
            motion_summary = {
                "method": motion.method,
                "expected_step_px": motion.expected_step_px,
                "actual_move_px": motion.actual_move_px,
                "y_offset_px": motion.y_offset_px,
                "score": round(motion.score, 6),
                "search_min_px": motion.search_min_px,
                "search_max_px": motion.search_max_px,
            }
        summary = {
            "scroll_index": scroll_index,
            "attempt_index": attempt_index,
            "amount_px": amount,
            "scroll_ok": scroll_ok,
            "moved": moved,
            "image_changed": image_changed,
            "hash_changed": hash_changed,
            "slot_sequence_changed": slot_sequence_changed,
            "cursor_moved_away_before_capture": cursor_moved,
            "ignored_slot_side_bands_for_motion": True,
            "grid_cols": grid_cols,
            "grid_rows": grid_rows,
            "slot_count": len(slots),
            "row_step_px": row_step_px,
            "expected_move_px": expected_move_px,
            "search_margin_px": search_margin_px,
            "movement_estimate": motion_summary,
            "moved_rows": moved_rows,
            "overlap_rows": overlap_rows,
            "before_y_offset_px": before_y_offset_px,
            "motion_y_offset_delta_px": y_offset_px - before_y_offset_px,
            "after_y_offset_px": y_offset_px,
            "tail_scroll": bool(tail_scroll),
            "new_scan_slot_indices_0_based": sorted(scan_indices),
            "new_scan_slot_numbers": [idx + 1 for idx in sorted(scan_indices)],
            "before_grid_hash": before_grid_hash,
            "after_grid_hash": after_grid_hash,
            "before_slot_hashes": before_hashes,
            "after_slot_hashes": after_hashes,
            "before_capture": str(before_path),
            "after_capture": str(after_path),
            "before_overlay": str(before_overlay),
            "after_overlay": str(after_overlay),
        }
        (case_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception:
        _log.debug("failed to save inventory scroll debug capture", exc_info=True)

def _slot_row_step_px(slots: list[dict], image_size: tuple[int, int], grid_cols: int) -> int:
    if grid_cols <= 0 or len(slots) <= grid_cols:
        return 0
    height = max(1, image_size[1])
    steps: list[float] = []
    for idx in range(grid_cols, len(slots), grid_cols):
        prev = slots[idx - grid_cols]
        cur = slots[idx]
        steps.append((float(cur["cy"]) - float(prev["cy"])) * height)
    if not steps:
        return 0
    return int(round(float(np.median(np.array(steps, dtype=np.float32)))))



def _move_cursor_away_from_inventory_grid(rect: tuple[int, int, int, int]) -> bool:
    hwnd = find_target_hwnd()
    if not hwnd:
        return False
    # Keep the OS cursor out of the item grid before capture so hover/focus
    # borders do not become part of the scroll-difference signal.
    cx, cy = ratio_to_client(rect, 0.25, 0.55)
    screen = client_to_screen(hwnd, cx, cy)
    if screen is None:
        return False
    return move_cursor_to_screen(screen[0], screen[1])

def _inventory_motion_region(grid_r: dict) -> dict:
    return _expand_region(grid_r, left=0.03, top=0.04, right=0.02, bottom=0.03)


def _inventory_overlap_rows_from_motion(
    motion: InventoryMotionEstimate | None,
    row_step_px: int,
    grid_rows: int,
) -> tuple[int, int, int, bool] | None:
    if motion is None or row_step_px <= 0 or grid_rows <= 0:
        return None
    target_rows = max(1, grid_rows - 1)
    actual_rows = motion.actual_move_px / max(1, row_step_px)
    tail_scroll = motion.actual_move_px < row_step_px * max(1.0, target_rows - 0.5)
    moved_rows = int(round(actual_rows))
    moved_rows = max(0, min(grid_rows, moved_rows))
    if tail_scroll and motion.actual_move_px >= row_step_px * 0.35:
        moved_rows = max(1, moved_rows)
    y_offset_px = int(round((moved_rows * row_step_px) - motion.actual_move_px))
    if tail_scroll:
        # Near the list end, the UI can clamp the scroll to a partial row.  The
        # y-offset carries that partial alignment, so scanning an extra row would
        # reread the previous bottom row and shift the true tail row downward.
        overlap_rows = grid_rows - moved_rows
        max_tail_offset = max(1, int(round(row_step_px * 0.45)))
        y_offset_px = max(-max_tail_offset, min(max_tail_offset, y_offset_px))
    else:
        overlap_rows = grid_rows - moved_rows
        # Normal drags settle on row boundaries. Large residual offsets here are
        # usually a row-feature false peak; carrying them forward shifts every
        # later slot ROI and can poison row-step calibration.
        max_normal_offset = max(4, int(round(row_step_px * 0.04)))
        if abs(y_offset_px) > max_normal_offset:
            y_offset_px = 0
    return max(0, min(grid_rows, overlap_rows)), moved_rows, y_offset_px, tail_scroll

def _adapt_inventory_drag_amount(
    amount_px: int,
    motion: InventoryMotionEstimate | None,
    row_step_px: int,
    grid_rows: int,
    drag_config: InventoryDragConfig,
) -> tuple[int, int]:
    if os.environ.get("BA_INVENTORY_DRAG_ADAPT", "0") != "1":
        return amount_px, 0
    if motion is None or row_step_px <= 0 or grid_rows <= 1 or motion.actual_move_px <= 0:
        return amount_px, 0
    if motion.score < 0.70:
        return amount_px, row_step_px * max(1, grid_rows - 1)

    target_rows = max(1, grid_rows - 1)
    target_move_px = row_step_px * target_rows
    if target_move_px <= 0:
        return amount_px, 0

    error_ratio = (target_move_px - motion.actual_move_px) / max(1, target_move_px)
    if abs(error_ratio) < 0.06:
        return amount_px, target_move_px

    current_abs = max(1.0, float(abs(amount_px)))
    desired_abs = current_abs * (target_move_px / max(1.0, float(motion.actual_move_px)))
    gain = 0.35 if desired_abs > current_abs else 0.25
    next_abs = current_abs + (desired_abs - current_abs) * gain

    # Keep one bad drag from over-correcting. The row-motion matcher will carry
    # the remaining offset, so the drag controller can be deliberately gentle.
    if next_abs > current_abs:
        next_abs = min(next_abs, current_abs * 1.15)
    else:
        next_abs = max(next_abs, current_abs * 0.85)

    base_abs = max(1, abs(drag_config.delta_px))
    min_abs = max(1, int(round(base_abs * 0.65)))
    start_ry = max(0.02, min(0.98, drag_config.start_ry))
    if amount_px < 0:
        max_by_edge = int(round(max(0.01, start_ry - 0.04) * drag_config.base_height))
    else:
        max_by_edge = int(round(max(0.01, 0.96 - start_ry) * drag_config.base_height))
    max_abs = max(min_abs, min(int(round(base_abs * 1.45)), max_by_edge))
    next_abs = max(min_abs, min(max_abs, next_abs))
    next_amount = int(round(next_abs)) * (-1 if amount_px < 0 else 1)
    return next_amount, target_move_px

def _inventory_motion_box(region: dict, image_size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = image_size
    return (
        int(round(float(region["x1"]) * width)),
        int(round(float(region["y1"]) * height)),
        int(round(float(region["x2"]) * width)),
        int(round(float(region["y2"]) * height)),
    )


def _suppress_slot_side_bands(
    edge: np.ndarray,
    *,
    motion_region: dict,
    image_size: tuple[int, int],
    slots: list[dict] | None,
    side_fraction: float = 0.18,
) -> np.ndarray:
    if not slots or edge.size == 0:
        return edge
    region_left, region_top, region_right, region_bottom = _inventory_motion_box(motion_region, image_size)
    if region_right <= region_left or region_bottom <= region_top:
        return edge
    masked = edge.copy()
    height, width = masked.shape
    for slot in slots:
        slot_left, slot_top, slot_right, slot_bottom = _inventory_motion_box(slot, image_size)
        local_y1 = max(0, min(height, slot_top - region_top))
        local_y2 = max(0, min(height, slot_bottom - region_top))
        if local_y2 <= local_y1:
            continue
        local_x1 = max(0, min(width, slot_left - region_left))
        local_x2 = max(0, min(width, slot_right - region_left))
        if local_x2 <= local_x1:
            continue
        band = max(3, int(round((local_x2 - local_x1) * side_fraction)))
        band = min(band, max(1, (local_x2 - local_x1) // 2))
        masked[local_y1:local_y2, local_x1:local_x1 + band] = 0.0
        masked[local_y1:local_y2, local_x2 - band:local_x2] = 0.0
    return masked


def _inventory_motion_array(
    image: Image.Image,
    region: dict,
    *,
    slots: list[dict] | None = None,
) -> np.ndarray | None:
    crop = crop_region(image, region).convert("L")
    arr = np.asarray(crop, dtype=np.float32)
    if arr.size == 0 or arr.shape[0] < 8 or arr.shape[1] < 8:
        return None
    gx = np.abs(np.diff(arr, axis=1, prepend=arr[:, :1]))
    gy = np.abs(np.diff(arr, axis=0, prepend=arr[:1, :]))
    edge = _suppress_slot_side_bands(
        gx + gy,
        motion_region=region,
        image_size=image.size,
        slots=slots,
    )

    # Collapse each scanline into a compact horizontal descriptor. Matching
    # row vectors across vertical shifts is less sensitive to slot text,
    # focus borders, and small animation noise than comparing the whole grid
    # bitmap directly.
    bin_count = max(8, min(64, arr.shape[1] // 12))
    chunks = np.array_split(edge, bin_count, axis=1)
    features = np.stack([chunk.mean(axis=1) for chunk in chunks], axis=1)
    if features.shape[0] >= 3:
        features = (
            np.roll(features, 1, axis=0)
            + features
            + np.roll(features, -1, axis=0)
        ) / 3.0
        features[0] = (features[0] + features[1]) / 2.0
        features[-1] = (features[-2] + features[-1]) / 2.0
    features -= features.mean(axis=1, keepdims=True)
    features -= float(features.mean())
    std = float(features.std())
    if std > 1e-6:
        features /= std
    return features.astype(np.float32, copy=False)


def _estimate_inventory_scroll_motion(
    before_img: Image.Image,
    after_img: Image.Image,
    grid_r: dict,
    expected_step_px: int,
    *,
    search_margin_px: int = 50,
    slots: list[dict] | None = None,
) -> InventoryMotionEstimate | None:
    if expected_step_px <= 0:
        return None
    region = _inventory_motion_region(grid_r)
    before = _inventory_motion_array(before_img, region, slots=slots)
    after = _inventory_motion_array(after_img, region, slots=slots)
    if before is None or after is None:
        return None
    height = min(before.shape[0], after.shape[0])
    width = min(before.shape[1], after.shape[1])
    if height <= expected_step_px + 16 or width <= 8:
        return None
    before = before[:height, :width]
    after = after[:height, :width]
    search_min = max(1, expected_step_px - max(1, search_margin_px))
    search_max = min(height - 8, expected_step_px + max(1, search_margin_px))
    if search_min > search_max:
        return None

    best_move = search_min
    best_score = -1.0
    for move in range(search_min, search_max + 1):
        before_part = before[move:height, :]
        after_part = after[:height - move, :]
        denom = float(np.sqrt(np.sum(before_part * before_part) * np.sum(after_part * after_part)))
        if denom <= 1e-6:
            continue
        score = float(np.sum(before_part * after_part) / denom)
        if score > best_score:
            best_score = score
            best_move = move

    if best_score < -0.5:
        return None
    return InventoryMotionEstimate(
        expected_step_px=expected_step_px,
        actual_move_px=best_move,
        y_offset_px=expected_step_px - best_move,
        score=best_score,
        search_min_px=search_min,
        search_max_px=search_max,
        method="row_feature_shift_slot_sides_ignored",
    )

_INVENTORY_TEMPLATE_DIRS: dict[str, tuple[str, ...]] = {
    "item": ("skill_book", "ooparts", "skill_db", "students_elephs"),
    "equipment": ("equipment",),
}
_INVENTORY_TEMPLATE_CATALOG: dict[str, list[tuple[str, str]]] = {}
_INVENTORY_DETAIL_TEMPLATE_CATALOG: dict[str, list[tuple[str, str]]] = {}
_INVENTORY_DETAIL_TEMPLATE_REGION: dict[str, dict] = {}
_INVENTORY_DETAIL_NAME_TEMPLATE_CATALOG: dict[str, list[tuple[str, str]]] = {}
_INVENTORY_DETAIL_NAME_TEMPLATE_REGION: dict[str, dict] = {}
_REGION_CAPTURE_PAYLOADS: dict[str, dict] = {}
_REGION_CAPTURE_REGIONS: dict[str, dict] = {}
_REGION_CAPTURE_REFERENCE_PATHS: dict[str, str | None] = {}


def _inventory_grid_template_config(section: dict, profile_id: str | None) -> dict | None:
    base_config = section.get("grid_template")
    profile_configs = section.get("profile_grid_templates")
    if not profile_id or not isinstance(profile_configs, dict):
        return base_config
    profile_config = profile_configs.get(profile_id)
    if not isinstance(profile_config, dict):
        return base_config
    if not isinstance(base_config, dict):
        return profile_config
    merged = dict(base_config)
    for key, value in profile_config.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            nested = dict(merged[key])
            nested.update(value)
            merged[key] = nested
        else:
            merged[key] = value
    return merged


def _inventory_template_catalog(source: str) -> list[tuple[str, str]]:
    cached = _INVENTORY_TEMPLATE_CATALOG.get(source)
    if cached is not None:
        return cached

    dirs = _INVENTORY_TEMPLATE_DIRS.get(source, ())
    catalog_by_item_id: dict[str, str] = {}
    for dir_name in dirs:
        base = TEMPLATE_DIR / dir_name if dir_name == "students_elephs" else TEMPLATE_DIR / "icons" / dir_name
        if not base.exists():
            continue
        for png in sorted(base.rglob("*.png")):
            item_id = png.stem
            if source == "equipment":
                item_id = canonical_equipment_item_id(item_id) or png.stem
            catalog_by_item_id[item_id] = str(png)

    catalog = list(catalog_by_item_id.items())
    _INVENTORY_TEMPLATE_CATALOG[source] = catalog
    return catalog


def _inventory_detail_template_catalog(profile_id: str | None) -> list[tuple[str, str]]:
    if not profile_id:
        return []
    cached = _INVENTORY_DETAIL_TEMPLATE_CATALOG.get(profile_id)
    if cached is not None:
        return cached

    base = TEMPLATE_DIR / "inventory_detail" / profile_id
    catalog: list[tuple[str, str]] = []
    if base.exists():
        for png in sorted(base.glob("*.png")):
            catalog.append((png.stem, str(png)))

    _INVENTORY_DETAIL_TEMPLATE_CATALOG[profile_id] = catalog
    return catalog


def _inventory_detail_template_region(profile_id: str | None) -> dict | None:
    if not profile_id:
        return None
    cached = _INVENTORY_DETAIL_TEMPLATE_REGION.get(profile_id)
    if cached is not None:
        return cached

    base = TEMPLATE_DIR / "inventory_detail" / profile_id
    if not base.exists():
        return None

    for json_path in sorted(base.glob("*.json")):
        try:
            payload = json.loads(json_path.read_text(encoding="utf-8-sig"))
        except Exception:
            continue
        points = payload.get("points_ratio") or []
        if len(points) < 4:
            continue
        xs = [float(point.get("x", 0.0)) for point in points]
        ys = [float(point.get("y", 0.0)) for point in points]
        region = {
            "x1": max(0.0, min(xs)),
            "y1": max(0.0, min(ys)),
            "x2": min(1.0, max(xs)),
            "y2": min(1.0, max(ys)),
        }
        _INVENTORY_DETAIL_TEMPLATE_REGION[profile_id] = region
        return region

    return None


def _inventory_detail_name_template_catalog(profile_id: str | None) -> list[tuple[str, str]]:
    if not profile_id:
        return []
    cached = _INVENTORY_DETAIL_NAME_TEMPLATE_CATALOG.get(profile_id)
    if cached is not None:
        return cached

    base = TEMPLATE_DIR / "inventory_detail_names" / profile_id
    catalog: list[tuple[str, str]] = []
    if base.exists():
        for png in sorted(base.glob("*.png")):
            catalog.append((png.stem, str(png)))

    _INVENTORY_DETAIL_NAME_TEMPLATE_CATALOG[profile_id] = catalog
    return catalog


def _region_from_payload(payload: dict) -> dict | None:
    points = payload.get("points_ratio") or []
    if len(points) < 4:
        return None
    try:
        xs = [float(point.get("x", 0.0)) for point in points]
        ys = [float(point.get("y", 0.0)) for point in points]
    except Exception:
        return None
    return {
        "x1": max(0.0, min(xs)),
        "y1": max(0.0, min(ys)),
        "x2": min(1.0, max(xs)),
        "y2": min(1.0, max(ys)),
    }


def _inventory_detail_name_template_region(source: str) -> dict | None:
    key = "equipment" if source == "equipment" else "item"
    cached = _INVENTORY_DETAIL_NAME_TEMPLATE_REGION.get(key)
    if cached is not None:
        return cached

    stems = (
        ("equip_name_image_region", "equip_name_image_regino")
        if key == "equipment"
        else ("item_name_image_region", "item_name_image_regino")
    )
    search_dirs = (
        TEMPLATE_DIR / "inventory_detail_names",
        BASE_DIR / "debug" / "region_captures",
    )
    for base in search_dirs:
        for stem in stems:
            json_path = base / f"{stem}.region.json"
            if not json_path.exists():
                continue
            try:
                payload = json.loads(json_path.read_text(encoding="utf-8-sig"))
            except Exception:
                continue
            region = _region_from_payload(payload)
            if region is None:
                continue
            _INVENTORY_DETAIL_NAME_TEMPLATE_REGION[key] = region
            return region
    return None


def _load_region_capture_payload(name: str, *, reference: bool = False) -> dict | None:
    suffix = "_001.json" if reference else ".region.json"
    cache_key = f"{name}{suffix}"
    cached = _REGION_CAPTURE_PAYLOADS.get(cache_key)
    if cached is not None:
        return cached

    path = REGION_CAPTURE_DIR / f"{name}{suffix}"
    if not path.exists():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return None
    if not isinstance(payload, dict):
        return None
    _REGION_CAPTURE_PAYLOADS[cache_key] = payload
    return payload


def _region_from_payload(payload: dict) -> dict | None:
    points = payload.get("points_ratio") or []
    if len(points) < 4:
        return None
    try:
        xs = [float(point.get("x", 0.0)) for point in points]
        ys = [float(point.get("y", 0.0)) for point in points]
    except Exception:
        return None
    return {
        "x1": max(0.0, min(xs)),
        "y1": max(0.0, min(ys)),
        "x2": min(1.0, max(xs)),
        "y2": min(1.0, max(ys)),
    }


def _region_capture_region(name: str) -> dict | None:
    cached = _REGION_CAPTURE_REGIONS.get(name)
    if cached is not None:
        return cached
    payload = _load_region_capture_payload(name)
    if payload is None:
        return None
    region = _region_from_payload(payload)
    if region is None:
        return None
    _REGION_CAPTURE_REGIONS[name] = region
    return region


def _region_capture_reference_path(name: str) -> str | None:
    if name in _REGION_CAPTURE_REFERENCE_PATHS:
        return _REGION_CAPTURE_REFERENCE_PATHS[name]
    payload = _load_region_capture_payload(name, reference=True)
    if payload is None:
        return None
    image_path = str(payload.get("image_path") or "").strip()
    resolved = image_path if image_path and Path(image_path).exists() else None
    _REGION_CAPTURE_REFERENCE_PATHS[name] = resolved
    return resolved


def _dict_to_student_entry(d: dict) -> StudentEntry:
    ws_raw = d.get("weapon_state")
    try:
        ws = WeaponState(ws_raw) if ws_raw else None
    except ValueError:
        ws = None
    return StudentEntry(
        student_id=d.get("student_id"),
        display_name=d.get("display_name"),
        level=d.get("level"),
        student_star=d.get("student_star"),
        weapon_state=ws,
        weapon_star=d.get("weapon_star"),
        weapon_level=d.get("weapon_level"),
        ex_skill=d.get("ex_skill"),
        skill1=d.get("skill1"),
        skill2=d.get("skill2"),
        skill3=d.get("skill3"),
        equip1=d.get("equip1"),
        equip2=d.get("equip2"),
        equip3=d.get("equip3"),
        equip4=d.get("equip4"),
        equip1_level=d.get("equip1_level"),
        equip2_level=d.get("equip2_level"),
        equip3_level=d.get("equip3_level"),
        combat_hp=d.get("combat_hp"),
        combat_atk=d.get("combat_atk"),
        combat_def=d.get("combat_def"),
        combat_heal=d.get("combat_heal"),
        form_combat_stats=_normalize_form_combat_stats(d.get("form_combat_stats")),
        stat_hp=d.get("stat_hp"),
        stat_atk=d.get("stat_atk"),
        stat_heal=d.get("stat_heal"),
        skipped=True,
    )



# Scanner


class Scanner:

    def __init__(
        self,
        regions: dict,
        on_progress: Optional[Callable[[str], None]] = None,
        on_progress_state: Optional[Callable[[dict], None]] = None,
        on_status_event: Optional[Callable[[dict], None]] = None,
        on_status_ack_wait: Optional[Callable[[int], bool]] = None,
        maxed_ids:   Optional[set[str]]  = None,
        maxed_saved_data: Optional[dict[str, dict]] = None,
        student_saved_data: Optional[dict[str, dict]] = None,
        student_total_hint: Optional[int] = None,
        autosave_manager = None,   # AutoSaveManager | None
        inventory_profile_id: str | list[str] | tuple[str, ...] | None = None,
        fast_student_ids: Optional[list[str]] = None,
        inventory_detail_override_dir: str | os.PathLike | None = None,
    ):
        self.r             = regions
        self._on_progress  = on_progress
        self._on_progress_state = on_progress_state
        self._on_status_event = on_status_event
        self._on_status_ack_wait = on_status_ack_wait
        self._status_seq = 0
        self._last_status_seq = 0
        self._stop         = False
        self._space_stop_latched = False
        self._maxed_saved_data: dict[str, dict] = {}
        self._student_total_hint = None
        self._asv          = autosave_manager   # AutoSaveManager or None
        self._student_basic_img: Optional[Image.Image] = None
        self._student_basic_crops: Optional[ScreenCropSet] = None
        self._student_equipment_crops: Optional[ScreenCropSet] = None
        self._student_stat_crops: Optional[ScreenCropSet] = None
        self._captured_click_points = self._load_captured_click_points()
        self._active_student_panel: str | None = None
        self._panel_transition_history: dict[str, list[float]] = {}
        self._panel_title_score_history: dict[str, list[float]] = {}
        self._basic_level_run_templates: dict[int, dict[str, list[np.ndarray]]] = {}
        self._equip_level_run_templates: dict[int, dict[str, list[np.ndarray]]] = {}
        self._basic_equip_level_run_templates: dict[int, dict[int, dict[str, list[np.ndarray]]]] = {}
        self._basic_equip_tier_run_templates: dict[int, dict[str, list[np.ndarray]]] = {}
        self._inventory_icon_cache: dict[str, dict[str, tuple[str | None, str, str | None]]] = {
            "item": {},
            "equipment": {},
        }
        self._inventory_failed_hashes: dict[str, set[str]] = {
            "item": set(),
            "equipment": set(),
        }
        self._default_inventory_profile_ids = normalize_inventory_profile_ids(inventory_profile_id)
        self._inventory_detail_override_dir = (
            Path(inventory_detail_override_dir)
            if inventory_detail_override_dir
            else None
        )
        self._forced_inventory_profile_id: str | None = (
            None
            if not self._default_inventory_profile_ids or self._default_inventory_profile_ids == ("all",)
            else self._default_inventory_profile_ids[0]
        )

        _log.debug(
            "scanner init: asset_dir=%s template_dir=%s inventory_profiles=%s detail_override=%s",
            ASSET_DIR,
            TEMPLATE_DIR,
            self._default_inventory_profile_ids or ("all",),
            self._inventory_detail_override_dir,
        )

    def stop(self) -> None:
        self._stop = True
        _log.info("scan stop requested")
        self._status("stop.requested")

    def clear_stop(self) -> None:
        self._stop = False
        self._space_stop_latched = False

    def _stop_requested(self) -> bool:
        if not self._stop and _space_key_down():
            self._stop = True
            if not self._space_stop_latched:
                self._space_stop_latched = True
                self._info("[stop] Spacebar emergency stop requested")
                self._status("stop.spacebar")
                _log.info("spacebar emergency stop requested")
        return self._stop

    def _wait(self, seconds: float, step: float = 0.05) -> bool:
        end = time.monotonic() + max(0.0, seconds)
        poll_step = max(0.001, step)
        while True:
            if self._stop_requested():
                return False
            remaining = end - time.monotonic()
            if remaining <= 0:
                break
            time.sleep(min(poll_step, remaining))
        return not self._stop_requested()

    def _panel_transition_initial_wait(self, key: str) -> float:
        samples = self._panel_transition_history.get(key, ())
        if len(samples) < 3:
            return PANEL_TRANSITION_INITIAL_WAIT
        ordered = sorted(samples)
        middle = len(ordered) // 2
        median = (
            ordered[middle]
            if len(ordered) % 2
            else (ordered[middle - 1] + ordered[middle]) / 2.0
        )
        return max(
            PANEL_TRANSITION_MIN_WAIT,
            min(PANEL_TRANSITION_MAX_WAIT, median - PANEL_TRANSITION_LEAD),
        )

    def _record_panel_transition(
        self,
        key: str,
        elapsed: float,
        *,
        success: bool,
        initial_wait: float,
    ) -> None:
        samples = self._panel_transition_history.setdefault(key, [])
        if success:
            samples.append(max(0.0, elapsed))
            del samples[:-PANEL_TRANSITION_HISTORY_SIZE]
        median = sorted(samples)[len(samples) // 2] if samples else 0.0
        _log.info(
            "[panel_transition] key=%s elapsed=%.3fs initial=%.3fs success=%s samples=%d median=%.3fs",
            key,
            elapsed,
            initial_wait,
            str(success).lower(),
            len(samples),
            median,
        )

    def _reset_panel_transition_history(self) -> None:
        self._panel_transition_history.clear()
        self._panel_title_score_history.clear()
        self._basic_level_run_templates.clear()
        equip_templates = getattr(self, "_equip_level_run_templates", None)
        if equip_templates is not None:
            equip_templates.clear()
        _log.info("[panel_transition] history reset for new student scan run")

    def _panel_title_score_threshold(self, panel_name: str) -> float:
        samples = self._panel_title_score_history.get(panel_name, ())
        if not samples:
            return STUDENT_PANEL_TITLE_MIN_SCORE
        ordered = sorted(samples)
        middle = len(ordered) // 2
        median = (
            ordered[middle]
            if len(ordered) % 2
            else (ordered[middle - 1] + ordered[middle]) / 2.0
        )
        return max(
            STUDENT_PANEL_TITLE_ADAPTIVE_FLOOR,
            min(STUDENT_PANEL_TITLE_MIN_SCORE, median - STUDENT_PANEL_TITLE_ADAPTIVE_LEAD),
        )

    def _record_panel_title_score(self, panel_name: str, score: float) -> None:
        samples = self._panel_title_score_history.setdefault(panel_name, [])
        samples.append(float(score))
        del samples[:-STUDENT_PANEL_TITLE_HISTORY_SIZE]
        threshold = self._panel_title_score_threshold(panel_name)
        _log.info(
            "[panel_title_calibration] panel=%s score=%.3f threshold=%.3f samples=%d",
            panel_name,
            score,
            threshold,
            len(samples),
        )

    def _load_captured_click_points(self) -> dict[str, dict]:
        path = Path(CAPTURED_CLICK_POINTS_FILE)
        try:
            if path.exists():
                raw = json.loads(path.read_text(encoding="utf-8"))
                if isinstance(raw, dict):
                    _log.info("[coord_capture] loaded %d points from %s", len(raw), path)
                    return raw
        except Exception as exc:
            _log.warning("[coord_capture] failed to load %s: %s", path, exc)
        return {}

    def _click_ratio_point(self, rx: float, ry: float, label: str = "", delay: float = 0.0) -> bool:
        rect = self._rect()
        if rect is None:
            _log.warning(f"[click] rect missing: {label}")
            return False
        hwnd = self._hwnd()
        if not hwnd:
            _log.warning(f"[click] hwnd missing: {label}")
            return False
        cx, cy = ratio_to_client(rect, rx, ry)
        ok = click_point(hwnd, cx, cy, label=label, delay=delay)
        _log.debug(
            f"[click] {label} ratio=({rx:.6f},{ry:.6f}) client=({cx},{cy}) ok={ok}"
        )
        return ok

    def _click_captured_point(self, name: str, *, label: str = "", delay: float = 0.0) -> bool:
        point = self._captured_click_points.get(name)
        if not isinstance(point, dict):
            return False
        ratio = point.get("ratio")
        if not isinstance(ratio, dict):
            return False
        try:
            rx = float(ratio["x"])
            ry = float(ratio["y"])
        except Exception:
            return False
        return self._click_ratio_point(rx, ry, label=label or name, delay=delay)

    def _click_region_capture(self, name: str, *, label: str = "", delay: float = 0.0) -> bool:
        region = _region_capture_region(name)
        if region is None:
            self.log(f"warning: missing region capture {name}")
            return False
        clicked = self._click_r(region, label or name)
        if clicked and delay > 0:
            return self._wait(delay)
        return clicked

    def _region_capture_match_score(self, name: str) -> float | None:
        region = _region_capture_region(name)
        template_path = _region_capture_reference_path(name)
        if region is None or not template_path:
            return None
        img = self._capture()
        if img is None:
            return None
        crop = crop_region(img, region)
        return match_score_resized(crop, template_path, focus_center=True)

    def _wait_for_region_capture_match(
        self,
        name: str,
        *,
        threshold: float,
        timeout: float,
        initial_wait: float = 0.0,
        poll: float = UI_FLAG_POLL,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        last_score: float | None = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            score = self._region_capture_match_score(name)
            last_score = score
            if score is not None and score >= threshold:
                self._debug(f"  {name} ready score={score:.3f}")
                return True
            if not self._wait(poll):
                return False
        if last_score is None:
            self.log(f"  {name} ready check unavailable")
        else:
            self.log(f"  {name} ready timeout score={last_score:.3f} < {threshold:.2f}")
        return False


    def _inventory_filter_title_score(self, img: Optional[Image.Image]) -> float | None:
        if img is None or not INVENTORY_FILTER_TITLE_TEMPLATE.exists():
            return None
        title_crop = crop_region(img, INVENTORY_FILTER_TITLE_REGION)
        return match_score_resized(title_crop, str(INVENTORY_FILTER_TITLE_TEMPLATE))

    def _is_inventory_filter_menu_capture(self, img: Optional[Image.Image]) -> bool:
        score = self._inventory_filter_title_score(img)
        matched = score is not None and score >= INVENTORY_FILTER_TITLE_MIN_SCORE
        _log.debug(
            "inventory_filter_title: score=%s threshold=%.3f matched=%s",
            "none" if score is None else f"{score:.3f}",
            INVENTORY_FILTER_TITLE_MIN_SCORE,
            str(matched).lower(),
        )
        return matched

    def _wait_for_inventory_filter_menu_open(
        self,
        *,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_MENU_SETTLE_WAIT,
        poll: float = UI_FLAG_POLL,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        ready_streak = 0
        last_score: float | None = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            last_score = self._inventory_filter_title_score(img)
            if last_score is not None and last_score >= INVENTORY_FILTER_TITLE_MIN_SCORE:
                ready_streak += 1
                if ready_streak >= INVENTORY_FILTER_TITLE_STABLE_POLLS:
                    self._debug(f"  inventory filter title ready score={last_score:.3f}")
                    return True
            else:
                ready_streak = 0
            if not self._wait(poll):
                return False
        if last_score is None:
            self.log("  inventory filter title check unavailable")
        else:
            self.log(
                f"  inventory filter title timeout "
                f"score={last_score:.3f} < {INVENTORY_FILTER_TITLE_MIN_SCORE:.2f}"
            )
        return False

    def _click_region_capture_and_wait_for_reference(
        self,
        click_name: str,
        reference_name: str,
        *,
        label: str = "",
        threshold: float = INVENTORY_PANEL_READY_THRESHOLD,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_TAB_SETTLE_WAIT,
        max_attempts: int = INVENTORY_PANEL_OPEN_ATTEMPTS,
    ) -> bool:
        for attempt in range(1, max_attempts + 1):
            if not self._click_region_capture(click_name, label=label or click_name):
                return False
            if self._wait_for_region_capture_match(
                reference_name,
                threshold=threshold,
                timeout=timeout,
                initial_wait=initial_wait,
                poll=min(UI_FLAG_POLL, PANEL_TRANSITION_POLL),
            ):
                return True
            if attempt < max_attempts:
                self.log(
                    f"  {click_name} did not open expected panel "
                    f"({attempt}/{max_attempts}) -> retry"
                )
        return False

    def _open_inventory_filter_panel(
        self,
        click_name: str,
        *,
        label: str,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_MENU_SETTLE_WAIT,
        max_attempts: int = 2,
    ) -> bool:
        for attempt in range(1, max_attempts + 1):
            if not self._click_region_capture(click_name, label=label or click_name):
                return False
            if self._wait_for_inventory_filter_menu_open(
                timeout=timeout,
                initial_wait=initial_wait,
                poll=min(UI_FLAG_POLL, PANEL_TRANSITION_POLL),
            ):
                return True
            if attempt < max_attempts:
                self.log(
                    f"  {click_name} did not open inventory filter menu "
                    f"({attempt}/{max_attempts}) -> retry"
                )
        self.log(f"  {label} failed: filter menu title was not recognized; stopping scan")
        self.stop()
        return False

    def _ensure_region_matches_reference(
        self,
        name: str,
        *,
        threshold: float = INVENTORY_SORT_RULE_MATCH_THRESHOLD,
        click_delay: float = DELAY_AFTER_CLICK,
        check_wait: float = INVENTORY_SORT_RULE_CHECK_WAIT,
        retry_wait: float = INVENTORY_SORT_RULE_RETRY_WAIT,
        max_attempts: int = INVENTORY_SORT_RULE_MAX_ATTEMPTS,
    ) -> bool:
        for attempt in range(1, max_attempts + 1):
            if check_wait > 0 and not self._wait(check_wait):
                return False
            score = self._region_capture_match_score(name)
            if score is None:
                self.log(f"  {name} reference unavailable -> skip check")
                return False
            self.log(f"  {name} match score={score:.3f} (attempt {attempt}/{max_attempts})")
            if score >= threshold:
                return True
            if attempt >= max_attempts:
                break
            self.log(f"  {name} mismatch -> clicking")
            if not self._click_region_capture(name, label=name, delay=click_delay):
                return False
            if retry_wait > 0 and not self._wait(retry_wait):
                return False
        self.log(f"  {name} did not reach threshold {threshold:.2f}")
        return False

    def _item_scan_profiles(
        self,
        inventory_profile_id: str | list[str] | tuple[str, ...] | None,
    ) -> tuple[str | None, ...]:
        requested = inventory_profile_id
        if requested is None:
            requested = self._default_inventory_profile_ids
        normalized = normalize_inventory_profile_ids(requested)
        if not normalized or normalized == ("all",):
            return (None,)
        return tuple(normalized)

    def _item_sort_rule_check_name(self, profile_id: str | None) -> str:
        if profile_id == "student_elephs":
            return "sort_name_rule_check"
        return "sort_rule_check"

    def _prepare_item_inventory(self, profile_id: str | None, *, ensure_sort_rule: bool) -> bool:
        self.log(f"  item filter menu open (profile={profile_id or 'all'})")
        if not self._open_inventory_filter_panel(
            "filtermenu_button",
            label="filtermenu_button",
            timeout=INVENTORY_PANEL_OPEN_TIMEOUT,
            initial_wait=INVENTORY_FILTER_MENU_SETTLE_WAIT,
            max_attempts=2,
        ):
            self.log("  item prepare failed: filter menu did not open")
            return False
        if not self._click_region_capture(
            "filter_tab",
            label="filter_tab",
            delay=INVENTORY_FILTER_TAB_SETTLE_WAIT,
        ):
            self.log("  item prepare failed: filter_tab click failed")
            return False
        if not self._click_region_capture(
            "filter_reset_button",
            label="filter_reset_button",
            delay=INVENTORY_FILTER_TAB_SETTLE_WAIT,
        ):
            self.log("  item prepare failed: filter_reset_button click failed")
            return False

        filter_button_by_profile = {
            "student_elephs": "eleph_filter",
            "tech_notes": "note_filter",
            "tactical_bd": "bd_filter",
            "ooparts": "ooparts_filter",
            "activity_reports": "reports_filter",
        }
        filter_button = filter_button_by_profile.get(profile_id or "")
        if filter_button:
            self.log(f"  item filter select: {filter_button}")
            if not self._click_region_capture(
                filter_button,
                label=filter_button,
                delay=INVENTORY_FILTER_TAB_SETTLE_WAIT,
            ):
                self.log(f"  item prepare failed: {filter_button} click failed")
                return False

        if not self._click_region_capture(
            "sort_tab",
            label="sort_tab",
            delay=INVENTORY_FILTER_TAB_SETTLE_WAIT,
        ):
            self.log("  item prepare failed: sort_tab click failed")
            return False
        sort_rule_check = self._item_sort_rule_check_name(profile_id)
        if not self._ensure_region_matches_reference(
            sort_rule_check,
            threshold=ITEM_SORT_RULE_MATCH_THRESHOLD,
        ):
            self.log(f"  item prepare failed: {sort_rule_check} mismatch")
            return False

        if not self._click_region_capture(
            "filter_confirm_button",
            label="filter_confirm_button",
            delay=INVENTORY_FILTER_CONFIRM_WAIT,
        ):
            self.log("  item prepare failed: filter_confirm_button click failed")
            return False
        return self._wait(INVENTORY_FILTER_CONFIRM_WAIT)

    def _prepare_equipment_inventory(self) -> bool:
        self.log("  equipment filter menu open")
        if not self._open_inventory_filter_panel(
            "eq_filtermenu_button",
            label="eq_filtermenu_button",
            timeout=INVENTORY_PANEL_OPEN_TIMEOUT,
            initial_wait=INVENTORY_FILTER_MENU_SETTLE_WAIT,
            max_attempts=2,
        ):
            self.log("  equipment prepare failed: filter panel did not open")
            return False
        if not self._ensure_region_matches_reference(
            "eq_sort_rule_check",
            threshold=EQUIPMENT_SORT_RULE_MATCH_THRESHOLD,
        ):
            self.log("  equipment prepare failed: eq_sort_rule_check mismatch")
            return False
        if not self._click_region_capture(
            "eq_filter_confirm_button",
            label="eq_filter_confirm_button",
            delay=INVENTORY_FILTER_CONFIRM_WAIT,
        ):
            self.log("  equipment prepare failed: eq_filter_confirm_button click failed")
            return False
        return self._wait(INVENTORY_FILTER_CONFIRM_WAIT)
    def _reset_inventory_scan_state(self, source: str) -> None:
        self._inventory_icon_cache[source] = {}
        self._inventory_failed_hashes[source] = set()
        self._inventory_motion_row_step_px = None

    def _close_inventory_menu(self) -> bool:
        menu_back = self.r.get("menu", {}).get("backbutton")
        if not menu_back:
            self.log("warning: missing menu backbutton")
            return False
        if not self._click_r(menu_back, "menu_backbutton"):
            return False
        return self._wait(0.2)

    def _go_home_from_inventory(self) -> bool:
        return self._click_region_capture("home", label="home", delay=0.35)

    def _exit_inventory_to_menu(self) -> bool:
        if not self._close_inventory_menu():
            return False
        if not self._go_home_from_inventory():
            return False
        if not self._open_menu():
            return False
        return self._wait(1.0)

    def _return_inventory_to_lobby(self) -> None:
        self.log("?????????????????????????????⑤벡???????????????????????????????????????꾩룆梨띰쭕?뚢뵾??????????????嶺뚮죭?댁젘??????????????????????釉먮폁???????????????????살몝????...")
        if not self._close_inventory_menu():
            return
        self._go_home_from_inventory()

    def _close_student_panel(
        self,
        *,
        capture_name: str | None = None,
        region_key: str | None = None,
        settle_reason: str,
        wait: float = PANEL_CLOSE_SETTLE_WAIT,
    ) -> bool:
        sr = self.r["student"]
        self._active_student_panel = None
        started = time.perf_counter()
        clicked = False
        if region_key and region_key in sr:
            clicked = self._click_r(sr[region_key], region_key)
        if (not clicked) and capture_name:
            clicked = self._click_captured_point(capture_name, label=capture_name)
        if not clicked:
            self._esc(delay=wait)
            started = time.perf_counter()
        ok = self._settle_student_detail(
            settle_reason,
            transition_key=f"close:{settle_reason}",
            started_at=started,
        )
        if not ok:
            self._esc(delay=wait)
            ok = self._settle_student_detail(f"{settle_reason}_esc_retry", initial_wait=0.0)
        return ok

    def _panel_close_spec(self, panel_name: str) -> tuple[str | None, str | None, str]:
        if panel_name == "skill":
            return "skill_close_button", "skillmenu_quit_button", "close_skill_menu"
        if panel_name == "weapon":
            return "weapon_close_button", "weapon_menu_quit_button", "close_weapon_menu"
        if panel_name == "equipment":
            return "equipment_close_button", "equipmentmenu_quit_button", "close_equipment_menu"
        if panel_name == "stat":
            return "stat_close_button", "statmenu_quit_button", "close_stat_menu"
        return None, None, "close_panel"

    def _close_active_student_panel(self, *, wait: float = PANEL_CLOSE_SETTLE_WAIT) -> bool:
        panel_name = self._active_student_panel
        if not panel_name:
            return False
        capture_name, region_key, settle_reason = self._panel_close_spec(panel_name)
        self._active_student_panel = None
        sr = self.r["student"]
        started = time.perf_counter()
        clicked = False
        if region_key and region_key in sr:
            clicked = self._click_r(sr[region_key], region_key)
        if (not clicked) and capture_name:
            clicked = self._click_captured_point(capture_name, label=capture_name)
        if not clicked:
            return False
        ok = self._settle_student_detail(
            settle_reason,
            transition_key=f"close:{settle_reason}",
            started_at=started,
        )
        if not ok:
            self._esc(delay=wait)
            ok = self._settle_student_detail(f"{settle_reason}_esc_retry", initial_wait=0.0)
        return ok


    # Forward logs to both the file logger and the UI progress callback.

    def _debug(self, msg: str) -> None:
        _log.debug(msg)

    def _info(self, msg: str) -> None:
        _log.info(msg)
        if self._on_progress:
            self._on_progress(msg)

    def _emit_progress_state(
        self,
        *,
        current: int | None = None,
        total: int | None = None,
        note: str = "",
    ) -> None:
        if self._on_progress_state:
            self._on_progress_state(
                {
                    "current": current,
                    "total": total,
                    "note": note,
                }
            )

    def _status(self, event_id: str, **fields) -> int | None:
        if not self._on_status_event:
            return None
        try:
            self._status_seq += 1
            event = make_status_event(event_id, data=fields)
            event["seq"] = self._status_seq
            self._on_status_event(event)
            self._last_status_seq = self._status_seq
            return self._status_seq
        except Exception:
            _log.exception("scan status callback failed: %s", event_id)
            return None

    def _status_skill_value(self, entry: StudentEntry, field_name: str, value: object) -> None:
        if value is None:
            return
        label_map = {
            "ex_skill": "EX",
            "skill1": "basic",
            "skill2": "enhanced",
            "skill3": "sub",
        }
        self._status(
            "skills.value.ok",
            student_name=entry.display_name,
            skill=field_name,
            label=label_map.get(field_name, field_name),
            value=value,
        )
        self._field_confirmed(entry, field_name, value)

    def _field_confirmed(
        self,
        entry: StudentEntry,
        field_name: str,
        value: object,
        *,
        label: str | None = None,
        display_value: str | None = None,
    ) -> int | None:
        if value is None:
            return None
        label_map = {
            "level": "level",
            "student_star": "student star",
            "weapon_star": "weapon star",
            "weapon_level": "weapon level",
            "ex_skill": "EX skill",
            "skill1": "basic skill",
            "skill2": "enhanced skill",
            "skill3": "sub skill",
            "equip1": "equipment 1 tier",
            "equip2": "equipment 2 tier",
            "equip3": "equipment 3 tier",
            "equip1_level": "equipment 1 level",
            "equip2_level": "equipment 2 level",
            "equip3_level": "equipment 3 level",
            "equip4": "favorite item",
            "stat_hp": "bonus hp",
            "stat_atk": "bonus atk",
            "stat_heal": "bonus heal",
            "combat_hp": "HP",
            "combat_atk": "ATK",
            "combat_def": "DEF",
            "combat_heal": "HEAL",
        }
        return self._status(
            "field.confirmed",
            student_id=entry.student_id,
            student_name=entry.display_name,
            field=field_name,
            value=value,
            label=label or label_map.get(field_name, field_name),
            display_value=display_value or str(value),
        )

    def _wait_ui_status_flush(self, seq: int | None = None, *, label: str = "") -> bool:
        if not self._on_status_ack_wait:
            return True
        target = int(seq or self._last_status_seq or 0)
        if target <= 0:
            return True
        ok = self._on_status_ack_wait(target)
        if not ok:
            _log.debug("ui status flush timeout: seq=%s label=%s", target, label)
        return ok

    @contextmanager
    def _perf_step(self, label: str, **fields) -> Iterator[None]:
        """Log elapsed time for one scanner step into the per-scan debug log."""
        started = time.perf_counter()
        try:
            yield
        finally:
            elapsed = time.perf_counter() - started
            extras = " ".join(
                f"{key}={value}"
                for key, value in fields.items()
                if value is not None
            )
            suffix = f" {extras}" if extras else ""
            _log.info("[perf] %s elapsed=%.3fs%s", label, elapsed, suffix)

    def _warn(self, msg: str) -> None:
        _log.warning(msg)
        if self._on_progress:
            self._on_progress(f"??????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷??????????????????{msg}")

    def _error(self, msg: str) -> None:
        _log.error(msg)
        if self._on_progress:
            self._on_progress(f"????????????????{msg}")

    # Backward-compatible alias so old code can keep using self.log(msg).
    @property
    def log(self):
        return self._info


    # Student entry lifecycle helpers


    def begin_student_scan(self, student_id: str) -> StudentEntry:
        """Create a temporary student entry at the start of a scan."""
        entry = StudentEntry(
            student_id=student_id,
            display_name=student_meta.display_name(student_id),
            scan_state=ScanState.TEMP,
        )
        self._status("student.scan.start", student_id=student_id, student_name=entry.display_name)
        _log.debug(f"[TEMP] start: {entry.label()}")
        return entry

    def _mark_favorite_item_unsupported(self, entry: StudentEntry, sid: str) -> None:
        entry.equip4 = EquipSlotFlag.NULL.value
        entry.set_meta("equip4", FieldMeta.skipped("favorite_item_unsupported"))
        self._status("favorite.unsupported", student_name=entry.display_name or student_meta.display_name(sid))
        self.log(f"  ????: {sid}??equip4 ???????????????????????????嫄?????????耀붾굝???????⑤슢??筌믩끃異?????????????????????????????룸㎗????꿔꺂?????????????????????????????곕춴???????????곕춴??????????????-> null")




    def finalize_student_entry(
        self,
        entry:   StudentEntry,
        ctx:     "ScanCtx",
        *,
        partial_ok: bool = True,
    ) -> EntryCommitResult:
        """Validate a temporary student entry before it is committed."""


















        if not entry.student_id:
            entry.scan_state = ScanState.FAILED
            self._status("student.scan.failed", student_name=entry.display_name or "")
            return EntryCommitResult(
                entry=entry, committed=False,
                missing=[], confidence=0.0,
                reason="student_id missing",
            )

        missing    = entry.missing_fields()
        confidence = entry.confidence()

        if not missing:
            # All required fields were filled, so the entry can be committed.
            entry.scan_state = ScanState.COMMITTED

            # Still log if any field succeeded with low confidence.
            uncertain = entry.uncertain_fields()
            if uncertain:
                self._status(
                    "summary.student.uncertain",
                    student_name=entry.display_name,
                    fields=", ".join(uncertain),
                )
                _log.warning(
                    f"{ctx} warning: committed with uncertain fields: {uncertain}"
                )
            else:
                _log.info(
                    f"{ctx} COMMITTED "
                    f"(confidence={confidence:.2f})"
                )
            return EntryCommitResult(
                entry=entry, committed=True,
                missing=[], confidence=confidence,
            )

        # Missing fields are allowed in partial mode.
        if partial_ok:
            entry.scan_state = ScanState.PARTIAL
            self._status("student.scan.partial_commit", student_name=entry.display_name)
            _log.warning(
                f"{ctx} warning: PARTIAL "
                f"(confidence={confidence:.2f} missing={missing})"
            )
            return EntryCommitResult(
                entry=entry, committed=True,
                missing=missing, confidence=confidence,
                reason=f"missing={missing}",
            )

        # In strict mode, missing required fields make the entry fail.
        entry.scan_state = ScanState.FAILED
        self._status("student.scan.failed", student_name=entry.display_name)
        _log.warning(
            f"{ctx} FAILED (strict) "
            f"(confidence={confidence:.2f} missing={missing})"
        )
        return EntryCommitResult(
            entry=entry, committed=False,
            missing=missing, confidence=confidence,
            reason=f"strict_fail missing={missing}",
        )

    def commit_student_entry(
        self,
        result:  EntryCommitResult,
        results: list[StudentEntry],
        idx:     int,
    ) -> bool:
        """Append a validated entry to the results list when allowed."""
        entry = result.entry
        if not result.committed:
            self._status("student.scan.failed", student_name=entry.display_name)
            _log.warning(
                f"[{idx+1:>3}] skipped entry: {entry.label()} -> {result.reason}"
            )
            return False

        results.append(entry)

        state_tag = "COMMITTED" if entry.is_committed() else "PARTIAL"
        _log.info(
            f"[{idx+1:>3}] {state_tag}: {entry.label()} "
            f"(confidence={result.confidence:.2f})"
        )
        if result.missing:
            self._status(
                "summary.student.failed",
                student_name=entry.display_name,
                fields=", ".join(result.missing),
            )
            self._warn(
                f"  [{idx+1:>3}] {entry.label()} missing fields: {result.missing}"
            )
        else:
            self._status("student.scan.commit", student_name=entry.display_name)
        return True



    def _capture(self, retry: int = RETRY_CAPTURE) -> Optional[Image.Image]:
        """Capture the game window, retrying briefly on failure."""
        started = time.perf_counter()
        for i in range(retry + 1):
            if self._stop_requested():
                _log.debug(
                    "[perf] capture elapsed=%.3fs success=false reason=stop attempt=%d",
                    time.perf_counter() - started,
                    i + 1,
                )
                return None
            img = capture_window_background()
            if img is not None:
                source_size = img.info.get("capture_source_size", img.size)
                try:
                    source_w, source_h = source_size
                except (TypeError, ValueError):
                    source_w, source_h = img.size
                _log.debug(
                    "[perf] capture elapsed=%.3fs success=true attempt=%d "
                    "source_size=%sx%s normalized_size=%sx%s size=%sx%s",
                    time.perf_counter() - started,
                    i + 1,
                    source_w,
                    source_h,
                    img.width,
                    img.height,
                    img.width,
                    img.height,
                )
                return img
            if i < retry:
                _log.debug(f"capture retry ({i+1}/{retry})")
                if not self._wait(0.1):
                    _log.debug(
                        "[perf] capture elapsed=%.3fs success=false reason=wait_stop attempt=%d",
                        time.perf_counter() - started,
                        i + 1,
                    )
                    return None
        self._error("capture failed")
        self._status("capture.failed")
        _log.info(
            "[perf] capture elapsed=%.3fs success=false attempts=%d",
            time.perf_counter() - started,
            retry + 1,
        )
        return None

    def _invalidate_student_basic_capture(self) -> None:
        self._student_basic_img = None
        self._student_basic_crops = None

    def _set_student_basic_capture(self, image: Image.Image) -> None:
        self._student_basic_img = image
        self._student_basic_crops = None

    def _student_basic_crop_keys(self) -> tuple[str, ...]:
        regions = self.r.get("student", {})
        explicit = {
            "student_texture_region",
            "weapon_info_menu_button",
            "equipment_button",
        }
        return tuple(
            key for key in regions
            if key.startswith("basic_") or key in explicit
        )

    def _get_student_basic_capture(
        self,
        *,
        refresh: bool = False,
    ) -> Optional[Image.Image]:
        if refresh or getattr(self, "_student_basic_img", None) is None:
            img = self._capture()
            if img is None:
                return None
            self._set_student_basic_capture(img)
        return self._student_basic_img

    def _get_student_basic_crops(self) -> Optional[ScreenCropSet]:
        image = self._get_student_basic_capture()
        if image is None:
            return None
        if getattr(self, "_student_basic_crops", None) is None:
            regions = self.r.get("student", {})
            self._student_basic_crops = ScreenCropSet.from_image(
                image,
                regions,
                keys=self._student_basic_crop_keys(),
            )
            _log.debug(
                "student basic crops prepared: count=%d memory=%d source=%s",
                len(self._student_basic_crops.names()),
                self._student_basic_crops.memory_bytes(),
                self._student_basic_crops.source_size,
            )
        return self._student_basic_crops

    def _get_student_basic_region(self, name: str) -> Optional[PreparedScreenRegion]:
        # Some unit-test scanners intentionally bypass __init__; in that case
        # retain the legacy caller-provided image path.
        if not hasattr(self, "_student_basic_img"):
            return None
        crops = self._get_student_basic_crops()
        return crops.get(name) if crops is not None else None

    def save_student_basic_crops(self, directory: str | Path, *, prefix: str = "") -> list[Path]:
        """Export the current named crops for ROI and matcher diagnostics."""
        crops = self._get_student_basic_crops()
        return crops.save_debug(directory, prefix=prefix) if crops is not None else []

    def save_student_panel_crops(
        self,
        panel_name: str,
        directory: str | Path,
        *,
        prefix: str = "",
    ) -> list[Path]:
        """Export retained equipment or stat crops without the full capture."""
        crops = {
            "equipment": getattr(self, "_student_equipment_crops", None),
            "stat": getattr(self, "_student_stat_crops", None),
        }.get(panel_name)
        return crops.save_debug(directory, prefix=prefix) if crops is not None else []

    def _release_student_basic_source(self) -> None:
        """Drop the full basic screenshot after all named consumers have run."""
        self._student_basic_img = None

    def _adjust_region(
        self,
        region: dict,
        *,
        left: float = 0.0,
        top: float = 0.0,
        right: float = 0.0,
        bottom: float = 0.0,
    ) -> dict:
        return {
            "x1": max(0.0, min(1.0, region["x1"] + left)),
            "y1": max(0.0, min(1.0, region["y1"] + top)),
            "x2": max(0.0, min(1.0, region["x2"] + right)),
            "y2": max(0.0, min(1.0, region["y2"] + bottom)),
        }

    def _basic_equipment_empty_dot_region(self, slot: int) -> Optional[dict]:
        regions = self.r.get("student", {}) if hasattr(self, "r") else {}
        if slot in (1, 2, 3):
            configured = regions.get(f"basic_equipment_{slot}_empty_dot_region")
        elif slot == 4:
            configured = regions.get("basic_favorite_empty_dot_region")
        else:
            configured = None
        return configured or BASIC_EQUIP_EMPTY_DOT_REGIONS.get(slot)

    def _basic_equipment_empty_dot_present(self, img: Image.Image, slot: int) -> bool:
        region = self._basic_equipment_empty_dot_region(slot)
        if not region:
            return False
        crop = crop_region(img, region).convert("RGB")
        arr = np.asarray(crop)
        if arr.size == 0:
            return False
        red = arr[:, :, 0].astype(np.int16)
        green = arr[:, :, 1].astype(np.int16)
        blue = arr[:, :, 2].astype(np.int16)
        mask = (
            (red > 230)
            & (green > 145)
            & (green < 220)
            & (blue < 100)
            & ((red - green) > 25)
        )
        pixels = int(mask.sum())
        ratio = float(mask.mean())
        _log.debug(f"basic equip{slot} empty dot: pixels={pixels} ratio={ratio:.3f} region={region}")
        return (
            pixels >= BASIC_EQUIP_EMPTY_DOT_MIN_PIXELS
            and ratio >= BASIC_EQUIP_EMPTY_DOT_MIN_RATIO
        )
    def _equipment_growth_button_active(self, img: Image.Image, region: dict) -> bool:
        ratio = self._active_blue_button_ratio(img, region, "equipment growth button")
        return ratio >= EQUIPMENT_GROWTH_ACTIVE_BLUE_MIN_RATIO

    def _active_blue_button_ratio(self, img: Image.Image, region: dict, label: str) -> float:
        crop = crop_region(img, region).convert("RGB")
        arr = np.asarray(crop)
        if arr.size == 0:
            return 0.0
        red = arr[:, :, 0].astype(np.int16)
        green = arr[:, :, 1].astype(np.int16)
        blue = arr[:, :, 2].astype(np.int16)
        mask = (
            (blue > 180)
            & (green > 150)
            & (red < 170)
            & ((blue - red) > 35)
        )
        ratio = float(mask.mean())
        _log.debug(f"{label} active blue ratio={ratio:.3f}")
        return ratio

    def _apply_basic_equipment_hints(
        self,
        entry: StudentEntry,
        img: Image.Image,
        slots_to_scan: set[int],
        *,
        include_favorite: bool,
        growth_button_active: bool,
    ) -> None:
        for slot in sorted(tuple(slots_to_scan)):
            if slot not in (1, 2, 3):
                continue
            if not self._basic_equipment_empty_dot_present(img, slot):
                continue
            equip_key = f"equip{slot}"
            level_key = f"equip{slot}_level"
            setattr(entry, equip_key, EquipSlotFlag.EMPTY.value)
            entry.set_meta(equip_key, FieldMeta.skipped("basic_empty_dot"))
            setattr(entry, level_key, None)
            entry.set_meta(level_key, FieldMeta.skipped("basic_empty_dot"))
            slots_to_scan.discard(slot)
            self.log(f"  equipment{slot}: empty dot detected -> skip basic read")
            self._status(f"equip{slot}.basic_empty_dot", student_name=entry.display_name)
    @staticmethod
    def _equipment_level_matches_tier(level: int, tier: str) -> bool:
        max_levels = {
            "T1": 10, "T2": 20, "T3": 30, "T4": 40, "T5": 45,
            "T6": 50, "T7": 55, "T8": 60, "T9": 65, "T10": 70,
        }
        max_level = max_levels.get(tier)
        return bool(max_level is not None and 1 <= level <= max_level)

    def _read_basic_equipment_slot(
        self,
        entry: StudentEntry,
        image: Image.Image,
        regions: dict,
        slot: int,
    ) -> bool:
        level_region = regions.get(f"basic_equipment_{slot}_level_digits_quad")
        icon_region = regions.get(f"basic_equipment_{slot}_icon_region")
        equipment_slots = student_meta.equipment_slots(entry.student_id)
        equipment_family = equipment_slots[slot - 1] if slot <= len(equipment_slots) else None
        if not (level_region and icon_region and equipment_family):
            return False
        if not hasattr(self, "_basic_equip_level_run_templates"):
            self._basic_equip_level_run_templates = {}
        level_templates = self._basic_equip_level_run_templates.setdefault(slot, {})
        tier_result = read_basic_equipment_icon_tier_result(
            image, icon_region, equipment_family,
        )
        generated_level_result = read_basic_equipment_generated_level_result(
            image,
            level_region,
            slot,
            equipment_family,
            str(tier_result.value) if tier_result.value and not tier_result.uncertain else None,
            icon_region,
        )
        if generated_level_result.value is not None and not generated_level_result.uncertain:
            level_result = generated_level_result
        else:
            level_result = read_basic_equipment_level_result(
                image, level_region, level_templates,
            )
        level = level_result.value
        tier = tier_result.value
        confident = (
            level is not None
            and tier is not None
            and not level_result.uncertain
            and not tier_result.uncertain
            and self._equipment_level_matches_tier(level, tier)
        )
        _log.debug(
            "basic equip%d: level=%s score=%.3f uncertain=%s tier=%s score=%.3f uncertain=%s compatible=%s icon=%s level_detail=%s",
            slot, level, level_result.score, level_result.uncertain,
            tier, tier_result.score, tier_result.uncertain,
            self._equipment_level_matches_tier(level, tier) if level and tier else False,
            tier_result.label,
            level_result.label,
        )
        if not confident:
            return False
        equip_key = f"equip{slot}"
        level_key = f"equip{slot}_level"
        setattr(entry, equip_key, tier)
        setattr(entry, level_key, level)
        entry.set_meta(
            equip_key,
            FieldMeta(status=FieldStatus.OK, source=FieldSource.TEMPLATE,
                      score=tier_result.score, note="basic_info_icon"),
        )
        entry.set_meta(
            level_key,
            FieldMeta(status=FieldStatus.OK, source=FieldSource.TEMPLATE,
                      score=level_result.score, note="basic_info_icon"),
        )
        self._status(f"equip{slot}.tier.ok", student_name=entry.display_name, tier=tier)
        self._field_confirmed(entry, equip_key, tier)
        self._status(f"equip{slot}.level.ok", student_name=entry.display_name, level=level)
        self._field_confirmed(entry, level_key, level, display_value=f"Lv.{level}")
        self.log(f"  equipment{slot}: basic read {tier} Lv.{level}")
        return True

    def _learn_basic_equipment_slot(
        self,
        entry: StudentEntry,
        image: Image.Image,
        regions: dict,
        slot: int,
    ) -> None:
        level = getattr(entry, f"equip{slot}_level")
        tier = getattr(entry, f"equip{slot}")
        level_region = regions.get(f"basic_equipment_{slot}_level_digits_quad")
        if isinstance(level, int) and level_region:
            if not hasattr(self, "_basic_equip_level_run_templates"):
                self._basic_equip_level_run_templates = {}
            templates = self._basic_equip_level_run_templates.setdefault(slot, {})
            learn_basic_equipment_level(image, level_region, level, templates)
        if isinstance(level, int) or isinstance(tier, str):
            _log.debug(
                "basic equip%d calibration: tier=%s level=%s",
                slot, tier, level,
            )

    def _is_lobby_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("lobby", {}).get("detect_flag")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_lobby(roi, {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0})

    def _is_student_menu_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("student_menu", {}).get("menu_detect_flag")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_student_menu(roi, {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0})

    def _student_additional_menu_region(self) -> Optional[dict]:
        # Reuse the student-menu detect ROI by default because the additional
        # menu applies the same dimmed effect to that area.
        return (
            self.r.get("student", {}).get("student_additional_menu_on_flag")
            or self.r.get("student_menu", {}).get("menu_detect_flag")
        )

    def _is_student_additional_menu_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self._student_additional_menu_region()
        if img is None or not detect_r:
            return False
        if (
            self._is_basic_info_tab_on_capture(img)
            or self._is_level_tab_on_capture(img)
            or self._is_star_tab_on_capture(img)
        ):
            return False
        roi = crop_region(img, detect_r)
        return is_student_additional_menu_on(
            roi,
            {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0},
        )

    def _is_student_panel_title_capture(self, img: Optional[Image.Image], panel_name: str) -> bool:
        if img is None:
            return False
        expected_template = STUDENT_PANEL_TITLE_TEMPLATES.get(panel_name)
        if expected_template is None or not expected_template.exists():
            _log.warning("student panel title template missing: %s", panel_name)
            return self._is_student_additional_menu_capture(img)
        title_crop = crop_region(img, STUDENT_PANEL_TITLE_REGION)
        scores: dict[str, float] = {}
        for name, template_path in STUDENT_PANEL_TITLE_TEMPLATES.items():
            if template_path.exists():
                scores[name] = match_score_resized(title_crop, str(template_path))
        expected_score = scores.get(panel_name, 0.0)
        other_best = max((score for name, score in scores.items() if name != panel_name), default=0.0)
        margin = expected_score - other_best
        threshold = self._panel_title_score_threshold(panel_name)
        has_history = bool(self._panel_title_score_history.get(panel_name))
        bootstrap_match = (
            not has_history
            and expected_score >= STUDENT_PANEL_TITLE_BOOTSTRAP_SCORE
            and margin >= STUDENT_PANEL_TITLE_BOOTSTRAP_MARGIN
        )
        adaptive_match = (
            expected_score >= threshold
            and margin >= STUDENT_PANEL_TITLE_MIN_MARGIN
        )
        matched = bootstrap_match or adaptive_match
        _log.debug(
            "student_panel_title[%s]: %s margin=%.3f threshold=%.3f bootstrap=%s matched=%s",
            panel_name,
            " ".join(f"{name}={score:.3f}" for name, score in sorted(scores.items())),
            margin,
            threshold,
            str(bootstrap_match).lower(),
            str(matched).lower(),
        )
        if matched:
            self._record_panel_title_score(panel_name, expected_score)
        return matched

    def _is_level_tab_on_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("student", {}).get("levelcheck_button")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_level_tab_on(roi, {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0})

    def _is_basic_info_tab_on_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("student", {}).get("basic_info_button")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_basic_info_tab_on(
            roi,
            {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0},
        )

    def _is_star_tab_on_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("student", {}).get("star_menu_button")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_star_tab_on(
            roi,
            {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0},
        )

    def _student_detail_score(self, img: Optional[Image.Image]) -> float:
        texture_r = self.r.get("student", {}).get("student_texture_region")
        if img is None or not texture_r:
            return 0.0
        crop = crop_region(img, texture_r)
        _, score = match_student_texture(crop)
        return score

    def _wait_for_student_menu_state(
        self,
        expected_in_student_menu: bool,
        *,
        timeout: float,
        initial_wait: float = 0.0,
        poll: float = 0.25,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        ready_streak = 0
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            matches = img is not None and self._is_student_menu_capture(img) == expected_in_student_menu
            if matches:
                ready_streak += 1
                if ready_streak < STUDENT_MENU_READY_STABLE_POLLS:
                    if not self._wait(poll):
                        return False
                    continue
                self._invalidate_student_basic_capture()
                return True
            ready_streak = 0
            if not self._wait(poll):
                return False
        return False

    def _wait_for_student_detail(
        self,
        *,
        timeout: float = DETAIL_READY_WAIT,
        initial_wait: float = 0.0,
        poll: float = 0.25,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        ready_streak = 0
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            if img is not None and self._is_basic_info_tab_on_capture(img):
                self._set_student_basic_capture(img)
                return True
            score = self._student_detail_score(img)
            _log.debug(
                f"[detail_wait] texture_score={score:.3f} "
                f"ready_streak={ready_streak}"
            )
            if score >= DETAIL_READY_SCORE:
                ready_streak += 1
                if ready_streak < DETAIL_READY_STABLE_POLLS:
                    if not self._wait(poll):
                        return False
                    continue
                self._set_student_basic_capture(img)
                return True
            else:
                ready_streak = 0
            if not self._wait(poll):
                return False
        return False

    def _wait_for_student_detail_fast(
        self,
        *,
        timeout: float = DETAIL_READY_WAIT,
        initial_wait: float = 0.0,
        poll: float = 0.20,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        last_img: Optional[Image.Image] = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            last_img = img
            if img is not None and self._is_basic_info_tab_on_capture(img):
                self._set_student_basic_capture(img)
                return True
            if not self._wait(poll):
                return False
        if last_img is not None:
            self._set_student_basic_capture(last_img)
            return True
        return False

    def _student_texture_digest(self, img: Optional[Image.Image]) -> Optional[str]:
        texture_r = self.r.get("student", {}).get("student_texture_region")
        if img is None or not texture_r:
            return None
        try:
            crop = crop_region(img, texture_r)
        except Exception:
            return None
        return hashlib.sha1(crop.tobytes()).hexdigest()

    def _student_texture_signature(self, img: Optional[Image.Image]) -> Optional[np.ndarray]:
        texture_r = self.r.get("student", {}).get("student_texture_region")
        if img is None or not texture_r:
            return None
        try:
            crop = crop_region(img, texture_r).convert("RGB").resize((24, 24), Image.BILINEAR)
        except Exception:
            return None
        return np.asarray(crop, dtype=np.float32) / 255.0

    @staticmethod
    def _student_texture_signature_delta(
        left: Optional[np.ndarray],
        right: Optional[np.ndarray],
    ) -> float:
        if left is None or right is None or left.shape != right.shape:
            return 1.0
        return float(np.mean(np.abs(left - right)))

    def _current_student_digest(self, *, refresh: bool) -> Optional[str]:
        img = self._get_student_basic_capture(refresh=refresh)
        return self._student_texture_digest(img)

    def _wait_for_student_change(
        self,
        previous_digest: str,
        *,
        timeout: float = 3.0,
        initial_wait: float = STUDENT_CHANGE_INITIAL_WAIT,
        poll: float = STUDENT_CHANGE_POLL,
    ) -> Optional[str]:
        started = time.perf_counter()
        if initial_wait > 0 and not self._wait(initial_wait):
            return None
        deadline = time.monotonic() + timeout
        changed_digest: Optional[str] = None
        previous_signature: Optional[np.ndarray] = None
        stable_streak = 0
        while time.monotonic() < deadline:
            if self._stop_requested():
                return None
            img = self._get_student_basic_capture(refresh=True)
            digest = self._student_texture_digest(img)
            if digest and digest != previous_digest:
                signature = self._student_texture_signature(img)
                delta = self._student_texture_signature_delta(previous_signature, signature)
                stable_streak = stable_streak + 1 if delta <= STUDENT_CHANGE_STABLE_DELTA else 1
                previous_signature = signature
                changed_digest = digest
                _log.debug(
                    "[navigation_transition] changed=true stable_streak=%d delta=%.4f",
                    stable_streak,
                    delta,
                )
                if stable_streak >= STUDENT_CHANGE_STABLE_POLLS:
                    _log.info(
                        "[navigation_transition] elapsed=%.3fs initial=%.3fs success=true stable=true",
                        time.perf_counter() - started,
                        initial_wait,
                    )
                    return digest
            else:
                changed_digest = None
                previous_signature = None
                stable_streak = 0
            if not self._wait(poll):
                return None
        if changed_digest is not None:
            _log.warning(
                "[navigation_transition] elapsed=%.3fs initial=%.3fs success=true stable=false",
                time.perf_counter() - started,
                initial_wait,
            )
            return changed_digest
        _log.warning(
            "[navigation_transition] elapsed=%.3fs initial=%.3fs success=false stable=false",
            time.perf_counter() - started,
            initial_wait,
        )
        return None

    def _wait_for_capture_match(
        self,
        predicate: Callable[[Optional[Image.Image]], bool],
        *,
        timeout: float,
        initial_wait: float = 0.0,
        poll: float = UI_FLAG_POLL,
        stable_polls: int = 1,
        label: str = "",
    ) -> Optional[Image.Image]:
        if initial_wait > 0 and not self._wait(initial_wait):
            return None
        deadline = time.monotonic() + timeout
        ready_streak = 0
        last_img: Optional[Image.Image] = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return None
            img = self._capture()
            last_img = img
            matched = img is not None and predicate(img)
            _log.debug(
                f"[wait_match] label={label} matched={matched} "
                f"ready_streak={ready_streak}"
            )
            if matched:
                ready_streak += 1
                if ready_streak >= stable_polls:
                    return img
            else:
                ready_streak = 0
            if not self._wait(poll):
                return last_img if matched else None
        return None

    def _click_student_region_and_wait(
        self,
        region_key: str,
        label: str,
        predicate: Callable[[Optional[Image.Image]], bool],
        *,
        timeout: float,
        initial_wait: float = DELAY_AFTER_CLICK,
        poll: float = UI_FLAG_POLL,
        stable_polls: int = 1,
        fallback_delay: float = DELAY_TAB_SWITCH,
        match_delay: float = UI_FLAG_MATCH_DELAY,
    ) -> Optional[Image.Image]:
        started = time.perf_counter()
        success = False
        transition_key = f"open:{label}"
        adaptive_initial_wait = self._panel_transition_initial_wait(transition_key)
        region = self.r.get("student", {}).get(region_key)
        try:
            if not region:
                self.log(f"  missing {region_key}")
                return None
            if not self._click_r(region, label):
                return None
            img = self._wait_for_capture_match(
                predicate,
                timeout=timeout,
                initial_wait=adaptive_initial_wait,
                poll=min(poll, PANEL_TRANSITION_POLL),
                stable_polls=stable_polls,
                label=label,
            )
            if img is not None:
                success = True
                return img
            if fallback_delay > 0 and not self._wait(fallback_delay):
                return None
            img = self._capture()
            if img is not None and predicate(img):
                success = True
                return img
            _log.warning(f"{label} did not reach expected panel state")
            return None
        finally:
            elapsed = time.perf_counter() - started
            self._record_panel_transition(
                transition_key,
                elapsed,
                success=success,
                initial_wait=adaptive_initial_wait,
            )
            _log.info(
                "[perf] student.panel_wait elapsed=%.3fs label=%s region=%s success=%s",
                elapsed,
                label,
                region_key,
                str(success).lower(),
            )

    def _recover_first_student_entry(self) -> bool:
        _log.warning("recovering first student entry from fallback state")
        img = self._capture()
        if img is not None:
            if self._is_lobby_capture(img):
                _log.warning("recover detect: still in lobby")
                if not self.enter_student_menu():
                    return False
            elif self._is_student_menu_capture(img):
                _log.warning("recover detect: still in student menu")
        self._invalidate_student_basic_capture()
        return self.enter_first_student()

    def _rect(self) -> Optional[tuple[int, int, int, int]]:
        return get_window_rect()

    def _hwnd(self) -> Optional[int]:
        return find_target_hwnd()

    def _retry(
        self,
        fn: Callable,
        max_attempts: int = 2,
        delay: float = 0.3,
        label: str = "",
    ):
        """Retry fn() until it returns a non-None result or attempts run out."""




        for i in range(max_attempts):
            if self._stop_requested():
                return None
            result = fn()
            if result is not None:
                return result
            if i < max_attempts - 1:
                self.log(f"  ?????{label} ({i+2}/{max_attempts})")
                if not self._wait(delay):
                    return None
        return None



    def _click_r(self, region: dict, label: str = "") -> bool:
        """Click the center point of a ratio region."""
        rect = self._rect()
        if rect is None:
            _log.warning(f"[click] window rect missing: {label}")
            return False
        hwnd = self._hwnd()
        rx = (region["x1"] + region["x2"]) / 2
        ry = (region["y1"] + region["y2"]) / 2
        if hwnd:
            cx, cy = ratio_to_client(rect, rx, ry)
            ok = click_point(hwnd, cx, cy, label=label)
            _log.debug(
                f"[click] {label} hwnd={hwnd} ratio=({rx:.4f},{ry:.4f}) "
                f"client=({cx},{cy}) ok={ok}"
            )
            return ok
        ok = click_center(rect, region, label)
        _log.debug(f"[click] {label} ratio=({rx:.4f},{ry:.4f}) fallback ok={ok}")
        return ok

    def _tab(self, region_key: str, delay: float = DELAY_TAB_SWITCH) -> bool:
        """Click a student tab/button region and wait for it to settle."""
        sr = self.r["student"]
        region = sr.get(region_key)
        if not region:
            self.log(f"  warning: {region_key} missing -> skipped")
            return False
        ok = self._click_r(region, region_key)
        if delay > 0:
            if not self._wait(delay):
                return False
        return ok

    def _esc(self, n: int = 1, delay: float = PANEL_CLOSE_SETTLE_WAIT) -> None:
        """Close the current panel, usually via ESC fallback logic."""
        hwnd = self._hwnd()
        for _ in range(n):
            if self._stop_requested():
                return
            if n == 1 and self._close_active_student_panel(wait=delay):
                return
            if hwnd:
                send_escape(hwnd, delay=delay)
            else:
                press_esc()

    def _restore_basic_tab(self) -> bool:
        """Return to the basic info tab."""
        sr = self.r["student"]
        current = self._get_student_basic_capture(refresh=True)
        if current is not None and self._is_basic_info_tab_on_capture(current):
            self._set_student_basic_capture(current)
            return True
        if "basic_info_button" in sr:
            img = self._click_student_region_and_wait(
                "basic_info_button",
                "basic_info_tab",
                self._is_basic_info_tab_on_capture,
                timeout=TAB_ON_READY_WAIT,
                initial_wait=DELAY_AFTER_CLICK,
                poll=UI_FLAG_POLL,
                stable_polls=1,
                fallback_delay=BASIC_TAB_SETTLE_WAIT,
            )
            if img is not None:
                self._set_student_basic_capture(img)
                return True
        else:
            self._esc()
        return self._settle_student_detail("basic_info_tab", initial_wait=0.0)

    def _settle_student_detail(
        self,
        reason: str,
        *,
        initial_wait: float = MENU_CLOSE_DETAIL_WAIT,
        timeout: float = 2.5,
        poll: float = 0.20,
        transition_key: str | None = None,
        started_at: float | None = None,
    ) -> bool:
        effective_initial_wait = initial_wait
        if transition_key:
            effective_initial_wait = self._panel_transition_initial_wait(transition_key)
        started = started_at if started_at is not None else time.perf_counter()
        self._invalidate_student_basic_capture()
        ok = self._wait_for_student_detail(
            timeout=timeout,
            initial_wait=effective_initial_wait,
            poll=min(poll, PANEL_TRANSITION_POLL) if transition_key else poll,
        )
        if transition_key:
            self._record_panel_transition(
                transition_key,
                time.perf_counter() - started,
                success=ok,
                initial_wait=effective_initial_wait,
            )
        _log.debug(f"[detail_settle] reason={reason} ok={ok}")
        return ok





    def scan_resources(self) -> dict:
        self.log("???????????????????????????..")
        img = self._capture()
        if img is None:
            return {}

        lobby_r = self.r["lobby"]
        result: dict = {}

        ocr.load()
        try:
            for key, rk in [("credit", "credit_region"),
                             ("pyroxene", "pyroxene_region")]: 
                try:
                    crop = crop_region(img, lobby_r[rk])
                    result[key] = ocr.read_item_count(crop)
                except Exception as e:
                    result[key] = None
                    _log.warning(f"?????OCR ?????????????????????????곕춴??????({key}): {type(e).__name__}: {e}")
        finally:
            ocr.unload()

        self.log(f"Lobby OCR: pyroxene={result.get('pyroxene', '-')} credit={result.get('credit', '-')}")
        return result





    def _open_menu(self) -> bool:
        rect = self._rect()
        if not rect:
            return False
        self.log("??????????????????????????????????????????????..")
        self._click_r(self.r["lobby"]["menu_button"], "menu_button")
        return self._wait(0.7)

    def _go_to(self, btn_key: str, label: str) -> bool:
        btn = self.r["menu"].get(btn_key)
        if not btn:
            self.log(f"warning: {label} button region missing")
            return False
        self.log(f"  {label} ????????????????..")
        self._click_r(btn, label)
        return self._wait(1.0)

    def _return_lobby(self) -> None:
        self.log("?????????????????????????????⑤벡???????????????????????????????????????꾩룆梨띰쭕?뚢뵾??????????????嶺뚮죭?댁젘??????????????????????釉먮폁???????????????????살몝????...")
        back = (
            self.r.get("student_menu", {}).get("backbutton")
            or self.r.get("menu", {}).get("backbutton")
        )
        for attempt in range(4):
            if self._stop_requested():
                return
            img = self._capture()
            if self._is_lobby_capture(img):
                return
            if self._close_active_student_panel(wait=PANEL_CLOSE_SETTLE_WAIT):
                continue
            if back and self._click_r(back, f"student_backbutton_{attempt + 1}"):
                if not self._wait(0.8):
                    return
                continue
            break
        self.log("  warning: ?????????????????????????????⑤벡???????????????????????????????????????꾩룆梨띰쭕?뚢뵾??????????????嶺뚮죭?댁젘??????????????????????釉먮폁???????????????????살몝???? ?????????????????????????????????거?????????????⑤벡瑜???饔낅떽???????멸괜????????????????????????????????????????곕춴??????-> ESC 1??fallback")
        self._esc()

    def _capture_inventory_page(
        self,
        img: Image.Image,
        slots: list[dict],
        *,
        grid_hash: str,
        page_index: int,
        grid_cols: int,
    ) -> InventoryPageSnapshot:
        slot_snaps: list[InventorySlotSnapshot] = []
        for idx, slot in enumerate(slots):
            icon_crop = crop_region(img, _slot_icon_region(slot))
            slot_snaps.append(
                InventorySlotSnapshot(
                    slot_index=idx,
                    icon_hash=_img_hash(icon_crop),
                )
            )
        last_row_hashes = [s.icon_hash for s in slot_snaps[-grid_cols:]] if grid_cols > 0 else []
        return InventoryPageSnapshot(
            page_index=page_index,
            grid_hash=grid_hash,
            last_row_hashes=last_row_hashes,
            slots=slot_snaps,
        )

    def _verify_inventory_slot(
        self,
        rect: tuple[int, int, int, int],
        slot: dict,
        name_r: dict,
        count_r: dict,
        source: str,
        profile_id: str | None = None,
        input_backend: InventoryGridInput | None = None,
        slot_index: int | None = None,
    ) -> InventoryVerification | None:
        self._debug(
            f"    verify slot: source={source} profile={profile_id or '-'} "
            f"slot=({slot.get('x1', 0):.3f},{slot.get('y1', 0):.3f},"
            f"{slot.get('x2', 0):.3f},{slot.get('y2', 0):.3f})"
        )
        if input_backend is not None:
            if slot_index is None:
                self._debug("    verify failed: missing input slot index")
                return None
            input_backend.move_to_slot(slot_index)
            input_backend.confirm_slot()
            self._debug(
                f"    verify slot via {input_backend.backend_name}: "
                f"slot_index={slot_index}"
            )
        else:
            click_ry = slot["y1"] + (slot["y2"] - slot["y1"]) * 0.4
            safe_click(rect, slot["cx"], click_ry, f"{source}_slot")
        if not self._wait(DELAY_AFTER_CLICK):
            return None

        img2 = self._capture()
        if img2 is None:
            self._debug("    verify failed: detail capture failed")
            return None
        if input_backend is not None and os.environ.get("BA_INVENTORY_VCON_SLOT_DEBUG") == "1":
            try:
                debug_dir = BASE_DIR / "debug" / "inventory_vcon_slots"
                debug_dir.mkdir(parents=True, exist_ok=True)
                safe_profile = (profile_id or source or "inventory").replace("/", "_").replace("\\", "_")
                safe_slot = slot_index if slot_index is not None else "unknown"
                img2.save(debug_dir / f"{source}_{safe_profile}_slot{safe_slot}_{int(time.time() * 1000)}.png")
            except Exception:
                _log.debug("failed to save vcon slot debug capture", exc_info=True)

        count = ""
        if source == "item" or profile_id:
            count_match = None
            if source == "equipment" or profile_id == "equipment":
                count_match = read_equipment_count_from_detail(img2)
                if (
                    count_match.value is None
                    and count_match.reason in ("no_x_templates", "missing_digit_templates")
                ):
                    self.log(
                        "    equipment count fallback -> item templates "
                        f"(reason={count_match.reason})"
                    )
                    count_match = read_item_count_from_detail(img2)
            else:
                count_match = read_item_count_from_detail(img2)
            if count_match.value is not None:
                count = count_match.value
                self.log(
                    f"    count template matched: {count} "
                    f"(digits={count_match.digit_count}, conf={count_match.confidence:.2f})"
                )
            else:
                self.log(
                    f"    count template fallback: reason={count_match.reason} "
                    f"(digits={count_match.digit_count}, conf={count_match.confidence:.2f})"
                )
            if not count:
                self._debug("    verify failed: count unresolved")
                return None
            matched_item_id = None
            matched_score = 0.0
            detail_crop = self._inventory_detail_crop(img2, profile_id) if profile_id else None
            detail_name_crop = self._inventory_detail_name_crop(img2, source) if profile_id else None
            if profile_id:
                matched_item_id, matched_score = self._match_inventory_detail_crop(
                    detail_crop,
                    profile_id,
                    detail_name_crop,
                )
                if matched_item_id:
                    self.log(
                        f"    detail template matched: {matched_item_id} "
                        f"(score={matched_score:.2f})"
                    )
                else:
                    self._debug(
                        f"    detail template unresolved "
                        f"(best_score={matched_score:.2f}, profile={profile_id})"
                    )
            return InventoryVerification(
                name=None,
                count=count,
                item_id=matched_item_id,
                match_score=matched_score,
                detail_crop=detail_crop,
                detail_name_crop=detail_name_crop,
            )
        self.log("    detail template fallback disabled: profile/template match required")
        return None

    def _match_inventory_icon(
        self,
        icon_crop: Image.Image,
        source: str,
    ) -> tuple[str | None, float]:
        best_item_id: str | None = None
        best_score = 0.0
        for item_id, path in _inventory_template_catalog(source):
            score = match_score_resized_raw(icon_crop, path)
            if score > best_score:
                best_score = score
                best_item_id = item_id
        threshold = 0.84 if source == "equipment" else 0.80
        if best_score < threshold:
            return None, best_score
        return best_item_id, best_score

    def _inventory_detail_crop(
        self,
        image: Image.Image,
        profile_id: str | None,
    ) -> Image.Image | None:
        region = _inventory_detail_template_region(profile_id)
        if region is None:
            return None
        return crop_region(image, region)

    def _inventory_detail_name_crop(
        self,
        image: Image.Image,
        source: str,
    ) -> Image.Image | None:
        region = _inventory_detail_name_template_region(source)
        if region is None:
            return None
        return crop_region(image, region)

    def _inventory_detail_template_catalog_for_scan(
        self,
        profile_id: str | None,
    ) -> list[tuple[str, str]]:
        base_catalog = _inventory_detail_template_catalog(profile_id)
        if not profile_id or self._inventory_detail_override_dir is None:
            return base_catalog

        override_base = self._inventory_detail_override_dir / profile_id
        if not override_base.exists():
            return base_catalog

        override_by_id: dict[str, str] = {}
        for png in sorted(override_base.glob("*.png")):
            override_by_id[png.stem] = str(png)
        if not override_by_id:
            return base_catalog

        catalog: list[tuple[str, str]] = []
        used: set[str] = set()
        for item_id, path in base_catalog:
            if item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
                catalog.append((item_id, path))
                used.add(item_id)
                continue
            override_path = override_by_id.get(item_id)
            if override_path:
                catalog.append((item_id, override_path))
                used.add(item_id)
            else:
                catalog.append((item_id, path))
        for item_id, path in override_by_id.items():
            if item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
                continue
            if item_id not in used:
                catalog.append((item_id, path))
        return catalog

    def _inventory_detail_name_template_catalog_for_scan(
        self,
        profile_id: str | None,
    ) -> list[tuple[str, str]]:
        base_catalog = _inventory_detail_name_template_catalog(profile_id)
        if not profile_id or self._inventory_detail_override_dir is None:
            return base_catalog

        override_base = self._inventory_detail_override_dir.parent / "inventory_detail_names" / profile_id
        if not override_base.exists():
            return base_catalog

        override_by_id = {png.stem: str(png) for png in sorted(override_base.glob("*.png"))}
        if not override_by_id:
            return base_catalog

        catalog: list[tuple[str, str]] = []
        used: set[str] = set()
        for item_id, path in base_catalog:
            override_path = override_by_id.get(item_id)
            catalog.append((item_id, override_path or path))
            used.add(item_id)
        for item_id, path in override_by_id.items():
            if item_id not in used:
                catalog.append((item_id, path))
        return catalog

    def _match_inventory_detail_name_crop(
        self,
        crop: Image.Image | None,
        profile_id: str | None,
    ) -> tuple[str | None, float]:
        if crop is None:
            return None, 0.0
        catalog = self._inventory_detail_name_template_catalog_for_scan(profile_id)
        if not catalog:
            return None, 0.0

        best_item_id: str | None = None
        best_score = 0.0
        second_best = 0.0
        for item_id, path in catalog:
            score = match_score_textonly(crop, path)
            if score > best_score:
                second_best = best_score
                best_score = score
                best_item_id = item_id
            elif score > second_best:
                second_best = score

        if best_score < 0.72 or (best_score - second_best) < 0.02:
            return None, best_score
        return best_item_id, best_score

    def _match_inventory_detail_crop(
        self,
        crop: Image.Image | None,
        profile_id: str | None,
        name_crop: Image.Image | None = None,
    ) -> tuple[str | None, float]:
        if crop is None:
            return None, 0.0
        catalog = self._inventory_detail_template_catalog_for_scan(profile_id)
        if not catalog:
            return None, 0.0
        name_catalog = dict(self._inventory_detail_name_template_catalog_for_scan(profile_id))

        best_item_id: str | None = None
        best_score = 0.0
        second_best = 0.0
        family_top_scores: dict[str, list[tuple[str, float]]] = {}
        for item_id, path in catalog:
            icon_score = match_score_resized_raw(crop, path)
            name_path = name_catalog.get(item_id)
            name_score = match_score_textonly(name_crop, name_path) if name_crop is not None and name_path else 0.0
            score = _combine_inventory_detail_scores(icon_score, name_score)
            if score > best_score:
                second_best = best_score
                best_score = score
                best_item_id = item_id
            elif score > second_best:
                second_best = score

            family_key = _inventory_detail_strict_family(item_id)
            if family_key is not None:
                top_scores = family_top_scores.setdefault(family_key, [])
                top_scores.append((item_id, score))
                top_scores.sort(key=lambda row: row[1], reverse=True)
                if len(top_scores) > 4:
                    del top_scores[4:]

        if best_score < 0.88 or (best_score - second_best) < 0.015:
            return None, best_score

        strict_family = _inventory_detail_strict_family(best_item_id)
        if strict_family is not None:
            family_threshold, overall_margin_threshold, family_margin_threshold = (
                STRICT_DETAIL_FAMILY_THRESHOLDS[strict_family]
            )
            family_second_best = 0.0
            for item_id, score in family_top_scores.get(strict_family, []):
                if item_id != best_item_id:
                    family_second_best = score
                    break
            overall_margin = best_score - second_best
            family_margin = best_score - family_second_best
            if (
                best_score < family_threshold
                or overall_margin < overall_margin_threshold
                or family_margin < family_margin_threshold
            ):
                self.log(
                    f"    detail template ambiguous reject: {best_item_id} "
                    f"(score={best_score:.2f}, overall_margin={overall_margin:.3f}, "
                    f"family_margin={family_margin:.3f})"
                )
                return None, best_score
        return best_item_id, best_score

    def _match_inventory_detail_template(
        self,
        image: Image.Image,
        profile_id: str | None,
    ) -> tuple[str | None, float]:
        return self._match_inventory_detail_crop(
            self._inventory_detail_crop(image, profile_id),
            profile_id,
            self._inventory_detail_name_crop(image, profile_id or "item"),
        )

    def _fill_missing_profile_entries(
        self,
        items: list[ItemEntry],
        profile,
        source: str,
    ) -> list[ItemEntry]:
        ordered_names = list(profile.ordered_names)
        ordered_item_ids = list(inventory_profile_ordered_item_ids(profile))
        if not ordered_names:
            return items

        def _entry_rank(entry: ItemEntry) -> tuple[int, int, int]:
            quantity = str(entry.quantity or "").strip()
            has_nonzero_quantity = int(quantity not in ("", "0"))
            has_item_id = int(bool(entry.item_id))
            quantity_len = len(quantity)
            return (has_nonzero_quantity, has_item_id, quantity_len)

        by_item_id: dict[str, ItemEntry] = {}
        by_name: dict[str, ItemEntry] = {}
        unmatched: list[ItemEntry] = []
        for entry in items:
            if entry.item_id:
                prev = by_item_id.get(entry.item_id)
                if prev is None or _entry_rank(entry) > _entry_rank(prev):
                    if prev is not None:
                        unmatched.append(prev)
                    by_item_id[entry.item_id] = entry
                else:
                    unmatched.append(entry)
                continue
            if entry.name:
                prev = by_name.get(entry.name)
                if prev is None or _entry_rank(entry) > _entry_rank(prev):
                    if prev is not None:
                        unmatched.append(prev)
                    by_name[entry.name] = entry
                else:
                    unmatched.append(entry)
                continue
            unmatched.append(entry)

        rebuilt: list[ItemEntry] = []
        for idx, expected_name in enumerate(ordered_names):
            expected_item_id = ordered_item_ids[idx] if idx < len(ordered_item_ids) else None
            matched = None
            if expected_item_id:
                matched = by_item_id.pop(expected_item_id, None)
            if matched is None and expected_name:
                matched = by_name.pop(expected_name, None)
            if matched is None:
                continue
            matched.name = expected_name or matched.name
            matched.item_id = expected_item_id or matched.item_id
            matched.index = idx
            rebuilt.append(matched)

        tail = [entry for entry in items if entry not in rebuilt]
        for idx, entry in enumerate(tail, start=len(rebuilt)):
            entry.index = idx
        return rebuilt + tail

    def _append_profile_gap_entries(
        self,
        items: list[ItemEntry],
        seen_keys: set[str],
        profile_seen_names: set[str],
        profile,
        ordered_names: list[str],
        ordered_item_ids: list[str | None],
        source: str,
        start_idx: int,
        end_idx: int,
    ) -> int:
        if end_idx <= start_idx:
            return 0
        end_idx = min(end_idx, len(ordered_names))
        self.log(
            f"  profile gap zero-fill: start={start_idx} end={end_idx}"
        )
        added = 0
        for profile_idx in range(max(0, start_idx), end_idx):
            expected_name = ordered_names[profile_idx]
            expected_item_id = (
                ordered_item_ids[profile_idx]
                if profile_idx < len(ordered_item_ids)
                else None
            )
            if not expected_name and not expected_item_id:
                continue
            entry = ItemEntry(
                name=expected_name,
                quantity="0",
                item_id=expected_item_id,
                source=source,
                index=len(items),
                scan_meta={
                    "status": "zero_filled",
                    "reason": "profile_order_gap",
                    "profile_id": profile.profile_id,
                    "profile_index": profile_idx,
                    "review_required": False,
                },
            )
            key = entry.key()
            if key in seen_keys:
                continue
            seen_keys.add(key)
            if entry.name:
                profile_seen_names.add(entry.name)
            items.append(entry)
            added += 1
        return added

    def _scroll_inventory_page(
        self,
        rect: tuple[int, int, int, int],
        slots: list[dict],
        grid_r: dict,
        drag_config: InventoryDragConfig,
        scroll_amount: int,
        grid_cols: int,
        scroll_index: int = 0,
        debug_dir: Path | None = None,
        before_y_offset_px: int = 0,
        drag_rx_offset: float = 0.0,
    ) -> tuple[bool, Optional[InventoryPageSnapshot], int, int, int]:
        before_img = self._capture()
        before_slots = (
            _shift_slots_y(slots, before_y_offset_px, before_img.size)
            if before_img is not None and before_y_offset_px
            else slots
        )
        before_grid_r = _grid_region(before_slots) if before_img is not None and before_y_offset_px else grid_r
        before = crop_region(before_img, before_grid_r) if before_img else None
        before_grid_hash = _img_hash(before) if before is not None else ""
        before_page = self._capture_inventory_page(
            before_img,
            before_slots,
            grid_hash=before_grid_hash,
            page_index=-1,
            grid_cols=grid_cols,
        ) if before_img is not None else None
        next_amount = scroll_amount
        start_rx = drag_config.start_rx + drag_rx_offset
        start_ry = drag_config.start_ry
        if abs(drag_rx_offset) >= 0.0001:
            self._debug(
                f"  drag x offset: rx={start_rx:.6f} "
                f"base={drag_config.start_rx:.6f} offset={drag_rx_offset:+.6f}"
            )
        retry_amount = int(scroll_amount * drag_config.retry_scale)
        attempts = [scroll_amount, retry_amount]

        for idx, amount in enumerate(attempts, start=1):
            end_ry = start_ry + drag_config.delta_ry(amount)
            start_rx_clamped = max(0.02, min(0.98, start_rx))
            start_ry_clamped = max(0.02, min(0.98, start_ry))
            end_ry_clamped = max(0.02, min(0.98, end_ry))
            scroll_ok = drag_scroll(
                find_target_hwnd(),
                rect,
                start_rx_clamped,
                start_ry_clamped,
                end_ry_clamped,
                delay=0.35,
                duration=drag_config.duration,
                end_hold=drag_config.end_hold,
            )
            self.log(
                f"  drag try {idx}: start=({start_rx_clamped:.6f},{start_ry_clamped:.6f}) "
                f"end=({start_rx_clamped:.6f},{end_ry_clamped:.6f}) "
                f"delta_px={amount} duration={drag_config.duration:.2f} ok={scroll_ok}"
            )
            cursor_moved = _move_cursor_away_from_inventory_grid(rect)
            if cursor_moved:
                self._debug("  drag cursor moved away from inventory grid before capture")
            if not self._wait(0.18):
                return False, None, next_amount, 0, before_y_offset_px

            after_img = self._capture()
            if after_img is None:
                return scroll_ok, None, next_amount, 0, before_y_offset_px
            after = crop_region(after_img, before_grid_r)
            after_grid_hash = _img_hash(after)
            after_page = self._capture_inventory_page(
                after_img,
                before_slots,
                grid_hash=after_grid_hash,
                page_index=-1,
                grid_cols=grid_cols,
            )
            before_hashes = [snap.icon_hash for snap in before_page.slots] if before_page is not None else []
            after_hashes = [snap.icon_hash for snap in after_page.slots]
            image_changed = before is None or not _images_similar(before, after)
            hash_changed = before_grid_hash != after_grid_hash
            slot_sequence_changed = before_hashes != after_hashes
            moved = image_changed or hash_changed or slot_sequence_changed
            self.log(
                f"  drag try {idx}: moved={moved} "
                f"(image_changed={image_changed}, hash_changed={hash_changed}, "
                f"slot_sequence_changed={slot_sequence_changed})"
            )
            if moved:
                grid_rows = max(1, (len(slots) + grid_cols - 1) // max(1, grid_cols))
                base_row_step_px = _slot_row_step_px(before_slots, after_img.size, grid_cols)
                calibrated_row_step_px = getattr(self, "_inventory_motion_row_step_px", None)
                row_step_px = base_row_step_px
                if calibrated_row_step_px is not None and base_row_step_px > 0:
                    calibrated_int = int(round(float(calibrated_row_step_px)))
                    if int(round(base_row_step_px * 0.97)) <= calibrated_int <= int(round(base_row_step_px * 1.03)):
                        row_step_px = calibrated_int
                expected_move_px = min(abs(amount), row_step_px * max(1, grid_rows - 1)) if row_step_px > 0 else abs(amount)
                search_margin_px = max(50, row_step_px * max(1, grid_rows - 1)) if row_step_px > 0 else 50
                motion = _estimate_inventory_scroll_motion(
                    before_img,
                    after_img,
                    before_grid_r,
                    expected_move_px,
                    search_margin_px=search_margin_px,
                    slots=before_slots,
                ) if before_img is not None else None
                motion_overlap = _inventory_overlap_rows_from_motion(motion, row_step_px, grid_rows)
                moved_rows: int | None = None
                tail_scroll = False
                if motion_overlap is not None:
                    overlap_rows, moved_rows, y_offset_delta_px, tail_scroll = motion_overlap
                    y_offset_px = before_y_offset_px + y_offset_delta_px
                    self.log(
                        f"  drag try {idx}: motion actual={motion.actual_move_px}px "
                        f"expected={motion.expected_step_px}px row_step={row_step_px}px "
                        f"moved_rows={moved_rows} overlap_rows={overlap_rows} tail={tail_scroll} "
                        f"before_y={before_y_offset_px:+d}px y_delta={y_offset_delta_px:+d}px "
                        f"y_offset={y_offset_px:+d}px score={motion.score:.3f} method={motion.method}"
                    )
                    if (
                        motion is not None
                        and moved_rows is not None
                        and moved_rows > 0
                        and not tail_scroll
                        and motion.score >= 0.70
                        and base_row_step_px > 0
                    ):
                        observed_row_step = motion.actual_move_px / max(1, moved_rows)
                        if base_row_step_px * 0.97 <= observed_row_step <= base_row_step_px * 1.03:
                            previous_row_step = getattr(self, "_inventory_motion_row_step_px", None)
                            if previous_row_step is None:
                                updated_row_step = observed_row_step
                            else:
                                updated_row_step = (float(previous_row_step) * 0.65) + (observed_row_step * 0.35)
                            self._inventory_motion_row_step_px = updated_row_step
                            self.log(
                                f"  drag try {idx}: observed row_step={observed_row_step:.2f}px "
                                f"calibrated={updated_row_step:.2f}px base={base_row_step_px}px"
                            )
                else:
                    overlap_rows = _count_row_overlap(before_hashes, after_hashes, grid_cols)
                    y_offset_px = before_y_offset_px
                    self.log(
                        f"  drag try {idx}: overlap_rows={overlap_rows} source=hash "
                        f"y_offset={y_offset_px:+d}px"
                    )

                final_slots = _shift_slots_y(slots, y_offset_px, after_img.size) if y_offset_px else slots
                final_grid_r = _grid_region(final_slots) if y_offset_px else grid_r
                final_after = crop_region(after_img, final_grid_r)
                final_after_grid_hash = _img_hash(final_after)
                final_after_page = self._capture_inventory_page(
                    after_img,
                    final_slots,
                    grid_hash=final_after_grid_hash,
                    page_index=-1,
                    grid_cols=grid_cols,
                )
                final_after_hashes = [snap.icon_hash for snap in final_after_page.slots]
                adapted_amount, target_move_px = _adapt_inventory_drag_amount(
                    amount,
                    motion,
                    row_step_px,
                    grid_rows,
                    drag_config,
                )
                if adapted_amount != amount:
                    self.log(
                        f"  drag try {idx}: adaptive next delta_px={adapted_amount} "
                        f"(current={amount}, target_move={target_move_px}px, "
                        f"actual={motion.actual_move_px if motion is not None else 0}px)"
                    )

                _save_inventory_scroll_debug(
                    debug_dir,
                    before_img=before_img,
                    after_img=after_img,
                    slots=slots,
                    grid_cols=grid_cols,
                    grid_rows=grid_rows,
                    scroll_index=scroll_index,
                    attempt_index=idx,
                    amount=amount,
                    scroll_ok=scroll_ok,
                    moved=moved,
                    image_changed=image_changed,
                    hash_changed=hash_changed,
                    slot_sequence_changed=slot_sequence_changed,
                    row_step_px=row_step_px,
                    expected_move_px=expected_move_px,
                    search_margin_px=search_margin_px,
                    motion=motion,
                    overlap_rows=overlap_rows,
                    moved_rows=moved_rows,
                    y_offset_px=y_offset_px,
                    before_grid_hash=before_grid_hash,
                    after_grid_hash=final_after_grid_hash,
                    before_hashes=before_hashes,
                    after_hashes=final_after_hashes,
                    cursor_moved=cursor_moved,
                    before_y_offset_px=before_y_offset_px,
                    before_slots=before_slots,
                    tail_scroll=tail_scroll,
                )
                next_amount = adapted_amount
                return True, final_after_page, next_amount, overlap_rows, y_offset_px

            grid_rows = max(1, (len(slots) + grid_cols - 1) // max(1, grid_cols))
            row_step_px = _slot_row_step_px(before_slots, after_img.size, grid_cols)
            expected_move_px = min(abs(amount), row_step_px * max(1, grid_rows - 1)) if row_step_px > 0 else abs(amount)
            search_margin_px = max(50, row_step_px * max(1, grid_rows - 1)) if row_step_px > 0 else 50
            _save_inventory_scroll_debug(
                debug_dir,
                before_img=before_img,
                after_img=after_img,
                slots=slots,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                scroll_index=scroll_index,
                attempt_index=idx,
                amount=amount,
                scroll_ok=scroll_ok,
                moved=moved,
                image_changed=image_changed,
                hash_changed=hash_changed,
                slot_sequence_changed=slot_sequence_changed,
                row_step_px=row_step_px,
                expected_move_px=expected_move_px,
                search_margin_px=search_margin_px,
                motion=None,
                overlap_rows=0,
                moved_rows=None,
                y_offset_px=before_y_offset_px,
                before_grid_hash=before_grid_hash,
                after_grid_hash=after_grid_hash,
                before_hashes=before_hashes,
                after_hashes=after_hashes,
                cursor_moved=cursor_moved,
                before_y_offset_px=before_y_offset_px,
                before_slots=before_slots,
            )
        return False, None, scroll_amount, 0, before_y_offset_px

    def _advance_inventory_page_with_input(
        self,
        input_backend: InventoryGridInput,
        slots: list[dict],
        grid_r: dict,
        grid_cols: int,
        before_page: InventoryPageSnapshot,
    ) -> tuple[bool, Optional[InventoryPageSnapshot]]:
        try:
            input_backend.advance_page()
        except Exception as exc:
            self.log(f"  {input_backend.backend_name} page advance failed: {exc}")
            _log.exception("inventory input page advance failed")
            return False, None

        if not self._wait(0.25):
            return False, None

        after_img = self._capture()
        if after_img is None:
            return False, None

        after = crop_region(after_img, grid_r)
        after_page = self._capture_inventory_page(
            after_img,
            slots,
            grid_hash=_img_hash(after),
            page_index=-1,
            grid_cols=grid_cols,
        )
        before_hashes = [snap.icon_hash for snap in before_page.slots]
        after_hashes = [snap.icon_hash for snap in after_page.slots]
        moved = (
            before_page.grid_hash != after_page.grid_hash
            or before_hashes != after_hashes
        )
        self.log(
            f"  {input_backend.backend_name} advance: moved={moved} "
            f"(hash_changed={before_page.grid_hash != after_page.grid_hash}, "
            f"slot_sequence_changed={before_hashes != after_hashes})"
        )
        if moved:
            overlap_rows = _count_row_overlap(before_hashes, after_hashes, grid_cols)
            self.log(f"  {input_backend.backend_name} advance: overlap_rows={overlap_rows}")
        return moved, after_page

    def _scan_grid(
        self,
        section: str,
        source: str,
        drag_config: InventoryDragConfig,
        scroll_amount: int,
        input_backend_name: str = "legacy",
    ) -> list[ItemEntry]:
        r_sec   = self.r[section]
        slots   = r_sec["grid_slots"]
        name_r  = r_sec["name_region"]
        count_r = r_sec["count_region"]
        grid_r  = _grid_region(slots)

        rect = self._rect()
        if not rect:
            self.log("window not found")
            return []

        items:       list[ItemEntry] = []
        seen_keys:   set[str]        = set()
        seen_hashes: list[str]       = []
        fast_grid_entries = 0
        detail_verified_entries = 0
        icon_cache = self._inventory_icon_cache.setdefault(source, {})
        failed_hashes = self._inventory_failed_hashes.setdefault(source, set())
        active_profile = get_inventory_profile(self._forced_inventory_profile_id)
        if active_profile is not None and active_profile.source != source:
            active_profile = None
        profile_seen_names: set[str] = set()
        icon = "item" if source == "item" else "equipment"
        scroll_debug_dir = _inventory_scroll_debug_dir(source, self._forced_inventory_profile_id)
        if scroll_debug_dir is not None:
            self.log(f"  inventory scroll debug: {scroll_debug_dir}")
        grid_cols = int(r_sec.get("grid_cols", 0))
        grid_rows = int(r_sec.get("grid_rows", 0))
        if grid_cols <= 0:
            grid_cols = max(1, int(round(len(slots) ** 0.5)))
        if grid_rows <= 0:
            grid_rows = max(1, (len(slots) + grid_cols - 1) // grid_cols)
        source_label = "\uC544\uC774\uD15C" if source == "item" else "\uC7A5\uBE44"
        self._status(
            "inventory.scan.start",
            source=source,
            source_label=source_label,
            grid_cols=grid_cols,
            grid_rows=grid_rows,
            total_slots=len(slots),
            profile_id=active_profile.profile_id if active_profile is not None else None,
        )
        current_scroll_amount = scroll_amount
        input_backend: InventoryGridInput | None = None
        legacy_scroll = True
        requested_backend = (input_backend_name or "legacy").strip().lower()
        if requested_backend != "legacy":
            self.log(
                f"  inventory input backend requested: {requested_backend} "
                "(experimental focus navigation)"
            )
            try:
                cursor_anchor_screen = None
                focus_anchor = None
                if slots:
                    hwnd = find_target_hwnd()
                    anchor_cx, anchor_cy = ratio_to_client(
                        rect,
                        float(slots[0].get("cx", 0.0)),
                        float(slots[0].get("cy", 0.0)),
                    )
                    if hwnd:
                        cursor_anchor_screen = client_to_screen(hwnd, anchor_cx, anchor_cy)
                        focus_anchor = (
                            lambda hwnd=hwnd, cx=anchor_cx, cy=anchor_cy:
                            click_point(hwnd, cx, cy, label="inventory_vcon_anchor", delay=0.25)
                        )
                input_backend = create_inventory_input_backend(
                    requested_backend,
                    cols=grid_cols,
                    rows=grid_rows,
                    cursor_anchor_screen=cursor_anchor_screen,
                    focus_anchor=focus_anchor,
                )
                input_backend.start()
                legacy_scroll = False
                self.log(
                    f"  inventory input backend: {input_backend.backend_name} "
                    f"(grid={grid_cols}x{grid_rows})"
                )
            except InventoryInputUnavailable as exc:
                self.log(
                    f"  inventory input backend unavailable: {requested_backend} "
                    f"({exc}) -> legacy scroll"
                )
                _log.warning("inventory input backend unavailable: %s", exc)
                input_backend = None
                legacy_scroll = True
        profile_ordered_names: list[str] = list(active_profile.ordered_names) if active_profile is not None else []
        profile_ordered_item_ids: list[str | None] = list(inventory_profile_ordered_item_ids(active_profile)) if active_profile is not None else []
        profile_index_by_name: dict[str, int] = {name: idx for idx, name in enumerate(profile_ordered_names)}
        profile_index_by_item_id: dict[str, int] = {
            item_id: idx for idx, item_id in enumerate(profile_ordered_item_ids) if item_id
        }
        profile_cursor = 0
        profile_max_unique_items = (
            INVENTORY_PROFILE_MAX_UNIQUE_ITEMS.get(active_profile.profile_id)
            if active_profile is not None
            else None
        )
        profile_slot_scan_limit = (
            min(len(slots), profile_max_unique_items)
            if input_backend is not None
            and active_profile is not None
            and profile_max_unique_items is not None
            else None
        )
        def _unique_scanned_item_count() -> int:
            return len(
                {
                    entry.item_id or entry.name
                    for entry in items
                    if entry.item_id or entry.name
                }
            )

        self.log(f"{icon} ?????????????????????????????????????????????????????????????(????{len(slots)}??")
        if active_profile is not None:
            expected_count = len(active_profile.expected_item_ids) or len(active_profile.ordered_names)
            limit_suffix = (
                f", max_unique={profile_max_unique_items}"
                if profile_max_unique_items is not None
                else ""
            )
            self.log(
                f"  inventory profile forced: {active_profile.profile_id} "
                f"({expected_count} expected{limit_suffix})"
            )
            if profile_slot_scan_limit is not None:
                self.log(f"  profile slot scan limit: {profile_slot_scan_limit}")

        def _profile_found_count() -> int:
            if active_profile is None:
                return 0
            if active_profile.expected_item_ids:
                return len(
                    {
                        entry.item_id
                        for entry in items
                        if entry.item_id in active_profile.expected_item_ids
                    }
                )
            return len(
                {
                    entry.name
                    for entry in items
                    if entry.name in set(active_profile.ordered_names)
                }
            )

        def _env_nonnegative_int(name: str, default: int) -> int:
            try:
                return max(0, int(os.environ.get(name, str(default))))
            except (TypeError, ValueError):
                return default

        def _env_float(name: str, default: float) -> float:
            try:
                return float(os.environ.get(name, str(default)))
            except (TypeError, ValueError):
                return default

        slot_count_row_gap_enabled = os.environ.get("BA_ITEM_COUNT_ROW_GAP_Y_OFFSET", "0") == "1"
        slot_count_y_offset_search_radius = _env_nonnegative_int("BA_ITEM_COUNT_Y_OFFSET_SEARCH_PX", 2)
        slot_count_color_filter_mode = os.environ.get("BA_ITEM_COUNT_COLOR_FILTER_MODE", "dark_ink")
        self._debug(f"  item slot count color filter mode: {slot_count_color_filter_mode}")
        self._inventory_motion_row_step_px = None
        grid_match_enabled = os.environ.get("BA_INVENTORY_GRID_MATCH", "1") != "0"
        grid_fast_min_score = _env_float("BA_ITEM_GRID_FAST_MIN_SCORE", 0.86)
        grid_fast_min_margin = _env_float("BA_ITEM_GRID_FAST_MIN_MARGIN", 0.09)
        grid_fast_min_count_confidence = _env_float("BA_ITEM_GRID_FAST_MIN_COUNT_CONF", 0.66)
        grid_order_hint_enabled = grid_match_enabled and os.environ.get("BA_ITEM_GRID_ORDER_HINT", "1") != "0"
        grid_order_hint_exact_min_score = _env_float("BA_ITEM_GRID_ORDER_HINT_EXACT_MIN_SCORE", 0.70)
        grid_order_hint_family_min_score = _env_float("BA_ITEM_GRID_ORDER_HINT_FAMILY_MIN_SCORE", 0.78)
        grid_order_hint_wb_min_score = _env_float("BA_ITEM_GRID_ORDER_HINT_WB_MIN_SCORE", 0.68)
        grid_order_hint_min_count_confidence = _env_float("BA_ITEM_GRID_ORDER_HINT_MIN_COUNT_CONF", 0.60)
        grid_row_anchor_hint_enabled = grid_order_hint_enabled and os.environ.get("BA_ITEM_GRID_ROW_ANCHOR_HINT", "1") != "0"
        grid_terminal_anchor_min_score = _env_float("BA_ITEM_GRID_TERMINAL_ANCHOR_MIN_SCORE", 0.55)
        self._debug(
            f"  item grid matcher: enabled={grid_match_enabled} "
            f"order_hint={grid_order_hint_enabled} row_anchor={grid_row_anchor_hint_enabled}"
        )

        def _next_profile_expected_item() -> tuple[int | None, str | None]:
            if active_profile is None or not profile_ordered_item_ids:
                return None, None
            index = max(0, profile_cursor)
            while index < len(profile_ordered_item_ids):
                item_id = profile_ordered_item_ids[index]
                name = profile_ordered_names[index] if index < len(profile_ordered_names) else None
                if item_id and (not name or name not in profile_seen_names):
                    return index, item_id
                index += 1
            return None, None

        def _school_tier_parts(item_id: str | None, prefix: str) -> tuple[str, str] | None:
            if not item_id or not item_id.startswith(prefix):
                return None
            suffix = item_id.removeprefix(prefix)
            school, sep, tier = suffix.rpartition("_")
            if not sep or not school or not tier.isdigit():
                return None
            return school, tier

        def _is_school_order_profile(profile_id: str | None) -> bool:
            return profile_id in {"tech_notes", "tactical_bd", "equipment", "student_elephs"}

        def _profile_order_relation(
            profile_id: str | None,
            expected_item_id: str | None,
            observed_item_id: str | None,
        ) -> str | None:
            if not expected_item_id or not observed_item_id:
                return None
            if expected_item_id == observed_item_id:
                return "exact"
            if profile_id == "tech_notes":
                prefix = "Item_Icon_SkillBook_"
                expected_parts = _school_tier_parts(expected_item_id, prefix)
                observed_parts = _school_tier_parts(observed_item_id, prefix)
                if expected_parts and observed_parts and expected_parts[0] == observed_parts[0]:
                    return "same_family"
                return None
            if profile_id == "tactical_bd":
                prefix = "Item_Icon_Material_ExSkill_"
                expected_parts = _school_tier_parts(expected_item_id, prefix)
                observed_parts = _school_tier_parts(observed_item_id, prefix)
                if expected_parts and observed_parts and expected_parts[0] == observed_parts[0]:
                    return "same_family"
                return None
            if profile_id != "ooparts":
                return None
            material_prefix = "Item_Icon_Material_"
            if expected_item_id.startswith(material_prefix) and observed_item_id.startswith(material_prefix):
                expected_base, _, expected_tier = expected_item_id.rpartition("_")
                observed_base, _, observed_tier = observed_item_id.rpartition("_")
                if expected_tier.isdigit() and observed_tier.isdigit() and expected_base == observed_base:
                    return "same_family"
            workbook_prefix = "Item_Icon_WorkBook_"
            if expected_item_id.startswith(workbook_prefix):
                if observed_item_id.startswith(workbook_prefix):
                    return "workbook_tail"
                return "workbook_expected"
            return None

        def _order_hint_min_score(relation: str | None) -> float:
            if relation == "exact":
                return grid_order_hint_exact_min_score
            if relation == "same_family":
                return grid_order_hint_family_min_score
            if relation in {"workbook_tail", "workbook_expected"}:
                return grid_order_hint_wb_min_score
            return 1.0

        next_scan_slot_indices: set[int] | None = None
        next_scan_y_offset_px = 0

        for scroll_i in range(MAX_SCROLLS):
            if self._stop_requested():
                break

            current_scan_slot_indices = next_scan_slot_indices
            current_scan_y_offset_px = next_scan_y_offset_px
            next_scan_slot_indices = None
            next_scan_y_offset_px = 0
            if current_scan_slot_indices is not None:
                if not current_scan_slot_indices:
                    self.log("  row-step scan window empty -> stopping")
                    break
                self.log(
                    f"  row-step scan window: "
                    f"{len(current_scan_slot_indices)}/{len(slots)} slots "
                    f"y_offset={current_scan_y_offset_px:+d}px"
                )

            img = self._capture()
            if img is None:
                break

            active_slots = _shift_slots_y(slots, current_scan_y_offset_px, img.size) if current_scan_y_offset_px else slots
            active_grid_r = _grid_region(active_slots) if current_scan_y_offset_px else grid_r
            grid_crop = crop_region(img, active_grid_r)
            cur_hash  = _img_hash(grid_crop)
            page = self._capture_inventory_page(
                img,
                active_slots,
                grid_hash=cur_hash,
                page_index=scroll_i,
                grid_cols=grid_cols,
            )

            if cur_hash in seen_hashes:
                self.log(f"  ?????????????????????????⑤벡????????????????????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷?????????????????????????嫄???????????????????????筌???????????????????????? -> ??????????????????????????????????????????({len(items)}??")
                break
            seen_hashes.append(cur_hash)
            if len(seen_hashes) > 10:
                seen_hashes.pop(0)

            new_this = 0
            page_item_ids: list[str] = []
            page_raw_names: list[str] = []
            profile_limit_reached = False
            slot_count_y_offset_hint = 0
            slot_count_row_y_offset_estimates = {}
            grid_row_anchor_state = InventoryGridRowAnchorState(
                grid_cols=grid_cols,
                enabled=bool(
                    grid_row_anchor_hint_enabled
                    and active_profile is not None
                    and _is_school_order_profile(active_profile.profile_id)
                ),
            )

            for slot_idx, (slot, slot_snap) in enumerate(zip(active_slots, page.slots)):
                if self._stop_requested():
                    break
                if current_scan_slot_indices is not None and slot_idx not in current_scan_slot_indices:
                    continue
                if not slot_count_row_gap_enabled and grid_cols > 0 and slot_idx % grid_cols == 0:
                    slot_count_y_offset_hint = 0
                if (
                    profile_slot_scan_limit is not None
                    and slot_idx >= profile_slot_scan_limit
                ):
                    self.log(
                        f"  profile slot scan limit reached: "
                        f"{slot_idx}/{profile_slot_scan_limit}"
                    )
                    profile_limit_reached = True
                    break

                icon_crop = crop_region(img, _slot_icon_region(slot))
                icon_template_item_id, icon_template_score = self._match_inventory_icon(icon_crop, source)
                icon_template_matched = icon_template_item_id is not None
                grid_template_item_id: str | None = None
                grid_template_score = 0.0
                grid_template_matched = False
                grid_count_confidence = 0.0
                grid_count_raw = ""
                detail_template_item_id: str | None = None
                detail_template_score = 0.0
                assigned_profile_idx: int | None = None
                matched_profile_name: str | None = None

                verified = None
                if source in {"item", "equipment"} and grid_match_enabled:
                    slot_crop = crop_region(img, slot)
                    slot_count_search_px = slot_count_y_offset_search_radius
                    slot_count_row_estimate = None
                    if slot_count_row_gap_enabled and grid_cols > 0:
                        slot_count_row_index = slot_idx // grid_cols
                        slot_count_row_estimate = slot_count_row_y_offset_estimates.get(slot_count_row_index)
                        if slot_count_row_estimate is None:
                            row_start = slot_count_row_index * grid_cols
                            row_end = min(len(active_slots), row_start + grid_cols)
                            row_indices = [
                                index
                                for index in range(row_start, row_end)
                                if current_scan_slot_indices is None or index in current_scan_slot_indices
                            ]
                            slot_count_row_estimate = estimate_item_slot_count_row_y_offset(
                                img,
                                [active_slots[index] for index in row_indices],
                                center=0,
                                radius=slot_count_y_offset_search_radius,
                                color_filter_tolerance_percent=1.0,
                                color_filter_mode=slot_count_color_filter_mode,
                            )
                            slot_count_row_y_offset_estimates[slot_count_row_index] = slot_count_row_estimate
                            if slot_count_row_estimate.y_offset_px is not None:
                                self._debug(
                                    f"    row count y-offset: row={slot_count_row_index + 1} "
                                    f"dy={slot_count_row_estimate.y_offset_px:+d}px "
                                    f"gap={slot_count_row_estimate.mean_bottom_gap:.2f} "
                                    f"samples={slot_count_row_estimate.sample_count} "
                                    f"conf={slot_count_row_estimate.confidence:.2f}"
                                )
                        if slot_count_row_estimate.y_offset_px is not None:
                            slot_count_y_offset_hint = slot_count_row_estimate.y_offset_px
                            slot_count_search_px = 0
                    slot_count_debug_dir = None
                    debug_count_match = None
                    if scroll_debug_dir is not None:
                        slot_count_debug_dir = (
                            scroll_debug_dir
                            / "slot_count_digits"
                            / f"page_{scroll_i + 1:02d}_slot_{slot_idx + 1:02d}"
                        )
                        debug_count_match = read_item_slot_count(
                            img,
                            slot,
                            debug_dir=slot_count_debug_dir,
                            y_offset_px=slot_count_y_offset_hint,
                            y_offset_search_px=slot_count_search_px,
                            color_filter_mode=slot_count_color_filter_mode,
                        )
                        slot_count_y_offset_hint = debug_count_match.y_offset_px
                        if (
                            debug_count_match.value is None
                            and slot_count_search_px == 0
                            and slot_count_row_estimate is not None
                            and slot_count_row_estimate.y_offset_px is not None
                            and slot_count_y_offset_search_radius > 0
                        ):
                            debug_count_match = read_item_slot_count(
                                img,
                                slot,
                                debug_dir=slot_count_debug_dir,
                                y_offset_px=slot_count_y_offset_hint,
                                y_offset_search_px=slot_count_y_offset_search_radius,
                                color_filter_mode=slot_count_color_filter_mode,
                            )
                            slot_count_y_offset_hint = debug_count_match.y_offset_px
                    grid_template_config = _inventory_grid_template_config(
                        r_sec,
                        active_profile.profile_id if active_profile is not None else None,
                    )
                    grid_tier_hint, grid_tier_confidence = detect_inventory_grid_tier_hint(
                        slot_crop,
                        grid_template_config,
                    )
                    if grid_tier_hint is not None:
                        self._status(
                            "inventory.slot.tier_hint",
                            source=source,
                            source_label=source_label,
                            slot_index=slot_idx,
                            slot_number=slot_idx + 1,
                            page_index=scroll_i + 1,
                            tier_hint=grid_tier_hint,
                            tier_confidence=round(grid_tier_confidence, 4),
                            grid_cols=grid_cols,
                            grid_rows=grid_rows,
                            total_slots=len(slots),
                            profile_id=active_profile.profile_id if active_profile is not None else None,
                        )
                    grid_catalog = _inventory_template_catalog(source)
                    if active_profile is not None and profile_index_by_item_id:
                        allowed_item_ids = set(profile_index_by_item_id)
                        grid_catalog = [
                            row for row in grid_catalog
                            if row[0] in allowed_item_ids
                        ]
                    grid_match = match_inventory_grid_template(
                        slot_crop,
                        grid_catalog,
                        grid_template_config,
                        row_anchor_state=grid_row_anchor_state,
                        slot_index=slot_idx,
                        ordered_item_ids=profile_ordered_item_ids,
                    )
                    grid_row_anchor_candidate_count = grid_match.row_anchor_candidate_count
                    grid_best_item_id = grid_match.best_item_id or grid_match.item_id
                    grid_candidate_item_id = grid_match.item_id
                    order_hint_item_id: str | None = None
                    order_hint_profile_idx: int | None = None
                    order_hint_relation: str | None = None
                    if (
                        grid_order_hint_enabled
                        and active_profile is not None
                        and grid_best_item_id is not None
                    ):
                        order_hint_profile_idx, expected_item_id = _next_profile_expected_item()
                        order_hint_relation = _profile_order_relation(
                            active_profile.profile_id,
                            expected_item_id,
                            grid_best_item_id,
                        )
                        if (
                            order_hint_relation is not None
                            and grid_match.score >= _order_hint_min_score(order_hint_relation)
                        ):
                            grid_candidate_item_id = grid_candidate_item_id or grid_best_item_id
                            order_hint_item_id = expected_item_id
                    if (
                        grid_order_hint_enabled
                        and active_profile is not None
                        and grid_best_item_id is not None
                        and not order_hint_item_id
                        and grid_row_anchor_candidate_count == 1
                        and grid_best_item_id in active_profile.terminal_item_ids
                        and grid_match.score >= grid_terminal_anchor_min_score
                    ):
                        terminal_profile_idx = profile_index_by_item_id.get(grid_best_item_id)
                        if terminal_profile_idx is not None:
                            grid_candidate_item_id = grid_candidate_item_id or grid_best_item_id
                            order_hint_item_id = grid_best_item_id
                            order_hint_profile_idx = terminal_profile_idx
                            order_hint_relation = "terminal_anchor"
                    if grid_candidate_item_id:
                        grid_profile_name = inventory_item_display_name(grid_candidate_item_id)
                        grid_profile_idx = profile_index_by_item_id.get(grid_candidate_item_id)
                        if grid_profile_idx is None and grid_profile_name:
                            grid_profile_idx = profile_index_by_name.get(grid_profile_name)
                        grid_allowed = active_profile is None or grid_profile_idx is not None
                        if not grid_allowed:
                            self._debug(
                                f"    grid template outside profile fallback: "
                                f"slot={slot_idx} item_id={grid_candidate_item_id}"
                            )
                            count_match = None
                        else:
                            count_match = debug_count_match or read_item_slot_count(
                                img,
                                slot,
                                y_offset_px=slot_count_y_offset_hint,
                                y_offset_search_px=slot_count_search_px,
                                color_filter_mode=slot_count_color_filter_mode,
                            )
                        if (
                            count_match is not None
                            and count_match.value is None
                            and debug_count_match is None
                            and slot_count_search_px == 0
                            and slot_count_row_estimate is not None
                            and slot_count_row_estimate.y_offset_px is not None
                            and slot_count_y_offset_search_radius > 0
                        ):
                            count_match = read_item_slot_count(
                                img,
                                slot,
                                y_offset_px=slot_count_y_offset_hint,
                                y_offset_search_px=slot_count_y_offset_search_radius,
                                color_filter_mode=slot_count_color_filter_mode,
                            )
                        if count_match is not None:
                            slot_count_y_offset_hint = count_match.y_offset_px
                        if count_match is not None and count_match.value is not None:
                            gate_reasons: list[str] = []
                            if grid_match.score < grid_fast_min_score:
                                gate_reasons.append(f"score<{grid_fast_min_score:.2f}")
                            if grid_match.margin < grid_fast_min_margin:
                                gate_reasons.append(f"margin<{grid_fast_min_margin:.3f}")
                            if count_match.confidence < grid_fast_min_count_confidence:
                                gate_reasons.append(f"count_conf<{grid_fast_min_count_confidence:.2f}")
                            order_hint_accepted = bool(
                                order_hint_item_id
                                and count_match.confidence >= grid_order_hint_min_count_confidence
                            )
                            tier_suffix = (
                                f" tier={grid_match.tier_hint} cand={grid_match.candidate_count}"
                                if grid_match.tier_hint is not None
                                else ""
                            )
                            anchor_suffix = (
                                f" row_anchor_candidates={grid_row_anchor_candidate_count}"
                                if grid_row_anchor_candidate_count
                                else ""
                            )
                            if gate_reasons and not order_hint_accepted:
                                self._debug(
                                    f"    grid fast gated: slot={slot_idx} item_id={grid_candidate_item_id} "
                                    f"x{count_match.value} reasons={','.join(gate_reasons)} "
                                    f"score={grid_match.score:.2f} margin={grid_match.margin:.3f} "
                                    f"count_conf={count_match.confidence:.2f} dy={count_match.y_offset_px:+d}"
                                    f"{tier_suffix}"
                                    f"{anchor_suffix}"
                                )
                            else:
                                grid_template_item_id = order_hint_item_id if order_hint_accepted else grid_candidate_item_id
                                if order_hint_accepted:
                                    assigned_profile_idx = order_hint_profile_idx
                                grid_template_score = grid_match.score
                                grid_count_confidence = count_match.confidence
                                grid_count_raw = count_match.raw
                                grid_template_matched = True
                                verified = InventoryVerification(
                                    name=None,
                                    count=count_match.value,
                                    item_id=grid_template_item_id,
                                    match_score=grid_template_score,
                                )
                                order_suffix = (
                                    f", order_hint={order_hint_relation}:{grid_best_item_id}->{grid_template_item_id}"
                                    if order_hint_accepted
                                    else ""
                                )
                                self.log(
                                    f"    grid template matched: {grid_template_item_id} "
                                    f"x{count_match.value} "
                                    f"(score={grid_match.score:.2f}, "
                                    f"margin={grid_match.margin:.3f}, "
                                    f"count_conf={count_match.confidence:.2f}, dy={count_match.y_offset_px:+d}"
                                    f"{tier_suffix}"
                                    f"{anchor_suffix}"
                                    f"{order_suffix})"
                                )
                        elif count_match is not None:
                            self._debug(
                                f"    grid count fallback: slot={slot_idx} "
                                f"reason={count_match.reason} raw={count_match.raw!r} dy={count_match.y_offset_px:+d}"
                            )
                    elif grid_match.score > 0.0:
                        best_suffix = f" item_id={grid_best_item_id}" if grid_best_item_id else ""
                        tier_suffix = (
                            f" tier={grid_match.tier_hint} cand={grid_match.candidate_count}"
                            if grid_match.tier_hint is not None
                            else ""
                        )
                        anchor_suffix = (
                            f" row_anchor_candidates={grid_row_anchor_candidate_count}"
                            if grid_row_anchor_candidate_count
                            else ""
                        )
                        self._debug(
                            f"    grid template fallback: slot={slot_idx}{best_suffix} "
                            f"best={grid_match.score:.2f} margin={grid_match.margin:.3f}"
                            f"{tier_suffix}"
                            f"{anchor_suffix}"
                        )
                used_detail_verification = verified is None
                if verified is None:
                    verified = self._verify_inventory_slot(
                        rect,
                        slot,
                        name_r,
                        count_r,
                        source,
                        profile_id=active_profile.profile_id if active_profile is not None else None,
                        input_backend=input_backend,
                        slot_index=slot_idx,
                    )
                if not verified:
                    continue
                if grid_template_matched:
                    fast_grid_entries += 1
                elif used_detail_verification:
                    detail_verified_entries += 1
                name = verified.name
                count = verified.count
                if verified.item_id:
                    if grid_template_matched and verified.item_id == grid_template_item_id:
                        pass
                    else:
                        detail_template_item_id = verified.item_id
                        detail_template_score = verified.match_score
                item_id = grid_template_item_id or detail_template_item_id or icon_template_item_id
                if not item_id:
                    self.log(f"  template unresolved skip: slot={slot_idx}")
                    continue

                row_anchor_confirmed = False
                if active_profile is not None:
                    matched_profile_name = inventory_item_display_name(item_id)
                    if not matched_profile_name and item_id in profile_index_by_name:
                        matched_profile_name = item_id
                    assigned_profile_idx = profile_index_by_item_id.get(item_id)
                    if assigned_profile_idx is None and matched_profile_name:
                        assigned_profile_idx = profile_index_by_name.get(matched_profile_name)

                    if assigned_profile_idx is None:
                        self.log(
                            f"  explicit template outside profile skip: "
                            f"slot={slot_idx} item_id={item_id}"
                        )
                        continue

                    if assigned_profile_idx > profile_cursor:
                        self.log(
                            f"  profile cursor jump: {profile_cursor} -> {assigned_profile_idx}"
                        )
                        gap_added = self._append_profile_gap_entries(
                            items,
                            seen_keys,
                            profile_seen_names,
                            active_profile,
                            profile_ordered_names,
                            profile_ordered_item_ids,
                            source,
                            profile_cursor,
                            assigned_profile_idx,
                        )
                        if gap_added:
                            profile_cursor = max(profile_cursor, assigned_profile_idx)
                    if assigned_profile_idx < len(profile_ordered_names):
                        name = profile_ordered_names[assigned_profile_idx]
                    else:
                        name = matched_profile_name
                    if (
                        assigned_profile_idx < len(profile_ordered_item_ids)
                        and profile_ordered_item_ids[assigned_profile_idx]
                    ):
                        item_id = profile_ordered_item_ids[assigned_profile_idx]
                    if grid_row_anchor_state.record_confirmed(slot_idx, assigned_profile_idx):
                        row_anchor_confirmed = True
                        row_number = slot_idx // max(1, grid_cols) + 1
                        self._debug(
                            f"    grid row anchor confirmed: "
                            f"row={row_number} "
                            f"slot={slot_idx + 1} profile_idx={assigned_profile_idx}"
                        )
                        self._status(
                            "inventory.row_anchor.confirmed",
                            source=source,
                            source_label=source_label,
                            slot_index=slot_idx,
                            slot_number=slot_idx + 1,
                            row_number=row_number,
                            page_index=scroll_i + 1,
                            item_name=name or matched_profile_name or inventory_item_display_name(item_id) or item_id,
                            item_id=item_id,
                            profile_index=assigned_profile_idx,
                            grid_cols=grid_cols,
                            grid_rows=grid_rows,
                            total_slots=len(slots),
                            profile_id=active_profile.profile_id if active_profile is not None else None,
                        )

                if not name and item_id:
                    name = inventory_item_display_name(item_id) or item_id
                if not name:
                    continue

                icon_cache[slot_snap.icon_hash] = (name, count, item_id)
                if grid_template_matched:
                    detect_source = f"grid_template({grid_template_score:.2f})"
                elif detail_template_item_id is not None:
                    detect_source = f"detail_image_template+detail({detail_template_score:.2f})"
                elif icon_template_matched:
                    detect_source = f"icon_template+detail({icon_template_score:.2f})"
                else:
                    detect_source = "detail_template"

                canonical_name = inventory_item_display_name(item_id)
                if canonical_name:
                    name = canonical_name
                elif active_profile is not None:
                    profile_name = resolve_inventory_profile_name(active_profile, name, profile_seen_names)
                    if profile_name:
                        name = profile_name
                        detect_source = f"{detect_source}+profile"
                    else:
                        duplicate_name = find_inventory_profile_duplicate(active_profile, name, profile_seen_names)
                        if duplicate_name:
                            self.log(
                                f"  duplicate profile match skipped: raw={name} "
                                f"-> {duplicate_name}"
                            )
                            continue
                if item_id:
                    page_item_ids.append(item_id)
                if name:
                    page_raw_names.append(name)

                entry = ItemEntry(
                    name=name,
                    quantity=count,
                    item_id=item_id,
                    source=source,
                    index=len(items),
                    scan_meta={
                        "status": "ok",
                        "reason": "direct_match",
                        "profile_id": active_profile.profile_id if active_profile is not None else None,
                        "profile_index": assigned_profile_idx,
                        "match_score": round(max(grid_template_score, detail_template_score, icon_template_score), 4),
                        "detect_source": detect_source,
                        "fast_grid": bool(grid_template_matched),
                        "grid_template_score": round(grid_template_score, 4) if grid_template_matched else None,
                        "grid_count_confidence": round(grid_count_confidence, 4) if grid_template_matched else None,
                        "grid_count_raw": grid_count_raw if grid_template_matched else None,
                        "roi_y_offset_px": current_scan_y_offset_px,
                        "review_required": False,
                    },
                    detail_crop=verified.detail_crop,
                    detail_name_crop=verified.detail_name_crop,
                )
                k = entry.key()
                if k not in seen_keys:
                    seen_keys.add(k)
                    items.append(entry)
                    if entry.name:
                        profile_seen_names.add(entry.name)
                        if active_profile is not None:
                            mapped_idx = profile_index_by_name.get(entry.name)
                            if mapped_idx is not None:
                                profile_cursor = max(profile_cursor, mapped_idx + 1)
                    new_this += 1
                    self.log(f"  {icon} [{len(items):>3}] {name}  x{count} ({detect_source})")
                    self._status(
                        "inventory.slot.confirmed",
                        source=source,
                        source_label=source_label,
                        slot_index=slot_idx,
                        slot_number=slot_idx + 1,
                        page_index=scroll_i + 1,
                        item_name=name,
                        quantity=count,
                        item_id=item_id,
                        row_anchor=row_anchor_confirmed,
                        grid_cols=grid_cols,
                        grid_rows=grid_rows,
                        total_slots=len(slots),
                        profile_id=active_profile.profile_id if active_profile is not None else None,
                    )
                    if (
                        profile_max_unique_items is not None
                        and _unique_scanned_item_count() >= profile_max_unique_items
                    ):
                        self.log(
                            f"  profile max unique items reached: "
                            f"{active_profile.profile_id} "
                            f"({_unique_scanned_item_count()}/{profile_max_unique_items})"
                        )
                        profile_limit_reached = True
                        break
            if active_profile is None:
                active_profile = infer_inventory_scan_profile(source, page_item_ids, page_raw_names)
                if active_profile is not None:
                    expected_count = len(active_profile.expected_item_ids) or len(active_profile.ordered_names)
                    profile_max_unique_items = INVENTORY_PROFILE_MAX_UNIQUE_ITEMS.get(
                        active_profile.profile_id
                    )
                    profile_slot_scan_limit = (
                        min(len(slots), profile_max_unique_items)
                        if input_backend is not None
                        and profile_max_unique_items is not None
                        else None
                    )
                    profile_ordered_names = list(active_profile.ordered_names)
                    profile_ordered_item_ids = list(inventory_profile_ordered_item_ids(active_profile))
                    profile_index_by_name = {name: idx for idx, name in enumerate(profile_ordered_names)}
                    profile_index_by_item_id = {
                        item_id: idx for idx, item_id in enumerate(profile_ordered_item_ids) if item_id
                    }
                    profile_cursor = 0
                    for entry in items:
                        mapped_idx = None
                        if entry.item_id:
                            mapped_idx = profile_index_by_item_id.get(entry.item_id)
                        if mapped_idx is None and entry.name:
                            mapped_idx = profile_index_by_name.get(entry.name)
                        if mapped_idx is not None:
                            profile_cursor = max(profile_cursor, mapped_idx + 1)
                    rebuilt_seen_keys: set[str] = set()
                    rebuilt_profile_names: set[str] = set()
                    for entry in items:
                        if not entry.item_id:
                            normalized_name = resolve_inventory_profile_name(
                                active_profile,
                                entry.name,
                                rebuilt_profile_names,
                            )
                            if normalized_name:
                                entry.name = normalized_name
                        if entry.name:
                            rebuilt_profile_names.add(entry.name)
                        rebuilt_seen_keys.add(entry.key())
                    seen_keys = rebuilt_seen_keys
                    profile_seen_names = rebuilt_profile_names
                    limit_suffix = (
                        f", max_unique={profile_max_unique_items}"
                        if profile_max_unique_items is not None
                        else ""
                    )
                    self.log(
                        f"  inventory profile detected: {active_profile.profile_id} "
                        f"({expected_count} expected{limit_suffix})"
                    )
                    if (
                        profile_max_unique_items is not None
                        and _unique_scanned_item_count() >= profile_max_unique_items
                    ):
                        self.log(
                            f"  profile max unique items reached: "
                            f"{active_profile.profile_id} "
                            f"({_unique_scanned_item_count()}/{profile_max_unique_items})"
                        )
                        profile_limit_reached = True

            fast_suffix = (
                f", fast_grid={fast_grid_entries}, detail={detail_verified_entries}"
                if source in {"item", "equipment"}
                else ""
            )
            self.log(
                f"  scroll {scroll_i+1}: new {new_this} / total {len(items)}"
                f"{fast_suffix}"
            )

            if profile_limit_reached:
                break
            if self._stop_requested():
                break

            if active_profile is not None:
                expected_count = len(active_profile.expected_item_ids) or len(active_profile.ordered_names)
                found_item_ids = {entry.item_id for entry in items if entry.item_id}
                found_names = {entry.name for entry in items if entry.name}
                if is_inventory_profile_complete(active_profile, found_item_ids, found_names):
                    self.log(
                        f"  profile complete: {active_profile.profile_id} "
                        f"({_profile_found_count()}/{expected_count} matched)"
                    )
                    break
                if is_inventory_profile_terminal_seen(active_profile, found_item_ids, found_names):
                    self.log(
                        f"  profile terminal reached: {active_profile.profile_id} "
                        f"({_profile_found_count()}/{expected_count} matched)"
                    )
                    break

            scroll_overlap_rows = 0
            if input_backend is not None and not legacy_scroll:
                moved, after_page = self._advance_inventory_page_with_input(
                    input_backend,
                    slots,
                    grid_r,
                    grid_cols,
                    page,
                )
            else:
                moved, after_page, current_scroll_amount, scroll_overlap_rows, next_scan_y_offset_px = self._scroll_inventory_page(
                    rect,
                    slots,
                    grid_r,
                    drag_config,
                    current_scroll_amount,
                    grid_cols,
                    scroll_index=scroll_i,
                    debug_dir=scroll_debug_dir,
                    before_y_offset_px=current_scan_y_offset_px,
                    drag_rx_offset=(
                        float(os.environ.get("BA_INVENTORY_ITEM_DRAG_RX_OFFSET", "-0.006"))
                        if source == "item"
                        else 0.0
                    ),
                )
                if (
                    moved
                    and scroll_overlap_rows <= 0
                    and os.environ.get("BA_INVENTORY_STOP_ON_NO_SCROLL_OVERLAP", "1") != "0"
                ):
                    self.log(
                        "  scroll overlap lost: no duplicated row detected after move "
                        "-> stopping inventory scan to avoid drift/user-interaction corruption"
                    )
                    break
                next_scan_slot_indices = _new_inventory_slot_indices(
                    len(slots),
                    grid_cols,
                    grid_rows,
                    scroll_overlap_rows,
                )
                if next_scan_slot_indices is None:
                    self.log(
                        f"  row-step scan window fallback: "
                        f"overlap_rows={scroll_overlap_rows} -> all slots"
                    )
                else:
                    self.log(
                        f"  row-step next scan: "
                        f"overlap_rows={scroll_overlap_rows} "
                        f"slots={len(next_scan_slot_indices)}/{len(slots)} "
                        f"y_offset={next_scan_y_offset_px:+d}px"
                    )
                self.log(f"  next drag delta_px={current_scroll_amount}")
            if after_page is None:
                break
            repeated_last_row = (
                page.last_row_hashes
                and after_page.last_row_hashes
                and page.last_row_hashes == after_page.last_row_hashes
            )
            if not moved:
                self.log(f"  scroll finished: total {len(items)}")
                break
            if repeated_last_row:
                self.log(f"  repeated last row after scroll: total {len(items)}")
                break
            self._status(
                "inventory.scroll",
                source=source,
                source_label=source_label,
                scroll_index=scroll_i + 1,
                next_page_index=scroll_i + 2,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                total_slots=len(slots),
                overlap_rows=scroll_overlap_rows,
                moved_rows=max(0, grid_rows - scroll_overlap_rows),
                scan_slots=sorted(next_scan_slot_indices) if next_scan_slot_indices is not None else None,
                y_offset_px=next_scan_y_offset_px,
            )
        if active_profile is not None:
            items = self._fill_missing_profile_entries(items, active_profile, source)
        if input_backend is not None:
            input_backend.close()
        return items

    def scan_items(
        self,
        inventory_profile_id: str | list[str] | tuple[str, ...] | None = None,
        *,
        navigate_from_menu: bool = True,
        return_to_lobby: bool = True,
    ) -> list[ItemEntry]:
        self.log("[scan] item scan start")
        self._debug(
            "item scan context: "
            f"navigate_from_menu={navigate_from_menu} "
            f"return_to_lobby={return_to_lobby} "
            f"profiles={self._item_scan_profiles(inventory_profile_id)} "
            f"icon_templates={len(_inventory_template_catalog('item'))}"
        )
        prev_forced_profile_id = self._forced_inventory_profile_id
        try:
            if navigate_from_menu:
                if not self._open_menu():
                    return []
            else:
                self.log("  using current item inventory screen")
            item_profiles = self._item_scan_profiles(inventory_profile_id)
            all_items: list[ItemEntry] = []
            sort_rule_checked = False

            for index, profile_id in enumerate(item_profiles, start=1):
                profile_label = profile_id or "all"
                self.log(f"[scan] item pass {index}/{len(item_profiles)} profile={profile_label}")
                self._forced_inventory_profile_id = profile_id
                if navigate_from_menu:
                    if not self._go_to("item_entry_button", "items"):
                        return all_items
                    if not self._wait(0.5):
                        return all_items
                if not self._prepare_item_inventory(profile_id, ensure_sort_rule=not sort_rule_checked):
                    self.log("  item inventory prepare failed; item scan stopped without lobby retry")
                    return all_items
                sort_rule_checked = True
                self._reset_inventory_scan_state("item")
                result = self._scan_grid("item", "item", ITEM_INVENTORY_DRAG, ITEM_INVENTORY_DRAG.delta_px)
                all_items.extend(result)
                self.log(f"[scan] item pass done: {len(result)} entries")
                if navigate_from_menu and index < len(item_profiles):
                    if not self._exit_inventory_to_menu():
                        return all_items

            self.log(f"[scan] item scan done: {len(all_items)} entries")
            return all_items
        except Exception as e:
            self.log(f"item scan error: {e}")
            _log.exception("item scan error")
            return []
        finally:
            self._forced_inventory_profile_id = prev_forced_profile_id
            if return_to_lobby:
                self._return_inventory_to_lobby()

    def scan_equipment(
        self,
        *,
        navigate_from_menu: bool = True,
        return_to_lobby: bool = True,
    ) -> list[ItemEntry]:
        self.log("[scan] equipment scan start")
        self._debug(
            "equipment scan context: "
            f"navigate_from_menu={navigate_from_menu} "
            f"return_to_lobby={return_to_lobby} "
            f"icon_templates={len(_inventory_template_catalog('equipment'))} "
            f"detail_templates={len(_inventory_detail_template_catalog('equipment'))}"
        )
        prev_forced_profile_id = self._forced_inventory_profile_id
        try:
            self._forced_inventory_profile_id = "equipment"
            if navigate_from_menu:
                if not self._open_menu():
                    return []
                if not self._go_to("equipment_entry_button", "equipment"):
                    return []
                if not self._wait(0.5):
                    return []
            else:
                self.log("  using current equipment inventory screen")
            if not self._prepare_equipment_inventory():
                self.log("  equipment inventory prepare failed; equipment scan stopped without lobby retry")
                return []
            self._reset_inventory_scan_state("equipment")
            result = self._scan_grid(
                "equipment",
                "equipment",
                EQUIPMENT_INVENTORY_DRAG,
                EQUIPMENT_INVENTORY_DRAG.delta_px,
            )
            self.log(f"[scan] equipment scan done: {len(result)} entries")
            return result
        except Exception as e:
            self.log(f"equipment scan error: {e}")
            _log.exception("equipment scan error")
            return []
        finally:
            self._forced_inventory_profile_id = prev_forced_profile_id
            if return_to_lobby:
                self._return_inventory_to_lobby()


    def scan_students(self) -> list[StudentEntry]:
        return self.scan_students_v5()

    def _scan_student_fields(self, entry: StudentEntry) -> bool:
        """Scan fields in dependency order so locked features can be skipped."""
        fields = {
            "student_id": entry.student_id,
            "student_name": entry.display_name,
        }
        with self._perf_step("student.fields", **fields):
            with self._perf_step("student.read_level", **fields):
                self.read_level(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_weapon_state", **fields):
                self.read_weapon_state(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_star", **fields):
                self.read_student_star(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.restore_basic_after_star", **fields):
                self._restore_basic_tab()
            if self._stop_requested():
                return False
            with self._perf_step("student.read_skills", **fields):
                self.read_skills(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_weapon", **fields):
                self.read_weapon(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_equipment", **fields):
                self.read_equipment(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_basic_combat_stats", **fields):
                self.read_basic_combat_stats(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_multi_form_combat_stats", **fields):
                self.read_multi_form_combat_stats(entry)
            self._release_student_basic_source()
            if self._stop_requested():
                return False
            with self._perf_step("student.read_stats", **fields):
                self.read_stats(entry)
        return not self._stop_requested()

    def scan_current_student(self) -> list[StudentEntry]:
        self._reset_panel_transition_history()
        self._info("[scan] current student scan start")
        self._status("session.start")
        self._emit_progress_state(current=0, total=1, note="current student scan")
        results: list[StudentEntry] = []

        try:
            with self._perf_step("student.identify", index=1, mode="current"):
                sid = self.identify_student(0)
            if sid is None:
                self._warn("student identify failed")
                self._status("student.identify.failed", index=1)
                return []

            ctx = ScanCtx(idx=1, student_id=sid)
            entry = self.begin_student_scan(sid)

            with self._perf_step("student.total", index=1, student_id=sid, student_name=entry.display_name, mode="current"):
                if not self._scan_student_fields(entry):
                    return results

                with self._perf_step("student.finalize_commit", index=1, student_id=sid, student_name=entry.display_name, mode="current"):
                    commit_result = self.finalize_student_entry(entry, ctx, partial_ok=True)
                    added = self.commit_student_entry(commit_result, results, 0)
            if added:
                self._emit_progress_state(current=1, total=1, note="current student scan")
                self._log_student(entry, 0)
                if self._asv:
                    self._asv.on_student_committed(entry)
        except Exception as e:
            _log.exception(f"????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲????????????????????????????????????????????????????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷?????????????????????????嫄???????????????????????筌??????????????????????????????????????? {e}")
            self._error(f"????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲????????????????????????????????????????????? {e}")
            if self._asv:
                partial = ScanResult(students=list(results))
                self._asv.emergency_save(partial, {})
        finally:
            self._restore_basic_tab()
            if self._asv:
                self._asv.log_stats()

        summary = f"current student scan done: total {len(results)}"
        self._emit_progress_state(current=len(results), total=1, note="current student scan done")
        self._status(
            "summary.session.done_with_counts",
            total=len(results),
            scanned=len(results),
            skipped=0,
            warnings=0,
        )
        _log.info(summary)
        self._info(f"[scan] {summary}")
        return results

    def scan_students_v5(self) -> list[StudentEntry]:
        self._reset_panel_transition_history()
        log_section(_log, "???????????????????????????????????????????????????(V6)")
        self._info("[scan] student scan start (v6)")
        self._status("session.start")
        results:       list[StudentEntry] = []
        skipped_count  = 0
        scanned_count  = 0
        self._emit_progress_state(
            current=0,
            total=self._student_total_hint,
            note="student scan",
        )

        try:
            self._status("session.first_student.enter")
            if not self._wait_for_student_detail(initial_wait=0.5, timeout=DETAIL_READY_WAIT):
                self._status("session.first_student.enter_failed")
                return []
            self._restore_basic_tab()

            seen_ids:        set[str]       = set()
            consecutive_dup: int            = 0
            prev_id:         Optional[str]  = None
            all_student_ids = tuple(student_meta.all_ids())

            for idx in range(500):
                if self._stop_requested():
                    _log.info("stop requested while scanning students; breaking loop")
                    break


                _log.debug(f"[{idx+1}] identify student")
                preferred_ids = tuple(sid for sid in all_student_ids if sid not in seen_ids)
                fallback_ids = all_student_ids if seen_ids else None
                with self._perf_step(
                    "student.identify",
                    index=idx + 1,
                    mode="v5",
                    pool=len(preferred_ids),
                    fallback_pool=len(fallback_ids or ()),
                ):
                    sid = self.identify_student(
                        idx,
                        candidate_ids=preferred_ids or None,
                        fallback_candidate_ids=fallback_ids,
                    )
                if sid is None:
                    self._warn(f"[{idx+1}] identify failed; stopping scan")
                    break


                if sid == prev_id:
                    consecutive_dup += 1
                    _log.info(
                        f"[{idx+1}] ?????????????????????????⑤벡??????????????????????? ????????????: {sid} "
                        f"({consecutive_dup}/{MAX_CONSECUTIVE_DUP})"
                    )
                    if consecutive_dup >= MAX_CONSECUTIVE_DUP:
                        _log.info("same student repeated; stopping loop")
                        self._status("student.loop.seen_before", student_id=sid, student_name=student_meta.display_name(sid))
                        self._info("  repeated student detected; stopping")
                        break
                    self._status("student.loop.duplicate", student_id=sid, student_name=student_meta.display_name(sid), count=consecutive_dup, limit=MAX_CONSECUTIVE_DUP)
                    self._wait_ui_status_flush(label=f"student:{sid}:skipped")
                    self._restore_basic_tab()
                    self.go_next_student()
                    continue

                consecutive_dup = 0
                prev_id = sid

                if sid in seen_ids:
                    _log.info(f"[{idx+1}] already scanned student {sid}; stopping")
                    self._status("student.loop.seen_before", student_id=sid, student_name=student_meta.display_name(sid))
                    self._info(f"  ?????????????????????? ???? ???????????????????????????{sid}")
                    break
                seen_ids.add(sid)




                _log.info(f"[{idx+1:>3}] ??????????????????????????????????????????????????? {sid}")
                ctx = ScanCtx(idx=idx+1, student_id=sid)

                # Create a temporary entry, then fill it step by step.
                entry = self.begin_student_scan(sid)

                with self._perf_step("student.total", index=idx + 1, student_id=sid, student_name=entry.display_name, mode="v5"):
                    # Keep going through the pipeline even if a step is missing.
                    # Each step writes into the same TEMP entry.
                    if not self._scan_student_fields(entry):
                        break

                    # Validate TEMP entry and decide COMMITTED/PARTIAL
                    with self._perf_step("student.finalize_commit", index=idx + 1, student_id=sid, student_name=entry.display_name, mode="v5"):
                        commit_result = self.finalize_student_entry(
                            entry, ctx, partial_ok=True
                        )

                        # Add the validated result unless it failed strict checks.
                        added = self.commit_student_entry(commit_result, results, idx)
                if added:
                    scanned_count += 1
                    self._emit_progress_state(
                        current=len(results),
                        total=self._student_total_hint,
            note="student scan",
                    )
                    self._log_student(entry, len(results) - 1)

                    if self._asv:
                        self._asv.on_student_committed(entry)
                    self._wait_ui_status_flush(label=f"student:{sid}")

                self._restore_basic_tab()
                with self._perf_step("student.navigate_next", index=idx + 1, student_id=sid, student_name=entry.display_name, mode="v5"):
                    self.go_next_student()

        except Exception as e:
            _log.exception(f"?????????????????????????????????????????????????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷?????????????????????????嫄???????????????????????筌??????????????????????????????????????? {e}")
            self._error(f"?????????????????????????????????????????? {e}")

            if self._asv:
                partial = ScanResult(students=list(results))
                self._asv.emergency_save(partial, {})
        finally:
            if self._asv:
                self._asv.log_stats()

        summary = (
            f"student scan done: total {len(results)} "
            f"(????????????????????{scanned_count} / ???????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷?????????????????????????嫄???????????????????????筌????{skipped_count})"
        )
        self._emit_progress_state(
            current=len(results),
            total=max(self._student_total_hint or 0, len(results)) or None,
            note="student scan",
        )
        self._status(
            "summary.session.done_with_counts",
            total=len(results),
            scanned=scanned_count,
            skipped=skipped_count,
            warnings=0,
        )
        _log.info(summary)
        self._info(f"[scan] {summary}")
        return results

    def scan_students_fast(self) -> list[StudentEntry]:
        return self.scan_students_v5()



    def _make_skipped_entry(self, student_id: str) -> StudentEntry:
        if student_id in self._maxed_saved_data:
            entry = _dict_to_student_entry(self._maxed_saved_data[student_id])
        else:
            entry = StudentEntry(
                student_id=student_id,
                display_name=student_meta.display_name(student_id),
                skipped=True,
            )

        return entry


    # Student pipeline steps




    def enter_student_menu(self) -> bool:
        self.log("  ???????????????????????????????????????..")
        self._status("session.student_menu.enter")
        btn = self.r["lobby"].get("student_menu_button")
        if not btn:
            self.log("  missing student_menu_button")
            self._status("session.student_menu.enter_failed")
            return False

        attempts = [
            btn,

        ]
        for attempt, region in enumerate(attempts, start=1):
            clicked = self._click_r(region, f"student_menu_{attempt}")
            _log.info(f"[student_menu] attempt={attempt} clicked={clicked}")
            if not clicked:
                continue
            if self._wait_for_student_menu_state(
                True,
                timeout=LOBBY_EXIT_WAIT,
                initial_wait=MENU_CLICK_SETTLE_WAIT,
            ):
                return self._wait(STUDENT_MENU_READY_SETTLE_WAIT)
            if attempt < len(attempts):
                self.log(f"  ????????????????????????????.. ({attempt+1}/{len(attempts)})")
        self._status("session.student_menu.enter_failed")
        return False

    def enter_first_student(self) -> bool:
        self.log("  ???????????????????????..")
        self._status("session.first_student.enter")
        btn = self.r["student_menu"].get("first_student_button")
        if not btn:
            self.log("  missing first_student_button")
            self._status("session.first_student.enter_failed")
            return False

        if not self._wait(FIRST_STUDENT_PRECLICK_WAIT):
            return False

        clicked = self._click_r(btn, "first_student")
        _log.info(f"[first_student] clicked={clicked}")
        if not clicked:
            self._status("session.first_student.enter_failed")
            return False
        ok = self._wait_for_student_detail(initial_wait=DETAIL_CLICK_SETTLE_WAIT)
        if not ok:
            self._status("session.first_student.enter_failed")
        return ok

    def enter_first_student_fast(self) -> bool:
        self.log("  ???????????????????????????????????????????????????...")
        self._status("session.first_student.enter")
        btn = self.r["student_menu"].get("first_student_button")
        if not btn:
            self.log("  missing first_student_button")
            self._status("session.first_student.enter_failed")
            return False
        if not self._wait(FIRST_STUDENT_PRECLICK_WAIT):
            return False
        clicked = self._click_r(btn, "first_student_fast")
        _log.info(f"[first_student_fast] clicked={clicked}")
        if not clicked:
            self._status("session.first_student.enter_failed")
            return False
        ok = self._wait_for_student_detail_fast(initial_wait=DETAIL_CLICK_SETTLE_WAIT)
        if not ok:
            self._status("session.first_student.enter_failed")
        return ok

    def go_next_student(self) -> bool:
        previous_digest = self._current_student_digest(refresh=False)
        self._invalidate_student_basic_capture()
        self._status("navigation.next.arrow")
        if self._send_student_arrow("right"):
            if previous_digest is None:
                return self._wait(DELAY_NEXT)
            if self._wait_for_student_change(previous_digest) is not None:
                return True
            self._status("navigation.next.no_change")
            self._warn("  ??????????????????????????????????????????????????????????????????????????????????????????????????????곕춴??????-> ????????????fallback")

        btn = self.r["student"].get("next_student_button")
        if not btn:
            self.log("  missing next_student_button")
            return False
        self._status("navigation.next.button_fallback")
        self._click_r(btn, "next_student")
        if previous_digest is not None:
            return self._wait_for_student_change(previous_digest) is not None
        return self._wait(DELAY_NEXT)

    def go_next_student_fast(self, previous_digest: str) -> Optional[str]:
        self._invalidate_student_basic_capture()
        self._status("navigation.next.arrow")
        if self._send_student_arrow("right"):
            next_digest = self._wait_for_student_change(previous_digest)
            if next_digest is not None:
                return next_digest
            self._status("navigation.next.no_change")
            self._warn("  ??????????????????????????????????????????????????????????????????????????????????????????????????????곕춴??????-> ????????????fallback")

        btn = self.r["student"].get("next_student_button")
        if not btn:
            self.log("  missing next_student_button")
            return None
        self._invalidate_student_basic_capture()
        self._status("navigation.next.button_fallback")
        if not self._click_r(btn, "next_student_fast"):
            return None
        return self._wait_for_student_change(previous_digest)

    def go_previous_student_fast(self, previous_digest: str) -> Optional[str]:
        self._invalidate_student_basic_capture()
        if self._send_student_arrow("left"):
            return self._wait_for_student_change(previous_digest)
        return None

    def _send_student_arrow(self, direction: str) -> bool:
        hwnd = find_target_hwnd()
        if not hwnd:
            self.log("  warning: target window missing -> arrow key skip")
            return False
        if direction == "left":
            return send_key(hwnd, VK_LEFT, key_name="left", delay=0.0)
        return send_key(hwnd, VK_RIGHT, key_name="right", delay=0.0)



    def _student_attribute_candidates(self, image: Image.Image) -> tuple[list[str], dict[str, str]]:
        """Read stable basic-card labels and return their metadata intersection."""
        regions = self.r.get("student", {})
        attributes: dict[str, str] = {}
        for field in ("attack_type", "defense_type", "position", "combat_class", "role"):
            region_key = f"basic_attribute_{field}"
            region = regions.get(region_key)
            if region is None:
                continue
            prepared = self._get_student_basic_region(region_key)
            crop = prepared.image if prepared is not None else crop_region(image, region)
            result = read_basic_student_attribute_result(crop, field)
            if result.value is not None and not result.uncertain:
                attributes[field] = str(result.value)
            _log.debug(
                "student attribute: field=%s value=%s score=%.3f uncertain=%s label=%s",
                field, result.value, result.score, result.uncertain, result.label,
            )

        # Three fields already reduce the average pool below six. Requiring at
        # least three prevents a broad or weak label from bloating the union.
        candidates = student_meta.ids_matching_attributes(attributes)
        if len(attributes) < 3 or not (1 <= len(candidates) <= 32):
            _log.info(
                "student attribute guard disabled: fields=%s pool=%d",
                attributes, len(candidates),
            )
            return [], attributes
        _log.info(
            "student attribute guard: fields=%s pool=%d candidates=%s",
            attributes, len(candidates), " ".join(candidates),
        )
        return candidates, attributes


    def identify_student(
        self,
        idx: int = 0,
        *,
        candidate_ids: Iterable[str] | None = None,
        fallback_candidate_ids: Iterable[str] | None = None,
    ) -> Optional[str]:
        """Identify the current student from the portrait texture region."""
        sr = self.r["student"]
        texture_r = sr.get("student_texture_region")
        ctx = ScanCtx(idx=idx + 1, step="identify")
        self._status("student.identify.start", index=idx + 1)

        if not texture_r:
            _log.warning(f"{ctx} student_texture_region missing -> cannot identify")
            self._status("student.identify.failed", index=idx + 1)
            return None

        def _try() -> Optional[str]:
            img = self._get_student_basic_capture(refresh=True)
            if img is None:
                return None
            crop = crop_region(img, texture_r)
            attribute_candidates, _attributes = self._student_attribute_candidates(img)
            sid, score = match_student_texture(
                crop,
                candidate_ids=candidate_ids,
                fallback_candidate_ids=fallback_candidate_ids,
                injected_candidate_ids=attribute_candidates,
            )
            if sid is not None:
                _log.info(
                    f"{ctx} ?????????????????????????????????????????????????????????????????????????????ㅻ깹???????????? {student_meta.display_name(sid)} "
                    f"(score={score:.3f})"
                )
                self._info(
                    f"  ??????????????????[{idx+1}] {student_meta.display_name(sid)} (score={score:.3f})"
                )
                self._status(
                    "student.identify.success",
                    index=idx + 1,
                    student_id=sid,
                    student_name=student_meta.display_name(sid),
                    technical=f"score={score:.3f}",
                )
                return sid

            _log.debug(f"{ctx} ?????????????????????????????????????????????????????????????????????????????????????????????곕춴??????(score={score:.3f})")
            dump_roi(crop, "identify_fail", score=score, reason="below_thresh")
            if self._asv:
                self._asv.on_step_error("identify")
            self._status("student.identify.retry", index=idx + 1, technical=f"score={score:.3f}")
            self._warn(f"[{idx+1}] ?????????????????????????????????????????????????????????????????????????????????????????????곕춴??????(score={score:.3f})")
            return None

        sid = self._retry(_try, max_attempts=RETRY_IDENTIFY, delay=0.6, label="identify student")
        if sid is not None or idx != 0:
            if sid is None:
                self._status("student.identify.failed", index=idx + 1)
            return sid

        _log.warning(f"{ctx} first student identify failed; trying recovery")
        self._warn(f"[{idx+1}] first student identify failed; trying recovery")
        if not self._recover_first_student_entry():
            self._status("student.identify.failed", index=idx + 1)
            return None
        self._restore_basic_tab()
        self._invalidate_student_basic_capture()
        sid = self._retry(_try, max_attempts=RETRY_IDENTIFY, delay=0.6, label="identify student after recovery")
        if sid is None:
            self._status("student.identify.failed", index=idx + 1)
        return sid



    def _read_skills_from_basic(self, entry: StudentEntry, img: Image.Image) -> bool:
        sr = self.r["student"]
        staged: dict[str, tuple[Optional[int], FieldMeta]] = {}
        specs = (
            ("ex_skill", "basic_EX_skill", True, None),
            ("skill1", "basic_Skill_1", False, None),
            ("skill2", "basic_Skill_2", False, SKILL2_UNLOCK_STAR),
            ("skill3", "basic_Skill_3", False, SKILL3_UNLOCK_STAR),
        )
        for field_name, region_key, is_ex, unlock_star in specs:
            if (
                unlock_star is not None
                and entry.student_star is not None
                and entry.student_star < unlock_star
            ):
                staged[field_name] = (None, FieldMeta.skipped("star_locked"))
                continue
            region = sr.get(region_key)
            if region is None:
                _log.debug("basic skill region missing: %s", region_key)
                return False
            prepared = self._get_student_basic_region(region_key)
            skill_crop = prepared.image if prepared is not None else crop_region(img, region)
            result = read_basic_skill_result(skill_crop, is_ex=is_ex)
            if result.value is None or result.uncertain:
                _log.info(
                    "[basic_skill] fallback student=%s field=%s value=%s score=%.3f label=%s",
                    entry.student_id,
                    field_name,
                    result.value,
                    result.score,
                    result.label,
                )
                return False
            staged[field_name] = (
                int(result.value),
                FieldMeta.ok(FieldSource.TEMPLATE, score=result.score),
            )

        for field_name, (value, meta) in staged.items():
            setattr(entry, field_name, value)
            entry.set_meta(field_name, meta)
            if value is None and field_name == "skill2":
                self._status("skills.skill2.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
            elif value is None and field_name == "skill3":
                self._status("skills.skill3.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
            else:
                self._status_skill_value(entry, field_name, value)
        self.log(
            f"  ?????????????????????????????????? EX={entry.ex_skill} "
            f"S1={entry.skill1} S2={entry.skill2} S3={entry.skill3}"
        )
        self._status(
            "skills.basic.success",
            student_name=entry.display_name,
            ex=entry.ex_skill,
            s1=entry.skill1,
            s2=entry.skill2,
            s3=entry.skill3,
        )
        self._status(
            "skills.summary",
            student_name=entry.display_name,
            ex=entry.ex_skill,
            s1=entry.skill1,
            s2=entry.skill2,
            s3=entry.skill3,
        )
        return True

    def read_skills(self, entry: StudentEntry) -> None:
        """Read the skill panel from a single capture and fill skill fields."""
        ctx = ScanCtx(student_id=entry.student_id, step="read_skills")
        self._status("skills.start", student_name=entry.display_name)
        basic_img = self._get_student_basic_capture()
        if basic_img is not None and self._read_skills_from_basic(entry, basic_img):
            return
        self._status("skills.basic.fallback", student_name=entry.display_name)
        self.log("  basic skill scan unavailable -> opening skill menu")

        self._active_student_panel = "skill"
        img = self._click_student_region_and_wait(
            "skill_menu_button",
            "skill_menu_button",
            lambda capture: self._is_student_panel_title_capture(capture, "skill"),
            timeout=ADDITIONAL_PANEL_READY_WAIT,
        )
        if img is None:
            _log.warning(f"{ctx} skill menu open failed")
            self._esc()
            return

        sr      = self.r["student"]
        check_r = sr.get("skill_all_view_check_region")

        if check_r:
            if read_skill_check(crop_region(img, check_r)) == CheckFlag.FALSE:
                self.log("  enabling all skill view")
                self._click_r(check_r, "skill_check")
                if not self._wait(0.3):
                    self._esc()
                    return
                img = self._capture()
                if img is None:
                    _log.warning(f"{ctx} skill menu capture failed")
                    self._esc()
                    return

        for field_name, region_key, tmpl_key in [
            ("ex_skill", "EX_skill", "EX_Skill"),
            ("skill1",   "Skill_1",  "Skill1"),
            ("skill2",   "Skill_2",  "Skill2"),
            ("skill3",   "Skill_3",  "Skill3"),
        ]:
            if field_name == "skill2" and entry.student_star is not None and entry.student_star < SKILL2_UNLOCK_STAR:
                entry.skill2 = None
                entry.set_meta("skill2", FieldMeta.skipped("star_locked"))
                self._status("skills.skill2.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
                self.log(f"  {entry.student_star} star -> Skill2 locked")
                continue
            if field_name == "skill3" and entry.student_star is not None and entry.student_star < SKILL3_UNLOCK_STAR:
                entry.skill3 = None
                entry.set_meta("skill3", FieldMeta.skipped("star_locked"))
                self._status("skills.skill3.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
                self.log(f"  {entry.student_star} star -> Skill3 locked")
                continue
            region = sr.get(region_key)
            if region is None:
                _log.warning(f"{ctx.with_step(field_name)} region missing -> skip")
                entry.set_meta(field_name, FieldMeta.region_missing(region_key))
                continue
            crop = crop_region(img, region)
            raw  = read_skill(crop, tmpl_key)
            try:
                setattr(entry, field_name, int(raw))
                entry.set_meta(field_name, FieldMeta.ok(FieldSource.TEMPLATE))
                self._status_skill_value(entry, field_name, getattr(entry, field_name))
            except (TypeError, ValueError):
                _log.debug(f"{ctx.with_step(field_name)} ????????????????????????⑤벡??????????????????????????????????곕춴??????(raw={raw!r})")
                dump_roi(crop, f"skill_{field_name}", reason="convert_fail")
                setattr(entry, field_name, None)
                entry.set_meta(field_name,
                               FieldMeta.failed(FieldSource.TEMPLATE,
                                                note=f"raw={raw!r}"))
                if self._asv:
                    self._asv.on_step_error("read_skills", entry.student_id or "")

        self.log(
            f"  ????????????????? EX={entry.ex_skill} "
            f"S1={entry.skill1} S2={entry.skill2} S3={entry.skill3}"
        )
        self._status(
            "skills.summary",
            student_name=entry.display_name,
            ex=entry.ex_skill,
            s1=entry.skill1,
            s2=entry.skill2,
            s3=entry.skill3,
        )
        self._close_student_panel(
            capture_name="skill_close_button",
            region_key="skillmenu_quit_button",
            settle_reason="close_skill_menu",
        )



    def read_weapon_state(self, entry: StudentEntry) -> None:
        """Read only the weapon unlock/equipped state from the basic tab."""
        ctx      = ScanCtx(student_id=entry.student_id, step="read_weapon")
        self._status("weapon_state.start", student_name=entry.display_name)
        img = self._get_student_basic_capture()
        if img is None:
            entry.weapon_state = WeaponState.NO_WEAPON_SYSTEM
            entry.set_meta("weapon_state", FieldMeta.failed(FieldSource.TEMPLATE, "capture_fail"))
            return

        sr       = self.r["student"]
        weapon_button_r = sr.get("weapon_info_menu_button")
        if weapon_button_r:
            prepared_button = self._get_student_basic_region("weapon_info_menu_button")
            button_img = prepared_button.image if prepared_button is not None else img
            button_region = prepared_button.region if prepared_button is not None else weapon_button_r
            active_ratio = self._active_blue_button_ratio(button_img, button_region, "weapon growth button")
            is_active = active_ratio >= EQUIPMENT_GROWTH_ACTIVE_BLUE_MIN_RATIO
            if is_active:
                entry.weapon_state = WeaponState.WEAPON_EQUIPPED
                entry.set_meta("weapon_state", FieldMeta.ok(FieldSource.TEMPLATE, score=active_ratio))
                self._status(
                    "weapon_state.equipped",
                    student_name=entry.display_name,
                    technical=f"button_blue_ratio={active_ratio:.3f}",
                )
                self.log(f"  ?????????????????????????????????????????? WEAPON_EQUIPPED (button_blue_ratio={active_ratio:.3f})")
                return
            entry.weapon_state = WeaponState.NO_WEAPON_SYSTEM
            entry.set_meta("weapon_state", FieldMeta.ok(FieldSource.TEMPLATE, score=1.0 - active_ratio))
            self._status(
                "weapon_state.no_system",
                student_name=entry.display_name,
                technical=f"button_blue_ratio={active_ratio:.3f}",
            )
            self.log(f"  ?????????????????????????????????????????? NO_WEAPON_SYSTEM (button_blue_ratio={active_ratio:.3f})")
            return

        weapon_r = sr.get("weapon_detect_flag_region") or sr.get("weapon_unlocked_flag")
        if not weapon_r:
            entry.weapon_state = WeaponState.NO_WEAPON_SYSTEM
            entry.set_meta("weapon_state", FieldMeta.region_missing("weapon_info_menu_button"))
            return

        state, score = detect_weapon_state(crop_region(img, weapon_r))
        entry.weapon_state = state

        if score < 0.60:
            entry.set_meta("weapon_state",
                           FieldMeta.uncertain(FieldSource.TEMPLATE, score=score,
                                               note=state.value))
            self._status("weapon_state.uncertain", student_name=entry.display_name, state=state.name, technical=f"score={score:.3f}")
            _log.warning(f"{ctx} ??????????????????????????????????????????????????????????(score={score:.3f}, {state.name})")
        else:
            entry.set_meta("weapon_state",
                           FieldMeta.ok(FieldSource.TEMPLATE, score=score))
            if state == WeaponState.WEAPON_EQUIPPED:
                self._status("weapon_state.equipped", student_name=entry.display_name, technical=f"score={score:.3f}")
            elif state == WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED:
                self._status("weapon_state.unlocked_not_equipped", student_name=entry.display_name, technical=f"score={score:.3f}")
            else:
                self._status("weapon_state.no_system", student_name=entry.display_name, technical=f"score={score:.3f}")
        self.log(f"  ?????????????????????????????????????????? {state.name} (score={score:.3f})")


    def read_weapon(self, entry: StudentEntry) -> None:
        """Read weapon detail when the weapon system is unlocked/equipped."""
        self._status("weapon.start", student_name=entry.display_name)

        if entry.weapon_state is None:
            self.read_weapon_state(entry)

        if entry.student_star is not None and entry.student_star < WEAPON_UNLOCK_STAR:
            entry.weapon_star = None
            entry.weapon_level = None
            entry.set_meta("weapon_star", FieldMeta.skipped("star_locked"))
            entry.set_meta("weapon_level", FieldMeta.skipped("star_locked"))
            self._status("weapon.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
            self.log(f"  {entry.student_star} star -> weapon locked")
            return

        state = entry.weapon_state
        if state is None:
            entry.set_meta("weapon_star", FieldMeta.skipped("weapon_state_missing"))
            entry.set_meta("weapon_level", FieldMeta.skipped("weapon_state_missing"))
            return
        weapon_meta = entry.get_meta("weapon_state")
        weapon_state_confirmed = (
            weapon_meta is not None
            and weapon_meta.status == FieldStatus.OK
        )
        if state == WeaponState.WEAPON_EQUIPPED and not weapon_state_confirmed:
            entry.weapon_star = None
            entry.weapon_level = None
            entry.set_meta("weapon_star", FieldMeta.skipped("weapon_state_uncertain"))
            entry.set_meta("weapon_level", FieldMeta.skipped("weapon_state_uncertain"))
            self._status("weapon.skip_state_uncertain", student_name=entry.display_name)
            self.log("  weapon button inactive -> weapon scan skipped")
            return
        if state == WeaponState.NO_WEAPON_SYSTEM:
            entry.weapon_star = None
            entry.weapon_level = None
            entry.set_meta("weapon_star", FieldMeta.skipped("no_weapon_system"))
            entry.set_meta("weapon_level", FieldMeta.skipped("no_weapon_system"))
            self._status("weapon.skip_no_system", student_name=entry.display_name)
            return

        if state == WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED:
            entry.weapon_star  = None
            entry.weapon_level = None
            entry.set_meta("weapon_star",  FieldMeta.skipped("not_equipped"))
            entry.set_meta("weapon_level", FieldMeta.skipped("not_equipped"))
            self._status("weapon.skip_not_equipped", student_name=entry.display_name)
            self.log("  basic weapon read unavailable -> opening weapon menu")
            return

        sr = self.r["student"]
        basic_img = self._get_student_basic_capture()
        basic_level_r = sr.get("basic_weapon_level_digits_quad")
        basic_star_r = sr.get("basic_weapon_star_region")
        prepared_level = self._get_student_basic_region("basic_weapon_level_digits_quad")
        prepared_star = self._get_student_basic_region("basic_weapon_star_region")
        if basic_img is not None and basic_level_r is not None and basic_star_r is not None:
            level_img = prepared_level.image if prepared_level is not None else basic_img
            level_region = prepared_level.region if prepared_level is not None else basic_level_r
            star_crop = prepared_star.image if prepared_star is not None else crop_region(basic_img, basic_star_r)
            basic_level = read_basic_weapon_level_result(level_img, level_region)
            basic_star = read_basic_weapon_star_result(star_crop)
            if (
                basic_level.value is not None
                and not basic_level.uncertain
                and basic_star.value is not None
                and not basic_star.uncertain
            ):
                entry.weapon_level = int(basic_level.value)
                entry.weapon_star = int(basic_star.value)
                entry.set_meta(
                    "weapon_level",
                    FieldMeta(
                        status=FieldStatus.OK,
                        source=FieldSource.TEMPLATE,
                        score=basic_level.score,
                        note="basic_info",
                    ),
                )
                entry.set_meta(
                    "weapon_star",
                    FieldMeta(
                        status=FieldStatus.OK,
                        source=FieldSource.TEMPLATE,
                        score=basic_star.score,
                        note="basic_info",
                    ),
                )
                self._status(
                    "weapon.basic_fast_success",
                    student_name=entry.display_name,
                    star=entry.weapon_star,
                    level=entry.weapon_level,
                )
                self._field_confirmed(entry, "weapon_star", entry.weapon_star, display_value=f"{entry.weapon_star} stars")
                self._field_confirmed(entry, "weapon_level", entry.weapon_level, display_value=f"Lv.{entry.weapon_level}")
                self.log(
                    f"  ?????????????????????????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲??????????????????????????????????????????????????? {entry.weapon_star}??Lv.{entry.weapon_level} "
                    f"(level={basic_level.score:.3f}, star={basic_star.score:.3f})"
                )
                return
            self._status("weapon.basic_fast_fallback", student_name=entry.display_name)
            self.log(
                "  ?????????????????????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲??????????????????????????????????????????????????????-> ????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲???????????????????????????????????????????????????????????????????????????????ㅻ깹??????????????????????????"
                f"(level={basic_level.value}/{basic_level.score:.3f}, "
                f"star={basic_star.value}/{basic_star.score:.3f})"
            )

        self._active_student_panel = "weapon"
        img = self._click_student_region_and_wait(
            "weapon_info_menu_button",
            "weapon_info_menu",
            lambda capture: self._is_student_panel_title_capture(capture, "weapon"),
            timeout=ADDITIONAL_PANEL_READY_WAIT,
        )
        if img is None:
            self.log("  missing weapon_info_menu_button")
            entry.weapon_star = None
            entry.weapon_level = None
            entry.set_meta("weapon_star", FieldMeta.failed(FieldSource.TEMPLATE, "panel_not_detected"))
            entry.set_meta("weapon_level", FieldMeta.failed(FieldSource.TEMPLATE, "panel_not_detected"))
            self._esc()
            return

        star_r = sr.get("weapon_star_region")
        if star_r:
            from core.matcher import read_weapon_star_v5_result
            rs = read_weapon_star_v5_result(crop_region(img, star_r))
            entry.weapon_star = rs.value
            entry.set_meta("weapon_star",
                           FieldMeta.ok(FieldSource.TEMPLATE, score=rs.score)
                           if not rs.uncertain
                           else FieldMeta.uncertain(FieldSource.TEMPLATE,
                                                    score=rs.score))
        else:
            entry.set_meta("weapon_star", FieldMeta.region_missing("weapon_star_region"))

        d1 = sr.get("weapon_level_digit_1") or sr.get("weapon_level_digit1")
        d2 = sr.get("weapon_level_digit_2") or sr.get("weapon_level_digit2")
        if d1 and d2:
            entry.weapon_level = read_weapon_level(img, d1, d2)
            for _ in range(2):
                if entry.weapon_level is not None:
                    break
                if not self._wait(WEAPON_CAPTURE_RETRY_WAIT):
                    break
                retry_img = self._capture()
                if retry_img is None:
                    break
                retry_level = read_weapon_level(retry_img, d1, d2)
                if retry_level is not None:
                    img = retry_img
                    entry.weapon_level = retry_level
                    break
            entry.set_meta("weapon_level",
                           FieldMeta.ok(FieldSource.TEMPLATE)
                           if entry.weapon_level is not None
                           else FieldMeta.failed(FieldSource.TEMPLATE, "digit_read_fail"))
            self.log(f"  ????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲????????????????????????????????? {entry.weapon_star}??Lv.{entry.weapon_level}")
            self._status(
                "weapon.summary",
                student_name=entry.display_name,
                star=entry.weapon_star,
                level=entry.weapon_level,
            )
            self._field_confirmed(entry, "weapon_star", entry.weapon_star, display_value=f"{entry.weapon_star} stars")
            self._field_confirmed(entry, "weapon_level", entry.weapon_level, display_value=f"Lv.{entry.weapon_level}")
        else:
            self.log("  missing weapon_level_digit")
            entry.set_meta("weapon_level", FieldMeta.region_missing("weapon_level_digit"))

        self._close_student_panel(
            capture_name="weapon_close_button",
            region_key="weapon_menu_quit_button",
            settle_reason="close_weapon_menu",
        )



    def read_equipment(self, entry: StudentEntry) -> None:
        """Read equipment state and slots from the equipment menu."""
        self._status("equipment.start", student_name=entry.display_name)


        sid       = entry.student_id or ""
        favorite_supported = student_meta.favorite_item_enabled(sid)
        if not favorite_supported and entry.equip4 is None:
            self._mark_favorite_item_unsupported(entry, sid)

        slots_to_scan = {1, 2, 3}
        if entry.level is not None and entry.level < EQUIP2_UNLOCK_LEVEL:
            entry.equip2 = EquipSlotFlag.LEVEL_LOCKED.value
            entry.equip2_level = None
            entry.set_meta("equip2", FieldMeta.skipped("level_locked"))
            entry.set_meta("equip2_level", FieldMeta.skipped("level_locked"))
            self._status("equip2.skip_level_locked_from_level", student_name=entry.display_name, level=entry.level)
            slots_to_scan.discard(2)
        if entry.level is not None and entry.level < EQUIP3_UNLOCK_LEVEL:
            entry.equip3 = EquipSlotFlag.LEVEL_LOCKED.value
            entry.equip3_level = None
            entry.set_meta("equip3", FieldMeta.skipped("level_locked"))
            entry.set_meta("equip3_level", FieldMeta.skipped("level_locked"))
            self._status("equip3.skip_level_locked_from_level", student_name=entry.display_name, level=entry.level)
            slots_to_scan.discard(3)

        sr        = self.r["student"]
        equip_btn = sr.get("equipment_button")
        if not equip_btn:
            self.log("  missing equipment_button")



        img = self._get_student_basic_capture()
        if img is None:
            return
        basic_img = img
        growth_button_active = self._equipment_growth_button_active(img, equip_btn)
        self._status(
            "equipment.button.active" if growth_button_active else "equipment.button.inactive",
            student_name=entry.display_name,
        )
        favorite_scan_needed = favorite_supported
        favorite_dot_present = (
            favorite_scan_needed
            and self._basic_equipment_empty_dot_present(img, 4)
        )
        if favorite_scan_needed:
            if favorite_dot_present:
                entry.equip4 = EquipSlotFlag.EMPTY.value
                entry.set_meta("equip4", FieldMeta.skipped("basic_empty_dot"))
                favorite_scan_needed = False
                self._status("favorite.basic_empty_dot", student_name=entry.display_name)
                self.log("  equipment: basic read unavailable -> opening equipment menu")
            elif not growth_button_active:
                entry.equip4 = EquipSlotFlag.LOVE_LOCKED.value
                entry.set_meta("equip4", FieldMeta.skipped("growth_button_off_no_dot_love_locked"))
                favorite_scan_needed = False
                self._status("favorite.slot_flag.love_locked", student_name=entry.display_name)
                self.log("  equipment: growth button inactive with empty slots -> infer locked")
        self._apply_basic_equipment_hints(
            entry,
            img,
            slots_to_scan,
            include_favorite=favorite_scan_needed,
            growth_button_active=growth_button_active,
        )
        for slot in sorted(tuple(slots_to_scan)):
            if self._read_basic_equipment_slot(entry, basic_img, sr, slot):
                slots_to_scan.discard(slot)
        if favorite_scan_needed and entry.equip4 is None:
            favorite_region = sr.get("basic_favorite_tier_region")
            if favorite_region:
                favorite_result = read_basic_favorite_tier_result(basic_img, favorite_region)
                _log.debug(
                    "basic favorite: value=%s score=%.3f uncertain=%s label=%s",
                    favorite_result.value,
                    favorite_result.score,
                    favorite_result.uncertain,
                    favorite_result.label,
                )
                if favorite_result.value in ("T1", "T2") and not favorite_result.uncertain:
                    entry.equip4 = str(favorite_result.value)
                    entry.set_meta(
                        "equip4",
                        FieldMeta(
                            status=FieldStatus.OK,
                            source=FieldSource.TEMPLATE,
                            score=favorite_result.score,
                            note="basic_info_marker",
                        ),
                    )
                    self._status(
                        "favorite.tier.t1" if entry.equip4 == "T1" else "favorite.tier.t2",
                        student_name=entry.display_name,
                        tier=entry.equip4,
                    )
                    self._field_confirmed(entry, "equip4", entry.equip4)
                    self.log(f"  ???? ????????? {entry.equip4} (?????????????????????????????????????????????됰Ŧ?????????轅붽틓????곌램?뽳쭕????????????????????????????룸ı???嶺뚮슣??쮼??????????????????????ㅻ깹?????????ㅻ깹??????????????????????????????關?쒎첎?嫄??怨몃룯?????")
        favorite_scan_needed = favorite_supported and entry.equip4 is None

        pre = read_equip_check(crop_region(img, equip_btn))
        if not slots_to_scan and not favorite_scan_needed:
            return

        if pre == CheckFlag.IMPOSSIBLE:
            self.log("  equipment growth button impossible on basic screen; opening menu")

        self._active_student_panel = "equipment"
        img = self._click_student_region_and_wait(
            "equipment_button",
            "equipment_tab",
            lambda capture: self._is_student_panel_title_capture(capture, "equipment"),
            timeout=ADDITIONAL_PANEL_READY_WAIT,
        )
        if img is None:
            self._esc()
            return

        check_r = sr.get("equipment_all_view_check_region")
        if check_r:
            check_state = read_equip_check_inside(crop_region(img, check_r))
            if check_state == CheckFlag.FALSE and self._wait(EQUIP_CHECK_RETRY_WAIT):
                retry_img = self._capture()
                if retry_img is not None:
                    img = retry_img
                    check_state = read_equip_check_inside(crop_region(img, check_r))
            if check_state == CheckFlag.FALSE:
                self.log("  equipment all-view checkbox is off; enabling it")
                if self._click_r(check_r, "equipment_all_view_check") and self._wait(0.45):
                    retry_img = self._capture()
                    if retry_img is not None:
                        img = retry_img
                        check_state = read_equip_check_inside(crop_region(img, check_r))
            if check_state == CheckFlag.FALSE:
                _log.warning(f"{entry.label()} equipment all-view checkbox remained off; continuing with visible slots")

        equipment_crop_keys = tuple(
            key for key in sr
            if key.startswith("equipment_") or key.startswith("equip")
        )
        self._student_equipment_crops = ScreenCropSet.from_image(
            img,
            sr,
            keys=equipment_crop_keys,
        )

        # Slots 1-3 share the same equipment-menu capture.
        for slot in sorted(slots_to_scan):
            skip_flags = {EquipSlotFlag.EMPTY}
            if slot in (2, 3):
                skip_flags.add(EquipSlotFlag.LEVEL_LOCKED)
            self._scan_equip_slot(entry, img, sr, slot,
                                  skip_flags=skip_flags, scan_level=True)
            self._learn_basic_equipment_slot(entry, basic_img, sr, slot)

        if slots_to_scan and all(getattr(entry, f"equip{slot}") in (None, "unknown") for slot in slots_to_scan):
            _log.warning(f"{entry.label()} equipment capture unstable -> retry once")
            if self._wait(0.35):
                retry_img = self._capture()
                if retry_img is not None:
                    img = retry_img
                    for slot in sorted(slots_to_scan):
                        skip_flags = {EquipSlotFlag.EMPTY}
                        if slot in (2, 3):
                            skip_flags.add(EquipSlotFlag.LEVEL_LOCKED)
                        self._scan_equip_slot(entry, img, sr, slot,
                                              skip_flags=skip_flags, scan_level=True)
                        self._learn_basic_equipment_slot(entry, basic_img, sr, slot)

        # ????4
        if favorite_supported:
            self._status("favorite.start", student_name=entry.display_name)
            self._scan_equip_slot(
                entry, img, sr, 4,
                skip_flags={EquipSlotFlag.EMPTY,
                            EquipSlotFlag.LOVE_LOCKED,
                            EquipSlotFlag.NULL},
                scan_level=False,
            )
        else:
            self._mark_favorite_item_unsupported(entry, sid)

        self._close_student_panel(
            capture_name="equipment_close_button",
            region_key="equipmentmenu_quit_button",
            settle_reason="close_equipment_menu",
        )

    def _scan_equip_slot(
        self,
        entry: StudentEntry,
        img: Image.Image,
        sr: dict,
        slot: int,
        skip_flags: set[EquipSlotFlag],
        scan_level: bool,
    ) -> None:
        """Scan one equipment slot from a shared equipment-menu capture."""
        equip_key = f"equip{slot}"
        level_key = f"equip{slot}_level"

        flag_r = (sr.get(f"equip{slot}_flag")
                  or sr.get(f"equip{slot}_emptyflag")
                  or sr.get(f"equip{slot}_empty_flag"))
        if flag_r:
            slot_flag = read_equip_slot_flag(crop_region(img, flag_r), slot)
            if slot_flag in skip_flags:
                self.log(f"  equipment{slot}: {slot_flag.value} -> skipped")
                setattr(entry, equip_key, slot_flag.value)
                entry.set_meta(equip_key,
                               FieldMeta.skipped(f"slot_flag={slot_flag.value}"))
                if scan_level:
                    entry.set_meta(level_key,
                                   FieldMeta.skipped(f"slot_flag={slot_flag.value}"))
                if slot == 2 and slot_flag == EquipSlotFlag.EMPTY:
                    self._status("equip2.slot_flag.empty", student_name=entry.display_name)
                elif slot == 2 and slot_flag == EquipSlotFlag.LEVEL_LOCKED:
                    self._status("equip2.slot_flag.level_locked", student_name=entry.display_name)
                elif slot == 3 and slot_flag == EquipSlotFlag.EMPTY:
                    self._status("equip3.slot_flag.empty", student_name=entry.display_name)
                elif slot == 3 and slot_flag == EquipSlotFlag.LEVEL_LOCKED:
                    self._status("equip3.slot_flag.level_locked", student_name=entry.display_name)
                elif slot == 4 and slot_flag == EquipSlotFlag.EMPTY:
                    self._status("favorite.slot_flag.empty", student_name=entry.display_name)
                elif slot == 4 and slot_flag == EquipSlotFlag.LOVE_LOCKED:
                    self._status("favorite.slot_flag.love_locked", student_name=entry.display_name)
                elif slot == 4 and slot_flag == EquipSlotFlag.NULL:
                    self._status("favorite.slot_flag.null", student_name=entry.display_name)
                return

        tier_r = sr.get(f"equipment_{slot}")
        tier_candidates: list[tuple[str, float]] = []
        if tier_r:
            tier_crop = crop_region(img, tier_r)
            tier_candidates = rank_equip_tier_candidates(tier_crop, slot)
            _log.debug(
                f"equip{slot} tier: "
                + " ".join(f"{t}={s:.3f}" for t, s in tier_candidates)
            )
        else:
            entry.set_meta(equip_key, FieldMeta.region_missing(f"equipment_{slot}"))

        lv: int | None = None
        if scan_level:
            d1 = sr.get(f"equipment_{slot}_level_digit_1")
            d2 = sr.get(f"equipment_{slot}_level_digit_2")
            if d1 and d2:
                lv = read_equip_level(
                    img,
                    slot,
                    d1,
                    d2,
                    getattr(self, "_equip_level_run_templates", None),
                )
                setattr(entry, level_key, lv)
                entry.set_meta(level_key,
                               FieldMeta.ok(FieldSource.TEMPLATE)
                               if lv is not None
                               else FieldMeta.failed(FieldSource.TEMPLATE,
                                                     "digit_read_fail"))
                self.log(f"  equipment{slot} level: {lv}")
                if lv is not None:
                    self._status(f"equip{slot}.level.ok", student_name=entry.display_name, level=lv)
                    self._field_confirmed(entry, f"equip{slot}_level", lv, display_value=f"Lv.{lv}")
            else:
                self.log(f"  missing equipment_{slot}_level_digit")
                entry.set_meta(level_key,
                               FieldMeta.region_missing(f"equipment_{slot}_level_digit"))

        if tier_r:
            tier = "unknown"
            tier_score = 0.0
            if tier_candidates:
                tier, tier_score = tier_candidates[0]
                if tier_score < EQUIP_TIER_ACCEPT_SCORE:
                    if (
                        scan_level
                        and lv == MAX_EQUIP_LEVEL
                        and tier == "T10"
                        and tier_score >= EQUIP_T10_LEVEL70_FALLBACK_SCORE
                    ):
                        entry.set_meta(
                            equip_key,
                            FieldMeta(
                                status=FieldStatus.INFERRED,
                                source=FieldSource.INFERRED,
                                score=tier_score,
                                note="level70_implies_t10",
                            ),
                        )
                    else:
                        tier = "unknown"
                        entry.set_meta(
                            equip_key,
                            FieldMeta.uncertain(
                                FieldSource.TEMPLATE,
                                score=tier_score,
                                note="tier=unknown",
                            ),
                        )
                else:
                    entry.set_meta(equip_key, FieldMeta.ok(FieldSource.TEMPLATE, score=tier_score))
            else:
                entry.set_meta(equip_key, FieldMeta.uncertain(FieldSource.TEMPLATE, note="tier=unknown"))
            setattr(entry, equip_key, tier)
            self.log(f"  equipment{slot} tier: {tier}")
            if tier != "unknown":
                if slot == 4:
                    if tier == "T1":
                        self._status("favorite.tier.t1", student_name=entry.display_name, tier=tier)
                        self._field_confirmed(entry, "equip4", tier)
                    elif tier == "T2":
                        self._status("favorite.tier.t2", student_name=entry.display_name, tier=tier)
                        self._field_confirmed(entry, "equip4", tier)
                else:
                    self._status(f"equip{slot}.tier.ok", student_name=entry.display_name, tier=tier)
                    self._field_confirmed(entry, f"equip{slot}", tier)

    def _learn_basic_level_for_run(
        self,
        image: Image.Image,
        region: dict,
        level: int,
    ) -> bool:
        digits = str(level)
        glyphs, has_second_digit = extract_basic_student_level_glyphs(image, region)
        detected_count = 2 if has_second_digit else 1
        if len(digits) != detected_count or len(glyphs) != len(digits):
            _log.info(
                "[basic_level_calibration] rejected level=%s detected_digits=%d glyphs=%d",
                level,
                detected_count,
                len(glyphs),
            )
            return False

        learned = 0
        for position, (digit, glyph) in enumerate(zip(digits, glyphs)):
            position_templates = self._basic_level_run_templates.setdefault(position, {})
            variants = position_templates.setdefault(digit, [])
            variants.append(glyph.copy())
            del variants[:-4]
            learned += 1
        total = sum(
            len(variants)
            for position_templates in self._basic_level_run_templates.values()
            for variants in position_templates.values()
        )
        _log.info(
            "[basic_level_calibration] learned level=%s digits=%s samples_added=%d total=%d",
            level,
            digits,
            learned,
            total,
        )
        return True


    def read_level(self, entry: StudentEntry) -> None:
        """Read the student level tab and parse the level digits."""
        ctx = ScanCtx(student_id=entry.student_id, step="read_level")
        self._status("level.start", student_name=entry.display_name)
        sr = self.r["student"]
        basic_region = sr.get("basic_level_digits_quad")
        basic_img = self._get_student_basic_capture()
        prepared_level = self._get_student_basic_region("basic_level_digits_quad")
        if basic_img is not None and basic_region is not None:
            level_img = prepared_level.image if prepared_level is not None else basic_img
            level_region = prepared_level.region if prepared_level is not None else basic_region
            basic_result = read_basic_student_level_result(
                level_img,
                level_region,
                self._basic_level_run_templates,
            )
            if basic_result.value is not None and not basic_result.uncertain:
                entry.level = int(basic_result.value)
                entry.set_meta("level", FieldMeta.ok(FieldSource.TEMPLATE, score=basic_result.score))
                self._status("level.read.ok", student_name=entry.display_name, level=entry.level)
                self._field_confirmed(entry, "level", entry.level, display_value=f"Lv.{entry.level}")
                _log.info(
                    "[basic_level] success student=%s value=%s score=%.3f label=%s",
                    entry.student_id,
                    entry.level,
                    basic_result.score,
                    basic_result.label,
                )
                self.log(
                    f"  ??????????????????????????????? {entry.label()} -> Lv.{entry.level} "
                    f"(score={basic_result.score:.3f})"
                )
                return
            _log.info(
                "[basic_level] fallback student=%s value=%s score=%.3f label=%s",
                entry.student_id,
                basic_result.value,
                basic_result.score,
                basic_result.label,
            )

        img = self._click_student_region_and_wait(
            "levelcheck_button",
            "levelcheck_button",
            self._is_level_tab_on_capture,
            timeout=TAB_ON_READY_WAIT,
            fallback_delay=0.5,
        )
        if img is None:
            _log.warning(f"{ctx} level tab capture failed")
            entry.set_meta("level", FieldMeta.failed(FieldSource.TEMPLATE, "tab_fail"))
            return

        d1 = sr.get("level_digit_1")
        d2 = sr.get("level_digit_2")
        if not d1 or not d2:
            _log.warning(f"{ctx} missing level_digit region")
            self._restore_basic_tab()
            entry.set_meta("level", FieldMeta.region_missing("level_digit"))
            return

        lv = read_student_level_v5(img, d1, d2)
        for _ in range(2):
            if lv is not None:
                break
            if not self._wait(LEVEL_CAPTURE_RETRY_WAIT):
                break
            retry_img = self._capture()
            if retry_img is None:
                break
            retry_level = read_student_level_v5(retry_img, d1, d2)
            if retry_level is not None:
                img = retry_img
                lv = retry_level
                break
        entry.level = lv

        if lv is not None:
            entry.set_meta("level", FieldMeta.ok(FieldSource.TEMPLATE))
            self._status("level.read.ok", student_name=entry.display_name, level=lv)
            self._field_confirmed(entry, "level", lv, display_value=f"Lv.{lv}")
            self.log(f"  ?????????????? {entry.label()} -> Lv.{lv}")
            if basic_img is not None and basic_region is not None:
                self._learn_basic_level_for_run(basic_img, basic_region, lv)
        else:
            entry.set_meta("level", FieldMeta.failed(FieldSource.TEMPLATE, "digit_read_fail"))
            self._status("level.read.failed", student_name=entry.display_name)
            _log.warning(f"{ctx} level digit read failed")
            if self._asv:
                self._asv.on_step_error("read_level", entry.student_id or "")

        self._restore_basic_tab()



    def read_student_star(self, entry: StudentEntry) -> None:
        """Read the student's star count, or infer it from weapon unlock state."""
        self._status("star.start", student_name=entry.display_name)


        ctx = ScanCtx(student_id=entry.student_id, step="read_student_star")

        weapon_meta = entry.get_meta("weapon_state")
        weapon_state_confirmed = (
            weapon_meta is not None
            and weapon_meta.status == FieldStatus.OK
        )
        can_infer_from_weapon = (
            weapon_state_confirmed
            and entry.weapon_state in (
                WeaponState.WEAPON_EQUIPPED,
                WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED,
            )
        )
        if can_infer_from_weapon:
            # Students with a weapon system unlocked are guaranteed to be 5-star.
            entry.student_star = 5
            entry.set_meta("student_star",
                           FieldMeta.inferred("weapon_state implies student star 5"))
            self._status("star.infer_from_weapon", student_name=entry.display_name, star=5)
            self._field_confirmed(entry, "student_star", 5, display_value="5 stars")
            self.log("  ????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲???????????????????????????????????????????????????????⑤벡????????? ??????-> ????????????????????????????????????????(5????????????????????")
            return
        if entry.weapon_state == WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED:
            self.log("  weapon state implies 5-star -> skipping star menu scan")

        sr = self.r["student"]
        basic_region = sr.get("basic_student_stars_quad")
        basic_img = self._get_student_basic_capture()
        prepared_star = self._get_student_basic_region("basic_student_stars_quad")
        if basic_img is not None and basic_region is not None:
            star_img = prepared_star.image if prepared_star is not None else basic_img
            star_region = prepared_star.region if prepared_star is not None else basic_region
            basic_result = read_basic_student_star_result(star_img, star_region)
            if basic_result.value is not None and not basic_result.uncertain:
                entry.student_star = int(basic_result.value)
                entry.set_meta(
                    "student_star",
                    FieldMeta.ok(FieldSource.TEMPLATE, score=basic_result.score),
                )
                self._status(
                    "star.read.ok",
                    student_name=entry.display_name,
                    star=entry.student_star,
                )
                self._field_confirmed(entry, "student_star", entry.student_star, display_value=f"{entry.student_star} stars")
                _log.info(
                    "[basic_star] success student=%s value=%s score=%.3f label=%s",
                    entry.student_id,
                    entry.student_star,
                    basic_result.score,
                    basic_result.label,
                )
                self.log(
                    f"  ????????????????????????? {entry.label()} -> {entry.student_star}??"
                    f"(score={basic_result.score:.3f})"
                )
                return
            _log.info(
                "[basic_star] fallback student=%s value=%s score=%.3f label=%s",
                entry.student_id,
                basic_result.value,
                basic_result.score,
                basic_result.label,
            )

        img = self._click_student_region_and_wait(
            "star_menu_button",
            "star_menu",
            self._is_star_tab_on_capture,
            timeout=TAB_ON_READY_WAIT,
            fallback_delay=0.3,
        )
        if img is None:
            entry.set_meta("student_star",
                           FieldMeta.failed(FieldSource.TEMPLATE, "capture_fail"))
            return

        region_key = (
            "student_star_region"
            if "student_star_region" in sr
            else "star_region"
        )
        star_r = sr.get(region_key)
        if not star_r:
            entry.set_meta("student_star",
                           FieldMeta.region_missing(region_key))
            return

        from core.matcher import read_student_star_v5_result
        r = read_student_star_v5_result(crop_region(img, star_r))

        entry.student_star = r.value
        if r.uncertain or r.value is None:
            entry.set_meta("student_star",
                           FieldMeta.uncertain(FieldSource.TEMPLATE,
                                               score=r.score,
                                               note=f"value={r.value}"))
            self._status("star.read.uncertain", student_name=entry.display_name, star=r.value, technical=f"score={r.score:.3f}")
            _log.warning(f"{ctx} ????????????????????????????????????(score={r.score:.3f} val={r.value})")
        else:
            entry.set_meta("student_star",
                           FieldMeta.ok(FieldSource.TEMPLATE, score=r.score))
            self._status("star.read.ok", student_name=entry.display_name, star=entry.student_star)
            self._field_confirmed(entry, "student_star", entry.student_star, display_value=f"{entry.student_star} stars")
            self.log(f"  ???????? {entry.label()} -> {entry.student_star}??(score={r.score:.3f})")



    def _student_form_template_candidates(self, student_id: str, form_index: int) -> list[Path]:
        template_names: list[str] = []
        configured = student_meta.field_for_form(student_id, "template_name", form_index)
        if configured:
            template_names.append(str(configured))
        base_name = student_meta.template_path(student_id)
        if form_index == 1:
            template_names.append(base_name)
        else:
            base = Path(base_name)
            suffix = base.suffix or ".png"
            template_names.append(f"{base.stem}_{form_index - 1}{suffix}")
            template_names.append(f"{student_id}_{form_index - 1}.png")
        seen: set[str] = set()
        paths: list[Path] = []
        for template_name in template_names:
            if not template_name or template_name in seen:
                continue
            seen.add(template_name)
            path = TEMPLATE_DIR / "students" / template_name
            if path.exists():
                paths.append(path)
        return paths

    def _match_current_student_form_by_template(self, student_id: str, image: Image.Image) -> int | None:
        texture_r = self.r.get("student", {}).get("student_texture_region")
        if not texture_r:
            return None
        crop = crop_region(image, texture_r)
        scores: list[tuple[int, float, str]] = []
        for form_index in student_meta.form_indexes(student_id):
            form_scores = [
                match_score_resized(crop, str(path))
                for path in self._student_form_template_candidates(student_id, form_index)
            ]
            if form_scores:
                best_score = max(form_scores)
                scores.append((form_index, best_score, str(form_scores)))
        if not scores:
            return None
        scores.sort(key=lambda item: item[1], reverse=True)
        best_form, best_score, _detail = scores[0]
        second_score = scores[1][1] if len(scores) > 1 else 0.0
        margin = best_score - second_score
        _log.debug(
            "multi-form template: student=%s best=%s score=%.3f margin=%.3f all=%s",
            student_id,
            best_form,
            best_score,
            margin,
            " ".join(f"{form}({score:.3f})" for form, score, _ in scores),
        )
        if best_score >= 0.60 and margin >= 0.025:
            return student_meta.normalize_form_index(student_id, best_form)
        return None

    def _match_current_student_form_by_attributes(self, student_id: str, image: Image.Image) -> int:
        regions = self.r.get("student", {})
        attributes: dict[str, str] = {}
        for field in ("attack_type", "defense_type", "position", "combat_class", "role"):
            region_key = f"basic_attribute_{field}"
            region = regions.get(region_key)
            if region is None:
                continue
            crop = crop_region(image, region)
            result = read_basic_student_attribute_result(crop, field)
            if result.value is not None and not result.uncertain:
                attributes[field] = str(result.value)
        best_form = 1
        best_score = -1
        for form_index in student_meta.form_indexes(student_id):
            score = 0
            for field, detected in attributes.items():
                expected = student_meta.field_for_form(student_id, field, form_index)
                if expected is not None and str(expected) == detected:
                    score += 1
            if score > best_score:
                best_score = score
                best_form = form_index
        _log.debug("multi-form attribute: student=%s form=%s score=%s attrs=%s", student_id, best_form, best_score, attributes)
        return student_meta.normalize_form_index(student_id, best_form)

    def _current_student_form_index(self, student_id: str) -> int:
        if not student_meta.is_multi_form(student_id):
            return 1
        image = self._get_student_basic_capture(refresh=True)
        if image is None:
            return 1
        template_form = self._match_current_student_form_by_template(student_id, image)
        if template_form is not None:
            return template_form
        return self._match_current_student_form_by_attributes(student_id, image)

    def _student_form_region(self, form_index: int) -> Optional[dict]:
        regions = self.r.get("student", {})
        return regions.get(f"style_form_{form_index}_button") or regions.get(f"student_form_{form_index}_button")

    def _switch_student_form(self, form_index: int) -> bool:
        region = self._student_form_region(form_index)
        if not region:
            self.log(f"  form {form_index} switch region missing")
            return False
        self._invalidate_student_basic_capture()
        if not self._click_r(region, f"student_form_{form_index}"):
            return False
        return self._settle_student_detail(f"student_form_{form_index}", initial_wait=0.35, timeout=2.0, poll=0.15)

    def _copy_combat_stats_from_entry(self, source: StudentEntry, target: StudentEntry) -> None:
        for field_name in _COMBAT_STAT_FIELDS:
            setattr(target, field_name, getattr(source, field_name, None))
            meta = source.get_meta(field_name)
            if meta is not None:
                target.set_meta(field_name, meta)

    def read_multi_form_combat_stats(self, entry: StudentEntry) -> None:
        student_id = entry.student_id or ""
        if not student_meta.is_multi_form(student_id):
            return
        current_form = self._current_student_form_index(student_id)
        _store_entry_form_combat_stats(entry, current_form)
        other_forms = [form for form in student_meta.form_indexes(student_id) if form != current_form]
        if not other_forms:
            return
        original_stats = _entry_combat_stats(entry)
        original_meta = {field_name: entry.get_meta(field_name) for field_name in _COMBAT_STAT_FIELDS}
        for form_index in other_forms:
            if self._stop_requested():
                break
            if not self._switch_student_form(form_index):
                continue
            self._status("student.form.switch", student_id=entry.student_id, student_name=entry.display_name, form_index=form_index)
            probe = StudentEntry(student_id=entry.student_id, display_name=entry.display_name)
            self.read_basic_combat_stats(probe)
            _store_entry_form_combat_stats(probe, form_index)
            if str(form_index) in probe.form_combat_stats:
                entry.form_combat_stats[str(form_index)] = probe.form_combat_stats[str(form_index)]
                self.log(f"  form {form_index} combat stats saved: {entry.form_combat_stats[str(form_index)]}")
        for field_name, value in original_stats.items():
            setattr(entry, field_name, value)
        for field_name, meta in original_meta.items():
            if meta is not None:
                entry.set_meta(field_name, meta)
        if current_form != student_meta.normalize_form_index(student_id, current_form):
            current_form = student_meta.normalize_form_index(student_id, current_form)
        if other_forms and current_form in student_meta.form_indexes(student_id):
            if self._switch_student_form(current_form):
                self._status("student.form.switch", student_id=entry.student_id, student_name=entry.display_name, form_index=current_form)

    def read_basic_combat_stats(self, entry: StudentEntry) -> None:
        """Read basic-screen combat values and additional-stat badge presence."""
        image = self._get_student_basic_capture()
        if image is None:
            return
        regions = self.r.get("student", {})
        from core.matcher import (
            read_basic_additional_stat_badge_result,
            read_basic_additional_stat_value_result,
            read_basic_combat_stat_result,
        )

        combat_details: dict[str, str] = {}
        for stat_key, field_name in (
            ("hp", "combat_hp"),
            ("atk", "combat_atk"),
            ("def", "combat_def"),
            ("heal", "combat_heal"),
        ):
            region_key = f"basic_combat_{stat_key}_digits"
            region = regions.get(region_key)
            if not region:
                entry.set_meta(field_name, FieldMeta.region_missing(region_key))
                continue
            result = read_basic_combat_stat_result(image, region)
            combat_details[stat_key] = result.label
            setattr(entry, field_name, result.value)
            if result.value is None or result.uncertain:
                entry.set_meta(field_name, FieldMeta.uncertain(
                    FieldSource.TEMPLATE, score=result.score, note=result.label
                ))
            else:
                entry.set_meta(field_name, FieldMeta.ok(FieldSource.TEMPLATE, score=result.score))
                self._field_confirmed(entry, field_name, result.value)

        badges: dict[str, Optional[bool]] = {}
        additional_values: dict[str, Optional[int]] = {}
        for stat_key in ("hp", "atk", "heal"):
            region_key = f"basic_additional_badge_{stat_key}"
            region = regions.get(region_key)
            if not region:
                badges[stat_key] = None
                additional_values[stat_key] = None
                continue
            result = read_basic_additional_stat_badge_result(image, region)
            badge_present = result.value if not result.uncertain else None
            badges[stat_key] = badge_present
            if badge_present is True:
                value_result = read_basic_additional_stat_value_result(image, region)
                additional_values[stat_key] = (
                    int(value_result.value)
                    if value_result.value is not None and not value_result.uncertain
                    else None
                )
                combat_details[f"additional_{stat_key}"] = value_result.label
            elif badge_present is False:
                additional_values[stat_key] = 0
            else:
                additional_values[stat_key] = None
        entry._basic_additional_badges = badges
        entry._basic_additional_values = additional_values
        _log.debug("basic combat recognition details: %s", combat_details)
        self.log(
            f"  basic stats: HP={entry.combat_hp} ATK={entry.combat_atk} "
            f"DEF={entry.combat_def} HEAL={entry.combat_heal} "
            f"badges={badges} additional={additional_values}"
        )

    def read_stats(self, entry: StudentEntry) -> None:
        """
        Lv.90 + 5??????????????????????????????????????????????????????????????????????????????????????
        ??????????????????????????????????ㅻ깹??????????????????????????????????????????????????????????????????????????HP / ATK / HEAL ??????????????????????????????????????
        """
        self._status("stats.start", student_name=entry.display_name)
        level_ok = entry.level is not None and entry.level >= STAT_UNLOCK_LEVEL
        star_ok  = entry.student_star is not None and entry.student_star >= STAT_UNLOCK_STAR

        if not level_ok or not star_ok:
            self.log(
                f"  ??????????????????????????????????????????????????????????"
                f"(Lv.{entry.level} / {entry.student_star}??"
            )
            self._status("stats.skip_condition", student_name=entry.display_name, level=entry.level, star=entry.student_star)
            return

        badges = getattr(entry, "_basic_additional_badges", {})
        additional_values = getattr(entry, "_basic_additional_values", {})
        stat_pairs = (("hp", "stat_hp"), ("atk", "stat_atk"), ("heal", "stat_heal"))
        confirmed_basic_stats: dict[str, int] = {}
        for stat_key, _field_name in stat_pairs:
            if stat_key in additional_values and additional_values.get(stat_key) is not None:
                confirmed_basic_stats[stat_key] = int(additional_values[stat_key] or 0)
            elif badges.get(stat_key) is False:
                confirmed_basic_stats[stat_key] = 0

        if len(confirmed_basic_stats) == len(stat_pairs):
            for stat_key, field_name in stat_pairs:
                value = confirmed_basic_stats[stat_key]
                setattr(entry, field_name, value)
                if badges.get(stat_key) is False:
                    entry.set_meta(field_name, FieldMeta.inferred("basic_screen_badge_absent"))
                else:
                    entry.set_meta(field_name, FieldMeta.ok(FieldSource.TEMPLATE))
            self._status(
                "stats.basic_values_skip",
                student_name=entry.display_name,
                hp=entry.stat_hp,
                atk=entry.stat_atk,
                heal=entry.stat_heal,
            )
            self._field_confirmed(entry, "stat_hp", entry.stat_hp)
            self._field_confirmed(entry, "stat_atk", entry.stat_atk)
            self._field_confirmed(entry, "stat_heal", entry.stat_heal)
            self.log(
                "  basic screen additional stats confirmed -> "
                f"stat menu skipped ({entry.stat_hp}/{entry.stat_atk}/{entry.stat_heal})"
            )
            return

        self._active_student_panel = "stat"
        img = self._click_student_region_and_wait(
            "stat_menu_button",
            "stat_menu_button",
            lambda capture: self._is_student_panel_title_capture(capture, "stat"),
            timeout=ADDITIONAL_PANEL_READY_WAIT,
            fallback_delay=0.4,
            match_delay=STAT_PANEL_MATCH_DELAY,
        )
        if img is None:
            self._esc()
            return

        ctx = ScanCtx(student_id=entry.student_id, step="read_stats")

        sr = self.r["student"]
        self._student_stat_crops = ScreenCropSet.from_image(
            img,
            sr,
            keys=("hp", "atk", "heal"),
        )
        for stat_key, field_name, region_key in [
            ("hp",   "stat_hp",   "hp"),
            ("atk",  "stat_atk",  "atk"),
            ("heal", "stat_heal", "heal"),
        ]:
            region = sr.get(region_key)
            if not region:
                _log.warning(f"{ctx.with_step(field_name)} missing region")
                entry.set_meta(field_name, FieldMeta.region_missing(region_key))
                continue

            from core.matcher import read_stat_value_result
            prepared = self._student_stat_crops.get(region_key)
            stat_crop = prepared.image if prepared is not None else crop_region(img, region)
            r = read_stat_value_result(stat_crop, stat_key)
            setattr(entry, field_name, r.value)

            if r.value is None or r.uncertain:
                entry.set_meta(field_name,
                               FieldMeta.uncertain(FieldSource.TEMPLATE,
                                                   score=r.score,
                                                   note=f"val={r.value}"))
                _log.warning(f"{ctx.with_step(field_name)} basic combat stat uncertain "
                             f"(score={r.score:.3f} val={r.value})")
            else:
                entry.set_meta(field_name,
                               FieldMeta.ok(FieldSource.TEMPLATE, score=r.score))
                self._field_confirmed(entry, field_name, r.value)

        self.log(
            f"  ???????????????????? HP={entry.stat_hp} "
            f"ATK={entry.stat_atk} HEAL={entry.stat_heal}"
        )
        self._status(
            "stats.summary",
            student_name=entry.display_name,
            hp=entry.stat_hp,
            atk=entry.stat_atk,
            heal=entry.stat_heal,
        )
        self._close_student_panel(
            capture_name="stat_close_button",
            region_key="statmenu_quit_button",
            settle_reason="close_stat_menu",
        )



    def _log_student(self, entry: StudentEntry, idx: int) -> None:
        weapon_info = ""
        if entry.weapon_state == WeaponState.WEAPON_EQUIPPED:
            weapon_info = f" | ???????????????????????????????{entry.weapon_star}???????????????????{entry.weapon_level}"
        elif entry.weapon_state == WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED:
            weapon_info = " | weapon:not-equipped"

        equip_info = (
            f"{entry.equip1}(Lv.{entry.equip1_level})/"

            f"{entry.equip3}(Lv.{entry.equip3_level})/"
            f"{entry.equip4}"
        )
        self.log(
            f"  [{idx+1:>3}] {entry.label()}  Lv.{entry.level}  "
            f"{entry.student_star}*{weapon_info}  "
            f"EX:{entry.ex_skill} S1:{entry.skill1} "
            f"S2:{entry.skill2} S3:{entry.skill3}  "
            f"equip:{equip_info}  "
            f"stats(HP:{entry.stat_hp}/ATK:{entry.stat_atk}/HEAL:{entry.stat_heal})"
        )
        self._status(
            "summary.student.compact",
            student_name=entry.display_name,
            level=entry.level,
            star=entry.student_star,
        )


        # Emit a compact summary for uncertain / failed / inferred fields.
        uncertain = entry.uncertain_fields()
        failed    = entry.failed_fields()
        inferred  = [k for k, v in entry._meta.items()
                     if v.status == FieldStatus.INFERRED]

        if uncertain:
            _log.warning(
                f"  [{idx+1:>3}] {entry.label()} "
                f"-> uncertain: {uncertain}"
            )
        if failed:
            _log.warning(
                f"  [{idx+1:>3}] {entry.label()} "
                f"-> failed: {failed}"
            )
        if inferred:
            _log.info(
                f"  [{idx+1:>3}] {entry.label()} "
                f"-> inferred: {inferred}"
            )



    def run_full_scan(self) -> ScanResult:
        self.clear_stop()
        result = ScanResult()
        self.log("[scan] full scan start")
        result.resources = self.scan_resources()
        result.items     = self.scan_items()
        if not self._stop_requested():
            result.equipment = self.scan_equipment()
        if not self._stop_requested():
            result.students  = self.scan_students()
        self.log("[scan] full scan done")
        return result

