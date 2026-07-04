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
from core.inventory_profiles import inventory_item_display_name
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


def _uses_yellow_item_background(item_id: str | None) -> bool:
    text = str(item_id or "")
    return (
        text == "Item_Icon_Favor_Selection"
        or text.startswith("Item_Icon_Favor_")
        or text in _WORKBOOK_ID_TO_NAME
        or text in _WB_ITEM_IDS
        or text.startswith("Item_Icon_WorkBook_")
    )


def _item_icon_background_path(item_id: str | None = None) -> Path | None:
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




class StudentViewerWindow(QMainWindow):
    def __init__(
        self,
        ui_scale: float,
        startup_geometry: QRect | None = None,
        startup_screen_geometry: QRect | None = None,
        student_scan_debug: bool = False,
    ):
        super().__init__()
        self._ui_scale = ui_scale
        self._startup_geometry = QRect(startup_geometry) if startup_geometry is not None and not startup_geometry.isEmpty() else None
        self._startup_screen_geometry = (
            QRect(startup_screen_geometry)
            if startup_screen_geometry is not None and not startup_screen_geometry.isEmpty()
            else None
        )
        self._startup_window_applied = False
        self._applying_work_area = False
        self._student_scan_debug_enabled = bool(student_scan_debug)
        self._ba_arrow_key_down = {VK_LEFT: False, VK_RIGHT: False}
        self._detail_panel: QFrame | None = None
        self._hero_wrap: QFrame | None = None
        self._busy_overlay: QFrame | None = None
        self._busy_label: QLabel | None = None
        self._busy_cursor_active = False
        self._student_card_asset = ParallelogramCardAsset(build_card_style(CARD_BUTTON_ASSET, ui_scale))
        self._card_button_style = build_card_button_style(CARD_BUTTON_ASSET, ui_scale)
        self._base_thumb_width = scale_px(self._student_card_asset.base_size.width(), ui_scale)
        self._thumb_width = self._base_thumb_width
        self._thumb_height = scale_px(self._student_card_asset.base_size.height(), ui_scale)
        self._student_grid_card_width = scale_px(STUDENT_GRID_CARD_BASE_WIDTH, ui_scale)
        self._plan_grid_card_width = scale_px(PLAN_GRID_CARD_BASE_WIDTH, ui_scale)
        outer_margin = self._student_card_asset.style.outer_margin * 2
        self._grid_width = self._thumb_width + outer_margin
        self._grid_height = self._thumb_height + outer_margin
        self.setWindowTitle("Blue Archive Planner")
        self.resize(scale_px(PLANNER_BASE_WIDTH, ui_scale), scale_px(PLANNER_BASE_HEIGHT, ui_scale))

        self._pool = QThreadPool.globalInstance()
        self._tactical_screenshot_tasks: list[QRunnable] = []
        if not get_active_profile_name():
            activate_profile("Default")
        self._all_students = load_students()
        self._records_by_id = {record.student_id: record for record in self._all_students}
        self._tactical_student_lookup_index: dict[str, list[str]] | None = None
        self._filtered_students = list(self._all_students)
        self._item_by_id: dict[str, StudentCardWidget] = {}
        self._plan_card_by_id: dict[str, StudentCardWidget] = {}
        self._resource_scope_card_by_id: dict[str, StudentCardWidget] = {}
        self._resource_search_card_by_id: dict[str, StudentCardWidget] = {}
        self._thumb_loading: set[tuple[str, int, int]] = set()
        self._pending_thumb_requests: list[tuple[str, int, int]] = []
        self._pending_thumb_lookup: set[tuple[str, int, int]] = set()
        self._thumb_batch_size = 16
        self._thumb_max_in_flight = 48
        self._thumb_pixmap_cache: OrderedDict[tuple[str, int, int], QPixmap] = OrderedDict()
        self._thumb_pixmap_cache_limit = 640
        self._placeholder_icon = make_placeholder_icon(self._thumb_width, self._thumb_height)
        self._unowned_icon_cache: dict[str, QIcon] = {}
        self._large_pixmap: QPixmap | None = None
        self._selected_filters: dict[str, set[str]] = {key: set() for key in FILTER_FIELD_ORDER}
        self._filter_options = build_filter_options(self._all_students)
        self._plan_path = get_storage_paths().current_dir / "growth_plan.json"
        self._plan = load_plan(self._plan_path)
        self._tactical_path = get_storage_paths().current_dir / "tactical_challenge.db"
        self._tactical_data = load_tactical_challenge(self._tactical_path, load_matches=False)
        self._raid_guide_path = get_storage_paths().current_raid_guides_json
        self._raid_guide_data = load_raid_guides(self._raid_guide_path)
        self._selected_raid_guide_id: str | None = None
        self._raid_new_guide_ids: set[str] = set()
        self._raid_guide_editor_guard = False
        self._raid_deck_rows: list[dict[str, object]] = []
        self._raid_selected_deck_slot_index = 0
        self._raid_student_lookup_index: dict[str, list[str]] | None = None
        self._raid_assist_window: TacticAssistWindow | None = None
        self._plan_editor_guard = False
        self._selected_plan_student_id: str | None = None
        self._plan_segment_inputs: dict[str, PlanSegmentSelector] = {}
        self._plan_level_inputs: dict[str, PlanStepper] = {}
        self._plan_level_rows: dict[str, QWidget] = {}
        self._plan_level_row_labels: dict[str, QLabel] = {}
        self._plan_equipment_labels: dict[str, QLabel] = {}
        self._plan_stat_rows: dict[str, QWidget] = {}
        self._plan_ability_release_expanded = False
        self._resource_selected_ids: set[str] = self._planned_student_ids()
        self._resource_search_pending_ids: set[str] = set()
        self._resource_current_student_id: str | None = None
        self._resource_include_unplanned_level = True
        self._resource_include_unplanned_equipment = True
        self._resource_include_unplanned_skills = True
        self._resource_requirement_sort_mode = "default"
        self._resource_syncing_controls = False
        self._main_tabs: QTabWidget | None = None
        self._settings_tab: QWidget | None = None
        self._scan_tab: QWidget | None = None
        self._students_tab: QWidget | None = None
        self._scanner_process: subprocess.Popen | None = None
        self._scanner_mode: str = ""
        self._scanner_tray_icon: QSystemTrayIcon | None = None
        self._settings_profile_combo: QComboBox | None = None
        self._settings_active_profile_label: QLabel | None = None
        self._settings_target_label: QLabel | None = None
        self._scan_header: QFrame | None = None
        self._scan_profile_label: QLabel | None = None
        self._scan_target_label: QLabel | None = None
        self._scan_status_label: QLabel | None = None
        self._scan_start_hint_label: QLabel | None = None
        self._scan_aspect_warning_label: QLabel | None = None
        self._scan_progress_bar: QProgressBar | None = None
        self._scan_progress_label: QLabel | None = None
        self._scan_eta_label: QLabel | None = None
        self._scan_stop_button: QPushButton | None = None
        self._scan_plana_image_label: QLabel | None = None
        self._scan_student_hero: StudentPortraitWidget | None = None
        self._scan_student_progress_strip: DetailProgressStrip | None = None
        self._scan_plana_message_label: QLabel | None = None
        self._scan_plana_meta_label: QLabel | None = None
        self._scan_plana_log: QPlainTextEdit | None = None
        self._scan_plana_pixmaps: dict[str, QPixmap] = {}
        self._scan_student_card: QFrame | None = None
        self._scan_inventory_card: QFrame | None = None
        self._scan_detail_stack: QStackedWidget | None = None
        self._scan_inventory_title_label: QLabel | None = None
        self._scan_inventory_meta_label: QLabel | None = None
        self._scan_inventory_grid_layout: QGridLayout | None = None
        self._scan_inventory_grid_cells: list[dict[str, object]] = []
        self._scan_inventory_grid_cols = 5
        self._scan_inventory_grid_rows = 4
        self._scan_inventory_visible_slots = 20
        self._scan_student_name_label: QLabel | None = None
        self._scan_student_meta_label: QLabel | None = None
        self._scan_student_value_labels: dict[str, QLabel] = {}
        self._scan_student_equip_cards: dict[str, EquipmentDetailCard] = {}
        self._scan_student_live_state: dict[str, object] = {}
        self._scan_student_position_label: QLabel | None = None
        self._scan_student_class_label: QLabel | None = None
        self._scan_student_weapon_level_label: QLabel | None = None
        self._scan_student_combat_stats_label: QLabel | None = None
        self._scan_current_student_id = ""
        self._scan_current_student_name = ""
        self._scan_inventory_confirmed_count = 0
        self._scan_inventory_scroll_animation: QParallelAnimationGroup | None = None
        self._scan_status_file_offset = 0
        self._scan_status_recent_messages: list[str] = []
        self._scan_started_at: datetime | None = None
        self._scan_last_progress: tuple[int | None, int | None] = (None, None)
        self._resource_tab: QWidget | None = None
        self._resources_dirty = False
        self._inventory_snapshot = load_inventory_snapshot()
        self._resource_snapshot = load_latest_resource_snapshot()
        self._inventory_quantity_index_cache = _inventory_quantity_index(self._inventory_snapshot or {}, self._resource_snapshot)
        self._plan_goal_map_cache: dict[str, StudentGoal] | None = None
        self._plan_cost_cache: dict[tuple[str, tuple[object, ...]], PlanCostSummary] = {}
        self._plan_resource_icon_path_cache: dict[tuple[str | None, str], Path | None] = {}
        self._plan_resource_pixmap_cache: dict[Path, QPixmap] = {}
        storage_paths = get_storage_paths()
        self._storage_watch_paths = (
            storage_paths.current_students_json,
            storage_paths.current_inventory_json,
            self._plan_path,
            self._tactical_path,
            self._raid_guide_path,
            storage_paths.db_path,
        )
        self._storage_mtimes = self._snapshot_storage_mtimes()
        self._stats_cards_layout: QGridLayout | None = None
        self._stats_summary_host: QWidget | None = None
        self._stats_chart_tabs: QTabBar | None = None
        self._stats_active_chart_tab = "collection"
        self._stats_sunburst: SunburstWidget | None = None
        self._stats_sunburst_mode: QComboBox | None = None
        self._stats_sunburst_value_mode: QComboBox | None = None
        self._stats_sunburst_detail: QLabel | None = None
        self._stats_sunburst_top_detail: QLabel | None = None
        self._stats_detail_path_label: QLabel | None = None
        self._stats_detail_name_label: QLabel | None = None
        self._stats_detail_level_label: QLabel | None = None
        self._stats_detail_total_label: QLabel | None = None
        self._stats_detail_metric_count_label: QLabel | None = None
        self._stats_detail_metric_percent_label: QLabel | None = None
        self._stats_detail_owned_bar: QProgressBar | None = None
        self._stats_detail_owned_bar_label: QLabel | None = None
        self._stats_detail_owned_label: QLabel | None = None
        self._stats_detail_unowned_label: QLabel | None = None
        self._stats_detail_planned_label: QLabel | None = None
        self._stats_sunburst_breadcrumb_host: QWidget | None = None
        self._stats_sunburst_breadcrumb_layout: QHBoxLayout | None = None
        self._stats_sunburst_legend_layout: QVBoxLayout | None = None
        self._stats_sunburst_root_button: QPushButton | None = None
        self._stats_sunburst_back_button: QPushButton | None = None
        self._stats_sunburst_clear_button: QPushButton | None = None
        self._stats_collection_mode = "school"
        self._stats_growth_mode = "level_bucket"
        self._stats_plan_mode = "shortage_items"
        self._stats_resource_mode = "shortage_items"
        self._stats_skill_mode = "skill_buff"
        self._stats_sunburst_selected_path: tuple[str, ...] = ()
        self._stats_sunburst_breadcrumb_path: tuple[str, ...] = ()
        self._stats_sunburst_selected_context: dict[str, object] = {}
        self._stats_sunburst_selected_node: SunburstNode | None = None
        self._stats_sunburst_drill_stack: list[tuple[str, ...]] = []
        self._tactical_selected_match_id: str | None = None
        self._tactical_match_page_size = 100
        self._tactical_match_loaded_count = self._tactical_match_page_size
        self._tactical_match_query = ""
        self._card_layout_guard = False
        self._thumb_pump = QTimer(self)
        self._thumb_pump.setSingleShot(False)
        self._thumb_pump.setInterval(0)
        self._thumb_pump.timeout.connect(self._drain_thumb_queue)
        self._filter_refresh_timer = QTimer(self)
        self._filter_refresh_timer.setSingleShot(True)
        self._filter_refresh_timer.setInterval(SEARCH_DEBOUNCE_MS)
        self._filter_refresh_timer.timeout.connect(self._apply_filters)
        self._plan_search_timer = QTimer(self)
        self._plan_search_timer.setSingleShot(True)
        self._plan_search_timer.setInterval(SEARCH_DEBOUNCE_MS)
        self._plan_search_timer.timeout.connect(self._refresh_plan_lists)
        self._storage_watch_timer = QTimer(self)
        self._storage_watch_timer.setSingleShot(False)
        self._storage_watch_timer.setInterval(1000)
        self._storage_watch_timer.timeout.connect(self._poll_storage_changes)
        self._storage_watch_timer.start()
        self._scanner_poll_timer = QTimer(self)
        self._scanner_poll_timer.setSingleShot(False)
        self._scanner_poll_timer.setInterval(1000)
        self._scanner_poll_timer.timeout.connect(self._check_scanner_process)
        self._scan_status_poll_timer = QTimer(self)
        self._scan_status_poll_timer.setSingleShot(False)
        self._scan_status_poll_timer.setInterval(75)
        self._scan_status_poll_timer.timeout.connect(self._poll_scan_status_events)
        self._ba_input_poll_timer = QTimer(self)
        self._ba_input_poll_timer.setSingleShot(False)
        self._ba_input_poll_timer.setInterval(35)
        self._ba_input_poll_timer.timeout.connect(self._poll_debug_ba_arrow_keys)

        self._build_ui()
        app = QApplication.instance()
        if app is not None:
            app.installEventFilter(self)
        if self._student_scan_debug_enabled:
            self._load_saved_target_into_capture()
            self._ba_input_poll_timer.start()
        self._apply_filters()
        self._refresh_plan_lists()
        self._refresh_plan_totals()
        self._refresh_stats_tab()
        self._refresh_resource_students_list()
        self._refresh_resource_view()
        self._refresh_tactical_tab()
        self._resources_dirty = False
        self.setMinimumSize(1, 1)

    def showEvent(self, event) -> None:
        super().showEvent(event)
        if self._startup_window_applied:
            return
        self._startup_window_applied = True
        QTimer.singleShot(0, self._apply_startup_window_state)

    def closeEvent(self, event) -> None:
        self._terminate_scanner_process()
        assist_window = getattr(self, "_raid_assist_window", None)
        if assist_window is not None:
            assist_window.close()
            self._raid_assist_window = None
        super().closeEvent(event)

    def _terminate_scanner_process(self) -> None:
        process = self._scanner_process
        self._scanner_poll_timer.stop()
        if self._scan_status_poll_timer is not None:
            self._scan_status_poll_timer.stop()
        if process is None:
            return
        self._scanner_process = None
        self._scanner_mode = ""
        self._finish_scan_progress_view(1)
        if process.poll() is not None:
            return
        try:
            process.terminate()
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=2)
        except Exception:
            pass

    def _snapshot_storage_mtimes(self) -> dict[Path, int | None]:
        mtimes: dict[Path, int | None] = {}
        for path in self._storage_watch_paths:
            try:
                mtimes[path] = path.stat().st_mtime_ns
            except OSError:
                mtimes[path] = None
        return mtimes

    def _poll_storage_changes(self) -> None:
        current_mtimes = self._snapshot_storage_mtimes()
        if current_mtimes == self._storage_mtimes:
            return
        self._storage_mtimes = current_mtimes
        self._reload_data()

    def _apply_startup_window_state(self) -> None:
        self._apply_work_area_geometry(self._startup_geometry, self._startup_screen_geometry)
        self._startup_geometry = None
        self._startup_screen_geometry = None
        QTimer.singleShot(0, self._sync_hero_height)
        self._schedule_inventory_layout_sync()
        if os.name == "nt":
            self.winId()
            _set_windows_caption_theme(int(self.winId()), PALETTE_SOFT, _preferred_text_hex(PALETTE_SOFT))

    def _apply_work_area_geometry(
        self,
        available_override: QRect | None = None,
        screen_geometry_override: QRect | None = None,
    ) -> None:
        if available_override is not None and not available_override.isEmpty():
            available = QRect(available_override)
            screen_geometry = QRect(screen_geometry_override) if screen_geometry_override is not None and not screen_geometry_override.isEmpty() else QRect(available_override)
        else:
            screen = self.windowHandle().screen() if self.windowHandle() else QApplication.primaryScreen()
            available = screen.availableGeometry() if screen is not None else QRect()
            screen_geometry = screen.geometry() if screen is not None else QRect()
        if os.name == "nt" and (available_override is None or available_override.isEmpty()):
            self.winId()
            work_area = _windows_work_area(int(self.winId()))
            if work_area is not None:
                available = work_area
        if available.isEmpty():
            return
        target_frame = _window_frame_for_screen_area(screen_geometry, available)
        frame = self.frameGeometry()
        client = self.geometry()
        left_margin = max(0, client.left() - frame.left())
        top_margin = max(0, client.top() - frame.top())
        right_margin = max(0, frame.right() - client.right())
        bottom_margin = max(0, frame.bottom() - client.bottom())
        target_client = QRect(
            target_frame.left() + left_margin,
            target_frame.top() + top_margin,
            max(1, target_frame.width() - left_margin - right_margin),
            max(1, target_frame.height() - top_margin - bottom_margin),
        )
        self._applying_work_area = True
        try:
            self.setWindowState(self.windowState() & ~Qt.WindowMaximized)
            self.setMinimumSize(1, 1)
            self.setMaximumSize(16777215, 16777215)
            self.setGeometry(target_client)
            self.setFixedSize(target_client.size())
        finally:
            self._applying_work_area = False

    def _add_main_tab(self, tabs: QTabWidget, content: QWidget, label: str) -> QWidget:
        tabs.addTab(content, label)
        return content

    def _build_scan_student_card(self) -> QFrame:
        card = QFrame()
        card.setObjectName("scanStudentCard")
        card.setMinimumWidth(scale_px(560, self._ui_scale))
        card.setMinimumHeight(scale_px(410, self._ui_scale))
        card.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        self._scan_student_value_labels = {}
        self._scan_student_equip_cards = {}

        capture_layout = QVBoxLayout(card)
        capture_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        capture_layout.setSpacing(scale_px(12, self._ui_scale))

        top_row = QHBoxLayout()
        top_row.setContentsMargins(0, 0, 0, 0)
        top_row.setSpacing(scale_px(18, self._ui_scale))

        hero_wrap = QFrame()
        hero_wrap.setObjectName("heroWrap")
        hero_wrap.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        hero_wrap.setMinimumSize(scale_px(236, self._ui_scale), scale_px(178, self._ui_scale))
        hero_layout = QVBoxLayout(hero_wrap)
        hero_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        self._scan_student_hero = StudentPortraitWidget(self._student_card_asset)
        self._scan_student_hero.setObjectName("hero")
        self._scan_student_hero.setMinimumSize(scale_px(220, self._ui_scale), scale_px(164, self._ui_scale))
        self._scan_student_hero.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        hero_layout.addWidget(self._scan_student_hero)
        top_row.addWidget(hero_wrap, 5)

        top_panel = QFrame()
        top_panel.setObjectName("scanStudentMetaPanel")
        top_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        top_panel.setMinimumWidth(scale_px(250, self._ui_scale))
        top_layout = QVBoxLayout(top_panel)
        top_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        top_layout.setSpacing(scale_px(8, self._ui_scale))

        self._scan_student_progress_strip = ScanLiveProgressStrip()
        top_layout.addWidget(self._scan_student_progress_strip)

        stat_row = QHBoxLayout()
        stat_row.setContentsMargins(0, 0, 0, 0)
        stat_row.setSpacing(scale_px(8, self._ui_scale))

        level_card = ParallelogramPanel(fill=_mix_hex(PALETTE_SOFT, SURFACE_ALT, 0.52), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        level_card.setMinimumHeight(scale_px(108, self._ui_scale))
        level_layout = QVBoxLayout(level_card)
        level_layout.setContentsMargins(scale_px(14, self._ui_scale), scale_px(12, self._ui_scale), scale_px(14, self._ui_scale), scale_px(12, self._ui_scale))
        level_layout.setSpacing(scale_px(4, self._ui_scale))
        level_title = QLabel("LEVEL")
        level_title.setObjectName("detailSectionTitle")
        level_title.setAlignment(Qt.AlignCenter)
        level_value = QLabel("-")
        level_value.setObjectName("detailBigValue")
        level_value.setAlignment(Qt.AlignCenter)
        self._scan_student_value_labels["level"] = level_value
        level_layout.addWidget(level_title)
        level_layout.addStretch(1)
        level_layout.addWidget(level_value)
        level_layout.addStretch(1)
        stat_row.addWidget(level_card, 3)

        side_cards = QVBoxLayout()
        side_cards.setContentsMargins(0, 0, 0, 0)
        side_cards.setSpacing(scale_px(6, self._ui_scale))
        self._scan_student_position_label = QLabel("-")
        self._scan_student_class_label = QLabel("-")
        self._scan_student_weapon_level_label = QLabel("-")
        for value_label, compact_text in (
            (self._scan_student_position_label, True),
            (self._scan_student_class_label, True),
            (self._scan_student_weapon_level_label, "weapon"),
        ):
            mini_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_SOFT, 0.16), border=PALETTE_SOFT, slant=DETAIL_SLANT)
            mini_card.setMinimumHeight(scale_px(30, self._ui_scale))
            mini_layout = QVBoxLayout(mini_card)
            mini_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(4, self._ui_scale), scale_px(10, self._ui_scale), scale_px(4, self._ui_scale))
            value_label.setObjectName("scanLiveWeaponValue" if compact_text == "weapon" else "scanLiveMiniValue")
            value_label.setAlignment(Qt.AlignCenter)
            mini_layout.addWidget(value_label, 1)
            side_cards.addWidget(mini_card)
        stat_row.addLayout(side_cards, 2)
        top_layout.addLayout(stat_row)

        self._scan_student_value_labels["stats"] = QLabel("-")
        self._scan_student_value_labels["stats"].setObjectName("detailMetaLine")
        self._scan_student_value_labels["stats"].setAlignment(Qt.AlignCenter)
        self._scan_student_value_labels["stats"].setTextFormat(Qt.RichText)
        top_layout.addWidget(self._scan_student_value_labels["stats"])
        top_row.addWidget(top_panel, 4)
        capture_layout.addLayout(top_row, 3)

        bottom_row = QHBoxLayout()
        bottom_row.setContentsMargins(0, 0, 0, 0)
        bottom_row.setSpacing(scale_px(18, self._ui_scale))

        skill_equip_layout = QVBoxLayout()
        skill_equip_layout.setContentsMargins(0, 0, 0, 0)
        skill_equip_layout.setSpacing(scale_px(10, self._ui_scale))

        skill_row = QHBoxLayout()
        skill_row.setContentsMargins(0, 0, 0, 0)
        skill_row.setSpacing(scale_px(8, self._ui_scale))
        for key, caption in (("skill_ex", "EX"), ("skill_s1", "N"), ("skill_s2", "P"), ("skill_s3", "S")):
            skill_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_ACCENT, 0.14), border=PALETTE_SOFT, slant=DETAIL_SLANT)
            skill_card.setMinimumHeight(scale_px(76, self._ui_scale))
            skill_layout = QVBoxLayout(skill_card)
            skill_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(7, self._ui_scale), scale_px(10, self._ui_scale), scale_px(7, self._ui_scale))
            skill_layout.setSpacing(scale_px(3, self._ui_scale))
            caption_label = QLabel(caption)
            caption_label.setObjectName("detailSkillLabel")
            caption_label.setAlignment(Qt.AlignCenter)
            value_label = QLabel("-")
            value_label.setObjectName("detailSkillValue")
            value_label.setAlignment(Qt.AlignCenter)
            value_label.setWordWrap(True)
            self._scan_student_value_labels[key] = value_label
            skill_layout.addStretch(1)
            skill_layout.addWidget(caption_label)
            skill_layout.addWidget(value_label)
            skill_layout.addStretch(1)
            skill_row.addWidget(skill_card, 1)
        skill_equip_layout.addLayout(skill_row, 1)

        equip_row = QHBoxLayout()
        equip_row.setContentsMargins(0, 0, 0, 0)
        equip_row.setSpacing(scale_px(8, self._ui_scale))
        for key in ("equip1", "equip2", "equip3", "favorite"):
            equip_card = EquipmentDetailCard(
                self._ui_scale,
                fill=_mix_hex(PALETTE_PANEL_ALT, PALETTE_SOFT, 0.18),
                border=PALETTE_SOFT,
                slant=DETAIL_SLANT,
            )
            equip_card.setMinimumHeight(scale_px(94, self._ui_scale))
            equip_row.addWidget(equip_card, 1)
            self._scan_student_equip_cards[key] = equip_card
        skill_equip_layout.addLayout(equip_row, 1)
        bottom_row.addLayout(skill_equip_layout, 10)

        stats_panel = QFrame()
        stats_panel.setObjectName("scanStudentMetaPanel")
        stats_panel.setSizePolicy(QSizePolicy.Fixed, QSizePolicy.Expanding)
        stats_panel.setMinimumWidth(scale_px(126, self._ui_scale))
        stats_panel.setMaximumWidth(scale_px(154, self._ui_scale))
        stats_layout = QVBoxLayout(stats_panel)
        stats_layout.setContentsMargins(scale_px(8, self._ui_scale), scale_px(8, self._ui_scale), scale_px(8, self._ui_scale), scale_px(8, self._ui_scale))
        self._scan_student_combat_stats_label = QLabel("-")
        self._scan_student_combat_stats_label.setObjectName("detailMetaLine")
        self._scan_student_combat_stats_label.setAlignment(Qt.AlignCenter | Qt.AlignVCenter)
        self._scan_student_combat_stats_label.setTextFormat(Qt.RichText)
        self._scan_student_combat_stats_label.setMinimumHeight(scale_px(112, self._ui_scale))
        self._scan_student_combat_stats_label.setWordWrap(False)
        stats_layout.addWidget(self._scan_student_combat_stats_label, 1)
        bottom_row.addWidget(stats_panel, 0)
        capture_layout.addLayout(bottom_row, 2)

        self._scan_student_name_label = QLabel("")
        self._scan_student_meta_label = QLabel("")
        self._scan_student_name_label.setVisible(False)
        self._scan_student_meta_label.setVisible(False)

        self._scan_student_card = card
        self._render_scan_live_card()
        return card
    def _build_scan_inventory_grid_card(self) -> QFrame:
        card = QFrame()
        card.setObjectName("scanInventoryCard")
        card.setMinimumWidth(scale_px(560, self._ui_scale))
        card.setMinimumHeight(scale_px(410, self._ui_scale))
        card.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        layout = QVBoxLayout(card)
        layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        layout.setSpacing(scale_px(12, self._ui_scale))

        header_row = QHBoxLayout()
        header_row.setContentsMargins(0, 0, 0, 0)
        header_row.setSpacing(scale_px(12, self._ui_scale))
        self._scan_inventory_title_label = QLabel("인벤토리 그리드")
        self._scan_inventory_title_label.setObjectName("detailInlineName")
        self._scan_inventory_title_label.setWordWrap(True)
        header_row.addWidget(self._scan_inventory_title_label, 1)

        self._scan_inventory_meta_label = QLabel("스캔 대기 중")
        self._scan_inventory_meta_label.setObjectName("detailInlineSub")
        self._scan_inventory_meta_label.setWordWrap(True)
        self._scan_inventory_meta_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        header_row.addWidget(self._scan_inventory_meta_label, 2)
        layout.addLayout(header_row)

        grid_host = QFrame()
        grid_host.setObjectName("scanInventoryGridHost")
        grid_host.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        grid = QGridLayout(grid_host)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setSpacing(scale_px(8, self._ui_scale))
        self._scan_inventory_grid_layout = grid
        self._scan_inventory_grid_cells = []
        self._scan_inventory_grid_cols = 5
        self._scan_inventory_grid_rows = 4
        self._scan_inventory_visible_slots = 20
        icon_min_size = scale_px(54, self._ui_scale)
        cell_min_size = scale_px(68, self._ui_scale)
        for index in range(25):
            cell = QFrame()
            cell.setObjectName("scanInventorySlot")
            cell.setMinimumSize(cell_min_size, cell_min_size)
            cell.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
            cell_layout = QVBoxLayout(cell)
            cell_layout.setContentsMargins(
                scale_px(5, self._ui_scale),
                scale_px(5, self._ui_scale),
                scale_px(5, self._ui_scale),
                scale_px(5, self._ui_scale),
            )
            cell_layout.setSpacing(scale_px(2, self._ui_scale))
            icon_label = QLabel()
            icon_label.setObjectName("scanInventorySlotImage")
            icon_label.setMinimumSize(icon_min_size, icon_min_size)
            icon_label.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
            icon_label.setAlignment(Qt.AlignCenter)
            cell_layout.addWidget(icon_label, 1)
            quantity_label = QLabel("")
            quantity_label.setObjectName("scanInventorySlotQuantity")
            quantity_label.setAlignment(Qt.AlignCenter)
            quantity_label.setMinimumHeight(scale_px(18, self._ui_scale))
            quantity_label.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            cell_layout.addWidget(quantity_label, 0)
            grid.addWidget(cell, index // self._scan_inventory_grid_cols, index % self._scan_inventory_grid_cols)
            self._scan_inventory_grid_cells.append({
                "frame": cell,
                "image": icon_label,
                "quantity_label": quantity_label,
                "slot": index + 1,
                "tier": None,
            })
        layout.addWidget(grid_host, 1)
        self._scan_inventory_card = card
        self._configure_scan_inventory_grid(5, 4)
        return card
    def _set_scan_detail_mode(self, mode: str) -> None:
        stack = self._scan_detail_stack
        if stack is None:
            return
        if mode == "inventory" and self._scan_inventory_card is not None:
            stack.setCurrentWidget(self._scan_inventory_card)
        elif self._scan_student_card is not None:
            stack.setCurrentWidget(self._scan_student_card)

    def _configure_scan_inventory_grid(self, grid_cols: object = None, grid_rows: object = None) -> None:
        try:
            cols = int(grid_cols)
        except (TypeError, ValueError):
            cols = 5
        try:
            rows = int(grid_rows)
        except (TypeError, ValueError):
            rows = 4
        cols = max(1, min(5, cols))
        rows = max(1, min(5, rows))
        self._scan_inventory_grid_cols = cols
        self._scan_inventory_grid_rows = rows
        self._scan_inventory_visible_slots = min(len(self._scan_inventory_grid_cells), cols * rows)
        grid = self._scan_inventory_grid_layout
        if grid is not None:
            for column in range(5):
                grid.setColumnStretch(column, 1 if column < cols else 0)
                grid.setColumnMinimumWidth(column, 0)
            for row in range(5):
                grid.setRowStretch(row, 1 if row < rows else 0)
                grid.setRowMinimumHeight(row, 0)
            for index, cell in enumerate(self._scan_inventory_grid_cells):
                frame = cell.get("frame")
                if isinstance(frame, QFrame):
                    grid.removeWidget(frame)
                    grid.addWidget(frame, index // cols, index % cols)
        self._reset_scan_inventory_grid_cells()
        self._reflow_scan_inventory_grid()

    def _reflow_scan_inventory_grid(self) -> None:
        grid = self._scan_inventory_grid_layout
        if grid is None:
            return
        cols = max(1, int(getattr(self, "_scan_inventory_grid_cols", 5) or 5))
        visible_slots = int(getattr(self, "_scan_inventory_visible_slots", 20) or 20)
        cells = list(getattr(self, "_scan_inventory_grid_cells", []))
        visible_cells = [
            (index, cell)
            for index, cell in enumerate(cells[:visible_slots])
        ]
        for index, cell in visible_cells:
            frame = cell.get("frame")
            if isinstance(frame, QFrame):
                grid.removeWidget(frame)
                grid.addWidget(frame, index // cols, index % cols)
                frame.setVisible(True)
        for index, cell in enumerate(cells[visible_slots:], start=visible_slots):
            frame = cell.get("frame")
            if isinstance(frame, QFrame):
                grid.removeWidget(frame)
                grid.addWidget(frame, index // cols, index % cols)
                frame.setVisible(False)

    def _inventory_slot_color(self, tier: object = None, confirmed: bool = False) -> str:
        if confirmed:
            return "#DDF7EC"
        try:
            tier_number = int(tier)
        except (TypeError, ValueError):
            tier_number = -1
        return {
            0: "#F7FAFC",
            1: "#D8ECFF",
            2: "#FFF0B8",
            3: "#EBCBFF",
        }.get(tier_number, "#EEF4F8")



    def _style_scan_inventory_cell(
        self,
        cell: dict[str, object],
        *,
        tier: object = None,
        confirmed: bool = False,
        anchor: bool = False,
        scan_target: bool = False,
    ) -> None:
        frame = cell.get("frame")
        if not isinstance(frame, QFrame):
            return
        if anchor and confirmed:
            bg = "rgba(255, 194, 87, 0.18)"
            border = "#FFC247"
        elif confirmed:
            bg = "rgba(65, 184, 131, 0.12)"
            border = "#41B883"
        elif anchor:
            bg = "rgba(255, 194, 87, 0.10)"
            border = "#F5B944"
        elif scan_target:
            bg = "rgba(92, 205, 255, 0.08)"
            border = "#5CCDFF"
        else:
            bg = "rgba(255, 255, 255, 0.04)"
            border = "#9EB6C8"
        frame.setStyleSheet(
            f"QFrame#scanInventorySlot {{ background: {bg}; border: 1px solid {border}; border-radius: 6px; }} "
            "QLabel { background: transparent; }"
        )

    def _empty_scan_inventory_state(self, slot_number: int) -> dict[str, object]:
        return {
            "slot": slot_number,
            "tier": None,
            "confirmed": False,
            "anchor": False,
            "scan_target": False,
            "item_name": "",
            "quantity": "",
            "item_id": None,
        }

    def _scan_inventory_cell_state(self, cell: dict[str, object]) -> dict[str, object]:
        return {
            "tier": cell.get("tier"),
            "confirmed": bool(cell.get("confirmed")),
            "anchor": bool(cell.get("anchor")),
            "scan_target": bool(cell.get("scan_target")),
            "item_name": str(cell.get("item_name") or ""),
            "quantity": str(cell.get("quantity") or ""),
            "item_id": cell.get("item_id"),
        }

    def _render_scan_inventory_cell(self, cell: dict[str, object], slot_number: int) -> None:
        image_label = cell.get("image")
        quantity_label = cell.get("quantity_label")
        tier = cell.get("tier")
        confirmed = bool(cell.get("confirmed"))
        anchor = bool(cell.get("anchor"))
        scan_target = bool(cell.get("scan_target"))
        item_name = str(cell.get("item_name") or "")
        quantity = str(cell.get("quantity") or "")
        item_id = cell.get("item_id")
        tooltip = f"{slot_number}\uBC88 \uC2AC\uB86F"
        if confirmed and item_name:
            tooltip = f"{item_name} x{quantity}" if quantity else item_name
        if anchor:
            tooltip = f"\uC575\uCEE4 / {tooltip}"
        if scan_target and not confirmed:
            tooltip = f"\uB2E4\uC74C \uC2A4\uCE94 / {tooltip}"
        if isinstance(image_label, QLabel):
            label_size = image_label.size()
            icon_side = max(
                scale_px(54, self._ui_scale),
                min(label_size.width(), label_size.height(), scale_px(86, self._ui_scale)),
            )
            image_label.setPixmap(
                _scan_inventory_slot_pixmap(
                    size=QSize(icon_side, icon_side),
                    item_id=str(item_id) if item_id else None,
                    item_name=item_name,
                    quantity=None,
                    tier=tier,
                    slot_number=None,
                )
            )
            image_label.setToolTip(tooltip)
        if isinstance(quantity_label, QLabel):
            quantity_text = str(quantity or "").strip()
            display_quantity = f"x{quantity_text}" if quantity_text else ""
            font_px = scale_px(15, self._ui_scale)
            if (display_quantity.startswith("x") and len(display_quantity) > 6) or (display_quantity and not display_quantity.startswith("x") and len(display_quantity) >= 6):
                font_px = scale_px(13, self._ui_scale)
            quantity_label.setText(display_quantity)
            quantity_label.setVisible(bool(display_quantity))
            quantity_label.setStyleSheet(
                f"background: transparent; color: #f7fbff; font-size: {font_px}px; font-weight: 900;"
            )
            quantity_label.setToolTip(tooltip)
        frame = cell.get("frame")
        if isinstance(frame, QFrame):
            frame.setVisible(slot_number <= getattr(self, "_scan_inventory_visible_slots", 20))
            frame.setToolTip(tooltip)
        self._style_scan_inventory_cell(
            cell,
            tier=tier,
            confirmed=confirmed,
            anchor=anchor,
            scan_target=scan_target,
        )

    def _apply_scan_inventory_cell_state(
        self,
        cell: dict[str, object],
        slot_number: int,
        state: dict[str, object] | None = None,
    ) -> None:
        next_state = self._empty_scan_inventory_state(slot_number)
        if state:
            for key in ("tier", "confirmed", "anchor", "scan_target", "item_name", "quantity", "item_id"):
                next_state[key] = state.get(key, next_state.get(key))
        cell.update(next_state)
        self._render_scan_inventory_cell(cell, slot_number)

    def _reset_scan_inventory_grid_cells(self) -> None:
        visible_slots = int(getattr(self, "_scan_inventory_visible_slots", 20) or 20)
        for index, cell in enumerate(getattr(self, "_scan_inventory_grid_cells", [])):
            slot_number = index + 1
            frame = cell.get("frame")
            if isinstance(frame, QFrame):
                frame.setVisible(index < visible_slots)
            self._apply_scan_inventory_cell_state(cell, slot_number)

    def _scan_inventory_cell(self, slot_number: object) -> dict[str, object] | None:
        try:
            index = int(slot_number) - 1
        except (TypeError, ValueError):
            return None
        cells = getattr(self, "_scan_inventory_grid_cells", [])
        if index < 0 or index >= len(cells) or index >= getattr(self, "_scan_inventory_visible_slots", len(cells)):
            return None
        return cells[index]

    def _set_scan_inventory_cell_tier(self, slot_number: object, tier: object) -> None:
        cell = self._scan_inventory_cell(slot_number)
        if cell is None:
            return
        cell["tier"] = tier
        self._render_scan_inventory_cell(cell, int(slot_number))

    def _mark_scan_inventory_cell_anchor(self, slot_number: object) -> None:
        cell = self._scan_inventory_cell(slot_number)
        if cell is None:
            return
        cell["anchor"] = True
        try:
            slot_index = int(slot_number)
        except (TypeError, ValueError):
            slot_index = 1
        self._render_scan_inventory_cell(cell, slot_index)
        self._reflow_scan_inventory_grid()

    def _set_scan_inventory_cell_confirmed(
        self,
        slot_number: object,
        item_name: str,
        quantity: str,
        item_id: str | None = None,
        *,
        row_anchor: bool = False,
    ) -> None:
        cell = self._scan_inventory_cell(slot_number)
        if cell is None:
            return
        try:
            slot_index = int(slot_number)
        except (TypeError, ValueError):
            slot_index = 1
        cell["confirmed"] = True
        cell["scan_target"] = False
        cell["item_name"] = item_name
        cell["quantity"] = quantity
        cell["item_id"] = item_id
        if row_anchor:
            cell["anchor"] = True
        self._render_scan_inventory_cell(cell, slot_index)
        self._reflow_scan_inventory_grid()

    def _apply_scan_inventory_scroll_feedback(
        self,
        moved_rows: object = None,
        overlap_rows: object = None,
        scan_slots: object = None,
    ) -> None:
        visible_slots = int(getattr(self, "_scan_inventory_visible_slots", 20) or 20)
        cols = max(1, int(getattr(self, "_scan_inventory_grid_cols", 5) or 5))
        rows = max(1, int(getattr(self, "_scan_inventory_grid_rows", 4) or 4))
        try:
            moved = int(moved_rows)
        except (TypeError, ValueError):
            try:
                moved = rows - int(overlap_rows)
            except (TypeError, ValueError):
                moved = rows
        moved = max(0, min(rows, moved))
        shift = moved * cols
        cells = list(getattr(self, "_scan_inventory_grid_cells", []))
        old_states = [self._scan_inventory_cell_state(cell) for cell in cells[:visible_slots]]
        new_states = [self._empty_scan_inventory_state(index + 1) for index in range(visible_slots)]
        if 0 < shift < visible_slots:
            for src_index in range(shift, visible_slots):
                dst_index = src_index - shift
                carried = dict(old_states[src_index])
                carried["scan_target"] = False
                new_states[dst_index].update(carried)
        elif shift == 0:
            for index in range(visible_slots):
                carried = dict(old_states[index])
                carried["scan_target"] = False
                new_states[index].update(carried)
        target_indices: set[int] = set()
        if isinstance(scan_slots, (list, tuple, set)):
            for raw in scan_slots:
                try:
                    value = int(raw)
                except (TypeError, ValueError):
                    continue
                if 0 <= value < visible_slots:
                    target_indices.add(value)
                elif 1 <= value <= visible_slots:
                    target_indices.add(value - 1)
        if not target_indices and shift > 0:
            target_indices = set(range(max(0, visible_slots - shift), visible_slots))
        for index in target_indices:
            if 0 <= index < visible_slots:
                new_states[index]["scan_target"] = True
        for index, cell in enumerate(cells):
            slot_number = index + 1
            if index < visible_slots:
                self._apply_scan_inventory_cell_state(cell, slot_number, new_states[index])
            else:
                frame = cell.get("frame")
                if isinstance(frame, QFrame):
                    frame.setVisible(False)
        self._reflow_scan_inventory_grid()
        self._animate_scan_inventory_scroll(moved)

    def _animate_scan_inventory_scroll(self, moved_rows: int) -> None:
        if moved_rows <= 0:
            return
        visible_slots = int(getattr(self, "_scan_inventory_visible_slots", 20) or 20)
        cols = max(1, int(getattr(self, "_scan_inventory_grid_cols", 5) or 5))
        rows = max(1, int(getattr(self, "_scan_inventory_grid_rows", 4) or 4))
        cells = list(getattr(self, "_scan_inventory_grid_cells", []))[:visible_slots]
        frames = [cell.get("frame") for cell in cells]
        frames = [frame for frame in frames if isinstance(frame, QFrame) and frame.isVisible()]
        if not frames:
            return
        row_step = 0
        if len(frames) > cols:
            row_step = abs(frames[cols].pos().y() - frames[0].pos().y())
        if row_step <= 0:
            spacing = 0
            grid = self._scan_inventory_grid_layout
            if grid is not None:
                spacing = max(0, grid.spacing())
            row_step = frames[0].height() + spacing
        offset = max(1, min(rows, int(moved_rows))) * max(1, row_step)
        previous = getattr(self, "_scan_inventory_scroll_animation", None)
        if previous is not None:
            previous.stop()
        group = QParallelAnimationGroup(self)
        duration = max(150, min(360, 170 + int(moved_rows) * 35))
        for frame in frames:
            end_pos = frame.pos()
            start_pos = end_pos + QPoint(0, offset)
            frame.move(start_pos)
            animation = QPropertyAnimation(frame, b"pos", group)
            animation.setDuration(duration)
            animation.setStartValue(start_pos)
            animation.setEndValue(end_pos)
            animation.setEasingCurve(QEasingCurve.OutCubic)
            group.addAnimation(animation)
        self._scan_inventory_scroll_animation = group
        group.finished.connect(lambda: setattr(self, "_scan_inventory_scroll_animation", None))
        group.start()

    def _build_scan_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("scanHeader")
        header.setProperty("connected", False)
        self._scan_header = header
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(6, self._ui_scale))
        title = QLabel("스캔")
        title.setObjectName("title")
        header_layout.addWidget(title)
        self._scan_profile_label = QLabel()
        self._scan_profile_label.setObjectName("scanProfile")
        header_layout.addWidget(self._scan_profile_label)
        self._scan_target_label = QLabel()
        self._scan_target_label.setObjectName("count")
        self._scan_target_label.setWordWrap(True)
        header_layout.addWidget(self._scan_target_label)

        scan_actions = QHBoxLayout()
        scan_actions.setSpacing(scale_px(6, self._ui_scale))
        for label, mode in (
            ("학생", "students"),
            ("현재 학생", "student_current"),
            ("자원", "resources"),
            ("아이템", "items"),
            ("장비", "equipment"),
        ):
            button = QPushButton(label)
            button.clicked.connect(lambda _checked=False, scan_mode=mode: self._launch_scanner(scan_mode))
            scan_actions.addWidget(button)
        scan_actions.addStretch(1)

        self._scan_aspect_warning_label = QLabel("")
        self._scan_aspect_warning_label.setObjectName("count")
        self._scan_aspect_warning_label.setWordWrap(True)
        self._scan_aspect_warning_label.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Fixed)
        scan_actions.addWidget(self._scan_aspect_warning_label, 1, Qt.AlignVCenter)
        header_layout.addLayout(scan_actions)
        layout.addWidget(header)

        body = QGridLayout()
        body.setSpacing(scale_px(12, self._ui_scale))
        layout.addLayout(body, 1)

        summary_panel = QFrame()
        summary_panel.setObjectName("panel")
        summary_layout = QVBoxLayout(summary_panel)
        summary_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        summary_layout.setSpacing(scale_px(10, self._ui_scale))

        self._scan_plana_message_label = QLabel("접속 확인. 선생님, 기다리고 있었습니다.")
        self._scan_plana_message_label.setObjectName("title")
        self._scan_plana_message_label.setWordWrap(True)
        self._scan_plana_message_label.setMinimumHeight(scale_px(78, self._ui_scale))
        self._scan_plana_message_label.setAlignment(Qt.AlignTop | Qt.AlignLeft)
        summary_layout.addWidget(self._scan_plana_message_label)

        self._scan_plana_meta_label = QLabel("학생부 정리 대기 중")
        self._scan_plana_meta_label.setObjectName("count")
        self._scan_plana_meta_label.setWordWrap(True)
        summary_layout.addWidget(self._scan_plana_meta_label)

        self._scan_plana_log = QPlainTextEdit()
        self._scan_plana_log.setReadOnly(True)
        self._scan_plana_log.setPlaceholderText("학생 스캔을 실행하면 프라나의 업무 보고가 표시됩니다.")
        self._scan_plana_log.setMinimumHeight(scale_px(150, self._ui_scale))
        summary_layout.addWidget(self._scan_plana_log, 1)
        body.addWidget(summary_panel, 0, 0)

        right_column = QWidget()
        right_column.setObjectName("planTransparent")
        right_column.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        right_column_layout = QVBoxLayout(right_column)
        right_column_layout.setContentsMargins(0, 0, 0, 0)
        right_column_layout.setSpacing(scale_px(12, self._ui_scale))
        body.addWidget(right_column, 0, 1, 2, 1)
        panel = QFrame()
        panel.setObjectName("panel")
        panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        panel_layout = QVBoxLayout(panel)
        panel_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        panel_layout.setSpacing(scale_px(8, self._ui_scale))

        controls_row = QHBoxLayout()
        controls_row.setContentsMargins(0, 0, 0, 0)
        controls_row.setSpacing(scale_px(8, self._ui_scale))

        progress_panel = QFrame()
        progress_panel.setObjectName("inventoryPressureRow")
        progress_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        progress_layout = QHBoxLayout(progress_panel)
        progress_layout.setContentsMargins(
            scale_px(8, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(4, self._ui_scale),
        )
        progress_layout.setSpacing(scale_px(6, self._ui_scale))

        self._scan_progress_bar = QProgressBar()
        self._scan_progress_bar.setRange(0, 100)
        self._scan_progress_bar.setValue(0)
        self._scan_progress_bar.setTextVisible(False)
        self._scan_progress_bar.setMinimumWidth(scale_px(120, self._ui_scale))
        self._scan_progress_bar.setMaximumWidth(scale_px(320, self._ui_scale))
        self._scan_progress_bar.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        progress_layout.addWidget(self._scan_progress_bar, 1)

        self._scan_progress_label = None
        self._scan_eta_label = None
        self._scan_status_label = self._scan_plana_meta_label
        controls_row.addWidget(progress_panel, 1)

        self._scan_stop_button = QPushButton("스캔 중지")
        self._scan_stop_button.setEnabled(False)
        self._scan_stop_button.clicked.connect(self._request_scanner_stop)
        controls_row.addWidget(self._scan_stop_button, 0, Qt.AlignVCenter)
        panel_layout.addLayout(controls_row)
        right_column_layout.addWidget(panel, 0)


        self._scan_plana_image_label = None
        self._scan_detail_stack = QStackedWidget()
        self._scan_detail_stack.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self._scan_detail_stack.addWidget(self._build_scan_student_card())
        self._scan_detail_stack.addWidget(self._build_scan_inventory_grid_card())
        body.addWidget(self._scan_detail_stack, 1, 0)

        preview_min_width = scale_px(560, self._ui_scale)
        preview_panel = AspectRatioFrame(aspect_width=16, aspect_height=9, min_width=preview_min_width)
        preview_panel.setObjectName("scanPreviewPanel")
        preview_panel.setMinimumSize(preview_min_width, preview_panel.heightForWidth(preview_min_width))
        preview_layout = QVBoxLayout(preview_panel)
        preview_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        preview_layout.addStretch(1)
        right_column_layout.addWidget(preview_panel, 1)

        body.setColumnStretch(0, 1)
        body.setColumnStretch(1, 2)
        body.setRowStretch(0, 0)
        body.setRowStretch(1, 1)
        self._set_plana_expression("neutral")
        self._reset_scan_student_card()
        self._sync_settings_labels()

    def _build_settings_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        title = QLabel("설정")
        title.setObjectName("title")
        header_layout.addWidget(title)
        self._settings_active_profile_label = QLabel()
        self._settings_active_profile_label.setObjectName("count")
        header_layout.addWidget(self._settings_active_profile_label)
        self._settings_target_label = QLabel()
        self._settings_target_label.setObjectName("count")
        self._settings_target_label.setWordWrap(True)
        header_layout.addWidget(self._settings_target_label)
        layout.addWidget(header)

        profile_panel = QFrame()
        profile_panel.setObjectName("panel")
        profile_layout = QVBoxLayout(profile_panel)
        profile_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        profile_layout.setSpacing(scale_px(10, self._ui_scale))
        profile_title = QLabel("계정 관리")
        profile_title.setObjectName("sectionTitle")
        profile_layout.addWidget(profile_title)
        self._settings_profile_combo = QComboBox()
        profile_layout.addWidget(self._settings_profile_combo)
        profile_buttons = QHBoxLayout()
        apply_profile = QPushButton("프로필 적용")
        apply_profile.clicked.connect(self._apply_selected_profile)
        profile_buttons.addWidget(apply_profile)
        new_profile = QPushButton("새 프로필")
        new_profile.clicked.connect(self._create_profile)
        profile_buttons.addWidget(new_profile)
        refresh_profile = QPushButton("새로고침")
        refresh_profile.clicked.connect(self._refresh_settings_profiles)
        profile_buttons.addWidget(refresh_profile)
        profile_buttons.addStretch(1)
        profile_layout.addLayout(profile_buttons)

        delete_data_button = QPushButton("현재 프로필 데이터 삭제")
        delete_data_button.clicked.connect(self._confirm_delete_current_profile_data)
        profile_layout.addWidget(delete_data_button)
        layout.addWidget(profile_panel)

        window_panel = QFrame()
        window_panel.setObjectName("panel")
        window_layout = QVBoxLayout(window_panel)
        window_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        window_layout.setSpacing(scale_px(10, self._ui_scale))
        window_title = QLabel("블루아카이브 창 인식")
        window_title.setObjectName("sectionTitle")
        window_layout.addWidget(window_title)
        window_buttons = QHBoxLayout()
        refresh_windows = QPushButton("창 목록 열기")
        refresh_windows.clicked.connect(self._open_window_picker_dialog)
        window_buttons.addWidget(refresh_windows)
        window_buttons.addStretch(1)
        window_layout.addLayout(window_buttons)
        layout.addWidget(window_panel)
        layout.addStretch(1)

        self._refresh_settings_profiles()
        self._sync_settings_labels()

    def _saved_target(self) -> tuple[int, str]:
        config = load_config()
        try:
            hwnd = int(config.get("target_hwnd") or 0)
        except (TypeError, ValueError):
            hwnd = 0
        return hwnd, str(config.get("target_title") or "")

    def _load_saved_target_into_capture(self) -> bool:
        hwnd, title = self._saved_target()
        if not hwnd:
            return False
        set_target_window(hwnd, title)
        return True

    def _sync_settings_labels(self) -> None:
        profile = get_active_profile_name("Default") or "Default"
        hwnd, title = self._saved_target()
        settings_target = f"{title} (HWND={hwnd})" if hwnd else "선택된 창 없음"
        scan_target = title if hwnd else "선택된 창 없음"
        target_connected = False
        if hwnd:
            try:
                target_connected = any(int(window.get("hwnd") or 0) == hwnd for window in get_all_windows())
            except Exception:
                target_connected = True
        aspect_warning = self._target_aspect_warning(hwnd)
        if self._settings_active_profile_label is not None:
            self._settings_active_profile_label.setText(f"현재 프로필: {profile}")
        if self._settings_target_label is not None:
            self._settings_target_label.setText(f"선택된 BA 창: {settings_target}")
        if self._scan_profile_label is not None:
            self._scan_profile_label.setText(f"현재 프로필: {profile}")
        if self._scan_target_label is not None:
            self._scan_target_label.setText(f"선택된 BA 창: {scan_target}")
        if self._scan_header is not None:
            if self._scan_header.property("connected") != target_connected:
                self._scan_header.setProperty("connected", target_connected)
                self._scan_header.style().unpolish(self._scan_header)
                self._scan_header.style().polish(self._scan_header)
                self._scan_header.update()
        if self._scan_aspect_warning_label is not None:
            self._scan_aspect_warning_label.setText(aspect_warning)

    def _target_aspect_warning(self, hwnd: int) -> str:
        if not hwnd:
            return ""
        size = ""
        try:
            for window in get_all_windows():
                if int(window.get("hwnd") or 0) == hwnd:
                    size = str(window.get("size") or "")
                    break
        except Exception:
            return ""
        match = re.search(r"(\d+)\s*[×x]\s*(\d+)", size)
        if not match:
            return ""
        width = int(match.group(1))
        height = int(match.group(2))
        if width <= 0 or height <= 0:
            return ""
        ratio = width / height
        target_ratio = 16 / 9
        if abs(ratio - target_ratio) <= 0.02:
            return f"BA 창 비율 확인: {width}x{height} (16:9)"
        return (
            f"BA 창 비율 확인 필요: 현재 {width}x{height}입니다. "
            "학생 스캔 전 블루 아카이브를 16:9 창모드로 맞춰 주십시오."
        )

    def _refresh_settings_profiles(self) -> None:
        if self._settings_profile_combo is None:
            return
        active = get_active_profile_name("Default") or "Default"
        profiles = list_profiles()
        if active not in profiles:
            profiles.insert(0, active)
        self._settings_profile_combo.clear()
        self._settings_profile_combo.addItems(profiles)
        index = self._settings_profile_combo.findText(active)
        if index >= 0:
            self._settings_profile_combo.setCurrentIndex(index)
        self._sync_settings_labels()

    def _open_window_picker_dialog(self) -> None:
        dialog = QDialog(self)
        dialog.setWindowTitle("Blue Archive 창 선택")
        dialog.setModal(True)
        dialog.resize(scale_px(680, self._ui_scale), scale_px(520, self._ui_scale))

        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        layout.setSpacing(scale_px(10, self._ui_scale))

        current_label = QLabel()
        current_label.setObjectName("count")
        current_label.setWordWrap(True)
        layout.addWidget(current_label)

        list_widget = QListWidget()
        list_widget.setSelectionMode(QAbstractItemView.SingleSelection)
        layout.addWidget(list_widget, 1)

        button_row = QHBoxLayout()
        refresh_button = QPushButton("새로고침")
        button_row.addWidget(refresh_button)
        button_row.addStretch(1)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        ok_button = buttons.button(QDialogButtonBox.StandardButton.Ok)
        cancel_button = buttons.button(QDialogButtonBox.StandardButton.Cancel)
        ok_button.setText("선택한 창 사용")
        cancel_button.setText("취소")
        ok_button.setEnabled(False)
        button_row.addWidget(buttons)
        layout.addLayout(button_row)

        def refresh() -> None:
            list_widget.clear()
            saved_hwnd, saved_title = self._saved_target()
            current_label.setText(f"현재 선택: {saved_title} (HWND={saved_hwnd})" if saved_hwnd else "현재 선택: 없음")
            selected_row = -1
            for index, window in enumerate(get_all_windows()):
                title = str(window.get("title") or "")
                hwnd = int(window.get("hwnd") or 0)
                size = str(window.get("size") or "")
                item = QListWidgetItem(f"{title}    {size}    HWND={hwnd}")
                item.setData(Qt.UserRole, window)
                if "blue archive" in title.casefold() or "bluearchive" in title.casefold():
                    item.setForeground(QColor("#3dbf7a"))
                list_widget.addItem(item)
                if hwnd == saved_hwnd:
                    selected_row = index
            if selected_row >= 0:
                list_widget.setCurrentRow(selected_row)
            ok_button.setEnabled(list_widget.currentItem() is not None)

        def apply_selected() -> None:
            item = list_widget.currentItem()
            if item is None:
                return
            window = item.data(Qt.UserRole)
            if not isinstance(window, dict):
                return
            hwnd = int(window.get("hwnd") or 0)
            title = str(window.get("title") or "")
            if not hwnd:
                return
            config = load_config()
            config["target_hwnd"] = hwnd
            config["target_title"] = title
            save_config(config)
            set_target_window(hwnd, title)
            self._sync_settings_labels()
            if self._scan_status_label is not None:
                self._scan_status_label.setText(f"BA 창 설정 완료: {title}")
            dialog.accept()

        list_widget.itemSelectionChanged.connect(lambda: ok_button.setEnabled(list_widget.currentItem() is not None))
        list_widget.itemDoubleClicked.connect(lambda _item: apply_selected())
        refresh_button.clicked.connect(refresh)
        buttons.accepted.connect(apply_selected)
        buttons.rejected.connect(dialog.reject)

        refresh()
        dialog.exec()

    def _apply_selected_profile(self) -> None:
        if self._settings_profile_combo is None:
            return
        name = self._settings_profile_combo.currentText().strip()
        if not name:
            return
        self._activate_profile_and_reload(name)

    def _create_profile(self) -> None:
        name, ok = QInputDialog.getText(self, "새 프로필", "프로필 이름")
        if not ok:
            return
        name = name.strip()
        if not name:
            return
        self._activate_profile_and_reload(name)
        self._refresh_settings_profiles()

    def _confirm_delete_current_profile_data(self) -> None:
        if self._scanner_process is not None and self._scanner_process.poll() is None:
            QMessageBox.information(self, "BA Planner", "스캔 중에는 데이터를 삭제할 수 없습니다.")
            return

        paths = get_storage_paths()
        message = (
            f"현재 프로필 '{paths.profile_name}'의 저장 데이터를 삭제합니다.\n\n"
            "삭제 대상:\n"
            "- 스캔 결과\n"
            "- 학생/인벤토리 현재 데이터\n"
            "- 변경 이력\n"
            "- 계획, 총력전/전술대항전 기록 등 프로필 데이터\n"
            "- 프로필 DB\n\n"
            "프로필 자체와 앱 설정, 선택된 BA 창 정보는 유지됩니다.\n"
            "이 작업은 되돌릴 수 없습니다. 계속하시겠습니까?"
        )
        answer = QMessageBox.warning(
            self,
            "모든 데이터 삭제",
            message,
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No,
        )
        if answer != QMessageBox.Yes:
            return

        try:
            self._delete_current_profile_data(paths)
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"데이터 삭제에 실패했습니다.\n\n{exc}")
            return

        QMessageBox.information(self, "BA Planner", "현재 프로필의 저장 데이터를 삭제했습니다.")

    def _delete_current_profile_data(self, paths) -> None:
        root = paths.root.resolve()
        targets = [
            paths.current_dir,
            paths.history_dir,
            paths.scans_dir,
            paths.db_path,
        ]
        for target in targets:
            resolved = target.resolve()
            if not resolved.is_relative_to(root):
                raise RuntimeError(f"프로필 범위를 벗어난 경로입니다: {target}")
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists():
                target.unlink()

        storage_paths = ensure_profile_storage(paths.profile_name)
        init_db(storage_paths.db_path)
        self._plan_path = storage_paths.current_dir / "growth_plan.json"
        self._tactical_path = storage_paths.current_dir / "tactical_challenge.db"
        self._raid_guide_path = storage_paths.current_raid_guides_json
        self._storage_watch_paths = (
            storage_paths.current_students_json,
            storage_paths.current_inventory_json,
            self._plan_path,
            self._tactical_path,
            self._raid_guide_path,
            storage_paths.db_path,
        )
        self._scan_status_file_offset = 0
        self._scan_status_recent_messages = []
        if self._scan_plana_log is not None:
            self._scan_plana_log.clear()
        if self._scan_status_label is not None:
            self._scan_status_label.setText("데이터 삭제 완료")
        self._reload_data()
        self._sync_settings_labels()

    def _activate_profile_and_reload(self, name: str) -> None:
        try:
            storage_paths = activate_profile(name)
            init_db(storage_paths.db_path)
            self._plan_path = storage_paths.current_dir / "growth_plan.json"
            self._tactical_path = storage_paths.current_dir / "tactical_challenge.db"
            self._raid_guide_path = storage_paths.current_raid_guides_json
            self._storage_watch_paths = (
                storage_paths.current_students_json,
                storage_paths.current_inventory_json,
                self._plan_path,
                self._tactical_path,
                self._raid_guide_path,
                storage_paths.db_path,
            )
            self._reload_data()
            self._sync_settings_labels()
            if self._scan_status_label is not None:
                self._scan_status_label.setText(f"프로필 전환 완료: {name}")
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"프로필 전환에 실패했습니다.\n\n{exc}")

    def _open_settings_tab(self) -> None:
        if self._main_tabs is not None and self._settings_tab is not None:
            self._main_tabs.setCurrentWidget(self._settings_tab)

    def _scan_status_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_status.jsonl"

    def _scan_stop_request_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_stop_requested.flag"

    def _scan_status_ack_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_status_ack.json"

    def _clear_scan_stop_request(self) -> None:
        try:
            self._scan_stop_request_path().unlink(missing_ok=True)
        except Exception:
            pass

    def _request_scanner_stop(self) -> None:
        process = self._scanner_process
        if process is None or process.poll() is not None:
            return
        try:
            path = self._scan_stop_request_path()
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(datetime.now().isoformat(), encoding="utf-8")
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"스캔 중지 요청을 전달하지 못했습니다.\n\n{exc}")
            return
        if self._scan_status_label is not None:
            self._scan_status_label.setText(f"{self._scanner_mode_label(self._scanner_mode)} 중지 요청")
        if self._scan_stop_button is not None:
            self._scan_stop_button.setEnabled(False)
            self._scan_stop_button.setText("중지 요청됨")

    def _reset_scan_progress_view(self, mode_label: str) -> None:
        self._scan_started_at = datetime.now()
        self._scan_last_progress = (0, None)
        if self._scan_progress_bar is not None:
            self._scan_progress_bar.setRange(0, 100)
            self._scan_progress_bar.setValue(0)
        if self._scan_progress_label is not None:
            self._scan_progress_label.setText("0%")
        if self._scan_eta_label is not None:
            self._scan_eta_label.setText(f"예상 완료: {mode_label} 진행률 수집 중")

    def _finish_scan_progress_view(self, code: int) -> None:
        if self._scan_progress_bar is not None:
            self._scan_progress_bar.setRange(0, 100)
            if code == 0:
                self._scan_progress_bar.setValue(100)
        if self._scan_progress_label is not None and code == 0:
            self._scan_progress_label.setText("100%")
        if self._scan_eta_label is not None:
            self._scan_eta_label.setText("예상 완료: 완료" if code == 0 else "예상 완료: 중단됨")
        if self._scan_stop_button is not None:
            self._scan_stop_button.setEnabled(False)
            self._scan_stop_button.setText("스캔 중지")

    def _update_scan_progress_from_event(self, event: dict) -> None:
        fields = event.get("fields") if isinstance(event.get("fields"), dict) else {}
        current = self._coerce_progress_int(fields.get("current"))
        total = self._coerce_progress_int(fields.get("total"))
        note = str(fields.get("note") or "").strip()
        if current is None:
            current = 0
        if total is not None and total <= 0:
            total = None
        self._scan_last_progress = (current, total)

        percent: float | None = None
        if total:
            percent = max(0.0, min(100.0, (current / total) * 100.0))

        if self._scan_progress_bar is not None:
            self._scan_progress_bar.setRange(0, 100)
            self._scan_progress_bar.setValue(int(round(percent or 0.0)))
        if self._scan_progress_label is not None:
            if total:
                self._scan_progress_label.setText(f"{percent:.1f}% ({current}/{total})")
            else:
                self._scan_progress_label.setText(f"{current}건 처리")

        eta_text = "예상 완료: 계산 중"
        if total and current > 0 and self._scan_started_at is not None:
            elapsed = max(0.0, (datetime.now() - self._scan_started_at).total_seconds())
            remaining = elapsed * max(0, total - current) / max(1, current)
            eta = datetime.now() + timedelta(seconds=remaining)
            eta_text = f"예상 완료: {eta.strftime('%H:%M:%S')}"
            if note:
                eta_text += f" · {note}"
        elif note:
            eta_text = f"예상 완료: 계산 중 · {note}"
        if self._scan_eta_label is not None:
            self._scan_eta_label.setText(eta_text)

    @staticmethod
    def _coerce_progress_int(value: object) -> int | None:
        try:
            if value is None or value == "":
                return None
            return int(value)
        except (TypeError, ValueError):
            return None

    def _resolve_scan_student_id(self, student_id: object = None, student_name: object = None) -> str:
        sid = str(student_id or "").strip()
        if sid:
            return sid
        name = str(student_name or "").strip()
        if not name:
            return ""
        try:
            for candidate in student_meta.all_ids():
                if student_meta.display_name(candidate) == name:
                    return candidate
        except Exception:
            return ""
        return ""

    def _scan_portrait_source(self, student_id: str, form_index: object = 1) -> Path | None:
        sid = str(student_id or "").strip()
        if not sid:
            return None
        try:
            form = int(form_index or 1)
        except (TypeError, ValueError):
            form = 1
        if form > 1:
            suffix = form - 1
            for ext in (".png", ".jpg", ".jpeg", ".webp"):
                path = PORTRAIT_DIR / f"{sid}_{suffix}{ext}"
                if path.exists():
                    return path
        return portrait_path(sid)

    def _set_scan_student_portrait(self, student_id: str, form_index: object = 1) -> None:
        if self._scan_student_hero is None:
            return
        sid = str(student_id or "").strip()
        if not sid:
            self._scan_student_hero.clear()
            return
        source = self._scan_portrait_source(sid, form_index)
        if source is None or not source.exists():
            self._scan_student_hero.clear()
            return
        portrait = QPixmap(str(source))
        if portrait.isNull():
            self._scan_student_hero.clear()
            return
        record = self._records_by_id.get(sid)
        self._scan_student_hero.setPixmap(portrait, owned=record.owned if record is not None else True)

    def _reset_scan_live_state(self, student_id: str) -> None:
        sid = str(student_id or "").strip()
        record = self._records_by_id.get(sid)
        position = student_meta.field(sid, "position") if sid else None
        combat_class = student_meta.field(sid, "combat_class") if sid else None
        if record is not None:
            position = record.position or position
            combat_class = record.combat_class or combat_class
        self._scan_student_live_state = {
            "student_id": sid,
            "form_index": 1,
            "position": _position_label(position),
            "combat_class": (str(combat_class or "-").title() if combat_class else "-"),
            "level": None,
            "student_star": None,
            "weapon_star": None,
            "weapon_level": None,
            "weapon_status": None,
            "ex_skill": None,
            "skill1": None,
            "skill2": None,
            "skill3": None,
            "equip1": None,
            "equip2": None,
            "equip3": None,
            "equip4": None,
            "equip1_level": None,
            "equip2_level": None,
            "equip3_level": None,
            "combat_hp": None,
            "combat_atk": None,
            "combat_def": None,
            "combat_heal": None,
            "stat_hp": None,
            "stat_atk": None,
            "stat_heal": None,
        }

    def _scan_int_value(self, value: object) -> int | None:
        if value is None:
            return None
        if isinstance(value, bool):
            return int(value)
        if isinstance(value, int):
            return value
        text = str(value).strip().replace(",", "")
        if not text or text == "-":
            return None
        match = re.search(r"-?\d+", text)
        if not match:
            return None
        try:
            return int(match.group(0))
        except ValueError:
            return None

    def _scan_text_value(self, value: object) -> str | None:
        text = str(value or "").strip()
        return text or None

    def _scan_tier_value(self, value: object) -> str | None:
        text = str(value or "").strip().upper()
        if not text or text == "-":
            return None
        match = re.search(r"T\s*(\d+)", text)
        if match:
            return f"T{match.group(1)}"
        if text in {"EMPTY", "LEVEL_LOCKED", "LOVE_LOCKED", "NULL", "UNSUPPORTED", "UNKNOWN", "NO_SYSTEM"}:
            return text.lower()
        return text

    def _render_scan_live_card(self) -> None:
        state = getattr(self, "_scan_student_live_state", {}) or {}
        sid = str(state.get("student_id") or self._scan_current_student_id or "").strip()
        if self._scan_student_progress_strip is not None:
            star = self._scan_int_value(state.get("student_star")) or 0
            weapon_star = self._scan_int_value(state.get("weapon_star")) or 0
            show_weapon = bool(weapon_star or state.get("weapon_level") is not None or state.get("weapon_status"))
            self._scan_student_progress_strip.setProgress(star, weapon_star, show_weapon)

        level_label = self._scan_student_value_labels.get("level")
        if level_label is not None:
            level = self._scan_int_value(state.get("level"))
            level_label.setText(str(level) if level is not None else "-")
        if self._scan_student_position_label is not None:
            self._scan_student_position_label.setText(str(state.get("position") or "-"))
        if self._scan_student_class_label is not None:
            self._scan_student_class_label.setText(str(state.get("combat_class") or "-"))
        if self._scan_student_weapon_level_label is not None:
            weapon_level = self._scan_int_value(state.get("weapon_level"))
            if weapon_level is not None:
                self._scan_student_weapon_level_label.setText(f"Lv.{weapon_level}")
            else:
                self._scan_student_weapon_level_label.setText(str(state.get("weapon_status") or "-"))

        skill_pairs = {
            "skill_ex": "ex_skill",
            "skill_s1": "skill1",
            "skill_s2": "skill2",
            "skill_s3": "skill3",
        }
        for label_key, state_key in skill_pairs.items():
            label = self._scan_student_value_labels.get(label_key)
            if label is not None:
                label.setText(str(state.get(state_key) or "-"))

        bonus_label = self._scan_student_value_labels.get("stats")
        bonus_values = (state.get("stat_hp"), state.get("stat_atk"), state.get("stat_heal"))
        if bonus_label is not None:
            if any(self._scan_int_value(value) is not None for value in bonus_values):
                bonus_label.setText(_detail_bonus_stats_html((
                    ("HP", self._scan_int_value(state.get("stat_hp"))),
                    ("ATK", self._scan_int_value(state.get("stat_atk"))),
                    ("HEAL", self._scan_int_value(state.get("stat_heal"))),
                ), font_px=scale_px(13, self._ui_scale)))
            else:
                bonus_label.setText("-")

        combat_values = (state.get("combat_hp"), state.get("combat_atk"), state.get("combat_def"), state.get("combat_heal"))
        if self._scan_student_combat_stats_label is not None:
            if any(self._scan_int_value(value) is not None for value in combat_values):
                self._scan_student_combat_stats_label.setText(_scan_live_vertical_stats_html((
                    ("HP", self._scan_int_value(state.get("combat_hp"))),
                    ("ATK", self._scan_int_value(state.get("combat_atk"))),
                    ("DEF", self._scan_int_value(state.get("combat_def"))),
                    ("HEAL", self._scan_int_value(state.get("combat_heal"))),
                ), font_px=scale_px(14, self._ui_scale)))
            else:
                self._scan_student_combat_stats_label.setText("-")

        for index, slot in enumerate(("equip1", "equip2", "equip3"), start=1):
            card = self._scan_student_equip_cards.get(slot)
            if card is None:
                continue
            tier = self._scan_text_value(state.get(slot))
            level = self._scan_int_value(state.get(f"{slot}_level"))
            icon_path = _equipment_icon_path(sid, index, tier) if sid else None
            icon_pixmap = QPixmap()
            value_text = _slot_placeholder(tier)
            if icon_path is not None:
                loaded = QPixmap(str(icon_path))
                if not loaded.isNull():
                    icon_pixmap = loaded
                    value_text = ""
            elif _parse_tier_number(tier) is not None:
                value_text = str(tier)
            card.setData(icon=icon_pixmap, value=value_text, level=str(level) if level is not None else "")

        favorite_card = self._scan_student_equip_cards.get("favorite")
        if favorite_card is not None:
            favorite_supported = student_meta.favorite_item_enabled(sid) if sid else True
            tier = self._scan_text_value(state.get("equip4"))
            tier_num = _parse_tier_number(tier)
            value_text = _slot_placeholder(tier, supported=favorite_supported)
            if tier_num is not None:
                value_text = f"T{tier_num}"
            favorite_card.setData(icon=QPixmap(), value=value_text, level="")

    def _reset_scan_student_card(self, student_id: object = None, student_name: object = None, meta: str = "") -> None:
        self._set_scan_detail_mode("student")
        name = str(student_name or "").strip()
        sid = self._resolve_scan_student_id(student_id, name)
        if sid and not name:
            try:
                name = student_meta.display_name(sid)
            except Exception:
                name = sid
        self._scan_current_student_id = sid
        self._scan_current_student_name = name
        self._reset_scan_live_state(sid)
        if self._scan_student_name_label is not None:
            self._scan_student_name_label.setText(name or "")
        if self._scan_student_meta_label is not None:
            self._scan_student_meta_label.setText(meta or "")
        for label in self._scan_student_value_labels.values():
            label.setText("-")
        if self._scan_student_progress_strip is not None:
            self._scan_student_progress_strip.setProgress(0, 0, False)
        for card in self._scan_student_equip_cards.values():
            card.clearData()
        self._set_scan_student_portrait(sid, 1)
        self._render_scan_live_card()

    def _set_scan_student_value(self, key: str, value: object) -> None:
        state = getattr(self, "_scan_student_live_state", None)
        if state is None:
            self._scan_student_live_state = {}
            state = self._scan_student_live_state
        text = str(value or "").strip()
        if key == "level":
            state["level"] = self._scan_int_value(value) if self._scan_int_value(value) is not None else text or None
        elif key == "star":
            state["student_star"] = self._scan_int_value(value)
        elif key == "weapon":
            level = self._scan_int_value(re.search(r"Lv\.\s*(\d+)", text).group(1) if re.search(r"Lv\.\s*(\d+)", text) else None)
            star_match = re.search(r"(\d+)\s*성", text)
            if star_match:
                state["weapon_star"] = self._scan_int_value(star_match.group(1))
            if level is not None:
                state["weapon_level"] = level
            elif text and not star_match:
                state["weapon_status"] = text
        elif key in {"skill_ex", "skill_s1", "skill_s2", "skill_s3"}:
            state[{"skill_ex": "ex_skill", "skill_s1": "skill1", "skill_s2": "skill2", "skill_s3": "skill3"}[key]] = self._scan_int_value(value) if self._scan_int_value(value) is not None else text or None
        elif key in {"equip1", "equip2", "equip3"}:
            tier = self._scan_tier_value(value)
            if tier is not None:
                state[key] = tier
            level_match = re.search(r"Lv\.\s*(\d+)", text)
            if level_match:
                state[f"{key}_level"] = self._scan_int_value(level_match.group(1))
        elif key == "favorite":
            state["equip4"] = self._scan_tier_value(value) or text or None
        elif key == "stats":
            match = re.search(r"HP\s+([^/]+)\s*/\s*ATK\s+([^/]+)\s*/\s*HEAL\s+(.+)$", text)
            if match:
                state["stat_hp"] = self._scan_int_value(match.group(1))
                state["stat_atk"] = self._scan_int_value(match.group(2))
                state["stat_heal"] = self._scan_int_value(match.group(3))
        elif key == "combat_stats":
            match = re.search(r"HP\s+([^/]+)\s*/\s*ATK\s+([^/]+)\s*/\s*DEF\s+([^/]+)\s*/\s*HEAL\s+(.+)$", text)
            if match:
                state["combat_hp"] = self._scan_int_value(match.group(1))
                state["combat_atk"] = self._scan_int_value(match.group(2))
                state["combat_def"] = self._scan_int_value(match.group(3))
                state["combat_heal"] = self._scan_int_value(match.group(4))
        label = self._scan_student_value_labels.get(key)
        if label is not None:
            label.setText(text or "-")
        self._render_scan_live_card()

    def _merge_scan_equipment_value(self, key: str, *, tier: object = None, level: object = None) -> None:
        state = self._scan_student_live_state
        if tier is not None and str(tier).strip():
            state[key] = self._scan_tier_value(tier)
        if level is not None and str(level).strip():
            state[f"{key}_level"] = self._scan_int_value(level)
        self._render_scan_live_card()

    def _merge_scan_weapon_value(self, *, star: object = None, level: object = None) -> None:
        state = self._scan_student_live_state
        if star is not None and str(star).strip():
            state["weapon_star"] = self._scan_int_value(star)
            state["weapon_status"] = None
        if level is not None and str(level).strip():
            state["weapon_level"] = self._scan_int_value(level)
            state["weapon_status"] = None
        self._render_scan_live_card()

    def _merge_scan_stat_value(self, field_name: str, value: object) -> None:
        self._scan_student_live_state[field_name] = self._scan_int_value(value)
        self._render_scan_live_card()

    def _merge_scan_combat_stat_value(self, field_name: str, value: object) -> None:
        self._scan_student_live_state[field_name] = self._scan_int_value(value)
        self._render_scan_live_card()

    def _apply_scan_field_confirmed_event(self, fields: dict) -> None:
        field_name = str(fields.get("field") or "").strip()
        value = fields.get("value")
        if not field_name:
            return
        direct_map = {
            "level": "level",
            "student_star": "star",
            "ex_skill": "skill_ex",
            "skill1": "skill_s1",
            "skill2": "skill_s2",
            "skill3": "skill_s3",
            "equip4": "favorite",
        }
        label_key = direct_map.get(field_name)
        if label_key:
            self._set_scan_student_value(label_key, value)
            return
        if field_name == "weapon_star":
            self._merge_scan_weapon_value(star=value)
        elif field_name == "weapon_level":
            self._merge_scan_weapon_value(level=value)
        elif field_name in {"equip1", "equip2", "equip3"}:
            self._merge_scan_equipment_value(field_name, tier=value)
        elif field_name in {"equip1_level", "equip2_level", "equip3_level"}:
            self._merge_scan_equipment_value(field_name.removesuffix("_level"), level=value)
        elif field_name in {"stat_hp", "stat_atk", "stat_heal"}:
            self._merge_scan_stat_value(field_name, value)
        elif field_name in {"combat_hp", "combat_atk", "combat_def", "combat_heal"}:
            self._merge_scan_combat_stat_value(field_name, value)
    def _reset_scan_inventory_card(self, source_label: object = None, meta: str = "", grid_cols: object = None, grid_rows: object = None) -> None:
        label = str(source_label or "").strip() or "인벤토리"
        self._set_scan_detail_mode("inventory")
        if grid_cols is not None or grid_rows is not None:
            self._configure_scan_inventory_grid(grid_cols, grid_rows)
        else:
            self._reset_scan_inventory_grid_cells()
        if self._scan_inventory_title_label is not None:
            self._scan_inventory_title_label.setText(f"{label} 그리드")
        if self._scan_inventory_meta_label is not None:
            self._scan_inventory_meta_label.setText(meta or "그리드 상태를 확인하고 있습니다.")
        self._scan_inventory_confirmed_count = 0
        self._scan_current_student_id = ""
        self._scan_current_student_name = ""
        if self._scan_student_name_label is not None:
            self._scan_student_name_label.setText(f"{label} 스캔 중")
        if self._scan_student_meta_label is not None:
            self._scan_student_meta_label.setText(meta or "그리드 상태를 확인하고 있습니다.")
        for value_label in self._scan_student_value_labels.values():
            value_label.setText("-")
        self._set_scan_student_value("level", "그리드")
        self._set_scan_student_value("star", "대기")
        self._set_scan_student_value("equip1", "확정 0")
        self._set_scan_student_value("equip2", "티어 대기")
        self._set_scan_student_value("equip3", "스크롤 대기")
        if self._scan_student_progress_strip is not None:
            self._scan_student_progress_strip.setProgress(0, 0, False)
        if self._scan_student_hero is not None:
            self._scan_student_hero.clear()

    def _update_scan_student_card_from_event(self, event: dict) -> None:
        event_id = str(event.get("id") or "")
        fields = event.get("fields") if isinstance(event.get("fields"), dict) else {}
        student_name = str(fields.get("student_name") or "").strip()
        student_id = self._resolve_scan_student_id(fields.get("student_id"), student_name)

        if event_id == "field.confirmed":
            self._apply_scan_field_confirmed_event(fields)
            return
        if event_id == "student.form.switch":
            form_index = fields.get("form_index") or 1
            sid = student_id or self._scan_current_student_id
            if sid:
                self._scan_student_live_state["form_index"] = self._scan_int_value(form_index) or 1
                self._set_scan_student_portrait(sid, form_index)
            return
        if event_id == "inventory.scan.start":
            source_label = fields.get("source_label") or fields.get("source") or "\uC778\uBCA4\uD1A0\uB9AC"
            grid_cols = fields.get("grid_cols")
            grid_rows = fields.get("grid_rows")
            total_slots = fields.get("total_slots")
            profile_id = str(fields.get("profile_id") or "").strip()
            grid_text = f"{grid_cols}x{grid_rows} \uADF8\uB9AC\uB4DC" if grid_cols and grid_rows else "\uADF8\uB9AC\uB4DC"
            meta_parts = [grid_text]
            if total_slots:
                meta_parts.append(f"{total_slots}\uCE78")
            if profile_id:
                meta_parts.append(profile_id)
            self._reset_scan_inventory_card(source_label, " / ".join(meta_parts), grid_cols, grid_rows)
            self._set_scan_student_value("star", f"{total_slots}\uCE78" if total_slots else "\uD655\uC778 \uC911")
            return
        if event_id == "inventory.slot.tier_hint":
            tier = fields.get("tier_hint")
            slot_number = fields.get("slot_number")
            if tier is not None:
                suffix = f" ({slot_number}\uBC88)" if slot_number else ""
                self._set_scan_student_value("equip2", f"T{tier} \uD78C\uD2B8{suffix}")
                self._set_scan_inventory_cell_tier(slot_number, tier)
            return
        if event_id == "inventory.row_anchor.confirmed":
            slot_number = fields.get("slot_number")
            row_number = fields.get("row_number")
            self._mark_scan_inventory_cell_anchor(slot_number)
            label = f"{row_number}\uD589 \uC575\uCEE4" if row_number else "\uD589 \uC575\uCEE4"
            if slot_number:
                label = f"{label} {slot_number}\uBC88"
            self._set_scan_student_value("equip2", label)
            if self._scan_inventory_meta_label is not None:
                self._scan_inventory_meta_label.setText(f"{label} \uD655\uC815")
            return
        if event_id == "inventory.slot.confirmed":
            self._scan_inventory_confirmed_count = max(0, self._scan_inventory_confirmed_count) + 1
            item_name = str(fields.get("item_name") or "").strip()
            quantity = str(fields.get("quantity") or "").strip()
            slot_number = fields.get("slot_number")
            row_anchor = bool(fields.get("row_anchor"))
            self._set_scan_student_value("equip1", f"\uD655\uC815 {self._scan_inventory_confirmed_count}")
            if item_name:
                detail = f"{item_name} x{quantity}" if quantity else item_name
                self._set_scan_student_value("favorite", detail)
            item_id = fields.get("item_id")
            self._set_scan_inventory_cell_confirmed(
                slot_number,
                item_name,
                quantity,
                str(item_id) if item_id else None,
                row_anchor=row_anchor,
            )
            if self._scan_inventory_meta_label is not None:
                suffix = " / \uC575\uCEE4" if row_anchor else ""
                self._scan_inventory_meta_label.setText(f"\uD655\uC815 {self._scan_inventory_confirmed_count}\uAC1C{suffix}")
            if self._scan_student_meta_label is not None:
                slot_text = f"{slot_number}\uBC88 \uC2AC\uB86F" if slot_number else "\uC2AC\uB86F"
                self._scan_student_meta_label.setText(f"{slot_text} \uD655\uC815 \uC911")
            return
        if event_id == "inventory.scroll":
            overlap_rows = fields.get("overlap_rows")
            moved_rows = fields.get("moved_rows")
            self._apply_scan_inventory_scroll_feedback(
                moved_rows=moved_rows,
                overlap_rows=overlap_rows,
                scan_slots=fields.get("scan_slots"),
            )
            if moved_rows is not None:
                self._set_scan_student_value("equip3", f"{moved_rows}\uD589 \uC774\uB3D9")
            elif overlap_rows is not None:
                self._set_scan_student_value("equip3", f"\uC911\uBCF5 {overlap_rows}\uD589")
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("\uB2E4\uC74C \uADF8\uB9AC\uB4DC \uD398\uC774\uC9C0\uB85C \uC774\uB3D9 \uC911")
            if self._scan_inventory_meta_label is not None:
                self._scan_inventory_meta_label.setText("\uADF8\uB9AC\uB4DC\uB97C \uC704\uB85C \uBC00\uC5B4 \uB2E4\uC74C \uD398\uC774\uC9C0\uB97C \uC900\uBE44\uD569\uB2C8\uB2E4")
            return

        if event_id == "student.identify.start":
            index = str(fields.get("index") or "").strip()
            meta = f"{index}번째 학생 사진 확인 중" if index else "학생 사진 확인 중"
            self._reset_scan_student_card(meta=meta)
            return
        if event_id == "student.identify.success":
            self._reset_scan_student_card(student_id, student_name, "사진 식별 완료. 기록 카드를 준비합니다.")
            return
        if event_id == "student.scan.start":
            self._reset_scan_student_card(student_id, student_name, "학생부 기록 정리 중")
            return

        if student_name and not self._scan_current_student_name:
            self._scan_current_student_name = student_name
            if self._scan_student_name_label is not None:
                self._scan_student_name_label.setText(student_name)
        if student_id and not self._scan_current_student_id:
            self._scan_current_student_id = student_id
            self._set_scan_student_portrait(student_id)

        if event_id == "level.read.ok":
            self._set_scan_student_value("level", fields.get("level"))
        elif event_id == "level.read.failed":
            self._set_scan_student_value("level", "확인 필요")
        elif event_id in {"star.read.ok", "star.infer_from_weapon"}:
            star = fields.get("star")
            self._set_scan_student_value("star", star)
            if self._scan_student_progress_strip is not None:
                try:
                    self._scan_student_progress_strip.setProgress(int(star or 0), 0, False)
                except (TypeError, ValueError):
                    pass
        elif event_id == "star.read.uncertain":
            star = fields.get("star")
            self._set_scan_student_value("star", f"{star}성 확인 필요" if star else "확인 필요")
        elif event_id == "weapon_state.no_system":
            self._set_scan_student_value("weapon", "미해금")
        elif event_id == "weapon_state.unlocked_not_equipped":
            self._set_scan_student_value("weapon", "미장착")
        elif event_id == "weapon_state.equipped":
            self._set_scan_student_value("weapon", "장착")
        elif event_id == "weapon_state.uncertain":
            self._set_scan_student_value("weapon", "확인 필요")
        elif event_id == "weapon.skip_star_locked":
            self._set_scan_student_value("weapon", "잠금")
        elif event_id == "weapon.skip_no_system":
            self._set_scan_student_value("weapon", "미해금")
        elif event_id == "weapon.skip_not_equipped":
            self._set_scan_student_value("weapon", "미장착")
        elif event_id == "weapon.summary":
            self._set_scan_student_value("weapon", f"{fields.get('star')}성 Lv.{fields.get('level')}")
            if self._scan_student_progress_strip is not None:
                try:
                    star_label = self._scan_student_value_labels.get("star")
                    student_star = int((star_label.text() if star_label is not None else "0") or 0)
                    weapon_star = int(fields.get("star") or 0)
                    self._scan_student_progress_strip.setProgress(student_star, weapon_star, True)
                except (TypeError, ValueError):
                    pass
        elif event_id == "skills.value.ok":
            skill_key = str(fields.get("skill") or "")
            label_key = {
                "ex_skill": "skill_ex",
                "skill1": "skill_s1",
                "skill2": "skill_s2",
                "skill3": "skill_s3",
            }.get(skill_key)
            if label_key:
                self._set_scan_student_value(label_key, fields.get("value"))
        elif event_id == "skills.summary":
            self._set_scan_student_value("skill_ex", fields.get("ex"))
            self._set_scan_student_value("skill_s1", fields.get("s1"))
            self._set_scan_student_value("skill_s2", fields.get("s2"))
            self._set_scan_student_value("skill_s3", fields.get("s3"))
        elif event_id == "skills.skill2.skip_star_locked":
            self._set_scan_student_value("skill_s2", "잠금")
        elif event_id == "skills.skill3.skip_star_locked":
            self._set_scan_student_value("skill_s3", "잠금")
        elif event_id == "equipment.saved_max_skip":
            for key in ("equip1", "equip2", "equip3"):
                self._set_scan_student_value(key, "T10 Lv.70")
        elif event_id == "equipment.favorite_saved_max_skip":
            self._set_scan_student_value("favorite", "T2")
        elif event_id.startswith("equip") and ".empty" in event_id:
            slot = event_id[5:6]
            if slot in {"1", "2", "3"}:
                self._set_scan_student_value(f"equip{slot}", "미장착")
        elif event_id in {"equip2.button_off_empty", "equip3.button_off_empty"}:
            self._set_scan_student_value(event_id[:6], "미장착")
        elif event_id in {"equip2.slot_flag.empty", "equip3.slot_flag.empty"}:
            self._set_scan_student_value(event_id[:6], "미장착")
        elif event_id in {"equip2.slot_flag.level_locked", "equip3.slot_flag.level_locked"}:
            self._set_scan_student_value(event_id[:6], "잠김")
        elif event_id in {"equip2.skip_level_locked_from_level", "equip3.skip_level_locked_from_level"}:
            self._set_scan_student_value(event_id[:6], "잠김")
        elif event_id.startswith("equip") and event_id.endswith(".tier.ok"):
            slot = event_id[5:6]
            if slot in {"1", "2", "3"}:
                self._merge_scan_equipment_value(f"equip{slot}", tier=fields.get("tier"))
        elif event_id.startswith("equip") and event_id.endswith(".level.ok"):
            slot = event_id[5:6]
            if slot in {"1", "2", "3"}:
                self._merge_scan_equipment_value(f"equip{slot}", level=fields.get("level"))
        elif event_id == "favorite.unsupported":
            self._set_scan_student_value("favorite", "없음")
        elif event_id in {"favorite.growth_off_dot_empty", "favorite.slot_flag.empty"}:
            self._set_scan_student_value("favorite", "미장착")
        elif event_id == "favorite.growth_on_needs_menu":
            self._set_scan_student_value("favorite", "상세 확인 중")
        elif event_id == "favorite.slot_flag.love_locked":
            self._set_scan_student_value("favorite", "인연 15 잠금")
        elif event_id == "favorite.slot_flag.null":
            self._set_scan_student_value("favorite", "없음")
        elif event_id == "favorite.tier.t1":
            self._set_scan_student_value("favorite", "T1")
        elif event_id == "favorite.tier.t2":
            self._set_scan_student_value("favorite", "T2")
        elif event_id == "stats.skip_condition":
            self._set_scan_student_value("stats", "잠금")
        elif event_id == "stats.saved_max_skip":
            self._set_scan_student_value("stats", "최대 기록")
        elif event_id == "stats.summary":
            self._set_scan_student_value(
                "stats",
                f"HP {fields.get('hp')} / ATK {fields.get('atk')} / HEAL {fields.get('heal')}",
            )
        elif event_id == "summary.student.compact":
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("정리 완료. 기록 반영을 기다립니다.")
        elif event_id == "student.scan.commit":
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("기록 반영 완료")
        elif event_id == "student.scan.partial_commit":
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("확인 필요 항목이 있어 일부 기록만 반영했습니다.")
        elif event_id == "student.scan.failed":
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("기록 반영 실패")

    def _plana_expression_path(self, expression: str) -> Path:
        filename = f"{expression}.png"
        candidates = (
            BASE_DIR / "assets" / "plana" / filename,
            APP_DIR / "assets" / "plana" / filename,
            APP_DIR / "_internal" / "assets" / "plana" / filename,
        )
        for path in candidates:
            if path.exists():
                return path
        return candidates[0]

    def _set_plana_expression(self, expression: str) -> None:
        if self._scan_plana_image_label is None:
            return
        expression = expression if expression else "neutral"
        pixmap = self._scan_plana_pixmaps.get(expression)
        if pixmap is None:
            path = self._plana_expression_path(expression)
            pixmap = QPixmap(str(path))
            self._scan_plana_pixmaps[expression] = pixmap
        if pixmap.isNull():
            self._scan_plana_image_label.clear()
            self._scan_plana_image_label.setVisible(False)
            return
        target_w = scale_px(260, self._ui_scale)
        target_h = scale_px(360, self._ui_scale)
        self._scan_plana_image_label.setVisible(True)
        self._scan_plana_image_label.setPixmap(
            pixmap.scaled(
                target_w,
                target_h,
                Qt.KeepAspectRatio,
                Qt.SmoothTransformation,
            )
        )

    def _set_plana_message(self, message: str, meta: str = "") -> None:
        if self._scan_plana_message_label is not None:
            self._scan_plana_message_label.setText(message)
        if self._scan_plana_meta_label is not None:
            self._scan_plana_meta_label.setText(meta or "학생부 정리 대기 중")

    def _reset_plana_scan_status(self, mode_label: str) -> None:
        self._scan_status_file_offset = 0
        self._scan_status_recent_messages = []
        try:
            reset_status_log(self._scan_status_path())
            write_status_ack(self._scan_status_ack_path(), 0)
        except Exception:
            pass
        self._set_plana_message(
            "스캔을 준비하는 중입니다. 잠시만 기다려 주십시오, 선생님.",
            f"{mode_label} 준비 중",
        )
        self._set_plana_expression("neutral")
        if self._scan_plana_log is not None:
            self._scan_plana_log.clear()
        self._reset_scan_student_card()

    def _append_plana_status_event(self, event: dict) -> None:
        if str(event.get("id") or "") == "progress.update":
            self._update_scan_progress_from_event(event)
            return
        self._update_scan_student_card_from_event(event)
        message = str(event.get("message") or "").strip()
        if not message:
            return
        level = str(event.get("level") or "detail")
        phase = str(event.get("phase") or "scan")
        expression = str(event.get("expression") or "").strip()
        if expression:
            self._set_plana_expression(expression)
        fields = event.get("fields") if isinstance(event.get("fields"), dict) else {}
        student_name = str(fields.get("student_name") or "").strip()
        meta_parts = []
        if student_name:
            meta_parts.append(student_name)
        if phase:
            meta_parts.append(phase)
        meta = " / ".join(meta_parts)
        if level in {"primary", "result", "skip", "warning", "error"}:
            self._set_plana_message(message, meta)

        try:
            ts = datetime.fromtimestamp(float(event.get("ts") or 0)).strftime("%H:%M:%S")
        except Exception:
            ts = "--:--:--"
        prefix = {
            "warning": "확인 필요",
            "error": "오류",
            "skip": "판단",
            "result": "확인",
            "primary": "진행",
        }.get(level, "상세")
        line = f"[{ts}] {prefix} · {message}"
        self._scan_status_recent_messages.append(line)
        self._scan_status_recent_messages = self._scan_status_recent_messages[-80:]
        if self._scan_plana_log is not None:
            self._scan_plana_log.setPlainText("\n".join(self._scan_status_recent_messages))
            self._scan_plana_log.verticalScrollBar().setValue(
                self._scan_plana_log.verticalScrollBar().maximum()
            )

    def _poll_scan_status_events(self) -> None:
        try:
            events, offset = read_status_events(self._scan_status_path(), self._scan_status_file_offset)
        except Exception:
            return
        self._scan_status_file_offset = offset
        last_seq = 0
        for event in events:
            self._append_plana_status_event(event)
            try:
                last_seq = max(last_seq, int(event.get("seq") or 0))
            except (TypeError, ValueError):
                pass
        if last_seq > 0:
            try:
                write_status_ack(self._scan_status_ack_path(), last_seq)
            except Exception:
                pass

    def _scanner_mode_label(self, mode: str) -> str:
        labels = {
            "resources": "자원 스캔",
            "items": "아이템 스캔",
            "equipment": "장비 스캔",
            "students": "학생 스캔",
            "student_current": "현재 학생 스캔",
        }
        return labels.get(mode, mode or "스캔")

    def _cleanup_finished_scanner_process(self, *, notify: bool) -> bool:
        process = self._scanner_process
        if process is None:
            return False
        code = process.poll()
        if code is None:
            return False
        self._scanner_process = None
        self._scanner_poll_timer.stop()
        if self._scan_status_poll_timer is not None:
            self._scan_status_poll_timer.stop()
        self._on_scanner_process_finished(code, notify=notify)
        return True

    def _on_scanner_process_finished(self, code: int, *, notify: bool = True) -> None:
        self._poll_scan_status_events()
        mode = self._scanner_mode
        self._scanner_mode = ""
        label = self._scanner_mode_label(mode)
        self._finish_scan_progress_view(code)
        if self._scan_status_label is not None:
            self._scan_status_label.setText(
                f"{label} 완료" if code == 0 else f"{label} 종료 코드: {code}"
            )
        if code == 0:
            try:
                self._reload_data()
            except Exception:
                pass
        if notify:
            self._notify_scanner_finished(label, code)

    def _notify_scanner_finished(self, label: str, code: int) -> None:
        title = "BA Planner"
        message = f"{label}이 끝났습니다." if code == 0 else f"{label}이 종료되었습니다. 코드: {code}"
        QApplication.alert(self, 0)
        QApplication.beep()
        if os.name == "nt":
            try:
                import winsound

                winsound.MessageBeep(winsound.MB_ICONASTERISK if code == 0 else winsound.MB_ICONHAND)
            except Exception:
                pass
        if not QSystemTrayIcon.isSystemTrayAvailable():
            return
        icon = self.windowIcon()
        if self._scanner_tray_icon is None:
            self._scanner_tray_icon = QSystemTrayIcon(icon, self)
            self._scanner_tray_icon.setToolTip("BA Planner")
            self._scanner_tray_icon.show()
        elif not icon.isNull():
            self._scanner_tray_icon.setIcon(icon)
        tray_icon = QSystemTrayIcon.Information if code == 0 else QSystemTrayIcon.Warning
        self._scanner_tray_icon.showMessage(title, message, tray_icon, 8000)

    def _scanner_command(self, mode: str) -> list[str]:
        command = [sys.executable]
        if not getattr(sys, "frozen", False):
            command.append(str(BASE_DIR / "main.py"))
        command.extend(["--scanner", "--use-saved-target", "--suppress-overlay"])
        if mode:
            command.extend(["--auto-scan", mode])
        return command

    def _launch_scanner(self, mode: str) -> None:
        self._cleanup_finished_scanner_process(notify=False)
        if self._scanner_process is not None and self._scanner_process.poll() is None:
            QMessageBox.information(self, "BA Planner", "이미 스캐너가 실행 중입니다.")
            return
        if not self._load_saved_target_into_capture():
            QMessageBox.information(self, "BA Planner", "먼저 설정 탭에서 BA 창을 선택해주세요.")
            self._open_settings_tab()
            return
        self._sync_settings_labels()
        activate_target_window()
        self._clear_scan_stop_request()
        creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW") else 0
        try:
            self._scanner_process = subprocess.Popen(
                self._scanner_command(mode),
                cwd=str(BASE_DIR),
                creationflags=creationflags,
            )
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"스캐너 실행에 실패했습니다.\n\n{exc}")
            return
        self._scanner_mode = mode
        label = self._scanner_mode_label(mode)
        self._reset_plana_scan_status(label)
        self._reset_scan_progress_view(label)
        if mode in {"items", "equipment", "resources"}:
            self._reset_scan_inventory_card(label, f"{label} 준비 중", 5, 5 if mode == "equipment" else 4)
        if mode in {"students", "all"}:
            self._set_plana_message(
                "첫 번째 학생의 기본 정보 화면을 확인합니다. 선생님, 스캔할 첫 번째 학생의 정보창을 띄워 주십시오.",
                "첫 학생 정보창에서 시작",
            )
        if self._scan_status_label is not None:
            self._scan_status_label.setText(f"{label} 시작")
        if self._scan_stop_button is not None:
            self._scan_stop_button.setEnabled(True)
            self._scan_stop_button.setText("스캔 중지")
        self._scanner_poll_timer.start()
        if self._scan_status_poll_timer is not None:
            self._scan_status_poll_timer.start()

    def _state_export_students(self) -> list[dict[str, object]]:
        field_map = (
            ("student_id", "student_id"),
            ("display_name", "display_name"),
            ("level", "level"),
            ("student_star", "star"),
            ("weapon_state", "weapon_state"),
            ("weapon_star", "weapon_star"),
            ("weapon_level", "weapon_level"),
            ("ex_skill", "ex_skill"),
            ("skill1", "skill1"),
            ("skill2", "skill2"),
            ("skill3", "skill3"),
            ("equip1", "equip1"),
            ("equip2", "equip2"),
            ("equip3", "equip3"),
            ("equip4", "equip4"),
            ("equip1_level", "equip1_level"),
            ("equip2_level", "equip2_level"),
            ("equip3_level", "equip3_level"),
            ("combat_hp", "combat_hp"),
            ("combat_atk", "combat_atk"),
            ("combat_def", "combat_def"),
            ("combat_heal", "combat_heal"),
            ("stat_hp", "stat_hp"),
            ("stat_atk", "stat_atk"),
            ("stat_heal", "stat_heal"),
        )
        rows: list[dict[str, object]] = []
        for record in self._all_students:
            if not record.owned:
                continue
            rows.append({export_key: getattr(record, attr) for export_key, attr in field_map})
        return rows

    def _copy_state_export_to_clipboard(self) -> None:
        try:
            students = self._state_export_students()
            token = encode_state_export(
                students=students,
                inventory=self._inventory_snapshot or {},
                resources=self._resource_snapshot or {},
                profile_name=get_active_profile_name("Default"),
                app_version=APP_VERSION,
            )
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"State export failed.\n\n{exc}")
            return
        QApplication.clipboard().setText(token)
        student_count = len(students)
        inventory_count = len(self._inventory_snapshot or {})
        resource_count = len(self._resource_snapshot or {})
        if self._scan_status_label is not None:
            self._scan_status_label.setText(
                f"State export copied: students {student_count}, inventory {inventory_count}, resources {resource_count}"
            )
        QMessageBox.information(
            self,
            "BA Planner",
            "State export copied to clipboard.\n\n"
            f"Students: {student_count} / Inventory: {inventory_count} / Resources: {resource_count}\n"
            f"Length: {len(token):,} characters",
        )

    def _check_scanner_process(self) -> None:
        if self._scanner_process is None:
            self._scanner_poll_timer.stop()
            if self._scan_status_poll_timer is not None:
                self._scan_status_poll_timer.stop()
            return
        self._poll_scan_status_events()
        code = self._scanner_process.poll()
        if code is None:
            return
        self._scanner_process = None
        self._scanner_poll_timer.stop()
        if self._scan_status_poll_timer is not None:
            self._scan_status_poll_timer.stop()
        self._on_scanner_process_finished(code)

    def _build_ui(self) -> None:
        root = QWidget(self)
        root.setObjectName("viewerRoot")
        self.setCentralWidget(root)

        outer_layout = QVBoxLayout(root)
        outer_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        outer_layout.setSpacing(scale_px(12, self._ui_scale))

        tabs = QTabWidget()
        self._main_tabs = tabs
        tabs.setObjectName("mainTabs")
        tabs.tabBar().setObjectName("mainTabBar")
        tabs.tabBar().setUsesScrollButtons(True)
        outer_layout.addWidget(tabs, 1)

        scan_tab = QWidget()
        self._scan_tab = self._add_main_tab(tabs, scan_tab, "스캔")
        self._build_scan_tab(scan_tab)

        students_tab = QWidget()
        self._students_tab = self._add_main_tab(tabs, students_tab, _tr("tab.students"))
        self._build_students_tab(students_tab)

        plan_tab = QWidget()
        self._add_main_tab(tabs, plan_tab, _tr("tab.plans"))
        self._build_plan_tab(plan_tab)

        resource_tab = QWidget()
        self._resource_tab = self._add_main_tab(tabs, resource_tab, "필요 재화")
        self._build_resource_tab(resource_tab)

        inventory_tab = QWidget()
        self._inventory_tab = self._add_main_tab(tabs, inventory_tab, _tr("tab.inventory"))
        self._build_inventory_tab(inventory_tab)

        tactical_tab = QWidget()
        self._add_main_tab(tabs, tactical_tab, "전술대항전")
        self._build_tactical_tab(tactical_tab)

        raid_guide_tab = QWidget()
        self._add_main_tab(tabs, raid_guide_tab, "공략 타임라인")
        self._build_raid_guide_tab(raid_guide_tab)

        stats_tab = QWidget()
        self._add_main_tab(tabs, stats_tab, "Statistics")
        self._build_stats_tab(stats_tab)

        settings_tab = QWidget()
        self._settings_tab = self._add_main_tab(tabs, settings_tab, "설정")
        self._build_settings_tab(settings_tab)

        tabs.currentChanged.connect(self._on_main_tab_changed)

        self.setStyleSheet(
            f"""
            QMainWindow, QWidget {{ background: {BG}; color: {INK}; }}
            QLabel {{ background: transparent; }}
            QTabWidget#mainTabs::pane {{
                border: none;
                border-radius: {scale_px(18, self._ui_scale)}px;
                background: transparent;
                top: {scale_px(3, self._ui_scale)}px;
            }}
            QTabWidget#tacticalInsightTabs::pane {{
                border: none;
                background: transparent;
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QTabBar::tab {{
                background: transparent;
                color: {MUTED};
                padding: {scale_px(10, self._ui_scale)}px {scale_px(14, self._ui_scale)}px;
                margin-right: {scale_px(6, self._ui_scale)}px;
                border-radius: {scale_px(10, self._ui_scale)}px;
            }}
            QTabBar::tab:hover {{
                background: {ACCENT_SOFT};
                color: {INK};
            }}
            QTabBar::tab:selected {{
                background: {ACCENT_PALE};
                color: {ACCENT_STRONG};
                font-weight: 700;
            }}
            QTabBar#mainTabBar {{
                margin-bottom: {scale_px(2, self._ui_scale)}px;
            }}
            QTabBar#mainTabBar::tab {{
                background: transparent;
                color: {MUTED};
                border: 2px solid transparent;
                border-radius: {scale_px(10, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px {scale_px(14, self._ui_scale)}px;
                margin-right: {scale_px(6, self._ui_scale)}px;
                font-weight: 700;
            }}
            QTabBar#mainTabBar::tab:hover {{
                background: transparent;
                color: #ffb5f0;
                border-color: {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
            }}
            QTabBar#mainTabBar::tab:selected {{
                background: transparent;
                color: #ffb5f0;
                border: 2px solid #ffb5f0;
                font-weight: 800;
            }}
            QTabWidget#inventoryRootTabs {{
                background: {_mix_hex(SURFACE_ALT, BG, 0.08)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.36)};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QTabWidget#inventoryRootTabs::pane {{
                background: transparent;
                border: none;
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QFrame#inventorySubTabs {{
                background: {SURFACE_ALT};
                border: none;
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QStackedWidget#inventorySubStack {{
                background: transparent;
                border: none;
            }}
            QStackedWidget#sectionTransparentStack,
            QStackedWidget#planEditorStack {{
                background: transparent;
                border: none;
            }}
            QWidget#inventoryPaneContent {{
                background: transparent;
                border: none;
            }}
            QScrollArea#sectionScrollArea {{
                background: transparent;
                border: none;
            }}
            QScrollArea#sectionScrollArea > QWidget > QWidget {{
                background: transparent;
                border: none;
            }}
            QTabBar#inventorySubTabBar {{
                background: transparent;
                border: none;
            }}
            QTabBar#inventorySubTabBar::tab {{
                background: transparent;
                color: {MUTED};
                border: none;
                border-bottom: {scale_px(2, self._ui_scale)}px solid transparent;
                border-radius: 0px;
                padding: {scale_px(10, self._ui_scale)}px {scale_px(16, self._ui_scale)}px;
                margin-right: {scale_px(10, self._ui_scale)}px;
                font-size: {scale_px(12, self._ui_scale)}px;
                font-weight: 800;
            }}
            QTabBar#inventorySubTabBar::tab:hover {{
                color: {INK};
                border-bottom-color: {ACCENT_SOFT};
            }}
            QTabBar#inventorySubTabBar::tab:selected {{
                color: {ACCENT_STRONG};
                border-bottom-color: {ACCENT};
                font-weight: 900;
            }}
            QFrame#header, QFrame#panel, QFrame#statPanel, QFrame#summaryCard, QFrame#scanInventoryCard {{
                background: {SURFACE};
                border: 1px solid {BORDER};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QFrame#scanHeader {{
                background: {SURFACE};
                border: 1px solid {BORDER};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QFrame#scanHeader[connected="true"] {{
                border: {scale_px(3, self._ui_scale)}px solid #76d7ff;
            }}
            QFrame#scanPreviewPanel {{
                background: #05070d;
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.12)};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QFrame#scanStudentCard, QFrame#scanStudentCaptureCard {{
                background: {_mix_hex(SURFACE_ALT, BG, 0.08)};
                border: none;
                border-radius: {scale_px(8, self._ui_scale)}px;
            }}
            QFrame#scanStudentMetaPanel {{
                background: {_mix_hex(PALETTE_PANEL, SURFACE_ALT, 0.18)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.2)};
                border-radius: {scale_px(8, self._ui_scale)}px;
            }}
            QLabel#scanStudentValue {{
                color: {INK};
                font-size: {scale_px(13, self._ui_scale)}px;
                font-weight: 900;
            }}
            QSplitter#inventorySplitter,
            QSplitter#sectionSplitter {{
                background: transparent;
                border: none;
            }}
            QSplitter#inventorySplitter::handle,
            QSplitter#sectionSplitter::handle {{
                background: transparent;
                border: none;
            }}
            QSplitter#inventorySplitter::handle:horizontal,
            QSplitter#sectionSplitter::handle:horizontal {{
                width: {scale_px(10, self._ui_scale)}px;
            }}
            QFrame#heroWrap {{
                background: {SURFACE_ALT};
                border: 1px solid {BORDER};
                border-radius: {scale_px(18, self._ui_scale)}px;
            }}
            QLabel#title {{ font-size: {scale_px(24, self._ui_scale)}px; font-weight: 800; color: {INK}; }}
            QLabel#count, QLabel#detailSub, QLabel#filterSummary, QLabel#sectionSub, QLabel#kpiValueSub {{ color: {MUTED}; }}
            QLabel#scanProfile {{
                color: #ff8fd6;
                font-size: {scale_px(15, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#sectionTitle {{ font-size: {scale_px(15, self._ui_scale)}px; font-weight: 800; color: {INK}; }}
            QLabel#badge {{
                background: {ACCENT_PALE};
                color: {ACCENT_STRONG};
                border: 1px solid {ACCENT_SOFT};
                border-radius: {scale_px(9, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px {scale_px(8, self._ui_scale)}px;
            }}
            QLabel#metricValue {{ font-size: {scale_px(22, self._ui_scale)}px; font-weight: 800; color: {INK}; }}
            QLabel#metricLabel {{ color: {MUTED}; font-size: {scale_px(11, self._ui_scale)}px; text-transform: uppercase; }}
            QLineEdit, QComboBox, QPushButton, QPlainTextEdit {{
                background: {SURFACE};
                border: 1px solid {BORDER};
                border-radius: {scale_px(9, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px {scale_px(10, self._ui_scale)}px;
                min-height: {scale_px(22, self._ui_scale)}px;
            }}
            QPushButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                font-weight: 700;
            }}
            QPushButton:hover {{
                background: transparent;
                color: #ffb5f0;
                border-color: {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QPushButton:checked {{
                background: transparent;
                color: #ffb5f0;
                border: 2px solid #ffb5f0;
            }}
            QPushButton:disabled {{
                background: transparent;
                color: {MUTED};
                border-color: {_mix_hex(BORDER, SURFACE_ALT, 0.28)};
            }}
            QComboBox, QLineEdit, QPlainTextEdit {{
                background: {SURFACE_ALT};
                color: {INK};
            }}
            QCheckBox {{
                color: {MUTED};
                spacing: {scale_px(8, self._ui_scale)}px;
            }}
            QListWidget#roundedList,
            QListWidget#planQuickAddList {{
                background: {SURFACE_ALT};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.36)};
                border-radius: {scale_px(14, self._ui_scale)}px;
                padding: 0px;
            }}
            QListWidget#roundedList::item,
            QListWidget#planQuickAddList::item {{
                background: transparent;
                border: none;
                padding: 0px;
            }}
            QListWidget#roundedList::item:selected,
            QListWidget#planQuickAddList::item:selected {{
                background: transparent;
                border: none;
            }}
            QAbstractItemView {{
                selection-background-color: transparent;
            }}
            QLabel#hero {{
                background: transparent;
                border: none;
                border-radius: {scale_px(16, self._ui_scale)}px;
            }}
            QLabel#detailName {{ font-size: {scale_px(28, self._ui_scale)}px; font-weight: 700; }}
            QFrame#detailCard {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 {SURFACE_ALT}, stop:1 {SURFACE});
                border: 1px solid {BORDER};
                border-radius: {scale_px(18, self._ui_scale)}px;
            }}
            QLabel#detailInlineName {{
                font-size: {scale_px(24, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#detailInlineSub, QLabel#detailMetaLine, QLabel#detailSectionTitle, QLabel#detailSkillLabel, QLabel#detailEquipCaption {{
                color: {MUTED};
            }}
            QLabel#detailSectionTitle {{
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 700;
                letter-spacing: 1px;
            }}
            QLabel#detailChip {{
                border-radius: {scale_px(10, self._ui_scale)}px;
                padding: {scale_px(5, self._ui_scale)}px {scale_px(10, self._ui_scale)}px;
                font-weight: 700;
            }}
            QLabel#detailBigValue {{
                font-size: {scale_px(44, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#detailMiniValue {{
                font-size: {scale_px(20, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#scanLiveMiniValue {{
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#scanLiveWeaponValue {{
                font-size: {scale_px(16, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#inventoryDetailMetricValue {{
                font-size: {scale_px(18, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#inventoryValue {{
                font-size: {scale_px(13, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#inventoryPressureAmount {{
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#inventoryPressureCoverage {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#inventoryCoveragePercent {{
                color: {INK};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#inventoryCoverageCaption {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#inventoryStudentDemand {{
                color: {INK};
                font-size: {scale_px(15, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#inventoryColumnHeader {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QPushButton#inventoryModeButton {{
                background: transparent;
                color: #ffa9f5;
                border: 1px solid {_mix_hex("#ffa9f5", SURFACE_ALT, 0.25)};
                border-radius: {scale_px(12, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px {scale_px(16, self._ui_scale)}px;
                font-size: {scale_px(13, self._ui_scale)}px;
                font-weight: 800;
            }}
            QPushButton#inventoryModeButton:hover {{
                background: transparent;
                color: #ffa9f5;
                border-color: {_mix_hex("#ffa9f5", "#ffffff", 0.18)};
            }}
            QPushButton#inventoryModeButton:checked {{
                background: transparent;
                color: #ffa9f5;
                border: 2px solid #ffa9f5;
            }}
            QPushButton#inventorySortDropdownButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(9, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px {scale_px(24, self._ui_scale)}px {scale_px(8, self._ui_scale)}px {scale_px(16, self._ui_scale)}px;
                min-height: {scale_px(22, self._ui_scale)}px;
                font-size: {scale_px(13, self._ui_scale)}px;
                font-weight: 800;
                text-align: left;
            }}
            QPushButton#inventorySortDropdownButton::menu-indicator {{
                subcontrol-origin: padding;
                subcontrol-position: center right;
                right: {scale_px(8, self._ui_scale)}px;
            }}
            QPushButton#inventorySortDropdownButton:hover {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QMenu {{
                background: {SURFACE_ALT};
                color: {INK};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.24)};
                border-radius: {scale_px(10, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px;
            }}
            QMenu::item {{
                padding: {scale_px(7, self._ui_scale)}px {scale_px(18, self._ui_scale)}px;
                border-radius: {scale_px(7, self._ui_scale)}px;
            }}
            QMenu::item:selected {{
                background: {ACCENT_SOFT};
                color: {INK};
            }}
            QPushButton#inventoryMiniModeButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(10, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px {scale_px(9, self._ui_scale)}px;
                min-height: {scale_px(18, self._ui_scale)}px;
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QPushButton#inventoryMiniModeButton:hover {{
                background: transparent;
                color: #ffb5f0;
                border-color: {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QPushButton#inventoryMiniModeButton:checked {{
                background: transparent;
                color: #ffb5f0;
                border: 2px solid #ffb5f0;
            }}
            QProgressBar#inventoryPressureBar {{
                background: transparent;
                border: 1px solid rgba(255, 255, 255, 0.78);
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPressureBar::chunk {{
                background: #ff304f;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPlanCoverageBar,
            QProgressBar#inventoryPoolCoverageBar {{
                background: #ffffff;
                border: 1px solid #e1e4eb;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPlanCoverageBar[empty="true"],
            QProgressBar#inventoryPoolCoverageBar[empty="true"] {{
                background: transparent;
                border: 1px solid rgba(255, 255, 255, 0.78);
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPlanCoverageBar::chunk {{
                background: #ff304f;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPoolCoverageBar::chunk {{
                background: #ffb5f0;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryBottleneckBar {{
                background: transparent;
                border: none;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryBottleneckBar::chunk {{
                background: #ff304f;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QLabel#inventoryBottleneckName {{
                color: #f7fbff;
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#inventoryBottleneckRatio {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QProgressBar#inventorySchoolRiskBar {{
                background: transparent;
                border: none;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventorySchoolRiskBar::chunk {{
                background: #ff304f;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QLabel#inventorySchoolRiskPercent {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#inventoryStatus {{
                border-radius: {scale_px(8, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px {scale_px(7, self._ui_scale)}px;
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 800;
                background: transparent;
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.18)};
                color: {MUTED};
            }}
            QLabel#inventoryStatus[status="sufficient"] {{
                background: transparent;
                border-color: #ffa9f5;
                color: #ffa9f5;
            }}
            QLabel#inventoryStatus[status="plan_shortage"] {{
                background: transparent;
                border-color: #ff304f;
                color: #ff304f;
            }}
            QLabel#inventoryStatus[status="long_term_pressure"] {{
                background: transparent;
                border-color: #ffb5f0;
                color: #ffb5f0;
            }}
            QLabel#inventoryStatus[status="unused"] {{
                background: transparent;
                border-color: #8b93a7;
                color: #8b93a7;
            }}
            QLabel#inventoryStatus[status="high_tier_bottleneck"] {{
                background: transparent;
                border-color: #d7193f;
                color: #d7193f;
            }}
            QLabel#inventoryRequiredBadge {{
                background: transparent;
                border: 1px solid #ffb5f0;
                border-radius: {scale_px(8, self._ui_scale)}px;
                color: #ffb5f0;
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
                padding: {scale_px(2, self._ui_scale)}px {scale_px(7, self._ui_scale)}px;
            }}
            QLabel#inventoryHintPink {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(8, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px;
                font-weight: 700;
            }}
            QLabel#inventoryHintBlue {{
                background: transparent;
                color: #9fd4ff;
                border: 1px solid {_mix_hex("#9fd4ff", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(8, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px;
                font-weight: 700;
            }}
            QLabel#detailMiniSub {{
                color: {MUTED};
                font-size: {scale_px(12, self._ui_scale)}px;
            }}
            QFrame#planSectionPanel {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 {_mix_hex(SURFACE, '#ffffff', 0.06)}, stop:1 {_mix_hex(SURFACE, SURFACE_ALT, 0.18)});
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.08)};
                border-radius: {scale_px(16, self._ui_scale)}px;
            }}
            QFrame#raidDeckGroup {{
                background: {_mix_hex(SURFACE_ALT, SURFACE, 0.42)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.22)};
                border-radius: {scale_px(12, self._ui_scale)}px;
            }}
            QFrame#inventoryContentPanel {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 {_mix_hex(SURFACE, '#ffffff', 0.06)}, stop:1 {_mix_hex(SURFACE, SURFACE_ALT, 0.18)});
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.18)};
                border-radius: {scale_px(16, self._ui_scale)}px;
            }}
            #planEditorInventoryShell {{
                background: {_mix_hex(SURFACE_ALT, BG, 0.08)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.36)};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            #planEditorSectionCard {{
                background: transparent;
                border: none;
            }}
            #planBand {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 {_mix_hex(SURFACE_ALT, '#ffffff', 0.03)}, stop:1 {_mix_hex(SURFACE_ALT, BG, 0.14)});
                border: 1px solid {_mix_hex(BORDER, SURFACE_ALT, 0.24)};
                border-radius: {scale_px(18, self._ui_scale)}px;
            }}
            #planBand QLabel#sectionTitle,
            #planBand QLabel#detailSectionTitle {{
                color: #f7fbff;
            }}
            #planEditorSectionCard QLabel#sectionTitle,
            #planEditorSectionCard QLabel#detailSectionTitle {{
                color: #f7fbff;
            }}
            QFrame#inventoryPressureRow {{
                background: transparent;
                border: none;
                border-radius: 0px;
            }}
            QWidget#planTransparent {{
                background: transparent;
                border: none;
            }}
            QLineEdit#planValueInput {{
                background: {_mix_hex(SURFACE_ALT, BG, 0.04)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.08)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(6, self._ui_scale)}px {scale_px(10, self._ui_scale)}px;
                font-size: {scale_px(17, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLineEdit#planValueInput:disabled {{
                color: {MUTED};
                background: {_mix_hex(SURFACE_ALT, BG, 0.22)};
            }}
            QPushButton#planQuickButton {{
                background: transparent;
                color: #ffa9f5;
                border: 1px solid {_mix_hex("#ffa9f5", SURFACE_ALT, 0.25)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(6, self._ui_scale)}px {scale_px(12, self._ui_scale)}px;
                font-size: {scale_px(12, self._ui_scale)}px;
                font-weight: 800;
                min-width: {scale_px(58, self._ui_scale)}px;
            }}
            QPushButton#planQuickButton:checked,
            QPushButton#resourceModeButton:checked {{
                background: transparent;
                color: #ffa9f5;
                border: 2px solid #ffa9f5;
            }}
            QPushButton#resourceModeButton {{
                background: transparent;
                color: #ffa9f5;
                border: 1px solid {_mix_hex("#ffa9f5", SURFACE_ALT, 0.25)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(6, self._ui_scale)}px {scale_px(14, self._ui_scale)}px;
                font-size: {scale_px(12, self._ui_scale)}px;
                font-weight: 800;
                min-width: {scale_px(58, self._ui_scale)}px;
            }}
            QLabel#resourceSectionTitle {{
                font-size: {scale_px(17, self._ui_scale)}px;
                font-weight: 900;
                color: {INK};
            }}
            QPushButton#planQuickButton:disabled {{
                background: transparent;
                color: {MUTED};
                border-color: {_mix_hex(BORDER, SURFACE_ALT, 0.28)};
            }}
            QPushButton#planStepButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px;
                font-size: {scale_px(15, self._ui_scale)}px;
                font-weight: 900;
                min-width: {scale_px(28, self._ui_scale)}px;
            }}
            QPushButton#planStepButton:hover {{
                background: transparent;
                border-color: {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QPushButton#planStepButton:disabled {{
                color: {MUTED};
                background: transparent;
                border-color: {_mix_hex(BORDER, SURFACE_ALT, 0.28)};
            }}
            QPushButton#planDisclosureButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(7, self._ui_scale)}px {scale_px(10, self._ui_scale)}px;
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 800;
                text-align: left;
            }}
            QPushButton#planDisclosureButton:hover {{
                background: transparent;
                color: #ffb5f0;
                border-color: {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QLabel#detailSkillValue {{
                color: {INK};
                font-size: {scale_px(21, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#detailEquipValue {{
                color: {INK};
                font-size: {scale_px(22, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#statValue {{ color: {INK}; font-weight: 700; }}
            QGroupBox {{
                border: 1px solid {BORDER};
                border-radius: {scale_px(12, self._ui_scale)}px;
                margin-top: {scale_px(10, self._ui_scale)}px;
                padding-top: {scale_px(12, self._ui_scale)}px;
                background: {SURFACE};
                font-weight: 700;
            }}
            QGroupBox::title {{
                subcontrol-origin: margin;
                left: {scale_px(12, self._ui_scale)}px;
                padding: 0 {scale_px(4, self._ui_scale)}px;
                color: {INK};
            }}
            QSpinBox {{
                background: {SURFACE_ALT};
                border: 1px solid {BORDER};
                border-radius: {scale_px(8, self._ui_scale)}px;
                padding: {scale_px(6, self._ui_scale)}px {scale_px(8, self._ui_scale)}px;
            }}
            QScrollBar:vertical {{
                background: {SURFACE_ALT};
                width: {scale_px(12, self._ui_scale)}px;
                margin: {scale_px(4, self._ui_scale)}px;
                border-radius: {scale_px(6, self._ui_scale)}px;
            }}
            QScrollBar::handle:vertical {{
                background: {ACCENT_SOFT};
                min-height: {scale_px(36, self._ui_scale)}px;
                border-radius: {scale_px(6, self._ui_scale)}px;
            }}
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,
            QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{
                background: transparent;
                border: none;
                height: 0px;
            }}
            """
        )
        self._build_busy_overlay(root)

    def _build_students_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(12, self._ui_scale))

        title_wrap = QVBoxLayout()
        title_wrap.setSpacing(scale_px(4, self._ui_scale))
        title = QLabel("Blue Archive Planner")
        title.setObjectName("title")
        title_wrap.addWidget(title)
        subtitle = QLabel("학생 목록과 현재 성장 상태를 확인하고 육성 계획을 구성합니다.")
        subtitle.setObjectName("count")
        title_wrap.addWidget(subtitle)
        header_layout.addLayout(title_wrap, 1)

        self._count_label = QLabel("")
        self._count_label.setObjectName("count")
        header_layout.addWidget(self._count_label)
        layout.addWidget(header)

        toolbar = QFrame()
        toolbar.setObjectName("panel")
        toolbar_layout = QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        toolbar_layout.setSpacing(scale_px(10, self._ui_scale))

        self._search = LiveSearchLineEdit()
        self._search.setPlaceholderText("학생 이름, ID, 태그로 검색")
        self._search.liveTextChanged.connect(self._schedule_filter_refresh)
        toolbar_layout.addWidget(self._search, 3)

        self._sort_mode = InventorySortDropdownButton()
        self._sort_mode.addItem("성급 높은순", "star_desc")
        self._sort_mode.addItem("성급 낮은순", "star_asc")
        self._sort_mode.addItem("레벨 높은순", "level_desc")
        self._sort_mode.addItem("이름순", "name_asc")
        self._sort_mode.modeChanged.connect(lambda *_: self._apply_filters())
        toolbar_layout.addWidget(self._sort_mode, 0, Qt.AlignVCenter)

        self._show_unowned = QCheckBox("미보유 학생 표시")
        self._show_unowned.setChecked(True)
        self._show_unowned.stateChanged.connect(self._apply_filters)
        toolbar_layout.addWidget(self._show_unowned)

        self._hide_jp_only = QCheckBox("일본 서버 전용 숨김")
        self._hide_jp_only.stateChanged.connect(self._apply_filters)
        toolbar_layout.addWidget(self._hide_jp_only)

        self._filter_button = QPushButton("필터")
        self._filter_button.setObjectName("planQuickButton")
        self._filter_button.clicked.connect(self._open_filter_dialog)
        toolbar_layout.addWidget(self._filter_button)

        refresh_button = QPushButton("새로고침")
        refresh_button.setObjectName("planQuickButton")
        refresh_button.clicked.connect(self._reload_data)
        toolbar_layout.addWidget(refresh_button)
        layout.addWidget(toolbar)

        self._filter_summary = QLabel("적용된 필터 없음")
        self._filter_summary.setWordWrap(True)
        self._filter_summary.setObjectName("filterSummary")
        layout.addWidget(self._filter_summary)

        content = QSplitter(Qt.Horizontal)
        content.setObjectName("sectionSplitter")
        content.setChildrenCollapsible(False)
        layout.addWidget(content, 1)

        list_panel = QFrame()
        list_panel.setObjectName("planSectionPanel")
        list_layout = QVBoxLayout(list_panel)
        list_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        list_layout.setSpacing(scale_px(10, self._ui_scale))

        detail = RoundedMaskFrame(ui_scale=self._ui_scale, radius=16)
        detail.setObjectName("planSectionPanel")
        detail.setFrameShape(QFrame.NoFrame)
        detail.setAttribute(Qt.WA_StyledBackground, True)
        detail_shell_layout = QVBoxLayout(detail)
        detail_shell_layout.setContentsMargins(0, 0, 0, 0)
        detail_shell_layout.setSpacing(0)
        detail_body = QWidget()
        detail_body.setObjectName("planTransparent")
        detail_body.setAutoFillBackground(False)
        detail_body.setAttribute(Qt.WA_TranslucentBackground, True)
        self._detail_panel = detail_body  # type: ignore[assignment]
        detail_shell_layout.addWidget(detail_body)
        detail_layout = QVBoxLayout(detail_body)
        detail_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        detail_layout.setSpacing(scale_px(10, self._ui_scale))

        hero_wrap = QFrame()
        self._hero_wrap = hero_wrap
        hero_wrap.setObjectName("heroWrap")
        hero_layout = QVBoxLayout(hero_wrap)
        hero_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
        )
        self._hero = StudentPortraitWidget(self._student_card_asset)
        self._hero.setObjectName("hero")
        self._hero.setMinimumWidth(scale_px(286, self._ui_scale))
        hero_layout.addWidget(self._hero)
        detail_layout.addWidget(hero_wrap)

        detail_card = QFrame()
        detail_card.setObjectName("detailCard")
        detail_card_layout = QVBoxLayout(detail_card)
        detail_card_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
        )
        detail_card_layout.setSpacing(scale_px(8, self._ui_scale))

        bar_row = QHBoxLayout()
        bar_row.setContentsMargins(0, 0, 0, 0)
        bar_row.setSpacing(scale_px(6, self._ui_scale))
        self._detail_attack_bar = ParallelogramPanel(fill=ACCENT_SOFT, border=ACCENT, slant=DETAIL_SLANT)
        self._detail_attack_bar.setFixedHeight(scale_px(8, self._ui_scale))
        self._detail_defense_bar = ParallelogramPanel(fill=ACCENT_PALE, border=PALETTE_SOFT, slant=DETAIL_SLANT)
        self._detail_defense_bar.setFixedHeight(scale_px(8, self._ui_scale))
        bar_row.addWidget(self._detail_attack_bar, 1)
        bar_row.addWidget(self._detail_defense_bar, 1)
        detail_card_layout.addLayout(bar_row)

        self._detail_progress_strip = DetailProgressStrip()
        detail_card_layout.addWidget(self._detail_progress_strip)

        name_row = QHBoxLayout()
        name_row.setContentsMargins(0, 0, 0, 0)
        name_row.setSpacing(scale_px(10, self._ui_scale))
        self._detail_school_icon = QLabel()
        self._detail_school_icon.setFixedSize(scale_px(26, self._ui_scale), scale_px(26, self._ui_scale))
        self._detail_school_icon.setScaledContents(False)
        name_row.addWidget(self._detail_school_icon, 0, Qt.AlignTop)
        name_col = QVBoxLayout()
        name_col.setContentsMargins(0, 0, 0, 0)
        name_col.setSpacing(scale_px(2, self._ui_scale))
        self._name = QLabel("학생을 선택하세요")
        self._name.setObjectName("detailInlineName")
        self._subtitle = QLabel("")
        self._subtitle.setObjectName("detailInlineSub")
        self._detail_badges = QLabel("")
        self._detail_badges.setObjectName("detailMetaLine")
        self._detail_badges.setWordWrap(True)
        name_col.addWidget(self._name)
        name_col.addWidget(self._subtitle)
        name_col.addWidget(self._detail_badges)
        name_row.addLayout(name_col, 1)
        detail_card_layout.addLayout(name_row)

        chip_row = QHBoxLayout()
        chip_row.setContentsMargins(0, 0, 0, 0)
        chip_row.setSpacing(scale_px(8, self._ui_scale))
        self._detail_attack_chip = QLabel("-")
        self._detail_attack_chip.setObjectName("detailChip")
        self._detail_defense_chip = QLabel("-")
        self._detail_defense_chip.setObjectName("detailChip")
        chip_row.addWidget(self._detail_attack_chip, 0, Qt.AlignLeft)
        chip_row.addWidget(self._detail_defense_chip, 0, Qt.AlignLeft)
        chip_row.addStretch(1)
        detail_card_layout.addLayout(chip_row)

        self._detail_plan_button = ParallelogramButton("플랜에 추가", style=self._card_button_style)
        self._detail_plan_button.clicked.connect(self._add_current_student_to_plan)
        self._detail_plan_button.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self._detail_plan_button.setFixedHeight(scale_px(32, self._ui_scale))
        plan_row = QHBoxLayout()
        plan_row.setContentsMargins(0, 0, 0, 0)
        plan_row.addWidget(self._detail_plan_button, 1)
        detail_card_layout.addLayout(plan_row)

        stat_row = QHBoxLayout()
        stat_row.setContentsMargins(0, 0, 0, 0)
        stat_row.setSpacing(scale_px(6, self._ui_scale))
        level_card = ParallelogramPanel(fill=_mix_hex(PALETTE_SOFT, SURFACE_ALT, 0.52), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        level_layout = QVBoxLayout(level_card)
        level_layout.setContentsMargins(scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale))
        level_layout.setSpacing(scale_px(6, self._ui_scale))
        level_title = QLabel("LEVEL")
        level_title.setObjectName("detailSectionTitle")
        level_title.setAlignment(Qt.AlignCenter)
        self._detail_level_value = QLabel("-")
        self._detail_level_value.setObjectName("detailBigValue")
        self._detail_level_value.setAlignment(Qt.AlignCenter)
        level_layout.addWidget(level_title)
        level_layout.addStretch(1)
        level_layout.addWidget(self._detail_level_value)
        level_layout.addStretch(1)
        stat_row.addWidget(level_card, 3)

        side_cards = QVBoxLayout()
        side_cards.setContentsMargins(0, 0, 0, 0)
        side_cards.setSpacing(scale_px(6, self._ui_scale))
        position_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_SOFT, 0.16), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        position_layout = QVBoxLayout(position_card)
        position_layout.setContentsMargins(scale_px(12, self._ui_scale), scale_px(10, self._ui_scale), scale_px(12, self._ui_scale), scale_px(10, self._ui_scale))
        position_layout.setSpacing(scale_px(2, self._ui_scale))
        self._detail_position_value = QLabel("-")
        self._detail_position_value.setObjectName("detailMiniValue")
        self._detail_position_value.setAlignment(Qt.AlignCenter)
        position_layout.addStretch(1)
        position_layout.addWidget(self._detail_position_value)
        position_layout.addStretch(1)
        side_cards.addWidget(position_card)

        class_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_SOFT, 0.16), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        class_layout = QVBoxLayout(class_card)
        class_layout.setContentsMargins(scale_px(12, self._ui_scale), scale_px(10, self._ui_scale), scale_px(12, self._ui_scale), scale_px(10, self._ui_scale))
        class_layout.setSpacing(scale_px(2, self._ui_scale))
        self._detail_class_value = QLabel("-")
        self._detail_class_value.setObjectName("detailMiniValue")
        self._detail_class_value.setAlignment(Qt.AlignCenter)
        class_layout.addStretch(1)
        class_layout.addWidget(self._detail_class_value)
        class_layout.addStretch(1)
        side_cards.addWidget(class_card)

        self._detail_weapon_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL_ALT, PALETTE_SOFT, 0.12), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        weapon_layout = QVBoxLayout(self._detail_weapon_card)
        weapon_layout.setContentsMargins(scale_px(12, self._ui_scale), scale_px(10, self._ui_scale), scale_px(12, self._ui_scale), scale_px(10, self._ui_scale))
        weapon_layout.setSpacing(scale_px(2, self._ui_scale))
        self._detail_weapon_value = QLabel("-")
        self._detail_weapon_value.setObjectName("detailMiniValue")
        self._detail_weapon_value.setAlignment(Qt.AlignCenter)
        self._detail_weapon_sub = QLabel("-")
        self._detail_weapon_sub.setObjectName("detailMiniSub")
        self._detail_weapon_sub.setAlignment(Qt.AlignCenter)
        weapon_layout.addStretch(1)
        weapon_layout.addWidget(self._detail_weapon_value)
        weapon_layout.addStretch(1)
        side_cards.addWidget(self._detail_weapon_card)
        stat_row.addLayout(side_cards, 2)
        detail_card_layout.addLayout(stat_row)

        skill_row = QHBoxLayout()
        skill_row.setContentsMargins(0, 0, 0, 0)
        skill_row.setSpacing(scale_px(4, self._ui_scale))
        self._detail_skill_labels: dict[str, QLabel] = {}
        for index, (key, label) in enumerate((("ex", "EX"), ("s1", "N"), ("s2", "P"), ("s3", "S"))):
            skill_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_ACCENT, 0.14), border=PALETTE_SOFT, slant=DETAIL_SLANT)
            skill_layout = QVBoxLayout(skill_card)
            skill_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale))
            skill_layout.setSpacing(scale_px(4, self._ui_scale))
            top = QLabel(label)
            top.setObjectName("detailSkillLabel")
            top.setAlignment(Qt.AlignCenter)
            value = QLabel("-")
            value.setObjectName("detailSkillValue")
            value.setAlignment(Qt.AlignCenter)
            self._detail_skill_labels[key] = value
            skill_layout.addStretch(1)
            skill_layout.addWidget(top)
            skill_layout.addWidget(value)
            skill_layout.addStretch(1)
            skill_row.addWidget(skill_card, 1)
        detail_card_layout.addLayout(skill_row)

        equip_row = QHBoxLayout()
        equip_row.setContentsMargins(0, 0, 0, 0)
        equip_row.setSpacing(0)
        self._detail_equip_cards: dict[str, EquipmentDetailCard] = {}
        for slot in ("equip1", "equip2", "equip3", "equip4"):
            card = EquipmentDetailCard(
                self._ui_scale,
                fill=_mix_hex(PALETTE_PANEL_ALT, PALETTE_SOFT, 0.18),
                border=PALETTE_SOFT,
                slant=DETAIL_SLANT,
            )
            equip_row.addWidget(card, 1)
            self._detail_equip_cards[slot] = card
        detail_card_layout.addLayout(equip_row)

        self._detail_stats_line = QLabel("-")
        self._detail_stats_line.setObjectName("detailMetaLine")
        self._detail_stats_line.setAlignment(Qt.AlignCenter)
        self._detail_stats_line.setTextFormat(Qt.RichText)
        self._detail_stats_line.setMinimumHeight(scale_px(38, self._ui_scale))
        self._detail_stats_line.setWordWrap(False)
        detail_card_layout.addWidget(self._detail_stats_line)

        self._detail_bonus_stats_line = QLabel("-")
        self._detail_bonus_stats_line.setObjectName("detailMetaLine")
        self._detail_bonus_stats_line.setAlignment(Qt.AlignCenter)
        self._detail_bonus_stats_line.setTextFormat(Qt.RichText)
        self._detail_bonus_stats_line.setMinimumHeight(scale_px(18, self._ui_scale))
        self._detail_bonus_stats_line.setWordWrap(False)
        detail_card_layout.addWidget(self._detail_bonus_stats_line)
        detail_layout.addWidget(detail_card)
        detail_layout.addStretch(1)
        self._student_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        student_grid_panel_layout = QVBoxLayout(self._student_grid_panel)
        student_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        student_grid_panel_layout.setSpacing(0)

        self._student_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            min_card_width=self._student_grid_card_width,
            fixed_column_count=STUDENT_GRID_COLUMNS,
        )
        self._student_grid.setObjectName("studentGrid")
        self._student_grid.setFrameShape(QFrame.NoFrame)
        self._student_grid.setAutoFillBackground(False)
        self._student_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._student_grid.viewport().setAutoFillBackground(False)
        self._student_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._student_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._student_grid.widget() is not None:
            self._student_grid.widget().setAutoFillBackground(False)
            self._student_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._student_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._student_grid, ui_scale=self._ui_scale)
        self._student_grid.current_changed.connect(self._on_student_card_changed)
        self._student_grid.layout_changed.connect(self._on_student_grid_layout_changed)
        student_grid_panel_layout.addWidget(self._student_grid, 1)
        list_layout.addWidget(self._student_grid_panel, 1)

        detail.setMinimumWidth(scale_px(356, self._ui_scale))
        detail.setMaximumWidth(scale_px(408, self._ui_scale))
        content.addWidget(list_panel)
        content.addWidget(detail)
        content.setStretchFactor(0, 5)
        content.setStretchFactor(1, 1)
        content.setSizes([scale_px(1168, self._ui_scale), scale_px(352, self._ui_scale)])
        content.splitterMoved.connect(lambda *_: QTimer.singleShot(0, self._sync_hero_height))
        QTimer.singleShot(0, self._sync_hero_height)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        QTimer.singleShot(0, self._sync_hero_height)
        self._sync_busy_overlay_geometry()

    def _build_busy_overlay(self, parent: QWidget) -> None:
        overlay = QFrame(parent)
        overlay.setObjectName("busyOverlay")
        overlay.setAttribute(Qt.WA_StyledBackground, True)
        overlay.hide()
        overlay.setGeometry(parent.rect())
        overlay.setStyleSheet(
            f"""
            QFrame#busyOverlay {{
                background: rgba(0, 0, 0, 132);
            }}
            QFrame#busyCard {{
                background: {SURFACE};
                border: 1px solid {BORDER};
                border-radius: {scale_px(10, self._ui_scale)}px;
            }}
            QProgressBar {{
                background: {SURFACE_ALT};
                border: 1px solid {BORDER};
                border-radius: {scale_px(5, self._ui_scale)}px;
                min-height: {scale_px(10, self._ui_scale)}px;
                max-height: {scale_px(10, self._ui_scale)}px;
            }}
            QProgressBar::chunk {{
                background: {ACCENT_STRONG};
                border-radius: {scale_px(5, self._ui_scale)}px;
            }}
            """
        )

        layout = QVBoxLayout(overlay)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setAlignment(Qt.AlignCenter)

        card = QFrame(overlay)
        card.setObjectName("busyCard")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(
            scale_px(24, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(24, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        card_layout.setSpacing(scale_px(12, self._ui_scale))

        label = QLabel("저장 중...", card)
        label.setObjectName("sectionTitle")
        label.setAlignment(Qt.AlignCenter)
        progress = QProgressBar(card)
        progress.setRange(0, 0)
        progress.setTextVisible(False)
        progress.setFixedWidth(scale_px(220, self._ui_scale))

        card_layout.addWidget(label)
        card_layout.addWidget(progress, 0, Qt.AlignHCenter)
        layout.addWidget(card)

        self._busy_overlay = overlay
        self._busy_label = label

    def _sync_busy_overlay_geometry(self) -> None:
        if self._busy_overlay is None:
            return
        parent = self._busy_overlay.parentWidget()
        if parent is None:
            return
        self._busy_overlay.setGeometry(parent.rect())

    def _show_busy_overlay(self, text: str = "저장 중...") -> None:
        if self._busy_overlay is None:
            return
        if self._busy_label is not None:
            self._busy_label.setText(text)
        self._sync_busy_overlay_geometry()
        self._busy_overlay.raise_()
        self._busy_overlay.show()
        if not self._busy_cursor_active:
            QApplication.setOverrideCursor(Qt.WaitCursor)
            self._busy_cursor_active = True
        QApplication.processEvents()

    def _hide_busy_overlay(self) -> None:
        if self._busy_overlay is not None:
            self._busy_overlay.hide()
        if self._busy_cursor_active:
            QApplication.restoreOverrideCursor()
            self._busy_cursor_active = False
        QApplication.processEvents()

    def changeEvent(self, event) -> None:
        super().changeEvent(event)
        if event.type() == QEvent.WindowStateChange and not self._applying_work_area:
            if self.windowState() & Qt.WindowMaximized:
                QTimer.singleShot(0, self._apply_work_area_geometry)
            QTimer.singleShot(0, self._sync_hero_height)

    def _sync_hero_height(self) -> None:
        if self._hero_wrap is None or self._detail_panel is None or not hasattr(self, "_hero"):
            return
        wrap_width = self._hero_wrap.width()
        if wrap_width <= 0:
            return
        inset = scale_px(32, self._ui_scale)
        card_width = max(1, wrap_width - inset)
        card_height = max(1, int(round(card_width / max(0.01, self._student_card_asset.aspect_ratio))))
        preferred_height = card_height + inset
        detail_height = self._detail_panel.height()
        max_height = max(scale_px(196, self._ui_scale), int(detail_height * 0.37)) if detail_height > 0 else preferred_height
        wrap_height = min(preferred_height, max_height)
        self._hero_wrap.setFixedHeight(wrap_height)

    def eventFilter(self, watched, event) -> bool:
        if event.type() == QEvent.KeyPress and self._handle_student_tab_arrow_key(event):
            return True
        return super().eventFilter(watched, event)

    def _is_students_tab_active(self) -> bool:
        return (
            self._main_tabs is not None
            and self._students_tab is not None
            and self._main_tabs.currentWidget() is self._students_tab
        )

    def _open_students_tab(self) -> None:
        if self._main_tabs is not None and self._students_tab is not None:
            self._main_tabs.setCurrentWidget(self._students_tab)

    def _handle_student_tab_arrow_key(self, event) -> bool:
        if not self._is_students_tab_active():
            return False
        key = event.key()
        if key not in {Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down}:
            return False
        modifiers = event.modifiers()
        if modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier):
            return False
        focus = QApplication.focusWidget()
        if isinstance(
            focus,
            (
                QLineEdit,
                QPlainTextEdit,
                QComboBox,
                QAbstractSpinBox,
                QListWidget,
                QTableWidget,
                QTabBar,
            ),
        ):
            return False
        moved = self._move_student_selection_for_key(key)
        if moved:
            event.accept()
        return moved

    def _move_student_selection_for_key(self, key: int) -> bool:
        columns = max(1, STUDENT_GRID_COLUMNS)
        if key == Qt.Key_Left:
            return self._move_student_selection(-1)
        if key == Qt.Key_Right:
            return self._move_student_selection(1)
        if key == Qt.Key_Up:
            return self._move_student_selection(-columns)
        if key == Qt.Key_Down:
            return self._move_student_selection(columns)
        return False

    def _move_student_selection(self, step: int) -> bool:
        if not hasattr(self, "_student_grid") or not self._filtered_students:
            return False
        ids = [record.student_id for record in self._filtered_students if record.student_id in self._item_by_id]
        if not ids:
            return False
        current = self._student_grid.current_card_id()
        if current in ids:
            current_index = ids.index(current)
            next_index = max(0, min(len(ids) - 1, current_index + int(step)))
        else:
            next_index = 0 if step >= 0 else len(ids) - 1
        next_id = ids[next_index]
        if next_id == current:
            return False
        self._student_grid.set_current_card(next_id)
        return True

    def _poll_debug_ba_arrow_keys(self) -> None:
        if not self._student_scan_debug_enabled:
            return
        if not is_target_foreground():
            self._ba_arrow_key_down[VK_LEFT] = False
            self._ba_arrow_key_down[VK_RIGHT] = False
            return
        for vk, key in ((VK_LEFT, Qt.Key_Left), (VK_RIGHT, Qt.Key_Right)):
            down = _async_key_down(vk)
            was_down = self._ba_arrow_key_down.get(vk, False)
            self._ba_arrow_key_down[vk] = down
            if down and not was_down:
                self._open_students_tab()
                self._move_student_selection_for_key(key)

    def _refresh_card_layout(self) -> None:
        if self._card_layout_guard or not hasattr(self, "_student_grid"):
            return
        sizes = [self._student_grid.current_card_size()]
        if hasattr(self, "_plan_grid"):
            sizes.append(self._plan_grid.current_card_size())
        if hasattr(self, "_resource_scope_grid"):
            sizes.append(self._resource_scope_grid.current_card_size())
        if hasattr(self, "_resource_search_grid"):
            sizes.append(self._resource_search_grid.current_card_size())
        thumb_width = max(size.width() for size in sizes)
        thumb_height = max(size.height() for size in sizes)
        outer_margin = self._student_card_asset.style.outer_margin * 2
        grid_width = thumb_width + outer_margin
        grid_height = thumb_height + outer_margin

        if thumb_width <= 0 or thumb_height <= 0:
            return

        if (
            thumb_width == self._thumb_width
            and thumb_height == self._thumb_height
            and grid_width == self._grid_width
            and grid_height == self._grid_height
        ):
            return

        self._card_layout_guard = True
        try:
            self._thumb_width = thumb_width
            self._thumb_height = thumb_height
            self._grid_width = grid_width
            self._grid_height = grid_height
            self._placeholder_icon = make_placeholder_icon(self._thumb_width, self._thumb_height)
            self._unowned_icon_cache.clear()
            self._clear_thumb_requests()
            for student_id in sorted(
                set(self._item_by_id)
                | set(self._plan_card_by_id)
                | set(getattr(self, "_plan_search_card_by_id", {}))
                | set(getattr(self, "_resource_scope_card_by_id", {}))
                | set(getattr(self, "_resource_search_card_by_id", {}))
            ):
                self._enqueue_thumb(student_id)
        finally:
            self._card_layout_guard = False

    def _on_plan_grid_layout_changed(self, width: int, height: int) -> None:
        if hasattr(self, "_plan_search_grid"):
            search_width = max(80, int(round(width * 0.5)))
            search_height = max(scale_px(96, self._ui_scale), int(round(height * 0.5)) + scale_px(28, self._ui_scale))
            self._plan_search_grid.set_min_card_width(search_width)
            self._plan_search_grid.setFixedHeight(search_height)
            if hasattr(self, "_plan_search_grid_panel"):
                self._plan_search_grid_panel.setFixedHeight(search_height + scale_px(20, self._ui_scale))
        self._refresh_card_layout()

    def _build_resource_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(12, self._ui_scale))

        title_wrap = QVBoxLayout()
        title_wrap.setSpacing(scale_px(4, self._ui_scale))
        title = QLabel("필요 재화량")
        title.setObjectName("title")
        title_wrap.addWidget(title)
        subtitle = QLabel(
            "계획된 범위의 학생들이 필요로 하는 재화량과, 계획에 포함되어 있지 않는 학생들을 임의로 묶어서 필요 재화량을 확인할 수 있습니다."
        )
        subtitle.setObjectName("count")
        subtitle.setWordWrap(True)
        title_wrap.addWidget(subtitle)
        header_layout.addLayout(title_wrap, 1)
        layout.addWidget(header)

        toolbar = QFrame()
        toolbar.setObjectName("panel")
        toolbar_layout = QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        toolbar_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_search = LiveSearchLineEdit()
        self._resource_search.setPlaceholderText("학생 이름, ID, 태그로 검색; 필터로 범위를 좁힙니다")
        self._resource_search.textChanged.connect(self._on_resource_search_changed)
        self._resource_search.liveTextChanged.connect(self._schedule_filter_refresh)
        toolbar_layout.addWidget(self._resource_search, 3)

        self._resource_sort_mode = InventorySortDropdownButton()
        self._resource_sort_mode.addItem("성급 높은순", "star_desc")
        self._resource_sort_mode.addItem("성급 낮은순", "star_asc")
        self._resource_sort_mode.addItem("레벨 높은순", "level_desc")
        self._resource_sort_mode.addItem("이름순", "name_asc")
        self._resource_sort_mode.modeChanged.connect(self._on_resource_sort_changed)
        toolbar_layout.addWidget(self._resource_sort_mode, 0, Qt.AlignVCenter)

        self._resource_show_unowned = QCheckBox("미보유 학생 표시")
        self._resource_show_unowned.stateChanged.connect(self._on_resource_show_unowned_changed)
        toolbar_layout.addWidget(self._resource_show_unowned)

        self._resource_hide_jp_only = QCheckBox("일본 서버 전용 숨김")
        self._resource_hide_jp_only.stateChanged.connect(self._on_resource_hide_jp_only_changed)
        toolbar_layout.addWidget(self._resource_hide_jp_only)

        self._resource_filter_button = QPushButton("필터")
        self._resource_filter_button.setObjectName("planQuickButton")
        self._resource_filter_button.clicked.connect(self._open_filter_dialog)
        toolbar_layout.addWidget(self._resource_filter_button)
        resource_refresh_button = QPushButton("새로고침")
        resource_refresh_button.setObjectName("planQuickButton")
        resource_refresh_button.clicked.connect(self._reload_data)
        toolbar_layout.addWidget(resource_refresh_button)

        self._resource_filter_summary = QLabel("적용된 필터 없음")
        self._resource_filter_summary.setWordWrap(True)
        self._resource_filter_summary.setObjectName("filterSummary")

        splitter = QSplitter(Qt.Horizontal)
        splitter.setObjectName("sectionSplitter")
        splitter.setChildrenCollapsible(False)

        left_panel = QFrame()
        left_panel.setObjectName("planSectionPanel")
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        left_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_left_top_panel = PlanEditorSectionCard(ui_scale=self._ui_scale, radius=16)
        resource_left_top_layout = QVBoxLayout(self._resource_left_top_panel)
        resource_left_top_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        resource_left_top_layout.setSpacing(scale_px(8, self._ui_scale))

        self._resource_left_header_host = QWidget()
        self._resource_left_header_host.setObjectName("planTransparent")
        left_header = QHBoxLayout(self._resource_left_header_host)
        left_header.setContentsMargins(0, 0, 0, 0)
        left_header.setSpacing(scale_px(8, self._ui_scale))
        left_header_title = QLabel("범위 설정")
        left_header_title.setObjectName("resourceSectionTitle")
        left_header.addWidget(left_header_title)
        left_header.addStretch(1)

        self._resource_mode_buttons: dict[int, QPushButton] = {}
        for index, label in enumerate(("범위", "검색")):
            button = QPushButton(label)
            button.setObjectName("resourceModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=index: self._set_resource_left_mode(value))
            self._resource_mode_buttons[index] = button
            left_header.addWidget(button, 0, Qt.AlignVCenter)

        self._resource_left_top_stack = QStackedWidget()
        self._resource_left_top_stack.setObjectName("sectionTransparentStack")
        resource_left_top_layout.addWidget(self._resource_left_header_host, 0)
        resource_left_top_layout.addWidget(self._resource_left_top_stack, 0)
        left_layout.addWidget(self._resource_left_top_panel, 0)

        self._resource_left_stack = QStackedWidget()
        self._resource_left_stack.setObjectName("sectionTransparentStack")
        left_layout.addWidget(self._resource_left_stack, 1)

        scope_tab = QWidget()
        scope_tab.setObjectName("planTransparent")
        scope_layout = QVBoxLayout(scope_tab)
        scope_layout.setContentsMargins(0, 0, 0, 0)
        scope_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_scope_top_controls = QWidget()
        self._resource_scope_top_controls.setObjectName("planTransparent")
        scope_top_layout = QVBoxLayout(self._resource_scope_top_controls)
        scope_top_layout.setContentsMargins(0, 0, 0, 0)
        scope_top_layout.setSpacing(scale_px(6, self._ui_scale))

        scope_header = QHBoxLayout()
        scope_header.setContentsMargins(0, 0, 0, 0)
        scope_header.setSpacing(scale_px(8, self._ui_scale))
        left_title = QLabel("계산 범위")
        left_title.setObjectName("sectionTitle")
        scope_header.addWidget(left_title)
        scope_header.addStretch(1)
        scope_top_layout.addLayout(scope_header)

        self._resource_list_summary = QLabel("")
        self._resource_list_summary.setObjectName("detailSub")
        self._resource_list_summary.setWordWrap(True)
        scope_top_layout.addWidget(self._resource_list_summary)
        self._resource_left_top_stack.addWidget(self._resource_scope_top_controls)

        unplanned_options = QFrame()
        unplanned_options.setObjectName("planSectionPanel")
        unplanned_layout = QVBoxLayout(unplanned_options)
        unplanned_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        unplanned_layout.setSpacing(scale_px(8, self._ui_scale))
        unplanned_title = QLabel("미계획 학생 계산")
        unplanned_title.setObjectName("detailSectionTitle")
        unplanned_layout.addWidget(unplanned_title)
        unplanned_row = QHBoxLayout()
        unplanned_row.setSpacing(scale_px(10, self._ui_scale))
        self._resource_unplanned_level = QCheckBox("레벨")
        self._resource_unplanned_level.setChecked(True)
        self._resource_unplanned_level.stateChanged.connect(self._on_resource_unplanned_options_changed)
        unplanned_row.addWidget(self._resource_unplanned_level)
        self._resource_unplanned_equipment = QCheckBox("장비")
        self._resource_unplanned_equipment.setChecked(True)
        self._resource_unplanned_equipment.stateChanged.connect(self._on_resource_unplanned_options_changed)
        unplanned_row.addWidget(self._resource_unplanned_equipment)
        self._resource_unplanned_skills = QCheckBox("스킬")
        self._resource_unplanned_skills.setChecked(True)
        self._resource_unplanned_skills.stateChanged.connect(self._on_resource_unplanned_options_changed)
        unplanned_row.addWidget(self._resource_unplanned_skills)
        unplanned_row.addStretch(1)
        unplanned_layout.addLayout(unplanned_row)
        resource_card_min_width = max(scale_px(104, self._ui_scale), int(round(self._student_card_asset.base_size.width() * 0.52)))
        self._resource_scope_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            min_card_width=resource_card_min_width,
        )
        self._resource_scope_grid.setObjectName("studentGrid")
        self._resource_scope_grid.setFrameShape(QFrame.NoFrame)
        self._resource_scope_grid.setAutoFillBackground(False)
        self._resource_scope_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._resource_scope_grid.viewport().setAutoFillBackground(False)
        self._resource_scope_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._resource_scope_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._resource_scope_grid.widget() is not None:
            self._resource_scope_grid.widget().setAutoFillBackground(False)
            self._resource_scope_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._resource_scope_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._resource_scope_grid, ui_scale=self._ui_scale)
        self._resource_scope_grid.current_changed.connect(self._on_resource_scope_card_changed)
        self._resource_scope_grid.layout_changed.connect(lambda *_: self._refresh_card_layout())
        self._resource_scope_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        scope_grid_panel_layout = QVBoxLayout(self._resource_scope_grid_panel)
        scope_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        scope_grid_panel_layout.setSpacing(0)
        scope_grid_panel_layout.addWidget(self._resource_scope_grid, 1)
        scope_layout.addWidget(self._resource_scope_grid_panel, 1)

        scope_buttons = QHBoxLayout()
        scope_buttons.setSpacing(scale_px(8, self._ui_scale))
        for label, handler in (
            ("선택 제거", self._resource_remove_scope_selected),
            ("비우기", self._resource_clear_checked),
        ):
            button = QPushButton(label)
            button.setObjectName("planQuickButton")
            button.clicked.connect(handler)
            if label == "선택 제거":
                self._resource_remove_scope_button = button
            scope_buttons.addWidget(button)
        scope_buttons.addStretch(1)
        scope_buttons.addWidget(unplanned_options, 0, Qt.AlignRight | Qt.AlignVCenter)
        scope_layout.addLayout(scope_buttons)
        self._resource_left_stack.addWidget(scope_tab)

        search_tab = QWidget()
        search_tab.setObjectName("planTransparent")
        search_layout = QVBoxLayout(search_tab)
        search_layout.setContentsMargins(0, 0, 0, 0)
        search_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_search_top_controls = QWidget()
        self._resource_search_top_controls.setObjectName("planTransparent")
        search_top_layout = QVBoxLayout(self._resource_search_top_controls)
        search_top_layout.setContentsMargins(0, 0, 0, 0)
        search_top_layout.setSpacing(scale_px(6, self._ui_scale))
        search_top_layout.addWidget(toolbar, 0)
        search_top_layout.addWidget(self._resource_filter_summary, 0)

        result_title = QLabel("검색 결과")
        result_title.setObjectName("sectionTitle")
        search_top_layout.addWidget(result_title)
        self._resource_search_summary = QLabel("")
        self._resource_search_summary.setObjectName("detailSub")
        self._resource_search_summary.setWordWrap(True)
        search_top_layout.addWidget(self._resource_search_summary)
        self._resource_left_top_stack.addWidget(self._resource_search_top_controls)

        self._resource_search_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            multi_select=True,
            min_card_width=resource_card_min_width,
        )
        self._resource_search_grid.setObjectName("studentGrid")
        self._resource_search_grid.setFrameShape(QFrame.NoFrame)
        self._resource_search_grid.setAutoFillBackground(False)
        self._resource_search_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._resource_search_grid.viewport().setAutoFillBackground(False)
        self._resource_search_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._resource_search_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._resource_search_grid.widget() is not None:
            self._resource_search_grid.widget().setAutoFillBackground(False)
            self._resource_search_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._resource_search_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._resource_search_grid, ui_scale=self._ui_scale)
        self._resource_search_grid.selection_changed.connect(self._on_resource_search_selection_changed)
        self._resource_search_grid.layout_changed.connect(lambda *_: self._refresh_card_layout())
        self._resource_search_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        search_grid_panel_layout = QVBoxLayout(self._resource_search_grid_panel)
        search_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        search_grid_panel_layout.setSpacing(0)
        search_grid_panel_layout.addWidget(self._resource_search_grid, 1)
        search_layout.addWidget(self._resource_search_grid_panel, 1)

        search_buttons = QHBoxLayout()
        search_buttons.setSpacing(scale_px(8, self._ui_scale))
        self._resource_add_selected_button = QPushButton("선택한 학생 추가")
        self._resource_add_selected_button.setObjectName("planQuickButton")
        self._resource_add_selected_button.clicked.connect(self._resource_add_pending_to_scope)
        search_buttons.addWidget(self._resource_add_selected_button)
        for label, handler in (
            ("결과 전체 추가", self._resource_check_visible),
            ("계획에 포함된 학생 전체 추가", self._resource_check_visible_planned),
            ("선택 해제", self._resource_clear_search_selection),
        ):
            button = QPushButton(label)
            button.setObjectName("planQuickButton")
            button.clicked.connect(handler)
            search_buttons.addWidget(button)
        search_buttons.addStretch(1)
        search_layout.addLayout(search_buttons)
        self._resource_left_stack.addWidget(search_tab)
        self._set_resource_left_mode(0)

        right_panel = QFrame()
        right_panel.setObjectName("planSectionPanel")
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        right_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_right_top_controls = PlanEditorSectionCard(ui_scale=self._ui_scale, radius=16)
        aggregate_options_layout = QVBoxLayout(self._resource_right_top_controls)
        aggregate_options_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        aggregate_options_layout.setSpacing(scale_px(8, self._ui_scale))
        aggregate_header = QHBoxLayout()
        aggregate_header.setContentsMargins(0, 0, 0, 0)
        aggregate_header.setSpacing(scale_px(8, self._ui_scale))
        aggregate_title = QLabel("합산 결과")
        aggregate_title.setObjectName("sectionTitle")
        aggregate_header.addWidget(aggregate_title)
        aggregate_header.addStretch(1)
        aggregate_sort_label = QLabel("정렬")
        aggregate_sort_label.setObjectName("detailMiniSub")
        aggregate_header.addWidget(aggregate_sort_label, 0, Qt.AlignVCenter)
        self._resource_requirement_sort = InventorySortDropdownButton()
        self._resource_requirement_sort.addItem("일반", "default")
        self._resource_requirement_sort.addItem("부족한 비율 순서", "shortage_ratio")
        self._resource_requirement_sort.modeChanged.connect(self._on_resource_requirement_sort_changed)
        aggregate_header.addWidget(self._resource_requirement_sort, 0, Qt.AlignVCenter)
        aggregate_options_layout.addLayout(aggregate_header)

        self._resource_aggregate_summary = QLabel("학생을 범위에 추가하면 성장 비용을 합산합니다.")
        self._resource_aggregate_summary.setObjectName("detailSub")
        self._resource_aggregate_summary.setWordWrap(True)
        aggregate_options_layout.addWidget(self._resource_aggregate_summary)

        self._resource_requirement_empty = QLabel("학생을 범위에 추가하면 필요한 재화를 미리 볼 수 있습니다.")
        self._resource_requirement_empty.setObjectName("filterSummary")
        self._resource_requirement_empty.setWordWrap(True)
        self._resource_requirement_empty.setMinimumHeight(scale_px(22, self._ui_scale))
        aggregate_options_layout.addWidget(self._resource_requirement_empty)
        right_layout.addWidget(self._resource_right_top_controls, 0)

        self._resource_requirement_scroll = QScrollArea()
        self._resource_requirement_scroll.setObjectName("sectionScrollArea")
        self._resource_requirement_scroll.setFrameShape(QFrame.NoFrame)
        self._resource_requirement_scroll.setWidgetResizable(True)
        self._resource_requirement_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._resource_requirement_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self._resource_requirement_scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        _install_planner_scroll_handle(self._resource_requirement_scroll, ui_scale=self._ui_scale)

        self._resource_requirement_grid_host = QWidget()
        self._resource_requirement_grid_host.setObjectName("planTransparent")
        self._resource_requirement_grid_host.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self._resource_requirement_grid = QGridLayout(self._resource_requirement_grid_host)
        self._resource_requirement_grid.setContentsMargins(
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
        )
        self._resource_requirement_grid.setHorizontalSpacing(scale_px(8, self._ui_scale))
        self._resource_requirement_grid.setVerticalSpacing(scale_px(8, self._ui_scale))
        self._resource_requirement_grid.setAlignment(Qt.AlignTop)
        for column in range(3):
            self._resource_requirement_grid.setColumnStretch(column, 1)
        self._resource_requirement_scroll.setWidget(self._resource_requirement_grid_host)
        self._resource_requirement_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        requirement_grid_panel_layout = QVBoxLayout(self._resource_requirement_grid_panel)
        requirement_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        requirement_grid_panel_layout.setSpacing(0)
        requirement_grid_panel_layout.addWidget(self._resource_requirement_scroll, 1)
        right_layout.addWidget(self._resource_requirement_grid_panel, 1)

        splitter.addWidget(left_panel)
        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 1)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([scale_px(720, self._ui_scale), scale_px(720, self._ui_scale)])
        layout.addWidget(splitter, 1)

        self._sync_resource_controls_from_students()
        self._refresh_resource_students_list()
        self._refresh_resource_view()
        QTimer.singleShot(0, self._sync_resource_result_start)
        self._resources_dirty = False

    def _inventory_panel_margin(self) -> int:
        return scale_px(14, self._ui_scale)

    def _inventory_panel_gap(self) -> int:
        return scale_px(10, self._ui_scale)

    def _configure_inventory_panel_layout(
        self,
        layout: QHBoxLayout | QVBoxLayout | QGridLayout,
        *,
        margin: int | None = None,
        spacing: int | None = None,
    ) -> None:
        panel_margin = self._inventory_panel_margin() if margin is None else margin
        panel_spacing = self._inventory_panel_gap() if spacing is None else spacing
        layout.setContentsMargins(panel_margin, panel_margin, panel_margin, panel_margin)
        layout.setSpacing(panel_spacing)

    def _build_inventory_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(4, self._ui_scale))

        title = QLabel(_tr("inventory.title"))
        title.setObjectName("title")
        header_layout.addWidget(title)

        subtitle = QLabel(_tr("inventory.subtitle"))
        subtitle.setObjectName("count")
        subtitle.setWordWrap(True)
        header_layout.addWidget(subtitle)

        self._inventory_summary = QLabel(_tr("inventory.empty"))
        self._inventory_summary.setObjectName("filterSummary")
        self._inventory_summary.setWordWrap(True)
        header_layout.addWidget(self._inventory_summary)

        layout.addWidget(header)

        self._inventory_root_tabs = RoundedMaskTabWidget(ui_scale=self._ui_scale)
        self._inventory_root_tabs.setObjectName("inventoryRootTabs")
        self._inventory_root_tabs.tabBar().hide()
        self._inventory_root_tabs.currentChanged.connect(self._sync_inventory_mode_buttons)
        self._inventory_root_buttons: dict[int, QPushButton] = {}
        self._inventory_equipment_lists: dict[str, QListWidget] = {}
        self._inventory_equipment_summaries: dict[str, QLabel] = {}
        self._inventory_item_lists: dict[str, QListWidget] = {}
        self._inventory_item_summaries: dict[str, QLabel] = {}
        self._inventory_oopart_plan_usage: dict[str, InventoryOpartPlanUsage] = {}
        self._inventory_oopart_selected_id: str | None = None
        self._inventory_pool_pressure_mode = "equipment"
        self._inventory_pool_pressure_buttons: dict[str, QPushButton] = {}
        self._inventory_requirement_index: dict[str, PlanResourceRequirement] = {}
        self._inventory_pool_requirement_index: dict[str, PlanResourceRequirement] = {}

        equipment_root = QWidget()
        equipment_layout = QVBoxLayout(equipment_root)
        self._configure_inventory_panel_layout(equipment_layout, margin=0)
        self._inventory_equipment_tabs = InventorySubTabWidget(ui_scale=self._ui_scale)
        self._inventory_equipment_tabs.setObjectName("inventorySubTabs")
        self._inventory_equipment_tabs.tabBar().setObjectName("inventorySubTabBar")

        for series in EQUIPMENT_SERIES:
            series_label = _equipment_series_label(series.icon_key)
            tab = QWidget()
            tab.setObjectName("inventoryPaneContent")
            tab.setAutoFillBackground(False)
            tab.setAttribute(Qt.WA_TranslucentBackground, True)
            tab_layout = QVBoxLayout(tab)
            self._configure_inventory_panel_layout(tab_layout)

            summary = QLabel(_tr("inventory.no_scanned_category"))

            tab_layout.addWidget(InventoryColumnHeader(ui_scale=self._ui_scale))

            item_list = RoundedListWidget(ui_scale=self._ui_scale)
            item_list.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            item_list.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            item_list.currentItemChanged.connect(self._on_inventory_item_changed)
            tab_layout.addWidget(item_list, 1)
            self._inventory_equipment_tabs.addTab(tab, series_label)
            self._inventory_equipment_lists[series.icon_key] = item_list
            self._inventory_equipment_summaries[series.icon_key] = summary

        equipment_layout.addWidget(self._inventory_equipment_tabs, 1)
        self._inventory_root_tabs.addTab(equipment_root, _tr("inventory.root_equipment"))

        item_root = QWidget()
        item_layout = QVBoxLayout(item_root)
        self._configure_inventory_panel_layout(item_layout, margin=0)
        self._inventory_item_tabs = InventorySubTabWidget(ui_scale=self._ui_scale)
        self._inventory_item_tabs.setObjectName("inventorySubTabs")
        self._inventory_item_tabs.tabBar().setObjectName("inventorySubTabBar")

        for key, label in (
            ("ooparts", _tr("inventory.category.ooparts")),
            ("wb", _tr("inventory.category.wb")),
            ("stones", _tr("inventory.category.stones")),
            ("reports", _tr("inventory.category.reports")),
            ("weapon_parts", _tr("inventory.category.weapon_parts")),
            ("tech_notes", _tr("inventory.category.tech_notes")),
            ("bd", _tr("inventory.category.bd")),
            ("resources", _tr("inventory.category.resources")),
            ("other", _tr("inventory.category.other")),
        ):
            tab = QWidget()
            tab.setObjectName("inventoryPaneContent")
            tab.setAutoFillBackground(False)
            tab.setAttribute(Qt.WA_TranslucentBackground, True)
            tab_layout = QVBoxLayout(tab)
            self._configure_inventory_panel_layout(tab_layout)

            summary = QLabel(_tr("inventory.no_scanned_category"))

            tab_layout.addWidget(InventoryColumnHeader(ui_scale=self._ui_scale))

            item_list = RoundedListWidget(ui_scale=self._ui_scale)
            item_list.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            item_list.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            item_list.currentItemChanged.connect(self._on_inventory_item_changed)
            if key == "ooparts":
                item_list.currentItemChanged.connect(self._on_inventory_oopart_changed)
            tab_layout.addWidget(item_list, 1)
            self._inventory_item_tabs.addTab(tab, label)
            self._inventory_item_lists[key] = item_list
            self._inventory_item_summaries[key] = summary

        item_layout.addWidget(self._inventory_item_tabs, 1)
        self._inventory_root_tabs.addTab(item_root, _tr("inventory.root_items"))

        inventory_mode_panel = RoundedMaskFrame(ui_scale=self._ui_scale)
        inventory_mode_panel.setObjectName("inventoryContentPanel")
        inventory_mode_layout = QVBoxLayout(inventory_mode_panel)
        self._configure_inventory_panel_layout(inventory_mode_layout)

        inventory_mode_buttons = QHBoxLayout()
        inventory_mode_buttons.setContentsMargins(0, 0, 0, 0)
        inventory_mode_buttons.setSpacing(scale_px(8, self._ui_scale))
        for index, label in ((0, _tr("inventory.root_equipment")), (1, _tr("inventory.root_items"))):
            button = QPushButton(label)
            button.setObjectName("inventoryModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=index: self._set_inventory_root_mode(value))
            inventory_mode_buttons.addWidget(button, 0)
            self._inventory_root_buttons[index] = button
        inventory_mode_buttons.addStretch(1)
        sort_label = QLabel(_tr("inventory.sort_label"))
        sort_label.setObjectName("detailMiniSub")
        inventory_mode_buttons.addWidget(sort_label, 0, Qt.AlignVCenter)
        self._inventory_material_sort_mode = InventorySortDropdownButton()
        self._inventory_material_sort_mode.addItem(_tr("inventory.sort_category"), "category_tier_desc")
        self._inventory_material_sort_mode.addItem(_tr("inventory.sort_tier"), "tier_desc")
        self._inventory_material_sort_mode.modeChanged.connect(lambda *_: self._refresh_inventory_tab())
        inventory_mode_buttons.addWidget(self._inventory_material_sort_mode, 0, Qt.AlignVCenter)
        inventory_mode_layout.addLayout(inventory_mode_buttons)
        inventory_mode_layout.addWidget(self._inventory_root_tabs, 1)
        self._sync_inventory_mode_buttons()

        inventory_splitter = QSplitter(Qt.Horizontal)
        inventory_splitter.setObjectName("inventorySplitter")
        inventory_splitter.setChildrenCollapsible(False)

        overview_panel = QFrame()
        overview_panel.setObjectName("planSectionPanel")
        overview_panel.setMinimumWidth(scale_px(260, self._ui_scale))
        overview_layout = QVBoxLayout(overview_panel)
        self._configure_inventory_panel_layout(overview_layout)

        pressure_panel = QFrame()
        pressure_panel.setObjectName("planBand")
        pressure_layout = QVBoxLayout(pressure_panel)
        pressure_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(9, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        pressure_layout.setSpacing(scale_px(8, self._ui_scale))
        insight_title = QLabel(_tr("inventory.pressure_title"))
        insight_title.setObjectName("sectionTitle")
        pressure_layout.addWidget(insight_title)

        self._inventory_insight_summary = QLabel(_tr("inventory.pressure_empty"))
        self._inventory_insight_summary.setObjectName("detailSub")
        self._inventory_insight_summary.setTextFormat(Qt.RichText)
        self._inventory_insight_summary.setWordWrap(True)
        pressure_layout.addWidget(self._inventory_insight_summary)
        overview_layout.addWidget(pressure_panel, 0)

        plan_priority_panel = QFrame()
        plan_priority_panel.setObjectName("planBand")
        plan_priority_panel.setFixedHeight(scale_px(230, self._ui_scale))
        plan_priority_layout = QVBoxLayout(plan_priority_panel)
        plan_priority_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        plan_priority_layout.setSpacing(scale_px(6, self._ui_scale))
        plan_priority_title = QLabel(_tr("inventory.plan_shortage_top"))
        plan_priority_title.setObjectName("detailSectionTitle")
        plan_priority_layout.addWidget(plan_priority_title)
        self._inventory_plan_priority_list = InventoryPriorityListWidget(ui_scale=self._ui_scale)
        self._configure_inventory_priority_cards(self._inventory_plan_priority_list)
        self._inventory_plan_priority_list.currentItemChanged.connect(self._on_inventory_priority_changed)
        plan_priority_layout.addWidget(self._inventory_plan_priority_list, 1)
        overview_layout.addWidget(plan_priority_panel, 0)

        pool_pressure_panel = QFrame()
        pool_pressure_panel.setObjectName("planBand")
        pool_pressure_panel.setFixedHeight(scale_px(230, self._ui_scale))
        pool_pressure_layout = QVBoxLayout(pool_pressure_panel)
        pool_pressure_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        pool_pressure_layout.setSpacing(scale_px(6, self._ui_scale))
        pool_pressure_header = QHBoxLayout()
        pool_pressure_header.setContentsMargins(0, 0, 0, 0)
        pool_pressure_header.setSpacing(scale_px(5, self._ui_scale))
        pool_pressure_title = QLabel(_tr("inventory.full_pool_top"))
        pool_pressure_title.setObjectName("detailSectionTitle")
        pool_pressure_header.addWidget(pool_pressure_title, 1, Qt.AlignVCenter)
        for mode, label in (("equipment", "장비"), ("ooparts", "오파츠")):
            button = QPushButton(label)
            button.setObjectName("inventoryMiniModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=mode: self._set_inventory_pool_pressure_mode(value))
            self._inventory_pool_pressure_buttons[mode] = button
            pool_pressure_header.addWidget(button, 0, Qt.AlignVCenter)
        pool_pressure_layout.addLayout(pool_pressure_header)
        self._sync_inventory_pool_pressure_buttons()
        self._inventory_pool_pressure_list = InventoryPriorityListWidget(ui_scale=self._ui_scale)
        self._configure_inventory_priority_cards(self._inventory_pool_pressure_list)
        self._inventory_pool_pressure_list.currentItemChanged.connect(self._on_inventory_priority_changed)
        pool_pressure_layout.addWidget(self._inventory_pool_pressure_list, 1)
        overview_layout.addWidget(pool_pressure_panel, 0)

        bottleneck_panel = QFrame()
        bottleneck_panel.setObjectName("planBand")
        bottleneck_layout = QVBoxLayout(bottleneck_panel)
        bottleneck_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        bottleneck_layout.setSpacing(scale_px(6, self._ui_scale))
        bottleneck_layout.setAlignment(Qt.AlignTop)
        bottleneck_title = QLabel(_tr("inventory.common_bottleneck"))
        bottleneck_title.setObjectName("detailSectionTitle")
        bottleneck_layout.addWidget(bottleneck_title)
        self._inventory_bottleneck_rows = QWidget()
        self._inventory_bottleneck_rows.setObjectName("planTransparent")
        self._inventory_bottleneck_rows_layout = QVBoxLayout(self._inventory_bottleneck_rows)
        self._inventory_bottleneck_rows_layout.setContentsMargins(0, scale_px(8, self._ui_scale), 0, 0)
        self._inventory_bottleneck_rows_layout.setSpacing(scale_px(7, self._ui_scale))
        bottleneck_layout.addWidget(self._inventory_bottleneck_rows, 0)

        school_panel = QFrame()
        self._inventory_school_risk_panel = school_panel
        school_panel.setObjectName("planBand")
        school_panel.setFixedHeight(scale_px(126, self._ui_scale))
        school_layout = QVBoxLayout(school_panel)
        school_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(7, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(7, self._ui_scale),
        )
        school_layout.setSpacing(scale_px(5, self._ui_scale))
        school_layout.setAlignment(Qt.AlignTop)
        school_title = QLabel(_tr("inventory.school_shortage"))
        school_title.setObjectName("detailSectionTitle")
        school_layout.addWidget(school_title)
        self._inventory_school_risk_rows_host = QWidget()
        self._inventory_school_risk_rows_host.setObjectName("planTransparent")
        self._inventory_school_risk_rows_layout = QVBoxLayout(self._inventory_school_risk_rows_host)
        self._inventory_school_risk_rows_layout.setContentsMargins(0, 0, 0, 0)
        self._inventory_school_risk_rows_layout.setSpacing(scale_px(5, self._ui_scale))
        school_layout.addWidget(self._inventory_school_risk_rows_host, 0)

        lower_pressure_stack = QWidget()
        lower_pressure_stack.setObjectName("planTransparent")
        lower_pressure_layout = QVBoxLayout(lower_pressure_stack)
        lower_pressure_layout.setContentsMargins(0, 0, 0, 0)
        lower_pressure_layout.setSpacing(scale_px(10, self._ui_scale))
        lower_pressure_layout.addWidget(bottleneck_panel, 1)
        lower_pressure_layout.addWidget(school_panel, 0)
        overview_layout.addWidget(lower_pressure_stack, 1)

        detail_shell = QFrame()
        detail_shell.setObjectName("planSectionPanel")
        detail_shell.setMinimumWidth(scale_px(360, self._ui_scale))
        detail_shell_layout = QVBoxLayout(detail_shell)
        self._configure_inventory_panel_layout(detail_shell_layout)

        detail_scroll = QScrollArea()
        detail_scroll.setObjectName("sectionScrollArea")
        detail_scroll.setFrameShape(QFrame.NoFrame)
        detail_scroll.setWidgetResizable(True)
        detail_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        detail_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)

        detail_panel = QWidget()
        detail_panel.setObjectName("planTransparent")
        detail_panel.setMinimumWidth(scale_px(320, self._ui_scale))
        detail_layout = QVBoxLayout(detail_panel)
        self._configure_inventory_panel_layout(detail_layout, margin=0)
        detail_scroll.setWidget(detail_panel)
        detail_shell_layout.addWidget(detail_scroll, 1)

        def build_detail_card() -> tuple[QFrame, QVBoxLayout]:
            card = QFrame()
            card.setObjectName("planBand")
            card_layout = QVBoxLayout(card)
            card_layout.setContentsMargins(
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
            )
            card_layout.setSpacing(scale_px(8, self._ui_scale))
            return card, card_layout

        def add_detail_metric_rows(parent_layout: QVBoxLayout, rows: tuple[tuple[str, str], ...]) -> None:
            table = QGridLayout()
            table.setContentsMargins(0, 0, 0, 0)
            table.setHorizontalSpacing(scale_px(8, self._ui_scale))
            table.setVerticalSpacing(scale_px(6, self._ui_scale))
            table.setColumnStretch(0, 1)
            table.setColumnMinimumWidth(1, scale_px(118, self._ui_scale))
            for row, (key, label) in enumerate(rows):
                name_label = QLabel(label)
                name_label.setObjectName("detailMiniSub")
                value_label = QLabel("-")
                value_label.setObjectName("inventoryDetailMetricValue")
                value_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
                value_label.setMinimumWidth(scale_px(118, self._ui_scale))
                self._inventory_oopart_metric_labels[key] = value_label
                table.addWidget(name_label, row, 0)
                table.addWidget(value_label, row, 1)
            parent_layout.addLayout(table)

        self._inventory_oopart_metric_labels: dict[str, QLabel] = {}

        plan_detail_card, plan_detail_layout = build_detail_card()
        detail_header = QWidget()
        detail_header.setObjectName("planTransparent")
        detail_header_layout = QHBoxLayout(detail_header)
        detail_header_layout.setContentsMargins(0, 0, 0, 0)
        detail_header_layout.setSpacing(scale_px(10, self._ui_scale))
        self._inventory_oopart_detail_icon = QLabel()
        self._inventory_oopart_detail_icon.setFixedSize(scale_px(48, self._ui_scale), scale_px(48, self._ui_scale))
        self._inventory_oopart_detail_icon.setAlignment(Qt.AlignCenter)
        detail_header_layout.addWidget(self._inventory_oopart_detail_icon, 0, Qt.AlignVCenter)
        detail_title_stack = QVBoxLayout()
        detail_title_stack.setContentsMargins(0, 0, 0, 0)
        detail_title_stack.setSpacing(scale_px(4, self._ui_scale))
        self._inventory_oopart_detail_title = QLabel(_tr("inventory.detail.select_oopart"))
        self._inventory_oopart_detail_title.setObjectName("sectionTitle")
        detail_title_stack.addWidget(self._inventory_oopart_detail_title)
        self._inventory_oopart_detail_meta = QLabel("")
        self._inventory_oopart_detail_meta.setObjectName("inventoryStatus")
        self._inventory_oopart_detail_meta.setAlignment(Qt.AlignCenter)
        self._inventory_oopart_detail_meta.setVisible(False)
        detail_title_stack.addWidget(self._inventory_oopart_detail_meta, 0, Qt.AlignLeft)
        detail_header_layout.addLayout(detail_title_stack, 1)
        plan_detail_layout.addWidget(detail_header)
        add_detail_metric_rows(
            plan_detail_layout,
            (
                ("owned", _tr("inventory.detail.owned")),
                ("required", _tr("inventory.detail.plan_need")),
                ("shortage", _tr("inventory.detail.plan_short")),
                ("coverage", _tr("inventory.detail.plan_coverage")),
            ),
        )
        detail_layout.addWidget(plan_detail_card, 0)

        pool_detail_card, pool_detail_layout = build_detail_card()
        pool_title = QLabel(_tr("inventory.detail.full_growth"))
        pool_title.setObjectName("detailSectionTitle")
        pool_detail_layout.addWidget(pool_title)
        add_detail_metric_rows(
            pool_detail_layout,
            (
                ("pool_required", _tr("inventory.detail.full_pool_need")),
                ("pool_shortage", _tr("inventory.detail.pool_left")),
                ("pool_coverage", _tr("inventory.detail.full_coverage")),
            ),
        )
        detail_layout.addWidget(pool_detail_card, 0)

        hint_card, hint_layout = build_detail_card()
        hint_title = QLabel(_tr("inventory.detail.decision_hints"))
        hint_title.setObjectName("detailSectionTitle")
        hint_layout.addWidget(hint_title)
        self._inventory_oopart_next_hint = QLabel("-")
        self._inventory_oopart_next_hint.setObjectName("inventoryHintPink")
        self._inventory_oopart_next_hint.setWordWrap(True)
        hint_layout.addWidget(self._inventory_oopart_next_hint)
        self._inventory_oopart_farm_hint = QLabel("-")
        self._inventory_oopart_farm_hint.setObjectName("inventoryHintBlue")
        self._inventory_oopart_farm_hint.setWordWrap(True)
        hint_layout.addWidget(self._inventory_oopart_farm_hint)
        detail_layout.addWidget(hint_card, 0)

        student_card, student_layout = build_detail_card()
        affected_value = QLabel("-")
        affected_value.setObjectName("inventoryDetailMetricValue")
        affected_value.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        self._inventory_oopart_metric_labels["affected"] = affected_value
        student_layout.addWidget(affected_value)
        breakdown_title = QLabel(_tr("inventory.detail.student_breakdown"))
        breakdown_title.setObjectName("detailSectionTitle")
        student_layout.addWidget(breakdown_title)

        self._inventory_oopart_impact_list = RoundedListWidget(ui_scale=self._ui_scale)
        self._inventory_oopart_impact_list.setIconSize(QSize(scale_px(34, self._ui_scale), scale_px(34, self._ui_scale)))
        self._inventory_oopart_impact_list.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self._inventory_oopart_impact_list.setFixedHeight(scale_px(80, self._ui_scale))
        self._inventory_oopart_impact_list.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._inventory_oopart_impact_list.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        student_layout.addWidget(self._inventory_oopart_impact_list, 0)
        detail_layout.addWidget(student_card, 0)

        self._inventory_oopart_detail_summary = QLabel(_tr("inventory.detail.pick_item"))
        self._inventory_oopart_detail_summary.setVisible(False)
        self._inventory_oopart_family_shortage = QLabel("-")
        self._inventory_oopart_family_shortage.setVisible(False)

        inventory_splitter.addWidget(overview_panel)
        inventory_splitter.addWidget(inventory_mode_panel)
        inventory_splitter.addWidget(detail_shell)
        inventory_splitter.setStretchFactor(0, 1)
        inventory_splitter.setStretchFactor(1, 5)
        inventory_splitter.setStretchFactor(2, 1)
        inventory_splitter.setSizes([
            scale_px(260, self._ui_scale),
            scale_px(1180, self._ui_scale),
            scale_px(360, self._ui_scale),
        ])
        layout.addWidget(inventory_splitter, 1)
        self._refresh_inventory_tab()

    def _set_inventory_root_mode(self, index: int) -> None:
        if hasattr(self, "_inventory_root_tabs"):
            self._inventory_root_tabs.setCurrentIndex(index)
        self._sync_inventory_mode_buttons()

    def _sync_inventory_mode_buttons(self, *_args) -> None:
        buttons = getattr(self, "_inventory_root_buttons", {})
        tabs = getattr(self, "_inventory_root_tabs", None)
        current = tabs.currentIndex() if tabs is not None else 0
        for index, button in buttons.items():
            button.blockSignals(True)
            button.setChecked(index == current)
            button.blockSignals(False)

    def _set_inventory_pool_pressure_mode(self, mode: str) -> None:
        if mode not in {"equipment", "ooparts"}:
            mode = "equipment"
        self._inventory_pool_pressure_mode = mode
        self._sync_inventory_pool_pressure_buttons()
        if hasattr(self, "_inventory_pool_pressure_list"):
            self._refresh_inventory_insight_panel()

    def _sync_inventory_pool_pressure_buttons(self) -> None:
        mode = getattr(self, "_inventory_pool_pressure_mode", "equipment")
        for key, button in getattr(self, "_inventory_pool_pressure_buttons", {}).items():
            button.blockSignals(True)
            button.setChecked(key == mode)
            button.blockSignals(False)

    def _sync_resource_controls_from_students(self) -> None:
        if not hasattr(self, "_resource_search"):
            return
        self._resource_syncing_controls = True
        try:
            if self._resource_search.text() != self._search.text():
                self._resource_search.setText(self._search.text())
            target_sort = self._sort_mode.currentData()
            self._resource_sort_mode.setCurrentData(str(target_sort))
            self._resource_show_unowned.setChecked(self._show_unowned.isChecked())
            self._resource_hide_jp_only.setChecked(self._hide_jp_only.isChecked())
            self._resource_filter_summary.setText(self._filter_summary.text())
            self._resource_filter_button.setText(self._filter_button.text())
        finally:
            self._resource_syncing_controls = False
        QTimer.singleShot(0, self._sync_resource_result_start)

    def _set_resource_left_mode(self, index: int) -> None:
        index = 0 if index <= 0 else 1
        if hasattr(self, "_resource_left_stack"):
            self._resource_left_stack.setCurrentIndex(index)
        if hasattr(self, "_resource_left_top_stack"):
            self._resource_left_top_stack.setCurrentIndex(index)
        for button_index, button in getattr(self, "_resource_mode_buttons", {}).items():
            button.blockSignals(True)
            button.setChecked(button_index == index)
            button.blockSignals(False)
        QTimer.singleShot(0, self._sync_resource_result_start)

    def _sync_resource_result_start(self) -> None:
        required = (
            "_resource_left_top_panel",
            "_resource_left_header_host",
            "_resource_left_stack",
            "_resource_left_top_stack",
            "_resource_scope_top_controls",
            "_resource_search_top_controls",
            "_resource_right_top_controls",
        )
        if not all(hasattr(self, name) for name in required):
            return
        active_top = (
            self._resource_search_top_controls
            if self._resource_left_stack.currentIndex() == 1
            else self._resource_scope_top_controls
        )
        left_header_height = self._resource_left_header_host.sizeHint().height()
        left_vertical_margins = scale_px(20, self._ui_scale)
        left_gap = scale_px(8, self._ui_scale)
        left_natural_height = left_vertical_margins + left_header_height + left_gap + active_top.sizeHint().height()
        target_height = max(left_natural_height, self._resource_right_top_controls.sizeHint().height())
        active_height = max(1, target_height - left_vertical_margins - left_header_height - left_gap)
        active_top.setFixedHeight(active_height)
        self._resource_left_top_stack.setFixedHeight(active_height)
        self._resource_left_top_panel.setFixedHeight(max(1, target_height))
        self._resource_right_top_controls.setFixedHeight(max(1, target_height))

    def _on_resource_requirement_sort_changed(self, _value: object) -> None:
        selector = getattr(self, "_resource_requirement_sort", None)
        self._resource_requirement_sort_mode = selector.currentData() if selector is not None else "default"
        self._refresh_resource_view()

    def _on_resource_search_changed(self, text: str) -> None:
        if self._resource_syncing_controls:
            return
        if self._search.text() != text:
            self._search.setText(text)

    def _on_resource_sort_changed(self, _value: object) -> None:
        if self._resource_syncing_controls:
            return
        target_sort = self._resource_sort_mode.currentData()
        if self._sort_mode.currentData() == target_sort:
            return
        self._sort_mode.setCurrentData(str(target_sort))

    def _on_resource_show_unowned_changed(self, _state: int) -> None:
        if self._resource_syncing_controls:
            return
        checked = self._resource_show_unowned.isChecked()
        if self._show_unowned.isChecked() != checked:
            self._show_unowned.setChecked(checked)

    def _on_resource_hide_jp_only_changed(self, _state: int) -> None:
        if self._resource_syncing_controls:
            return
        checked = self._resource_hide_jp_only.isChecked()
        if self._hide_jp_only.isChecked() != checked:
            self._hide_jp_only.setChecked(checked)

    def _resource_compact_cost_text(self, summary: PlanCostSummary | None) -> str:
        if summary is None:
            return "아직 계획 목표 없음"
        total_materials = sum(summary.star_materials.values()) + sum(summary.equipment_materials.values()) + sum(summary.skill_books.values()) + sum(summary.ex_ooparts.values()) + sum(summary.skill_ooparts.values()) + sum(summary.favorite_item_materials.values()) + sum(summary.stat_materials.values())
        return (
            f"크레딧 {_format_count(summary.credits, compact=True)} · "
            f"EXP {_format_count(summary.level_exp, compact=True)} · "
            f"재화 {_format_count(total_materials, compact=True)}"
        )

    def _resource_focus_label(
        self,
        record: StudentRecord,
        summary: PlanCostSummary | None,
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> str:
        goal_map = self._plan_goal_map() if goal_map is None else goal_map
        status = []
        status.append("계획됨" if record.student_id in goal_map else "미계획")
        status.append("보유" if record.owned else "미보유")
        if summary is None:
            return " · ".join(status)
        buckets = [
            ("스킬", sum(summary.skill_books.values()) + sum(summary.ex_ooparts.values()) + sum(summary.skill_ooparts.values())),
            ("장비", sum(summary.equipment_materials.values())),
            ("성급", sum(summary.star_materials.values())),
            ("애용품", sum(summary.favorite_item_materials.values())),
            ("능력개방", sum(summary.stat_materials.values())),
        ]
        label, amount = max(buckets, key=lambda item: item[1])
        if amount > 0:
            status.append(f"{label} 중심")
        return " · ".join(status)

    def _resource_goal_for_student(
        self,
        student_id: str,
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> StudentGoal | None:
        goal_map = self._plan_goal_map() if goal_map is None else goal_map
        return goal_map.get(student_id)

    def _resource_summary_for_student(
        self,
        student_id: str,
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> PlanCostSummary | None:
        record = self._records_by_id.get(student_id)
        goal = self._resource_goal_for_student(student_id, goal_map)
        if record is None or goal is None:
            return None
        return self._cached_goal_cost(student_id, record=record, goal=goal)

    def _resource_unplanned_goal_for_student(self, student_id: str) -> StudentGoal | None:
        if not (
            self._resource_include_unplanned_level
            or self._resource_include_unplanned_equipment
            or self._resource_include_unplanned_skills
        ):
            return None
        record = self._records_by_id.get(student_id)
        if record is None:
            return None
        goal = StudentGoal(student_id=student_id)
        if self._resource_include_unplanned_level:
            goal.target_level = MAX_TARGET_LEVEL
        if self._resource_include_unplanned_equipment:
            goal.target_equip1_tier = MAX_TARGET_EQUIP_TIER
            goal.target_equip2_tier = MAX_TARGET_EQUIP_TIER
            goal.target_equip3_tier = MAX_TARGET_EQUIP_TIER
            goal.target_equip1_level = MAX_TARGET_EQUIP_LEVEL
            goal.target_equip2_level = MAX_TARGET_EQUIP_LEVEL
            goal.target_equip3_level = MAX_TARGET_EQUIP_LEVEL
            if self._record_supports_unique_item(record):
                goal.target_equip4_tier = MAX_TARGET_EQUIP4_TIER
        if self._resource_include_unplanned_skills:
            goal.target_ex_skill = MAX_TARGET_EX_SKILL
            goal.target_skill1 = MAX_TARGET_SKILL
            goal.target_skill2 = MAX_TARGET_SKILL
            goal.target_skill3 = MAX_TARGET_SKILL
        return goal

    def _resource_current_student(self) -> str | None:
        if hasattr(self, "_resource_scope_grid"):
            return self._resource_scope_grid.current_card_id()
        return None

    def _refresh_resource_students_list(self) -> None:
        if not hasattr(self, "_resource_scope_grid"):
            return
        current_id = self._resource_current_student_id or self._resource_current_student()
        old_scope_cards = dict(self._resource_scope_card_by_id)
        old_search_cards = dict(self._resource_search_card_by_id)

        goal_map = self._plan_goal_map()
        visible_ids = {record.student_id for record in self._filtered_students}
        self._resource_search_pending_ids &= visible_ids
        selected_records = [
            self._records_by_id[student_id]
            for student_id in self._resource_selected_ids
            if student_id in self._records_by_id
        ]
        selected_records.sort(key=lambda record: record.title.lower())
        planned_count = sum(1 for record in selected_records if record.student_id in goal_map)

        scope_cards: list[StudentCardWidget] = []
        next_scope_by_id: dict[str, StudentCardWidget] = {}
        for record in selected_records:
            card = old_scope_cards.get(record.student_id)
            if card is None:
                card = self._build_student_card(record)
            else:
                self._apply_student_card_record(card, record)
            card.setDisplayOptions(show_name_panel=False, show_unowned_badge=True)
            scope_cards.append(card)
            next_scope_by_id[record.student_id] = card

        self._resource_scope_card_by_id = next_scope_by_id
        self._resource_scope_grid.set_cards(scope_cards)

        if scope_cards:
            restore_id = current_id if current_id in self._resource_scope_card_by_id else selected_records[0].student_id
            self._resource_scope_grid.set_current_card(restore_id)
            self._resource_current_student_id = restore_id
        else:
            self._resource_scope_grid.set_current_card(None)
            self._resource_current_student_id = None

        visible_planned = sum(1 for record in self._filtered_students if record.student_id in goal_map)
        search_cards: list[StudentCardWidget] = []
        next_search_by_id: dict[str, StudentCardWidget] = {}
        for record in self._filtered_students:
            card = old_search_cards.get(record.student_id)
            if card is None:
                card = self._build_student_card(record)
            else:
                self._apply_student_card_record(card, record)
            card.setDisplayOptions(show_name_panel=False, show_unowned_badge=True)
            card.setToolTip("")
            search_cards.append(card)
            next_search_by_id[record.student_id] = card

        self._resource_search_card_by_id = next_search_by_id
        self._resource_search_grid.set_cards(search_cards)
        self._resource_search_grid.set_selected_card_ids(set(self._resource_search_pending_ids))

        self._resource_list_summary.setText(
            f"범위 {len(selected_records)}명 · 계획 {planned_count}명 · 미계획 {len(selected_records) - planned_count}명"
        )
        if hasattr(self, "_resource_search_summary"):
            visible_selected = len(self._resource_selected_ids & {record.student_id for record in self._filtered_students})
            pending_count = len(self._resource_search_pending_ids)
            self._resource_search_summary.setText(
                f"검색 결과 {len(self._filtered_students)}명 · 계획 {visible_planned}명 · 이미 범위에 있음 {visible_selected}명 · 선택 {pending_count}명"
            )
        self._update_resource_scope_actions()
        self._update_resource_search_actions()
        for record in selected_records:
            self._enqueue_thumb(record.student_id)
        for record in self._filtered_students:
            self._enqueue_thumb(record.student_id)
        QTimer.singleShot(0, self._sync_resource_result_start)

    def _on_resource_scope_card_changed(self, current: str | None, _previous: str | None) -> None:
        self._resource_current_student_id = current
        self._update_resource_scope_actions()

    def _on_resource_search_selection_changed(self, selected_ids: object) -> None:
        if isinstance(selected_ids, set):
            self._resource_search_pending_ids = {str(student_id) for student_id in selected_ids}
        else:
            self._resource_search_pending_ids = set()
        self._refresh_resource_search_summary()
        self._update_resource_search_actions()

    def _refresh_resource_search_summary(self) -> None:
        if not hasattr(self, "_resource_search_summary"):
            return
        goal_map = self._plan_goal_map()
        visible_planned = sum(1 for record in self._filtered_students if record.student_id in goal_map)
        visible_selected = len(self._resource_selected_ids & {record.student_id for record in self._filtered_students})
        self._resource_search_summary.setText(
            f"검색 결과 {len(self._filtered_students)}명 · 계획 {visible_planned}명 · 이미 범위에 있음 {visible_selected}명 · 선택 {len(self._resource_search_pending_ids)}명"
        )
        QTimer.singleShot(0, self._sync_resource_result_start)

    def _update_resource_scope_actions(self) -> None:
        if hasattr(self, "_resource_remove_scope_button"):
            self._resource_remove_scope_button.setEnabled(bool(self._resource_current_student()))

    def _update_resource_search_actions(self) -> None:
        if hasattr(self, "_resource_add_selected_button"):
            self._resource_add_selected_button.setEnabled(bool(self._resource_search_pending_ids))

    def _on_resource_unplanned_options_changed(self, _state: int) -> None:
        self._resource_include_unplanned_level = self._resource_unplanned_level.isChecked()
        self._resource_include_unplanned_equipment = self._resource_unplanned_equipment.isChecked()
        self._resource_include_unplanned_skills = self._resource_unplanned_skills.isChecked()
        self._refresh_resource_view()

    def _resource_add_pending_to_scope(self) -> None:
        if not self._resource_search_pending_ids:
            return
        self._resource_selected_ids.update(self._resource_search_pending_ids)
        self._resource_search_pending_ids.clear()
        self._set_resource_left_mode(0)
        self._refresh_resource_students_list()
        self._refresh_resource_view()

    def _resource_remove_scope_selected(self) -> None:
        student_id = self._resource_current_student()
        if not student_id:
            return
        self._resource_selected_ids.discard(student_id)
        self._resource_search_pending_ids.discard(student_id)
        self._resource_current_student_id = None
        self._refresh_resource_students_list()
        self._refresh_resource_view()

    def _resource_clear_search_selection(self) -> None:
        self._resource_search_pending_ids.clear()
        if hasattr(self, "_resource_search_grid"):
            self._resource_search_grid.set_selected_card_ids(set())
        self._refresh_resource_search_summary()
        self._update_resource_search_actions()

    def _resource_check_visible(self) -> None:
        self._resource_selected_ids.update(record.student_id for record in self._filtered_students)
        self._resource_search_pending_ids.clear()
        self._set_resource_left_mode(0)
        self._refresh_resource_students_list()
        self._refresh_resource_view()

    def _resource_check_visible_planned(self) -> None:
        goal_map = self._plan_goal_map()
        self._resource_selected_ids.update(record.student_id for record in self._filtered_students if record.student_id in goal_map)
        self._resource_search_pending_ids.clear()
        self._set_resource_left_mode(0)
        self._refresh_resource_students_list()
        self._refresh_resource_view()

    def _resource_clear_checked(self) -> None:
        self._resource_selected_ids.clear()
        self._resource_search_pending_ids.clear()
        self._resource_current_student_id = None
        self._refresh_resource_students_list()
        self._refresh_resource_view()

    def _resource_total_for_ids(
        self,
        student_ids: list[str] | tuple[str, ...] | set[str],
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> tuple[PlanCostSummary, int, int]:
        goal_map = self._plan_goal_map() if goal_map is None else goal_map
        ordered_ids = [student_id for student_id in student_ids if student_id in self._records_by_id]
        total = PlanCostSummary()
        contributing_count = 0
        for student_id in ordered_ids:
            record = self._records_by_id[student_id]
            if student_id in goal_map:
                summary = self._cached_goal_cost(student_id, record=record, goal=goal_map[student_id])
            else:
                unplanned_goal = self._resource_unplanned_goal_for_student(student_id)
                summary = calculate_goal_cost(record, unplanned_goal) if unplanned_goal is not None else None
            if summary is None:
                continue
            total.merge(summary)
            contributing_count += 1
        return total, len(ordered_ids), contributing_count

    def _set_output_from_summary(self, target: QListWidget, summary: PlanCostSummary | None) -> None:
        target.clear()
        if summary is None:
            target.addItem("이 선택에 사용할 계획 목표가 아직 없습니다.")
            return

        sections: list[tuple[str, list[tuple[str, int]]]] = []
        if summary.credits:
            sections.append(("크레딧", [("크레딧", summary.credits)]))
        if summary.level_exp:
            sections.append(("레벨 EXP", [("레벨 EXP", summary.level_exp)] + sorted(summary.level_exp_items.items(), key=lambda item: (-item[1], item[0]))))
        if summary.equipment_exp or summary.equipment_exp_items:
            rows = []
            if summary.equipment_exp:
                rows.append(("장비 EXP", summary.equipment_exp))
            rows.extend(sorted(summary.equipment_exp_items.items(), key=lambda item: (-item[1], item[0])))
            sections.append(("장비 EXP", rows))
        if summary.weapon_exp or summary.weapon_exp_items:
            rows = []
            if summary.weapon_exp:
                rows.append(("무기 EXP", summary.weapon_exp))
            rows.extend(sorted(summary.weapon_exp_items.items(), key=lambda item: (-item[1], item[0])))
            sections.append(("무기 EXP", rows))
        for heading, mapping in (("성급 재화", summary.star_materials), ("장비 재화", summary.equipment_materials), ("스킬북", summary.skill_books), ("EX 오파츠", summary.ex_ooparts), ("일반 스킬 오파츠", summary.skill_ooparts), ("애용품 재화", summary.favorite_item_materials), ("능력개방 재화", summary.stat_materials)):
            if mapping:
                sections.append((heading, sorted(mapping.items(), key=lambda item: (-item[1], item[0]))))
        if summary.stat_levels:
            sections.append(("능력개방 목표", sorted(summary.stat_levels.items(), key=lambda item: item[0])))

        if not sections and summary.warnings:
            for warning in dict.fromkeys(summary.warnings):
                target.addItem(warning)
            return

        for heading, rows in sections:
            heading_item = QListWidgetItem(heading)
            heading_item.setFlags(Qt.ItemIsEnabled)
            target.addItem(heading_item)
            for key, value in rows:
                target.addItem(f"  {key}: {_format_count(value, compact=True)}" if isinstance(value, int) else f"  {key}: {value}")
        if summary.warnings:
            target.addItem("메모")
            for warning in dict.fromkeys(summary.warnings):
                target.addItem(f"  {warning}")

    def _clear_requirement_grid(self, grid: QGridLayout) -> None:
        while grid.count():
            item = grid.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()

    def _clear_layout_widgets(self, layout) -> None:
        while layout.count():
            item = layout.takeAt(0)
            widget = item.widget()
            child_layout = item.layout()
            if widget is not None:
                widget.deleteLater()
            elif child_layout is not None:
                self._clear_layout_widgets(child_layout)

    def _populate_requirement_grid(
        self,
        grid: QGridLayout,
        entries: list[PlanResourceRequirement],
        *,
        columns: int = 3,
    ) -> None:
        for index, requirement in enumerate(entries):
            chip = PlanResourceChip(ui_scale=self._ui_scale)
            chip.setData(requirement)
            grid.addWidget(chip, index // columns, index % columns)

    def _sort_resource_requirement_entries(
        self,
        entries: list[PlanResourceRequirement],
    ) -> list[PlanResourceRequirement]:
        if getattr(self, "_resource_requirement_sort_mode", "default") != "shortage_ratio":
            return entries
        return sorted(
            entries,
            key=lambda entry: (
                -(max(0, entry.required - entry.owned) / max(1, entry.required)),
                -max(0, entry.required - entry.owned),
                -entry.required,
                entry.name.casefold(),
            ),
        )

    def _refresh_resource_view(self) -> None:
        if not hasattr(self, "_resource_requirement_grid"):
            return
        self._refresh_resource_aggregate_view()

    def _is_resource_tab_current(self) -> bool:
        return (
            self._main_tabs is not None
            and self._resource_tab is not None
            and self._main_tabs.currentWidget() is self._resource_tab
        )

    def _refresh_resources_if_visible(self) -> None:
        if self._is_resource_tab_current():
            self._refresh_resource_students_list()
            self._refresh_resource_view()
            self._resources_dirty = False
        else:
            self._resources_dirty = True

    def _on_main_tab_changed(self, _index: int) -> None:
        if self._resources_dirty and self._is_resource_tab_current():
            self._refresh_resource_students_list()
            self._refresh_resource_view()
            self._resources_dirty = False
        if getattr(self, "_main_tabs", None) is not None and self._main_tabs.currentWidget() is getattr(self, "_inventory_tab", None):
            self._schedule_inventory_layout_sync()

    def _schedule_inventory_layout_sync(self) -> None:
        if not hasattr(self, "_inventory_root_tabs"):
            return
        QTimer.singleShot(0, self._sync_inventory_layout)
        QTimer.singleShot(80, self._sync_inventory_layout)

    def _sync_inventory_layout(self) -> None:
        widgets: list[QWidget] = []
        for name in ("_inventory_root_tabs", "_inventory_equipment_tabs", "_inventory_item_tabs"):
            widget = getattr(self, name, None)
            if isinstance(widget, QWidget):
                widgets.append(widget)
        for group_name in ("_inventory_equipment_lists", "_inventory_item_lists"):
            for widget in getattr(self, group_name, {}).values():
                if isinstance(widget, QWidget):
                    widgets.append(widget)
        for name in ("_inventory_plan_priority_list", "_inventory_pool_pressure_list", "_inventory_oopart_impact_list"):
            widget = getattr(self, name, None)
            if isinstance(widget, QWidget):
                widgets.append(widget)

        for widget in widgets:
            widget.updateGeometry()
            if widget.layout() is not None:
                widget.layout().activate()
            if isinstance(widget, RoundedListWidget):
                widget._schedule_sync_after_layout()
            elif isinstance(widget, RoundedMaskFrame):
                widget._schedule_mask()

    def _refresh_resource_aggregate_view(self) -> None:
        goal_map = self._plan_goal_map()
        student_ids = sorted(
            self._resource_selected_ids,
            key=lambda student_id: self._records_by_id[student_id].title.lower() if student_id in self._records_by_id else student_id,
        )
        summary, selected_count, contributing_count = self._resource_total_for_ids(student_ids, goal_map)
        planned_count = sum(1 for student_id in student_ids if student_id in goal_map)
        unplanned_count = max(0, selected_count - planned_count)
        unplanned_included = max(0, contributing_count - planned_count)
        self._resource_aggregate_summary.setText(
            f"선택 범위 {selected_count}명을 합산 중입니다. 계획 학생 {planned_count}명과 미계획 학생 {unplanned_included}/{unplanned_count}명이 현재 합계에 반영됩니다."
        )
        self._resource_requirement_grid_host.setUpdatesEnabled(False)
        try:
            self._clear_requirement_grid(self._resource_requirement_grid)
            self._resource_requirement_scroll.setVisible(True)
            if contributing_count == 0:
                self._resource_requirement_empty.setText("현재 선택 범위에서 필요한 재화가 없습니다.")
                self._resource_requirement_empty.setVisible(True)
                return
            entries = self._sort_resource_requirement_entries(self._plan_requirement_entries(summary))
            self._resource_requirement_empty.setText("" if entries else "현재 계산 범위에는 추가 재화가 필요하지 않습니다.")
            self._resource_requirement_empty.setVisible(True)
            if not entries:
                return
            shortages = sum(1 for entry in entries if entry.required > entry.owned)
            self._resource_aggregate_summary.setText(
                f"{len(entries)}종의 아이템 중 부족한 종류는 {shortages}개이며, 계획에 있는 학생 {planned_count}명과 포함되어 있지 않은 학생 {unplanned_included}명이 반영되어 있습니다."
            )
            self._populate_requirement_grid(self._resource_requirement_grid, entries)
        finally:
            self._resource_requirement_grid_host.setUpdatesEnabled(True)

    def _refresh_resource_inventory_view(self) -> None:
        self._refresh_inventory_tab()
        return
        if not hasattr(self, "_resource_inventory_output"):
            return
        self._resource_inventory_output.clear()
        inventory = self._inventory_snapshot or {}
        if not inventory:
            self._resource_inventory_summary.setText(_tr("inventory.empty"))
            self._resource_inventory_output.addItem("아이템 또는 장비 스캔을 실행하면 현재 인벤토리가 채워집니다.")
            return

        def sort_key(item: tuple[str, dict]) -> tuple[int, str]:
            _, payload = item
            raw_quantity = payload.get("quantity")
            try:
                quantity = int(str(raw_quantity).replace(",", ""))
            except Exception:
                quantity = -1
            name = str(payload.get("name") or item[0])
            return (-quantity, name)

        ordered = sorted(inventory.items(), key=sort_key)
        total_quantity = 0
        for _, payload in ordered:
            try:
                total_quantity += int(str(payload.get("quantity") or "0").replace(",", ""))
            except Exception:
                continue

        self._resource_inventory_summary.setText(
            f"현재 인벤토리 스냅샷 {len(ordered)}개 · 총 수량 {_format_count(total_quantity, compact=True)}"
        )
        for key, payload in ordered:
            name = str(payload.get("name") or key)
            quantity_value = _inventory_quantity_value(payload.get("quantity"))
            quantity = _format_count(quantity_value, compact=True) if quantity_value is not None else str(payload.get("quantity") or "?")
            item = QListWidgetItem(f"{name}: {quantity}")
            if quantity_value is not None:
                item.setToolTip(f"{name}: {_full_count_tooltip(quantity_value)}")
            self._resource_inventory_output.addItem(item)

    def _inventory_plan_requirement_index(self) -> dict[str, PlanResourceRequirement]:
        goal_map = self._plan_goal_map()
        total, _selected_count, _contributing_count = self._resource_total_for_ids(
            [goal.student_id for goal in self._plan.goals],
            goal_map,
        )
        entries = self._plan_requirement_entries(total)
        return {entry.key: entry for entry in entries}

    def _inventory_full_pool_goal_for_student(self, record: StudentRecord) -> StudentGoal:
        goal = StudentGoal(student_id=record.student_id)
        goal.target_level = MAX_TARGET_LEVEL
        goal.target_star = MAX_TARGET_STAR
        goal.target_ex_skill = MAX_TARGET_EX_SKILL
        goal.target_skill1 = MAX_TARGET_SKILL
        goal.target_skill2 = MAX_TARGET_SKILL
        goal.target_skill3 = MAX_TARGET_SKILL
        goal.target_equip1_tier = MAX_TARGET_EQUIP_TIER
        goal.target_equip2_tier = MAX_TARGET_EQUIP_TIER
        goal.target_equip3_tier = MAX_TARGET_EQUIP_TIER
        goal.target_equip1_level = MAX_TARGET_EQUIP_LEVEL
        goal.target_equip2_level = MAX_TARGET_EQUIP_LEVEL
        goal.target_equip3_level = MAX_TARGET_EQUIP_LEVEL
        if self._plan_allows_weapon_targets(record):
            goal.target_weapon_star = MAX_TARGET_WEAPON_STAR
            goal.target_weapon_level = MAX_TARGET_WEAPON_LEVEL
        if self._record_supports_unique_item(record):
            goal.target_equip4_tier = MAX_TARGET_EQUIP4_TIER
        goal.target_stat_hp = MAX_TARGET_STAT
        goal.target_stat_atk = MAX_TARGET_STAT
        goal.target_stat_heal = MAX_TARGET_STAT
        return goal

    def _inventory_full_pool_requirement_index(self) -> dict[str, PlanResourceRequirement]:
        total = PlanCostSummary()
        for record in self._all_students:
            goal = self._inventory_full_pool_goal_for_student(record)
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is not None:
                total.merge(summary)
        entries = self._plan_requirement_entries(total)
        return {entry.key: entry for entry in entries}

    def _inventory_requirement_for_entry(
        self,
        item_id: str,
        name: str,
        requirement_index: dict[str, PlanResourceRequirement] | None = None,
    ) -> PlanResourceRequirement | None:
        requirement_index = requirement_index if requirement_index is not None else getattr(self, "_inventory_requirement_index", {})
        if item_id in requirement_index:
            return requirement_index[item_id]
        folded_name = name.casefold()
        for entry in requirement_index.values():
            if entry.name.casefold() == folded_name:
                return entry
        return None

    def _inventory_status_for_values(self, *, owned: int, required: int, pool_left: int = 0, tier: int = 0) -> str:
        if required > owned:
            return "고티어 병목" if tier >= 8 else "계획 부족"
        if pool_left > 0:
            return "장기적으로 부족"
        if required <= 0 and pool_left <= 0:
            return "미사용"
        return "충분"

    def _inventory_equipment_priority_statuses(self, entries: list[tuple[str, dict]]) -> dict[str, str]:
        requirement_index = getattr(self, "_inventory_requirement_index", {})
        ranked: list[tuple[int, int, str, str]] = []
        seen: set[str] = set()
        for item_key, payload in entries:
            item_id = payload.get("item_id")
            item_id_text = str(item_id) if item_id else str(item_key)
            if item_id_text in seen:
                continue
            seen.add(item_id_text)
            name = _inventory_display_label(item_key, payload)
            owned = _inventory_quantity_value(payload.get("quantity")) or 0
            requirement = self._inventory_requirement_for_entry(item_id_text, name, requirement_index)
            required = requirement.required if requirement is not None else 0
            shortage = max(0, required - owned)
            if shortage <= 0:
                continue
            tier = _tier_from_item_id_or_name(item_id_text, name)
            ranked.append((shortage, tier, name.casefold(), item_id_text))
        ranked.sort(key=lambda item: (-item[0], -item[1], item[2]))
        return {
            item_id: _inventory_priority_shortage_status(rank)
            for rank, (_shortage, _tier, _name, item_id) in enumerate(ranked[:3], start=1)
        }

    def _inventory_oopart_priority_statuses(
        self,
        oopart_usage: dict[str, InventoryOpartPlanUsage],
    ) -> dict[str, str]:
        ranked_by_tier: dict[int, list[tuple[int, int, str, str]]] = {4: [], 3: []}
        for item_id, usage in oopart_usage.items():
            shortage = usage.shortage
            if shortage <= 0:
                continue
            tier = _tier_from_item_id_or_name(item_id, usage.name)
            if tier not in ranked_by_tier:
                continue
            ranked_by_tier[tier].append((shortage, usage.required, usage.name.casefold(), item_id))

        statuses: dict[str, str] = {}
        for tier in (4, 3):
            ranked = ranked_by_tier[tier]
            ranked.sort(key=lambda item: (-item[0], -item[1], item[2]))
            if ranked:
                statuses[ranked[0][3]] = _inventory_priority_shortage_status(1)
        return statuses

    @staticmethod
    def _inventory_bottleneck_bucket(category: str) -> str:
        if category == "credits":
            return "크레딧"
        if category == "level_exp":
            return "레벨"
        if category in {"equipment_exp", "equipment_materials"}:
            return "장비"
        if category == "weapon_exp":
            return "무기"
        if category in {"skill_books", "ex_ooparts", "skill_ooparts"}:
            return "스킬"
        if category == "stat_materials":
            return "능력개방"
        return "기타"

    @staticmethod
    def _inventory_is_common_requirement_category(category: str) -> bool:
        return category in {
            "credits",
            "level_exp",
            "equipment_exp",
            "weapon_exp",
            "skill_books",
            "stat_materials",
            "equipment_materials",
        }

    def _inventory_common_bottleneck_rows(self) -> list[tuple[int, int, int, str]]:
        buckets: dict[str, list[int]] = defaultdict(lambda: [0, 0])
        for entry in self._inventory_requirement_index.values():
            if not self._inventory_is_common_requirement_category(entry.category):
                continue
            required = max(0, entry.required)
            shortage = max(0, entry.required - entry.owned)
            if required <= 0:
                continue
            bucket = self._inventory_bottleneck_bucket(entry.category)
            buckets[bucket][0] += shortage
            buckets[bucket][1] += required
        rows = []
        for bucket, (shortage, required) in buckets.items():
            if required <= 0:
                continue
            ratio = int((shortage / required) * 100) if shortage > 0 else 0
            coverage = max(0, min(100, 100 - ratio))
            rows.append((ratio, coverage, shortage, bucket))
        bucket_order = {
            "크레딧": 0,
            "레벨": 1,
            "장비": 2,
            "무기": 3,
            "스킬": 4,
            "능력개방": 5,
        }
        rows.sort(key=lambda item: (bucket_order.get(item[3], 99), -item[0], -item[1], item[3]))
        return rows

    def _inventory_common_bottleneck_text(self) -> str:
        rows = self._inventory_common_bottleneck_rows()
        rows = [(ratio, shortage, bucket) for ratio, _coverage, shortage, bucket in rows]
        if not rows:
            return "현재 계획의 공통 재화 병목이 없습니다."
        return "\n".join(f"{bucket}: {ratio}% 부족 ({_format_count(shortage, compact=True)})" for ratio, shortage, bucket in rows)

    def _inventory_plan_diagnosis_text(self) -> str:
        coverage_rows = self._inventory_common_bottleneck_rows()
        coverage = 100.0 if not coverage_rows else sum(row[1] for row in coverage_rows) / len(coverage_rows)

        bottleneck_rows = [row for row in coverage_rows if row[2] > 0]
        if bottleneck_rows:
            _shortage_ratio, _bucket_coverage, _shortage, bucket = max(
                bottleneck_rows,
                key=lambda row: (row[0], row[2], row[3]),
            )
            bottleneck = bucket
            recommendations = {
                "크레딧": "크레딧 확보 우선",
                "레벨": "활동 보고서 확보 우선",
                "장비": "장비 재료 파밍 우선",
                "무기": "무기 성장 재료 확보",
                "스킬": "BD/기술 노트/오파츠 우선",
                "능력개방": "WB 확보 우선",
            }
            action = recommendations.get(bucket, "부족률 높은 재화부터 확보")
        else:
            bottleneck = "없음"
            action = "현재 계획 유지"

        return (
            f'<div style="color:{MUTED}; margin-bottom:5px;">재화 충족률 : {coverage:.1f}%</div>'
            f'<div style="color:{MUTED}; margin-bottom:5px;">가장 큰 병목 요소 : {escape(bottleneck)}</div>'
            f'<div style="color:{MUTED};">행동 추천 : {escape(action)}</div>'
        )

    def _inventory_pool_pressure_rows(self) -> list[tuple[str, InventoryOpartPlanUsage | PlanResourceRequirement, int, str]]:
        mode = getattr(self, "_inventory_pool_pressure_mode", "equipment")
        if mode == "ooparts":
            rows: list[tuple[str, InventoryOpartPlanUsage | PlanResourceRequirement, int, str]] = [
                ("usage", usage, usage.pool_shortage, usage.name.lower())
                for usage in self._inventory_oopart_plan_usage.values()
                if usage.pool_shortage > 0
            ]
        else:
            rows = [
                ("requirement", entry, entry.required - entry.owned, entry.name.lower())
                for entry in self._inventory_pool_requirement_index.values()
                if entry.category == "equipment_materials" and entry.required > entry.owned
            ]
        rows.sort(key=lambda row: (-row[2], row[3]))
        return rows[:5]

    def _refresh_inventory_common_bottleneck_summary(self) -> None:
        layout = getattr(self, "_inventory_bottleneck_rows_layout", None)
        if layout is None:
            return
        self._clear_layout_widgets(layout)
        rows = self._inventory_common_bottleneck_rows()
        if not rows:
            label = QLabel("현재 계획의 공통 재화 병목이 없습니다.")
            label.setObjectName("detailSub")
            label.setWordWrap(True)
            layout.addWidget(label)
            return
        for shortage_ratio, coverage, shortage, bucket in rows:
            row = QWidget()
            row.setObjectName("planTransparent")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(scale_px(6, self._ui_scale))

            name_label = QLabel(bucket)
            name_label.setObjectName("inventoryBottleneckName")
            name_label.setAlignment(Qt.AlignCenter)
            name_label.setFixedWidth(scale_px(58, self._ui_scale))
            row_layout.addWidget(name_label, 0, Qt.AlignVCenter)

            bar = QProgressBar()
            bar.setObjectName("inventoryBottleneckBar")
            bar.setTextVisible(False)
            bar.setFixedHeight(scale_px(7, self._ui_scale))
            bar.setValue(coverage)
            bar.setToolTip(f"충족률 {coverage}% · 부족 {_full_count_tooltip(shortage)}")
            row_layout.addWidget(bar, 1, Qt.AlignVCenter)

            value_label = QLabel(f"{coverage}%")
            value_label.setObjectName("inventoryBottleneckRatio")
            value_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
            value_label.setFixedWidth(scale_px(34, self._ui_scale))
            value_label.setToolTip(f"부족률 {shortage_ratio}% · 부족 {_full_count_tooltip(shortage)}")
            row_layout.addWidget(value_label, 0, Qt.AlignVCenter)
            layout.addWidget(row)

    def _inventory_school_risk_rows(self) -> list[tuple[int, int, int, str, dict[str, int]]]:
        inventory_index = getattr(self, "_inventory_quantity_index_cache", {})
        required_by_school: dict[str, dict[str, int]] = defaultdict(lambda: {"BD": 0, "기술 노트": 0})
        item_ids_by_school: dict[str, set[str]] = defaultdict(set)

        for record in self._all_students:
            school = (record.school or "ETC").strip() or "ETC"
            goal = self._inventory_full_pool_goal_for_student(record)
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is None:
                continue
            for entry in self._plan_requirement_entries(summary, record=record):
                item_id = entry.key
                match = re.match(r"Item_Icon_Material_ExSkill_([^_]+)_", item_id)
                if match:
                    school_key = match.group(1)
                    required_by_school[school_key]["BD"] += entry.required
                    item_ids_by_school[school_key].add(item_id)
                    continue
                match = re.match(r"Item_Icon_SkillBook_([^_]+)_", item_id)
                if match and "Ultimate" not in item_id:
                    school_key = match.group(1)
                    required_by_school[school_key]["기술 노트"] += entry.required
                    item_ids_by_school[school_key].add(item_id)

        rows: list[tuple[int, int, int, str, dict[str, int]]] = []
        for school, values in required_by_school.items():
            required = values["BD"] + values["기술 노트"]
            if required <= 0:
                continue
            owned = sum(max(0, int(inventory_index.get(item_id, 0))) for item_id in item_ids_by_school.get(school, set()))
            shortage = max(0, required - owned)
            if shortage <= 0:
                continue
            coverage = max(0, min(100, int((owned / required) * 100)))
            rows.append((coverage, shortage, required, school, values))
        rows.sort(key=lambda row: (row[0], -row[1], row[3]))
        return rows[:3]

    def _refresh_inventory_school_risk_summary(self) -> None:
        layout = getattr(self, "_inventory_school_risk_rows_layout", None)
        if layout is None:
            return
        self._clear_layout_widgets(layout)
        rows = self._inventory_school_risk_rows()
        if not rows:
            label = QLabel("재화 부족 위험 학교가 없습니다.")
            label.setObjectName("detailSub")
            label.setWordWrap(True)
            layout.addWidget(label)
            return

        spacing = scale_px(5, self._ui_scale)
        row_host_height = self._inventory_school_risk_rows_host.height()
        if row_host_height <= 0 and hasattr(self, "_inventory_school_risk_panel"):
            row_host_height = max(
                1,
                self._inventory_school_risk_panel.height()
                - scale_px(14, self._ui_scale)
                - scale_px(22, self._ui_scale)
                - spacing,
            )
        available_row_height = max(1, row_host_height - spacing * max(0, len(rows) - 1))
        icon_size = max(
            scale_px(18, self._ui_scale),
            min(scale_px(30, self._ui_scale), available_row_height // max(1, len(rows))),
        )
        for coverage, shortage, required, school, values in rows:
            row = QWidget()
            row.setObjectName("planTransparent")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(scale_px(6, self._ui_scale))

            icon = QLabel()
            icon.setFixedSize(scale_px(50, self._ui_scale), icon_size)
            icon.setAlignment(Qt.AlignCenter)
            logo_path = _school_logo_tinted_path(school, size=icon_size)
            if logo_path is not None and logo_path.exists():
                pixmap = QPixmap(str(logo_path))
                if not pixmap.isNull():
                    icon.setPixmap(pixmap.scaled(icon_size, icon_size, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            row_layout.addWidget(icon, 0, Qt.AlignCenter)

            bar = QProgressBar()
            bar.setObjectName("inventorySchoolRiskBar")
            bar.setTextVisible(False)
            bar.setFixedHeight(scale_px(7, self._ui_scale))
            bar.setValue(coverage)
            bar.setToolTip(
                f"{school}\n충족률 {coverage}% · 부족 {_full_count_tooltip(shortage)} / 필요 {_full_count_tooltip(required)}\n"
                f"BD {_format_count(values['BD'], compact=True)} · 기술 노트 {_format_count(values['기술 노트'], compact=True)}"
            )
            row_layout.addWidget(bar, 1, Qt.AlignVCenter)

            percent = QLabel(f"{coverage}%")
            percent.setObjectName("inventorySchoolRiskPercent")
            percent.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
            percent.setFixedWidth(scale_px(34, self._ui_scale))
            row_layout.addWidget(percent, 0, Qt.AlignVCenter)
            layout.addWidget(row)

    def _inventory_school_shortage_text(self) -> str:
        school_totals: dict[str, dict[str, int]] = defaultdict(lambda: {"BD": 0, "TN": 0})
        wb_totals: dict[str, int] = defaultdict(int)
        for entry in self._inventory_requirement_index.values():
            shortage = max(0, entry.required - entry.owned)
            if shortage <= 0:
                continue
            item_id = entry.key
            match = re.match(r"Item_Icon_Material_ExSkill_([^_]+)_", item_id)
            if match:
                school_totals[match.group(1)]["BD"] += shortage
                continue
            match = re.match(r"Item_Icon_SkillBook_([^_]+)_", item_id)
            if match and "Ultimate" not in item_id:
                school_totals[match.group(1)]["TN"] += shortage
                continue
            if item_id in _WORKBOOK_ID_TO_NAME:
                wb_totals[_WORKBOOK_ID_TO_NAME[item_id].replace(" WB", "")] += shortage
        school_rows = [
            (values["BD"] + values["TN"], school, values)
            for school, values in school_totals.items()
            if values["BD"] or values["TN"]
        ]
        school_rows.sort(key=lambda item: (-item[0], item[1]))
        lines = []
        icon_size = scale_px(36, getattr(self, "_ui_scale", 1.0))
        for _total, school, values in school_rows[:4]:
            logo_path = _school_logo_tinted_path(school, size=icon_size)
            counts = f"BD {values['BD']:,} · 기술 노트 {values['TN']:,}"
            if logo_path is not None:
                logo_src = escape(logo_path.as_posix(), quote=True)
                lines.append(
                    f'<img src="{logo_src}" width="{icon_size}" height="{icon_size}"> '
                    f'<span style="vertical-align:middle;">{escape(counts)}</span>'
                )
            else:
                lines.append(f"{escape(school)} {escape(counts)}")
        if wb_totals:
            wb_text = ", ".join(f"{name} {amount:,}" for name, amount in sorted(wb_totals.items()))
            lines.append(f"WB: {escape(wb_text)}")
        return "<br>".join(lines) if lines else "현재 계획의 BD, 기술 노트, WB 부족이 없습니다."

    def _inventory_material_sort_mode_key(self) -> str:
        selector = getattr(self, "_inventory_material_sort_mode", None)
        value = selector.currentData() if selector is not None else None
        return str(value or "category_tier_desc")

    def _inventory_oopart_sort_key(self, entry: tuple[str, dict]) -> tuple[int, int, str]:
        item_id = str(entry[1].get("item_id") or "")
        family_order = {
            definition.icon_key: index
            for index, definition in enumerate(OPART_DEFINITIONS)
        }
        match = re.match(r"Item_Icon_Material_(.+)_(\d+)$", item_id)
        if not match:
            return (9999, 9999, _inventory_display_label(entry[0], entry[1]).lower())
        family = match.group(1)
        tier_index = int(match.group(2))
        family_index = family_order.get(family, 9999)
        name = _inventory_display_label(entry[0], entry[1]).lower()
        if self._inventory_material_sort_mode_key() == "tier_desc":
            return (-tier_index, family_index, name)
        return (family_index, -tier_index, name)

    def _inventory_school_material_sort_key(self, entry: tuple[str, dict], *, material: str) -> tuple[int, int, str]:
        item_id = str(entry[1].get("item_id") or "")
        school_order = {school: index for index, school in enumerate(_SCHOOL_SEQUENCE)}
        if material == "bd":
            pattern = r"Item_Icon_Material_ExSkill_([^_]+)_(\d+)$"
        else:
            if item_id == "Item_Icon_SkillBook_Ultimate_Piece":
                return (9998, 9998, _inventory_display_label(entry[0], entry[1]).lower())
            pattern = r"Item_Icon_SkillBook_([^_]+)_(\d+)$"
        match = re.match(pattern, item_id)
        if not match:
            return (9999, 9999, _inventory_display_label(entry[0], entry[1]).lower())
        school = match.group(1)
        tier_index = int(match.group(2))
        school_index = school_order.get(school, 9999)
        name = _inventory_display_label(entry[0], entry[1]).lower()
        if self._inventory_material_sort_mode_key() == "tier_desc":
            return (-tier_index, school_index, name)
        return (school_index, -tier_index, name)

    def _inventory_build_oopart_plan_usage(self) -> dict[str, InventoryOpartPlanUsage]:
        usage_by_item: dict[str, InventoryOpartPlanUsage] = {}
        impact_by_item: dict[str, dict[str, InventoryOpartStudentImpact]] = {}
        pool_impact_by_item: dict[str, dict[str, InventoryOpartStudentImpact]] = {}

        def add_summary(
            *,
            record: StudentRecord,
            summary: PlanCostSummary,
            target_usage_by_item: dict[str, InventoryOpartPlanUsage],
            target_impact_by_item: dict[str, dict[str, InventoryOpartStudentImpact]],
            pool: bool,
        ) -> None:
            for category, values, impact_field in (
                ("ex_ooparts", summary.ex_ooparts, "ex_required"),
                ("skill_ooparts", summary.skill_ooparts, "skill_required"),
            ):
                for key, raw_required in values.items():
                    required = int(raw_required or 0)
                    if required <= 0:
                        continue
                    item_id = _plan_resource_item_id(key, category)
                    if not item_id or item_id not in _OPART_ITEM_IDS:
                        continue
                    name = _plan_resource_display_name(item_id, key)
                    usage = target_usage_by_item.get(item_id)
                    if usage is None:
                        usage = InventoryOpartPlanUsage(item_id=item_id, name=name)
                        target_usage_by_item[item_id] = usage
                    if pool:
                        usage.pool_required += required
                        if impact_field == "ex_required":
                            usage.pool_ex_required += required
                        else:
                            usage.pool_skill_required += required
                    else:
                        usage.required += required
                        if impact_field == "ex_required":
                            usage.ex_required += required
                        else:
                            usage.skill_required += required

                    impacts = target_impact_by_item.setdefault(item_id, {})
                    impact = impacts.get(record.student_id)
                    if impact is None:
                        impact = InventoryOpartStudentImpact(student_id=record.student_id, title=record.title)
                        impacts[record.student_id] = impact
                    if impact_field == "ex_required":
                        impact.ex_required += required
                    else:
                        impact.skill_required += required

        priority_index = self._plan_priority_index()

        for goal in self._plan.goals:
            record = self._records_by_id.get(goal.student_id)
            if record is None:
                continue
            summary = self._cached_goal_cost(goal.student_id, record=record, goal=goal)
            if summary is None:
                continue
            add_summary(
                record=record,
                summary=summary,
                target_usage_by_item=usage_by_item,
                target_impact_by_item=impact_by_item,
                pool=False,
            )

        for record in self._all_students:
            goal = StudentGoal(student_id=record.student_id)
            goal.target_ex_skill = MAX_TARGET_EX_SKILL
            goal.target_skill1 = MAX_TARGET_SKILL
            goal.target_skill2 = MAX_TARGET_SKILL
            goal.target_skill3 = MAX_TARGET_SKILL
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is None:
                continue
            add_summary(
                record=record,
                summary=summary,
                target_usage_by_item=usage_by_item,
                target_impact_by_item=pool_impact_by_item,
                pool=True,
            )

        for item_id, usage in usage_by_item.items():
            usage.owned = self._inventory_quantity_index_cache.get(item_id, 0)
            usage.impacts = sorted(
                impact_by_item.get(item_id, {}).values(),
                key=lambda impact: (
                    priority_index.get(impact.student_id, 999999),
                    impact.title.lower(),
                    impact.student_id,
                ),
            )
            usage.pool_impacts = sorted(
                pool_impact_by_item.get(item_id, {}).values(),
                key=lambda impact: (
                    priority_index.get(impact.student_id, 999999),
                    -impact.total_required,
                    impact.title.lower(),
                    impact.student_id,
                ),
            )
        return usage_by_item

    @staticmethod
    def _inventory_coverage(owned: int, required: int) -> str:
        if required <= 0:
            return "-"
        return f"{min(100, int((owned / required) * 100))}%"

    def _inventory_oopart_status(self, usage: InventoryOpartPlanUsage | None) -> str:
        if usage is None or (usage.required <= 0 and usage.pool_required <= 0):
            return "미사용"
        if usage.shortage > 0:
            return "계획 부족"
        if usage.pool_shortage > 0:
            return "장기적으로 부족"
        return "충분"

    def _clear_inventory_oopart_metrics(self) -> None:
        for label in getattr(self, "_inventory_oopart_metric_labels", {}).values():
            label.setText("-")

    def _set_inventory_metric(self, key: str, value: str) -> None:
        label = getattr(self, "_inventory_oopart_metric_labels", {}).get(key)
        if label is not None:
            label.setText(value)

    def _set_inventory_metric_number(self, key: str, value: int, *, compact: bool = True, signed: bool = False, empty_zero: bool = False) -> None:
        label = getattr(self, "_inventory_oopart_metric_labels", {}).get(key)
        if label is None:
            return
        if empty_zero and value <= 0:
            label.setText("-")
            label.setToolTip("-")
            return
        label.setText(_format_count(value, compact=compact, signed=signed))
        label.setToolTip(_full_count_tooltip(value))

    def _set_inventory_detail_status(self, status: str | None) -> None:
        label = getattr(self, "_inventory_oopart_detail_meta", None)
        if label is None:
            return
        if not status:
            label.setText("")
            label.setToolTip("")
            label.setProperty("status", "")
            label.setVisible(False)
        else:
            status_text = _inventory_status_label(status)
            label.setText(status_text)
            label.setToolTip(status_text)
            label.setProperty("status", _inventory_status_key(status))
            label.setVisible(True)
        label.style().unpolish(label)
        label.style().polish(label)

    def _set_inventory_detail_icon(self, item_id: str | None, name: str) -> None:
        icon_label = getattr(self, "_inventory_oopart_detail_icon", None)
        if icon_label is None:
            return
        icon_path = _inventory_icon_path(item_id, name)
        if icon_path is not None and icon_path.exists():
            pixmap = _item_icon_pixmap(size=icon_label.size(), item_id=item_id, icon_path=icon_path)
            if not pixmap.isNull():
                icon_label.setPixmap(pixmap)
                return
        icon_label.setPixmap(QPixmap())

    def _resize_inventory_impact_list_to_contents(self) -> None:
        target = getattr(self, "_inventory_oopart_impact_list", None)
        if target is None:
            return
        minimum = scale_px(80, self._ui_scale)
        height = target.frameWidth() * 2 + scale_px(8, self._ui_scale)
        for index in range(target.count()):
            item = target.item(index)
            hint = item.sizeHint()
            height += hint.height() if hint.isValid() else scale_px(28, self._ui_scale)
        if target.count() > 1:
            height += max(0, target.count() - 1) * max(0, target.spacing())
        target.setFixedHeight(max(minimum, height))

    def _clear_inventory_detail_hints(self) -> None:
        for attr in (
            "_inventory_oopart_next_hint",
            "_inventory_oopart_farm_hint",
            "_inventory_oopart_family_shortage",
        ):
            label = getattr(self, attr, None)
            if label is not None:
                label.setText("-")

    def _inventory_student_icon(self, student_id: str) -> QIcon:
        size = scale_px(34, self._ui_scale)
        source = ensure_thumbnail(student_id, size, size)
        if source is not None and source.exists():
            pixmap = QPixmap(str(source))
            if not pixmap.isNull():
                return QIcon(pixmap.scaled(size, size, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        return make_placeholder_icon(size, size)

    def _inventory_student_pixmap(self, student_id: str, size: int) -> QPixmap:
        source = ensure_thumbnail(student_id, size, size)
        if source is None or not source.exists():
            return QPixmap()
        pixmap = QPixmap(str(source))
        return pixmap if not pixmap.isNull() else QPixmap()

    def _inventory_oopart_family_shortage_text(self, item_id: str) -> str:
        prefix = "_".join(item_id.rsplit("_", 1)[:-1])
        if not prefix:
            return "-"
        rows: list[str] = []
        for tier_index in range(3, -1, -1):
            sibling_id = f"{prefix}_{tier_index}"
            usage = self._inventory_oopart_plan_usage.get(sibling_id)
            if usage is None:
                continue
            shortage = usage.shortage or usage.pool_shortage
            if shortage > 0:
                label = f"T{tier_index + 1}"
                sign = "-" if usage.shortage > 0 else "전체 육성 -"
                rows.append(f"{label}: {sign}{_format_count(shortage, compact=True)}")
        return "\n".join(rows) if rows else "같은 계열 부족이 없습니다."

    def _inventory_oopart_decision_hints(self, usage: InventoryOpartPlanUsage) -> tuple[str, str]:
        if usage.shortage > 0:
            top = usage.impacts[0] if usage.impacts else None
            if top is not None:
                next_hint = f"다음 목표\n{top.title}의 육성에 {_format_count(top.total_required, compact=True)}개가 더 필요합니다."
            else:
                next_hint = f"다음 목표\n현재 계획 수요를 충족하려면 {_format_count(usage.shortage, compact=True)}개 더 필요합니다."
            farm_hint = f"파밍 우선순위\n높습니다. 현재 계획 학생 중 {len(usage.impacts):,}명이 더 필요로 합니다."
            return next_hint, farm_hint
        if usage.pool_shortage > 0:
            next_hint = f"다음 목표\n현재 계획은 충족되었지만 전체 육성 기준으로는 {_format_count(usage.pool_shortage, compact=True)}개가 더 필요합니다."
            farm_hint = "파밍 우선순위\n현재는 괜찮지만, 전체 학생 육성 기준으로는 장기적으로 부족할 수 있습니다."
            return next_hint, farm_hint
        return (
            "다음 목표\n현재 계획과 알려진 전체 육성 수요가 모두 충족됐습니다.",
            "파밍 우선순위\n현재는 파밍을 안해도 괜찮습니다.",
        )
        if usage.shortage > 0:
            top = usage.impacts[0] if usage.impacts else None
            if top is not None:
                need_parts = []
                if top.ex_required:
                    need_parts.append(f"EX {_format_count(top.ex_required, compact=True)}")
                if top.skill_required:
                    need_parts.append(f"일반 {_format_count(top.skill_required, compact=True)}")
                need_text = " / ".join(need_parts) or _format_count(top.total_required, compact=True)
                next_hint = f"다음 목표\n{top.title} ({need_text})까지 {_format_count(usage.shortage, compact=True)}개 더 필요합니다."
            else:
                next_hint = f"다음 목표\n현재 계획 수요를 해소하려면 {_format_count(usage.shortage, compact=True)}개 더 필요합니다."
            farm_hint = f"파밍 우선순위\n높음 - 현재 계획 학생 {len(usage.impacts):,}명을 막고 있습니다."
        elif usage.pool_shortage > 0:
            next_hint = f"다음 목표\n현재 계획은 충족됐지만 전체 육성 기준 {_format_count(usage.pool_shortage, compact=True)}개가 더 필요합니다."
            farm_hint = f"파밍 우선순위\n중간 - 전체 육성 {len(usage.pool_impacts):,}명 기준 장기적으로 부족합니다."
        else:
            next_hint = "다음 목표\n현재 계획과 알려진 전체 육성 수요가 모두 충족됐습니다."
            farm_hint = "파밍 우선순위\n지금은 낮음."
        return next_hint, farm_hint

    def _inventory_common_decision_hints(
        self,
        *,
        name: str,
        shortage: int,
        pool_left: int,
        consumers: list[tuple[str, str, int]],
        pool_consumers: list[tuple[str, str, int]],
    ) -> tuple[str, str]:
        if shortage > 0:
            if consumers:
                _student_id, title, amount = consumers[0]
                next_hint = f"다음 목표\n{title}의 육성에 {_format_count(amount, compact=True)}개가 더 필요합니다."
            else:
                next_hint = f"다음 목표\n현재 계획 수요를 충족하려면 {_format_count(shortage, compact=True)}개 더 필요합니다."
            farm_hint = f"파밍 우선순위\n높습니다. 현재 계획 학생 중 {len(consumers):,}명이 더 필요로 합니다."
            return next_hint, farm_hint
        if pool_left > 0:
            next_hint = f"다음 목표\n현재 계획은 충족되었지만 전체 육성 기준으로는 {_format_count(pool_left, compact=True)}개가 더 필요합니다."
            farm_hint = "파밍 우선순위\n현재는 괜찮지만, 전체 학생 육성 기준으로는 장기적으로 부족할 수 있습니다."
            return next_hint, farm_hint
        return (
            "다음 목표\n현재 계획과 알려진 전체 육성 수요가 모두 충족됐습니다.",
            "파밍 우선순위\n현재는 파밍을 안해도 괜찮습니다.",
        )
        if shortage > 0:
            if consumers:
                _student_id, title, amount = consumers[0]
                next_hint = f"다음 목표\n{title} 목표를 열려면 {_format_count(shortage, compact=True)}개 더 필요합니다. (학생 필요 {_format_count(amount, compact=True)})"
            else:
                next_hint = f"다음 목표\n현재 계획 수요를 해소하려면 {_format_count(shortage, compact=True)}개 더 필요합니다."
            farm_hint = f"파밍 우선순위\n높음 - 현재 계획 학생 {len(consumers):,}명을 막고 있습니다."
        elif pool_left > 0:
            next_hint = f"다음 목표\n현재 계획은 충족됐지만 전체 육성 기준 {name} {_format_count(pool_left, compact=True)}개가 더 필요합니다."
            farm_hint = f"파밍 우선순위\n중간 - 전체 육성 {len(pool_consumers):,}명 기준 장기적으로 부족합니다."
        else:
            next_hint = "다음 목표\n현재 계획과 알려진 전체 육성 수요가 모두 충족됐습니다."
            farm_hint = "파밍 우선순위\n지금은 낮음."
        return next_hint, farm_hint

    def _inventory_common_related_pressure_text(self, item_id: str, category: str) -> str:
        rows: list[tuple[int, str]] = []
        for entry in self._inventory_requirement_index.values():
            if entry.key == item_id or entry.category != category:
                continue
            shortage = max(0, entry.required - entry.owned)
            if shortage > 0:
                rows.append((shortage, entry.name))
        rows.sort(key=lambda item: (-item[0], item[1].casefold()))
        if rows:
            return "\n".join(f"{name}: -{_format_count(shortage, compact=True)}" for shortage, name in rows[:5])
        return "연관된 현재 계획 부족이 없습니다."

    def _inventory_student_consumers(self, item_id: str, name: str, *, full_pool: bool = False) -> list[tuple[str, str, int]]:
        consumers: list[tuple[str, str, int]] = []
        if full_pool:
            records_and_goals = []
            for record in self._all_students:
                records_and_goals.append((record, self._inventory_full_pool_goal_for_student(record)))
        else:
            records_and_goals = []
            for goal in self._plan.goals:
                record = self._records_by_id.get(goal.student_id)
                if record is not None:
                    records_and_goals.append((record, goal))
        for record, goal in records_and_goals:
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is None:
                continue
            for entry in self._plan_requirement_entries(summary, record=record):
                if entry.key == item_id or entry.name.casefold() == name.casefold():
                    consumers.append((record.student_id, record.title, entry.required))
                    break
        priority_index = self._plan_priority_index()
        consumers.sort(
            key=lambda item: (
                priority_index.get(item[0], 999999) if not full_pool else 999999,
                -item[2],
                item[1].casefold(),
                item[0],
            )
        )
        return consumers

    @staticmethod
    def _inventory_exp_yield(category: str, item_id: str, name: str) -> tuple[str, int] | None:
        tier = _tier_from_item_id_or_name(item_id, name)
        if tier <= 0:
            return None
        index = max(0, min(3, tier - 1))
        if category == "level_exp":
            return "레벨 EXP", (50, 500, 2_000, 10_000)[index]
        if category == "equipment_exp":
            return "장비 EXP", (90, 360, 1_440, 5_760)[index]
        if category == "weapon_exp":
            return "무기 EXP", (10, 50, 200, 1_000)[index]
        return None

    def _on_inventory_item_changed(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None = None) -> None:
        if current is None or not hasattr(self, "_inventory_oopart_detail_title"):
            return
        category = str(current.data(Qt.UserRole + 6) or "")
        if category == "ooparts":
            return

        item_id = str(current.data(Qt.UserRole) or "")
        name = str(current.data(Qt.UserRole + 1) or item_id or "인벤토리 항목")
        owned = int(current.data(Qt.UserRole + 2) or 0)
        required = int(current.data(Qt.UserRole + 3) or 0)
        shortage = int(current.data(Qt.UserRole + 4) or 0)
        status = str(current.data(Qt.UserRole + 5) or self._inventory_status_for_values(owned=owned, required=required))
        pool_required = int(current.data(Qt.UserRole + 7) or 0)
        pool_left = int(current.data(Qt.UserRole + 8) or 0)

        self._inventory_oopart_detail_title.setText(name)
        self._set_inventory_detail_status(status)
        self._set_inventory_detail_icon(item_id, name)
        self._clear_inventory_detail_hints()
        self._inventory_oopart_impact_list.clear()
        self._set_inventory_metric_number("owned", owned)
        self._set_inventory_metric_number("required", required, empty_zero=True)
        self._set_inventory_metric_number("shortage", shortage, empty_zero=True)
        self._set_inventory_metric("coverage", self._inventory_coverage(owned, required))
        self._set_inventory_metric_number("pool_required", pool_required, empty_zero=True)
        self._set_inventory_metric_number("pool_shortage", pool_left, empty_zero=True)
        self._set_inventory_metric("pool_coverage", self._inventory_coverage(owned, pool_required))
        self._set_inventory_metric("ex_required", "-")
        self._set_inventory_metric("skill_required", "-")

        consumers = self._inventory_student_consumers(item_id, name) if required > 0 else []
        pool_consumers = self._inventory_student_consumers(item_id, name, full_pool=True) if pool_required > 0 else []
        if consumers or pool_consumers:
            self._set_inventory_metric("affected", f"계획 {len(consumers):,}명 / 전체 {len(pool_consumers):,}명")
        else:
            self._set_inventory_metric("affected", "-")
        category_text = _inventory_category_label(category) or _tr("tab.inventory")
        self._inventory_oopart_detail_summary.setText(
            f"상태: {_inventory_status_label(status)}. {category_text} 재화를 현재 계획 및 전체 육성 수요와 비교합니다."
        )
        next_hint, farm_hint = self._inventory_common_decision_hints(
            name=name,
            shortage=shortage,
            pool_left=pool_left,
            consumers=consumers,
            pool_consumers=pool_consumers,
        )
        if hasattr(self, "_inventory_oopart_next_hint"):
            self._inventory_oopart_next_hint.setText(next_hint)
        if hasattr(self, "_inventory_oopart_farm_hint"):
            self._inventory_oopart_farm_hint.setText(farm_hint)
        if hasattr(self, "_inventory_oopart_family_shortage"):
            self._inventory_oopart_family_shortage.setText(self._inventory_common_related_pressure_text(item_id, category))
        exp_yield = self._inventory_exp_yield(category, item_id, name)
        if exp_yield is not None and owned > 0:
            label, value = exp_yield
            self._inventory_oopart_impact_list.addItem(f"환산 가치: {_format_count(owned * value, compact=True)} {label}")
        planned_consumer_ids = {student_id for student_id, _title, _amount in consumers}
        display_consumers = [(student_id, title, amount, True) for student_id, title, amount in consumers]
        display_consumers.extend(
            (student_id, title, amount, False)
            for student_id, title, amount in pool_consumers
            if student_id not in planned_consumer_ids
        )
        if display_consumers:
            for student_id, title, amount, planned in display_consumers[:12]:
                item = QListWidgetItem("")
                item.setSizeHint(QSize(scale_px(260, self._ui_scale), scale_px(64, self._ui_scale)))
                row = InventoryOpartImpactRow(card_asset=self._student_card_asset, ui_scale=self._ui_scale)
                row.setGenericData(
                    title=title,
                    demand_text=(
                        f"{_format_count(amount, compact=True)}개"
                        if planned
                        else f"{_format_count(amount, compact=True)}개"
                    ),
                    pixmap=self._inventory_student_pixmap(student_id, scale_px(76, self._ui_scale)),
                    planned=planned,
                )
                if planned:
                    item.setBackground(QColor("#3a2238"))
                    item.setForeground(QColor("#ffe1f0"))
                self._inventory_oopart_impact_list.addItem(item)
                self._inventory_oopart_impact_list.setItemWidget(item, row)
        else:
            self._inventory_oopart_impact_list.addItem("현재 계획에서 이 아이템을 소비하는 학생이 없습니다.")

        self._resize_inventory_impact_list_to_contents()

    def _on_inventory_oopart_changed(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None = None) -> None:
        item_id = str(current.data(Qt.UserRole) or "") if current is not None else ""
        self._inventory_oopart_selected_id = item_id or None
        if current is not None:
            target = self._inventory_item_lists.get("ooparts") if hasattr(self, "_inventory_item_lists") else None
            widget = target.itemWidget(current) if target is not None else None
            if isinstance(widget, InventoryOpartFamilyRow):
                widget.setSelectedItem(item_id)
        self._update_inventory_oopart_detail(current)

    def _on_inventory_oopart_cell_selected(self, item_id: str, list_item: QListWidgetItem, widget: InventoryOpartFamilyRow) -> None:
        list_item.setData(Qt.UserRole, item_id)
        list_item.setData(Qt.UserRole + 1, _plan_resource_display_name(item_id, item_id))
        list_item.setData(Qt.UserRole + 2, self._inventory_quantity_index_cache.get(item_id, 0))
        usage = self._inventory_oopart_plan_usage.get(item_id) if hasattr(self, "_inventory_oopart_plan_usage") else None
        list_item.setData(Qt.UserRole + 3, usage.required if usage else 0)
        list_item.setData(Qt.UserRole + 4, usage.shortage if usage else 0)
        list_item.setData(Qt.UserRole + 5, self._inventory_oopart_status(usage))
        list_item.setData(Qt.UserRole + 6, "ooparts")
        widget.setSelectedItem(item_id)
        target = self._inventory_item_lists.get("ooparts") if hasattr(self, "_inventory_item_lists") else None
        if target is not None:
            target.setCurrentItem(list_item)
        self._inventory_oopart_selected_id = item_id
        self._update_inventory_oopart_detail(list_item)

    def _on_inventory_priority_changed(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None = None) -> None:
        item_id = str(current.data(Qt.UserRole) or "") if current is not None else ""
        if item_id:
            category = str(current.data(Qt.UserRole + 6) or "")
            if category == "ooparts" or item_id in _OPART_ITEM_IDS:
                self._select_inventory_oopart(item_id)
            else:
                self._select_inventory_item(item_id)

    def _select_inventory_item(self, item_id: str) -> None:
        if not item_id:
            return
        for list_map, root_index in (
            (getattr(self, "_inventory_equipment_lists", {}), 0),
            (getattr(self, "_inventory_item_lists", {}), 1),
        ):
            for category_index, (_category, target) in enumerate(list_map.items()):
                for index in range(target.count()):
                    item = target.item(index)
                    if str(item.data(Qt.UserRole) or "") == item_id:
                        self._inventory_root_tabs.setCurrentIndex(root_index)
                        if root_index == 0 and hasattr(self, "_inventory_equipment_tabs"):
                            self._inventory_equipment_tabs.setCurrentIndex(category_index)
                        elif root_index == 1 and hasattr(self, "_inventory_item_tabs"):
                            self._inventory_item_tabs.setCurrentIndex(category_index)
                        target.setCurrentItem(item)
                        target.scrollToItem(item)
                        return

    def _select_inventory_oopart(self, item_id: str) -> None:
        if not hasattr(self, "_inventory_item_lists"):
            return
        target = self._inventory_item_lists.get("ooparts")
        if target is None:
            return
        family_prefix = "_".join(item_id.rsplit("_", 1)[:-1])

        def apply_match(item: QListWidgetItem) -> None:
            item.setData(Qt.UserRole, item_id)
            item.setData(Qt.UserRole + 1, _plan_resource_display_name(item_id, item_id))
            item.setData(Qt.UserRole + 2, self._inventory_quantity_index_cache.get(item_id, 0))
            usage = self._inventory_oopart_plan_usage.get(item_id) if hasattr(self, "_inventory_oopart_plan_usage") else None
            item.setData(Qt.UserRole + 3, usage.required if usage else 0)
            item.setData(Qt.UserRole + 4, usage.shortage if usage else 0)
            item.setData(Qt.UserRole + 5, self._inventory_oopart_status(usage))
            item.setData(Qt.UserRole + 6, "ooparts")
            widget = target.itemWidget(item)
            if isinstance(widget, InventoryOpartFamilyRow):
                widget.setSelectedItem(item_id)
            self._inventory_root_tabs.setCurrentIndex(1)
            self._inventory_item_tabs.setCurrentIndex(0)
            target.setCurrentItem(item)
            target.scrollToItem(item)

        fallback_item: QListWidgetItem | None = None
        for index in range(target.count()):
            item = target.item(index)
            current_id = str(item.data(Qt.UserRole) or "")
            current_prefix = "_".join(current_id.rsplit("_", 1)[:-1])
            if current_id == item_id:
                apply_match(item)
                return
            if fallback_item is None and family_prefix and current_prefix == family_prefix:
                fallback_item = item
        if fallback_item is not None:
            apply_match(fallback_item)

    def _configure_inventory_priority_cards(self, target: QListWidget) -> None:
        target.setViewMode(QListView.ListMode)
        target.setResizeMode(QListView.Adjust)
        target.setMovement(QListView.Static)
        target.setFlow(QListView.TopToBottom)
        target.setWrapping(False)
        target.setWordWrap(True)
        target.setSpacing(0)
        target.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        target.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        target.verticalScrollBar().setEnabled(False)
        target.setFixedHeight(scale_px(182, self._ui_scale))

    def _add_inventory_usage_list_item(self, target: QListWidget, usage: InventoryOpartPlanUsage, *, pool: bool) -> None:
        if pool:
            amount = usage.pool_shortage
            meta = f"{_format_count(usage.owned, compact=True)} / {_format_count(usage.pool_required, compact=True)} · 전체 육성 부족"
            tooltip = f"{usage.name}\n전체 육성 부족 {usage.pool_shortage:,} / 필요 {usage.pool_required:,}"
        else:
            amount = usage.shortage
            meta = f"{_format_count(usage.owned, compact=True)} / {_format_count(usage.required, compact=True)} · 계획 {len(usage.impacts)}명"
            tooltip = f"{usage.name}\n계획 부족 {usage.shortage:,} / 필요 {usage.required:,}"
        item = QListWidgetItem("")
        item.setSizeHint(QSize(scale_px(170, self._ui_scale), scale_px(36, self._ui_scale)))
        item.setData(Qt.UserRole, usage.item_id)
        target.addItem(item)

        row = InventoryPressureRow(ui_scale=self._ui_scale)
        icon_path = _inventory_icon_path(usage.item_id, usage.name)
        row.setData(
            icon_path=icon_path,
            item_id=usage.item_id,
            name=usage.name,
            amount=amount,
            total=usage.pool_required if pool else usage.required,
            meta=meta,
            pool=pool,
        )
        target.setItemWidget(item, row)
        item.setToolTip(tooltip)
        item.setData(Qt.UserRole + 6, "ooparts")

    def _add_inventory_requirement_list_item(self, target: QListWidget, entry: PlanResourceRequirement, *, pool: bool) -> None:
        shortage = max(0, entry.required - entry.owned)
        if shortage <= 0:
            return
        item = QListWidgetItem("")
        item.setSizeHint(QSize(scale_px(170, self._ui_scale), scale_px(36, self._ui_scale)))
        item.setData(Qt.UserRole, entry.key)
        item.setData(Qt.UserRole + 1, entry.name)
        item.setData(Qt.UserRole + 2, entry.owned)
        item.setData(Qt.UserRole + 3, entry.required)
        item.setData(Qt.UserRole + 4, shortage)
        item.setData(Qt.UserRole + 6, entry.category)
        target.addItem(item)

        row = InventoryPressureRow(ui_scale=self._ui_scale)
        row.setData(
            icon_path=entry.icon_path,
            item_id=entry.key,
            name=entry.name,
            amount=shortage,
            total=entry.required,
            meta=(
                f"{_format_count(entry.owned, compact=True)} / {_format_count(entry.required, compact=True)} · "
                f"{'전체 육성 부족' if pool else '계획 부족'}"
            ),
            pool=pool,
        )
        target.setItemWidget(item, row)
        item.setToolTip(f"{entry.name}\n부족 {shortage:,} / 필요 {entry.required:,}")

    def _refresh_inventory_insight_panel(self) -> None:
        if not hasattr(self, "_inventory_insight_summary"):
            return
        self._inventory_plan_priority_list.clear()
        self._inventory_pool_pressure_list.clear()
        if hasattr(self, "_inventory_bottleneck_rows_layout"):
            self._refresh_inventory_common_bottleneck_summary()
        if hasattr(self, "_inventory_school_risk_rows_layout"):
            self._refresh_inventory_school_risk_summary()

        usages = list(self._inventory_oopart_plan_usage.values())
        plan_requirement_top = [
            entry
            for entry in sorted(
                self._inventory_requirement_index.values(),
                key=lambda entry: (-(entry.required - entry.owned), entry.name.lower()),
            )
            if self._inventory_is_common_requirement_category(entry.category) and entry.required > entry.owned
        ][:5]
        pool_priority_rows = self._inventory_pool_pressure_rows()

        if not usages and not plan_requirement_top and not pool_priority_rows:
            self._inventory_insight_summary.setText("아직 계획 또는 전체 육성 기준 오파츠 수요가 없습니다.")
            self._update_inventory_oopart_detail(None)
            return

        self._inventory_insight_summary.setText(self._inventory_plan_diagnosis_text())

        plan_priority_rows = sorted(
            [("usage", usage, usage.shortage, usage.name.lower()) for usage in usages if usage.shortage > 0]
            + [
                ("requirement", entry, entry.required - entry.owned, entry.name.lower())
                for entry in plan_requirement_top
            ],
            key=lambda row: (-row[2], row[3]),
        )[:5]
        if plan_priority_rows:
            for row_type, source, _, _ in plan_priority_rows:
                if row_type == "usage":
                    self._add_inventory_usage_list_item(self._inventory_plan_priority_list, source, pool=False)
                else:
                    self._add_inventory_requirement_list_item(self._inventory_plan_priority_list, source, pool=False)
        else:
            self._inventory_plan_priority_list.addItem("현재 계획 부족이 없습니다.")
        if pool_priority_rows:
            for row_type, source, _, _ in pool_priority_rows:
                if row_type == "usage":
                    self._add_inventory_usage_list_item(self._inventory_pool_pressure_list, source, pool=True)
                else:
                    self._add_inventory_requirement_list_item(self._inventory_pool_pressure_list, source, pool=True)
        else:
            self._inventory_pool_pressure_list.addItem("전체 육성 기준 남은 부족이 없습니다.")

    def _update_inventory_oopart_detail(self, current: QListWidgetItem | None) -> None:
        if not hasattr(self, "_inventory_oopart_detail_title"):
            return
        self._inventory_oopart_impact_list.clear()
        if current is None:
            self._inventory_oopart_detail_title.setText(_tr("inventory.detail.select_oopart"))
            self._set_inventory_detail_status(None)
            self._set_inventory_detail_icon(None, "")
            self._inventory_oopart_detail_summary.setText(_tr("inventory.detail.pick_item"))
            self._clear_inventory_oopart_metrics()
            self._clear_inventory_detail_hints()
            self._resize_inventory_impact_list_to_contents()
            return

        item_id = str(current.data(Qt.UserRole) or "")
        name = str(current.data(Qt.UserRole + 1) or item_id or "오파츠")
        owned = int(current.data(Qt.UserRole + 2) or 0)
        usage = self._inventory_oopart_plan_usage.get(item_id)
        self._inventory_oopart_detail_title.setText(name)
        self._set_inventory_detail_icon(item_id, name)
        if usage is None:
            usage = InventoryOpartPlanUsage(item_id=item_id, name=name, owned=owned)
        else:
            usage.owned = owned

        self._set_inventory_metric_number("owned", owned)
        self._set_inventory_metric_number("required", usage.required, empty_zero=True)
        self._set_inventory_metric_number("shortage", usage.shortage, empty_zero=True)
        self._set_inventory_metric("coverage", self._inventory_coverage(owned, usage.required))
        self._set_inventory_metric_number("pool_required", usage.pool_required, empty_zero=True)
        self._set_inventory_metric_number("pool_shortage", usage.pool_shortage, empty_zero=True)
        self._set_inventory_metric("pool_coverage", self._inventory_coverage(owned, usage.pool_required))
        self._set_inventory_metric_number("ex_required", usage.ex_required, empty_zero=True)
        self._set_inventory_metric_number("skill_required", usage.skill_required, empty_zero=True)
        self._set_inventory_metric("affected", f"계획 {len(usage.impacts):,}명 / 전체 {len(usage.pool_impacts):,}명")

        status = self._inventory_oopart_status(usage)
        self._set_inventory_detail_status(status)
        planned_ids = set(self._plan_goal_map())
        planned_pool_count = sum(1 for impact in usage.pool_impacts if impact.student_id in planned_ids)
        self._inventory_oopart_detail_summary.setText(
            f"상태: {_inventory_status_label(status)}. 전체 육성 영향 학생 {len(usage.pool_impacts):,}명 "
            f"(현재 계획 {planned_pool_count:,}명)."
        )
        next_hint, farm_hint = self._inventory_oopart_decision_hints(usage)
        if hasattr(self, "_inventory_oopart_next_hint"):
            self._inventory_oopart_next_hint.setText(next_hint)
        if hasattr(self, "_inventory_oopart_farm_hint"):
            self._inventory_oopart_farm_hint.setText(farm_hint)
        if hasattr(self, "_inventory_oopart_family_shortage"):
            self._inventory_oopart_family_shortage.setText(self._inventory_oopart_family_shortage_text(item_id))
        if not usage.pool_impacts:
            self._inventory_oopart_impact_list.addItem("표시할 학생 수요가 없습니다.")
            self._resize_inventory_impact_list_to_contents()
            return

        planned_impacts = [impact for impact in usage.impacts if impact.student_id in planned_ids]
        planned_seen = {impact.student_id for impact in planned_impacts}
        remaining_pool = [impact for impact in usage.pool_impacts if impact.student_id not in planned_seen]
        for impact in planned_impacts + remaining_pool:
            is_planned = impact.student_id in planned_ids
            item = QListWidgetItem("")
            item.setSizeHint(QSize(scale_px(260, self._ui_scale), scale_px(64, self._ui_scale)))
            row = InventoryOpartImpactRow(card_asset=self._student_card_asset, ui_scale=self._ui_scale)
            row.setData(
                impact=impact,
                pixmap=self._inventory_student_pixmap(impact.student_id, scale_px(76, self._ui_scale)),
                planned=is_planned,
            )
            if is_planned:
                item.setBackground(QColor("#3a2238"))
                item.setForeground(QColor("#ffe1f0"))
            self._inventory_oopart_impact_list.addItem(item)
            self._inventory_oopart_impact_list.setItemWidget(item, row)
        self._resize_inventory_impact_list_to_contents()

    def _inventory_classify_item(self, item_key: str, payload: dict) -> str:
        item_id = str(payload.get("item_id") or "")
        name = _inventory_display_label(item_key, payload)
        if item_id == "Currency_Icon_Gold":
            return "resources"
        if item_id in _OPART_ITEM_IDS:
            return "ooparts"
        if item_id in _WB_ITEM_IDS or item_id in _WORKBOOK_ID_TO_NAME:
            return "wb"
        if item_id.startswith("Equipment_Icon_Exp_"):
            return "stones"
        if item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
            return "weapon_parts"
        if item_id.startswith("Item_Icon_SkillBook_"):
            return "tech_notes"
        if item_id.startswith("Item_Icon_Material_ExSkill_"):
            return "bd"
        if _report_icon_for_entry(item_id or None, name):
            return "reports"
        return "other"

    def _inventory_snapshot_with_resources(self, inventory: dict[str, dict]) -> dict[str, dict]:
        merged = dict(inventory)
        credit_quantity = _inventory_quantity_value(getattr(self, "_resource_snapshot", {}).get("credit"))
        if credit_quantity is not None:
            merged["Currency_Icon_Gold"] = {
                "item_id": "Currency_Icon_Gold",
                "name": "크레딧",
                "quantity": credit_quantity,
                "item_source": "resources",
            }
        return merged

    def _inventory_convertible_coverage_key(self, item_id: str, name: str, category: str) -> tuple[str, int] | None:
        stone_match = re.match(r"Equipment_Icon_Exp_(\d+)$", item_id)
        if category == "stones" and stone_match:
            return ("stones", int(stone_match.group(1)) + 1)

        weapon_part = _weapon_exp_item_part_and_tier(item_id)
        if category == "weapon_parts" and weapon_part is not None:
            part_key, tier = weapon_part
            return (f"weapon:{part_key}", tier)

        if category == "reports":
            report_token = _report_icon_for_entry(item_id or None, name)
            report_match = re.match(r"report_(\d+)$", report_token or "")
            if report_match:
                return ("reports", int(report_match.group(1)) + 1)
        return None

    def _inventory_convertible_coverage_owned(
        self,
        entries: list[tuple[str, dict]],
        *,
        category: str,
        requirement_index: dict[str, PlanResourceRequirement],
    ) -> dict[str, float]:
        rows: dict[str, dict[str, object]] = {}
        grouped: dict[str, list[str]] = {}
        for item_key, payload in entries:
            item_id = payload.get("item_id")
            item_id_text = str(item_id) if item_id else str(item_key)
            name = _inventory_display_label(item_key, payload)
            family_tier = self._inventory_convertible_coverage_key(item_id_text, name, category)
            if family_tier is None:
                continue
            family, tier = family_tier
            quantity_value = _inventory_quantity_value(payload.get("quantity"))
            owned = float(quantity_value if quantity_value is not None else 0)
            requirement = self._inventory_requirement_for_entry(item_id_text, name, requirement_index)
            required = float(requirement.required if requirement is not None else 0)
            rows[item_id_text] = {
                "family": family,
                "tier": tier,
                "owned": owned,
                "required": required,
            }
            grouped.setdefault(family, []).append(item_id_text)

        effective = {item_id: float(row["owned"]) for item_id, row in rows.items()}
        for item_ids in grouped.values():
            for target_id in item_ids:
                target = rows[target_id]
                target_tier = int(target["tier"])
                adjusted_owned = float(target["owned"])
                for source_id in item_ids:
                    source = rows[source_id]
                    source_tier = int(source["tier"])
                    if source_tier >= target_tier:
                        continue
                    surplus = max(0.0, float(source["owned"]) - float(source["required"]))
                    if surplus <= 0:
                        continue
                    adjusted_owned += surplus / float(4 ** (target_tier - source_tier))
                effective[target_id] = adjusted_owned
        return effective

    def _set_inventory_oopart_family_items(
        self,
        target: QListWidget,
        summary: QLabel,
        oopart_usage: dict[str, InventoryOpartPlanUsage],
    ) -> None:
        target.clear()
        if not self._inventory_oopart_selected_id and OPART_DEFINITIONS:
            self._inventory_oopart_selected_id = f"Item_Icon_Material_{OPART_DEFINITIONS[0].icon_key}_3"

        usages = list(oopart_usage.values())
        plan_shortage_items = sum(1 for usage in usages if usage.shortage > 0)
        plan_shortage_total = sum(usage.shortage for usage in usages)
        pool_shortage_items = sum(1 for usage in usages if usage.pool_shortage > 0)
        pool_shortage_total = sum(usage.pool_shortage for usage in usages)
        summary.setText(
            f"{len(OPART_DEFINITIONS)}계열 · 계획 부족 {plan_shortage_items}개 ({plan_shortage_total:,}) · "
            f"전체 육성 부족 {pool_shortage_items}개 ({pool_shortage_total:,})"
        )

        restore_item: QListWidgetItem | None = None
        for definition in OPART_DEFINITIONS:
            tier_items: list[tuple[int, str, str, int, str, Path | None]] = []
            row_selected_id = self._inventory_oopart_selected_id
            family_ids = [f"Item_Icon_Material_{definition.icon_key}_{index}" for index in range(4)]
            if row_selected_id not in family_ids:
                row_selected_id = family_ids[-1]
            for tier_index in range(3, -1, -1):
                item_id = f"Item_Icon_Material_{definition.icon_key}_{tier_index}"
                name = _plan_resource_display_name(item_id, item_id)
                usage = oopart_usage.get(item_id)
                owned = self._inventory_quantity_index_cache.get(item_id, 0)
                status = self._inventory_oopart_status(usage)
                tier_items.append((tier_index + 1, item_id, name, owned, status, _inventory_icon_path(item_id, name)))

            widget = InventoryOpartFamilyRow(
                family_name=definition.family_en,
                tier_items=tier_items,
                selected_item_id=self._inventory_oopart_selected_id if self._inventory_oopart_selected_id in family_ids else None,
                ui_scale=self._ui_scale,
            )
            item = QListWidgetItem()
            item.setFlags(Qt.ItemIsEnabled | Qt.ItemIsSelectable)
            item.setSizeHint(QSize(scale_px(320, self._ui_scale), scale_px(98, self._ui_scale)))
            item.setData(Qt.UserRole, row_selected_id)
            item.setData(Qt.UserRole + 1, _plan_resource_display_name(row_selected_id, row_selected_id))
            item.setData(Qt.UserRole + 2, self._inventory_quantity_index_cache.get(row_selected_id, 0))
            selected_usage = oopart_usage.get(row_selected_id)
            item.setData(Qt.UserRole + 3, selected_usage.required if selected_usage else 0)
            item.setData(Qt.UserRole + 4, selected_usage.shortage if selected_usage else 0)
            item.setData(Qt.UserRole + 5, self._inventory_oopart_status(selected_usage))
            item.setData(Qt.UserRole + 6, "ooparts")
            target.addItem(item)
            target.setItemWidget(item, widget)
            widget.selected.connect(lambda value, list_item=item, row_widget=widget: self._on_inventory_oopart_cell_selected(value, list_item, row_widget))
            if self._inventory_oopart_selected_id in family_ids:
                restore_item = item

        if restore_item is None and target.count() > 0:
            restore_item = target.item(0)
            self._inventory_oopart_selected_id = str(restore_item.data(Qt.UserRole) or "")
        target.setCurrentItem(restore_item)
        self._update_inventory_oopart_detail(restore_item)

    def _set_inventory_list_items(
        self,
        target: QListWidget,
        summary: QLabel,
        entries: list[tuple[str, dict]],
        *,
        category: str = "",
        oopart_usage: dict[str, InventoryOpartPlanUsage] | None = None,
        priority_statuses: dict[str, str] | None = None,
    ) -> None:
        target.clear()
        requirement_index = getattr(self, "_inventory_requirement_index", {})
        pool_requirement_index = getattr(self, "_inventory_pool_requirement_index", {})
        if not entries:
            summary.setText(_tr("inventory.no_scanned_category"))
            target.addItem(_tr("inventory.scan_to_populate"))
            if category == "ooparts":
                self._inventory_oopart_selected_id = None
                self._update_inventory_oopart_detail(None)
            return

        total_quantity = sum(
            quantity
            for _item_key, payload in entries
            if (quantity := _inventory_quantity_value(payload.get("quantity"))) is not None
        )
        summary.setText(_tr("inventory.summary", count=len(entries), quantity=_format_count(total_quantity, compact=True)))

        if category == "ooparts" and oopart_usage:
            shortage_items = sum(1 for usage in oopart_usage.values() if usage.shortage > 0)
            total_shortage = sum(usage.shortage for usage in oopart_usage.values())
            pool_shortage_items = sum(1 for usage in oopart_usage.values() if usage.pool_shortage > 0)
            pool_total_shortage = sum(usage.pool_shortage for usage in oopart_usage.values())
            plan_top = sorted(oopart_usage.values(), key=lambda usage: (-usage.shortage, usage.name.lower()))[:3]
            pool_top = sorted(oopart_usage.values(), key=lambda usage: (-usage.pool_shortage, usage.name.lower()))[:3]
            plan_top_text = ", ".join(f"{usage.name} {_format_count(usage.shortage, compact=True)}" for usage in plan_top if usage.shortage > 0) or "없음"
            pool_top_text = ", ".join(f"{usage.name} {_format_count(usage.pool_shortage, compact=True)}" for usage in pool_top if usage.pool_shortage > 0) or "없음"
            summary.setText(
                f"{len(entries)}개 · 총 수량 {_format_count(total_quantity, compact=True)} · "
                f"계획 부족 {shortage_items}개 ({_format_count(total_shortage, compact=True)}) · "
                f"전체 육성 부족 {pool_shortage_items}개 ({_format_count(pool_total_shortage, compact=True)})\n"
                f"계획 우선순위: {plan_top_text}\n"
                f"전체 육성 부족: {pool_top_text}"
            )

        plan_coverage_owned = self._inventory_convertible_coverage_owned(
            entries,
            category=category,
            requirement_index=requirement_index,
        )
        pool_coverage_owned = self._inventory_convertible_coverage_owned(
            entries,
            category=category,
            requirement_index=pool_requirement_index,
        )

        restore_item: QListWidgetItem | None = None
        for item_key, payload in entries:
            item_id = payload.get("item_id")
            item_id_text = str(item_id) if item_id else str(item_key)
            name = _inventory_display_label(item_key, payload)
            quantity_value = _inventory_quantity_value(payload.get("quantity"))
            owned = quantity_value if quantity_value is not None else 0
            requirement = self._inventory_requirement_for_entry(item_id_text, name, requirement_index)
            required = requirement.required if requirement is not None else 0
            plan_short = max(0, required - owned)
            pool_requirement = self._inventory_requirement_for_entry(item_id_text, name, pool_requirement_index)
            pool_required = pool_requirement.required if pool_requirement is not None else 0
            pool_left = max(0, pool_required - owned)
            usage = oopart_usage.get(item_id_text) if oopart_usage else None
            priority_status = priority_statuses.get(item_id_text) if priority_statuses else None
            shortage = bool(usage and (usage.shortage > 0 or usage.pool_shortage > 0))
            if usage and usage.required > 0:
                quantity = _format_count(owned, compact=True)
                meta = (
                    f"계획 필요 {_format_count(usage.required, compact=True)} · 계획 부족 {_format_count(usage.shortage, compact=True)} · "
                    f"전체 육성 필요 {_format_count(usage.pool_required, compact=True)} · 전체 육성 부족 {_format_count(usage.pool_shortage, compact=True)} · "
                    f"EX {_format_count(usage.ex_required, compact=True)} / 일반 {_format_count(usage.skill_required, compact=True)} · 계획 {len(usage.impacts)}명"
                )
            elif usage and usage.pool_required > 0:
                quantity = _format_count(owned, compact=True)
                meta = (
                    f"계획 수요 없음 · 전체 육성 필요 {_format_count(usage.pool_required, compact=True)} · "
                    f"전체 육성 부족 {_format_count(usage.pool_shortage, compact=True)} · EX {_format_count(usage.pool_ex_required, compact=True)} / 일반 {_format_count(usage.pool_skill_required, compact=True)}"
                )
            else:
                quantity = _format_count(quantity_value, compact=True) if quantity_value is not None else str(payload.get("quantity") or "?")
                tier = _tier_from_item_id_or_name(item_id_text, name)
                meta_parts = []
                if category:
                    meta_parts.append(_inventory_category_label(category))
                if tier:
                    meta_parts.append(f"T{tier}")
                meta = " - ".join(meta_parts)
            if not usage:
                tier = _tier_from_item_id_or_name(item_id_text, name)
                status = priority_status or self._inventory_status_for_values(owned=owned, required=required, pool_left=pool_left, tier=tier)
                shortage = plan_short > 0 or bool(priority_status)
                plan_need_text = _format_count(required, compact=True) if required > 0 else "-"
                plan_short_text = _format_count(plan_short, compact=True, signed=True) if plan_short > 0 else "-"
                pool_remain_text = _format_count(pool_left, compact=True) if pool_left > 0 else "-"
            else:
                status = priority_status or self._inventory_oopart_status(usage)
                shortage = shortage or bool(priority_status)
                plan_need_text = _format_count(usage.required, compact=True) if usage.required > 0 else "-"
                plan_short_text = _format_count(usage.shortage, compact=True, signed=True) if usage.shortage > 0 else "-"
                pool_remain_text = _format_count(usage.pool_shortage, compact=True) if usage.pool_shortage > 0 else "-"
            plan_effective_owned = plan_coverage_owned.get(item_id_text, float(owned))
            pool_effective_owned = pool_coverage_owned.get(item_id_text, float(owned))
            widget = InventoryListItem(ui_scale=self._ui_scale)
            widget.setData(
                icon_path=_inventory_icon_path(str(item_id) if item_id else None, name),
                item_id=item_id_text or None,
                name=name,
                quantity=quantity,
                meta="" if category == "ooparts" else meta,
                shortage=shortage,
                plan_need=plan_need_text,
                plan_short=plan_short_text,
                pool_remain=pool_remain_text,
                status=status,
                show_text=True,
                owned_value=owned,
                plan_required_value=required if not usage else usage.required,
                pool_required_value=pool_required if not usage else usage.pool_required,
                plan_coverage_owned_value=plan_effective_owned,
                pool_coverage_owned_value=pool_effective_owned,
                owned_tooltip=_full_count_tooltip(owned),
                plan_need_tooltip=_full_count_tooltip(required if not usage else usage.required),
                plan_short_tooltip=_full_count_tooltip(plan_short if not usage else usage.shortage),
                pool_remain_tooltip=_full_count_tooltip(pool_left if not usage else usage.pool_shortage),
            )
            item = QListWidgetItem()
            item.setFlags(Qt.ItemIsEnabled | Qt.ItemIsSelectable)
            item.setSizeHint(QSize(scale_px(640, self._ui_scale), scale_px(64, self._ui_scale)))
            item.setData(Qt.UserRole, item_id_text)
            item.setData(Qt.UserRole + 1, name)
            item.setData(Qt.UserRole + 2, owned)
            item.setData(Qt.UserRole + 3, required if not usage else usage.required)
            item.setData(Qt.UserRole + 4, plan_short if not usage else usage.shortage)
            item.setData(Qt.UserRole + 5, status)
            item.setData(Qt.UserRole + 6, category)
            item.setData(Qt.UserRole + 7, pool_required if not usage else usage.pool_required)
            item.setData(Qt.UserRole + 8, pool_left if not usage else usage.pool_shortage)
            target.addItem(item)
            target.setItemWidget(item, widget)
            if category == "ooparts" and item_id_text == self._inventory_oopart_selected_id:
                restore_item = item

        if category == "ooparts":
            if restore_item is None and target.count() > 0:
                restore_item = target.item(0)
            target.setCurrentItem(restore_item)
            self._update_inventory_oopart_detail(restore_item)

    def _refresh_inventory_tab(self) -> None:
        if not hasattr(self, "_inventory_root_tabs"):
            return

        inventory = self._inventory_snapshot_with_resources(self._inventory_snapshot or {})
        self._inventory_requirement_index = self._inventory_plan_requirement_index()
        self._inventory_pool_requirement_index = self._inventory_full_pool_requirement_index()
        if not inventory:
            self._inventory_summary.setText(_tr("inventory.empty_with_hint"))
            self._inventory_oopart_plan_usage = self._inventory_build_oopart_plan_usage()
            oopart_priority_statuses = self._inventory_oopart_priority_statuses(self._inventory_oopart_plan_usage)
            for key, widget in self._inventory_equipment_lists.items():
                self._set_inventory_list_items(widget, self._inventory_equipment_summaries[key], [])
            for key, widget in self._inventory_item_lists.items():
                if key == "ooparts" and self._inventory_oopart_plan_usage:
                    entries = [
                        (
                            item_id,
                            {
                                "item_id": item_id,
                                "name": usage.name,
                                "quantity": 0,
                                "planned_only": True,
                            },
                        )
                        for item_id, usage in self._inventory_oopart_plan_usage.items()
                    ]
                    entries.sort(key=self._inventory_oopart_sort_key)
                    self._set_inventory_list_items(
                        widget,
                        self._inventory_item_summaries[key],
                        entries,
                        category=key,
                        oopart_usage=self._inventory_oopart_plan_usage,
                        priority_statuses=oopart_priority_statuses,
                    )
                else:
                    self._set_inventory_list_items(widget, self._inventory_item_summaries[key], [], category=key)
            self._refresh_inventory_insight_panel()
            self._schedule_inventory_layout_sync()
            return

        total_quantity = sum(
            quantity
            for payload in inventory.values()
            if (quantity := _inventory_quantity_value(payload.get("quantity"))) is not None
        )
        latest_seen = max((str(payload.get("last_seen_at") or "") for payload in inventory.values()), default="")
        latest_time = _tr("inventory.last_updated", time=latest_seen) if latest_seen else "확인되지 않았습니다"
        self._inventory_summary.setText(
            _tr(
                "inventory.summary_scanned",
                count=len(inventory),
                quantity=_format_count(total_quantity, compact=True),
                time=latest_time,
            )
        )

        self._inventory_oopart_plan_usage = self._inventory_build_oopart_plan_usage()
        self._refresh_inventory_insight_panel()

        equipment_groups: dict[str, list[tuple[str, dict]]] = {series.icon_key: [] for series in EQUIPMENT_SERIES}
        item_groups: dict[str, list[tuple[str, dict]]] = {
            "ooparts": [],
            "wb": [],
            "stones": [],
            "reports": [],
            "weapon_parts": [],
            "tech_notes": [],
            "bd": [],
            "resources": [],
            "other": [],
        }

        for item_key, payload in inventory.items():
            item_id = str(payload.get("item_id") or "")
            if item_id.startswith("Equipment_Icon_") and "_Tier" in item_id:
                series_key = item_id.removeprefix("Equipment_Icon_").split("_Tier", 1)[0]
                if series_key in equipment_groups:
                    equipment_groups[series_key].append((item_key, payload))
                    continue
            item_groups[self._inventory_classify_item(item_key, payload)].append((item_key, payload))

        scanned_oopart_ids = {
            str(payload.get("item_id") or item_key)
            for item_key, payload in item_groups["ooparts"]
        }
        for item_id, usage in self._inventory_oopart_plan_usage.items():
            if item_id in scanned_oopart_ids:
                continue
            item_groups["ooparts"].append(
                (
                    item_id,
                    {
                        "item_id": item_id,
                        "name": usage.name,
                        "quantity": usage.owned,
                        "planned_only": True,
                    },
                )
            )

        known_requirement_ids = {
            str(payload.get("item_id") or item_key)
            for item_key, payload in inventory.items()
        }
        known_requirement_ids.update(str(payload.get("item_id") or item_key) for item_key, payload in item_groups["ooparts"])
        requirement_entries: dict[str, PlanResourceRequirement] = {}
        requirement_entries.update(self._inventory_pool_requirement_index)
        requirement_entries.update(self._inventory_requirement_index)
        for item_id, entry in requirement_entries.items():
            if not self._inventory_is_common_requirement_category(entry.category):
                continue
            if item_id in known_requirement_ids or item_id in _OPART_ITEM_IDS:
                continue
            payload = {
                "item_id": item_id,
                "name": entry.name,
                "quantity": 0,
                "planned_only": True,
            }
            if item_id.startswith("Equipment_Icon_") and "_Tier" in item_id:
                series_key = item_id.removeprefix("Equipment_Icon_").split("_Tier", 1)[0]
                if series_key in equipment_groups:
                    equipment_groups[series_key].append((item_id, payload))
                    known_requirement_ids.add(item_id)
                    continue
            item_groups[self._inventory_classify_item(item_id, payload)].append((item_id, payload))
            known_requirement_ids.add(item_id)

        wb_order = {
            item_id: index
            for index, item_id in enumerate(tuple(_WORKBOOK_ID_TO_NAME) + _WB_ITEM_IDS)
        }
        stone_order = {item_id: index for index, (item_id, _name) in enumerate(EQUIPMENT_EXP_ITEMS)}
        report_order = {token: index for index, token in enumerate(_REPORT_ORDER)}
        weapon_order = {
            item_id: index
            for index, item_id in enumerate(
                [
                    f"Equipment_Icon_WeaponExpGrowth{part_key}_{tier}"
                    for part_key, _label in WEAPON_PART_ITEMS
                    for tier in range(3, -1, -1)
                ]
            )
        }
        def equipment_sort_key(entry: tuple[str, dict]) -> tuple[int, str]:
            item_id = str(entry[1].get("item_id") or "")
            try:
                tier_number = int(item_id.rsplit("_Tier", 1)[-1])
            except ValueError:
                tier_number = -1
            return (-tier_number, _inventory_display_label(entry[0], entry[1]).lower())

        def ordered_sort_key(order_map: dict[str, int], entry: tuple[str, dict]) -> tuple[int, str]:
            item_id = str(entry[1].get("item_id") or "")
            return (order_map.get(item_id, 9999), _inventory_display_label(entry[0], entry[1]).lower())

        equipment_priority_statuses = self._inventory_equipment_priority_statuses(
            [entry for entries in equipment_groups.values() for entry in entries]
        )
        oopart_priority_statuses = self._inventory_oopart_priority_statuses(self._inventory_oopart_plan_usage)

        for series in EQUIPMENT_SERIES:
            entries = sorted(equipment_groups[series.icon_key], key=equipment_sort_key)
            self._set_inventory_list_items(
                self._inventory_equipment_lists[series.icon_key],
                self._inventory_equipment_summaries[series.icon_key],
                entries,
                priority_statuses=equipment_priority_statuses,
            )

        ordered_items = {
            "ooparts": sorted(item_groups["ooparts"], key=self._inventory_oopart_sort_key),
            "wb": sorted(item_groups["wb"], key=lambda entry: ordered_sort_key(wb_order, entry)),
            "stones": sorted(item_groups["stones"], key=lambda entry: ordered_sort_key(stone_order, entry)),
            "reports": sorted(
                item_groups["reports"],
                key=lambda entry: (
                    report_order.get(
                        _report_icon_for_entry(
                            str(entry[1].get("item_id") or "") or None,
                            _inventory_display_label(entry[0], entry[1]),
                        )
                        or "",
                        9999,
                    ),
                    _inventory_display_label(entry[0], entry[1]).lower(),
                ),
            ),
            "weapon_parts": sorted(item_groups["weapon_parts"], key=lambda entry: ordered_sort_key(weapon_order, entry)),
            "tech_notes": sorted(item_groups["tech_notes"], key=lambda entry: self._inventory_school_material_sort_key(entry, material="tech_notes")),
            "bd": sorted(item_groups["bd"], key=lambda entry: self._inventory_school_material_sort_key(entry, material="bd")),
            "resources": sorted(item_groups["resources"], key=lambda entry: _inventory_display_label(entry[0], entry[1]).lower()),
            "other": sorted(item_groups["other"], key=lambda entry: _inventory_display_label(entry[0], entry[1]).lower()),
        }

        for category, entries in ordered_items.items():
            self._set_inventory_list_items(
                self._inventory_item_lists[category],
                self._inventory_item_summaries[category],
                entries,
                category=category,
                oopart_usage=self._inventory_oopart_plan_usage if category == "ooparts" else None,
                priority_statuses=oopart_priority_statuses if category == "ooparts" else None,
            )
        self._schedule_inventory_layout_sync()

    def _build_raid_guide_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        title = QLabel("공략 타임라인")
        title.setObjectName("title")
        subtitle = QLabel("총력전, 대결전, 제약해제결전의 덱과 스킬 사용 타이밍을 오버레이용 데이터로 정리합니다.")
        subtitle.setObjectName("count")
        header_layout.addWidget(title)
        header_layout.addWidget(subtitle)
        layout.addWidget(header)

        splitter = QSplitter(Qt.Horizontal)
        splitter.setObjectName("sectionSplitter")
        splitter.setChildrenCollapsible(False)
        layout.addWidget(splitter, 1)

        list_panel = QFrame()
        list_panel.setObjectName("planSectionPanel")
        list_layout = QVBoxLayout(list_panel)
        list_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        list_layout.setSpacing(scale_px(8, self._ui_scale))
        list_title = QLabel("공략 목록")
        list_title.setObjectName("sectionTitle")
        list_layout.addWidget(list_title)
        self._raid_filter_text = QLineEdit()
        self._raid_filter_text.setPlaceholderText("보스, 난이도, 제목 검색")
        self._raid_filter_text.textChanged.connect(lambda *_: self._refresh_raid_guide_list())
        list_layout.addWidget(self._raid_filter_text)
        self._raid_filter_mode = QComboBox()
        self._raid_filter_mode.addItem("전체 모드", "")
        for mode, label in RAID_GUIDE_MODES.items():
            self._raid_filter_mode.addItem(label, mode)
        self._raid_filter_mode.currentIndexChanged.connect(lambda *_: self._refresh_raid_guide_list())
        list_layout.addWidget(self._raid_filter_mode)
        self._raid_guide_list = RoundedListWidget(ui_scale=self._ui_scale)
        self._raid_guide_list.currentItemChanged.connect(self._on_raid_guide_selected)
        list_layout.addWidget(self._raid_guide_list, 1)
        list_buttons = QGridLayout()
        list_buttons.setContentsMargins(0, 0, 0, 0)
        list_buttons.setHorizontalSpacing(scale_px(6, self._ui_scale))
        list_buttons.setVerticalSpacing(scale_px(6, self._ui_scale))
        self._raid_new_button = QPushButton("새 공략")
        self._raid_edit_button = QPushButton("수정")
        self._raid_duplicate_button = QPushButton("복제")
        self._raid_delete_button = QPushButton("삭제")
        self._raid_share_button = QPushButton("공유")
        self._raid_import_share_button = QPushButton("가져오기")
        self._raid_new_button.clicked.connect(self._new_raid_guide)
        self._raid_edit_button.clicked.connect(self._edit_selected_raid_guide)
        self._raid_duplicate_button.clicked.connect(self._duplicate_selected_raid_guide)
        self._raid_delete_button.clicked.connect(self._delete_selected_raid_guide)
        self._raid_share_button.clicked.connect(self._share_current_raid_guide)
        self._raid_import_share_button.clicked.connect(self._import_raid_guide_share)
        list_buttons.addWidget(self._raid_new_button, 0, 0)
        list_buttons.addWidget(self._raid_edit_button, 0, 1)
        list_buttons.addWidget(self._raid_duplicate_button, 1, 0)
        list_buttons.addWidget(self._raid_delete_button, 1, 1)
        list_buttons.addWidget(self._raid_share_button, 2, 0)
        list_buttons.addWidget(self._raid_import_share_button, 2, 1)
        list_layout.addLayout(list_buttons)
        splitter.addWidget(list_panel)

        editor_panel = QFrame()
        editor_panel.setObjectName("planSectionPanel")
        editor_layout = QVBoxLayout(editor_panel)
        editor_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        editor_layout.setSpacing(scale_px(10, self._ui_scale))

        meta_panel = QFrame()
        meta_panel.setObjectName("planBand")
        meta_layout = QGridLayout(meta_panel)
        meta_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        meta_layout.setHorizontalSpacing(scale_px(8, self._ui_scale))
        meta_layout.setVerticalSpacing(scale_px(8, self._ui_scale))
        self._raid_title_input = QLineEdit()
        self._raid_title_input.setPlaceholderText("공략 제목")
        self._raid_mode_input = InventorySortDropdownButton()
        for mode, label in RAID_GUIDE_MODES.items():
            self._raid_mode_input.addItem(label, mode)
        self._raid_mode_input.modeChanged.connect(lambda *_: self._on_raid_mode_changed())
        self._raid_boss_input = InventorySortDropdownButton()
        for boss in RAID_BOSS_TIME_LIMIT_SECONDS:
            self._raid_boss_input.addItem(boss, boss)
        self._raid_boss_input.addItem(RAID_CUSTOM_INPUT_LABEL, "")
        self._raid_boss_input.modeChanged.connect(lambda *_: self._on_raid_boss_changed())
        self._raid_boss_custom_input = QLineEdit()
        self._raid_boss_custom_input.setPlaceholderText("보스 직접 입력")
        self._raid_boss_custom_input.textChanged.connect(lambda *_: self._on_raid_boss_changed())
        boss_input_wrap = QWidget()
        boss_input_wrap.setObjectName("planTransparent")
        boss_input_layout = QHBoxLayout(boss_input_wrap)
        boss_input_layout.setContentsMargins(0, 0, 0, 0)
        boss_input_layout.setSpacing(scale_px(6, self._ui_scale))
        boss_input_layout.addWidget(self._raid_boss_input, 1)
        boss_input_layout.addWidget(self._raid_boss_custom_input, 1)
        self._raid_difficulty_input = InventorySortDropdownButton()
        for difficulty in RAID_GUIDE_DIFFICULTIES:
            self._raid_difficulty_input.addItem(difficulty, difficulty)
        self._raid_difficulty_input.addItem(RAID_CUSTOM_INPUT_LABEL, "")
        self._raid_difficulty_input.modeChanged.connect(lambda *_: self._sync_raid_difficulty_custom_visibility())
        self._raid_difficulty_custom_input = QLineEdit()
        self._raid_difficulty_custom_input.setPlaceholderText("난이도 직접 입력")
        difficulty_input_wrap = QWidget()
        difficulty_input_wrap.setObjectName("planTransparent")
        difficulty_input_layout = QHBoxLayout(difficulty_input_wrap)
        difficulty_input_layout.setContentsMargins(0, 0, 0, 0)
        difficulty_input_layout.setSpacing(scale_px(6, self._ui_scale))
        difficulty_input_layout.addWidget(self._raid_difficulty_input, 1)
        difficulty_input_layout.addWidget(self._raid_difficulty_custom_input, 1)
        self._raid_terrain_input = InventorySortDropdownButton()
        for terrain in ("실내전", "시가전", "야전"):
            self._raid_terrain_input.addItem(terrain, terrain)
        self._raid_time_limit_input = QSpinBox()
        self._raid_time_limit_input.setRange(0, 9999)
        self._raid_time_limit_input.setButtonSymbols(QAbstractSpinBox.NoButtons)
        time_limit_wrap = QWidget()
        time_limit_wrap.setObjectName("planTransparent")
        time_limit_layout = QHBoxLayout(time_limit_wrap)
        time_limit_layout.setContentsMargins(0, 0, 0, 0)
        time_limit_layout.setSpacing(scale_px(6, self._ui_scale))
        time_limit_layout.addWidget(self._raid_time_limit_input, 1)
        time_limit_label = QLabel("sec")
        time_limit_label.setObjectName("detailMiniSub")
        time_limit_layout.addWidget(time_limit_label)
        self._raid_notes_input = ImmediatePlaceholderPlainTextEdit()
        self._raid_notes_input.setPlaceholderText("공략 전체 메모")
        self._raid_notes_input.setMaximumHeight(scale_px(72, self._ui_scale))
        self._raid_editor_state_label = QLabel("")
        self._raid_editor_state_label.setWordWrap(True)
        meta_layout.addWidget(QLabel("제목"), 0, 0)
        meta_layout.addWidget(self._raid_title_input, 0, 1, 1, 3)
        meta_layout.addWidget(QLabel("모드"), 1, 0)
        meta_layout.addWidget(self._raid_mode_input, 1, 1)
        meta_layout.addWidget(QLabel("지형"), 1, 2)
        meta_layout.addWidget(self._raid_terrain_input, 1, 3)
        meta_layout.addWidget(QLabel("보스"), 2, 0)
        meta_layout.addWidget(boss_input_wrap, 2, 1, 1, 3)
        meta_layout.addWidget(QLabel("난이도"), 3, 0)
        meta_layout.addWidget(difficulty_input_wrap, 3, 1)
        meta_layout.addWidget(QLabel("제한시간"), 3, 2)
        meta_layout.addWidget(time_limit_wrap, 3, 3)
        meta_layout.addWidget(self._raid_notes_input, 4, 0, 1, 4)
        meta_layout.addWidget(self._raid_editor_state_label, 5, 0, 1, 4)
        list_layout.insertWidget(0, meta_panel)

        step_row = QHBoxLayout()
        step_row.setContentsMargins(0, 0, 0, 0)
        step_row.setSpacing(scale_px(8, self._ui_scale))
        self._raid_deck_step_button = QPushButton("1. 덱 설정")
        self._raid_timeline_step_button = QPushButton("2. 타임라인 작성")
        self._raid_deck_step_button.clicked.connect(lambda: self._set_raid_editor_step(0))
        self._raid_timeline_step_button.clicked.connect(self._go_raid_timeline_step)
        step_row.addWidget(self._raid_deck_step_button)
        step_row.addWidget(self._raid_timeline_step_button)
        step_row.addStretch(1)
        editor_layout.addLayout(step_row)

        self._raid_editor_stack = QStackedWidget()
        self._raid_editor_stack.setObjectName("sectionTransparentStack")

        deck_panel = QFrame()
        deck_panel.setObjectName("planBand")
        deck_layout = QVBoxLayout(deck_panel)
        deck_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        deck_header = QLabel("덱")
        deck_header.setObjectName("sectionTitle")
        deck_layout.addWidget(deck_header)
        self._raid_deck_preview_host = QWidget()
        self._raid_deck_preview_host.setObjectName("planTransparent")
        self._raid_deck_preview_grid = QGridLayout(self._raid_deck_preview_host)
        self._raid_deck_preview_grid.setContentsMargins(0, 0, 0, 0)
        self._raid_deck_preview_grid.setHorizontalSpacing(scale_px(10, self._ui_scale))
        self._raid_deck_preview_grid.setVerticalSpacing(scale_px(5, self._ui_scale))
        deck_layout.addWidget(self._raid_deck_preview_host)
        template_row = QHBoxLayout()
        template_row.setContentsMargins(0, 0, 0, 0)
        template_row.setSpacing(scale_px(6, self._ui_scale))
        self._raid_deck_template_input = QLineEdit()
        self._raid_deck_template_input.setPlaceholderText("스트라이커1 스트라이커2 ... 스페셜1 스페셜2  예: 드히나 수시노 아코 히마리")
        self._raid_deck_template_input.returnPressed.connect(self._import_raid_deck_template)
        template_import_button = QPushButton("Import")
        template_copy_button = QPushButton("Copy")
        template_import_button.clicked.connect(self._import_raid_deck_template)
        template_copy_button.clicked.connect(self._copy_raid_deck_template)
        template_row.addWidget(self._raid_deck_template_input, 1)
        template_row.addWidget(template_import_button)
        template_row.addWidget(template_copy_button)
        deck_layout.addLayout(template_row)
        order_row = QHBoxLayout()
        order_row.setContentsMargins(0, 0, 0, 0)
        order_row.setSpacing(scale_px(6, self._ui_scale))
        self._raid_order_pick_button = QPushButton("순서 설정")
        self._raid_order_pick_button.setCheckable(True)
        self._raid_order_pick_button.setToolTip("켜둔 상태에서 캐릭터 아이콘을 누르면 1번부터 첫 사용 순서가 붙습니다. 이미 번호가 붙은 아이콘을 누르면 해당 번호를 제거합니다.")
        self._raid_order_pick_button.toggled.connect(self._update_raid_order_status)
        self._raid_order_clear_button = QPushButton("순서 초기화")
        self._raid_order_clear_button.setToolTip("모든 첫 사용 순서를 지웁니다.")
        self._raid_order_clear_button.clicked.connect(self._clear_raid_first_orders)
        self._raid_order_status = QLabel("")
        self._raid_order_status.setObjectName("filterSummary")
        self._raid_order_status.setWordWrap(True)
        order_row.addWidget(self._raid_order_pick_button)
        order_row.addWidget(self._raid_order_clear_button)
        order_row.addWidget(self._raid_order_status, 1)
        deck_layout.addLayout(order_row)
        detail_panel = QFrame()
        detail_panel.setObjectName("planSectionPanel")
        detail_layout = QGridLayout(detail_panel)
        detail_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        detail_layout.setHorizontalSpacing(scale_px(10, self._ui_scale))
        detail_layout.setVerticalSpacing(scale_px(8, self._ui_scale))
        self._raid_slot_detail_title = QLabel("슬롯을 선택하세요")
        self._raid_slot_detail_title.setObjectName("sectionTitle")
        self._raid_slot_detail_student = QLabel("")
        self._raid_slot_detail_student.setObjectName("detailSub")
        self._raid_slot_student_input = QLineEdit()
        self._raid_slot_student_input.setPlaceholderText("학생 이름 또는 별칭")
        self._raid_slot_student_input.editingFinished.connect(self._apply_selected_raid_slot_student_text)
        self._raid_slot_borrowed = QCheckBox("대여 학생")
        self._raid_slot_borrowed.stateChanged.connect(self._update_selected_raid_slot_detail)
        condition_panel = QFrame()
        condition_panel.setObjectName("planTransparent")
        condition_layout = QVBoxLayout(condition_panel)
        condition_layout.setContentsMargins(0, 0, 0, 0)
        condition_layout.setSpacing(scale_px(7, self._ui_scale))
        condition_title = QLabel("육성 조건")
        condition_title.setObjectName("sectionTitle")
        condition_layout.addWidget(condition_title)
        star_row = QHBoxLayout()
        star_row.setContentsMargins(0, 0, 0, 0)
        star_row.setSpacing(scale_px(6, self._ui_scale))
        star_label = QLabel("성작")
        star_label.setObjectName("detailMiniSub")
        self._raid_slot_star_selector = PlanSegmentSelector(9, color_break=5, ui_scale=self._ui_scale)
        self._raid_slot_star_selector.valueChanged.connect(self._update_selected_raid_slot_detail)
        star_row.addWidget(star_label)
        star_row.addWidget(self._raid_slot_star_selector, 1)
        condition_layout.addLayout(star_row)
        skill_grid = QGridLayout()
        skill_grid.setContentsMargins(0, 0, 0, 0)
        skill_grid.setHorizontalSpacing(scale_px(6, self._ui_scale))
        skill_grid.setVerticalSpacing(scale_px(3, self._ui_scale))
        self._raid_slot_skill_inputs: dict[str, QSpinBox] = {}
        for column, (key, label, maximum) in enumerate((
            ("ex", "EX", 5),
            ("basic", "기본", 10),
            ("enhanced", "강화", 10),
            ("sub", "서브", 10),
        )):
            spin = MaxTokenSpinBox(show_max_token=True)
            spin.setRange(0, maximum)
            spin.setSpecialValueText("-")
            spin.valueChanged.connect(self._update_selected_raid_slot_detail)
            skill_label = QLabel(label)
            skill_label.setObjectName("detailMiniSub")
            skill_grid.addWidget(skill_label, 0, column)
            skill_grid.addWidget(spin, 1, column)
            self._raid_slot_skill_inputs[key] = spin
        condition_layout.addLayout(skill_grid)
        equipment_grid = QGridLayout()
        equipment_grid.setContentsMargins(0, 0, 0, 0)
        equipment_grid.setHorizontalSpacing(scale_px(6, self._ui_scale))
        equipment_grid.setVerticalSpacing(scale_px(3, self._ui_scale))
        self._raid_slot_equipment_inputs: dict[str, QSpinBox] = {}
        self._raid_slot_equipment_labels: dict[str, QLabel] = {}
        for column, (key, label, maximum) in enumerate((
            ("equip1", "장비1", 10),
            ("equip2", "장비2", 10),
            ("equip3", "장비3", 10),
            ("unique", "애용품", 2),
        )):
            spin = MaxTokenSpinBox()
            spin.setRange(0, maximum)
            spin.setSpecialValueText("-")
            spin.setPrefix("T")
            spin.valueChanged.connect(self._update_selected_raid_slot_detail)
            equipment_label = QLabel(label)
            equipment_label.setObjectName("detailMiniSub")
            equipment_grid.addWidget(equipment_label, 0, column)
            equipment_grid.addWidget(spin, 1, column)
            self._raid_slot_equipment_labels[key] = equipment_label
            self._raid_slot_equipment_inputs[key] = spin
        condition_layout.addLayout(equipment_grid)
        stat_grid = QGridLayout()
        stat_grid.setContentsMargins(0, 0, 0, 0)
        stat_grid.setHorizontalSpacing(scale_px(6, self._ui_scale))
        stat_grid.setVerticalSpacing(scale_px(3, self._ui_scale))
        self._raid_slot_stat_inputs: dict[str, QSpinBox] = {}
        for column, (key, label) in enumerate((
            ("hp", "HP"),
            ("atk", "ATK"),
            ("heal", "HEAL"),
        )):
            spin = MaxTokenSpinBox()
            spin.setRange(0, 25)
            spin.valueChanged.connect(self._update_selected_raid_slot_detail)
            max_button = QPushButton("MAX")
            max_button.setFixedWidth(scale_px(48, self._ui_scale))
            max_button.clicked.connect(lambda _checked=False, target=spin: target.setValue(target.maximum()))
            stat_label = QLabel(label)
            stat_label.setObjectName("detailMiniSub")
            stat_input_row = QHBoxLayout()
            stat_input_row.setContentsMargins(0, 0, 0, 0)
            stat_input_row.setSpacing(scale_px(4, self._ui_scale))
            stat_input_row.addWidget(spin, 1)
            stat_input_row.addWidget(max_button)
            stat_grid.addWidget(stat_label, 0, column)
            stat_grid.addLayout(stat_input_row, 1, column)
            self._raid_slot_stat_inputs[key] = spin
        condition_layout.addLayout(stat_grid)
        condition_layout.addStretch(1)
        notes_panel = QFrame()
        notes_panel.setObjectName("planTransparent")
        notes_layout = QVBoxLayout(notes_panel)
        notes_layout.setContentsMargins(0, 0, 0, 0)
        notes_layout.setSpacing(scale_px(6, self._ui_scale))
        notes_title = QLabel("슬롯 메모")
        notes_title.setObjectName("sectionTitle")
        notes_layout.addWidget(notes_title)
        self._raid_slot_notes = ImmediatePlaceholderPlainTextEdit()
        self._raid_slot_notes.setPlaceholderText("선택한 학생/슬롯 메모")
        self._raid_slot_notes.setMinimumHeight(scale_px(128, self._ui_scale))
        self._raid_slot_notes.textChanged.connect(self._update_selected_raid_slot_detail)
        notes_layout.addWidget(self._raid_slot_notes, 1)
        detail_body = QWidget()
        detail_body.setObjectName("planTransparent")
        detail_body_layout = QHBoxLayout(detail_body)
        detail_body_layout.setContentsMargins(0, 0, 0, 0)
        detail_body_layout.setSpacing(scale_px(12, self._ui_scale))
        detail_body_layout.addWidget(condition_panel, 1)
        detail_body_layout.addWidget(notes_panel, 1)
        detail_layout.addWidget(self._raid_slot_detail_title, 0, 0)
        detail_layout.addWidget(self._raid_slot_student_input, 0, 1)
        detail_layout.addWidget(self._raid_slot_borrowed, 0, 2)
        detail_layout.addWidget(detail_body, 1, 0, 1, 3)
        detail_layout.setColumnStretch(1, 1)
        deck_layout.addWidget(detail_panel)
        deck_action_row = QHBoxLayout()
        deck_action_row.setContentsMargins(0, 0, 0, 0)
        self._raid_deck_status = QLabel("")
        self._raid_deck_status.setObjectName("filterSummary")
        self._raid_deck_status.setWordWrap(True)
        self._raid_to_timeline_button = QPushButton("타임라인 작성으로")
        self._raid_to_timeline_button.clicked.connect(self._go_raid_timeline_step)
        deck_save_button = QPushButton("저장")
        deck_save_button.clicked.connect(self._save_current_raid_guide)
        deck_action_row.addWidget(self._raid_deck_status, 1)
        deck_action_row.addWidget(deck_save_button)
        deck_action_row.addWidget(self._raid_to_timeline_button)
        deck_layout.addLayout(deck_action_row)

        timeline_panel = QFrame()
        timeline_panel.setObjectName("planBand")
        timeline_layout = QVBoxLayout(timeline_panel)
        timeline_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        timeline_layout.setSpacing(scale_px(8, self._ui_scale))
        action_row = QHBoxLayout()
        action_row.setContentsMargins(0, 0, 0, 0)
        timeline_title = QLabel("타임라인")
        timeline_title.setObjectName("sectionTitle")
        action_row.addWidget(timeline_title)
        edit_deck_button = QPushButton("덱 수정")
        edit_deck_button.clicked.connect(lambda: self._set_raid_editor_step(0))
        action_row.addWidget(edit_deck_button)
        assist_button = QPushButton("보조 모드")
        assist_button.clicked.connect(self._open_raid_assist)
        action_row.addWidget(assist_button)
        action_row.addStretch(1)
        for label, callback in (
            ("행 추가", self._add_raid_timeline_row),
            ("복제", self._duplicate_raid_timeline_row),
            ("삭제", self._delete_raid_timeline_row),
            ("위", lambda: self._move_raid_timeline_row(-1)),
            ("아래", lambda: self._move_raid_timeline_row(1)),
        ):
            button = QPushButton(label)
            button.clicked.connect(callback)
            action_row.addWidget(button)
        timeline_layout.addLayout(action_row)

        self._raid_deck_summary_host = QWidget()
        self._raid_deck_summary_host.setObjectName("planTransparent")
        self._raid_deck_summary_grid = QGridLayout(self._raid_deck_summary_host)
        self._raid_deck_summary_grid.setContentsMargins(0, 0, 0, 0)
        self._raid_deck_summary_grid.setHorizontalSpacing(scale_px(8, self._ui_scale))
        self._raid_deck_summary_grid.setVerticalSpacing(scale_px(6, self._ui_scale))
        timeline_layout.addWidget(self._raid_deck_summary_host)

        self._raid_timeline_table = QTableWidget(0, 5)
        self._raid_timeline_table.setHorizontalHeaderLabels(
            ["사용 타이밍", "사용 스킬", "시전 대상", "메모", "이미지"]
        )
        self._raid_timeline_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self._raid_timeline_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self._raid_timeline_table.setEditTriggers(QAbstractItemView.AllEditTriggers)
        self._raid_timeline_table.setAlternatingRowColors(True)
        timeline_font = QFont(self._raid_timeline_table.font())
        if timeline_font.pointSize() > 0:
            timeline_font.setPointSize(timeline_font.pointSize() + 1)
        elif timeline_font.pixelSize() > 0:
            timeline_font.setPixelSize(timeline_font.pixelSize() + 1)
        else:
            timeline_font.setPointSize(11)
        self._raid_timeline_table.setFont(timeline_font)
        self._raid_timeline_table.verticalHeader().setVisible(True)
        self._raid_timeline_table.verticalHeader().setDefaultSectionSize(scale_px(30, self._ui_scale))
        header_view = self._raid_timeline_table.horizontalHeader()
        header_view.setSectionResizeMode(QHeaderView.Interactive)
        header_view.setSectionResizeMode(3, QHeaderView.Stretch)
        self._raid_timeline_table.setColumnWidth(0, scale_px(150, self._ui_scale))
        self._raid_timeline_table.setColumnWidth(1, scale_px(180, self._ui_scale))
        self._raid_timeline_table.setColumnWidth(2, scale_px(160, self._ui_scale))
        self._raid_timeline_table.setColumnWidth(4, scale_px(130, self._ui_scale))
        self._raid_timeline_table.itemChanged.connect(self._on_raid_timeline_item_changed)
        timeline_layout.addWidget(self._raid_timeline_table, 1)

        paste_row = QHBoxLayout()
        paste_row.setContentsMargins(0, 0, 0, 0)
        self._raid_paste_input = QPlainTextEdit()
        self._raid_paste_input.setPlaceholderText("아카라이브 표나 텍스트 타임라인을 붙여넣고 가져오기를 누르세요.")
        self._raid_paste_input.setMaximumHeight(scale_px(86, self._ui_scale))
        paste_button = QPushButton("붙여넣기 가져오기")
        paste_button.clicked.connect(self._import_raid_timeline_text)
        paste_row.addWidget(self._raid_paste_input, 1)
        paste_row.addWidget(paste_button)
        timeline_layout.addLayout(paste_row)

        bottom_row = QHBoxLayout()
        bottom_row.setContentsMargins(0, 0, 0, 0)
        self._raid_status = QLabel("")
        self._raid_status.setObjectName("filterSummary")
        self._raid_status.setWordWrap(True)
        bottom_row.addWidget(self._raid_status, 1)
        save_button = QPushButton("저장")
        save_button.clicked.connect(self._save_current_raid_guide)
        bottom_assist_button = QPushButton("보조 모드")
        bottom_assist_button.clicked.connect(self._open_raid_assist)
        bottom_row.addWidget(save_button)
        bottom_row.addWidget(bottom_assist_button)
        timeline_layout.addLayout(bottom_row)
        self._raid_editor_stack.addWidget(deck_panel)
        self._raid_editor_stack.addWidget(timeline_panel)
        editor_layout.addWidget(self._raid_editor_stack, 1)
        splitter.addWidget(editor_panel)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 7)

        self._selected_raid_guide_id = self._raid_guide_data.guides[0].id if self._raid_guide_data.guides else None
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()
        self._set_raid_editor_step(0)

    def _current_raid_guide(self) -> RaidGuide | None:
        selected_id = getattr(self, "_selected_raid_guide_id", None)
        for guide in self._raid_guide_data.guides:
            if guide.id == selected_id:
                return guide
        return self._raid_guide_data.guides[0] if self._raid_guide_data.guides else None

    def _set_raid_combo_text(self, combo: QComboBox, value: str) -> None:
        text = str(value or "").strip()
        combo.blockSignals(True)
        if text:
            index = combo.findText(text, Qt.MatchFixedString)
            if index >= 0:
                combo.setCurrentIndex(index)
            else:
                combo.setCurrentIndex(-1)
                combo.setEditText(text)
        else:
            combo.setCurrentIndex(-1)
            combo.setEditText("")
        combo.blockSignals(False)

    def _raid_combo_text(self, combo: QComboBox) -> str:
        text = combo.currentText().strip()
        return "" if text == RAID_CUSTOM_INPUT_LABEL else text

    def _raid_current_boss(self) -> str:
        if not hasattr(self, "_raid_boss_input"):
            return ""
        data = str(self._raid_boss_input.currentData() or "").strip()
        if data:
            return data
        return self._raid_boss_custom_input.text().strip() if hasattr(self, "_raid_boss_custom_input") else ""

    def _set_raid_boss_value(self, value: str) -> None:
        if not hasattr(self, "_raid_boss_input"):
            return
        boss = str(value or "").strip()
        if boss and boss in RAID_BOSS_TIME_LIMIT_SECONDS:
            self._raid_boss_input.setCurrentData(boss)
            if hasattr(self, "_raid_boss_custom_input"):
                self._raid_boss_custom_input.clear()
                self._raid_boss_custom_input.hide()
        else:
            self._raid_boss_input.setCurrentData("")
            if hasattr(self, "_raid_boss_custom_input"):
                self._raid_boss_custom_input.setText(boss)
                self._raid_boss_custom_input.show()

    def _sync_raid_difficulty_custom_visibility(self) -> None:
        if not hasattr(self, "_raid_difficulty_custom_input"):
            return
        self._raid_difficulty_custom_input.setVisible(not str(self._raid_difficulty_input.currentData() or "").strip())

    def _raid_current_difficulty(self) -> str:
        if not hasattr(self, "_raid_difficulty_input"):
            return ""
        data = str(self._raid_difficulty_input.currentData() or "").strip()
        if data:
            return data
        return self._raid_difficulty_custom_input.text().strip() if hasattr(self, "_raid_difficulty_custom_input") else ""

    def _set_raid_difficulty_value(self, value: str) -> None:
        if not hasattr(self, "_raid_difficulty_input"):
            return
        difficulty = str(value or "").strip()
        if difficulty and difficulty in RAID_GUIDE_DIFFICULTIES:
            self._raid_difficulty_input.setCurrentData(difficulty)
            if hasattr(self, "_raid_difficulty_custom_input"):
                self._raid_difficulty_custom_input.clear()
                self._raid_difficulty_custom_input.hide()
        else:
            self._raid_difficulty_input.setCurrentData("")
            if hasattr(self, "_raid_difficulty_custom_input"):
                self._raid_difficulty_custom_input.setText(difficulty)
                self._raid_difficulty_custom_input.show()

    def _raid_generated_title(self, *, terrain: str, boss: str, difficulty: str) -> str:
        parts = [
            str(terrain or "지형").strip() or "지형",
            str(boss or "보스").strip() or "보스",
            str(difficulty or "난이도").strip() or "난이도",
        ]
        return "_".join(parts)

    def _raid_guide_display_title(self, guide: RaidGuide) -> str:
        title = str(guide.title or "").strip()
        if title:
            return title
        return self._raid_generated_title(terrain=guide.terrain, boss=guide.boss, difficulty=guide.difficulty)

    def _raid_unique_generated_title(self, base_title: str, current_guide_id: str) -> str:
        base = str(base_title or "").strip() or self._raid_generated_title(terrain="", boss="", difficulty="")
        data = getattr(self, "_raid_guide_data", None)
        existing_titles: set[str] = set()
        for guide in getattr(data, "guides", []):
            if guide.id == current_guide_id:
                continue
            display_title = self._raid_guide_display_title(guide).strip()
            if display_title:
                existing_titles.add(display_title)
        if base not in existing_titles:
            return base
        suffix = 2
        while f"{base}_{suffix}" in existing_titles:
            suffix += 1
        return f"{base}_{suffix}"

    def _raid_should_generate_title(self, raw_title: str, previous_generated_title: str) -> bool:
        title = str(raw_title or "").strip()
        if not title:
            return True
        if title == previous_generated_title:
            return True
        return title.replace(" ", "") in {"새공략", "공략"}

    def _on_raid_boss_changed(self) -> None:
        if getattr(self, "_raid_guide_editor_guard", False):
            return
        boss = self._raid_current_boss()
        if hasattr(self, "_raid_boss_custom_input"):
            self._raid_boss_custom_input.setVisible(not str(self._raid_boss_input.currentData() or "").strip())
        time_limit = RAID_BOSS_TIME_LIMIT_SECONDS.get(boss)
        if time_limit is not None:
            self._raid_time_limit_input.setValue(time_limit)
        default_mode = RAID_BOSS_DEFAULT_MODES.get(boss)
        if default_mode and self._raid_mode_input.currentData() != default_mode:
            self._raid_mode_input.setCurrentData(default_mode)

    def _set_raid_editor_step(self, index: int) -> None:
        if not hasattr(self, "_raid_editor_stack"):
            return
        self._raid_editor_stack.setCurrentIndex(max(0, min(1, index)))
        active = self._raid_editor_stack.currentIndex()
        self._raid_deck_step_button.setStyleSheet("font-weight: 900;" if active == 0 else "")
        self._raid_timeline_step_button.setStyleSheet("font-weight: 900;" if active == 1 else "")
        if active == 1:
            self._refresh_raid_deck_summary()

    def _refresh_raid_editor_source_state(self) -> None:
        if not hasattr(self, "_raid_editor_state_label"):
            return
        current = self._current_raid_guide()
        if current is None:
            self._raid_editor_state_label.setText("현재 상태: 선택된 공략 없음")
            self._raid_editor_state_label.setStyleSheet(
                f"color: #8a93a7; font-weight: 800; padding: {scale_px(5, self._ui_scale)}px;"
            )
            return
        if current.id in getattr(self, "_raid_new_guide_ids", set()):
            self._raid_editor_state_label.setText("현재 상태: 새 공략 작성 중")
            self._raid_editor_state_label.setStyleSheet(
                "color: #2f80ed; font-weight: 900; "
                f"padding: {scale_px(6, self._ui_scale)}px; "
                "border: 1px solid rgba(47, 128, 237, 0.45); "
                "border-radius: 6px; "
                "background: rgba(47, 128, 237, 0.10);"
            )
            return
        self._raid_editor_state_label.setText("현재 상태: 기존 공략 수정 중")
        self._raid_editor_state_label.setStyleSheet(
            "color: #4f5d75; font-weight: 900; "
            f"padding: {scale_px(6, self._ui_scale)}px; "
            "border: 1px solid rgba(79, 93, 117, 0.28); "
            "border-radius: 6px; "
            "background: rgba(79, 93, 117, 0.08);"
        )

    def _raid_deck_complete(self) -> bool:
        for row in getattr(self, "_raid_deck_rows", []):
            student_id = str(row.get("student_id") or "")
            if not student_id or student_id not in self._records_by_id:
                return False
        return bool(getattr(self, "_raid_deck_rows", []))

    def _go_raid_timeline_step(self) -> None:
        self._sync_raid_deck_slot_icons()
        self._raid_deck_status.setStyleSheet("")
        self._set_raid_editor_step(1)

    def _update_raid_step_state(self) -> None:
        if not hasattr(self, "_raid_to_timeline_button"):
            return
        complete = self._raid_deck_complete()
        self._raid_to_timeline_button.setEnabled(True)
        self._raid_timeline_step_button.setEnabled(True)
        if hasattr(self, "_raid_deck_status"):
            guide = self._collect_raid_guide_from_editor()
            filled = sum(1 for slot in guide.deck if slot.student_id)
            total = len(guide.deck)
            if complete:
                self._raid_deck_status.setStyleSheet("")
                self._raid_deck_status.setText(f"덱 설정 완료 · {filled}/{total}")
            else:
                self._raid_deck_status.setStyleSheet("")
                self._raid_deck_status.setText(f"덱 슬롯 {filled}/{total} 입력")

    def _save_raid_guide_data(self) -> None:
        save_raid_guides(self._raid_guide_path, self._raid_guide_data)
        self._storage_mtimes = self._snapshot_storage_mtimes()

    def _open_raid_assist(self) -> None:
        if not hasattr(self, "_raid_timeline_table"):
            return
        guide = self._collect_raid_guide_from_editor()
        if not guide.timeline:
            if hasattr(self, "_raid_status"):
                self._raid_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
                self._raid_status.setText("Assist needs at least one timeline step.")
            return
        existing = getattr(self, "_raid_assist_window", None)
        if existing is not None:
            existing.close()
        window = TacticAssistWindow(
            guide,
            template_root=TEMPLATE_DIR / "tactic_assist",
            parent=self,
        )
        window.destroyed.connect(lambda *_: setattr(self, "_raid_assist_window", None))
        self._raid_assist_window = window
        window.show()

    def _raid_student_label(self, student_id: str) -> str:
        if not student_id:
            return ""
        record = self._records_by_id.get(student_id)
        return record.title if record is not None else student_meta.display_name(student_id)

    def _raid_lookup_key(self, value: object) -> str:
        cleaned = " ".join(str(value or "").strip().split())
        cleaned = re.sub(r"\s*([()])\s*", r"\1", cleaned)
        return cleaned.casefold()

    def _raid_student_lookup_index_map(self) -> dict[str, list[str]]:
        cached = getattr(self, "_raid_student_lookup_index", None)
        if cached is not None:
            return cached
        index: dict[str, set[str]] = defaultdict(set)
        for student_id in student_meta.all_ids():
            record = self._records_by_id.get(student_id)
            terms: list[object] = [
                student_id,
                student_id.replace("_", " "),
                student_meta.display_name(student_id),
                record.title if record is not None else "",
                record.display_name if record is not None else "",
            ]
            terms.extend(student_meta.search_tags(student_id))
            terms.extend(student_meta.kr_search_tags(student_id))
            for term in terms:
                key = self._raid_lookup_key(term)
                if key:
                    index[key].add(student_id)
        self._raid_student_lookup_index = {
            key: sorted(values, key=lambda student_id: self._raid_student_label(student_id).casefold())
            for key, values in index.items()
        }
        return self._raid_student_lookup_index

    def _raid_student_id_for_text(self, text: str) -> str:
        raw = str(text or "").strip()
        if not raw:
            return ""
        if raw in self._records_by_id or raw in set(student_meta.all_ids()):
            return raw
        matches = self._raid_student_lookup_index_map().get(self._raid_lookup_key(raw), [])
        return matches[0] if len(matches) == 1 else raw

    def _raid_slot_expected_combat_class(self, slot_type: object) -> str:
        return "special" if str(slot_type or "") == "support" else str(slot_type or "")

    def _raid_portrait_pixmap(self, student_id: str, size: int) -> QPixmap:
        if not student_id or student_id not in self._records_by_id:
            return QPixmap()
        source = ensure_thumbnail(student_id, size, size)
        if source is None or not source.exists():
            return QPixmap()
        pixmap = QPixmap(str(source))
        return pixmap if not pixmap.isNull() else QPixmap()

    def _make_raid_student_combo(self, expected_class: str | None = None) -> QComboBox:
        combo = QComboBox()
        combo.setEditable(True)
        combo.addItem("", "")
        records = sorted(self._all_students, key=lambda record: record.title.casefold())
        for record in records:
            if expected_class and student_meta.combat_class(record.student_id) != expected_class:
                continue
            combo.addItem(record.title, record.student_id)
        return combo

    def _set_combo_student(self, combo: QComboBox, student_id: str) -> None:
        if not student_id:
            combo.setCurrentIndex(0)
            return
        index = combo.findData(student_id)
        if index >= 0:
            combo.setCurrentIndex(index)
        else:
            combo.setEditText(self._raid_student_label(student_id) if student_id in self._records_by_id else student_id)

    def _combo_student_id(self, combo: QComboBox) -> str:
        data = combo.currentData()
        if data:
            return str(data)
        return self._raid_student_id_for_text(combo.currentText())

    def _raid_template_label_for_student(self, student_id: str) -> str:
        return self._raid_student_label(student_id) if student_id in self._records_by_id else str(student_id or "")

    def _raid_deck_template_from_slots(self) -> str:
        strikers: list[str] = []
        supports: list[str] = []
        for row in getattr(self, "_raid_deck_rows", []):
            student_id = str(row.get("student_id") or "")
            label = self._raid_template_label_for_student(student_id)
            if row.get("slot_type") == "striker":
                strikers.append(label)
            else:
                supports.append(label)
        tokens = [*strikers, *supports]
        while tokens and not tokens[-1]:
            tokens.pop()
        return " ".join(token or "-" for token in tokens)

    def _sync_raid_template_from_slots(self) -> None:
        if getattr(self, "_raid_template_sync_guard", False) or not hasattr(self, "_raid_deck_template_input"):
            return
        self._raid_template_sync_guard = True
        self._raid_deck_template_input.setText(self._raid_deck_template_from_slots())
        self._raid_template_sync_guard = False

    def _raid_template_parts(self, value: str) -> list[str]:
        text = str(value or "")
        has_explicit_separator = any(separator in text for separator in ",/;")
        if has_explicit_separator:
            parts = text.replace("/", ",").replace(";", ",").replace("\n", ",").split(",")
        else:
            parts = text.split()
        return ["" if part.strip() == "-" else part.strip() for part in parts]

    def _raid_student_ids_for_text(self, text: str) -> list[str]:
        needle = self._raid_lookup_key(text)
        if not needle:
            return []
        return list(self._raid_student_lookup_index_map().get(needle, []))

    def _parse_raid_deck_template(self, value: str) -> tuple[list[str], list[str], list[str]]:
        raw = str(value or "").strip()
        striker_count, support_count = slot_counts_for_mode(str(self._raid_mode_input.currentData() or ""))
        if "|" in raw:
            striker_raw, support_raw = raw.split("|", 1)
            striker_tokens = self._raid_template_parts(striker_raw)
            support_tokens = self._raid_template_parts(support_raw)
        else:
            tokens = self._raid_template_parts(raw)
            striker_tokens = tokens[:striker_count]
            support_tokens = tokens[striker_count : striker_count + support_count]

        errors: list[str] = []

        def resolve(tokens: list[str], expected_class: str, label: str, maximum: int) -> list[str]:
            resolved: list[str] = []
            for index, token in enumerate(tokens[:maximum], start=1):
                if not token:
                    resolved.append("")
                    continue
                matches = self._raid_student_ids_for_text(token)
                if not matches:
                    errors.append(f"{label}{index}: '{token}' 학생을 인식할 수 없습니다.")
                    resolved.append(token)
                    continue
                if len(matches) > 1:
                    names = ", ".join(self._raid_student_label(student_id) for student_id in matches[:6])
                    suffix = "..." if len(matches) > 6 else ""
                    errors.append(f"{label}{index}: '{token}' 중복 태그입니다. ({names}{suffix})")
                    resolved.append(token)
                    continue
                student_id = matches[0]
                if student_meta.combat_class(student_id) != self._raid_slot_expected_combat_class(expected_class):
                    errors.append(f"{label}{index}: '{self._raid_student_label(student_id)}'는 {label} 슬롯에 배치할 수 없습니다.")
                resolved.append(student_id)
            resolved += [""] * max(0, maximum - len(resolved))
            return resolved

        return (
            resolve(striker_tokens, "striker", "S", striker_count),
            resolve(support_tokens, "special", "SP", support_count),
            errors,
        )

    def _apply_raid_deck_template(self, value: str) -> list[str]:
        strikers, supports, errors = self._parse_raid_deck_template(value)
        self._raid_template_sync_guard = True
        for row in getattr(self, "_raid_deck_rows", []):
            source = strikers if row.get("slot_type") == "striker" else supports
            slot_index = int(row.get("slot_index") or 1) - 1
            row["student_id"] = source[slot_index] if slot_index < len(source) else ""
        self._raid_template_sync_guard = False
        self._sync_raid_deck_slot_icons()
        self._sync_raid_template_from_slots()
        self._refresh_selected_raid_slot_detail()
        self._update_raid_step_state()
        self._refresh_raid_validation()
        return errors

    def _import_raid_deck_template(self) -> None:
        value = self._raid_deck_template_input.text().strip() or QApplication.clipboard().text().strip()
        if not value:
            return
        errors = self._apply_raid_deck_template(value)
        if errors:
            self._raid_deck_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
            self._raid_deck_status.setText(" / ".join(errors[:3]) + (f" 외 {len(errors) - 3}개" if len(errors) > 3 else ""))

    def _copy_raid_deck_template(self) -> None:
        text = self._raid_deck_template_from_slots()
        self._raid_deck_template_input.setText(text)
        QApplication.clipboard().setText(text)

    def _sync_raid_deck_slot_icons(self) -> None:
        preview_icons = getattr(self, "_raid_deck_preview_icons", [])
        for index, row in enumerate(getattr(self, "_raid_deck_rows", [])):
            icon = preview_icons[index] if index < len(preview_icons) else None
            if not isinstance(icon, TacticalDeckSlot):
                continue
            student_id = str(row.get("student_id") or "")
            name = self._raid_student_label(student_id) if student_id in self._records_by_id else student_id
            pixmap = self._raid_portrait_pixmap(student_id, max(self._thumb_width, self._thumb_height))
            first_order = int(row.get("first_order") or 0)
            icon.setData(
                name=name,
                pixmap=pixmap,
                badge_text=str(first_order) if first_order > 0 else "",
                corner_badge_text="A" if bool(row.get("borrowed")) else "",
            )
        self._update_raid_order_status()

    def _ordered_raid_deck_indices(self, *, exclude_index: int | None = None) -> list[int]:
        ordered: list[tuple[int, int]] = []
        for index, row in enumerate(getattr(self, "_raid_deck_rows", [])):
            if exclude_index is not None and index == exclude_index:
                continue
            try:
                order = int(row.get("first_order") or 0)
            except (TypeError, ValueError):
                order = 0
            if order > 0:
                ordered.append((order, index))
        return [index for _order, index in sorted(ordered)]

    def _apply_raid_first_order(self, index: int, order: int) -> None:
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows or index < 0 or index >= len(rows):
            return
        ordered_indices = self._ordered_raid_deck_indices(exclude_index=index)
        if order > 0:
            insert_at = max(0, min(order - 1, len(ordered_indices)))
            ordered_indices.insert(insert_at, index)
        for row in rows:
            row["first_order"] = 0
        for order_index, row_index in enumerate(ordered_indices, start=1):
            rows[row_index]["first_order"] = order_index
        self._sync_raid_deck_slot_icons()
        self._refresh_selected_raid_slot_detail()
        self._refresh_raid_validation()

    def _next_raid_first_order(self) -> int:
        rows = getattr(self, "_raid_deck_rows", [])
        used: set[int] = set()
        for row in rows:
            try:
                order = int(row.get("first_order") or 0)
            except (TypeError, ValueError):
                order = 0
            if order > 0:
                used.add(order)
        for order in range(1, len(rows) + 1):
            if order not in used:
                return order
        return len(rows) + 1

    def _update_raid_order_status(self, _checked: bool | None = None) -> None:
        if not hasattr(self, "_raid_order_status"):
            return
        rows = getattr(self, "_raid_deck_rows", [])
        count = 0
        for row in rows:
            try:
                order = int(row.get("first_order") or 0)
            except (TypeError, ValueError):
                order = 0
            if order > 0:
                count += 1
        if hasattr(self, "_raid_order_pick_button") and self._raid_order_pick_button.isChecked():
            self._raid_order_pick_button.setText("확인")
            next_order = self._next_raid_first_order()
            self._raid_order_status.setText(f"아이콘을 누르면 {next_order}번으로 지정됩니다. 번호가 있는 아이콘은 누르면 해제됩니다.")
        else:
            if hasattr(self, "_raid_order_pick_button"):
                self._raid_order_pick_button.setText("순서 설정")
            self._raid_order_status.setText(f"첫 사용 순서 {count}/{len(rows)}")

    def _on_raid_deck_slot_clicked(self, index: int) -> None:
        self._select_raid_deck_slot(index)
        if not hasattr(self, "_raid_order_pick_button") or not self._raid_order_pick_button.isChecked():
            return
        rows = getattr(self, "_raid_deck_rows", [])
        if index < 0 or index >= len(rows):
            return
        if not str(rows[index].get("student_id") or ""):
            self._update_raid_order_status()
            return
        current_order = int(rows[index].get("first_order") or 0)
        self._apply_raid_first_order(index, 0 if current_order > 0 else self._next_raid_first_order())

    def _clear_raid_first_orders(self) -> None:
        for row in getattr(self, "_raid_deck_rows", []):
            row["first_order"] = 0
        self._sync_raid_deck_slot_icons()
        self._refresh_selected_raid_slot_detail()
        self._refresh_raid_validation()

    def _select_raid_deck_slot(self, index: int) -> None:
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows:
            self._raid_selected_deck_slot_index = 0
            return
        self._raid_selected_deck_slot_index = max(0, min(index, len(rows) - 1))
        self._refresh_selected_raid_slot_detail()

    def _apply_selected_raid_slot_student_text(self) -> None:
        if getattr(self, "_raid_slot_detail_guard", False):
            return
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows or not hasattr(self, "_raid_slot_student_input"):
            return
        index = max(0, min(getattr(self, "_raid_selected_deck_slot_index", 0), len(rows) - 1))
        row = rows[index]
        raw = self._raid_slot_student_input.text().strip()
        if not raw:
            row["student_id"] = ""
            row["borrowed"] = False
            row["first_order"] = 0
            row["star_conditions"] = {}
            row["skill_conditions"] = {}
            row["equipment_conditions"] = {}
            row["stat_conditions"] = {}
            self._sync_raid_deck_slot_icons()
            self._sync_raid_template_from_slots()
            self._refresh_selected_raid_slot_detail()
            self._update_raid_step_state()
            self._refresh_raid_validation()
            return

        warning_message = ""
        matches = self._raid_student_ids_for_text(raw)
        if len(matches) == 1:
            student_id = matches[0]
            row["student_id"] = student_id
            if not row.get("skill_conditions"):
                row["skill_conditions"] = self._default_raid_skill_conditions()
            expected_class = self._raid_slot_expected_combat_class(row.get("slot_type"))
            if expected_class and student_meta.combat_class(student_id) != expected_class:
                warning_message = f"{self._raid_student_label(student_id)}은(는) 이 슬롯 타입과 다릅니다."
        elif len(matches) > 1:
            names = ", ".join(self._raid_student_label(student_id) for student_id in matches[:6])
            suffix = "..." if len(matches) > 6 else ""
            self._raid_deck_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
            self._raid_deck_status.setText(f"'{raw}' 후보가 여러 명입니다: {names}{suffix}")
            return
        else:
            row["student_id"] = raw
            warning_message = f"'{raw}' 학생을 인식하지 못했습니다."

        self._sync_raid_deck_slot_icons()
        self._sync_raid_template_from_slots()
        self._refresh_selected_raid_slot_detail()
        self._update_raid_step_state()
        self._refresh_raid_validation()
        if warning_message:
            self._raid_deck_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
            self._raid_deck_status.setText(warning_message)

    def _raid_condition_values_from_inputs(self, inputs: dict[str, QSpinBox]) -> dict[str, int]:
        values: dict[str, int] = {}
        for key, spin in inputs.items():
            value = int(spin.value())
            if inputs is getattr(self, "_raid_slot_skill_inputs", {}) or value > 0:
                values[key] = value
        return values

    def _default_raid_skill_conditions(self) -> dict[str, int]:
        return {
            "ex": 5,
            "basic": 10,
            "enhanced": 10,
            "sub": 10,
        }

    def _raid_star_conditions_from_inputs(self) -> dict[str, int]:
        total = int(self._raid_slot_star_selector.value())
        weapon_star = max(0, total - 5)
        star = min(5, total)
        if weapon_star > 0:
            star = 5
        values: dict[str, int] = {}
        if star > 0:
            values["star"] = star
        if weapon_star > 0:
            values["weapon_star"] = weapon_star
        return values

    def _set_raid_star_condition_inputs(self, values: object) -> None:
        mapping = values if isinstance(values, dict) else {}
        try:
            star = max(0, min(5, int(mapping.get("star", 0) or 0)))
        except (TypeError, ValueError):
            star = 0
        try:
            weapon_star = max(0, min(4, int(mapping.get("weapon_star", 0) or 0)))
        except (TypeError, ValueError):
            weapon_star = 0
        total = 5 + weapon_star if weapon_star > 0 else star
        self._raid_slot_star_selector.blockSignals(True)
        self._raid_slot_star_selector.setState(minimum_value=0, value=total, enabled_count=9)
        self._raid_slot_star_selector.blockSignals(False)

    def _set_raid_condition_inputs(self, inputs: dict[str, QSpinBox], values: object) -> None:
        mapping = values if isinstance(values, dict) else {}
        for key, spin in inputs.items():
            spin.blockSignals(True)
            try:
                value = int(mapping.get(key, 0) or 0)
            except (TypeError, ValueError):
                value = 0
            spin.setValue(max(spin.minimum(), min(spin.maximum(), value)))
            spin.blockSignals(False)

    def _refresh_selected_raid_slot_detail(self) -> None:
        if not hasattr(self, "_raid_slot_detail_title"):
            return
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows:
            self._raid_slot_detail_title.setText("슬롯을 선택하세요")
            self._raid_slot_detail_student.setText("")
            if hasattr(self, "_raid_slot_student_input"):
                self._raid_slot_student_input.clear()
            if hasattr(self, "_raid_slot_star_selector"):
                self._set_raid_star_condition_inputs({})
            self._set_raid_condition_inputs(getattr(self, "_raid_slot_skill_inputs", {}), {})
            self._set_raid_condition_inputs(getattr(self, "_raid_slot_equipment_inputs", {}), {})
            self._set_raid_condition_inputs(getattr(self, "_raid_slot_stat_inputs", {}), {})
            return
        index = max(0, min(getattr(self, "_raid_selected_deck_slot_index", 0), len(rows) - 1))
        self._raid_selected_deck_slot_index = index
        row = rows[index]
        slot_label = "S" if row.get("slot_type") == "striker" else "SP"
        student_id = str(row.get("student_id") or "")
        name = self._raid_student_label(student_id) if student_id in self._records_by_id else student_id or "-"
        self._raid_slot_detail_guard = True
        self._raid_slot_detail_title.setText(f"{slot_label}{row.get('slot_index')} 상세")
        self._raid_slot_detail_student.setText(name)
        self._raid_slot_student_input.setText(name if student_id else "")
        self._raid_slot_borrowed.setChecked(bool(row.get("borrowed")))
        equipment_slot_names = list(student_meta.equipment_slots(student_id) or ()) if student_id else []
        for offset, key in enumerate(("equip1", "equip2", "equip3")):
            label_widget = self._raid_slot_equipment_labels.get(key)
            if label_widget is None:
                continue
            if offset < len(equipment_slot_names) and equipment_slot_names[offset]:
                label_widget.setText(_equipment_series_label(str(equipment_slot_names[offset])))
            else:
                label_widget.setText(f"장비{offset + 1}")
        if "unique" in self._raid_slot_equipment_labels:
            self._raid_slot_equipment_labels["unique"].setText("애용품")
        self._set_raid_star_condition_inputs(row.get("star_conditions"))
        self._set_raid_condition_inputs(self._raid_slot_skill_inputs, row.get("skill_conditions"))
        self._set_raid_condition_inputs(self._raid_slot_equipment_inputs, row.get("equipment_conditions"))
        self._set_raid_condition_inputs(self._raid_slot_stat_inputs, row.get("stat_conditions"))
        self._raid_slot_notes.setPlainText(str(row.get("notes") or ""))
        self._raid_slot_detail_guard = False

    def _raid_deck_group_layouts(self, grid: QGridLayout, *, mode: str, compact: bool = False) -> dict[str, QHBoxLayout]:
        striker_count, support_count = slot_counts_for_mode(mode)
        groups: dict[str, QHBoxLayout] = {}
        for column, (slot_type, title, count) in enumerate((
            ("striker", "STRIKER", striker_count),
            ("support", "SPECIAL", support_count),
        )):
            frame = QFrame()
            frame.setObjectName("raidDeckGroup")
            frame.setSizePolicy(QSizePolicy.Fixed, QSizePolicy.Fixed)
            outer = QVBoxLayout(frame)
            margin_x = scale_px(6 if compact else 8, self._ui_scale)
            margin_y = scale_px(5 if compact else 7, self._ui_scale)
            outer.setContentsMargins(margin_x, margin_y, margin_x, margin_y)
            outer.setSpacing(scale_px(3 if compact else 4, self._ui_scale))
            label = QLabel(title)
            label.setObjectName("detailMiniSub")
            label.setAlignment(Qt.AlignLeft)
            outer.addWidget(label)
            row = QHBoxLayout()
            row.setContentsMargins(0, 0, 0, 0)
            row.setSpacing(scale_px(1 if compact else 2, self._ui_scale))
            outer.addLayout(row)
            grid.addWidget(frame, 0, column, Qt.AlignLeft | Qt.AlignTop)
            grid.setColumnStretch(column, 0)
            groups[slot_type] = row
        grid.setColumnStretch(2, 1)
        return groups

    def _fix_raid_deck_group_widths(self, grid: QGridLayout) -> None:
        for index in range(grid.count()):
            widget = grid.itemAt(index).widget()
            if isinstance(widget, QFrame) and widget.objectName() == "raidDeckGroup":
                widget.setFixedWidth(widget.sizeHint().width())

    def _update_selected_raid_slot_detail(self) -> None:
        if getattr(self, "_raid_slot_detail_guard", False):
            return
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows:
            return
        index = max(0, min(getattr(self, "_raid_selected_deck_slot_index", 0), len(rows) - 1))
        rows[index]["borrowed"] = self._raid_slot_borrowed.isChecked()
        rows[index]["star_conditions"] = self._raid_star_conditions_from_inputs()
        rows[index]["skill_conditions"] = self._raid_condition_values_from_inputs(self._raid_slot_skill_inputs)
        rows[index]["equipment_conditions"] = self._raid_condition_values_from_inputs(self._raid_slot_equipment_inputs)
        rows[index]["stat_conditions"] = self._raid_condition_values_from_inputs(self._raid_slot_stat_inputs)
        rows[index]["notes"] = self._raid_slot_notes.toPlainText().strip()
        if not str(rows[index].get("student_id") or ""):
            rows[index]["first_order"] = 0
            rows[index]["star_conditions"] = {}
            rows[index]["skill_conditions"] = {}
            rows[index]["equipment_conditions"] = {}
            rows[index]["stat_conditions"] = {}
            self._sync_raid_deck_slot_icons()
            self._refresh_raid_validation()
            return
        self._sync_raid_deck_slot_icons()
        self._refresh_raid_validation()

    def _refresh_raid_deck_summary(self) -> None:
        if not hasattr(self, "_raid_deck_summary_grid"):
            return
        while self._raid_deck_summary_grid.count():
            item = self._raid_deck_summary_grid.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()
        guide = self._collect_raid_guide_from_editor()
        group_layouts = self._raid_deck_group_layouts(self._raid_deck_summary_grid, mode=guide.mode, compact=True)
        for index, slot in enumerate(guide.deck):
            cell = QWidget()
            cell.setObjectName("planTransparent")
            layout = QVBoxLayout(cell)
            layout.setContentsMargins(0, 0, 0, 0)
            layout.setSpacing(scale_px(3, self._ui_scale))
            slot_width = scale_px(54, self._ui_scale)
            slot_height = max(scale_px(42, self._ui_scale), int(round(slot_width / self._student_card_asset.aspect_ratio)))
            icon = TacticalDeckSlot(
                card_asset=self._student_card_asset,
                ui_scale=self._ui_scale,
                preferred_width=slot_width,
                preferred_height=slot_height,
            )
            icon.setFixedSize(slot_width, slot_height)
            name = self._raid_student_label(slot.student_id) if slot.student_id in self._records_by_id else slot.student_id
            icon.setData(
                name=name,
                pixmap=self._raid_portrait_pixmap(slot.student_id, slot_width),
                badge_text=str(slot.first_order) if getattr(slot, "first_order", 0) else "",
                corner_badge_text="A" if getattr(slot, "is_borrowed", False) else "",
            )
            layout.addWidget(icon, 0, Qt.AlignCenter)
            group_layouts.get(slot.slot_type, group_layouts["striker"]).addWidget(cell)
        self._fix_raid_deck_group_widths(self._raid_deck_summary_grid)

    def _raid_guide_list_focus_badge(self, guide: RaidGuide) -> str:
        if guide.id in getattr(self, "_raid_new_guide_ids", set()):
            return "새 작성"
        return "수정 중"

    def _style_raid_guide_list_row(self, row: QWidget, *, active: bool, badge_text: str) -> None:
        title = row.findChild(QLabel, "raidGuideRowTitle")
        badge = row.findChild(QLabel, "raidGuideRowBadge")
        radius = scale_px(10, self._ui_scale)
        if active:
            row.setStyleSheet(
                f"""
                QFrame#raidGuideRow {{
                    background: {_mix_hex(ACCENT_SOFT, '#ffffff', 0.08)};
                    border: {scale_px(2, self._ui_scale)}px solid {ACCENT};
                    border-radius: {radius}px;
                }}
                QLabel#raidGuideRowTitle {{
                    color: {INK};
                    font-weight: 900;
                }}
                QLabel#raidGuideRowBadge {{
                    color: #ffffff;
                    background: {ACCENT_STRONG};
                    border-radius: {scale_px(8, self._ui_scale)}px;
                    padding: {scale_px(2, self._ui_scale)}px {scale_px(8, self._ui_scale)}px;
                    font-weight: 900;
                }}
                """
            )
            if badge is not None:
                badge.setText(badge_text)
                badge.show()
        else:
            row.setStyleSheet(
                f"""
                QFrame#raidGuideRow {{
                    background: transparent;
                    border: {scale_px(1, self._ui_scale)}px solid transparent;
                    border-radius: {radius}px;
                }}
                QFrame#raidGuideRow:hover {{
                    background: {_mix_hex(SURFACE_ALT, '#ffffff', 0.04)};
                    border-color: {_mix_hex(BORDER, '#ffffff', 0.16)};
                }}
                QLabel#raidGuideRowTitle {{
                    color: {INK};
                    font-weight: 700;
                }}
                QLabel#raidGuideRowBadge {{
                    color: transparent;
                    background: transparent;
                    border: none;
                }}
                """
            )
            if badge is not None:
                badge.clear()
                badge.hide()
        if title is not None:
            font = title.font()
            font.setBold(active)
            title.setFont(font)

    def _raid_guide_list_row_widget(self, guide: RaidGuide, display_title: str, *, active: bool) -> QWidget:
        row = QFrame()
        row.setObjectName("raidGuideRow")
        row.setProperty("guideId", guide.id)
        row.setCursor(Qt.PointingHandCursor)
        layout = QHBoxLayout(row)
        layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(7, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(7, self._ui_scale),
        )
        layout.setSpacing(scale_px(8, self._ui_scale))
        title = QLabel(display_title)
        title.setObjectName("raidGuideRowTitle")
        title.setWordWrap(False)
        layout.addWidget(title, 1)
        badge = QLabel("")
        badge.setObjectName("raidGuideRowBadge")
        badge.setAlignment(Qt.AlignCenter)
        layout.addWidget(badge, 0, Qt.AlignRight | Qt.AlignVCenter)
        self._style_raid_guide_list_row(row, active=active, badge_text=self._raid_guide_list_focus_badge(guide))
        return row

    def _sync_raid_guide_list_focus(self) -> None:
        if not hasattr(self, "_raid_guide_list"):
            return
        selected_id = self._selected_raid_guide_id
        guide_by_id = {guide.id: guide for guide in self._raid_guide_data.guides}
        for row_index in range(self._raid_guide_list.count()):
            item = self._raid_guide_list.item(row_index)
            guide_id = str(item.data(Qt.UserRole) or "")
            widget = self._raid_guide_list.itemWidget(item)
            guide = guide_by_id.get(guide_id)
            if widget is None or guide is None:
                continue
            self._style_raid_guide_list_row(
                widget,
                active=guide_id == selected_id,
                badge_text=self._raid_guide_list_focus_badge(guide),
            )

    def _refresh_raid_guide_list(self) -> None:
        if not hasattr(self, "_raid_guide_list"):
            return
        selected_id = self._selected_raid_guide_id
        self._raid_guide_list.blockSignals(True)
        self._raid_guide_list.clear()
        query = self._raid_filter_text.text().strip().casefold() if hasattr(self, "_raid_filter_text") else ""
        mode_filter = self._raid_filter_mode.currentData() if hasattr(self, "_raid_filter_mode") else ""
        selected_row = -1
        for guide in self._raid_guide_data.guides:
            display_title = self._raid_guide_display_title(guide)
            haystack = " ".join([display_title, guide.boss, guide.difficulty, guide.terrain]).casefold()
            if query and query not in haystack:
                continue
            if mode_filter and guide.mode != mode_filter:
                continue
            item = QListWidgetItem("")
            item.setToolTip(display_title)
            item.setData(Qt.UserRole, guide.id)
            item.setSizeHint(QSize(0, scale_px(46, self._ui_scale)))
            self._raid_guide_list.addItem(item)
            self._raid_guide_list.setItemWidget(
                item,
                self._raid_guide_list_row_widget(guide, display_title, active=guide.id == selected_id),
            )
            if guide.id == selected_id:
                selected_row = self._raid_guide_list.count() - 1
        self._raid_guide_list.blockSignals(False)
        if selected_row >= 0:
            self._raid_guide_list.setCurrentRow(selected_row)
        elif self._raid_guide_list.count():
            self._raid_guide_list.setCurrentRow(0)
        self._sync_raid_guide_list_focus()

    def _on_raid_guide_selected(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None) -> None:
        if self._raid_guide_editor_guard or current is None:
            return
        self._selected_raid_guide_id = str(current.data(Qt.UserRole) or "")
        self._load_selected_raid_guide()
        self._sync_raid_guide_list_focus()

    def _load_selected_raid_guide(self) -> None:
        guide = self._current_raid_guide()
        if guide is None or not hasattr(self, "_raid_title_input"):
            if guide is None and hasattr(self, "_raid_title_input"):
                self._raid_guide_editor_guard = True
                empty_guide = new_raid_guide()
                self._raid_title_input.clear()
                self._set_raid_boss_value("")
                self._set_raid_difficulty_value("")
                self._raid_time_limit_input.setValue(int(empty_guide.time_limit_seconds or 0))
                self._raid_notes_input.clear()
                self._rebuild_raid_deck_editor(empty_guide)
                self._set_raid_timeline_steps([])
                self._raid_guide_editor_guard = False
                self._update_raid_step_state()
                self._refresh_raid_deck_summary()
                self._refresh_raid_editor_source_state()
                self._refresh_raid_validation()
            return
        guide = sanitize_guide(guide)
        self._raid_guide_editor_guard = True
        self._raid_title_input.setText(guide.title)
        self._raid_mode_input.setCurrentData(guide.mode)
        self._set_raid_boss_value(guide.boss)
        self._set_raid_difficulty_value(guide.difficulty)
        self._raid_terrain_input.setCurrentData(guide.terrain)
        self._raid_time_limit_input.setValue(int(guide.time_limit_seconds or 0))
        self._raid_notes_input.setPlainText(guide.notes)
        self._rebuild_raid_deck_editor(guide)
        self._set_raid_timeline_steps(guide.timeline)
        self._raid_guide_editor_guard = False
        self._update_raid_step_state()
        self._refresh_raid_deck_summary()
        self._refresh_raid_editor_source_state()
        self._refresh_raid_validation()

    def _rebuild_raid_deck_editor(self, guide: RaidGuide | None = None) -> None:
        guide = sanitize_guide(guide or self._collect_raid_guide_from_editor())
        if hasattr(self, "_raid_deck_preview_grid"):
            while self._raid_deck_preview_grid.count():
                item = self._raid_deck_preview_grid.takeAt(0)
                widget = item.widget()
                if widget is not None:
                    widget.deleteLater()
        self._raid_deck_rows = []
        self._raid_deck_preview_icons: list[TacticalDeckSlot] = []
        group_layouts = self._raid_deck_group_layouts(self._raid_deck_preview_grid, mode=guide.mode, compact=False)
        for index, slot in enumerate(guide.deck):
            slot_label = "S" if slot.slot_type == "striker" else "SP"
            if len(guide.deck) > 6:
                slot_width = min(self._thumb_width, scale_px(104, self._ui_scale))
                slot_height = max(scale_px(78, self._ui_scale), int(round(slot_width / self._student_card_asset.aspect_ratio)))
            else:
                slot_width = min(self._thumb_width, scale_px(220, self._ui_scale))
                slot_height = max(scale_px(120, self._ui_scale), int(round(slot_width / self._student_card_asset.aspect_ratio)))

            preview_cell = QWidget()
            preview_cell.setObjectName("planTransparent")
            preview_layout = QVBoxLayout(preview_cell)
            preview_layout.setContentsMargins(0, 0, 0, 0)
            preview_layout.setSpacing(scale_px(3, self._ui_scale))
            preview_icon = TacticalDeckSlot(
                card_asset=self._student_card_asset,
                ui_scale=self._ui_scale,
                preferred_width=slot_width,
                preferred_height=slot_height,
            )
            preview_icon.setFixedSize(slot_width, slot_height)
            preview_label = QLabel(f"{slot_label}{slot.slot_index}")
            preview_label.setObjectName("detailSub")
            preview_label.setAlignment(Qt.AlignCenter)
            preview_layout.addWidget(preview_icon, 0, Qt.AlignCenter)
            preview_layout.addWidget(preview_label)
            group_layouts.get(slot.slot_type, group_layouts["striker"]).addWidget(preview_cell)
            self._raid_deck_preview_icons.append(preview_icon)
            preview_icon.clicked.connect(lambda slot_index=index: self._on_raid_deck_slot_clicked(slot_index))
            self._raid_deck_rows.append(
                {
                    "slot_type": slot.slot_type,
                    "slot_index": slot.slot_index,
                    "student_id": slot.student_id,
                    "alias": slot.alias,
                    "borrowed": bool(slot.is_borrowed),
                    "first_order": int(getattr(slot, "first_order", 0) or 0),
                    "star_conditions": {
                        key: value
                        for key, value in dict(getattr(slot, "star_conditions", {}) or {}).items()
                        if key != "weapon_level"
                    },
                    "skill_conditions": dict(getattr(slot, "skill_conditions", {}) or self._default_raid_skill_conditions()),
                    "equipment_conditions": dict(getattr(slot, "equipment_conditions", {}) or {}),
                    "stat_conditions": dict(getattr(slot, "stat_conditions", {}) or {}),
                    "notes": slot.notes,
                }
            )
        self._fix_raid_deck_group_widths(self._raid_deck_preview_grid)
        self._raid_selected_deck_slot_index = min(getattr(self, "_raid_selected_deck_slot_index", 0), max(0, len(self._raid_deck_rows) - 1))
        self._sync_raid_deck_slot_icons()
        self._sync_raid_template_from_slots()
        self._refresh_selected_raid_slot_detail()
        self._update_raid_step_state()

    def _set_raid_timeline_steps(self, steps: list[TimelineStep]) -> None:
        self._raid_guide_editor_guard = True
        self._raid_timeline_table.setRowCount(0)
        for step in steps:
            self._append_raid_timeline_step(step)
        self._refresh_raid_timeline_row_numbers()
        self._raid_guide_editor_guard = False

    def _table_text(self, row: int, column: int) -> str:
        item = self._raid_timeline_table.item(row, column)
        return item.text().strip() if item is not None else ""

    def _refresh_raid_timeline_row_numbers(self) -> None:
        if not hasattr(self, "_raid_timeline_table"):
            return
        for row in range(self._raid_timeline_table.rowCount()):
            self._raid_timeline_table.setVerticalHeaderItem(row, QTableWidgetItem(str(row + 1)))

    def _set_table_text(self, row: int, column: int, text: object) -> None:
        item = QTableWidgetItem(str(text or ""))
        if column == 0:
            item.setToolTip("예: 3:40.000, 03:40:000, 3코, 3.5코. 비우면 이전 스킬 후 즉시 사용")
        elif column == 1:
            item.setToolTip("예: 아코, 아코 EX")
        elif column == 2:
            item.setToolTip("예: 드히나. 비우면 대상 지정 없음")
        elif column == 4:
            item.setToolTip("나중에 커스텀 이미지나 게임 캡처를 연결할 자리입니다.")
        self._raid_timeline_table.setItem(row, column, item)

    def _normalize_raid_timing_text(self, text: str) -> str:
        raw = str(text or "").strip()
        match = re.match(r"^(\d{1,2}):(\d{2}):(\d{1,3})$", raw)
        if match:
            return f"{int(match.group(1))}:{match.group(2)}.{match.group(3).ljust(3, '0')[:3]}"
        return raw

    def _raid_timeline_skill_text(self, step: TimelineStep) -> str:
        actor = self._raid_student_label(step.actor_student_id) if step.actor_student_id in self._records_by_id else step.actor_student_id
        action = str(step.action_type or "EX").strip()
        actor_text = str(actor or "").strip()
        if actor_text and action and action != "EX":
            actor_text = f"{actor_text} {action}"
        return actor_text

    def _raid_timeline_target_text(self, step: TimelineStep) -> str:
        return (
            self._raid_student_label(step.target_student_id)
            if step.target_student_id in self._records_by_id
            else str(step.target_student_id or "")
        )

    def _raid_timeline_memo_text(self, step: TimelineStep) -> str:
        parts = [
            step.condition,
            step.damage_check,
            step.phase,
            step.note,
        ]
        return " / ".join(str(part).strip() for part in parts if str(part or "").strip())

    def _split_raid_skill_target_text(self, text: str) -> tuple[str, str]:
        raw = str(text or "").strip()
        for delimiter in ("->", "=>", "→", ">"):
            if delimiter in raw:
                actor, target = raw.split(delimiter, 1)
                return actor.strip(), target.strip()
        return raw, ""

    def _parse_raid_timeline_skill_text(self, text: str) -> tuple[str, str, str]:
        actor_text, target_text = self._split_raid_skill_target_text(text)
        action_type = "EX"
        actor_id = self._raid_student_id_for_text(actor_text)
        if actor_text and actor_id == actor_text:
            pieces = actor_text.rsplit(None, 1)
            if len(pieces) == 2:
                possible_actor, possible_action = pieces
                possible_actor_id = self._raid_student_id_for_text(possible_actor)
                if possible_actor_id != possible_actor or possible_actor in self._records_by_id:
                    actor_id = possible_actor_id
                    action_type = possible_action.strip() or "EX"
        target_id = self._raid_student_id_for_text(target_text)
        return actor_id, action_type, target_id

    def _append_raid_timeline_step(self, step: TimelineStep | None = None) -> None:
        row = self._raid_timeline_table.rowCount()
        self._raid_timeline_table.insertRow(row)
        step = step or TimelineStep(order=row + 1)
        values = [
            step.cue_text,
            self._raid_timeline_skill_text(step),
            self._raid_timeline_target_text(step),
            self._raid_timeline_memo_text(step),
            step.card_hint,
        ]
        for column, value in enumerate(values):
            self._set_table_text(row, column, value)
        self._refresh_raid_timeline_row_numbers()

    def _timeline_steps_from_table(self) -> list[TimelineStep]:
        steps: list[TimelineStep] = []
        for row in range(self._raid_timeline_table.rowCount()):
            step = TimelineStep(order=row + 1)
            timing_text = self._normalize_raid_timing_text(self._table_text(row, 0))
            if timing_text:
                update_step_cue(step, timing_text)
            else:
                step.cue_kind = "trigger"
                step.cue_text = ""
            actor_id, action_type, embedded_target_id = self._parse_raid_timeline_skill_text(self._table_text(row, 1))
            target_text = self._table_text(row, 2)
            step.actor_student_id = actor_id
            step.action_type = action_type
            step.target_student_id = self._raid_student_id_for_text(target_text) if target_text else embedded_target_id
            step.note = self._table_text(row, 3)
            step.card_hint = self._table_text(row, 4)
            if step.cue_text and not step.actor_student_id and not step.target_student_id:
                step.action_type = "marker"
                step.cue_kind = "note" if step.cue_kind == "trigger" else step.cue_kind
            steps.append(step)
        return steps

    def _collect_raid_guide_from_editor(self) -> RaidGuide:
        current = self._current_raid_guide()
        guide = current or new_raid_guide()
        mode = self._raid_mode_input.currentData() if hasattr(self, "_raid_mode_input") else guide.mode
        boss = self._raid_current_boss() if hasattr(self, "_raid_boss_input") else guide.boss
        difficulty = self._raid_current_difficulty() if hasattr(self, "_raid_difficulty_input") else guide.difficulty
        terrain = (
            str(self._raid_terrain_input.currentData() or "").strip()
            if hasattr(self, "_raid_terrain_input")
            else guide.terrain
        )
        raw_title = self._raid_title_input.text().strip() if hasattr(self, "_raid_title_input") else guide.title
        previous_generated_title = self._raid_generated_title(terrain=guide.terrain, boss=guide.boss, difficulty=guide.difficulty)
        if self._raid_should_generate_title(raw_title, previous_generated_title):
            generated_title = self._raid_generated_title(terrain=terrain, boss=boss, difficulty=difficulty)
            title = self._raid_unique_generated_title(generated_title, guide.id)
        else:
            title = raw_title
        deck: list[GuideDeckSlot] = []
        for row in getattr(self, "_raid_deck_rows", []):
            star_conditions = {
                key: value
                for key, value in dict(row.get("star_conditions") or {}).items()
                if key != "weapon_level"
            }
            deck.append(
                GuideDeckSlot(
                    slot_type=str(row["slot_type"]),
                    slot_index=int(row["slot_index"]),
                    student_id=str(row.get("student_id") or ""),
                    alias=str(row.get("alias") or ""),
                    is_borrowed=bool(row.get("borrowed")),
                    first_order=int(row.get("first_order") or 0),
                    star_conditions=star_conditions,
                    skill_conditions=dict(row.get("skill_conditions") or {}),
                    equipment_conditions=dict(row.get("equipment_conditions") or {}),
                    stat_conditions=dict(row.get("stat_conditions") or {}),
                    notes=str(row.get("notes") or ""),
                )
            )
        return sanitize_guide(
            RaidGuide(
                id=guide.id,
                title=title,
                mode=str(mode or guide.mode),
                boss=boss,
                difficulty=difficulty,
                terrain=terrain,
                time_limit_seconds=self._raid_time_limit_input.value() if hasattr(self, "_raid_time_limit_input") else guide.time_limit_seconds,
                notes=self._raid_notes_input.toPlainText().strip() if hasattr(self, "_raid_notes_input") else guide.notes,
                deck=deck or default_deck_for_mode(str(mode or guide.mode)),
                timeline=self._timeline_steps_from_table() if hasattr(self, "_raid_timeline_table") else guide.timeline,
            )
        )

    def _on_raid_mode_changed(self) -> None:
        if self._raid_guide_editor_guard:
            return
        guide = self._collect_raid_guide_from_editor()
        guide.deck = default_deck_for_mode(guide.mode)
        self._rebuild_raid_deck_editor(guide)
        self._set_raid_editor_step(0)
        self._refresh_raid_validation()

    def _on_raid_timeline_item_changed(self, item: QTableWidgetItem) -> None:
        if self._raid_guide_editor_guard:
            return
        if item.column() == 0:
            normalized = self._normalize_raid_timing_text(item.text())
            if normalized != item.text().strip():
                self._raid_guide_editor_guard = True
                self._set_table_text(item.row(), 0, normalized)
                self._raid_guide_editor_guard = False
        self._refresh_raid_validation()

    def _add_raid_timeline_row(self) -> None:
        self._append_raid_timeline_step(TimelineStep(order=self._raid_timeline_table.rowCount() + 1, action_type="EX"))
        self._raid_timeline_table.setCurrentCell(self._raid_timeline_table.rowCount() - 1, 0)

    def _duplicate_raid_timeline_row(self) -> None:
        row = self._raid_timeline_table.currentRow()
        if row < 0:
            return
        step = TimelineStep(order=row + 2)
        update_step_cue(step, self._normalize_raid_timing_text(self._table_text(row, 0)))
        step.actor_student_id, step.action_type, embedded_target_id = self._parse_raid_timeline_skill_text(self._table_text(row, 1))
        target_text = self._table_text(row, 2)
        step.target_student_id = self._raid_student_id_for_text(target_text) if target_text else embedded_target_id
        step.note = self._table_text(row, 3)
        step.card_hint = self._table_text(row, 4)
        self._raid_timeline_table.insertRow(row + 1)
        self._raid_guide_editor_guard = True
        for column, value in enumerate([
            step.cue_text,
            self._raid_timeline_skill_text(step),
            self._raid_timeline_target_text(step),
            step.note,
            step.card_hint,
        ]):
            self._set_table_text(row + 1, column, value)
        self._refresh_raid_timeline_row_numbers()
        self._raid_guide_editor_guard = False

    def _delete_raid_timeline_row(self) -> None:
        row = self._raid_timeline_table.currentRow()
        if row >= 0:
            self._raid_timeline_table.removeRow(row)
            self._refresh_raid_timeline_row_numbers()
            self._refresh_raid_validation()

    def _move_raid_timeline_row(self, direction: int) -> None:
        row = self._raid_timeline_table.currentRow()
        target = row + direction
        if row < 0 or target < 0 or target >= self._raid_timeline_table.rowCount():
            return
        rows = self._timeline_steps_from_table()
        rows[row], rows[target] = rows[target], rows[row]
        self._set_raid_timeline_steps(rows)
        self._raid_timeline_table.setCurrentCell(target, 0)
        self._refresh_raid_timeline_row_numbers()

    def _import_raid_timeline_text(self) -> None:
        text = self._raid_paste_input.toPlainText()
        if not text.strip():
            return
        steps = parse_timeline_text(text, start_order=self._raid_timeline_table.rowCount() + 1)
        for step in steps:
            resolved = self._raid_student_id_for_text(step.actor_student_id)
            step.actor_student_id = resolved
            self._append_raid_timeline_step(step)
        self._raid_paste_input.clear()
        self._refresh_raid_validation()

    def _share_current_raid_guide(self) -> None:
        guide = self._collect_raid_guide_from_editor()
        try:
            token = encode_raid_guide_share(guide)
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"공략 공유 문자열을 만들지 못했습니다.\n\n{exc}")
            return
        QApplication.clipboard().setText(token)
        if hasattr(self, "_raid_status"):
            self._raid_status.setStyleSheet("color: #2f80ed; font-weight: 900;")
            self._raid_status.setText("공략 공유 문자열을 클립보드에 복사했습니다. 이미지는 별도로 공유해 주세요.")
            self._raid_status.setToolTip(token)

    def _import_raid_guide_share(self) -> None:
        clipboard_text = QApplication.clipboard().text().strip()
        initial_text = clipboard_text if "BAPRG1:" in clipboard_text else ""
        text, ok = QInputDialog.getMultiLineText(
            self,
            "공략 공유 문자열 가져오기",
            "BAPRG1: 공유 문자열을 붙여넣으세요.\n이미지가 있는 공략은 이미지를 별도로 받은 뒤 함께 보관해 주세요.",
            initial_text,
        )
        if not ok:
            return
        try:
            guide = decode_raid_guide_share(text)
        except ValueError as exc:
            QMessageBox.warning(self, "BA Planner", f"공략 공유 문자열을 읽지 못했습니다.\n\n{exc}")
            return
        self._raid_guide_data.guides.append(guide)
        self._selected_raid_guide_id = guide.id
        self._raid_new_guide_ids.add(guide.id)
        self._save_raid_guide_data()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()
        if hasattr(self, "_raid_status"):
            self._raid_status.setStyleSheet("color: #2f80ed; font-weight: 900;")
            self._raid_status.setText("공유 문자열에서 공략을 가져왔습니다. 추가 이미지는 별도로 연결해 주세요.")

    def _new_raid_guide(self) -> None:
        guide = new_raid_guide()
        self._raid_guide_data.guides.append(guide)
        self._selected_raid_guide_id = guide.id
        self._raid_new_guide_ids.add(guide.id)
        self._save_raid_guide_data()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()

    def _edit_selected_raid_guide(self) -> None:
        current = self._current_raid_guide()
        if current is None:
            return
        self._selected_raid_guide_id = current.id
        self._load_selected_raid_guide()
        self._set_raid_editor_step(0)

    def _duplicate_selected_raid_guide(self) -> None:
        current = self._collect_raid_guide_from_editor()
        cloned = clone_guide(current)
        self._raid_guide_data.guides.append(cloned)
        self._selected_raid_guide_id = cloned.id
        self._raid_new_guide_ids.add(cloned.id)
        self._save_raid_guide_data()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()

    def _delete_selected_raid_guide(self) -> None:
        current = self._current_raid_guide()
        if current is None:
            return
        self._raid_guide_data.guides = [guide for guide in self._raid_guide_data.guides if guide.id != current.id]
        self._raid_new_guide_ids.discard(current.id)
        self._selected_raid_guide_id = self._raid_guide_data.guides[0].id if self._raid_guide_data.guides else None
        self._save_raid_guide_data()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()

    def _save_current_raid_guide(self) -> None:
        guide = self._collect_raid_guide_from_editor()
        for index, existing in enumerate(self._raid_guide_data.guides):
            if existing.id == guide.id:
                self._raid_guide_data.guides[index] = guide
                break
        else:
            self._raid_guide_data.guides.append(guide)
        self._selected_raid_guide_id = guide.id
        self._raid_new_guide_ids.discard(guide.id)
        self._save_raid_guide_data()
        if hasattr(self, "_raid_title_input"):
            self._raid_guide_editor_guard = True
            self._raid_title_input.setText(guide.title)
            self._raid_guide_editor_guard = False
        self._refresh_raid_guide_list()
        self._refresh_raid_editor_source_state()
        self._show_raid_deck_saved_feedback(guide)
        self._refresh_raid_validation(saved=True)

    def _show_raid_deck_saved_feedback(self, guide: RaidGuide) -> None:
        if not hasattr(self, "_raid_deck_status"):
            return
        filled = sum(1 for slot in guide.deck if slot.student_id)
        total = len(guide.deck)
        self._raid_deck_status.setStyleSheet("color: #2f80ed; font-weight: 900;")
        self._raid_deck_status.setText(f"저장 완료 · 덱 슬롯 {filled}/{total}")

    def _refresh_raid_validation(self, *, saved: bool = False) -> None:
        if not hasattr(self, "_raid_status"):
            return
        guide = self._collect_raid_guide_from_editor()
        warnings = validate_guide(guide, known_student_ids=set(student_meta.all_ids()))
        prefix = "저장 완료. " if saved else ""
        if warnings:
            visible = warnings[:3]
            suffix = f" 외 {len(warnings) - 3}개" if len(warnings) > 3 else ""
            self._raid_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
            self._raid_status.setText(prefix + " / ".join(visible) + suffix)
            self._raid_status.setToolTip("\n".join(warnings))
        else:
            striker_count, support_count = slot_counts_for_mode(guide.mode)
            self._raid_status.setStyleSheet("")
            self._raid_status.setText(
                prefix + f"{RAID_GUIDE_MODES.get(guide.mode, guide.mode)} · 덱 {striker_count}+{support_count} · 행 {len(guide.timeline)}개"
            )
            self._raid_status.setToolTip("")

    def _build_tactical_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        title = QLabel("전술대항전")
        title.setObjectName("title")
        subtitle = QLabel("전술대항전 전적, 상대 방어덱, 공격 족보를 한 곳에서 기록하고 찾아봅니다.")
        subtitle.setObjectName("count")
        header_layout.addWidget(title)
        header_layout.addWidget(subtitle)
        layout.addWidget(header)

        splitter = QSplitter(Qt.Horizontal)
        splitter.setObjectName("sectionSplitter")
        splitter.setChildrenCollapsible(False)
        layout.addWidget(splitter, 1)

        input_shell = QFrame()
        input_shell.setObjectName("planSectionPanel")
        input_shell_layout = QVBoxLayout(input_shell)
        input_shell_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        input_shell_layout.setSpacing(0)

        input_panel = QWidget()
        input_panel.setObjectName("planTransparent")
        input_scroll = QScrollArea()
        input_scroll.setObjectName("sectionScrollArea")
        input_scroll.setWidgetResizable(True)
        input_scroll.setFrameShape(QFrame.NoFrame)
        input_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        input_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        _install_planner_scroll_handle(input_scroll, ui_scale=self._ui_scale)
        input_scroll.setWidget(input_panel)
        input_shell_layout.addWidget(input_scroll, 1)
        input_layout = QVBoxLayout(input_panel)
        input_layout.setContentsMargins(
            scale_px(4, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(4, self._ui_scale),
        )
        input_layout.setSpacing(scale_px(10, self._ui_scale))

        match_title = QLabel("오늘 전적 입력")
        match_title.setObjectName("sectionTitle")
        input_layout.addWidget(match_title)
        date_row = QHBoxLayout()
        date_row.setContentsMargins(0, 0, 0, 0)
        self._tactical_date = QLineEdit(date.today().isoformat())
        self._tactical_season = QLineEdit(self._tactical_data.season or "")
        self._tactical_season.setPlaceholderText("시즌")
        self._tactical_season.editingFinished.connect(self._save_tactical_season)
        date_row.addWidget(QLabel("날짜"))
        date_row.addWidget(self._tactical_date, 1)
        date_row.addWidget(QLabel("시즌"))
        date_row.addWidget(self._tactical_season, 1)
        input_layout.addLayout(date_row)

        self._tactical_match_panels: list[dict] = []
        panel_widget, panel = self._build_tactical_match_input_panel(1)
        self._tactical_match_panels.append(panel)
        input_layout.addWidget(panel_widget)

        abbrev_panel = self._build_tactical_abbreviation_panel()
        input_layout.addWidget(abbrev_panel)

        self._tactical_status = QLabel("")
        self._tactical_status.setObjectName("filterSummary")
        self._tactical_status.setWordWrap(True)
        self._tactical_status.setMaximumHeight(scale_px(48, self._ui_scale))
        self._tactical_status.hide()
        input_layout.addStretch(1)
        splitter.addWidget(input_shell)

        history_panel = QFrame()
        history_panel.setObjectName("planSectionPanel")
        history_layout = QVBoxLayout(history_panel)
        history_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        history_layout.setSpacing(scale_px(10, self._ui_scale))
        history_header = QHBoxLayout()
        history_title = QLabel("전적 기록")
        history_title.setObjectName("sectionTitle")
        self._tactical_match_summary = QLabel("")
        self._tactical_match_summary.setObjectName("filterSummary")
        history_header.addWidget(history_title)
        history_header.addWidget(self._tactical_match_summary, 1, Qt.AlignRight)
        history_layout.addLayout(history_header)
        self._tactical_match_search = QLineEdit()
        self._tactical_match_search.setPlaceholderText("상대 이름, 학생, 메모 검색")
        self._tactical_match_search.textChanged.connect(lambda *_: self._reset_tactical_match_list())
        history_layout.addWidget(self._tactical_match_search)
        self._tactical_match_list = RoundedListWidget(ui_scale=self._ui_scale)
        _install_planner_scroll_handle(self._tactical_match_list, ui_scale=self._ui_scale)
        self._tactical_match_list.currentItemChanged.connect(self._on_tactical_match_selected)
        history_layout.addWidget(self._tactical_match_list, 1)
        self._tactical_match_load_more_button = QPushButton("더 보기")
        self._tactical_match_load_more_button.clicked.connect(self._load_more_tactical_matches)
        history_layout.addWidget(self._tactical_match_load_more_button)
        match_action_row = QHBoxLayout()
        match_action_row.setContentsMargins(0, 0, 0, 0)
        self._tactical_match_copy_attack_button = QPushButton("ATK Copy")
        self._tactical_match_copy_attack_button.clicked.connect(self._copy_selected_tactical_match_attack)
        self._tactical_match_copy_defense_button = QPushButton("DEF Copy")
        self._tactical_match_copy_defense_button.clicked.connect(self._copy_selected_tactical_match_defense)
        self._tactical_match_edit_button = QPushButton("수정")
        self._tactical_match_edit_button.clicked.connect(self._edit_selected_tactical_match)
        self._tactical_match_batch_names_button = QPushButton("이름 일괄")
        self._tactical_match_batch_names_button.clicked.connect(self._edit_tactical_opponents_batch)
        self._tactical_match_delete_button = QPushButton("[삭제]")
        self._tactical_match_delete_button.clicked.connect(self._delete_selected_tactical_match)
        self._tactical_match_import_button = QPushButton("Excel Import")
        self._tactical_match_import_button.clicked.connect(self._import_tactical_spreadsheet)
        import_template_path = self._ensure_tactical_import_template()
        self._tactical_match_import_button.setToolTip(
            f"템플릿: {import_template_path}\n설명서: {tactical_import_readme_path(import_template_path)}"
        )
        match_action_row.addStretch(1)
        match_action_row.addWidget(self._tactical_match_import_button)
        match_action_row.addWidget(self._tactical_match_copy_attack_button)
        match_action_row.addWidget(self._tactical_match_copy_defense_button)
        match_action_row.addWidget(self._tactical_match_batch_names_button)
        match_action_row.addWidget(self._tactical_match_edit_button)
        match_action_row.addWidget(self._tactical_match_delete_button)
        history_layout.addLayout(match_action_row)
        splitter.addWidget(history_panel)

        insight_panel = QFrame()
        insight_panel.setObjectName("planSectionPanel")
        insight_layout = QVBoxLayout(insight_panel)
        insight_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        insight_layout.setSpacing(scale_px(10, self._ui_scale))
        tactical_mode_buttons = QHBoxLayout()
        tactical_mode_buttons.setContentsMargins(0, 0, 0, 0)
        tactical_mode_buttons.setSpacing(scale_px(8, self._ui_scale))
        tactical_insight_buttons: dict[int, QPushButton] = {}
        tactical_insight_stack = QStackedWidget()
        tactical_insight_stack.setObjectName("sectionTransparentStack")

        def sync_tactical_insight_buttons(index: int) -> None:
            for button_index, button in tactical_insight_buttons.items():
                button.setChecked(button_index == index)

        for index, label in enumerate(("상대", "족보")):
            button = QPushButton(label)
            button.setObjectName("inventoryModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=index: tactical_insight_stack.setCurrentIndex(value))
            tactical_mode_buttons.addWidget(button, 0)
            tactical_insight_buttons[index] = button
        tactical_mode_buttons.addStretch(1)
        tactical_insight_stack.currentChanged.connect(sync_tactical_insight_buttons)
        insight_layout.addLayout(tactical_mode_buttons)
        insight_layout.addWidget(tactical_insight_stack, 1)

        opponent_tab = QWidget()
        opponent_tab.setObjectName("planTransparent")
        opponent_tab_layout = QVBoxLayout(opponent_tab)
        opponent_tab_layout.setContentsMargins(0, 0, 0, 0)
        opponent_tab_layout.setSpacing(0)
        opponent_container = QFrame()
        opponent_container.setObjectName("planBand")
        opponent_layout = QVBoxLayout(opponent_container)
        opponent_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        opponent_layout.setSpacing(scale_px(10, self._ui_scale))
        opponent_search_row = QHBoxLayout()
        self._tactical_opponent_search = QLineEdit()
        self._tactical_opponent_search.setPlaceholderText("상대 이름 검색")
        self._tactical_opponent_search.returnPressed.connect(self._refresh_tactical_opponent_report)
        opponent_search_button = QPushButton("검색")
        opponent_search_button.clicked.connect(self._refresh_tactical_opponent_report)
        opponent_search_row.addWidget(self._tactical_opponent_search, 1)
        opponent_search_row.addWidget(opponent_search_button)
        opponent_layout.addLayout(opponent_search_row)
        self._tactical_opponent_summary = QLabel("")
        self._tactical_opponent_summary.setObjectName("detailSub")
        self._tactical_opponent_summary.setWordWrap(True)
        opponent_layout.addWidget(self._tactical_opponent_summary)
        self._tactical_opponent_top_list = RoundedListWidget(ui_scale=self._ui_scale)
        _install_planner_scroll_handle(self._tactical_opponent_top_list, ui_scale=self._ui_scale)
        opponent_layout.addWidget(self._tactical_opponent_top_list, 1)
        opponent_tab_layout.addWidget(opponent_container, 1)
        tactical_insight_stack.addWidget(opponent_tab)

        jokbo_tab = QWidget()
        jokbo_tab.setObjectName("planTransparent")
        jokbo_tab_layout = QVBoxLayout(jokbo_tab)
        jokbo_tab_layout.setContentsMargins(0, 0, 0, 0)
        jokbo_tab_layout.setSpacing(0)
        jokbo_container = QFrame()
        jokbo_container.setObjectName("planBand")
        jokbo_layout = QVBoxLayout(jokbo_container)
        jokbo_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        jokbo_layout.setSpacing(scale_px(10, self._ui_scale))
        search_group, self._tactical_jokbo_search_inputs = self._build_tactical_deck_editor("방어덱 검색")
        jokbo_layout.addWidget(search_group)
        search_buttons = QHBoxLayout()
        search_jokbo_button = QPushButton("족보 검색")
        search_jokbo_button.clicked.connect(self._refresh_tactical_jokbo_results)
        copy_search_button = QPushButton("전적 방어덱 복사")
        copy_search_button.clicked.connect(self._copy_selected_tactical_defense_to_search)
        search_buttons.addWidget(search_jokbo_button)
        search_buttons.addWidget(copy_search_button)
        jokbo_layout.addLayout(search_buttons)
        self._tactical_jokbo_results = RoundedListWidget(ui_scale=self._ui_scale)
        _install_planner_scroll_handle(self._tactical_jokbo_results, ui_scale=self._ui_scale)
        jokbo_layout.addWidget(self._tactical_jokbo_results, 1)
        jokbo_action_row = QHBoxLayout()
        jokbo_action_row.setContentsMargins(0, 0, 0, 0)
        self._tactical_jokbo_copy_defense_button = QPushButton("DEF Copy")
        self._tactical_jokbo_copy_defense_button.clicked.connect(self._copy_selected_tactical_jokbo_defense)
        self._tactical_jokbo_copy_attack_button = QPushButton("ATK Copy")
        self._tactical_jokbo_copy_attack_button.clicked.connect(self._copy_selected_tactical_jokbo_attack)
        jokbo_action_row.addStretch(1)
        jokbo_action_row.addWidget(self._tactical_jokbo_copy_attack_button)
        jokbo_action_row.addWidget(self._tactical_jokbo_copy_defense_button)
        jokbo_layout.addLayout(jokbo_action_row)
        jokbo_tab_layout.addWidget(jokbo_container, 1)
        tactical_insight_stack.addWidget(jokbo_tab)
        tactical_insight_stack.setCurrentIndex(0)
        sync_tactical_insight_buttons(0)
        splitter.addWidget(insight_panel)
        splitter.setSizes([scale_px(420, self._ui_scale), scale_px(520, self._ui_scale), scale_px(470, self._ui_scale)])

    def _build_tactical_match_input_panel(self, index: int) -> tuple[QFrame, dict]:
        panel_widget = QFrame()
        panel_widget.setObjectName("planBand")
        layout = QVBoxLayout(panel_widget)
        layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale))
        layout.setSpacing(scale_px(8, self._ui_scale))

        header = QHBoxLayout()
        title = QLabel("대전 기록")
        title.setObjectName("sectionTitle")
        opponent = QLineEdit()
        opponent.setPlaceholderText("상대 이름")
        opponent.setMinimumWidth(scale_px(48, self._ui_scale))
        opponent.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Fixed)
        win_button = QPushButton("승")
        loss_button = QPushButton("패")
        win_button.setCheckable(True)
        loss_button.setCheckable(True)
        save_button = QPushButton("전적 추가")
        clear_button = QPushButton("새 입력")
        button_spacing = scale_px(6, self._ui_scale)
        header.setSpacing(button_spacing)
        action_width = scale_px(68, self._ui_scale)
        result_width = scale_px(36, self._ui_scale)
        for button in (win_button, loss_button):
            button.setFixedWidth(result_width)
        for button in (save_button, clear_button):
            button.setFixedWidth(action_width)
        header.addWidget(title)
        header.addWidget(opponent, 1)
        header.addWidget(win_button)
        header.addWidget(loss_button)
        header.addWidget(save_button)
        header.addWidget(clear_button)
        layout.addLayout(header)

        recent_row = QHBoxLayout()
        recent_row.setContentsMargins(0, 0, 0, 0)
        recent_row.setSpacing(button_spacing)
        paste_screenshot_button = QPushButton("붙여넣기")
        folder_screenshot_button = QPushButton("Folder")
        screenshot_button = QPushButton("캡처")
        recent_attack_button = QPushButton("최근 공격")
        recent_defense_button = QPushButton("최근 방어")
        result_action_span = result_width * 2 + action_width * 3 + button_spacing * 4
        recent_button_width = (result_action_span - button_spacing) // 2
        screenshot_button.setFixedWidth(action_width)
        folder_screenshot_button.setFixedWidth(action_width)
        paste_screenshot_button.setFixedWidth(action_width)
        recent_min_width = scale_px(86 if self._ui_scale >= SMALL_16_9_SCALE_THRESHOLD else 76, self._ui_scale)
        for button in (recent_attack_button, recent_defense_button):
            button.setMinimumWidth(recent_min_width)
            button.setMaximumWidth(recent_button_width)
            button.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        screenshot_button.setToolTip("전술대항전 결과창 스크린샷에서 승패와 공방덱을 읽어옵니다.")
        folder_screenshot_button.setToolTip("Recursively scans 16:9 images in a folder. Date-like folder names such as 260606 are used as match dates.")
        recent_attack_button.setToolTip("상대 이름으로 최근 공격 기록의 공덱/방덱을 가져옵니다.")
        recent_defense_button.setToolTip("상대 이름으로 최근 방어 기록의 공덱/방덱을 가져옵니다.")
        paste_screenshot_button.setToolTip("Analyze one image copied to the clipboard, the same as uploading a screenshot.")
        recent_row.addStretch(1)
        recent_row.addWidget(screenshot_button)
        recent_row.addWidget(folder_screenshot_button)
        recent_row.addWidget(paste_screenshot_button)
        recent_row.addWidget(recent_attack_button, 1)
        recent_row.addWidget(recent_defense_button, 1)
        layout.addLayout(recent_row)

        mode_row = QHBoxLayout()
        mode_row.setContentsMargins(0, 0, 0, 0)
        attack_mode_button = QPushButton("공격 기록")
        defense_mode_button = QPushButton("방어 기록")
        jokbo_mode_button = QPushButton("족보")
        attack_mode_button.setCheckable(True)
        defense_mode_button.setCheckable(True)
        jokbo_mode_button.setCheckable(True)
        mode_hint = QLabel("공격 기록: 내 공격덱 vs 상대 방어덱 / 방어 기록: 상대 공격덱 vs 내 방어덱 / 족보: 방어덱과 공격덱 페어")
        mode_hint.setObjectName("detailSub")
        mode_hint.setWordWrap(True)
        mode_row.addWidget(attack_mode_button)
        mode_row.addWidget(defense_mode_button)
        mode_row.addWidget(jokbo_mode_button)
        mode_row.addWidget(mode_hint, 1)
        layout.addLayout(mode_row)

        attack_widget, attack_editor = self._build_tactical_deck_editor("공격덱")
        defense_widget, defense_editor = self._build_tactical_deck_editor("방어덱")
        layout.addWidget(attack_widget)
        layout.addWidget(defense_widget)

        notes = QPlainTextEdit()
        notes.setPlaceholderText("메모")
        notes.setMaximumHeight(scale_px(58, self._ui_scale))
        layout.addWidget(notes)
        status = QLabel("")
        status.setObjectName("filterSummary")
        status.setWordWrap(True)
        status.setMaximumHeight(scale_px(48, self._ui_scale))
        status.hide()
        layout.addWidget(status)

        panel = {
            "title": title,
            "opponent": opponent,
            "result": "win",
            "win_button": win_button,
            "loss_button": loss_button,
            "mode": "attack",
            "attack_mode_button": attack_mode_button,
            "defense_mode_button": defense_mode_button,
            "jokbo_mode_button": jokbo_mode_button,
            "attack": attack_editor,
            "defense": defense_editor,
            "notes": notes,
            "status": status,
            "save_button": save_button,
            "editing_match_id": "",
            "editing_source": "",
            "editing_created_at": "",
        }
        win_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_result(target, "win"))
        loss_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_result(target, "loss"))
        attack_mode_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_mode(target, "attack"))
        defense_mode_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_mode(target, "defense"))
        jokbo_mode_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_mode(target, "jokbo"))
        save_button.clicked.connect(lambda *_args, target=panel: self._save_tactical_match_panel(target))
        clear_button.clicked.connect(lambda *_args, target=panel: self._clear_tactical_match_panel(target))
        screenshot_button.clicked.connect(lambda *_args, target=panel: self._import_tactical_screenshot_panel(target))
        folder_screenshot_button.clicked.connect(lambda *_args, target=panel: self._import_tactical_screenshot_folder_panel(target))
        paste_screenshot_button.clicked.connect(lambda *_args, target=panel: self._paste_tactical_screenshot_panel(target))
        recent_attack_button.clicked.connect(lambda *_args, target=panel: self._load_recent_tactical_match_panel(target, "attack"))
        recent_defense_button.clicked.connect(lambda *_args, target=panel: self._load_recent_tactical_match_panel(target, "defense"))
        self._set_tactical_panel_result(panel, "win")
        self._set_tactical_panel_mode(panel, "attack")
        return panel_widget, panel

    def _build_tactical_abbreviation_panel(self) -> QFrame:
        panel = QFrame()
        panel.setObjectName("planBand")
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale))
        layout.setSpacing(scale_px(7, self._ui_scale))

        header = QHBoxLayout()
        title = QLabel("줄임말 설정")
        title.setObjectName("sectionTitle")
        self._tactical_abbrev_toggle = QPushButton("펼치기")
        self._tactical_abbrev_toggle.setObjectName("planDisclosureButton")
        self._tactical_abbrev_toggle.setCheckable(True)
        self._tactical_abbrev_toggle.clicked.connect(lambda checked=False: self._set_tactical_abbreviation_expanded(bool(checked)))
        header.addWidget(title)
        header.addStretch(1)
        header.addWidget(self._tactical_abbrev_toggle)
        layout.addLayout(header)

        self._tactical_abbrev_body = QWidget()
        self._tactical_abbrev_body.setObjectName("planTransparent")
        body_layout = QVBoxLayout(self._tactical_abbrev_body)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(scale_px(7, self._ui_scale))

        button_row = QHBoxLayout()
        button_row.setContentsMargins(0, 0, 0, 0)
        add_striker_button = QPushButton("스트 추가")
        add_striker_button.clicked.connect(lambda *_: self._add_tactical_abbreviation_row("", "", "striker"))
        add_special_button = QPushButton("스페셜 추가")
        add_special_button.clicked.connect(lambda *_: self._add_tactical_abbreviation_row("", "", "special"))
        button_row.addStretch(1)
        button_row.addWidget(add_striker_button)
        button_row.addWidget(add_special_button)
        body_layout.addLayout(button_row)

        hint = QLabel("스트라이커와 스페셜 줄임말은 별도 사전입니다. 같은 글자도 슬롯에 따라 따로 해석됩니다.")
        hint.setObjectName("detailSub")
        hint.setWordWrap(True)
        body_layout.addWidget(hint)

        self._tactical_abbrev_rows: list[tuple[QLineEdit, QLineEdit, QWidget]] = []
        self._tactical_special_abbrev_rows: list[tuple[QLineEdit, QLineEdit, QWidget]] = []
        striker_label = QLabel("스트라이커")
        striker_label.setObjectName("detailSectionTitle")
        body_layout.addWidget(striker_label)
        self._tactical_abbrev_rows_layout = QVBoxLayout()
        self._tactical_abbrev_rows_layout.setContentsMargins(0, 0, 0, 0)
        self._tactical_abbrev_rows_layout.setSpacing(scale_px(5, self._ui_scale))
        body_layout.addLayout(self._tactical_abbrev_rows_layout)

        for key, value in sorted((self._tactical_data.abbreviations or {}).items()):
            self._add_tactical_abbreviation_row(key, value, "striker")
        if not self._tactical_abbrev_rows:
            self._add_tactical_abbreviation_row("", "", "striker")

        special_label = QLabel("스페셜")
        special_label.setObjectName("detailSectionTitle")
        body_layout.addWidget(special_label)
        self._tactical_special_abbrev_rows_layout = QVBoxLayout()
        self._tactical_special_abbrev_rows_layout.setContentsMargins(0, 0, 0, 0)
        self._tactical_special_abbrev_rows_layout.setSpacing(scale_px(5, self._ui_scale))
        body_layout.addLayout(self._tactical_special_abbrev_rows_layout)

        for key, value in sorted((self._tactical_data.special_abbreviations or {}).items()):
            self._add_tactical_abbreviation_row(key, value, "special")
        if not self._tactical_special_abbrev_rows:
            self._add_tactical_abbreviation_row("", "", "special")
        layout.addWidget(self._tactical_abbrev_body)
        self._set_tactical_abbreviation_expanded(False)
        return panel

    def _set_tactical_abbreviation_expanded(self, expanded: bool) -> None:
        body = getattr(self, "_tactical_abbrev_body", None)
        toggle = getattr(self, "_tactical_abbrev_toggle", None)
        if body is not None:
            body.setVisible(expanded)
        if toggle is not None:
            toggle.blockSignals(True)
            toggle.setChecked(expanded)
            toggle.setText("접기" if expanded else "펼치기")
            toggle.blockSignals(False)

    def _add_tactical_abbreviation_row(self, key: str, value: str, role: str = "striker") -> None:
        rows_layout_name = "_tactical_special_abbrev_rows_layout" if role == "special" else "_tactical_abbrev_rows_layout"
        rows_name = "_tactical_special_abbrev_rows" if role == "special" else "_tactical_abbrev_rows"
        rows_layout = getattr(self, rows_layout_name, None)
        rows = getattr(self, rows_name, None)
        if rows_layout is None or rows is None:
            return
        row = QWidget()
        row_layout = QHBoxLayout(row)
        row_layout.setContentsMargins(0, 0, 0, 0)
        row_layout.setSpacing(scale_px(5, self._ui_scale))
        key_input = QLineEdit(key)
        key_input.setMaxLength(1)
        key_input.setPlaceholderText("글자")
        key_input.setFixedWidth(scale_px(48, self._ui_scale))
        student_input = QLineEdit(value)
        student_input.setPlaceholderText("스페셜 학생" if role == "special" else "스트라이커 학생")
        remove_button = QPushButton("[삭제]")
        row_layout.addWidget(key_input)
        row_layout.addWidget(student_input, 1)
        row_layout.addWidget(remove_button)
        rows_layout.addWidget(row)
        rows.append((key_input, student_input, row))
        key_input.editingFinished.connect(self._save_tactical_abbreviations)
        student_input.editingFinished.connect(self._save_tactical_abbreviations)
        remove_button.clicked.connect(lambda *_args, target=row, target_role=role: self._remove_tactical_abbreviation_row(target, target_role))

    def _remove_tactical_abbreviation_row(self, row: QWidget, role: str = "striker") -> None:
        rows_name = "_tactical_special_abbrev_rows" if role == "special" else "_tactical_abbrev_rows"
        rows = getattr(self, rows_name, [])
        setattr(self, rows_name, [entry for entry in rows if entry[2] is not row])
        row.setParent(None)
        row.deleteLater()
        self._save_tactical_abbreviations()

    def _set_tactical_panel_mode(self, panel: dict, mode: str) -> None:
        panel["mode"] = mode if mode in {"attack", "defense", "jokbo"} else "attack"
        if "title" in panel:
            if panel.get("editing_match_id"):
                panel["title"].setText("전적 수정")
            else:
                panel["title"].setText("족보 모드" if panel["mode"] == "jokbo" else "대전 기록")
        panel["attack_mode_button"].setChecked(panel["mode"] == "attack")
        panel["defense_mode_button"].setChecked(panel["mode"] == "defense")
        panel["jokbo_mode_button"].setChecked(panel["mode"] == "jokbo")
        selected_style = "background: transparent; color: #ffb5f0; border: 2px solid #ffb5f0; font-weight: 900;"
        idle_style = f"background: transparent; color: {MUTED}; border: 1px solid {_mix_hex('#ffb5f0', SURFACE_ALT, 0.28)}; font-weight: 700;"
        panel["attack_mode_button"].setStyleSheet(selected_style if panel["mode"] == "attack" else idle_style)
        panel["defense_mode_button"].setStyleSheet(selected_style if panel["mode"] == "defense" else idle_style)
        panel["jokbo_mode_button"].setStyleSheet(selected_style if panel["mode"] == "jokbo" else idle_style)
        opponent_input = panel.get("opponent")
        if opponent_input is not None:
            is_jokbo = panel["mode"] == "jokbo"
            opponent_input.setEnabled(not is_jokbo)
            opponent_input.setPlaceholderText("족보 모드에서는 상대 이름 미사용" if is_jokbo else "상대 이름")

    def _set_tactical_panel_result(self, panel: dict, result: str) -> None:
        panel["result"] = "loss" if result == "loss" else "win"
        panel["win_button"].setChecked(panel["result"] == "win")
        panel["loss_button"].setChecked(panel["result"] == "loss")
        panel["win_button"].setText("승")
        panel["loss_button"].setText("패")
        selected_style = "background: transparent; color: #ffb5f0; border: 2px solid #ffb5f0; font-weight: 900;"
        idle_style = f"background: transparent; color: {MUTED}; border: 1px solid {_mix_hex('#ffb5f0', SURFACE_ALT, 0.28)}; font-weight: 700;"
        panel["win_button"].setStyleSheet(selected_style if panel["result"] == "win" else idle_style)
        panel["loss_button"].setStyleSheet(selected_style if panel["result"] == "loss" else idle_style)

    def _set_tactical_panel_editing(self, panel: dict, match: TacticalMatch | None = None) -> None:
        panel["editing_match_id"] = match.id if match is not None else ""
        panel["editing_source"] = match.source if match is not None else ""
        panel["editing_created_at"] = match.created_at if match is not None else ""
        save_button = panel.get("save_button")
        if save_button is not None:
            save_button.setText("수정 저장" if match is not None else "전적 추가")
        self._set_tactical_panel_mode(panel, panel.get("mode", "attack"))
        if hasattr(self, "_tactical_match_list"):
            self._refresh_tactical_match_list()

    def _load_tactical_match_into_panel(self, panel: dict, match: TacticalMatch) -> None:
        if hasattr(self, "_tactical_date"):
            self._tactical_date.setText(match.date or "")
        if hasattr(self, "_tactical_season"):
            self._tactical_season.setText(match.season or self._tactical_data.season or "")
        panel["opponent"].setText(match.opponent)
        panel["notes"].setPlainText(match.notes)
        self._set_tactical_panel_result(panel, match.result)
        has_attack_pair = bool(match.my_attack.strikers or match.my_attack.supports or match.opponent_defense.strikers or match.opponent_defense.supports)
        has_defense_pair = bool(match.my_defense.strikers or match.my_defense.supports or match.opponent_attack.strikers or match.opponent_attack.supports)
        mode = "defense" if has_defense_pair and not has_attack_pair else "attack"
        self._set_tactical_panel_mode(panel, mode)
        if mode == "defense":
            self._set_tactical_deck_inputs(panel["attack"], match.opponent_attack)
            self._set_tactical_deck_inputs(panel["defense"], match.my_defense)
        else:
            self._set_tactical_deck_inputs(panel["attack"], match.my_attack)
            self._set_tactical_deck_inputs(panel["defense"], match.opponent_defense)
        self._set_tactical_panel_editing(panel, match)
        self._set_tactical_status(f"{self._tactical_date_label(match)} {match.opponent} 전적을 수정 모드로 불러왔습니다.", panel=panel)

    def _tactical_import_key(self, value: object) -> str:
        return re.sub(r"[\s_\-./()]+", "", str(value or "").strip().casefold())

    def _tactical_import_template_path(self) -> Path:
        return get_storage_paths().current_dir / "tactical_challenge_import_template.xlsx"

    def _ensure_tactical_import_template(self) -> Path:
        path = self._tactical_import_template_path()
        ensure_tactical_import_template(path)
        return path

    def _tactical_import_value(self, row: dict[str, str], *aliases: str) -> str:
        for alias in aliases:
            value = row.get(self._tactical_import_key(alias), "")
            if str(value or "").strip():
                return str(value).strip()
        return ""

    def _tactical_import_deck_value(
        self,
        row: dict[str, str],
        single_aliases: tuple[str, ...],
        slot_aliases: tuple[str, ...],
    ) -> str:
        single_value = self._tactical_import_value(row, *single_aliases)
        if single_value:
            return single_value

        def _slot(index: int) -> str:
            aliases: list[str] = []
            for alias in slot_aliases:
                aliases.extend(
                    [
                        f"{alias}{index}",
                        f"{alias}S{index}",
                        f"{alias}스트{index}",
                        f"{alias}스트라이커{index}",
                    ]
                )
            return self._tactical_import_value(row, *aliases)

        def _support(index: int) -> str:
            aliases: list[str] = []
            for alias in slot_aliases:
                aliases.extend(
                    [
                        f"{alias}SP{index}",
                        f"{alias}Special{index}",
                        f"{alias}스페셜{index}",
                        f"{alias}서포터{index}",
                        f"{alias}지원{index}",
                    ]
                )
            return self._tactical_import_value(row, *aliases)

        strikers = [_slot(index) for index in range(1, TACTICAL_STRIKER_SLOTS + 1)]
        supports = [_support(index) for index in range(1, TACTICAL_SUPPORT_SLOTS + 1)]
        if not any(strikers) and not any(supports):
            return ""
        return f"{','.join(strikers)}|{','.join(supports)}"

    def _normalize_tactical_import_date(self, value: str) -> str:
        text = str(value or "").strip()
        if not text:
            return ""
        if re.fullmatch(r"\d{8}", text):
            return date(int(text[:4]), int(text[4:6]), int(text[6:8])).isoformat()
        if re.fullmatch(r"\d+(\.0+)?", text):
            serial = int(float(text))
            if 20000 <= serial <= 80000:
                return (date(1899, 12, 30) + timedelta(days=serial)).isoformat()
        normalized = re.sub(r"[./]", "-", text)
        return date.fromisoformat(normalized[:10]).isoformat()

    def _normalize_tactical_import_result(self, value: str) -> str:
        key = self._tactical_import_key(value)
        if key in {"승", "win", "w", "1", "true", "o"}:
            return "win"
        if key in {"패", "loss", "lose", "l", "0", "false", "x"}:
            return "loss"
        return ""

    def _normalize_tactical_import_mode(self, value: str) -> str:
        key = self._tactical_import_key(value)
        if "족보" in key or "jokbo" in key:
            return "jokbo"
        if "방어" in key or "defense" in key or key == "def":
            return "defense"
        return "attack"

    def _canonical_import_deck(self, row_number: int, deck_text: str, label: str, errors: list[str]) -> TacticalDeck:
        deck = self._parse_tactical_deck_template(deck_text)
        canonical, error = self._canonical_tactical_deck_or_error(deck, label)
        if error:
            errors.append(f"{row_number}행: {error}")
        return canonical

    def _failed_tactical_import_row(self, raw_row: dict[str, str], error: str) -> dict[str, str]:
        failed = {str(key): str(value or "").strip() for key, value in raw_row.items()}
        failed["오류"] = error
        return failed

    def _build_tactical_import_entries(self, rows: list[dict[str, str]]) -> tuple[list[TacticalMatch], list[TacticalJokboEntry], list[str], list[dict[str, str]]]:
        matches: list[TacticalMatch] = []
        jokbo_entries: list[TacticalJokboEntry] = []
        errors: list[str] = []
        failed_rows: list[dict[str, str]] = []
        now = datetime.now().isoformat(timespec="seconds")

        for index, raw_row in enumerate(rows, start=2):
            row = {self._tactical_import_key(key): str(value or "").strip() for key, value in raw_row.items()}

            def reject(message: str) -> None:
                errors.append(message)
                failed_rows.append(self._failed_tactical_import_row(raw_row, message))

            mode = self._normalize_tactical_import_mode(
                self._tactical_import_value(row, "mode", "type", "구분", "종류", "기록종류", "기록")
            )
            generic_attack = self._tactical_import_deck_value(
                row,
                ("attack", "atk", "공격덱", "공덱"),
                ("attack", "atk", "공격", "공"),
            )
            generic_defense = self._tactical_import_deck_value(
                row,
                ("defense", "def", "방어덱", "방덱"),
                ("defense", "def", "방어", "방"),
            )
            notes = self._tactical_import_value(row, "notes", "note", "memo", "메모", "비고")
            source = self._tactical_import_value(row, "source", "출처", "데이터출처", "source_type") or "내 기록"
            row_id = self._tactical_import_value(row, "id", "match_id", "고유값")

            if mode == "jokbo":
                defense_text = self._tactical_import_deck_value(
                    row,
                    ("jokbo_defense", "족보방어덱", "방어덱", "방덱"),
                    ("jokbo_defense", "jokbodef", "족보방어", "방어", "방"),
                ) or generic_defense
                attack_text = self._tactical_import_deck_value(
                    row,
                    ("jokbo_attack", "족보공격덱", "공격덱", "공덱"),
                    ("jokbo_attack", "jokboatk", "족보공격", "공격", "공"),
                ) or generic_attack
                if not defense_text or not attack_text:
                    reject(f"{index}행: 족보는 공격덱과 방어덱이 모두 필요합니다.")
                    continue
                jokbo_errors_before = len(errors)
                defense = self._canonical_import_deck(index, defense_text, "족보 방어덱", errors)
                attack = self._canonical_import_deck(index, attack_text, "족보 공격덱", errors)
                if len(errors) != jokbo_errors_before:
                    failed_rows.append(self._failed_tactical_import_row(raw_row, "\n".join(errors[jokbo_errors_before:])))
                    continue
                jokbo_entries.append(
                    TacticalJokboEntry(
                        id=row_id or f"import-jokbo-{datetime.now().strftime('%Y%m%d%H%M%S')}-{index}-{uuid4().hex[:6]}",
                        defense=defense,
                        attack=attack,
                        notes=notes,
                        updated_at=now,
                    )
                )
                continue

            date_text = self._tactical_import_value(row, "date", "날짜", "일자")
            opponent = self._tactical_import_value(row, "opponent", "상대", "상대이름", "name", "이름")
            result_text = self._tactical_import_value(row, "result", "승패", "결과", "winloss")
            result = self._normalize_tactical_import_result(result_text) if result_text else "loss"
            if not opponent and source != "내 기록":
                opponent = "미상"
            if not opponent:
                reject(f"{index}행: 상대 이름이 필요합니다.")
                continue
            if result_text and not result:
                reject(f"{index}행: 승패는 승/패 또는 win/loss로 입력해 주세요.")
                continue
            if date_text:
                try:
                    match_date = self._normalize_tactical_import_date(date_text)
                except Exception:
                    reject(f"{index}행: 날짜 '{date_text}'를 인식할 수 없습니다.")
                    continue
            else:
                match_date = ""

            my_attack_text = self._tactical_import_deck_value(
                row,
                ("my_attack", "my atk", "내공격덱", "내공덱"),
                ("my_attack", "myatk", "내공격", "내공"),
            )
            opponent_defense_text = self._tactical_import_deck_value(
                row,
                ("opponent_defense", "op def", "상대방어덱", "상대방덱"),
                ("opponent_defense", "opdef", "상대방어", "상대방"),
            )
            my_defense_text = self._tactical_import_deck_value(
                row,
                ("my_defense", "my def", "내방어덱", "내방덱"),
                ("my_defense", "mydef", "내방어", "내방"),
            )
            opponent_attack_text = self._tactical_import_deck_value(
                row,
                ("opponent_attack", "op atk", "상대공격덱", "상대공덱"),
                ("opponent_attack", "opatk", "상대공격", "상대공"),
            )
            if mode == "defense":
                my_defense_text = my_defense_text or generic_defense
                opponent_attack_text = opponent_attack_text or generic_attack
            else:
                my_attack_text = my_attack_text or generic_attack
                opponent_defense_text = opponent_defense_text or generic_defense

            if not any((my_attack_text, opponent_defense_text, my_defense_text, opponent_attack_text)):
                reject(f"{index}행: 덱 정보가 필요합니다.")
                continue

            match_errors_before = len(errors)
            my_attack = self._canonical_import_deck(index, my_attack_text, "내 공격덱", errors) if my_attack_text else TacticalDeck()
            opponent_defense = self._canonical_import_deck(index, opponent_defense_text, "상대 방어덱", errors) if opponent_defense_text else TacticalDeck()
            my_defense = self._canonical_import_deck(index, my_defense_text, "내 방어덱", errors) if my_defense_text else TacticalDeck()
            opponent_attack = self._canonical_import_deck(index, opponent_attack_text, "상대 공격덱", errors) if opponent_attack_text else TacticalDeck()
            if len(errors) != match_errors_before:
                failed_rows.append(self._failed_tactical_import_row(raw_row, "\n".join(errors[match_errors_before:])))
                continue

            matches.append(
                TacticalMatch(
                    id=row_id or f"import-tc-{datetime.now().strftime('%Y%m%d%H%M%S')}-{index}-{uuid4().hex[:6]}",
                    date=match_date,
                    season=self._tactical_import_value(row, "season", "시즌") or self._tactical_data.season,
                    opponent=opponent,
                    result=result,
                    my_attack=my_attack,
                    opponent_defense=opponent_defense,
                    my_defense=my_defense,
                    opponent_attack=opponent_attack,
                    source=source,
                    notes=notes,
                    created_at=now,
                )
            )

        return matches, jokbo_entries, errors, failed_rows

    def _import_tactical_spreadsheet(self) -> None:
        template_path = self._ensure_tactical_import_template()
        self._show_busy_overlay("가져오는 중...")
        try:
            rows = read_tactical_import_rows(template_path)
            if not rows:
                self._set_tactical_status(f"템플릿에 가져올 행이 없습니다.\n{template_path}", error=True)
                return
            matches, jokbo_entries, errors, failed_rows = self._build_tactical_import_entries(rows)
            if not matches and not jokbo_entries and errors:
                write_tactical_import_rows(template_path, failed_rows)
                preview = "\n".join(errors[:12])
                suffix = f"\n...외 {len(errors) - 12}개 오류" if len(errors) > 12 else ""
                self._set_tactical_status(
                    "가져올 수 있는 행이 없습니다. 문제가 있는 행만 템플릿에 남겼습니다.\n" + preview + suffix,
                    error=True,
                )
                return
            upsert_tactical_matches(self._tactical_path, matches)
            upsert_tactical_jokbo_entries(self._tactical_path, jokbo_entries)
            self._storage_mtimes = self._snapshot_storage_mtimes()
            self._tactical_match_loaded_count = max(self._tactical_match_loaded_count, self._tactical_match_page_size)
            self._refresh_tactical_match_list()
            self._refresh_tactical_jokbo_results()
            if failed_rows:
                write_tactical_import_rows(template_path, failed_rows)
                preview = "\n".join(errors[:8])
                suffix = f"\n...외 {len(errors) - 8}개 오류" if len(errors) > 8 else ""
                self._set_tactical_status(
                    f"정상 행은 가져왔습니다. 전적 {len(matches)}개, 족보 {len(jokbo_entries)}개\n"
                    f"문제가 있는 행 {len(failed_rows)}개는 템플릿에 남겼습니다. 확인이 필요합니다.\n"
                    f"{preview}{suffix}",
                    error=True,
                )
            else:
                clear_tactical_import_template(template_path)
                self._set_tactical_status(
                    f"템플릿 데이터를 가져왔습니다. 전적 {len(matches)}개, 족보 {len(jokbo_entries)}개\n"
                    f"템플릿을 비웠습니다: {template_path}"
                )
        except Exception as exc:
            self._set_tactical_status(f"가져오기 실패: {exc}", error=True)
        finally:
            self._hide_busy_overlay()

    def _save_tactical_match_panel(self, panel: dict) -> None:
        if not self._save_tactical_abbreviations():
            return
        season = self._tactical_season.text().strip()
        if self._tactical_data.season != season:
            self._tactical_data.season = season
            self._save_tactical_metadata()
        now = datetime.now().isoformat(timespec="seconds")
        attack_deck = self._deck_from_tactical_inputs(panel["attack"])
        defense_deck = self._deck_from_tactical_inputs(panel["defense"])
        attack_deck, attack_error = self._canonical_tactical_deck_or_error(attack_deck, "공격덱")
        defense_deck, defense_error = self._canonical_tactical_deck_or_error(defense_deck, "방어덱")
        if attack_error or defense_error:
            self._set_tactical_status("\n".join(error for error in (attack_error, defense_error) if error), error=True, panel=panel)
            return
        self._set_tactical_deck_inputs(panel["attack"], attack_deck)
        self._set_tactical_deck_inputs(panel["defense"], defense_deck)
        if panel.get("mode") == "jokbo":
            if panel.get("editing_match_id"):
                self._set_tactical_status("전적 수정 중에는 족보로 저장할 수 없습니다. Clear로 수정 모드를 끝낸 뒤 저장해 주세요.", error=True, panel=panel)
                return
            if not any(defense_deck.strikers) and not any(defense_deck.supports):
                self._set_tactical_status("족보의 방어덱을 입력해 주세요.", error=True, panel=panel)
                return
            if not any(attack_deck.strikers) and not any(attack_deck.supports):
                self._set_tactical_status("족보의 공격덱을 입력해 주세요.", error=True, panel=panel)
                return
            entry = TacticalJokboEntry(
                id=f"jokbo-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:6]}",
                defense=defense_deck,
                attack=attack_deck,
                wins=0,
                losses=0,
                notes=panel["notes"].toPlainText().strip(),
                updated_at=now,
            )
            self._show_busy_overlay()
            try:
                self._tactical_data.jokbo.append(entry)
                upsert_tactical_jokbo(self._tactical_path, entry)
                self._storage_mtimes = self._snapshot_storage_mtimes()
                if hasattr(self, "_tactical_jokbo_search_inputs"):
                    self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, defense_deck)
                self._refresh_tactical_jokbo_results()
            finally:
                self._hide_busy_overlay()
            self._set_tactical_status("족보를 저장했습니다.", panel=panel)
            return

        opponent = panel["opponent"].text().strip()
        if not opponent:
            self._set_tactical_status("상대 이름을 입력해 주세요.", error=True, panel=panel)
            return
        editing_match_id = str(panel.get("editing_match_id") or "")
        existing_match = get_tactical_match(self._tactical_path, editing_match_id) if editing_match_id else None
        is_defense_record = panel.get("mode") == "defense"
        match = TacticalMatch(
            id=editing_match_id or f"tc-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:6]}",
            date=self._tactical_date.text().strip(),
            season=season,
            opponent=opponent,
            result=str(panel["result"]),
            my_attack=TacticalDeck() if is_defense_record else attack_deck,
            opponent_defense=TacticalDeck() if is_defense_record else defense_deck,
            my_defense=defense_deck if is_defense_record else TacticalDeck(),
            opponent_attack=attack_deck if is_defense_record else TacticalDeck(),
            source=panel.get("editing_source") or (existing_match.source if existing_match is not None else "내 기록") or "내 기록",
            notes=panel["notes"].toPlainText().strip(),
            created_at=panel.get("editing_created_at") or (existing_match.created_at if existing_match is not None else now) or now,
        )
        self._tactical_selected_match_id = match.id
        self._show_busy_overlay()
        try:
            upsert_tactical_match(self._tactical_path, match)
            self._storage_mtimes = self._snapshot_storage_mtimes()
            self._tactical_match_loaded_count = max(self._tactical_match_loaded_count, self._tactical_match_page_size)
            self._refresh_tactical_match_list()
        finally:
            self._hide_busy_overlay()
        self._set_tactical_panel_editing(panel, match if editing_match_id else None)
        action_text = "수정했습니다" if editing_match_id else "저장했습니다"
        self._set_tactical_status(f"{self._tactical_date_label(match)} {opponent} 전적을 {action_text}.", panel=panel)

    def _clear_tactical_match_panel(self, panel: dict) -> None:
        panel["opponent"].clear()
        panel["notes"].clear()
        self._set_tactical_status("", panel=panel)
        self._set_tactical_panel_editing(panel, None)
        self._set_tactical_panel_result(panel, "win")
        self._set_tactical_panel_mode(panel, "attack")
        if hasattr(self, "_tactical_date"):
            self._tactical_date.setText(date.today().isoformat())
        if hasattr(self, "_tactical_season"):
            self._tactical_season.setText(self._tactical_data.season or "")
        self._clear_tactical_deck_inputs(panel["attack"])
        self._clear_tactical_deck_inputs(panel["defense"])

    def _load_recent_tactical_match_panel(self, panel: dict, mode: str) -> None:
        opponent = panel["opponent"].text().strip()
        if not opponent:
            self._set_tactical_status("상대 이름을 입력해 주세요.", error=True, panel=panel)
            return
        mode = "defense" if mode == "defense" else "attack"
        self._show_busy_overlay("불러오는 중...")
        try:
            match = latest_tactical_match_for_opponent(self._tactical_path, opponent, mode)
        finally:
            self._hide_busy_overlay()
        if match is None:
            label = "방어" if mode == "defense" else "공격"
            self._set_tactical_status(f"{opponent}의 최근 {label} 기록을 찾지 못했습니다.", error=True, panel=panel)
            return
        self._set_tactical_panel_mode(panel, mode)
        self._set_tactical_panel_result(panel, match.result)
        if mode == "defense":
            self._set_tactical_deck_inputs(panel["attack"], match.opponent_attack)
            self._set_tactical_deck_inputs(panel["defense"], match.my_defense)
        else:
            self._set_tactical_deck_inputs(panel["attack"], match.my_attack)
            self._set_tactical_deck_inputs(panel["defense"], match.opponent_defense)
        label = "방어" if mode == "defense" else "공격"
        self._set_tactical_status(f"{self._tactical_date_label(match)} {opponent} 최근 {label} 기록을 가져왔습니다.", panel=panel)

    def _start_tactical_screenshot_task(self, panel: dict, path: str, busy_text: str) -> None:
        self._show_busy_overlay(busy_text)
        task = TacticalScreenshotTask(path, self._tactical_screenshot_candidate_priority(), self._tactical_screenshot_answer_cache_path())
        task.signals.loaded.connect(
            lambda loaded_path, readout, target=panel, finished_task=task: self._apply_tactical_screenshot_readout(
                target,
                loaded_path,
                readout,
                finished_task,
            )
        )
        task.signals.failed.connect(
            lambda loaded_path, message, target=panel, finished_task=task: self._fail_tactical_screenshot_import(
                target,
                loaded_path,
                message,
                finished_task,
            )
        )
        self._tactical_screenshot_tasks.append(task)
        self._pool.start(task)

    def _start_tactical_screenshot_batch_task(self, panel: dict, paths: list[str], busy_text: str) -> None:
        self._show_busy_overlay(busy_text)
        task = TacticalScreenshotBatchTask(paths, self._tactical_screenshot_candidate_priority(), self._tactical_screenshot_answer_cache_path())
        task.signals.completed.connect(
            lambda results, errors, target=panel, finished_task=task: self._apply_tactical_screenshot_batch(
                target,
                results,
                errors,
                finished_task,
            )
        )
        self._tactical_screenshot_tasks.append(task)
        self._pool.start(task)

    def _tactical_screenshot_answer_cache_path(self) -> str:
        return str(get_storage_paths().current_dir / "tactical_screenshot_answer_cache.json")

    def _tactical_screenshot_candidate_priority(self) -> dict[str, list[str]]:
        season = self._tactical_season.text().strip() if hasattr(self, "_tactical_season") else ""
        try:
            return tactical_student_frequency_from_storage(self._tactical_path, season, limit=20)
        except Exception:
            return {}
    def _paste_tactical_screenshot_panel(self, panel: dict) -> None:
        clipboard = QApplication.clipboard()
        image = clipboard.image()
        source_path = ""
        if image.isNull():
            pixmap = clipboard.pixmap()
            if not pixmap.isNull():
                image = pixmap.toImage()
        if image.isNull():
            mime = clipboard.mimeData()
            if mime is not None and mime.hasUrls():
                for url in mime.urls():
                    path = Path(url.toLocalFile())
                    if path.suffix.casefold() in {".png", ".jpg", ".jpeg", ".bmp"} and path.exists():
                        source_path = str(path)
                        break
        if image.isNull() and not source_path:
            self._set_tactical_status("클립보드에 분석할 이미지가 없습니다.", error=True, panel=panel)
            return
        if source_path:
            self._start_tactical_screenshot_task(panel, source_path, "클립보드 이미지 분석 중...")
            return

        clipboard_dir = get_storage_paths().current_dir / "tactical_clipboard"
        clipboard_dir.mkdir(parents=True, exist_ok=True)
        path = clipboard_dir / f"tactical_clipboard_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid4().hex[:6]}.png"
        if not image.save(str(path), "PNG"):
            self._set_tactical_status("클립보드 이미지를 저장하지 못했습니다.", error=True, panel=panel)
            return
        self._start_tactical_screenshot_task(panel, str(path), "클립보드 이미지 분석 중...")

    def _import_tactical_screenshot_panel(self, panel: dict) -> None:
        paths, _selected_filter = QFileDialog.getOpenFileNames(
            self,
            "Select tactical result screenshots",
            str(Path.home() / "Pictures" / "Screenshots"),
            "Images (*.png *.jpg *.jpeg *.bmp *.webp);;All Files (*)",
        )
        if not paths:
            return
        paths = sorted(paths, key=self._tactical_screenshot_file_time_key)
        if len(paths) > 1:
            self._start_tactical_screenshot_batch_task(
                panel,
                paths,
                f"Analyzing {len(paths)} screenshots...",
            )
            return
        self._start_tactical_screenshot_task(panel, paths[0], "Analyzing screenshot...")

    def _import_tactical_screenshot_folder_panel(self, panel: dict) -> None:
        folder = QFileDialog.getExistingDirectory(
            self,
            "Select tactical screenshot folder",
            str(Path.home() / "Pictures" / "Screenshots"),
        )
        if not folder:
            return
        paths = [str(path) for path in collect_tactical_screenshot_images(folder)]
        if not paths:
            self._set_tactical_status("Folder contains no readable 16:9 screenshots.", error=True, panel=panel)
            return
        paths = sorted(paths, key=self._tactical_screenshot_batch_sort_key)
        self._start_tactical_screenshot_batch_task(
            panel,
            paths,
            f"Analyzing {len(paths)} folder screenshots...",
        )

    def _tactical_screenshot_batch_sort_key(self, path: str) -> tuple[str, int, int, str]:
        inferred_date = tactical_screenshot_date_from_path(path)
        created_ns, modified_ns, folded = self._tactical_screenshot_file_time_key(path)
        return (inferred_date, created_ns, modified_ns, folded)

    def _tactical_screenshot_file_time_key(self, path: str) -> tuple[int, int, str]:
        try:
            stat = Path(path).stat()
            created_ns = getattr(stat, "st_birthtime_ns", None)
            if created_ns is None:
                created_ns = int(stat.st_ctime_ns)
            modified_ns = int(stat.st_mtime_ns)
        except OSError:
            created_ns = 0
            modified_ns = 0
        return (int(created_ns), modified_ns, str(path).casefold())

    def _discard_tactical_screenshot_task(self, task: QRunnable | None) -> None:
        if task is None:
            return
        try:
            self._tactical_screenshot_tasks.remove(task)
        except ValueError:
            pass

    def _fail_tactical_screenshot_import(
        self,
        panel: dict,
        _path: str,
        message: str,
        task: TacticalScreenshotTask | None = None,
    ) -> None:
        self._discard_tactical_screenshot_task(task)
        self._hide_busy_overlay()
        self._set_tactical_status(f"스크린샷 분석 실패: {message}", error=True, panel=panel)

    def _display_tactical_screenshot_deck(self, deck: TacticalDeck) -> TacticalDeck:
        return TacticalDeck(
            strikers=[self._tactical_student_display_name(student_id) for student_id in deck.strikers],
            supports=[self._tactical_student_display_name(student_id) for student_id in deck.supports],
        )

    def _tactical_match_from_screenshot_readout(
        self,
        readout: object,
        *,
        opponent: str,
        match_date: str,
        season: str,
        source: str,
        notes: str,
        created_at: str,
    ) -> TacticalMatch:
        left_deck = self._display_tactical_screenshot_deck(readout.left.deck)
        right_deck = self._display_tactical_screenshot_deck(readout.right.deck)
        is_defense_record = readout.mode == "defense"
        return TacticalMatch(
            id=f"tc-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:6]}",
            date=match_date,
            season=season,
            opponent=opponent,
            result=readout.result,
            my_attack=TacticalDeck() if is_defense_record else left_deck,
            opponent_defense=TacticalDeck() if is_defense_record else right_deck,
            my_defense=left_deck if is_defense_record else TacticalDeck(),
            opponent_attack=right_deck if is_defense_record else TacticalDeck(),
            source=source,
            notes=notes,
            created_at=created_at,
        )

    def _apply_tactical_screenshot_batch(
        self,
        panel: dict,
        results: object,
        errors: object,
        task: QRunnable | None = None,
    ) -> None:
        self._discard_tactical_screenshot_task(task)
        self._hide_busy_overlay()
        readouts = list(results or [])
        failures = list(errors or [])
        if not readouts:
            preview = "; ".join(f"{Path(path).name}: {message}" for path, message in failures[:3])
            self._set_tactical_status(f"스크린샷 분석 실패: {preview}", error=True, panel=panel)
            return

        fallback_match_date = self._tactical_date.text().strip() if hasattr(self, "_tactical_date") else ""
        if not fallback_match_date:
            fallback_match_date = date.today().isoformat()
        season = self._tactical_season.text().strip() if hasattr(self, "_tactical_season") else ""
        now = datetime.now()
        matches: list[TacticalMatch] = []
        warnings: list[str] = []
        for index, (path, readout) in enumerate(readouts):
            created_at = (now + timedelta(microseconds=index)).isoformat(timespec="microseconds")
            match = self._tactical_match_from_screenshot_readout(
                readout,
                opponent="",
                match_date=tactical_screenshot_date_from_path(path) or fallback_match_date,
                season=season,
                source="스크린샷",
                notes="",
                created_at=created_at,
            )
            matches.append(match)
            warnings.extend(f"{Path(path).name}: {warning}" for warning in readout.warnings[:2])

        upsert_tactical_matches(self._tactical_path, matches)
        self._storage_mtimes = self._snapshot_storage_mtimes()
        self._tactical_match_loaded_count = max(self._tactical_match_loaded_count, self._tactical_match_page_size)
        self._tactical_selected_match_id = matches[-1].id if matches else self._tactical_selected_match_id
        self._refresh_tactical_match_list()
        self._refresh_tactical_jokbo_results()
        panel["opponent"].clear()

        failed_text = f" 실패 {len(failures)}장." if failures else ""
        warning_text = f"\n주의: {' / '.join(warnings[:3])}" if warnings else ""
        self._set_tactical_status(
            f"스크린샷 {len(matches)}장을 상대 이름 없이 순서대로 추가했습니다.{failed_text}{warning_text}",
            error=bool(failures or warnings),
            panel=panel,
        )
        self._open_tactical_opponents_batch(matches, panel=panel)

    def _apply_tactical_screenshot_readout(
        self,
        panel: dict,
        _path: str,
        readout: object,
        task: TacticalScreenshotTask | None = None,
    ) -> None:
        self._discard_tactical_screenshot_task(task)
        self._hide_busy_overlay()

        self._set_tactical_panel_editing(panel, None)
        self._set_tactical_panel_result(panel, readout.result)
        self._set_tactical_panel_mode(panel, readout.mode)
        if readout.mode == "defense":
            self._set_tactical_deck_inputs(panel["attack"], self._display_tactical_screenshot_deck(readout.right.deck))
            self._set_tactical_deck_inputs(panel["defense"], self._display_tactical_screenshot_deck(readout.left.deck))
        else:
            self._set_tactical_deck_inputs(panel["attack"], self._display_tactical_screenshot_deck(readout.left.deck))
            self._set_tactical_deck_inputs(panel["defense"], self._display_tactical_screenshot_deck(readout.right.deck))
        if hasattr(self, "_tactical_date") and not self._tactical_date.text().strip():
            self._tactical_date.setText(date.today().isoformat())
        mode_label = "방어 기록" if readout.mode == "defense" else "공격 기록"
        result_label = "승" if readout.result == "win" else "패"
        warning_text = f"\n주의: {' / '.join(readout.warnings[:3])}" if readout.warnings else ""
        self._set_tactical_status(
            f"스크린샷에서 {mode_label} · {result_label} · 좌우 덱을 불러왔습니다. 상대 이름은 직접 입력해 주세요."
            f"{warning_text}",
            error=bool(readout.warnings),
            panel=panel,
        )

    def _save_tactical_season(self) -> None:
        if self._tactical_data.season == self._tactical_season.text().strip():
            return
        self._tactical_data.season = self._tactical_season.text().strip()
        self._save_tactical_metadata()

    def _save_tactical_abbreviations(self) -> bool:
        if not hasattr(self, "_tactical_abbrev_rows"):
            return True
        errors: list[str] = []

        def _collect(rows: list[tuple[QLineEdit, QLineEdit, QWidget]], expected_class: str, label: str) -> dict[str, str]:
            mapping: dict[str, str] = {}
            for key_input, student_input, _row in rows:
                key = key_input.text().strip()
                value = student_input.text().strip()
                if not key and not value:
                    continue
                if not key or not value:
                    errors.append(f"{label} 줄임말: 글자와 학생을 모두 입력해 주세요.")
                    continue
                if len(key) != 1:
                    errors.append(f"{label} 줄임말: '{key}'는 한 글자만 사용할 수 있습니다.")
                    continue
                if key in mapping:
                    errors.append(f"{label} 줄임말: '{key}'가 중복 등록되어 있습니다.")
                    continue
                matches = self._tactical_student_ids_for_name(value)
                if not matches:
                    errors.append(f"{label} 줄임말: '{value}' 학생을 인식할 수 없습니다.")
                    continue
                if len(matches) > 1:
                    names = ", ".join(self._tactical_student_display_name(student_id) for student_id in matches[:6])
                    suffix = "..." if len(matches) > 6 else ""
                    errors.append(f"{label} 줄임말: '{value}' 중복 태그입니다. ({names}{suffix})")
                    continue
                student_id = matches[0]
                if student_meta.combat_class(student_id) != expected_class:
                    errors.append(f"{label} 줄임말: '{self._tactical_student_display_name(student_id)}'는 {label} 학생이 아닙니다.")
                    continue
                mapping[key] = self._tactical_student_display_name(student_id)
                student_input.setText(mapping[key])
            return mapping

        striker_mapping = _collect(self._tactical_abbrev_rows, "striker", "스트라이커")
        special_mapping = _collect(getattr(self, "_tactical_special_abbrev_rows", []), "special", "스페셜")
        if errors:
            self._set_tactical_status("\n".join(errors), error=True)
            return False
        if (
            striker_mapping == self._tactical_data.abbreviations
            and special_mapping == self._tactical_data.special_abbreviations
        ):
            return True
        self._tactical_data.abbreviations = striker_mapping
        self._tactical_data.special_abbreviations = special_mapping
        self._save_tactical_metadata()
        return True

    def _compact_tactical_message(self, text: str, *, max_lines: int = 2, max_chars: int = 150) -> str:
        full_text = str(text or "").strip()
        if not full_text:
            return ""
        lines = [line.strip() for line in full_text.splitlines() if line.strip()]
        if len(lines) > max_lines:
            visible = lines[:max_lines]
            visible.append(f"...외 {len(lines) - max_lines}개")
            return "\n".join(visible)
        compact = "\n".join(lines) if lines else full_text
        if len(compact) > max_chars:
            return compact[: max(0, max_chars - 3)].rstrip() + "..."
        return compact

    def _set_tactical_status(self, text: str, *, error: bool = False, panel: dict | None = None) -> None:
        target = panel.get("status") if panel is not None else None
        if target is None and getattr(self, "_tactical_match_panels", None):
            target = self._tactical_match_panels[0].get("status")
        if target is None and hasattr(self, "_tactical_status"):
            target = self._tactical_status
        if target is None:
            return
        full_text = str(text or "").strip()
        compact_text = self._compact_tactical_message(full_text)
        target.setStyleSheet("color: #ff6b6b; font-weight: 800;" if error else "")
        target.setText(compact_text)
        target.setToolTip(full_text if full_text and full_text != compact_text else "")
        target.setVisible(bool(full_text))

    def _tactical_lookup_key(self, value: object) -> str:
        cleaned = " ".join(str(value or "").strip().split())
        cleaned = re.sub(r"\s*([()])\s*", r"\1", cleaned)
        return cleaned.casefold()

    def _tactical_abbreviation_map(self, role: str = "striker") -> dict[str, str]:
        rows_name = "_tactical_special_abbrev_rows" if role == "special" else "_tactical_abbrev_rows"
        data = self._tactical_data.special_abbreviations if role == "special" else self._tactical_data.abbreviations
        if hasattr(self, rows_name):
            mapping: dict[str, str] = {}
            for key_input, student_input, _row in getattr(self, rows_name):
                key = key_input.text().strip()
                value = student_input.text().strip()
                if len(key) == 1 and value:
                    mapping[key] = value
            return mapping
        return dict(data or {})

    def _parse_tactical_deck_template(self, value: str) -> TacticalDeck:
        raw = str(value or "").strip()
        if not raw:
            return TacticalDeck()
        striker_abbreviations = self._tactical_abbreviation_map("striker")
        special_abbreviations = self._tactical_abbreviation_map("special")
        if "|" in raw:
            striker_raw, support_raw = raw.split("|", 1)
        else:
            striker_raw, support_raw = raw, ""

        compact_striker = "".join(striker_raw.split())
        compact_support = "".join(support_raw.split())
        has_striker_separator = any(separator in striker_raw for separator in ",/;")
        has_support_separator = any(separator in support_raw for separator in ",/;")
        exact_striker = self._tactical_student_ids_for_name(compact_striker)
        exact_support = self._tactical_student_ids_for_name(compact_support)
        compact_strikers = (
            compact_striker
            and not exact_striker
            and not has_striker_separator
            and 1 < len(compact_striker) <= TACTICAL_STRIKER_SLOTS
            and all(char in striker_abbreviations for char in compact_striker)
        )
        compact_supports = (
            compact_support
            and not exact_support
            and not has_support_separator
            and 1 < len(compact_support) <= TACTICAL_SUPPORT_SLOTS
            and all(char in special_abbreviations for char in compact_support)
        )
        deck = parse_deck_template(raw)
        deck.strikers = (
            [striker_abbreviations[char] for char in compact_striker]
            if compact_strikers
            else [striker_abbreviations.get(name, name) if len(name) == 1 else name for name in deck.strikers]
        )
        deck.supports = (
            [special_abbreviations[char] for char in compact_support]
            if compact_supports
            else [special_abbreviations.get(name, name) if len(name) == 1 else name for name in deck.supports]
        )
        return deck

    def _tactical_student_ids_for_name(self, name: str) -> list[str]:
        needle = self._tactical_lookup_key(name)
        if not needle:
            return []
        index = self._tactical_student_lookup_index_map()
        return list(index.get(needle, []))

    def _tactical_student_lookup_index_map(self) -> dict[str, list[str]]:
        cached = getattr(self, "_tactical_student_lookup_index", None)
        if cached is not None:
            return cached
        index: dict[str, set[str]] = defaultdict(set)

        for student_id in student_meta.all_ids():
            record = self._records_by_id.get(student_id)
            terms: list[object] = [
                student_id,
                student_id.replace("_", " "),
                student_meta.display_name(student_id),
                record.title if record is not None else "",
                record.display_name if record is not None else "",
            ]
            terms.extend(student_meta.search_tags(student_id))
            terms.extend(student_meta.kr_search_tags(student_id))
            for term in terms:
                key = self._tactical_lookup_key(term)
                if key:
                    index[key].add(student_id)
        built = {
            key: sorted(values, key=lambda student_id: student_meta.display_name(student_id).casefold())
            for key, values in index.items()
        }
        self._tactical_student_lookup_index = built
        return built

    def _tactical_student_display_name(self, student_id: str) -> str:
        record = self._records_by_id.get(student_id)
        return record.title if record is not None else student_meta.display_name(student_id)

    def _canonical_tactical_deck_or_error(self, deck: TacticalDeck, label: str) -> tuple[TacticalDeck, str]:
        errors: list[str] = []

        def _is_empty_token(value: str) -> bool:
            key = self._tactical_import_key(value)
            return key in {"", "-", "?", "unknown", "none", "null", "na", "n/a", "알수없음", "미상"}

        def _resolve_slots(values: list[str], prefix: str, expected_class: str, expected_label: str) -> list[str]:
            resolved: list[str] = []
            for index, raw_name in enumerate(values, start=1):
                raw_name = str(raw_name or "").strip()
                if _is_empty_token(raw_name):
                    resolved.append("")
                    continue
                matches = self._tactical_student_ids_for_name(raw_name)
                if not matches:
                    errors.append(f"{label} {prefix}{index}: '{raw_name}' 학생을 인식할 수 없어 저장할 수 없습니다.")
                    resolved.append(raw_name)
                elif len(matches) > 1:
                    names = ", ".join(self._tactical_student_display_name(student_id) for student_id in matches[:6])
                    suffix = "..." if len(matches) > 6 else ""
                    errors.append(f"{label} {prefix}{index}: '{raw_name}' 중복 태그입니다. ({names}{suffix})")
                    resolved.append(raw_name)
                else:
                    student_id = matches[0]
                    if student_meta.combat_class(student_id) != expected_class:
                        errors.append(f"{label} {prefix}{index}: '{self._tactical_student_display_name(student_id)}'는 {expected_label} 자리에 배치할 수 없습니다.")
                    resolved.append(self._tactical_student_display_name(student_id))
            return resolved

        canonical = TacticalDeck(
            strikers=_resolve_slots(deck.strikers[:TACTICAL_STRIKER_SLOTS], "S", "striker", "스트라이커"),
            supports=_resolve_slots(deck.supports[:TACTICAL_SUPPORT_SLOTS], "SP", "special", "스페셜"),
        )
        return canonical, "\n".join(errors)

    def _canonical_tactical_search_deck_or_error(self, deck: TacticalDeck, label: str) -> tuple[TacticalDeck, str]:
        errors: list[str] = []

        def _resolve_slots(values: list[str], prefix: str, expected_class: str, expected_label: str) -> list[str]:
            resolved: list[str] = []
            for index, raw_name in enumerate(values, start=1):
                raw_name = str(raw_name or "").strip()
                if not raw_name:
                    resolved.append("")
                    continue
                if raw_name == "*":
                    resolved.append("*")
                    continue
                matches = self._tactical_student_ids_for_name(raw_name)
                if not matches:
                    errors.append(f"{label} {prefix}{index}: '{raw_name}' 학생을 인식할 수 없습니다.")
                    resolved.append(raw_name)
                elif len(matches) > 1:
                    names = ", ".join(self._tactical_student_display_name(student_id) for student_id in matches[:6])
                    suffix = "..." if len(matches) > 6 else ""
                    errors.append(f"{label} {prefix}{index}: '{raw_name}' 중복 태그입니다. ({names}{suffix})")
                    resolved.append(raw_name)
                else:
                    student_id = matches[0]
                    if student_meta.combat_class(student_id) != expected_class:
                        errors.append(f"{label} {prefix}{index}: '{self._tactical_student_display_name(student_id)}'는 {expected_label} 자리에 배치할 수 없습니다.")
                    resolved.append(self._tactical_student_display_name(student_id))
            return resolved

        canonical = TacticalDeck(
            strikers=_resolve_slots(deck.strikers[:TACTICAL_STRIKER_SLOTS], "S", "striker", "스트라이커"),
            supports=_resolve_slots(deck.supports[:TACTICAL_SUPPORT_SLOTS], "SP", "special", "스페셜"),
        )
        return canonical, "\n".join(errors)

    def _tactical_student_id_for_name(self, name: str) -> str | None:
        matches = self._tactical_student_ids_for_name(name)
        return matches[0] if len(matches) == 1 else None

    def _tactical_portrait_pixmap(self, name: str, size: int) -> QPixmap:
        student_id = self._tactical_student_id_for_name(name)
        if not student_id:
            return QPixmap()
        source = ensure_thumbnail(student_id, size, size)
        if source is None or not source.exists():
            return QPixmap()
        pixmap = QPixmap(str(source))
        return pixmap if not pixmap.isNull() else QPixmap()

    def _build_tactical_deck_editor(self, title: str) -> tuple[QWidget, TacticalDeckEditor]:
        editor = TacticalDeckEditor(
            title,
            card_asset=self._student_card_asset,
            ui_scale=self._ui_scale,
            icon_provider=self._tactical_portrait_pixmap,
            deck_parser=self._parse_tactical_deck_template,
        )
        return editor, editor

    def _deck_from_tactical_inputs(self, inputs) -> TacticalDeck:
        if isinstance(inputs, TacticalDeckEditor):
            return inputs.deck()
        return TacticalDeck(
            strikers=[edit.text().strip() for edit in inputs.get("strikers", []) if edit.text().strip()],
            supports=[edit.text().strip() for edit in inputs.get("supports", []) if edit.text().strip()],
        )

    def _set_tactical_deck_inputs(self, inputs, deck: TacticalDeck) -> None:
        if isinstance(inputs, TacticalDeckEditor):
            inputs.setDeck(deck)
            return
        for edits, values in ((inputs.get("strikers", []), deck.strikers), (inputs.get("supports", []), deck.supports)):
            for index, edit in enumerate(edits):
                edit.setText(values[index] if index < len(values) else "")

    def _clear_tactical_deck_inputs(self, inputs) -> None:
        if isinstance(inputs, TacticalDeckEditor):
            inputs.clearDeck()
            return
        for edit in inputs.get("strikers", []) + inputs.get("supports", []):
            edit.clear()

    def _save_tactical_data(self) -> None:
        self._show_busy_overlay()
        try:
            save_tactical_challenge(self._tactical_path, self._tactical_data, sync_matches=False)
            self._storage_mtimes = self._snapshot_storage_mtimes()
        finally:
            self._hide_busy_overlay()

    def _save_tactical_metadata(self) -> None:
        self._show_busy_overlay()
        try:
            save_tactical_metadata(
                self._tactical_path,
                season=self._tactical_data.season,
                abbreviations=self._tactical_data.abbreviations,
                special_abbreviations=self._tactical_data.special_abbreviations,
            )
            self._storage_mtimes = self._snapshot_storage_mtimes()
        finally:
            self._hide_busy_overlay()

    def _save_tactical_match(self) -> None:
        if self._tactical_match_panels:
            self._save_tactical_match_panel(self._tactical_match_panels[0])

    def _save_tactical_jokbo(self) -> None:
        if not self._tactical_match_panels:
            return
        panel = self._tactical_match_panels[0]
        self._set_tactical_panel_mode(panel, "jokbo")
        self._save_tactical_match_panel(panel)

    def _clear_tactical_match_form(self) -> None:
        for panel in self._tactical_match_panels:
            self._clear_tactical_match_panel(panel)

    def _copy_tactical_match_defense_to_jokbo(self) -> None:
        deck = TacticalDeck()
        for panel in self._tactical_match_panels:
            candidate = self._deck_from_tactical_inputs(panel["defense"])
            if candidate.strikers or candidate.supports:
                deck = candidate
                break
        if self._tactical_match_panels:
            self._set_tactical_deck_inputs(self._tactical_match_panels[0]["defense"], deck)
        self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, deck)

    def _selected_tactical_match(self) -> TacticalMatch | None:
        selected_id = self._tactical_selected_match_id
        if not selected_id and hasattr(self, "_tactical_match_list"):
            item = self._tactical_match_list.currentItem()
            selected_id = str(item.data(Qt.UserRole) or "") if item is not None else ""
        if not selected_id:
            return None
        return get_tactical_match(self._tactical_path, selected_id)

    def _tactical_date_label(self, match: TacticalMatch) -> str:
        return match.date or "날짜 없음"

    def _copy_selected_tactical_defense_to_search(self) -> None:
        match = self._selected_tactical_match()
        if match is None:
            return
        deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
        self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, deck)
        self._refresh_tactical_jokbo_results()

    def _refresh_tactical_tab(self) -> None:
        if not hasattr(self, "_tactical_match_list"):
            return
        if hasattr(self, "_tactical_season") and not self._tactical_season.hasFocus():
            previous = self._tactical_season.blockSignals(True)
            try:
                self._tactical_season.setText(self._tactical_data.season or "")
            finally:
                self._tactical_season.blockSignals(previous)
        self._refresh_tactical_match_list()
        self._refresh_tactical_opponent_report()
        self._refresh_tactical_jokbo_results()

    def _blank_tactical_opponent_matches(self) -> list[TacticalMatch]:
        total = tactical_match_count(self._tactical_path, "")
        matches = query_tactical_matches(self._tactical_path, "", limit=max(total, self._tactical_match_page_size))
        return [match for match in matches if not match.opponent.strip()]

    def _edit_tactical_opponents_batch(self) -> None:
        matches = self._blank_tactical_opponent_matches()
        if not matches:
            QMessageBox.information(self, "BA Planner", "상대 이름이 비어 있는 전술대항전 기록이 없습니다.")
            return
        self._open_tactical_opponents_batch(matches)

    def _open_tactical_opponents_batch(self, matches: list[TacticalMatch], panel: dict | None = None) -> None:
        rows = [match for match in matches if match is not None]
        if not rows:
            return
        dialog = TacticalOpponentBatchDialog(self, rows, self._ui_scale)
        if dialog.exec() != QDialog.Accepted:
            return
        updated = dialog.edited_matches()
        if not updated:
            return
        upsert_tactical_matches(self._tactical_path, updated)
        self._storage_mtimes = self._snapshot_storage_mtimes()
        self._tactical_match_loaded_count = max(self._tactical_match_loaded_count, self._tactical_match_page_size)
        if updated:
            self._tactical_selected_match_id = updated[-1].id
        self._refresh_tactical_match_list()
        self._refresh_tactical_opponent_report()
        self._refresh_tactical_jokbo_results()
        self._set_tactical_status(f"상대 이름 {len(updated)}건을 저장했습니다.", panel=panel)

    def _reset_tactical_match_list(self) -> None:
        self._tactical_match_loaded_count = self._tactical_match_page_size
        self._refresh_tactical_match_list()

    def _load_more_tactical_matches(self) -> None:
        self._show_busy_overlay("불러오는 중...")
        try:
            self._tactical_match_loaded_count += self._tactical_match_page_size
            self._refresh_tactical_match_list()
        finally:
            self._hide_busy_overlay()

    def _refresh_tactical_match_list(self) -> None:
        query = self._tactical_match_search.text() if hasattr(self, "_tactical_match_search") else ""
        if query != self._tactical_match_query:
            self._tactical_match_query = query
            self._tactical_match_loaded_count = self._tactical_match_page_size
        total_filtered = tactical_match_count(self._tactical_path, query)
        matches = query_tactical_matches(self._tactical_path, query, limit=self._tactical_match_loaded_count)
        current_id = self._tactical_selected_match_id
        editing_ids = self._tactical_match_editing_ids()
        self._tactical_match_list.blockSignals(True)
        self._tactical_match_list.clear()
        for match in matches:
            result_text = "승" if match.result == "win" else "패"
            season_text = f" · {match.season}" if match.season else ""
            source_label = self._tactical_match_source_label(match.source)
            source_text = f" · {source_label}" if source_label else ""
            is_editing = match.id in editing_ids
            item = QListWidgetItem()
            item.setData(Qt.UserRole, match.id)
            item.setToolTip(self._tactical_match_tooltip(match))
            self._tactical_match_list.addItem(item)
            row = QFrame()
            row.setObjectName("planBand")
            if is_editing:
                row.setStyleSheet(
                    f"QFrame#planBand {{ border: 2px solid #ffb5f0; background: {_mix_hex(ACCENT_SOFT, '#ffffff', 0.08)}; }}"
                )
            row_layout = QVBoxLayout(row)
            row_layout.setContentsMargins(scale_px(8, self._ui_scale), scale_px(7, self._ui_scale), scale_px(8, self._ui_scale), scale_px(7, self._ui_scale))
            top_row = QHBoxLayout()
            text = QLabel(f"{self._tactical_date_label(match)}{season_text}{source_text}  [{result_text}] {match.opponent}")
            text.setWordWrap(True)
            text.setObjectName("sectionTitle")
            top_row.addWidget(text, 1)
            if is_editing:
                editing_badge = QLabel("수정 중")
                editing_badge.setStyleSheet(
                    "color: #ffb5f0; font-weight: 900; padding: 2px 6px; border: 1px solid #ffb5f0; border-radius: 4px;"
                )
                top_row.addWidget(editing_badge)
            row_layout.addLayout(top_row)
            deck_row = QHBoxLayout()
            deck_row.setContentsMargins(0, 0, 0, 0)
            deck_row.setSpacing(scale_px(6, self._ui_scale))
            attack_deck = match.my_attack if (match.my_attack.strikers or match.my_attack.supports) else match.opponent_attack
            defense_deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
            attack_label = "ATK" if (match.my_attack.strikers or match.my_attack.supports) else "OP ATK"
            defense_label = "DEF" if (match.opponent_defense.strikers or match.opponent_defense.supports) else "MY DEF"
            attack_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
            attack_preview.setDeck(attack_deck)
            defense_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
            defense_preview.setDeck(defense_deck)
            deck_row.addWidget(QLabel(attack_label))
            deck_row.addWidget(attack_preview)
            deck_row.addStretch(1)
            deck_row.addWidget(QLabel(defense_label))
            deck_row.addWidget(defense_preview)
            row_layout.addLayout(deck_row)
            hint = row.sizeHint()
            hint.setHeight(hint.height() + scale_px(8, self._ui_scale))
            item.setSizeHint(hint)
            self._tactical_match_list.setItemWidget(item, row)
            if current_id and match.id == current_id:
                self._tactical_match_list.setCurrentItem(item)
        self._tactical_match_list.blockSignals(False)
        summary = tactical_match_summary(self._tactical_path, self._tactical_date.text().strip())
        self._tactical_match_summary.setText(
            f"오늘 {summary['today']}/5 · 전체 {summary['wins']}승 {summary['losses']}패 · 표시 {len(matches)}/{total_filtered}"
        )
        if hasattr(self, "_tactical_match_load_more_button"):
            self._tactical_match_load_more_button.setVisible(len(matches) < total_filtered)
        self._set_tactical_match_detail(self._selected_tactical_match())

    def _delete_tactical_match(self, match_id: str) -> None:
        self._show_busy_overlay("삭제 중...")
        try:
            if not delete_tactical_match(self._tactical_path, match_id):
                return
            if self._tactical_selected_match_id == match_id:
                self._tactical_selected_match_id = None
            for panel in getattr(self, "_tactical_match_panels", []):
                if panel.get("editing_match_id") == match_id:
                    self._clear_tactical_match_panel(panel)
            self._storage_mtimes = self._snapshot_storage_mtimes()
            self._refresh_tactical_match_list()
        finally:
            self._hide_busy_overlay()
        self._set_tactical_status("전적을 삭제했습니다.")

    def _selected_tactical_match_decks(self) -> tuple[TacticalDeck, TacticalDeck] | None:
        match = self._selected_tactical_match()
        if match is None:
            return None
        attack_deck = match.my_attack if (match.my_attack.strikers or match.my_attack.supports) else match.opponent_attack
        defense_deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
        return attack_deck, defense_deck

    def _copy_selected_tactical_match_attack(self) -> None:
        decks = self._selected_tactical_match_decks()
        if decks is not None:
            self._copy_tactical_deck_template(decks[0])

    def _copy_selected_tactical_match_defense(self) -> None:
        decks = self._selected_tactical_match_decks()
        if decks is not None:
            self._copy_tactical_deck_template(decks[1])

    def _edit_selected_tactical_match(self) -> None:
        match = self._selected_tactical_match()
        if match is None:
            self._set_tactical_status("수정할 전적을 먼저 선택해 주세요.", error=True)
            return
        if not self._tactical_match_panels:
            return
        self._load_tactical_match_into_panel(self._tactical_match_panels[0], match)

    def _delete_selected_tactical_match(self) -> None:
        match = self._selected_tactical_match()
        if match is not None:
            self._delete_tactical_match(match.id)

    def _tactical_match_tooltip(self, match: TacticalMatch) -> str:
        lines = [
            f"{self._tactical_date_label(match)} {match.season} {match.opponent}".strip(),
            f"내 공격덱: {deck_label(match.my_attack)}",
            f"상대 방어덱: {deck_label(match.opponent_defense)}",
        ]
        source_label = self._tactical_match_source_label(match.source)
        if source_label:
            lines.insert(1, f"출처: {source_label}")
        if deck_label(match.my_defense, empty=""):
            lines.append(f"내 방어덱: {deck_label(match.my_defense)}")
        if deck_label(match.opponent_attack, empty=""):
            lines.append(f"상대 공격덱: {deck_label(match.opponent_attack)}")
        if match.notes:
            lines.append(match.notes)
        return "\n".join(lines)

    def _on_tactical_match_selected(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None) -> None:
        self._tactical_selected_match_id = str(current.data(Qt.UserRole) or "") if current is not None else None
        match = self._selected_tactical_match()
        if match is not None:
            self._tactical_opponent_search.setText(match.opponent)
            deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
            self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, deck)
        self._set_tactical_match_detail(match)
        self._refresh_tactical_opponent_report()
        self._refresh_tactical_jokbo_results()

    def _set_tactical_match_detail(self, match: TacticalMatch | None) -> None:
        if not hasattr(self, "_tactical_match_detail"):
            return
        if match is None:
            self._tactical_match_detail.setText("선택한 전적의 상세 정보가 여기에 표시됩니다.")
            return
        result_text = "승리" if match.result == "win" else "패배"
        header_parts = [self._tactical_date_label(match), match.season or "-"]
        source_label = self._tactical_match_source_label(match.source)
        if source_label:
            header_parts.append(source_label)
        header_parts.extend([match.opponent, result_text])
        lines = [
            " · ".join(header_parts),
            f"내 공격덱: {deck_label(match.my_attack)}",
            f"상대 방어덱: {deck_label(match.opponent_defense)}",
        ]
        if deck_label(match.my_defense, empty=""):
            lines.append(f"내 방어덱: {deck_label(match.my_defense)}")
        if deck_label(match.opponent_attack, empty=""):
            lines.append(f"상대 공격덱: {deck_label(match.opponent_attack)}")
        if match.notes:
            lines.append(f"메모: {match.notes}")
        self._tactical_match_detail.setText("\n".join(lines))

    def _refresh_tactical_opponent_report(self) -> None:
        if not hasattr(self, "_tactical_opponent_summary"):
            return
        opponent = self._tactical_opponent_search.text().strip()
        if not opponent:
            match = self._selected_tactical_match()
            opponent = match.opponent if match is not None else ""
        if not opponent:
            self._tactical_opponent_summary.setText("상대를 검색하거나 전적을 선택하면 상대전적과 최근 방어덱이 표시됩니다.")
            self._tactical_opponent_top_list.clear()
            return
        report = opponent_report_from_storage(self._tactical_path, opponent)
        total = len(report["matches"])
        self._tactical_opponent_top_list.clear()
        if total == 0:
            self._tactical_opponent_summary.setText(f"{opponent}: 기록이 없습니다.")
            return
        self._tactical_opponent_summary.setText(
            f"{opponent}: {report['wins']}승 {report['losses']}패 ({report['win_rate']:.1f}%)"
        )
        if deck_label(report["recent_defense"], empty=""):
            self._add_tactical_opponent_deck_row(
                title="최근 방어덱",
                defense=report["recent_defense"],
                attack=report["recent_attack"],
            )
        for index, entry in enumerate(report["top_defenses"], start=1):
            self._add_tactical_opponent_deck_row(
                title=f"TOP {index} · {entry['count']}회 · {entry['wins']}승 {entry['losses']}패 ({entry['win_rate']:.1f}%)",
                defense=entry["deck"],
                attack=entry["attack"],
            )
        if not report["top_defenses"]:
            self._tactical_opponent_top_list.addItem("방어덱 정보가 있는 전적이 없습니다.")

    def _add_tactical_opponent_deck_row(self, *, title: str, defense: TacticalDeck, attack: TacticalDeck) -> None:
        item = QListWidgetItem()
        item.setToolTip(f"공격: {deck_label(attack)}\n방어: {deck_label(defense)}")
        row = QFrame()
        row.setObjectName("planBand")
        layout = QVBoxLayout(row)
        layout.setContentsMargins(scale_px(8, self._ui_scale), scale_px(7, self._ui_scale), scale_px(8, self._ui_scale), scale_px(7, self._ui_scale))
        label = QLabel(title)
        label.setObjectName("sectionTitle")
        label.setWordWrap(True)
        layout.addWidget(label)
        deck_row = QHBoxLayout()
        deck_row.setContentsMargins(0, 0, 0, 0)
        deck_row.setSpacing(scale_px(6, self._ui_scale))
        attack_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
        attack_preview.setDeck(attack)
        defense_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
        defense_preview.setDeck(defense)
        deck_row.addWidget(QLabel("ATK"))
        deck_row.addWidget(attack_preview)
        deck_row.addStretch(1)
        deck_row.addWidget(QLabel("DEF"))
        deck_row.addWidget(defense_preview)
        layout.addLayout(deck_row)
        self._tactical_opponent_top_list.addItem(item)
        hint = row.sizeHint()
        hint.setHeight(hint.height() + scale_px(8, self._ui_scale))
        item.setSizeHint(hint)
        self._tactical_opponent_top_list.setItemWidget(item, row)

    def _refresh_tactical_jokbo_results(self) -> None:
        if not hasattr(self, "_tactical_jokbo_results"):
            return
        defense = self._deck_from_tactical_inputs(self._tactical_jokbo_search_inputs)
        if not any(defense.strikers) and not any(defense.supports):
            self._tactical_jokbo_results.clear()
            self._tactical_jokbo_results.addItem("방어덱을 입력하거나 전적을 선택하면 족보를 검색합니다.")
            return
        defense, error = self._canonical_tactical_search_deck_or_error(defense, "족보 검색 방어덱")
        if error:
            self._tactical_jokbo_results.clear()
            item = QListWidgetItem(self._compact_tactical_message(error, max_lines=2, max_chars=130))
            item.setToolTip(error)
            self._tactical_jokbo_results.addItem(item)
            self._set_tactical_status(error, error=True)
            return
        self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, defense)
        results = search_jokbo_from_storage(self._tactical_path, self._tactical_data, defense)
        self._tactical_jokbo_results.clear()
        for result in results["manual"]:
            entry = result["entry"]
            self._add_tactical_jokbo_result_row(
                title=f"족보 · {result['wins']}승 {result['losses']}패 ({result['win_rate']:.1f}%)",
                defense=entry.defense,
                attack=entry.attack,
                note=entry.notes or "-",
            )
        for result in results["observed"]:
            self._add_tactical_jokbo_result_row(
                title=f"전적 기반 · {result['wins']}승 {result['losses']}패 ({result['win_rate']:.1f}%)",
                defense=result["defense"],
                attack=result["attack"],
                note="",
            )
        if self._tactical_jokbo_results.count() == 0:
            self._tactical_jokbo_results.addItem("일치하는 족보나 전적 기반 공격덱이 없습니다.")

    def _add_tactical_jokbo_result_row(self, *, title: str, defense: TacticalDeck, attack: TacticalDeck, note: str) -> None:
        item = QListWidgetItem()
        item.setData(Qt.UserRole, deck_template(defense))
        item.setData(Qt.UserRole + 1, deck_template(attack))
        row = QFrame()
        row.setObjectName("planBand")
        layout = QVBoxLayout(row)
        layout.setContentsMargins(scale_px(8, self._ui_scale), scale_px(7, self._ui_scale), scale_px(8, self._ui_scale), scale_px(7, self._ui_scale))
        label = QLabel(title)
        label.setObjectName("sectionTitle")
        if note:
            label.setToolTip(note)
        layout.addWidget(label)
        decks = QHBoxLayout()
        decks.setContentsMargins(0, 0, 0, 0)
        decks.setSpacing(scale_px(6, self._ui_scale))
        defense_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
        defense_preview.setDeck(defense)
        attack_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
        attack_preview.setDeck(attack)
        decks.addWidget(QLabel("ATK"))
        decks.addWidget(attack_preview)
        decks.addStretch(1)
        decks.addWidget(QLabel("DEF"))
        decks.addWidget(defense_preview)
        layout.addLayout(decks)
        self._tactical_jokbo_results.addItem(item)
        hint = row.sizeHint()
        hint.setHeight(hint.height() + scale_px(8, self._ui_scale))
        item.setSizeHint(hint)
        self._tactical_jokbo_results.setItemWidget(item, row)

    def _selected_tactical_jokbo_decks(self) -> tuple[TacticalDeck, TacticalDeck] | None:
        if not hasattr(self, "_tactical_jokbo_results"):
            return None
        item = self._tactical_jokbo_results.currentItem()
        if item is None:
            return None
        defense_text = str(item.data(Qt.UserRole) or "")
        attack_text = str(item.data(Qt.UserRole + 1) or "")
        if not defense_text and not attack_text:
            return None
        return parse_deck_template(defense_text), parse_deck_template(attack_text)

    def _copy_selected_tactical_jokbo_defense(self) -> None:
        decks = self._selected_tactical_jokbo_decks()
        if decks is not None:
            self._copy_tactical_deck_template(decks[0])

    def _copy_selected_tactical_jokbo_attack(self) -> None:
        decks = self._selected_tactical_jokbo_decks()
        if decks is not None:
            self._copy_tactical_deck_template(decks[1])

    def _copy_tactical_deck_template(self, deck: TacticalDeck) -> None:
        QApplication.clipboard().setText(deck_input_template(deck))
        if hasattr(self, "_tactical_status"):
            self._set_tactical_status("덱 템플릿을 복사했습니다.")

    def _tactical_match_editing_ids(self) -> set[str]:
        return {
            str(panel.get("editing_match_id") or "")
            for panel in getattr(self, "_tactical_match_panels", [])
            if str(panel.get("editing_match_id") or "")
        }

    def _tactical_match_source_label(self, source: str) -> str:
        source = str(source or "").strip()
        return "" if source in {"", "내 기록", "스크린샷"} else source

    def _build_stats_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(12, self._ui_scale))

        scroll = QScrollArea()
        scroll.setObjectName("sectionScrollArea")
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        host = QWidget()
        host_layout = QVBoxLayout(host)
        host_layout.setContentsMargins(0, 0, 0, 0)
        host_layout.setSpacing(scale_px(12, self._ui_scale))

        self._stats_summary_host = QWidget()
        self._stats_summary_cards = QGridLayout(self._stats_summary_host)
        self._stats_summary_cards.setContentsMargins(0, 0, 0, 0)
        self._stats_summary_cards.setHorizontalSpacing(scale_px(12, self._ui_scale))
        self._stats_summary_cards.setVerticalSpacing(scale_px(12, self._ui_scale))
        host_layout.addWidget(self._stats_summary_host)

        middle_row = QHBoxLayout()
        middle_row.setContentsMargins(0, 0, 0, 0)
        middle_row.setSpacing(scale_px(12, self._ui_scale))

        sunburst_panel = QFrame()
        sunburst_panel.setObjectName("planSectionPanel")
        sunburst_layout = QVBoxLayout(sunburst_panel)
        sunburst_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        sunburst_layout.setSpacing(scale_px(12, self._ui_scale))

        sunburst_header = QHBoxLayout()
        sunburst_header.setContentsMargins(0, 0, 0, 0)
        sunburst_header.setSpacing(scale_px(10, self._ui_scale))
        sunburst_title = QLabel("분포 탐색")
        sunburst_title.setObjectName("sectionTitle")
        sunburst_header.addWidget(sunburst_title)
        sunburst_header.addStretch(1)
        self._stats_sunburst_mode = InventorySortDropdownButton()
        self._stats_sunburst_mode.addItem("학교 > 역할 > 공격 타입", "collection_school_role_attack")
        self._stats_sunburst_mode.addItem("Striker/Special > 역할 > 포지션", "collection_class_role_position")
        self._stats_sunburst_mode.addItem("공격 타입 > 방어 타입 > 역할", "collection_attack_defense_role")
        self._stats_sunburst_mode.addItem("직군 > 육성도", "role_training")
        self._stats_sunburst_mode.addItem("필요 재화 > 세부 재화 > 티어/계열", "plan_required")
        self._stats_sunburst_mode.addItem("부족 재화 > 세부 재화 > 영향 학생", "plan_shortage")
        self._stats_sunburst_mode.addItem("기능군 > 태그 > 학생", "skill_function")
        self._stats_sunburst_mode.setCurrentIndex(4)
        self._stats_sunburst_mode.modeChanged.connect(lambda *_: self._stats_refresh_sunburst_mode())
        sunburst_header.addWidget(self._stats_sunburst_mode, 0, Qt.AlignRight)
        self._stats_sunburst_value_mode = InventorySortDropdownButton()
        self._stats_sunburst_value_mode.modeChanged.connect(lambda *_: self._stats_refresh_sunburst_mode())
        sunburst_header.addWidget(self._stats_sunburst_value_mode, 0, Qt.AlignRight)
        nav_buttons = QWidget()
        nav_buttons.setObjectName("planTransparent")
        nav_layout = QHBoxLayout(nav_buttons)
        nav_layout.setContentsMargins(0, 0, 0, 0)
        nav_layout.setSpacing(scale_px(6, self._ui_scale))
        self._stats_sunburst_root_button = QPushButton("전체")
        self._stats_sunburst_root_button.clicked.connect(self._stats_reset_sunburst_root)
        nav_layout.addWidget(self._stats_sunburst_root_button)
        self._stats_sunburst_back_button = QPushButton("뒤로")
        self._stats_sunburst_back_button.clicked.connect(self._stats_sunburst_back)
        nav_layout.addWidget(self._stats_sunburst_back_button)
        self._stats_sunburst_clear_button = QPushButton("선택 해제")
        self._stats_sunburst_clear_button.clicked.connect(self._stats_clear_sunburst_selection)
        nav_layout.addWidget(self._stats_sunburst_clear_button)
        sunburst_header.addWidget(nav_buttons, 0, Qt.AlignRight)
        sunburst_layout.addLayout(sunburst_header)
        self._stats_sunburst_breadcrumb_host = QWidget()
        self._stats_sunburst_breadcrumb_layout = QHBoxLayout(self._stats_sunburst_breadcrumb_host)
        self._stats_sunburst_breadcrumb_layout.setContentsMargins(0, 0, 0, 0)
        self._stats_sunburst_breadcrumb_layout.setSpacing(scale_px(6, self._ui_scale))
        self._stats_update_sunburst_value_options()

        chart_and_legend = QHBoxLayout()
        chart_and_legend.setContentsMargins(0, 0, 0, 0)
        chart_and_legend.setSpacing(scale_px(12, self._ui_scale))
        self._stats_sunburst = SunburstWidget(self._ui_scale)
        self._stats_sunburst.segmentSelected.connect(self._on_stats_sunburst_segment_selected)
        chart_and_legend.addWidget(self._stats_sunburst, 1)
        legend_panel = QFrame()
        legend_panel.setObjectName("planBand")
        legend_panel.setFixedWidth(scale_px(210, self._ui_scale))
        legend_layout = QVBoxLayout(legend_panel)
        legend_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        legend_layout.setSpacing(scale_px(6, self._ui_scale))
        legend_title = QLabel("색상 경로")
        legend_title.setObjectName("detailSectionTitle")
        legend_layout.addWidget(legend_title)
        self._stats_sunburst_legend_layout = QVBoxLayout()
        self._stats_sunburst_legend_layout.setContentsMargins(0, 0, 0, 0)
        self._stats_sunburst_legend_layout.setSpacing(scale_px(4, self._ui_scale))
        legend_layout.addLayout(self._stats_sunburst_legend_layout)
        legend_layout.addStretch(1)
        chart_and_legend.addWidget(legend_panel, 0)
        sunburst_layout.addLayout(chart_and_legend, 1)
        self._stats_summary_line = QLabel("")
        self._stats_summary_line.setObjectName("filterSummary")
        sunburst_layout.addWidget(self._stats_summary_line)
        middle_row.addWidget(sunburst_panel, 3)

        detail_panel = QFrame()
        detail_panel.setObjectName("planSectionPanel")
        detail_layout = QVBoxLayout(detail_panel)
        detail_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        detail_layout.setSpacing(scale_px(8, self._ui_scale))
        selected_title = QLabel("선택 상세 정보")
        selected_title.setObjectName("sectionTitle")
        detail_layout.addWidget(selected_title)

        path_caption = QLabel("선택 경로")
        path_caption.setObjectName("detailSub")
        detail_layout.addWidget(path_caption)
        self._stats_detail_path_label = QLabel("L0: 전체")
        self._stats_detail_path_label.setObjectName("filterSummary")
        detail_layout.addWidget(self._stats_detail_path_label, 0, Qt.AlignLeft)

        divider = QFrame()
        divider.setFrameShape(QFrame.HLine)
        divider.setObjectName("sectionDivider")
        detail_layout.addWidget(divider)

        title_row = QHBoxLayout()
        title_row.setContentsMargins(0, 0, 0, 0)
        title_stack = QVBoxLayout()
        title_stack.setContentsMargins(0, 0, 0, 0)
        title_stack.setSpacing(0)
        self._stats_detail_name_label = QLabel("전체")
        self._stats_detail_name_label.setObjectName("detailSectionTitle")
        self._stats_detail_level_label = QLabel("Level 0")
        self._stats_detail_level_label.setObjectName("detailSub")
        title_stack.addWidget(self._stats_detail_name_label)
        title_stack.addWidget(self._stats_detail_level_label)
        title_row.addLayout(title_stack, 1)
        self._stats_detail_total_label = QLabel("0")
        self._stats_detail_total_label.setObjectName("metricValue")
        self._stats_detail_total_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        title_row.addWidget(self._stats_detail_total_label, 0)
        detail_layout.addLayout(title_row)

        metric_row = QHBoxLayout()
        metric_row.setContentsMargins(0, 0, 0, 0)
        metric_row.setSpacing(scale_px(8, self._ui_scale))
        count_card = QFrame()
        count_card.setObjectName("statPanel")
        count_layout = QVBoxLayout(count_card)
        count_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(8, self._ui_scale), scale_px(10, self._ui_scale), scale_px(8, self._ui_scale))
        count_title = QLabel("학생 수")
        count_title.setObjectName("detailSub")
        self._stats_detail_metric_count_label = QLabel("0")
        self._stats_detail_metric_count_label.setObjectName("kpiValueSub")
        count_layout.addWidget(count_title)
        count_layout.addWidget(self._stats_detail_metric_count_label)
        metric_row.addWidget(count_card, 1)
        percent_card = QFrame()
        percent_card.setObjectName("statPanel")
        percent_layout = QVBoxLayout(percent_card)
        percent_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(8, self._ui_scale), scale_px(10, self._ui_scale), scale_px(8, self._ui_scale))
        percent_title = QLabel("비율")
        percent_title.setObjectName("detailSub")
        self._stats_detail_metric_percent_label = QLabel("0.0%")
        self._stats_detail_metric_percent_label.setObjectName("kpiValueSub")
        percent_layout.addWidget(percent_title)
        percent_layout.addWidget(self._stats_detail_metric_percent_label)
        metric_row.addWidget(percent_card, 1)
        detail_layout.addLayout(metric_row)

        owned_label_row = QHBoxLayout()
        owned_label_row.setContentsMargins(0, 0, 0, 0)
        owned_title = QLabel("보유율")
        owned_title.setObjectName("detailSub")
        owned_label_row.addWidget(owned_title)
        self._stats_detail_owned_bar_label = QLabel("0.0%")
        self._stats_detail_owned_bar_label.setObjectName("detailSub")
        self._stats_detail_owned_bar_label.setAlignment(Qt.AlignRight)
        owned_label_row.addWidget(self._stats_detail_owned_bar_label)
        detail_layout.addLayout(owned_label_row)
        self._stats_detail_owned_bar = QProgressBar()
        self._stats_detail_owned_bar.setRange(0, 100)
        self._stats_detail_owned_bar.setTextVisible(False)
        self._stats_detail_owned_bar.setFixedHeight(scale_px(8, self._ui_scale))
        detail_layout.addWidget(self._stats_detail_owned_bar)

        chip_row = QHBoxLayout()
        chip_row.setContentsMargins(0, 0, 0, 0)
        chip_row.setSpacing(scale_px(8, self._ui_scale))
        self._stats_detail_owned_label = QLabel("보유\n0")
        self._stats_detail_unowned_label = QLabel("미보유\n0")
        self._stats_detail_planned_label = QLabel("계획\n0")
        for chip in (self._stats_detail_owned_label, self._stats_detail_unowned_label, self._stats_detail_planned_label):
            chip.setObjectName("filterSummary")
            chip.setAlignment(Qt.AlignCenter)
            chip.setMinimumHeight(scale_px(48, self._ui_scale))
            chip_row.addWidget(chip, 1)
        detail_layout.addLayout(chip_row)

        self._stats_sunburst_top_detail = QLabel("")
        self._stats_sunburst_top_detail.hide()
        self._stats_sunburst_detail = QLabel("")
        self._stats_sunburst_detail.hide()
        detail_layout.addStretch(1)
        middle_row.addWidget(detail_panel, 2)
        host_layout.addLayout(middle_row, 1)

        self._stats_chart_tabs = QTabBar()
        self._stats_chart_tabs.setObjectName("inventorySubTabBar")
        for label, value in (
            ("컬렉션 구성", "collection"),
            ("육성 상태", "growth"),
            ("계획 진행", "plan"),
            ("재화/인벤토리", "resource"),
            ("스킬/기능 태그", "skill"),
        ):
            index = self._stats_chart_tabs.addTab(label)
            self._stats_chart_tabs.setTabData(index, value)
        self._stats_chart_tabs.currentChanged.connect(self._stats_chart_tab_changed)
        host_layout.addWidget(self._stats_chart_tabs)
        self._stats_chart_tabs.hide()

        cards_wrap = QWidget()
        self._stats_cards_layout = QGridLayout(cards_wrap)
        self._stats_cards_layout.setContentsMargins(0, 0, 0, 0)
        self._stats_cards_layout.setHorizontalSpacing(scale_px(12, self._ui_scale))
        self._stats_cards_layout.setVerticalSpacing(scale_px(12, self._ui_scale))
        self._stats_cards_layout.setColumnStretch(0, 1)
        host_layout.addWidget(cards_wrap)
        cards_wrap.hide()
        scroll.setWidget(host)
        layout.addWidget(scroll, 1)

    def _build_plan_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(10, self._ui_scale))

        title = QLabel("계획 작업공간")
        title.setObjectName("title")
        header_layout.addWidget(title)

        summary = QLabel("필요할 때만 검색하고, 계획 학생은 학생 탭처럼 카드로 관리합니다.")
        summary.setObjectName("count")
        header_layout.addWidget(summary, 1)
        layout.addWidget(header)

        quick_add_panel = QFrame()
        self._plan_quick_add_panel = quick_add_panel
        quick_add_panel.setObjectName("planBand")
        quick_add_layout = QVBoxLayout(quick_add_panel)
        quick_add_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(12, self._ui_scale),
        )
        quick_add_layout.setSpacing(scale_px(8, self._ui_scale))

        quick_add_header = QHBoxLayout()
        quick_add_header.setContentsMargins(0, 0, 0, 0)
        quick_add_header.setSpacing(scale_px(10, self._ui_scale))
        title_add = QLabel("빠른 추가")
        title_add.setObjectName("sectionTitle")
        quick_add_header.addWidget(title_add)
        quick_add_note = QLabel("필요할 때만 학생 이름, ID, 태그로 검색하세요.")
        quick_add_note.setObjectName("count")
        quick_add_note.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        quick_add_header.addWidget(quick_add_note, 1)
        quick_add_layout.addLayout(quick_add_header)

        quick_add_row = QHBoxLayout()
        quick_add_row.setContentsMargins(0, 0, 0, 0)
        quick_add_row.setSpacing(scale_px(8, self._ui_scale))
        self._plan_search = LiveSearchLineEdit()
        self._plan_search.setPlaceholderText("학생 이름, ID, 태그 입력")
        self._plan_search.liveTextChanged.connect(self._schedule_plan_search_refresh)
        quick_add_row.addWidget(self._plan_search, 1)
        self._plan_add_button = QPushButton("추가")
        self._plan_add_button.clicked.connect(self._add_selected_student_to_plan)
        quick_add_row.addWidget(self._plan_add_button, 0, Qt.AlignVCenter)
        quick_add_layout.addLayout(quick_add_row)

        self._plan_search_card_by_id: dict[str, StudentCardWidget] = {}
        plan_search_width = max(scale_px(80, self._ui_scale), int(round(self._student_card_asset.base_size.width() * 0.5)))
        self._plan_search_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            drag_enabled=True,
            min_card_width=plan_search_width,
            fixed_card_width=True,
        )
        self._plan_search_grid.setObjectName("studentGrid")
        plan_search_grid_height = max(
            scale_px(150, self._ui_scale),
            int(round(plan_search_width / self._student_card_asset.aspect_ratio)) + scale_px(28, self._ui_scale),
        )
        plan_search_panel_vertical_margins = scale_px(20, self._ui_scale)
        self._plan_search_grid.setFixedHeight(plan_search_grid_height)
        self._plan_search_grid.setFrameShape(QFrame.NoFrame)
        self._plan_search_grid.setAutoFillBackground(False)
        self._plan_search_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._plan_search_grid.viewport().setAutoFillBackground(False)
        self._plan_search_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._plan_search_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._plan_search_grid.widget() is not None:
            self._plan_search_grid.widget().setAutoFillBackground(False)
            self._plan_search_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._plan_search_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._plan_search_grid, ui_scale=self._ui_scale)
        self._plan_search_grid.current_changed.connect(self._on_plan_search_card_changed)
        self._plan_search_grid.card_drag_moved.connect(self._on_plan_search_card_drag_moved)
        self._plan_search_grid.card_drag_finished.connect(self._on_plan_search_card_drag_finished)
        self._plan_search_grid.setVisible(False)
        self._plan_search_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        self._plan_search_grid_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self._plan_search_grid_panel.setFixedHeight(plan_search_grid_height + plan_search_panel_vertical_margins)
        self._plan_search_grid_panel.setVisible(False)
        plan_search_grid_panel_layout = QVBoxLayout(self._plan_search_grid_panel)
        plan_search_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        plan_search_grid_panel_layout.setSpacing(0)
        plan_search_grid_panel_layout.addWidget(self._plan_search_grid)
        quick_add_layout.addWidget(self._plan_search_grid_panel)

        self._plan_search_state = QLabel("학생 순서를 드래그해서 변경할 수 있으며, 학생 순서대로 인벤토리 탭에서 재화 우선 목표를 보여줍니다.")
        self._plan_search_state.setObjectName("filterSummary")
        self._plan_search_state.setWordWrap(True)
        quick_add_layout.addWidget(self._plan_search_state)

        splitter = QSplitter(Qt.Horizontal)
        splitter.setObjectName("sectionSplitter")
        splitter.setChildrenCollapsible(False)
        layout.addWidget(splitter, 1)

        plan_panel = QFrame()
        self._plan_panel = plan_panel
        plan_panel.setObjectName("planSectionPanel")
        plan_layout = QVBoxLayout(plan_panel)
        plan_layout.setContentsMargins(scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale))
        plan_layout.setSpacing(scale_px(10, self._ui_scale))

        plan_header = QHBoxLayout()
        plan_header.setContentsMargins(0, 0, 0, 0)
        plan_header.setSpacing(scale_px(10, self._ui_scale))
        title_plan = QLabel("계획 학생")
        title_plan.setObjectName("sectionTitle")
        plan_header.addWidget(title_plan)
        self._plan_count_label = QLabel("")
        self._plan_count_label.setObjectName("count")
        plan_header.addWidget(self._plan_count_label, 1, Qt.AlignRight)
        plan_layout.addLayout(plan_header)

        self._plan_empty_label = QLabel("아직 계획에 학생이 없습니다. 아래 빠른 추가에서 첫 학생을 추가하세요.")
        self._plan_empty_label.setObjectName("filterSummary")
        self._plan_empty_label.setWordWrap(True)
        plan_layout.addWidget(self._plan_empty_label)

        self._plan_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        plan_grid_layout = QVBoxLayout(self._plan_grid_panel)
        plan_grid_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        plan_grid_layout.setSpacing(0)

        self._plan_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            reorder_enabled=True,
            min_card_width=self._plan_grid_card_width,
            fixed_column_count=PLAN_GRID_COLUMNS,
        )
        self._plan_grid.setObjectName("studentGrid")
        self._plan_grid.setFrameShape(QFrame.NoFrame)
        self._plan_grid.setAutoFillBackground(False)
        self._plan_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._plan_grid.viewport().setAutoFillBackground(False)
        self._plan_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._plan_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._plan_grid.widget() is not None:
            self._plan_grid.widget().setAutoFillBackground(False)
            self._plan_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._plan_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._plan_grid, ui_scale=self._ui_scale)
        self._plan_grid.current_changed.connect(self._on_plan_card_changed)
        self._plan_grid.layout_changed.connect(self._on_plan_grid_layout_changed)
        self._plan_grid.order_changed.connect(self._on_plan_order_changed)
        plan_grid_layout.addWidget(self._plan_grid, 1)
        plan_layout.addWidget(self._plan_grid_panel, 1)

        plan_layout.addWidget(quick_add_panel, 0)

        plan_buttons = QHBoxLayout()
        self._plan_remove_button = QPushButton("제거")
        self._plan_remove_button.clicked.connect(self._remove_selected_plan_student)
        plan_buttons.addWidget(self._plan_remove_button)
        self._plan_open_button = QPushButton("학생 탭에서 보기")
        self._plan_open_button.clicked.connect(self._focus_selected_plan_student_in_viewer)
        plan_buttons.addWidget(self._plan_open_button)
        plan_buttons.addStretch(1)
        plan_layout.addLayout(plan_buttons)

        splitter.addWidget(plan_panel)

        editor_panel = RoundedMaskFrame(ui_scale=self._ui_scale)
        editor_panel.setObjectName("planEditorInventoryShell")
        editor_panel.setFrameShape(QFrame.NoFrame)
        editor_panel.setAutoFillBackground(False)
        editor_panel.setAttribute(Qt.WA_StyledBackground, True)
        editor_outer_layout = QVBoxLayout(editor_panel)
        self._configure_inventory_panel_layout(editor_outer_layout)

        editor_scroll = QScrollArea()
        editor_scroll.setObjectName("sectionScrollArea")
        editor_scroll.setWidgetResizable(True)
        editor_scroll.setFrameShape(QFrame.NoFrame)
        editor_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        editor_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        _install_planner_scroll_handle(editor_scroll, ui_scale=self._ui_scale)
        editor_outer_layout.addWidget(editor_scroll, 1)

        editor_content = QWidget()
        editor_content.setObjectName("planTransparent")
        editor_layout = QVBoxLayout(editor_content)
        editor_layout.setContentsMargins(scale_px(16, self._ui_scale), scale_px(16, self._ui_scale), scale_px(16, self._ui_scale), scale_px(16, self._ui_scale))
        editor_layout.setSpacing(scale_px(10, self._ui_scale))
        editor_scroll.setWidget(editor_content)

        editor_header = PlanEditorSectionCard(ui_scale=self._ui_scale, radius=16)
        editor_header_layout = QHBoxLayout(editor_header)
        editor_header_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
        )
        editor_header_layout.setSpacing(scale_px(10, self._ui_scale))
        name_col = QVBoxLayout()
        name_col.setContentsMargins(0, 0, 0, 0)
        name_col.setSpacing(scale_px(2, self._ui_scale))
        self._plan_name = QLabel("학생을 선택하세요")
        self._plan_name.setObjectName("detailName")
        name_col.addWidget(self._plan_name)
        self._plan_current = QLabel("")
        self._plan_current.setObjectName("detailSub")
        name_col.addWidget(self._plan_current)
        editor_header_layout.addLayout(name_col, 1)

        plan_editor_stack = QStackedWidget()
        plan_editor_stack.setObjectName("planEditorStack")
        plan_editor_stack.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        plan_editor_mode_buttons = QHBoxLayout()
        plan_editor_mode_buttons.setContentsMargins(0, 0, 0, 0)
        plan_editor_mode_buttons.setSpacing(scale_px(8, self._ui_scale))
        plan_editor_buttons: dict[int, QPushButton] = {}

        def sync_plan_editor_buttons(index: int) -> None:
            for button_index, button in plan_editor_buttons.items():
                button.setChecked(button_index == index)

        for index, label in ((0, "목표 타겟"), (1, "필요 재화")):
            button = QPushButton(label)
            button.setObjectName("inventoryModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=index: plan_editor_stack.setCurrentIndex(value))
            plan_editor_mode_buttons.addWidget(button, 0)
            plan_editor_buttons[index] = button
        plan_editor_mode_buttons.addStretch(1)
        plan_editor_stack.currentChanged.connect(sync_plan_editor_buttons)
        editor_header_layout.addLayout(plan_editor_mode_buttons, 0)
        editor_layout.addWidget(editor_header)

        edit_tab = QWidget()
        edit_tab.setObjectName("planTransparent")
        edit_tab_layout = QVBoxLayout(edit_tab)
        edit_tab_layout.setContentsMargins(0, 0, 0, 0)
        edit_tab_layout.setSpacing(0)
        resources_tab = QWidget()
        resources_tab.setObjectName("planTransparent")
        resources_tab_layout = QVBoxLayout(resources_tab)
        resources_tab_layout.setContentsMargins(0, 0, 0, 0)
        resources_tab_layout.setSpacing(0)

        controls_wrap = PlanEditorContentPanel(ui_scale=self._ui_scale)
        controls_wrap.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        controls_layout = QVBoxLayout(controls_wrap)
        controls_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        controls_layout.setSpacing(0)

        self._plan_controls_scroll = QScrollArea()
        self._plan_controls_scroll.setObjectName("sectionScrollArea")
        self._plan_controls_scroll.setFrameShape(QFrame.NoFrame)
        self._plan_controls_scroll.setWidgetResizable(True)
        self._plan_controls_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._plan_controls_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self._plan_controls_scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        _install_planner_scroll_handle(self._plan_controls_scroll, ui_scale=self._ui_scale)

        controls_content = QWidget()
        controls_content.setObjectName("planTransparent")
        controls_content_layout = QVBoxLayout(controls_content)
        controls_content_layout.setContentsMargins(0, 0, 0, 0)
        controls_content_layout.setSpacing(scale_px(10, self._ui_scale))
        self._plan_controls_scroll.setWidget(controls_content)
        controls_layout.addWidget(self._plan_controls_scroll, 1)

        def add_plan_level_row(
            parent_layout: QVBoxLayout,
            field_name: str,
            label: str,
            maximum: int,
            *,
            label_width: int = 62,
        ) -> QFrame:
            row = QFrame()
            row.setObjectName("inventoryPressureRow")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
            )
            row_layout.setSpacing(scale_px(8, self._ui_scale))
            row_title = QLabel(label)
            row_title.setObjectName("detailSectionTitle")
            row_title.setMinimumWidth(scale_px(label_width, self._ui_scale))
            self._plan_level_row_labels[field_name] = row_title
            row_layout.addWidget(row_title)
            selector = PlanStepper(maximum, ui_scale=self._ui_scale)
            selector.valueChanged.connect(lambda value, name=field_name: self._on_plan_digit_changed(name, value))
            self._plan_level_inputs[field_name] = selector
            self._plan_level_rows[field_name] = row
            row_layout.addWidget(selector, 1)
            parent_layout.addWidget(row)
            return row

        progression_panel = PlanEditorSectionCard(ui_scale=self._ui_scale)
        progression_layout = QVBoxLayout(progression_panel)
        progression_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        progression_layout.setSpacing(scale_px(8, self._ui_scale))
        progression_title = QLabel("목표 타겟")
        progression_title.setObjectName("sectionTitle")
        progression_layout.addWidget(progression_title)
        progression_row = QFrame()
        progression_row.setObjectName("inventoryPressureRow")
        progression_row_layout = QHBoxLayout(progression_row)
        progression_row_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        progression_row_layout.setSpacing(scale_px(12, self._ui_scale))
        progression_label = QLabel("성작 상태")
        progression_label.setObjectName("detailSectionTitle")
        progression_label.setMinimumWidth(scale_px(118, self._ui_scale))
        progression_row_layout.addWidget(progression_label, 0, Qt.AlignTop)
        star_selector = PlanSegmentSelector(9, color_break=5, ui_scale=self._ui_scale)
        star_selector.valueChanged.connect(lambda value: self._on_plan_segment_changed("star_weapon", value))
        self._plan_segment_inputs["star_weapon"] = star_selector
        progression_row_layout.addWidget(star_selector, 1)
        progression_layout.addWidget(progression_row)

        add_plan_level_row(progression_layout, "target_level", "학생 레벨", 90, label_width=118)
        add_plan_level_row(progression_layout, "target_weapon_level", "전용무기 레벨", MAX_TARGET_WEAPON_LEVEL, label_width=118)

        stat_toggle = QPushButton()
        stat_toggle.setObjectName("planDisclosureButton")
        stat_toggle.clicked.connect(self._toggle_ability_release_targets)
        progression_layout.addWidget(stat_toggle)
        self._plan_stat_caption = stat_toggle
        self._update_ability_release_toggle_text()

        for field_name, label in (
            ("target_stat_hp", "HP"),
            ("target_stat_atk", "ATK"),
            ("target_stat_heal", "HEAL"),
        ):
            row = add_plan_level_row(progression_layout, field_name, label, 25, label_width=118)
            self._plan_stat_rows[field_name] = row

        controls_content_layout.addWidget(progression_panel)

        requirement_panel = PlanEditorSectionCard(ui_scale=self._ui_scale)
        requirement_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        requirement_layout = QVBoxLayout(requirement_panel)
        requirement_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        requirement_layout.setSpacing(scale_px(8, self._ui_scale))
        requirement_header = QHBoxLayout()
        requirement_header.setContentsMargins(0, 0, 0, 0)
        requirement_header.setSpacing(scale_px(10, self._ui_scale))
        requirement_title = QLabel("필요 재화")
        requirement_title.setObjectName("sectionTitle")
        requirement_header.addWidget(requirement_title)
        self._plan_requirement_summary = QLabel("선택 학생 · 필요 / 보유")
        self._plan_requirement_summary.setObjectName("count")
        self._plan_requirement_summary.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        requirement_header.addWidget(self._plan_requirement_summary, 1)
        requirement_layout.addLayout(requirement_header)

        self._plan_requirement_empty = QLabel("계획 학생을 선택하고 목표를 지정하면 필요한 재화를 미리 볼 수 있습니다.")
        self._plan_requirement_empty.setObjectName("filterSummary")
        self._plan_requirement_empty.setWordWrap(True)
        self._plan_requirement_empty.setMinimumHeight(scale_px(22, self._ui_scale))
        requirement_layout.addWidget(self._plan_requirement_empty)

        self._plan_requirement_scroll = QScrollArea()
        self._plan_requirement_scroll.setObjectName("sectionScrollArea")
        self._plan_requirement_scroll.setFrameShape(QFrame.NoFrame)
        self._plan_requirement_scroll.setWidgetResizable(True)
        self._plan_requirement_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._plan_requirement_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self._plan_requirement_scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        _install_planner_scroll_handle(self._plan_requirement_scroll, ui_scale=self._ui_scale)

        self._plan_requirement_grid_host = QWidget()
        self._plan_requirement_grid_host.setObjectName("planTransparent")
        self._plan_requirement_grid_host.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self._plan_requirement_grid = QGridLayout(self._plan_requirement_grid_host)
        self._plan_requirement_grid.setContentsMargins(
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
        )
        self._plan_requirement_grid.setHorizontalSpacing(scale_px(8, self._ui_scale))
        self._plan_requirement_grid.setVerticalSpacing(scale_px(8, self._ui_scale))
        self._plan_requirement_grid.setAlignment(Qt.AlignTop)
        for column in range(3):
            self._plan_requirement_grid.setColumnStretch(column, 1)
        self._plan_requirement_scroll.setWidget(self._plan_requirement_grid_host)
        requirement_layout.addWidget(self._plan_requirement_scroll, 1)

        skill_panel = PlanEditorSectionCard(ui_scale=self._ui_scale)
        skill_layout = QVBoxLayout(skill_panel)
        skill_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        skill_layout.setSpacing(scale_px(8, self._ui_scale))
        skill_title = QLabel("스킬")
        skill_title.setObjectName("sectionTitle")
        skill_layout.addWidget(skill_title)
        for field_name, label, count in (
            ("target_ex_skill", "EX", MAX_TARGET_EX_SKILL),
            ("target_skill1", "Skill1", MAX_TARGET_SKILL),
            ("target_skill2", "Skill2", MAX_TARGET_SKILL),
            ("target_skill3", "Skill3", MAX_TARGET_SKILL),
        ):
            row = QFrame()
            row.setObjectName("inventoryPressureRow")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
            )
            row_layout.setSpacing(scale_px(12, self._ui_scale))
            row_title = QLabel(label)
            row_title.setObjectName("detailSectionTitle")
            row_title.setMinimumWidth(scale_px(64, self._ui_scale))
            row_layout.addWidget(row_title)
            selector = PlanSegmentSelector(count, active_fill=ACCENT_STRONG, active_border=ACCENT, ui_scale=self._ui_scale)
            selector.valueChanged.connect(lambda value, name=field_name: self._on_plan_segment_changed(name, value))
            self._plan_segment_inputs[field_name] = selector
            row_layout.addWidget(selector, 1)
            skill_layout.addWidget(row)
        controls_content_layout.addWidget(skill_panel, 0)

        equipment_panel = PlanEditorSectionCard(ui_scale=self._ui_scale)
        equipment_layout = QVBoxLayout(equipment_panel)
        equipment_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        equipment_layout.setSpacing(scale_px(8, self._ui_scale))
        equipment_title = QLabel("장비 티어")
        equipment_title.setObjectName("sectionTitle")
        equipment_layout.addWidget(equipment_title)

        equipment_body = QWidget()
        equipment_body.setObjectName("planTransparent")
        equipment_body_layout = QHBoxLayout(equipment_body)
        equipment_body_layout.setContentsMargins(0, 0, 0, 0)
        equipment_body_layout.setSpacing(scale_px(10, self._ui_scale))
        equipment_main = QVBoxLayout()
        equipment_main.setContentsMargins(0, 0, 0, 0)
        equipment_main.setSpacing(scale_px(10, self._ui_scale))
        equipment_body_layout.addLayout(equipment_main, 9)

        self._plan_unique_item_panel = QFrame()
        self._plan_unique_item_panel.setObjectName("inventoryPressureRow")
        unique_layout = QVBoxLayout(self._plan_unique_item_panel)
        unique_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        unique_layout.setSpacing(scale_px(8, self._ui_scale))
        unique_title = QLabel("애용품")
        unique_title.setObjectName("detailSectionTitle")
        unique_layout.addWidget(unique_title)
        self._plan_unique_item_selector = PlanSegmentSelector(2, active_fill=PALETTE_SOFT, active_border="#ffffff", inactive_fill=_mix_hex(SURFACE_ALT, BG, 0.14), ui_scale=self._ui_scale)
        self._plan_unique_item_selector.valueChanged.connect(lambda value: self._on_plan_segment_changed("target_equip4_tier", value))
        self._plan_segment_inputs["target_equip4_tier"] = self._plan_unique_item_selector
        unique_layout.addWidget(self._plan_unique_item_selector)
        equipment_body_layout.addWidget(self._plan_unique_item_panel, 3)
        equipment_layout.addWidget(equipment_body)

        for field_name, slot_index in (
            ("target_equip1_tier", 1),
            ("target_equip2_tier", 2),
            ("target_equip3_tier", 3),
        ):
            row = QFrame()
            row.setObjectName("inventoryPressureRow")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
            )
            row_layout.setSpacing(scale_px(10, self._ui_scale))
            row_title = QLabel(f"장비 {slot_index}")
            row_title.setObjectName("detailSectionTitle")
            row_title.setMinimumWidth(scale_px(70, self._ui_scale))
            self._plan_equipment_labels[field_name] = row_title
            row_layout.addWidget(row_title)
            control_stack = QVBoxLayout()
            control_stack.setContentsMargins(0, 0, 0, 0)
            control_stack.setSpacing(scale_px(8, self._ui_scale))
            selector = PlanSegmentSelector(MAX_TARGET_EQUIP_TIER, active_fill=PALETTE_SOFT, active_border="#ffffff", inactive_fill=_mix_hex(SURFACE_ALT, BG, 0.14), ui_scale=self._ui_scale)
            selector.valueChanged.connect(lambda value, name=field_name: self._on_plan_segment_changed(name, value))
            self._plan_segment_inputs[field_name] = selector
            control_stack.addWidget(selector)

            level_field_name = f"target_equip{slot_index}_level"
            level_row = QWidget()
            level_row.setObjectName("planTransparent")
            level_layout = QHBoxLayout(level_row)
            level_layout.setContentsMargins(0, 0, 0, 0)
            level_layout.setSpacing(scale_px(8, self._ui_scale))
            level_title = QLabel("레벨")
            level_title.setObjectName("detailSectionTitle")
            level_title.setMinimumWidth(scale_px(54, self._ui_scale))
            self._plan_level_row_labels[level_field_name] = row_title
            level_layout.addWidget(level_title)
            level_selector = PlanStepper(MAX_TARGET_EQUIP_LEVEL, ui_scale=self._ui_scale)
            level_selector.valueChanged.connect(lambda value, name=level_field_name: self._on_plan_digit_changed(name, value))
            self._plan_level_inputs[level_field_name] = level_selector
            self._plan_level_rows[level_field_name] = level_row
            level_layout.addWidget(level_selector, 1)
            control_stack.addWidget(level_row)

            row_layout.addLayout(control_stack, 1)
            equipment_main.addWidget(row)
        controls_content_layout.addWidget(equipment_panel, 0)

        self._plan_student_summary = QLabel("필요 재화 미리보기가 여기에 표시됩니다.")
        self._plan_total_summary = QLabel("")
        self._plan_student_summary.setVisible(False)
        self._plan_total_summary.setVisible(False)
        controls_content_layout.addStretch(1)
        edit_tab_layout.addWidget(controls_wrap, 1)
        resources_tab_layout.addWidget(requirement_panel, 1)
        plan_editor_stack.addWidget(edit_tab)
        plan_editor_stack.addWidget(resources_tab)
        plan_editor_stack.setCurrentIndex(0)
        sync_plan_editor_buttons(0)
        editor_layout.addWidget(plan_editor_stack, 1)
        splitter.addWidget(editor_panel)

        splitter.setStretchFactor(0, 5)
        splitter.setStretchFactor(1, 3)

    def _plan_goal_map(self) -> dict[str, StudentGoal]:
        if self._plan_goal_map_cache is None:
            self._plan_goal_map_cache = self._plan.goal_map()
        return self._plan_goal_map_cache

    def _invalidate_plan_caches(self, student_id: str | None = None) -> None:
        self._plan_goal_map_cache = None
        if student_id is None:
            self._plan_cost_cache.clear()
            return
        for cache_key in [cache_key for cache_key in self._plan_cost_cache if cache_key[0] == student_id]:
            del self._plan_cost_cache[cache_key]

    def _plan_priority_index(self) -> dict[str, int]:
        return {goal.student_id: index for index, goal in enumerate(self._plan.goals)}

    def _planned_student_ids(self) -> set[str]:
        return {goal.student_id for goal in self._plan.goals if goal.student_id in self._records_by_id}

    def _add_plan_student_to_resource_scope(self, student_id: str) -> None:
        if student_id in self._records_by_id:
            self._resource_selected_ids.add(student_id)

    def _goal_cache_signature(self, goal: StudentGoal) -> tuple[object, ...]:
        return tuple(getattr(goal, field_name, None) for field_name in _PLAN_GOAL_CACHE_FIELDS)

    def _cached_goal_cost(
        self,
        student_id: str,
        *,
        record: StudentRecord | None = None,
        goal: StudentGoal | None = None,
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> PlanCostSummary | None:
        record = record or self._records_by_id.get(student_id)
        if goal is None:
            goal_map = self._plan_goal_map() if goal_map is None else goal_map
            goal = goal_map.get(student_id)
        if record is None or goal is None:
            return None
        cache_key = (student_id, self._goal_cache_signature(goal))
        summary = self._plan_cost_cache.get(cache_key)
        if summary is None:
            summary = calculate_goal_cost(record, goal)
            self._plan_cost_cache[cache_key] = summary
        return summary

    def _cached_plan_resource_icon_path(self, item_id: str | None, name: str) -> Path | None:
        cache_key = (item_id, name)
        if cache_key not in self._plan_resource_icon_path_cache:
            self._plan_resource_icon_path_cache[cache_key] = _plan_resource_icon_path(item_id, name)
        return self._plan_resource_icon_path_cache[cache_key]

    def _cached_plan_resource_pixmap(self, icon_path: Path | None) -> QPixmap | None:
        if icon_path is None:
            return None
        pixmap = self._plan_resource_pixmap_cache.get(icon_path)
        if pixmap is None:
            pixmap = QPixmap(str(icon_path)) if icon_path.exists() else QPixmap()
            self._plan_resource_pixmap_cache[icon_path] = pixmap
        return pixmap if not pixmap.isNull() else None

    def _save_plan(self) -> None:
        save_plan(self._plan_path, self._plan)
        try:
            self._storage_mtimes[self._plan_path] = self._plan_path.stat().st_mtime_ns
        except OSError:
            self._storage_mtimes[self._plan_path] = None

    def _get_or_create_goal(self, student_id: str) -> StudentGoal:
        for goal in self._plan.goals:
            if goal.student_id == student_id:
                return goal
        goal = StudentGoal(student_id=student_id)
        self._plan.goals.append(goal)
        self._invalidate_plan_caches(student_id)
        return goal

    def _apply_student_card_record(self, card: StudentCardWidget, record: StudentRecord) -> None:
        divider_primary, divider_secondary = _student_divider_colors(record)
        card.setData(
            title=record.title,
            owned=record.owned,
            divider_left=QColor(divider_primary),
            divider_right=QColor(divider_secondary),
        )
        card.setToolTip("")

    def _build_student_card(
        self,
        record,
        *,
        show_name_panel: bool = True,
        show_unowned_badge: bool = True,
    ) -> StudentCardWidget:
        divider_primary, divider_secondary = _student_divider_colors(record)
        card = StudentCardWidget(
            card_asset=self._student_card_asset,
            student_id=record.student_id,
            title=record.title,
            owned=record.owned,
            divider_left=QColor(divider_primary),
            divider_right=QColor(divider_secondary),
            show_name_panel=show_name_panel,
            show_unowned_badge=show_unowned_badge,
        )
        card.setToolTip("")
        self._apply_cached_thumb_to_card(card)
        return card

    def _current_plan_grid_student_id(self) -> str | None:
        if not hasattr(self, "_plan_grid"):
            return None
        return self._plan_grid.current_card_id()

    def _set_plan_search_selection(self, student_id: str | None) -> None:
        if not hasattr(self, "_plan_search_grid"):
            return
        target_id = student_id if student_id in self._plan_search_card_by_id else None
        previous = self._plan_search_grid.blockSignals(True)
        try:
            self._plan_search_grid.set_current_card(target_id)
        finally:
            self._plan_search_grid.blockSignals(previous)

    def _set_plan_grid_selection(self, student_id: str | None) -> None:
        if not hasattr(self, "_plan_grid"):
            return
        target_id = student_id if student_id in self._plan_card_by_id else None
        previous = self._plan_grid.blockSignals(True)
        try:
            self._plan_grid.set_current_card(target_id)
        finally:
            self._plan_grid.blockSignals(previous)

    def _has_any_card_target(self, student_id: str) -> bool:
        return (
            student_id in self._item_by_id
            or student_id in self._plan_card_by_id
            or student_id in self._resource_scope_card_by_id
            or student_id in self._resource_search_card_by_id
        )

    def _update_plan_actions(self) -> None:
        search_selected = self._plan_current_all_student_id()
        planned_selected = self._current_plan_grid_student_id()
        if hasattr(self, "_plan_add_button"):
            self._plan_add_button.setEnabled(bool(search_selected))
        if hasattr(self, "_plan_remove_button"):
            self._plan_remove_button.setEnabled(bool(planned_selected))
        if hasattr(self, "_plan_open_button"):
            self._plan_open_button.setEnabled(bool(planned_selected))

    @staticmethod
    def _record_has_weapon_system(record: StudentRecord) -> bool:
        return (record.weapon_state or "") != "no_weapon_system"

    @staticmethod
    def _plan_allows_weapon_targets(record: StudentRecord) -> bool:
        # In the planner, allow future weapon goals even before the weapon
        # system is unlocked on the current record.
        return True

    @staticmethod
    def _weapon_level_cap_for_star(weapon_star: int) -> int:
        return {
            1: 30,
            2: 40,
            3: 50,
            4: 60,
        }.get(max(0, int(weapon_star)), 0)

    @staticmethod
    def _record_base_star(record: StudentRecord) -> int:
        try:
            rarity = int(record.rarity or 1)
        except (TypeError, ValueError):
            rarity = 1
        return max(1, min(5, rarity))

    @staticmethod
    def _record_current_star(record: StudentRecord) -> int:
        return max(StudentViewerWindow._record_base_star(record), int(record.star or 0))

    @staticmethod
    def _record_current_skill(raw_value: int | None) -> int:
        return max(1, int(raw_value or 0))

    @staticmethod
    def _record_weapon_level(record: StudentRecord) -> int:
        if (record.weapon_state or "") in ("weapon_equipped", "weapon_unlocked_not_equipped"):
            return max(1, int(record.weapon_level or 0) or 1)
        return 0

    @staticmethod
    def _record_star_weapon_total(record: StudentRecord) -> int:
        weapon_star = max(0, int(record.weapon_star or 0))
        if (record.weapon_state or "") == "no_weapon_system":
            weapon_star = 0
        if weapon_star > 0:
            return 5 + weapon_star
        return StudentViewerWindow._record_current_star(record)

    def _current_or_target_weapon_star(self, record: StudentRecord, goal: StudentGoal | None = None) -> int:
        current_weapon_star = max(0, int(record.weapon_star or 0))
        if goal is None:
            return current_weapon_star
        return max(current_weapon_star, int(getattr(goal, "target_weapon_star", 0) or 0))

    def _current_or_target_star(self, record: StudentRecord, goal: StudentGoal | None = None) -> int:
        current_star = self._record_current_star(record)
        if goal is None:
            return current_star
        return max(current_star, int(getattr(goal, "target_star", 0) or 0))

    @staticmethod
    def _current_equipment_level(current_tier: int, raw_level: int | None) -> int:
        if raw_level and raw_level > 0:
            return min(int(raw_level), EQUIPMENT_TIER_MAX_LEVEL.get(max(current_tier, 0), MAX_TARGET_EQUIP_LEVEL))
        if current_tier <= 0:
            return 0
        return 1

    @staticmethod
    def _minimum_equipment_tier_for_level(level: int) -> int:
        normalized = max(0, int(level))
        for tier, max_level in sorted(EQUIPMENT_TIER_MAX_LEVEL.items()):
            if normalized <= max_level:
                return tier
        return MAX_TARGET_EQUIP_TIER

    @staticmethod
    def _equipment_level_cap_for_tier(tier: int) -> int:
        return EQUIPMENT_TIER_MAX_LEVEL.get(max(0, int(tier)), MAX_TARGET_EQUIP_LEVEL)

    @staticmethod
    def _goal_value(goal: StudentGoal | None, field_name: str, current_value: int) -> int:
        if goal is None:
            return current_value
        raw_value = getattr(goal, field_name, None)
        if raw_value is None:
            return current_value
        return max(current_value, int(raw_value))

    def _sync_plan_goal(self, goal: StudentGoal, record: StudentRecord) -> None:
        current_star = self._record_current_star(record)
        current_weapon_star = max(0, int(record.weapon_star or 0))
        current_weapon_level = self._record_weapon_level(record)
        allows_weapon_targets = self._plan_allows_weapon_targets(record)

        target_star = max(current_star, int(goal.target_star or 0))
        target_weapon_star = max(current_weapon_star, int(goal.target_weapon_star or 0))
        target_weapon_level = max(current_weapon_level, int(goal.target_weapon_level or 0))

        if not allows_weapon_targets:
            target_weapon_star = current_weapon_star
            target_weapon_level = current_weapon_level
        if target_weapon_star > 0 or target_weapon_level > 0:
            target_star = max(target_star, 5)
        target_weapon_level = min(target_weapon_level, self._weapon_level_cap_for_star(target_weapon_star))

        goal.target_star = target_star if target_star > current_star else None
        goal.target_weapon_star = target_weapon_star if allows_weapon_targets and target_weapon_star > current_weapon_star else None
        goal.target_weapon_level = target_weapon_level if allows_weapon_targets and target_weapon_level > current_weapon_level else None

        for slot_index in range(1, 4):
            tier_field = f"target_equip{slot_index}_tier"
            level_field = f"target_equip{slot_index}_level"
            current_tier = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
            current_level = self._current_equipment_level(current_tier, getattr(record, f"equip{slot_index}_level", None))
            raw_target_tier = getattr(goal, tier_field)
            target_level = max(current_level, int(getattr(goal, level_field) or 0))
            target_tier = max(current_tier, int(raw_target_tier or 0))
            if target_level > 0:
                if raw_target_tier is not None and target_tier > 0:
                    target_level = min(target_level, self._equipment_level_cap_for_tier(target_tier))
                else:
                    target_tier = max(target_tier, self._minimum_equipment_tier_for_level(target_level))
                target_level = min(target_level, EQUIPMENT_TIER_MAX_LEVEL.get(target_tier, MAX_TARGET_EQUIP_LEVEL))
            setattr(goal, level_field, target_level if target_level > current_level else None)
            setattr(goal, tier_field, target_tier if target_tier > current_tier else None)

        if self._record_supports_unique_item(record) and hasattr(goal, "target_equip4_tier"):
            current_unique_tier = _parse_tier_number(record.equip4) or 0
            target_unique_tier = max(current_unique_tier, int(getattr(goal, "target_equip4_tier") or 0))
            goal.target_equip4_tier = target_unique_tier if target_unique_tier > current_unique_tier else None

    @staticmethod
    def _record_has_unique_item(record: StudentRecord) -> bool:
        value = str(record.equip4 or "").strip().lower()
        return bool(value and value != "null")

    @staticmethod
    def _record_supports_unique_item(record: StudentRecord) -> bool:
        if StudentViewerWindow._record_has_unique_item(record):
            return True
        return bool(student_meta.favorite_item_enabled(record.student_id))

    @staticmethod
    def _equipment_slot_labels(record: StudentRecord) -> list[str]:
        labels = list(student_meta.equipment_slots(record.student_id) or [])
        fallback = ["장비 1", "장비 2", "장비 3"]
        normalized: list[str] = []
        for index in range(3):
            try:
                label = str(labels[index] or fallback[index]).strip()
            except Exception:
                label = fallback[index]
            normalized.append(_equipment_series_label(label.title()))
        return normalized

    def _plan_supports_field(self, goal: StudentGoal | None, field_name: str) -> bool:
        if goal is None:
            return False
        return hasattr(goal, field_name)

    def _refresh_plan_editor_visibility(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        labels = self._equipment_slot_labels(record)
        for idx, field_name in enumerate(("target_equip1_tier", "target_equip2_tier", "target_equip3_tier")):
            label_widget = self._plan_equipment_labels.get(field_name)
            if label_widget is not None:
                label_widget.setText(labels[idx])
        for idx, field_name in enumerate(("target_equip1_level", "target_equip2_level", "target_equip3_level"), start=1):
            label_widget = self._plan_level_row_labels.get(field_name)
            if label_widget is not None:
                label_widget.setText(labels[idx - 1])

        target_weapon_star = self._goal_value(goal, "target_weapon_star", max(0, int(record.weapon_star or 0)))
        target_weapon_level = self._goal_value(goal, "target_weapon_level", self._record_weapon_level(record))
        show_weapon_level = self._plan_allows_weapon_targets(record) and (target_weapon_star > 0 or target_weapon_level > 0)
        weapon_row = self._plan_level_rows.get("target_weapon_level")
        if weapon_row is not None:
            weapon_row.setVisible(show_weapon_level)

        self._refresh_ability_release_visibility(record, goal)

        has_unique_item = self._record_supports_unique_item(record)
        self._plan_unique_item_panel.setVisible(has_unique_item)
        if has_unique_item:
            selector = self._plan_unique_item_selector
            selector.setEnabled(self._plan_supports_field(goal, "target_equip4_tier"))

    @staticmethod
    def _set_widget_visible(widget: QWidget | None, visible: bool) -> None:
        if widget is not None and widget.isVisible() != visible:
            widget.setVisible(visible)

    def _update_ability_release_toggle_text(self) -> None:
        marker = "-" if self._plan_ability_release_expanded else "+"
        self._plan_stat_caption.setText(f"능력개방 {marker}")

    def _ability_release_available(self, record: StudentRecord, goal: StudentGoal | None) -> bool:
        current_level = max(0, int(record.level or 0))
        return self._goal_value(goal, "target_level", current_level) >= 90

    def _refresh_ability_release_visibility(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        available = self._ability_release_available(record, goal)
        self._set_widget_visible(self._plan_stat_caption, available)
        for row in self._plan_stat_rows.values():
            self._set_widget_visible(row, available and self._plan_ability_release_expanded)
        self._update_ability_release_toggle_text()

    def _toggle_ability_release_targets(self) -> None:
        self._plan_ability_release_expanded = not self._plan_ability_release_expanded
        student_id = self._selected_plan_student_id or self._plan_current_all_student_id()
        record = self._records_by_id.get(student_id) if student_id else None
        goal = self._plan_goal_map().get(student_id) if student_id else None
        if record is not None:
            self._refresh_ability_release_visibility(record, goal)
        else:
            self._update_ability_release_toggle_text()

    def _refresh_weapon_level_controls(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        current_weapon_level = self._record_weapon_level(record)
        target_weapon_star = self._current_or_target_weapon_star(record, goal)
        target_weapon_level = self._goal_value(goal, "target_weapon_level", current_weapon_level)
        show_weapon_level = self._plan_allows_weapon_targets(record) and (target_weapon_star > 0 or target_weapon_level > 0)
        self._set_widget_visible(self._plan_level_rows.get("target_weapon_level"), show_weapon_level)
        weapon_level_selector = self._plan_level_inputs["target_weapon_level"]
        weapon_level_selector.setMaximumValue(self._weapon_level_cap_for_star(target_weapon_star))
        weapon_level_selector.setEnabled(self._plan_allows_weapon_targets(record))
        weapon_level_selector.setState(
            minimum_value=current_weapon_level,
            value=target_weapon_level,
        )

    def _refresh_star_weapon_controls(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        current_total = self._record_star_weapon_total(record)
        current_star = self._record_current_star(record)
        current_weapon_star = max(0, int(record.weapon_star or 0))
        target_star = self._goal_value(goal, "target_star", current_star)
        target_weapon_star = self._goal_value(goal, "target_weapon_star", current_weapon_star)
        target_total = target_star if target_weapon_star <= 0 else 5 + target_weapon_star
        self._plan_segment_inputs["star_weapon"].setState(
            minimum_value=current_total,
            value=target_total,
            enabled_count=9 if self._plan_allows_weapon_targets(record) else 5,
        )
        self._refresh_weapon_level_controls(record, goal)

    def _refresh_single_equipment_controls(self, record: StudentRecord, goal: StudentGoal | None, slot_index: int) -> None:
        tier_field = f"target_equip{slot_index}_tier"
        level_field = f"target_equip{slot_index}_level"
        current_tier = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
        current_level = self._current_equipment_level(current_tier, getattr(record, f"equip{slot_index}_level", None))
        target_tier = self._goal_value(goal, tier_field, current_tier)
        self._plan_segment_inputs[tier_field].setState(
            minimum_value=current_tier,
            value=target_tier,
        )
        self._plan_level_inputs[level_field].setMaximumValue(self._equipment_level_cap_for_tier(target_tier))
        self._plan_level_inputs[level_field].setState(
            minimum_value=current_level,
            value=self._goal_value(goal, level_field, current_level),
        )

    def _refresh_single_digit_control(self, record: StudentRecord, goal: StudentGoal | None, field_name: str) -> None:
        if field_name == "target_level":
            current_value = max(0, int(record.level or 0))
        elif field_name == "target_weapon_level":
            self._refresh_star_weapon_controls(record, goal)
            return
        elif field_name == "target_stat_hp":
            current_value = max(0, int(record.stat_hp or 0))
        elif field_name == "target_stat_atk":
            current_value = max(0, int(record.stat_atk or 0))
        elif field_name == "target_stat_heal":
            current_value = max(0, int(record.stat_heal or 0))
        else:
            return
        selector = self._plan_level_inputs.get(field_name)
        if selector is None:
            return
        selector.setEnabled(self._plan_supports_field(goal, field_name))
        selector.setState(
            minimum_value=current_value,
            value=self._goal_value(goal, field_name, current_value),
        )
        if field_name == "target_level":
            self._refresh_ability_release_visibility(record, goal)

    def _refresh_single_segment_control(self, record: StudentRecord, goal: StudentGoal | None, field_name: str) -> None:
        if field_name == "star_weapon":
            self._refresh_star_weapon_controls(record, goal)
            return
        if field_name.startswith("target_equip") and field_name.endswith("_tier"):
            self._refresh_single_equipment_controls(record, goal, int(field_name[len("target_equip")]))
            return
        if field_name == "target_equip4_tier":
            if self._record_supports_unique_item(record):
                current_unique_tier = _parse_tier_number(record.equip4) or 0
                self._plan_unique_item_selector.setState(
                    minimum_value=current_unique_tier,
                    value=self._goal_value(goal, "target_equip4_tier", current_unique_tier),
                    enabled_count=2,
                )
            return
        current_value = 0
        if field_name == "target_ex_skill":
            current_value = self._record_current_skill(record.ex_skill)
        elif field_name == "target_skill1":
            current_value = self._record_current_skill(record.skill1)
        elif field_name == "target_skill2":
            current_value = self._record_current_skill(record.skill2)
        elif field_name == "target_skill3":
            current_value = self._record_current_skill(record.skill3)
        selector = self._plan_segment_inputs.get(field_name)
        if selector is not None:
            selector.setState(
                minimum_value=current_value,
                value=self._goal_value(goal, field_name, current_value),
            )

    def _refresh_plan_editor_controls(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        current_total = self._record_star_weapon_total(record)
        current_star = self._record_current_star(record)
        current_weapon_star = max(0, int(record.weapon_star or 0))
        target_star = self._goal_value(goal, "target_star", current_star)
        target_weapon_star = self._goal_value(goal, "target_weapon_star", current_weapon_star)
        target_total = target_star if target_weapon_star <= 0 else 5 + target_weapon_star
        self._plan_segment_inputs["star_weapon"].setState(
            minimum_value=current_total,
            value=target_total,
            enabled_count=9 if self._plan_allows_weapon_targets(record) else 5,
        )

        for field_name, current_value in (
            ("target_ex_skill", self._record_current_skill(record.ex_skill)),
            ("target_skill1", self._record_current_skill(record.skill1)),
            ("target_skill2", self._record_current_skill(record.skill2)),
            ("target_skill3", self._record_current_skill(record.skill3)),
        ):
            self._plan_segment_inputs[field_name].setState(
                minimum_value=current_value,
                value=self._goal_value(goal, field_name, current_value),
            )

        for slot_index in range(1, 4):
            tier_field = f"target_equip{slot_index}_tier"
            level_field = f"target_equip{slot_index}_level"
            current_tier = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
            current_level = self._current_equipment_level(current_tier, getattr(record, f"equip{slot_index}_level", None))
            target_tier = self._goal_value(goal, tier_field, current_tier)
            self._plan_segment_inputs[tier_field].setState(
                minimum_value=current_tier,
                value=target_tier,
            )
            self._plan_level_inputs[level_field].setMaximumValue(self._equipment_level_cap_for_tier(target_tier))
            self._plan_level_inputs[level_field].setState(
                minimum_value=current_level,
                value=self._goal_value(goal, level_field, current_level),
            )

        current_level = max(0, int(record.level or 0))
        current_weapon_level = self._record_weapon_level(record)
        self._plan_level_inputs["target_level"].setState(
            minimum_value=current_level,
            value=self._goal_value(goal, "target_level", current_level),
        )
        weapon_level_selector = self._plan_level_inputs["target_weapon_level"]
        target_weapon_star = self._current_or_target_weapon_star(record, goal)
        weapon_level_selector.setMaximumValue(self._weapon_level_cap_for_star(target_weapon_star))
        weapon_level_selector.setEnabled(self._plan_allows_weapon_targets(record))
        weapon_level_selector.setState(
            minimum_value=current_weapon_level,
            value=self._goal_value(goal, "target_weapon_level", current_weapon_level),
        )

        for field_name, current_value in (
            ("target_stat_hp", max(0, int(record.stat_hp or 0))),
            ("target_stat_atk", max(0, int(record.stat_atk or 0))),
            ("target_stat_heal", max(0, int(record.stat_heal or 0))),
        ):
            selector = self._plan_level_inputs.get(field_name)
            if selector is None:
                continue
            selector.setEnabled(self._plan_supports_field(goal, field_name))
            selector.setState(
                minimum_value=current_value,
                value=self._goal_value(goal, field_name, current_value),
            )

        if self._record_supports_unique_item(record):
            current_unique_tier = _parse_tier_number(record.equip4) or 0
            self._plan_unique_item_selector.setState(
                minimum_value=current_unique_tier,
                value=self._goal_value(goal, "target_equip4_tier", current_unique_tier),
                enabled_count=2,
            )

        self._refresh_plan_editor_visibility(record, goal)

    def _on_plan_segment_changed(self, field_name: str, value: int) -> None:
        if self._plan_editor_guard:
            return
        student_id = self._selected_plan_student_id or self._plan_current_all_student_id()
        if not student_id:
            return
        record = self._records_by_id.get(student_id)
        if record is None:
            return
        was_planned = student_id in self._plan_goal_map()
        goal = self._get_or_create_goal(student_id)

        if field_name == "star_weapon":
            target_star = min(5, value)
            target_weapon_star = max(0, value - 5)
            goal.target_star = target_star if target_star > self._record_current_star(record) else None
            goal.target_weapon_star = target_weapon_star if target_weapon_star > max(0, int(record.weapon_star or 0)) else None
        else:
            current_value = 0
            if field_name == "target_ex_skill":
                current_value = self._record_current_skill(record.ex_skill)
            elif field_name == "target_skill1":
                current_value = self._record_current_skill(record.skill1)
            elif field_name == "target_skill2":
                current_value = self._record_current_skill(record.skill2)
            elif field_name == "target_skill3":
                current_value = self._record_current_skill(record.skill3)
            elif field_name.startswith("target_equip"):
                slot_index = int(field_name[len("target_equip")])
                current_value = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
            if self._plan_supports_field(goal, field_name):
                setattr(goal, field_name, value if value > current_value else None)

        self._sync_plan_goal(goal, record)
        self._invalidate_plan_caches(student_id)
        if not was_planned:
            self._add_plan_student_to_resource_scope(student_id)
        self._save_plan()
        self._selected_plan_student_id = student_id
        self._refresh_after_plan_goal_change(student_id, rebuild_lists=not was_planned, changed_field=field_name)

    def _on_plan_digit_changed(self, field_name: str, value: int) -> None:
        if self._plan_editor_guard:
            return
        student_id = self._selected_plan_student_id or self._plan_current_all_student_id()
        if not student_id:
            return
        record = self._records_by_id.get(student_id)
        if record is None:
            return
        was_planned = student_id in self._plan_goal_map()
        goal = self._get_or_create_goal(student_id)

        if field_name == "target_level":
            current_value = max(0, int(record.level or 0))
        elif field_name == "target_weapon_level":
            current_value = self._record_weapon_level(record)
        elif field_name == "target_stat_hp":
            current_value = max(0, int(record.stat_hp or 0))
        elif field_name == "target_stat_atk":
            current_value = max(0, int(record.stat_atk or 0))
        elif field_name == "target_stat_heal":
            current_value = max(0, int(record.stat_heal or 0))
        else:
            slot_index = int(field_name[len("target_equip")])
            current_tier = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
            current_value = self._current_equipment_level(current_tier, getattr(record, f"equip{slot_index}_level", None))
        if self._plan_supports_field(goal, field_name):
            setattr(goal, field_name, value if value > current_value else None)

        self._sync_plan_goal(goal, record)
        self._invalidate_plan_caches(student_id)
        if not was_planned:
            self._add_plan_student_to_resource_scope(student_id)
        self._save_plan()
        self._selected_plan_student_id = student_id
        self._refresh_after_plan_goal_change(student_id, rebuild_lists=not was_planned, changed_field=field_name)

    def _refresh_after_plan_goal_change(self, student_id: str, *, rebuild_lists: bool, changed_field: str | None = None) -> None:
        if rebuild_lists:
            self._refresh_plan_lists()
            self._set_plan_grid_selection(student_id)
        else:
            self._refresh_plan_editor_after_goal_change(student_id, changed_field)
            if self._current_plan_grid_student_id() != student_id:
                self._set_plan_grid_selection(student_id)
            self._update_plan_actions()
        self._refresh_plan_totals()

    def _refresh_plan_editor_after_goal_change(self, student_id: str, changed_field: str | None = None) -> None:
        record = self._records_by_id.get(student_id)
        goal = self._plan_goal_map().get(student_id)
        if record is None:
            self._clear_plan_editor()
            return
        self._plan_editor_guard = True
        try:
            if changed_field is None:
                self._refresh_plan_editor_controls(record, goal)
            elif changed_field in self._plan_segment_inputs:
                self._refresh_single_segment_control(record, goal, changed_field)
            elif changed_field in self._plan_level_inputs:
                if changed_field.startswith("target_equip") and changed_field.endswith("_level"):
                    self._refresh_single_equipment_controls(record, goal, int(changed_field[len("target_equip")]))
                else:
                    self._refresh_single_digit_control(record, goal, changed_field)
        finally:
            self._plan_editor_guard = False
        self._update_plan_student_summary(student_id)
        self._refresh_selected_plan_requirements(student_id)

    def _set_plan_empty_scroll_margin_mode(self, empty: bool) -> None:
        for attr in ("_plan_controls_scroll", "_plan_requirement_scroll"):
            scroll_area = getattr(self, attr, None)
            if scroll_area is None:
                continue
            margins = scroll_area.viewportMargins()
            scroll_area.setViewportMargins(
                margins.left(),
                margins.top(),
                0 if empty else scale_px(18, self._ui_scale),
                margins.bottom(),
            )
            handle = getattr(scroll_area, "_planner_scroll_handle", None)
            if isinstance(handle, PlannerScrollHandle):
                handle.setSuppressed(empty)

    def _refresh_plan_lists(self) -> None:
        if not hasattr(self, "_plan_search_grid"):
            return
        query = _live_line_edit_text(self._plan_search).strip().casefold()
        current_all = self._plan_current_all_student_id()
        current_plan = self._current_plan_grid_student_id() or self._selected_plan_student_id
        goal_map = self._plan_goal_map()

        self._plan_search_grid.clear_cards()
        self._plan_search_card_by_id.clear()
        search_cards: list[StudentCardWidget] = []
        match_count = 0
        if query:
            for record in sorted(self._all_students, key=lambda item: item.title.lower()):
                if query not in student_meta.search_blob(record.student_id, record.title):
                    continue
                card = self._build_student_card(
                    record,
                    show_name_panel=False,
                    show_unowned_badge=False,
                )
                search_cards.append(card)
                self._plan_search_card_by_id[record.student_id] = card
                match_count += 1

        if search_cards:
            self._plan_search_grid.add_cards(search_cards)
            for student_id in self._plan_search_card_by_id:
                self._enqueue_thumb(student_id)
        self._plan_search_grid.setVisible(bool(query))
        if hasattr(self, "_plan_search_grid_panel"):
            self._plan_search_grid_panel.setVisible(bool(query))
        if not query:
            self._plan_search_state.setText("학생 순서를 드래그해서 변경할 수 있으며, 학생 순서대로 인벤토리 탭에서 재화 우선 목표를 보여줍니다.")
        elif match_count:
            self._plan_search_state.setText(f"{match_count}명 찾음. 학생을 선택해 계획에 추가하세요.")
        else:
            self._plan_search_state.setText("검색과 일치하는 학생이 없습니다.")

        planned_goals = list(self._plan.goals)
        planned_ids = tuple(goal.student_id for goal in planned_goals if goal.student_id in self._records_by_id)
        current_ids = tuple(self._plan_card_by_id)
        if planned_ids != current_ids:
            self._plan_grid.clear_cards()
            self._plan_card_by_id.clear()
            planned_cards: list[StudentCardWidget] = []
            for goal in planned_goals:
                record = self._records_by_id.get(goal.student_id)
                if record is None:
                    continue
                card = self._build_student_card(record)
                planned_cards.append(card)
                self._plan_card_by_id[record.student_id] = card

            if planned_cards:
                self._plan_grid.add_cards(planned_cards)
                for student_id in self._plan_card_by_id:
                    self._enqueue_thumb(student_id)
        else:
            planned_cards = list(self._plan_card_by_id.values())

        self._plan_count_label.setText(f"{len(planned_cards)}명")
        self._plan_empty_label.setVisible(not planned_cards)
        self._plan_grid.setVisible(bool(planned_cards))
        if hasattr(self, "_plan_grid_panel"):
            self._plan_grid_panel.setVisible(bool(planned_cards))

        self._set_plan_search_selection(current_all)
        self._set_plan_grid_selection(current_plan)
        focused_id = current_plan if current_plan in self._plan_card_by_id else self._plan_current_all_student_id()
        if focused_id:
            self._selected_plan_student_id = focused_id if focused_id in goal_map else None
            self._load_plan_student(focused_id)
        else:
            self._selected_plan_student_id = None
            self._clear_plan_editor()
        self._update_plan_actions()

    def _plan_current_all_student_id(self) -> str | None:
        if not hasattr(self, "_plan_search_grid"):
            return None
        return self._plan_search_grid.current_card_id()

    def _on_plan_search_card_changed(self, current: str | None, _previous: str | None) -> None:
        if current is None:
            self._update_plan_actions()
            return
        self._selected_plan_student_id = current if current in self._plan_goal_map() else None
        self._set_plan_grid_selection(current if current in self._plan_goal_map() else None)
        self._load_plan_student(current)
        self._update_plan_actions()

    def _on_plan_card_changed(self, current: str | None, _previous: str | None) -> None:
        if current is None:
            self._selected_plan_student_id = None
            self._update_plan_actions()
            return
        self._selected_plan_student_id = current
        self._set_plan_search_selection(current)
        self._load_plan_student(current)
        self._update_plan_actions()

    def _on_plan_order_changed(self, student_ids: object) -> None:
        ordered_ids = [str(student_id) for student_id in student_ids or []]
        if not ordered_ids:
            return
        ordered_id_set = set(ordered_ids)
        goal_by_id = {goal.student_id: goal for goal in self._plan.goals}
        next_goals = [goal_by_id[student_id] for student_id in ordered_ids if student_id in goal_by_id]
        next_goals.extend(goal for goal in self._plan.goals if goal.student_id not in ordered_id_set)
        if [goal.student_id for goal in next_goals] == [goal.student_id for goal in self._plan.goals]:
            return
        self._plan.goals = next_goals
        self._invalidate_plan_caches()
        self._save_plan()
        self._refresh_plan_totals()

    @staticmethod
    def _global_pos_in_widget(widget: QWidget | None, global_pos: QPoint) -> bool:
        if widget is None or not widget.isVisible():
            return False
        top_left = widget.mapToGlobal(QPoint(0, 0))
        return QRect(top_left, widget.size()).contains(global_pos)

    def _is_plan_drop_target(self, global_pos: QPoint) -> bool:
        if self._global_pos_in_widget(getattr(self, "_plan_quick_add_panel", None), global_pos):
            return False
        if self._global_pos_in_widget(getattr(self, "_plan_grid_panel", None), global_pos):
            return True
        if self._global_pos_in_widget(getattr(self, "_plan_empty_label", None), global_pos):
            return True
        plan_panel = getattr(self, "_plan_panel", None)
        if not self._global_pos_in_widget(plan_panel, global_pos):
            return False
        quick_add_panel = getattr(self, "_plan_quick_add_panel", None)
        if quick_add_panel is None:
            return True
        quick_add_top = quick_add_panel.mapToGlobal(QPoint(0, 0)).y()
        return global_pos.y() < quick_add_top

    def _plan_drop_insert_index(self, global_pos: QPoint) -> int | None:
        if (
            hasattr(self, "_plan_grid")
            and self._plan_grid.isVisible()
            and self._global_pos_in_widget(getattr(self, "_plan_grid_panel", None), global_pos)
        ):
            return self._plan_grid.drop_index_for_global_pos(
                global_pos,
                stable_index=getattr(self._plan_grid, "_drop_placeholder_index", None),
            )
        return None

    def _add_student_to_plan(self, student_id: str, *, insert_index: int | None = None) -> None:
        if not student_id:
            return
        goal = self._get_or_create_goal(student_id)
        if insert_index is not None:
            next_goals = [candidate for candidate in self._plan.goals if candidate.student_id != student_id]
            clamped_index = max(0, min(insert_index, len(next_goals)))
            next_goals.insert(clamped_index, goal)
            if [candidate.student_id for candidate in next_goals] != [candidate.student_id for candidate in self._plan.goals]:
                self._plan.goals = next_goals
                self._invalidate_plan_caches()
        self._add_plan_student_to_resource_scope(student_id)
        self._selected_plan_student_id = student_id
        self._save_plan()
        self._refresh_plan_lists()
        self._set_plan_grid_selection(student_id)
        self._update_plan_student_summary(student_id)
        self._refresh_plan_totals()
        self._update_plan_actions()

    def _on_plan_search_card_drag_moved(self, _student_id: str, global_pos: object) -> None:
        if not isinstance(global_pos, QPoint) or not hasattr(self, "_plan_grid"):
            return
        if (
            self._plan_grid.isVisible()
            and self._global_pos_in_widget(getattr(self, "_plan_grid_panel", None), global_pos)
        ):
            index = self._plan_grid.drop_index_for_global_pos(
                global_pos,
                stable_index=getattr(self._plan_grid, "_drop_placeholder_index", None),
            )
            self._plan_grid.set_external_drop_placeholder(index)
            return
        self._plan_grid.clear_external_drop_placeholder()

    def _on_plan_search_card_drag_finished(self, student_id: str, global_pos: object) -> None:
        if not isinstance(global_pos, QPoint):
            return
        try:
            if not self._is_plan_drop_target(global_pos):
                return
            self._add_student_to_plan(student_id, insert_index=self._plan_drop_insert_index(global_pos))
        finally:
            if hasattr(self, "_plan_grid"):
                self._plan_grid.clear_external_drop_placeholder()

    def _add_selected_student_to_plan(self) -> None:
        student_id = self._plan_current_all_student_id() or self._selected_plan_student_id
        if not student_id:
            return
        self._add_student_to_plan(student_id)

    def _remove_selected_plan_student(self) -> None:
        student_id = self._current_plan_grid_student_id() or self._selected_plan_student_id
        if not student_id:
            return
        self._plan.goals = [goal for goal in self._plan.goals if goal.student_id != student_id]
        self._invalidate_plan_caches(student_id)
        self._selected_plan_student_id = None
        self._save_plan()
        self._refresh_plan_lists()
        self._refresh_plan_totals()
        self._update_plan_actions()

    def _focus_selected_plan_student_in_viewer(self) -> None:
        if not self._selected_plan_student_id:
            return
        if self._selected_plan_student_id in self._item_by_id:
            self._student_grid.set_current_card(self._selected_plan_student_id)
            if self._main_tabs is not None:
                self._main_tabs.setCurrentIndex(0)

    def _load_plan_student(self, student_id: str) -> None:
        record = self._records_by_id.get(student_id)
        if record is None:
            self._clear_plan_editor()
            return
        self._set_plan_empty_scroll_margin_mode(False)
        goal = self._plan_goal_map().get(student_id)
        self._plan_editor_guard = True
        try:
            self._plan_ability_release_expanded = False
            self._plan_name.setText(record.title)
            self._plan_current.setText("보유" if record.owned else "미보유")
            for selector in self._plan_segment_inputs.values():
                selector.setEnabled(True)
            for selector in self._plan_level_inputs.values():
                selector.setEnabled(True)
            self._refresh_plan_editor_controls(record, goal)
        finally:
            self._plan_editor_guard = False
        self._update_plan_student_summary(student_id)
        self._refresh_selected_plan_requirements(student_id)

    def _clear_plan_editor(self) -> None:
        self._set_plan_empty_scroll_margin_mode(True)
        self._plan_editor_guard = True
        try:
            self._plan_name.setText("학생을 선택하세요")
            self._plan_current.setText("")
            for selector in self._plan_segment_inputs.values():
                selector.setEnabled(False)
                selector.setState(minimum_value=0, value=0, enabled_count=selector._count)
            for selector in self._plan_level_inputs.values():
                selector.setEnabled(False)
                selector.setState(minimum_value=0, value=0)
        finally:
            self._plan_editor_guard = False
        if hasattr(self, "_plan_unique_item_panel"):
            self._plan_unique_item_panel.setVisible(False)
        if hasattr(self, "_plan_stat_caption"):
            self._plan_stat_caption.setVisible(False)
            self._update_ability_release_toggle_text()
        for row in getattr(self, "_plan_stat_rows", {}).values():
            row.setVisible(False)
        self._plan_student_summary.setText("선택된 학생이 없습니다.")
        self._refresh_plan_requirements(None)
        self._update_plan_actions()

    def _update_plan_student_summary(self, student_id: str) -> None:
        record = self._records_by_id.get(student_id)
        goal = self._plan_goal_map().get(student_id)
        if record is None or goal is None:
            self._plan_student_summary.setText("비용을 계산하려면 이 학생을 계획에 추가하세요.")
            return
        summary = self._cached_goal_cost(student_id, record=record, goal=goal)
        if summary is None:
            self._plan_student_summary.setText("비용을 계산하려면 이 학생을 계획에 추가하세요.")
            return
        self._plan_student_summary.setText(self._format_cost_summary(summary))

    def _add_current_student_to_plan(self) -> None:
        student_id = self._current_student_id()
        if not student_id:
            return
        self._get_or_create_goal(student_id)
        self._add_plan_student_to_resource_scope(student_id)
        self._selected_plan_student_id = student_id
        self._save_plan()
        self._refresh_plan_lists()
        self._set_plan_grid_selection(student_id)
        self._refresh_plan_totals()
        self._update_plan_actions()

    def _refresh_plan_totals(self) -> None:
        if not hasattr(self, "_plan_total_summary"):
            return
        goal_map = self._plan_goal_map()
        total, _selected_count, _contributing_count = self._resource_total_for_ids(
            [goal.student_id for goal in self._plan.goals],
            goal_map,
        )
        self._plan_total_summary.setText(
            f"계획 학생 {len(self._plan.goals)}명\n{self._format_cost_summary(total)}"
        )
        self._refresh_resources_if_visible()
        self._refresh_inventory_tab()

    def _refresh_selected_plan_requirements(self, student_id: str | None = None) -> None:
        selected_id = student_id or self._selected_plan_student_id or self._current_plan_grid_student_id()
        if not selected_id:
            self._refresh_plan_requirements(None)
            return
        record = self._records_by_id.get(selected_id)
        goal = self._plan_goal_map().get(selected_id)
        if record is None or goal is None:
            self._refresh_plan_requirements(None)
            return
        self._refresh_plan_requirements(self._cached_goal_cost(selected_id, record=record, goal=goal), record=record)

    def _plan_requirement_sort_key(
        self,
        entry: PlanResourceRequirement,
        *,
        equipment_slot_order: dict[str, int],
    ) -> tuple[int, int, str]:
        category = entry.category
        item_id = entry.key
        if category == "skill_books":
            if item_id == "Item_Icon_SkillBook_Ultimate_Piece":
                category = "secret_notes"
            elif item_id.startswith("Item_Icon_Material_ExSkill_"):
                category = "skill_bd"
            elif item_id.startswith("Item_Icon_SkillBook_"):
                category = "skill_notes"
        elif category == "equipment_materials":
            series_key = _equipment_series_key_from_item(item_id, entry.name)
            slot_index = equipment_slot_order.get(series_key or "")
            if slot_index in (1, 2, 3):
                category = f"equipment_slot_{slot_index}"
        tier = _tier_from_item_id_or_name(item_id, entry.name)
        return (
            _PLAN_RESOURCE_CATEGORY_ORDER.get(category, 999),
            -tier,
            entry.name.lower(),
        )

    def _apply_weapon_exp_wildcard_ownership(self, merged: dict[tuple[str, str], PlanResourceRequirement]) -> None:
        inventory_index = self._inventory_quantity_index_cache
        wildcard_remaining = {
            tier: inventory_index.get(f"{WEAPON_EXP_ITEM_PREFIX}{WEAPON_EXP_WILDCARD_PART_KEY}_{tier - 1}", 0)
            for tier in range(1, 5)
        }
        weapon_entries: list[PlanResourceRequirement] = []
        for entry in merged.values():
            if entry.category != "weapon_exp":
                continue
            parsed = _weapon_exp_item_part_and_tier(entry.key)
            if parsed is None:
                continue
            part_key, tier = parsed
            if part_key == WEAPON_EXP_WILDCARD_PART_KEY:
                wildcard_remaining[tier] = max(0, wildcard_remaining.get(tier, 0) - entry.required)
            else:
                weapon_entries.append(entry)

        for entry in sorted(weapon_entries, key=lambda value: value.key):
            parsed = _weapon_exp_item_part_and_tier(entry.key)
            if parsed is None:
                continue
            _part_key, tier = parsed
            shortage = max(0, entry.required - entry.owned)
            if shortage <= 0:
                continue
            wildcard_available = wildcard_remaining.get(tier, 0)
            if wildcard_available <= 0:
                continue
            wildcard_used = min(shortage, wildcard_available)
            entry.owned += wildcard_used
            wildcard_remaining[tier] = wildcard_available - wildcard_used

    def _plan_requirement_entries(self, summary: PlanCostSummary, *, record: StudentRecord | None = None) -> list[PlanResourceRequirement]:
        inventory_index = self._inventory_quantity_index_cache
        merged: dict[tuple[str, str], PlanResourceRequirement] = {}
        equipment_slot_order: dict[str, int] = {}
        if record is not None:
            for index, slot_key in enumerate(student_meta.equipment_slots(record.student_id) or (), start=1):
                if slot_key:
                    equipment_slot_order[str(slot_key)] = index

        def add_entry(category: str, key: str, required: int) -> None:
            if required <= 0:
                return
            item_id = _plan_resource_item_id(key, category)
            name = _plan_resource_display_name(item_id, key)
            owned = inventory_index.get(item_id or "", inventory_index.get(key, 0))
            icon_path = self._cached_plan_resource_icon_path(item_id, name)
            icon = self._cached_plan_resource_pixmap(icon_path)
            merge_key = (category, item_id or key)
            current = merged.get(merge_key)
            if current is None:
                merged[merge_key] = PlanResourceRequirement(
                    key=item_id or key,
                    name=name,
                    required=required,
                    owned=owned,
                    icon_path=icon_path,
                    category=category,
                    icon=icon,
                )
            else:
                current.required += required

        add_entry("credits", "Currency_Icon_Gold", summary.credits)
        for category, values in (
            ("level_exp", summary.level_exp_items),
            ("equipment_exp", summary.equipment_exp_items),
            ("weapon_exp", summary.weapon_exp_items),
            ("skill_books", summary.skill_books),
            ("ex_ooparts", summary.ex_ooparts),
            ("skill_ooparts", summary.skill_ooparts),
            ("favorite_item_materials", summary.favorite_item_materials),
            ("stat_materials", summary.stat_materials),
            ("equipment_materials", summary.equipment_materials),
            ("star_materials", summary.star_materials),
        ):
            for key, required in values.items():
                add_entry(category, key, required)

        self._apply_weapon_exp_wildcard_ownership(merged)

        return sorted(
            merged.values(),
            key=lambda entry: self._plan_requirement_sort_key(entry, equipment_slot_order=equipment_slot_order),
        )

    def _refresh_plan_requirements(self, summary: PlanCostSummary | None, *, record: StudentRecord | None = None) -> None:
        if not hasattr(self, "_plan_requirement_grid"):
            return

        self._plan_requirement_grid_host.setUpdatesEnabled(False)
        try:
            while self._plan_requirement_grid.count():
                item = self._plan_requirement_grid.takeAt(0)
                widget = item.widget()
                if widget is not None:
                    widget.deleteLater()

            if summary is None:
                self._plan_requirement_empty.setText("계획 학생을 선택하고 목표를 지정하면 필요한 재화를 미리 볼 수 있습니다.")
                self._plan_requirement_empty.setVisible(True)
                self._plan_requirement_scroll.setVisible(True)
                self._plan_requirement_summary.setText("선택 학생 · 필요 / 보유")
                return

            entries = self._plan_requirement_entries(summary, record=record)
            self._plan_requirement_empty.setText("" if entries else "이 학생의 현재 목표에는 추가 재화가 필요하지 않습니다.")
            self._plan_requirement_empty.setVisible(True)
            self._plan_requirement_scroll.setVisible(True)
            if not entries:
                self._plan_requirement_summary.setText("선택 학생 · 필요 / 보유")
                return

            shortages = sum(1 for entry in entries if entry.required > entry.owned)
            self._plan_requirement_summary.setText(
                f"{len(entries)}개 · 부족 {shortages}개 · 필요 / 보유"
            )
            columns = 3
            for index, requirement in enumerate(entries):
                chip = PlanResourceChip(ui_scale=self._ui_scale)
                chip.setData(requirement)
                self._plan_requirement_grid.addWidget(chip, index // columns, index % columns)
        finally:
            self._plan_requirement_grid_host.setUpdatesEnabled(True)

    def _stats_set_mode(self, attr_name: str, value: str) -> None:
        if getattr(self, attr_name, None) == value:
            return
        setattr(self, attr_name, value)
        self._refresh_stats_tab()

    def _stats_chart_tab_changed(self, index: int) -> None:
        if self._stats_chart_tabs is None:
            return
        value = self._stats_chart_tabs.tabData(index)
        next_tab = str(value or "collection")
        if self._stats_active_chart_tab == next_tab:
            return
        self._stats_active_chart_tab = next_tab
        self._refresh_stats_tab()

    def _stats_refresh_sunburst_mode(self) -> None:
        self._stats_update_sunburst_value_options()
        self._stats_sunburst_selected_path = ()
        self._stats_sunburst_breadcrumb_path = ()
        self._stats_sunburst_selected_context = {}
        self._stats_sunburst_selected_node = None
        self._stats_sunburst_drill_stack.clear()
        self._refresh_stats_tab()

    def _stats_reset_sunburst_root(self) -> None:
        self._stats_sunburst_selected_path = ()
        self._stats_sunburst_breadcrumb_path = ()
        self._stats_sunburst_selected_context = {}
        self._stats_sunburst_selected_node = None
        self._stats_sunburst_drill_stack.clear()
        self._refresh_stats_tab()

    def _stats_clear_sunburst_selection(self) -> None:
        current_path = self._stats_sunburst_breadcrumb_path
        self._stats_sunburst_selected_path = ()
        self._stats_sunburst_selected_context = {}
        self._stats_sunburst_selected_node = None
        if current_path:
            self._stats_sunburst_breadcrumb_path = current_path
        self._refresh_stats_tab()

    def _stats_sunburst_back(self) -> None:
        if not self._stats_sunburst_drill_stack:
            self._stats_reset_sunburst_root()
            return
        previous_path = self._stats_sunburst_drill_stack.pop()
        self._stats_apply_sunburst_path(previous_path, push_current=False)

    def _on_stats_sunburst_segment_selected(self, payload: object) -> None:
        if not isinstance(payload, dict) or not payload:
            self._stats_clear_sunburst_selection()
            return
        path = tuple(str(part) for part in payload.get("path", ()) if str(part))
        self._stats_apply_sunburst_path(path, push_current=True)

    def _stats_current_sunburst_mode(self) -> str:
        value = self._stats_sunburst_mode.currentData() if self._stats_sunburst_mode is not None else None
        return str(value or "collection_school_role_attack")

    def _stats_update_sunburst_value_options(self) -> None:
        if self._stats_sunburst_value_mode is None:
            return
        mode = self._stats_current_sunburst_mode()
        if mode == "role_training":
            options = (("직군 평균 육성도", "training_avg"), ("학생 수", "student_count"), ("보유 학생만", "owned_count"))
            default = "training_avg"
        elif mode.startswith("collection_") or mode == "skill_function":
            options = (("학생 수", "student_count"), ("보유 학생만", "owned_count"), ("계획 학생만", "planned_count"))
            default = "student_count"
        elif mode == "plan_required":
            options = (("필요 비율", "required"), ("충족률", "coverage"), ("부족 비율", "shortage"))
            default = "required"
        else:
            options = (("부족 비율", "shortage"), ("필요 비율", "required"), ("충족률", "coverage"))
            default = "shortage"
        current = self._stats_sunburst_value_key()
        if current not in {value for _label, value in options}:
            current = default
        self._stats_sunburst_value_mode.blockSignals(True)
        self._stats_sunburst_value_mode.clear()
        for label, value in options:
            self._stats_sunburst_value_mode.addItem(label, value)
        selected_index = next((index for index, (_label, value) in enumerate(options) if value == current), 0)
        self._stats_sunburst_value_mode.setCurrentIndex(selected_index)
        self._stats_sunburst_value_mode.blockSignals(False)
        return
        if mode.startswith("collection_") or mode == "skill_function":
            options = (("학생 수", "student_count"), ("보유 학생", "owned_count"), ("계획 학생", "planned_count"))
            default = "student_count"
        elif mode == "plan_required":
            options = (("필요 비율", "required"), ("충족률", "coverage"), ("부족 비율", "shortage"))
            default = "required"
        else:
            options = (("부족 비율", "shortage"), ("필요 비율", "required"), ("충족률", "coverage"))
            default = "shortage"
        current = self._stats_sunburst_value_key()
        if current not in {value for _label, value in options}:
            current = default
        self._stats_sunburst_value_mode.blockSignals(True)
        self._stats_sunburst_value_mode.clear()
        for label, value in options:
            self._stats_sunburst_value_mode.addItem(label, value)
        selected_index = next((index for index, (_label, value) in enumerate(options) if value == current), 0)
        self._stats_sunburst_value_mode.setCurrentIndex(selected_index)
        self._stats_sunburst_value_mode.blockSignals(False)

    def _stats_node_for_path(self, root: SunburstNode, path: tuple[str, ...]) -> SunburstNode | None:
        if not path:
            return root
        parts = list(path)
        if parts and parts[0] == root.label:
            parts = parts[1:]
        node = root
        for part in parts:
            found = next((child for child in node.children if child.label == part), None)
            if found is None and self._stats_sunburst is not None:
                display_nodes = self._stats_sunburst._display_nodes(node.children)
                found = next((child for child in display_nodes if child.label == part), None)
            if found is None:
                return None
            node = found
        return node

    def _stats_apply_sunburst_path(self, path: tuple[str, ...], *, push_current: bool) -> None:
        root = self._stats_sunburst_root()
        if not path or path == (root.label,):
            self._stats_reset_sunburst_root()
            return
        node = self._stats_node_for_path(root, path)
        if node is None:
            self._stats_reset_sunburst_root()
            return
        if push_current and self._stats_sunburst_selected_path != path:
            self._stats_sunburst_drill_stack.append(self._stats_sunburst_selected_path)
        self._stats_sunburst_selected_path = path
        self._stats_sunburst_breadcrumb_path = path
        context = dict(node.context or {})
        context["node"] = node
        self._stats_sunburst_selected_context = context
        self._stats_sunburst_selected_node = node
        self._refresh_stats_tab()

    def _stats_sunburst_value_key(self) -> str:
        value = self._stats_sunburst_value_mode.currentData() if self._stats_sunburst_value_mode is not None else None
        return str(value or "student_count")

    def _stats_scope_student_ids(self) -> set[str] | None:
        value = self._stats_sunburst_selected_context.get("student_ids")
        if isinstance(value, set):
            return {str(item) for item in value}
        if isinstance(value, (list, tuple)):
            return {str(item) for item in value}
        return None

    def _stats_scope_records(self) -> list[StudentRecord]:
        student_ids = self._stats_scope_student_ids()
        if not student_ids:
            return list(self._filtered_students)
        return [record for record in self._filtered_students if record.student_id in student_ids]

    def _stats_option_combo(
        self,
        layout: QHBoxLayout,
        options: tuple[tuple[str, str], ...],
        current_value: str,
        attr_name: str,
    ) -> QComboBox:
        combo = QComboBox()
        for label, value in options:
            combo.addItem(label, value)
        selected_index = next((index for index, (_label, value) in enumerate(options) if value == current_value), 0)
        combo.setCurrentIndex(selected_index)
        combo.currentIndexChanged.connect(lambda *_args, combo=combo, attr_name=attr_name: self._stats_set_mode(attr_name, str(combo.currentData())))
        layout.addWidget(combo, 0, Qt.AlignRight)
        return combo

    def _stats_make_rows(self, counts: Counter[str], *, denominator: int | None = None) -> list[DistributionRow]:
        if not counts:
            return []
        total = denominator if denominator is not None else sum(counts.values())
        if total <= 0:
            total = sum(counts.values())
        rows: list[DistributionRow] = []
        ordered = [(label, count) for label, count in counts.items() if count > 0]
        for index, (label, count) in enumerate(sorted(ordered, key=lambda item: (-item[1], item[0].casefold()))):
            percent = (count / total * 100.0) if total else 0.0
            rows.append(DistributionRow(label=label, count=count, percent=percent, color=PALETTE[index % len(PALETTE)]))
        return rows

    def _stats_resource_weight(self, amount: int | float, basis: int | float) -> float:
        if basis <= 0:
            return 0.0
        return max(0.0, float(amount) / float(basis) * 100.0)

    def _stats_resource_weighted_entries(
        self,
        records: list[StudentRecord],
        goal_map: dict[str, StudentGoal],
        *,
        shortage_only: bool = False,
    ) -> list[tuple[StudentRecord, PlanResourceRequirement, float, int]]:
        weighted: list[tuple[StudentRecord, PlanResourceRequirement, float, int]] = []
        for record in records:
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
            if summary is None:
                continue
            entries = self._plan_requirement_entries(summary, record=record)
            if shortage_only:
                basis = sum(max(0, entry.required - entry.owned) for entry in entries)
            else:
                basis = sum(entry.required for entry in entries)
            if basis <= 0:
                continue
            for entry in entries:
                shortage = max(0, entry.required - entry.owned)
                amount = shortage if shortage_only else entry.required
                weight = self._stats_resource_weight(amount, basis)
                if weight > 0:
                    weighted.append((record, entry, weight, shortage))
        return weighted

    def _stats_field_rows(self, field_name: str, *, records: list[StudentRecord] | None = None, multi: bool = False) -> list[DistributionRow]:
        records = list(self._stats_scope_records() if records is None else records)
        if field_name == "owned":
            return build_distribution(records, field_name)
        counts: Counter[str] = Counter()
        for record in records:
            values = get_student_values(record, field_name)
            if not values:
                counts["(없음)"] += 1
                continue
            selected_values = values if multi else values[:1]
            for value in selected_values:
                counts[format_filter_value(field_name, value)] += 1
        return self._stats_make_rows(counts, denominator=len(records))

    @staticmethod
    def _stats_bucket(number: int, buckets: tuple[tuple[int, int, str], ...], empty_label: str = "미확인") -> str:
        if number <= 0:
            return empty_label
        for low, high, label in buckets:
            if low <= number <= high:
                return label
        return str(number)

    @staticmethod
    def _stats_summary_has_requirement(summary: PlanCostSummary | None) -> bool:
        if summary is None:
            return False
        if any((summary.credits, summary.level_exp, summary.equipment_exp, summary.weapon_exp)):
            return True
        return any(
            bool(mapping)
            for mapping in (
                summary.star_materials,
                summary.equipment_materials,
                summary.level_exp_items,
                summary.equipment_exp_items,
                summary.weapon_exp_items,
                summary.skill_books,
                summary.ex_ooparts,
                summary.skill_ooparts,
                summary.favorite_item_materials,
                summary.stat_materials,
                summary.stat_levels,
            )
        )

    def _stats_equipment_tier(self, record: StudentRecord, slot_index: int) -> int:
        return _tier_from_item_id_or_name(None, getattr(record, f"equip{slot_index}", None))

    def _stats_growth_score(self, record: StudentRecord) -> float:
        pieces: list[float] = []
        pieces.append(min(1.0, max(0.0, (_int_or_none(record.level) or 0) / MAX_TARGET_LEVEL)))
        pieces.append(min(1.0, max(0.0, record.star / MAX_TARGET_STAR)))
        skills = [
            min(1.0, max(0.0, (_int_or_none(record.ex_skill) or 0) / MAX_TARGET_EX_SKILL)),
            min(1.0, max(0.0, (_int_or_none(record.skill1) or 0) / MAX_TARGET_SKILL)),
            min(1.0, max(0.0, (_int_or_none(record.skill2) or 0) / MAX_TARGET_SKILL)),
            min(1.0, max(0.0, (_int_or_none(record.skill3) or 0) / MAX_TARGET_SKILL)),
        ]
        pieces.append(sum(skills) / len(skills))
        equipment_tiers = [self._stats_equipment_tier(record, index) for index in (1, 2, 3)]
        if any(equipment_tiers):
            pieces.append(sum(min(1.0, max(0.0, tier / MAX_TARGET_EQUIP_TIER)) for tier in equipment_tiers) / 3)
        stat_values = [_int_or_none(record.stat_hp) or 0, _int_or_none(record.stat_atk) or 0, _int_or_none(record.stat_heal) or 0]
        if any(stat_values):
            pieces.append(sum(min(1.0, max(0.0, value / MAX_TARGET_STAT)) for value in stat_values) / 3)
        if record.weapon_state in {"weapon_equipped", "weapon_unlocked_not_equipped"}:
            weapon_level = min(1.0, max(0.0, (_int_or_none(record.weapon_level) or 0) / MAX_TARGET_WEAPON_LEVEL))
            weapon_star = min(1.0, max(0.0, (_int_or_none(record.weapon_star) or 0) / MAX_TARGET_WEAPON_STAR))
            pieces.append((weapon_level + weapon_star) / 2)
        return (sum(pieces) / len(pieces) * 100.0) if pieces else 0.0

    def _stats_training_score(self, record: StudentRecord) -> float:
        return self._stats_growth_score(record)

    def _stats_training_group_rows(self, field_name: str, records: list[StudentRecord]) -> list[DistributionRow]:
        grouped: dict[str, list[float]] = defaultdict(list)
        for record in records:
            values = get_student_values(record, field_name)
            label = format_filter_value(field_name, values[0]) if values else "(없음)"
            grouped[label].append(self._stats_training_score(record))
        rows: list[DistributionRow] = []
        for index, (label, scores) in enumerate(
            sorted(grouped.items(), key=lambda item: (-(sum(item[1]) / max(1, len(item[1]))), item[0].casefold()))
        ):
            average = sum(scores) / max(1, len(scores))
            rows.append(DistributionRow(label=label, count=average, percent=average, color=PALETTE[index % len(PALETTE)]))
        return rows

    def _stats_growth_rows(self, mode: str) -> list[DistributionRow]:
        records = [record for record in self._stats_scope_records() if record.owned]
        counts: Counter[str] = Counter()
        if not records:
            return []
        if mode == "level_bucket":
            buckets = ((1, 34, "Lv 1-34"), (35, 49, "Lv 35-49"), (50, 69, "Lv 50-69"), (70, 84, "Lv 70-84"), (85, 90, "Lv 85-90"))
            for record in records:
                counts[self._stats_bucket(_int_or_none(record.level) or 0, buckets)] += 1
        elif mode == "star":
            for record in records:
                counts[f"{record.star or 0}성"] += 1
        elif mode == "weapon_state":
            return self._stats_field_rows("weapon_state", records=records)
        elif mode == "weapon_star":
            for record in records:
                value = _int_or_none(record.weapon_star) or 0
                counts[f"전무 {value}성" if value else "전무 없음"] += 1
        elif mode == "weapon_level":
            buckets = ((1, 20, "Lv 1-20"), (21, 40, "Lv 21-40"), (41, 50, "Lv 41-50"), (51, 60, "Lv 51-60"))
            for record in records:
                counts[self._stats_bucket(_int_or_none(record.weapon_level) or 0, buckets, "전무 없음")] += 1
        elif mode == "ex_skill":
            for record in records:
                counts[f"EX Lv {(_int_or_none(record.ex_skill) or 0)}"] += 1
        elif mode in {"skill1", "skill2", "skill3"}:
            label_map = {"skill1": "기본", "skill2": "강화", "skill3": "서브"}
            for record in records:
                counts[f"{label_map[mode]} Lv {(_int_or_none(getattr(record, mode)) or 0)}"] += 1
        elif mode == "normal_skill_avg":
            buckets = ((1, 3, "평균 1-3"), (4, 6, "평균 4-6"), (7, 9, "평균 7-9"), (10, 10, "평균 10"))
            for record in records:
                values = [_int_or_none(record.skill1) or 0, _int_or_none(record.skill2) or 0, _int_or_none(record.skill3) or 0]
                counts[self._stats_bucket(round(sum(values) / 3), buckets)] += 1
        elif mode == "equipment_avg":
            buckets = ((1, 3, "평균 T1-T3"), (4, 6, "평균 T4-T6"), (7, 9, "평균 T7-T9"), (10, 10, "평균 T10"))
            for record in records:
                tiers = [self._stats_equipment_tier(record, index) for index in (1, 2, 3)]
                counts[self._stats_bucket(round(sum(tiers) / 3), buckets)] += 1
        elif mode in {"equip1", "equip2", "equip3"}:
            slot_index = int(mode[-1])
            for record in records:
                tier = self._stats_equipment_tier(record, slot_index)
                counts[f"T{tier}" if tier else "미장착"] += 1
        elif mode == "equip4":
            for record in records:
                tier = _tier_from_item_id_or_name(None, record.equip4)
                counts[f"T{tier}" if tier else "없음"] += 1
        elif mode == "equipment_slot_status":
            for record in records:
                for slot_index in (1, 2, 3):
                    tier = self._stats_equipment_tier(record, slot_index)
                    if tier >= MAX_TARGET_EQUIP_TIER:
                        counts["최대 티어"] += 1
                    elif tier > 0:
                        counts["장착"] += 1
                    else:
                        counts["미장착/잠김"] += 1
            return self._stats_make_rows(counts, denominator=len(records) * 3)
        elif mode == "role_training":
            return self._stats_training_group_rows("role", records)
        elif mode in {"ability_hp", "ability_atk", "ability_heal"}:
            field_name = {"ability_hp": "stat_hp", "ability_atk": "stat_atk", "ability_heal": "stat_heal"}[mode]
            buckets = ((1, 5, "1-5"), (6, 10, "6-10"), (11, 15, "11-15"), (16, 20, "16-20"), (21, 24, "21-24"), (25, 25, "25"))
            for record in records:
                counts[self._stats_bucket(_int_or_none(getattr(record, field_name)) or 0, buckets, "0")] += 1
        else:
            buckets = ((1, 39, "0-39%"), (40, 59, "40-59%"), (60, 79, "60-79%"), (80, 94, "80-94%"), (95, 100, "95-100%"))
            for record in records:
                counts[self._stats_bucket(round(self._stats_growth_score(record)), buckets, "0%")] += 1
        return self._stats_make_rows(counts, denominator=len(records))

    def _stats_plan_rows(self, mode: str) -> list[DistributionRow]:
        goal_map = self._plan_goal_map()
        records = self._stats_scope_records()
        planned_records = [record for record in records if record.student_id in goal_map]
        if mode == "plan_membership":
            counts = Counter(
                "계획 있음" if record.student_id in goal_map else "계획 없음"
                for record in records
            )
            return self._stats_make_rows(counts, denominator=len(records))

        if mode == "planned_owned_ratio":
            counts = Counter("보유" if record.owned else "미보유" for record in planned_records)
            return self._stats_make_rows(counts, denominator=len(planned_records))

        if mode == "plan_completion":
            counts: Counter[str] = Counter()
            for record in planned_records:
                summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
                counts["목표 달성"] += int(not self._stats_summary_has_requirement(summary))
                counts["남은 목표 있음"] += int(self._stats_summary_has_requirement(summary))
            return self._stats_make_rows(counts, denominator=max(1, len(planned_records)))

        if mode in {"planned_school", "planned_role", "planned_attack"}:
            field_name = {"planned_school": "school", "planned_role": "role", "planned_attack": "attack_type"}[mode]
            return self._stats_field_rows(field_name, records=planned_records)

        if mode.startswith("target_") or mode == "before_after_change":
            counts: Counter[str] = Counter()
            deltas: Counter[str] = Counter()
            for record in planned_records:
                goal = goal_map.get(record.student_id)
                if goal is None:
                    continue
                target_level = max(_int_or_none(record.level) or 0, int(getattr(goal, "target_level", 0) or 0))
                target_star = self._current_or_target_star(record, goal)
                target_weapon = self._current_or_target_weapon_star(record, goal)
                target_ex = max(_int_or_none(record.ex_skill) or 0, int(getattr(goal, "target_ex_skill", 0) or 0))
                target_skills = [
                    max(_int_or_none(getattr(record, field_name)) or 0, int(getattr(goal, f"target_{field_name}", 0) or 0))
                    for field_name in ("skill1", "skill2", "skill3")
                ]
                target_equips = [
                    max(self._stats_equipment_tier(record, slot_index), int(getattr(goal, f"target_equip{slot_index}_tier", 0) or 0))
                    for slot_index in (1, 2, 3)
                ]
                target_stats = [
                    max(_int_or_none(getattr(record, field_name)) or 0, int(getattr(goal, f"target_{field_name}", 0) or 0))
                    for field_name in ("stat_hp", "stat_atk", "stat_heal")
                ]
                if mode == "target_level":
                    counts[self._stats_bucket(target_level, ((1, 34, "Lv 1-34"), (35, 49, "Lv 35-49"), (50, 69, "Lv 50-69"), (70, 84, "Lv 70-84"), (85, 90, "Lv 85-90")))] += 1
                elif mode == "target_star":
                    counts[f"{target_star}성"] += 1
                elif mode == "target_weapon":
                    counts[f"전무 {target_weapon}성" if target_weapon else "전무 없음"] += 1
                elif mode == "target_ex":
                    counts[f"EX Lv {target_ex}"] += 1
                elif mode == "target_normal_skill":
                    counts[f"평균 Lv {round(sum(target_skills) / 3)}"] += 1
                elif mode == "target_equipment":
                    counts[f"평균 T{round(sum(target_equips) / 3)}"] += 1
                elif mode == "target_ability":
                    counts[f"평균 {round(sum(target_stats) / 3)}"] += 1
                else:
                    deltas["레벨"] += max(0, target_level - (_int_or_none(record.level) or 0))
                    deltas["성급"] += max(0, target_star - self._record_current_star(record))
                    deltas["전무"] += max(0, target_weapon - (int(record.weapon_star or 0)))
                    deltas["EX"] += max(0, target_ex - (_int_or_none(record.ex_skill) or 0))
                    deltas["일반 스킬"] += sum(max(0, target - (_int_or_none(getattr(record, field_name)) or 0)) for target, field_name in zip(target_skills, ("skill1", "skill2", "skill3")))
                    deltas["장비"] += sum(max(0, target - self._stats_equipment_tier(record, slot_index)) for target, slot_index in zip(target_equips, (1, 2, 3)))
                    deltas["능력개방"] += sum(max(0, target - (_int_or_none(getattr(record, field_name)) or 0)) for target, field_name in zip(target_stats, ("stat_hp", "stat_atk", "stat_heal")))
            if mode == "before_after_change":
                return self._stats_make_rows(deltas)
            return self._stats_make_rows(counts, denominator=len(planned_records))

        student_ids = [record.student_id for record in planned_records]
        summary, _selected_count, contributing_count = self._resource_total_for_ids(student_ids, goal_map)
        entries = self._plan_requirement_entries(summary)
        if contributing_count == 0:
            return []

        if mode in {"required_categories", "shortage_categories"}:
            counts: Counter[str] = Counter()
            weighted_entries = self._stats_resource_weighted_entries(
                planned_records,
                goal_map,
                shortage_only=mode == "shortage_categories",
            )
            for _record, entry, weight, _shortage in weighted_entries:
                counts[_plan_resource_category_label(entry.category)] += weight
            return self._stats_make_rows(counts)

        if mode == "expensive_students":
            counts = Counter()
            for record in planned_records:
                summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
                if summary is None:
                    continue
                requirement_count = len(self._plan_requirement_entries(summary, record=record))
                if requirement_count:
                    counts[record.title] = requirement_count
            return self._stats_make_rows(counts)

        if mode == "remaining_growth":
            counts = Counter()
            for record, _entry, weight, _shortage in self._stats_resource_weighted_entries(planned_records, goal_map, shortage_only=True):
                counts[record.title] += weight
            return self._stats_make_rows(counts)

        counts = Counter()
        for _record, entry, weight, _shortage in self._stats_resource_weighted_entries(planned_records, goal_map, shortage_only=True):
            counts[entry.name] += weight
        return self._stats_make_rows(counts)

    def _stats_resource_rows(self, mode: str) -> list[DistributionRow]:
        goal_map = self._plan_goal_map()
        planned_records = [record for record in self._stats_scope_records() if record.student_id in goal_map]
        summary, _selected_count, contributing_count = self._resource_total_for_ids([record.student_id for record in planned_records], goal_map)
        if contributing_count == 0:
            return []
        entries = self._plan_requirement_entries(summary)
        counts: Counter[str] = Counter()

        weighted_required = self._stats_resource_weighted_entries(planned_records, goal_map, shortage_only=False)
        weighted_shortage = self._stats_resource_weighted_entries(planned_records, goal_map, shortage_only=True)

        if mode == "required_totals":
            for _record, entry, weight, _shortage in weighted_required:
                counts[entry.name] += weight
            return self._stats_make_rows(counts)
        if mode == "shortage_categories":
            for _record, entry, weight, _shortage in weighted_shortage:
                counts[_plan_resource_category_label(entry.category)] += weight
            return self._stats_make_rows(counts)
        if mode == "shortage_items":
            for _record, entry, weight, _shortage in weighted_shortage:
                counts[entry.name] += weight
            return self._stats_make_rows(counts)
        if mode == "required_categories":
            for _record, entry, weight, _shortage in weighted_required:
                counts[_plan_resource_category_label(entry.category)] += weight
            return self._stats_make_rows(counts)
        if mode == "school_demand":
            for _record, entry, weight, _shortage in weighted_required:
                for pattern in (r"Item_Icon_Material_ExSkill_([^_]+)_", r"Item_Icon_SkillBook_([^_]+)_"):
                    match = re.match(pattern, entry.key)
                    if match:
                        counts[match.group(1)] += weight
                        break
            return self._stats_make_rows(counts)
        if mode == "oopart_family":
            for _record, entry, weight, _shortage in weighted_required:
                if entry.category not in {"ex_ooparts", "skill_ooparts"}:
                    continue
                family = re.sub(r"\s+T\d+$", "", entry.name).strip() or entry.name
                counts[family] += weight
            return self._stats_make_rows(counts)
        if mode == "equipment_type":
            for _record, entry, weight, _shortage in weighted_required:
                if entry.category != "equipment_materials":
                    continue
                series = _equipment_series_key_from_item(entry.key, entry.name) or re.sub(r"\s+T\d+$", "", entry.name).strip() or entry.name
                counts[_equipment_series_label(series)] += weight
            return self._stats_make_rows(counts)
        if mode == "equipment_tier":
            for _record, entry, weight, _shortage in weighted_required:
                if entry.category != "equipment_materials":
                    continue
                tier = _tier_from_item_id_or_name(entry.key, entry.name)
                counts[f"T{tier}" if tier else "?곗뼱 誘몄긽"] += weight
            return self._stats_make_rows(counts)

        if mode == "required_totals":
            counts["크레딧"] = summary.credits
            counts["활동 보고서 EXP"] = summary.level_exp
            counts["장비 EXP"] = summary.equipment_exp
            counts["무기 EXP"] = summary.weapon_exp
            return self._stats_make_rows(counts)
        if mode == "shortage_categories":
            for entry in entries:
                shortage = max(0, entry.required - entry.owned)
                if shortage:
                    counts[_plan_resource_category_label(entry.category)] += shortage
            return self._stats_make_rows(counts)
        if mode == "required_categories":
            for entry in entries:
                if entry.required:
                    counts[_plan_resource_category_label(entry.category)] += entry.required
            return self._stats_make_rows(counts)
        if mode == "shortage_rate":
            rows: list[DistributionRow] = []
            shortage_rows = [
                (entry.name, max(0, entry.required - entry.owned), entry.required)
                for entry in entries
                if entry.required > 0 and max(0, entry.required - entry.owned) > 0
            ]
            shortage_rows.sort(key=lambda item: (-(item[1] / max(1, item[2])), -item[1], item[0]))
            for index, (name, shortage, required) in enumerate(shortage_rows):
                rows.append(DistributionRow(name, shortage, shortage / max(1, required) * 100.0, PALETTE[index % len(PALETTE)]))
            return rows
        if mode == "school_demand":
            for entry in entries:
                for pattern in (r"Item_Icon_Material_ExSkill_([^_]+)_", r"Item_Icon_SkillBook_([^_]+)_"):
                    match = re.match(pattern, entry.key)
                    if match:
                        counts[match.group(1)] += entry.required
                        break
            return self._stats_make_rows(counts)
        if mode == "oopart_family":
            for entry in entries:
                if entry.category not in {"ex_ooparts", "skill_ooparts"}:
                    continue
                family = re.sub(r"\s+T\d+$", "", entry.name).strip() or entry.name
                counts[family] += entry.required
            return self._stats_make_rows(counts)
        if mode == "equipment_type":
            for entry in entries:
                if entry.category != "equipment_materials":
                    continue
                series = _equipment_series_key_from_item(entry.key, entry.name) or re.sub(r"\s+T\d+$", "", entry.name).strip() or entry.name
                counts[_equipment_series_label(series)] += entry.required
            return self._stats_make_rows(counts)
        if mode == "equipment_tier":
            for entry in entries:
                if entry.category != "equipment_materials":
                    continue
                tier = _tier_from_item_id_or_name(entry.key, entry.name)
                counts[f"T{tier}" if tier else "티어 미상"] += entry.required
            return self._stats_make_rows(counts)

        for entry in entries:
            shortage = max(0, entry.required - entry.owned)
            if shortage:
                counts[entry.name] += shortage
        return self._stats_make_rows(counts)

    def _stats_skill_rows(self, mode: str) -> list[DistributionRow]:
        records = [record for record in self._stats_scope_records() if record.owned]
        if mode == "skill_is_area_damage":
            return self._stats_field_rows("skill_is_area_damage", records=records)
        if mode in {"skill_ignore_cover", "skill_knockback"}:
            return self._stats_field_rows(mode, records=records)
        return self._stats_field_rows(mode, records=records, multi=True)

    def _stats_show_chart_row_detail(self, row: DistributionRow) -> None:
        if self._stats_sunburst_detail is None:
            return
        self._stats_sunburst_detail.setText(
            "\n".join(
                (
                    "Chart selection",
                    f"Label: {row.label}",
                    f"Value: {self._stats_row_count_text(row.count, compact=True)}",
                    f"Share: {row.percent:.1f}%",
                )
            )
        )

    def _stats_row_count_text(self, value: int | float, *, compact: bool = False) -> str:
        try:
            number = float(value)
        except (TypeError, ValueError):
            return _format_count(value, compact=compact)
        if not compact and not number.is_integer():
            return f"{number:,.1f}"
        return _format_count(value, compact=compact)

    def _stats_add_bar_rows(self, layout: QVBoxLayout, rows: list[DistributionRow], *, limit: int = 8, compact_count: bool = False) -> None:
        if not rows:
            empty = QLabel("현재 조건에 맞는 데이터가 없습니다.")
            empty.setObjectName("detailSub")
            layout.addWidget(empty)
            return
        for row in rows[:limit]:
            wrap = QWidget()
            row_layout = QHBoxLayout(wrap)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(scale_px(8, self._ui_scale))
            label = QLabel(row.label)
            label.setObjectName("detailSub")
            label.setFixedWidth(scale_px(132, self._ui_scale))
            label.setToolTip(row.label)
            row_layout.addWidget(label, 0, Qt.AlignVCenter)
            bar = QProgressBar()
            bar.setRange(0, 100)
            bar.setTextVisible(False)
            bar.setFixedHeight(scale_px(8, self._ui_scale))
            bar.setValue(max(0, min(100, int(round(row.percent)))))
            row_layout.addWidget(bar, 1, Qt.AlignVCenter)
            count_text = self._stats_row_count_text(row.count, compact=compact_count)
            value = QLabel(f"{count_text} · {row.percent:.1f}%")
            value.setObjectName("detailSub")
            value.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
            value.setFixedWidth(scale_px(92, self._ui_scale))
            row_layout.addWidget(value, 0, Qt.AlignVCenter)
            wrap.setCursor(Qt.PointingHandCursor)
            wrap.mousePressEvent = lambda event, row=row: self._stats_show_chart_row_detail(row)
            layout.addWidget(wrap)

    def _stats_add_distribution_rows(self, layout: QVBoxLayout, rows: list[DistributionRow]) -> None:
        if not rows:
            empty = QLabel("현재 조건에 맞는 데이터가 없습니다.")
            empty.setObjectName("detailSub")
            layout.addWidget(empty)
            return
        top = rows[0]
        top_wrap = QHBoxLayout()
        donut = DonutWidget(top.percent, top.color, f"{top.percent:.0f}%", self._ui_scale)
        top_wrap.addWidget(donut, 0, Qt.AlignLeft | Qt.AlignVCenter)
        top_text = QVBoxLayout()
        main_label = QLabel(top.label)
        main_label.setObjectName("metricValue")
        count_label = QLabel(f"{self._stats_row_count_text(top.count, compact=True)}")
        count_label.setObjectName("detailSub")
        top_text.addWidget(main_label)
        top_text.addWidget(count_label)
        top_wrap.addLayout(top_text, 1)
        layout.addLayout(top_wrap)
        self._stats_add_bar_rows(layout, rows, limit=5)

    def _stats_add_chart_card(
        self,
        *,
        grid: QGridLayout,
        index: int,
        title: str,
        subtitle: str,
        options: tuple[tuple[str, str], ...],
        current_value: str,
        attr_name: str,
        rows: list[DistributionRow],
        chart_kind: str,
        compact_count: bool = False,
    ) -> None:
        card = QFrame()
        card.setObjectName("statPanel")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(scale_px(16, self._ui_scale), scale_px(16, self._ui_scale), scale_px(16, self._ui_scale), scale_px(16, self._ui_scale))
        card_layout.setSpacing(scale_px(10, self._ui_scale))
        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        title_wrap = QVBoxLayout()
        title_label = QLabel(title)
        title_label.setObjectName("sectionTitle")
        subtitle_label = QLabel(subtitle)
        subtitle_label.setObjectName("detailSub")
        subtitle_label.setWordWrap(True)
        title_wrap.addWidget(title_label)
        title_wrap.addWidget(subtitle_label)
        header.addLayout(title_wrap, 1)
        self._stats_option_combo(header, options, current_value, attr_name)
        card_layout.addLayout(header)
        if chart_kind == "distribution":
            self._stats_add_distribution_rows(card_layout, rows)
        else:
            self._stats_add_bar_rows(card_layout, rows, compact_count=compact_count)
        grid.addWidget(card, index // 2, index % 2)

    def _stats_value_label(self, record: StudentRecord, field_name: str) -> str:
        if field_name == "owned":
            return "보유" if record.owned else "미보유"
        value = get_student_value(record, field_name)
        return format_filter_value(field_name, value) if value else "(누락)"

    def _sunburst_context_merge(self, current: dict[str, object], incoming: dict[str, object]) -> None:
        for key in ("student_ids", "resource_keys", "categories"):
            value = incoming.get(key)
            if value is None:
                continue
            target = current.setdefault(key, set())
            if isinstance(target, set):
                if isinstance(value, (set, list, tuple)):
                    target.update(str(item) for item in value)
                else:
                    target.add(str(value))
        for key in ("required", "owned", "shortage"):
            value = incoming.get(key)
            if value is None:
                continue
            try:
                current[key] = float(current.get(key, 0.0) or 0.0) + float(value)
            except (TypeError, ValueError):
                pass
        for key in ("training_score_sum", "training_count"):
            value = incoming.get(key)
            if value is None:
                continue
            try:
                current[key] = float(current.get(key, 0.0) or 0.0) + float(value)
            except (TypeError, ValueError):
                pass
        impacts = incoming.get("impacts")
        if isinstance(impacts, list):
            current.setdefault("impacts", [])
            if isinstance(current["impacts"], list):
                current["impacts"].extend(impacts)

    def _sunburst_tree_from_paths(self, title: str, paths: list[tuple], *, value_mode: str | None = None) -> SunburstNode:
        tree: dict[str, dict] = {}

        for item in paths:
            if len(item) == 2:
                raw_path, raw_value = item
                context = {}
            else:
                raw_path, raw_value, context = item
            value = float(raw_value or 0)
            if value <= 0:
                continue
            cursor = tree
            if isinstance(context, dict):
                self._sunburst_context_merge(cursor.setdefault("_context", {}), context)
            for part in raw_path:
                label = str(part or "(누락)")
                cursor = cursor.setdefault(label, {})
                if isinstance(context, dict):
                    self._sunburst_context_merge(cursor.setdefault("_context", {}), context)
            cursor["_value"] = float(cursor.get("_value", 0.0)) + value

        def build(label: str, branch: dict) -> SunburstNode:
            children = [
                build(child_label, child_branch)
                for child_label, child_branch in branch.items()
                if child_label not in {"_value", "_context"}
            ]
            children.sort(key=lambda child: (-child.total(), child.label.casefold()))
            context = dict(branch.get("_context", {}) or {})
            node_value = float(branch.get("_value", 0.0))
            if value_mode == "coverage":
                required = float(context.get("required", 0.0) or 0.0)
                owned = float(context.get("owned", 0.0) or 0.0)
                node_value = 100.0 if required <= 0 and owned > 0 else max(0.0, min(100.0, owned / required * 100.0)) if required > 0 else 0.0
                context["value_mode"] = "coverage"
            elif value_mode == "training_avg":
                score_sum = float(context.get("training_score_sum", 0.0) or 0.0)
                score_count = float(context.get("training_count", 0.0) or 0.0)
                node_value = max(0.0, min(100.0, score_sum / score_count)) if score_count > 0 else 0.0
                context["value_mode"] = "training_avg"
            node = SunburstNode(label=label, value=node_value, children=children, context=context)
            node.context = context | {"node": node}
            return node

        root = build(title, tree)
        return root

    def _collection_sunburst_root(self, mode: str) -> SunburstNode:
        if mode == "collection_class_role_position":
            fields = ("combat_class", "role", "position")
            title = "Visible Students"
        elif mode == "collection_attack_defense_role":
            fields = ("attack_type", "defense_type", "role")
            title = "Visible Students"
        else:
            fields = ("school", "role", "attack_type")
            title = "Visible Students"
        value_key = self._stats_sunburst_value_key()
        goal_map = self._plan_goal_map()
        records = list(self._filtered_students)
        paths = [
            (
                tuple(self._stats_value_label(record, field_name) for field_name in fields),
                1.0,
                {"student_ids": {record.student_id}},
            )
            for record in records
            if value_key == "student_count"
            or (value_key == "owned_count" and record.owned)
            or (value_key == "planned_count" and record.student_id in goal_map)
        ]
        return self._sunburst_tree_from_paths(title, paths)

    @staticmethod
    def _stats_training_bucket_label(score: float) -> str:
        if score >= 90:
            return "90-100%"
        if score >= 75:
            return "75-89%"
        if score >= 60:
            return "60-74%"
        if score >= 40:
            return "40-59%"
        return "0-39%"

    def _role_training_sunburst_root(self) -> SunburstNode:
        value_key = self._stats_sunburst_value_key()
        records = list(self._filtered_students)
        paths: list[tuple] = []
        value_mode: str | None = "training_avg" if value_key == "training_avg" else None
        for record in records:
            if value_key in {"training_avg", "owned_count"} and not record.owned:
                continue
            score = self._stats_training_score(record)
            role_label = self._stats_value_label(record, "role")
            bucket_label = self._stats_training_bucket_label(score)
            if value_key == "student_count" or value_key == "owned_count":
                value = 1.0
            else:
                value = score
            paths.append(
                (
                    (role_label, bucket_label),
                    value,
                    {
                        "student_ids": {record.student_id},
                        "training_score_sum": score,
                        "training_count": 1,
                    },
                )
            )
        return self._sunburst_tree_from_paths("직군별 육성도", paths, value_mode=value_mode if paths else None)

    def _skill_book_sunburst_path(self, item_id: str, name: str) -> tuple[str, ...]:
        if "SkillBook_Ultimate" in item_id or "Ultimate" in item_id:
            return ("Skills", "Secret Notes", name)
        match = re.match(r"Item_Icon_Material_ExSkill_([^_]+)_(\d+)", item_id)
        if match:
            return ("Skills", "Tactical BD", match.group(1), f"T{int(match.group(2)) + 1}")
        match = re.match(r"Item_Icon_SkillBook_([^_]+)_(\d+)", item_id)
        if match:
            return ("스킬", "기술 노트", match.group(1), f"T{int(match.group(2)) + 1}")
        base, tier = _plan_resource_split_tier(name)
        school, _, kind = base.partition(" ")
        if school and kind:
            return ("스킬", kind, school, f"T{tier}" if tier else name)
        return ("스킬", "기타", name)

    def _oopart_sunburst_path(self, group: str, item_id: str, name: str) -> tuple[str, ...]:
        tier = _tier_from_item_id_or_name(item_id, name)
        family = name
        if tier:
            family = re.sub(r"\s+T\d+$", "", name).strip() or name
        return ("오파츠", group, family, f"T{tier}" if tier else name)

    def _equipment_sunburst_path(self, item_id: str, name: str) -> tuple[str, ...]:
        tier = _tier_from_item_id_or_name(item_id, name)
        series_key = _equipment_series_key_from_item(item_id, name)
        series = series_key or re.sub(r"\s+T\d+$", "", name).strip() or name
        return ("장비", "설계도", series, f"T{tier}" if tier else name)

    def _resource_sunburst_root(self, *, shortage_only: bool) -> SunburstNode:
        goal_map = self._plan_goal_map()
        records = [record for record in self._filtered_students if record.student_id in goal_map]
        value_key = self._stats_sunburst_value_key()
        paths: list[tuple] = []

        def resource_path(entry: PlanResourceRequirement) -> tuple[str, ...]:
            item_id = entry.key
            if entry.category == "credits":
                return ("재화", entry.name)
            if entry.category == "level_exp":
                return ("레벨", "활동 보고서", entry.name)
            if entry.category == "equipment_exp":
                return ("장비", "경험치", entry.name)
            if entry.category == "weapon_exp":
                return ("전용무기", "경험치", entry.name)
            if entry.category == "skill_books":
                return self._skill_book_sunburst_path(item_id, entry.name)
            if entry.category == "ex_ooparts":
                return self._oopart_sunburst_path("EX 스킬", item_id, entry.name)
            if entry.category == "skill_ooparts":
                return self._oopart_sunburst_path("일반 스킬", item_id, entry.name)
            if entry.category == "stat_materials":
                return ("능력개방", entry.name)
            if entry.category == "favorite_item_materials":
                return ("애용품", entry.name)
            if entry.category == "equipment_materials":
                return self._equipment_sunburst_path(item_id, entry.name)
            if entry.category == "star_materials":
                return ("성작 / 전용무기", "엘레프", entry.name)
            return ("기타", entry.category, entry.name)

        for record in records:
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
            if summary is None:
                continue
            entries = self._plan_requirement_entries(summary, record=record)
            required_basis = sum(entry.required for entry in entries)
            shortage_basis = sum(max(0, entry.required - entry.owned) for entry in entries)
            for entry in entries:
                shortage = max(0, entry.required - entry.owned)
                if value_key == "coverage":
                    value = 100.0 if entry.required <= 0 else max(0.0, min(100.0, (entry.owned / entry.required) * 100.0))
                elif shortage_only or value_key == "shortage":
                    value = self._stats_resource_weight(shortage, shortage_basis)
                else:
                    value = self._stats_resource_weight(entry.required, required_basis)
                if value <= 0:
                    continue
                base_path = resource_path(entry)
                path = (*base_path, record.title) if shortage_only else base_path
                paths.append(
                    (
                        path,
                        value,
                        {
                            "student_ids": {record.student_id},
                            "resource_keys": {entry.key},
                            "categories": {entry.category},
                            "required": entry.required,
                            "owned": entry.owned,
                            "shortage": shortage,
                            "weight": value,
                            "impacts": [(record.student_id, record.title, entry.name, int(entry.required), int(shortage))],
                        },
                    )
                )

        title = "계획 부족" if shortage_only else "계획 필요"
        return self._sunburst_tree_from_paths(title, paths, value_mode="coverage" if value_key == "coverage" else None)

    def _skill_function_sunburst_root(self) -> SunburstNode:
        records = [record for record in self._filtered_students if record.owned]
        groups = (
            ("버프", "skill_buff"),
            ("디버프", "skill_debuff"),
            ("CC", "skill_cc"),
            ("특수 효과", "skill_special"),
            ("회복", "skill_heal_targets"),
            ("해제", "skill_dispel_targets"),
            ("이동", "skill_reposition_targets"),
            ("소환", "skill_summon_types"),
            ("패시브", "passive_stat"),
            ("전무 패시브", "weapon_passive_stat"),
            ("추가 패시브", "extra_passive_stat"),
        )
        paths: list[tuple] = []
        for record in records:
            for group_label, field_name in groups:
                for value in get_student_values(record, field_name):
                    label = format_filter_value(field_name, value)
                    paths.append(((group_label, label, record.title), 1.0, {"student_ids": {record.student_id}}))
            for field_name, label in (
                ("skill_is_area_damage", "EX 범위 공격"),
                ("skill_ignore_cover", "엄폐 무시"),
                ("skill_knockback", "넉백"),
            ):
                value = get_student_value(record, field_name)
                if value:
                    paths.append(((label, format_filter_value(field_name, value), record.title), 1.0, {"student_ids": {record.student_id}}))
        return self._sunburst_tree_from_paths("기능 맵", paths)

    def _stats_sunburst_root(self) -> SunburstNode:
        mode = self._stats_sunburst_mode.currentData() if self._stats_sunburst_mode is not None else None
        if mode == "plan_required":
            return self._resource_sunburst_root(shortage_only=False)
        if mode == "plan_shortage":
            return self._resource_sunburst_root(shortage_only=True)
        if mode == "skill_function":
            return self._skill_function_sunburst_root()
        if mode == "role_training":
            return self._role_training_sunburst_root()
        return self._collection_sunburst_root(str(mode or "collection_school_role_attack"))

    def _stats_rebuild_sunburst_breadcrumb(self, breadcrumb: tuple[str, ...]) -> None:
        layout = self._stats_sunburst_breadcrumb_layout
        if layout is None:
            return
        self._clear_layout_widgets(layout)
        if not breadcrumb:
            button = QPushButton("전체")
            button.setFixedHeight(scale_px(24, self._ui_scale))
            button.clicked.connect(self._stats_reset_sunburst_root)
            layout.addWidget(button, 0, Qt.AlignLeft)
            layout.addStretch(1)
            return
        for index, part in enumerate(breadcrumb):
            if index:
                separator = QLabel(">")
                separator.setObjectName("filterSummary")
                layout.addWidget(separator, 0, Qt.AlignLeft)
            button = QPushButton(part)
            button.setFixedHeight(scale_px(24, self._ui_scale))
            if index == 0:
                button.clicked.connect(self._stats_reset_sunburst_root)
            else:
                target_path = tuple(breadcrumb[: index + 1])
                button.clicked.connect(lambda _checked=False, path=target_path: self._stats_apply_sunburst_path(path, push_current=True))
            layout.addWidget(button, 0, Qt.AlignLeft)
        layout.addStretch(1)

    def _stats_update_sunburst_legend(self, root: SunburstNode) -> None:
        layout = self._stats_sunburst_legend_layout
        if layout is None:
            return
        self._clear_layout_widgets(layout)
        if self._stats_sunburst is None or not root.children:
            empty = QLabel("표시할 경로가 없습니다.")
            empty.setObjectName("detailSub")
            empty.setWordWrap(True)
            layout.addWidget(empty)
            return
        max_depth = max(1, self._stats_sunburst._display_depth(root, is_root=True))
        levels: dict[int, dict[str, dict[str, object]]] = defaultdict(dict)

        def collect(nodes: list[SunburstNode], depth: int, path: tuple[str, ...]) -> None:
            for index, node in enumerate(nodes):
                value = node.total()
                if value <= 0:
                    continue
                current_path = (*path, node.label)
                level = levels[depth]
                entry = level.setdefault(
                    node.label,
                    {
                        "value": 0.0,
                        "color": SunburstWidget._node_color(node, index, depth, max_depth),
                        "paths": [],
                    },
                )
                entry["value"] = float(entry.get("value", 0.0) or 0.0) + value
                paths = entry.get("paths")
                if isinstance(paths, list) and len(paths) < 6:
                    paths.append(current_path)
                if node.children and not (node.context or {}).get("other"):
                    child_nodes = self._stats_sunburst._display_nodes(node.children)
                    collect(child_nodes, depth + 1, current_path)

        collect(self._stats_sunburst._display_nodes(root.children), 1, (root.label,))
        max_rows_per_level = 12
        for depth in sorted(levels):
            entries = sorted(levels[depth].items(), key=lambda item: (-float(item[1].get("value", 0.0) or 0.0), item[0].casefold()))
            if not entries:
                continue
            self._stats_add_sunburst_legend_header(
                layout,
                depth,
                max_depth,
                SunburstWidget._node_color(SunburstNode("Level"), 0, depth, max_depth),
            )
            level_total = sum(float(entry.get("value", 0.0) or 0.0) for _label, entry in entries)
            visible_entries = entries[:max_rows_per_level]
            for entry_index, (label, entry) in enumerate(visible_entries):
                value = float(entry.get("value", 0.0) or 0.0)
                percent = (value / level_total * 100.0) if level_total else 0.0
                paths = entry.get("paths")
                path_tuple = tuple(paths[0]) if isinstance(paths, list) and paths else (root.label, label)
                tooltip_paths = [" > ".join(path) for path in paths] if isinstance(paths, list) else []
                self._stats_add_sunburst_legend_row(
                    layout,
                    label,
                    str(entry.get("color") or "#6f7f8f"),
                    percent,
                    depth,
                    path_tuple,
                    tooltip="\n".join(tooltip_paths),
                    height_index=entry_index,
                    height_total=len(visible_entries),
                )
            if len(entries) > max_rows_per_level:
                more = QLabel(f"+ {len(entries) - max_rows_per_level} more")
                more.setObjectName("detailSub")
                layout.addWidget(more)
    def _stats_add_sunburst_legend_header(self, layout: QVBoxLayout, depth: int, max_depth: int, color: str) -> None:
        row = QWidget()
        row_layout = QHBoxLayout(row)
        row_layout.setContentsMargins(0, scale_px(4, self._ui_scale), 0, 0)
        row_layout.setSpacing(scale_px(6, self._ui_scale))
        swatch = QLabel("")
        swatch.setFixedSize(scale_px(10, self._ui_scale), scale_px(10, self._ui_scale))
        swatch.setStyleSheet(f"background: {color}; border-radius: {scale_px(2, self._ui_scale)}px;")
        row_layout.addWidget(swatch, 0, Qt.AlignVCenter)
        position = "내부" if depth == 1 else "외부" if depth == max_depth else "중간"
        header = QLabel(f"Level {depth} · {position}")
        header.setObjectName("detailSub")
        header.setStyleSheet("font-weight: 800; color: #d8e7f3;")
        row_layout.addWidget(header, 1, Qt.AlignVCenter)
        layout.addWidget(row)

    def _stats_add_sunburst_legend_row(
        self,
        layout: QVBoxLayout,
        label_text: str,
        color: str,
        percent: float,
        depth: int,
        path: tuple[str, ...],
        tooltip: str | None = None,
        height_index: int = 0,
        height_total: int = 1,
    ) -> None:
        row = QWidget()
        row.setFixedHeight(scale_px(20, self._ui_scale))
        row_layout = QHBoxLayout(row)
        row_layout.setContentsMargins(scale_px(max(0, depth - 1) * 14, self._ui_scale), 0, 0, 0)
        row_layout.setSpacing(scale_px(6, self._ui_scale))
        swatch = QLabel("")
        ratio = (height_total - height_index) / max(1, height_total)
        swatch_height = scale_px(4 + ratio * 10, self._ui_scale)
        swatch.setFixedSize(scale_px(9, self._ui_scale), swatch_height)
        swatch.setStyleSheet(f"background: {color}; border-radius: {scale_px(2, self._ui_scale)}px;")
        row_layout.addWidget(swatch, 0, Qt.AlignVCenter)
        label = QLabel(label_text)
        label.setObjectName("detailSub")
        label.setToolTip(tooltip or " > ".join(path))
        row_layout.addWidget(label, 1, Qt.AlignVCenter)
        value_label = QLabel(f"{percent:.1f}%")
        value_label.setObjectName("detailSub")
        value_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        value_label.setFixedWidth(scale_px(48, self._ui_scale))
        row_layout.addWidget(value_label, 0, Qt.AlignVCenter)
        layout.addWidget(row)

    def _stats_update_sunburst_detail_panel(self, display_root: SunburstNode, breadcrumb: tuple[str, ...]) -> None:
        required_widgets = (
            self._stats_detail_path_label,
            self._stats_detail_name_label,
            self._stats_detail_level_label,
            self._stats_detail_total_label,
            self._stats_detail_metric_count_label,
            self._stats_detail_metric_percent_label,
            self._stats_detail_owned_bar,
            self._stats_detail_owned_bar_label,
            self._stats_detail_owned_label,
            self._stats_detail_unowned_label,
            self._stats_detail_planned_label,
        )
        if any(widget is None for widget in required_widgets):
            return
        context = dict(display_root.context or {})
        if self._stats_sunburst_selected_context:
            context |= self._stats_sunburst_selected_context
        path = self._stats_sunburst_selected_path or breadcrumb or (display_root.label,)
        level = max(0, len(path) - 1)
        label = path[-1] if path else display_root.label
        student_ids_raw = context.get("student_ids")
        student_ids = {str(item) for item in student_ids_raw} if isinstance(student_ids_raw, set) else set()
        if not student_ids and isinstance(student_ids_raw, (list, tuple)):
            student_ids = {str(item) for item in student_ids_raw}
        scoped_records = [record for record in self._filtered_students if not student_ids or record.student_id in student_ids]
        total_students = len(scoped_records)
        owned = sum(1 for record in scoped_records if record.owned)
        unowned = max(0, total_students - owned)
        goal_map = self._plan_goal_map()
        planned = sum(1 for record in scoped_records if record.student_id in goal_map)
        percent = (total_students / max(1, len(self._filtered_students)) * 100.0) if self._filtered_students else 0.0
        owned_rate = owned / max(1, total_students) * 100.0 if total_students else 0.0
        training_sum = float(context.get("training_score_sum", 0.0) or 0.0)
        training_count = float(context.get("training_count", 0.0) or 0.0)
        total_text = f"{training_sum / training_count:.1f}%" if training_count > 0 else f"{total_students:,}"

        self._stats_detail_path_label.setText(f"L{level}: {label}")
        self._stats_detail_name_label.setText(label)
        self._stats_detail_level_label.setText(f"Level {level}")
        self._stats_detail_total_label.setText(total_text)
        self._stats_detail_metric_count_label.setText(f"{total_students:,}")
        self._stats_detail_metric_percent_label.setText(f"{percent:.1f}%")
        self._stats_detail_owned_bar.setValue(max(0, min(100, int(round(owned_rate)))))
        self._stats_detail_owned_bar_label.setText(f"{owned_rate:.1f}%")
        self._stats_detail_owned_label.setText(f"보유\n{owned:,}")
        self._stats_detail_unowned_label.setText(f"미보유\n{unowned:,}")
        self._stats_detail_planned_label.setText(f"계획\n{planned:,}")

    def _refresh_stats_sunburst(self) -> None:
        if self._stats_sunburst is None or self._stats_sunburst_detail is None or self._stats_sunburst_top_detail is None:
            return
        root = self._stats_sunburst_root()
        breadcrumb = self._stats_sunburst_breadcrumb_path or (root.label,)
        display_root = self._stats_node_for_path(root, breadcrumb) or root
        if display_root is root:
            breadcrumb = (root.label,)
        self._stats_sunburst.setRoot(display_root, selected_path=(), breadcrumb=breadcrumb)
        self._stats_rebuild_sunburst_breadcrumb(breadcrumb)
        self._stats_update_sunburst_legend(display_root)
        self._stats_update_sunburst_detail_panel(display_root, breadcrumb)
        if self._stats_sunburst_root_button is not None:
            self._stats_sunburst_root_button.setEnabled(display_root is not root or bool(self._stats_sunburst_selected_path))
        if self._stats_sunburst_back_button is not None:
            self._stats_sunburst_back_button.setEnabled(bool(self._stats_sunburst_drill_stack))
        if self._stats_sunburst_clear_button is not None:
            self._stats_sunburst_clear_button.setEnabled(bool(self._stats_sunburst_selected_context))
        if not display_root.children:
            self._stats_sunburst_top_detail.setText("현재 모드와 필터에 맞는 데이터가 없습니다.")
            self._stats_sunburst_detail.setText("선택된 segment가 없습니다.")
            return
        total = display_root.total()
        top_lines = [f"Root: {' > '.join(breadcrumb)}", f"Total: {total:,.0f}"]
        for child in sorted(display_root.children, key=lambda node: (-node.total(), node.label.casefold()))[:8]:
            percent = (child.total() / total * 100.0) if total else 0.0
            top_lines.append(f"{child.label}: {child.total():,.0f} ({percent:.1f}%)")
        self._stats_sunburst_top_detail.setText("\n".join(top_lines))

        context = self._stats_sunburst_selected_context
        lines: list[str] = []
        if context:
            required = float(context.get("required", 0.0) or 0.0)
            owned = float(context.get("owned", 0.0) or 0.0)
            shortage = float(context.get("shortage", 0.0) or 0.0)
            student_ids = context.get("student_ids")
            student_count = len(student_ids) if isinstance(student_ids, set) else 0
            if self._stats_sunburst_selected_path:
                lines.append("Path: " + " > ".join(self._stats_sunburst_selected_path))
            if student_count:
                lines.append(f"Students: {student_count:,}")
            training_sum = float(context.get("training_score_sum", 0.0) or 0.0)
            training_count = float(context.get("training_count", 0.0) or 0.0)
            if training_count > 0:
                lines.append(f"Training: {training_sum / training_count:.1f}%")
            if required or owned or shortage:
                coverage = 100.0 if required <= 0 else max(0.0, min(100.0, owned / required * 100.0))
                lines.append(f"Required: {_format_count(required, compact=True)}")
                lines.append(f"Owned: {_format_count(owned, compact=True)}")
                lines.append(f"Shortage: {_format_count(shortage, compact=True)}")
                lines.append(f"Coverage: {coverage:.1f}%")
            impacts = context.get("impacts")
            if isinstance(impacts, list) and impacts:
                lines.append("Impact TOP")
                for impact in sorted(impacts, key=lambda item: (-(item[4] if len(item) > 4 else 0), str(item[1])))[:6]:
                    if len(impact) >= 5:
                        lines.append(f"- {impact[1]}: {impact[2]} {_format_count(impact[3], compact=True)} / 부족 {_format_count(impact[4], compact=True)}")
        self._stats_sunburst_detail.setText("\n".join(lines) if lines else "선택된 segment가 없습니다.")

    def _refresh_stats_tab(self) -> None:
        if self._stats_cards_layout is None or self._stats_summary_host is None:
            return

        while self._stats_summary_cards.count():
            item = self._stats_summary_cards.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()

        while self._stats_cards_layout.count():
            item = self._stats_cards_layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()

        records = self._stats_scope_records()
        total = len(records)
        owned = sum(1 for record in records if record.owned)
        unowned = max(0, total - owned)
        goal_map = self._plan_goal_map()
        planned = sum(1 for record in records if record.student_id in goal_map)
        owned_records = [record for record in records if record.owned]
        planned_records = [record for record in records if record.student_id in goal_map]
        avg_level = round(sum((_int_or_none(record.level) or 0) for record in owned_records) / max(1, owned), 1) if owned else 0
        avg_star = round(sum(record.star for record in owned_records) / max(1, owned), 1) if owned else 0
        weapon_records = [record for record in owned_records if record.weapon_state in {"weapon_equipped", "weapon_unlocked_not_equipped"}]
        avg_weapon = round(sum((_int_or_none(record.weapon_level) or 0) for record in weapon_records) / max(1, len(weapon_records)), 1) if weapon_records else 0
        avg_ex = round(sum((_int_or_none(record.ex_skill) or 0) for record in owned_records) / max(1, owned), 1) if owned else 0
        normal_skill_values = [
            (_int_or_none(record.skill1) or 0) + (_int_or_none(record.skill2) or 0) + (_int_or_none(record.skill3) or 0)
            for record in owned_records
        ]
        avg_normal_skill = round(sum(normal_skill_values) / max(1, owned * 3), 1) if owned else 0
        avg_equip = round(
            sum(sum(self._stats_equipment_tier(record, index) for index in (1, 2, 3)) for record in owned_records) / max(1, owned * 3),
            1,
        ) if owned else 0
        avg_ability = round(
            sum((_int_or_none(record.stat_hp) or 0) + (_int_or_none(record.stat_atk) or 0) + (_int_or_none(record.stat_heal) or 0) for record in owned_records) / max(1, owned * 3),
            1,
        ) if owned else 0
        avg_score = round(sum(self._stats_growth_score(record) for record in owned_records) / max(1, owned), 1) if owned else 0
        avg_training = round(sum(self._stats_training_score(record) for record in owned_records) / max(1, owned), 1) if owned else 0
        complete_count = 0
        for record in planned_records:
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
            if not self._stats_summary_has_requirement(summary):
                complete_count += 1
        completion = round(complete_count / max(1, len(planned_records)) * 100.0, 1) if planned_records else 0
        planned_summary, _selected_count, contributing_count = self._resource_total_for_ids([record.student_id for record in planned_records], goal_map)
        shortage_count = 0
        if contributing_count:
            shortage_count = sum(1 for entry in self._plan_requirement_entries(planned_summary) if entry.required > entry.owned)

        summary_cards = (
            ("표시 중 학생", str(total), "현재 필터 기준"),
            ("보유율", f"{(owned / max(1, total) * 100.0):.1f}%", f"{owned} / {total}"),
            ("계획 편입률", f"{(planned / max(1, total) * 100.0):.1f}%", f"{planned} / {total}"),
            ("평균 레벨 / 성급", f"Lv.{avg_level} / ★{avg_star}", "보유 학생 기준"),
            ("육성 완성도", f"{avg_training:.1f}%", "기존 종합 점수 기준"),
        )
        for index, (label, value, sub) in enumerate(summary_cards):
            card = QFrame()
            card.setObjectName("summaryCard")
            card_layout = QVBoxLayout(card)
            card_layout.setContentsMargins(scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale))
            text_label = QLabel(label)
            text_label.setObjectName("metricLabel")
            value_label = QLabel(value)
            value_label.setObjectName("metricValue")
            sub_label = QLabel(sub)
            sub_label.setObjectName("kpiValueSub")
            card_layout.addWidget(text_label)
            card_layout.addWidget(value_label)
            card_layout.addWidget(sub_label)
            self._stats_summary_cards.addWidget(card, 0, index)
            self._stats_summary_cards.setColumnStretch(index, 1)

        if self._stats_scope_student_ids():
            self._stats_summary_line.setText(
                f"통계는 학생 탭에 현재 표시된 {len(self._filtered_students)}명 중 선버스트 선택 범위 {len(records)}명을 기준으로 합니다."
            )
        else:
            self._stats_summary_line.setText(f"통계는 학생 탭에 현재 표시된 {len(self._filtered_students)}명을 기준으로 합니다.")
        self._refresh_stats_sunburst()

        collection_options = (
            ("보유 여부", "owned"),
            ("학교", "school"),
            ("초기 성급", "rarity"),
            ("파밍", "farmable"),
            ("공격 타입", "attack_type"),
            ("방어 타입", "defense_type"),
            ("클래스", "combat_class"),
            ("역할", "role"),
            ("포지션", "position"),
            ("무기 타입", "weapon_type"),
            ("엄폐", "cover_type"),
            ("사거리", "range_type"),
            ("메인 오파츠", "growth_material_main"),
            ("서브 오파츠", "growth_material_sub"),
        )
        growth_options = (
            ("레벨 구간", "level_bucket"),
            ("성급", "star"),
            ("전용무기 상태", "weapon_state"),
            ("전용무기 성급", "weapon_star"),
            ("전용무기 레벨", "weapon_level"),
            ("EX 스킬", "ex_skill"),
            ("기본 스킬", "skill1"),
            ("강화 스킬", "skill2"),
            ("서브 스킬", "skill3"),
            ("일반 스킬 평균", "normal_skill_avg"),
            ("장비 평균 티어", "equipment_avg"),
            ("1번 장비", "equip1"),
            ("2번 장비", "equip2"),
            ("3번 장비", "equip3"),
            ("장비 슬롯 상태", "equipment_slot_status"),
            ("애용품", "equip4"),
            ("능력개방 HP", "ability_hp"),
            ("능력개방 ATK", "ability_atk"),
            ("능력개방 HEAL", "ability_heal"),
            ("직군별 육성도", "role_training"),
            ("종합 완성도", "growth_score"),
        )
        plan_options = (
            ("계획 포함 여부", "plan_membership"),
            ("계획 대상 보유율", "planned_owned_ratio"),
            ("목표 완료 여부", "plan_completion"),
            ("학생별 남은 성장량", "remaining_growth"),
            ("남은 재화 종류 많은 학생", "expensive_students"),
            ("목표 레벨", "target_level"),
            ("목표 성급", "target_star"),
            ("목표 전무", "target_weapon"),
            ("목표 EX", "target_ex"),
            ("목표 일반 스킬", "target_normal_skill"),
            ("목표 장비", "target_equipment"),
            ("목표 능력개방", "target_ability"),
            ("계획 전후 변화", "before_after_change"),
            ("계획 학교 구성", "planned_school"),
            ("계획 역할 구성", "planned_role"),
            ("계획 공격 타입", "planned_attack"),
            ("필요 재화 비율", "required_categories"),
            ("부족 재화 비율 TOP", "shortage_items"),
        )
        resource_options = (
            ("필요 재화 비율 TOP", "required_totals"),
            ("부족 재화 비율 TOP", "shortage_items"),
            ("부족률 TOP", "shortage_rate"),
            ("필요 카테고리 비율", "required_categories"),
            ("부족 카테고리 비율", "shortage_categories"),
            ("학교별 BD/노트", "school_demand"),
            ("오파츠 계열", "oopart_family"),
            ("장비 종류", "equipment_type"),
            ("장비 티어", "equipment_tier"),
        )
        skill_options = (
            ("버프", "skill_buff"),
            ("디버프", "skill_debuff"),
            ("CC", "skill_cc"),
            ("특수 효과", "skill_special"),
            ("회복 대상", "skill_heal_targets"),
            ("해제 대상", "skill_dispel_targets"),
            ("이동 대상", "skill_reposition_targets"),
            ("소환", "skill_summon_types"),
            ("패시브 스탯", "passive_stat"),
            ("전무 패시브", "weapon_passive_stat"),
            ("추가 패시브", "extra_passive_stat"),
            ("EX 범위 공격", "skill_is_area_damage"),
            ("엄폐 무시", "skill_ignore_cover"),
            ("넉백", "skill_knockback"),
        )

        if self._stats_collection_mode not in {value for _label, value in collection_options}:
            self._stats_collection_mode = "school"
        if self._stats_growth_mode not in {value for _label, value in growth_options}:
            self._stats_growth_mode = "level_bucket"
        if self._stats_plan_mode not in {value for _label, value in plan_options}:
            self._stats_plan_mode = "shortage_items"
        if self._stats_resource_mode not in {value for _label, value in resource_options}:
            self._stats_resource_mode = "shortage_items"
        if self._stats_skill_mode not in {value for _label, value in skill_options}:
            self._stats_skill_mode = "skill_buff"

        if self._stats_chart_tabs is not None:
            target_index = next(
                (index for index in range(self._stats_chart_tabs.count()) if self._stats_chart_tabs.tabData(index) == self._stats_active_chart_tab),
                0,
            )
            if self._stats_chart_tabs.currentIndex() != target_index:
                self._stats_chart_tabs.blockSignals(True)
                self._stats_chart_tabs.setCurrentIndex(target_index)
                self._stats_chart_tabs.blockSignals(False)

        chart_specs = {
            "collection": dict(
                title="분포 분석",
                subtitle="현재 root 범위",
                options=collection_options,
                current_value=self._stats_collection_mode,
                attr_name="_stats_collection_mode",
                rows=self._stats_field_rows(self._stats_collection_mode),
                chart_kind="distribution",
                compact_count=False,
            ),
            "growth": dict(
                title="분포 분석",
                subtitle="육성 상태 기준",
                options=growth_options,
                current_value=self._stats_growth_mode,
                attr_name="_stats_growth_mode",
                rows=self._stats_growth_rows(self._stats_growth_mode),
                chart_kind="bar",
                compact_count=False,
            ),
            "plan": dict(
                title="분포 분석",
                subtitle="계획 진행 기준",
                options=plan_options,
                current_value=self._stats_plan_mode,
                attr_name="_stats_plan_mode",
                rows=self._stats_plan_rows(self._stats_plan_mode),
                chart_kind="bar",
                compact_count=False,
            ),
            "resource": dict(
                title="분포 분석",
                subtitle="재화/인벤토리 기준",
                options=resource_options,
                current_value=self._stats_resource_mode,
                attr_name="_stats_resource_mode",
                rows=self._stats_resource_rows(self._stats_resource_mode),
                chart_kind="bar",
                compact_count=False,
            ),
            "skill": dict(
                title="분포 분석",
                subtitle="스킬/기능 태그 기준",
                options=skill_options,
                current_value=self._stats_skill_mode,
                attr_name="_stats_skill_mode",
                rows=self._stats_skill_rows(self._stats_skill_mode),
                chart_kind="bar",
                compact_count=False,
            ),
        }
        spec = chart_specs.get(self._stats_active_chart_tab, chart_specs["collection"])
        self._stats_add_chart_card(grid=self._stats_cards_layout, index=0, **spec)

    def _format_cost_summary(self, summary: PlanCostSummary) -> str:
        lines = [
            f"크레딧: {_format_count(summary.credits, compact=True)}",
            f"EXP: {_format_count(summary.level_exp, compact=True)}",
        ]
        if summary.level_exp_items:
            lines.append("활동 보고서:")
            for key, value in sorted(summary.level_exp_items.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.equipment_exp:
            lines.append(f"장비 EXP: {_format_count(summary.equipment_exp, compact=True)}")
        if summary.equipment_exp_items:
            lines.append("장비 강화석:")
            for key, value in sorted(summary.equipment_exp_items.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.weapon_exp:
            lines.append(f"무기 EXP: {_format_count(summary.weapon_exp, compact=True)}")
        if summary.weapon_exp_items:
            lines.append("무기 성장 재료:")
            for key, value in sorted(summary.weapon_exp_items.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.star_materials:
            lines.append("성급 재화:")
            for key, value in sorted(summary.star_materials.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.equipment_materials:
            lines.append("장비 재화:")
            for key, value in sorted(summary.equipment_materials.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.skill_books:
            lines.append("스킬북:")
            for key, value in sorted(summary.skill_books.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.ex_ooparts:
            lines.append("EX 오파츠:")
            for key, value in sorted(summary.ex_ooparts.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.skill_ooparts:
            lines.append("일반 스킬 오파츠:")
            for key, value in sorted(summary.skill_ooparts.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.favorite_item_materials:
            lines.append("애용품 재화:")
            for key, value in sorted(summary.favorite_item_materials.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.stat_materials:
            lines.append("능력개방 재화:")
            for key, value in sorted(summary.stat_materials.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.stat_levels:
            lines.append("능력개방 목표:")
            for key, value in sorted(summary.stat_levels.items()):
                lines.append(f"- {key}: +{value}")
        if summary.warnings:
            lines.append("메모:")
            for warning in dict.fromkeys(summary.warnings):
                lines.append(f"- {warning}")
        return "\n".join(lines)

    def _reload_data(self) -> None:
        self._all_students = load_students()
        self._inventory_snapshot = load_inventory_snapshot()
        self._resource_snapshot = load_latest_resource_snapshot()
        self._inventory_quantity_index_cache = _inventory_quantity_index(self._inventory_snapshot or {}, self._resource_snapshot)
        self._plan = load_plan(self._plan_path)
        self._tactical_data = load_tactical_challenge(self._tactical_path, load_matches=False)
        self._raid_guide_data = load_raid_guides(self._raid_guide_path)
        self._invalidate_plan_caches()
        self._storage_mtimes = self._snapshot_storage_mtimes()
        self._records_by_id = {record.student_id: record for record in self._all_students}
        self._tactical_student_lookup_index = None
        self._raid_student_lookup_index = None
        self._filter_options = build_filter_options(self._all_students)
        self._unowned_icon_cache.clear()
        self._apply_filters()
        self._refresh_plan_lists()
        self._refresh_plan_totals()
        self._refresh_stats_tab()
        self._refresh_inventory_tab()
        self._refresh_tactical_tab()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()

    def _schedule_filter_refresh(self, *_args) -> None:
        self._filter_refresh_timer.start()

    def _schedule_plan_search_refresh(self, *_args) -> None:
        self._plan_search_timer.start()

    def _apply_filters(self) -> None:
        for key in HIDDEN_STUDENT_FILTER_FIELDS:
            self._selected_filters.pop(key, None)
        active_search = self._resource_search if hasattr(self, "_resource_search") and self._resource_search.hasFocus() else self._search
        query = _live_line_edit_text(active_search).strip().casefold()
        sort_mode = self._sort_mode.currentData()

        items = [
            record
            for record in self._all_students
            if matches_student_filters(
                record,
                self._selected_filters,
                query,
                hide_jp_only=self._hide_jp_only.isChecked(),
            )
            and (self._show_unowned.isChecked() or record.owned)
        ]

        if sort_mode == "star_desc":
            items.sort(key=lambda record: (-record.star, -(record.level or 0), record.title.lower()))
        elif sort_mode == "star_asc":
            items.sort(key=lambda record: (record.star, record.level or 0, record.title.lower()))
        elif sort_mode == "level_desc":
            items.sort(key=lambda record: (-(record.level or 0), -record.star, record.title.lower()))
        else:
            items.sort(key=lambda record: record.title.lower())

        self._filtered_students = items
        self._filter_summary.setText(
            summarize_filters(
                self._selected_filters,
                self._filter_options,
                hide_jp_only=self._hide_jp_only.isChecked(),
            )
        )
        active_count = active_filter_count(self._selected_filters) + int(self._hide_jp_only.isChecked())
        self._filter_button.setText(f"필터 ({active_count})" if active_count else "필터")
        self._rebuild_list()
        self._refresh_stats_tab()
        self._sync_resource_controls_from_students()
        self._refresh_resources_if_visible()

    def _open_filter_dialog(self) -> None:
        dialog = FilterDialog(self, self._filter_options, self._selected_filters, self._ui_scale)
        if dialog.exec() == QDialog.Accepted:
            self._selected_filters = dialog.selected_filters()
            self._apply_filters()

    def _rebuild_list(self) -> None:
        selected_id = self._current_student_id()
        old_cards = dict(self._item_by_id)
        cards: list[StudentCardWidget] = []
        next_by_id: dict[str, StudentCardWidget] = {}

        for record in self._filtered_students:
            card = old_cards.get(record.student_id)
            if card is None:
                card = self._build_student_card(record)
            else:
                self._apply_student_card_record(card, record)
            cards.append(card)
            next_by_id[record.student_id] = card

        self._item_by_id = next_by_id
        self._student_grid.set_cards(cards)

        for record in self._filtered_students:
            self._enqueue_thumb(record.student_id)

        owned_count = sum(1 for record in self._all_students if record.owned)
        self._count_label.setText(f"{len(self._filtered_students)}명 표시 / 전체 {len(self._all_students)}명 (보유 {owned_count}명)")

        if self._filtered_students:
            restore_id = selected_id if selected_id in self._item_by_id else self._filtered_students[0].student_id
            self._student_grid.set_current_card(restore_id)
        else:
            self._student_grid.set_current_card(None)
            self._clear_detail()

    def _remember_thumb_pixmap(self, student_id: str, width: int, height: int, pixmap: QPixmap) -> None:
        if pixmap.isNull():
            return
        key = (student_id, width, height)
        self._thumb_pixmap_cache[key] = pixmap
        self._thumb_pixmap_cache.move_to_end(key)
        while len(self._thumb_pixmap_cache) > self._thumb_pixmap_cache_limit:
            self._thumb_pixmap_cache.popitem(last=False)

    def _cached_thumb_pixmap(self, student_id: str, width: int, height: int, path: str | None = None) -> QPixmap | None:
        key = (student_id, width, height)
        cached = self._thumb_pixmap_cache.get(key)
        if cached is not None:
            self._thumb_pixmap_cache.move_to_end(key)
            return cached
        if not path:
            return None
        pixmap = QPixmap(path)
        if pixmap.isNull():
            return None
        self._remember_thumb_pixmap(student_id, width, height, pixmap)
        return pixmap

    def _apply_cached_thumb_to_card(self, card: StudentCardWidget) -> None:
        pixmap = self._cached_thumb_pixmap(card.student_id, self._thumb_width, self._thumb_height)
        if pixmap is not None:
            card.setPixmap(pixmap)

    def _clear_thumb_requests(self) -> None:
        self._thumb_pump.stop()
        self._thumb_loading.clear()
        self._pending_thumb_requests.clear()
        self._pending_thumb_lookup.clear()

    def _enqueue_thumb(self, student_id: str) -> None:
        request = (student_id, self._thumb_width, self._thumb_height)
        if request in self._thumb_loading or request in self._pending_thumb_lookup:
            return
        self._pending_thumb_requests.append(request)
        self._pending_thumb_lookup.add(request)
        if not self._thumb_pump.isActive():
            self._thumb_pump.start()

    def _visible_thumb_student_ids(self) -> set[str]:
        visible: set[str] = set()
        for attr in ("_student_grid", "_plan_grid", "_resource_scope_grid", "_resource_search_grid"):
            grid = getattr(self, attr, None)
            if grid is not None and grid.isVisible():
                visible.update(grid.visible_card_ids())
        return visible

    def _pop_next_thumb_request(self) -> tuple[str, int, int]:
        visible_ids = self._visible_thumb_student_ids()
        if visible_ids:
            for index, request in enumerate(self._pending_thumb_requests):
                if request[0] in visible_ids:
                    return self._pending_thumb_requests.pop(index)
        return self._pending_thumb_requests.pop(0)

    def _drain_thumb_queue(self) -> None:
        started = 0
        while (
            self._pending_thumb_requests
            and started < self._thumb_batch_size
            and len(self._thumb_loading) < self._thumb_max_in_flight
        ):
            student_id, width, height = self._pop_next_thumb_request()
            request = (student_id, width, height)
            self._pending_thumb_lookup.discard(request)
            if not self._has_any_card_target(student_id):
                continue
            self._queue_thumb(student_id, width, height)
            started += 1
        if not self._pending_thumb_requests or len(self._thumb_loading) >= self._thumb_max_in_flight:
            self._thumb_pump.stop()

    def _queue_thumb(self, student_id: str, width: int, height: int) -> None:
        request = (student_id, width, height)
        if request in self._thumb_loading:
            return

        self._thumb_loading.add(request)
        task = ThumbTask(student_id, width, height)
        task.signals.loaded.connect(self._apply_thumb)
        self._pool.start(task)

    def _apply_thumb(self, student_id: str, path: str, width: int, height: int) -> None:
        self._thumb_loading.discard((student_id, width, height))
        if self._pending_thumb_requests and not self._thumb_pump.isActive():
            self._thumb_pump.start()
        if not path:
            return
        if width != self._thumb_width or height != self._thumb_height:
            return

        pixmap = self._cached_thumb_pixmap(student_id, width, height, path)
        if pixmap is not None and not pixmap.isNull():
            if student_id in self._item_by_id:
                self._student_grid.set_card_pixmap(student_id, pixmap)
            if student_id in self._plan_card_by_id:
                self._plan_grid.set_card_pixmap(student_id, pixmap)
            if student_id in self._resource_scope_card_by_id:
                self._resource_scope_grid.set_card_pixmap(student_id, pixmap)
            if student_id in self._resource_search_card_by_id:
                self._resource_search_grid.set_card_pixmap(student_id, pixmap)

    def _on_student_card_changed(self, current: str | None, _previous: str | None) -> None:
        if not current:
            self._clear_detail()
            return

        record = next((entry for entry in self._filtered_students if entry.student_id == current), None)
        if record is None:
            self._clear_detail()
            return

        self._populate_detail(record)

    def _on_student_grid_layout_changed(self, _width: int, _height: int) -> None:
        self._refresh_card_layout()

    def _populate_detail(self, record: StudentRecord) -> None:
        attack_color = _attack_color(record.attack_type)
        defense_color = _defense_accent_color(record.defense_type)
        self._name.setText(record.title)
        self._subtitle.clear()
        self._detail_badges.clear()
        self._subtitle.setVisible(False)
        self._detail_badges.setVisible(False)
        self._detail_plan_button.setText("플랜에서 보기" if record.student_id in self._plan_goal_map() else "플랜에 추가")
        self._detail_attack_bar.setColors(_mix_hex(attack_color, SURFACE_ALT, 0.12), attack_color)
        self._detail_defense_bar.setColors(_mix_hex(defense_color, SURFACE_ALT, 0.12), defense_color)
        has_weapon_progress = record.owned and record.star >= 5 and (record.weapon_state or "") != "no_weapon_system"
        self._detail_progress_strip.setProgress(record.star if record.owned else 0, record.weapon_star or 0, has_weapon_progress)
        self._detail_attack_chip.setVisible(False)
        self._detail_defense_chip.setVisible(False)
        self._detail_level_value.setStyleSheet(f"color: {INK};")
        self._detail_weapon_value.setStyleSheet(f"color: {INK};")

        school_logo = _school_logo_path(record.school)
        if school_logo is not None:
            school_pixmap = QPixmap(str(school_logo))
            if not school_pixmap.isNull():
                self._detail_school_icon.setPixmap(_tinted_pixmap(school_pixmap, "#ffffff", self._detail_school_icon.size()))
            else:
                self._detail_school_icon.setPixmap(QPixmap())
        else:
            self._detail_school_icon.setPixmap(QPixmap())

        self._detail_level_value.setText(str(record.level or "-") if record.owned else "-")
        self._detail_position_value.setText(_position_label(record.position))
        self._detail_class_value.setText((record.combat_class or "-").title())
        has_weapon = record.owned and (record.weapon_state or "") != "no_weapon_system"
        self._detail_weapon_card.setVisible(True)
        self._detail_weapon_value.setText(f"Lv.{record.weapon_level}" if has_weapon and record.weapon_level is not None else "-")
        self._detail_weapon_sub.clear()

        self._detail_skill_labels["ex"].setText(str(record.ex_skill or "-") if record.owned else "-")
        self._detail_skill_labels["s1"].setText(str(record.skill1 or "-") if record.owned else "-")
        self._detail_skill_labels["s2"].setText(str(record.skill2 or "-") if record.owned else "-")
        self._detail_skill_labels["s3"].setText(str(record.skill3 or "-") if record.owned else "-")

        for index, slot in enumerate(("equip1", "equip2", "equip3"), start=1):
            tier = getattr(record, slot)
            tier_num = _parse_tier_number(tier)
            level = _int_or_none(getattr(record, f"{slot}_level"))
            value_text = _slot_placeholder(tier) if record.owned else "-"
            icon_path = _equipment_icon_path(record.student_id, index, tier) if record.owned else None
            icon_pixmap = QPixmap()
            if icon_path is not None:
                loaded = QPixmap(str(icon_path))
                if not loaded.isNull():
                    icon_pixmap = loaded
                    value_text = ""
            elif tier_num is not None:
                value_text = f"T{tier_num}"
            self._detail_equip_cards[slot].setData(
                icon=icon_pixmap,
                value=value_text,
                level=str(level) if record.owned and level is not None else "",
            )

        favorite_supported = student_meta.favorite_item_enabled(record.student_id)
        favorite_tier = _parse_tier_number(record.equip4)
        favorite_value = _slot_placeholder(record.equip4, supported=favorite_supported) if record.owned else "-"
        if record.owned and favorite_tier is not None:
            favorite_value = f"T{favorite_tier}"
        self._detail_equip_cards["equip4"].setData(
            icon=QPixmap(),
            value=favorite_value,
            level="",
        )

        combat_values = (record.combat_hp, record.combat_atk, record.combat_def, record.combat_heal)
        if record.owned and any(_int_or_none(value) is not None for value in combat_values):
            self._detail_stats_line.setText(_detail_stats_html((
                ("HP", record.combat_hp),
                ("ATK", record.combat_atk),
                ("DEF", record.combat_def),
                ("HEAL", record.combat_heal),
            ), font_px=scale_px(17, self._ui_scale)))
        else:
            self._detail_stats_line.setText("-")

        if record.owned:
            self._detail_bonus_stats_line.setText(_detail_bonus_stats_html((
                ("HP", record.stat_hp),
                ("ATK", record.stat_atk),
                ("HEAL", record.stat_heal),
            ), font_px=scale_px(13, self._ui_scale)))
        else:
            self._detail_bonus_stats_line.setText("-")

        hero_path = portrait_path(record.student_id)
        hero_size = self._hero.card_size()
        hero_source = None
        if hero_size.width() > 0 and hero_size.height() > 0:
            hero_source = ensure_thumbnail(record.student_id, hero_size.width(), hero_size.height())
        if hero_source is None:
            hero_source = hero_path

        if hero_source and hero_source.exists():
            pixmap = QPixmap(str(hero_source))
            if not pixmap.isNull():
                self._large_pixmap = pixmap
                self._hero.setPixmap(self._large_pixmap, owned=record.owned)
                return

        self._large_pixmap = None
        if record.owned:
            self._hero.clear()
        else:
            self._hero.setPixmap(self._unowned_icon(record.student_id).pixmap(self._hero.size()), owned=False)

    def _clear_detail(self) -> None:
        self._name.setText("학생을 선택하세요")
        self._subtitle.clear()
        self._detail_badges.clear()
        self._subtitle.setVisible(False)
        self._detail_badges.setVisible(False)
        self._detail_attack_chip.setVisible(False)
        self._detail_defense_chip.setVisible(False)
        self._detail_school_icon.setPixmap(QPixmap())
        self._detail_plan_button.setText("플랜에 추가")
        self._detail_progress_strip.setProgress(0, 0, False)
        self._detail_level_value.setText("-")
        self._detail_position_value.setText("-")
        self._detail_class_value.setText("-")
        self._detail_weapon_card.setVisible(False)
        self._detail_weapon_value.setText("-")
        self._detail_weapon_sub.clear()
        for label in self._detail_skill_labels.values():
            label.setText("-")
        for card in self._detail_equip_cards.values():
            card.clearData()
        self._detail_stats_line.setText("-")
        self._detail_bonus_stats_line.setText("-")
        self._hero.clear()

    def _current_student_id(self) -> str | None:
        if not hasattr(self, "_student_grid"):
            return None
        return self._student_grid.current_card_id()

    def _unowned_icon(self, student_id: str) -> QIcon:
        cached = self._unowned_icon_cache.get(student_id)
        if cached is None:
            cached = make_unowned_icon(student_id, self._thumb_width, self._thumb_height)
            self._unowned_icon_cache[student_id] = cached
        return cached

    @staticmethod
    def _equip_text(tier: str | None, level: int | None) -> str:
        if tier and level is not None:
            return f"{tier} / Lv.{level}"
        if tier:
            return tier
        return "-"


_QT_MESSAGE_HANDLER = None


def _install_qt_message_filter() -> None:
    global _QT_MESSAGE_HANDLER
    if _QT_MESSAGE_HANDLER is not None:
        return

    def _handler(mode: QtMsgType, context, message: str) -> None:
        if "QFont::setPointSize: Point size <= 0" in str(message or ""):
            return
        sys.stderr.write(str(message) + "\n")

    _QT_MESSAGE_HANDLER = _handler
    qInstallMessageHandler(_QT_MESSAGE_HANDLER)


_install_qt_message_filter()


def _parse_viewer_args(argv: list[str]) -> tuple[argparse.Namespace, list[str]]:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument(
        *sorted(VIEWER_STUDENT_SCAN_DEBUG_FLAGS),
        dest="student_scan_debug",
        action="store_true",
    )
    args, remaining = parser.parse_known_args(argv[1:])
    return args, [argv[0], *remaining]


def main() -> int:
    args, qt_argv = _parse_viewer_args(sys.argv)
    app = QApplication(qt_argv)
    _apply_ui_font(app)
    startup_screen = app.screenAt(QCursor.pos()) or app.primaryScreen()
    startup_geometry = startup_screen.availableGeometry() if startup_screen is not None else None
    startup_screen_geometry = startup_screen.geometry() if startup_screen is not None else None
    window = StudentViewerWindow(
        get_qt_ui_scale(app, base_width=PLANNER_BASE_WIDTH, base_height=PLANNER_BASE_HEIGHT),
        startup_geometry=startup_geometry,
        startup_screen_geometry=startup_screen_geometry,
        student_scan_debug=args.student_scan_debug,
    )
    window.show()
    return app.exec()

if __name__ == "__main__":
    raise SystemExit(main())

