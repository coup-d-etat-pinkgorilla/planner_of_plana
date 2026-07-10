"""
Standalone Qt-based student viewer process.
"""

from __future__ import annotations

import ctypes
import argparse
import json
import math
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from collections import Counter, OrderedDict, defaultdict
from dataclasses import dataclass, field, fields
from datetime import date, datetime, timedelta
from html import escape
from pathlib import Path
from uuid import uuid4

BASE_DIR = Path(__file__).resolve().parent.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

import core.student_meta as student_meta
from core.config import (
    APP_DIR,
    BASE_DIR,
    TEMPLATE_DIR,
    activate_profile,
    get_active_profile_name,
    get_storage_paths,
    ensure_profile_storage,
    list_profiles,
    load_config,
    save_config,
)
from core.db import APP_VERSION, init_db
from core.equipment_items import EQUIPMENT_EXP_ITEMS, EQUIPMENT_ITEM_ID_TO_NAME, EQUIPMENT_SERIES, WEAPON_PART_ITEMS
from core.inventory_profiles import get_inventory_profile, inventory_item_display_name, inventory_profile_ordered_item_ids
from core.oparts import OPART_DEFINITIONS, OPART_ITEM_ID_TO_NAME, OPART_LEGACY_WB_ITEM_IDS, OPART_ORDERED_ITEM_IDS, OPART_WB_ITEMS
from core.planning import (
    MAX_TARGET_EQUIP_LEVEL,
    MAX_TARGET_EQUIP_TIER,
    MAX_TARGET_EQUIP4_TIER,
    MAX_TARGET_EX_SKILL,
    MAX_TARGET_LEVEL,
    MAX_TARGET_SKILL,
    MAX_TARGET_STAR,
    MAX_TARGET_STAT,
    MAX_TARGET_WEAPON_LEVEL,
    MAX_TARGET_WEAPON_STAR,
    StudentGoal,
    load_plan,
    save_plan,
)
from core.planning_calc import (
    PlanCostSummary,
    WEAPON_EXP_ITEM_PREFIX,
    WEAPON_EXP_WILDCARD_PART_KEY,
    calculate_goal_cost,
)
from core.raid_guide import (
    RAID_BOSS_DEFAULT_MODES,
    RAID_BOSS_TIME_LIMIT_SECONDS,
    RAID_GUIDE_DIFFICULTIES,
    RAID_GUIDE_MODES,
    GuideDeckSlot,
    RaidGuide,
    TimelineStep,
    clone_guide,
    decode_raid_guide_share,
    default_deck_for_mode,
    encode_raid_guide_share,
    load_raid_guides,
    parse_cue,
    new_raid_guide,
    parse_timeline_text,
    sanitize_guide,
    save_raid_guides,
    slot_counts_for_mode,
    update_step_cue,
    validate_guide,
)
from core.scan_status import read_status_events, reset_status_log, write_status_ack
from core.state_export import encode_state_export
from core.tactical_challenge import (
    TACTICAL_STRIKER_SLOTS,
    TACTICAL_SUPPORT_SLOTS,
    TacticalDeck,
    TacticalJokboEntry,
    TacticalMatch,
    clear_tactical_import_template,
    deck_label,
    deck_input_template,
    deck_template,
    delete_tactical_match,
    ensure_tactical_import_template,
    get_tactical_match,
    latest_tactical_match_for_opponent,
    load_tactical_challenge,
    opponent_report_from_storage,
    parse_deck_template,
    query_tactical_matches,
    read_tactical_import_rows,
    tactical_import_readme_path,
    write_tactical_import_rows,
    save_tactical_metadata,
    save_tactical_challenge,
    search_jokbo_from_storage,
    tactical_match_count,
    tactical_match_summary,
    tactical_student_frequency_from_storage,
    upsert_tactical_jokbo,
    upsert_tactical_jokbo_entries,
    upsert_tactical_match,
    upsert_tactical_matches,
)
from core.tactical_screenshot import (
    collect_tactical_screenshot_images,
    parse_tactical_result_screenshot,
    tactical_screenshot_date_from_path,
)
from gui.tactic_assist_qt import TacticAssistWindow
from PySide6.QtCore import QEasingCurve, QEvent, QObject, QPoint, QParallelAnimationGroup, QPropertyAnimation, QRect, QRectF, QRunnable, QSize, Qt, QtMsgType, QThreadPool, QTimer, Signal, qInstallMessageHandler
from PySide6.QtGui import QColor, QCursor, QFont, QFontDatabase, QFontMetrics, QIcon, QImage, QIntValidator, QLinearGradient, QPainter, QPainterPath, QPen, QPixmap, QRegion, QValidator
from PySide6.QtWidgets import (
    QAbstractItemView,
    QAbstractSpinBox,
    QAbstractScrollArea,
    QApplication,
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QFrame,
    QFileDialog,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QListView,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMenu,
    QMessageBox,
    QPlainTextEdit,
    QProgressBar,
    QPushButton,
    QHeaderView,
    QSpinBox,
    QSplitter,
    QStackedWidget,
    QSystemTrayIcon,
    QTabBar,
    QTabWidget,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
    QScrollArea,
    QSizePolicy,
)


def activate_target_window() -> bool:
    from core.capture import activate_target_window as _activate_target_window

    return _activate_target_window()


def get_all_windows() -> list[dict]:
    from core.capture import get_all_windows as _get_all_windows

    return _get_all_windows()


def set_target_window(hwnd: int, title: str) -> None:
    from core.capture import set_target_window as _set_target_window

    _set_target_window(hwnd, title)


def is_target_foreground() -> bool:
    from core.capture import is_target_foreground as _is_target_foreground

    return _is_target_foreground()


VIEWER_STUDENT_SCAN_DEBUG_FLAGS = {
    "--student-scan-debug",
    "--student-debug",
    "--debug-student-scan",
}
VK_LEFT = 0x25
VK_RIGHT = 0x27


def _async_key_down(vk: int) -> bool:
    if os.name != "nt":
        return False
    try:
        return bool(ctypes.windll.user32.GetAsyncKeyState(int(vk)) & 0x8000)
    except Exception:
        return False

_PLAN_GOAL_CACHE_FIELDS = tuple(field.name for field in fields(StudentGoal))
RAID_CUSTOM_INPUT_LABEL = "직접 입력"
_UI_LANGUAGE = os.environ.get("BA_PLANNER_LANG", "ko").split(".", 1)[0].replace("-", "_").lower()
if _UI_LANGUAGE not in {"ko", "en"}:
    _UI_LANGUAGE = "ko"

SHOW_RAID_GUIDE_TAB = False
SHOW_STATS_TAB = False

_I18N: dict[str, dict[str, str]] = {
    "ko": {
        "tab.students": "학생",
        "tab.plans": "플랜",
        "tab.inventory": "인벤토리",
        "inventory.title": "인벤토리 상태 분석",
        "inventory.subtitle": "여기서 선생님이 보유하고 있는 재화의 종류, 수량을 확인하고, 계획에 필요한 재화와 부족한 재화를 확인할 수 있습니다.",
        "inventory.empty": "아직 스캔된 인벤토리가 없습니다.",
        "inventory.empty_with_hint": "아직 스캔된 인벤토리가 없습니다. 아이템 또는 장비 스캔을 실행하면 이 탭이 채워집니다.",
        "inventory.sort_label": "오파츠 / BD / 노트 정렬",
        "inventory.sort_category": "카테고리별 정렬",
        "inventory.sort_tier": "티어별 정렬",
        "inventory.root_equipment": "장비",
        "inventory.root_items": "아이템",
        "inventory.category.ooparts": "오파츠",
        "inventory.category.wb": "WB",
        "inventory.category.stones": "강화석",
        "inventory.category.reports": "활동 보고서",
        "inventory.category.weapon_parts": "무기 성장 재료",
        "inventory.category.tech_notes": "기술 노트",
        "inventory.category.bd": "BD",
        "inventory.category.resources": "재화",
        "inventory.category.elephs": "엘레프",
        "inventory.category.presents": "선물",
        "inventory.category.other": "기타",
        "inventory.header.material": "재화",
        "inventory.header.owned": "보유",
        "inventory.header.plan_need": "계획 필요",
        "inventory.header.plan_short": "계획 부족",
        "inventory.header.pool_remain": "전체 육성 부족",
        "inventory.header.status": "상태",
        "inventory.pressure_title": "부족 진단",
        "inventory.pressure_empty": "인벤토리를 스캔하고 오파츠를 선택하면 계획 부족 상태를 확인할 수 있습니다.",
        "inventory.plan_shortage_top": "계획 부족 TOP 5",
        "inventory.full_pool_top": "전체 육성 부족 TOP 5",
        "inventory.common_bottleneck": "재화별 충족도 요약",
        "inventory.school_shortage": "재화 부족 위험 학교 TOP 3",
        "inventory.detail.select_oopart": "오파츠를 선택하세요",
        "inventory.detail.pick_item": "위 아이템을 선택하면 계획 사용처와 영향을 받는 학생을 볼 수 있습니다.",
        "inventory.detail.inventory_status": "인벤토리 상태",
        "inventory.detail.owned": "보유",
        "inventory.detail.plan_need": "계획 필요",
        "inventory.detail.plan_short": "계획 부족",
        "inventory.detail.plan_coverage": "계획 충족률",
        "inventory.detail.full_pool_need": "전체 육성 필요",
        "inventory.detail.pool_left": "전체 육성 부족",
        "inventory.detail.full_coverage": "전체 육성 충족률",
        "inventory.detail.skill_demand": "스킬 수요",
        "inventory.detail.ex_skill": "EX 스킬",
        "inventory.detail.normal_skills": "일반 스킬",
        "inventory.detail.affected_students": "영향 학생",
        "inventory.detail.current_full_pool": "계획 / 전체 육성",
        "inventory.detail.decision_hints": "판단 힌트",
        "inventory.detail.related_pressure": "연관 부족 현황",
        "inventory.detail.full_growth": "전체 육성",
        "inventory.detail.student_breakdown": "학생별 요구량",
        "inventory.status.sufficient": "충분",
        "inventory.status.plan_shortage": "계획 부족",
        "inventory.status.long_term_pressure": "장기적으로 부족",
        "inventory.status.unused": "미사용",
        "inventory.status.high_tier_bottleneck": "고티어 병목",
        "inventory.no_scanned_category": "이 카테고리에 스캔된 아이템이 아직 없습니다.",
        "inventory.scan_to_populate": "아이템 또는 장비 스캔을 실행하면 이 카테고리가 채워집니다.",
        "inventory.summary": "{count}개 · 총 수량 {quantity}",
        "inventory.summary_scanned": "총 {count}개의 아이템 종류가 확인되었으며, 마지막 갱신일은 {time}입니다.",
        "inventory.last_updated": "{time}",
    }
}


def _tr(key: str, default: str | None = None, **kwargs: object) -> str:
    text = _I18N.get(_UI_LANGUAGE, {}).get(key)
    if text is None:
        text = _I18N.get("en", {}).get(key, default if default is not None else key)
    return text.format(**kwargs) if kwargs else text


def _format_count(value: int | float | None, *, compact: bool = False, signed: bool = False) -> str:
    if value is None:
        return "-"
    number = int(value)
    if signed and number > 0:
        return f"-{_format_count(number, compact=compact)}"
    sign = "-" if number < 0 else ""
    amount = abs(number)
    if compact and amount >= 100_000_000_0000:
        compact_value = amount / 100_000_000_0000
        return f"{sign}{compact_value:.1f}조".replace(".0조", "조")
    if compact and amount >= 100_000_000:
        compact_value = amount / 100_000_000
        return f"{sign}{compact_value:.1f}억".replace(".0억", "억")
    if compact and amount >= 10_000:
        compact_value = amount / 10_000
        return f"{sign}{compact_value:.1f}만".replace(".0만", "만")
    return f"{number:,}"


def _full_count_tooltip(value: int | float | None) -> str:
    return "-" if value is None else f"{int(value):,}"


def _inventory_status_key(status: str) -> str:
    if _inventory_is_priority_shortage_status(status):
        return "plan_shortage"
    normalized = (status or "").replace("-", " ").replace("_", " ").strip().lower()
    mapping = {
        "sufficient": "sufficient",
        "충분": "sufficient",
        "plan shortage": "plan_shortage",
        "계획 부족": "plan_shortage",
        "long term pressure": "long_term_pressure",
        "long-term pressure": "long_term_pressure",
        "장기적으로 부족": "long_term_pressure",
        "unused": "unused",
        "미사용": "unused",
        "high tier bottleneck": "high_tier_bottleneck",
        "high-tier bottleneck": "high_tier_bottleneck",
        "고티어 병목": "high_tier_bottleneck",
    }
    return mapping.get(normalized, normalized.replace(" ", "_") or "unused")


def _inventory_is_priority_shortage_status(status: str) -> bool:
    text = (status or "").strip().lower()
    return "순위로 부족" in text or "priority shortage" in text


def _inventory_priority_shortage_status(rank: int) -> str:
    return f"{rank}순위로 부족"


def _inventory_status_label(status: str) -> str:
    if _inventory_is_priority_shortage_status(status):
        return status
    key = _inventory_status_key(status)
    return _tr(f"inventory.status.{key}", status)


def _inventory_category_label(category: str) -> str:
    return _tr(f"inventory.category.{category}", category.replace("_", " ").title() if category else "")


def _equipment_series_label(series_key: str) -> str:
    labels = {
        "Necklace": "목걸이",
        "Watch": "시계",
        "Charm": "부적",
        "Hairpin": "헤어핀",
        "Badge": "배지",
        "Bag": "가방",
        "Shoes": "신발",
        "Gloves": "장갑",
        "Hat": "모자",
    }
    return labels.get(series_key, series_key)

try:
    from PIL import Image

    HAS_PIL = True
except ImportError:
    HAS_PIL = False

PORTRAIT_DIR = TEMPLATE_DIR / "students_portraits"
UI_FONT_PATH = BASE_DIR / "gui" / "font" / "경기천년제목_Medium.ttf"
POLI_BG_DIR = TEMPLATE_DIR / "icons" / "temp"
STUDENT_ELEPH_DIR = TEMPLATE_DIR / "students_elephs"
SCHOOL_LOGO_DIR = TEMPLATE_DIR / "icons" / "school_logo"
EQUIPMENT_ICON_DIR = TEMPLATE_DIR / "icons" / "equipment"
OPART_ICON_DIR = TEMPLATE_DIR / "icons" / "ooparts"
SKILL_BOOK_ICON_DIR = TEMPLATE_DIR / "icons" / "skill_book"
SKILL_DB_ICON_DIR = TEMPLATE_DIR / "icons" / "skill_db"
PRESENT_ICON_DIR = TEMPLATE_DIR / "icons" / "presents"
INVENTORY_DETAIL_DIR = TEMPLATE_DIR / "inventory_detail"
CARD_BUTTON_ASSET = POLI_BG_DIR / "square.png"
ITEM_ICON_DEFAULT_BACKGROUND = POLI_BG_DIR / "square.png"
ITEM_ICON_BACKGROUND_BLUE = POLI_BG_DIR / "square_blue.png"
ITEM_ICON_BACKGROUND_YELLOW = POLI_BG_DIR / "square_yellow.png"
ITEM_ICON_BACKGROUND_PURPLE = POLI_BG_DIR / "square_purple.png"
ITEM_ICON_BACKGROUND_BY_TIER_INDEX: dict[int, Path] = {
    1: ITEM_ICON_BACKGROUND_BLUE,
    2: ITEM_ICON_BACKGROUND_YELLOW,
    3: ITEM_ICON_BACKGROUND_PURPLE,
}
MAIN_UI_PALETTE_PATH = BASE_DIR / "gui" / "main_ui_color_palete.txt"
THUMB_STYLE_VERSION = "v5-parallelogram-card-fit"
DETAIL_SLANT = 0.22
SEARCH_DEBOUNCE_MS = 180

_REPORT_NAME_TO_ICON = {
    "초급활동보고서": "report_0",
    "소급활동보고서": "report_0",
    "일반활동보고서": "report_1",
    "상급활동보고서": "report_2",
    "최상급활동보고서": "report_3",
}
_REPORT_ICON_TO_NAME = {
    "report_0": "초급 활동 보고서",
    "report_1": "일반 활동 보고서",
    "report_2": "상급 활동 보고서",
    "report_3": "최상급 활동 보고서",
}
_REPORT_ID_TO_ICON = {
    **{icon_id: icon_id for icon_id in _REPORT_ICON_TO_NAME},
    **{f"Item_Icon_ExpItem_{tier}": f"report_{tier}" for tier in range(4)},
}
_REPORT_ORDER = ("report_3", "report_2", "report_1", "report_0")
_WORKBOOK_ID_TO_NAME = {
    "Item_Icon_WorkBook_PotentialAttack": "교양 사격 WB",
    "Item_Icon_WorkBook_PotentialMaxHP": "교양 체육 WB",
    "Item_Icon_WorkBook_PotentialHealPower": "교양 위색 WB",
}
_WB_ITEM_IDS = tuple(item_id for item_id, _name in OPART_WB_ITEMS) + OPART_LEGACY_WB_ITEM_IDS
_LEGACY_WB_ID_TO_ITEM_ID = {name: item_id for item_id, name in OPART_WB_ITEMS}
_OPART_NAME_TO_ITEM_ID = {
    name: item_id
    for item_id, name in OPART_ITEM_ID_TO_NAME.items()
    if item_id.startswith("Item_Icon_")
}
_OPART_ITEM_IDS = tuple(item_id for item_id in OPART_ORDERED_ITEM_IDS if item_id not in _WB_ITEM_IDS)
_SCHOOL_SEQUENCE = (
    "Hyakkiyako",
    "RedWinter",
    "Trinity",
    "Gehenna",
    "Abydos",
    "Millennium",
    "Arius",
    "Shanhaijing",
    "Valkyrie",
    "Highlander",
    "Wildhunt",
)
_OPART_EN_TO_ICON_KEY = {
    definition.family_en.casefold(): definition.icon_key
    for definition in OPART_DEFINITIONS
}
_PLAN_RESOURCE_CATEGORY_ORDER = {
    "credits": 0,
    "level_exp": 10,
    "equipment_exp": 20,
    "weapon_exp": 30,
    "skill_bd": 40,
    "skill_notes": 50,
    "secret_notes": 60,
    "ex_ooparts": 70,
    "skill_ooparts": 80,
    "stat_materials": 85,
    "favorite_item_materials": 86,
    "equipment_slot_1": 90,
    "equipment_slot_2": 100,
    "equipment_slot_3": 110,
    "equipment_materials": 120,
    "star_materials": 130,
}
_PLAN_RESOURCE_CATEGORY_LABELS = {
    "credits": "크레딧",
    "level_exp": "활동 보고서",
    "equipment_exp": "장비 강화석",
    "weapon_exp": "무기 성장 재료",
    "skill_books": "BD / 기술 노트",
    "ex_ooparts": "EX 오파츠",
    "skill_ooparts": "일반 스킬 오파츠",
    "stat_materials": "능력개방",
    "favorite_item_materials": "애용품",
    "equipment_materials": "장비 설계도",
    "star_materials": "엘레프",
}
_EQUIPMENT_NAME_TO_ITEM_ID = {
    name: item_id
    for item_id, name in EQUIPMENT_ITEM_ID_TO_NAME.items()
}


def _plan_resource_category_label(category: str) -> str:
    return _PLAN_RESOURCE_CATEGORY_LABELS.get(category, category.replace("_", " ").title())

from gui.student_filters import (
    FILTER_FIELD_LABELS,
    FILTER_FIELD_ORDER,
    active_filter_count,
    build_filter_options,
    format_filter_value,
    get_student_value,
    get_student_values,
    matches_student_filters,
    summarize_filters,
)
from gui.parallelogram_button import (
    ParallelogramButton,
    ParallelogramButtonRow,
    build_card_button_style,
)
from gui.parallelogram_card import (
    ParallelogramCardAsset,
    ParallelogramCardGrid,
    StudentCardWidget,
    StudentPortraitWidget,
    build_card_style,
)
from gui.student_stats import DistributionRow, DonutWidget, PALETTE, SunburstNode, SunburstWidget, build_distribution


def _normalize_hex(color: str, fallback: str) -> str:
    value = (color or "").strip()
    if len(value) == 7 and value.startswith("#"):
        return value.lower()
    return fallback.lower()


