"""Data model for the offline inventory-grid match inspector."""

from __future__ import annotations

import copy
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

import numpy as np
from PIL import Image

from core.inventory_grid_matcher import (
    InventoryGridPreparedComparison,
    InventoryGridTierColorInspection,
    inspect_inventory_grid_tier_color,
    prepare_inventory_grid_comparison,
    rank_inventory_grid_templates,
)
from core.scanner_shared import (
    _inventory_grid_template_matching_config,
    _shift_slots_y,
    inventory_profile_template_catalog,
)


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CAPTURE_ROOT = ROOT / "debug" / "item_equip_scroll_debugger"
REFERENCE_SLOT_SIZE = (234, 190)


@dataclass(frozen=True)
class CaptureCase:
    source: str
    profile_id: str
    case_dir: Path
    summary_path: Path
    summary: dict

    @property
    def label(self) -> str:
        return self.case_dir.name


@dataclass(frozen=True)
class CaptureFrame:
    case: CaptureCase
    phase: str
    image_path: Path
    y_offset_px: int
    active_slot_indices: frozenset[int]


@dataclass
class SlotRecord:
    frame: CaptureFrame
    slot_index: int
    region: dict
    slot_crop: Image.Image
    is_active: bool

    @property
    def key(self) -> str:
        rel = self.frame.image_path.name
        return f"{self.frame.case.profile_id}:{self.frame.case.label}:{self.frame.phase}:{rel}:{self.slot_index}"


@dataclass
class InspectorExperiment:
    crop_ratio: dict[str, float] | None = None
    direct_screen_crop_ratio: dict[str, float] | None = None
    direct_template_crop_ratio: dict[str, float] | None = None
    tier_enabled: bool | None = None
    sample_box: dict[str, float] | None = None
    sample_search_box: dict[str, float] | None = None
    sample_stride: float | None = None
    fixed_sample: bool = False
    selected_candidates: dict[str, str] = field(default_factory=dict)

    def to_json(self) -> dict:
        return {
            "crop_ratio": self.crop_ratio,
            "direct_screen_crop_ratio": self.direct_screen_crop_ratio,
            "direct_template_crop_ratio": self.direct_template_crop_ratio,
            "tier_enabled": self.tier_enabled,
            "sample_box": self.sample_box,
            "sample_search_box": self.sample_search_box,
            "sample_stride": self.sample_stride,
            "fixed_sample": self.fixed_sample,
            "selected_candidates": dict(self.selected_candidates),
        }

    @classmethod
    def from_json(cls, payload: dict) -> "InspectorExperiment":
        return cls(
            crop_ratio=_dict_or_none(payload.get("crop_ratio")),
            direct_screen_crop_ratio=_dict_or_none(payload.get("direct_screen_crop_ratio")),
            direct_template_crop_ratio=_dict_or_none(payload.get("direct_template_crop_ratio")),
            tier_enabled=payload.get("tier_enabled") if isinstance(payload.get("tier_enabled"), bool) else None,
            sample_box=_dict_or_none(payload.get("sample_box")),
            sample_search_box=_dict_or_none(payload.get("sample_search_box")),
            sample_stride=_float_or_none(payload.get("sample_stride")),
            fixed_sample=bool(payload.get("fixed_sample", False)),
            selected_candidates={str(k): str(v) for k, v in dict(payload.get("selected_candidates") or {}).items()},
        )


def _dict_or_none(value: object) -> dict | None:
    return dict(value) if isinstance(value, dict) else None


def _float_or_none(value: object) -> float | None:
    try:
        return float(value) if value is not None else None
    except (TypeError, ValueError):
        return None


