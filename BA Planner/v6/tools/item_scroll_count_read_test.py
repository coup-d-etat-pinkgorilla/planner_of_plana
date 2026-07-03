from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.capture import capture_window_background, find_target_hwnd, get_all_windows, get_window_rect, set_target_window
from core.config import load_config
from core.input import drag_scroll
from tools.inventory_drag_test import load_slots, resolve_drag_points, slot_center
from tools.item_slot_count_test import digit_rois_for_slot, read_slot
from tools.debug_item_slot_outline_text import DEFAULT_PROJECT, SLOT_TEMPLATE_DIR, load_slot_template_masks

DEFAULT_OUTPUT_DIR = ROOT / "debug" / "260625" / "scroll_count_read_test"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Drag item inventory, capture, and read 20 slot count texts before/after scrolling.")
    parser.add_argument("--project", type=Path, default=DEFAULT_PROJECT)
    parser.add_argument("--hwnd", type=int, default=None)
    parser.add_argument("--title-contains", default="Blue Archive")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--slot-template-dir", type=Path, default=SLOT_TEMPLATE_DIR)
    parser.add_argument("--save-slot-templates", action="store_true")
    parser.add_argument("--before-expected", nargs="*", default=None, help="optional 20 expected slot texts before dragging; supports k")
    parser.add_argument("--after-expected", nargs="*", default=None, help="optional 20 expected slot texts after dragging; supports k")
    parser.add_argument("--from-slot", type=int, default=16)
    parser.add_argument("--to-slot", type=int, default=1)
    parser.add_argument("--drag-scale", type=float, default=1.08)
    parser.add_argument("--delta-y", type=float, default=None)
    parser.add_argument("--start-y-offset", type=float, default=0.0)
    parser.add_argument("--end-y-offset", type=float, default=0.0)
    parser.add_argument("--duration", type=float, default=0.65)
    parser.add_argument("--end-hold", type=float, default=0.40)
    parser.add_argument("--delay", type=float, default=0.45)
    parser.add_argument("--settle", type=float, default=0.80)
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--interval", type=float, default=0.70)
    parser.add_argument("--capture-retry", type=int, default=2)
    parser.add_argument("--white-threshold", type=int, default=175)
    parser.add_argument("--black-threshold", type=int, default=130)
    parser.add_argument("--dilate", type=int, default=2)
    parser.add_argument("--confidence-threshold", type=float, default=0.50, help="minimum score to print a best-effort character")
    parser.add_argument("--k-confidence-threshold", type=float, default=0.72)
    parser.add_argument("--k-margin-threshold", type=float, default=0.10)
    parser.add_argument("--margin-threshold", type=float, default=0.03, help="minimum top-vs-second margin to accept a character")
    parser.add_argument("--strict-confidence-threshold", type=float, default=0.80, help="minimum mean score to mark a slot as OK")
    parser.add_argument("--blank-text-threshold", type=int, default=80)
    parser.add_argument("--slots", type=int, default=20)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


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



def select_target(args: argparse.Namespace) -> tuple[int | None, str]:
    if args.hwnd:
        set_target_window(args.hwnd, f"manual:{args.hwnd}")
        return args.hwnd, f"manual:{args.hwnd}"
    saved_hwnd, saved_title = load_saved_target()
    if find_target_hwnd() is not None:
        return saved_hwnd, saved_title
    needle = (args.title_contains or "").strip().lower()
    if needle:
        for window in get_all_windows():
            title = str(window.get("title") or "")
            if needle in title.lower():
                hwnd = int(window["hwnd"])
                set_target_window(hwnd, title)
                return hwnd, title
    return saved_hwnd, saved_title

def read_all_slots(
    image: Image.Image,
    project: dict,
    templates,
    args: argparse.Namespace,
    expected_values: list[str] | None = None,
) -> tuple[list[dict], list[tuple[int, list[list[Image.Image]]]]]:
    results: list[dict] = []
    sheet_rows: list[tuple[int, list[list[Image.Image]]]] = []
    for slot_index in range(1, args.slots + 1):
        rois = digit_rois_for_slot(project, slot_index)
        if len(rois) != 6:
            results.append({"slot": slot_index, "value": "", "confidence": 0.0, "status": "missing-roi"})
            continue
        expected = expected_values[slot_index - 1] if expected_values and slot_index - 1 < len(expected_values) else None
        if expected in {"", "-", "?"}:
            expected = None
        value, confidence, rows, lines = read_slot(image, rois, templates, args, expected=expected)
        ambiguous = "?" in value
        if value and not ambiguous and confidence >= args.strict_confidence_threshold:
            status = "OK"
        elif value and not ambiguous:
            status = "LOWCONF"
        else:
            status = "CHECK"
        results.append({
            "slot": slot_index,
            "value": value,
            "confidence": confidence,
            "status": status,
            "lines": lines,
        })
        sheet_rows.append((slot_index, rows))
    return results, sheet_rows


