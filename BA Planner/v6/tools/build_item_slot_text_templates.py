from __future__ import annotations

import argparse
import json
import sys
from dataclasses import replace
from pathlib import Path

import numpy as np
from PIL import Image, ImageColor, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.quad_roi import warp_quad_region
from tools.debug_item_slot_outline_text import SLOT_TEMPLATE_DIR
from tools.template_alignment_studio_model import LayerSpec, render_text_layer

DEFAULT_PROJECT = ROOT / "debug" / "260625" / "template_alignment_studio_item.json"
DEFAULT_OUTPUT = ROOT / "debug" / "260625" / "item_slot_synthetic_templates_contact.png"
DEFAULT_CHARS = "0123456789xk"
RGB_CUBE_DISTANCE = float((3 * (255 ** 2)) ** 0.5)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build item slot count glyph templates from a Template Alignment Studio text layer.")
    parser.add_argument("--project", type=Path, default=DEFAULT_PROJECT)
    parser.add_argument("--layer", default="digit5")
    parser.add_argument("--roi", default="itemslot_1_digit_5")
    parser.add_argument("--all-digit-rois", action="store_true", help="render the same font glyph into itemslot_1_digit_0..5 ROIs")
    parser.add_argument("--roi-prefix", default="itemslot_1_digit_", help="prefix used with --all-digit-rois")
    parser.add_argument("--chars", default=DEFAULT_CHARS)
    parser.add_argument("--text-format", default="  {char}", help="text rendered into the source layer; default preserves rightmost digit placement")
    parser.add_argument("--output-dir", type=Path, default=SLOT_TEMPLATE_DIR)
    parser.add_argument("--contact", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--prefix", default="synthetic_digit5")
    parser.add_argument("--threshold", type=int, default=16)
    parser.add_argument("--mask-mode", choices=("color", "alpha"), default="color")
    parser.add_argument("--color-geometry", choices=("warp", "bbox"), default="warp", help="how to crop color masks; bbox matches the original synthetic_digit5 generation")
    parser.add_argument("--fill", default="#2D4663")
    parser.add_argument("--target-color", default="#2D4663")
    parser.add_argument("--tolerance-percent", type=float, default=0.0)
    parser.add_argument("--stroke-width", type=int, default=0)
    parser.add_argument("--stroke-fill", default="#2D4663")
    parser.add_argument("--opacity", type=int, default=100)
    return parser.parse_args()


def load_project_payload(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def find_layer(payload: dict, name: str) -> LayerSpec:
    for row in payload.get("layers", []):
        if row.get("name") == name:
            return LayerSpec(**{key: value for key, value in row.items() if key in LayerSpec.__dataclass_fields__})
    raise KeyError(f"layer not found: {name}")


def find_roi(payload: dict, name: str) -> dict:
    for roi in payload.get("rois", []):
        if roi.get("name") == name:
            return roi
    raise KeyError(f"roi not found: {name}")


def roi_points(roi: dict) -> list[tuple[int, int]]:
    points = roi.get("points") or []
    if len(points) >= 4:
        return [(int(round(point["x"])), int(round(point["y"]))) for point in points[:4]]
    x = int(round(roi["x"]))
    y = int(round(roi["y"]))
    w = int(round(roi["width"]))
    h = int(round(roi["height"]))
    slant = int(round(roi.get("slant", 0) or 0)) if roi.get("shape") == "parallelogram" else 0
    return [(x + slant, y), (x + w + slant, y), (x + w, y + h), (x, y + h)]

def roi_warp_payload(roi: dict, canvas_size: tuple[int, int]) -> dict:
    width, height = canvas_size
    return {
        "points_ratio": [
            {"x": x / width, "y": y / height}
            for x, y in roi_points(roi)
        ],
    }


def crop_roi_alpha(canvas: Image.Image, roi: dict, threshold: int) -> Image.Image:
    points = roi_points(roi)
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    box = (min(xs), min(ys), max(xs), max(ys))
    crop = canvas.crop(box)
    if roi.get("shape") == "parallelogram":
        poly_mask = Image.new("L", crop.size, 0)
        local_points = [(x - box[0], y - box[1]) for x, y in points]
        ImageDraw.Draw(poly_mask).polygon(local_points, fill=255)
        alpha = Image.composite(crop.getchannel("A"), Image.new("L", crop.size, 0), poly_mask)
    else:
        alpha = crop.getchannel("A")
    return alpha.point(lambda value: 255 if value >= threshold else 0)


def parse_rgb(value: str) -> tuple[int, int, int]:
    return ImageColor.getcolor(value, "RGB")


def crop_roi_color_mask_bbox(canvas: Image.Image, roi: dict, target_color: str, tolerance_percent: float) -> Image.Image:
    points = roi_points(roi)
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    box = (min(xs), min(ys), max(xs), max(ys))
    crop = canvas.crop(box).convert("RGBA")
    arr = np.array(crop, dtype=np.uint8)
    target = np.array(parse_rgb(target_color), dtype=np.int16)
    diff = arr[..., :3].astype(np.int16) - target.reshape(1, 1, 3)
    diff32 = diff.astype(np.int32)
    distance = np.sqrt(np.sum(diff32 * diff32, axis=2))
    threshold = max(0.0, float(tolerance_percent)) / 100.0 * RGB_CUBE_DISTANCE
    mask_arr = ((distance <= threshold + 1e-6) & (arr[..., 3] >= 1)).astype(np.uint8) * 255
    mask = Image.fromarray(mask_arr, "L")
    if roi.get("shape") == "parallelogram":
        poly_mask = Image.new("L", crop.size, 0)
        local_points = [(x - box[0], y - box[1]) for x, y in points]
        ImageDraw.Draw(poly_mask).polygon(local_points, fill=255)
        mask = Image.composite(mask, Image.new("L", crop.size, 0), poly_mask)
    return mask

def crop_roi_color_mask(canvas: Image.Image, roi: dict, target_color: str, tolerance_percent: float) -> Image.Image:
    crop = warp_quad_region(canvas, roi_warp_payload(roi, canvas.size))
    if crop is None:
        return Image.new("L", (1, 1), 0)
    arr = np.array(crop, dtype=np.uint8)
    target = np.array(parse_rgb(target_color), dtype=np.int16)
    diff = arr[..., :3].astype(np.int16) - target.reshape(1, 1, 3)
    diff32 = diff.astype(np.int32)
    distance = np.sqrt(np.sum(diff32 * diff32, axis=2))
    threshold = max(0.0, float(tolerance_percent)) / 100.0 * RGB_CUBE_DISTANCE
    mask_arr = (distance <= threshold + 1e-6).astype(np.uint8) * 255
    return Image.fromarray(mask_arr, "L")


def render_char_to_canvas(
    layer: LayerSpec,
    char: str,
    text_format: str,
    canvas_size: tuple[int, int],
    *,
    fill: str,
    stroke_width: int,
    stroke_fill: str,
    opacity: int,
    offset: tuple[int, int] = (0, 0),
) -> Image.Image:
    text_layer = replace(
        layer,
        text=text_format.format(char=char),
        visible=True,
        opacity=max(0, min(100, int(opacity))),
        fill=fill,
        stroke_width=max(0, int(stroke_width)),
        stroke_fill=stroke_fill,
        x=layer.x + int(offset[0]),
        y=layer.y + int(offset[1]),
    )
    layer_image = render_text_layer(text_layer)
    if text_layer.opacity < 100:
        alpha = layer_image.getchannel("A").point(lambda value: value * text_layer.opacity // 100)
        layer_image.putalpha(alpha)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(layer_image, dest=(text_layer.x, text_layer.y))
    return canvas


def make_contact(entries: list[tuple[str, Image.Image]]) -> Image.Image:
    scale = 6
    label_h = 22
    tiles = []
    for char, mask in entries:
        body = mask.convert("RGB").resize((mask.width * scale, mask.height * scale), Image.Resampling.NEAREST)
        tile = Image.new("RGB", (body.width, body.height + label_h), "white")
        tile.paste(body, (0, label_h))
        ImageDraw.Draw(tile).text((4, 4), char, fill="black")
        tiles.append(tile)
    if not tiles:
        return Image.new("RGB", (1, 1), "white")
    width = sum(tile.width for tile in tiles)
    height = max(tile.height for tile in tiles)
    sheet = Image.new("RGB", (width, height), (230, 230, 230))
    x = 0
    for tile in tiles:
        sheet.paste(tile, (x, 0))
        x += tile.width
    return sheet


def main() -> int:
    args = parse_args()
    payload = load_project_payload(args.project)
    layer = find_layer(payload, args.layer)
    base_roi = find_roi(payload, args.roi)
    if args.all_digit_rois:
        target_rois = [(position, find_roi(payload, f"{args.roi_prefix}{position}")) for position in range(6)]
    else:
        target_rois = [(None, base_roi)]
    base_x = int(round(base_roi["x"]))
    base_y = int(round(base_roi["y"]))
    canvas_size = (2560, 1440)
    entries: list[tuple[str, Image.Image]] = []
    saved = []
    for position, roi in target_rois:
        offset = (int(round(roi["x"])) - base_x, int(round(roi["y"])) - base_y)
        pos_suffix = "" if position is None else f"_pos{position}"
        for char in args.chars:
            render_char = "K" if char == "k" else char
            canvas = render_char_to_canvas(
                layer,
                render_char,
                args.text_format,
                canvas_size,
                fill=args.fill,
                stroke_width=args.stroke_width,
                stroke_fill=args.stroke_fill,
                opacity=args.opacity,
                offset=offset,
            )
            if args.mask_mode == "color":
                if args.color_geometry == "bbox":
                    mask = crop_roi_color_mask_bbox(canvas, roi, args.target_color, args.tolerance_percent)
                else:
                    mask = crop_roi_color_mask(canvas, roi, args.target_color, args.tolerance_percent)
            else:
                mask = crop_roi_alpha(canvas, roi, args.threshold)
            if not mask.getbbox():
                print(f"warning: empty glyph for {char!r} at position {position}")
                continue
            target_dir = args.output_dir / char
            target_dir.mkdir(parents=True, exist_ok=True)
            target = target_dir / f"{args.prefix}{pos_suffix}_{char}.png"
            mask.save(target)
            entries.append((f"{char}{pos_suffix}", mask))
            saved.append(target)
    args.contact.parent.mkdir(parents=True, exist_ok=True)
    make_contact(entries).save(args.contact, quality=95)
    print(
        f"layer={args.layer} roi={args.roi} all_digit_rois={args.all_digit_rois} text_format={args.text_format!r} "
        f"mask_mode={args.mask_mode} color_geometry={args.color_geometry} target={args.target_color} "
        f"tolerance={args.tolerance_percent:g}%"
    )
    for path in saved:
        print(f"saved={path}")
    print(f"contact={args.contact.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())