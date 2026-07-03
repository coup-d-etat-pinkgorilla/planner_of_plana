from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

from core.quad_roi import binary_glyph_similarity, normalize_binary_glyph

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

DEFAULT_PROJECT = ROOT / "debug" / "260625" / "template_alignment_studio_item.json"
DEFAULT_OUTPUT = ROOT / "debug" / "260625" / "itemslot_1_outline_text_contact.png"
SCREENSHOT_DIR = Path(r"C:\Users\brigh\Pictures\Screenshots")
TEMPLATE_DIR = ROOT / "templates" / "inventory_count"
SLOT_TEMPLATE_DIR = ROOT / "templates" / "item_slot_count"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract black text with white outline from item slot digit ROIs.")
    parser.add_argument("--project", type=Path, default=DEFAULT_PROJECT)
    parser.add_argument("--image", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--prefix", default="itemslot_1_digit_")
    parser.add_argument("--white-threshold", type=int, default=188)
    parser.add_argument("--black-threshold", type=int, default=110)
    parser.add_argument("--dilate", type=int, default=2)
    parser.add_argument("--slot-template-dir", type=Path, default=SLOT_TEMPLATE_DIR)
    parser.add_argument("--expected", default=None, help="Known slot text, e.g. x2229, used to label/save templates.")
    parser.add_argument("--save-slot-templates", action="store_true")
    parser.add_argument("--use-detail-templates", action="store_true")
    parser.add_argument("--confidence-threshold", type=float, default=0.80)
    parser.add_argument("--k-confidence-threshold", type=float, default=0.72)
    parser.add_argument("--k-margin-threshold", type=float, default=0.10)
    parser.add_argument("--margin-threshold", type=float, default=0.03)
    return parser.parse_args()


def find_reference_image(project: dict) -> Path:
    ref = str(project.get("reference_path") or "")
    candidate = Path(ref)
    if candidate.exists():
        return candidate
    # Older project files may have mojibake in the Korean filename; use the timestamp tail.
    for token in ("2026-06-25 163019", "2026-06-25 174953"):
        matches = list(SCREENSHOT_DIR.glob(f"*{token}.png"))
        if matches:
            return matches[0]
    raise FileNotFoundError("reference image not found; pass --image")


def roi_points(roi: dict) -> list[tuple[float, float]]:
    points = roi.get("points") or []
    if len(points) >= 4:
        return [(float(p["x"]), float(p["y"])) for p in points[:4]]
    x = float(roi["x"])
    y = float(roi["y"])
    w = float(roi["width"])
    h = float(roi["height"])
    slant = float(roi.get("slant", 0) or 0) if roi.get("shape") == "parallelogram" else 0.0
    return [(x + slant, y), (x + w + slant, y), (x + w, y + h), (x, y + h)]


def warp_roi(image: Image.Image, roi: dict) -> Image.Image:
    points = roi_points(roi)
    top_left, top_right, bottom_right, bottom_left = points
    top_width = np.linalg.norm(np.array(top_right) - np.array(top_left))
    bottom_width = np.linalg.norm(np.array(bottom_right) - np.array(bottom_left))
    left_height = np.linalg.norm(np.array(bottom_left) - np.array(top_left))
    right_height = np.linalg.norm(np.array(bottom_right) - np.array(top_right))
    dst_w = max(1, int(round(max(top_width, bottom_width))))
    dst_h = max(1, int(round(max(left_height, right_height))))
    src = np.array(points, dtype=np.float32)
    dst = np.array([(0, 0), (dst_w - 1, 0), (dst_w - 1, dst_h - 1), (0, dst_h - 1)], dtype=np.float32)
    matrix = cv2.getPerspectiveTransform(src, dst)
    warped = cv2.warpPerspective(np.array(image.convert("RGB")), matrix, (dst_w, dst_h))
    return Image.fromarray(warped)


def extract_outline_text(crop: Image.Image, white_threshold: int, black_threshold: int, dilate: int) -> dict[str, Image.Image | int | float]:
    arr = np.array(crop.convert("RGB"), dtype=np.uint8)
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    maxc = arr.max(axis=2)
    minc = arr.min(axis=2)
    saturation_span = maxc.astype(np.int16) - minc.astype(np.int16)

    white = ((gray >= white_threshold) & (saturation_span <= 55)).astype(np.uint8) * 255
    black = (gray <= black_threshold).astype(np.uint8) * 255
    if dilate > 0:
        kernel_size = dilate * 2 + 1
        kernel = np.ones((kernel_size, kernel_size), np.uint8)
        near_white = cv2.dilate(white, kernel, iterations=1)
    else:
        near_white = white
    text = cv2.bitwise_and(black, near_white)
    text = cv2.morphologyEx(text, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))

    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(text, 8)
    cleaned = np.zeros_like(text)
    kept_components = 0
    for label in range(1, count):
        area = int(stats[label, cv2.CC_STAT_AREA])
        w = int(stats[label, cv2.CC_STAT_WIDTH])
        h = int(stats[label, cv2.CC_STAT_HEIGHT])
        if area >= 4 and h >= 4 and w >= 2:
            cleaned[labels == label] = 255
            kept_components += 1

    return {
        "white": Image.fromarray(white),
        "black": Image.fromarray(black),
        "text": Image.fromarray(text),
        "cleaned": Image.fromarray(cleaned),
        "white_pixels": int(np.count_nonzero(white)),
        "black_pixels": int(np.count_nonzero(black)),
        "text_pixels": int(np.count_nonzero(cleaned)),
        "components": kept_components,
    }



