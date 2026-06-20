"""Perspective-normalized quadrilateral ROI helpers."""

from __future__ import annotations

import cv2
import numpy as np
from PIL import Image


def warp_quad_region(
    image: Image.Image,
    payload: dict,
    *,
    output_size: tuple[int, int] | None = None,
) -> Image.Image | None:
    points = payload.get("points_ratio") or []
    if len(points) != 4:
        return None

    width, height = image.size
    src_points = [
        (float(point["x"]) * width, float(point["y"]) * height)
        for point in points
    ]
    top_left, top_right, bottom_right, bottom_left = src_points
    if output_size is None:
        top_width = np.hypot(top_right[0] - top_left[0], top_right[1] - top_left[1])
        bottom_width = np.hypot(bottom_right[0] - bottom_left[0], bottom_right[1] - bottom_left[1])
        left_height = np.hypot(bottom_left[0] - top_left[0], bottom_left[1] - top_left[1])
        right_height = np.hypot(bottom_right[0] - top_right[0], bottom_right[1] - top_right[1])
        dst_w = max(1, int(round(max(top_width, bottom_width))))
        dst_h = max(1, int(round(max(left_height, right_height))))
    else:
        dst_w, dst_h = output_size

    src = np.asarray(src_points, dtype=np.float32)
    dst = np.asarray(
        ((0, 0), (dst_w - 1, 0), (dst_w - 1, dst_h - 1), (0, dst_h - 1)),
        dtype=np.float32,
    )
    matrix = cv2.getPerspectiveTransform(src, dst)
    rgb = np.asarray(image.convert("RGB"))
    warped = cv2.warpPerspective(rgb, matrix, (dst_w, dst_h), flags=cv2.INTER_CUBIC)
    return Image.fromarray(warped)


def otsu_binary(image: Image.Image) -> np.ndarray:
    gray = cv2.cvtColor(np.asarray(image.convert("RGB")), cv2.COLOR_RGB2GRAY)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    _threshold, binary = cv2.threshold(
        gray,
        0,
        255,
        cv2.THRESH_BINARY + cv2.THRESH_OTSU,
    )
    return binary


def normalize_binary_glyph(
    binary: np.ndarray,
    *,
    output_size: tuple[int, int] = (24, 32),
    padding: int = 2,
) -> np.ndarray | None:
    if binary.size == 0:
        return None

    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(binary)
    keep = [index for index in range(1, count) if stats[index, cv2.CC_STAT_AREA] >= 4]
    if not keep:
        return None

    # A tight digit cell may retain a sliver of the adjacent ``Lv.`` prefix.
    # The digit is the dominant connected component after perspective repair.
    keep = [max(keep, key=lambda index: stats[index, cv2.CC_STAT_AREA])]
    cleaned = np.zeros_like(binary)
    for index in keep:
        cleaned[labels == index] = 255
    ys, xs = np.where(cleaned > 0)
    if xs.size == 0:
        return None

    glyph = cleaned[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    dst_w, dst_h = output_size
    usable_w = max(1, dst_w - padding * 2)
    usable_h = max(1, dst_h - padding * 2)
    scale = min(usable_w / glyph.shape[1], usable_h / glyph.shape[0])
    resized_w = max(1, int(round(glyph.shape[1] * scale)))
    resized_h = max(1, int(round(glyph.shape[0] * scale)))
    resized = cv2.resize(glyph, (resized_w, resized_h), interpolation=cv2.INTER_NEAREST)

    canvas = np.zeros((dst_h, dst_w), dtype=np.uint8)
    x = (dst_w - resized_w) // 2
    y = (dst_h - resized_h) // 2
    canvas[y:y + resized_h, x:x + resized_w] = resized
    return canvas


def binary_glyph_similarity(left: np.ndarray, right: np.ndarray) -> float:
    if left.shape != right.shape:
        right = cv2.resize(right, (left.shape[1], left.shape[0]), interpolation=cv2.INTER_NEAREST)
    left_mask = left > 0
    right_mask = right > 0
    union = np.logical_or(left_mask, right_mask).sum()
    if union == 0:
        return 0.0
    intersection = np.logical_and(left_mask, right_mask).sum()
    iou = float(intersection / union)

    a = left.astype(np.float32).reshape(-1)
    b = right.astype(np.float32).reshape(-1)
    a -= a.mean()
    b -= b.mean()
    denom = float(np.linalg.norm(a) * np.linalg.norm(b))
    corr = float(np.dot(a, b) / denom) if denom > 1e-6 else 0.0
    corr = max(0.0, min(1.0, (corr + 1.0) / 2.0))
    return 0.55 * iou + 0.45 * corr
