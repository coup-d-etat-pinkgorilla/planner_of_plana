"""
Student scanning pipeline for BA Analyzer v6.

This module coordinates student navigation, recognition, and data collection.
Broken legacy comments and UI strings were cleaned up for readability.
"""

import ctypes
import os
import sys
import time
import types
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
    _digit_region,
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
_ASSET_REGION_CAPTURE_DIR = ASSET_DIR / "debug" / "region_captures"
REGION_CAPTURE_DIR = _ASSET_REGION_CAPTURE_DIR if _ASSET_REGION_CAPTURE_DIR.exists() else BASE_DIR / "debug" / "region_captures"
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
    "presents": 76,
    "equipment": 110,
}
INVENTORY_NO_SCROLL_PROFILES = frozenset({
    "activity_reports",
})
INVENTORY_PROFILE_SLOT_SCAN_LIMITS = {
    "activity_reports": 4,
}
INVENTORY_ANCHOR_MATCH_ENV = "BA_INVENTORY_ANCHOR_MATCH"
INVENTORY_DIRECT_ICON_MATCH_ENV = "BA_INVENTORY_DIRECT_ICON_MATCH"
INVENTORY_GRID_ORDER_HINT_PROFILES = frozenset({
    "tech_notes",
    "tactical_bd",
    "equipment",
    "student_elephs",
    "ooparts",
    "presents",
})
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


INVENTORY_SCROLL_RESIDUAL_SETTLE_WAIT = 0.28
INVENTORY_SCROLL_RESIDUAL_MIN_SCORE = 0.82
INVENTORY_SCROLL_NEAR_ZERO_VERIFY_WAIT = 0.30
INVENTORY_SCROLL_NEAR_ZERO_EXPECTED_BAND_RATIO = 0.28
INVENTORY_SCROLL_NEAR_ZERO_EXPECTED_MIN_SCORE = 0.70
INVENTORY_SCROLL_NEAR_ZERO_EXPECTED_MAX_SCORE_GAP = 0.12


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


def _inventory_anchor_scan_order(
    total_slots: int,
    grid_cols: int,
    grid_rows: int,
    scan_indices: set[int] | None = None,
) -> list[int]:
    if total_slots <= 0:
        return []
    allowed = set(range(total_slots)) if scan_indices is None else {idx for idx in scan_indices if 0 <= idx < total_slots}
    if grid_cols <= 0 or grid_rows <= 0:
        return [idx for idx in range(total_slots) if idx in allowed]
    anchor_col = min(4, grid_cols - 1)
    ordered: list[int] = []
    seen: set[int] = set()

    def add_slot(idx: int) -> None:
        if idx < total_slots and idx in allowed and idx not in seen:
            ordered.append(idx)
            seen.add(idx)

    for row in range(grid_rows):
        row_start = row * grid_cols
        row_end = min(total_slots, row_start + grid_cols)
        if row_start >= total_slots:
            break
        anchor_idx = row_start + anchor_col
        if anchor_idx >= row_end:
            anchor_idx = row_end - 1
        add_slot(anchor_idx)
        for idx in range(row_start, row_end):
            add_slot(idx)

    for idx in range(total_slots):
        add_slot(idx)
    return ordered


def _carried_inventory_anchor_indices(
    confirmed_profile_indices: dict[int, int],
    total_slots: int,
    grid_cols: int,
    grid_rows: int,
    overlap_rows: int,
) -> dict[int, int]:
    if not confirmed_profile_indices or total_slots <= 0 or grid_cols <= 0 or grid_rows <= 0:
        return {}
    carried_rows = max(0, min(grid_rows, overlap_rows))
    if carried_rows <= 0:
        return {}
    old_start = max(0, (grid_rows - carried_rows) * grid_cols)
    carried_limit = min(total_slots, old_start + carried_rows * grid_cols)
    carried: dict[int, int] = {}
    for old_slot_idx, profile_idx in confirmed_profile_indices.items():
        if old_start <= old_slot_idx < carried_limit:
            carried[old_slot_idx - old_start] = profile_idx
    return carried

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


def _target_gray_mask_for_inventory_patch(
    image: Image.Image,
    box: tuple[int, int, int, int],
    *,
    target_rgb: tuple[int, int, int] = (0xC4, 0xCF, 0xD4),
    tolerance: int = 14,
) -> np.ndarray | None:
    x1, y1, x2, y2 = box
    if x2 <= x1 + 1 or y2 <= y1 + 1:
        return None
    arr = np.asarray(image.crop((x1, y1, x2, y2)).convert("RGB"), dtype=np.float32)
    if arr.size == 0:
        return None
    target = np.asarray(target_rgb, dtype=np.float32).reshape((1, 1, 3))
    diff = np.abs(arr - target)
    return (np.max(diff, axis=2) <= float(tolerance)).astype(np.float32)


