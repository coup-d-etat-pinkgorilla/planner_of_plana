from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from functools import lru_cache
import json
import os
from pathlib import Path
import re
from typing import Sequence

import cv2
import numpy as np
from PIL import Image

import core.student_meta as student_meta
from core.config import REGIONS_DIR, TEMPLATE_DIR
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
_ANSWER_CACHE_STORE_SCORE = 0.80
_ANSWER_CACHE_STORE_MARGIN = 0.020
_ANSWER_CACHE_MAX_RECORDS_PER_SLOT = 24
TACTICAL_SCREENSHOT_IMAGE_SUFFIXES = frozenset({".png", ".jpg", ".jpeg", ".bmp", ".webp"})
_DATE_FOLDER_PATTERNS = (
    re.compile(r"^(?P<year>\d{4})[-_. ]?(?P<month>\d{2})[-_. ]?(?P<day>\d{2})$"),
    re.compile(r"^(?P<year>\d{2})(?P<month>\d{2})(?P<day>\d{2})$"),
)


@dataclass(slots=True)
class TacticalSlotMatch:
    slot_index: int
    student_id: str
    score: float
    runner_up_id: str = ""
    runner_up_score: float = 0.0
    role: str = ""
    visible: bool = True
    source: str = ""
    variant_factor: float = 0.0
    variant_offset_x: int = 0
    variant_offset_y: int = 0
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
    factor: float = 1.0
    offset_x: int = 0
    offset_y: int = 0


@dataclass(slots=True)
class _CandidateScore:
    score: float
    student_id: str
    variant: _TemplateVariant | None = None


@dataclass(slots=True)
class _SlotRoi:
    index: int
    x: int
    y: int
    width: int
    height: int


@dataclass(slots=True)
class _RoiProfile:
    name: str
    width: int
    height: int
    slots: dict[int, _SlotRoi]


class _AnswerCache:
    def __init__(self, path: str | Path | None):
        self.path = Path(path) if path else None
        self.records: dict[str, list[dict]] = {}
        self.dirty = False
        if self.path is not None:
            self._load()

    def _load(self) -> None:
        if self.path is None or not self.path.exists():
            return
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except Exception:
            return
        rows = raw.get("records") if isinstance(raw, dict) else None
        if not isinstance(rows, list):
            return
        for row in rows:
            if not isinstance(row, dict):
                continue
            student_id = str(row.get("student_id") or "").strip()
            resolution = str(row.get("resolution") or "").strip()
            try:
                slot_index = int(row.get("slot_index"))
            except Exception:
                continue
            if not student_id or not resolution:
                continue
            self.records.setdefault(self._key(resolution, slot_index), []).append(dict(row))

    @staticmethod
    def _resolution_key(width: int, height: int) -> str:
        return f"{int(width)}x{int(height)}"

    @staticmethod
    def _key(resolution: str, slot_index: int) -> str:
        return f"{resolution}:{int(slot_index)}"

    def hints(self, width: int, height: int, slot_index: int, role: str) -> list[dict]:
        key = self._key(self._resolution_key(width, height), slot_index)
        rows = []
        for row in self.records.get(key, []):
            student_id = str(row.get("student_id") or "")
            if student_meta.combat_class(student_id) != role:
                continue
            rows.append(row)
        rows.sort(key=lambda row: (float(row.get("score") or 0.0), int(row.get("uses") or 0)), reverse=True)
        return rows[:8]

    def remember(self, width: int, height: int, match: TacticalSlotMatch) -> None:
        if self.path is None or not match.student_id:
            return
        if match.score < _ANSWER_CACHE_STORE_SCORE or match.margin < _ANSWER_CACHE_STORE_MARGIN:
            return
        if not match.variant_factor:
            return
        resolution = self._resolution_key(width, height)
        key = self._key(resolution, match.slot_index)
        rows = self.records.setdefault(key, [])
        existing = None
        for row in rows:
            if (
                str(row.get("student_id")) == match.student_id
                and float(row.get("factor") or 0.0) == float(match.variant_factor)
                and int(row.get("offset_x") or 0) == int(match.variant_offset_x)
                and int(row.get("offset_y") or 0) == int(match.variant_offset_y)
            ):
                existing = row
                break
        if existing is None:
            rows.append(
                {
                    "resolution": resolution,
                    "slot_index": match.slot_index,
                    "student_id": match.student_id,
                    "factor": match.variant_factor,
                    "offset_x": match.variant_offset_x,
                    "offset_y": match.variant_offset_y,
                    "score": float(match.score),
                    "uses": 1,
                }
            )
        else:
            existing["score"] = max(float(existing.get("score") or 0.0), float(match.score))
            existing["uses"] = int(existing.get("uses") or 0) + 1
        rows.sort(key=lambda row: (float(row.get("score") or 0.0), int(row.get("uses") or 0)), reverse=True)
        del rows[_ANSWER_CACHE_MAX_RECORDS_PER_SLOT:]
        self.dirty = True

    def save(self) -> None:
        if self.path is None or not self.dirty:
            return
        rows = [row for bucket in self.records.values() for row in bucket]
        payload = {"version": 1, "records": rows}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(tmp, self.path)
        self.dirty = False


