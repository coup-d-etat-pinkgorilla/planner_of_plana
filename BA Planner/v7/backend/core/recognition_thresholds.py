"""Named recognition thresholds (C4): one table instead of literals spread through recognizers.

Each entry keeps the value it had when it was introduced; C4 only moves values here. Changing a
value is a C7 decision recorded in the scanner consolidation status document.

``field`` / ``source`` / ``resolution`` describe where a threshold applies ("*" = any,
"native1280" / "native2560" = resolution-specific). ``kind`` is score, margin, similarity, ratio, or intensity (8-bit luminance).
"""
from __future__ import annotations

from dataclasses import dataclass


P5 = "docs/migration/p5-scanner-matcher/scanner-runtime.md"
F2 = "docs/migration/scanner-fallback-restoration/f2-results.md"
F3 = "docs/migration/scanner-fallback-restoration/f3-results.md"
F4 = "docs/migration/scanner-fallback-restoration/f4-results.md"
F5 = "docs/migration/scanner-fallback-restoration/f5-results.md"
F6 = "docs/migration/scanner-fallback-restoration/f6-results.md"
F7 = "docs/migration/scanner-fallback-restoration/f7-results.md"
F8 = "docs/migration/scanner-fallback-restoration/f8-results.md"
S2W = "docs/migration/student-weapon-basic-recognition-2026-09-05.md"
S3B_POSITION = "docs/migration/student-scan-v7-session-s3b-position-bank-handoff"
F9 = "docs/migration/scanner-fallback-restoration/f9-results.md"
F10 = "docs/migration/scanner-fallback-restoration/f10-results.md"
F12 = "docs/migration/scanner-fallback-restoration/f12-results.md"


@dataclass(frozen=True, slots=True)
class Threshold:
    name: str
    value: float
    kind: str
    phase: str
    doc: str
    field: str = "*"
    source: str = "*"
    resolution: str = "*"
    note: str = ""