def _binary_mask_array(img: Image.Image, size: tuple[int, int]) -> np.ndarray:
    arr = np.array(img.convert("L").resize(size, Image.Resampling.NEAREST), dtype=np.uint8)
    return (arr > 0).astype(np.float32)


def _score_binary_arrays(a: np.ndarray, b: np.ndarray) -> float:
    aa = a.astype(np.float32).reshape(-1)
    bb = b.astype(np.float32).reshape(-1)
    if aa.sum() <= 0 or bb.sum() <= 0:
        return 0.0
    inter = float(np.dot(aa, bb))
    union = float(np.count_nonzero((aa + bb) > 0))
    iou = inter / union if union else 0.0
    aa = aa - aa.mean()
    bb = bb - bb.mean()
    denom = float(np.linalg.norm(aa) * np.linalg.norm(bb))
    corr = float(np.dot(aa, bb) / denom) if denom > 1e-6 else 0.0
    return max(0.0, min(1.0, (iou * 0.55) + (((corr + 1.0) / 2.0) * 0.45)))


def _shift_binary_array(arr: np.ndarray, dx: int, dy: int) -> np.ndarray:
    if dx == 0 and dy == 0:
        return arr
    h, w = arr.shape
    out = np.zeros_like(arr)
    src_x1 = max(0, -dx)
    src_x2 = min(w, w - dx) if dx >= 0 else w
    dst_x1 = max(0, dx)
    dst_x2 = min(w, w + dx) if dx < 0 else w
    src_y1 = max(0, -dy)
    src_y2 = min(h, h - dy) if dy >= 0 else h
    dst_y1 = max(0, dy)
    dst_y2 = min(h, h + dy) if dy < 0 else h
    if src_x1 < src_x2 and src_y1 < src_y2 and dst_x1 < dst_x2 and dst_y1 < dst_y2:
        out[dst_y1:dst_y2, dst_x1:dst_x2] = arr[src_y1:src_y2, src_x1:src_x2]
    return out


def _trim_mask(img: Image.Image, pad: int = 2) -> Image.Image | None:
    arr = np.array(img.convert("L"), dtype=np.uint8)
    ys, xs = np.nonzero(arr > 0)
    if len(xs) == 0 or len(ys) == 0:
        return None
    x1 = max(0, int(xs.min()) - pad)
    x2 = min(arr.shape[1], int(xs.max()) + pad + 1)
    y1 = max(0, int(ys.min()) - pad)
    y2 = min(arr.shape[0], int(ys.max()) + pad + 1)
    return Image.fromarray(arr[y1:y2, x1:x2])


