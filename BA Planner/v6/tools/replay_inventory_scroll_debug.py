from __future__ import annotations

import argparse
import contextlib
import json
import sys
from pathlib import Path
from typing import Iterable

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

with contextlib.redirect_stdout(sys.stderr):
    from core.inventory_slot_count_matcher import _digit_region  # noqa: E402
    from core.scanner import (  # noqa: E402
        _estimate_inventory_scroll_motion,
        _grid_region,
        _inventory_overlap_rows_from_motion,
        _new_inventory_slot_indices,
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


def _write_studio_project(path: Path, reference_path: Path, rois: Iterable[dict], *, metadata: dict) -> None:
    roi_rows = []
    for roi in rois:
        row = dict(roi)
        row["points"] = _roi_points(row)
        roi_rows.append(row)
    payload = {
        "reference_path": str(reference_path.resolve()),
        "layers": [],
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
        motion = _estimate_inventory_scroll_motion(
            before,
            after,
            grid_region,
            expected_move,
            search_margin_px=search_margin,
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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())