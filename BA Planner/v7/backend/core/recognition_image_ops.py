"""Shared image operations for recognizers (C5c, X15).

Moved verbatim from the recognizer modules that owned them so no module imports another's private
helper. The two grey NCC variants differ on purpose and are named by what they do:
``ncc_signed_lanczos`` (LANCZOS to the template, signed) and ``ncc_unit_bilinear`` (BILINEAR to the
crop, clamped at 0). Behavior-preserving: identical arithmetic and evaluation order.
"""
from __future__ import annotations

from PIL import Image, ImageChops, ImageStat


def pixels(image: Image.Image):
    """Flattened pixel values across Pillow versions."""
    flattened = getattr(image, "get_flattened_data", None)
    return flattened() if flattened is not None else image.getdata()


def ncc_signed_lanczos(left: Image.Image, right: Image.Image) -> float:
    """Grey NCC of left resized (LANCZOS) to right; signed, clamped to [-1, 1]. Was student_weapon_recognizer._normalized_correlation."""
    size = right.size
    source = left.convert("L").resize(size, Image.Resampling.LANCZOS)
    template = right.convert("L")
    try:
        source_values = list(source.getdata())
        template_values = list(template.getdata())
        source_mean = sum(source_values) / max(1, len(source_values))
        template_mean = sum(template_values) / max(1, len(template_values))
        numerator = sum(
            (a - source_mean) * (b - template_mean)
            for a, b in zip(source_values, template_values, strict=True)
        )
        left_square = sum((value - source_mean) ** 2 for value in source_values)
        right_square = sum((value - template_mean) ** 2 for value in template_values)
        denominator = (left_square * right_square) ** 0.5
        return 0.0 if denominator == 0 else max(-1.0, min(1.0, numerator / denominator))
    finally:
        source.close()
        template.close()


def color_similarity(left: Image.Image, right: Image.Image) -> float:
    """RGB mean-difference similarity of left resized (LANCZOS) to right, in [0, 1]."""
    source = left.convert("RGB").resize(right.size, Image.Resampling.LANCZOS)
    template = right.convert("RGB")
    try:
        mean = ImageStat.Stat(ImageChops.difference(source, template)).mean
        return max(0.0, min(1.0, 1.0 - sum(mean) / (3.0 * 255.0)))
    finally:
        source.close()
        template.close()


def ncc_unit_bilinear(left: Image.Image, right: Image.Image) -> float:
    """Grey NCC of right resized (BILINEAR) to left; clamped to [0, 1]. Was student_equipment_recognizer._normalized_correlation."""
    right = right.resize(left.size, Image.Resampling.BILINEAR)
    a = list(pixels(left.convert("L")))
    b = list(pixels(right.convert("L")))
    if not a:
        return 0.0
    mean_a = sum(a) / len(a)
    mean_b = sum(b) / len(b)
    numerator = sum((x - mean_a) * (y - mean_b) for x, y in zip(a, b))
    denominator_a = sum((x - mean_a) ** 2 for x in a) ** 0.5
    denominator_b = sum((y - mean_b) ** 2 for y in b) ** 0.5
    if denominator_a == 0.0 or denominator_b == 0.0:
        return 0.0
    return max(0.0, min(1.0, numerator / (denominator_a * denominator_b)))


def mean_difference(left: Image.Image, right: Image.Image) -> float:
    """Mean-difference similarity of right resized (BILINEAR) to left, in [0, 1]."""
    right = right.resize(left.size, Image.Resampling.BILINEAR)
    stat = ImageStat.Stat(ImageChops.difference(left, right))
    return max(0.0, 1.0 - sum(stat.mean) / (len(stat.mean) * 255.0))


def mask_from_predicate(image: Image.Image, predicate) -> Image.Image:
    """Binary L mask of the pixels that satisfy predicate."""
    rgb = image.convert("RGB")
    result = Image.new("L", rgb.size)
    result.putdata([255 if predicate(pixel) else 0 for pixel in pixels(rgb)])
    return result


def normalize_mask(mask: Image.Image, *, size: tuple[int, int] = (20, 28), padding: int = 2) -> Image.Image | None:
    """Tight-crop a binary glyph and centre it, NEAREST-scaled, in a padded canvas."""
    source = mask.convert("L").point(lambda value: 255 if value >= 127 else 0)
    box = source.getbbox()
    if box is None:
        return None
    glyph = source.crop(box)
    target_width = max(1, size[0] - padding * 2)
    target_height = max(1, size[1] - padding * 2)
    scale = min(target_width / glyph.width, target_height / glyph.height)
    resized = glyph.resize(
        (max(1, round(glyph.width * scale)), max(1, round(glyph.height * scale))),
        Image.Resampling.NEAREST,
    )
    result = Image.new("L", size)
    result.paste(resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2))
    return result


