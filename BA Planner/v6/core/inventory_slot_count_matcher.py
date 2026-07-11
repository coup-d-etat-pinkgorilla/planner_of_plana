from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

from core.config import TEMPLATE_DIR
from core.quad_roi import binary_glyph_similarity, normalize_binary_glyph, warp_quad_region


SLOT_COUNT_TEMPLATE_DIR = TEMPLATE_DIR / "item_slot_count"
ALLOWED_VALUES = frozenset({"x", "k", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"})
SLOT_TEXT_COLOR = (0x2D, 0x46, 0x63)
RGB_CUBE_DISTANCE = float(np.sqrt(3.0 * (255.0 ** 2)))
COLOR_FILTER_MODE_EXACT = "exact"
COLOR_FILTER_MODE_DARK_INK = "dark_ink"

_BASE_SLOT = {"x": 1379.0, "y": 319.0, "width": 234.0, "height": 190.0}
_BASE_DIGIT = {"x": 1434.0, "y": 463.0, "width": 22.0, "height": 34.0, "slant": 5.0, "step": 23.0}
SLOT_TEXT_OUTLINE_MARGIN = 3
SLOT_TEXT_OUTLINE_WEIGHT = 0.32
SLOT_COUNT_BOTTOM_GAP_TARGET = 4.0
SLOT_COUNT_Y_OFFSET_CONFLICT_CONF_MARGIN = 0.06
SLOT_COUNT_56_HOLE_RATIO_THRESHOLD = 0.045
SLOT_COUNT_56_HOLE_SOFT_MIN_SCORE = 0.72
SLOT_COUNT_56_HOLE_SOFT_MIN_MARGIN = 0.018
SLOT_COUNT_CONFUSION_PAIR_WEIGHT = 0.07
SLOT_COUNT_CONFUSION_PAIRS = frozenset({
    tuple(sorted(pair))
    for pair in (
        ("5", "6"),
        ("3", "8"),
        ("0", "6"),
        ("0", "8"),
        ("8", "9"),
        ("1", "7"),
        ("3", "5"),
        ("4", "9"),
        ("6", "8"),
    )
})
K_SUFFIX_DIGIT_LEFT_SHIFT_PX = 6

@dataclass(frozen=True)
class SlotCountResult:
    value: str | None
    confidence: float
    reason: str = ""
    raw: str = ""
    y_offset_px: int = 0


@dataclass(frozen=True)
class SlotGlyphFeature:
    text: Image.Image
    outline: Image.Image
    method: str = "outline"


@dataclass(frozen=True)
class SlotCountYOffsetEstimate:
    y_offset_px: int | None
    confidence: float = 0.0
    sample_count: int = 0
    mean_bottom_gap: float = 0.0
    bottom_gap_spread: float = 0.0
    candidates: tuple[dict, ...] = ()


@dataclass(frozen=True)
class PreparedBinaryArray:
    arr: np.ndarray
    flat: np.ndarray
    total: float
    centered: np.ndarray
    norm: float


@dataclass(frozen=True)
class PreparedBinaryMask:
    image: Image.Image
    native: PreparedBinaryArray
    canonical: PreparedBinaryArray | None
    glyph: np.ndarray | None


@dataclass
class PreparedFeatureMask:
    image: Image.Image
    binary_u8: np.ndarray
    canonical: PreparedBinaryArray | None
    glyph: np.ndarray | None
    shifted_by_size: dict[tuple[int, int], tuple[PreparedBinaryArray, ...]] = field(default_factory=dict)


@dataclass(frozen=True)
class SlotPreparedTemplate:
    value: str
    name: str
    image: Image.Image
    position: int | None
    text: PreparedBinaryMask
    outline: PreparedBinaryMask


def _expand_slot_count_value(digits: str, suffix: str | None = None) -> str:
    return digits


def _region_box(region: dict, image_size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = image_size
    return (
        int(round(float(region["x1"]) * width)),
        int(round(float(region["y1"]) * height)),
        int(round(float(region["x2"]) * width)),
        int(round(float(region["y2"]) * height)),
    )


def _save_debug_image(path: Path, image: Image.Image, *, scale: int = 1) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = image.convert("L")
    if scale > 1:
        out = out.resize((out.width * scale, out.height * scale), Image.Resampling.NEAREST)
    out.save(path)


def _debug_slot_overlay(image: Image.Image, slot: dict) -> Image.Image:
    crop = image.crop(_region_box(slot, image.size)).convert("RGBA")
    overlay = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    slot_box = _region_box(slot, image.size)
    slot_w = max(1, slot_box[2] - slot_box[0])
    slot_h = max(1, slot_box[3] - slot_box[1])
    for position, points in enumerate(_DIGIT_RELATIVE_POINTS):
        local = [(rel_x * slot_w, rel_y * slot_h) for rel_x, rel_y in points]
        draw.polygon(local, outline=(255, 70, 210, 230))
        draw.text((local[3][0] + 1, local[3][1] + 1), str(position), fill=(255, 255, 255, 255))
    return Image.alpha_composite(crop, overlay).convert("RGB")


def _parse_hex_color(value: str) -> tuple[int, int, int] | None:
    text = (value or "").strip()
    if not text:
        return None
    if not text.startswith("#"):
        text = "#" + text
    if len(text) == 4:
        text = "#" + "".join(ch * 2 for ch in text[1:])
    if len(text) != 7:
        return None
    try:
        return int(text[1:3], 16), int(text[3:5], 16), int(text[5:7], 16)
    except ValueError:
        return None


def _digit_relative_points(position: int) -> tuple[tuple[float, float], ...]:
    x = _BASE_DIGIT["x"] + _BASE_DIGIT["step"] * position
    y = _BASE_DIGIT["y"]
    w = _BASE_DIGIT["width"]
    h = _BASE_DIGIT["height"]
    slant = _BASE_DIGIT["slant"]
    points = (
        (x + slant, y),
        (x + w + slant, y),
        (x + w, y + h),
        (x, y + h),
    )
    return tuple(
        (
            (px - _BASE_SLOT["x"]) / _BASE_SLOT["width"],
            (py - _BASE_SLOT["y"]) / _BASE_SLOT["height"],
        )
        for px, py in points
    )


_DIGIT_RELATIVE_POINTS = tuple(_digit_relative_points(position) for position in range(6))


@lru_cache(maxsize=1)
def _load_slot_template_masks() -> tuple[tuple[str, str, Image.Image], ...]:
    entries: list[tuple[str, str, Image.Image]] = []
    if not SLOT_COUNT_TEMPLATE_DIR.exists():
        return ()
    for path in sorted(SLOT_COUNT_TEMPLATE_DIR.glob("*/*.png")):
        value = path.parent.name
        if value not in ALLOWED_VALUES:
            continue
        try:
            image = Image.open(path).convert("L")
        except Exception:
            continue
        entries.append((value, path.name, image))
    return tuple(entries)


def has_slot_count_templates() -> bool:
    return bool(_load_slot_template_masks())


def _outline_kernel(margin: int) -> np.ndarray:
    size = max(1, margin * 2 + 1)
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (size, size))


def _outline_from_screen(text: np.ndarray, white: np.ndarray, margin: int) -> np.ndarray:
    if margin <= 0 or not np.any(text):
        return np.zeros_like(text)
    dilated = cv2.dilate(text, _outline_kernel(margin), iterations=1)
    return np.where((dilated > 0) & (text == 0) & (white > 0), 255, 0).astype(np.uint8)


def _outline_from_template(mask: Image.Image, margin: int = SLOT_TEXT_OUTLINE_MARGIN) -> Image.Image:
    arr = ((np.array(mask.convert("L"), dtype=np.uint8) > 0).astype(np.uint8)) * 255
    if margin <= 0 or not np.any(arr):
        return Image.fromarray(np.zeros_like(arr))
    dilated = cv2.dilate(arr, _outline_kernel(margin), iterations=1)
    outline = np.where((dilated > 0) & (arr == 0), 255, 0).astype(np.uint8)
    return Image.fromarray(outline)


def _extract_outline_text(
    crop: Image.Image,
    *,
    white_threshold: int,
    black_threshold: int,
    dilate: int,
) -> tuple[SlotGlyphFeature, int]:
    arr = np.array(crop.convert("RGB"), dtype=np.uint8)
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    maxc = arr.max(axis=2)
    minc = arr.min(axis=2)
    saturation_span = maxc.astype(np.int16) - minc.astype(np.int16)

    white = ((gray >= white_threshold) & (saturation_span <= 55)).astype(np.uint8) * 255
    black = (gray <= black_threshold).astype(np.uint8) * 255
    if dilate > 0:
        kernel_size = dilate * 2 + 1
        near_white = cv2.dilate(white, np.ones((kernel_size, kernel_size), np.uint8), iterations=1)
    else:
        near_white = white
    text = cv2.bitwise_and(black, near_white)
    text = cv2.morphologyEx(text, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))

    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(text, 8)
    cleaned = np.zeros_like(text)
    for label in range(1, count):
        area = int(stats[label, cv2.CC_STAT_AREA])
        w = int(stats[label, cv2.CC_STAT_WIDTH])
        h = int(stats[label, cv2.CC_STAT_HEIGHT])
        if area >= 4 and h >= 4 and w >= 2:
            cleaned[labels == label] = 255
    outline = _outline_from_screen(cleaned, white, SLOT_TEXT_OUTLINE_MARGIN)
    return SlotGlyphFeature(Image.fromarray(cleaned), Image.fromarray(outline), "outline"), int(np.count_nonzero(cleaned))



def _clean_color_text_mask(text: np.ndarray) -> tuple[SlotGlyphFeature, int]:
    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(text, 8)
    cleaned = np.zeros_like(text)
    for label in range(1, count):
        area = int(stats[label, cv2.CC_STAT_AREA])
        w = int(stats[label, cv2.CC_STAT_WIDTH])
        h = int(stats[label, cv2.CC_STAT_HEIGHT])
        if area >= 3 and h >= 3 and w >= 1:
            cleaned[labels == label] = 255
    text_image = Image.fromarray(cleaned)
    outline = _outline_from_template(text_image, SLOT_TEXT_OUTLINE_MARGIN)
    return SlotGlyphFeature(text_image, outline, "color"), int(np.count_nonzero(cleaned))


def _extract_color_text(
    crop: Image.Image,
    *,
    target_rgb: tuple[int, int, int],
    tolerance_percent: float,
) -> tuple[SlotGlyphFeature, int]:
    arr = np.array(crop.convert("RGB"), dtype=np.uint8)
    target = np.array(target_rgb, dtype=np.int16)
    diff = arr.astype(np.int16) - target.reshape(1, 1, 3)
    diff32 = diff.astype(np.int32)
    distance = np.sqrt(np.sum(diff32 * diff32, axis=2))
    threshold = max(0.0, float(tolerance_percent)) / 100.0 * RGB_CUBE_DISTANCE
    text = (distance <= threshold + 1e-6).astype(np.uint8) * 255
    return _clean_color_text_mask(text)


def _normalize_color_filter_mode(mode: str) -> str:
    normalized = (mode or COLOR_FILTER_MODE_EXACT).strip().lower().replace("-", "_")
    if normalized in {"dark", "ink", "darkink", COLOR_FILTER_MODE_DARK_INK}:
        return COLOR_FILTER_MODE_DARK_INK
    return COLOR_FILTER_MODE_EXACT


def _build_dark_ink_mask_array(arr: np.ndarray) -> np.ndarray:
    rgb = arr.astype(np.float32)
    r = rgb[:, :, 0]
    g = rgb[:, :, 1]
    b = rgb[:, :, 2]
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    value = np.maximum.reduce((r, g, b))
    chroma = value - np.minimum.reduce((r, g, b))

    bg_luma = float(np.percentile(luma, 82.0)) if luma.size else 255.0
    local_dark_limit = min(138.0, max(72.0, bg_luma - 34.0))
    local_contrast = bg_luma - luma

    dark_enough = (luma <= local_dark_limit) & (value <= 166.0) & (local_contrast >= 22.0)
    navy_bias = (b >= r + 4.0) & (g >= r - 8.0) & ((b + g) >= (2.0 * r + 14.0))
    neutral_dark_ink = (luma <= 82.0) & (value <= 124.0) & (chroma <= 72.0)
    mask = dark_enough & (navy_bias | neutral_dark_ink)
    return mask.astype(np.uint8) * 255

def _build_subtractor_color_mask(
    image: Image.Image,
    slot: dict,
    *,
    target_rgb: tuple[int, int, int],
    tolerance_percent: float,
    mode: str = COLOR_FILTER_MODE_EXACT,
) -> tuple[Image.Image, int]:
    box = _region_box(slot, image.size)
    left, top, right, bottom = box
    if right <= left or bottom <= top:
        return Image.new("L", image.size, 0), 0
    crop = image.crop(box).convert("RGB")
    arr = np.asarray(crop, dtype=np.uint8)
    if _normalize_color_filter_mode(mode) == COLOR_FILTER_MODE_DARK_INK:
        mask_arr = _build_dark_ink_mask_array(arr)
    else:
        target = np.asarray(target_rgb, dtype=np.int16)
        diff = arr.astype(np.int16) - target.reshape(1, 1, 3)
        diff32 = diff.astype(np.int32)
        distance = np.sqrt(np.sum(diff32 * diff32, axis=2))
        threshold = max(0.0, float(tolerance_percent)) / 100.0 * RGB_CUBE_DISTANCE
        mask_arr = (distance <= threshold + 1e-6).astype(np.uint8) * 255
    mask = Image.new("L", image.size, 0)
    mask.paste(Image.fromarray(mask_arr, "L"), (left, top))
    return mask, int(np.count_nonzero(mask_arr))


def _warp_mask_quad(mask: Image.Image, payload: dict) -> Image.Image | None:
    points = payload.get("points_ratio") or []
    if len(points) != 4:
        return None

    width, height = mask.size
    src_points = [
        (float(point["x"]) * width, float(point["y"]) * height)
        for point in points
    ]
    top_left, top_right, bottom_right, bottom_left = src_points
    top_width = np.hypot(top_right[0] - top_left[0], top_right[1] - top_left[1])
    bottom_width = np.hypot(bottom_right[0] - bottom_left[0], bottom_right[1] - bottom_left[1])
    left_height = np.hypot(bottom_left[0] - top_left[0], bottom_left[1] - top_left[1])
    right_height = np.hypot(bottom_right[0] - top_right[0], bottom_right[1] - top_right[1])
    dst_w = max(1, int(round(max(top_width, bottom_width))))
    dst_h = max(1, int(round(max(left_height, right_height))))

    border = 1
    crop_left = max(0, int(np.floor(min(point[0] for point in src_points))) - border)
    crop_top = max(0, int(np.floor(min(point[1] for point in src_points))) - border)
    crop_right = min(width, int(np.ceil(max(point[0] for point in src_points))) + border + 1)
    crop_bottom = min(height, int(np.ceil(max(point[1] for point in src_points))) + border + 1)
    if crop_right <= crop_left or crop_bottom <= crop_top:
        return None

    local_points = [(point[0] - crop_left, point[1] - crop_top) for point in src_points]
    src = np.asarray(local_points, dtype=np.float32)
    dst = np.asarray(
        ((0, 0), (dst_w - 1, 0), (dst_w - 1, dst_h - 1), (0, dst_h - 1)),
        dtype=np.float32,
    )
    matrix = cv2.getPerspectiveTransform(src, dst)
    crop = np.asarray(mask.crop((crop_left, crop_top, crop_right, crop_bottom)).convert("L"), dtype=np.uint8)
    warped = cv2.warpPerspective(crop, matrix, (dst_w, dst_h), flags=cv2.INTER_NEAREST)
    return Image.fromarray(warped.astype(np.uint8), "L")


def _extract_color_text_from_subtractor_mask(
    slot_color_mask: Image.Image,
    payload: dict,
) -> tuple[SlotGlyphFeature, int, int]:
    warped = _warp_mask_quad(slot_color_mask, payload)
    if warped is None:
        empty = Image.new("L", (1, 1), 0)
        return SlotGlyphFeature(empty, empty, "color"), 0, 0
    raw_pixels = int(np.count_nonzero(np.asarray(warped, dtype=np.uint8)))
    feature, clean_pixels = _clean_color_text_mask(np.asarray(warped, dtype=np.uint8))
    return feature, clean_pixels, raw_pixels

def _extract_reference_color_text(
    image: Image.Image,
    payload: dict,
    *,
    target_rgb: tuple[int, int, int],
    tolerance_percent: float,
) -> tuple[SlotGlyphFeature, int, int]:
    points = payload.get("points_ratio") or []
    if len(points) != 4:
        empty = Image.new("L", (1, 1), 0)
        return SlotGlyphFeature(empty, empty, "color"), 0, 0

    width, height = image.size
    src_points = [
        (float(point["x"]) * width, float(point["y"]) * height)
        for point in points
    ]
    top_left, top_right, bottom_right, bottom_left = src_points
    top_width = np.hypot(top_right[0] - top_left[0], top_right[1] - top_left[1])
    bottom_width = np.hypot(bottom_right[0] - bottom_left[0], bottom_right[1] - bottom_left[1])
    left_height = np.hypot(bottom_left[0] - top_left[0], bottom_left[1] - top_left[1])
    right_height = np.hypot(bottom_right[0] - top_right[0], bottom_right[1] - top_right[1])
    dst_w = max(1, int(round(max(top_width, bottom_width))))
    dst_h = max(1, int(round(max(left_height, right_height))))

    border = 1
    crop_left = max(0, int(np.floor(min(point[0] for point in src_points))) - border)
    crop_top = max(0, int(np.floor(min(point[1] for point in src_points))) - border)
    crop_right = min(width, int(np.ceil(max(point[0] for point in src_points))) + border + 1)
    crop_bottom = min(height, int(np.ceil(max(point[1] for point in src_points))) + border + 1)
    if crop_right <= crop_left or crop_bottom <= crop_top:
        empty = Image.new("L", (1, 1), 0)
        return SlotGlyphFeature(empty, empty, "color"), 0, 0

    local_points = [(point[0] - crop_left, point[1] - crop_top) for point in src_points]
    src = np.asarray(local_points, dtype=np.float32)
    dst = np.asarray(
        ((0, 0), (dst_w - 1, 0), (dst_w - 1, dst_h - 1), (0, dst_h - 1)),
        dtype=np.float32,
    )
    matrix = cv2.getPerspectiveTransform(src, dst)

    crop = image.crop((crop_left, crop_top, crop_right, crop_bottom)).convert("RGB")
    arr = np.asarray(crop, dtype=np.uint8)
    target = np.asarray(target_rgb, dtype=np.int16)
    diff = arr.astype(np.int16) - target.reshape(1, 1, 3)
    diff32 = diff.astype(np.int32)
    distance = np.sqrt(np.sum(diff32 * diff32, axis=2))
    threshold = max(0.0, float(tolerance_percent)) / 100.0 * RGB_CUBE_DISTANCE
    source_mask = (distance <= threshold + 1e-6).astype(np.uint8) * 255
    roi_mask = np.zeros_like(source_mask, dtype=np.uint8)
    cv2.fillPoly(roi_mask, [np.asarray(local_points, dtype=np.int32)], 255)
    source_mask = cv2.bitwise_and(source_mask, roi_mask)
    raw_pixels = int(np.count_nonzero(source_mask))
    warped = cv2.warpPerspective(source_mask, matrix, (dst_w, dst_h), flags=cv2.INTER_NEAREST)
    feature, clean_pixels = _clean_color_text_mask(warped.astype(np.uint8))
    return feature, clean_pixels, raw_pixels


def _binary_uint8(img: Image.Image) -> np.ndarray:
    return ((np.asarray(img.convert("L"), dtype=np.uint8) > 0).astype(np.uint8)) * 255


def _binary_mask_array(img: Image.Image, size: tuple[int, int]) -> np.ndarray:
    binary = _binary_uint8(img)
    return _binary_mask_array_from_uint8(binary, size)


def _binary_mask_array_from_uint8(binary: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    width, height = size
    if binary.shape == (height, width):
        resized = binary
    else:
        resized = cv2.resize(binary, (width, height), interpolation=cv2.INTER_NEAREST)
    return (resized > 0).astype(np.float32)


def _prepare_binary_array(arr: np.ndarray) -> PreparedBinaryArray:
    binary = (arr > 0).astype(np.float32)
    flat = binary.reshape(-1)
    total = float(flat.sum())
    if total <= 0:
        centered = flat.copy()
        norm = 0.0
    else:
        centered = flat - float(flat.mean())
        norm = float(np.linalg.norm(centered))
    return PreparedBinaryArray(binary, flat, total, centered, norm)


def _score_prepared_arrays(a: PreparedBinaryArray, b: PreparedBinaryArray) -> float:
    if a.total <= 0 or b.total <= 0:
        return 0.0
    inter = float(np.dot(a.flat, b.flat))
    union = a.total + b.total - inter
    iou = inter / union if union > 1e-6 else 0.0
    denom = a.norm * b.norm
    corr = float(np.dot(a.centered, b.centered) / denom) if denom > 1e-6 else 0.0
    return max(0.0, min(1.0, (iou * 0.55) + (((corr + 1.0) / 2.0) * 0.45)))


def _score_binary_arrays(a: np.ndarray, b: np.ndarray) -> float:
    return _score_prepared_arrays(_prepare_binary_array(a), _prepare_binary_array(b))


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
    arr = np.asarray(img.convert("L"), dtype=np.uint8)
    ys, xs = np.nonzero(arr > 0)
    if len(xs) == 0 or len(ys) == 0:
        return None
    x1 = max(0, int(xs.min()) - pad)
    x2 = min(arr.shape[1], int(xs.max()) + pad + 1)
    y1 = max(0, int(ys.min()) - pad)
    y2 = min(arr.shape[0], int(ys.max()) + pad + 1)
    return Image.fromarray(arr[y1:y2, x1:x2])


def _prepare_binary_mask(img: Image.Image) -> PreparedBinaryMask:
    binary = _binary_uint8(img)
    native = _prepare_binary_array(_binary_mask_array_from_uint8(binary, img.size))
    glyph = normalize_binary_glyph(binary, output_size=(24, 32), padding=2)
    trimmed = _trim_mask(Image.fromarray(binary))
    canonical = None
    if trimmed is not None:
        canonical = _prepare_binary_array(_binary_mask_array(trimmed, (24, 34)))
    return PreparedBinaryMask(img, native, canonical, glyph)


def _prepare_feature_mask(img: Image.Image) -> PreparedFeatureMask:
    binary = _binary_uint8(img)
    glyph = normalize_binary_glyph(binary, output_size=(24, 32), padding=2)
    trimmed = _trim_mask(Image.fromarray(binary))
    canonical = None
    if trimmed is not None:
        canonical = _prepare_binary_array(_binary_mask_array(trimmed, (24, 34)))
    return PreparedFeatureMask(img, binary, canonical, glyph)


def _feature_shifted_arrays(feature: PreparedFeatureMask, size: tuple[int, int]) -> tuple[PreparedBinaryArray, ...]:
    cached = feature.shifted_by_size.get(size)
    if cached is not None:
        return cached
    base = _binary_mask_array_from_uint8(feature.binary_u8, size)
    shifted = tuple(
        _prepare_binary_array(_shift_binary_array(base, dx, dy))
        for dy in range(-2, 3)
        for dx in range(-2, 3)
    )
    feature.shifted_by_size[size] = shifted
    return shifted


def _best_shifted_feature_for_template(
    feature: PreparedFeatureMask,
    template: SlotPreparedTemplate,
) -> PreparedBinaryArray | None:
    best: PreparedBinaryArray | None = None
    best_score = -1.0
    for shifted in _feature_shifted_arrays(feature, template.text.image.size):
        score = _score_prepared_arrays(shifted, template.text.native)
        if score > best_score:
            best_score = score
            best = shifted
    return best


def _synthetic_alpha_template_for_pair(
    templates: tuple[SlotPreparedTemplate, ...],
    value: str,
    position: int,
) -> SlotPreparedTemplate | None:
    expected_name = f"synthetic_alpha_pos{position}_{value}.png"
    for template in templates:
        if template.name == expected_name:
            return template
    return None


def _confusion_pair_exclusive_evidence(
    feature: PreparedFeatureMask,
    templates: tuple[SlotPreparedTemplate, ...],
    value: str,
    other_value: str,
    position: int,
) -> float:
    value_template = _synthetic_alpha_template_for_pair(templates, value, position)
    other_template = _synthetic_alpha_template_for_pair(templates, other_value, position)
    if value_template is None or other_template is None:
        return 0.0
    shifted = _best_shifted_feature_for_template(feature, value_template)
    if shifted is None:
        return 0.0

    value_mask = value_template.text.native.arr > 0
    other_mask = other_template.text.native.arr > 0
    input_mask = shifted.arr > 0
    value_only = value_mask & ~other_mask
    other_only = other_mask & ~value_mask
    if int(value_only.sum()) < 2 or int(other_only.sum()) < 2:
        return 0.0
    value_coverage = float(input_mask[value_only].mean())
    other_coverage = float(input_mask[other_only].mean())
    return value_coverage - other_coverage


def _adjust_confusion_pair_scores(
    top: list[tuple[str, str, float]],
    *,
    feature: PreparedFeatureMask,
    templates: tuple[SlotPreparedTemplate, ...],
    position: int | None,
    method: str,
) -> list[tuple[str, str, float]]:
    if method != "color" or position is None or len(top) < 2:
        return top
    first_value, first_name, first_score = top[0]
    second_value, second_name, second_score = top[1]
    if not (first_value.isdigit() and second_value.isdigit()):
        return top
    if tuple(sorted((first_value, second_value))) not in SLOT_COUNT_CONFUSION_PAIRS:
        return top

    first_evidence = _confusion_pair_exclusive_evidence(
        feature,
        templates,
        first_value,
        second_value,
        position,
    )
    second_evidence = _confusion_pair_exclusive_evidence(
        feature,
        templates,
        second_value,
        first_value,
        position,
    )
    adjusted = list(top)
    adjusted[0] = (first_value, first_name, first_score + SLOT_COUNT_CONFUSION_PAIR_WEIGHT * first_evidence)
    adjusted[1] = (second_value, second_name, second_score + SLOT_COUNT_CONFUSION_PAIR_WEIGHT * second_evidence)
    adjusted.sort(key=lambda row: row[2], reverse=True)
    return adjusted

def _prepared_mask_similarity(feature: PreparedFeatureMask, template: PreparedBinaryMask) -> float:
    full = 0.0
    for shifted in _feature_shifted_arrays(feature, template.image.size):
        full = max(full, _score_prepared_arrays(shifted, template.native))

    glyph = 0.0
    if feature.glyph is not None and template.glyph is not None:
        glyph = binary_glyph_similarity(feature.glyph, template.glyph)

    canonical = 0.0
    if feature.canonical is not None and template.canonical is not None:
        canonical = _score_prepared_arrays(feature.canonical, template.canonical)
    return max(full, glyph, canonical)


def _mask_similarity(a: Image.Image, b: Image.Image) -> float:
    return _prepared_mask_similarity(_prepare_feature_mask(a), _prepare_binary_mask(b))


def _feature_similarity(feature: SlotGlyphFeature, template: SlotPreparedTemplate) -> float:
    text_feature = _prepare_feature_mask(feature.text)
    text_score = _prepared_mask_similarity(text_feature, template.text)
    if feature.method == "color":
        return text_score
    outline_feature = _prepare_feature_mask(feature.outline)
    outline_score = _prepared_mask_similarity(outline_feature, template.outline)
    return (1.0 - SLOT_TEXT_OUTLINE_WEIGHT) * text_score + SLOT_TEXT_OUTLINE_WEIGHT * outline_score


@lru_cache(maxsize=1)
def _load_prepared_slot_template_masks() -> tuple[SlotPreparedTemplate, ...]:
    prepared: list[SlotPreparedTemplate] = []
    for value, name, image in _load_slot_template_masks():
        prepared.append(
            SlotPreparedTemplate(
                value=value,
                name=name,
                image=image,
                position=_template_position(name),
                text=_prepare_binary_mask(image),
                outline=_prepare_binary_mask(_outline_from_template(image)),
            )
        )
    return tuple(prepared)


def _template_position(name: str) -> int | None:
    match = re.search(r"(?:_digit_|_pos)([0-5])(?:_|\.)", name)
    if match:
        return int(match.group(1))
    if name.startswith("synthetic_digit5_"):
        return 5
    return None


def _template_matches_feature(name: str, feature: SlotGlyphFeature) -> bool:
    # Font-rendered masks are tuned for the studio color-filter result.  When a
    # capture falls back to outline extraction, keep the empirical templates as
    # the comparison set so synthetic masks do not dilute the margin.
    if feature.method != "color" and name.startswith("font_gyeonggi"):
        return False
    return True



def _digit_lower_hole_metrics(mask: Image.Image) -> dict:
    binary = _binary_uint8(mask)
    ys, xs = np.where(binary > 0)
    if len(xs) == 0:
        return {"lower_hole_ratio": 0.0, "lower_hole_area": 0, "has_lower_hole": False}

    x1 = max(0, int(xs.min()) - 1)
    x2 = min(binary.shape[1], int(xs.max()) + 2)
    y1 = max(0, int(ys.min()) - 1)
    y2 = min(binary.shape[0], int(ys.max()) + 2)
    roi = binary[y1:y2, x1:x2]
    if roi.size == 0:
        return {"lower_hole_ratio": 0.0, "lower_hole_area": 0, "has_lower_hole": False}

    roi = cv2.copyMakeBorder(roi, 2, 2, 2, 2, cv2.BORDER_CONSTANT, value=0)
    kernel = np.ones((2, 2), np.uint8)
    closed = cv2.morphologyEx(roi, cv2.MORPH_CLOSE, kernel, iterations=1)
    background = np.where(closed > 0, 0, 255).astype(np.uint8)
    flood = background.copy()
    height, width = flood.shape
    flood_mask = np.zeros((height + 2, width + 2), np.uint8)
    cv2.floodFill(flood, flood_mask, (0, 0), 128)
    holes = np.where(flood == 255, 255, 0).astype(np.uint8)

    count, labels, stats, centroids = cv2.connectedComponentsWithStats(holes, 8)
    bbox_area = max(1, (height - 4) * (width - 4))
    best_area = 0
    best_ratio = 0.0
    best_center_y = 0.0
    for label in range(1, count):
        area = int(stats[label, cv2.CC_STAT_AREA])
        if area < 4:
            continue
        x = int(stats[label, cv2.CC_STAT_LEFT])
        y = int(stats[label, cv2.CC_STAT_TOP])
        w = int(stats[label, cv2.CC_STAT_WIDTH])
        h = int(stats[label, cv2.CC_STAT_HEIGHT])
        if x <= 0 or y <= 0 or x + w >= width or y + h >= height:
            continue
        center_y = float(centroids[label][1]) / float(max(1, height))
        if center_y < 0.35:
            continue
        ratio = float(area) / float(bbox_area)
        if area > best_area:
            best_area = area
            best_ratio = ratio
            best_center_y = center_y

    return {
        "lower_hole_ratio": best_ratio,
        "lower_hole_area": best_area,
        "lower_hole_center_y": best_center_y,
        "has_lower_hole": best_ratio >= SLOT_COUNT_56_HOLE_RATIO_THRESHOLD,
    }

def _classify_mask(
    feature: SlotGlyphFeature,
    templates: tuple[SlotPreparedTemplate, ...],
    *,
    allowed_values: frozenset[str] | None = None,
    position: int | None = None,
) -> list[tuple[str, str, float]]:
    text_feature = _prepare_feature_mask(feature.text)
    outline_feature = None if feature.method == "color" else _prepare_feature_mask(feature.outline)

    def score_template(template: SlotPreparedTemplate) -> float:
        text_score = _prepared_mask_similarity(text_feature, template.text)
        if outline_feature is None:
            return text_score
        outline_score = _prepared_mask_similarity(outline_feature, template.outline)
        return (1.0 - SLOT_TEXT_OUTLINE_WEIGHT) * text_score + SLOT_TEXT_OUTLINE_WEIGHT * outline_score

    scored = [
        (template.value, template.name, score_template(template))
        for template in templates
        if (allowed_values is None or template.value in allowed_values)
        and (position is None or template.position in (None, position))
        and _template_matches_feature(template.name, feature)
    ]
    scored.sort(key=lambda row: row[2], reverse=True)
    collapsed: dict[str, tuple[str, str, float]] = {}
    for value, name, score in scored:
        if value not in collapsed:
            collapsed[value] = (value, name, score)
    top = sorted(collapsed.values(), key=lambda row: row[2], reverse=True)[:5]
    return _adjust_confusion_pair_scores(
        top,
        feature=text_feature,
        templates=templates,
        position=position,
        method=feature.method,
    )

def _shift_slot_y_for_count(slot: dict, y_offset_px: int, image_height: int) -> dict:
    if not y_offset_px or image_height <= 0:
        return slot
    shifted = dict(slot)
    delta = float(y_offset_px) / float(image_height)
    for key in ("y1", "y2"):
        if key in shifted:
            shifted[key] = float(shifted[key]) + delta
    return shifted


def _slot_count_y_offset_candidates(center: int, radius: int) -> list[int]:
    radius = max(0, int(radius))
    center = max(-radius, min(radius, int(center)))
    candidates = [center]
    for step in range(1, radius + 1):
        candidates.extend((center - step, center + step))
    deduped: list[int] = []
    for candidate in candidates:
        if -radius <= candidate <= radius and candidate not in deduped:
            deduped.append(candidate)
    return deduped

def _digit_region(
    slot: dict,
    position: int,
    image_size: tuple[int, int],
    *,
    x_offset_px: int = 0,
) -> dict:
    width, height = image_size
    slot_x1 = float(slot["x1"]) * width
    slot_y1 = float(slot["y1"]) * height
    slot_w = (float(slot["x2"]) - float(slot["x1"])) * width
    slot_h = (float(slot["y2"]) - float(slot["y1"])) * height
    return {
        "points_ratio": [
            {
                "x": (slot_x1 + rel_x * slot_w + x_offset_px) / width,
                "y": (slot_y1 + rel_y * slot_h) / height,
            }
            for rel_x, rel_y in _DIGIT_RELATIVE_POINTS[position]
        ]
    }


def _uses_k_suffix_layout(
    *,
    nonblank_count: int,
    terminal_digit_accepted: bool,
    terminal_k_accepted: bool,
) -> bool:
    """Return whether the complete count run should use the K-shifted ROIs."""
    return bool(
        nonblank_count >= 3
        and (terminal_k_accepted or not terminal_digit_accepted)
    )


def _mask_bottom_gap(mask: Image.Image) -> int | None:
    arr = np.asarray(mask.convert("L"), dtype=np.uint8)
    ys, _xs = np.nonzero(arr > 0)
    if len(ys) == 0:
        return None
    return int(arr.shape[0] - 1 - int(ys.max()))


def _prefilter_y_offset_candidates_by_bottom_gap(
    image: Image.Image,
    slot: dict,
    candidates: list[int],
    *,
    target_rgb: tuple[int, int, int],
    tolerance_percent: float,
    color_filter_mode: str = COLOR_FILTER_MODE_DARK_INK,
    color_blank_text_threshold: int = 8,
    target_gap: float = SLOT_COUNT_BOTTOM_GAP_TARGET,
    keep: int = 2,
) -> tuple[list[int], list[dict]]:
    ranked: list[tuple[float, int, dict]] = []
    for candidate in candidates:
        effective_slot = _shift_slot_y_for_count(slot, candidate, image.size[1])
        slot_color_mask, slot_color_pixels = _build_subtractor_color_mask(
            image,
            effective_slot,
            target_rgb=target_rgb,
            tolerance_percent=tolerance_percent,
            mode=color_filter_mode,
        )
        gaps: list[int] = []
        clean_pixels: list[int] = []
        for position in range(6):
            feature, clean, _raw = _extract_color_text_from_subtractor_mask(
                slot_color_mask,
                _digit_region(effective_slot, position, image.size),
            )
            clean_pixels.append(clean)
            if clean < color_blank_text_threshold:
                continue
            gap = _mask_bottom_gap(feature.text)
            if gap is not None:
                gaps.append(gap)
        if len(gaps) < 3:
            continue
        median_gap = float(np.median(np.asarray(gaps, dtype=np.float32)))
        spread = float(np.std(np.asarray(gaps, dtype=np.float32))) if len(gaps) > 1 else 0.0
        penalty = abs(median_gap - target_gap) + min(1.0, spread * 0.15)
        detail = {
            "y_offset_px": candidate,
            "slot_color_pixels": slot_color_pixels,
            "sample_count": len(gaps),
            "median_bottom_gap": round(median_gap, 3),
            "bottom_gap_spread": round(spread, 3),
            "penalty": round(penalty, 3),
            "clean_pixels": clean_pixels,
        }
        ranked.append((penalty, abs(candidate), detail))
    if not ranked:
        return candidates, []
    ranked.sort(key=lambda row: (row[0], row[1]))
    details = [row[2] for row in ranked]
    if ranked[0][0] > 1.25:
        return candidates, details
    selected: list[int] = []
    for _penalty, _distance, detail in ranked:
        candidate = int(detail["y_offset_px"])
        if candidate not in selected:
            selected.append(candidate)
        if len(selected) >= max(1, keep):
            break
    return selected, details


def estimate_item_slot_count_row_y_offset(
    image: Image.Image,
    slots: list[dict] | tuple[dict, ...],
    *,
    center: int = 0,
    radius: int = 2,
    color_filter_hex: str = "#2D4663",
    color_filter_tolerance_percent: float = 1.0,
    color_filter_mode: str = COLOR_FILTER_MODE_DARK_INK,
    color_blank_text_threshold: int = 8,
    target_gap: float = SLOT_COUNT_BOTTOM_GAP_TARGET,
    min_samples: int = 8,
) -> SlotCountYOffsetEstimate:
    """Estimate count ROI y-offset from the row's average lower text gap."""
    if not slots:
        return SlotCountYOffsetEstimate(None)
    target_rgb = _parse_hex_color(color_filter_hex) or SLOT_TEXT_COLOR
    candidates = _slot_count_y_offset_candidates(center, radius)
    ranked: list[tuple[float, int, dict]] = []
    for candidate in candidates:
        gaps: list[int] = []
        slot_sample_count = 0
        for slot in slots:
            effective_slot = _shift_slot_y_for_count(slot, candidate, image.size[1])
            slot_color_mask, slot_color_pixels = _build_subtractor_color_mask(
                image,
                effective_slot,
                target_rgb=target_rgb,
                tolerance_percent=color_filter_tolerance_percent,
                mode=color_filter_mode,
            )
            if slot_color_pixels < color_blank_text_threshold:
                continue
            slot_has_sample = False
            for position in range(6):
                feature, clean, _raw = _extract_color_text_from_subtractor_mask(
                    slot_color_mask,
                    _digit_region(effective_slot, position, image.size),
                )
                if clean < color_blank_text_threshold:
                    continue
                gap = _mask_bottom_gap(feature.text)
                if gap is None:
                    continue
                gaps.append(gap)
                slot_has_sample = True
            if slot_has_sample:
                slot_sample_count += 1
        if len(gaps) < min_samples:
            continue
        arr = np.asarray(gaps, dtype=np.float32)
        mean_gap = float(np.mean(arr))
        spread = float(np.std(arr)) if len(gaps) > 1 else 0.0
        penalty = abs(mean_gap - target_gap) + min(1.0, spread * 0.15)
        confidence = max(0.0, min(1.0, 1.0 - (penalty / 2.5))) * min(1.0, len(gaps) / 20.0)
        detail = {
            "y_offset_px": candidate,
            "sample_count": len(gaps),
            "slot_sample_count": slot_sample_count,
            "mean_bottom_gap": round(mean_gap, 3),
            "bottom_gap_spread": round(spread, 3),
            "penalty": round(penalty, 3),
            "confidence": round(confidence, 3),
        }
        ranked.append((penalty, abs(candidate - int(center)), detail))
    if not ranked:
        return SlotCountYOffsetEstimate(None)
    ranked.sort(key=lambda row: (row[0], row[1]))
    details = tuple(row[2] for row in ranked)
    best = ranked[0][2]
    if float(best["penalty"]) > 1.25 or int(best["sample_count"]) < min_samples:
        return SlotCountYOffsetEstimate(None, candidates=details)
    return SlotCountYOffsetEstimate(
        int(best["y_offset_px"]),
        confidence=float(best["confidence"]),
        sample_count=int(best["sample_count"]),
        mean_bottom_gap=float(best["mean_bottom_gap"]),
        bottom_gap_spread=float(best["bottom_gap_spread"]),
        candidates=details,
    )


def read_item_slot_count(
    image: Image.Image,
    slot: dict,
    *,
    confidence_threshold: float = 0.60,
    margin_threshold: float = 0.07,
    digit_soft_confidence_threshold: float = 0.70,
    digit_soft_margin_threshold: float = 0.05,
    x_confidence_threshold: float = 0.74,
    x_margin_threshold: float = 0.12,
    x_soft_confidence_threshold: float = 0.55,
    x_soft_margin_threshold: float = 0.04,
    k_confidence_threshold: float = 0.72,
    k_margin_threshold: float = 0.10,
    blank_text_threshold: int = 80,
    white_threshold: int = 175,
    black_threshold: int = 130,
    dilate: int = 2,
    color_filter_enabled: bool = True,
    color_filter_hex: str = "#2D4663",
    color_filter_tolerance_percent: float = 0.0,
    color_filter_mode: str = COLOR_FILTER_MODE_DARK_INK,
    color_blank_text_threshold: int = 8,
    outline_fallback_enabled: bool = True,
    debug_dir: Path | None = None,
    y_offset_px: int = 0,
    y_offset_search_px: int = 0,
    y_offset_bottom_gap_prefilter_enabled: bool = True,
    y_offset_bottom_gap_prefilter_keep: int = 2,
) -> SlotCountResult:
    templates = _load_prepared_slot_template_masks()
    if not templates:
        return SlotCountResult(None, 0.0, "no_templates", y_offset_px=int(y_offset_px))

    y_offset_px = int(round(y_offset_px))
    y_offset_search_px = max(0, int(round(y_offset_search_px)))
    if y_offset_search_px > 0:
        probes: list[SlotCountResult] = []
        candidate_offsets = _slot_count_y_offset_candidates(y_offset_px, y_offset_search_px)
        all_candidate_offsets = list(candidate_offsets)
        bottom_gap_prefilter: list[dict] = []
        if color_filter_enabled and y_offset_bottom_gap_prefilter_enabled:
            candidate_offsets, bottom_gap_prefilter = _prefilter_y_offset_candidates_by_bottom_gap(
                image,
                slot,
                candidate_offsets,
                target_rgb=_parse_hex_color(color_filter_hex) or SLOT_TEXT_COLOR,
                tolerance_percent=color_filter_tolerance_percent,
                color_filter_mode=color_filter_mode,
                color_blank_text_threshold=color_blank_text_threshold,
                keep=y_offset_bottom_gap_prefilter_keep,
            )
        def _probe_offset(candidate_offset: int) -> SlotCountResult:
            return read_item_slot_count(
                image,
                slot,
                confidence_threshold=confidence_threshold,
                margin_threshold=margin_threshold,
                digit_soft_confidence_threshold=digit_soft_confidence_threshold,
                digit_soft_margin_threshold=digit_soft_margin_threshold,
                x_confidence_threshold=x_confidence_threshold,
                x_margin_threshold=x_margin_threshold,
                x_soft_confidence_threshold=x_soft_confidence_threshold,
                x_soft_margin_threshold=x_soft_margin_threshold,
                k_confidence_threshold=k_confidence_threshold,
                k_margin_threshold=k_margin_threshold,
                blank_text_threshold=blank_text_threshold,
                white_threshold=white_threshold,
                black_threshold=black_threshold,
                dilate=dilate,
                color_filter_enabled=color_filter_enabled,
                color_filter_hex=color_filter_hex,
                color_filter_tolerance_percent=color_filter_tolerance_percent,
                color_filter_mode=color_filter_mode,
                color_blank_text_threshold=color_blank_text_threshold,
                outline_fallback_enabled=outline_fallback_enabled,
                debug_dir=None,
                y_offset_px=candidate_offset,
                y_offset_search_px=0,
                y_offset_bottom_gap_prefilter_enabled=y_offset_bottom_gap_prefilter_enabled,
                y_offset_bottom_gap_prefilter_keep=y_offset_bottom_gap_prefilter_keep,
            )

        for candidate_offset in candidate_offsets:
            probes.append(_probe_offset(candidate_offset))

        if not any(result.value is not None for result in probes):
            probed_offsets = {int(result.y_offset_px) for result in probes}
            for candidate_offset in all_candidate_offsets:
                if int(candidate_offset) in probed_offsets:
                    continue
                probes.append(_probe_offset(candidate_offset))
                candidate_offsets.append(candidate_offset)
        def _probe_key(result: SlotCountResult) -> tuple[int, float, int, int]:
            return (
                1 if result.value is not None else 0,
                float(result.confidence),
                len(result.raw or ""),
                -abs(int(result.y_offset_px) - y_offset_px),
            )

        best = max(probes, key=_probe_key)
        valid_probes = [result for result in probes if result.value is not None]
        if valid_probes:
            nearest = max(
                valid_probes,
                key=lambda result: (
                    -abs(int(result.y_offset_px) - y_offset_px),
                    float(result.confidence),
                    len(result.raw or ""),
                ),
            )
            if (
                best.value != nearest.value
                and float(best.confidence) - float(nearest.confidence)
                <= SLOT_COUNT_Y_OFFSET_CONFLICT_CONF_MARGIN
            ):
                best = nearest
        if debug_dir is None:
            return best
        final = read_item_slot_count(
            image,
            slot,
            confidence_threshold=confidence_threshold,
            margin_threshold=margin_threshold,
            digit_soft_confidence_threshold=digit_soft_confidence_threshold,
            digit_soft_margin_threshold=digit_soft_margin_threshold,
            x_confidence_threshold=x_confidence_threshold,
            x_margin_threshold=x_margin_threshold,
            x_soft_confidence_threshold=x_soft_confidence_threshold,
            x_soft_margin_threshold=x_soft_margin_threshold,
            k_confidence_threshold=k_confidence_threshold,
            k_margin_threshold=k_margin_threshold,
            blank_text_threshold=blank_text_threshold,
            white_threshold=white_threshold,
            black_threshold=black_threshold,
            dilate=dilate,
            color_filter_enabled=color_filter_enabled,
            color_filter_hex=color_filter_hex,
            color_filter_tolerance_percent=color_filter_tolerance_percent,
            color_filter_mode=color_filter_mode,
            color_blank_text_threshold=color_blank_text_threshold,
            outline_fallback_enabled=outline_fallback_enabled,
            debug_dir=debug_dir,
            y_offset_px=best.y_offset_px,
            y_offset_search_px=0,
            y_offset_bottom_gap_prefilter_enabled=y_offset_bottom_gap_prefilter_enabled,
            y_offset_bottom_gap_prefilter_keep=y_offset_bottom_gap_prefilter_keep,
        )
        try:
            summary_path = debug_dir / "summary.json"
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
            summary["y_offset_search"] = {
                "center": y_offset_px,
                "radius": y_offset_search_px,
                "selected": final.y_offset_px,
                "bottom_gap_prefilter": bottom_gap_prefilter,
                "probed_offsets": candidate_offsets,
                "candidates": [
                    {
                        "y_offset_px": result.y_offset_px,
                        "value": result.value,
                        "confidence": round(result.confidence, 6),
                        "reason": result.reason,
                        "raw": result.raw,
                    }
                    for result in probes
                ],
            }
            summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception:
            pass
        return final

    digit_values = frozenset("0123456789")
    target_rgb = _parse_hex_color(color_filter_hex) or SLOT_TEXT_COLOR
    debug_positions: list[dict] = []
    x_position: int | None = None
    effective_slot = _shift_slot_y_for_count(slot, y_offset_px, image.size[1])
    slot_color_mask: Image.Image | None = None
    slot_color_pixels = 0
    if color_filter_enabled:
        slot_color_mask, slot_color_pixels = _build_subtractor_color_mask(
            image,
            effective_slot,
            target_rgb=target_rgb,
            tolerance_percent=color_filter_tolerance_percent,
            mode=color_filter_mode,
        )

    def _save_debug_asset(position: int, name: str, asset: Image.Image, *, scale: int = 1) -> str | None:
        if debug_dir is None:
            return None
        try:
            path = debug_dir / f"pos{position}_{name}.png"
            path.parent.mkdir(parents=True, exist_ok=True)
            out = asset.convert("RGB") if asset.mode not in ("L", "1") else asset.convert("L")
            if scale > 1:
                out = out.resize((out.width * scale, out.height * scale), Image.Resampling.NEAREST)
            out.save(path)
            return path.name
        except Exception:
            return None

    def _finish(result: SlotCountResult) -> SlotCountResult:
        if result.y_offset_px != y_offset_px:
            result = SlotCountResult(result.value, result.confidence, result.reason, result.raw, y_offset_px)
        if debug_dir is not None:
            try:
                debug_dir.mkdir(parents=True, exist_ok=True)
                _debug_slot_overlay(image, effective_slot).save(debug_dir / "slot_digit_rois.png", quality=95)
                summary = {
                    "value": result.value,
                    "confidence": round(result.confidence, 6),
                    "reason": result.reason,
                    "raw": result.raw,
                    "color_filter_enabled": color_filter_enabled,
                    "color_filter_hex": color_filter_hex,
                    "color_filter_tolerance_percent": color_filter_tolerance_percent,
                    "color_filter_mode": _normalize_color_filter_mode(color_filter_mode),
                    "slot_color_pixels": slot_color_pixels,
                    "x_position": x_position,
                    "y_offset_px": y_offset_px,
                    "positions": debug_positions,
                    "slot_overlay": "slot_digit_rois.png",
                }
                if slot_color_mask is not None:
                    slot_box = _region_box(effective_slot, image.size)
                    slot_color_mask.crop(slot_box).save(debug_dir / "slot_color_mask.png")
                    summary["slot_color_mask"] = "slot_color_mask.png"
                (debug_dir / "summary.json").write_text(
                    json.dumps(summary, ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )
            except Exception:
                pass
        return result

    position_records: list[dict] = []
    for position in range(6):
        digit_payload = _digit_region(effective_slot, position, image.size)
        crop = warp_quad_region(image, digit_payload)
        if crop is None:
            return _finish(SlotCountResult(None, 0.0, "crop_failed", ""))

        debug_entry: dict = {"position": position, "images": {}}
        crop_name = _save_debug_asset(position, "crop", crop, scale=4)
        if crop_name:
            debug_entry["images"]["crop"] = crop_name

        if color_filter_enabled and slot_color_mask is not None:
            color_feature, color_pixels, color_source_pixels = _extract_color_text_from_subtractor_mask(
                slot_color_mask,
                digit_payload,
            )
            debug_entry["color_source_pixels"] = color_source_pixels
            debug_entry["color_text_pixels"] = color_pixels
            name = _save_debug_asset(position, "color_text", color_feature.text, scale=6)
            if name:
                debug_entry["images"]["color_text"] = name
            name = _save_debug_asset(position, "color_outline", color_feature.outline, scale=6)
            if name:
                debug_entry["images"]["color_outline"] = name
            feature = color_feature
            text_pixels = color_pixels
            active_blank_threshold = color_blank_text_threshold
            if text_pixels < active_blank_threshold and outline_fallback_enabled:
                outline_feature, outline_pixels = _extract_outline_text(
                    crop,
                    white_threshold=white_threshold,
                    black_threshold=black_threshold,
                    dilate=dilate,
                )
                debug_entry["outline_fallback"] = True
                debug_entry["outline_text_pixels"] = outline_pixels
                name = _save_debug_asset(position, "outline_text", outline_feature.text, scale=6)
                if name:
                    debug_entry["images"]["outline_text"] = name
                name = _save_debug_asset(position, "outline_outline", outline_feature.outline, scale=6)
                if name:
                    debug_entry["images"]["outline_outline"] = name
                feature = outline_feature
                text_pixels = outline_pixels
                active_blank_threshold = blank_text_threshold
        else:
            feature, text_pixels = _extract_outline_text(
                crop,
                white_threshold=white_threshold,
                black_threshold=black_threshold,
                dilate=dilate,
            )
            active_blank_threshold = blank_text_threshold
            name = _save_debug_asset(position, "outline_text", feature.text, scale=6)
            if name:
                debug_entry["images"]["outline_text"] = name
            name = _save_debug_asset(position, "outline_outline", feature.outline, scale=6)
            if name:
                debug_entry["images"]["outline_outline"] = name

        debug_entry["method"] = feature.method
        debug_entry["text_pixels"] = text_pixels
        debug_entry["blank_threshold"] = active_blank_threshold
        name = _save_debug_asset(position, "used_text", feature.text, scale=6)
        if name:
            debug_entry["images"]["used_text"] = name
        name = _save_debug_asset(position, "used_outline", feature.outline, scale=6)
        if name:
            debug_entry["images"]["used_outline"] = name
        record = {
            "position": position,
            "feature": feature,
            "text_pixels": text_pixels,
            "blank_threshold": active_blank_threshold,
            "debug": debug_entry,
        }
        if position > 0:
            shifted_payload = _digit_region(
                effective_slot,
                position,
                image.size,
                x_offset_px=-K_SUFFIX_DIGIT_LEFT_SHIFT_PX,
            )
            shifted_crop = warp_quad_region(image, shifted_payload)
            if shifted_crop is not None:
                shifted_debug = {
                    "position": position,
                    "variant": "k_suffix_left_shift",
                    "x_offset_px": -K_SUFFIX_DIGIT_LEFT_SHIFT_PX,
                }
                if color_filter_enabled and slot_color_mask is not None:
                    shifted_feature, shifted_pixels, shifted_source_pixels = _extract_color_text_from_subtractor_mask(
                        slot_color_mask,
                        shifted_payload,
                    )
                    shifted_debug["color_source_pixels"] = shifted_source_pixels
                    shifted_debug["color_text_pixels"] = shifted_pixels
                    shifted_blank_threshold = color_blank_text_threshold
                    if shifted_pixels < shifted_blank_threshold and outline_fallback_enabled:
                        shifted_outline_feature, shifted_outline_pixels = _extract_outline_text(
                            shifted_crop,
                            white_threshold=white_threshold,
                            black_threshold=black_threshold,
                            dilate=dilate,
                        )
                        shifted_debug["outline_fallback"] = True
                        shifted_debug["outline_text_pixels"] = shifted_outline_pixels
                        shifted_feature = shifted_outline_feature
                        shifted_pixels = shifted_outline_pixels
                        shifted_blank_threshold = blank_text_threshold
                else:
                    shifted_feature, shifted_pixels = _extract_outline_text(
                        shifted_crop,
                        white_threshold=white_threshold,
                        black_threshold=black_threshold,
                        dilate=dilate,
                    )
                    shifted_blank_threshold = blank_text_threshold
                shifted_debug["method"] = shifted_feature.method
                shifted_debug["text_pixels"] = shifted_pixels
                shifted_debug["blank_threshold"] = shifted_blank_threshold
                record["k_suffix_record"] = {
                    "position": position,
                    "feature": shifted_feature,
                    "text_pixels": shifted_pixels,
                    "blank_threshold": shifted_blank_threshold,
                    "debug": shifted_debug,
                    "variant": "k_suffix_left_shift",
                    "x_offset_px": -K_SUFFIX_DIGIT_LEFT_SHIFT_PX,
                }
        position_records.append(record)

    def _is_blank_record(record: dict) -> bool:
        return int(record["text_pixels"]) < int(record["blank_threshold"])

    def _classify_x_record(record: dict) -> dict | None:
        top = _classify_mask(record["feature"], templates, allowed_values=frozenset({"x"}), position=int(record["position"]))
        debug_entry = record["debug"]
        debug_entry["x_top"] = [
            {"value": value, "template": name, "score": round(score, 6)}
            for value, name, score in top
        ]
        if not top:
            return None
        best_value, best_name, best_score = top[0]
        second_score = top[1][2] if len(top) > 1 else 0.0
        margin = best_score - second_score
        debug_entry["x_best_value"] = best_value
        debug_entry["x_best_score"] = round(best_score, 6)
        debug_entry["x_margin"] = round(margin, 6)
        hard_x = best_value == "x" and best_score >= x_confidence_threshold and margin >= x_margin_threshold
        soft_x = best_value == "x" and best_score >= x_soft_confidence_threshold and margin >= x_soft_margin_threshold
        return {"record": record, "value": best_value, "template": best_name, "score": best_score, "margin": margin, "hard": hard_x, "soft": soft_x}

    def _classify_digit_record(record: dict) -> dict | None:
        top = _classify_mask(record["feature"], templates, allowed_values=digit_values, position=int(record["position"]))
        if not top:
            return None
        best_value, best_name, best_score = top[0]
        second_value = top[1][0] if len(top) > 1 else ""
        second_score = top[1][2] if len(top) > 1 else 0.0
        margin = best_score - second_score
        hard_digit = best_score >= confidence_threshold and margin >= margin_threshold
        soft_digit = record["feature"].method == "color" and best_score >= digit_soft_confidence_threshold and margin >= digit_soft_margin_threshold
        hole_rule = None
        hole_soft = False
        if (
            record["feature"].method == "color"
            and {str(best_value), str(second_value)} == {"5", "6"}
            and float(best_score) >= SLOT_COUNT_56_HOLE_SOFT_MIN_SCORE
            and float(margin) >= SLOT_COUNT_56_HOLE_SOFT_MIN_MARGIN
        ):
            hole_metrics = _digit_lower_hole_metrics(record["feature"].text)
            has_lower_hole = bool(hole_metrics.get("has_lower_hole"))
            supports_best = (best_value == "6" and has_lower_hole) or (best_value == "5" and not has_lower_hole)
            hole_soft = supports_best
            hole_rule = {
                "pair": "5/6",
                "best": best_value,
                "second": second_value,
                "supports_best": supports_best,
                "lower_hole_ratio": round(float(hole_metrics.get("lower_hole_ratio") or 0.0), 6),
                "lower_hole_area": int(hole_metrics.get("lower_hole_area") or 0),
                "lower_hole_center_y": round(float(hole_metrics.get("lower_hole_center_y") or 0.0), 6),
                "has_lower_hole": has_lower_hole,
            }
        soft_digit = soft_digit or hole_soft
        context_soft_digit = (
            record["feature"].method == "color"
            and best_score >= 0.60
            and margin >= 0.025
        )
        return {
            "top": top,
            "value": best_value,
            "template": best_name,
            "score": best_score,
            "margin": margin,
            "hard": hard_digit,
            "soft": soft_digit,
            "context_soft": context_soft_digit,
            "hole_soft": hole_soft,
            "hole_rule": hole_rule,
            "variant": record.get("variant", "normal"),
            "x_offset_px": int(record.get("x_offset_px", 0) or 0),
        }

    def _classify_k_record(record: dict) -> dict | None:
        top = _classify_mask(record["feature"], templates, allowed_values=frozenset({"k"}), position=int(record["position"]))
        if not top:
            return None
        best_value, best_name, best_score = top[0]
        second_score = top[1][2] if len(top) > 1 else 0.0
        margin = best_score - second_score
        hard_k = best_value == "k" and best_score >= k_confidence_threshold and margin >= k_margin_threshold
        return {
            "top": top,
            "value": best_value,
            "template": best_name,
            "score": best_score,
            "margin": margin,
            "hard": hard_k,
            "soft": hard_k,
        }

    k_results_by_position: dict[int, dict] = {}

    def _has_later_hard_k(position: int) -> bool:
        return any(
            int(pos) > position and bool(result.get("hard") or result.get("soft"))
            for pos, result in k_results_by_position.items()
        )

    nonblank_records = [record for record in position_records if not _is_blank_record(record)]
    terminal_record = nonblank_records[-1] if nonblank_records else None
    terminal_digit_result = _classify_digit_record(terminal_record) if terminal_record is not None else None
    terminal_k_result = _classify_k_record(terminal_record) if terminal_record is not None else None
    terminal_digit_accepted = bool(
        terminal_digit_result
        and (
            terminal_digit_result.get("hard")
            or terminal_digit_result.get("soft")
            or terminal_digit_result.get("context_soft")
        )
    )
    # A large terminal K shifts the complete right-aligned count run to the
    # left.  Do not require a strong K template before selecting that geometry:
    # the existing terminal-K heuristic is specifically for cases where the
    # glyph is too wide/partial to classify cleanly.  A terminal glyph that is
    # not an acceptable digit is sufficient structural evidence to compare the
    # shifted run, while an accepted final digit keeps the normal geometry.
    k_suffix_layout = _uses_k_suffix_layout(
        nonblank_count=len(nonblank_records),
        terminal_digit_accepted=terminal_digit_accepted,
        terminal_k_accepted=bool(
            terminal_k_result and (terminal_k_result.get("hard") or terminal_k_result.get("soft"))
        ),
    )

    def _best_digit_for_context(record: dict, *, later_k: bool, prefer_shifted: bool = False) -> dict | None:
        normal = _classify_digit_record(record)
        shifted = None
        if later_k and record.get("k_suffix_record") is not None:
            shifted = _classify_digit_record(record["k_suffix_record"])
        if shifted is None:
            return normal
        if normal is None:
            return shifted
        normal_accept = bool(normal.get("hard") or normal.get("soft") or normal.get("context_soft"))
        shifted_accept = bool(shifted.get("hard") or shifted.get("soft") or shifted.get("context_soft"))
        if prefer_shifted and shifted_accept:
            return shifted
        if shifted_accept and not normal_accept:
            return shifted
        if shifted_accept == normal_accept and float(shifted.get("score") or 0.0) >= float(normal.get("score") or 0.0) + 0.02:
            return shifted
        return normal
    for record in position_records:
        if _is_blank_record(record):
            record["debug"]["decision"] = "blank"
            continue
        normal_x_result = _classify_x_record(record)
        shifted_x_result = None
        if k_suffix_layout and record.get("k_suffix_record") is not None:
            shifted_x_result = _classify_x_record(record["k_suffix_record"])
        if shifted_x_result is not None and (
            normal_x_result is None
            or (
                bool(shifted_x_result.get("hard") or shifted_x_result.get("soft"))
                and (
                    k_suffix_layout
                    or float(shifted_x_result.get("score") or 0.0)
                    >= float(normal_x_result.get("score") or 0.0)
                )
            )
        ):
            record["x_result"] = shifted_x_result
            record["x_result"]["variant"] = "k_suffix_left_shift"
            record["x_result"]["x_offset_px"] = -K_SUFFIX_DIGIT_LEFT_SHIFT_PX
        else:
            record["x_result"] = normal_x_result
        k_result = _classify_k_record(record)
        if k_result is not None:
            k_results_by_position[int(record["position"])] = k_result

    x_candidates: list[dict] = []
    for record in position_records:
        if _is_blank_record(record):
            continue
        x_result = record.get("x_result")
        if not x_result or not (x_result["hard"] or x_result["soft"]):
            continue
        position = int(record["position"])
        has_right_text = any(int(other["position"]) > position and not _is_blank_record(other) for other in position_records)
        if has_right_text:
            x_candidates.append(x_result)
    x_candidates.sort(key=lambda candidate: (1 if candidate["hard"] else 0, float(candidate["score"]), int(candidate["record"]["position"])), reverse=True)

    def _attempt_anchor(candidate: dict) -> dict:
        anchor_position = int(candidate["record"]["position"])
        attempt_digits: list[str] = []
        attempt_confidences: list[float] = [float(candidate["score"])]
        attempt_raw: list[str] = ["x"]
        decisions: dict[int, dict] = {anchor_position: {"kind": "x", "x_result": candidate}}
        for record in position_records:
            position = int(record["position"])
            if position <= anchor_position:
                continue
            if _is_blank_record(record):
                if attempt_digits:
                    break
                return {"ok": False, "reason": "blank_after_prefix", "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}
            later_text = any(
                int(other["position"]) > position and not _is_blank_record(other)
                for other in position_records
            )
            digit_result = _best_digit_for_context(
                record,
                later_k=k_suffix_layout or _has_later_hard_k(position),
                prefer_shifted=k_suffix_layout,
            )
            digit_context_soft = bool(
                attempt_digits
                and later_text
                and digit_result is not None
                and digit_result.get("context_soft")
            )
            if digit_result is not None and (digit_result["hard"] or digit_result["soft"] or digit_context_soft):
                decisions[position] = {"kind": "digit", "digit_result": digit_result, "context_soft": digit_context_soft}
                attempt_raw.append(str(digit_result["value"]))
                attempt_digits.append(str(digit_result["value"]))
                attempt_confidences.append(float(digit_result["score"]))
                continue
            if attempt_digits:
                k_result = _classify_k_record(record)
                if k_result is not None and (k_result["hard"] or k_result["soft"]):
                    decisions[position] = {"kind": "k", "k_result": k_result}
                    attempt_raw.append("k")
                    attempt_confidences.append(float(k_result["score"]))
                    trailing_text = later_text
                    if trailing_text:
                        return {"ok": False, "reason": "text_after_k", "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}
                    raw_value = "".join(attempt_digits)
                    if raw_value.startswith("0") and len(raw_value) > 1:
                        return {"ok": False, "reason": "leading_zero", "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}
                    return {"ok": False, "reason": "k_suffix_requires_detail", "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}
                if len(attempt_digits) >= 2 and not later_text:
                    decisions[position] = {"kind": "k_heuristic", "digit_result": digit_result}
                    attempt_raw.append("k")
                    if digit_result is not None:
                        attempt_confidences.append(float(digit_result["score"]))
                    raw_value = "".join(attempt_digits)
                    if raw_value.startswith("0") and len(raw_value) > 1:
                        return {"ok": False, "reason": "leading_zero", "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}
                    return {"ok": False, "reason": "k_suffix_requires_detail", "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}
            if digit_result is None:
                return {"ok": False, "reason": "digit_unclassified", "confidence": 0.0, "raw": "".join(attempt_raw), "decisions": decisions}
            decisions[position] = {"kind": "digit", "digit_result": digit_result}
            return {"ok": False, "reason": "digit_weak", "confidence": float(digit_result["score"]), "raw": "".join(attempt_raw), "decisions": decisions}
        if not attempt_digits:
            return {"ok": False, "reason": "blank_after_prefix", "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}
        raw_value = "".join(attempt_digits)
        if raw_value.startswith("0") and len(raw_value) > 1:
            return {"ok": False, "reason": "leading_zero", "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}
        return {"ok": True, "value": _expand_slot_count_value(raw_value), "confidence": min(attempt_confidences), "raw": "".join(attempt_raw), "decisions": decisions}

    attempts = [_attempt_anchor(candidate) for candidate in x_candidates]
    successful_attempts = [attempt for attempt in attempts if attempt.get("ok")]
    if successful_attempts:
        # x_candidates is already sorted by x-anchor strength.  Prefer the
        # strongest plausible anchor over a longer parse from a weaker leading
        # noise candidate.
        selected_attempt = successful_attempts[0]
    else:
        selected_attempt = max(attempts, key=lambda attempt: (len(str(attempt.get("raw") or "")), float(attempt.get("confidence") or 0.0))) if attempts else None

    if selected_attempt is None:
        first_nonblank = next((record for record in position_records if not _is_blank_record(record)), None)
        for record in position_records:
            debug_entry = record["debug"]
            if _is_blank_record(record):
                debug_entry["decision"] = "blank"
            elif first_nonblank is record:
                debug_entry["top"] = debug_entry.get("x_top", [])
                debug_entry["best_value"] = debug_entry.get("x_best_value")
                debug_entry["best_score"] = debug_entry.get("x_best_score")
                debug_entry["margin"] = debug_entry.get("x_margin")
                debug_entry["decision"] = "x_anchor_weak"
            else:
                debug_entry["decision"] = "unparsed_after_x_anchor_failure"
            debug_positions.append(debug_entry)
        if first_nonblank is None:
            return _finish(SlotCountResult(None, 0.0, "x_anchor_missing", ""))
        score = float(first_nonblank["debug"].get("x_best_score") or 0.0)
        return _finish(SlotCountResult(None, score, "x_anchor_weak", ""))

    selected_decisions = selected_attempt["decisions"]
    for record in position_records:
        position = int(record["position"])
        debug_entry = record["debug"]
        decision = selected_decisions.get(position)
        if decision is None:
            if _is_blank_record(record):
                debug_entry["decision"] = "blank"
            elif any(int(candidate["record"]["position"]) == position for candidate in x_candidates):
                debug_entry["decision"] = "unused_x_candidate"
            else:
                debug_entry["decision"] = "leading_noise_before_x"
            debug_positions.append(debug_entry)
            continue
        if decision["kind"] == "x":
            x_result = decision["x_result"]
            x_position = position
            debug_entry["top"] = debug_entry.get("x_top", [])
            debug_entry["best_value"] = x_result["value"]
            debug_entry["best_score"] = round(float(x_result["score"]), 6)
            debug_entry["margin"] = round(float(x_result["margin"]), 6)
            debug_entry["decision"] = "accepted_x" if x_result["hard"] else "accepted_x_soft"
            if x_result.get("variant") == "k_suffix_left_shift":
                debug_entry["variant"] = x_result["variant"]
                debug_entry["x_offset_px"] = x_result["x_offset_px"]
        elif decision["kind"] == "digit":
            digit_result = decision["digit_result"]
            debug_entry["top"] = [
                {"value": value, "template": name, "score": round(score, 6)}
                for value, name, score in digit_result["top"]
            ]
            debug_entry["best_value"] = digit_result["value"]
            debug_entry["best_score"] = round(float(digit_result["score"]), 6)
            debug_entry["margin"] = round(float(digit_result["margin"]), 6)
            if digit_result.get("hole_rule") is not None:
                debug_entry["hole_5_6"] = digit_result["hole_rule"]
            if digit_result.get("variant") != "normal":
                debug_entry["variant"] = digit_result.get("variant")
                debug_entry["x_offset_px"] = digit_result.get("x_offset_px")
            if digit_result["hard"] or digit_result["soft"]:
                if digit_result.get("hole_soft") and not digit_result["hard"]:
                    debug_entry["decision"] = "accepted_digit_5_6_hole"
                else:
                    debug_entry["decision"] = "accepted_digit" if digit_result["hard"] else "accepted_digit_soft_margin"
            elif decision.get("context_soft"):
                debug_entry["decision"] = "accepted_digit_context_soft"
            else:
                debug_entry["decision"] = "digit_weak"
        elif decision["kind"] == "k":
            k_result = decision["k_result"]
            debug_entry["top"] = [
                {"value": value, "template": name, "score": round(score, 6)}
                for value, name, score in k_result["top"]
            ]
            debug_entry["best_value"] = k_result["value"]
            debug_entry["best_score"] = round(float(k_result["score"]), 6)
            debug_entry["margin"] = round(float(k_result["margin"]), 6)
            debug_entry["decision"] = "accepted_k"
        else:
            digit_result = decision.get("digit_result")
            if digit_result is not None:
                debug_entry["top"] = [
                    {"value": value, "template": name, "score": round(score, 6)}
                    for value, name, score in digit_result["top"]
                ]
                debug_entry["best_value"] = digit_result["value"]
                debug_entry["best_score"] = round(float(digit_result["score"]), 6)
                debug_entry["margin"] = round(float(digit_result["margin"]), 6)
            debug_entry["decision"] = "accepted_k_heuristic"
        debug_positions.append(debug_entry)

    if selected_attempt.get("ok"):
        return _finish(SlotCountResult(str(selected_attempt["value"]), float(selected_attempt.get("confidence") or 0.0), raw=str(selected_attempt.get("raw") or "")))
    return _finish(SlotCountResult(None, float(selected_attempt.get("confidence") or 0.0), str(selected_attempt.get("reason") or "digit_weak"), str(selected_attempt.get("raw") or "")))