def _hex_to_rgb(color: str) -> tuple[int, int, int]:
    value = color.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def _rgb_to_hex(red: int, green: int, blue: int) -> str:
    return f"#{max(0, min(255, red)):02x}{max(0, min(255, green)):02x}{max(0, min(255, blue)):02x}"


def _hex_to_colorref(color: str) -> int:
    red, green, blue = _hex_to_rgb(color)
    return red | (green << 8) | (blue << 16)


def _mix_hex(color_a: str, color_b: str, amount_from_b: float) -> str:
    amount = max(0.0, min(1.0, amount_from_b))
    ar, ag, ab = _hex_to_rgb(color_a)
    br, bg, bb = _hex_to_rgb(color_b)
    return _rgb_to_hex(
        int(round(ar + (br - ar) * amount)),
        int(round(ag + (bg - ag) * amount)),
        int(round(ab + (bb - ab) * amount)),
    )


def _load_main_palette() -> tuple[str, str, str, str, str]:
    fallback = ("#f266b3", "#efe4f2", "#313b59", "#2c3140", "#f2f2f2")
    if not MAIN_UI_PALETTE_PATH.exists():
        return fallback

    try:
        values = [entry.strip() for entry in MAIN_UI_PALETTE_PATH.read_text(encoding="utf-8").split(",")]
    except Exception:
        return fallback

    if len(values) < 5:
        return fallback

    return tuple(_normalize_hex(values[index], fallback[index]) for index in range(5))  # type: ignore[return-value]


def _preferred_text_hex(background: str) -> str:
    red, green, blue = _hex_to_rgb(background)
    luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
    return "#101722" if luminance >= 170 else "#f2f2f2"


def _live_line_edit_text(widget: QLineEdit | None) -> str:
    if isinstance(widget, LiveSearchLineEdit):
        return widget.liveText()
    return widget.text() if widget is not None else ""


PALETTE_ACCENT, PALETTE_SOFT, PALETTE_PANEL, PALETTE_PANEL_ALT, PALETTE_TEXT = _load_main_palette()

BG = _mix_hex(PALETTE_PANEL_ALT, "#090b12", 0.3)
SURFACE = PALETTE_PANEL
SURFACE_ALT = PALETTE_PANEL_ALT
INK = PALETTE_TEXT
MUTED = _mix_hex(PALETTE_TEXT, PALETTE_PANEL_ALT, 0.38)
BORDER = _mix_hex(PALETTE_SOFT, PALETTE_PANEL_ALT, 0.72)
ACCENT = PALETTE_ACCENT
ACCENT_STRONG = _mix_hex(PALETTE_ACCENT, "#ffffff", 0.14)
ACCENT_SOFT = _mix_hex(PALETTE_ACCENT, PALETTE_PANEL_ALT, 0.58)
ACCENT_PALE = _mix_hex(PALETTE_SOFT, PALETTE_PANEL_ALT, 0.55)
SHADOW = _mix_hex(PALETTE_PANEL_ALT, "#000000", 0.35)
WORK_AREA_ASPECT_RATIO = 16 / 9
PLANNER_BASE_WIDTH = 1920
PLANNER_BASE_HEIGHT = 1080
SMALL_16_9_SCALE_THRESHOLD = 0.85
SMALL_16_9_SCALE_FACTOR = 0.9
STUDENT_GRID_CARD_BASE_WIDTH = 252
PLAN_GRID_CARD_BASE_WIDTH = 252
STUDENT_GRID_COLUMNS = 8
PLAN_GRID_COLUMNS = 6

if os.name == "nt":
    _dwmapi = ctypes.WinDLL("dwmapi", use_last_error=True)
    _user32 = ctypes.WinDLL("user32", use_last_error=True)
else:
    _dwmapi = None
    _user32 = None


class _RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long), ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class _MONITORINFO(ctypes.Structure):
    _fields_ = [
        ("cbSize", ctypes.c_ulong),
        ("rcMonitor", _RECT),
        ("rcWork", _RECT),
        ("dwFlags", ctypes.c_ulong),
    ]


def _set_windows_caption_theme(hwnd: int, caption_hex: str, text_hex: str) -> None:
    if _dwmapi is None or not hwnd:
        return

    attributes = (
        (35, _hex_to_colorref(caption_hex)),
        (36, _hex_to_colorref(text_hex)),
        (34, _hex_to_colorref(caption_hex)),
    )
    for attribute, value in attributes:
        color = ctypes.c_int(value)
        try:
            _dwmapi.DwmSetWindowAttribute(
                ctypes.c_void_p(hwnd),
                attribute,
                ctypes.byref(color),
                ctypes.sizeof(color),
            )
        except Exception:
            return


def _windows_work_area(hwnd: int) -> QRect | None:
    if _user32 is None or not hwnd:
        return None
    try:
        monitor = _user32.MonitorFromWindow(ctypes.c_void_p(hwnd), 2)
        if not monitor:
            return None
        info = _MONITORINFO()
        info.cbSize = ctypes.sizeof(_MONITORINFO)
        if not _user32.GetMonitorInfoW(monitor, ctypes.byref(info)):
            return None
        work = info.rcWork
        return QRect(work.left, work.top, max(1, work.right - work.left), max(1, work.bottom - work.top))
    except Exception:
        return None


def _windows_primary_work_area() -> QRect | None:
    if _user32 is None:
        return None
    try:
        work = _RECT()
        if not _user32.SystemParametersInfoW(48, 0, ctypes.byref(work), 0):
            return None
        return QRect(work.left, work.top, max(1, work.right - work.left), max(1, work.bottom - work.top))
    except Exception:
        return None


