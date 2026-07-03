from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.debug_item_slot_outline_text import (  # noqa: E402
    DEFAULT_PROJECT,
    DEFAULT_OUTPUT,
    SLOT_TEMPLATE_DIR,
    classify_mask,
    extract_outline_text,
    find_reference_image,
    load_slot_template_masks,
    save_slot_template,
    tile_with_label,
    warp_roi,
)

DEFAULT_EXPECTED = [
    "x2229", "x790", "x631", "x96", "x2866",
    "x1234", "x724", "x21", "x5297", "x1712",
    "x1441", "x215", "x4042", "x1591", "x692",
    "x202", "x4205", "x2029", "x666", "x112",
]
DEFAULT_OUTPUT_ALL = ROOT / "debug" / "260625" / "itemslot_20_count_test_contact.png"
ALLOWED_CHARS = set("0123456789xk")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read 20 item slot counts from slot digit ROIs.")
    parser.add_argument("--project", type=Path, default=DEFAULT_PROJECT)
    parser.add_argument("--image", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_ALL)
    parser.add_argument("--slot-template-dir", type=Path, default=SLOT_TEMPLATE_DIR)
    parser.add_argument("--expected", nargs="*", default=DEFAULT_EXPECTED)
    parser.add_argument("--save-slot-templates", action="store_true")
    parser.add_argument("--white-threshold", type=int, default=175)
    parser.add_argument("--black-threshold", type=int, default=130)
    parser.add_argument("--dilate", type=int, default=2)
    parser.add_argument("--confidence-threshold", type=float, default=0.80)
    parser.add_argument("--k-confidence-threshold", type=float, default=0.72)
    parser.add_argument("--k-margin-threshold", type=float, default=0.10)
    parser.add_argument("--margin-threshold", type=float, default=0.03)
    parser.add_argument("--blank-text-threshold", type=int, default=80)
    parser.add_argument("--slots", type=int, default=20)
    return parser.parse_args()


def digit_rois_for_slot(project: dict, slot_index: int) -> list[dict]:
    prefix = f"itemslot_{slot_index}_digit_"
    rois = [roi for roi in project.get("rois", []) if str(roi.get("name", "")).startswith(prefix)]
    rois.sort(key=lambda row: int(str(row["name"]).rsplit("_", 1)[-1]))
    return rois


def expected_labels(rois: list[dict], expected: str | None) -> dict[str, str]:
    if not expected:
        return {}
    chars = [char.lower() for char in expected.strip()]
    bad = [char for char in chars if char not in ALLOWED_CHARS]
    if bad:
        raise ValueError(f"unsupported expected chars: {bad!r}")
    if len(chars) > len(rois):
        raise ValueError(f"expected {expected!r} is longer than {len(rois)} digit cells")
    padded = [""] * (len(rois) - len(chars)) + chars
    return {roi["name"]: char for roi, char in zip(rois, padded) if char}


def read_slot(image: Image.Image, rois: list[dict], templates, args: argparse.Namespace, expected: str | None) -> tuple[str, float, list[list[Image.Image]], list[str]]:
    labels = expected_labels(rois, expected)
    chars: list[str] = []
    confidences: list[float] = []
    rows: list[list[Image.Image]] = []
    lines: list[str] = []
    for roi in rois:
        crop = warp_roi(image, roi)
        result = extract_outline_text(crop, args.white_threshold, args.black_threshold, args.dilate)
        label = labels.get(roi["name"])
        if args.save_slot_templates and label:
            save_slot_template(result["cleaned"], args.slot_template_dir, label, roi["name"])
        text_pixels = int(result["text_pixels"])
        has_text = text_pixels >= args.blank_text_threshold
        top = classify_mask(result["cleaned"], templates) if has_text else []
        top_text = ", ".join(f"{value}:{score:.2f}" for value, _name, score in top[:3]) or "empty"
        margin = top[0][2] - top[1][2] if len(top) > 1 else (top[0][2] if top else 0.0)
        accepted = bool(top and top[0][2] >= args.confidence_threshold and margin >= args.margin_threshold)
        if accepted and top[0][0] == "k":
            accepted = top[0][2] >= args.k_confidence_threshold and margin >= args.k_margin_threshold
        if accepted:
            chars.append(top[0][0])
            confidences.append(top[0][2])
        elif has_text:
            chars.append("?")
        lines.append(
            f"{roi['name']} text={result['text_pixels']} expected={label or '-'} margin={margin:.2f} top={top_text}"
        )
        rows.append([
            tile_with_label(crop, f"{roi['name']} raw", scale=3),
            tile_with_label(result["cleaned"], "text", scale=3),
        ])
    value = "".join(chars)
    confidence = sum(confidences) / len(confidences) if confidences else 0.0
    return value, confidence, rows, lines