def _shift_tolerant_similarity(a: Image.Image, b: Image.Image, *, max_shift: int = 2) -> float:
    bb_img = b.convert("L")
    size = bb_img.size
    aa = _binary_mask_array(a, size)
    bb = _binary_mask_array(bb_img, size)
    best = 0.0
    for dy in range(-max_shift, max_shift + 1):
        for dx in range(-max_shift, max_shift + 1):
            best = max(best, _score_binary_arrays(_shift_binary_array(aa, dx, dy), bb))
    return best



def _normalized_glyph_score(a: Image.Image, b: Image.Image) -> float:
    left = np.array(a.convert("L"), dtype=np.uint8)
    right = np.array(b.convert("L"), dtype=np.uint8)
    left = ((left > 0).astype(np.uint8)) * 255
    right = ((right > 0).astype(np.uint8)) * 255
    left_glyph = normalize_binary_glyph(left, output_size=(24, 32), padding=2)
    right_glyph = normalize_binary_glyph(right, output_size=(24, 32), padding=2)
    if left_glyph is None or right_glyph is None:
        return 0.0
    return binary_glyph_similarity(left_glyph, right_glyph)

def mask_similarity(a: Image.Image, b: Image.Image) -> float:
    full = _shift_tolerant_similarity(a, b, max_shift=2)
    glyph = _normalized_glyph_score(a, b)
    a_trim = _trim_mask(a)
    b_trim = _trim_mask(b)
    if a_trim is None or b_trim is None:
        return max(full, glyph)
    canonical_size = (24, 34)
    aa = _binary_mask_array(a_trim, canonical_size)
    bb = _binary_mask_array(b_trim, canonical_size)
    canonical = _score_binary_arrays(aa, bb)
    return max(full, canonical, glyph)

def template_value(path: Path) -> str | None:
    stem = path.stem
    try:
        index = int(stem.rsplit("_", 1)[-1])
    except ValueError:
        return None
    if stem.startswith("x_digit"):
        return "x"
    if 1 <= index <= 9:
        return str(index)
    if index == 10:
        return "0"
    return None


def load_template_masks(white_threshold: int, black_threshold: int, dilate: int) -> list[tuple[str, str, Image.Image]]:
    entries: list[tuple[str, str, Image.Image]] = []
    for path in sorted(TEMPLATE_DIR.glob("*.png")):
        value = template_value(path)
        if value is None:
            continue
        try:
            image = Image.open(path).convert("RGB")
        except Exception:
            continue
        result = extract_outline_text(image, white_threshold, black_threshold, dilate)
        mask = result["cleaned"]
        if int(result["text_pixels"]) <= 0:
            gray = np.array(image.convert("L"), dtype=np.uint8)
            _thr, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
            mask = Image.fromarray(otsu)
        entries.append((value, path.name, mask))
    return entries



def load_slot_template_masks(template_dir: Path) -> list[tuple[str, str, Image.Image]]:
    entries: list[tuple[str, str, Image.Image]] = []
    for path in sorted(template_dir.glob("*/*.png")):
        value = path.parent.name
        if value not in {"x", "k", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}:
            continue
        try:
            image = Image.open(path).convert("L")
        except Exception:
            continue
        entries.append((value, path.name, image))
    return entries


def expected_by_roi(rois: list[dict], expected: str | None) -> dict[str, str]:
    if not expected:
        return {}
    chars = list(expected.strip())
    if len(chars) > len(rois):
        raise ValueError(f"expected text {expected!r} is longer than ROI count {len(rois)}")
    padded = [""] * (len(rois) - len(chars)) + chars
    return {roi["name"]: char for roi, char in zip(rois, padded) if char}


def save_slot_template(mask: Image.Image, template_dir: Path, value: str, source_name: str) -> Path | None:
    value = value.strip()
    if value not in {"x", "k", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}:
        return None
    if not np.count_nonzero(np.array(mask.convert("L"), dtype=np.uint8)):
        return None
    target_dir = template_dir / value
    target_dir.mkdir(parents=True, exist_ok=True)
    path = target_dir / f"{source_name}.png"
    mask.save(path)
    return path

