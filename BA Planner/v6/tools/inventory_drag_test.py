from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.capture import (
    capture_window_background,
    crop_region,
    find_target_hwnd,
    get_window_rect,
    set_target_window,
)
from core.config import REGIONS_DIR, load_config
from core.input import drag_scroll, ratio_to_client
from core.scanner import (
    _count_row_overlap,
    _estimate_inventory_scroll_motion,
    _grid_region,
    _img_hash,
    _new_inventory_slot_indices,
    _shift_slots_y,
    _slot_icon_region,
    _slot_row_step_px,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Test inventory grid drag ranges and save before/after ROI overlays."
    )
    parser.add_argument(
        "--section",
        choices=("item", "equipment"),
        default="item",
        help="inventory region file/section to use",
    )
    parser.add_argument("--from-slot", type=int, default=None, help="1-based start slot")
    parser.add_argument("--to-slot", type=int, default=None, help="1-based end slot")
    parser.add_argument(
        "--drag-scale",
        type=float,
        default=1.0,
        help="scale the start->end drag vector; default is one row for item tests",
    )
    parser.add_argument(
        "--delta-y",
        type=float,
        default=None,
        help="override vertical client-pixel delta from the start point; negative drags upward",
    )
    parser.add_argument(
        "--start-y-offset",
        type=float,
        default=0.0,
        help="client-pixel offset applied to the start point before dragging",
    )
    parser.add_argument(
        "--end-y-offset",
        type=float,
        default=0.0,
        help="client-pixel offset applied to the end point before scaling",
    )
    parser.add_argument("--duration", type=float, default=0.65, help="drag duration seconds")
    parser.add_argument("--end-hold", type=float, default=0.40, help="hold seconds before mouse up")
    parser.add_argument("--delay", type=float, default=0.35, help="delay after each drag")
    parser.add_argument("--repeat", type=int, default=1, help="number of drag attempts")
    parser.add_argument("--interval", type=float, default=0.6, help="seconds between repeated drags")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="directory for before/after captures and ROI overlays",
    )
    parser.add_argument(
        "--no-debug-capture",
        action="store_true",
        help="skip before/after screenshots and ROI overlays",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print resolved coordinates without moving the mouse",
    )
    return parser.parse_args()


def load_region_payload(section: str) -> dict:
    path = REGIONS_DIR / f"{section}_regions.json"
    with path.open("r", encoding="utf-8-sig") as handle:
        payload = json.load(handle)
    section_payload = payload[section]
    slots = section_payload["grid_slots"]
    if not isinstance(slots, list) or not slots:
        raise ValueError(f"no grid_slots in {path}")
    return section_payload


def load_slots(section: str) -> list[dict]:
    return load_region_payload(section)["grid_slots"]


def slot_center(slots: list[dict], slot_number: int) -> tuple[float, float]:
    if slot_number < 1 or slot_number > len(slots):
        raise ValueError(f"slot {slot_number} is outside 1..{len(slots)}")
    slot = slots[slot_number - 1]
    return float(slot["cx"]), float(slot["cy"])


def load_saved_target() -> tuple[int | None, str]:
    config = load_config()
    try:
        hwnd = int(config.get("target_hwnd") or 0)
    except (TypeError, ValueError):
        hwnd = 0
    title = str(config.get("target_title") or "")
    if hwnd:
        set_target_window(hwnd, title)
        return hwnd, title
    return None, ""


def resolve_drag_points(
    rect: tuple[int, int, int, int],
    start_rx: float,
    start_ry: float,
    end_rx: float,
    end_ry: float,
    args: argparse.Namespace,
) -> tuple[float, float, float, int, int, int, int]:
    width = max(1, rect[2])
    height = max(1, rect[3])
    start_cx, start_cy = ratio_to_client(rect, start_rx, start_ry)
    end_cx, end_cy = ratio_to_client(rect, end_rx, end_ry)

    start_cy = int(round(start_cy + args.start_y_offset))
    end_cy = int(round(end_cy + args.end_y_offset))
    if args.delta_y is not None:
        end_cy = int(round(start_cy + args.delta_y))
    else:
        end_cy = int(round(start_cy + ((end_cy - start_cy) * args.drag_scale)))

    start_cy = max(1, min(height - 1, start_cy))
    end_cy = max(1, min(height - 1, end_cy))
    rx = start_cx / width
    start_ry = start_cy / height
    resolved_end_ry = end_cy / height
    return rx, start_ry, resolved_end_ry, start_cx, start_cy, end_cx, end_cy