def _fit_rect_to_aspect(rect: QRect, aspect_ratio: float = WORK_AREA_ASPECT_RATIO) -> QRect:
    if rect.isEmpty() or aspect_ratio <= 0:
        return rect
    width = rect.width()
    height = rect.height()
    target_width = width
    target_height = int(round(width / aspect_ratio))
    if target_height > height:
        target_height = height
        target_width = int(round(height * aspect_ratio))
    x = rect.left() + max(0, (width - target_width) // 2)
    y = rect.top() + max(0, (height - target_height) // 2)
    return QRect(x, y, max(1, target_width), max(1, target_height))


def _window_frame_for_screen_area(screen_geometry: QRect, available_geometry: QRect) -> QRect:
    if available_geometry.isEmpty():
        return QRect()
    if screen_geometry.isEmpty():
        return _fit_rect_to_aspect(available_geometry)
    target_with_reserved_area = _fit_rect_to_aspect(screen_geometry)
    target_frame = target_with_reserved_area.intersected(available_geometry)
    if target_frame.isEmpty():
        return _fit_rect_to_aspect(available_geometry)
    return target_frame


def get_qt_ui_scale(
    app: QApplication,
    base_width: int | None = None,
    base_height: int = 1080,
    max_scale: float = 1.8,
) -> float:
    raw = os.getenv("BA_UI_SCALE")
    if raw:
        try:
            value = float(raw)
            if value > 0:
                return value
        except ValueError:
            pass

    screen = app.screenAt(QCursor.pos()) or app.primaryScreen()
    if screen is None:
        return 1.0

    screen_geometry = screen.geometry()
    available_geometry = screen.availableGeometry()
    if os.name == "nt":
        work_area = _windows_work_area(0) or (_windows_primary_work_area() if screen == app.primaryScreen() else None)
        if work_area is not None and not work_area.isEmpty() and work_area.intersects(available_geometry):
            available_geometry = work_area
    target_frame = _window_frame_for_screen_area(screen_geometry, available_geometry)
    height = max(1, target_frame.height())
    scale = height / float(base_height)
    if base_width:
        width = max(1, target_frame.width())
        scale = min(scale, width / float(base_width))
    if scale < SMALL_16_9_SCALE_THRESHOLD:
        scale *= SMALL_16_9_SCALE_FACTOR
    scale = min(max_scale, scale)
    return max(0.1, scale)


def scale_px(value: int | float, scale: float) -> int:
    return max(1, int(round(float(value) * scale)))


def _school_short_label(school: str | None) -> str:
    mapping = {
        "Abydos": "ABY",
        "Arius": "ARI",
        "Gehenna": "GEH",
        "Highlander": "HIG",
        "Hyakkiyako": "HYA",
        "Millennium": "MIL",
        "RedWinter": "RED",
        "Red Winter": "RED",
        "Sakugawa": "SAK",
        "Shanhaijing": "SHA",
        "SRT": "SRT",
        "Tokiwadai": "TOK",
        "Trinity": "TRI",
        "Valkyrie": "VAL",
        "Wildhunt": "WLD",
    }
    return mapping.get((school or "").strip(), "ETC")


def _school_accent_color(school: str | None) -> str:
    mapping = {
        "Abydos": "#00bcd4",
        "Arius": "#7d8597",
        "Gehenna": "#6a1b9a",
        "Highlander": "#2a9d8f",
        "Hyakkiyako": "#ff8f00",
        "Millennium": "#1565c0",
        "RedWinter": "#d84315",
        "Red Winter": "#d84315",
        "Sakugawa": "#00897b",
        "Shanhaijing": "#ef6c00",
        "SRT": "#455a64",
        "Tokiwadai": "#5e35b1",
        "Trinity": "#f06292",
        "Valkyrie": "#546e7a",
        "Wildhunt": "#8e24aa",
    }
    return mapping.get((school or "").strip(), "#5c6ea8")


def _role_label(role: str | None) -> str:
    mapping = {
        "tanker": "Tank",
        "dealer": "Striker",
        "healer": "Healer",
        "supporter": "Support",
        "t_s": "TS",
    }
    return mapping.get((role or "").strip().lower(), "-")


def _position_label(position: str | None) -> str:
    mapping = {
        "front": "Front",
        "middle": "Middle",
        "back": "Back",
    }
    return mapping.get((position or "").strip().lower(), "-")


def _attack_color(attack_type: str | None) -> str:
    mapping = {
        "Explosive": "#920008",
        "Piercing": "#bd8901",
        "Mystic": "#226f9b",
        "Sonic": "#9945a8",
        "Break": "#228b22",
        "Demolition": "#228b22",
        "Disassembly": "#228b22",
        "Composite": "#228b22",
    }
    return mapping.get((attack_type or "").strip(), "#5c6ea8")


def _defense_accent_color(defense_type: str | None) -> str:
    mapping = {
        "Light": _attack_color("Explosive"),
        "Heavy": _attack_color("Piercing"),
        "Special": _attack_color("Mystic"),
        "Elastic": _attack_color("Sonic"),
        "Composite": "#228b22",
    }
    return mapping.get((defense_type or "").strip(), BORDER)


def _student_divider_colors(record: "StudentRecord") -> tuple[str, str]:
    primary = _attack_color(record.attack_type)
    secondary = _defense_accent_color(record.defense_type)
    return primary, secondary


def _school_logo_path(school: str | None) -> Path | None:
    mapping = {
        "Abydos": "School_Icon_ABYDOS.png",
        "Arius": "School_Icon_Arius.png",
        "ETC": "School_Icon_ETC.png",
        "Gehenna": "School_Icon_GEHENNA.png",
        "Highlander": "School_Icon_HIGHLANDER.png",
        "Hyakkiyako": "School_Icon_HYAKKIYAKO.png",
        "Millennium": "School_Icon_MILLENNIUM.png",
        "RedWinter": "School_Icon_REDWINTER.png",
        "Red Winter": "School_Icon_REDWINTER.png",
        "Sakugawa": "School_Icon_SAKUGAWA.png",
        "Shanhaijing": "School_Icon_SHANHAIJING.png",
        "SRT": "School_Icon_SRT.png",
        "Tokiwadai": "School_Icon_Tokiwadai.png",
        "Trinity": "School_Icon_TRINITY.png",
        "Valkyrie": "School_Icon_VALKYRIE.png",
        "Wildhunt": "School_Icon_WILDHUNT.png",
    }
    filename = mapping.get((school or "").strip(), "School_Icon_ETC.png")
    path = SCHOOL_LOGO_DIR / filename
    return path if path.exists() else None


def _school_logo_badge_path(school: str | None, *, size: int) -> Path | None:
    logo_path = _school_logo_path(school)
    if logo_path is None:
        return None
    badge_dir = Path(os.environ.get("BA_PLANNER_CACHE_DIR") or (BASE_DIR / "debug" / "school_badges"))
    badge_dir.mkdir(parents=True, exist_ok=True)
    safe_school = re.sub(r"[^A-Za-z0-9_-]+", "_", (school or "ETC").strip() or "ETC")
    badge_path = badge_dir / f"{safe_school}_{size}.png"
    source_mtime = max(
        logo_path.stat().st_mtime if logo_path.exists() else 0,
        ITEM_ICON_DEFAULT_BACKGROUND.stat().st_mtime if ITEM_ICON_DEFAULT_BACKGROUND.exists() else 0,
    )
    if badge_path.exists() and badge_path.stat().st_mtime >= source_mtime:
        return badge_path

    badge = QPixmap(size, size)
    badge.fill(Qt.transparent)
    painter = QPainter(badge)
    if ITEM_ICON_DEFAULT_BACKGROUND.exists():
        background = QPixmap(str(ITEM_ICON_DEFAULT_BACKGROUND))
        if not background.isNull():
            painter.drawPixmap(0, 0, size, size, background)
    logo = QPixmap(str(logo_path))
    if not logo.isNull():
        logo_size = max(1, int(size * 0.78))
        inset = (size - logo_size) // 2
        painter.drawPixmap(
            QRect(inset, inset, logo_size, logo_size),
            logo.scaled(logo_size, logo_size, Qt.KeepAspectRatio, Qt.SmoothTransformation),
        )
    painter.end()
    badge.save(str(badge_path), "PNG")
    return badge_path if badge_path.exists() else logo_path


def _school_logo_tinted_path(school: str | None, *, size: int, color: str = "#f7fbff") -> Path | None:
    logo_path = _school_logo_path(school)
    if logo_path is None:
        return None
    cache_dir = Path(os.environ.get("BA_PLANNER_CACHE_DIR") or (BASE_DIR / "debug" / "school_badges"))
    cache_dir.mkdir(parents=True, exist_ok=True)
    safe_school = re.sub(r"[^A-Za-z0-9_-]+", "_", (school or "ETC").strip() or "ETC")
    safe_color = color.replace("#", "")
    tinted_path = cache_dir / f"{safe_school}_{size}_{safe_color}_logo.png"
    source_mtime = logo_path.stat().st_mtime if logo_path.exists() else 0
    if tinted_path.exists() and tinted_path.stat().st_mtime >= source_mtime:
        return tinted_path

    logo = QPixmap(str(logo_path))
    if logo.isNull():
        return logo_path
    tinted = _tinted_pixmap(logo, color, QSize(size, size))
    if tinted.isNull():
        return logo_path
    tinted.save(str(tinted_path), "PNG")
    return tinted_path if tinted_path.exists() else logo_path


def _tinted_pixmap(pixmap: QPixmap, color: str, size: QSize | None = None) -> QPixmap:
    source = pixmap
    if size is not None and size.isValid():
        source = pixmap.scaled(size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
    if source.isNull():
        return QPixmap()
    canvas = QPixmap(source.size())
    canvas.fill(Qt.transparent)
    painter = QPainter(canvas)
    painter.drawPixmap(0, 0, source)
    painter.setCompositionMode(QPainter.CompositionMode_SourceIn)
    painter.fillRect(canvas.rect(), QColor(color))
    painter.end()
    return canvas


def _item_icon_tier_index(item_id: str | None) -> int | None:
    text = str(item_id or "")
    if text in {"Item_Icon_SkillBook_Ultimate", "Item_Icon_SkillBook_Ultimate_Piece", "Item_Icon_SkillBook_Ultimated"}:
        return 3
    match = re.search(r"_(\d+)$", text)
    if match:
        return int(match.group(1))
    return None


def _uses_tiered_item_background(item_id: str | None) -> bool:
    text = str(item_id or "")
    if text in _OPART_ITEM_IDS:
        return True
    return (
        text.startswith("Item_Icon_ExpItem_")
        or text.startswith("report_")
        or text.startswith("Item_Icon_SkillBook_")
        or text.startswith("Item_Icon_Material_ExSkill_")
        or text.startswith("Equipment_Icon_Exp_")
        or text.startswith("Equipment_Icon_WeaponExpGrowth")
    )


def _is_present_item_id(item_id: str | None) -> bool:
    text = str(item_id or "")
    return text == "Item_Icon_Favor_Selection" or text.startswith("Item_Icon_Favor_")


def _is_t3_present_item_id(item_id: str | None) -> bool:
    text = str(item_id or "")
    return text.startswith("Item_Icon_Favor_SSR") or text.startswith("Item_Icon_Favor_Lv2_") or text == "Item_Icon_Favor_Random_Lv2"


def _uses_yellow_item_background(item_id: str | None) -> bool:
    text = str(item_id or "")
    return (
        (_is_present_item_id(text) and not _is_t3_present_item_id(text))
        or text in _WORKBOOK_ID_TO_NAME
        or text in _WB_ITEM_IDS
        or text.startswith("Item_Icon_WorkBook_")
    )


def _item_icon_background_path(item_id: str | None = None) -> Path | None:
    if _is_t3_present_item_id(item_id) and ITEM_ICON_BACKGROUND_PURPLE.exists():
        return ITEM_ICON_BACKGROUND_PURPLE
    if _uses_yellow_item_background(item_id) and ITEM_ICON_BACKGROUND_YELLOW.exists():
        return ITEM_ICON_BACKGROUND_YELLOW
    if _uses_tiered_item_background(item_id):
        tier_index = _item_icon_tier_index(item_id)
        if tier_index is not None:
            tier_path = ITEM_ICON_BACKGROUND_BY_TIER_INDEX.get(tier_index)
            if tier_path is not None and tier_path.exists():
                return tier_path
    return ITEM_ICON_DEFAULT_BACKGROUND if ITEM_ICON_DEFAULT_BACKGROUND.exists() else None


def _draw_centered_pixmap(painter: QPainter, pixmap: QPixmap, bounds: QRect) -> None:
    if pixmap.isNull() or not bounds.isValid():
        return
    scaled = pixmap.scaled(bounds.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
    x = bounds.x() + (bounds.width() - scaled.width()) // 2
    y = bounds.y() + (bounds.height() - scaled.height()) // 2
    painter.drawPixmap(x, y, scaled)


def _item_icon_pixmap(
    *,
    size: QSize,
    item_id: str | None = None,
    icon_path: Path | None = None,
    icon: QPixmap | None = None,
) -> QPixmap:
    if not size.isValid() or size.width() <= 0 or size.height() <= 0:
        return QPixmap()

    source = QPixmap(icon) if icon is not None else QPixmap()
    if source.isNull() and icon_path is not None and icon_path.exists():
        source = QPixmap(str(icon_path))
    if source.isNull():
        return QPixmap()

    background_path = _item_icon_background_path(item_id)
    if background_path is None:
        return source.scaled(size, Qt.KeepAspectRatio, Qt.SmoothTransformation)

    background = QPixmap(str(background_path))
    if background.isNull():
        return source.scaled(size, Qt.KeepAspectRatio, Qt.SmoothTransformation)

    canvas = QPixmap(size)
    canvas.fill(Qt.transparent)
    painter = QPainter(canvas)
    _draw_centered_pixmap(painter, background, canvas.rect())
    _draw_centered_pixmap(painter, source, canvas.rect())
    painter.end()
    return canvas


def _item_icon(icon_path: Path | None, *, size: QSize, item_id: str | None = None) -> QIcon:
    pixmap = _item_icon_pixmap(size=size, item_id=item_id, icon_path=icon_path)
    return QIcon(pixmap) if not pixmap.isNull() else QIcon()


def _scan_inventory_slot_pixmap(
    *,
    size: QSize,
    item_id: str | None = None,
    item_name: str | None = None,
    quantity: str | None = None,
    tier: object = None,
    slot_number: int | None = None,
) -> QPixmap:
    if not size.isValid() or size.width() <= 0 or size.height() <= 0:
        return QPixmap()

    icon_path = _inventory_icon_path(item_id, item_name)
    canvas = QPixmap(size)
    canvas.fill(Qt.transparent)
    painter = QPainter(canvas)
    painter.setRenderHint(QPainter.SmoothPixmapTransform, True)
    painter.setRenderHint(QPainter.TextAntialiasing, True)

    base_icon = QPixmap()
    if icon_path is not None and icon_path.exists():
        base_icon = _item_icon_pixmap(size=size, item_id=item_id, icon_path=icon_path)
    if base_icon.isNull():
        background_path = _item_icon_background_path(item_id)
        if background_path is None or not background_path.exists():
            background_path = ITEM_ICON_DEFAULT_BACKGROUND if ITEM_ICON_DEFAULT_BACKGROUND.exists() else None
        if background_path is not None:
            background = QPixmap(str(background_path))
            if not background.isNull():
                _draw_centered_pixmap(painter, background, canvas.rect())
    else:
        painter.drawPixmap(0, 0, base_icon)

    badge_text = str(quantity or '').strip()
    if not badge_text and slot_number is not None:
        badge_text = str(slot_number)
    if badge_text:
        font = QFont()
        font.setBold(True)
        font.setPixelSize(max(9, int(round(size.height() * 0.24))))
        metrics = QFontMetrics(font)
        max_width = max(16, size.width() - max(6, int(round(size.width() * 0.16))))
        painter.setFont(font)
        text_width = metrics.horizontalAdvance(badge_text)
        text_height = metrics.height()
        pad_x = max(3, int(round(size.width() * 0.08)))
        pad_y = max(2, int(round(size.height() * 0.06)))
        rect_width = min(max_width, text_width + 2)
        rect = QRect(
            size.width() - rect_width - pad_x,
            size.height() - text_height - pad_y,
            rect_width,
            text_height + 1,
        )
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            painter.setPen(QColor(20, 24, 32, 220))
            painter.drawText(rect.translated(dx, dy), Qt.AlignRight | Qt.AlignVCenter, badge_text)
        painter.setPen(QColor('#ffffff'))
        painter.drawText(rect, Qt.AlignRight | Qt.AlignVCenter, badge_text)

    painter.end()
    return canvas

class ParallelogramPanel(QWidget):
    def __init__(
        self,
        fill: str = "rgba(55, 65, 98, 0.45)",
        border: str = "#4b5b84",
        slant: float = 0.22,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._fill = QColor(fill)
        self._border = QColor(border)
        self._slant_ratio = max(0.08, min(float(slant), 0.36))
        self.setAttribute(Qt.WA_TranslucentBackground, True)

    def setColors(self, fill: str, border: str | None = None) -> None:
        self._fill = QColor(fill)
        self._border = QColor(border or fill)
        self.update()

    def _slant_for_size(self, width: int, height: int) -> int:
        return max(8, min(int(round(height * self._slant_ratio)), max(8, width // 4)))

    def edge_bounds_at_y(self, y: float) -> tuple[float, float]:
        width = max(1, self.width())
        height = max(1, self.height())
        slant = self._slant_for_size(width, height)
        progress = 0.0 if height <= 1 else max(0.0, min(1.0, y / float(height - 1)))
        left = slant * (1.0 - progress)
        right = (width - 1) - (slant * progress)
        return left, right

    def paintEvent(self, event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        width = max(1, self.width())
        height = max(1, self.height())
        slant = self._slant_for_size(width, height)
        path = self._rounded_parallelogram_path(width, height, slant)
        painter.fillPath(path, self._fill)
        painter.setPen(QPen(self._border, 1))
        painter.drawPath(path)
        painter.end()

    @staticmethod
    def _rounded_parallelogram_path(width: int, height: int, slant: int) -> QPainterPath:
        points = [
            (float(slant), 0.0),
            (float(width - 1), 0.0),
            (float(width - slant - 1), float(height - 1)),
            (0.0, float(height - 1)),
        ]
        edge_lengths = []
        for index in range(4):
            ax, ay = points[index]
            bx, by = points[(index + 1) % 4]
            edge_lengths.append(math.hypot(bx - ax, by - ay))

        radius = max(4.0, min(height * 0.18, width * 0.12, min(edge_lengths) * 0.28))

        def _offset(point_from: tuple[float, float], point_to: tuple[float, float], distance: float) -> tuple[float, float]:
            fx, fy = point_from
            tx, ty = point_to
            length = math.hypot(tx - fx, ty - fy)
            if length <= 1e-6:
                return fx, fy
            ratio = distance / length
            return fx + ((tx - fx) * ratio), fy + ((ty - fy) * ratio)

        path = QPainterPath()
        start = _offset(points[0], points[1], radius)
        path.moveTo(*start)
        for index in (1, 2, 3, 0):
            current = points[index]
            prev_point = points[(index - 1) % 4]
            next_point = points[(index + 1) % 4]
            edge_in = _offset(current, prev_point, radius)
            edge_out = _offset(current, next_point, radius)
            path.lineTo(*edge_in)
            path.quadTo(current[0], current[1], edge_out[0], edge_out[1])
        path.closeSubpath()
        return path


class EquipmentDetailCard(ParallelogramPanel):
    def __init__(self, ui_scale: float, *, fill: str, border: str, slant: float, parent: QWidget | None = None) -> None:
        super().__init__(fill=fill, border=border, slant=slant, parent=parent)
        self._ui_scale = ui_scale
        self._icon = QPixmap()
        self._value_text = "-"
        self._level_text = ""
        self._value_color = QColor(INK)
        self._level_color = QColor(INK)
        self.setMinimumHeight(scale_px(92, ui_scale))
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

    def setData(self, *, icon: QPixmap | None, value: str, level: str = "") -> None:
        self._icon = icon or QPixmap()
        self._value_text = value or ""
        self._level_text = level or ""
        self.update()

    def clearData(self) -> None:
        self._icon = QPixmap()
        self._value_text = "-"
        self._level_text = ""
        self.update()

    def paintEvent(self, event) -> None:
        super().paintEvent(event)

        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.setRenderHint(QPainter.SmoothPixmapTransform, True)

        height = max(1, self.height())
        pad_x = scale_px(8, self._ui_scale)
        pad_y = scale_px(6, self._ui_scale)
        center_y = height * 0.54

        if not self._icon.isNull():
            icon_size = scale_px(63, self._ui_scale)
            scaled = self._icon.scaled(icon_size, icon_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            left, right = self.edge_bounds_at_y(center_y)
            center_x = (left + right) / 2.0
            x = int(round(center_x - (scaled.width() / 2)))
            y = int(round(center_y - (scaled.height() / 2)))
            painter.drawPixmap(max(0, x), max(0, y), scaled)

        if self._level_text:
            level_font = QFont(self.font())
            level_font.setItalic(True)
            level_font.setBold(True)
            level_font.setPixelSize(scale_px(17, self._ui_scale))
            painter.setFont(level_font)
            painter.setPen(self._level_color)
            left, right = self.edge_bounds_at_y(pad_y + scale_px(10, self._ui_scale))
            level_rect = QRect(
                int(round(left + pad_x)),
                pad_y,
                max(scale_px(28, self._ui_scale), int(round(right - left - (pad_x * 2)))),
                scale_px(22, self._ui_scale),
            )
            painter.drawText(level_rect, Qt.AlignLeft | Qt.AlignVCenter, self._level_text)

        if self._value_text:
            value_font = QFont(self.font())
            value_font.setBold(True)
            value_font.setPixelSize(scale_px(25 if len(self._value_text) <= 2 else 21, self._ui_scale))
            painter.setFont(value_font)
            painter.setPen(self._value_color)
            left, right = self.edge_bounds_at_y(center_y)
            value_rect = QRect(
                int(round(left + pad_x)),
                int(round(center_y - scale_px(18, self._ui_scale))),
                max(scale_px(30, self._ui_scale), int(round(right - left - (pad_x * 2)))),
                scale_px(36, self._ui_scale),
            )
            painter.drawText(value_rect, Qt.AlignCenter, self._value_text)
        painter.end()


class DetailProgressStrip(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._star_count = 0
        self._weapon_star_count = 0
        self._show_weapon = False
        self.setFixedHeight(18)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

    def setProgress(self, star_count: int, weapon_star_count: int, show_weapon: bool) -> None:
        self._star_count = max(0, min(5, int(star_count)))
        self._weapon_star_count = max(0, min(4, int(weapon_star_count)))
        self._show_weapon = bool(show_weapon)
        self.update()

    def paintEvent(self, event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)

        active_rect = self.rect().adjusted(0, 0, 0, -1)
        segment_gap = 4
        segment_count = 5 + (4 if self._show_weapon else 0)
        if segment_count <= 0:
            painter.end()
            return

        segment_width = max(10, int((active_rect.width() - (segment_gap * (segment_count - 1))) / segment_count))
        segment_height = max(8, active_rect.height())
        y = active_rect.y() + max(0, (active_rect.height() - segment_height) // 2)

        for index in range(segment_count):
            x = active_rect.x() + (index * (segment_width + segment_gap))
            path = ParallelogramPanel._rounded_parallelogram_path(segment_width, segment_height, max(4, int(round(segment_height * DETAIL_SLANT))))

            painter.save()
            painter.translate(x, y)
            if index < 5:
                filled = index < self._star_count
                fill = QColor("#ffd84a" if filled else _mix_hex("#ffd84a", SURFACE_ALT, 0.78))
                border = QColor("#ffe88f" if filled else _mix_hex("#ffe88f", SURFACE_ALT, 0.58))
            else:
                weapon_index = index - 5
                filled = weapon_index < self._weapon_star_count
                fill = QColor("#69c6ff" if filled else _mix_hex("#69c6ff", SURFACE_ALT, 0.8))
                border = QColor("#b6e6ff" if filled else _mix_hex("#b6e6ff", SURFACE_ALT, 0.6))
            painter.fillPath(path, fill)
            painter.setPen(QPen(border, 1))
            painter.drawPath(path)
            painter.restore()

        painter.end()



class ScanLiveProgressStrip(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._star_count = 0
        self._weapon_star_count = 0
        self._show_weapon = False
        self.setFixedHeight(34)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

    def setProgress(self, star_count: int, weapon_star_count: int, show_weapon: bool) -> None:
        self._star_count = max(0, min(5, int(star_count)))
        self._weapon_star_count = max(0, min(5, int(weapon_star_count)))
        self._show_weapon = bool(show_weapon)
        self.update()

    def _draw_row(
        self,
        painter: QPainter,
        *,
        y: int,
        row_height: int,
        filled_count: int,
        active_fill: str,
        active_border: str,
        inactive_mix: float,
        enabled: bool = True,
    ) -> None:
        active_rect = self.rect().adjusted(0, 0, 0, -1)
        segment_gap = 4
        segment_count = 5
        segment_width = max(10, int((active_rect.width() - (segment_gap * (segment_count - 1))) / segment_count))
        segment_height = max(7, row_height)
        for index in range(segment_count):
            x = active_rect.x() + (index * (segment_width + segment_gap))
            path = ParallelogramPanel._rounded_parallelogram_path(
                segment_width,
                segment_height,
                max(4, int(round(segment_height * DETAIL_SLANT))),
            )
            painter.save()
            painter.translate(x, y)
            filled = enabled and index < filled_count
            fill = QColor(active_fill if filled else _mix_hex(active_fill, SURFACE_ALT, inactive_mix))
            border = QColor(active_border if filled else _mix_hex(active_border, SURFACE_ALT, 0.62))
            painter.fillPath(path, fill)
            painter.setPen(QPen(border, 1))
            painter.drawPath(path)
            painter.restore()

    def paintEvent(self, event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        active_rect = self.rect().adjusted(0, 0, 0, -1)
        row_gap = 5
        row_height = max(7, int((active_rect.height() - row_gap) / 2))
        top_y = active_rect.y()
        bottom_y = top_y + row_height + row_gap
        self._draw_row(
            painter,
            y=top_y,
            row_height=row_height,
            filled_count=self._star_count,
            active_fill="#ffd84a",
            active_border="#ffe88f",
            inactive_mix=0.78,
            enabled=True,
        )
        self._draw_row(
            painter,
            y=bottom_y,
            row_height=row_height,
            filled_count=self._weapon_star_count,
            active_fill="#69c6ff",
            active_border="#b6e6ff",
            inactive_mix=0.82,
            enabled=self._show_weapon,
        )
        painter.end()
EQUIPMENT_TIER_MAX_LEVEL = {
    0: 0,
    1: 10,
    2: 20,
    3: 30,
    4: 40,
    5: 45,
    6: 50,
    7: 55,
    8: 60,
    9: 65,
    10: 70,
}


class PlanEditorCell(ParallelogramPanel):
    clicked = Signal()

    def __init__(self, label: str = "", *, compact: bool = False, ui_scale: float = 1.0, parent: QWidget | None = None) -> None:
        super().__init__(fill=SURFACE_ALT, border=BORDER, slant=DETAIL_SLANT, parent=parent)
        self._label = label
        self._text_color = QColor(INK)
        self._current_marker = False
        self._clickable = True
        self._compact = compact
        self._ui_scale = ui_scale
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setMinimumHeight(scale_px(15 if compact else 20, self._ui_scale))

    def setCellState(
        self,
        *,
        label: str | None = None,
        fill: str,
        border: str,
        text_color: str,
        current_marker: bool = False,
        clickable: bool = True,
    ) -> None:
        if label is not None:
            self._label = label
        self.setColors(fill, border)
        self._text_color = QColor(text_color)
        self._current_marker = current_marker
        self._clickable = clickable
        self.update()

    def mousePressEvent(self, event) -> None:
        if event.button() == Qt.LeftButton and self._clickable and self.isEnabled():
            self.clicked.emit()
            event.accept()
            return
        super().mousePressEvent(event)

    def paintEvent(self, event) -> None:
        super().paintEvent(event)
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        font = QFont(self.font())
        font.setBold(True)
        font.setPixelSize(scale_px(8 if self._compact else 10, self._ui_scale))
        painter.setFont(font)
        painter.setPen(self._text_color)
        rect = self.rect().adjusted(scale_px(4, self._ui_scale), 0, -scale_px(4, self._ui_scale), 0)
        painter.drawText(rect, Qt.AlignCenter, self._label)
        if self._current_marker:
            marker_h = max(2, scale_px(2, self._ui_scale))
            marker_rect = QRect(
                scale_px(6, self._ui_scale),
                self.height() - marker_h - scale_px(3, self._ui_scale),
                max(scale_px(12, self._ui_scale), self.width() - scale_px(12, self._ui_scale)),
                marker_h,
            )
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor("#f4fbff"))
            painter.drawRoundedRect(marker_rect, marker_h, marker_h)
        painter.end()


class PlanSegmentSelector(QWidget):
    valueChanged = Signal(int)

    def __init__(
        self,
        count: int,
        *,
        color_break: int = 0,
        active_fill: str = ACCENT_STRONG,
        active_border: str = ACCENT,
        inactive_fill: str | None = None,
        inactive_border: str | None = None,
        ui_scale: float = 1.0,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._count = count
        self._color_break = color_break
        self._fallback_fill = active_fill
        self._fallback_border = active_border
        self._inactive_fill = inactive_fill if inactive_fill is not None else _mix_hex(SURFACE_ALT, BG, 0.08)
        self._inactive_border = inactive_border if inactive_border is not None else _mix_hex(BORDER, SURFACE_ALT, 0.18)
        self._ui_scale = ui_scale
        self._minimum_value = 0
        self._value = 0
        self._enabled_count = count
        self._cells: list[PlanEditorCell] = []
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(2, self._ui_scale))
        for index in range(1, count + 1):
            cell = PlanEditorCell(compact=True, ui_scale=self._ui_scale)
            cell.clicked.connect(lambda idx=index: self._on_cell_clicked(idx))
            self._cells.append(cell)
            layout.addWidget(cell, 1)
        self._refresh_cells()

    def setState(self, *, minimum_value: int, value: int, enabled_count: int | None = None) -> None:
        next_minimum = max(0, min(self._count, minimum_value))
        next_enabled_count = max(0, min(self._count, enabled_count if enabled_count is not None else self._count))
        next_value = max(next_minimum, min(next_enabled_count, value))
        if (
            next_minimum == self._minimum_value
            and next_enabled_count == self._enabled_count
            and next_value == self._value
        ):
            return
        self._minimum_value = next_minimum
        self._enabled_count = next_enabled_count
        self._value = next_value
        self._refresh_cells()

    def value(self) -> int:
        return self._value

    def setEnabled(self, enabled: bool) -> None:
        if enabled == self.isEnabled():
            return
        super().setEnabled(enabled)
        self._refresh_cells()

    def _colors_for_index(self, index: int) -> tuple[str, str]:
        if self._color_break and index > self._color_break:
            return "#69c6ff", "#b6e6ff"
        if self._color_break:
            return "#ffd84a", "#ffe88f"
        return self._fallback_fill, self._fallback_border

    def _refresh_cells(self) -> None:
        for index, cell in enumerate(self._cells, start=1):
            accent_fill, accent_border = self._colors_for_index(index)
            clickable = self.isEnabled() and index <= self._enabled_count
            if not clickable:
                fill = _mix_hex(SURFACE_ALT, BG, 0.22)
                border = _mix_hex(BORDER, SURFACE_ALT, 0.4)
                text_color = MUTED
            elif index <= self._value:
                if index <= self._minimum_value:
                    fill = _mix_hex(accent_fill, SURFACE_ALT, 0.2)
                    border = _mix_hex(accent_border, "#ffffff", 0.12)
                else:
                    fill = accent_fill
                    border = accent_border
                text_color = "#112031"
            else:
                fill = self._inactive_fill
                border = self._inactive_border
                text_color = MUTED
            cell.setCellState(fill=fill, border=border, text_color=text_color, clickable=clickable)

    def _on_cell_clicked(self, index: int) -> None:
        if index > self._enabled_count:
            return
        candidate = max(self._minimum_value, index)
        if index == self._value:
            candidate = max(self._minimum_value, index - 1)
        if candidate == self._value:
            return
        self._value = candidate
        self._refresh_cells()
        self.valueChanged.emit(candidate)


class PlanOptionStrip(QWidget):
    valueClicked = Signal(object)

    def __init__(self, options: list[object], *, compact: bool = True, ui_scale: float = 1.0, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._options = list(options)
        self._selected_value = self._options[0] if self._options else 0
        self._current_value: object | None = None
        self._enabled_values: set[object] = set(self._options)
        self._ui_scale = ui_scale
        self._cells: dict[object, PlanEditorCell] = {}
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(4, self._ui_scale))
        for option in self._options:
            cell = PlanEditorCell(str(option), compact=compact, ui_scale=self._ui_scale)
            cell.clicked.connect(lambda value=option: self.valueClicked.emit(value))
            self._cells[option] = cell
            layout.addWidget(cell, 1)
        self._refresh_cells()

    def setState(self, *, selected_value: object, current_value: object | None = None, enabled_values: set[object] | None = None) -> None:
        self._selected_value = selected_value
        self._current_value = current_value
        self._enabled_values = set(self._options if enabled_values is None else enabled_values)
        self._refresh_cells()

    def _refresh_cells(self) -> None:
        for value, cell in self._cells.items():
            enabled = self.isEnabled() and value in self._enabled_values
            is_selected = value == self._selected_value
            is_current = self._current_value is not None and value == self._current_value
            if not enabled:
                fill = _mix_hex(SURFACE_ALT, BG, 0.22)
                border = _mix_hex(BORDER, SURFACE_ALT, 0.4)
                text_color = MUTED
            elif is_selected:
                fill = ACCENT_STRONG
                border = ACCENT
                text_color = "#ffffff"
            elif is_current:
                fill = _mix_hex(PALETTE_SOFT, SURFACE_ALT, 0.44)
                border = _mix_hex("#ffffff", PALETTE_SOFT, 0.22)
                text_color = INK
            else:
                fill = _mix_hex(SURFACE_ALT, BG, 0.08)
                border = _mix_hex(BORDER, SURFACE_ALT, 0.18)
                text_color = MUTED
            cell.setCellState(
                fill=fill,
                border=border,
                text_color=text_color,
                current_marker=is_current and not is_selected,
                clickable=enabled,
            )

class LiveSearchLineEdit(QLineEdit):
    liveTextChanged = Signal(str)

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._preedit_text = ""
        self.textChanged.connect(self._emit_live_text)

    def liveText(self) -> str:
        if not self._preedit_text:
            return self.text()
        cursor = self.cursorPosition()
        base_text = self.text()
        return f"{base_text[:cursor]}{self._preedit_text}{base_text[cursor:]}"

    def inputMethodEvent(self, event) -> None:
        super().inputMethodEvent(event)
        self._preedit_text = event.preeditString() or ""
        self._emit_live_text()

    def focusOutEvent(self, event) -> None:
        super().focusOutEvent(event)
        if self._preedit_text:
            self._preedit_text = ""
            self._emit_live_text()

    def _emit_live_text(self, *_args) -> None:
        self.liveTextChanged.emit(self.liveText())


class PlanStepper(QWidget):
    valueChanged = Signal(int)

    def __init__(self, max_value: int, *, ui_scale: float = 1.0, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._max_value = max_value
        self._ui_scale = ui_scale
        self._minimum_value = 0
        self._value = 0
        self._updating = False

        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(6, self._ui_scale))

        self._input = QLineEdit("0")
        self._input.setObjectName("planValueInput")
        self._input.setAlignment(Qt.AlignCenter)
        self._input.setValidator(QIntValidator(0, self._max_value, self))
        self._input.setMinimumHeight(scale_px(34, self._ui_scale))
        self._input.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self._input.textEdited.connect(self._on_text_edited)
        self._input.editingFinished.connect(self._on_editing_finished)
        layout.addWidget(self._input, 1)

        self._minus_button = QPushButton("-")
        self._minus_button.setObjectName("planStepButton")
        self._minus_button.setMinimumHeight(scale_px(34, self._ui_scale))
        self._minus_button.setFixedWidth(scale_px(34, self._ui_scale))
        self._minus_button.clicked.connect(lambda: self._step_by(-1))
        layout.addWidget(self._minus_button)

        self._plus_button = QPushButton("+")
        self._plus_button.setObjectName("planStepButton")
        self._plus_button.setMinimumHeight(scale_px(34, self._ui_scale))
        self._plus_button.setFixedWidth(scale_px(34, self._ui_scale))
        self._plus_button.clicked.connect(lambda: self._step_by(1))
        layout.addWidget(self._plus_button)

        self._min_label = QLabel("MIN 0")
        self._min_label.setObjectName("detailMiniSub")
        self._min_label.setAlignment(Qt.AlignCenter)
        self._min_label.setMinimumWidth(scale_px(52, self._ui_scale))
        layout.addWidget(self._min_label)

        self._max_button = QPushButton("MAX")
        self._max_button.setObjectName("planQuickButton")
        self._max_button.setMinimumHeight(scale_px(34, self._ui_scale))
        self._max_button.setMinimumWidth(scale_px(54, self._ui_scale))
        self._max_button.clicked.connect(self._set_to_max)
        layout.addWidget(self._max_button)

        self._refresh()

    def setState(self, *, minimum_value: int, value: int) -> None:
        next_minimum = max(0, min(self._max_value, minimum_value))
        next_value = max(next_minimum, min(self._max_value, value))
        if next_minimum == self._minimum_value and next_value == self._value:
            return
        self._minimum_value = next_minimum
        self._value = next_value
        self._refresh()

    def value(self) -> int:
        return self._value

    def setMaximumValue(self, maximum_value: int) -> None:
        next_max_value = max(0, int(maximum_value))
        if next_max_value == self._max_value:
            return
        self._max_value = next_max_value
        self._input.setValidator(QIntValidator(0, self._max_value, self))
        self._minimum_value = min(self._minimum_value, self._max_value)
        self._value = min(self._value, self._max_value)
        self._refresh()

    def setEnabled(self, enabled: bool) -> None:
        if enabled == self.isEnabled():
            return
        super().setEnabled(enabled)
        self._refresh()

    def _commit_value(self, candidate: int, *, emit_signal: bool) -> None:
        candidate = max(self._minimum_value, min(self._max_value, int(candidate)))
        changed = candidate != self._value
        self._value = candidate
        self._refresh()
        if emit_signal and changed:
            self.valueChanged.emit(candidate)

    def _on_text_edited(self, text: str) -> None:
        if self._updating:
            return
        stripped = text.strip()
        if not stripped:
            return
        self._commit_value(int(stripped), emit_signal=True)

    def _on_editing_finished(self) -> None:
        text = self._input.text().strip()
        if not text:
            self._refresh()
            return
        self._commit_value(int(text), emit_signal=True)

    def _set_to_max(self) -> None:
        if not self.isEnabled():
            return
        self._commit_value(self._max_value, emit_signal=True)

    def _step_by(self, delta: int) -> None:
        if not self.isEnabled():
            return
        self._commit_value(self._value + int(delta), emit_signal=True)

    def _refresh(self) -> None:
        self._updating = True
        try:
            self._input.setText(str(self._value))
        finally:
            self._updating = False
        self._input.setPlaceholderText(str(self._minimum_value))
        self._min_label.setText(f"최소 {self._minimum_value}")
        enabled = self.isEnabled()
        self._input.setEnabled(enabled)
        self._minus_button.setEnabled(enabled and self._value > self._minimum_value)
        self._plus_button.setEnabled(enabled and self._value < self._max_value)
        self._max_button.setEnabled(enabled and self._value < self._max_value)


class PlanDualDigitSelector(QWidget):
    valueChanged = Signal(int)

    def __init__(self, max_value: int, *, ui_scale: float = 1.0, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._max_value = max_value
        self._ui_scale = ui_scale
        self._minimum_value = 0
        self._value = 0
        self._tens_options = list(range((max_value // 10) + 1))
        self._tens_strip = PlanOptionStrip(self._tens_options, ui_scale=self._ui_scale)
        self._ones_strip = PlanOptionStrip(list(range(10)), ui_scale=self._ui_scale)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(6, self._ui_scale))

        tens_caption = QLabel("10s")
        tens_caption.setObjectName("detailSectionTitle")
        layout.addWidget(tens_caption)
        self._tens_strip.valueClicked.connect(self._on_tens_clicked)
        layout.addWidget(self._tens_strip)

        ones_caption = QLabel("1s")
        ones_caption.setObjectName("detailSectionTitle")
        layout.addWidget(ones_caption)
        self._ones_strip.valueClicked.connect(self._on_ones_clicked)
        layout.addWidget(self._ones_strip)

    def setState(self, *, minimum_value: int, value: int) -> None:
        self._minimum_value = max(0, min(self._max_value, minimum_value))
        self._value = max(self._minimum_value, min(self._max_value, value))
        self._refresh_strips()

    def value(self) -> int:
        return self._value

    def setMaximumValue(self, maximum_value: int) -> None:
        self._max_value = max(0, int(maximum_value))
        self._tens_options = list(range((self._max_value // 10) + 1))
        self._minimum_value = min(self._minimum_value, self._max_value)
        self._value = min(self._value, self._max_value)
        self._refresh_strips()

    def _refresh_strips(self) -> None:
        current_tens, current_ones = divmod(self._minimum_value, 10)
        selected_tens, selected_ones = divmod(self._value, 10)
        max_ones = self._max_value - (selected_tens * 10) if selected_tens == max(self._tens_options) else 9
        enabled_ones = {value for value in range(max(0, min(9, max_ones)) + 1)}
        self._tens_strip.setState(selected_value=selected_tens, current_value=current_tens, enabled_values=set(self._tens_options))
        self._ones_strip.setState(selected_value=selected_ones, current_value=current_ones, enabled_values=enabled_ones)

    def _apply_candidate(self, candidate: int) -> None:
        clamped = max(self._minimum_value, min(self._max_value, candidate))
        if clamped == self._value:
            self._refresh_strips()
            return
        self._value = clamped
        self._refresh_strips()
        self.valueChanged.emit(clamped)

    def _on_tens_clicked(self, tens: int) -> None:
        ones = self._value % 10
        self._apply_candidate((tens * 10) + ones)

    def _on_ones_clicked(self, ones: int) -> None:
        tens = self._value // 10
        self._apply_candidate((tens * 10) + ones)


def _parse_tier_number(tier: str | None) -> int | None:
    value = (tier or "").strip().upper()
    if not value.startswith("T"):
        return None
    try:
        return int(value[1:])
    except ValueError:
        return None


def _equipment_icon_path(student_id: str, slot_index: int, tier: str | None) -> Path | None:
    tier_number = _parse_tier_number(tier)
    if tier_number is None:
        return None
    slots = student_meta.equipment_slots(student_id)
    if slot_index < 1 or slot_index > len(slots):
        return None
    slot_name = slots[slot_index - 1]
    if not slot_name:
        return None
    path = EQUIPMENT_ICON_DIR / f"Equipment_Icon_{slot_name}_Tier{tier_number}.png"
    return path if path.exists() else None


def _slot_placeholder(value: str | None, *, supported: bool = True) -> str:
    raw = str(value or "").strip().lower()
    if not supported or raw in {"level_locked", "love_locked", "null", "unsupported", "no_system"}:
        return ""
    if raw in {"", "unknown", "empty", "none", "0"}:
        return "-"
    return str(value or "-")


def _detail_stats_html(pairs: tuple[tuple[str, int | None], ...], *, font_px: int = 17) -> str:
    normalized = tuple((label, f"{(_int_or_none(value) or 0):,}") for label, value in pairs)
    if len(normalized) >= 4:
        left_rows = normalized[0::2]
        right_rows = normalized[1::2]
        rows = []
        for left, right in zip(left_rows, right_rows):
            rows.append(
                "<tr>"
                f"<td align='left' width='34'>{escape(left[0])}</td>"
                f"<td align='right' width='72' style='padding-left:8px;'>{escape(left[1])}</td>"
                "<td width='28'></td>"
                f"<td align='left' width='46'>{escape(right[0])}</td>"
                f"<td align='right' width='72' style='padding-left:8px;'>{escape(right[1])}</td>"
                "</tr>"
            )
        return (
            f"<table align='center' cellspacing='0' cellpadding='0' "
            f"style='font-size:{font_px}px; font-weight:800; color:#f7fbff;'>"
            + "".join(rows)
            + "</table>"
        )

    cells = []
    for label, value in normalized:
        cells.append(
            f"<td align='left' width='34'>{escape(label)}</td>"
            f"<td align='right' width='58' style='padding-left:8px; padding-right:10px;'>{escape(value)}</td>"
        )
    return (
        f"<table align='center' cellspacing='0' cellpadding='0' "
        f"style='font-size:{font_px}px; font-weight:800; color:#f7fbff;'><tr>"
        + "".join(cells)
        + "</tr></table>"
    )


def _detail_bonus_stats_html(pairs: tuple[tuple[str, int | None], ...], *, font_px: int = 13) -> str:
    pieces = [f"{escape(label)} {(_int_or_none(value) or 0):,}" for label, value in pairs]
    return (
        f"<span style='font-size:{font_px}px; font-weight:800; color:#c9c9d4;'>"
        + "&nbsp;&nbsp;|&nbsp;&nbsp;".join(pieces)
        + "</span>"
    )



def _scan_live_vertical_stats_html(pairs: tuple[tuple[str, int | None], ...], *, font_px: int = 14) -> str:
    rows = []
    for label, value in pairs:
        rows.append(
            "<tr>"
            f"<td align='left' width='42'>{escape(label)}</td>"
            f"<td align='right' width='76' style='padding-left:10px;'>{escape(f'{(_int_or_none(value) or 0):,}')}</td>"
            "</tr>"
        )
    return (
        f"<table align='center' cellspacing='0' cellpadding='0' "
        f"style='font-size:{font_px}px; font-weight:800; color:#f7fbff;'>"
        + "".join(rows)
        + "</table>"
    )
def _inventory_name_token(value: str | None) -> str:
    return "".join(str(value or "").split()).lower()


def _report_icon_token(name: str | None) -> str | None:
    return _REPORT_NAME_TO_ICON.get(_inventory_name_token(name))


def _report_icon_for_entry(item_id: str | None, name: str | None) -> str | None:
    if item_id:
        icon_token = _REPORT_ID_TO_ICON.get(item_id)
        if icon_token:
            return icon_token
    return _report_icon_token(name)


def _inventory_icon_path(item_id: str | None, name: str | None) -> Path | None:
    if item_id:
        item_id = _LEGACY_WB_ID_TO_ITEM_ID.get(item_id, item_id)
    elif name:
        item_id = _OPART_NAME_TO_ITEM_ID.get(name)

    name_token = _inventory_name_token(name)
    item_token = _inventory_name_token(item_id)
    if item_id == "Currency_Icon_Gold" or item_token in {"currency_icon_gold", "currencyicongold", "credits", "credit"} or name_token in {"크레딧", "credits", "credit"}:
        path = POLI_BG_DIR / "Currency_Icon_Gold.png"
        if path.exists():
            return path

    student_id = _student_id_from_eleph_item_id(item_id)
    if student_id:
        path = STUDENT_ELEPH_DIR / f"{item_id}.png"
        if path.exists():
            return path

    report_icon = _report_icon_for_entry(item_id, name)
    if report_icon:
        path = POLI_BG_DIR / f"{report_icon}.png"
        if path.exists():
            return path

    if item_id:
        if item_id == "Item_Icon_Favor_Selection":
            path = POLI_BG_DIR / f"{item_id}.png"
            if path.exists():
                return path
        if item_id.startswith("Item_Icon_Favor_"):
            path = PRESENT_ICON_DIR / f"{item_id}.png"
            if path.exists():
                return path
            path = INVENTORY_DETAIL_DIR / "presents" / f"{item_id}.png"
            if path.exists():
                return path
        if item_id in _WORKBOOK_ID_TO_NAME:
            path = POLI_BG_DIR / f"{item_id}.png"
            if path.exists():
                return path
        if item_id.startswith("Item_Icon_SkillBook_"):
            icon_item_id = "Item_Icon_SkillBook_Ultimate" if item_id in {
                "Item_Icon_SkillBook_Ultimate_Piece",
                "Item_Icon_SkillBook_Ultimated",
            } else item_id
            path = SKILL_BOOK_ICON_DIR / f"{icon_item_id}.png"
            if path.exists():
                return path
            path = INVENTORY_DETAIL_DIR / "tech_notes" / f"{icon_item_id}.png"
            if path.exists():
                return path
        if item_id.startswith("Item_Icon_Material_ExSkill_"):
            path = SKILL_DB_ICON_DIR / f"{item_id}.png"
            if path.exists():
                return path
            path = INVENTORY_DETAIL_DIR / "tactical_bd" / f"{item_id}.png"
            if path.exists():
                return path
        if item_id in _OPART_ITEM_IDS or item_id in _WB_ITEM_IDS:
            path = OPART_ICON_DIR / f"{item_id}.png"
            if path.exists():
                return path
        if item_id.startswith("Equipment_Icon_") and "_Tier" in item_id:
            path = EQUIPMENT_ICON_DIR / f"{item_id}.png"
            if path.exists():
                return path
            path = INVENTORY_DETAIL_DIR / "equipment" / f"{item_id}.png"
            if path.exists():
                return path
        if item_id.startswith("Equipment_Icon_Exp_") or item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
            path = EQUIPMENT_ICON_DIR / f"{item_id}.png"
            if path.exists():
                return path

    if name:
        path = INVENTORY_DETAIL_DIR / "activity_reports" / f"{name}.png"
        if path.exists():
            return path

    return None


def _inventory_quantity_value(raw_quantity: object) -> int | None:
    try:
        if raw_quantity in (None, ""):
            return None
        return int(str(raw_quantity).replace(",", ""))
    except (TypeError, ValueError):
        return None


def _inventory_display_label(item_key: str, payload: dict) -> str:
    item_id = payload.get("item_id")
    if item_id:
        item_id_text = str(item_id)
        student_id = _student_id_from_eleph_item_id(item_id_text)
        if student_id:
            return f"{student_meta.display_name(student_id)}의 엘레프"
        report_icon = _REPORT_ID_TO_ICON.get(item_id_text)
        if report_icon:
            return _REPORT_ICON_TO_NAME.get(report_icon, item_id_text)
        workbook_name = _WORKBOOK_ID_TO_NAME.get(item_id_text)
        if workbook_name:
            return workbook_name
    display_name = inventory_item_display_name(str(item_id)) if item_id else None
    return str(display_name or payload.get("name") or item_key)


def _plan_resource_split_tier(key: str) -> tuple[str, int | None]:
    base, separator, tier_text = key.rpartition(" T")
    if not separator:
        return key.strip(), None
    try:
        return base.strip(), int(tier_text)
    except ValueError:
        return key.strip(), None


def _student_id_from_eleph_item_id(item_id: str | None) -> str | None:
    prefix = "Item_Icon_SecretStone_"
    if item_id and item_id.startswith(prefix):
        return item_id[len(prefix):]
    return None


def _tier_from_item_id_or_name(item_id: str | None, name: str | None) -> int:
    text = f"{item_id or ''} {name or ''}"
    for pattern in (r"_Tier(\d+)", r" T(\d+)", r"_(\d+)(?:\s|$)"):
        match = re.search(pattern, text)
        if match:
            try:
                number = int(match.group(1))
            except ValueError:
                continue
            if pattern.startswith(r"_Tier"):
                return number
            return number + 1 if item_id and item_id.endswith(f"_{number}") else number
    return 0


def _equipment_series_key_from_item(item_id: str | None, name: str | None) -> str | None:
    text = item_id or ""
    match = re.match(r"Equipment_Icon_([^_]+)_Tier\d+", text)
    if match:
        return match.group(1)
    item_name = name or ""
    for series in EQUIPMENT_SERIES:
        if item_name in series.tier_names:
            return series.icon_key
    return None


def _plan_resource_item_id(key: str, category: str) -> str | None:
    base, tier = _plan_resource_split_tier(key)
    if category == "credits":
        return "Currency_Icon_Gold"
    if category == "star_materials" and key.startswith("Item_Icon_SecretStone_"):
        return key
    if tier is None:
        if category == "equipment_materials" and base in _EQUIPMENT_NAME_TO_ITEM_ID:
            return _EQUIPMENT_NAME_TO_ITEM_ID[base]
        return key if key.startswith(("Item_Icon_", "Equipment_Icon_")) else None

    zero_tier = max(0, tier - 1)
    if category == "level_exp":
        return f"Item_Icon_ExpItem_{zero_tier}"
    if category == "equipment_exp":
        return f"Equipment_Icon_Exp_{zero_tier}"
    if category == "weapon_exp":
        match = re.match(rf"{re.escape(WEAPON_EXP_ITEM_PREFIX)}([A-Z]+)(?:_\d+)?$", base)
        part_key = match.group(1) if match else "A"
        return f"{WEAPON_EXP_ITEM_PREFIX}{part_key}_{zero_tier}"
    if category == "skill_books":
        school, _, resource_kind = base.partition(" ")
        if school in _SCHOOL_SEQUENCE and resource_kind == "BD":
            return f"Item_Icon_Material_ExSkill_{school}_{zero_tier}"
        if school in _SCHOOL_SEQUENCE and resource_kind == "Note":
            if tier == 5:
                return "Item_Icon_SkillBook_Ultimate_Piece"
            return f"Item_Icon_SkillBook_{school}_{zero_tier}"
    if category == "equipment_materials" and base in EQUIPMENT_ITEM_ID_TO_NAME:
        return base
    if category == "equipment_materials" and base in _EQUIPMENT_NAME_TO_ITEM_ID:
        return _EQUIPMENT_NAME_TO_ITEM_ID[base]
    if category == "equipment_materials" and base in {series.icon_key for series in EQUIPMENT_SERIES}:
        return f"Equipment_Icon_{base}_Tier{tier}"
    if category in {"ex_ooparts", "skill_ooparts", "stat_materials"}:
        if base == "Item_Icon_WorkBook_PotentialMaxHP":
            return base
        icon_key = _OPART_EN_TO_ICON_KEY.get(base.casefold())
        if icon_key:
            return f"Item_Icon_Material_{icon_key}_{zero_tier}"
    if category == "favorite_item_materials":
        if base == "Item_Icon_Favor_Selection":
            return base
        icon_key = _OPART_EN_TO_ICON_KEY.get(base.casefold())
        if icon_key:
            return f"Item_Icon_Material_{icon_key}_{zero_tier}"
    return key if key.startswith(("Item_Icon_", "Equipment_Icon_")) else None


def _weapon_exp_item_part_and_tier(item_id: str | None) -> tuple[str, int] | None:
    if not item_id:
        return None
    match = re.match(rf"{re.escape(WEAPON_EXP_ITEM_PREFIX)}([A-Z]+)_(\d+)$", item_id)
    if not match:
        return None
    return match.group(1), int(match.group(2)) + 1


def _plan_resource_icon_path(item_id: str | None, name: str) -> Path | None:
    if item_id == "Currency_Icon_Gold":
        path = POLI_BG_DIR / "Currency_Icon_Gold.png"
        return path if path.exists() else None
    student_id = _student_id_from_eleph_item_id(item_id)
    if student_id:
        path = STUDENT_ELEPH_DIR / f"{item_id}.png"
        return path if path.exists() else None
    if item_id == "Item_Icon_Favor_Selection":
        path = POLI_BG_DIR / "Item_Icon_Favor_Selection.png"
        return path if path.exists() else None
    return _inventory_icon_path(item_id, name)


def _plan_resource_display_name(item_id: str | None, fallback: str) -> str:
    if item_id == "Currency_Icon_Gold":
        return "크레딧"
    student_id = _student_id_from_eleph_item_id(item_id)
    if student_id:
        return f"{student_meta.display_name(student_id)}의 엘레프"
    if item_id == "Item_Icon_Favor_Selection":
        return "Favorite Gift Selection"
    display_name = inventory_item_display_name(item_id) if item_id else None
    return str(display_name or fallback)


def load_latest_resource_snapshot() -> dict[str, int]:
    paths = get_storage_paths()

    def add_resource(target: dict[str, int], key: object, value: object) -> None:
        quantity = _inventory_quantity_value(value)
        if quantity is not None:
            target[str(key)] = quantity

    if paths.db_path.exists():
        try:
            init_db(paths.db_path)
            conn = sqlite3.connect(paths.db_path)
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                """
                SELECT r.key, r.value
                FROM resources AS r
                JOIN scans AS s ON s.scan_id = r.scan_id
                WHERE r.value IS NOT NULL AND r.value != ''
                ORDER BY s.scanned_at DESC, r.scan_id DESC
                """
            ).fetchall()
            conn.close()
            latest: dict[str, int] = {}
            for row in rows:
                key = str(row["key"])
                if key not in latest:
                    add_resource(latest, key, row["value"])
            if latest:
                return latest
        except Exception:
            pass

    if paths.scans_dir.exists():
        try:
            for path in sorted(paths.scans_dir.glob("*.json"), key=lambda item: item.stat().st_mtime, reverse=True):
                payload = json.loads(path.read_text(encoding="utf-8"))
                resources = payload.get("resources")
                if not isinstance(resources, dict):
                    resources = (payload.get("result") or {}).get("resources")
                if not isinstance(resources, dict):
                    continue
                latest: dict[str, int] = {}
                for key, value in resources.items():
                    add_resource(latest, key, value)
                if latest:
                    return latest
        except Exception:
            pass

    return {}


def _inventory_quantity_index(inventory: dict[str, dict], resources: dict[str, int] | None = None) -> dict[str, int]:
    index: dict[str, int] = {}
    for item_key, payload in inventory.items():
        quantity = _inventory_quantity_value(payload.get("quantity"))
        if quantity is None:
            continue
        candidates = {str(item_key)}
        item_id = payload.get("item_id")
        if item_id:
            candidates.add(str(item_id))
        name = payload.get("name")
        if name:
            candidates.add(str(name))
        for candidate in candidates:
            index[candidate] = max(index.get(candidate, 0), quantity)
    credit_quantity = _inventory_quantity_value((resources or {}).get("credit"))
    if credit_quantity is not None:
        for candidate in ("Currency_Icon_Gold", "credit", "credits", "크레딧"):
            index[candidate] = max(index.get(candidate, 0), credit_quantity)
    return index


def _load_ui_font_family() -> str | None:
    if not UI_FONT_PATH.exists():
        return None
    font_id = QFontDatabase.addApplicationFont(str(UI_FONT_PATH))
    if font_id < 0:
        return None
    families = QFontDatabase.applicationFontFamilies(font_id)
    return families[0] if families else None


def _apply_ui_font(app: QApplication) -> None:
    ui_font_family = _load_ui_font_family()
    if not ui_font_family:
        return
    ui_font = QFont(app.font())
    ui_font.setFamily(ui_font_family)
    ui_font.setPointSize(11)
    app.setFont(ui_font)


def _int_or_none(value: object) -> int | None:
    try:
        if value is None or value == "":
            return None
        return int(value)
    except (TypeError, ValueError):
        return None


@dataclass(slots=True)
class StudentRecord:
    student_id: str
    display_name: str
    owned: bool
    farmable: str | None
    level: int | None
    star: int
    weapon_state: str | None
    weapon_star: int | None
    weapon_level: int | None
    ex_skill: int | None
    skill1: int | None
    skill2: int | None
    skill3: int | None
    equip1: str | None
    equip2: str | None
    equip3: str | None
    equip4: str | None
    equip1_level: int | None
    equip2_level: int | None
    equip3_level: int | None
    combat_hp: int | None
    combat_atk: int | None
    combat_def: int | None
    combat_heal: int | None
    stat_hp: int | None
    stat_atk: int | None
    stat_heal: int | None
    school: str | None
    rarity: str | None
    attack_type: str | None
    defense_type: str | None
    combat_class: str | None
    role: str | None
    position: str | None
    weapon_type: str | None
    cover_type: str | None
    range_type: str | None

    @property
    def title(self) -> str:
        return self.display_name or self.student_id


def load_students() -> list[StudentRecord]:
    records_by_id: dict[str, StudentRecord] = {}
    paths = get_storage_paths()
    db_path = paths.db_path
    current_json = paths.current_students_json

    if db_path.exists():
        try:
            conn = sqlite3.connect(db_path)
            conn.row_factory = sqlite3.Row
            rows = conn.execute("SELECT * FROM students ORDER BY student_id").fetchall()
            conn.close()
            for row in rows:
                record = _row_to_record(dict(row), owned=True)
                records_by_id[record.student_id] = record
        except Exception:
            pass

    if not records_by_id and current_json.exists():
        try:
            payload = json.loads(current_json.read_text(encoding="utf-8"))
            for value in payload.values():
                record = _row_to_record(value, owned=True)
                records_by_id[record.student_id] = record
        except Exception:
            pass

    for student_id in student_meta.all_ids():
        if student_id not in records_by_id:
            records_by_id[student_id] = _row_to_record({"student_id": student_id}, owned=False)

    return list(records_by_id.values())


def load_inventory_snapshot() -> dict[str, dict]:
    paths = get_storage_paths()
    inventory_json = paths.current_inventory_json
    payload: dict[str, dict] = {}
    loaded_from_db = False

    db_path = paths.db_path
    if db_path.exists():
        try:
            init_db(db_path)
            conn = sqlite3.connect(db_path)
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                """
                SELECT item_key, item_id, name, quantity, item_index, item_source, last_seen_at, last_scan_id
                FROM inventory_current
                ORDER BY COALESCE(item_index, 999999), item_key
                """
            ).fetchall()
            conn.close()
            if rows:
                payload = {
                    str(row["item_key"]): {
                        "item_id": row["item_id"],
                        "name": row["name"],
                        "quantity": row["quantity"],
                        "index": row["item_index"],
                        "item_source": row["item_source"],
                        "last_seen_at": row["last_seen_at"],
                        "last_scan_id": row["last_scan_id"],
                    }
                    for row in rows
                }
                loaded_from_db = True
        except Exception:
            payload = {}

    if not payload:
        if not inventory_json.exists():
            return {}
        try:
            raw_payload = json.loads(inventory_json.read_text(encoding="utf-8"))
        except Exception:
            return {}
        if not isinstance(raw_payload, dict):
            return {}
        payload = raw_payload

    def _looks_like_inventory_id(value: object) -> bool:
        return isinstance(value, str) and ("_Icon_" in value or value.startswith("Item_"))

    def _entry_rank(entry: dict) -> tuple[int, int, int, int]:
        quantity = str(entry.get("quantity") or "").strip()
        return (
            int(quantity not in ("", "0")),
            int(bool(entry.get("item_id"))),
            int(bool(entry.get("last_seen_at"))),
            len(quantity),
        )

    normalized: dict[str, dict] = {}
    changed = False
    for key, raw_value in payload.items():
        if not isinstance(raw_value, dict):
            continue
        entry = dict(raw_value)
        key_text = str(key)
        item_id = entry.get("item_id") or (key_text if _looks_like_inventory_id(key_text) else None)
        if item_id and entry.get("item_id") != item_id:
            entry["item_id"] = item_id
            changed = True
        display_name = inventory_item_display_name(str(item_id)) if item_id else None
        if display_name and entry.get("name") != display_name:
            entry["name"] = display_name
            changed = True
        canonical_key = str(item_id or entry.get("name") or key_text)
        if canonical_key != key_text:
            changed = True
        current = normalized.get(canonical_key)
        if current is None or _entry_rank(entry) > _entry_rank(current):
            primary, secondary = entry, current
        else:
            primary, secondary = current, entry
        if secondary:
            primary = dict(primary)
            for merge_key in ("item_id", "name", "quantity", "index", "item_source", "last_seen_at", "last_scan_id"):
                if primary.get(merge_key) in (None, "") and secondary.get(merge_key) not in (None, ""):
                    primary[merge_key] = secondary.get(merge_key)
                    changed = True
        normalized[canonical_key] = primary

    if changed:
        try:
            inventory_json.write_text(json.dumps(normalized, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception:
            pass

    if not loaded_from_db and normalized:
        try:
            init_db(db_path)
            conn = sqlite3.connect(db_path)
            with conn:
                conn.execute("DELETE FROM inventory_current")
                conn.executemany(
                    """
                    INSERT INTO inventory_current (
                        item_key, item_id, name, quantity,
                        item_index, item_source, last_seen_at, last_scan_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        (
                            item_key,
                            entry.get("item_id"),
                            entry.get("name"),
                            entry.get("quantity"),
                            entry.get("index"),
                            entry.get("item_source"),
                            entry.get("last_seen_at"),
                            entry.get("last_scan_id"),
                        )
                        for item_key, entry in normalized.items()
                    ],
                )
            conn.close()
        except Exception:
            pass

    return normalized


def _row_to_record(row: dict, owned: bool) -> StudentRecord:
    student_id = row.get("student_id") or ""
    canonical_name = student_meta.field(student_id, "display_name")
    return StudentRecord(
        student_id=student_id,
        display_name=canonical_name or row.get("display_name") or student_id or "",
        owned=owned,
        farmable=row.get("farmable") or student_meta.field(student_id, "farmable"),
        level=row.get("level"),
        star=int(row.get("student_star") or 0),
        weapon_state=row.get("weapon_state"),
        weapon_star=row.get("weapon_star"),
        weapon_level=row.get("weapon_level"),
        ex_skill=row.get("ex_skill"),
        skill1=row.get("skill1"),
        skill2=row.get("skill2"),
        skill3=row.get("skill3"),
        equip1=row.get("equip1"),
        equip2=row.get("equip2"),
        equip3=row.get("equip3"),
        equip4=row.get("equip4"),
        equip1_level=row.get("equip1_level"),
        equip2_level=row.get("equip2_level"),
        equip3_level=row.get("equip3_level"),
        combat_hp=row.get("combat_hp"),
        combat_atk=row.get("combat_atk"),
        combat_def=row.get("combat_def"),
        combat_heal=row.get("combat_heal"),
        stat_hp=row.get("stat_hp"),
        stat_atk=row.get("stat_atk"),
        stat_heal=row.get("stat_heal"),
        school=row.get("school") or student_meta.field(student_id, "school"),
        rarity=row.get("rarity") or student_meta.field(student_id, "rarity"),
        attack_type=row.get("attack_type") or student_meta.field(student_id, "attack_type"),
        defense_type=row.get("defense_type") or student_meta.field(student_id, "defense_type"),
        combat_class=row.get("combat_class") or student_meta.field(student_id, "combat_class"),
        role=row.get("role") or student_meta.field(student_id, "role"),
        position=row.get("position") or student_meta.field(student_id, "position"),
        weapon_type=row.get("weapon_type") or student_meta.field(student_id, "weapon_type"),
        cover_type=row.get("cover_type") or student_meta.field(student_id, "cover_type"),
        range_type=row.get("range_type") or student_meta.field(student_id, "range_type"),
    )


def portrait_path(student_id: str) -> Path | None:
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        path = PORTRAIT_DIR / f"{student_id}{ext}"
        if path.exists():
            return path
    return None


def thumb_cache_path(student_id: str, width: int, height: int) -> Path:
    return BASE_DIR / "cache" / "student_thumbs" / THUMB_STYLE_VERSION / f"{width}x{height}" / f"{student_id}.png"


def _render_card_portrait(student_id: str, source: Path, width: int, height: int) -> Image.Image:
    with Image.open(source) as img:
        portrait = img.convert("RGBA")

    if portrait.width <= 0 or portrait.height <= 0:
        return Image.new("RGBA", (width, height), (0, 0, 0, 0))

    alpha = portrait.getchannel("A")
    bbox = alpha.getbbox()
    if bbox:
        portrait = portrait.crop(bbox)

    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    scale = min((width * 0.98) / portrait.width, (height * 0.98) / portrait.height)
    scaled = portrait.resize(
        (
            max(1, int(round(portrait.width * scale))),
            max(1, int(round(portrait.height * scale))),
        ),
        Image.LANCZOS,
    )
    offset = (
        (width - scaled.width) // 2,
        (height - scaled.height) // 2,
    )
    canvas.paste(scaled, offset, scaled)
    return canvas


def ensure_thumbnail(student_id: str, width: int = 128, height: int | None = None) -> Path | None:
    if not HAS_PIL:
        return portrait_path(student_id)
    if height is None:
        height = width

    source = portrait_path(student_id)
    if source is None:
        return None

    target = thumb_cache_path(student_id, width, height)
    if target.exists():
        return target

    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        canvas = _render_card_portrait(student_id, source, width, height)
        canvas.save(target, format="PNG")
        return target
    except Exception:
        return source


def make_placeholder_icon(width: int = 128, height: int | None = None) -> QIcon:
    if height is None:
        height = width
    pixmap = QPixmap(width, height)
    pixmap.fill(Qt.transparent)
    return QIcon(pixmap)


def make_unowned_icon(student_id: str, width: int = 128, height: int | None = None) -> QIcon:
    if height is None:
        height = width
    source = ensure_thumbnail(student_id, width, height)
    if source and source.exists():
        pixmap = QPixmap(str(source))
        if not pixmap.isNull():
            return QIcon(_make_dimmed_pixmap(pixmap.scaled(width, height, Qt.IgnoreAspectRatio, Qt.SmoothTransformation), width, height))
    return QIcon(_make_dimmed_pixmap(QPixmap(width, height), width, height, fill="#1a2430"))


def _make_dimmed_pixmap(pixmap: QPixmap, width: int, height: int, fill: str | None = None) -> QPixmap:
    canvas = QPixmap(width, height)
    canvas.fill(QColor(fill or Qt.transparent))
    painter = QPainter(canvas)
    x = max(0, (width - pixmap.width()) // 2)
    y = max(0, (height - pixmap.height()) // 2)
    painter.setOpacity(0.35)
    painter.drawPixmap(x, y, pixmap)
    painter.setOpacity(1.0)
    painter.fillRect(canvas.rect(), QColor(0, 0, 0, 96))
    painter.setPen(QColor("#d8e7f3"))
    painter.drawText(canvas.rect(), Qt.AlignCenter, "UNOWNED")
    painter.end()
    return canvas


class ThumbSignals(QObject):
    loaded = Signal(str, str, int, int)


class ThumbTask(QRunnable):
    def __init__(self, student_id: str, width: int, height: int):
        super().__init__()
        self.student_id = student_id
        self.width = width
        self.height = height
        self.signals = ThumbSignals()

    def run(self) -> None:
        path = ensure_thumbnail(self.student_id, self.width, self.height)
        self.signals.loaded.emit(self.student_id, str(path) if path else "", self.width, self.height)


class TacticalScreenshotSignals(QObject):
    loaded = Signal(str, object)
    failed = Signal(str, str)


class TacticalScreenshotTask(QRunnable):
    def __init__(self, path: str, candidate_priority: dict | None = None, answer_cache_path: str | None = None):
        super().__init__()
        self.path = path
        self.candidate_priority = candidate_priority or {}
        self.answer_cache_path = answer_cache_path
        self.signals = TacticalScreenshotSignals()

    def run(self) -> None:
        try:
            readout = parse_tactical_result_screenshot(
                self.path,
                candidate_priority=self.candidate_priority,
                answer_cache_path=self.answer_cache_path,
            )
        except Exception as exc:
            self.signals.failed.emit(self.path, str(exc))
            return
        self.signals.loaded.emit(self.path, readout)


class TacticalScreenshotBatchSignals(QObject):
    completed = Signal(object, object)


class TacticalScreenshotBatchTask(QRunnable):
    def __init__(self, paths: list[str], candidate_priority: dict | None = None, answer_cache_path: str | None = None):
        super().__init__()
        self.paths = list(paths)
        self.candidate_priority = candidate_priority or {}
        self.answer_cache_path = answer_cache_path
        self.signals = TacticalScreenshotBatchSignals()

    def run(self) -> None:
        results: list[tuple[str, object]] = []
        errors: list[tuple[str, str]] = []
        for path in self.paths:
            try:
                results.append(
                    (
                        path,
                        parse_tactical_result_screenshot(
                            path,
                            candidate_priority=self.candidate_priority,
                            answer_cache_path=self.answer_cache_path,
                        ),
                    )
                )
            except Exception as exc:
                errors.append((path, str(exc)))
        self.signals.completed.emit(results, errors)


HIDDEN_STUDENT_FILTER_FIELDS: frozenset[str] = frozenset({"skill_special"})


class TacticalOpponentBatchDialog(QDialog):
    def __init__(self, parent: QWidget, matches: list[TacticalMatch], ui_scale: float):
        super().__init__(parent)
        self._matches = list(matches)
        self._ui_scale = ui_scale
        self.setWindowTitle("상대 이름 일괄 입력")
        self.resize(scale_px(920, ui_scale), scale_px(620, ui_scale))

        layout = QVBoxLayout(self)
        layout.setContentsMargins(
            scale_px(14, ui_scale),
            scale_px(14, ui_scale),
            scale_px(14, ui_scale),
            scale_px(14, ui_scale),
        )
        layout.setSpacing(scale_px(10, ui_scale))

        guide = QLabel("상대 이름 칸을 직접 수정하거나, 여러 줄 이름을 클립보드에서 선택 행부터 붙여넣을 수 있습니다.")
        guide.setObjectName("detailSub")
        guide.setWordWrap(True)
        layout.addWidget(guide)

        self.table = QTableWidget(len(self._matches), 4)
        self.table.setHorizontalHeaderLabels(["날짜", "결과", "덱", "상대 이름"])
        self.table.verticalHeader().setVisible(False)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.table.setAlternatingRowColors(True)
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents)
        self.table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeToContents)
        self.table.horizontalHeader().setSectionResizeMode(2, QHeaderView.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeToContents)
        self.table.setColumnWidth(3, scale_px(170, ui_scale))
        layout.addWidget(self.table, 1)

        for row, match in enumerate(self._matches):
            self._set_readonly_item(row, 0, match.date or "-")
            self._set_readonly_item(row, 1, "승" if match.result == "win" else "패" if match.result == "loss" else "-")
            self._set_readonly_item(row, 2, self._deck_summary(match))
            item = QTableWidgetItem(match.opponent or "")
            item.setData(Qt.UserRole, match.id)
            self.table.setItem(row, 3, item)

        actions = QHBoxLayout()
        actions.setContentsMargins(0, 0, 0, 0)
        paste_button = QPushButton("클립보드 붙여넣기")
        paste_button.clicked.connect(self._paste_names)
        clear_selected_button = QPushButton("선택 비우기")
        clear_selected_button.clicked.connect(self._clear_selected_names)
        fill_down_button = QPushButton("위 이름 채우기")
        fill_down_button.clicked.connect(self._fill_down_names)
        actions.addWidget(paste_button)
        actions.addWidget(fill_down_button)
        actions.addWidget(clear_selected_button)
        actions.addStretch(1)
        layout.addLayout(actions)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel)
        buttons.button(QDialogButtonBox.StandardButton.Save).setText("저장")
        buttons.button(QDialogButtonBox.StandardButton.Cancel).setText("취소")
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _set_readonly_item(self, row: int, column: int, text: str) -> None:
        item = QTableWidgetItem(str(text or ""))
        item.setFlags(item.flags() & ~Qt.ItemIsEditable)
        self.table.setItem(row, column, item)

    def _deck_summary(self, match: TacticalMatch) -> str:
        attack_deck = match.my_attack if (match.my_attack.strikers or match.my_attack.supports) else match.opponent_attack
        defense_deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
        return f"ATK {deck_input_template(attack_deck) or '-'} / DEF {deck_input_template(defense_deck) or '-'}"

    def _target_start_row(self) -> int:
        selected = sorted({index.row() for index in self.table.selectedIndexes()})
        if selected:
            return selected[0]
        current = self.table.currentRow()
        if current >= 0:
            return current
        for row in range(self.table.rowCount()):
            item = self.table.item(row, 3)
            if item is not None and not item.text().strip():
                return row
        return 0

    def _paste_names(self) -> None:
        lines = [line.strip() for line in QApplication.clipboard().text().splitlines()]
        names = [line for line in lines if line]
        if not names:
            return
        row = self._target_start_row()
        for name in names:
            if row >= self.table.rowCount():
                break
            item = self.table.item(row, 3)
            if item is not None:
                item.setText(name)
            row += 1

    def _clear_selected_names(self) -> None:
        rows = sorted({index.row() for index in self.table.selectedIndexes()})
        for row in rows:
            item = self.table.item(row, 3)
            if item is not None:
                item.setText("")

    def _fill_down_names(self) -> None:
        previous = ""
        for row in range(self.table.rowCount()):
            item = self.table.item(row, 3)
            if item is None:
                continue
            current = item.text().strip()
            if current:
                previous = current
            elif previous:
                item.setText(previous)

    def edited_matches(self) -> list[TacticalMatch]:
        updated: list[TacticalMatch] = []
        for row, match in enumerate(self._matches):
            item = self.table.item(row, 3)
            opponent = item.text().strip() if item is not None else ""
            if opponent == match.opponent:
                continue
            match.opponent = opponent
            updated.append(match)
        return updated

class FilterDialog(QDialog):
    def __init__(
        self,
        parent: QWidget,
        filter_options: dict[str, list],
        selected_filters: dict[str, set[str]],
        ui_scale: float,
    ) -> None:
        super().__init__(parent)
        self.setWindowTitle("학생 필터")
        self.resize(scale_px(740, ui_scale), scale_px(760, ui_scale))
        self._checkboxes: dict[str, list[tuple[str, QCheckBox]]] = {}

        layout = QVBoxLayout(self)
        layout.setContentsMargins(
            scale_px(16, ui_scale),
            scale_px(16, ui_scale),
            scale_px(16, ui_scale),
            scale_px(16, ui_scale),
        )
        layout.setSpacing(scale_px(12, ui_scale))

        intro = QLabel("각 항목에서 하나 이상의 값을 선택하세요. 선택한 항목은 모두 만족하는 학생만 표시됩니다.")
        intro.setWordWrap(True)
        layout.addWidget(intro)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        body = QWidget()
        body_layout = QVBoxLayout(body)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(scale_px(10, ui_scale))

        for key in FILTER_FIELD_ORDER:
            if key in HIDDEN_STUDENT_FILTER_FIELDS:
                continue
            options = filter_options.get(key) or []
            if not options:
                continue
            group = QGroupBox(FILTER_FIELD_LABELS[key])
            group_layout = QGridLayout(group)
            group_layout.setContentsMargins(
                scale_px(12, ui_scale),
                scale_px(12, ui_scale),
                scale_px(12, ui_scale),
                scale_px(12, ui_scale),
            )
            group_layout.setHorizontalSpacing(scale_px(12, ui_scale))
            group_layout.setVerticalSpacing(scale_px(8, ui_scale))
            pairs: list[tuple[str, QCheckBox]] = []
            for index, option in enumerate(options):
                checkbox = QCheckBox(option.label)
                checkbox.setChecked(option.value in selected_filters.get(key, set()))
                group_layout.addWidget(checkbox, index // 3, index % 3)
                pairs.append((option.value, checkbox))
            self._checkboxes[key] = pairs
            body_layout.addWidget(group)

        body_layout.addStretch(1)
        scroll.setWidget(body)
        layout.addWidget(scroll, 1)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Apply
            | QDialogButtonBox.StandardButton.Reset
            | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.button(QDialogButtonBox.StandardButton.Apply).clicked.connect(self.accept)
        buttons.button(QDialogButtonBox.StandardButton.Cancel).clicked.connect(self.reject)
        buttons.button(QDialogButtonBox.StandardButton.Reset).clicked.connect(self._reset)
        buttons.button(QDialogButtonBox.StandardButton.Apply).setText("적용")
        buttons.button(QDialogButtonBox.StandardButton.Reset).setText("초기화")
        buttons.button(QDialogButtonBox.StandardButton.Cancel).setText("취소")
        layout.addWidget(buttons)

    def selected_filters(self) -> dict[str, set[str]]:
        return {
            key: {value for value, checkbox in pairs if checkbox.isChecked()}
            for key, pairs in self._checkboxes.items()
        }

    def _reset(self) -> None:
        for pairs in self._checkboxes.values():
            for _value, checkbox in pairs:
                checkbox.setChecked(False)


class InventoryCoverageBar(QWidget):
    def __init__(
        self,
        *,
        ui_scale: float,
        base_color: str,
        adjusted_color: str = "#ff5fb5",
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self._base_color = QColor(base_color)
        self._adjusted_color = QColor(adjusted_color)
        self._raw_ratio = 0.0
        self._effective_ratio = 0.0
        self._empty = True
        self.setAutoFillBackground(False)
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setFixedHeight(scale_px(7, self._ui_scale))
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

    def setCoverage(self, *, raw_owned: int | float, effective_owned: int | float, required: int | float) -> None:
        if required <= 0:
            self._raw_ratio = 0.0
            self._effective_ratio = 0.0
            self._empty = True
        else:
            self._raw_ratio = max(0.0, float(raw_owned) / float(required))
            self._effective_ratio = max(self._raw_ratio, float(effective_owned) / float(required))
            self._empty = False
        self.update()

    def paintEvent(self, event) -> None:
        super().paintEvent(event)
        rect = QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5)
        if rect.isEmpty():
            return
        radius = max(1, scale_px(3, self._ui_scale))
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)

        path = QPainterPath()
        path.addRoundedRect(rect, radius, radius)
        if self._empty:
            painter.setPen(QPen(QColor(255, 255, 255, 200), 1))
            painter.setBrush(Qt.NoBrush)
            painter.drawPath(path)
            return

        painter.setPen(QPen(QColor(255, 255, 255, 200), 1))
        painter.setBrush(Qt.NoBrush)
        painter.drawPath(path)

        painter.save()
        painter.setClipPath(path)
        width = rect.width()
        raw_width = width * min(1.0, self._raw_ratio)
        effective_width = width * min(1.0, self._effective_ratio)
        if raw_width > 0:
            painter.fillRect(QRectF(rect.left(), rect.top(), raw_width, rect.height()), self._base_color)
        if effective_width > raw_width:
            painter.fillRect(
                QRectF(rect.left() + raw_width, rect.top(), effective_width - raw_width, rect.height()),
                self._adjusted_color,
            )
        painter.restore()


class InventoryListItem(QFrame):
    def __init__(self, *, ui_scale: float, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self.setObjectName("planBand")
        self.setFixedHeight(scale_px(64, self._ui_scale))
        icon_width = scale_px(40, self._ui_scale)
        coverage_width = scale_px(420, self._ui_scale)
        value_width = scale_px(88, self._ui_scale)
        status_width = scale_px(112, self._ui_scale)

        layout = QGridLayout(self)
        layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        layout.setHorizontalSpacing(scale_px(10, self._ui_scale))
        layout.setVerticalSpacing(scale_px(1, self._ui_scale))

        self._icon = QLabel()
        self._icon.setFixedSize(icon_width, icon_width)
        self._icon.setAlignment(Qt.AlignCenter)
        layout.addWidget(self._icon, 0, 0, 2, 1, Qt.AlignVCenter)

        self._text_host = QWidget()
        self._text_host.setObjectName("planTransparent")
        self._text_host.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Preferred)
        text_wrap = QVBoxLayout()
        text_wrap.setContentsMargins(0, 0, 0, 0)
        text_wrap.setSpacing(scale_px(2, self._ui_scale))
        text_wrap.setAlignment(Qt.AlignVCenter)
        self._text_host.setLayout(text_wrap)

        self._name = QLabel("-")
        self._name.setObjectName("sectionTitle")
        self._name.setWordWrap(False)
        self._name.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Preferred)
        text_wrap.addWidget(self._name)

        self._meta = QLabel("")
        self._meta.setObjectName("detailMiniSub")
        self._meta.setWordWrap(False)
        self._meta.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Preferred)
        self._meta.setVisible(False)
        text_wrap.addWidget(self._meta)
        layout.addWidget(self._text_host, 0, 1, 2, 1)

        self._coverage_host = QWidget()
        self._coverage_host.setObjectName("planTransparent")
        self._coverage_host.setFixedWidth(coverage_width)
        coverage_layout = QHBoxLayout(self._coverage_host)
        coverage_layout.setContentsMargins(0, 0, 0, 0)
        coverage_layout.setSpacing(scale_px(10, self._ui_scale))
        self._plan_coverage_bar = self._build_coverage_bar("inventoryPlanCoverageBar")
        self._pool_coverage_bar = self._build_coverage_bar("inventoryPoolCoverageBar")
        self._plan_coverage_label = self._build_coverage_label()
        self._pool_coverage_label = self._build_coverage_label()
        coverage_layout.addWidget(
            self._build_coverage_group(self._plan_coverage_bar, self._plan_coverage_label),
            1,
        )
        coverage_layout.addWidget(
            self._build_coverage_group(self._pool_coverage_bar, self._pool_coverage_label),
            1,
        )
        layout.addWidget(self._coverage_host, 0, 2, 2, 1, Qt.AlignCenter)

        self._owned = self._build_value_label(value_width)
        self._plan_need = self._build_value_label(value_width)
        self._plan_short = self._build_value_label(value_width)
        self._pool_remain = self._build_value_label(value_width)
        self._status = QLabel("-")
        self._status.setObjectName("inventoryStatus")
        self._status.setAlignment(Qt.AlignCenter)
        self._status.setFixedWidth(status_width)

        for column, widget in enumerate(
            (self._owned, self._plan_need, self._plan_short, self._pool_remain, self._status),
            start=3,
        ):
            layout.addWidget(widget, 0, column, 2, 1, Qt.AlignCenter)

        layout.setColumnMinimumWidth(0, icon_width)
        layout.setColumnStretch(1, 1)
        layout.setColumnMinimumWidth(2, coverage_width)
        for column in range(3, 7):
            layout.setColumnMinimumWidth(column, value_width)
        layout.setColumnMinimumWidth(7, status_width)

    def _build_coverage_bar(self, object_name: str) -> InventoryCoverageBar:
        base_color = "#ff304f" if object_name == "inventoryPlanCoverageBar" else "#ffb5f0"
        bar = InventoryCoverageBar(ui_scale=self._ui_scale, base_color=base_color)
        bar.setObjectName(object_name)
        return bar

    def _build_coverage_group(self, bar: InventoryCoverageBar, label: QLabel) -> QWidget:
        group = QWidget()
        group.setObjectName("planTransparent")
        layout = QVBoxLayout(group)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(2, self._ui_scale))
        layout.addWidget(bar)
        layout.addWidget(label)
        return group

    def _build_coverage_label(self) -> QLabel:
        label = QLabel("-")
        label.setObjectName("inventoryCoveragePercent")
        label.setAlignment(Qt.AlignCenter)
        label.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        return label

    def _build_value_label(self, width: int) -> QLabel:
        label = QLabel("-")
        label.setObjectName("inventoryValue")
        label.setAlignment(Qt.AlignCenter)
        label.setFixedWidth(width)
        return label

    def _set_coverage_meter(
        self,
        *,
        bar: InventoryCoverageBar,
        label: QLabel,
        raw_owned: int | float,
        effective_owned: int | float,
        required: int | float,
        tooltip_prefix: str,
        cap_at_100: bool = False,
    ) -> None:
        if required <= 0:
            bar.setCoverage(raw_owned=0, effective_owned=0, required=0)
            label.setText("-")
            tooltip = f"{tooltip_prefix}: requirement unavailable"
        else:
            percentage = (max(0, effective_owned) / required) * 100
            display_percentage = min(100.0, percentage) if cap_at_100 else percentage
            bar.setCoverage(raw_owned=raw_owned, effective_owned=effective_owned, required=required)
            label.setText(f"{display_percentage:.2f}%")
            tooltip = f"{tooltip_prefix}: {_format_count(effective_owned)} / {_format_count(required)} ({display_percentage:.2f}%)"
        label.setProperty("adjusted", False)
        label.style().unpolish(label)
        label.style().polish(label)
        bar.setToolTip(tooltip)
        label.setToolTip(tooltip)

    def setData(
        self,
        *,
        icon_path: Path | None,
        item_id: str | None = None,
        name: str,
        quantity: str,
        meta: str = "",
        shortage: bool = False,
        plan_need: str = "-",
        plan_short: str = "-",
        pool_remain: str = "-",
        status: str = "",
        show_text: bool = True,
        owned_value: int | float = 0,
        plan_required_value: int | float = 0,
        pool_required_value: int | float = 0,
        plan_coverage_owned_value: int | float | None = None,
        pool_coverage_owned_value: int | float | None = None,
        owned_tooltip: str = "",
        plan_need_tooltip: str = "",
        plan_short_tooltip: str = "",
        pool_remain_tooltip: str = "",
    ) -> None:
        self._text_host.setVisible(show_text)
        self._name.setText(name if show_text else "")
        self._owned.setText(quantity)
        self._plan_need.setText(plan_need)
        self._plan_short.setText(plan_short)
        self._pool_remain.setText(pool_remain)
        self._set_coverage_meter(
            bar=self._plan_coverage_bar,
            label=self._plan_coverage_label,
            raw_owned=owned_value,
            effective_owned=owned_value if plan_coverage_owned_value is None else plan_coverage_owned_value,
            required=plan_required_value,
            tooltip_prefix="Plan coverage",
            cap_at_100=True,
        )
        self._set_coverage_meter(
            bar=self._pool_coverage_bar,
            label=self._pool_coverage_label,
            raw_owned=owned_value,
            effective_owned=owned_value if pool_coverage_owned_value is None else pool_coverage_owned_value,
            required=pool_required_value,
            tooltip_prefix="Full growth coverage",
        )
        status_text = status or ("계획 부족" if shortage else "충분")
        self._status.setText(_inventory_status_label(status_text))
        self._meta.setText("")
        self._owned.setToolTip(owned_tooltip or quantity)
        self._plan_need.setToolTip(plan_need_tooltip or plan_need)
        self._plan_short.setToolTip(plan_short_tooltip or plan_short)
        self._pool_remain.setToolTip(pool_remain_tooltip or pool_remain)
        self._status.setToolTip(_inventory_status_label(status_text))
        warning_style = "color: #ff6b6b;" if shortage else ""
        self._name.setStyleSheet(warning_style)
        self._owned.setStyleSheet(warning_style)
        self._plan_short.setStyleSheet(warning_style)
        self._meta.setStyleSheet(warning_style if shortage else "")
        self._status.setProperty("status", _inventory_status_key(status_text))
        self._status.style().unpolish(self._status)
        self._status.style().polish(self._status)

        if icon_path is not None and icon_path.exists():
            pixmap = _item_icon_pixmap(size=self._icon.size(), item_id=item_id, icon_path=icon_path)
            if not pixmap.isNull():
                self._icon.setPixmap(pixmap)
                return
        self._icon.setPixmap(QPixmap())


class InventoryColumnHeader(QWidget):
    def __init__(self, *, ui_scale: float, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self.setObjectName("planTransparent")
        icon_width = scale_px(40, self._ui_scale)
        coverage_width = scale_px(420, self._ui_scale)
        value_width = scale_px(88, self._ui_scale)
        status_width = scale_px(112, self._ui_scale)

        layout = QGridLayout(self)
        layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            0,
            scale_px(12, self._ui_scale),
            0,
        )
        layout.setHorizontalSpacing(scale_px(10, self._ui_scale))
        layout.setVerticalSpacing(0)

        spacer = QLabel("")
        spacer.setFixedWidth(icon_width)
        layout.addWidget(spacer, 0, 0)

        name_header = QLabel("")
        name_header.setObjectName("inventoryColumnHeader")
        layout.addWidget(name_header, 0, 1)

        coverage_header = QWidget()
        coverage_header.setObjectName("planTransparent")
        coverage_header.setFixedWidth(coverage_width)
        coverage_header_layout = QHBoxLayout(coverage_header)
        coverage_header_layout.setContentsMargins(0, 0, 0, 0)
        coverage_header_layout.setSpacing(scale_px(10, self._ui_scale))
        for text in ("계획 달성량", "전체 달성량"):
            label = QLabel(text)
            label.setObjectName("inventoryColumnHeader")
            label.setAlignment(Qt.AlignCenter)
            coverage_header_layout.addWidget(label, 1)
        layout.addWidget(coverage_header, 0, 2)

        labels = (
            (_tr("inventory.header.owned"), Qt.AlignCenter),
            (_tr("inventory.header.plan_need"), Qt.AlignCenter),
            (_tr("inventory.header.plan_short"), Qt.AlignCenter),
            (_tr("inventory.header.pool_remain"), Qt.AlignCenter),
            (_tr("inventory.header.status"), Qt.AlignCenter),
        )
        for column, (text, alignment) in enumerate(labels, start=3):
            label = QLabel(text)
            label.setObjectName("inventoryColumnHeader")
            label.setAlignment(alignment | Qt.AlignVCenter)
            if column in (3, 4, 5, 6):
                label.setFixedWidth(value_width)
            elif column == 7:
                label.setFixedWidth(status_width)
            layout.addWidget(label, 0, column)

        layout.setColumnMinimumWidth(0, icon_width)
        layout.setColumnStretch(1, 1)
        layout.setColumnMinimumWidth(2, coverage_width)
        for column in range(3, 7):
            layout.setColumnMinimumWidth(column, value_width)
        layout.setColumnMinimumWidth(7, status_width)


class RoundedListWidget(QListWidget):
    def __init__(self, *, ui_scale: float = 1.0, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self.setObjectName("roundedList")
        self.setFrameShape(QFrame.NoFrame)
        self.setLineWidth(0)
        self.setMidLineWidth(0)
        self.setViewportMargins(1, 1, 1, 1)
        self.setAttribute(Qt.WA_StyledBackground, True)
        self.viewport().setAutoFillBackground(False)
        self.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        QTimer.singleShot(0, self._sync_after_layout)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._schedule_sync_after_layout()

    def showEvent(self, event) -> None:
        super().showEvent(event)
        self._schedule_sync_after_layout()

    def setItemWidget(self, item: QListWidgetItem, widget: QWidget) -> None:
        super().setItemWidget(item, widget)
        self._schedule_sync_after_layout()

    def _schedule_sync_after_layout(self) -> None:
        self._sync_after_layout()
        QTimer.singleShot(0, self._sync_after_layout)

    def _sync_after_layout(self) -> None:
        self._update_viewport_mask()
        self._sync_item_widget_widths()

    def _update_viewport_mask(self) -> None:
        rect = self.viewport().rect()
        if rect.isEmpty():
            return
        radius = max(0, scale_px(13, self._ui_scale))
        path = QPainterPath()
        path.addRoundedRect(QRectF(0, 0, rect.width(), rect.height()), radius, radius)
        self.viewport().setMask(QRegion(path.toFillPolygon().toPolygon()))

    def _sync_item_widget_widths(self) -> None:
        viewport_width = self.viewport().width()
        if viewport_width <= 0:
            return
        for row in range(self.count()):
            item = self.item(row)
            if item is None:
                continue
            hint = item.sizeHint()
            height = hint.height() if hint.height() > 0 else self.sizeHintForRow(row)
            if height <= 0:
                height = scale_px(64, self._ui_scale)
            next_hint = QSize(viewport_width, height)
            if hint != next_hint:
                item.setSizeHint(next_hint)
            widget = self.itemWidget(item)
            if widget is not None and widget.width() != viewport_width:
                widget.setFixedWidth(viewport_width)


class InventoryPriorityListWidget(RoundedListWidget):
    def wheelEvent(self, event) -> None:
        event.accept()

    def keyPressEvent(self, event) -> None:
        if event.key() in {
            Qt.Key_Up,
            Qt.Key_Down,
            Qt.Key_PageUp,
            Qt.Key_PageDown,
            Qt.Key_Home,
            Qt.Key_End,
        }:
            event.accept()
            return
        super().keyPressEvent(event)


class PlannerScrollHandle(QWidget):
    def __init__(self, owner: QAbstractScrollArea, *, ui_scale: float, radius_margin: int = 14) -> None:
        super().__init__(owner)
        self._owner = owner
        self._ui_scale = ui_scale
        self._radius_margin = radius_margin
        self._dragging = False
        self._drag_offset_y = 0
        self._suppressed = False
        self.setCursor(Qt.PointingHandCursor)
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        owner.verticalScrollBar().valueChanged.connect(lambda *_: self.update_position())
        owner.verticalScrollBar().rangeChanged.connect(lambda *_: self.update_position())
        self._sync_timer = QTimer(self)
        self._sync_timer.setInterval(250)
        self._sync_timer.timeout.connect(self.update_position)
        self._sync_timer.start()
        self.hide()

    def paintEvent(self, event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        rect = QRectF(0.5, 0.5, max(0.0, self.width() - 1.0), max(0.0, self.height() - 1.0))
        path = QPainterPath()
        radius = max(1, self.width() / 2)
        path.addRoundedRect(rect, radius, radius)
        painter.fillPath(path, QColor(ACCENT_SOFT))
        painter.setPen(QPen(QColor(ACCENT), 1))
        painter.drawPath(path)
        painter.end()

    def mousePressEvent(self, event) -> None:
        if event.button() != Qt.LeftButton:
            return super().mousePressEvent(event)
        self._dragging = True
        self._drag_offset_y = int(event.position().y())
        event.accept()

    def mouseMoveEvent(self, event) -> None:
        if not self._dragging:
            return super().mouseMoveEvent(event)
        self.set_scroll_from_handle_y(self.y() + int(event.position().y()) - self._drag_offset_y)
        event.accept()

    def mouseReleaseEvent(self, event) -> None:
        if event.button() == Qt.LeftButton and self._dragging:
            self._dragging = False
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def _track_rect(self) -> QRect:
        top_margin = scale_px(self._radius_margin, self._ui_scale)
        width = scale_px(6, self._ui_scale)
        right_margin = scale_px(6, self._ui_scale)
        top = top_margin
        bottom = max(top, self._owner.height() - top_margin)
        return QRect(max(0, self._owner.width() - right_margin - width), top, width, max(0, bottom - top))

    def update_position(self) -> None:
        if self._suppressed:
            self.hide()
            return
        bar = self._owner.verticalScrollBar()
        track = self._track_rect()
        if track.height() <= 0 or bar.maximum() <= bar.minimum() or not self._owner.isVisible():
            self.hide()
            return
        page = max(1, bar.pageStep())
        total = max(page, (bar.maximum() - bar.minimum()) + page)
        handle_height = max(scale_px(28, self._ui_scale), int(round(track.height() * page / total)))
        handle_height = min(track.height(), handle_height)
        travel = max(0, track.height() - handle_height)
        ratio = 0.0 if bar.maximum() <= bar.minimum() else (bar.value() - bar.minimum()) / (bar.maximum() - bar.minimum())
        y = track.y() + int(round(travel * ratio))
        self.setGeometry(track.x(), y, track.width(), handle_height)
        self.raise_()
        self.show()

    def set_scroll_from_handle_y(self, y: int) -> None:
        bar = self._owner.verticalScrollBar()
        track = self._track_rect()
        handle_height = self.height()
        travel = max(1, track.height() - handle_height)
        clamped_y = max(track.y(), min(track.y() + travel, y))
        ratio = (clamped_y - track.y()) / travel
        bar.setValue(bar.minimum() + int(round((bar.maximum() - bar.minimum()) * ratio)))
        self.update_position()

    def setSuppressed(self, suppressed: bool) -> None:
        self._suppressed = suppressed
        if suppressed:
            self.hide()
        else:
            self.update_position()


class PlanQuickAddListWidget(RoundedListWidget):
    def __init__(self, *, ui_scale: float = 1.0, parent: QWidget | None = None) -> None:
        super().__init__(ui_scale=ui_scale, parent=parent)
        self.setObjectName("planQuickAddList")
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setViewportMargins(
            scale_px(1, self._ui_scale),
            scale_px(1, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(1, self._ui_scale),
        )
        self._scroll_handle = PlannerScrollHandle(self, ui_scale=self._ui_scale)
        QTimer.singleShot(0, self._scroll_handle.update_position)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._scroll_handle.update_position()

    def showEvent(self, event) -> None:
        super().showEvent(event)
        self._scroll_handle.update_position()

    def _sync_after_layout(self) -> None:
        super()._sync_after_layout()
        self._scroll_handle.update_position()


def _install_planner_scroll_handle(scroll_area: QAbstractScrollArea, *, ui_scale: float) -> PlannerScrollHandle:
    scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
    scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
    margins = scroll_area.viewportMargins()
    right_margin = scale_px(18, ui_scale)
    scroll_area.setViewportMargins(
        margins.left(),
        margins.top(),
        max(margins.right(), right_margin),
        margins.bottom(),
    )
    handle = getattr(scroll_area, "_planner_scroll_handle", None)
    if not isinstance(handle, PlannerScrollHandle):
        handle = PlannerScrollHandle(scroll_area, ui_scale=ui_scale)
        setattr(scroll_area, "_planner_scroll_handle", handle)
    QTimer.singleShot(0, handle.update_position)
    return handle


def _apply_rounded_mask(widget: QWidget, *, radius: int) -> None:
    rect = widget.rect()
    if rect.isEmpty():
        return
    path = QPainterPath()
    path.addRoundedRect(QRectF(0, 0, rect.width(), rect.height()), radius, radius)
    widget.setMask(QRegion(path.toFillPolygon().toPolygon()))


class RoundedMaskFrame(QFrame):
    def __init__(self, *, ui_scale: float, radius: int = 14, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self._radius = radius
        QTimer.singleShot(0, self._schedule_mask)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._schedule_mask()

    def showEvent(self, event) -> None:
        super().showEvent(event)
        self._schedule_mask()

    def _schedule_mask(self) -> None:
        self._update_mask()
        QTimer.singleShot(0, self._update_mask)

    def _update_mask(self) -> None:
        _apply_rounded_mask(self, radius=max(0, scale_px(self._radius, self._ui_scale)))


class AspectRatioFrame(QFrame):
    def __init__(
        self,
        *,
        aspect_width: int = 16,
        aspect_height: int = 9,
        min_width: int = 1,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._aspect_width = max(1, int(aspect_width))
        self._aspect_height = max(1, int(aspect_height))
        self._min_width = max(1, int(min_width))
        policy = QSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        policy.setHeightForWidth(True)
        self.setSizePolicy(policy)

    def hasHeightForWidth(self) -> bool:
        return True

    def heightForWidth(self, width: int) -> int:
        return max(1, int(round(max(1, width) * self._aspect_height / self._aspect_width)))

    def sizeHint(self) -> QSize:
        width = max(self._min_width, super().sizeHint().width())
        return QSize(width, self.heightForWidth(width))

    def minimumSizeHint(self) -> QSize:
        return QSize(self._min_width, self.heightForWidth(self._min_width))

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        target_height = self.heightForWidth(max(self._min_width, self.width()))
        if self.minimumHeight() != target_height or self.maximumHeight() != target_height:
            self.setMinimumHeight(target_height)
            self.setMaximumHeight(target_height)
            self.updateGeometry()

class RoundedMaskTabWidget(QTabWidget):
    def __init__(self, *, ui_scale: float, radius: int = 14, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self._radius = radius
        self.currentChanged.connect(lambda *_: self._schedule_mask())
        QTimer.singleShot(0, self._schedule_mask)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._schedule_mask()

    def showEvent(self, event) -> None:
        super().showEvent(event)
        self._schedule_mask()

    def _schedule_mask(self) -> None:
        self._update_mask()
        QTimer.singleShot(0, self._update_mask)

    def _update_mask(self) -> None:
        _apply_rounded_mask(self, radius=max(0, scale_px(self._radius, self._ui_scale)))


class InventorySubTabWidget(RoundedMaskFrame):
    currentChanged = Signal(int)

    def __init__(self, *, ui_scale: float, parent: QWidget | None = None) -> None:
        super().__init__(ui_scale=ui_scale, radius=14, parent=parent)
        self._ui_scale = ui_scale
        self.setFrameShape(QFrame.NoFrame)
        self.setAutoFillBackground(False)
        self.setAttribute(Qt.WA_StyledBackground, True)

        self._tab_bar = QTabBar(self)
        self._tab_bar.setDocumentMode(True)
        self._tab_bar.setDrawBase(False)
        self._tab_bar.setExpanding(False)
        self._tab_bar.setUsesScrollButtons(True)
        self._tab_bar.currentChanged.connect(self._on_tab_changed)

        self._stack = QStackedWidget(self)
        self._stack.setObjectName("inventorySubStack")
        self._stack.setAutoFillBackground(False)
        self._stack.setAttribute(Qt.WA_TranslucentBackground, True)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(self._tab_bar, 0)
        layout.addWidget(self._stack, 1)

    def tabBar(self) -> QTabBar:
        return self._tab_bar

    def addTab(self, page: QWidget, label: str) -> int:
        page.setAutoFillBackground(False)
        page.setAttribute(Qt.WA_TranslucentBackground, True)
        index = self._stack.addWidget(page)
        self._tab_bar.addTab(label)
        if index == 0:
            self.setCurrentIndex(0)
        return index

    def setCurrentIndex(self, index: int) -> None:
        if index < 0 or index >= self._stack.count():
            return
        if self._tab_bar.currentIndex() != index:
            self._tab_bar.setCurrentIndex(index)
        self._stack.setCurrentIndex(index)
        self._schedule_mask()
        self._clear_current_page_mask()

    def currentIndex(self) -> int:
        return self._stack.currentIndex()

    def currentWidget(self) -> QWidget | None:
        return self._stack.currentWidget()

    def _on_tab_changed(self, index: int) -> None:
        if index < 0 or index >= self._stack.count():
            return
        self._stack.setCurrentIndex(index)
        self._clear_current_page_mask()
        self.currentChanged.emit(index)

    def _clear_current_page_mask(self) -> None:
        page = self.currentWidget()
        if page is None:
            return
        page.setAutoFillBackground(False)
        page.setAttribute(Qt.WA_TranslucentBackground, True)
        page.clearMask()


class PlanEditorSectionCard(RoundedMaskFrame):
    def __init__(self, *, ui_scale: float, radius: int = 18, parent: QWidget | None = None) -> None:
        super().__init__(ui_scale=ui_scale, radius=radius, parent=parent)
        self.setObjectName("planEditorSectionCard")
        self.setFrameShape(QFrame.NoFrame)
        self.setAutoFillBackground(False)
        self.setAttribute(Qt.WA_TranslucentBackground, True)

    def paintEvent(self, event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        radius = max(0, scale_px(self._radius, self._ui_scale))
        rect = QRectF(0.5, 0.5, max(0.0, self.width() - 1.0), max(0.0, self.height() - 1.0))
        path = QPainterPath()
        path.addRoundedRect(rect, radius, radius)
        fill = QLinearGradient(rect.topLeft(), rect.topRight())
        fill.setColorAt(0.0, QColor(_mix_hex(SURFACE_ALT, "#ffffff", 0.03)))
        fill.setColorAt(1.0, QColor(_mix_hex(SURFACE_ALT, BG, 0.14)))
        painter.fillPath(path, fill)
        painter.setPen(QPen(QColor(_mix_hex(BORDER, SURFACE_ALT, 0.24)), 1))
        painter.drawPath(path)
        painter.end()


class PlanEditorContentPanel(RoundedMaskFrame):
    def __init__(self, *, ui_scale: float, radius: int = 18, parent: QWidget | None = None) -> None:
        super().__init__(ui_scale=ui_scale, radius=radius, parent=parent)
        self.setObjectName("planEditorContentPanel")
        self.setFrameShape(QFrame.NoFrame)
        self.setAutoFillBackground(False)
        self.setAttribute(Qt.WA_TranslucentBackground, True)

    def paintEvent(self, event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        radius = max(0, scale_px(self._radius, self._ui_scale))
        rect = QRectF(0, 0, max(0.0, self.width()), max(0.0, self.height()))
        path = QPainterPath()
        path.addRoundedRect(rect, radius, radius)
        painter.fillPath(path, QColor(BG))
        painter.end()


class PlanGridContentPanel(PlanEditorContentPanel):
    pass


class InventorySortDropdownButton(QPushButton):
    modeChanged = Signal(str)

    def __init__(self, *, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("inventorySortDropdownButton")
        self._menu = QMenu(self)
        self._options: list[tuple[str, str]] = []
        self._current_data = ""
        self._display_text = ""
        self.setMenu(self._menu)

    def addItem(self, label: str, data: str) -> None:
        self._options.append((label, data))
        action = self._menu.addAction(label)
        action.triggered.connect(lambda _checked=False, value=data: self.setCurrentData(value))
        if not self._current_data:
            self._set_current_data(data, emit=False)

    def clear(self) -> None:
        self._menu.clear()
        self._options.clear()
        self._current_data = ""
        self._display_text = ""
        super().setText("")
        self.update()

    def setCurrentIndex(self, index: int) -> None:
        if 0 <= index < len(self._options):
            self._set_current_data(self._options[index][1], emit=False)

    def currentData(self) -> str:
        return self._current_data

    def setCurrentData(self, data: str) -> None:
        self._set_current_data(data, emit=True)

    def _set_current_data(self, data: str, *, emit: bool) -> None:
        match = next(((label, value) for label, value in self._options if value == data), None)
        if match is None:
            return
        label, value = match
        changed = value != self._current_data
        self._current_data = value
        self._display_text = label
        super().setText("")
        self.updateGeometry()
        self.update()
        if emit and changed:
            self.modeChanged.emit(value)

    def _show_menu(self) -> None:
        self._menu.popup(self.mapToGlobal(self.rect().bottomLeft()))

    def text(self) -> str:
        return self._display_text

    def sizeHint(self) -> QSize:
        hint = super().sizeHint()
        text_width = QFontMetrics(self.font()).horizontalAdvance(self._display_text)
        return QSize(max(hint.width(), text_width + 54), hint.height())

    def paintEvent(self, event) -> None:
        super().paintEvent(event)
        if not self._display_text:
            return
        painter = QPainter(self)
        painter.setRenderHint(QPainter.TextAntialiasing, True)
        painter.setPen(QColor(self.palette().buttonText().color()))
        rect = self.rect().adjusted(22, 0, -30, 0)
        painter.drawText(rect, Qt.AlignLeft | Qt.AlignVCenter, self._display_text)
        painter.end()


class InventoryPressureRow(QFrame):
    def __init__(self, *, ui_scale: float, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self.setObjectName("inventoryPressureRow")
        self.setFrameShape(QFrame.NoFrame)
        self.setFixedHeight(scale_px(36, self._ui_scale))

        layout = QHBoxLayout(self)
        layout.setContentsMargins(
            scale_px(6, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(4, self._ui_scale),
        )
        layout.setSpacing(scale_px(6, self._ui_scale))

        self._icon = QLabel()
        self._icon.setFixedSize(scale_px(26, self._ui_scale), scale_px(26, self._ui_scale))
        self._icon.setAlignment(Qt.AlignCenter)
        layout.addWidget(self._icon, 0, Qt.AlignTop)

        meter_stack = QVBoxLayout()
        meter_stack.setContentsMargins(0, scale_px(4, self._ui_scale), 0, 0)
        meter_stack.setSpacing(scale_px(4, self._ui_scale))
        self._bar = QProgressBar()
        self._bar.setObjectName("inventoryPressureBar")
        self._bar.setTextVisible(False)
        self._bar.setFixedHeight(scale_px(7, self._ui_scale))
        meter_stack.addWidget(self._bar)

        self._coverage = QLabel("-")
        self._coverage.setObjectName("inventoryPressureCoverage")
        self._coverage.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        meter_stack.addWidget(self._coverage)
        layout.addLayout(meter_stack, 1)
        layout.setAlignment(meter_stack, Qt.AlignTop)

        self._amount = QLabel("-")
        self._amount.setObjectName("inventoryPressureAmount")
        self._amount.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        self._amount.setFixedWidth(scale_px(34, self._ui_scale))
        layout.addWidget(self._amount, 0, Qt.AlignVCenter)

    def setData(
        self,
        *,
        icon_path: Path | None,
        item_id: str,
        name: str,
        amount: int,
        total: int,
        meta: str,
        pool: bool,
    ) -> None:
        shortage_percentage = 0 if total <= 0 else min(100, int((amount / total) * 100))
        coverage_percentage = max(0, 100 - shortage_percentage)
        covered = max(0, total - amount)
        coverage_text = f"{_format_count(covered, compact=True)}/{_format_count(total, compact=True)}"
        self._coverage.setText(coverage_text)
        self._amount.setText(f"{coverage_percentage}%")
        tooltip = f"{name}\n{meta}\n부족량: {_full_count_tooltip(amount)} / 필요: {_full_count_tooltip(total)}"
        self.setToolTip(tooltip)
        self._icon.setToolTip(tooltip)
        self._coverage.setToolTip(tooltip)
        self._amount.setToolTip(tooltip)
        self._amount.setStyleSheet("color: #ff304f;")
        self._bar.setValue(coverage_percentage)
        self._bar.setToolTip(f"충족률: {coverage_percentage}%")
        if icon_path is not None and icon_path.exists():
            pixmap = _item_icon_pixmap(size=self._icon.size(), item_id=item_id, icon_path=icon_path)
            if not pixmap.isNull():
                self._icon.setPixmap(pixmap)
                return
        self._icon.setPixmap(QPixmap())


@dataclass(slots=True)
class PlanResourceRequirement:
    key: str
    name: str
    required: int
    owned: int
    icon_path: Path | None
    category: str
    icon: QPixmap | None = None


@dataclass(slots=True)
class InventoryOpartStudentImpact:
    student_id: str
    title: str
    ex_required: int = 0
    skill_required: int = 0

    @property
    def total_required(self) -> int:
        return self.ex_required + self.skill_required


@dataclass(slots=True)
class InventoryOpartPlanUsage:
    item_id: str
    name: str
    required: int = 0
    owned: int = 0
    ex_required: int = 0
    skill_required: int = 0
    impacts: list[InventoryOpartStudentImpact] = field(default_factory=list)
    pool_required: int = 0
    pool_ex_required: int = 0
    pool_skill_required: int = 0
    pool_impacts: list[InventoryOpartStudentImpact] = field(default_factory=list)

    @property
    def shortage(self) -> int:
        return max(0, self.required - self.owned)

    @property
    def pool_shortage(self) -> int:
        return max(0, self.pool_required - self.owned)


class InventoryOpartFamilyRow(QFrame):
    selected = Signal(str)

    def __init__(
        self,
        *,
        family_name: str,
        tier_items: list[tuple[int, str, str, int, str, Path | None]],
        selected_item_id: str | None,
        ui_scale: float,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self._buttons: dict[str, QPushButton] = {}
        self.setObjectName("planBand")

        layout = QGridLayout(self)
        layout.setContentsMargins(
            scale_px(8, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        layout.setHorizontalSpacing(scale_px(8, self._ui_scale))
        layout.setVerticalSpacing(0)

        icon_size = QSize(scale_px(34, self._ui_scale), scale_px(34, self._ui_scale))
        for column, (tier, item_id, name, owned, status, icon_path) in enumerate(tier_items):
            button = QPushButton(f"T{tier}  {owned:,}\n{status}")
            button.setObjectName("planQuickButton")
            button.setToolTip(f"{family_name} T{tier}\n{name}\n{owned:,} - {status}")
            button.setMinimumHeight(scale_px(74, self._ui_scale))
            button.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            if icon_path is not None and icon_path.exists():
                icon = _item_icon(icon_path, size=icon_size, item_id=item_id)
                if not icon.isNull():
                    button.setIcon(icon)
                    button.setIconSize(icon_size)
            button.clicked.connect(lambda _checked=False, value=item_id: self.selected.emit(value))
            self._buttons[item_id] = button
            layout.addWidget(button, 0, column)
            layout.setColumnStretch(column, 1)

        self.setSelectedItem(selected_item_id)

    def setSelectedItem(self, item_id: str | None) -> None:
        for button_item_id, button in self._buttons.items():
            button.setProperty("selectedOpart", button_item_id == item_id)
            if button_item_id == item_id:
                button.setStyleSheet("background: transparent; color: #ffa9f5; border: 2px solid #ffa9f5;")
            else:
                button.setStyleSheet("")


class PlanResourceChip(QFrame):
    def __init__(self, *, ui_scale: float, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        self.setObjectName("planBand")
        self.setFixedHeight(scale_px(50, self._ui_scale))
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(
            scale_px(9, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(9, self._ui_scale),
            scale_px(6, self._ui_scale),
        )
        layout.setSpacing(scale_px(8, self._ui_scale))

        self._icon = QLabel()
        self._icon.setFixedSize(scale_px(34, self._ui_scale), scale_px(34, self._ui_scale))
        self._icon.setAlignment(Qt.AlignCenter)
        layout.addWidget(self._icon, 0, Qt.AlignVCenter)

        text_wrap = QVBoxLayout()
        text_wrap.setContentsMargins(0, 0, 0, 0)
        text_wrap.setSpacing(scale_px(1, self._ui_scale))
        self._name = QLabel("-")
        self._name.setObjectName("detailMiniSub")
        self._name.setWordWrap(False)
        text_wrap.addWidget(self._name)
        self._quantity = QLabel("-")
        self._quantity.setObjectName("detailMiniValue")
        self._quantity.setWordWrap(False)
        text_wrap.addWidget(self._quantity)
        layout.addLayout(text_wrap, 1)

    def setData(self, requirement: PlanResourceRequirement) -> None:
        self._name.setText(requirement.name)
        self._name.setToolTip(requirement.name)
        self._quantity.setText(
            f"{_format_count(requirement.required, compact=True)} / {_format_count(requirement.owned, compact=True)}"
        )
        self._quantity.setToolTip(f"{requirement.required:,} / {requirement.owned:,}")
        shortage = requirement.required > requirement.owned
        self._name.setStyleSheet(f"color: #ff6b6b;" if shortage else "")
        self._quantity.setStyleSheet(f"color: #ff6b6b;" if shortage else "")

        if requirement.icon is not None and not requirement.icon.isNull():
            pixmap = _item_icon_pixmap(size=self._icon.size(), item_id=requirement.key, icon=requirement.icon)
            self._icon.setPixmap(pixmap)
            return

        if requirement.icon_path is not None and requirement.icon_path.exists():
            pixmap = _item_icon_pixmap(size=self._icon.size(), item_id=requirement.key, icon_path=requirement.icon_path)
            if not pixmap.isNull():
                self._icon.setPixmap(pixmap)
                return
        self._icon.setPixmap(QPixmap())


class MaxTokenSpinBox(QSpinBox):
    def __init__(self, *, show_max_token: bool = False, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._show_max_token = show_max_token
        self.setButtonSymbols(QAbstractSpinBox.NoButtons)
        self.setKeyboardTracking(False)

    def focusInEvent(self, event) -> None:
        super().focusInEvent(event)
        QTimer.singleShot(0, self.selectAll)

    def _clean_text(self, text: str) -> str:
        value = str(text or "").strip()
        prefix = self.prefix()
        suffix = self.suffix()
        if prefix and value.startswith(prefix):
            value = value[len(prefix):].strip()
        if suffix and value.endswith(suffix):
            value = value[: -len(suffix)].strip()
        return value

    def validate(self, text: str, pos: int) -> tuple[QValidator.State, str, int]:
        value = self._clean_text(text)
        if not value:
            return QValidator.Intermediate, text, pos
        if value.casefold() in {"m", "max"}:
            return QValidator.Acceptable, text, pos
        return super().validate(text, pos)

    def valueFromText(self, text: str) -> int:
        value = self._clean_text(text)
        if value.casefold() in {"m", "max"}:
            return self.maximum()
        return super().valueFromText(text)

    def textFromValue(self, value: int) -> str:
        if self._show_max_token and value == self.maximum():
            return "M"
        return super().textFromValue(value)


class ImmediatePlaceholderPlainTextEdit(QPlainTextEdit):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._stored_placeholder_text = ""
        self._placeholder_hidden_for_input = False
        self.textChanged.connect(self._sync_immediate_placeholder)

    def setPlaceholderText(self, text: str) -> None:
        self._stored_placeholder_text = str(text or "")
        if self._placeholder_hidden_for_input and not self.toPlainText():
            super().setPlaceholderText("")
        else:
            super().setPlaceholderText(self._stored_placeholder_text)

    def _hide_placeholder_for_input(self) -> None:
        if self.toPlainText() or self._placeholder_hidden_for_input:
            return
        self._placeholder_hidden_for_input = True
        super().setPlaceholderText("")

    def _sync_immediate_placeholder(self) -> None:
        if self.toPlainText():
            self._placeholder_hidden_for_input = False
            super().setPlaceholderText(self._stored_placeholder_text)
        elif not self.hasFocus():
            self._placeholder_hidden_for_input = False
            super().setPlaceholderText(self._stored_placeholder_text)

    def keyPressEvent(self, event) -> None:
        if event.text() and not (event.modifiers() & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)):
            self._hide_placeholder_for_input()
        super().keyPressEvent(event)

    def inputMethodEvent(self, event) -> None:
        has_input = bool(event.preeditString() or event.commitString())
        if has_input:
            self._hide_placeholder_for_input()
        super().inputMethodEvent(event)
        if has_input and not self.toPlainText():
            self._hide_placeholder_for_input()

    def focusOutEvent(self, event) -> None:
        super().focusOutEvent(event)
        if not self.toPlainText():
            self._placeholder_hidden_for_input = False
            super().setPlaceholderText(self._stored_placeholder_text)
        else:
            self._sync_immediate_placeholder()


class TacticalDeckSlot(QWidget):
    clicked = Signal()

    def __init__(
        self,
        *,
        card_asset: ParallelogramCardAsset,
        ui_scale: float,
        preferred_width: int,
        preferred_height: int,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._card_asset = card_asset
        self._ui_scale = ui_scale
        self._preferred_size = QSize(preferred_width, preferred_height)
        self._pixmap = QPixmap()
        self._text = ""
        self._badge_text = ""
        self._corner_badge_text = ""
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setMinimumWidth(scale_px(24, self._ui_scale))
        self.setFixedHeight(preferred_height)
        self.setCursor(Qt.PointingHandCursor)

    def setData(self, *, name: str, pixmap: QPixmap, badge_text: str = "", corner_badge_text: str = "") -> None:
        self._text = name
        self._pixmap = pixmap
        self._badge_text = str(badge_text or "").strip()
        self._corner_badge_text = str(corner_badge_text or "").strip()
        self.setToolTip("")
        self.update()

    def sizeHint(self) -> QSize:
        return self._preferred_size

    def paintEvent(self, event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.setRenderHint(QPainter.SmoothPixmapTransform, True)

        available_width = max(1, self.width())
        available_height = max(1, self.height())
        target_ratio = max(0.01, float(self._card_asset.aspect_ratio))
        if available_width / available_height > target_ratio:
            card_height = available_height
            card_width = max(1, int(round(card_height * target_ratio)))
        else:
            card_width = available_width
            card_height = max(1, int(round(card_width / target_ratio)))
        card_size = QSize(card_width, card_height)
        card_x = (available_width - card_width) // 2
        card_y = (available_height - card_height) // 2
        card_image = QImage(card_size, QImage.Format_ARGB32_Premultiplied)
        card_image.fill(Qt.transparent)
        card_painter = QPainter(card_image)
        card_painter.setRenderHint(QPainter.Antialiasing, True)
        card_painter.setRenderHint(QPainter.SmoothPixmapTransform, True)
        card_painter.drawImage(0, 0, self._card_asset.background(card_size, hovered=False, selected=False))
        if not self._pixmap.isNull():
            scaled = self._pixmap.scaled(card_size, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation)
            card_painter.drawPixmap((card_size.width() - scaled.width()) // 2, (card_size.height() - scaled.height()) // 2, scaled)
        card_painter.drawImage(0, 0, self._card_asset.outline(card_size))
        card_painter.end()

        painter.drawImage(card_x, card_y, self._card_asset.apply_alpha_mask(card_image))
        if self._text and self._pixmap.isNull():
            painter.setPen(QColor(MUTED))
            painter.drawText(self.rect(), Qt.AlignCenter, "*" if self._text.strip() == "*" else "?")
        if self._badge_text:
            badge_size = max(scale_px(22, self._ui_scale), min(card_width, card_height) // 4)
            badge_rect = QRectF(
                card_x + card_width - badge_size - scale_px(4, self._ui_scale),
                card_y + scale_px(4, self._ui_scale),
                badge_size,
                badge_size,
            )
            painter.setPen(QPen(QColor("#ffffff"), max(1, scale_px(2, self._ui_scale))))
            painter.setBrush(QColor(ACCENT_STRONG))
            painter.drawEllipse(badge_rect)
            badge_font = QFont(painter.font())
            badge_font.setBold(True)
            badge_font.setPixelSize(max(scale_px(11, self._ui_scale), int(badge_size * 0.52)))
            painter.setFont(badge_font)
            painter.setPen(QColor("#ffffff"))
            painter.drawText(badge_rect, Qt.AlignCenter, self._badge_text)
        if self._corner_badge_text:
            corner_badge_size = max(scale_px(22, self._ui_scale), min(card_width, card_height) // 5)
            corner_badge_rect = QRectF(
                card_x + scale_px(4, self._ui_scale),
                card_y + scale_px(4, self._ui_scale),
                corner_badge_size,
                corner_badge_size,
            )
            painter.setPen(QPen(QColor("#ffffff"), max(1, scale_px(2, self._ui_scale))))
            painter.setBrush(QColor("#2f80ed"))
            painter.drawEllipse(corner_badge_rect)
            corner_badge_font = QFont(painter.font())
            corner_badge_font.setBold(True)
            corner_badge_font.setPixelSize(max(scale_px(11, self._ui_scale), int(corner_badge_size * 0.54)))
            painter.setFont(corner_badge_font)
            painter.setPen(QColor("#ffffff"))
            painter.drawText(corner_badge_rect, Qt.AlignCenter, self._corner_badge_text)
        painter.end()

    def mousePressEvent(self, event) -> None:
        if event.button() == Qt.LeftButton:
            self.clicked.emit()
            event.accept()
            return
        super().mousePressEvent(event)


class InventoryOpartImpactRow(QWidget):
    def __init__(
        self,
        *,
        card_asset: ParallelogramCardAsset,
        ui_scale: float,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._ui_scale = ui_scale
        slot_width = scale_px(54, self._ui_scale)
        slot_height = max(scale_px(42, self._ui_scale), int(round(slot_width / card_asset.aspect_ratio)))
        self.setObjectName("planTransparent")
        self.setMinimumHeight(slot_height + scale_px(8, self._ui_scale))

        layout = QHBoxLayout(self)
        layout.setContentsMargins(
            scale_px(6, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(4, self._ui_scale),
        )
        layout.setSpacing(scale_px(10, self._ui_scale))

        self._icon = TacticalDeckSlot(
            card_asset=card_asset,
            ui_scale=self._ui_scale,
            preferred_width=slot_width,
            preferred_height=slot_height,
        )
        self._icon.setFixedSize(slot_width, slot_height)
        layout.addWidget(self._icon, 0, Qt.AlignVCenter)

        text_stack = QVBoxLayout()
        text_stack.setContentsMargins(0, 0, 0, 0)
        text_stack.setSpacing(scale_px(2, self._ui_scale))
        title_row = QHBoxLayout()
        title_row.setContentsMargins(0, 0, 0, 0)
        title_row.setSpacing(scale_px(6, self._ui_scale))
        self._title = QLabel("-")
        self._title.setObjectName("sectionTitle")
        self._title.setWordWrap(False)
        title_row.addWidget(self._title, 1)
        self._planned_badge = QLabel("필요")
        self._planned_badge.setObjectName("inventoryRequiredBadge")
        self._planned_badge.setAlignment(Qt.AlignCenter)
        self._planned_badge.setVisible(False)
        title_row.addWidget(self._planned_badge, 0, Qt.AlignVCenter)
        text_stack.addLayout(title_row)
        self._demand = QLabel("-")
        self._demand.setObjectName("inventoryStudentDemand")
        self._demand.setWordWrap(False)
        text_stack.addWidget(self._demand)
        layout.addLayout(text_stack, 1)

    def setData(self, *, impact: InventoryOpartStudentImpact, pixmap: QPixmap, planned: bool) -> None:
        self._title.setText(impact.title)
        self._demand.setText(
            f"EX : {_format_count(impact.ex_required, compact=True)}개, "
            f"일반 : {_format_count(impact.skill_required, compact=True)}개"
        )
        self._planned_badge.setVisible(planned)
        self._icon.setData(name=impact.title, pixmap=pixmap)
        if planned:
            self._title.setStyleSheet("color: #ffe1f0;")
            self._demand.setStyleSheet("color: #ff8fc4;")
        else:
            self._title.setStyleSheet("")
            self._demand.setStyleSheet("")

    def setGenericData(self, *, title: str, demand_text: str, pixmap: QPixmap, planned: bool = True) -> None:
        self._title.setText(title)
        self._demand.setText(demand_text)
        self._planned_badge.setVisible(planned)
        self._icon.setData(name=title, pixmap=pixmap)
        if planned:
            self._title.setStyleSheet("color: #ffe1f0;")
            self._demand.setStyleSheet("color: #ff8fc4;")
        else:
            self._title.setStyleSheet("")
            self._demand.setStyleSheet("")


class TacticalDeckEditor(QWidget):
    def __init__(self, title: str, *, card_asset: ParallelogramCardAsset, ui_scale: float, icon_provider, deck_parser=None, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._card_asset = card_asset
        self._ui_scale = ui_scale
        self._icon_provider = icon_provider
        self._deck_parser = deck_parser or parse_deck_template
        slot_base_width = 74 if self._ui_scale >= SMALL_16_9_SCALE_THRESHOLD else 58
        slot_base_height = 58 if self._ui_scale >= SMALL_16_9_SCALE_THRESHOLD else 44
        self._slot_width = scale_px(slot_base_width, self._ui_scale)
        self._slot_height = max(scale_px(slot_base_height, self._ui_scale), int(round(self._slot_width / self._card_asset.aspect_ratio)))
        self._icons: list[TacticalDeckSlot] = []
        self._deck = TacticalDeck()
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(7, self._ui_scale))

        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        title_label = QLabel(title)
        title_label.setObjectName("detailSectionTitle")
        header.addWidget(title_label)
        header.addStretch(1)
        layout.addLayout(header)

        icon_row = QHBoxLayout()
        icon_row.setContentsMargins(0, 0, 0, 0)
        icon_row.setSpacing(scale_px(5, self._ui_scale))
        for index in range(TACTICAL_STRIKER_SLOTS + TACTICAL_SUPPORT_SLOTS):
            if index == TACTICAL_STRIKER_SLOTS:
                divider = QLabel("|")
                divider.setObjectName("sectionTitle")
                divider.setAlignment(Qt.AlignCenter)
                icon_row.addWidget(divider)
            label = TacticalDeckSlot(
                card_asset=self._card_asset,
                ui_scale=self._ui_scale,
                preferred_width=self._slot_width,
                preferred_height=self._slot_height,
            )
            self._icons.append(label)
            icon_row.addWidget(label, 1)
        layout.addLayout(icon_row)

        self._template_input = QLineEdit()
        self._template_input.setPlaceholderText("student1 student2 student3 student4 support1 support2")
        self._template_input.returnPressed.connect(self.importTemplate)
        layout.addWidget(self._template_input)
        action_row = QHBoxLayout()
        action_row.setContentsMargins(0, 0, 0, 0)
        action_row.addStretch(1)
        copy_button = QPushButton("Copy")
        import_button = QPushButton("Import")
        button_width = max(
            scale_px(68, self._ui_scale),
            QFontMetrics(import_button.font()).horizontalAdvance("Import") + scale_px(28, self._ui_scale),
        )
        copy_button.setFixedWidth(button_width)
        import_button.setFixedWidth(button_width)
        copy_button.clicked.connect(self.copyTemplate)
        import_button.clicked.connect(self.importTemplate)
        action_row.addWidget(copy_button)
        action_row.addWidget(import_button)
        layout.addLayout(action_row)
        self._syncIcons()

    def deck(self) -> TacticalDeck:
        text = self._template_input.text().strip()
        if text and text != deck_input_template(self._deck):
            return self._deck_parser(text)
        return self._deck

    def templateText(self) -> str:
        return self._template_input.text().strip()

    def setDeck(self, deck: TacticalDeck) -> None:
        self._deck = deck
        self._template_input.setText(deck_input_template(self._deck))
        self._syncIcons()

    def clearDeck(self) -> None:
        self.setDeck(TacticalDeck())
        self._template_input.clear()

    def copyTemplate(self) -> None:
        self._deck = self.deck()
        self._syncIcons()
        text = deck_input_template(self._deck)
        self._template_input.setText(text)
        QApplication.clipboard().setText(text)

    def importTemplate(self) -> None:
        text = self._template_input.text().strip() or QApplication.clipboard().text().strip()
        if text:
            self.setDeck(self._deck_parser(text))

    def _syncIcons(self) -> None:
        deck = self._deck
        names = deck.strikers[:TACTICAL_STRIKER_SLOTS]
        names += [""] * max(0, TACTICAL_STRIKER_SLOTS - len(names))
        names += deck.supports[:TACTICAL_SUPPORT_SLOTS]
        for index, label in enumerate(self._icons):
            name = names[index] if index < len(names) else ""
            pixmap = self._icon_provider(name, max(self._slot_width, self._slot_height)) if name else QPixmap()
            label.setData(name=name, pixmap=pixmap if pixmap is not None else QPixmap())


class TacticalDeckPreview(QWidget):
    def __init__(
        self,
        *,
        card_asset: ParallelogramCardAsset,
        ui_scale: float,
        icon_provider,
        compact: bool = False,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._card_asset = card_asset
        self._ui_scale = ui_scale
        self._icon_provider = icon_provider
        self._compact = compact
        self._slot_width = scale_px(38 if compact else 58, self._ui_scale)
        self._slot_height = max(scale_px(30 if compact else 44, self._ui_scale), int(round(self._slot_width / self._card_asset.aspect_ratio)))
        self._icons: list[TacticalDeckSlot] = []
        self.setSizePolicy(QSizePolicy.Fixed if compact else QSizePolicy.Expanding, QSizePolicy.Fixed)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(4, self._ui_scale))
        divider_count = 0
        for index in range(TACTICAL_STRIKER_SLOTS + TACTICAL_SUPPORT_SLOTS):
            if index == TACTICAL_STRIKER_SLOTS:
                divider = QLabel("|")
                divider.setObjectName("detailSub")
                layout.addWidget(divider)
                divider_count += 1
            label = TacticalDeckSlot(
                card_asset=self._card_asset,
                ui_scale=self._ui_scale,
                preferred_width=self._slot_width,
                preferred_height=self._slot_height,
            )
            self._icons.append(label)
            layout.addWidget(label, 1)
        if compact:
            item_count = TACTICAL_STRIKER_SLOTS + TACTICAL_SUPPORT_SLOTS + divider_count
            total_width = self._slot_width * (TACTICAL_STRIKER_SLOTS + TACTICAL_SUPPORT_SLOTS) + layout.spacing() * max(0, item_count - 1) + scale_px(8, self._ui_scale)
            self.setFixedWidth(total_width)

    def setDeck(self, deck: TacticalDeck) -> None:
        names = deck.strikers[:TACTICAL_STRIKER_SLOTS]
        names += [""] * max(0, TACTICAL_STRIKER_SLOTS - len(names))
        names += deck.supports[:TACTICAL_SUPPORT_SLOTS]
        for index, label in enumerate(self._icons):
            name = names[index] if index < len(names) else ""
            pixmap = self._icon_provider(name, max(self._slot_width, self._slot_height)) if name else QPixmap()
            label.setData(name=name, pixmap=pixmap if pixmap is not None else QPixmap())