def save_sheet(path: Path, slot_rows: list[tuple[int, list[list[Image.Image]]]], title: str) -> None:
    blocks: list[Image.Image] = []
    try:
        font = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
    for slot_index, rows in slot_rows:
        row_width = sum(tile.width for tile in rows[0]) if rows else 1
        header = Image.new("RGB", (row_width, 24), "white")
        draw = ImageDraw.Draw(header)
        draw.text((4, 4), f"{title} slot {slot_index}", fill="black", font=font)
        blocks.append(header)
        for row in rows:
            w = sum(tile.width for tile in row)
            h = max(tile.height for tile in row)
            line = Image.new("RGB", (w, h), (230, 230, 230))
            x = 0
            for tile in row:
                line.paste(tile, (x, 0))
                x += tile.width
            blocks.append(line)
    width = max((img.width for img in blocks), default=1)
    height = sum((img.height for img in blocks), 0) or 1
    sheet = Image.new("RGB", (width, height), (230, 230, 230))
    y = 0
    for img in blocks:
        sheet.paste(img, (0, y))
        y += img.height
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, quality=95)


def print_results(label: str, results: list[dict]) -> None:
    ok = sum(1 for row in results if row["status"] == "OK")
    readable = sum(1 for row in results if row["status"] in {"OK", "LOWCONF"})
    values = [row["value"] or "-" for row in results]
    mean_conf = sum(row["confidence"] for row in results if row["value"]) / max(1, sum(1 for row in results if row["value"]))
    print(f"{label}: ok={ok}/{len(results)} readable={readable}/{len(results)} mean_conf={mean_conf:.2f}")
    print("  values=" + ", ".join(values))
    for row in results:
        print(f"  slot {row['slot']:02d}: {row['value'] or 'empty'} conf={row['confidence']:.2f} {row['status']}")


def capture_or_fail(hwnd: int, args: argparse.Namespace) -> Image.Image:
    image = capture_window_background(hwnd, retry=max(0, args.capture_retry), normalize=True)
    if image is None:
        raise RuntimeError("failed to capture target window")
    return image.convert("RGB")


def main() -> int:
    args = parse_args()
    saved_hwnd, saved_title = select_target(args)
    hwnd = find_target_hwnd()
    rect = get_window_rect()
    if hwnd is None or rect is None:
        if saved_hwnd:
            print(f"saved target unavailable: {saved_title or '-'} hwnd={saved_hwnd}", file=sys.stderr)
        else:
            print("no saved target. Open main.py and select the game window first.", file=sys.stderr)
        return 2

    project = json.loads(args.project.read_text(encoding="utf-8-sig"))
    templates = load_slot_template_masks(args.slot_template_dir)
    k_templates = sum(1 for value, _name, _mask in templates if value == "k")
    slots = load_slots("item")
    start_rx, start_ry = slot_center(slots, args.from_slot)
    end_rx, end_ry = slot_center(slots, args.to_slot)
    resolved = resolve_drag_points(rect, start_rx, start_ry, end_rx, end_ry, args)
    drag_rx, drag_start_ry, drag_end_ry, start_cx, start_cy, _end_cx, end_cy = resolved

    print(f"target={saved_title or '-'} hwnd={hwnd}")
    print(f"drag client=({start_cx},{start_cy})->({start_cx},{end_cy}) duration={args.duration:.2f} end_hold={args.end_hold:.2f}")
    print(f"templates={len(templates)} k_templates={k_templates}")
    if k_templates == 0:
        print("warning: no k templates yet; pass --before-expected/--after-expected with --save-slot-templates on a screen that contains k")
    if args.dry_run:
        return 0

    args.output_dir.mkdir(parents=True, exist_ok=True)
    before = capture_or_fail(hwnd, args)
    before.save(args.output_dir / "before_capture.png", quality=95)
    before_results, before_rows = read_all_slots(before, project, templates, args, args.before_expected)
    if args.save_slot_templates and args.before_expected:
        templates = load_slot_template_masks(args.slot_template_dir)
    print_results("before", before_results)
    save_sheet(args.output_dir / "before_contact.png", before_rows, "before")

    ok_all = True
    for attempt in range(max(1, args.repeat)):
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
        print(f"drag {attempt + 1}/{max(1, args.repeat)} ok={ok}")
        if attempt + 1 < max(1, args.repeat):
            time.sleep(max(0.0, args.interval))
    time.sleep(max(0.0, args.settle))

    after = capture_or_fail(hwnd, args)
    after.save(args.output_dir / "after_capture.png", quality=95)
    after_results, after_rows = read_all_slots(after, project, templates, args, args.after_expected)
    print_results("after", after_results)
    save_sheet(args.output_dir / "after_contact.png", after_rows, "after")

    summary = {
        "drag_ok": ok_all,
        "before": before_results,
        "after": after_results,
    }
    (args.output_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"saved={args.output_dir.resolve()}")
    after_readable = sum(1 for row in after_results if row["status"] in {"OK", "LOWCONF"})
    return 0 if ok_all and after_readable >= max(1, args.slots // 2) else 1


if __name__ == "__main__":
    raise SystemExit(main())