def _default_output_dir(section: str) -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return ROOT / "debug" / "inventory_drag_test" / f"{stamp}_{section}"


def capture_or_fail(hwnd: int) -> Image.Image:
    image = capture_window_background(hwnd, retry=2, normalize=True)
    if image is None:
        raise RuntimeError("failed to capture target window")
    return image.convert("RGB")


def _region_box(region: dict, size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = size
    return (
        int(round(float(region["x1"]) * width)),
        int(round(float(region["y1"]) * height)),
        int(round(float(region["x2"]) * width)),
        int(round(float(region["y2"]) * height)),
    )


def _slot_hashes(image: Image.Image, slots: list[dict]) -> list[str]:
    return [_img_hash(crop_region(image, _slot_icon_region(slot))) for slot in slots]


def _grid_shape(section_payload: dict, slot_count: int) -> tuple[int, int]:
    cols = int(section_payload.get("grid_cols", 0) or 0)
    rows = int(section_payload.get("grid_rows", 0) or 0)
    if cols <= 0:
        cols = 5 if slot_count % 5 == 0 else max(1, int(round(slot_count ** 0.5)))
    if rows <= 0:
        rows = max(1, (slot_count + cols - 1) // cols)
    return cols, rows


def _draw_label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill: str) -> None:
    x, y = xy
    draw.rectangle((x, y, x + max(28, len(text) * 7), y + 14), fill=(0, 0, 0, 170))
    draw.text((x + 2, y + 1), text, fill=fill)


def draw_roi_overlay(
    image: Image.Image,
    slots: list[dict],
    *,
    title: str,
    output_path: Path,
    scan_indices: set[int] | None = None,
    overlap_rows: int | None = None,
    grid_cols: int = 5,
    carried_rows: int = 0,
) -> None:
    canvas = image.convert("RGBA")
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    size = canvas.size

    grid_box = _region_box(_grid_region(slots), size)
    draw.rectangle(grid_box, outline=(255, 255, 255, 210), width=3)

    for idx, slot in enumerate(slots):
        slot_box = _region_box(slot, size)
        icon_box = _region_box(_slot_icon_region(slot), size)
        is_new = scan_indices is not None and idx in scan_indices
        color = (255, 76, 210, 235) if is_new else (80, 255, 120, 210)
        width = 4 if is_new else 2
        draw.rectangle(slot_box, outline=color, width=width)
        draw.rectangle(icon_box, outline=(60, 220, 255, 180), width=1)
        label = str(idx + 1)
        if carried_rows > 0 and idx < carried_rows * grid_cols:
            label = f"{idx + 1} old+"
        _draw_label(draw, (slot_box[0] + 3, slot_box[1] + 3), label, "white")

    header_lines = [title]
    if overlap_rows is not None:
        new_count = len(scan_indices) if scan_indices is not None else len(slots)
        header_lines.append(f"overlap_rows={overlap_rows} new_scan_slots={new_count}/{len(slots)}")
    header_lines.append("green=slot ROI, cyan=icon hash ROI, magenta=new scan window")
    header_h = 22 * len(header_lines) + 8
    draw.rectangle((8, 8, min(size[0] - 8, 760), 8 + header_h), fill=(0, 0, 0, 185))
    for i, line in enumerate(header_lines):
        draw.text((16, 14 + i * 22), line, fill=(255, 255, 255, 255))

    Image.alpha_composite(canvas, overlay).convert("RGB").save(output_path, quality=95)


def save_debug_captures(
    output_dir: Path,
    section: str,
    section_payload: dict,
    before: Image.Image,
    after: Image.Image | None,
    expected_move_px: int | None = None,
) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    slots = section_payload["grid_slots"]
    grid_cols, grid_rows = _grid_shape(section_payload, len(slots))
    before_hashes = _slot_hashes(before, slots)

    before_path = output_dir / "before_capture.png"
    before_overlay = output_dir / "before_roi_overlay.png"
    before.save(before_path, quality=95)
    draw_roi_overlay(
        before,
        slots,
        title=f"{section} before drag corrected ROI (y_offset=0px)",
        output_path=before_overlay,
        grid_cols=grid_cols,
    )

    summary = {
        "section": section,
        "grid_cols": grid_cols,
        "grid_rows": grid_rows,
        "slot_count": len(slots),
        "before_capture": str(before_path),
        "before_overlay": str(before_overlay),
    }
    if after is None:
        (output_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
        return summary

    row_step_px = _slot_row_step_px(slots, before.size, grid_cols)
    expected_motion_px = expected_move_px if expected_move_px is not None else row_step_px
    search_margin_px = max(50, row_step_px * max(1, grid_rows - 1)) if expected_move_px is not None else 50
    motion = _estimate_inventory_scroll_motion(
        before,
        after,
        _grid_region(slots),
        expected_motion_px,
        search_margin_px=search_margin_px,
    )
    moved_rows = None
    if motion is not None and row_step_px > 0:
        moved_rows = max(0, min(grid_rows, int(round(motion.actual_move_px / row_step_px))))
    y_offset_px = int(round((moved_rows * row_step_px) - motion.actual_move_px)) if motion is not None and moved_rows is not None else 0
    adjusted_after_slots = _shift_slots_y(slots, y_offset_px, after.size)
    after_hashes = _slot_hashes(after, adjusted_after_slots)
    overlap_source = "slot_hash"
    overlap_rows = _count_row_overlap(before_hashes, after_hashes, grid_cols)
    if moved_rows is not None:
        overlap_rows = max(0, min(grid_rows, grid_rows - moved_rows))
        overlap_source = "container_motion"
    scan_indices = _new_inventory_slot_indices(len(slots), grid_cols, grid_rows, overlap_rows)
    if scan_indices is None:
        scan_indices = set(range(len(slots)))

    after_path = output_dir / "after_capture.png"
    after_overlay = output_dir / "after_roi_overlay.png"
    after.save(after_path, quality=95)
    draw_roi_overlay(
        after,
        adjusted_after_slots,
        title=f"{section} after drag corrected ROI (y_offset={y_offset_px:+d}px)",
        output_path=after_overlay,
        scan_indices=scan_indices,
        overlap_rows=overlap_rows,
        grid_cols=grid_cols,
        carried_rows=overlap_rows,
    )

    motion_summary = None
    if motion is not None:
        motion_summary = {
            "expected_step_px": motion.expected_step_px,
            "actual_move_px": motion.actual_move_px,
            "expected_delta_px": motion.y_offset_px,
            "roi_y_offset_px": y_offset_px,
            "score": round(motion.score, 6),
            "search_min_px": motion.search_min_px,
            "search_max_px": motion.search_max_px,
        }

    summary.update(
        {
            "after_capture": str(after_path),
            "after_overlay": str(after_overlay),
            "movement_estimate": motion_summary,
            "row_step_px": row_step_px,
            "expected_motion_px": expected_motion_px,
            "after_y_offset_px": y_offset_px,
            "moved_rows": moved_rows,
            "overlap_source": overlap_source,
            "overlap_rows": overlap_rows,
            "new_scan_slot_indices_0_based": sorted(scan_indices),
            "new_scan_slot_numbers": [idx + 1 for idx in sorted(scan_indices)],
        }
    )
    (output_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    return summary


def main() -> int:
    args = parse_args()
    section_payload = load_region_payload(args.section)
    slots = section_payload["grid_slots"]
    if args.from_slot is None:
        args.from_slot = 21 if args.section == "equipment" else 16
    if args.to_slot is None:
        args.to_slot = 1 if args.section == "item" else max(1, args.from_slot - 5)
    start_rx, start_ry = slot_center(slots, args.from_slot)
    end_rx, end_ry = slot_center(slots, args.to_slot)

    saved_hwnd, saved_title = load_saved_target()
    hwnd = find_target_hwnd()
    rect = get_window_rect()
    if hwnd is None or rect is None:
        print(
            f"{args.section} drag: slot {args.from_slot} -> {args.to_slot}\n"
            f"  base ratio: ({start_rx:.6f}, {start_ry:.6f}) -> ({end_rx:.6f}, {end_ry:.6f})\n"
            f"  tuning: scale={args.drag_scale:.3f} delta_y={args.delta_y} "
            f"start_y_offset={args.start_y_offset:.1f} end_y_offset={args.end_y_offset:.1f}"
        )
        if saved_hwnd:
            print(f"  saved target: {saved_title or '-'} hwnd={saved_hwnd} is not available")
        else:
            print("  saved target: none; select a window in main.py first")
        if args.dry_run:
            return 0
        print("Target game window was not found.", file=sys.stderr)
        return 2

    resolved = resolve_drag_points(rect, start_rx, start_ry, end_rx, end_ry, args)
    drag_rx, drag_start_ry, drag_end_ry, start_cx, start_cy, end_cx, end_cy = resolved

    print(
        f"{args.section} drag: slot {args.from_slot} -> {args.to_slot}\n"
        f"  target: {saved_title or '-'} hwnd={hwnd}\n"
        f"  base ratio: ({start_rx:.6f}, {start_ry:.6f}) -> ({end_rx:.6f}, {end_ry:.6f})\n"
        f"  drag ratio: ({drag_rx:.6f}, {drag_start_ry:.6f}) -> ({drag_rx:.6f}, {drag_end_ry:.6f})\n"
        f"  client: ({start_cx}, {start_cy}) -> ({end_cx}, {end_cy})\n"
        f"  delta:  dx={end_cx - start_cx}, dy={end_cy - start_cy}\n"
        f"  tuning: scale={args.drag_scale:.3f} delta_y={args.delta_y} "
        f"duration={args.duration:.2f}s end_hold={args.end_hold:.2f}s"
    )

    output_dir = args.output_dir or _default_output_dir(args.section)
    before = None
    if not args.no_debug_capture:
        before = capture_or_fail(hwnd)
        summary = save_debug_captures(output_dir, args.section, section_payload, before, None)
        print(f"  before capture: {summary['before_capture']}")
        print(f"  before overlay: {summary['before_overlay']}")

    if args.dry_run:
        return 0

    ok_all = True
    repeats = max(1, args.repeat)
    for attempt in range(repeats):
        ok = drag_scroll(
            hwnd,
            rect,
            drag_rx,
            drag_start_ry,
            drag_end_ry,
            delay=max(0.0, args.delay),
            duration=max(0.01, args.duration),
            end_hold=max(0.0, args.end_hold),
        )
        ok_all = ok_all and ok
        print(f"attempt {attempt + 1}/{repeats} ok={ok}")
        if attempt + 1 < repeats:
            time.sleep(max(0.0, args.interval))

    if not args.no_debug_capture and before is not None:
        after = capture_or_fail(hwnd)
        summary = save_debug_captures(
            output_dir,
            args.section,
            section_payload,
            before,
            after,
            expected_move_px=abs(end_cy - start_cy),
        )
        print(f"  after capture: {summary['after_capture']}")
        print(f"  after overlay: {summary['after_overlay']}")
        motion = summary.get("movement_estimate")
        if motion:
            print(
                f"  movement: expected={motion['expected_step_px']}px "
                f"actual={motion['actual_move_px']}px "
                f"roi_y_offset={summary.get('after_y_offset_px', 0):+d}px "
                f"score={motion['score']:.3f}"
            )
        print(
            f"  overlap_rows={summary['overlap_rows']} "
            f"source={summary.get('overlap_source')} "
            f"new_slots={summary['new_scan_slot_numbers']}"
        )
        print(f"  summary: {output_dir / 'summary.json'}")
    return 0 if ok_all else 1


if __name__ == "__main__":
    raise SystemExit(main())