def make_sheet(slot_rows: list[tuple[int, list[list[Image.Image]]]]) -> Image.Image:
    flattened: list[Image.Image] = []
    for slot_index, rows in slot_rows:
        label_h = 24
        row_width = sum(tile.width for tile in rows[0]) if rows else 1
        header = Image.new("RGB", (row_width, label_h), "white")
        draw = ImageDraw.Draw(header)
        try:
            font = ImageFont.truetype("arial.ttf", 14)
        except OSError:
            font = ImageFont.load_default()
        draw.text((4, 4), f"slot {slot_index}", fill="black", font=font)
        flattened.append(header)
        for row in rows:
            w = sum(tile.width for tile in row)
            h = max(tile.height for tile in row)
            line = Image.new("RGB", (w, h), (230, 230, 230))
            x = 0
            for tile in row:
                line.paste(tile, (x, 0))
                x += tile.width
            flattened.append(line)
    width = max(img.width for img in flattened) if flattened else 1
    height = sum(img.height for img in flattened) if flattened else 1
    sheet = Image.new("RGB", (width, height), (230, 230, 230))
    y = 0
    for img in flattened:
        sheet.paste(img, (0, y))
        y += img.height
    return sheet


def main() -> int:
    args = parse_args()
    project = json.loads(args.project.read_text(encoding="utf-8-sig"))
    image_path = args.image or find_reference_image(project)
    image = Image.open(image_path).convert("RGB")
    templates = load_slot_template_masks(args.slot_template_dir)
    if args.save_slot_templates:
        # Save first, then reload so this run can classify with newly added samples.
        for slot_index in range(1, args.slots + 1):
            rois = digit_rois_for_slot(project, slot_index)
            expected = args.expected[slot_index - 1] if slot_index - 1 < len(args.expected) else None
            read_slot(image, rois, templates, args, expected)
        templates = load_slot_template_masks(args.slot_template_dir)

    print(f"image={image_path}")
    print(f"templates={len(templates)}")
    slot_rows: list[tuple[int, list[list[Image.Image]]]] = []
    ok = 0
    for slot_index in range(1, args.slots + 1):
        rois = digit_rois_for_slot(project, slot_index)
        if len(rois) != 6:
            print(f"slot {slot_index:02d}: missing digit ROIs ({len(rois)})")
            continue
        expected = args.expected[slot_index - 1] if slot_index - 1 < len(args.expected) else None
        value, confidence, rows, lines = read_slot(image, rois, templates, args, expected)
        match = expected is None or value == expected.lower()
        ok += 1 if match else 0
        status = "OK" if match else "NG"
        print(f"slot {slot_index:02d}: {value or 'empty'} conf={confidence:.2f} expected={expected or '-'} {status}")
        for line in lines:
            print(f"  {line}")
        slot_rows.append((slot_index, rows))

    if slot_rows:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        make_sheet(slot_rows).save(args.output, quality=95)
        print(f"saved={args.output.resolve()}")
    print(f"matched={ok}/{args.slots}")
    return 0 if ok == args.slots else 1


if __name__ == "__main__":
    raise SystemExit(main())