def classify_mask(mask: Image.Image, templates: list[tuple[str, str, Image.Image]]) -> list[tuple[str, str, float]]:
    scored = [(value, name, mask_similarity(mask, tmpl)) for value, name, tmpl in templates]
    scored.sort(key=lambda row: row[2], reverse=True)
    collapsed: dict[str, tuple[str, str, float]] = {}
    for value, name, score in scored:
        if value not in collapsed:
            collapsed[value] = (value, name, score)
    return sorted(collapsed.values(), key=lambda row: row[2], reverse=True)[:5]

def tile_with_label(img: Image.Image, label: str, scale: int = 4) -> Image.Image:
    body = img.convert("RGB").resize((img.width * scale, img.height * scale), Image.Resampling.NEAREST)
    label_h = 22
    out = Image.new("RGB", (body.width, body.height + label_h), "white")
    out.paste(body, (0, label_h))
    draw = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
    draw.text((3, 3), label, fill="black", font=font)
    return out


def main() -> int:
    args = parse_args()
    project = json.loads(args.project.read_text(encoding="utf-8-sig"))
    image_path = args.image or find_reference_image(project)
    image = Image.open(image_path).convert("RGB")
    rois = [roi for roi in project.get("rois", []) if str(roi.get("name", "")).startswith(args.prefix)]
    rois.sort(key=lambda row: int(str(row["name"]).rsplit("_", 1)[-1]))
    if not rois:
        print(f"no ROIs found with prefix {args.prefix!r}", file=sys.stderr)
        return 2

    labels = expected_by_roi(rois, args.expected)
    templates = load_slot_template_masks(args.slot_template_dir)
    if args.use_detail_templates:
        templates.extend(load_template_masks(args.white_threshold, args.black_threshold, args.dilate))
    rows = []
    recognized_chars: list[str] = []
    confidences: list[float] = []
    print(f"image={image_path}")
    print(f"templates={len(templates)}")
    for roi in rois:
        crop = warp_roi(image, roi)
        result = extract_outline_text(crop, args.white_threshold, args.black_threshold, args.dilate)
        name = roi["name"]
        label = labels.get(name)
        if args.save_slot_templates and label:
            save_slot_template(result["cleaned"], args.slot_template_dir, label, name)
        top = classify_mask(result["cleaned"], templates) if int(result["text_pixels"]) > 0 else []
        top_text = ", ".join(f"{value}:{score:.2f}" for value, _name, score in top[:3]) or "empty"
        margin = top[0][2] - top[1][2] if len(top) > 1 else (top[0][2] if top else 0.0)
        expected_text = f" expected={label}" if label else ""
        accepted = bool(top and top[0][2] >= args.confidence_threshold and margin >= args.margin_threshold)
        if accepted and top[0][0] == "k":
            accepted = top[0][2] >= args.k_confidence_threshold and margin >= args.k_margin_threshold
        if accepted:
            recognized_chars.append(top[0][0])
            confidences.append(top[0][2])
        elif int(result["text_pixels"]) > 0:
            recognized_chars.append("?")
        print(
            f"{name}: crop={crop.size} white={result['white_pixels']} "
            f"black={result['black_pixels']} text={result['text_pixels']} "
            f"components={result['components']}{expected_text} margin={margin:.2f} top={top_text}"
        )
        rows.append([
            tile_with_label(crop, f"{name} raw"),
            tile_with_label(result["white"], "white"),
            tile_with_label(result["black"], "black"),
            tile_with_label(result["cleaned"], "text"),
        ])

    row_width = sum(tile.width for tile in rows[0])
    row_height = max(tile.height for tile in rows[0])
    sheet = Image.new("RGB", (row_width, row_height * len(rows)), (230, 230, 230))
    for y_idx, row in enumerate(rows):
        x = 0
        for tile in row:
            sheet.paste(tile, (x, y_idx * row_height))
            x += tile.width
    recognized = "".join(recognized_chars)
    mean_confidence = (sum(confidences) / len(confidences)) if confidences else 0.0
    print(f"recognized={recognized or 'empty'} confidence={mean_confidence:.2f}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, quality=95)
    print(f"saved={args.output.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
