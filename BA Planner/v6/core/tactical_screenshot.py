from __future__ import annotations

from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

import core.student_meta as student_meta
from core.config import TEMPLATE_DIR
from core.tactical_challenge import TacticalDeck


_BASE_WIDTH = 2560
_BASE_HEIGHT = 1440
_SLOT_CROP_WIDTH = 117
_PORTRAIT_TEMPLATE_WIDTH = 252
_PORTRAIT_TEMPLATE_HEIGHT = 204
_SLOT_CROP_HEIGHT = round(_SLOT_CROP_WIDTH * _PORTRAIT_TEMPLATE_HEIGHT / _PORTRAIT_TEMPLATE_WIDTH)
_SLOT_CROP_TOP = 1064
_SLOT_CENTERS_X = (263, 413, 563, 713, 863, 1013, 1534, 1685, 1836, 1985, 2138, 2288)

_COARSE_VARIANT_FACTORS = (1.00,)
_COARSE_VARIANT_OFFSETS_X = (0,)
_COARSE_VARIANT_OFFSETS_Y = (0,)
_REFINED_VARIANT_FACTORS = (0.88, 0.94, 1.00, 1.06, 1.12)
_REFINED_VARIANT_OFFSETS_X = (-8, -4, 0, 4, 8, 12)
_REFINED_VARIANT_OFFSETS_Y = (-12, -8, -4, 0, 4, 8)
_REFINED_CANDIDATE_COUNT = 5


@dataclass(slots=True)
class TacticalSlotMatch:
    slot_index: int
    student_id: str
    score: float
    runner_up_id: str = ""
    runner_up_score: float = 0.0
    role: str = ""
    visible: bool = True

    @property
    def margin(self) -> float:
        return float(self.score) - float(self.runner_up_score)


@dataclass(slots=True)
class TacticalSideReadout:
    deck: TacticalDeck
    slots: list[TacticalSlotMatch] = field(default_factory=list)


@dataclass(slots=True)
class TacticalScreenshotReadout:
    result: str
    mode: str
    left: TacticalSideReadout
    right: TacticalSideReadout
    confidence: float
    warnings: list[str] = field(default_factory=list)


@dataclass(slots=True)
class _TemplateVariant:
    student_id: str
    rgb: np.ndarray
    gray: np.ndarray
    hsv: np.ndarray
    valid: np.ndarray


def parse_tactical_result_screenshot(path: str | Path) -> TacticalScreenshotReadout:
    image = Image.open(path).convert("RGB")
    image = _normalize_game_view(image)
    left_visible = [_slot_has_portrait(image, index) for index in range(6)]
    right_visible = [_slot_has_portrait(image, index) for index in range(6, 12)]
    left_role_hint = None if sum(left_visible) < 6 else "fixed"
    right_role_hint = None if sum(right_visible) < 6 else "fixed"
    left_slots = [
        _match_slot(image, index, role_hint=left_role_hint) if visible else _empty_slot(index)
        for index, visible in zip(range(6), left_visible)
    ]
    right_slots = [
        _match_slot(image, index, role_hint=right_role_hint) if visible else _empty_slot(index)
        for index, visible in zip(range(6, 12), right_visible)
    ]
    result = _detect_left_result(image)
    mode = _detect_left_mode(image)
    confidence = min((slot.score for slot in [*left_slots, *right_slots] if slot.visible), default=0.0)
    warnings = _warnings(left_slots, right_slots, result, mode)
    return TacticalScreenshotReadout(
        result=result,
        mode=mode,
        left=TacticalSideReadout(deck=_deck_from_slots(left_slots), slots=left_slots),
        right=TacticalSideReadout(deck=_deck_from_slots(right_slots), slots=right_slots),
        confidence=float(confidence),
        warnings=warnings,
    )


def _normalize_game_view(image: Image.Image) -> Image.Image:
    width, height = image.size
    if width <= 0 or height <= 0:
        return image
    ratio = width / height
    target_ratio = _BASE_WIDTH / _BASE_HEIGHT
    if abs(ratio - target_ratio) <= 0.01:
        return image

    candidate = _best_centered_16_9_crop(width, height)
    content_candidate = _content_16_9_crop(image)
    if content_candidate is not None:
        candidate = content_candidate
    left, top, right, bottom = candidate
    if right - left <= 0 or bottom - top <= 0:
        return image
    return image.crop((left, top, right, bottom))