_ENTRIES = (
    # Inventory grid adapter (P5 runtime, F12 profile gate).
    Threshold("inventory.visible_content.ratio", 0.12, "ratio", "P5", P5, "slot", note="share of non-background pixels that makes a slot non-empty"),
    Threshold("inventory.grid_icon.score", 0.80, "score", "P5", P5, "item_id", "grid_icon_template"),
    Threshold("inventory.grid_icon.margin", 0.03, "margin", "P5", P5, "item_id", "grid_icon_template"),
    Threshold("inventory.grid_icon.floor_without_detail", 0.55, "score", "P5", P5, "item_id", "grid_same_crop_rematch",
              note="below this a slot is dropped when no detail panel can confirm it"),
    Threshold("inventory.profile_gate.outside_score", 0.55, "score", "F12", F12, "item_id", "inventory_profile_catalog",
              note="a global match this strong outside the scan profile skips the slot (see C0-1)"),
    Threshold("inventory.slot_count.score", 0.70, "score", "P5", P5, "quantity", "slot_count_glyph"),
    Threshold("inventory.slot_count.margin", 0.04, "margin", "P5", P5, "quantity", "slot_count_glyph"),
    Threshold("inventory.wheel.same_frame", 0.995, "similarity", "P5", P5, "scroll_terminal", "stable_frame_overlap",
              note="navigation-free fallback: whole-frame similarity after one wheel that means no motion"),
    Threshold("inventory.wheel.zero_overlap", 0.05, "similarity", "P5", P5, "scroll_overlap", "frame_overlap"),
    # Inventory navigation (F10).
    Threshold("inventory.menu.filter_title", 0.85, "score", "F10", F10, "menu", "filter_title"),
    Threshold("inventory.menu.sort_check_visible", 0.68, "score", "F10", F10, "menu", "sort_rule_check"),
    Threshold("inventory.sort_check.item", 0.68, "score", "F10", F10, "sort", "sort_rule_check"),
    Threshold("inventory.sort_check.equipment", 0.70, "score", "F10", F10, "sort", "eq_sort_rule_check"),
    Threshold("inventory.scroll.settled_same", 0.985, "similarity", "F10", F10, "scroll", "page_signature",
              note="consecutive captures this similar count toward a settled page"),
    Threshold("inventory.scroll.no_motion_same", 0.97, "similarity", "F10", F10, "scroll_terminal", "verified_no_motion",
              note="before/after page similarity that means the drag did not move the list"),
    Threshold("inventory.scroll.overlap_score", 0.94, "score", "F10", F10, "scroll_overlap", "verified_row_overlap"),
    Threshold("inventory.scroll.tail_residual_floor", 0.88, "score", "F10", F10, "scroll_overlap", "verified_tail_residual"),
    Threshold("inventory.scroll.overlap_margin.item", 0.03, "margin", "F10", F10, "scroll_overlap", "verified_row_overlap"),
    Threshold("inventory.scroll.overlap_margin.equipment", 0.025, "margin", "F10", F10, "scroll_overlap", "verified_row_overlap"),
    # Inventory detail panel (F9).
    Threshold("inventory.detail.source_title.correlation", 0.8, "score", "F9", F9, "source", "inventory_detail_title"),
    Threshold("inventory.detail.source_title.color", 0.95, "similarity", "F9", F9, "source", "inventory_detail_title"),
    Threshold("inventory.detail.selection.edge_fraction", 0.15, "ratio", "F9", F9, "selection", "selection_border"),
    Threshold("inventory.detail.x_mark.score", 0.72, "score", "F9", F9, "quantity", "inventory_detail_count"),
    Threshold("inventory.detail.x_mark.margin", 0.025, "margin", "F9", F9, "quantity", "inventory_detail_count"),
    Threshold("inventory.detail.digit.score", 0.66, "score", "F9", F9, "quantity", "inventory_detail_count"),
    Threshold("inventory.detail.digit.margin", 0.025, "margin", "F9", F9, "quantity", "inventory_detail_count"),
    Threshold("inventory.detail.same_grid.color", 0.975, "similarity", "F9", F9, "selection", "same_grid"),
    # Student adapter identity defaults (P5).
    Threshold("student.identity.template.score", 0.82, "score", "P5", P5, "student_id", "student_texture_template"),
    Threshold("student.identity.template.margin", 0.04, "margin", "P5", P5, "student_id", "student_texture_template"),
    # Student panel transitions (F2).
    Threshold("student.panel.tab.correlation_floor", 0.75, "score", "F2", F2, "panel_state", "active_tab",
              note="an active tab needs this glyph correlation before its colour score counts"),
    Threshold("student.panel.title.score", 0.86, "score", "F2", F2, "panel_state", "panel_title"),
    Threshold("student.panel.title.margin", 0.04, "margin", "F2", F2, "panel_state", "panel_title"),
    Threshold("student.panel.title.ambiguous", 0.70, "score", "F2", F2, "panel_state", "panel_title",
              note="a panel title this strong but not decisive blocks reading the dimmed tab underneath"),
    Threshold("student.panel.tab.score", 0.90, "score", "F2", F2, "panel_state", "active_tab"),
    Threshold("student.panel.same_student.name_color", 0.985, "similarity", "F2", F2, "student_id", "panel_return"),
    Threshold("student.panel.same_student.portrait_color", 0.90, "similarity", "F2", F2, "student_id", "panel_return"),
    # Student entry / list recovery (F8).
    Threshold("student.entry.screen.score", 0.90, "score", "F8", F8, "screen_state", "entry_screen"),
    Threshold("student.entry.screen.margin", 0.10, "margin", "F8", F8, "screen_state", "entry_screen"),
    Threshold("student.entry.list_card.score", 0.90, "score", "F8", F8, "screen_state", "student_list_card"),
    # Equipment menu controls (F7).
    Threshold("student.equipment.show_all.score", 0.75, "score", "F7", F7, "equipment_show_all", "equipment_show_all_template"),
    Threshold("student.equipment.show_all.margin", 0.10, "margin", "F7", F7, "equipment_show_all", "equipment_show_all_template"),
    Threshold("student.equipment.growth_off.light", 0.90, "ratio", "F7", F7, "equipment_growth", "equipment_growth_template"),
    Threshold("student.equipment.growth_off.neutral_card", 0.90, "ratio", "F7", F7, "equipment_growth", "equipment_growth_template"),
    # Student weapon basic reads (S2 weapon).
    Threshold("student.weapon.signal.min_mean", 35.0, "intensity", "S2", S2W, "weapon_level", "basic_weapon_level_glyph"),
    Threshold("student.weapon.signal.min_stddev", 8.0, "intensity", "S2", S2W, "weapon_level", "basic_weapon_level_glyph"),
    Threshold("student.weapon.state.score", 0.72, "score", "S2", S2W, "weapon_state", "basic_weapon_state_template"),
    Threshold("student.weapon.state.margin", 0.10, "margin", "S2", S2W, "weapon_state", "basic_weapon_state_template"),
    Threshold("student.weapon.menu_star.score", 0.60, "score", "S2", S2W, "weapon_star", "weapon_menu_star"),
    Threshold("student.weapon.menu_star.margin", 0.02, "margin", "S2", S2W, "weapon_star", "weapon_menu_star"),
    Threshold("student.weapon.menu_level.null_second_digit", 0.60, "score", "S2", S2W, "weapon_level", "weapon_menu_level",
              note="a blank second digit this confident means a one-digit level"),
    Threshold("student.weapon.menu_level.score", 0.55, "score", "S2", S2W, "weapon_level", "weapon_menu_level"),
    Threshold("student.weapon.menu_level.margin", 0.015, "margin", "S2", S2W, "weapon_level", "weapon_menu_level"),
    # Student level tab (F4).
    Threshold("student.level.blank_occupancy", 0.005, "ratio", "F4", F4, "level", "level_tab_template"),
    Threshold("student.level.glyph_occupancy.min", 0.025, "ratio", "F4", F4, "level", "level_tab_template"),
    Threshold("student.level.glyph_occupancy.max", 0.75, "ratio", "F4", F4, "level", "level_tab_template"),
    Threshold("student.level.tab.score", 0.58, "score", "F4", F4, "level", "level_tab_template"),
    Threshold("student.level.tab.margin", 0.035, "margin", "F4", F4, "level", "level_tab_template"),
    # Student star tab (F5).
    Threshold("student.star.tab.score", 0.60, "score", "F5", F5, "student_star", "star_tab_template"),
    Threshold("student.star.tab.margin", 0.035, "margin", "F5", F5, "student_star", "star_tab_template"),
    # Student skill panel (F6).
    Threshold("student.skill.show_all.score", 0.75, "score", "F6", F6, "skill_show_all", "skill_show_all_template"),
    Threshold("student.skill.show_all.margin", 0.10, "margin", "F6", F6, "skill_show_all", "skill_show_all_template"),
    Threshold("student.skill.menu_digit.score", 0.70, "score", "F6", F6, "skill", "skill_menu_digit"),
    Threshold("student.skill.menu_digit.margin", 0.035, "margin", "F6", F6, "skill", "skill_menu_digit"),
    # Student potential (F3).
    Threshold("student.potential.badge.blue_present", 0.08, "ratio", "F3", F3, "stat_*", "potential_badge"),
    Threshold("student.potential.badge.blue_absent", 0.02, "ratio", "F3", F3, "stat_*", "potential_badge_absent"),
    Threshold("student.potential.badge.light_absent", 0.65, "ratio", "F3", F3, "stat_*", "potential_badge_absent"),
    Threshold("student.potential.badge.dark_absent", 0.005, "ratio", "F3", F3, "stat_*", "potential_badge_absent"),
    Threshold("student.potential.basic.margin", 0.035, "margin", "F3", F3, "stat_*", "potential_basic_template"),
    Threshold("student.potential.basic.score", 0.78, "score", "F3", F3, "stat_*", "potential_basic_template"),
    Threshold("student.potential.basic_badge.score", 0.62, "score", "F3", F3, "stat_*", "potential_basic_template",
              note="weaker glyph score accepted only with a wide margin and a present blue badge"),
    Threshold("student.potential.basic_badge.margin", 0.30, "margin", "F3", F3, "stat_*", "potential_basic_template"),
    Threshold("student.potential.zero_correction.below", 0.72, "score", "F3", F3, "stat_*", "potential_basic_template",
              note="X23 '4->0' correction applies only under this score"),
    Threshold("student.potential.zero_correction.tolerance", 0.03, "margin", "F3", F3, "stat_*", "potential_basic_template",
              note="X23: zero may trail the best label by this much"),
    Threshold("student.potential.menu.score", 0.60, "score", "F3", F3, "stat_*", "potential_menu"),
    # Studio numeric bank (S3b position bank).
    Threshold("studio.glyph.min_height_ratio", 0.30, "ratio", "S3b", S3B_POSITION, "digit", "studio_numeric_bank",
              note="connected components shorter than this share of the cell are not digits"),
)

THRESHOLDS: dict[str, Threshold] = {entry.name: entry for entry in _ENTRIES}
if len(THRESHOLDS) != len(_ENTRIES):
    raise RuntimeError("duplicate recognition threshold name")


def value(name: str) -> float:
    """The registered value of one named threshold."""
    return THRESHOLDS[name].value


def lookup(field: str, source: str, kind: str, resolution: str = "*") -> list[Threshold]:
    """Entries for field x source x resolution (``*`` entries apply to every resolution)."""
    return [entry for entry in _ENTRIES
            if entry.field == field and entry.source == source and entry.kind == kind
            and entry.resolution in {"*", resolution}]
