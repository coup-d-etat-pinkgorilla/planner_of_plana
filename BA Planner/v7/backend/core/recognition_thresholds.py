"""Named recognition thresholds (C4): one table instead of literals spread through recognizers.

Each entry keeps the value it had when it was introduced; C4 only moves values here. Changing a
value is a C7 decision recorded in the scanner consolidation status document.

``field`` / ``source`` / ``resolution`` describe where a threshold applies ("*" = any,
"native1280" / "native2560" = resolution-specific). ``kind`` is score, margin, similarity or ratio.
"""
from __future__ import annotations

from dataclasses import dataclass


P5 = "docs/migration/p5-scanner-matcher/scanner-runtime.md"
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