def _best_centered_16_9_crop(width: int, height: int) -> tuple[int, int, int, int]:
    target_ratio = _BASE_WIDTH / _BASE_HEIGHT
    if width / height > target_ratio:
        crop_width = int(round(height * target_ratio))
        left = max(0, (width - crop_width) // 2)
        return left, 0, left + crop_width, height
    crop_height = int(round(width / target_ratio))
    top = max(0, (height - crop_height) // 2)
    return 0, top, width, top + crop_height


def _content_16_9_crop(image: Image.Image) -> tuple[int, int, int, int] | None:
    arr = np.asarray(image.convert("RGB"), dtype=np.uint8)
    if arr.size == 0:
        return None
    hsv = cv2.cvtColor(arr, cv2.COLOR_RGB2HSV)
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    edges = cv2.Canny(gray, 40, 120)
    kernel = np.ones((5, 5), dtype=np.uint8)
    colored = ((hsv[:, :, 1] > 22) & (hsv[:, :, 2] > 35)).astype(np.uint8) * 255
    edges = cv2.dilate(edges, kernel, iterations=1)
    mask = cv2.bitwise_or(colored, edges)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((15, 15), dtype=np.uint8), iterations=2)
    contours, _hierarchy = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    image_area = image.width * image.height
    target_ratio = _BASE_WIDTH / _BASE_HEIGHT
    best: tuple[float, tuple[int, int, int, int]] | None = None
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        if w < image.width * 0.55 or h < image.height * 0.55:
            continue
        area = w * h
        if area < image_area * 0.45:
            continue
        ratio = w / max(1, h)
        ratio_error = abs(ratio - target_ratio)
        if ratio_error > 0.16:
            continue
        score = area / max(1, image_area) - ratio_error
        box = _fit_16_9_inside(x, y, x + w, y + h)
        if best is None or score > best[0]:
            best = (score, box)
    return best[1] if best is not None else None


def _fit_16_9_inside(left: int, top: int, right: int, bottom: int) -> tuple[int, int, int, int]:
    width = max(1, right - left)
    height = max(1, bottom - top)
    target_ratio = _BASE_WIDTH / _BASE_HEIGHT
    if width / height > target_ratio:
        crop_width = int(round(height * target_ratio))
        offset = max(0, (width - crop_width) // 2)
        return left + offset, top, left + offset + crop_width, bottom
    crop_height = int(round(width / target_ratio))
    offset = max(0, (height - crop_height) // 2)
    return left, top + offset, right, top + offset + crop_height


def _deck_from_slots(slots: list[TacticalSlotMatch]) -> TacticalDeck:
    ordered = sorted(slots, key=lambda slot: slot.slot_index)
    strikers: list[str] = []
    supports: list[str] = []
    for slot in ordered:
        if not slot.student_id:
            continue
        if student_meta.combat_class(slot.student_id) == "special":
            supports.append(slot.student_id)
        else:
            strikers.append(slot.student_id)
    return TacticalDeck(
        strikers=strikers,
        supports=supports,
    )


def _warnings(
    left_slots: list[TacticalSlotMatch],
    right_slots: list[TacticalSlotMatch],
    result: str,
    mode: str,
) -> list[str]:
    warnings: list[str] = []
    if result not in {"win", "loss"}:
        warnings.append("result could not be detected")
    if mode not in {"attack", "defense"}:
        warnings.append("attack/defense icon could not be detected")
    for label, slots in (("left", left_slots), ("right", right_slots)):
        visible_count = sum(1 for slot in slots if slot.visible)
        if visible_count < 6:
            warnings.append(f"{label} side has only {visible_count}/6 visible students; hidden slots were left blank")
    for slot in [*left_slots, *right_slots]:
        if not slot.visible:
            continue
        if slot.score < 0.68:
            warnings.append(f"slot {slot.slot_index + 1} has low score ({slot.score:.3f})")
        elif slot.margin < 0.010:
            warnings.append(
                f"slot {slot.slot_index + 1} is close: {slot.student_id} vs {slot.runner_up_id}"
            )
    return warnings


def _empty_slot(slot_index: int) -> TacticalSlotMatch:
    return TacticalSlotMatch(slot_index=slot_index, student_id="", score=0.0, role="", visible=False)


def _slot_has_portrait(image: Image.Image, slot_index: int) -> bool:
    crop = _slot_crop(image, slot_index)
    arr = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    hsv = cv2.cvtColor(arr, cv2.COLOR_RGB2HSV)
    saturation = hsv[:, :, 1]
    value = hsv[:, :, 2]
    non_background = ((saturation > 35) | (value < 220)).mean()
    colored = ((saturation > 45) & (value > 60)).mean()
    return bool(non_background >= 0.10 or colored >= 0.05)


def _match_slot(image: Image.Image, slot_index: int, *, role_hint: str | None = "fixed") -> TacticalSlotMatch:
    crop = _slot_crop(image, slot_index)
    crop_rgb = np.asarray(crop, dtype=np.uint8)
    crop_rgb_f = crop_rgb.astype(np.float32)
    crop_gray = cv2.cvtColor(crop_rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    crop_hsv = cv2.cvtColor(crop_rgb, cv2.COLOR_RGB2HSV)
    role = "striker" if slot_index % 6 < 4 else "special"
    candidate_role = role if role_hint == "fixed" else "any"
    scores: list[tuple[float, str]] = []
    for student_id in _candidate_student_ids(candidate_role):
        best_score = -1.0
        for variant in _portrait_variants(crop.width, crop.height, student_id):
            score = _variant_score(crop_rgb_f, crop_gray, crop_hsv, variant)
            if score > best_score:
                best_score = score
        if best_score >= 0.0:
            scores.append((float(best_score), student_id))
    scores.sort(reverse=True)
    refined_scores: list[tuple[float, str]] = []
    for _coarse_score, student_id in scores[:_REFINED_CANDIDATE_COUNT]:
        best_score = -1.0
        for variant in _refined_portrait_variants(crop.width, crop.height, student_id):
            score = _variant_score(crop_rgb_f, crop_gray, crop_hsv, variant)
            if score > best_score:
                best_score = score
        if best_score >= 0.0:
            refined_scores.append((float(best_score), student_id))
    refined_scores.sort(reverse=True)
    ranked = refined_scores or scores
    best = ranked[0] if ranked else (0.0, "")
    runner_up = ranked[1] if len(ranked) > 1 else (0.0, "")
    return TacticalSlotMatch(
        slot_index=slot_index,
        student_id=best[1],
        score=best[0],
        runner_up_id=runner_up[1],
        runner_up_score=runner_up[0],
        role=role,
        visible=True,
    )


def _slot_crop(image: Image.Image, slot_index: int) -> Image.Image:
    width, height = image.size
    scale_x = width / _BASE_WIDTH
    scale_y = height / _BASE_HEIGHT
    crop_width = max(24, int(round(_SLOT_CROP_WIDTH * scale_x)))
    crop_height = max(24, int(round(_SLOT_CROP_HEIGHT * scale_y)))
    center_x = int(round(_SLOT_CENTERS_X[slot_index] * scale_x))
    top = int(round(_SLOT_CROP_TOP * scale_y))
    left = center_x - crop_width // 2
    return image.crop((left, top, left + crop_width, top + crop_height))


@lru_cache(maxsize=2)
def _candidate_student_ids(role: str) -> tuple[str, ...]:
    portrait_dir = TEMPLATE_DIR / "students_portraits"
    ids: list[str] = []
    for student_id in student_meta.all_ids():
        if role != "any" and student_meta.combat_class(student_id) != role:
            continue
        template_name = student_meta.template_path(student_id)
        if (portrait_dir / template_name).exists() or (portrait_dir / f"{student_id}.png").exists():
            ids.append(student_id)
    return tuple(sorted(ids))


@lru_cache(maxsize=8192)
def _portrait_variants(width: int, height: int, student_id: str) -> tuple[_TemplateVariant, ...]:
    return _build_portrait_variants(
        width,
        height,
        student_id,
        _COARSE_VARIANT_FACTORS,
        _COARSE_VARIANT_OFFSETS_X,
        _COARSE_VARIANT_OFFSETS_Y,
    )


@lru_cache(maxsize=8192)
def _refined_portrait_variants(width: int, height: int, student_id: str) -> tuple[_TemplateVariant, ...]:
    return _build_portrait_variants(
        width,
        height,
        student_id,
        _REFINED_VARIANT_FACTORS,
        _REFINED_VARIANT_OFFSETS_X,
        _REFINED_VARIANT_OFFSETS_Y,
    )


def _build_portrait_variants(
    width: int,
    height: int,
    student_id: str,
    factors: tuple[float, ...],
    offsets_x: tuple[int, ...],
    offsets_y: tuple[int, ...],
) -> tuple[_TemplateVariant, ...]:
    path = _portrait_path(student_id)
    if path is None:
        return ()
    source = Image.open(path).convert("RGBA")
    source_width, source_height = source.size
    variants: list[_TemplateVariant] = []
    for factor in factors:
        scale = width / max(1, source_width) * factor
        resized_width = max(1, int(round(source_width * scale)))
        resized_height = max(1, int(round(source_height * scale)))
        arr = np.asarray(
            source.resize((resized_width, resized_height), Image.Resampling.LANCZOS),
            dtype=np.uint8,
        )
        for offset_x in offsets_x:
            for offset_y in offsets_y:
                canvas = np.zeros((height, width, 4), dtype=np.uint8)
                src_x0 = max(0, offset_x)
                src_y0 = max(0, offset_y)
                src_x1 = min(resized_width, offset_x + width)
                src_y1 = min(resized_height, offset_y + height)
                if src_x1 <= src_x0 or src_y1 <= src_y0:
                    continue
                dst_x0 = src_x0 - offset_x
                dst_y0 = src_y0 - offset_y
                canvas[
                    dst_y0 : dst_y0 + (src_y1 - src_y0),
                    dst_x0 : dst_x0 + (src_x1 - src_x0),
                ] = arr[src_y0:src_y1, src_x0:src_x1]
                alpha = canvas[:, :, 3]
                valid = alpha > 20
                if int(valid.sum()) < 350:
                    continue
                rgb = canvas[:, :, :3]
                variants.append(
                    _TemplateVariant(
                        student_id=student_id,
                        rgb=rgb.astype(np.float32),
                        gray=cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32),
                        hsv=cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV),
                        valid=valid,
                    )
                )
    return tuple(variants)


def _portrait_path(student_id: str) -> Path | None:
    portrait_dir = TEMPLATE_DIR / "students_portraits"
    template_name = student_meta.template_path(student_id)
    for path in (portrait_dir / template_name, portrait_dir / f"{student_id}.png"):
        if path.exists():
            return path
    return None


def _variant_score(
    crop_rgb: np.ndarray,
    crop_gray: np.ndarray,
    crop_hsv: np.ndarray,
    variant: _TemplateVariant,
) -> float:
    valid = variant.valid
    crop_pixels = crop_rgb[valid]
    tmpl_pixels = variant.rgb[valid]
    diff = 1.0 - float(np.mean(np.abs(crop_pixels - tmpl_pixels)) / 255.0)

    crop_gray_valid = crop_gray[valid].copy()
    tmpl_gray_valid = variant.gray[valid].copy()
    crop_gray_valid -= float(crop_gray_valid.mean())
    tmpl_gray_valid -= float(tmpl_gray_valid.mean())
    denominator = float(np.linalg.norm(crop_gray_valid) * np.linalg.norm(tmpl_gray_valid))
    corr = 0.0 if denominator < 1e-6 else float(np.dot(crop_gray_valid, tmpl_gray_valid) / denominator)
    corr = (corr + 1.0) / 2.0

    mask = valid.astype(np.uint8)
    crop_hist = cv2.calcHist([crop_hsv], [0, 1], mask, [18, 12], [0, 180, 0, 256])
    tmpl_hist = cv2.calcHist([variant.hsv], [0, 1], mask, [18, 12], [0, 180, 0, 256])
    cv2.normalize(crop_hist, crop_hist)
    cv2.normalize(tmpl_hist, tmpl_hist)
    hist = (float(cv2.compareHist(crop_hist, tmpl_hist, cv2.HISTCMP_CORREL)) + 1.0) / 2.0
    return max(0.0, min(1.0, 0.62 * corr + 0.20 * diff + 0.18 * hist))


def _detect_left_result(image: Image.Image) -> str:
    width, height = image.size
    crop = _relative_crop(image, 180, 340, 450, 500)
    arr = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    yellow = (
        (arr[:, :, 0] > 180)
        & (arr[:, :, 1] > 140)
        & (arr[:, :, 2] < 110)
    )
    threshold = max(40, int(width * height * 0.0008))
    return "win" if int(yellow.sum()) >= threshold else "loss"


def _detect_left_mode(image: Image.Image) -> str:
    crop = _relative_crop(image, 100, 360, 240, 500)
    arr = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    hsv = cv2.cvtColor(arr, cv2.COLOR_RGB2HSV)
    mask = (
        ((hsv[:, :, 0] > 85) & (hsv[:, :, 0] < 115) & (hsv[:, :, 1] > 80) & (hsv[:, :, 2] > 120))
        | ((arr[:, :, 2] > 150) & (arr[:, :, 1] > 120) & (arr[:, :, 0] < 120))
    )
    ys, xs = np.where(mask)
    if len(xs) < 20:
        return "attack"
    points = np.column_stack([xs, ys]).astype(np.float32)
    points -= points.mean(axis=0)
    covariance = np.cov(points.T)
    values, vectors = np.linalg.eig(covariance)
    vector = vectors[:, int(np.argmax(values))]
    angle = abs(float(np.degrees(np.arctan2(vector[1], vector[0]))))
    return "attack" if 30.0 <= angle <= 65.0 else "defense"


def _relative_crop(image: Image.Image, left: int, top: int, right: int, bottom: int) -> Image.Image:
    width, height = image.size
    sx = width / _BASE_WIDTH
    sy = height / _BASE_HEIGHT
    return image.crop(
        (
            int(round(left * sx)),
            int(round(top * sy)),
            int(round(right * sx)),
            int(round(bottom * sy)),
        )
    )