def _region_box_px(region: dict, image_size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = image_size
    return (
        max(0, min(width, int(round(float(region["x1"]) * width)))),
        max(0, min(height, int(round(float(region["y1"]) * height)))),
        max(0, min(width, int(round(float(region["x2"]) * width)))),
        max(0, min(height, int(round(float(region["y2"]) * height)))),
    )


def _inventory_region_gray_score(image: Image.Image, region: dict, *, tolerance: int = 14) -> float:
    mask = _target_gray_mask_for_inventory_patch(
        image,
        _region_box_px(region, image.size),
        tolerance=tolerance,
    )
    if mask is None or mask.size == 0:
        return 0.0
    return float(mask.mean())


def _slot_relative_region(slot: dict, left: float, top: float, right: float, bottom: float) -> dict:
    width = float(slot["x2"]) - float(slot["x1"])
    height = float(slot["y2"]) - float(slot["y1"])
    return {
        "x1": float(slot["x1"]) + width * left,
        "y1": float(slot["y1"]) + height * top,
        "x2": float(slot["x1"]) + width * right,
        "y2": float(slot["y1"]) + height * bottom,
    }


def _inventory_gray_band_target_height_px(slots: list[dict]) -> int:
    row_centers = {round(float(slot.get("cy", 0.0)), 5) for slot in slots}
    return 1050 if len(row_centers) >= 5 else 870


def _inventory_gray_band_scan_region(
    slots: list[dict],
    image_size: tuple[int, int],
    *,
    target_width_px: int = 1150,
    target_height_px: int | None = None,
) -> dict:
    grid = _grid_region(slots)
    image_w, image_h = image_size
    gx1 = int(round(float(grid["x1"]) * image_w))
    gy1 = int(round(float(grid["y1"]) * image_h))
    gx2 = int(round(float(grid["x2"]) * image_w))
    gy2 = int(round(float(grid["y2"]) * image_h))
    grid_w = max(1, gx2 - gx1)
    grid_h = max(1, gy2 - gy1)
    if target_height_px is None:
        target_height_px = _inventory_gray_band_target_height_px(slots)
    width = max(int(target_width_px), grid_w)
    height = max(int(target_height_px), grid_h)
    cx = (gx1 + gx2) // 2
    x1 = max(0, min(image_w - width, cx - width // 2)) if image_w > width else 0
    x2 = min(image_w, x1 + width)
    y1 = max(0, gy1)
    y2 = min(image_h, y1 + height)
    if y2 - y1 < height and y2 == image_h:
        y1 = max(0, y2 - height)
    return {
        "x1": x1 / max(1, image_w),
        "y1": y1 / max(1, image_h),
        "x2": x2 / max(1, image_w),
        "y2": y2 / max(1, image_h),
    }


def _inventory_detect_gray_bands(
    image: Image.Image,
    slots: list[dict],
    *,
    scan_width_px: int = 1150,
    scan_height_px: int = 8,
    x_step_px: int = 4,
    min_y_separation_px: int = 10,
) -> list[dict]:
    region = _inventory_gray_band_scan_region(slots, image.size)
    width, height = image.size
    x1 = int(round(float(region["x1"]) * width))
    y1 = int(round(float(region["y1"]) * height))
    x2 = int(round(float(region["x2"]) * width))
    y2 = int(round(float(region["y2"]) * height))
    roi_w = int(scan_width_px)
    roi_h = int(scan_height_px)
    if x2 < x1 + roi_w or y2 < y1 + roi_h:
        return []
    gray_mask = _target_gray_mask_for_inventory_patch(image, (x1, y1, x2, y2))
    if gray_mask is None:
        return []
    integral = np.pad(gray_mask, ((1, 0), (1, 0)), mode="constant").cumsum(axis=0).cumsum(axis=1)

    def rect_sum(local_x: int, local_y: int) -> float:
        xx1 = local_x
        yy1 = local_y
        xx2 = local_x + roi_w
        yy2 = local_y + roi_h
        return float(integral[yy2, xx2] - integral[yy1, xx2] - integral[yy2, xx1] + integral[yy1, xx1])

    max_local_x = gray_mask.shape[1] - roi_w
    max_local_y = gray_mask.shape[0] - roi_h
    if max_local_x < 0 or max_local_y < 0:
        return []
    x_step = max(1, int(x_step_px))
    area = float(roi_w * roi_h)
    y_candidates: list[dict] = []
    for local_y in range(0, max_local_y + 1):
        best_x = 0
        best_score = -1.0
        for local_x in range(0, max_local_x + 1, x_step):
            score = rect_sum(local_x, local_y) / area
            if score > best_score:
                best_score = score
                best_x = local_x
        if max_local_x % x_step:
            local_x = max_local_x
            score = rect_sum(local_x, local_y) / area
            if score > best_score:
                best_score = score
                best_x = local_x
        y_candidates.append(
            {
                "x1_px": int(x1 + best_x),
                "x2_px": int(x1 + best_x + roi_w),
                "y1_px": int(y1 + local_y),
                "y2_px": int(y1 + local_y + roi_h),
                "y_center_px": float(y1 + local_y + (roi_h - 1) / 2.0),
                "strength": float(best_score),
            }
        )
    selected: list[dict] = []
    for candidate in sorted(y_candidates, key=lambda row: float(row["strength"]), reverse=True):
        cy = float(candidate["y_center_px"])
        if any(abs(cy - float(row["y_center_px"])) < min_y_separation_px for row in selected):
            continue
        selected.append(candidate)
        if len(selected) >= 32:
            break
    return sorted(selected, key=lambda row: float(row["strength"]), reverse=True)


def _choose_inventory_gray_band_sequence(
    bands: list[dict],
    *,
    count: int,
    expected_spacing_px: int,
    tolerance_px: int = 24,
) -> dict | None:
    if count <= 0 or expected_spacing_px <= 0 or len(bands) < count:
        return None
    candidates = sorted(bands, key=lambda row: float(row["y_center_px"]))
    best: dict | None = None
    tolerance = max(1, int(tolerance_px))
    for start in candidates:
        sequence = [start]
        strengths = [float(start["strength"])]
        penalties = []
        start_y = float(start["y_center_px"])
        used = {id(start)}
        for step_index in range(1, count):
            target_y = start_y + float(expected_spacing_px * step_index)
            options = [row for row in candidates if id(row) not in used]
            if not options:
                break
            nearest = min(options, key=lambda row: abs(float(row["y_center_px"]) - target_y))
            error = abs(float(nearest["y_center_px"]) - target_y)
            if error > tolerance:
                break
            sequence.append(nearest)
            used.add(id(nearest))
            strengths.append(float(nearest["strength"]))
            penalties.append(error / max(1.0, float(expected_spacing_px)))
        if len(sequence) != count:
            continue
        mean_strength = sum(strengths) / max(1, len(strengths))
        spacing_score = 1.0 - min(1.0, (sum(penalties) / max(1, len(penalties))) if penalties else 0.0)
        score = (mean_strength * 0.85) + (spacing_score * 0.15)
        row = {
            "bands": sorted(sequence, key=lambda item: float(item["y_center_px"])),
            "score": float(score),
            "mean_strength": float(mean_strength),
            "spacing_score": float(spacing_score),
        }
        if best is None or float(row["score"]) > float(best["score"]):
            best = row
    return best



def _inventory_gray_band_tail_anchors_px(grid_rows: int, image_height: int) -> list[float]:
    scale = float(image_height) / 1440.0
    if grid_rows >= 5:
        anchors = [565.5, 767.5, 959.5, 1162.5, 1364.5]
    elif grid_rows == 4:
        anchors = [398.0, 599.0, 801.0, 1004.0]
    else:
        return []
    return [value * scale for value in anchors]


def _inventory_gray_band_tail_signature(
    bands: list[dict],
    image_size: tuple[int, int],
    *,
    grid_rows: int,
    max_mean_error_px: float = 6.0,
    max_single_error_px: float = 10.0,
    min_mean_strength: float = 0.65,
) -> dict | None:
    anchors = _inventory_gray_band_tail_anchors_px(grid_rows, image_size[1])
    if not anchors or len(bands) < len(anchors):
        return None
    used: set[int] = set()
    matched: list[dict] = []
    errors: list[float] = []
    for anchor_y in anchors:
        options = [(idx, band) for idx, band in enumerate(bands) if idx not in used]
        if not options:
            return None
        best_idx, best_band = min(options, key=lambda item: abs(float(item[1]["y_center_px"]) - anchor_y))
        error = abs(float(best_band["y_center_px"]) - anchor_y)
        if error > max_single_error_px:
            return None
        used.add(best_idx)
        matched.append(best_band)
        errors.append(error)
    mean_error = sum(errors) / max(1, len(errors))
    mean_strength = sum(float(band["strength"]) for band in matched) / max(1, len(matched))
    if mean_error > max_mean_error_px or mean_strength < min_mean_strength:
        return None
    score = max(0.0, min(1.0, mean_strength - (mean_error / max(1.0, float(image_size[1])))))
    return {
        "detected": True,
        "anchors_px": anchors,
        "band_y_centers_px": [float(band["y_center_px"]) for band in matched],
        "errors_px": errors,
        "mean_error_px": float(mean_error),
        "max_error_px": float(max(errors) if errors else 0.0),
        "mean_strength": float(mean_strength),
        "score": float(score),
        "bands": matched,
    }



def _inventory_tail_last_row_top_px(grid_rows: int, image_height: int) -> float | None:
    scale = float(image_height) / 1440.0
    if grid_rows >= 5:
        return 1171.0 * scale
    if grid_rows == 4:
        return 1010.0 * scale
    return None


def _inventory_slots_from_tail_last_row_anchor(
    base_slots: list[dict],
    image_size: tuple[int, int],
    *,
    grid_cols: int,
    grid_rows: int,
    row_step_px: int,
) -> tuple[list[dict], list[float]] | None:
    if grid_cols <= 0 or grid_rows <= 0 or not base_slots or row_step_px <= 0:
        return None
    image_h = image_size[1]
    last_top = _inventory_tail_last_row_top_px(grid_rows, image_h)
    if last_top is None:
        return None
    sample_row = min(len(base_slots) - 1, max(0, (grid_rows - 1) * grid_cols))
    slot_h = (float(base_slots[sample_row]["y2"]) - float(base_slots[sample_row]["y1"])) * image_h
    last_center = float(last_top) + (slot_h / 2.0)
    row_centers = [last_center - float(row_step_px * (grid_rows - 1 - row)) for row in range(grid_rows)]
    rebuilt: list[dict] = []
    for index, slot in enumerate(base_slots):
        row_index = index // grid_cols
        if row_index >= len(row_centers):
            rebuilt.append(dict(slot))
            continue
        center_y = row_centers[row_index]
        y1 = max(0.0, min(float(image_h), center_y - (slot_h / 2.0)))
        y2 = max(0.0, min(float(image_h), center_y + (slot_h / 2.0)))
        if y2 <= y1:
            y2 = min(float(image_h), y1 + max(1.0, slot_h))
        rebuilt_slot = dict(slot)
        rebuilt_slot["y1"] = y1 / max(1, image_h)
        rebuilt_slot["y2"] = y2 / max(1, image_h)
        if "cy" in rebuilt_slot:
            rebuilt_slot["cy"] = center_y / max(1, image_h)
        rebuilt.append(rebuilt_slot)
    return rebuilt, row_centers


def _inventory_slots_from_gray_band_spaces(
    base_slots: list[dict],
    image_size: tuple[int, int],
    *,
    grid_cols: int,
    grid_rows: int,
    bands: list[dict],
    fallback_row_step_px: int,
) -> tuple[list[dict], list[float]]:
    if grid_cols <= 0 or grid_rows <= 0 or not base_slots:
        return list(base_slots), []
    image_h = image_size[1]
    band_centers = sorted(float(row["y_center_px"]) for row in bands)
    if not band_centers:
        return list(base_slots), []
    if len(band_centers) >= 2:
        spacing = float(np.median(np.diff(np.asarray(band_centers, dtype=np.float32))))
    else:
        spacing = float(fallback_row_step_px)
    if spacing <= 0:
        spacing = float(fallback_row_step_px or 1)
    boundaries = [band_centers[0] - spacing, *band_centers]
    row_centers = [
        (float(boundaries[row_index]) + float(boundaries[row_index + 1])) / 2.0
        for row_index in range(min(grid_rows, len(boundaries) - 1))
    ]
    rebuilt: list[dict] = []
    for index, slot in enumerate(base_slots):
        row_index = index // grid_cols
        if row_index >= len(row_centers):
            rebuilt.append(dict(slot))
            continue
        slot_h = (float(slot["y2"]) - float(slot["y1"])) * image_h
        center_y = row_centers[row_index]
        y1 = max(0.0, min(float(image_h), center_y - (slot_h / 2.0)))
        y2 = max(0.0, min(float(image_h), center_y + (slot_h / 2.0)))
        if y2 <= y1:
            y2 = min(float(image_h), y1 + max(1.0, slot_h))
        rebuilt_slot = dict(slot)
        rebuilt_slot["y1"] = y1 / max(1, image_h)
        rebuilt_slot["y2"] = y2 / max(1, image_h)
        if "cy" in rebuilt_slot:
            rebuilt_slot["cy"] = center_y / max(1, image_h)
        rebuilt.append(rebuilt_slot)
    return rebuilt, row_centers


def _inventory_gray_band_layout_slots(
    image: Image.Image,
    base_slots: list[dict],
    *,
    grid_cols: int,
    grid_rows: int,
    row_step_px: int,
    min_score: float = 0.96,
) -> dict | None:
    bands = _inventory_detect_gray_bands(image, base_slots)
    tail_signature = _inventory_gray_band_tail_signature(
        bands,
        image.size,
        grid_rows=grid_rows,
    )
    sequence = _choose_inventory_gray_band_sequence(
        bands,
        count=grid_rows,
        expected_spacing_px=row_step_px,
    )
    if tail_signature is not None:
        sequence = {
            "bands": tail_signature["bands"],
            "score": tail_signature["score"],
            "mean_strength": tail_signature["mean_strength"],
            "spacing_score": 1.0,
        }
    if sequence is None or (float(sequence["score"]) < float(min_score) and tail_signature is None):
        return None
    tail_anchor_layout = (
        _inventory_slots_from_tail_last_row_anchor(
            base_slots,
            image.size,
            grid_cols=grid_cols,
            grid_rows=grid_rows,
            row_step_px=row_step_px,
        )
        if tail_signature is not None
        else None
    )
    if tail_anchor_layout is not None:
        slots, row_centers = tail_anchor_layout
    else:
        slots, row_centers = _inventory_slots_from_gray_band_spaces(
            base_slots,
            image.size,
            grid_cols=grid_cols,
            grid_rows=grid_rows,
            bands=sequence["bands"],
            fallback_row_step_px=row_step_px,
        )
    public_tail_signature = None
    if tail_signature is not None:
        public_tail_signature = {
            "detected": True,
            "anchors_px": [round(float(value), 3) for value in tail_signature["anchors_px"]],
            "band_y_centers_px": [round(float(value), 3) for value in tail_signature["band_y_centers_px"]],
            "errors_px": [round(float(value), 3) for value in tail_signature["errors_px"]],
            "mean_error_px": round(float(tail_signature["mean_error_px"]), 3),
            "max_error_px": round(float(tail_signature["max_error_px"]), 3),
            "mean_strength": round(float(tail_signature["mean_strength"]), 6),
            "score": round(float(tail_signature["score"]), 6),
        }
    return {
        "slots": slots,
        "bands": sequence["bands"],
        "row_centers_px": row_centers,
        "score": float(sequence["score"]),
        "mean_strength": float(sequence["mean_strength"]),
        "spacing_score": float(sequence["spacing_score"]),
        "candidate_count": len(bands),
        "tail_page_detected": tail_signature is not None,
        "tail_signature": public_tail_signature,
        "tail_last_row_top_px": round(float(_inventory_tail_last_row_top_px(grid_rows, image.size[1]) or 0.0), 3) if tail_signature is not None else None,
    }



def _inventory_digit_edge_image(image: Image.Image) -> np.ndarray:
    arr = np.asarray(image.convert("L"), dtype=np.float32)
    gx = np.abs(np.diff(arr, axis=1, prepend=arr[:, :1]))
    gy = np.abs(np.diff(arr, axis=0, prepend=arr[:1, :]))
    return ((gy * 1.5) + (gx * 0.5)).astype(np.float32, copy=False)


def _inventory_slot_digit_points(slot: dict, image_size: tuple[int, int]) -> list[list[tuple[int, int]]]:
    width, height = image_size
    polygons: list[list[tuple[int, int]]] = []
    for position in range(6):
        digit = _digit_region(slot, position, image_size)
        points: list[tuple[int, int]] = []
        for point in digit.get("points_ratio", []):
            points.append((int(round(float(point["x"]) * width)), int(round(float(point["y"]) * height))))
        if len(points) == 4:
            polygons.append(points)
    return polygons


def _inventory_slot_digit_gray_score(
    image: Image.Image,
    slot: dict,
    *,
    margin_px: int = 2,
    tolerance: int = 14,
) -> float:
    polygons = _inventory_slot_digit_points(slot, image.size)
    if not polygons:
        return 0.0
    xs = [x for polygon in polygons for x, _y in polygon]
    ys = [y for polygon in polygons for _x, y in polygon]
    width, height = image.size
    x1 = max(0, min(xs) - margin_px)
    y1 = max(0, min(ys) - margin_px)
    x2 = min(width, max(xs) + margin_px + 1)
    y2 = min(height, max(ys) + margin_px + 1)
    gray = _target_gray_mask_for_inventory_patch(image, (x1, y1, x2, y2), tolerance=tolerance)
    if gray is None:
        return 0.0
    mask_img = Image.new("L", (x2 - x1, y2 - y1), 0)
    draw = ImageDraw.Draw(mask_img)
    for polygon in polygons:
        draw.polygon([(x - x1, y - y1) for x, y in polygon], fill=255)
    mask = np.asarray(mask_img, dtype=np.float32) / 255.0
    sample_weight = float(mask.sum())
    if sample_weight <= 0.0:
        return 0.0
    return float((gray * mask).sum() / sample_weight)


def _inventory_tail_empty_slot_gray_scores(image: Image.Image, slot: dict) -> dict:
    icon_score = _inventory_region_gray_score(image, _slot_icon_region(slot))
    background_score = _inventory_region_gray_score(
        image,
        _slot_relative_region(slot, 0.18, 0.16, 0.82, 0.70),
    )
    digit_score = _inventory_slot_digit_gray_score(image, slot)
    mean_score = (icon_score + background_score + digit_score) / 3.0
    return {
        "icon": icon_score,
        "background": background_score,
        "digit": digit_score,
        "mean": mean_score,
    }


def _inventory_tail_empty_slot_detected(scores: dict, *, min_each: float = 0.82, min_mean: float = 0.90) -> bool:
    return bool(
        float(scores.get("icon", 0.0)) >= min_each
        and float(scores.get("background", 0.0)) >= min_each
        and float(scores.get("digit", 0.0)) >= min_each
        and float(scores.get("mean", 0.0)) >= min_mean
    )


def _inventory_slot_digit_edge_patch(
    edge: np.ndarray,
    image_size: tuple[int, int],
    slot: dict,
    *,
    margin_px: int = 2,
) -> tuple[np.ndarray, np.ndarray, tuple[int, int, int, int]] | None:
    polygons = _inventory_slot_digit_points(slot, image_size)
    if not polygons:
        return None
    xs = [x for polygon in polygons for x, _y in polygon]
    ys = [y for polygon in polygons for _x, y in polygon]
    height, width = edge.shape[:2]
    x1 = max(0, min(xs) - margin_px)
    y1 = max(0, min(ys) - margin_px)
    x2 = min(width, max(xs) + margin_px + 1)
    y2 = min(height, max(ys) + margin_px + 1)
    if x2 <= x1 + 1 or y2 <= y1 + 1:
        return None
    mask_img = Image.new("L", (x2 - x1, y2 - y1), 0)
    draw = ImageDraw.Draw(mask_img)
    for polygon in polygons:
        draw.polygon([(x - x1, y - y1) for x, y in polygon], fill=255)
    mask = np.asarray(mask_img, dtype=np.float32) / 255.0
    if float(mask.sum()) < 16.0:
        return None
    patch = edge[y1:y2, x1:x2].astype(np.float32, copy=True)
    patch *= mask
    active = patch[mask > 0]
    if active.size > 0:
        mean = float(active.mean())
        std = float(active.std())
        if std > 1e-6:
            patch = ((patch - mean) / std) * mask
    return patch.astype(np.float32, copy=False), mask.astype(np.float32, copy=False), (x1, y1, x2, y2)


def _inventory_weighted_ncc_score(
    before_patch: np.ndarray,
    before_mask: np.ndarray,
    after_patch: np.ndarray,
    after_mask: np.ndarray,
) -> tuple[float, float] | None:
    height = min(before_patch.shape[0], after_patch.shape[0], before_mask.shape[0], after_mask.shape[0])
    width = min(before_patch.shape[1], after_patch.shape[1], before_mask.shape[1], after_mask.shape[1])
    if height <= 1 or width <= 1:
        return None
    weight = before_mask[:height, :width].astype(np.float64, copy=False) * after_mask[:height, :width].astype(np.float64, copy=False)
    sample_weight = float(weight.sum())
    if sample_weight < 16.0:
        return None
    before_f = before_patch[:height, :width].astype(np.float64, copy=False)
    after_f = after_patch[:height, :width].astype(np.float64, copy=False)
    before_mean = float(np.sum(before_f * weight) / sample_weight)
    after_mean = float(np.sum(after_f * weight) / sample_weight)
    before_c = (before_f - before_mean) * weight
    after_c = (after_f - after_mean) * weight
    denom = float(np.sqrt(np.sum(before_c * before_c) * np.sum(after_c * after_c)))
    if denom <= 1e-6:
        return None
    return float(np.sum(before_c * after_c) / denom), sample_weight


def _inventory_overlap_digit_vote_candidates(row_step_px: int, refine_radius_px: int) -> list[int]:
    local_radius = max(0, int(refine_radius_px))
    centers = [0]
    if row_step_px > 0:
        centers = [-int(row_step_px), 0, int(row_step_px)]
    return sorted({center + dy for center in centers for dy in range(-local_radius, local_radius + 1)})


def _estimate_inventory_overlap_digit_y_delta(
    before: Image.Image,
    after: Image.Image,
    slots: list[dict],
    *,
    before_y_offset_px: int,
    grid_cols: int,
    grid_rows: int,
    row_step_px: int,
    moved_rows: int | None,
    refine_radius_px: int = 4,
) -> dict | None:
    if row_step_px <= 0 or grid_cols <= 0 or grid_rows <= 0:
        return None
    if moved_rows is None or moved_rows <= 0 or moved_rows >= grid_rows:
        return None
    overlap_rows = grid_rows - moved_rows
    if overlap_rows <= 0:
        return None
    before_row = moved_rows
    after_row = 0
    if before_row >= grid_rows:
        return None

    before_slots = _shift_slots_y(slots, before_y_offset_px, before.size) if before_y_offset_px else slots
    before_edge = _inventory_digit_edge_image(before)
    after_edge = _inventory_digit_edge_image(after)
    candidate_deltas = _inventory_overlap_digit_vote_candidates(row_step_px, refine_radius_px)
    slot_votes: list[dict] = []
    for col in range(grid_cols):
        before_idx = before_row * grid_cols + col
        after_idx = after_row * grid_cols + col
        if before_idx >= len(slots) or after_idx >= len(slots):
            continue
        before_patch = _inventory_slot_digit_edge_patch(before_edge, before.size, before_slots[before_idx])
        if before_patch is None:
            continue
        before_arr, before_mask, _before_box = before_patch
        candidates: list[dict] = []
        for delta_y in candidate_deltas:
            after_y_offset = before_y_offset_px + int(delta_y)
            after_slot = _shift_region_y(slots[after_idx], after_y_offset, after.size[1]) if after_y_offset else slots[after_idx]
            after_patch = _inventory_slot_digit_edge_patch(after_edge, after.size, after_slot)
            if after_patch is None:
                continue
            after_arr, after_mask, _after_box = after_patch
            scored = _inventory_weighted_ncc_score(before_arr, before_mask, after_arr, after_mask)
            if scored is None:
                continue
            score, sample_weight = scored
            candidates.append({"delta_y_offset_px": int(delta_y), "score": score, "sample_weight": sample_weight})
        if not candidates:
            continue
        best = max(candidates, key=lambda item: float(item["score"]))
        slot_votes.append(
            {
                "column": col,
                "best_delta_y_offset_px": int(best["delta_y_offset_px"]),
                "best_score": float(best["score"]),
                "best_sample_weight": float(best["sample_weight"]),
            }
        )
    if not slot_votes:
        return None

    groups: dict[int, list[dict]] = {}
    for vote in slot_votes:
        groups.setdefault(int(vote["best_delta_y_offset_px"]), []).append(vote)
    dominant_delta, dominant_votes = max(
        groups.items(),
        key=lambda item: (len(item[1]), sum(float(v["best_score"]) for v in item[1]) / max(1, len(item[1]))),
    )
    dominant_score = sum(float(vote["best_score"]) for vote in dominant_votes) / max(1, len(dominant_votes))
    return {
        "method": "overlap_row_slot_count_digit_vote",
        "dominant_delta_y_offset_px": int(dominant_delta),
        "dominant_after_y_offset_px": int(before_y_offset_px + dominant_delta),
        "dominant_move_px": int((moved_rows * row_step_px) - dominant_delta),
        "dominant_count": len(dominant_votes),
        "slot_count": len(slot_votes),
        "confidence": len(dominant_votes) / max(1, len(slot_votes)),
        "dominant_mean_score": dominant_score,
        "moved_rows": int(moved_rows),
        "overlap_rows": int(overlap_rows),
        "before_row": int(before_row),
        "after_row": int(after_row),
        "votes": slot_votes,
    }


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
    if source not in {"item", "equipment"} or os.environ.get("BA_INVENTORY_SCROLL_DEBUG", "0") == "0":
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
    tail_scroll: bool = False,
    y_offset_refinement: dict | None = None,
    focus_anchor_clicked_before_capture: bool = False,
    after_slots: list[dict] | None = None,
    gray_band_layout: dict | None = None,
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
        adjusted_slots = after_slots if after_slots is not None else (_shift_slots_y(slots, y_offset_px, after_img.size) if y_offset_px else slots)
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
            "focus_anchor_clicked_before_capture": focus_anchor_clicked_before_capture,
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
            "y_offset_refinement": y_offset_refinement,
            "gray_band_layout": gray_band_layout,
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


def _click_inventory_focus_anchor_slot(
    rect: tuple[int, int, int, int],
    slots: list[dict],
) -> bool:
    if not slots:
        return False
    slot = slots[0]
    rx = float(slot.get("cx", (float(slot.get("x1", 0.0)) + float(slot.get("x2", 0.0))) / 2.0))
    y1 = float(slot.get("y1", 0.0))
    y2 = float(slot.get("y2", y1))
    # Click the upper half of slot 1 to move the in-game focus highlight away
    # from lower overlap bands before motion captures.
    ry = y1 + (y2 - y1) * 0.35
    return safe_click(rect, rx, ry, "inventory_focus_anchor_slot_1")


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


def _inventory_normal_residual_limit_px(row_step_px: int) -> int:
    return max(4, int(round(row_step_px * 0.04)))


def _inventory_normal_residual_carry_limit_px(row_step_px: int) -> int:
    return max(_inventory_normal_residual_limit_px(row_step_px), int(round(row_step_px * 0.25)))


def _inventory_overlap_rows_from_motion(
    motion: InventoryMotionEstimate | None,
    row_step_px: int,
    grid_rows: int,
    *,
    carry_normal_offset: bool = False,
) -> tuple[int, int, int, bool] | None:
    if motion is None or row_step_px <= 0 or grid_rows <= 0:
        return None
    target_rows = max(1, grid_rows - 1)
    actual_rows = motion.actual_move_px / max(1, row_step_px)
    tail_scroll = motion.actual_move_px < row_step_px * max(1.0, target_rows - 0.5)
    if tail_scroll and motion.actual_move_px < row_step_px * 0.35:
        return None
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
        # Normal drags usually settle on row boundaries. A large residual can be
        # a false peak, so callers must explicitly opt in after a settle recheck.
        max_normal_offset = _inventory_normal_residual_limit_px(row_step_px)
        max_carry_offset = _inventory_normal_residual_carry_limit_px(row_step_px)
        if abs(y_offset_px) > max_normal_offset:
            if not carry_normal_offset or abs(y_offset_px) > max_carry_offset:
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


def _estimate_inventory_scroll_motion_from_arrays(
    before: np.ndarray,
    after: np.ndarray,
    expected_step_px: int,
    search_min: int,
    search_max: int,
    *,
    method: str,
) -> InventoryMotionEstimate | None:
    height = min(before.shape[0], after.shape[0])
    width = min(before.shape[1], after.shape[1])
    if height <= expected_step_px + 16 or width <= 8:
        return None
    before = before[:height, :width]
    after = after[:height, :width]
    search_min = max(1, search_min)
    search_max = min(height - 8, search_max)
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
        method=method,
    )


def _inventory_motion_feature_pair(
    before_img: Image.Image,
    after_img: Image.Image,
    grid_r: dict,
    *,
    slots: list[dict] | None = None,
) -> tuple[np.ndarray, np.ndarray] | None:
    region = _inventory_motion_region(grid_r)
    before = _inventory_motion_array(before_img, region, slots=slots)
    after = _inventory_motion_array(after_img, region, slots=slots)
    if before is None or after is None:
        return None
    return before, after


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
    pair = _inventory_motion_feature_pair(before_img, after_img, grid_r, slots=slots)
    if pair is None:
        return None
    before, after = pair
    search_min = max(1, expected_step_px - max(1, search_margin_px))
    search_max = expected_step_px + max(1, search_margin_px)
    return _estimate_inventory_scroll_motion_from_arrays(
        before,
        after,
        expected_step_px,
        search_min,
        search_max,
        method="row_feature_shift_slot_sides_ignored",
    )


def _verify_inventory_near_zero_motion(
    before_img: Image.Image,
    after_img: Image.Image,
    grid_r: dict,
    expected_step_px: int,
    row_step_px: int,
    reference_motion: InventoryMotionEstimate | None,
    *,
    slots: list[dict] | None = None,
) -> InventoryMotionEstimate | None:
    if expected_step_px <= 0 or row_step_px <= 0:
        return None
    pair = _inventory_motion_feature_pair(before_img, after_img, grid_r, slots=slots)
    if pair is None:
        return None
    before, after = pair
    band_px = max(8, int(round(row_step_px * INVENTORY_SCROLL_NEAR_ZERO_EXPECTED_BAND_RATIO)))
    candidate = _estimate_inventory_scroll_motion_from_arrays(
        before,
        after,
        expected_step_px,
        expected_step_px - band_px,
        expected_step_px + band_px,
        method="row_feature_shift_expected_band",
    )
    if candidate is None:
        return None
    if candidate.actual_move_px < row_step_px * 0.35:
        return None
    if candidate.score < INVENTORY_SCROLL_NEAR_ZERO_EXPECTED_MIN_SCORE:
        return None
    if (
        reference_motion is not None
        and reference_motion.score > candidate.score + INVENTORY_SCROLL_NEAR_ZERO_EXPECTED_MAX_SCORE_GAP
    ):
        return None
    return candidate
_INVENTORY_TEMPLATE_DIRS: dict[str, tuple[str, ...]] = {
    "item": ("skill_book", "ooparts", "skill_db", "students_elephs", "presents"),
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


def _inventory_grid_template_matching_config(section: dict, profile_id: str | None) -> dict | None:
    config = _inventory_grid_template_config(section, profile_id)
    if os.environ.get(INVENTORY_DIRECT_ICON_MATCH_ENV, "1") != "0":
        return config
    if not isinstance(config, dict) or "direct_icon_match" not in config:
        return config
    legacy_config = dict(config)
    direct_config = legacy_config.get("direct_icon_match")
    if isinstance(direct_config, dict):
        legacy_direct_config = dict(direct_config)
        legacy_direct_config["enabled"] = False
        legacy_config["direct_icon_match"] = legacy_direct_config
    else:
        legacy_config.pop("direct_icon_match", None)
    return legacy_config

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

    if source == "item":
        report_dir = TEMPLATE_DIR / "icons" / "temp"
        for tier in range(4):
            report_path = report_dir / f"report_{tier}.png"
            if report_path.exists():
                catalog_by_item_id[f"Item_Icon_ExpItem_{tier}"] = str(report_path)
        for workbook_path in sorted(report_dir.glob("Item_Icon_WorkBook_*.png")):
            catalog_by_item_id[workbook_path.stem] = str(workbook_path)

    catalog = list(catalog_by_item_id.items())
    _INVENTORY_TEMPLATE_CATALOG[source] = catalog
    return catalog


def inventory_profile_template_catalog(
    source: str,
    profile_id: str | None = None,
) -> list[tuple[str, str]]:
    """Return canonical grid candidates using the same catalog as production."""
    catalog = list(_inventory_template_catalog(source))
    profile = get_inventory_profile(profile_id) if profile_id else None
    if profile is None or profile.source != source or not profile.expected_item_ids:
        return catalog
    allowed = profile.expected_item_ids
    return [row for row in catalog if row[0] in allowed]


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