def binary_iou(left: Image.Image, right: Image.Image) -> float:
    """Intersection over union of two binary masks (right NEAREST-resized to left)."""
    a = left.convert("L")
    b = right.convert("L").resize(a.size, Image.Resampling.NEAREST)
    left_bits = [value >= 127 for value in pixels(a)]
    right_bits = [value >= 127 for value in pixels(b)]
    intersection = sum(x and y for x, y in zip(left_bits, right_bits))
    union = sum(x or y for x, y in zip(left_bits, right_bits))
    return intersection / union if union else 0.0


def otsu_binary(image: Image.Image, *, inverse: bool = False) -> Image.Image:
    """Otsu threshold of the grey image (inverse selects the dark side)."""
    gray = image.convert("L")
    histogram = gray.histogram()
    pixel_count = sum(histogram)
    weighted_total = sum(index * count for index, count in enumerate(histogram))
    background_weight = 0
    background_total = 0
    best_variance = -1.0
    threshold = 0
    for index, count in enumerate(histogram):
        background_weight += count
        if background_weight == 0:
            continue
        foreground_weight = pixel_count - background_weight
        if foreground_weight == 0:
            break
        background_total += index * count
        background_mean = background_total / background_weight
        foreground_mean = (weighted_total - background_total) / foreground_weight
        variance = (
            background_weight
            * foreground_weight
            * (background_mean - foreground_mean) ** 2
        )
        if variance > best_variance:
            best_variance = variance
            threshold = index
    return gray.point(
        lambda value: 255
        if (value <= threshold if inverse else value > threshold)
        else 0
    )


def ncc_difference_score(left: Image.Image, right: Image.Image) -> float:
    """0.70 x grey NCC + 0.30 x (1 - mean difference); right BILINEAR-resized to left."""
    right = right.resize(left.size, Image.Resampling.BILINEAR).convert("L")
    left = left.convert("L")
    left_values = list(pixels(left))
    right_values = list(pixels(right))
    if not left_values:
        return 0.0
    left_mean = sum(left_values) / len(left_values)
    right_mean = sum(right_values) / len(right_values)
    numerator = sum(
        (left_value - left_mean) * (right_value - right_mean)
        for left_value, right_value in zip(left_values, right_values)
    )
    left_norm = sum((value - left_mean) ** 2 for value in left_values) ** 0.5
    right_norm = sum((value - right_mean) ** 2 for value in right_values) ** 0.5
    correlation = numerator / (left_norm * right_norm) if left_norm and right_norm else 0.0
    difference = ImageStat.Stat(ImageChops.difference(left, right)).mean[0] / 255.0
    return 0.70 * correlation + 0.30 * (1.0 - difference)

# E2 "icon region" of an inventory tile: without the quantity strip and card border.
TILE_ICON_REGION = (0.12, 0.06, 0.88, 0.76)
TILE_ICON_SIZE = (48, 48)


def _tile_icon_channels(image: Image.Image) -> tuple[list[float], list[float], list[float]]:
    rgb = image.convert("RGB")
    w, h = rgb.size
    x1, y1, x2, y2 = TILE_ICON_REGION
    with rgb.crop((int(w * x1), int(h * y1), int(w * x2), int(h * y2))) as icon:
        with icon.resize(TILE_ICON_SIZE, Image.Resampling.BILINEAR) as small:
            bands = small.split()
    try:
        return tuple([float(value) for value in pixels(band)] for band in bands)  # type: ignore[return-value]
    finally:
        for band in bands:
            band.close()


def _ncc_values(left: list[float], right: list[float]) -> float:
    left_mean = sum(left) / len(left)
    right_mean = sum(right) / len(right)
    numerator = sum((a - left_mean) * (b - right_mean) for a, b in zip(left, right))
    denominator = (sum((a - left_mean) ** 2 for a in left) * sum((b - right_mean) ** 2 for b in right)) ** 0.5
    return numerator / denominator if denominator > 0 else 0.0


def ncc_per_channel_icon(left: Image.Image, right: Image.Image) -> float:
    """E2 metric M4: mean of per-channel NCC over the tile icon region (48x48 BILINEAR).

    Separates same-shape/different-colour tiers (grey NCC fails) and same-tier/different-school
    tiles (background-dominated mean difference fails); see c5e-experiments-2026-09-27 E2.
    Not used by recognition yet (C5e-2 tile bank).
    """
    left_channels = _tile_icon_channels(left)
    right_channels = _tile_icon_channels(right)
    return sum(_ncc_values(a, b) for a, b in zip(left_channels, right_channels)) / 3.0
