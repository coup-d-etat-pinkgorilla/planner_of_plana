from __future__ import annotations

import argparse
import contextlib
import json
import shutil
import sys
from pathlib import Path
from typing import Iterable

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

with contextlib.redirect_stdout(sys.stderr):
    from core.inventory_slot_count_matcher import _digit_region  # noqa: E402
    from core.capture import crop_region  # noqa: E402
    from core.scanner import (  # noqa: E402
        _estimate_inventory_scroll_motion,
        _grid_region,
        InventoryMotionEstimate,
        _inventory_motion_feature_pair,
        _inventory_motion_region,
        _inventory_overlap_rows_from_motion,
        _suppress_slot_side_bands,
        _verify_inventory_near_zero_motion,
        _new_inventory_slot_indices,
        _shift_region_y,
        _shift_slots_y,
        _slot_icon_region,
        _slot_row_step_px,
    )


def _load_slots(section: str) -> list[dict]:
    path = ROOT / "regions" / f"{section}_regions.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    if section not in payload or "grid_slots" not in payload[section]:
        raise ValueError(f"missing {section}.grid_slots in {path}")
    return payload[section]["grid_slots"]


def _expand_ratio_region(
    region: dict,
    *,
    left: float = 0.0,
    top: float = 0.0,
    right: float = 0.0,
    bottom: float = 0.0,
) -> dict:
    return {
        "x1": max(0.0, float(region["x1"]) - left),
        "y1": max(0.0, float(region["y1"]) - top),
        "x2": min(1.0, float(region["x2"]) + right),
        "y2": min(1.0, float(region["y2"]) + bottom),
    }


def _estimate_motion_with_near_zero_verification(
    before: Image.Image,
    after: Image.Image,
    grid_region: dict,
    expected_move_px: int,
    row_step_px: int,
    search_margin_px: int,
    *,
    slots: list[dict] | None = None,
):
    motion = _estimate_inventory_scroll_motion(
        before,
        after,
        grid_region,
        expected_move_px,
        search_margin_px=search_margin_px,
        slots=slots,
    )
    if motion is None or row_step_px <= 0 or motion.actual_move_px >= row_step_px * 0.35:
        return motion
    verified = _verify_inventory_near_zero_motion(
        before,
        after,
        grid_region,
        expected_move_px,
        row_step_px,
        motion,
        slots=slots,
    )
    return verified if verified is not None else motion


def _scan_range(indices: set[int] | None, total: int) -> tuple[str, int]:
    if indices is None:
        return f"1-{total}", total
    if not indices:
        return "empty", 0
    numbers = [idx + 1 for idx in sorted(indices)]
    contiguous = numbers == list(range(numbers[0], numbers[-1] + 1))
    if contiguous:
        return f"{numbers[0]}-{numbers[-1]}", len(numbers)
    return ",".join(str(n) for n in numbers), len(numbers)


def _region_to_roi(name: str, region: dict, image_size: tuple[int, int], *, enabled: bool = True) -> dict:
    width, height = image_size
    x1 = int(round(float(region["x1"]) * width))
    y1 = int(round(float(region["y1"]) * height))
    x2 = int(round(float(region["x2"]) * width))
    y2 = int(round(float(region["y2"]) * height))
    x1, x2 = sorted((x1, x2))
    y1, y2 = sorted((y1, y2))
    return {
        "name": name,
        "x": x1,
        "y": y1,
        "width": max(1, x2 - x1),
        "height": max(1, y2 - y1),
        "enabled": enabled,
        "shape": "rectangle",
        "slant": 0,
    }


def _digit_to_roi(name: str, slot: dict, position: int, image_size: tuple[int, int]) -> dict:
    width, height = image_size
    digit = _digit_region(slot, position, image_size)
    points = [
        (float(point["x"]) * width, float(point["y"]) * height)
        for point in digit.get("points_ratio", [])
    ]
    if len(points) != 4:
        return _region_to_roi(name, slot, image_size)
    tl, tr, br, bl = points
    x = int(round(bl[0]))
    y = int(round(tl[1]))
    roi_width = int(round(tr[0] - tl[0]))
    roi_height = int(round(bl[1] - tl[1]))
    slant = int(round(tl[0] - bl[0]))
    if roi_width <= 0 or roi_height <= 0:
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        return {
            "name": name,
            "x": int(round(min(xs))),
            "y": int(round(min(ys))),
            "width": max(1, int(round(max(xs) - min(xs)))),
            "height": max(1, int(round(max(ys) - min(ys)))),
            "enabled": True,
            "shape": "rectangle",
            "slant": 0,
        }
    return {
        "name": name,
        "x": x,
        "y": y,
        "width": max(1, roi_width),
        "height": max(1, roi_height),
        "enabled": True,
        "shape": "parallelogram",
        "slant": slant,
    }


def _roi_points(roi: dict) -> list[dict[str, int]]:
    slant = int(roi.get("slant") or 0) if roi.get("shape") == "parallelogram" else 0
    x = int(roi["x"])
    y = int(roi["y"])
    width = int(roi["width"])
    height = int(roi["height"])
    return [
        {"x": x + slant, "y": y},
        {"x": x + width + slant, "y": y},
        {"x": x + width, "y": y + height},
        {"x": x, "y": y + height},
    ]