def _read_json(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return payload


def discover_capture_cases(capture_root: Path = DEFAULT_CAPTURE_ROOT) -> list[CaptureCase]:
    capture_root = Path(capture_root)
    cases: list[CaptureCase] = []
    for summary_path in sorted(capture_root.rglob("summary.json")):
        case_dir = summary_path.parent
        try:
            if case_dir.parent.name == "captures":
                relative = case_dir.relative_to(capture_root)
                source = relative.parts[0]
                profile_id = relative.parts[1] if source == "item" and len(relative.parts) > 1 else "equipment"
            else:
                run_match = re.search(r"_(item|equipment)_([^\\/]+)$", case_dir.parent.name)
                if run_match is None or not case_dir.name.startswith("scroll_"):
                    continue
                source = run_match.group(1)
                profile_id = run_match.group(2) if source == "item" else "equipment"
            if source not in {"item", "equipment"}:
                continue
            summary = _read_json(summary_path)
        except (OSError, ValueError, json.JSONDecodeError):
            continue
        cases.append(CaptureCase(source, profile_id, case_dir, summary_path, summary))
    return cases


def capture_frames(case: CaptureCase, phase: str = "both") -> list[CaptureFrame]:
    wanted = ("before", "after") if phase == "both" else (phase,)
    frames: list[CaptureFrame] = []
    total = max(0, int(case.summary.get("slot_count") or 0))
    after_active = frozenset(int(value) for value in case.summary.get("new_scan_slot_indices_0_based") or range(total))
    for name in wanted:
        path_value = case.summary.get(f"{name}_capture")
        image_path = Path(path_value) if path_value else case.case_dir / f"{name}_capture.png"
        if not image_path.exists():
            fallback = case.case_dir / f"{name}_capture.png"
            image_path = fallback if fallback.exists() else image_path
        if not image_path.exists():
            continue
        y_offset = int(case.summary.get(f"{name}_y_offset_px") or 0)
        active = frozenset(range(total)) if name == "before" else after_active
        frames.append(CaptureFrame(case, name, image_path, y_offset, active))
    return frames


def load_region_section(source: str) -> dict:
    section_name = "equipment" if source == "equipment" else "item"
    path = ROOT / "regions" / f"{section_name}_regions.json"
    payload = _read_json(path)
    section = payload.get(section_name)
    if not isinstance(section, dict) or not isinstance(section.get("grid_slots"), list):
        raise ValueError(f"missing {section_name}.grid_slots in {path}")
    return section


def _crop_ratio_region(image: Image.Image, region: dict) -> Image.Image:
    width, height = image.size
    box = (
        int(round(float(region["x1"]) * width)),
        int(round(float(region["y1"]) * height)),
        int(round(float(region["x2"]) * width)),
        int(round(float(region["y2"]) * height)),
    )
    return image.crop(box).convert("RGB")


def slot_records(case: CaptureCase, phase: str = "both") -> list[SlotRecord]:
    section = load_region_section(case.source)
    base_slots = list(section["grid_slots"])
    records: list[SlotRecord] = []
    for frame in capture_frames(case, phase):
        image = Image.open(frame.image_path).convert("RGB")
        slots = _shift_slots_y(base_slots, frame.y_offset_px, image.size)
        for slot_index, region in enumerate(slots):
            records.append(
                SlotRecord(
                    frame=frame,
                    slot_index=slot_index,
                    region=region,
                    slot_crop=_crop_ratio_region(image, region),
                    is_active=slot_index in frame.active_slot_indices,
                )
            )
    return records


def base_matching_config(source: str, profile_id: str) -> dict:
    section = load_region_section(source)
    config = _inventory_grid_template_matching_config(section, profile_id)
    return copy.deepcopy(config or {})


def effective_matching_config(base: dict, experiment: InspectorExperiment) -> dict:
    config = copy.deepcopy(base)
    if experiment.crop_ratio is not None:
        config["crop_ratio"] = dict(experiment.crop_ratio)
    direct = config.get("direct_icon_match")
    if not isinstance(direct, dict):
        direct = {}
        config["direct_icon_match"] = direct
    if experiment.direct_screen_crop_ratio is not None:
        direct["screen_crop_ratio"] = dict(experiment.direct_screen_crop_ratio)
    if experiment.direct_template_crop_ratio is not None:
        direct["template_crop_ratio"] = dict(experiment.direct_template_crop_ratio)
    tier = config.get("tier_hint")
    if not isinstance(tier, dict):
        tier = {}
        config["tier_hint"] = tier
    if experiment.tier_enabled is not None:
        tier["enabled"] = experiment.tier_enabled
    if experiment.sample_box is not None:
        tier["sample_box"] = dict(experiment.sample_box)
    if experiment.sample_search_box is not None:
        tier["sample_search_box"] = dict(experiment.sample_search_box)
    if experiment.sample_stride is not None:
        tier["sample_stride"] = float(experiment.sample_stride)
    if experiment.fixed_sample and isinstance(tier.get("sample_box"), dict):
        tier["sample_search_box"] = dict(tier["sample_box"])
        tier["sample_stride"] = max(
            float(tier["sample_box"].get("width", 1)),
            float(tier["sample_box"].get("height", 1)),
        )
    return config


def profile_catalog(source: str, profile_id: str) -> list[tuple[str, str]]:
    return inventory_profile_template_catalog(source, profile_id)


def prepare_comparison(
    record: SlotRecord,
    item_id: str,
    icon_path: str,
    config: dict,
    *,
    mode: str = "production",
    catalog: list[tuple[str, str]] | None = None,
) -> InventoryGridPreparedComparison | None:
    return prepare_inventory_grid_comparison(
        record.slot_crop,
        item_id,
        icon_path,
        config,
        mode=mode,
        catalog=catalog,
    )


def rank_record(record: SlotRecord, catalog: list[tuple[str, str]], config: dict) -> list[tuple[str, float]]:
    return rank_inventory_grid_templates(record.slot_crop, catalog, config, use_tier_hint=True)


def inspect_record_color(record: SlotRecord, config: dict) -> InventoryGridTierColorInspection:
    return inspect_inventory_grid_tier_color(record.slot_crop, config)


def aggregate_color_inspections(
    records: Iterable[SlotRecord],
    config: dict,
) -> dict:
    inspections = [(record, inspect_record_color(record, config)) for record in records]
    enabled = [(record, result) for record, result in inspections if result.sample_box is not None]
    recognized = [(record, result) for record, result in enabled if result.tier_hint is not None]
    distances = [result.distances[0][1] for _record, result in enabled if result.distances]
    margins = [result.distance_margin for _record, result in enabled if result.distances]
    worst = sorted(
        enabled,
        key=lambda row: row[1].distances[0][1] if row[1].distances else float("inf"),
        reverse=True,
    )[:8]
    return {
        "total": len(inspections),
        "sampled": len(enabled),
        "recognized": len(recognized),
        "unknown": len(enabled) - len(recognized),
        "worst_distance": max(distances) if distances else None,
        "minimum_margin": min(margins) if margins else None,
        "worst_slots": [
            f"{record.frame.phase} S{record.slot_index + 1:02d}"
            for record, _result in worst
        ],
    }


def save_session(
    path: Path,
    capture_root: Path,
    profile_id: str,
    experiment: InspectorExperiment,
) -> None:
    payload = {
        "version": 1,
        "capture_root": str(Path(capture_root).resolve()),
        "profile_id": profile_id,
        "experiment": experiment.to_json(),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def load_session(path: Path) -> tuple[Path, str, InspectorExperiment]:
    payload = _read_json(path)
    if int(payload.get("version") or 0) != 1:
        raise ValueError(f"unsupported inspector session version: {path}")
    return (
        Path(str(payload.get("capture_root") or DEFAULT_CAPTURE_ROOT)),
        str(payload.get("profile_id") or ""),
        InspectorExperiment.from_json(dict(payload.get("experiment") or {})),
    )