@dataclass(slots=True)
class _MatchContext:
    candidate_priority: dict[str, tuple[str, ...]]
    answer_cache: _AnswerCache

def is_tactical_screenshot_image(path: str | Path) -> bool:
    path = Path(path)
    if path.suffix.casefold() not in TACTICAL_SCREENSHOT_IMAGE_SUFFIXES:
        return False
    try:
        with Image.open(path) as image:
            width, height = image.size
    except Exception:
        return False
    if width <= 0 or height <= 0:
        return False
    target_ratio = _BASE_WIDTH / _BASE_HEIGHT
    return abs((width / height) - target_ratio) <= 0.01


def collect_tactical_screenshot_images(root: str | Path) -> list[Path]:
    root_path = Path(root)
    if not root_path.exists():
        return []
    if root_path.is_file():
        return [root_path] if is_tactical_screenshot_image(root_path) else []
    paths: list[Path] = []
    for path in root_path.rglob("*"):
        if path.is_file() and is_tactical_screenshot_image(path):
            paths.append(path)
    return sorted(paths, key=lambda path: tuple(part.casefold() for part in path.parts))


def tactical_screenshot_date_from_path(path: str | Path) -> str:
    for parent in Path(path).parents:
        parsed = _date_from_folder_name(parent.name)
        if parsed:
            return parsed
    return ""


def _date_from_folder_name(name: str) -> str:
    cleaned = str(name or "").strip()
    for pattern in _DATE_FOLDER_PATTERNS:
        match = pattern.match(cleaned)
        if match is None:
            continue
        year = int(match.group("year"))
        if year < 100:
            year += 2000
        month = int(match.group("month"))
        day = int(match.group("day"))
        try:
            return date(year, month, day).isoformat()
        except ValueError:
            return ""
    return ""


def _normalize_candidate_priority(candidate_priority: dict[str, Sequence[str]] | None) -> dict[str, tuple[str, ...]]:
    if not candidate_priority:
        return {}
    normalized: dict[str, tuple[str, ...]] = {}
    for role in ("striker", "special", "any"):
        seen: set[str] = set()
        values: list[str] = []
        for raw in candidate_priority.get(role, ()):
            student_id = str(raw or "").strip()
            if not student_id or student_id in seen:
                continue
            if _portrait_path(student_id) is None:
                continue
            if role != "any" and student_meta.combat_class(student_id) != role:
                continue
            seen.add(student_id)
            values.append(student_id)
        if values:
            normalized[role] = tuple(values)
    return normalized


@lru_cache(maxsize=1)
def _roi_profiles() -> tuple[_RoiProfile, ...]:
    path = REGIONS_DIR / "tactical_screenshot_regions.json"
    if not path.exists():
        return ()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return ()
    profiles: list[_RoiProfile] = []
    for item in raw.get("profiles", []):
        if not isinstance(item, dict):
            continue
        resolution = item.get("resolution") or []
        try:
            width = int(resolution[0])
            height = int(resolution[1])
        except Exception:
            continue
        slots: dict[int, _SlotRoi] = {}
        for row in item.get("slots", []):
            if not isinstance(row, dict):
                continue
            try:
                slot = _SlotRoi(
                    index=int(row.get("index")),
                    x=int(row.get("x")),
                    y=int(row.get("y")),
                    width=int(row.get("width")),
                    height=int(row.get("height")),
                )
            except Exception:
                continue
            if 0 <= slot.index < 12 and slot.width > 0 and slot.height > 0:
                slots[slot.index] = slot
        if len(slots) == 12 and width > 0 and height > 0:
            profiles.append(_RoiProfile(str(item.get("name") or "manual"), width, height, slots))
    return tuple(profiles)


def _roi_profile_for_image(width: int, height: int) -> _RoiProfile | None:
    profiles = _roi_profiles()
    if not profiles:
        return None
    exact = next((profile for profile in profiles if profile.width == width and profile.height == height), None)
    if exact is not None:
        return exact
    target_ratio = width / max(1, height)
    candidates = [
        profile
        for profile in profiles
        if abs((profile.width / max(1, profile.height)) - target_ratio) <= 0.01
    ]
    return candidates[0] if candidates else None

