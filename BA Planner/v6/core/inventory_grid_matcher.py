from __future__ import annotations

from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

from core.config import TEMPLATE_DIR


@dataclass(frozen=True)
class InventoryGridMatchResult:
    item_id: str | None
    score: float
    margin: float
    second_item_id: str | None = None
    best_item_id: str | None = None
    tier_hint: int | None = None
    tier_hint_confidence: float = 0.0
    candidate_count: int = 0
    row_anchor_candidate_count: int = 0


@dataclass
class InventoryGridRowAnchorState:
    grid_cols: int
    enabled: bool = True
    confirmed_profile_indices: dict[int, int] = field(default_factory=dict)
    used_profile_indices: set[int] = field(default_factory=set)
    anchor_slots: set[int] = field(default_factory=set)

    def anchor_profile_indices(self) -> dict[int, int]:
        return {
            slot_index: profile_index
            for slot_index, profile_index in self.confirmed_profile_indices.items()
            if slot_index in self.anchor_slots
        }

    def row_has_anchor(self, slot_index: int) -> bool:
        if not self.enabled or self.grid_cols <= 0:
            return False
        row_index = slot_index // self.grid_cols
        return any(anchor_slot // self.grid_cols == row_index for anchor_slot in self.anchor_slots)

    def should_promote_anchor(self, slot_index: int, *, strong_match: bool) -> bool:
        return bool(self.enabled and strong_match and not self.row_has_anchor(slot_index))

    def surrounding_anchors(self, slot_index: int) -> tuple[tuple[int, int] | None, tuple[int, int] | None]:
        if not self.enabled or self.grid_cols <= 0:
            return None, None
        previous_anchors = [
            (confirmed_slot, self.confirmed_profile_indices[confirmed_slot])
            for confirmed_slot in self.anchor_slots
            if confirmed_slot < slot_index and confirmed_slot in self.confirmed_profile_indices
        ]
        next_anchors = [
            (confirmed_slot, self.confirmed_profile_indices[confirmed_slot])
            for confirmed_slot in self.anchor_slots
            if confirmed_slot > slot_index and confirmed_slot in self.confirmed_profile_indices
        ]
        lower = max(previous_anchors, key=lambda row: row[0]) if previous_anchors else None
        upper = min(next_anchors, key=lambda row: row[0]) if next_anchors else None
        return lower, upper

    def exact_profile_index_for_slot(self, slot_index: int) -> int | None:
        lower, upper = self.surrounding_anchors(slot_index)
        if lower is None or upper is None:
            return None
        lower_slot, lower_index = lower
        upper_slot, upper_index = upper
        slot_gap = upper_slot - lower_slot - 1
        profile_gap = upper_index - lower_index - 1
        if slot_gap <= 0 or profile_gap != slot_gap:
            return None
        profile_index = lower_index + (slot_index - lower_slot)
        if lower_index < profile_index < upper_index:
            return profile_index
        return None

    def has_sparse_anchor_gap(self, slot_index: int) -> bool:
        lower, upper = self.surrounding_anchors(slot_index)
        if lower is None or upper is None:
            return False
        lower_slot, lower_index = lower
        upper_slot, upper_index = upper
        slot_gap = upper_slot - lower_slot - 1
        profile_gap = upper_index - lower_index - 1
        return slot_gap > 0 and 0 <= profile_gap < slot_gap

    def candidate_item_ids_for_slot(
        self,
        slot_index: int,
        ordered_item_ids: list[str | None] | tuple[str | None, ...],
    ) -> list[str] | None:
        if not self.enabled or self.grid_cols <= 0 or not ordered_item_ids:
            return None
        lower_anchor, upper_anchor = self.surrounding_anchors(slot_index)
        if lower_anchor is None and upper_anchor is None:
            return None
        if lower_anchor is not None and upper_anchor is not None:
            lower_slot, lower_index = lower_anchor
            upper_slot, upper_index = upper_anchor
            slot_gap = upper_slot - lower_slot - 1
            profile_gap = upper_index - lower_index - 1
            if slot_gap <= 0:
                return []
            if profile_gap < slot_gap:
                return None
            offset = slot_index - lower_slot
            extra_candidates = profile_gap - slot_gap
            start_index = lower_index + offset
            end_index = min(upper_index, start_index + extra_candidates + 1)
        elif upper_anchor is not None:
            upper_slot, upper_index = upper_anchor
            slot_gap = upper_slot
            profile_gap = upper_index
            if slot_gap > 0 and profile_gap >= slot_gap:
                offset = slot_index
                extra_candidates = profile_gap - slot_gap
                start_index = offset
                end_index = min(upper_index, start_index + extra_candidates + 1)
            else:
                start_index = 0
                end_index = upper_index
        else:
            lower_index = lower_anchor[1] if lower_anchor is not None else None
            start_index = (lower_index + 1) if lower_index is not None else 0
            end_index = len(ordered_item_ids)

        if end_index <= start_index:
            return []
        return [
            item_id
            for profile_index, item_id in enumerate(
                ordered_item_ids[start_index:end_index],
                start=start_index,
            )
            if item_id and profile_index not in self.used_profile_indices
        ]

    def record_confirmed(self, slot_index: int, profile_index: int | None, *, as_anchor: bool = True) -> bool:
        if not self.enabled or self.grid_cols <= 0 or profile_index is None:
            return False
        previous = self.confirmed_profile_indices.get(slot_index)
        self.confirmed_profile_indices[slot_index] = profile_index
        self.used_profile_indices.add(profile_index)
        if as_anchor:
            self.anchor_slots.add(slot_index)
        return bool(as_anchor and previous != profile_index)

DEFAULT_GRID_TEMPLATE = {
    "background": "icons/temp/square.png",
    "tier_backgrounds": {
        "0": "icons/temp/square.png",
        "1": "icons/temp/square_blue.png",
        "2": "icons/temp/square_yellow.png",
        "3": "icons/temp/square_purple.png",
    },
    "background_geometry": {
        "width_ratio": 1.0,
        "height_ratio": 187 / 190,
        "offset_x_ratio": 1 / 234,
        "offset_y_ratio": 1 / 190,
    },
    "icon_geometry": {
        "width_ratio": 227 / 234,
        "height_ratio": 181 / 190,
        "offset_x_ratio": 4 / 234,
        "offset_y_ratio": 4 / 190,
    },
    "crop_ratio": {
        "left": 0.18,
        "right": 0.18,
        "top": 0.16,
        "bottom": 0.30,
    },
    "tier_hint": {
        "enabled": True,
        "reference_width": 234,
        "reference_height": 190,
        "sample_box": {"x": 32, "y": 54, "width": 5, "height": 5},
        "sample_search_box": {"x": 30, "y": 44, "width": 10, "height": 28},
        "sample_stride": 1,
        "palette": {
            "0": (180, 203, 218),
            "1": (119, 175, 253),
            "2": (237, 158, 143),
            "3": (223, 86, 248),
        },
        "max_distance": 70.0,
        "min_distance_margin": 8.0,
        "fallback_min_score": 0.82,
    },
    "threshold": 0.82,
    "margin": 0.025,
}


def _template_asset_path(value: str | None, fallback: str) -> Path:
    raw = str(value or fallback).strip() or fallback
    path = Path(raw)
    if path.is_absolute():
        return path
    return TEMPLATE_DIR / raw


def _merged_config(config: dict | None) -> dict:
    merged = {
        "background": DEFAULT_GRID_TEMPLATE["background"],
        "tier_backgrounds": dict(DEFAULT_GRID_TEMPLATE["tier_backgrounds"]),
        "background_rules": [],
        "background_geometry": dict(DEFAULT_GRID_TEMPLATE["background_geometry"]),
        "icon_geometry": dict(DEFAULT_GRID_TEMPLATE["icon_geometry"]),
        "crop_ratio": dict(DEFAULT_GRID_TEMPLATE["crop_ratio"]),
        "tier_hint": dict(DEFAULT_GRID_TEMPLATE["tier_hint"]),
        "threshold": DEFAULT_GRID_TEMPLATE["threshold"],
        "margin": DEFAULT_GRID_TEMPLATE["margin"],
    }
    merged["tier_hint"]["sample_box"] = dict(DEFAULT_GRID_TEMPLATE["tier_hint"]["sample_box"])
    merged["tier_hint"]["sample_search_box"] = dict(DEFAULT_GRID_TEMPLATE["tier_hint"]["sample_search_box"])
    merged["tier_hint"]["palette"] = dict(DEFAULT_GRID_TEMPLATE["tier_hint"]["palette"])
    if not isinstance(config, dict):
        return merged
    for key in ("background", "threshold", "margin"):
        if key in config:
            merged[key] = config[key]
    value = config.get("tier_backgrounds")
    if isinstance(value, dict):
        merged["tier_backgrounds"].update(value)
    value = config.get("background_rules")
    if isinstance(value, list):
        merged["background_rules"] = [rule for rule in value if isinstance(rule, dict)]
    for key in ("background_geometry", "icon_geometry", "crop_ratio"):
        value = config.get(key)
        if isinstance(value, dict):
            merged[key].update(value)
    value = config.get("tier_hint")
    if isinstance(value, dict):
        merged["tier_hint"].update({k: v for k, v in value.items() if k not in {"sample_box", "sample_search_box", "palette"}})
        if isinstance(value.get("sample_box"), dict):
            merged["tier_hint"]["sample_box"].update(value["sample_box"])
        if isinstance(value.get("sample_search_box"), dict):
            merged["tier_hint"]["sample_search_box"].update(value["sample_search_box"])
        if isinstance(value.get("palette"), dict):
            merged["tier_hint"]["palette"].update(value["palette"])
    return merged


def _background_for_item(item_id: str, config: dict) -> Path:
    fallback = str(config.get("background") or "icons/temp/square.png")
    text = item_id.casefold()
    rules = config.get("background_rules")
    if isinstance(rules, list):
        for rule in rules:
            if not isinstance(rule, dict):
                continue
            contains = str(rule.get("contains") or "").casefold()
            background = rule.get("background")
            if contains and contains in text and background:
                return _template_asset_path(str(background), fallback)

    tier_token = item_id.rsplit("_", 1)[-1]
    tier_backgrounds = config.get("tier_backgrounds")
    if isinstance(tier_backgrounds, dict):
        background = tier_backgrounds.get(tier_token)
        if background:
            return _template_asset_path(str(background), fallback)
    return _template_asset_path(fallback, "icons/temp/square.png")


def _crop_inner(image: Image.Image, crop_ratio: dict) -> Image.Image:
    width, height = image.size
    left = float(crop_ratio.get("left", 0.0))
    right = float(crop_ratio.get("right", 0.0))
    top = float(crop_ratio.get("top", 0.0))
    bottom = float(crop_ratio.get("bottom", 0.0))
    x1 = max(0, min(width - 1, int(round(width * left))))
    x2 = max(x1 + 1, min(width, int(round(width * (1.0 - right)))))
    y1 = max(0, min(height - 1, int(round(height * top))))
    y2 = max(y1 + 1, min(height, int(round(height * (1.0 - bottom)))))
    return image.crop((x1, y1, x2, y2))


def _equipment_item_style_crop_ratio(item_id: str | None, config: dict) -> dict:
    text = str(item_id or "")
    if text.startswith("Equipment_Icon_WeaponExpGrowth"):
        return DEFAULT_GRID_TEMPLATE["crop_ratio"]
    if text.startswith("Equipment_Icon_") and text.endswith("_Tier1"):
        return DEFAULT_GRID_TEMPLATE["crop_ratio"]
    return config["crop_ratio"]


def _item_tier_hint(item_id: str | None) -> int | None:
    if not item_id:
        return None
    token = item_id.rsplit("_", 1)[-1]
    if not token.isdigit():
        return None
    tier = int(token)
    if 0 <= tier <= 3:
        return tier
    return None


def _scaled_sample_box(
    box_config: dict,
    *,
    sx: float,
    sy: float,
    width: int,
    height: int,
) -> tuple[int, int, int, int]:
    x1 = int(round(float(box_config.get("x", 0)) * sx))
    y1 = int(round(float(box_config.get("y", 0)) * sy))
    x2 = int(round((float(box_config.get("x", 0)) + float(box_config.get("width", 1))) * sx))
    y2 = int(round((float(box_config.get("y", 0)) + float(box_config.get("height", 1))) * sy))
    x1 = max(0, min(width - 1, x1))
    y1 = max(0, min(height - 1, y1))
    x2 = max(x1 + 1, min(width, x2))
    y2 = max(y1 + 1, min(height, y2))
    return x1, y1, x2, y2


def _palette_distances(rgb: np.ndarray, palette_config: dict) -> list[tuple[int, float]]:
    distances: list[tuple[int, float]] = []
    for key, value in palette_config.items():
        try:
            tier = int(key)
            palette_rgb = np.asarray(value, dtype=np.float32)
        except (TypeError, ValueError):
            continue
        if palette_rgb.shape != (3,):
            continue
        distances.append((tier, float(np.linalg.norm(rgb - palette_rgb))))
    distances.sort(key=lambda row: row[1])
    return distances


def _iter_positions(start: int, stop: int, window: int, step: int) -> list[int]:
    last = max(start, stop - window)
    positions = list(range(start, last + 1, max(1, step)))
    if not positions or positions[-1] != last:
        positions.append(last)
    return positions


def _detect_tier_color(slot_crop: Image.Image, config: dict) -> tuple[int | None, float]:
    tier_config = config.get("tier_hint")
    if not isinstance(tier_config, dict) or not tier_config.get("enabled", True):
        return None, 0.0
    box_config = tier_config.get("sample_box")
    palette_config = tier_config.get("palette")
    if not isinstance(box_config, dict) or not isinstance(palette_config, dict):
        return None, 0.0

    ref_w = max(1.0, float(tier_config.get("reference_width", 234)))
    ref_h = max(1.0, float(tier_config.get("reference_height", 190)))
    sx = slot_crop.width / ref_w
    sy = slot_crop.height / ref_h

    search_config = tier_config.get("sample_search_box")
    if not isinstance(search_config, dict):
        search_config = box_config
    search_x1, search_y1, search_x2, search_y2 = _scaled_sample_box(
        search_config,
        sx=sx,
        sy=sy,
        width=slot_crop.width,
        height=slot_crop.height,
    )
    sample_w = max(1, int(round(float(box_config.get("width", 1)) * sx)))
    sample_h = max(1, int(round(float(box_config.get("height", 1)) * sy)))
    stride = max(1.0, float(tier_config.get("sample_stride", 1)))
    step_x = max(1, int(round(stride * sx)))
    step_y = max(1, int(round(stride * sy)))

    slot_rgb = slot_crop.convert("RGB")
    best_distances: list[tuple[int, float]] = []
    best_margin = float("-inf")
    for y1 in _iter_positions(search_y1, search_y2, sample_h, step_y):
        for x1 in _iter_positions(search_x1, search_x2, sample_w, step_x):
            x2 = min(slot_crop.width, x1 + sample_w)
            y2 = min(slot_crop.height, y1 + sample_h)
            sample = np.asarray(slot_rgb.crop((x1, y1, x2, y2)), dtype=np.uint8)
            if sample.size == 0:
                continue
            rgb = np.median(sample.reshape(-1, 3).astype(np.float32), axis=0)
            distances = _palette_distances(rgb, palette_config)
            if not distances:
                continue
            second_distance = distances[1][1] if len(distances) > 1 else float("inf")
            distance_margin = second_distance - distances[0][1]
            if not best_distances or distances[0][1] < best_distances[0][1] or (
                distances[0][1] == best_distances[0][1] and distance_margin > best_margin
            ):
                best_distances = distances
                best_margin = distance_margin

    if not best_distances:
        return None, 0.0
    distances = best_distances
    best_tier, best_distance = distances[0]
    second_distance = distances[1][1] if len(distances) > 1 else float("inf")
    max_distance = float(tier_config.get("max_distance", 70.0))
    min_margin = float(tier_config.get("min_distance_margin", 8.0))
    distance_margin = second_distance - best_distance
    if best_distance > max_distance or distance_margin < min_margin:
        return None, 0.0
    confidence = max(0.0, min(1.0, min(max_distance - best_distance, distance_margin) / max(max_distance, 1.0)))
    return best_tier, confidence


def inventory_item_tier_hint(item_id: str | None) -> int | None:
    return _item_tier_hint(item_id)


def detect_inventory_grid_tier_hint(
    slot_crop: Image.Image,
    config: dict | None = None,
) -> tuple[int | None, float]:
    return _detect_tier_color(slot_crop.convert("RGB"), _merged_config(config))

def _paste_scaled(base: Image.Image, overlay: Image.Image, geometry: dict) -> None:
    width, height = base.size
    item_width = max(1, round(width * float(geometry.get("width_ratio", 1.0))))
    item_height = max(1, round(height * float(geometry.get("height_ratio", 1.0))))
    x = round(width * float(geometry.get("offset_x_ratio", 0.0)))
    y = round(height * float(geometry.get("offset_y_ratio", 0.0)))
    scaled = overlay.convert("RGBA").resize((item_width, item_height), Image.Resampling.LANCZOS)
    base.alpha_composite(scaled, dest=(x, y))


@lru_cache(maxsize=4096)
def _grid_template_crop(
    icon_path: str,
    output_width: int,
    output_height: int,
    background_path: str,
    background_width_ratio: float,
    background_height_ratio: float,
    background_offset_x_ratio: float,
    background_offset_y_ratio: float,
    icon_width_ratio: float,
    icon_height_ratio: float,
    icon_offset_x_ratio: float,
    icon_offset_y_ratio: float,
    crop_left: float,
    crop_right: float,
    crop_top: float,
    crop_bottom: float,
) -> np.ndarray | None:
    icon_file = Path(icon_path)
    background_file = Path(background_path)
    if not icon_file.exists() or not background_file.exists():
        return None

    slot = Image.new("RGBA", (output_width, output_height), (0, 0, 0, 0))
    _paste_scaled(
        slot,
        Image.open(background_file),
        {
            "width_ratio": background_width_ratio,
            "height_ratio": background_height_ratio,
            "offset_x_ratio": background_offset_x_ratio,
            "offset_y_ratio": background_offset_y_ratio,
        },
    )
    _paste_scaled(
        slot,
        Image.open(icon_file),
        {
            "width_ratio": icon_width_ratio,
            "height_ratio": icon_height_ratio,
            "offset_x_ratio": icon_offset_x_ratio,
            "offset_y_ratio": icon_offset_y_ratio,
        },
    )
    crop = _crop_inner(
        slot.convert("RGB"),
        {
            "left": crop_left,
            "right": crop_right,
            "top": crop_top,
            "bottom": crop_bottom,
        },
    )
    return np.asarray(crop.convert("RGB"), dtype=np.uint8).copy()


def _template_for(
    item_id: str,
    icon_path: str,
    output_size: tuple[int, int],
    config: dict,
) -> np.ndarray | None:
    background_geometry = config["background_geometry"]
    icon_geometry = config["icon_geometry"]
    crop_ratio = _equipment_item_style_crop_ratio(item_id, config)
    background_path = _background_for_item(item_id, config)
    return _grid_template_crop(
        icon_path,
        output_size[0],
        output_size[1],
        str(background_path),
        float(background_geometry.get("width_ratio", 1.0)),
        float(background_geometry.get("height_ratio", 1.0)),
        float(background_geometry.get("offset_x_ratio", 0.0)),
        float(background_geometry.get("offset_y_ratio", 0.0)),
        float(icon_geometry.get("width_ratio", 1.0)),
        float(icon_geometry.get("height_ratio", 1.0)),
        float(icon_geometry.get("offset_x_ratio", 0.0)),
        float(icon_geometry.get("offset_y_ratio", 0.0)),
        float(crop_ratio.get("left", 0.0)),
        float(crop_ratio.get("right", 0.0)),
        float(crop_ratio.get("top", 0.0)),
        float(crop_ratio.get("bottom", 0.0)),
    )


def _rgb_similarity(left: np.ndarray, right: np.ndarray) -> float:
    if left.shape != right.shape:
        right = cv2.resize(right, (left.shape[1], left.shape[0]), interpolation=cv2.INTER_AREA)
    left_f = left.astype(np.float32)
    right_f = right.astype(np.float32)
    diff_score = 1.0 - float(np.mean(np.abs(left_f - right_f)) / 255.0)

    left_gray = cv2.cvtColor(left, cv2.COLOR_RGB2GRAY)
    right_gray = cv2.cvtColor(right, cv2.COLOR_RGB2GRAY)
    try:
        res = cv2.matchTemplate(left_gray, right_gray, cv2.TM_CCOEFF_NORMED)
        _min, ncc, _min_loc, _max_loc = cv2.minMaxLoc(res)
    except cv2.error:
        ncc = 0.0
    ncc_score = max(0.0, min(1.0, (float(ncc) + 1.0) / 2.0))
    return max(0.0, min(1.0, 0.62 * ncc_score + 0.38 * diff_score))


def _rank_inventory_grid_templates_raw(
    slot_rgb: Image.Image,
    slot_size: tuple[int, int],
    catalog: list[tuple[str, str]],
    config: dict,
) -> list[tuple[str, float]]:
    scores: list[tuple[str, float]] = []
    for item_id, path in catalog:
        crop_ratio = _equipment_item_style_crop_ratio(item_id, config)
        screen_arr = np.asarray(_crop_inner(slot_rgb, crop_ratio), dtype=np.uint8)
        template_arr = _template_for(item_id, path, slot_size, config)
        if template_arr is None:
            continue
        scores.append((item_id, _rgb_similarity(screen_arr, template_arr)))
    scores.sort(key=lambda row: row[1], reverse=True)
    return scores


def _tier_filtered_catalog(catalog: list[tuple[str, str]], tier: int | None) -> list[tuple[str, str]]:
    if tier is None:
        return []
    filtered = [row for row in catalog if _item_tier_hint(row[0]) in (None, tier)]
    if len(filtered) >= len(catalog):
        return []
    return filtered


def _row_anchor_filtered_catalog(
    catalog: list[tuple[str, str]],
    row_anchor_state: InventoryGridRowAnchorState | None,
    slot_index: int | None,
    ordered_item_ids: list[str | None] | tuple[str | None, ...] | None,
) -> tuple[list[tuple[str, str]], int, bool]:
    if row_anchor_state is None or slot_index is None or ordered_item_ids is None:
        return catalog, 0, False
    candidate_item_ids = row_anchor_state.candidate_item_ids_for_slot(slot_index, ordered_item_ids)
    if candidate_item_ids is None:
        return catalog, 0, False
    allowed = set(candidate_item_ids)
    return [row for row in catalog if row[0] in allowed], len(allowed), True


def rank_inventory_grid_templates(
    slot_crop: Image.Image,
    catalog: list[tuple[str, str]],
    config: dict | None = None,
    *,
    use_tier_hint: bool = True,
) -> list[tuple[str, float]]:
    if not catalog:
        return []
    merged = _merged_config(config)
    slot_rgb = slot_crop.convert("RGB")
    if use_tier_hint:
        tier_hint, _tier_confidence = _detect_tier_color(slot_rgb, merged)
        filtered_catalog = _tier_filtered_catalog(catalog, tier_hint)
        if filtered_catalog:
            ranked = _rank_inventory_grid_templates_raw(slot_rgb, slot_crop.size, filtered_catalog, merged)
            fallback_min_score = float(merged.get("tier_hint", {}).get("fallback_min_score", merged["threshold"]))
            if ranked and ranked[0][1] >= fallback_min_score:
                return ranked
    return _rank_inventory_grid_templates_raw(slot_rgb, slot_crop.size, catalog, merged)


def match_inventory_grid_template(
    slot_crop: Image.Image,
    catalog: list[tuple[str, str]],
    config: dict | None = None,
    *,
    row_anchor_state: InventoryGridRowAnchorState | None = None,
    slot_index: int | None = None,
    ordered_item_ids: list[str | None] | tuple[str | None, ...] | None = None,
) -> InventoryGridMatchResult:
    merged = _merged_config(config)
    tier_hint, tier_confidence = _detect_tier_color(slot_crop.convert("RGB"), merged)
    match_catalog, row_anchor_count, row_anchor_applied = _row_anchor_filtered_catalog(
        catalog,
        row_anchor_state,
        slot_index,
        ordered_item_ids,
    )
    ranked = rank_inventory_grid_templates(
        slot_crop,
        match_catalog,
        merged,
        use_tier_hint=True,
    )
    filtered_catalog = _tier_filtered_catalog(match_catalog, tier_hint)
    if not ranked:
        return InventoryGridMatchResult(
            None,
            0.0,
            0.0,
            tier_hint=tier_hint,
            tier_hint_confidence=tier_confidence,
            row_anchor_candidate_count=row_anchor_count,
        )
    best_item_id, best_score = ranked[0]
    candidate_count = len(match_catalog)
    if filtered_catalog and _item_tier_hint(best_item_id) in (None, tier_hint):
        candidate_count = len(filtered_catalog)
    second_item_id = ranked[1][0] if len(ranked) > 1 else None
    second_score = ranked[1][1] if len(ranked) > 1 else 0.0
    margin = best_score - second_score
    if best_score < float(merged["threshold"]) or margin < float(merged["margin"]):
        return InventoryGridMatchResult(
            None,
            best_score,
            margin,
            second_item_id,
            best_item_id,
            tier_hint,
            tier_confidence,
            candidate_count,
            row_anchor_count,
        )
    return InventoryGridMatchResult(
        best_item_id,
        best_score,
        margin,
        second_item_id,
        best_item_id,
        tier_hint,
        tier_confidence,
        candidate_count,
        row_anchor_count,
    )