def _write_studio_project(
    path: Path,
    reference_path: Path,
    rois: Iterable[dict],
    *,
    metadata: dict,
    layers: Iterable[dict] | None = None,
) -> None:
    roi_rows = []
    for roi in rois:
        row = dict(roi)
        row["points"] = _roi_points(row)
        roi_rows.append(row)
    payload = {
        "reference_path": str(reference_path.resolve()),
        "layers": [dict(layer) for layer in (layers or [])],
        "rois": roi_rows,
        "roi": roi_rows[0] if roi_rows else _region_to_roi("main", {"x1": 0, "y1": 0, "x2": 1, "y2": 1}, (1, 1)),
        "metadata": metadata,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def _studio_rois_for_capture(
    *,
    image_size: tuple[int, int],
    slots: list[dict],
    grid_cols: int,
    scan_indices: set[int] | None,
    include_digits: bool,
    prefix: str,
) -> list[dict]:
    active = set(range(len(slots))) if scan_indices is None else set(scan_indices)
    rois: list[dict] = [_region_to_roi(f"{prefix}_grid", _grid_region(slots), image_size)]
    for index, slot in enumerate(slots):
        slot_no = index + 1
        is_active = index in active
        rois.append(_region_to_roi(f"{prefix}_slot_{slot_no:02d}", slot, image_size, enabled=is_active))
        rois.append(_region_to_roi(f"{prefix}_icon_{slot_no:02d}", _slot_icon_region(slot), image_size, enabled=is_active))
        if include_digits and is_active:
            for position in range(6):
                rois.append(_digit_to_roi(f"{prefix}_slot_{slot_no:02d}_digit_{position}", slot, position, image_size))
    return rois


def _pixel_box_for_region(region: dict, image_size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = image_size
    x1 = int(round(float(region["x1"]) * width))
    y1 = int(round(float(region["y1"]) * height))
    x2 = int(round(float(region["x2"]) * width))
    y2 = int(round(float(region["y2"]) * height))
    x1, x2 = sorted((x1, x2))
    y1, y2 = sorted((y1, y2))
    return x1, y1, x2, y2


def _union_regions(regions: list[dict]) -> dict | None:
    if not regions:
        return None
    return {
        "x1": min(float(region["x1"]) for region in regions),
        "y1": min(float(region["y1"]) for region in regions),
        "x2": max(float(region["x2"]) for region in regions),
        "y2": max(float(region["y2"]) for region in regions),
    }


def _overlap_bottom_band_rois(
    *,
    image_size: tuple[int, int],
    slots: list[dict],
    grid_cols: int,
    moved_rows: int | None,
    overlap_rows: int,
    prefix: str,
) -> list[dict]:
    if moved_rows is None or grid_cols <= 0 or overlap_rows <= 0:
        return []
    rois: list[dict] = []
    for overlap_row in range(overlap_rows):
        before_row = int(moved_rows) + overlap_row
        after_row = overlap_row
        for col in range(grid_cols):
            after_idx = after_row * grid_cols + col
            before_idx = before_row * grid_cols + col
            if after_idx >= len(slots):
                continue
            region = _slot_bottom_band_region(slots[after_idx], image_size)
            rois.append(
                _region_to_roi(
                    f"{prefix}_before_slot_{before_idx + 1:02d}_on_after_slot_{after_idx + 1:02d}_bottom_band",
                    region,
                    image_size,
                    enabled=True,
                )
            )
    return rois


def _previous_overlap_row_rois(
    *,
    image_size: tuple[int, int],
    slots: list[dict],
    grid_cols: int,
    moved_rows: int | None,
    overlap_rows: int,
    prefix: str,
    include_digits: bool = True,
) -> list[dict]:
    if moved_rows is None or grid_cols <= 0 or overlap_rows <= 0:
        return []
    rois: list[dict] = []
    for overlap_row in range(overlap_rows):
        before_row = int(moved_rows) + overlap_row
        after_row = overlap_row
        for col in range(grid_cols):
            after_idx = after_row * grid_cols + col
            before_idx = before_row * grid_cols + col
            if after_idx >= len(slots):
                continue
            slot = slots[after_idx]
            name = f"{prefix}_before_slot_{before_idx + 1:02d}_on_after_slot_{after_idx + 1:02d}"
            rois.append(_region_to_roi(f"{name}_slot", slot, image_size, enabled=True))
            rois.append(_region_to_roi(f"{name}_icon", _slot_icon_region(slot), image_size, enabled=True))
            if include_digits:
                for position in range(6):
                    rois.append(_digit_to_roi(f"{name}_digit_{position}", slot, position, image_size))
    return rois


def replay_scroll_folder(folder: Path, section: str) -> list[dict]:
    slots = _load_slots(section)
    y_offset = 0
    calibrated_row_step: float | None = None
    rows: list[dict] = []

    for summary_path in sorted(folder.glob("scroll_*_try_*/summary.json")):
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        before = Image.open(summary["before_capture"])
        after = Image.open(summary["after_capture"])
        grid_cols = int(summary.get("grid_cols") or 5)
        grid_rows = int(summary.get("grid_rows") or max(1, (len(slots) + grid_cols - 1) // grid_cols))
        amount_px = int(summary.get("amount_px") or 0)

        before_slots = _shift_slots_y(slots, y_offset, before.size) if y_offset else slots
        grid_region = _grid_region(before_slots)
        base_row_step = _slot_row_step_px(before_slots, before.size, grid_cols)
        row_step = base_row_step
        if calibrated_row_step is not None and base_row_step > 0:
            candidate = int(round(calibrated_row_step))
            if round(base_row_step * 0.85) <= candidate <= round(base_row_step * 1.15):
                row_step = candidate

        expected_move = min(abs(amount_px), row_step * max(1, grid_rows - 1)) if row_step > 0 else abs(amount_px)
        search_margin = max(50, row_step * max(1, grid_rows - 1)) if row_step > 0 else 50
        motion = _estimate_motion_with_near_zero_verification(
            before,
            after,
            grid_region,
            expected_move,
            row_step,
            search_margin,
            slots=before_slots,
        )
        overlap = _inventory_overlap_rows_from_motion(motion, row_step, grid_rows)
        if overlap is None:
            overlap_rows, moved_rows, delta_y, tail_scroll = 0, None, 0, False
        else:
            overlap_rows, moved_rows, delta_y, tail_scroll = overlap

        next_y_offset = y_offset + delta_y
        scan_indices = _new_inventory_slot_indices(len(slots), grid_cols, grid_rows, overlap_rows)
        scan_range, scan_count = _scan_range(scan_indices, len(slots))

        observed_row_step = None
        if (
            motion is not None
            and moved_rows is not None
            and moved_rows > 0
            and not tail_scroll
            and motion.score >= 0.70
            and base_row_step > 0
        ):
            observed_row_step = motion.actual_move_px / moved_rows
            if base_row_step * 0.85 <= observed_row_step <= base_row_step * 1.15:
                if calibrated_row_step is None:
                    calibrated_row_step = observed_row_step
                else:
                    calibrated_row_step = (calibrated_row_step * 0.65) + (observed_row_step * 0.35)

        old_motion = summary.get("movement_estimate") or {}
        rows.append(
            {
                "scroll": int(summary.get("scroll_index", len(rows))) + 1,
                "attempt": int(summary.get("attempt_index", 1)),
                "amount": amount_px,
                "old_actual": old_motion.get("actual_move_px"),
                "actual": motion.actual_move_px if motion is not None else None,
                "score": motion.score if motion is not None else None,
                "grid_cols": grid_cols,
                "grid_rows": grid_rows,
                "base_row_step": base_row_step,
                "row_step": row_step,
                "observed_row_step": observed_row_step,
                "calibrated_row_step": calibrated_row_step,
                "moved_rows": moved_rows,
                "overlap_rows": overlap_rows,
                "tail_scroll": tail_scroll,
                "before_y_offset": y_offset,
                "delta_y_offset": delta_y,
                "after_y_offset": next_y_offset,
                "scan_range": scan_range,
                "scan_count": scan_count,
                "scan_indices": sorted(scan_indices) if scan_indices is not None else None,
                "before_capture": summary["before_capture"],
                "after_capture": summary["after_capture"],
                "summary": str(summary_path),
            }
        )
        y_offset = next_y_offset

    return rows



def _motion_score_curve(
    before_arr: np.ndarray,
    after_arr: np.ndarray,
    *,
    expected_move_px: int,
    search_min_px: int,
    search_max_px: int,
) -> list[dict]:
    height = min(before_arr.shape[0], after_arr.shape[0])
    width = min(before_arr.shape[1], after_arr.shape[1])
    if height <= expected_move_px + 16 or width <= 8:
        return []
    before = before_arr[:height, :width]
    after = after_arr[:height, :width]
    search_min = max(1, int(search_min_px))
    search_max = min(height - 8, int(search_max_px))
    if search_min > search_max:
        return []

    rows: list[dict] = []
    for move in range(search_min, search_max + 1):
        before_part = before[move:height, :]
        after_part = after[:height - move, :]
        denom = float(np.sqrt(np.sum(before_part * before_part) * np.sum(after_part * after_part)))
        if denom <= 1e-6:
            continue
        score = float(np.sum(before_part * after_part) / denom)
        rows.append(
            {
                "move_px": move,
                "score": score,
                "expected_delta_px": int(expected_move_px) - move,
            }
        )
    return rows


def _inventory_motion_edge_array(
    image: Image.Image,
    grid_region: dict,
    *,
    slots: list[dict] | None = None,
) -> np.ndarray | None:
    region = _inventory_motion_region(grid_region)
    crop = crop_region(image, region).convert("L")
    arr = np.asarray(crop, dtype=np.float32)
    if arr.size == 0 or arr.shape[0] < 8 or arr.shape[1] < 8:
        return None
    gx = np.abs(np.diff(arr, axis=1, prepend=arr[:, :1]))
    gy = np.abs(np.diff(arr, axis=0, prepend=arr[:1, :]))
    edge = (gy * 1.5) + (gx * 0.5)
    edge = _suppress_slot_side_bands(
        edge,
        motion_region=region,
        image_size=image.size,
        slots=slots,
    )
    std = float(edge.std())
    if std > 1e-6:
        edge = (edge - float(edge.mean())) / std
    return edge.astype(np.float32, copy=False)


def _region_pixel_box(region: dict, image_size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = image_size
    x1 = int(round(float(region["x1"]) * width))
    y1 = int(round(float(region["y1"]) * height))
    x2 = int(round(float(region["x2"]) * width))
    y2 = int(round(float(region["y2"]) * height))
    x1, x2 = sorted((x1, x2))
    y1, y2 = sorted((y1, y2))
    return x1, y1, x2, y2


def _inventory_digit_motion_edge_pair(
    image: Image.Image,
    grid_region: dict,
    *,
    slots: list[dict] | None = None,
) -> tuple[np.ndarray, np.ndarray] | None:
    if not slots:
        return None
    region = _inventory_motion_region(grid_region)
    crop = crop_region(image, region).convert("L")
    arr = np.asarray(crop, dtype=np.float32)
    if arr.size == 0 or arr.shape[0] < 8 or arr.shape[1] < 8:
        return None

    gx = np.abs(np.diff(arr, axis=1, prepend=arr[:, :1]))
    gy = np.abs(np.diff(arr, axis=0, prepend=arr[:1, :]))
    edge = (gy * 1.5) + (gx * 0.5)

    left, top, _right, _bottom = _region_pixel_box(region, image.size)
    mask_img = Image.new("L", (arr.shape[1], arr.shape[0]), 0)
    draw = ImageDraw.Draw(mask_img)
    for slot in slots:
        for position in range(6):
            digit = _digit_region(slot, position, image.size)
            points = []
            for point in digit.get("points_ratio", []):
                px = int(round(float(point["x"]) * image.width)) - left
                py = int(round(float(point["y"]) * image.height)) - top
                points.append((px, py))
            if len(points) == 4:
                draw.polygon(points, fill=255)
    mask = np.asarray(mask_img, dtype=np.float32) / 255.0
    if float(mask.sum()) < 16.0:
        return None
    edge *= mask
    active = edge[mask > 0]
    if active.size > 0:
        mean = float(active.mean())
        std = float(active.std())
        if std > 1e-6:
            edge = ((edge - mean) / std) * mask
    return edge.astype(np.float32, copy=False), mask.astype(np.float32, copy=False)


def _weighted_ncc_score(
    before_part: np.ndarray,
    after_part: np.ndarray,
    weight_part: np.ndarray,
) -> float | None:
    weight = weight_part.astype(np.float64, copy=False)
    sample_weight = float(weight.sum())
    if sample_weight < 16.0:
        return None
    before_f = before_part.astype(np.float64, copy=False)
    after_f = after_part.astype(np.float64, copy=False)
    before_mean = float(np.sum(before_f * weight) / sample_weight)
    after_mean = float(np.sum(after_f * weight) / sample_weight)
    before_c = (before_f - before_mean) * weight
    after_c = (after_f - after_mean) * weight
    denom = float(np.sqrt(np.sum(before_c * before_c) * np.sum(after_c * after_c)))
    if denom <= 1e-6:
        return None
    return float(np.sum(before_c * after_c) / denom)


def _motion_weighted_ncc_curve(
    before_arr: np.ndarray,
    after_arr: np.ndarray,
    before_mask: np.ndarray,
    after_mask: np.ndarray,
    *,
    expected_move_px: int,
    search_min_px: int,
    search_max_px: int,
) -> list[dict]:
    height = min(before_arr.shape[0], after_arr.shape[0], before_mask.shape[0], after_mask.shape[0])
    width = min(before_arr.shape[1], after_arr.shape[1], before_mask.shape[1], after_mask.shape[1])
    if height <= expected_move_px + 16 or width <= 8:
        return []
    before = before_arr[:height, :width]
    after = after_arr[:height, :width]
    before_w = before_mask[:height, :width]
    after_w = after_mask[:height, :width]
    search_min = max(1, int(search_min_px))
    search_max = min(height - 8, int(search_max_px))
    if search_min > search_max:
        return []

    rows: list[dict] = []
    for move in range(search_min, search_max + 1):
        weight = before_w[move:height, :] * after_w[:height - move, :]
        score = _weighted_ncc_score(before[move:height, :], after[:height - move, :], weight)
        if score is None:
            continue
        rows.append(
            {
                "move_px": move,
                "score": score,
                "expected_delta_px": int(expected_move_px) - move,
                "sample_weight": float(weight.sum()),
            }
        )
    return rows


def _image_gradient_edge(image: Image.Image) -> np.ndarray:
    arr = np.asarray(image.convert("L"), dtype=np.float32)
    gx = np.abs(np.diff(arr, axis=1, prepend=arr[:, :1]))
    gy = np.abs(np.diff(arr, axis=0, prepend=arr[:1, :]))
    return ((gy * 1.5) + (gx * 0.5)).astype(np.float32, copy=False)


def _slot_digit_points(slot: dict, image_size: tuple[int, int]) -> list[list[tuple[int, int]]]:
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


def _slot_digit_edge_patch(
    edge: np.ndarray,
    image_size: tuple[int, int],
    slot: dict,
    *,
    margin_px: int = 2,
) -> tuple[np.ndarray, np.ndarray, tuple[int, int, int, int]] | None:
    polygons = _slot_digit_points(slot, image_size)
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


def _patch_weighted_ncc(
    before_patch: np.ndarray,
    before_mask: np.ndarray,
    after_patch: np.ndarray,
    after_mask: np.ndarray,
) -> tuple[float, float] | None:
    height = min(before_patch.shape[0], after_patch.shape[0], before_mask.shape[0], after_mask.shape[0])
    width = min(before_patch.shape[1], after_patch.shape[1], before_mask.shape[1], after_mask.shape[1])
    if height <= 1 or width <= 1:
        return None
    weight = before_mask[:height, :width] * after_mask[:height, :width]
    score = _weighted_ncc_score(
        before_patch[:height, :width],
        after_patch[:height, :width],
        weight,
    )
    if score is None:
        return None
    return score, float(weight.sum())


def _overlap_digit_vote_candidates(
    row_step_px: int,
    refine_radius_px: int,
    *,
    candidate_centers_px: Iterable[int] | None = None,
) -> list[int]:
    local_radius = max(0, int(refine_radius_px))
    if candidate_centers_px is None:
        centers = [0]
        if row_step_px > 0:
            centers = [-int(row_step_px), 0, int(row_step_px)]
    else:
        centers = [int(center) for center in candidate_centers_px]
    candidates = sorted({center + dy for center in centers for dy in range(-local_radius, local_radius + 1)})
    return candidates


def _slot_bottom_band_region(
    slot: dict,
    image_size: tuple[int, int],
    *,
    y_start_ratio: float = 0.52,
    y_end_ratio: float = 1.00,
    x_margin_ratio: float = 0.02,
) -> dict:
    slot_w = float(slot["x2"]) - float(slot["x1"])
    slot_h = float(slot["y2"]) - float(slot["y1"])
    return {
        "x1": max(0.0, float(slot["x1"]) + slot_w * x_margin_ratio),
        "y1": max(0.0, float(slot["y1"]) + slot_h * y_start_ratio),
        "x2": min(1.0, float(slot["x2"]) - slot_w * x_margin_ratio),
        "y2": min(1.0, float(slot["y1"]) + slot_h * y_end_ratio),
    }


def _gray_mask_for_patch(
    image: Image.Image,
    box: tuple[int, int, int, int],
    *,
    chroma_tolerance: int = 7,
    min_luma: int = 120,
    max_luma: int = 245,
) -> tuple[np.ndarray, np.ndarray] | None:
    x1, y1, x2, y2 = box
    if x2 <= x1 + 1 or y2 <= y1 + 1:
        return None
    arr = np.asarray(image.crop((x1, y1, x2, y2)).convert("RGB"), dtype=np.float32)
    if arr.size == 0:
        return None
    max_rgb = arr.max(axis=2)
    min_rgb = arr.min(axis=2)
    luma = (arr[:, :, 0] * 0.299) + (arr[:, :, 1] * 0.587) + (arr[:, :, 2] * 0.114)
    mask = (max_rgb - min_rgb <= float(chroma_tolerance)) & (luma >= float(min_luma)) & (luma <= float(max_luma))
    return mask.astype(np.float32), luma.astype(np.float32)


def _target_gray_mask_for_patch(
    image: Image.Image,
    box: tuple[int, int, int, int],
    *,
    target_rgb: tuple[int, int, int] = (0xC4, 0xCF, 0xD4),
    tolerance: int = 14,
) -> tuple[np.ndarray, np.ndarray] | None:
    x1, y1, x2, y2 = box
    if x2 <= x1 + 1 or y2 <= y1 + 1:
        return None
    arr = np.asarray(image.crop((x1, y1, x2, y2)).convert("RGB"), dtype=np.float32)
    if arr.size == 0:
        return None
    target = np.asarray(target_rgb, dtype=np.float32).reshape((1, 1, 3))
    diff = np.abs(arr - target)
    distance = np.sqrt(np.sum((arr - target) * (arr - target), axis=2))
    mask = np.max(diff, axis=2) <= float(tolerance)
    return mask.astype(np.float32), distance.astype(np.float32)


def _save_target_gray_mask_layer_image(source: Image.Image, box: tuple[int, int, int, int], output_path: Path) -> bool:
    mask_pair = _target_gray_mask_for_patch(source, box)
    if mask_pair is None:
        return False
    gray_mask, _distance = mask_pair
    x1, y1, x2, y2 = box
    alpha = np.clip(gray_mask * 190.0, 0, 190).astype(np.uint8)
    rgba = np.zeros((alpha.shape[0], alpha.shape[1], 4), dtype=np.uint8)
    rgba[:, :, 0] = 196
    rgba[:, :, 1] = 207
    rgba[:, :, 2] = 212
    rgba[:, :, 3] = alpha
    overlay = Image.fromarray(rgba, "RGBA")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    overlay.save(output_path)
    return True


def _gray_line_profile_patch(
    image: Image.Image,
    region: dict,
    *,
    chroma_tolerance: int = 7,
    min_luma: int = 120,
    max_luma: int = 245,
) -> tuple[np.ndarray, np.ndarray, tuple[int, int, int, int]] | None:
    box = _pixel_box_for_region(region, image.size)
    x1, y1, x2, y2 = box
    width, height = image.size
    x1 = max(0, min(width, x1))
    x2 = max(0, min(width, x2))
    y1 = max(0, min(height, y1))
    y2 = max(0, min(height, y2))
    if x2 <= x1 + 8 or y2 <= y1 + 3:
        return None
    mask_pair = _gray_mask_for_patch(
        image,
        (x1, y1, x2, y2),
        chroma_tolerance=chroma_tolerance,
        min_luma=min_luma,
        max_luma=max_luma,
    )
    if mask_pair is None:
        return None
    gray_mask, _luma = mask_pair
    gray_count = float(gray_mask.sum())
    if gray_count < max(8.0, gray_mask.shape[1] * 0.25):
        return None
    gray_ratio = gray_mask.mean(axis=1).astype(np.float32)
    edge_profile = np.abs(np.diff(gray_ratio, prepend=gray_ratio[:1]))
    if float(edge_profile.max(initial=0.0)) <= 1e-6:
        return None
    profile = edge_profile - float(edge_profile.mean())
    std = float(profile.std())
    if std > 1e-6:
        profile = profile / std
    return profile.astype(np.float32, copy=False), gray_mask.astype(np.float32, copy=False), (x1, y1, x2, y2)


def _profile_ncc_score(before_profile: np.ndarray, after_profile: np.ndarray) -> float | None:
    height = min(before_profile.shape[0], after_profile.shape[0])
    if height <= 2:
        return None
    before_f = before_profile[:height].astype(np.float64, copy=False)
    after_f = after_profile[:height].astype(np.float64, copy=False)
    before_f = before_f - float(before_f.mean())
    after_f = after_f - float(after_f.mean())
    denom = float(np.sqrt(np.sum(before_f * before_f) * np.sum(after_f * after_f)))
    if denom <= 1e-6:
        return None
    return float(np.sum(before_f * after_f) / denom)


def _save_gray_mask_layer_image(source: Image.Image, box: tuple[int, int, int, int], output_path: Path) -> bool:
    mask_pair = _gray_mask_for_patch(source, box)
    if mask_pair is None:
        return False
    gray_mask, _luma = mask_pair
    x1, y1, x2, y2 = box
    overlay = Image.new("RGBA", (max(1, x2 - x1), max(1, y2 - y1)), (0, 0, 0, 0))
    alpha = np.clip(gray_mask * 180.0, 0, 180).astype(np.uint8)
    rgba = np.zeros((alpha.shape[0], alpha.shape[1], 4), dtype=np.uint8)
    rgba[:, :, 0] = 80
    rgba[:, :, 1] = 220
    rgba[:, :, 2] = 255
    rgba[:, :, 3] = alpha
    overlay = Image.fromarray(rgba, "RGBA")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    overlay.save(output_path)
    return True


def _edge_region_patch(
    edge: np.ndarray,
    image_size: tuple[int, int],
    region: dict,
) -> tuple[np.ndarray, np.ndarray, tuple[int, int, int, int]] | None:
    x1, y1, x2, y2 = _pixel_box_for_region(region, image_size)
    height, width = edge.shape[:2]
    x1 = max(0, min(width, x1))
    x2 = max(0, min(width, x2))
    y1 = max(0, min(height, y1))
    y2 = max(0, min(height, y2))
    if x2 <= x1 + 1 or y2 <= y1 + 1:
        return None
    patch = edge[y1:y2, x1:x2].astype(np.float32, copy=True)
    mask = np.ones_like(patch, dtype=np.float32)
    active = patch[mask > 0]
    if active.size > 0:
        mean = float(active.mean())
        std = float(active.std())
        if std > 1e-6:
            patch = ((patch - mean) / std) * mask
    return patch.astype(np.float32, copy=False), mask, (x1, y1, x2, y2)


def _gray_band_target_height_px(slots: list[dict]) -> int:
    row_centers = {round(float(slot.get("cy", 0.0)), 5) for slot in slots}
    return 1050 if len(row_centers) >= 5 else 870


def _gray_bar_scan_region(
    slots: list[dict],
    image_size: tuple[int, int],
    *,
    target_width_px: int = 1150,
    target_height_px: int | None = None,
) -> dict:
    grid = _grid_region(slots)
    gx1, gy1, gx2, gy2 = _pixel_box_for_region(grid, image_size)
    image_w, image_h = image_size
    grid_w = max(1, gx2 - gx1)
    grid_h = max(1, gy2 - gy1)
    if target_height_px is None:
        target_height_px = _gray_band_target_height_px(slots)
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


def _gray_bar_detection_region(slots: list[dict], image_size: tuple[int, int]) -> dict:
    return _gray_bar_scan_region(slots, image_size)


def _detect_gray_bars(
    image: Image.Image,
    region: dict,
    *,
    target_tolerance: int = 14,
    scan_width_px: int = 1150,
    scan_height_px: int = 8,
    x_step_px: int = 4,
    min_y_separation_px: int = 10,
) -> list[dict]:
    x1, y1, x2, y2 = _pixel_box_for_region(region, image.size)
    width, height = image.size
    x1 = max(0, min(width, x1))
    x2 = max(0, min(width, x2))
    y1 = max(0, min(height, y1))
    y2 = max(0, min(height, y2))
    roi_w = int(scan_width_px)
    roi_h = int(scan_height_px)
    if x2 < x1 + roi_w or y2 < y1 + roi_h:
        return []
    mask_pair = _target_gray_mask_for_patch(
        image,
        (x1, y1, x2, y2),
        tolerance=target_tolerance,
    )
    if mask_pair is None:
        return []
    gray_mask, _distance = mask_pair
    integral = np.pad(gray_mask, ((1, 0), (1, 0)), mode="constant").cumsum(axis=0).cumsum(axis=1)

    def rect_sum(local_x: int, local_y: int) -> float:
        xx1 = local_x
        yy1 = local_y
        xx2 = local_x + roi_w
        yy2 = local_y + roi_h
        return float(integral[yy2, xx2] - integral[yy1, xx2] - integral[yy2, xx1] + integral[yy1, xx1])

    max_local_x = gray_mask.shape[1] - roi_w
    max_local_y = gray_mask.shape[0] - roi_h
    x_step = max(1, int(x_step_px))
    y_candidates: list[dict] = []
    area = float(roi_w * roi_h)
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
                "height_px": roi_h,
                "width_px": roi_w,
                "strength": float(best_score),
                "peak": float(best_score),
                "threshold": None,
                "scan_roi_width_px": roi_w,
                "scan_roi_height_px": roi_h,
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
    selected.sort(key=lambda row: float(row["strength"]), reverse=True)
    return selected


def _gray_bar_roi_from_box(name: str, box: tuple[int, int, int, int], *, enabled: bool = True) -> dict:
    x1, y1, x2, y2 = box
    return {
        "name": name,
        "x": int(x1),
        "y": int(y1),
        "width": max(1, int(x2) - int(x1)),
        "height": max(1, int(y2) - int(y1)),
        "enabled": enabled,
        "shape": "rectangle",
        "slant": 0,
    }



def _choose_regular_gray_band_sequence(
    bars: list[dict],
    *,
    count: int,
    expected_spacing_px: int,
    tolerance_px: int = 24,
) -> dict | None:
    if count <= 0 or expected_spacing_px <= 0:
        return None
    if len(bars) < count:
        return None
    candidates = sorted(bars, key=lambda row: float(row["y_center_px"]))
    best: dict | None = None
    tolerance = max(1, int(tolerance_px))
    for start in candidates:
        sequence = [start]
        score_parts = [float(start["strength"])]
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
            score_parts.append(float(nearest["strength"]))
            penalties.append(error / max(1.0, float(expected_spacing_px)))
        if len(sequence) != count:
            continue
        spacing_score = 1.0 - min(1.0, (sum(penalties) / max(1, len(penalties))) if penalties else 0.0)
        mean_strength = sum(score_parts) / max(1, len(score_parts))
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



def _gray_band_tail_anchors_px(grid_rows: int, image_height: int) -> list[float]:
    scale = float(image_height) / 1440.0
    if grid_rows >= 5:
        anchors = [565.5, 767.5, 959.5, 1162.5, 1364.5]
    elif grid_rows == 4:
        anchors = [398.0, 599.0, 801.0, 1004.0]
    else:
        return []
    return [value * scale for value in anchors]


def _gray_band_tail_signature(
    bands: list[dict],
    image_size: tuple[int, int],
    *,
    grid_rows: int,
    max_mean_error_px: float = 6.0,
    max_single_error_px: float = 10.0,
    min_mean_strength: float = 0.65,
) -> dict | None:
    anchors = _gray_band_tail_anchors_px(grid_rows, image_size[1])
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


def _public_gray_band_tail_signature(signature: dict | None) -> dict | None:
    if signature is None:
        return None
    return {
        "detected": True,
        "anchors_px": [round(float(value), 3) for value in signature["anchors_px"]],
        "band_y_centers_px": [round(float(value), 3) for value in signature["band_y_centers_px"]],
        "errors_px": [round(float(value), 3) for value in signature["errors_px"]],
        "mean_error_px": round(float(signature["mean_error_px"]), 3),
        "max_error_px": round(float(signature["max_error_px"]), 3),
        "mean_strength": round(float(signature["mean_strength"]), 6),
        "score": round(float(signature["score"]), 6),
    }



def _tail_last_row_top_px(grid_rows: int, image_height: int) -> float | None:
    scale = float(image_height) / 1440.0
    if grid_rows >= 5:
        return 1171.0 * scale
    if grid_rows == 4:
        return 1010.0 * scale
    return None


def _slots_from_tail_last_row_anchor(
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
    last_top = _tail_last_row_top_px(grid_rows, image_h)
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


def _slots_from_gray_band_spaces(
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
    _image_w, image_h = image_size
    band_centers = sorted(float(row["y_center_px"]) for row in bands)
    if not band_centers:
        return list(base_slots), []
    if len(band_centers) >= 2:
        spacing = float(np.median(np.diff(np.asarray(band_centers, dtype=np.float32))))
    else:
        spacing = float(fallback_row_step_px)
    if spacing <= 0:
        spacing = float(fallback_row_step_px or 1)
    virtual_top_band = band_centers[0] - spacing
    boundaries = [virtual_top_band, *band_centers]
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


def _gray_band_layout_for_image(
    image: Image.Image,
    base_slots: list[dict],
    *,
    grid_cols: int,
    grid_rows: int,
    row_step_px: int,
) -> dict | None:
    region = _gray_bar_scan_region(base_slots, image.size)
    bars = _detect_gray_bars(image, region)
    tail_signature = _gray_band_tail_signature(bars, image.size, grid_rows=grid_rows)
    sequence = _choose_regular_gray_band_sequence(
        bars,
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
    if sequence is None:
        return None
    tail_anchor_layout = (
        _slots_from_tail_last_row_anchor(
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
        rebuilt_slots, row_centers = tail_anchor_layout
    else:
        rebuilt_slots, row_centers = _slots_from_gray_band_spaces(
            base_slots,
            image.size,
            grid_cols=grid_cols,
            grid_rows=grid_rows,
            bands=sequence["bands"],
            fallback_row_step_px=row_step_px,
        )
    return {
        "scan_region": region,
        "bars": bars,
        "selected_bands": sequence["bands"],
        "selected_score": sequence["score"],
        "selected_mean_strength": sequence["mean_strength"],
        "selected_spacing_score": sequence["spacing_score"],
        "row_centers_px": row_centers,
        "slots": rebuilt_slots,
        "tail_page_detected": tail_signature is not None,
        "tail_signature": _public_gray_band_tail_signature(tail_signature),
        "tail_last_row_top_px": round(float(_tail_last_row_top_px(grid_rows, image.size[1]) or 0.0), 3) if tail_signature is not None else None,
    }


def _overlap_gray_bar_diagnostic(
    before: Image.Image,
    after: Image.Image,
    base_slots: list[dict],
    *,
    before_y_offset_px: int,
    grid_cols: int,
    grid_rows: int,
    row_step_px: int,
    moved_rows: int | None,
    refine_radius_px: int,
) -> dict | None:
    if row_step_px <= 0 or grid_cols <= 0 or grid_rows <= 0:
        return None
    if moved_rows is None or moved_rows <= 0 or moved_rows >= grid_rows:
        return None
    overlap_rows = grid_rows - moved_rows
    if overlap_rows <= 0:
        return None
    before_slots = _shift_slots_y(base_slots, before_y_offset_px, before.size) if before_y_offset_px else base_slots
    detect_region = _gray_bar_detection_region(before_slots, before.size)
    before_bars = _detect_gray_bars(before, detect_region)
    after_bars = _detect_gray_bars(after, detect_region)
    if not before_bars or not after_bars:
        return None

    expected_shift = int(moved_rows) * int(row_step_px)
    radius = max(0, int(refine_radius_px))
    pair_votes: list[dict] = []
    for before_index, before_bar in enumerate(before_bars):
        predicted_after_y = float(before_bar["y_center_px"]) - expected_shift
        for after_index, after_bar in enumerate(after_bars):
            delta = float(after_bar["y_center_px"]) - predicted_after_y
            if abs(delta) > radius + 0.51:
                continue
            rounded_delta = int(round(delta))
            score = (float(before_bar["strength"]) * float(after_bar["strength"])) ** 0.5
            score -= min(0.25, abs(delta - rounded_delta) * 0.05)
            pair_votes.append(
                {
                    "before_bar_index": before_index,
                    "after_bar_index": after_index,
                    "delta_y_offset_px": rounded_delta,
                    "raw_delta_y_offset_px": float(delta),
                    "score": float(score),
                    "before_y_center_px": float(before_bar["y_center_px"]),
                    "after_y_center_px": float(after_bar["y_center_px"]),
                    "predicted_after_y_center_px": float(predicted_after_y),
                    "before_box": [
                        int(before_bar["x1_px"]),
                        int(before_bar["y1_px"]),
                        int(before_bar["x2_px"]),
                        int(before_bar["y2_px"]),
                    ],
                    "after_box": [
                        int(after_bar["x1_px"]),
                        int(after_bar["y1_px"]),
                        int(after_bar["x2_px"]),
                        int(after_bar["y2_px"]),
                    ],
                    "before_strength": float(before_bar["strength"]),
                    "after_strength": float(after_bar["strength"]),
                }
            )
    if not pair_votes:
        return None
    groups: dict[int, list[dict]] = {}
    for vote in pair_votes:
        groups.setdefault(int(vote["delta_y_offset_px"]), []).append(vote)
    dominant_delta, dominant_votes = max(
        groups.items(),
        key=lambda item: (len(item[1]), sum(float(v["score"]) for v in item[1]) / max(1, len(item[1]))),
    )
    dominant_votes_sorted = sorted(dominant_votes, key=lambda row: float(row["score"]), reverse=True)
    dominant_score = sum(float(vote["score"]) for vote in dominant_votes) / max(1, len(dominant_votes))
    return {
        "method": "whole_region_gray_bar_position_vote",
        "before_y_offset_px": int(before_y_offset_px),
        "dominant_delta_y_offset_px": int(dominant_delta),
        "dominant_after_y_offset_px": int(before_y_offset_px + dominant_delta),
        "dominant_move_px": int(expected_shift - dominant_delta),
        "dominant_count": len(dominant_votes),
        "slot_count": max(1, min(len(before_bars), len(after_bars))),
        "confidence": len(dominant_votes) / max(1, len(pair_votes)),
        "dominant_mean_score": dominant_score,
        "moved_rows": int(moved_rows),
        "overlap_rows": int(overlap_rows),
        "candidate_delta_y_offsets_px": list(range(-radius, radius + 1)),
        "detection_region": detect_region,
        "before_bars": before_bars,
        "after_bars": after_bars,
        "votes": pair_votes,
        "selected_pairs": dominant_votes_sorted[:8],
        "groups": {
            str(delta): {
                "count": len(votes),
                "mean_score": sum(float(v["score"]) for v in votes) / max(1, len(votes)),
            }
            for delta, votes in sorted(groups.items())
        },
    }


def _overlap_gray_line_diagnostic(
    before: Image.Image,
    after: Image.Image,
    base_slots: list[dict],
    *,
    before_y_offset_px: int,
    grid_cols: int,
    grid_rows: int,
    row_step_px: int,
    moved_rows: int | None,
    refine_radius_px: int,
) -> dict | None:
    if row_step_px <= 0 or grid_cols <= 0 or grid_rows <= 0:
        return None
    if moved_rows is None or moved_rows <= 0 or moved_rows >= grid_rows:
        return None
    overlap_rows = grid_rows - moved_rows
    if overlap_rows <= 0:
        return None
    overlap_row = 0
    before_row = moved_rows + overlap_row
    after_row = overlap_row
    if before_row >= grid_rows or after_row >= grid_rows:
        return None

    before_slots = _shift_slots_y(base_slots, before_y_offset_px, before.size) if before_y_offset_px else base_slots
    candidate_deltas = _overlap_digit_vote_candidates(row_step_px, refine_radius_px, candidate_centers_px=(0,))
    slot_votes: list[dict] = []

    for col in range(grid_cols):
        before_idx = before_row * grid_cols + col
        after_idx = after_row * grid_cols + col
        if before_idx >= len(base_slots) or after_idx >= len(base_slots):
            continue
        before_region = _slot_bottom_band_region(
            before_slots[before_idx],
            before.size,
            y_start_ratio=0.42,
            y_end_ratio=1.00,
            x_margin_ratio=0.06,
        )
        before_patch = _gray_line_profile_patch(before, before_region)
        if before_patch is None:
            continue
        before_profile, before_mask, before_box = before_patch
        candidate_rows: list[dict] = []
        for delta_y in candidate_deltas:
            after_y_offset = before_y_offset_px + int(delta_y)
            after_slot = _shift_region_y(base_slots[after_idx], after_y_offset, after.size[1]) if after_y_offset else base_slots[after_idx]
            after_region = _slot_bottom_band_region(
                after_slot,
                after.size,
                y_start_ratio=0.42,
                y_end_ratio=1.00,
                x_margin_ratio=0.06,
            )
            after_patch = _gray_line_profile_patch(after, after_region)
            if after_patch is None:
                continue
            after_profile, after_mask, after_box = after_patch
            score = _profile_ncc_score(before_profile, after_profile)
            if score is None:
                continue
            sample_weight = float(before_mask.sum() + after_mask.sum()) / 2.0
            candidate_rows.append(
                {
                    "delta_y_offset_px": int(delta_y),
                    "score": score,
                    "sample_weight": sample_weight,
                    "after_y_offset_px": after_y_offset,
                    "after_box": after_box,
                }
            )
        if not candidate_rows:
            continue
        best = max(candidate_rows, key=lambda item: float(item["score"]))
        top = sorted(candidate_rows, key=lambda item: float(item["score"]), reverse=True)[:5]
        slot_votes.append(
            {
                "column": col,
                "before_slot_index": before_idx,
                "after_slot_index": after_idx,
                "before_row": before_row,
                "after_row": after_row,
                "before_box": before_box,
                "best_delta_y_offset_px": int(best["delta_y_offset_px"]),
                "best_after_y_offset_px": int(best["after_y_offset_px"]),
                "best_score": float(best["score"]),
                "best_sample_weight": float(best["sample_weight"]),
                "best_after_box": best.get("after_box"),
                "top_candidates": [
                    {
                        "delta_y_offset_px": int(candidate["delta_y_offset_px"]),
                        "score": float(candidate["score"]),
                        "sample_weight": float(candidate["sample_weight"]),
                    }
                    for candidate in top
                ],
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
        "method": "overlap_row_gray_line_profile_vote",
        "before_y_offset_px": int(before_y_offset_px),
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
        "candidate_delta_y_offsets_px": candidate_deltas,
        "votes": slot_votes,
        "groups": {
            str(delta): {
                "count": len(votes),
                "mean_score": sum(float(v["best_score"]) for v in votes) / max(1, len(votes)),
                "columns": [int(v["column"]) for v in votes],
            }
            for delta, votes in sorted(groups.items())
        },
    }


def _overlap_bottom_band_diagnostic(
    before: Image.Image,
    after: Image.Image,
    base_slots: list[dict],
    *,
    before_y_offset_px: int,
    grid_cols: int,
    grid_rows: int,
    row_step_px: int,
    moved_rows: int | None,
    refine_radius_px: int,
) -> dict | None:
    if row_step_px <= 0 or grid_cols <= 0 or grid_rows <= 0:
        return None
    if moved_rows is None or moved_rows <= 0 or moved_rows >= grid_rows:
        return None
    overlap_rows = grid_rows - moved_rows
    if overlap_rows <= 0:
        return None
    overlap_row = 0
    before_row = moved_rows + overlap_row
    after_row = overlap_row
    if before_row >= grid_rows or after_row >= grid_rows:
        return None

    before_slots = _shift_slots_y(base_slots, before_y_offset_px, before.size) if before_y_offset_px else base_slots
    before_edge = _image_gradient_edge(before)
    after_edge = _image_gradient_edge(after)
    candidate_deltas = _overlap_digit_vote_candidates(row_step_px, refine_radius_px, candidate_centers_px=(0,))
    slot_votes: list[dict] = []

    for col in range(grid_cols):
        before_idx = before_row * grid_cols + col
        after_idx = after_row * grid_cols + col
        if before_idx >= len(base_slots) or after_idx >= len(base_slots):
            continue
        before_region = _slot_bottom_band_region(before_slots[before_idx], before.size)
        before_patch = _edge_region_patch(before_edge, before.size, before_region)
        if before_patch is None:
            continue
        before_arr, before_mask, before_box = before_patch
        candidate_rows: list[dict] = []
        for delta_y in candidate_deltas:
            after_y_offset = before_y_offset_px + int(delta_y)
            after_slot = _shift_region_y(base_slots[after_idx], after_y_offset, after.size[1]) if after_y_offset else base_slots[after_idx]
            after_region = _slot_bottom_band_region(after_slot, after.size)
            after_patch = _edge_region_patch(after_edge, after.size, after_region)
            if after_patch is None:
                continue
            after_arr, after_mask, after_box = after_patch
            scored = _patch_weighted_ncc(before_arr, before_mask, after_arr, after_mask)
            if scored is None:
                continue
            score, sample_weight = scored
            candidate_rows.append(
                {
                    "delta_y_offset_px": int(delta_y),
                    "score": score,
                    "sample_weight": sample_weight,
                    "after_y_offset_px": after_y_offset,
                    "after_box": after_box,
                }
            )
        if not candidate_rows:
            continue
        best = max(candidate_rows, key=lambda item: float(item["score"]))
        top = sorted(candidate_rows, key=lambda item: float(item["score"]), reverse=True)[:5]
        slot_votes.append(
            {
                "column": col,
                "before_slot_index": before_idx,
                "after_slot_index": after_idx,
                "before_row": before_row,
                "after_row": after_row,
                "before_box": before_box,
                "best_delta_y_offset_px": int(best["delta_y_offset_px"]),
                "best_after_y_offset_px": int(best["after_y_offset_px"]),
                "best_score": float(best["score"]),
                "best_sample_weight": float(best["sample_weight"]),
                "best_after_box": best.get("after_box"),
                "top_candidates": [
                    {
                        "delta_y_offset_px": int(candidate["delta_y_offset_px"]),
                        "score": float(candidate["score"]),
                        "sample_weight": float(candidate["sample_weight"]),
                    }
                    for candidate in top
                ],
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
        "method": "overlap_row_bottom_band_vote",
        "before_y_offset_px": int(before_y_offset_px),
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
        "candidate_delta_y_offsets_px": candidate_deltas,
        "votes": slot_votes,
        "groups": {
            str(delta): {
                "count": len(votes),
                "mean_score": sum(float(v["best_score"]) for v in votes) / max(1, len(votes)),
                "columns": [int(v["column"]) for v in votes],
            }
            for delta, votes in sorted(groups.items())
        },
    }


def _overlap_digit_vote_diagnostic(
    before: Image.Image,
    after: Image.Image,
    base_slots: list[dict],
    *,
    before_y_offset_px: int,
    grid_cols: int,
    grid_rows: int,
    row_step_px: int,
    moved_rows: int | None,
    refine_radius_px: int,
    candidate_centers_px: Iterable[int] | None = None,
) -> dict | None:
    if row_step_px <= 0 or grid_cols <= 0 or grid_rows <= 0:
        return None
    if moved_rows is None or moved_rows <= 0 or moved_rows >= grid_rows:
        moved_rows = max(1, grid_rows - 1)
    overlap_rows = max(1, grid_rows - moved_rows)
    overlap_row = 0
    before_row = moved_rows + overlap_row
    after_row = overlap_row
    if before_row >= grid_rows or after_row >= grid_rows:
        return None

    before_slots = _shift_slots_y(base_slots, before_y_offset_px, before.size) if before_y_offset_px else base_slots
    before_edge = _image_gradient_edge(before)
    after_edge = _image_gradient_edge(after)
    candidate_deltas = _overlap_digit_vote_candidates(
        row_step_px,
        refine_radius_px,
        candidate_centers_px=candidate_centers_px,
    )
    slot_votes: list[dict] = []

    for col in range(grid_cols):
        before_idx = before_row * grid_cols + col
        after_idx = after_row * grid_cols + col
        if before_idx >= len(base_slots) or after_idx >= len(base_slots):
            continue
        before_patch = _slot_digit_edge_patch(before_edge, before.size, before_slots[before_idx])
        if before_patch is None:
            continue
        before_arr, before_mask, before_box = before_patch
        candidate_rows: list[dict] = []
        for delta_y in candidate_deltas:
            after_y_offset = before_y_offset_px + int(delta_y)
            after_slot = _shift_region_y(base_slots[after_idx], after_y_offset, after.size[1]) if after_y_offset else base_slots[after_idx]
            after_patch = _slot_digit_edge_patch(after_edge, after.size, after_slot)
            if after_patch is None:
                continue
            after_arr, after_mask, after_box = after_patch
            scored = _patch_weighted_ncc(before_arr, before_mask, after_arr, after_mask)
            if scored is None:
                continue
            score, sample_weight = scored
            candidate_rows.append(
                {
                    "delta_y_offset_px": int(delta_y),
                    "score": score,
                    "sample_weight": sample_weight,
                    "after_y_offset_px": after_y_offset,
                    "after_box": after_box,
                }
            )
        if not candidate_rows:
            continue
        best = max(candidate_rows, key=lambda item: float(item["score"]))
        top = sorted(candidate_rows, key=lambda item: float(item["score"]), reverse=True)[:5]
        slot_votes.append(
            {
                "column": col,
                "before_slot_index": before_idx,
                "after_slot_index": after_idx,
                "before_row": before_row,
                "after_row": after_row,
                "before_box": before_box,
                "best_delta_y_offset_px": int(best["delta_y_offset_px"]),
                "best_after_y_offset_px": int(best["after_y_offset_px"]),
                "best_score": float(best["score"]),
                "best_sample_weight": float(best["sample_weight"]),
                "best_after_box": best.get("after_box"),
                "top_candidates": [
                    {
                        "delta_y_offset_px": int(candidate["delta_y_offset_px"]),
                        "score": float(candidate["score"]),
                        "sample_weight": float(candidate["sample_weight"]),
                    }
                    for candidate in top
                ],
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
        "before_y_offset_px": int(before_y_offset_px),
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
        "candidate_delta_y_offsets_px": candidate_deltas,
        "votes": slot_votes,
        "groups": {
            str(delta): {
                "count": len(votes),
                "mean_score": sum(float(v["best_score"]) for v in votes) / max(1, len(votes)),
                "columns": [int(v["column"]) for v in votes],
            }
            for delta, votes in sorted(groups.items())
        },
    }


def _ncc_score(before_part: np.ndarray, after_part: np.ndarray) -> float | None:
    before_f = before_part.astype(np.float64, copy=False)
    after_f = after_part.astype(np.float64, copy=False)
    before_f = before_f - float(before_f.mean())
    after_f = after_f - float(after_f.mean())
    denom = float(np.sqrt(np.sum(before_f * before_f) * np.sum(after_f * after_f)))
    if denom <= 1e-6:
        return None
    return float(np.sum(before_f * after_f) / denom)


def _motion_ncc_curve(
    before_arr: np.ndarray,
    after_arr: np.ndarray,
    *,
    expected_move_px: int,
    search_min_px: int,
    search_max_px: int,
) -> list[dict]:
    height = min(before_arr.shape[0], after_arr.shape[0])
    width = min(before_arr.shape[1], after_arr.shape[1])
    if height <= expected_move_px + 16 or width <= 8:
        return []
    before = before_arr[:height, :width]
    after = after_arr[:height, :width]
    search_min = max(1, int(search_min_px))
    search_max = min(height - 8, int(search_max_px))
    if search_min > search_max:
        return []

    rows: list[dict] = []
    for move in range(search_min, search_max + 1):
        score = _ncc_score(before[move:height, :], after[:height - move, :])
        if score is None:
            continue
        rows.append(
            {
                "move_px": move,
                "score": score,
                "expected_delta_px": int(expected_move_px) - move,
            }
        )
    return rows


def _best_curve_row_near(curve: list[dict], center_px: int | None, *, radius_px: int) -> dict | None:
    if center_px is None:
        return None
    radius = max(0, int(radius_px))
    rows = [
        row
        for row in curve
        if abs(int(row["move_px"]) - int(center_px)) <= radius
    ]
    if not rows:
        return None
    return max(rows, key=lambda item: float(item["score"]))


def _top_motion_candidates(curve: list[dict], *, keep: int = 8, min_separation_px: int = 3) -> list[dict]:
    selected: list[dict] = []
    for row in sorted(curve, key=lambda item: float(item["score"]), reverse=True):
        move = int(row["move_px"])
        if any(abs(move - int(prev["move_px"])) < min_separation_px for prev in selected):
            continue
        selected.append(row)
        if len(selected) >= max(1, keep):
            break
    return selected


def _curve_row(curve: list[dict], move_px: int | None) -> dict | None:
    if move_px is None:
        return None
    for row in curve:
        if int(row["move_px"]) == int(move_px):
            return row
    return None


def _write_motion_curve_csv(path: Path, curve: list[dict]) -> None:
    has_sample_weight = any("sample_weight" in row for row in curve)
    header = "move_px,score,expected_delta_px"
    if has_sample_weight:
        header += ",sample_weight"
    lines = [header]
    for row in curve:
        line = f"{int(row['move_px'])},{float(row['score']):.9f},{int(row['expected_delta_px'])}"
        if has_sample_weight:
            line += f",{float(row.get('sample_weight') or 0.0):.1f}"
        lines.append(line)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _save_motion_edge_overlay(
    path: Path,
    before_edge: np.ndarray,
    after_edge: np.ndarray,
    move_px: int,
    *,
    label: str,
) -> None:
    height = min(before_edge.shape[0], after_edge.shape[0])
    width = min(before_edge.shape[1], after_edge.shape[1])
    move = max(1, min(int(move_px), height - 8))
    overlap_h = height - move
    if width <= 1 or overlap_h <= 1:
        return

    before_part = before_edge[move:height, :width]
    after_part = after_edge[:overlap_h, :width]

    def to_u8(arr: np.ndarray) -> Image.Image:
        arr = arr.astype(np.float32, copy=False)
        lo, hi = np.percentile(arr, [1.0, 99.0])
        if float(hi - lo) <= 1e-6:
            scaled = np.zeros(arr.shape, dtype=np.uint8)
        else:
            scaled = np.clip((arr - lo) * (255.0 / (hi - lo)), 0, 255).astype(np.uint8)
        return Image.fromarray(scaled, mode="L")

    before_img = to_u8(before_part)
    after_img = to_u8(after_part)
    overlay = Image.merge("RGB", (after_img, before_img, before_img))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle((0, 0, min(width - 1, len(label) * 7 + 8), 18), fill=(0, 0, 0))
    draw.text((4, 3), label, fill=(255, 255, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    overlay.save(path, quality=95)


def _save_motion_alignment_overlay(
    path: Path,
    before: Image.Image,
    after: Image.Image,
    grid_region: dict,
    move_px: int,
    *,
    label: str,
) -> None:
    before_crop = crop_region(before, _inventory_motion_region(grid_region)).convert("L")
    after_crop = crop_region(after, _inventory_motion_region(grid_region)).convert("L")
    width = min(before_crop.width, after_crop.width)
    height = min(before_crop.height, after_crop.height)
    move = max(1, min(int(move_px), height - 8))
    overlap_h = height - move
    if width <= 1 or overlap_h <= 1:
        return
    before_part = before_crop.crop((0, move, width, height))
    after_part = after_crop.crop((0, 0, width, overlap_h))
    overlay = Image.merge("RGB", (after_part, before_part, before_part))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle((0, 0, min(width - 1, len(label) * 7 + 8), 18), fill=(0, 0, 0))
    draw.text((4, 3), label, fill=(255, 255, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    overlay.save(path, quality=95)


def export_motion_diagnostics(
    folder: Path,
    section: str,
    rows: list[dict],
    output_dir: Path,
    *,
    top_n: int = 8,
    refine_radius_px: int = 4,
) -> list[Path]:
    base_slots = _load_slots(section)
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    index_rows: list[dict] = []

    for row in rows:
        scroll = int(row["scroll"])
        before_path = Path(row["before_capture"])
        after_path = Path(row["after_capture"])
        before = Image.open(before_path)
        after = Image.open(after_path)
        before_y = int(row.get("before_y_offset") or 0)
        before_slots = _shift_slots_y(base_slots, before_y, before.size) if before_y else base_slots
        grid_region = _grid_region(before_slots)
        grid_cols = int(row.get("grid_cols") or 5)
        row_step = int(row.get("row_step") or _slot_row_step_px(before_slots, before.size, grid_cols) or 0)
        grid_rows = int(row.get("grid_rows") or max(1, (len(base_slots) + grid_cols - 1) // max(1, grid_cols)))
        amount_px = int(row.get("amount") or 0)
        expected_move = min(abs(amount_px), row_step * max(1, grid_rows - 1)) if row_step > 0 else abs(amount_px)
        search_margin = max(50, row_step * max(1, grid_rows - 1)) if row_step > 0 else 50
        search_min = max(1, expected_move - max(1, search_margin))
        search_max = expected_move + max(1, search_margin)
        pair = _inventory_motion_feature_pair(before, after, grid_region, slots=before_slots)
        if pair is None:
            diag = {
                "scroll": scroll,
                "error": "feature_pair_failed",
                "before_capture": str(before_path),
                "after_capture": str(after_path),
            }
            diag_path = output_dir / f"scroll_{scroll:02d}_motion.json"
            _write_json(diag_path, diag)
            written.append(diag_path)
            index_rows.append(diag)
            continue

        curve = _motion_score_curve(
            pair[0],
            pair[1],
            expected_move_px=expected_move,
            search_min_px=search_min,
            search_max_px=search_max,
        )
        top = _top_motion_candidates(curve, keep=top_n)
        best = top[0] if top else None
        moved_rows = row.get("moved_rows")
        row_boundary_move = int(row_step * int(moved_rows)) if moved_rows is not None and row_step > 0 else None
        row_boundary = _curve_row(curve, row_boundary_move)
        old_actual = row.get("old_actual")
        replay_actual = row.get("actual")
        old_actual_row = _curve_row(curve, int(old_actual)) if old_actual is not None else None
        replay_actual_row = _curve_row(curve, int(replay_actual)) if replay_actual is not None else None
        top_score = float(best["score"]) if best is not None else None
        row_boundary_score = float(row_boundary["score"]) if row_boundary is not None else None
        boundary_gap = None
        if top_score is not None and row_boundary_score is not None:
            boundary_gap = top_score - row_boundary_score

        curve_path = output_dir / f"scroll_{scroll:02d}_curve.csv"
        _write_motion_curve_csv(curve_path, curve)
        written.append(curve_path)

        edge_before = _inventory_motion_edge_array(before, grid_region, slots=before_slots)
        edge_after = _inventory_motion_edge_array(after, grid_region, slots=before_slots)
        edge_curve: list[dict] = []
        edge_top: list[dict] = []
        edge_best: dict | None = None
        edge_row_boundary: dict | None = None
        edge_summary_actual: dict | None = None
        edge_replay_actual: dict | None = None
        edge_refinements: dict[str, dict | None] = {}
        edge_curve_path: Path | None = None
        if edge_before is not None and edge_after is not None:
            edge_curve = _motion_ncc_curve(
                edge_before,
                edge_after,
                expected_move_px=expected_move,
                search_min_px=search_min,
                search_max_px=search_max,
            )
            edge_top = _top_motion_candidates(edge_curve, keep=top_n)
            edge_best = edge_top[0] if edge_top else None
            edge_row_boundary = _curve_row(edge_curve, row_boundary_move)
            edge_summary_actual = _curve_row(edge_curve, int(old_actual)) if old_actual is not None else None
            edge_replay_actual = _curve_row(edge_curve, int(replay_actual)) if replay_actual is not None else None
            edge_refinements = {
                "near_feature_best": _best_curve_row_near(
                    edge_curve,
                    int(best["move_px"]) if best is not None else None,
                    radius_px=refine_radius_px,
                ),
                "near_row_boundary": _best_curve_row_near(
                    edge_curve,
                    row_boundary_move,
                    radius_px=refine_radius_px,
                ),
                "near_summary_actual": _best_curve_row_near(
                    edge_curve,
                    int(old_actual) if old_actual is not None else None,
                    radius_px=refine_radius_px,
                ),
                "near_replay_actual": _best_curve_row_near(
                    edge_curve,
                    int(replay_actual) if replay_actual is not None else None,
                    radius_px=refine_radius_px,
                ),
            }
            edge_curve_path = output_dir / f"scroll_{scroll:02d}_edge_ncc_curve.csv"
            _write_motion_curve_csv(edge_curve_path, edge_curve)
            written.append(edge_curve_path)

        digit_before_pair = _inventory_digit_motion_edge_pair(before, grid_region, slots=before_slots)
        digit_after_pair = _inventory_digit_motion_edge_pair(after, grid_region, slots=before_slots)
        digit_edge_before: np.ndarray | None = None
        digit_edge_after: np.ndarray | None = None
        digit_curve: list[dict] = []
        digit_top: list[dict] = []
        digit_best: dict | None = None
        digit_row_boundary: dict | None = None
        digit_summary_actual: dict | None = None
        digit_replay_actual: dict | None = None
        digit_refinements: dict[str, dict | None] = {}
        digit_curve_path: Path | None = None
        if digit_before_pair is not None and digit_after_pair is not None:
            digit_edge_before, digit_before_mask = digit_before_pair
            digit_edge_after, digit_after_mask = digit_after_pair
            digit_curve = _motion_weighted_ncc_curve(
                digit_edge_before,
                digit_edge_after,
                digit_before_mask,
                digit_after_mask,
                expected_move_px=expected_move,
                search_min_px=search_min,
                search_max_px=search_max,
            )
            digit_top = _top_motion_candidates(digit_curve, keep=top_n)
            digit_best = digit_top[0] if digit_top else None
            digit_row_boundary = _curve_row(digit_curve, row_boundary_move)
            digit_summary_actual = _curve_row(digit_curve, int(old_actual)) if old_actual is not None else None
            digit_replay_actual = _curve_row(digit_curve, int(replay_actual)) if replay_actual is not None else None
            digit_refinements = {
                "near_feature_best": _best_curve_row_near(
                    digit_curve,
                    int(best["move_px"]) if best is not None else None,
                    radius_px=refine_radius_px,
                ),
                "near_row_boundary": _best_curve_row_near(
                    digit_curve,
                    row_boundary_move,
                    radius_px=refine_radius_px,
                ),
                "near_summary_actual": _best_curve_row_near(
                    digit_curve,
                    int(old_actual) if old_actual is not None else None,
                    radius_px=refine_radius_px,
                ),
                "near_replay_actual": _best_curve_row_near(
                    digit_curve,
                    int(replay_actual) if replay_actual is not None else None,
                    radius_px=refine_radius_px,
                ),
            }
            digit_curve_path = output_dir / f"scroll_{scroll:02d}_digit_edge_ncc_curve.csv"
            _write_motion_curve_csv(digit_curve_path, digit_curve)
            written.append(digit_curve_path)

        overlap_digit_vote = _overlap_digit_vote_diagnostic(
            before,
            after,
            base_slots,
            before_y_offset_px=before_y,
            grid_cols=grid_cols,
            grid_rows=grid_rows,
            row_step_px=row_step,
            moved_rows=int(row.get("moved_rows")) if row.get("moved_rows") is not None else None,
            refine_radius_px=refine_radius_px,
        )

        overlays: list[str] = []
        overlay_candidates: list[tuple[str, int, float | None]] = []
        if best is not None:
            overlay_candidates.append(("best", int(best["move_px"]), float(best["score"])))
        if row_boundary is not None:
            overlay_candidates.append(("row_boundary", int(row_boundary["move_px"]), float(row_boundary["score"])))
        if old_actual_row is not None:
            overlay_candidates.append(("summary_actual", int(old_actual_row["move_px"]), float(old_actual_row["score"])))
        seen_moves: set[int] = set()
        for label, move, score in overlay_candidates:
            if move in seen_moves:
                continue
            seen_moves.add(move)
            overlay_path = output_dir / f"scroll_{scroll:02d}_{label}_{move}px_overlay.png"
            _save_motion_alignment_overlay(
                overlay_path,
                before,
                after,
                grid_region,
                move,
                label=f"{label} move={move}px score={score:.5f}" if score is not None else f"{label} move={move}px",
            )
            overlays.append(str(overlay_path))
            written.append(overlay_path)

        edge_overlays: list[str] = []
        if edge_before is not None and edge_after is not None:
            edge_overlay_candidates: list[tuple[str, int, float | None]] = []
            if edge_best is not None:
                edge_overlay_candidates.append(("edge_ncc_best", int(edge_best["move_px"]), float(edge_best["score"])))
            for label, candidate in edge_refinements.items():
                if candidate is not None:
                    edge_overlay_candidates.append((label, int(candidate["move_px"]), float(candidate["score"])))
            seen_edge_moves: set[int] = set()
            for label, move, score in edge_overlay_candidates:
                if move in seen_edge_moves:
                    continue
                seen_edge_moves.add(move)
                overlay_path = output_dir / f"scroll_{scroll:02d}_{label}_{move}px_edge_overlay.png"
                _save_motion_edge_overlay(
                    overlay_path,
                    edge_before,
                    edge_after,
                    move,
                    label=f"{label} move={move}px score={score:.5f}" if score is not None else f"{label} move={move}px",
                )
                edge_overlays.append(str(overlay_path))
                written.append(overlay_path)

        digit_overlays: list[str] = []
        if digit_edge_before is not None and digit_edge_after is not None:
            digit_overlay_candidates: list[tuple[str, int, float | None]] = []
            if digit_best is not None:
                digit_overlay_candidates.append(("digit_edge_ncc_best", int(digit_best["move_px"]), float(digit_best["score"])))
            for label, candidate in digit_refinements.items():
                if candidate is not None:
                    digit_overlay_candidates.append((f"digit_{label}", int(candidate["move_px"]), float(candidate["score"])))
            seen_digit_moves: set[int] = set()
            for label, move, score in digit_overlay_candidates:
                if move in seen_digit_moves:
                    continue
                seen_digit_moves.add(move)
                overlay_path = output_dir / f"scroll_{scroll:02d}_{label}_{move}px_edge_overlay.png"
                _save_motion_edge_overlay(
                    overlay_path,
                    digit_edge_before,
                    digit_edge_after,
                    move,
                    label=f"{label} move={move}px score={score:.5f}" if score is not None else f"{label} move={move}px",
                )
                digit_overlays.append(str(overlay_path))
                written.append(overlay_path)

        edge_best_score = float(edge_best["score"]) if edge_best is not None else None
        edge_row_boundary_score = float(edge_row_boundary["score"]) if edge_row_boundary is not None else None
        edge_boundary_gap = None
        if edge_best_score is not None and edge_row_boundary_score is not None:
            edge_boundary_gap = edge_best_score - edge_row_boundary_score
        digit_best_score = float(digit_best["score"]) if digit_best is not None else None
        digit_row_boundary_score = float(digit_row_boundary["score"]) if digit_row_boundary is not None else None
        digit_boundary_gap = None
        if digit_best_score is not None and digit_row_boundary_score is not None:
            digit_boundary_gap = digit_best_score - digit_row_boundary_score

        diag = {
            "scroll": scroll,
            "attempt": row.get("attempt"),
            "section": section,
            "before_capture": str(before_path),
            "after_capture": str(after_path),
            "expected_move_px": expected_move,
            "search_min_px": search_min,
            "search_max_px": min(pair[0].shape[0] - 8, search_max),
            "grid_cols": grid_cols,
            "grid_rows": grid_rows,
            "row_step_px": row_step,
            "moved_rows": moved_rows,
            "row_boundary_move_px": row_boundary_move,
            "row_boundary_score": row_boundary_score,
            "best_move_px": int(best["move_px"]) if best is not None else None,
            "best_score": top_score,
            "best_delta_from_row_boundary_px": (
                int(best["move_px"]) - int(row_boundary_move)
                if best is not None and row_boundary_move is not None
                else None
            ),
            "best_score_minus_row_boundary_score": boundary_gap,
            "summary_actual_move_px": old_actual,
            "replay_actual_move_px": replay_actual,
            "summary_actual_score": float(old_actual_row["score"]) if old_actual_row is not None else None,
            "replay_actual_score": float(replay_actual_row["score"]) if replay_actual_row is not None else None,
            "top_candidates": top,
            "edge_ncc_method": "full_2d_gradient_ncc_slot_sides_ignored",
            "edge_ncc_refine_radius_px": max(0, int(refine_radius_px)),
            "edge_ncc_best_move_px": int(edge_best["move_px"]) if edge_best is not None else None,
            "edge_ncc_best_score": edge_best_score,
            "edge_ncc_row_boundary_score": edge_row_boundary_score,
            "edge_ncc_best_delta_from_row_boundary_px": (
                int(edge_best["move_px"]) - int(row_boundary_move)
                if edge_best is not None and row_boundary_move is not None
                else None
            ),
            "edge_ncc_best_score_minus_row_boundary_score": edge_boundary_gap,
            "edge_ncc_summary_actual_score": (
                float(edge_summary_actual["score"]) if edge_summary_actual is not None else None
            ),
            "edge_ncc_replay_actual_score": (
                float(edge_replay_actual["score"]) if edge_replay_actual is not None else None
            ),
            "edge_ncc_top_candidates": edge_top,
            "edge_ncc_refinements": edge_refinements,
            "edge_ncc_curve_csv": str(edge_curve_path) if edge_curve_path is not None else None,
            "edge_ncc_overlays": edge_overlays,
            "digit_edge_ncc_method": "slot_count_digit_region_weighted_gradient_ncc",
            "digit_edge_ncc_refine_radius_px": max(0, int(refine_radius_px)),
            "digit_edge_ncc_best_move_px": int(digit_best["move_px"]) if digit_best is not None else None,
            "digit_edge_ncc_best_score": digit_best_score,
            "digit_edge_ncc_row_boundary_score": digit_row_boundary_score,
            "digit_edge_ncc_best_delta_from_row_boundary_px": (
                int(digit_best["move_px"]) - int(row_boundary_move)
                if digit_best is not None and row_boundary_move is not None
                else None
            ),
            "digit_edge_ncc_best_score_minus_row_boundary_score": digit_boundary_gap,
            "digit_edge_ncc_summary_actual_score": (
                float(digit_summary_actual["score"]) if digit_summary_actual is not None else None
            ),
            "digit_edge_ncc_replay_actual_score": (
                float(digit_replay_actual["score"]) if digit_replay_actual is not None else None
            ),
            "digit_edge_ncc_top_candidates": digit_top,
            "digit_edge_ncc_refinements": digit_refinements,
            "digit_edge_ncc_curve_csv": str(digit_curve_path) if digit_curve_path is not None else None,
            "digit_edge_ncc_overlays": digit_overlays,
            "overlap_digit_vote": overlap_digit_vote,
            "overlap_digit_vote_move_px": (
                int(overlap_digit_vote["dominant_move_px"]) if overlap_digit_vote is not None else None
            ),
            "overlap_digit_vote_delta_y_offset_px": (
                int(overlap_digit_vote["dominant_delta_y_offset_px"]) if overlap_digit_vote is not None else None
            ),
            "overlap_digit_vote_confidence": (
                float(overlap_digit_vote["confidence"]) if overlap_digit_vote is not None else None
            ),
            "curve_csv": str(curve_path),
            "overlays": overlays,
            "source_summary": row.get("summary"),
        }
        diag_path = output_dir / f"scroll_{scroll:02d}_motion.json"
        _write_json(diag_path, diag)
        written.append(diag_path)
        index_rows.append(diag)

    index_path = output_dir / "index.json"
    _write_json(index_path, {"folder": str(folder.resolve()), "section": section, "diagnostics": index_rows})
    written.append(index_path)
    return written


def _motion_search_window(row: dict, row_step: int, grid_rows: int) -> tuple[int, int, int]:
    amount_px = int(row.get("amount") or 0)
    expected_move = min(abs(amount_px), row_step * max(1, grid_rows - 1)) if row_step > 0 else abs(amount_px)
    search_margin = max(50, row_step * max(1, grid_rows - 1)) if row_step > 0 else 50
    search_min = max(1, expected_move - max(1, search_margin))
    search_max = expected_move + max(1, search_margin)
    return expected_move, search_min, search_max


def _motion_choice_for_studio(
    row: dict,
    before: Image.Image,
    after: Image.Image,
    grid_region: dict,
    *,
    base_slots: list[dict],
    before_slots: list[dict],
    before_y_offset_px: int,
    grid_cols: int,
    row_step: int,
    grid_rows: int,
    source: str,
    refine_radius_px: int,
) -> dict | None:
    expected_move, search_min, search_max = _motion_search_window(row, row_step, grid_rows)
    source = source.strip().lower()
    feature_motion = None
    if source in {"feature_best", "edge_ncc_near_feature_best", "digit_edge_ncc_near_feature_best"}:
        feature_motion = _estimate_motion_with_near_zero_verification(
            before,
            after,
            grid_region,
            expected_move,
            row_step,
            max(1, search_max - expected_move),
            slots=before_slots,
        )
    if source == "feature_best":
        if feature_motion is None:
            return None
        return {
            "source": source,
            "move_px": int(feature_motion.actual_move_px),
            "score": float(feature_motion.score),
            "expected_move_px": expected_move,
            "search_min_px": search_min,
            "search_max_px": search_max,
        }

    if source in {"overlap_digit_vote", "row_count_digit_template_move", "row_count_bottom_band_template_move", "row_count_gray_line_template_move", "row_count_gray_bar_template_move"}:
        row_moved_rows = row.get("moved_rows")
        if row.get("tail_scroll") or row_moved_rows is None:
            return None
        row_moved_rows = int(row_moved_rows)
        if row_moved_rows <= 0 or row_moved_rows >= grid_rows:
            return None
        fixed_row_count = source in {"row_count_digit_template_move", "row_count_bottom_band_template_move", "row_count_gray_line_template_move", "row_count_gray_bar_template_move"}
        if source == "row_count_gray_bar_template_move":
            vote = _overlap_gray_bar_diagnostic(
                before,
                after,
                base_slots,
                before_y_offset_px=before_y_offset_px,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                row_step_px=row_step,
                moved_rows=row_moved_rows,
                refine_radius_px=refine_radius_px,
            )
            vote_key = "overlap_gray_bar"
            actual_move_source = "gray_bar_position_matching"
        elif source == "row_count_gray_line_template_move":
            vote = _overlap_gray_line_diagnostic(
                before,
                after,
                base_slots,
                before_y_offset_px=before_y_offset_px,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                row_step_px=row_step,
                moved_rows=row_moved_rows,
                refine_radius_px=refine_radius_px,
            )
            vote_key = "overlap_gray_line"
            actual_move_source = "gray_line_profile_matching"
        elif source == "row_count_bottom_band_template_move":
            vote = _overlap_bottom_band_diagnostic(
                before,
                after,
                base_slots,
                before_y_offset_px=before_y_offset_px,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                row_step_px=row_step,
                moved_rows=row_moved_rows,
                refine_radius_px=refine_radius_px,
            )
            vote_key = "overlap_bottom_band"
            actual_move_source = "bottom_band_template_matching"
        else:
            vote = _overlap_digit_vote_diagnostic(
                before,
                after,
                base_slots,
                before_y_offset_px=before_y_offset_px,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                row_step_px=row_step,
                moved_rows=row_moved_rows,
                refine_radius_px=refine_radius_px,
                candidate_centers_px=(0,) if fixed_row_count else None,
            )
            vote_key = "overlap_digit_vote"
            actual_move_source = "digit_template_matching"
        if vote is None:
            return None
        min_dominant_count = min(4, int(vote["slot_count"]))
        min_mean_score = 0.55
        if source == "row_count_gray_line_template_move":
            min_dominant_count = min(3, int(vote["slot_count"]))
            min_mean_score = 0.05
        if source == "row_count_gray_bar_template_move":
            min_dominant_count = 1
            min_mean_score = 0.05
        if int(vote["dominant_count"]) < min_dominant_count or float(vote["dominant_mean_score"]) < min_mean_score:
            return None
        return {
            "source": source,
            "move_px": int(vote["dominant_move_px"]),
            "score": float(vote["dominant_mean_score"]),
            "expected_move_px": expected_move,
            "search_min_px": search_min,
            "search_max_px": search_max,
            vote_key: vote,
            "direct_delta_y_offset_px": int(vote["dominant_delta_y_offset_px"]),
            "direct_moved_rows": int(vote["moved_rows"]),
            "direct_overlap_rows": int(vote["overlap_rows"]),
            "direct_tail_scroll": False,
            "row_count_source": "cosine_feature_replay_moved_rows",
            "actual_move_source": actual_move_source,
            "template_candidate_centers_px": [0] if fixed_row_count else [-row_step, 0, row_step],
            "acceptance_min_dominant_count": min_dominant_count,
            "acceptance_min_mean_score": min_mean_score,
        }

    if source.startswith("digit_edge_ncc"):
        digit_before_pair = _inventory_digit_motion_edge_pair(before, grid_region, slots=before_slots)
        digit_after_pair = _inventory_digit_motion_edge_pair(after, grid_region, slots=before_slots)
        if digit_before_pair is None or digit_after_pair is None:
            return None
        digit_before, digit_before_mask = digit_before_pair
        digit_after, digit_after_mask = digit_after_pair
        curve = _motion_weighted_ncc_curve(
            digit_before,
            digit_after,
            digit_before_mask,
            digit_after_mask,
            expected_move_px=expected_move,
            search_min_px=search_min,
            search_max_px=search_max,
        )
        if not curve:
            return None
        if source == "digit_edge_ncc_best":
            candidate = max(curve, key=lambda item: float(item["score"]))
        elif source == "digit_edge_ncc_near_feature_best":
            actual = feature_motion.actual_move_px if feature_motion is not None else row.get("actual")
            candidate = _best_curve_row_near(
                curve,
                int(actual) if actual is not None else None,
                radius_px=refine_radius_px,
            )
        elif source == "digit_edge_ncc_near_row_boundary":
            moved_rows = row.get("moved_rows")
            row_boundary = int(row_step * int(moved_rows)) if moved_rows is not None and row_step > 0 else None
            candidate = _best_curve_row_near(curve, row_boundary, radius_px=refine_radius_px)
        else:
            raise ValueError(f"unknown best motion source: {source}")
        if candidate is None:
            return None
        return {
            "source": source,
            "move_px": int(candidate["move_px"]),
            "score": float(candidate["score"]),
            "expected_move_px": expected_move,
            "search_min_px": search_min,
            "search_max_px": min(digit_before.shape[0] - 8, search_max),
        }

    edge_before = _inventory_motion_edge_array(before, grid_region, slots=before_slots)
    edge_after = _inventory_motion_edge_array(after, grid_region, slots=before_slots)
    if edge_before is None or edge_after is None:
        return None
    curve = _motion_ncc_curve(
        edge_before,
        edge_after,
        expected_move_px=expected_move,
        search_min_px=search_min,
        search_max_px=search_max,
    )
    if not curve:
        return None

    candidate: dict | None
    if source == "edge_ncc_best":
        candidate = max(curve, key=lambda item: float(item["score"]))
    elif source == "edge_ncc_near_feature_best":
        actual = feature_motion.actual_move_px if feature_motion is not None else row.get("actual")
        candidate = _best_curve_row_near(
            curve,
            int(actual) if actual is not None else None,
            radius_px=refine_radius_px,
        )
    elif source == "edge_ncc_near_row_boundary":
        moved_rows = row.get("moved_rows")
        row_boundary = int(row_step * int(moved_rows)) if moved_rows is not None and row_step > 0 else None
        candidate = _best_curve_row_near(curve, row_boundary, radius_px=refine_radius_px)
    else:
        raise ValueError(f"unknown best motion source: {source}")
    if candidate is None:
        return None
    return {
        "source": source,
        "move_px": int(candidate["move_px"]),
        "score": float(candidate["score"]),
        "expected_move_px": expected_move,
        "search_min_px": search_min,
        "search_max_px": min(edge_before.shape[0] - 8, search_max),
    }


def _save_previous_overlap_row_layers(
    output_dir: Path,
    before: Image.Image,
    *,
    scroll: int,
    source_slug: str,
    base_slots: list[dict],
    before_y_offset_px: int,
    after_y_offset_px: int,
    grid_cols: int,
    moved_rows: int | None,
    overlap_rows: int,
    opacity: int = 45,
) -> list[dict]:
    if moved_rows is None or grid_cols <= 0 or overlap_rows <= 0:
        return []
    before_slots = _shift_slots_y(base_slots, before_y_offset_px, before.size) if before_y_offset_px else base_slots
    after_slots = _shift_slots_y(base_slots, after_y_offset_px, before.size) if after_y_offset_px else base_slots
    layer_dir = output_dir / "overlap_digit_vote_layers" / f"scroll_{scroll:02d}"
    layer_dir.mkdir(parents=True, exist_ok=True)
    layers: list[dict] = []
    for overlap_row in range(overlap_rows):
        before_start = (int(moved_rows) + overlap_row) * grid_cols
        after_start = overlap_row * grid_cols
        before_regions = [
            before_slots[idx]
            for idx in range(before_start, min(before_start + grid_cols, len(before_slots)))
        ]
        after_regions = [
            after_slots[idx]
            for idx in range(after_start, min(after_start + grid_cols, len(after_slots)))
        ]
        before_region = _union_regions(before_regions)
        after_region = _union_regions(after_regions)
        if before_region is None or after_region is None:
            continue
        bx1, by1, bx2, by2 = _pixel_box_for_region(before_region, before.size)
        ax1, ay1, ax2, ay2 = _pixel_box_for_region(after_region, before.size)
        if bx2 <= bx1 or by2 <= by1 or ax2 <= ax1 or ay2 <= ay1:
            continue
        crop = before.crop((bx1, by1, bx2, by2)).convert("RGBA")
        crop_path = layer_dir / f"scroll_{scroll:02d}_previous_overlap_row_{overlap_row + 1:02d}.png"
        crop.save(crop_path)
        layers.append(
            {
                "name": f"{source_slug}_previous_overlap_row_{overlap_row + 1:02d}_before_slots_{before_start + 1:02d}_{min(before_start + grid_cols, len(before_slots)):02d}",
                "kind": "image",
                "path": str(crop_path.resolve()),
                "x": ax1,
                "y": ay1,
                "width": max(1, ax2 - ax1),
                "height": max(1, ay2 - ay1),
                "opacity": max(0, min(100, int(opacity))),
                "visible": True,
            }
        )
    return layers


def _save_overlap_gray_bar_layers(
    output_dir: Path,
    before: Image.Image,
    *,
    scroll: int,
    source_slug: str,
    choice: dict,
    opacity: int = 78,
) -> list[dict]:
    gray_bar = choice.get("overlap_gray_bar") if isinstance(choice, dict) else None
    if not isinstance(gray_bar, dict):
        return []
    layers: list[dict] = []
    layer_dir = output_dir / "overlap_gray_bar_layers" / f"scroll_{scroll:02d}"
    layer_dir.mkdir(parents=True, exist_ok=True)
    for pair_index, pair in enumerate(gray_bar.get("selected_pairs") or []):
        before_box = pair.get("before_box")
        after_box = pair.get("after_box")
        if not before_box or not after_box or len(before_box) != 4 or len(after_box) != 4:
            continue
        bx1, by1, bx2, by2 = [int(round(float(value))) for value in before_box]
        ax1, ay1, ax2, ay2 = [int(round(float(value))) for value in after_box]
        if bx2 <= bx1 or by2 <= by1 or ax2 <= ax1 or ay2 <= ay1:
            continue
        delta = int(pair.get("delta_y_offset_px") or 0)
        score = float(pair.get("score") or 0.0)
        layer_path = layer_dir / f"scroll_{scroll:02d}_pair_{pair_index:02d}_before_gray_bar_delta_{delta:+d}.png"
        if not _save_target_gray_mask_layer_image(before, (bx1, by1, bx2, by2), layer_path):
            continue
        layers.append(
            {
                "name": f"{source_slug}_before_gray_bar_pair_{pair_index:02d}_dy_{delta:+d}_score_{score:.3f}",
                "kind": "image",
                "path": str(layer_path.resolve()),
                "x": ax1,
                "y": ay1,
                "width": max(1, ax2 - ax1),
                "height": max(1, ay2 - ay1),
                "opacity": max(0, min(100, int(opacity))),
                "visible": True,
            }
        )
    return layers


def _save_overlap_gray_line_layers(
    output_dir: Path,
    before: Image.Image,
    *,
    scroll: int,
    source_slug: str,
    choice: dict,
    opacity: int = 72,
) -> list[dict]:
    gray_line = choice.get("overlap_gray_line") if isinstance(choice, dict) else None
    if not isinstance(gray_line, dict):
        return []
    layers: list[dict] = []
    layer_dir = output_dir / "overlap_gray_line_layers" / f"scroll_{scroll:02d}"
    layer_dir.mkdir(parents=True, exist_ok=True)
    for slot_vote in gray_line.get("votes") or []:
        before_box = slot_vote.get("before_box")
        after_box = slot_vote.get("best_after_box")
        if not before_box or not after_box or len(before_box) != 4 or len(after_box) != 4:
            continue
        bx1, by1, bx2, by2 = [int(round(float(value))) for value in before_box]
        ax1, ay1, ax2, ay2 = [int(round(float(value))) for value in after_box]
        if bx2 <= bx1 or by2 <= by1 or ax2 <= ax1 or ay2 <= ay1:
            continue
        column = int(slot_vote.get("column") or 0)
        delta = int(slot_vote.get("best_delta_y_offset_px") or 0)
        score = float(slot_vote.get("best_score") or 0.0)
        layer_path = layer_dir / f"scroll_{scroll:02d}_col_{column}_before_gray_line_mask_delta_{delta:+d}.png"
        if not _save_gray_mask_layer_image(before, (bx1, by1, bx2, by2), layer_path):
            continue
        layers.append(
            {
                "name": f"{source_slug}_before_gray_line_col_{column}_dy_{delta:+d}_score_{score:.3f}",
                "kind": "image",
                "path": str(layer_path.resolve()),
                "x": ax1,
                "y": ay1,
                "width": max(1, ax2 - ax1),
                "height": max(1, ay2 - ay1),
                "opacity": max(0, min(100, int(opacity))),
                "visible": True,
            }
        )
    return layers


def _save_overlap_bottom_band_layers(
    output_dir: Path,
    before: Image.Image,
    *,
    scroll: int,
    source_slug: str,
    choice: dict,
    opacity: int = 60,
) -> list[dict]:
    band = choice.get("overlap_bottom_band") if isinstance(choice, dict) else None
    if not isinstance(band, dict):
        return []
    layers: list[dict] = []
    layer_dir = output_dir / "overlap_bottom_band_layers" / f"scroll_{scroll:02d}"
    layer_dir.mkdir(parents=True, exist_ok=True)
    for slot_vote in band.get("votes") or []:
        before_box = slot_vote.get("before_box")
        after_box = slot_vote.get("best_after_box")
        if not before_box or not after_box or len(before_box) != 4 or len(after_box) != 4:
            continue
        bx1, by1, bx2, by2 = [int(round(float(value))) for value in before_box]
        ax1, ay1, ax2, ay2 = [int(round(float(value))) for value in after_box]
        if bx2 <= bx1 or by2 <= by1 or ax2 <= ax1 or ay2 <= ay1:
            continue
        crop = before.crop((bx1, by1, bx2, by2)).convert("RGBA")
        column = int(slot_vote.get("column") or 0)
        delta = int(slot_vote.get("best_delta_y_offset_px") or 0)
        score = float(slot_vote.get("best_score") or 0.0)
        crop_path = layer_dir / f"scroll_{scroll:02d}_col_{column}_before_bottom_band_delta_{delta:+d}.png"
        crop.save(crop_path)
        layers.append(
            {
                "name": f"{source_slug}_before_bottom_band_col_{column}_dy_{delta:+d}_score_{score:.3f}",
                "kind": "image",
                "path": str(crop_path.resolve()),
                "x": ax1,
                "y": ay1,
                "width": max(1, ax2 - ax1),
                "height": max(1, ay2 - ay1),
                "opacity": max(0, min(100, int(opacity))),
                "visible": True,
            }
        )
    return layers


def _save_overlap_digit_vote_layers(
    output_dir: Path,
    before: Image.Image,
    *,
    scroll: int,
    source_slug: str,
    choice: dict,
    opacity: int = 65,
) -> list[dict]:
    vote = choice.get("overlap_digit_vote") if isinstance(choice, dict) else None
    if not isinstance(vote, dict):
        return []
    layers: list[dict] = []
    layer_dir = output_dir / "overlap_digit_vote_layers" / f"scroll_{scroll:02d}"
    layer_dir.mkdir(parents=True, exist_ok=True)
    for slot_vote in vote.get("votes") or []:
        before_box = slot_vote.get("before_box")
        after_box = slot_vote.get("best_after_box")
        if not before_box or not after_box or len(before_box) != 4 or len(after_box) != 4:
            continue
        bx1, by1, bx2, by2 = [int(round(float(value))) for value in before_box]
        ax1, ay1, ax2, ay2 = [int(round(float(value))) for value in after_box]
        if bx2 <= bx1 or by2 <= by1 or ax2 <= ax1 or ay2 <= ay1:
            continue
        crop = before.crop((bx1, by1, bx2, by2)).convert("RGBA")
        column = int(slot_vote.get("column") or 0)
        delta = int(slot_vote.get("best_delta_y_offset_px") or 0)
        score = float(slot_vote.get("best_score") or 0.0)
        crop_path = layer_dir / f"scroll_{scroll:02d}_col_{column}_before_digit_delta_{delta:+d}.png"
        crop.save(crop_path)
        layers.append(
            {
                "name": f"{source_slug}_before_digit_col_{column}_dy_{delta:+d}_score_{score:.3f}",
                "kind": "image",
                "path": str(crop_path.resolve()),
                "x": ax1,
                "y": ay1,
                "width": max(1, ax2 - ax1),
                "height": max(1, ay2 - ay1),
                "opacity": max(0, min(100, int(opacity))),
                "visible": True,
            }
        )
    return layers


def export_best_studio_projects(
    folder: Path,
    section: str,
    rows: list[dict],
    output_dir: Path,
    *,
    source: str = "edge_ncc_best",
    refine_radius_px: int = 4,
) -> list[Path]:
    base_slots = _load_slots(section)
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    index_rows: list[dict] = []
    source_slug = source.strip().lower()
    for old_project in output_dir.glob(f"scroll_*_after_{source_slug}_*px_feedback_alignment.json"):
        old_project.unlink(missing_ok=True)
    old_index = output_dir / f"index_{source_slug}_feedback.json"
    old_index.unlink(missing_ok=True)
    if source_slug in {"overlap_digit_vote", "row_count_digit_template_move"}:
        shutil.rmtree(output_dir / "overlap_digit_vote_layers", ignore_errors=True)
    if source_slug == "row_count_bottom_band_template_move":
        shutil.rmtree(output_dir / "overlap_bottom_band_layers", ignore_errors=True)
    if source_slug == "row_count_gray_line_template_move":
        shutil.rmtree(output_dir / "overlap_gray_line_layers", ignore_errors=True)
    if source_slug == "row_count_gray_bar_template_move":
        shutil.rmtree(output_dir / "overlap_gray_bar_layers", ignore_errors=True)
    feedback_y_offset = 0

    for row in rows:
        scroll = int(row["scroll"])
        before_path = Path(row["before_capture"])
        after_path = Path(row["after_capture"])
        before = Image.open(before_path)
        after = Image.open(after_path)
        replay_before_y = int(row.get("before_y_offset") or 0)
        replay_after_y = int(row.get("after_y_offset") or 0)
        before_y = int(feedback_y_offset)
        before_slots = _shift_slots_y(base_slots, before_y, before.size) if before_y else base_slots
        grid_region = _grid_region(before_slots)
        grid_cols = int(row.get("grid_cols") or 5)
        grid_rows = int(row.get("grid_rows") or max(1, (len(base_slots) + grid_cols - 1) // max(1, grid_cols)))
        row_step = int(row.get("row_step") or _slot_row_step_px(before_slots, before.size, grid_cols) or 0)

        choice = _motion_choice_for_studio(
            row,
            before,
            after,
            grid_region,
            base_slots=base_slots,
            before_slots=before_slots,
            before_y_offset_px=before_y,
            grid_cols=grid_cols,
            row_step=row_step,
            grid_rows=grid_rows,
            source=source_slug,
            refine_radius_px=refine_radius_px,
        )
        if choice is None:
            index_rows.append(
                {
                    "scroll": scroll,
                    "section": section,
                    "source": source_slug,
                    "feedback_loop": True,
                    "error": "motion_choice_failed",
                    "feedback_before_y_offset": before_y,
                    "reference_replay_before_y_offset": replay_before_y,
                    "reference_replay_after_y_offset": replay_after_y,
                    "after_capture": str(after_path),
                }
            )
            continue

        move_px = int(choice["move_px"])
        expected_move = int(choice["expected_move_px"])
        direct_delta = choice.get("direct_delta_y_offset_px")
        if direct_delta is not None:
            delta_y = int(direct_delta)
            moved_rows = int(choice.get("direct_moved_rows") or row.get("moved_rows") or max(1, grid_rows - 1))
            overlap_rows = int(choice.get("direct_overlap_rows") or max(0, grid_rows - moved_rows))
            tail_scroll = bool(choice.get("direct_tail_scroll", False))
        else:
            motion = InventoryMotionEstimate(
                expected_step_px=expected_move,
                actual_move_px=move_px,
                y_offset_px=expected_move - move_px,
                score=float(choice["score"] or 0.0),
                search_min_px=int(choice["search_min_px"]),
                search_max_px=int(choice["search_max_px"]),
                method=f"studio_feedback_{source_slug}",
            )
            overlap = _inventory_overlap_rows_from_motion(motion, row_step, grid_rows)
            if overlap is None:
                overlap_rows, moved_rows, delta_y, tail_scroll = 0, None, 0, False
            else:
                overlap_rows, moved_rows, delta_y, tail_scroll = overlap
        corrected_y = before_y + int(delta_y)
        feedback_y_offset = corrected_y
        corrected_slots = _shift_slots_y(base_slots, corrected_y, after.size) if corrected_y else base_slots
        scan_indices = _new_inventory_slot_indices(len(base_slots), grid_cols, grid_rows, overlap_rows)
        scan_range, scan_count = _scan_range(scan_indices, len(base_slots))
        row_boundary_move = int(row_step * int(moved_rows)) if moved_rows is not None and row_step > 0 else None

        rois = _studio_rois_for_capture(
            image_size=after.size,
            slots=corrected_slots,
            grid_cols=grid_cols,
            scan_indices=scan_indices,
            include_digits=True,
            prefix=f"scroll_{scroll:02d}_after_{source_slug}",
        )
        if source_slug == "row_count_gray_bar_template_move" and rois:
            rois[0] = _region_to_roi(
                f"scroll_{scroll:02d}_after_{source_slug}_grid",
                _gray_bar_scan_region(corrected_slots, after.size),
                after.size,
            )
        previous_overlap_rois = _previous_overlap_row_rois(
            image_size=after.size,
            slots=corrected_slots,
            grid_cols=grid_cols,
            moved_rows=moved_rows,
            overlap_rows=overlap_rows,
            prefix=f"scroll_{scroll:02d}_previous_overlap",
            include_digits=True,
        )
        bottom_band_rois = []
        if source_slug in {"row_count_bottom_band_template_move", "row_count_gray_line_template_move"}:
            bottom_band_rois = _overlap_bottom_band_rois(
                image_size=after.size,
                slots=corrected_slots,
                grid_cols=grid_cols,
                moved_rows=moved_rows,
                overlap_rows=overlap_rows,
                prefix=f"scroll_{scroll:02d}_bottom_band",
            )
        gray_bar_rois = []
        if source_slug == "row_count_gray_bar_template_move":
            gray_bar = choice.get("overlap_gray_bar") if isinstance(choice, dict) else None
            if isinstance(gray_bar, dict):
                for pair_index, pair in enumerate(gray_bar.get("selected_pairs") or []):
                    after_box = pair.get("after_box")
                    if after_box and len(after_box) == 4:
                        gray_bar_rois.append(
                            _gray_bar_roi_from_box(
                                f"scroll_{scroll:02d}_gray_bar_pair_{pair_index:02d}_after",
                                tuple(int(round(float(value))) for value in after_box),
                                enabled=True,
                            )
                        )
        rois.extend(previous_overlap_rois)
        rois.extend(bottom_band_rois)
        rois.extend(gray_bar_rois)
        overlay_layers = _save_previous_overlap_row_layers(
            output_dir,
            before,
            scroll=scroll,
            source_slug=source_slug,
            base_slots=base_slots,
            before_y_offset_px=before_y,
            after_y_offset_px=corrected_y,
            grid_cols=grid_cols,
            moved_rows=moved_rows,
            overlap_rows=overlap_rows,
        )
        if source_slug in {"overlap_digit_vote", "row_count_digit_template_move"}:
            overlay_layers.extend(
                _save_overlap_digit_vote_layers(
                    output_dir,
                    before,
                    scroll=scroll,
                    source_slug=source_slug,
                    choice=choice,
                )
            )
        if source_slug == "row_count_bottom_band_template_move":
            overlay_layers.extend(
                _save_overlap_bottom_band_layers(
                    output_dir,
                    before,
                    scroll=scroll,
                    source_slug=source_slug,
                    choice=choice,
                )
            )
        if source_slug == "row_count_gray_line_template_move":
            overlay_layers.extend(
                _save_overlap_gray_line_layers(
                    output_dir,
                    before,
                    scroll=scroll,
                    source_slug=source_slug,
                    choice=choice,
                )
            )
        if source_slug == "row_count_gray_bar_template_move":
            overlay_layers.extend(
                _save_overlap_gray_bar_layers(
                    output_dir,
                    before,
                    scroll=scroll,
                    source_slug=source_slug,
                    choice=choice,
                )
            )

        metadata = {
            "source_folder": str(folder.resolve()),
            "section": section,
            "scroll": scroll,
            "phase": "after_best_corrected_feedback",
            "feedback_loop": True,
            "best_motion_source": source_slug,
            "best_move_px": move_px,
            "best_score": choice.get("score"),
            "expected_move_px": expected_move,
            "row_step": row_step,
            "row_boundary_move_px": row_boundary_move,
            "best_delta_from_row_boundary_px": move_px - row_boundary_move if row_boundary_move is not None else None,
            "row_count_source": choice.get("row_count_source"),
            "actual_move_source": choice.get("actual_move_source"),
            "template_candidate_centers_px": choice.get("template_candidate_centers_px"),
            "gray_bar_scan_roi_px": [1150, 8] if source_slug == "row_count_gray_bar_template_move" else None,
            "gray_bar_target_rgb": "#c4cfd4" if source_slug == "row_count_gray_bar_template_move" else None,
            "gray_bar_target_tolerance": 14 if source_slug == "row_count_gray_bar_template_move" else None,
            "gray_bar_scan_grid_target_height_px": _gray_band_target_height_px(base_slots) if source_slug == "row_count_gray_bar_template_move" else None,
            "acceptance_min_dominant_count": choice.get("acceptance_min_dominant_count"),
            "acceptance_min_mean_score": choice.get("acceptance_min_mean_score"),
            "feedback_before_y_offset": before_y,
            "feedback_delta_y_offset": delta_y,
            "feedback_after_y_offset": corrected_y,
            "moved_rows": moved_rows,
            "overlap_rows": overlap_rows,
            "tail_scroll": tail_scroll,
            "scan_range": scan_range,
            "scan_count": scan_count,
            "reference_replay_actual": row.get("actual"),
            "reference_replay_before_y_offset": replay_before_y,
            "reference_replay_after_y_offset": replay_after_y,
            "reference_replay_delta_y_offset": row.get("delta_y_offset"),
            "previous_overlap_roi_count": len(previous_overlap_rois),
            "bottom_band_roi_count": len(bottom_band_rois),
            "gray_bar_roi_count": len(gray_bar_rois),
            "previous_overlap_layer_count": len([layer for layer in overlay_layers if "previous_overlap_row" in str(layer.get("name", ""))]),
            "bottom_band_layer_count": len([layer for layer in overlay_layers if "before_bottom_band_col" in str(layer.get("name", ""))]),
            "gray_line_layer_count": len([layer for layer in overlay_layers if "before_gray_line_col" in str(layer.get("name", ""))]),
            "gray_bar_layer_count": len([layer for layer in overlay_layers if "before_gray_bar_pair" in str(layer.get("name", ""))]),
            "overlap_digit_vote_layer_count": len(overlay_layers),
            "overlap_digit_vote_layers": overlay_layers,
        }
        project = output_dir / f"scroll_{scroll:02d}_after_{source_slug}_{move_px}px_feedback_alignment.json"
        _write_studio_project(project, after_path, rois, metadata=metadata, layers=overlay_layers)
        written.append(project)
        index_rows.append({**metadata, "project": str(project), "after_capture": str(after_path)})

    index_path = output_dir / f"index_{source_slug}_feedback.json"
    _write_json(
        index_path,
        {
            "folder": str(folder.resolve()),
            "section": section,
            "source": source_slug,
            "feedback_loop": True,
            "projects": index_rows,
        },
    )
    written.append(index_path)
    return written


def export_gray_band_layout_studio_projects(
    folder: Path,
    section: str,
    rows: list[dict],
    output_dir: Path,
) -> list[Path]:
    base_slots = _load_slots(section)
    output_dir.mkdir(parents=True, exist_ok=True)
    for old_project in output_dir.glob("scroll_*_after_gray_band_layout_alignment.json"):
        old_project.unlink(missing_ok=True)
    old_index = output_dir / "index_gray_band_layout.json"
    old_index.unlink(missing_ok=True)

    written: list[Path] = []
    index_rows: list[dict] = []
    for row in rows:
        scroll = int(row["scroll"])
        after_path = Path(row["after_capture"])
        after = Image.open(after_path)
        grid_cols = int(row.get("grid_cols") or 5)
        grid_rows = int(row.get("grid_rows") or max(1, (len(base_slots) + grid_cols - 1) // max(1, grid_cols)))
        row_step = int(row.get("row_step") or _slot_row_step_px(base_slots, after.size, grid_cols) or 0)
        layout = _gray_band_layout_for_image(
            after,
            base_slots,
            grid_cols=grid_cols,
            grid_rows=grid_rows,
            row_step_px=row_step,
        )
        if layout is None:
            index_rows.append(
                {
                    "scroll": scroll,
                    "section": section,
                    "source": "gray_band_layout",
                    "error": "gray_band_layout_failed",
                    "after_capture": str(after_path),
                    "row_step": row_step,
                }
            )
            continue

        rois = _studio_rois_for_capture(
            image_size=after.size,
            slots=layout["slots"],
            grid_cols=grid_cols,
            scan_indices=None,
            include_digits=True,
            prefix=f"scroll_{scroll:02d}_after_gray_band_layout",
        )
        if rois:
            rois[0] = _region_to_roi(
                f"scroll_{scroll:02d}_after_gray_band_layout_scan_region",
                layout["scan_region"],
                after.size,
            )
        selected_ids = {id(band) for band in layout["selected_bands"]}
        for band_index, band in enumerate(layout["selected_bands"]):
            rois.append(
                _gray_bar_roi_from_box(
                    f"scroll_{scroll:02d}_gray_band_layout_selected_band_{band_index:02d}_score_{float(band['strength']):.3f}",
                    (
                        int(band["x1_px"]),
                        int(band["y1_px"]),
                        int(band["x2_px"]),
                        int(band["y2_px"]),
                    ),
                    enabled=True,
                )
            )
        candidate_index = 0
        for band in layout["bars"][:16]:
            if id(band) in selected_ids:
                continue
            rois.append(
                _gray_bar_roi_from_box(
                    f"scroll_{scroll:02d}_gray_band_layout_candidate_{candidate_index:02d}_score_{float(band['strength']):.3f}",
                    (
                        int(band["x1_px"]),
                        int(band["y1_px"]),
                        int(band["x2_px"]),
                        int(band["y2_px"]),
                    ),
                    enabled=False,
                )
            )
            candidate_index += 1

        metadata = {
            "source_folder": str(folder.resolve()),
            "section": section,
            "scroll": scroll,
            "phase": "after_gray_band_layout",
            "source": "gray_band_layout",
            "row_step": row_step,
            "grid_cols": grid_cols,
            "grid_rows": grid_rows,
            "gray_bar_scan_roi_px": [1150, 8],
            "gray_bar_target_rgb": "#c4cfd4",
            "gray_bar_target_tolerance": 14,
            "gray_bar_scan_grid_target_height_px": _gray_band_target_height_px(base_slots),
            "selected_band_count": len(layout["selected_bands"]),
            "candidate_band_count": len(layout["bars"]),
            "selected_score": layout["selected_score"],
            "selected_mean_strength": layout["selected_mean_strength"],
            "selected_spacing_score": layout["selected_spacing_score"],
            "selected_band_y_centers_px": [float(band["y_center_px"]) for band in layout["selected_bands"]],
            "row_centers_px": [float(value) for value in layout["row_centers_px"]],
            "tail_page_detected": bool(layout.get("tail_page_detected")),
            "tail_signature": layout.get("tail_signature"),
            "tail_last_row_top_px": layout.get("tail_last_row_top_px"),
            "method": "detect_target_gray_bands_then_place_slot_rows_between_adjacent_bands",
        }
        project = output_dir / f"scroll_{scroll:02d}_after_gray_band_layout_alignment.json"
        _write_studio_project(project, after_path, rois, metadata=metadata)
        written.append(project)
        index_rows.append({**metadata, "project": str(project), "after_capture": str(after_path)})

    index_path = output_dir / "index_gray_band_layout.json"
    _write_json(
        index_path,
        {
            "folder": str(folder.resolve()),
            "section": section,
            "source": "gray_band_layout",
            "projects": index_rows,
        },
    )
    written.append(index_path)
    return written



def export_studio_projects(folder: Path, section: str, rows: list[dict], output_dir: Path) -> list[Path]:
    base_slots = _load_slots(section)
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    index_rows: list[dict] = []

    for row in rows:
        scroll = int(row["scroll"])
        before_path = Path(row["before_capture"])
        after_path = Path(row["after_capture"])
        before = Image.open(before_path)
        after = Image.open(after_path)
        before_slots = _shift_slots_y(base_slots, int(row["before_y_offset"]), before.size) if row["before_y_offset"] else base_slots
        after_slots = _shift_slots_y(base_slots, int(row["after_y_offset"]), after.size) if row["after_y_offset"] else base_slots
        scan_indices = set(row["scan_indices"]) if row["scan_indices"] is not None else None

        before_rois = _studio_rois_for_capture(
            image_size=before.size,
            slots=before_slots,
            grid_cols=5,
            scan_indices=None,
            include_digits=False,
            prefix=f"scroll_{scroll:02d}_before",
        )
        after_rois = _studio_rois_for_capture(
            image_size=after.size,
            slots=after_slots,
            grid_cols=5,
            scan_indices=scan_indices,
            include_digits=True,
            prefix=f"scroll_{scroll:02d}_after",
        )
        metadata = {
            "source_folder": str(folder.resolve()),
            "section": section,
            "scroll": scroll,
            "amount": row["amount"],
            "actual": row["actual"],
            "row_step": row["row_step"],
            "moved_rows": row["moved_rows"],
            "overlap_rows": row["overlap_rows"],
            "tail_scroll": row["tail_scroll"],
            "scan_range": row["scan_range"],
        }

        before_project = output_dir / f"scroll_{scroll:02d}_before_alignment.json"
        after_project = output_dir / f"scroll_{scroll:02d}_after_alignment.json"
        _write_studio_project(before_project, before_path, before_rois, metadata={**metadata, "phase": "before"})
        _write_studio_project(after_project, after_path, after_rois, metadata={**metadata, "phase": "after"})
        written.extend([before_project, after_project])
        index_rows.append({**metadata, "before_project": str(before_project), "after_project": str(after_project)})

    index_path = output_dir / "index.json"
    _write_json(index_path, {"folder": str(folder.resolve()), "section": section, "projects": index_rows})
    written.append(index_path)
    return written


def print_table(rows: list[dict]) -> None:
    if not rows:
        print("no scroll summaries found")
        return
    header = (
        "scroll amount actual row_step moved overlap tail y_before y_delta y_after "
        "score observed calibrated scan"
    )
    print(header)
    print("-" * len(header))
    for row in rows:
        score = "" if row["score"] is None else f"{row['score']:.3f}"
        observed = "" if row["observed_row_step"] is None else f"{row['observed_row_step']:.2f}"
        calibrated = "" if row["calibrated_row_step"] is None else f"{row['calibrated_row_step']:.2f}"
        actual = "" if row["actual"] is None else str(row["actual"])
        moved = "" if row["moved_rows"] is None else str(row["moved_rows"])
        print(
            f"{row['scroll']:>6} {row['amount']:>6} {actual:>6} {row['row_step']:>8} "
            f"{moved:>5} {row['overlap_rows']:>7} {str(row['tail_scroll']):>4} "
            f"{row['before_y_offset']:>8} {row['delta_y_offset']:>7} {row['after_y_offset']:>7} "
            f"{score:>5} {observed:>8} {calibrated:>10} "
            f"{row['scan_range']} ({row['scan_count']})"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Replay saved inventory scroll debug captures through the current motion logic."
    )
    parser.add_argument("folder", type=Path, help="debug/inventory_scroll_scan/... folder")
    parser.add_argument("--section", choices=("item", "equipment"), default="item")
    parser.add_argument("--json", action="store_true", help="print JSON instead of a table")
    parser.add_argument(
        "--export-studio-projects",
        action="store_true",
        help="write Template Alignment Studio JSON projects for before/after captures",
    )
    parser.add_argument(
        "--studio-output-dir",
        type=Path,
        default=None,
        help="output directory for --export-studio-projects; defaults to <folder>/studio_projects",
    )
    parser.add_argument(
        "--export-best-studio-projects",
        action="store_true",
        help="write after-capture Studio projects whose ROIs are corrected by a selected best motion estimate",
    )
    parser.add_argument(
        "--export-gray-band-layout-studio-projects",
        action="store_true",
        help="write after-capture Studio projects whose slot rows are rebuilt from detected target gray bands",
    )
    parser.add_argument(
        "--gray-band-layout-output-dir",
        type=Path,
        default=None,
        help="output directory for --export-gray-band-layout-studio-projects; defaults to <folder>/gray_band_layout_studio_projects",
    )
    parser.add_argument(
        "--best-studio-output-dir",
        type=Path,
        default=None,
        help="output directory for --export-best-studio-projects; defaults to <folder>/best_studio_projects",
    )
    parser.add_argument(
        "--best-motion-source",
        choices=(
            "edge_ncc_best",
            "feature_best",
            "edge_ncc_near_feature_best",
            "edge_ncc_near_row_boundary",
            "digit_edge_ncc_best",
            "digit_edge_ncc_near_feature_best",
            "digit_edge_ncc_near_row_boundary",
            "overlap_digit_vote",
            "row_count_digit_template_move",
            "row_count_bottom_band_template_move",
            "row_count_gray_line_template_move",
            "row_count_gray_bar_template_move",
        ),
        default="edge_ncc_best",
        help="motion estimate used to correct ROIs in --export-best-studio-projects",
    )
    parser.add_argument(
        "--export-motion-diagnostics",
        action="store_true",
        help="write per-scroll motion score curves, top candidates, and visual alignment overlays",
    )
    parser.add_argument(
        "--motion-output-dir",
        type=Path,
        default=None,
        help="output directory for --export-motion-diagnostics; defaults to <folder>/motion_diagnostics",
    )
    parser.add_argument(
        "--motion-top-n",
        type=int,
        default=8,
        help="number of separated top motion candidates to record",
    )
    parser.add_argument(
        "--motion-refine-radius",
        type=int,
        default=4,
        help="edge-NCC local refinement radius around feature/boundary candidates in pixels",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    folder = args.folder
    if not folder.is_absolute():
        folder = ROOT / folder
    rows = replay_scroll_folder(folder, args.section)
    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    else:
        print_table(rows)
    if args.export_studio_projects:
        output_dir = args.studio_output_dir
        if output_dir is None:
            output_dir = folder / "studio_projects"
        elif not output_dir.is_absolute():
            output_dir = ROOT / output_dir
        written = export_studio_projects(folder, args.section, rows, output_dir)
        print(f"wrote {len(written)} studio files to {output_dir}")
    if args.export_best_studio_projects:
        best_output_dir = args.best_studio_output_dir
        if best_output_dir is None:
            best_output_dir = folder / "best_studio_projects"
        elif not best_output_dir.is_absolute():
            best_output_dir = ROOT / best_output_dir
        written = export_best_studio_projects(
            folder,
            args.section,
            rows,
            best_output_dir,
            source=args.best_motion_source,
            refine_radius_px=max(0, args.motion_refine_radius),
        )
        print(f"wrote {len(written)} best-corrected studio files to {best_output_dir}")
    if args.export_gray_band_layout_studio_projects:
        gray_band_output_dir = args.gray_band_layout_output_dir
        if gray_band_output_dir is None:
            gray_band_output_dir = folder / "gray_band_layout_studio_projects"
        elif not gray_band_output_dir.is_absolute():
            gray_band_output_dir = ROOT / gray_band_output_dir
        written = export_gray_band_layout_studio_projects(
            folder,
            args.section,
            rows,
            gray_band_output_dir,
        )
        print(f"wrote {len(written)} gray-band layout studio files to {gray_band_output_dir}")
    if args.export_motion_diagnostics:
        motion_output_dir = args.motion_output_dir
        if motion_output_dir is None:
            motion_output_dir = folder / "motion_diagnostics"
        elif not motion_output_dir.is_absolute():
            motion_output_dir = ROOT / motion_output_dir
        written = export_motion_diagnostics(
            folder,
            args.section,
            rows,
            motion_output_dir,
            top_n=max(1, args.motion_top_n),
            refine_radius_px=max(0, args.motion_refine_radius),
        )
        print(f"wrote {len(written)} motion diagnostic files to {motion_output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())