def parse_tactical_result_screenshot(
    path: str | Path,
    *,
    candidate_priority: dict[str, Sequence[str]] | None = None,
    answer_cache_path: str | Path | None = None,
) -> TacticalScreenshotReadout:
    image = Image.open(path).convert("RGB")
    image = _normalize_game_view(image)
    context = _MatchContext(
        candidate_priority=_normalize_candidate_priority(candidate_priority),
        answer_cache=_AnswerCache(answer_cache_path),
    )
    left_visible = [_slot_has_portrait(image, index) for index in range(6)]
    right_visible = [_slot_has_portrait(image, index) for index in range(6, 12)]
    left_role_hint = None if sum(left_visible) < 6 else "fixed"
    right_role_hint = None if sum(right_visible) < 6 else "fixed"
    left_slots = [
        _match_slot(image, index, role_hint=left_role_hint, context=context) if visible else _empty_slot(index)
        for index, visible in zip(range(6), left_visible)
    ]
    right_slots = [
        _match_slot(image, index, role_hint=right_role_hint, context=context) if visible else _empty_slot(index)
        for index, visible in zip(range(6, 12), right_visible)
    ]
    context.answer_cache.save()
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


def _match_slot(
    image: Image.Image,
    slot_index: int,
    *,
    role_hint: str | None = "fixed",
    context: _MatchContext | None = None,
) -> TacticalSlotMatch:
    context = context or _MatchContext({}, _AnswerCache(None))
    crop = _slot_crop(image, slot_index)
    crop_rgb = np.asarray(crop, dtype=np.uint8)
    crop_rgb_f = crop_rgb.astype(np.float32)
    crop_gray = cv2.cvtColor(crop_rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    crop_hsv = cv2.cvtColor(crop_rgb, cv2.COLOR_RGB2HSV)
    role = "striker" if slot_index % 6 < 4 else "special"
    candidate_role = role if role_hint == "fixed" else "any"

    cached_scores = _score_answer_cache_hints(
        image.width,
        image.height,
        crop,
        crop_rgb_f,
        crop_gray,
        crop_hsv,
        slot_index,
        role,
        context.answer_cache,
    )

    priority_ids = _priority_candidate_ids(candidate_role, context.candidate_priority)
    priority_scores = _coarse_score_candidates(crop, crop_rgb_f, crop_gray, crop_hsv, priority_ids)
    priority_set = set(priority_ids)
    fallback_ids = [student_id for student_id in _candidate_student_ids(candidate_role) if student_id not in priority_set]
    fallback_scores = _coarse_score_candidates(crop, crop_rgb_f, crop_gray, crop_hsv, fallback_ids)
    all_scores = _merge_candidate_scores(cached_scores, priority_scores, fallback_scores)
    refined_scores = _refine_scores(crop, crop_rgb_f, crop_gray, crop_hsv, all_scores)
    match = _match_from_ranked(slot_index, role, refined_scores or all_scores, source="verified")
    context.answer_cache.remember(image.width, image.height, match)
    return match


def _score_answer_cache_hints(
    image_width: int,
    image_height: int,
    crop: Image.Image,
    crop_rgb_f: np.ndarray,
    crop_gray: np.ndarray,
    crop_hsv: np.ndarray,
    slot_index: int,
    role: str,
    answer_cache: _AnswerCache,
) -> list[_CandidateScore]:
    ranked: list[_CandidateScore] = []
    for hint in answer_cache.hints(image_width, image_height, slot_index, role):
        student_id = str(hint.get("student_id") or "")
        try:
            factor = float(hint.get("factor") or 1.0)
            offset_x = int(hint.get("offset_x") or 0)
            offset_y = int(hint.get("offset_y") or 0)
        except Exception:
            continue
        variant = _specific_portrait_variant(crop.width, crop.height, student_id, factor, offset_x, offset_y)
        if variant is None:
            continue
        score = _variant_score(crop_rgb_f, crop_gray, crop_hsv, variant)
        ranked.append(_CandidateScore(float(score), student_id, variant))
    ranked.sort(key=lambda item: item.score, reverse=True)
    return ranked


def _merge_candidate_scores(*groups: Sequence[_CandidateScore]) -> list[_CandidateScore]:
    """Combine hint and full-pool scores without allowing group order to bias Top-K."""
    best_by_student: dict[str, _CandidateScore] = {}
    for group in groups:
        for candidate in group:
            current = best_by_student.get(candidate.student_id)
            if current is None or candidate.score > current.score:
                best_by_student[candidate.student_id] = candidate
    return sorted(best_by_student.values(), key=lambda item: item.score, reverse=True)


def _priority_candidate_ids(role: str, candidate_priority: dict[str, tuple[str, ...]]) -> tuple[str, ...]:
    if role == "any":
        role_ids = (
            *candidate_priority.get("striker", ()),
            *candidate_priority.get("special", ()),
            *candidate_priority.get("any", ()),
        )
    else:
        role_ids = (*candidate_priority.get(role, ()), *candidate_priority.get("any", ()))
    allowed = set(_candidate_student_ids(role))
    ordered: list[str] = []
    seen: set[str] = set()
    for student_id in role_ids:
        if student_id in seen or student_id not in allowed:
            continue
        ordered.append(student_id)
        seen.add(student_id)
    return tuple(ordered)


def _coarse_score_candidates(
    crop: Image.Image,
    crop_rgb_f: np.ndarray,
    crop_gray: np.ndarray,
    crop_hsv: np.ndarray,
    candidate_ids: Sequence[str],
) -> list[_CandidateScore]:
    scores: list[_CandidateScore] = []
    for student_id in candidate_ids:
        best: _CandidateScore | None = None
        for variant in _portrait_variants(crop.width, crop.height, student_id):
            score = _variant_score(crop_rgb_f, crop_gray, crop_hsv, variant)
            if best is None or score > best.score:
                best = _CandidateScore(float(score), student_id, variant)
        if best is not None:
            scores.append(best)
    scores.sort(key=lambda item: item.score, reverse=True)
    return scores


def _refine_scores(
    crop: Image.Image,
    crop_rgb_f: np.ndarray,
    crop_gray: np.ndarray,
    crop_hsv: np.ndarray,
    scores: Sequence[_CandidateScore],
) -> list[_CandidateScore]:
    refined: list[_CandidateScore] = []
    seen: set[str] = set()
    for coarse in scores:
        if coarse.student_id in seen:
            continue
        seen.add(coarse.student_id)
        best: _CandidateScore | None = None
        for variant in _refined_portrait_variants(crop.width, crop.height, coarse.student_id):
            score = _variant_score(crop_rgb_f, crop_gray, crop_hsv, variant)
            if best is None or score > best.score:
                best = _CandidateScore(float(score), coarse.student_id, variant)
        if best is not None:
            refined.append(best)
        if len(refined) >= _REFINED_CANDIDATE_COUNT:
            break
    refined.sort(key=lambda item: item.score, reverse=True)
    return refined


def _match_from_ranked(slot_index: int, role: str, ranked: Sequence[_CandidateScore], *, source: str) -> TacticalSlotMatch:
    best = ranked[0] if ranked else _CandidateScore(0.0, "", None)
    runner_up = ranked[1] if len(ranked) > 1 else _CandidateScore(0.0, "", None)
    variant = best.variant
    return TacticalSlotMatch(
        slot_index=slot_index,
        student_id=best.student_id,
        score=best.score,
        runner_up_id=runner_up.student_id,
        runner_up_score=runner_up.score,
        role=role,
        visible=True,
        source=source,
        variant_factor=float(variant.factor) if variant is not None else 0.0,
        variant_offset_x=int(variant.offset_x) if variant is not None else 0,
        variant_offset_y=int(variant.offset_y) if variant is not None else 0,
    )


def _slot_crop(image: Image.Image, slot_index: int) -> Image.Image:
    width, height = image.size
    profile = _roi_profile_for_image(width, height)
    if profile is not None and slot_index in profile.slots:
        slot = profile.slots[slot_index]
        scale_x = width / max(1, profile.width)
        scale_y = height / max(1, profile.height)
        left = int(round(slot.x * scale_x))
        top = int(round(slot.y * scale_y))
        crop_width = max(24, int(round(slot.width * scale_x)))
        crop_height = max(24, int(round(slot.height * scale_y)))
        return image.crop((left, top, left + crop_width, top + crop_height))

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
                        factor=float(factor),
                        offset_x=int(offset_x),
                        offset_y=int(offset_y),
                    )
                )
    return tuple(variants)


@lru_cache(maxsize=8192)
def _specific_portrait_variant(
    width: int,
    height: int,
    student_id: str,
    factor: float,
    offset_x: int,
    offset_y: int,
) -> _TemplateVariant | None:
    variants = _build_portrait_variants(
        width,
        height,
        student_id,
        (float(factor),),
        (int(offset_x),),
        (int(offset_y),),
    )
    return variants[0] if variants else None

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
