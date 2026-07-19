"""Python-owned models exposed to the Qt Quick Planner presentation."""

from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
from datetime import date, datetime
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from uuid import uuid4
from collections import Counter

from PySide6.QtCore import QByteArray, QAbstractListModel, QModelIndex, QObject, Property, QRunnable, QThreadPool, QTimer, Qt, Signal, Slot, QUrl

from core.config import activate_profile, get_active_profile_name, get_profile_account_portrait, get_storage_paths, list_profiles, load_config, save_config
from core.inventory_profiles import inventory_item_display_name
from core import student_meta
from core.planning import GrowthPlan, StudentGoal, load_plan, save_plan
from core.planning_calc import PlanCostSummary, calculate_plan_totals
from core.scan_status import read_status_events, reset_status_log, write_status_ack
from core.tactical_challenge import (
    TacticalDeck,
    TacticalJokboEntry,
    TacticalMatch,
    deck_template,
    load_tactical_challenge,
    parse_deck_template,
    query_tactical_matches,
    search_jokbo_from_storage,
    tactical_match_count,
    tactical_match_summary,
    upsert_tactical_match,
    upsert_tactical_jokbo,
)
from core.tactical_screenshot import parse_tactical_result_screenshot, tactical_screenshot_date_from_path
from gui.student_filters import FILTER_FIELD_LABELS, FILTER_FIELD_ORDER, build_filter_options, matches_student_filters


BASE_DIR = Path(__file__).resolve().parents[2]


_CATEGORY_LABELS = {
    "all": "전체",
    "equipment": "장비",
    "ooparts": "오파츠",
    "workbooks": "전술 교육 BD",
    "activity_reports": "활동 보고서",
    "enhancement_stones": "강화석",
    "weapon_parts": "무기 부품",
    "skill_books": "기술 노트",
    "elephs": "엘레프",
    "presents": "선물",
    "resources": "재화",
    "other": "기타",
}


def _quantity(value: object) -> int:
    try:
        return max(0, int(str(value or "0").replace(",", "").strip()))
    except (TypeError, ValueError):
        return 0


def _category_for(item_id: str, name: str) -> str:
    if item_id == "Currency_Icon_Gold":
        return "resources"
    if item_id.startswith("Equipment_Icon_Exp_"):
        return "enhancement_stones"
    if item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
        return "weapon_parts"
    if item_id.startswith("Equipment_Icon_"):
        return "equipment"
    if item_id.startswith("Item_Icon_SkillBook_"):
        return "skill_books"
    if item_id.startswith("Item_Icon_Material_ExSkill_"):
        return "workbooks"
    if item_id.startswith("Item_Icon_SecretStone_"):
        return "elephs"
    if item_id.startswith("Item_Icon_Favor_"):
        return "presents"
    lowered = f"{item_id} {name}".casefold()
    if "opart" in lowered or "오파츠" in lowered:
        return "ooparts"
    if "report" in lowered or "보고서" in lowered:
        return "activity_reports"
    return "other"


def _icon_url(item_id: str, category: str) -> str:
    root = Path(__file__).resolve().parents[2]
    candidates: list[Path] = []
    if item_id:
        candidates.extend(
            (
                root / "templates" / "icons" / "temp" / f"{item_id}.png",
                root / "templates" / "students_elephs" / f"{item_id}.png",
                root / "templates" / "icons" / "presents" / f"{item_id}.png",
                root / "templates" / "icons" / "skill_book" / f"{item_id}.png",
                root / "templates" / "inventory_detail" / category / f"{item_id}.png",
                root / "templates" / "inventory_detail" / "equipment" / f"{item_id}.png",
                root / "templates" / "inventory_detail" / "tech_notes" / f"{item_id}.png",
                root / "templates" / "inventory_detail" / "tactical_bd" / f"{item_id}.png",
                root / "templates" / "inventory_detail" / "presents" / f"{item_id}.png",
            )
        )
    for path in candidates:
        if path.exists():
            return QUrl.fromLocalFile(str(path)).toString()
    return ""


@dataclass(frozen=True, slots=True)
class InventoryRow:
    item_key: str
    item_id: str
    name: str
    quantity: int
    category: str
    icon_url: str = ""
    last_seen_at: str = ""


@dataclass(frozen=True, slots=True)
class StudentRow:
    student_id: str
    display_name: str
    owned: bool
    level: int
    star: int
    school: str
    attack_type: str
    defense_type: str
    role: str
    portrait_url: str
    farmable: str | None = None
    rarity: str | None = None
    weapon_state: str | None = None
    weapon_star: int | None = None
    weapon_level: int | None = None
    ex_skill: int | None = None
    skill1: int | None = None
    skill2: int | None = None
    skill3: int | None = None
    equip1: str | None = None
    equip2: str | None = None
    equip3: str | None = None
    equip4: str | None = None
    equip1_level: int | None = None
    equip2_level: int | None = None
    equip3_level: int | None = None
    combat_hp: int | None = None
    combat_atk: int | None = None
    combat_def: int | None = None
    combat_heal: int | None = None
    stat_hp: int | None = None
    stat_atk: int | None = None
    stat_heal: int | None = None
    combat_class: str | None = None
    position: str | None = None
    weapon_type: str | None = None
    cover_type: str | None = None
    range_type: str | None = None


@dataclass(frozen=True, slots=True)
class PlanRow:
    student_id: str
    display_name: str
    portrait_url: str
    current_level: int
    current_star: int
    target_level: int
    target_star: int
    target_ex_skill: int
    target_skill1: int
    target_skill2: int
    target_skill3: int
    notes: str


@dataclass(frozen=True, slots=True)
class PlanResourceRow:
    category: str
    name: str
    quantity: int


@dataclass(frozen=True, slots=True)
class TacticalMatchRow:
    match_id: str
    match_date: str
    season: str
    opponent: str
    result: str
    mode: str
    attack_deck: str
    defense_deck: str
    notes: str


class _ScreenshotWorkerSignals(QObject):
    completed = Signal(str, object)
    failed = Signal(str)


class _ScreenshotWorker(QRunnable):
    def __init__(self, path: str) -> None:
        super().__init__()
        self.path = path
        self.signals = _ScreenshotWorkerSignals()

    def run(self) -> None:
        try:
            readout = parse_tactical_result_screenshot(self.path)
        except Exception as exc:
            self.signals.failed.emit(str(exc))
            return
        self.signals.completed.emit(self.path, readout)


def load_inventory_rows() -> list[InventoryRow]:
    paths = get_storage_paths()
    raw_rows: list[dict] = []
    if paths.db_path.exists():
        try:
            connection = sqlite3.connect(paths.db_path)
            connection.row_factory = sqlite3.Row
            try:
                raw_rows = [
                    dict(row)
                    for row in connection.execute(
                        """
                        SELECT item_key, item_id, name, quantity, item_index, last_seen_at
                        FROM inventory_current
                        ORDER BY COALESCE(item_index, 999999), item_key
                        """
                    ).fetchall()
                ]
            finally:
                connection.close()
        except sqlite3.Error:
            raw_rows = []
    if not raw_rows and paths.current_inventory_json.exists():
        try:
            payload = json.loads(paths.current_inventory_json.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                raw_rows = [dict(value, item_key=key) for key, value in payload.items() if isinstance(value, dict)]
        except (OSError, ValueError, TypeError):
            raw_rows = []

    rows: list[InventoryRow] = []
    for payload in raw_rows:
        item_key = str(payload.get("item_key") or payload.get("item_id") or payload.get("name") or "")
        item_id = str(payload.get("item_id") or (item_key if "_Icon_" in item_key else ""))
        name = str(payload.get("name") or inventory_item_display_name(item_id) or item_key or "알 수 없는 항목")
        category = _category_for(item_id, name)
        rows.append(
            InventoryRow(
                item_key=item_key,
                item_id=item_id,
                name=name,
                quantity=_quantity(payload.get("quantity")),
                category=category,
                icon_url=_icon_url(item_id, category),
                last_seen_at=str(payload.get("last_seen_at") or ""),
            )
        )
    return rows


def _student_portrait_url(student_id: str) -> str:
    portrait_dir = Path(__file__).resolve().parents[2] / "templates" / "students_portraits"
    for extension in (".png", ".jpg", ".jpeg", ".webp"):
        path = portrait_dir / f"{student_id}{extension}"
        if path.exists():
            return QUrl.fromLocalFile(str(path)).toString()
    return ""


def _profile_portrait_url(profile_name: str) -> str:
    student_id, form_index = get_profile_account_portrait(profile_name)
    portrait_dir = Path(__file__).resolve().parents[2] / "templates" / "students_portraits"
    suffixes = [f"_{form_index - 1}"] if form_index > 1 else []
    suffixes.append("")
    for suffix in suffixes:
        for extension in (".png", ".jpg", ".jpeg", ".webp"):
            path = portrait_dir / f"{student_id}{suffix}{extension}"
            if path.exists():
                return QUrl.fromLocalFile(str(path)).toString()
    return _student_portrait_url("hasumi")


def load_student_rows() -> list[StudentRow]:
    paths = get_storage_paths()
    current: dict[str, dict] = {}
    if paths.db_path.exists():
        try:
            connection = sqlite3.connect(paths.db_path)
            connection.row_factory = sqlite3.Row
            try:
                current = {
                    str(row["student_id"]): dict(row)
                    for row in connection.execute(
                        """
                        SELECT * FROM students
                        ORDER BY student_id
                        """
                    ).fetchall()
                }
            finally:
                connection.close()
        except sqlite3.Error:
            current = {}
    if not current and paths.current_students_json.exists():
        try:
            payload = json.loads(paths.current_students_json.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                current = {
                    str(value.get("student_id") or key): dict(value)
                    for key, value in payload.items()
                    if isinstance(value, dict)
                }
        except (OSError, ValueError, TypeError):
            current = {}

    rows: list[StudentRow] = []
    for student_id in student_meta.all_ids():
        payload = current.get(student_id, {})
        display_name = str(
            payload.get("display_name")
            or student_meta.field(student_id, "display_name", student_id)
            or student_id
        )
        rows.append(
            StudentRow(
                student_id=student_id,
                display_name=display_name,
                owned=student_id in current,
                level=_quantity(payload.get("level")),
                star=_quantity(payload.get("student_star") or student_meta.field(student_id, "rarity", 0)),
                school=str(student_meta.field(student_id, "school", "") or ""),
                attack_type=str(student_meta.field(student_id, "attack_type", "") or ""),
                defense_type=str(student_meta.field(student_id, "defense_type", "") or ""),
                role=str(student_meta.field(student_id, "role", "") or ""),
                portrait_url=_student_portrait_url(student_id),
                farmable=student_meta.field(student_id, "farmable"),
                rarity=student_meta.field(student_id, "rarity"),
                weapon_state=payload.get("weapon_state"),
                weapon_star=payload.get("weapon_star"),
                weapon_level=payload.get("weapon_level"),
                ex_skill=payload.get("ex_skill"),
                skill1=payload.get("skill1"),
                skill2=payload.get("skill2"),
                skill3=payload.get("skill3"),
                equip1=payload.get("equip1"),
                equip2=payload.get("equip2"),
                equip3=payload.get("equip3"),
                equip4=payload.get("equip4"),
                equip1_level=payload.get("equip1_level"),
                equip2_level=payload.get("equip2_level"),
                equip3_level=payload.get("equip3_level"),
                combat_hp=payload.get("combat_hp"),
                combat_atk=payload.get("combat_atk"),
                combat_def=payload.get("combat_def"),
                combat_heal=payload.get("combat_heal"),
                stat_hp=payload.get("stat_hp"),
                stat_atk=payload.get("stat_atk"),
                stat_heal=payload.get("stat_heal"),
                combat_class=student_meta.field(student_id, "combat_class"),
                position=student_meta.field(student_id, "position"),
                weapon_type=student_meta.field(student_id, "weapon_type"),
                cover_type=student_meta.field(student_id, "cover_type"),
                range_type=student_meta.field(student_id, "range_type"),
            )
        )
    rows.sort(key=lambda row: (not row.owned, row.display_name.casefold(), row.student_id))
    return rows


class InventoryListModel(QAbstractListModel):
    ItemKeyRole = Qt.UserRole + 1
    ItemIdRole = Qt.UserRole + 2
    NameRole = Qt.UserRole + 3
    QuantityRole = Qt.UserRole + 4
    CategoryRole = Qt.UserRole + 5
    CategoryLabelRole = Qt.UserRole + 6
    IconUrlRole = Qt.UserRole + 7
    LastSeenAtRole = Qt.UserRole + 8

    countChanged = Signal()
    queryChanged = Signal()
    categoryChanged = Signal()

    def __init__(self, rows: Iterable[InventoryRow] = (), parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._source_rows = list(rows)
        self._rows = list(self._source_rows)
        self._query = ""
        self._category = "all"

    def roleNames(self) -> dict[int, QByteArray]:  # noqa: N802 - Qt virtual name
        return {
            self.ItemKeyRole: QByteArray(b"itemKey"),
            self.ItemIdRole: QByteArray(b"itemId"),
            self.NameRole: QByteArray(b"name"),
            self.QuantityRole: QByteArray(b"quantity"),
            self.CategoryRole: QByteArray(b"category"),
            self.CategoryLabelRole: QByteArray(b"categoryLabel"),
            self.IconUrlRole: QByteArray(b"iconUrl"),
            self.LastSeenAtRole: QByteArray(b"lastSeenAt"),
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: N802
        return 0 if parent.isValid() else len(self._rows)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._rows):
            return None
        row = self._rows[index.row()]
        values = {
            self.ItemKeyRole: row.item_key,
            self.ItemIdRole: row.item_id,
            self.NameRole: row.name,
            self.QuantityRole: row.quantity,
            self.CategoryRole: row.category,
            self.CategoryLabelRole: _CATEGORY_LABELS.get(row.category, row.category),
            self.IconUrlRole: row.icon_url,
            self.LastSeenAtRole: row.last_seen_at,
            Qt.DisplayRole: row.name,
        }
        return values.get(role)

    @Property(int, notify=countChanged)
    def count(self) -> int:
        return len(self._rows)

    @Property(str, notify=queryChanged)
    def query(self) -> str:
        return self._query

    @query.setter
    def query(self, value: str) -> None:
        normalized = str(value or "").strip().casefold()
        if normalized == self._query:
            return
        self._query = normalized
        self.queryChanged.emit()
        self._refilter()

    @Property(str, notify=categoryChanged)
    def category(self) -> str:
        return self._category

    @category.setter
    def category(self, value: str) -> None:
        normalized = str(value or "all")
        if normalized not in _CATEGORY_LABELS:
            normalized = "all"
        if normalized == self._category:
            return
        self._category = normalized
        self.categoryChanged.emit()
        self._refilter()

    def replace_rows(self, rows: Iterable[InventoryRow]) -> None:
        self.beginResetModel()
        self._source_rows = list(rows)
        self._rows = self._filtered_rows()
        self.endResetModel()
        self.countChanged.emit()

    def _filtered_rows(self) -> list[InventoryRow]:
        return [
            row
            for row in self._source_rows
            if (self._category == "all" or row.category == self._category)
            and (not self._query or self._query in f"{row.name} {row.item_id} {row.item_key}".casefold())
        ]

    def _refilter(self) -> None:
        self.beginResetModel()
        self._rows = self._filtered_rows()
        self.endResetModel()
        self.countChanged.emit()


class StudentListModel(QAbstractListModel):
    StudentIdRole = Qt.UserRole + 1
    DisplayNameRole = Qt.UserRole + 2
    OwnedRole = Qt.UserRole + 3
    LevelRole = Qt.UserRole + 4
    StarRole = Qt.UserRole + 5
    SchoolRole = Qt.UserRole + 6
    AttackTypeRole = Qt.UserRole + 7
    DefenseTypeRole = Qt.UserRole + 8
    StudentRoleRole = Qt.UserRole + 9
    PortraitUrlRole = Qt.UserRole + 10

    countChanged = Signal()
    queryChanged = Signal()
    ownedOnlyChanged = Signal()
    filtersChanged = Signal()

    def __init__(self, rows: Iterable[StudentRow] = (), parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._source_rows = list(rows)
        self._rows = list(self._source_rows)
        self._query = ""
        self._owned_only = False
        self._selected_filters: dict[str, set[str]] = {}
        self._filter_options: dict[str, list[dict[str, str]]] = {}
        self._rebuild_filter_options()

    def roleNames(self) -> dict[int, QByteArray]:  # noqa: N802
        return {
            self.StudentIdRole: QByteArray(b"studentId"),
            self.DisplayNameRole: QByteArray(b"displayName"),
            self.OwnedRole: QByteArray(b"owned"),
            self.LevelRole: QByteArray(b"level"),
            self.StarRole: QByteArray(b"star"),
            self.SchoolRole: QByteArray(b"school"),
            self.AttackTypeRole: QByteArray(b"attackType"),
            self.DefenseTypeRole: QByteArray(b"defenseType"),
            self.StudentRoleRole: QByteArray(b"studentRole"),
            self.PortraitUrlRole: QByteArray(b"portraitUrl"),
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: N802
        return 0 if parent.isValid() else len(self._rows)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._rows):
            return None
        row = self._rows[index.row()]
        values = {
            self.StudentIdRole: row.student_id,
            self.DisplayNameRole: row.display_name,
            self.OwnedRole: row.owned,
            self.LevelRole: row.level,
            self.StarRole: row.star,
            self.SchoolRole: row.school,
            self.AttackTypeRole: row.attack_type,
            self.DefenseTypeRole: row.defense_type,
            self.StudentRoleRole: row.role,
            self.PortraitUrlRole: row.portrait_url,
            Qt.DisplayRole: row.display_name,
        }
        return values.get(role)

    @Property(int, notify=countChanged)
    def count(self) -> int:
        return len(self._rows)

    @Property(str, notify=queryChanged)
    def query(self) -> str:
        return self._query

    @query.setter
    def query(self, value: str) -> None:
        normalized = str(value or "").strip().casefold()
        if normalized == self._query:
            return
        self._query = normalized
        self.queryChanged.emit()
        self._refilter()

    @Property(bool, notify=ownedOnlyChanged)
    def ownedOnly(self) -> bool:
        return self._owned_only

    @ownedOnly.setter
    def ownedOnly(self, value: bool) -> None:
        normalized = bool(value)
        if normalized == self._owned_only:
            return
        self._owned_only = normalized
        self.ownedOnlyChanged.emit()
        self._refilter()

    @Property("QVariantMap", notify=filtersChanged)
    def filterOptions(self) -> dict[str, list[dict[str, str]]]:
        return self._filter_options

    @Property("QVariantList", constant=True)
    def filterFields(self) -> list[dict[str, str]]:
        return [{"key": key, "label": FILTER_FIELD_LABELS.get(key, key)} for key in FILTER_FIELD_ORDER]

    @Property("QVariantMap", notify=filtersChanged)
    def selectedFilterValues(self) -> dict[str, str]:
        return {
            key: next(iter(values), "")
            for key, values in self._selected_filters.items()
        }

    @Property(int, notify=filtersChanged)
    def activeFilterCount(self) -> int:
        return sum(bool(values) for values in self._selected_filters.values())

    @Slot(str, str)
    def setFilter(self, key: str, value: str) -> None:
        normalized_key = str(key or "")
        if normalized_key not in FILTER_FIELD_ORDER:
            return
        normalized_value = str(value or "").strip()
        updated = {normalized_value} if normalized_value else set()
        if self._selected_filters.get(normalized_key, set()) == updated:
            return
        if updated:
            self._selected_filters[normalized_key] = updated
        else:
            self._selected_filters.pop(normalized_key, None)
        self.filtersChanged.emit()
        self._refilter()

    @Slot()
    def clearFilters(self) -> None:
        if not self._selected_filters:
            return
        self._selected_filters.clear()
        self.filtersChanged.emit()
        self._refilter()

    def replace_rows(self, rows: Iterable[StudentRow]) -> None:
        self.beginResetModel()
        self._source_rows = list(rows)
        self._rebuild_filter_options()
        self._rows = self._filtered_rows()
        self.endResetModel()
        self.countChanged.emit()

    def _filtered_rows(self) -> list[StudentRow]:
        return [
            row
            for row in self._source_rows
            if (not self._owned_only or row.owned)
            and matches_student_filters(row, self._selected_filters)
            and (
                not self._query
                or self._query in (
                    f"{row.display_name} {row.student_id} {row.school} {row.role} "
                    f"{row.attack_type} {row.defense_type} {row.combat_class or ''} {row.position or ''}"
                ).casefold()
            )
        ]

    def _rebuild_filter_options(self) -> None:
        options = build_filter_options(self._source_rows)
        self._filter_options = {
            key: [{"value": "", "label": "전체"}]
            + [{"value": option.value, "label": option.label} for option in values]
            for key, values in options.items()
        }
        self.filtersChanged.emit()

    def _refilter(self) -> None:
        self.beginResetModel()
        self._rows = self._filtered_rows()
        self.endResetModel()
        self.countChanged.emit()


class PlanListModel(QAbstractListModel):
    StudentIdRole = Qt.UserRole + 1
    DisplayNameRole = Qt.UserRole + 2
    PortraitUrlRole = Qt.UserRole + 3
    CurrentLevelRole = Qt.UserRole + 4
    CurrentStarRole = Qt.UserRole + 5
    TargetLevelRole = Qt.UserRole + 6
    TargetStarRole = Qt.UserRole + 7
    TargetExSkillRole = Qt.UserRole + 8
    TargetSkill1Role = Qt.UserRole + 9
    TargetSkill2Role = Qt.UserRole + 10
    TargetSkill3Role = Qt.UserRole + 11
    NotesRole = Qt.UserRole + 12

    countChanged = Signal()

    def __init__(self, rows: Iterable[PlanRow] = (), parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._rows = list(rows)

    def roleNames(self) -> dict[int, QByteArray]:  # noqa: N802
        return {
            self.StudentIdRole: QByteArray(b"studentId"),
            self.DisplayNameRole: QByteArray(b"displayName"),
            self.PortraitUrlRole: QByteArray(b"portraitUrl"),
            self.CurrentLevelRole: QByteArray(b"currentLevel"),
            self.CurrentStarRole: QByteArray(b"currentStar"),
            self.TargetLevelRole: QByteArray(b"targetLevel"),
            self.TargetStarRole: QByteArray(b"targetStar"),
            self.TargetExSkillRole: QByteArray(b"targetExSkill"),
            self.TargetSkill1Role: QByteArray(b"targetSkill1"),
            self.TargetSkill2Role: QByteArray(b"targetSkill2"),
            self.TargetSkill3Role: QByteArray(b"targetSkill3"),
            self.NotesRole: QByteArray(b"notes"),
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: N802
        return 0 if parent.isValid() else len(self._rows)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._rows):
            return None
        row = self._rows[index.row()]
        values = {
            self.StudentIdRole: row.student_id,
            self.DisplayNameRole: row.display_name,
            self.PortraitUrlRole: row.portrait_url,
            self.CurrentLevelRole: row.current_level,
            self.CurrentStarRole: row.current_star,
            self.TargetLevelRole: row.target_level,
            self.TargetStarRole: row.target_star,
            self.TargetExSkillRole: row.target_ex_skill,
            self.TargetSkill1Role: row.target_skill1,
            self.TargetSkill2Role: row.target_skill2,
            self.TargetSkill3Role: row.target_skill3,
            self.NotesRole: row.notes,
            Qt.DisplayRole: row.display_name,
        }
        return values.get(role)

    @Property(int, notify=countChanged)
    def count(self) -> int:
        return len(self._rows)

    def replace_rows(self, rows: Iterable[PlanRow]) -> None:
        self.beginResetModel()
        self._rows = list(rows)
        self.endResetModel()
        self.countChanged.emit()


class PlanResourceListModel(QAbstractListModel):
    CategoryRole = Qt.UserRole + 1
    NameRole = Qt.UserRole + 2
    QuantityRole = Qt.UserRole + 3

    countChanged = Signal()

    def __init__(self, rows: Iterable[PlanResourceRow] = (), parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._rows = list(rows)

    def roleNames(self) -> dict[int, QByteArray]:  # noqa: N802
        return {
            self.CategoryRole: QByteArray(b"category"),
            self.NameRole: QByteArray(b"name"),
            self.QuantityRole: QByteArray(b"quantity"),
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: N802
        return 0 if parent.isValid() else len(self._rows)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._rows):
            return None
        row = self._rows[index.row()]
        return {
            self.CategoryRole: row.category,
            self.NameRole: row.name,
            self.QuantityRole: row.quantity,
            Qt.DisplayRole: row.name,
        }.get(role)

    @Property(int, notify=countChanged)
    def count(self) -> int:
        return len(self._rows)

    def replace_rows(self, rows: Iterable[PlanResourceRow]) -> None:
        self.beginResetModel()
        self._rows = list(rows)
        self.endResetModel()
        self.countChanged.emit()


class TacticalMatchListModel(QAbstractListModel):
    MatchIdRole = Qt.UserRole + 1
    DateRole = Qt.UserRole + 2
    SeasonRole = Qt.UserRole + 3
    OpponentRole = Qt.UserRole + 4
    ResultRole = Qt.UserRole + 5
    ModeRole = Qt.UserRole + 6
    AttackDeckRole = Qt.UserRole + 7
    DefenseDeckRole = Qt.UserRole + 8
    NotesRole = Qt.UserRole + 9

    countChanged = Signal()

    def __init__(self, rows: Iterable[TacticalMatchRow] = (), parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._rows = list(rows)

    def roleNames(self) -> dict[int, QByteArray]:  # noqa: N802
        return {
            self.MatchIdRole: QByteArray(b"matchId"), self.DateRole: QByteArray(b"matchDate"),
            self.SeasonRole: QByteArray(b"season"), self.OpponentRole: QByteArray(b"opponent"),
            self.ResultRole: QByteArray(b"result"), self.ModeRole: QByteArray(b"mode"),
            self.AttackDeckRole: QByteArray(b"attackDeck"), self.DefenseDeckRole: QByteArray(b"defenseDeck"),
            self.NotesRole: QByteArray(b"notes"),
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: N802
        return 0 if parent.isValid() else len(self._rows)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._rows):
            return None
        row = self._rows[index.row()]
        return {
            self.MatchIdRole: row.match_id, self.DateRole: row.match_date, self.SeasonRole: row.season,
            self.OpponentRole: row.opponent, self.ResultRole: row.result, self.ModeRole: row.mode,
            self.AttackDeckRole: row.attack_deck, self.DefenseDeckRole: row.defense_deck,
            self.NotesRole: row.notes, Qt.DisplayRole: row.opponent,
        }.get(role)

    @Property(int, notify=countChanged)
    def count(self) -> int:
        return len(self._rows)

    def replace_rows(self, rows: Iterable[TacticalMatchRow]) -> None:
        self.beginResetModel()
        self._rows = list(rows)
        self.endResetModel()
        self.countChanged.emit()


_PLAN_RESOURCE_GROUPS = (
    ("신비 해방", "star_materials"),
    ("장비", "equipment_materials"),
    ("활동 보고서", "level_exp_items"),
    ("장비 강화", "equipment_exp_items"),
    ("전용무기 강화", "weapon_exp_items"),
    ("스킬 교재", "skill_books"),
    ("EX 오파츠", "ex_ooparts"),
    ("일반 스킬 오파츠", "skill_ooparts"),
    ("애용품", "favorite_item_materials"),
    ("능력 개방", "stat_materials"),
)


def plan_resource_rows(summary: PlanCostSummary) -> list[PlanResourceRow]:
    rows: list[PlanResourceRow] = []
    for category, field_name in _PLAN_RESOURCE_GROUPS:
        values = getattr(summary, field_name, {})
        for item_key, quantity in sorted(values.items(), key=lambda item: str(item[0]).casefold()):
            amount = _quantity(quantity)
            if amount <= 0:
                continue
            name = inventory_item_display_name(str(item_key)) or str(item_key)
            rows.append(PlanResourceRow(category, name, amount))
    return rows

class AppController(QObject):
    profileNameChanged = Signal()
    profilesChanged = Signal()
    inventoryStatusChanged = Signal()
    studentStatusChanged = Signal()
    selectedStudentIdChanged = Signal()
    planStatusChanged = Signal()
    planSummaryChanged = Signal()
    tacticalStatusChanged = Signal()
    tacticalDraftChanged = Signal()
    tacticalJokboChanged = Signal()
    statisticsChanged = Signal()
    windowCandidatesChanged = Signal()
    targetChanged = Signal()
    scanStateChanged = Signal()

    def __init__(
        self,
        *,
        load_data: bool = True,
        plan_path: Path | None = None,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        active_profile = get_active_profile_name()
        if load_data and not active_profile:
            activate_profile("Default")
            active_profile = get_active_profile_name("Default")
        self._profile_name = str(active_profile or "미선택")
        self._profiles = list_profiles()
        self._inventory_model = InventoryListModel(parent=self)
        self._student_model = StudentListModel(parent=self)
        self._student_model.countChanged.connect(self._refresh_statistics)
        self._plan_model = PlanListModel(parent=self)
        self._plan_resource_model = PlanResourceListModel(parent=self)
        self._tactical_model = TacticalMatchListModel(parent=self)
        self._inventory_status = "대기 중"
        self._student_status = "대기 중"
        self._plan_status = "대기 중"
        self._selected_student_id = ""
        self._tactical_query = ""
        self._tactical_status = "전적 대기 중"
        self._tactical_summary: dict[str, int] = {"total": 0, "wins": 0, "losses": 0, "today": 0}
        self._tactical_draft: dict[str, object] = {}
        self._tactical_jokbo_results: list[dict[str, object]] = []
        self._screenshot_workers: list[_ScreenshotWorker] = []
        self._statistics: dict[str, object] = {"total": 0, "owned": 0, "averageLevel": 0, "groups": []}
        self._plan_summary: dict[str, object] = {
            "credits": 0,
            "levelExp": 0,
            "equipmentExp": 0,
            "weaponExp": 0,
            "warnings": [],
        }
        self._window_candidates: list[dict[str, object]] = []
        config = load_config()
        self._target_hwnd = int(config.get("target_hwnd") or 0)
        self._target_title = str(config.get("target_title") or "")
        self._scanner_process: subprocess.Popen | None = None
        self._scanner_mode = ""
        self._scan_running = False
        self._scan_status = "스캔 대기 중"
        self._scan_progress = 0
        self._scan_log_lines: list[str] = []
        self._scan_status_offset = 0
        self._scan_timer = QTimer(self)
        self._scan_timer.setInterval(100)
        self._scan_timer.timeout.connect(self._poll_scan)
        self._student_rows: list[StudentRow] = []
        self._plan_path = plan_path
        self._tactical_path = get_storage_paths().current_dir / "tactical_challenge.db" if active_profile else None
        if self._plan_path is None and active_profile:
            self._plan_path = get_storage_paths().current_dir / "growth_plan.json"
        self._plan = (
            load_plan(self._plan_path)
            if self._plan_path is not None and (load_data or plan_path is not None)
            else GrowthPlan()
        )
        if load_data:
            self.reloadInventory()
            self.reloadStudents()
            self.reloadTactical()
            self.refreshWindows()

    @Property(str, notify=profileNameChanged)
    def profileName(self) -> str:
        return self._profile_name

    @Property(str, notify=profileNameChanged)
    def headerPortraitUrl(self) -> str:
        return _profile_portrait_url(self._profile_name)

    @Property("QStringList", notify=profilesChanged)
    def profiles(self) -> list[str]:
        return list(self._profiles)

    @Slot(str)
    def switchProfile(self, name: str) -> None:
        normalized = str(name or "").strip()
        if not normalized or (self._scan_running and normalized != self._profile_name):
            return
        activate_profile(normalized)
        self._profile_name = normalized
        self._profiles = list_profiles()
        if normalized not in self._profiles:
            self._profiles.append(normalized)
        self._plan_path = get_storage_paths().current_dir / "growth_plan.json"
        self._tactical_path = get_storage_paths().current_dir / "tactical_challenge.db"
        self._plan = load_plan(self._plan_path)
        self.profileNameChanged.emit()
        self.profilesChanged.emit()
        self.reloadInventory()
        self.reloadStudents()
        self.reloadTactical()

    @Property(QObject, constant=True)
    def inventoryModel(self) -> QObject:
        return self._inventory_model

    @Property(QObject, constant=True)
    def studentModel(self) -> QObject:
        return self._student_model

    @Property(QObject, constant=True)
    def planModel(self) -> QObject:
        return self._plan_model

    @Property(QObject, constant=True)
    def planResourceModel(self) -> QObject:
        return self._plan_resource_model

    @Property(QObject, constant=True)
    def tacticalModel(self) -> QObject:
        return self._tactical_model

    @Property(str, notify=tacticalStatusChanged)
    def tacticalStatus(self) -> str:
        return self._tactical_status

    @Property("QVariantMap", notify=tacticalStatusChanged)
    def tacticalSummary(self) -> dict[str, int]:
        return dict(self._tactical_summary)

    @Property("QVariantMap", notify=tacticalDraftChanged)
    def tacticalDraft(self) -> dict[str, object]:
        return dict(self._tactical_draft)

    @Property("QVariantList", notify=tacticalJokboChanged)
    def tacticalJokboResults(self) -> list[dict[str, object]]:
        return list(self._tactical_jokbo_results)

    @Property("QVariantMap", notify=statisticsChanged)
    def studentStatistics(self) -> dict[str, object]:
        return dict(self._statistics)

    @Slot()
    def _refresh_statistics(self) -> None:
        rows = list(self._student_model._rows)
        owned = [row for row in rows if row.owned]
        groups: list[dict[str, object]] = []
        for label, field_name in (
            ("학교", "school"), ("공격 타입", "attack_type"),
            ("방어 타입", "defense_type"), ("역할", "role"),
        ):
            counts = Counter(str(getattr(row, field_name) or "미분류") for row in rows)
            for value, count in counts.most_common():
                groups.append({"category": label, "label": value, "count": count})
        self._statistics = {
            "total": len(rows),
            "owned": len(owned),
            "averageLevel": round(sum(row.level for row in owned) / len(owned), 1) if owned else 0,
            "groups": groups,
        }
        self.statisticsChanged.emit()

    @Property(str, notify=inventoryStatusChanged)
    def inventoryStatus(self) -> str:
        return self._inventory_status

    @Property(str, notify=studentStatusChanged)
    def studentStatus(self) -> str:
        return self._student_status

    @Property(str, notify=planStatusChanged)
    def planStatus(self) -> str:
        return self._plan_status

    @Property("QVariantMap", notify=planSummaryChanged)
    def planSummary(self) -> dict[str, object]:
        return dict(self._plan_summary)

    @Property(str, notify=selectedStudentIdChanged)
    def selectedStudentId(self) -> str:
        return self._selected_student_id

    @selectedStudentId.setter
    def selectedStudentId(self, value: str) -> None:
        normalized = str(value or "")
        if normalized == self._selected_student_id:
            return
        self._selected_student_id = normalized
        self.selectedStudentIdChanged.emit()

    @Property("QVariantMap", notify=selectedStudentIdChanged)
    def selectedStudentDetail(self) -> dict[str, object]:
        student = next(
            (row for row in self._student_rows if row.student_id == self._selected_student_id),
            None,
        )
        if student is None:
            return {}
        return {
            "studentId": student.student_id,
            "displayName": student.display_name,
            "owned": student.owned,
            "portraitUrl": student.portrait_url,
            "level": student.level,
            "star": student.star,
            "school": student.school,
            "attackType": student.attack_type,
            "defenseType": student.defense_type,
            "role": student.role,
            "combatClass": student.combat_class or "",
            "position": student.position or "",
            "weaponType": student.weapon_type or "",
            "weaponState": student.weapon_state or "",
            "weaponStar": student.weapon_star or 0,
            "weaponLevel": student.weapon_level or 0,
            "skills": [student.ex_skill or 0, student.skill1 or 0, student.skill2 or 0, student.skill3 or 0],
            "equipment": [student.equip1 or "-", student.equip2 or "-", student.equip3 or "-"],
            "equipmentLevels": [student.equip1_level or 0, student.equip2_level or 0, student.equip3_level or 0],
            "combatStats": [student.combat_hp or 0, student.combat_atk or 0, student.combat_def or 0, student.combat_heal or 0],
            "potentialStats": [student.stat_hp or 0, student.stat_atk or 0, student.stat_heal or 0],
        }

    @Property("QVariantList", notify=windowCandidatesChanged)
    def windowCandidates(self) -> list[dict[str, object]]:
        return list(self._window_candidates)

    @Property(str, notify=targetChanged)
    def targetTitle(self) -> str:
        return self._target_title

    @Property(bool, notify=targetChanged)
    def targetConnected(self) -> bool:
        if not self._target_hwnd:
            return False
        return any(int(row.get("hwnd") or 0) == self._target_hwnd for row in self._window_candidates)

    @Property(bool, notify=scanStateChanged)
    def scanRunning(self) -> bool:
        return self._scan_running

    @Property(str, notify=scanStateChanged)
    def scanStatus(self) -> str:
        return self._scan_status

    @Property(int, notify=scanStateChanged)
    def scanProgress(self) -> int:
        return self._scan_progress

    @Property(str, notify=scanStateChanged)
    def scanLog(self) -> str:
        return "\n".join(self._scan_log_lines)

    @Slot()
    def reloadInventory(self) -> None:
        try:
            rows = load_inventory_rows()
        except Exception as exc:
            self._inventory_status = f"불러오기 실패: {exc}"
        else:
            self._inventory_model.replace_rows(rows)
            self._inventory_status = f"{len(rows):,}개 항목을 불러왔습니다."
        self.inventoryStatusChanged.emit()

    @Slot()
    def reloadStudents(self) -> None:
        try:
            rows = load_student_rows()
        except Exception as exc:
            self._student_status = f"불러오기 실패: {exc}"
        else:
            self._student_rows = rows
            self._student_model.replace_rows(rows)
            if self._selected_student_id and not any(
                row.student_id == self._selected_student_id for row in rows
            ):
                self._selected_student_id = ""
            self.selectedStudentIdChanged.emit()
            owned_count = sum(1 for row in rows if row.owned)
            self._student_status = f"전체 {len(rows):,}명 · 보유 {owned_count:,}명"
        self.studentStatusChanged.emit()
        self.reloadPlan()

    def _plan_rows(self) -> list[PlanRow]:
        students = {row.student_id: row for row in self._student_rows}
        rows: list[PlanRow] = []
        for goal in self._plan.goals:
            student = students.get(goal.student_id)
            display_name = (
                student.display_name
                if student is not None
                else str(student_meta.field(goal.student_id, "display_name", goal.student_id) or goal.student_id)
            )
            current_level = student.level if student is not None else 0
            current_star = student.star if student is not None else 0
            rows.append(
                PlanRow(
                    student_id=goal.student_id,
                    display_name=display_name,
                    portrait_url=student.portrait_url if student is not None else _student_portrait_url(goal.student_id),
                    current_level=current_level,
                    current_star=current_star,
                    target_level=max(1, int(goal.target_level or current_level or 1)),
                    target_star=max(1, int(goal.target_star or current_star or 1)),
                    target_ex_skill=int(goal.target_ex_skill or 1),
                    target_skill1=int(goal.target_skill1 or 1),
                    target_skill2=int(goal.target_skill2 or 1),
                    target_skill3=int(goal.target_skill3 or 1),
                    notes=str(goal.notes or ""),
                )
            )
        return rows

    @Slot()
    def reloadPlan(self) -> None:
        if self._plan_path is not None:
            try:
                self._plan = load_plan(self._plan_path)
            except (OSError, ValueError, TypeError) as exc:
                self._plan_status = f"불러오기 실패: {exc}"
                self.planStatusChanged.emit()
                return
        rows = self._plan_rows()
        self._plan_model.replace_rows(rows)
        self._refresh_plan_summary()
        self._plan_status = f"계획 학생 {len(rows):,}명"
        self.planStatusChanged.emit()

    def _refresh_plan_summary(self) -> None:
        try:
            summary = calculate_plan_totals(
                {row.student_id: row for row in self._student_rows},
                self._plan,
            )
        except (OSError, ValueError, TypeError, KeyError) as exc:
            summary = PlanCostSummary(warnings=[f"계산 실패: {exc}"])
        self._plan_resource_model.replace_rows(plan_resource_rows(summary))
        self._plan_summary = {
            "credits": summary.credits,
            "levelExp": summary.level_exp,
            "equipmentExp": summary.equipment_exp,
            "weaponExp": summary.weapon_exp,
            "warnings": list(summary.warnings),
        }
        self.planSummaryChanged.emit()

    def _save_plan_and_refresh(self) -> None:
        if self._plan_path is None:
            self._plan_status = "활성 프로필이 없어 저장할 수 없습니다."
            self.planStatusChanged.emit()
            return
        save_plan(self._plan_path, self._plan)
        self._plan_model.replace_rows(self._plan_rows())
        self._refresh_plan_summary()
        self._plan_status = f"계획 학생 {len(self._plan.goals):,}명 · 저장됨"
        self.planStatusChanged.emit()

    @Slot(str)
    def searchTactical(self, query: str) -> None:
        self._tactical_query = str(query or "").strip()
        self.reloadTactical()

    @Slot()
    def reloadTactical(self) -> None:
        if self._tactical_path is None:
            self._tactical_model.replace_rows([])
            return
        try:
            matches = query_tactical_matches(self._tactical_path, self._tactical_query, limit=500)
            rows = []
            for match in matches:
                is_defense = bool(deck_template(match.my_defense) or deck_template(match.opponent_attack))
                rows.append(TacticalMatchRow(
                    match_id=match.id,
                    match_date=match.date,
                    season=match.season,
                    opponent=match.opponent,
                    result=match.result,
                    mode="defense" if is_defense else "attack",
                    attack_deck=deck_template(match.opponent_attack if is_defense else match.my_attack),
                    defense_deck=deck_template(match.my_defense if is_defense else match.opponent_defense),
                    notes=match.notes,
                ))
            self._tactical_model.replace_rows(rows)
            self._tactical_summary = tactical_match_summary(self._tactical_path, date.today().isoformat())
            total = tactical_match_count(self._tactical_path, self._tactical_query)
            self._tactical_status = f"검색 {total:,}건 · 최대 500건 표시"
        except (OSError, sqlite3.Error, ValueError, TypeError) as exc:
            self._tactical_status = f"전적 불러오기 실패: {exc}"
        self.tacticalStatusChanged.emit()

    @Slot(str, str, str, str, str, str, str)
    def addTacticalMatch(
        self,
        match_date: str,
        season: str,
        opponent: str,
        result: str,
        mode: str,
        attack_deck: str,
        defense_deck: str,
    ) -> None:
        if self._tactical_path is None or not str(opponent or "").strip():
            self._tactical_status = "상대 이름을 입력해 주세요."
            self.tacticalStatusChanged.emit()
            return
        attack = parse_deck_template(attack_deck)
        defense = parse_deck_template(defense_deck)
        is_defense = mode == "defense"
        now = datetime.now().isoformat(timespec="seconds")
        match = TacticalMatch(
            id=f"tc-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:6]}",
            date=str(match_date or date.today().isoformat()).strip(),
            season=str(season or "").strip(),
            opponent=str(opponent).strip(),
            result="loss" if result == "loss" else "win",
            my_attack=TacticalDeck() if is_defense else attack,
            opponent_defense=TacticalDeck() if is_defense else defense,
            my_defense=defense if is_defense else TacticalDeck(),
            opponent_attack=attack if is_defense else TacticalDeck(),
            created_at=now,
        )
        upsert_tactical_match(self._tactical_path, match)
        self.reloadTactical()

    @Slot(str)
    def analyzeTacticalScreenshot(self, source: str) -> None:
        path = QUrl(str(source or "")).toLocalFile() or str(source or "")
        if not path:
            return
        self._tactical_status = "전술대항전 스크린샷을 분석하고 있습니다."
        self.tacticalStatusChanged.emit()
        worker = _ScreenshotWorker(path)
        self._screenshot_workers.append(worker)
        worker.signals.completed.connect(
            lambda loaded_path, readout, current=worker: self._on_tactical_screenshot_loaded(current, loaded_path, readout)
        )
        worker.signals.failed.connect(
            lambda message, current=worker: self._on_tactical_screenshot_failed(current, message)
        )
        QThreadPool.globalInstance().start(worker)

    def _release_screenshot_worker(self, worker: _ScreenshotWorker) -> None:
        if worker in self._screenshot_workers:
            self._screenshot_workers.remove(worker)

    def _on_tactical_screenshot_loaded(self, worker: _ScreenshotWorker, path: str, readout: object) -> None:
        self._release_screenshot_worker(worker)
        mode = str(getattr(readout, "mode", "attack") or "attack")
        left = getattr(readout, "left", None)
        right = getattr(readout, "right", None)
        left_deck = deck_template(getattr(left, "deck", None))
        right_deck = deck_template(getattr(right, "deck", None))
        self._tactical_draft = {
            "date": tactical_screenshot_date_from_path(path) or date.today().isoformat(),
            "result": str(getattr(readout, "result", "win") or "win"),
            "mode": mode,
            "attackDeck": left_deck if mode != "defense" else right_deck,
            "defenseDeck": right_deck if mode != "defense" else left_deck,
            "confidence": round(float(getattr(readout, "confidence", 0.0)), 3),
            "warnings": list(getattr(readout, "warnings", []) or []),
            "sourcePath": path,
        }
        self._tactical_status = f"스크린샷 분석 완료 · 신뢰도 {self._tactical_draft['confidence']}"
        self.tacticalDraftChanged.emit()
        self.tacticalStatusChanged.emit()

    def _on_tactical_screenshot_failed(self, worker: _ScreenshotWorker, message: str) -> None:
        self._release_screenshot_worker(worker)
        self._tactical_status = f"스크린샷 분석 실패: {message}"
        self.tacticalStatusChanged.emit()

    @Slot(str, str)
    def searchTacticalJokbo(self, defense_deck: str, query: str = "") -> None:
        if self._tactical_path is None:
            return
        defense = parse_deck_template(defense_deck)
        if not defense.strikers and not defense.supports:
            self._tactical_jokbo_results = []
            self._tactical_status = "검색할 상대 방어덱을 입력해 주세요."
            self.tacticalJokboChanged.emit()
            self.tacticalStatusChanged.emit()
            return
        try:
            metadata = load_tactical_challenge(self._tactical_path, load_matches=False)
            result = search_jokbo_from_storage(self._tactical_path, metadata, defense, query=str(query or ""))
            rows: list[dict[str, object]] = []
            for item in result.get("manual", []):
                entry = item["entry"]
                rows.append({
                    "source": "수동 족보",
                    "attackDeck": deck_template(entry.attack),
                    "defenseDeck": deck_template(entry.defense),
                    "wins": int(item.get("wins") or 0),
                    "losses": int(item.get("losses") or 0),
                    "winRate": round(float(item.get("win_rate") or 0.0), 1),
                    "notes": entry.notes or "",
                })
            for item in result.get("observed", []):
                rows.append({
                    "source": "전적 기반",
                    "attackDeck": deck_template(item["attack"]),
                    "defenseDeck": deck_template(item["defense"]),
                    "wins": int(item.get("wins") or 0),
                    "losses": int(item.get("losses") or 0),
                    "winRate": round(float(item.get("win_rate") or 0.0), 1),
                    "notes": "",
                })
            self._tactical_jokbo_results = rows
            self._tactical_status = f"일치하는 족보 {len(rows):,}건"
        except (OSError, sqlite3.Error, ValueError, TypeError, KeyError) as exc:
            self._tactical_jokbo_results = []
            self._tactical_status = f"족보 검색 실패: {exc}"
        self.tacticalJokboChanged.emit()
        self.tacticalStatusChanged.emit()

    @Slot(str, str, str)
    def addTacticalJokbo(self, defense_deck: str, attack_deck: str, notes: str) -> None:
        if self._tactical_path is None:
            return
        defense = parse_deck_template(defense_deck)
        attack = parse_deck_template(attack_deck)
        if not (defense.strikers or defense.supports) or not (attack.strikers or attack.supports):
            self._tactical_status = "방어덱과 공격덱을 모두 입력해 주세요."
            self.tacticalStatusChanged.emit()
            return
        entry = TacticalJokboEntry(
            id=f"jokbo-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:6]}",
            defense=defense,
            attack=attack,
            notes=str(notes or "").strip(),
            updated_at=datetime.now().isoformat(timespec="seconds"),
        )
        upsert_tactical_jokbo(self._tactical_path, entry)
        self._tactical_status = "족보를 저장했습니다."
        self.tacticalStatusChanged.emit()
        self.searchTacticalJokbo(defense_deck, "")

    @Slot(str)
    def addPlanStudent(self, student_id: str) -> None:
        normalized = str(student_id or "").strip()
        if not normalized or any(goal.student_id == normalized for goal in self._plan.goals):
            return
        self._plan.goals.append(StudentGoal(student_id=normalized))
        self._save_plan_and_refresh()

    @Slot(str)
    def removePlanStudent(self, student_id: str) -> None:
        normalized = str(student_id or "").strip()
        remaining = [goal for goal in self._plan.goals if goal.student_id != normalized]
        if len(remaining) == len(self._plan.goals):
            return
        self._plan.goals = remaining
        self._save_plan_and_refresh()

    @Slot(str, str, int)
    def setPlanTarget(self, student_id: str, field: str, value: int) -> None:
        allowed = {
            "target_level": (1, 90),
            "target_star": (1, 5),
            "target_weapon_star": (0, 4),
            "target_weapon_level": (0, 60),
            "target_ex_skill": (1, 5),
            "target_skill1": (1, 10),
            "target_skill2": (1, 10),
            "target_skill3": (1, 10),
            "target_equip1_tier": (0, 10),
            "target_equip2_tier": (0, 10),
            "target_equip3_tier": (0, 10),
            "target_equip1_level": (0, 70),
            "target_equip2_level": (0, 70),
            "target_equip3_level": (0, 70),
            "target_equip4_tier": (0, 2),
            "target_stat_hp": (0, 25),
            "target_stat_atk": (0, 25),
            "target_stat_heal": (0, 25),
        }
        if field not in allowed:
            return
        goal = next((item for item in self._plan.goals if item.student_id == student_id), None)
        if goal is None:
            return
        if int(value) <= 0:
            setattr(goal, field, None)
            self._save_plan_and_refresh()
            return
        minimum, maximum = allowed[field]
        setattr(goal, field, max(minimum, min(maximum, int(value))))
        self._save_plan_and_refresh()

    @Slot(str, result="QVariantMap")
    def planGoalDetail(self, student_id: str) -> dict[str, object]:
        goal = next((item for item in self._plan.goals if item.student_id == student_id), None)
        if goal is None:
            return {}
        student = next((row for row in self._student_rows if row.student_id == student_id), None)
        payload = {
            field_name: getattr(goal, field_name) or 0
            for field_name in StudentGoal.__dataclass_fields__
            if field_name.startswith("target_")
        }
        payload.update({
            "studentId": student_id,
            "displayName": student.display_name if student else student_id,
            "portraitUrl": student.portrait_url if student else _student_portrait_url(student_id),
            "favorite": bool(goal.favorite),
            "notes": str(goal.notes or ""),
        })
        return payload

    @Slot(str, bool)
    def setPlanFavorite(self, student_id: str, value: bool) -> None:
        goal = next((item for item in self._plan.goals if item.student_id == student_id), None)
        if goal is None:
            return
        goal.favorite = bool(value)
        self._save_plan_and_refresh()

    @Slot(str, str)
    def setPlanNotes(self, student_id: str, value: str) -> None:
        goal = next((item for item in self._plan.goals if item.student_id == student_id), None)
        if goal is None:
            return
        goal.notes = str(value or "")
        self._save_plan_and_refresh()

    @Slot()
    def launchLegacyViewer(self) -> None:
        creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW") else 0
        try:
            subprocess.Popen(
                [sys.executable, "-m", "gui.viewer_app_qt"],
                cwd=str(BASE_DIR),
                creationflags=creationflags,
            )
        except OSError as exc:
            self._scan_status = f"레거시 Viewer 실행 실패: {exc}"
            self.scanStateChanged.emit()

    @Slot()
    def refreshWindows(self) -> None:
        try:
            from core.capture import get_all_windows

            candidates = []
            for window in get_all_windows():
                hwnd = int(window.get("hwnd") or 0)
                title = str(window.get("title") or "")
                if not hwnd or not title:
                    continue
                candidates.append(
                    {
                        "hwnd": str(hwnd),
                        "title": title,
                        "size": str(window.get("size") or ""),
                        "likelyBA": "blue archive" in title.casefold() or "bluearchive" in title.casefold(),
                    }
                )
            candidates.sort(key=lambda row: (not bool(row["likelyBA"]), str(row["title"]).casefold()))
            self._window_candidates = candidates
        except Exception as exc:
            self._window_candidates = []
            self._scan_status = f"창 목록을 가져오지 못했습니다: {exc}"
            self.scanStateChanged.emit()
        self.windowCandidatesChanged.emit()
        self.targetChanged.emit()

    @Slot(str, str)
    def connectWindow(self, hwnd: str, title: str) -> None:
        try:
            resolved_hwnd = int(str(hwnd or "0"))
        except ValueError:
            resolved_hwnd = 0
        if not resolved_hwnd:
            return
        config = load_config()
        config["target_hwnd"] = resolved_hwnd
        config["target_title"] = str(title or "")
        save_config(config)
        from core.capture import set_target_window

        set_target_window(resolved_hwnd, str(title or ""))
        self._target_hwnd = resolved_hwnd
        self._target_title = str(title or "")
        self._scan_status = f"BA 창 연결: {self._target_title}"
        self.targetChanged.emit()
        self.scanStateChanged.emit()

    @Slot()
    def disconnectWindow(self) -> None:
        config = load_config()
        config.pop("target_hwnd", None)
        config.pop("target_title", None)
        save_config(config)
        from core.capture import clear_target

        clear_target()
        self._target_hwnd = 0
        self._target_title = ""
        self._scan_status = "BA 창 연결 해제"
        self.targetChanged.emit()
        self.scanStateChanged.emit()

    def _scan_status_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_status.jsonl"

    def _scan_ack_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_status_ack.json"

    def _scan_stop_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_stop_requested.flag"

    def _scanner_command(self, mode: str, item_filter: str = "") -> list[str]:
        command = [sys.executable]
        if not getattr(sys, "frozen", False):
            command.append(str(BASE_DIR / "main.py"))
        command.extend(["--scanner", "--use-saved-target", "--suppress-overlay", "--auto-scan", mode])
        if mode == "items" and item_filter:
            command.extend(["--item-scan-filter", item_filter])
        return command

    @Slot(str)
    def startScan(self, mode: str) -> None:
        normalized_mode = str(mode or "").strip()
        if normalized_mode not in {"resources", "items", "equipment", "students", "student_current", "all"}:
            return
        if self._scanner_process is not None and self._scanner_process.poll() is None:
            self._scan_status = "이미 스캔이 실행 중입니다."
            self.scanStateChanged.emit()
            return
        if not self._target_hwnd:
            self._scan_status = "먼저 Blue Archive 창을 연결해 주세요."
            self.scanStateChanged.emit()
            return
        try:
            from core.capture import activate_target_window, set_target_window

            set_target_window(self._target_hwnd, self._target_title)
            activate_target_window()
            self._scan_stop_path().unlink(missing_ok=True)
            reset_status_log(self._scan_status_path())
            write_status_ack(self._scan_ack_path(), 0)
            creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW") else 0
            self._scanner_process = subprocess.Popen(
                self._scanner_command(normalized_mode, "all" if normalized_mode == "items" else ""),
                cwd=str(BASE_DIR),
                creationflags=creationflags,
            )
        except Exception as exc:
            self._scanner_process = None
            self._scan_status = f"스캐너 실행 실패: {exc}"
            self.scanStateChanged.emit()
            return
        self._scanner_mode = normalized_mode
        self._scan_running = True
        self._scan_progress = 0
        self._scan_status_offset = 0
        self._scan_log_lines = []
        self._scan_status = f"{normalized_mode} 스캔 준비 중"
        self._scan_timer.start()
        self.scanStateChanged.emit()

    @Slot(str)
    def startItemScan(self, item_filter: str) -> None:
        normalized = str(item_filter or "all").strip()
        if normalized not in {"all", "tech_notes", "tactical_bd", "ooparts", "student_elephs", "presents", "activity_reports"}:
            return
        if self._scanner_process is not None and self._scanner_process.poll() is None:
            return
        if not self._target_hwnd:
            self._scan_status = "먼저 Blue Archive 창을 연결해 주세요."
            self.scanStateChanged.emit()
            return
        try:
            from core.capture import activate_target_window, set_target_window
            set_target_window(self._target_hwnd, self._target_title)
            activate_target_window()
            self._scan_stop_path().unlink(missing_ok=True)
            reset_status_log(self._scan_status_path())
            write_status_ack(self._scan_ack_path(), 0)
            creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW") else 0
            self._scanner_process = subprocess.Popen(
                self._scanner_command("items", normalized), cwd=str(BASE_DIR), creationflags=creationflags
            )
        except Exception as exc:
            self._scanner_process = None
            self._scan_status = f"스캐너 실행 실패: {exc}"
            self.scanStateChanged.emit()
            return
        self._scanner_mode = "items"
        self._scan_running = True
        self._scan_progress = 0
        self._scan_status_offset = 0
        self._scan_log_lines = []
        self._scan_status = f"아이템 스캔 준비 중 · {normalized}"
        self._scan_timer.start()
        self.scanStateChanged.emit()

    @Slot()
    def stopScan(self) -> None:
        if self._scanner_process is None or self._scanner_process.poll() is not None:
            return
        try:
            path = self._scan_stop_path()
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("stop", encoding="utf-8")
            self._scan_status = "스캔 중지 요청을 전달했습니다."
        except OSError as exc:
            self._scan_status = f"중지 요청 실패: {exc}"
        self.scanStateChanged.emit()

    def _poll_scan(self) -> None:
        try:
            events, self._scan_status_offset = read_status_events(
                self._scan_status_path(), self._scan_status_offset
            )
        except Exception:
            events = []
        last_sequence = 0
        for event in events:
            message = str(event.get("message") or "").strip()
            if message:
                self._scan_log_lines.append(message)
                self._scan_log_lines = self._scan_log_lines[-80:]
                self._scan_status = message
            fields = event.get("fields") if isinstance(event.get("fields"), dict) else {}
            if str(event.get("id") or "") == "progress.update":
                current = _quantity(fields.get("current"))
                total = _quantity(fields.get("total"))
                self._scan_progress = int(round((current / total) * 100)) if total else 0
            try:
                last_sequence = max(last_sequence, int(event.get("seq") or 0))
            except (TypeError, ValueError):
                pass
        if last_sequence:
            try:
                write_status_ack(self._scan_ack_path(), last_sequence)
            except OSError:
                pass

        process = self._scanner_process
        code = process.poll() if process is not None else None
        if process is not None and code is not None:
            self._scanner_process = None
            self._scanner_mode = ""
            self._scan_running = False
            self._scan_progress = 100 if code == 0 else self._scan_progress
            self._scan_status = "스캔 완료" if code == 0 else f"스캔 종료 코드: {code}"
            self._scan_timer.stop()
            if code == 0:
                self.reloadInventory()
                self.reloadStudents()
        self.scanStateChanged.emit()

    @Slot()
    def shutdown(self) -> None:
        self._scan_timer.stop()
        process = self._scanner_process
        if process is not None and process.poll() is None:
            process.terminate()
