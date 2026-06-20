"""
core/matcher.py — BA Analyzer v6
OpenCV 템플릿 매칭 엔진

변경점 (v5 → v6):
  - 전처리 코드 제거 → core/preprocess.py 위임
  - 파일 I/O 제거 → core/template_cache.py 위임
    · _load_tmpl (lru_cache) 완전 제거
    · 모든 템플릿 접근은 _tmpl(path) 헬퍼를 통해 캐시에서만 읽음
  - 함수 내부에 Image.open / cv2.imread / lru_cache 없음
  - 디버그 로그 포맷 통일: [Matcher] {함수명}: {결과} ({점수:.3f})
"""

from __future__ import annotations

import cv2
import numpy as np
import os
from functools import lru_cache
from enum import Enum
from pathlib import Path
from PIL import Image
from typing import Iterable, Optional

from core.config import TEMPLATE_DIR
from core.logger import get_logger, LOG_MATCHER
from core.log_context import MatchCtx, log_exc, log_cv2_error, EXC_DEBUG, dump_roi

_log = get_logger(LOG_MATCHER)
from core.preprocess import (
    to_gray,
    to_bgr,
    normalize_hist,
    binarize,
    focus_center_crop,
    preprocess_for_template,
    preprocess_for_masked_template,
    preprocess_for_text_template,
    preprocess_for_color_hist,
    calc_color_hist,
)
from core.template_cache import get_cache, TemplateEntry
from core.quad_roi import (
    binary_glyph_similarity,
    normalize_binary_glyph,
    otsu_binary,
    warp_quad_region,
)


# ══════════════════════════════════════════════════════════
# 인식 결과 메타정보 타입
# ══════════════════════════════════════════════════════════

from dataclasses import dataclass, field as dc_field
from enum import Enum as _Enum


class RecogSource(_Enum):
    """인식 방법 태그 — 디버그 추적용."""
    TEMPLATE_RESIZED = "template_resized"   # match_score_resized
    TEMPLATE_MASKED  = "template_masked"    # match_masked_icon
    TEMPLATE_TEXT    = "template_text"      # match_score_textonly
    TEMPLATE_RAW     = "template_raw"       # match_score (원본 크기)
    COLOR_HIST       = "color_hist"         # _color_hist_score
    COMBINED         = "combined"           # 여러 방법 혼합
    OCR              = "ocr"                # EasyOCR
    SKIPPED          = "skipped"            # 조건 미충족으로 스킵
    FALLBACK         = "fallback"           # 기본값 사용


@dataclass
class RecognitionResult:
    """
    인식 결과 + 신뢰도 메타정보.

    Attributes
    ----------
    value      : 인식된 값 (int / str / None)
    score      : 유사도 점수 0.0~1.0 (높을수록 확실)
    source     : 어떤 방법으로 인식했는지
    uncertain  : True 이면 score 가 UNCERTAIN 구간 (재검토 권장)
    label      : 로그용 짧은 설명 (자동 생성)

    사용 예
    -------
    r = read_skill_result(crop, "EX_Skill")
    if r.uncertain:
        log(f"[경고] EX 스킬 인식 불확실: {r.value} ({r.score:.3f})")
    entry.ex_skill = r.value
    """
    value:    Optional[int | str]
    score:    float
    source:   RecogSource       = RecogSource.TEMPLATE_RESIZED
    uncertain: bool             = False
    label:    str               = ""

    def __post_init__(self):
        if not self.label:
            self.label = f"{self.source.value}:{self.value}({self.score:.3f})"

    @classmethod
    def skipped(cls, reason: str = "") -> "RecognitionResult":
        """조건 미충족으로 스킵된 결과."""
        return cls(value=None, score=0.0,
                   source=RecogSource.SKIPPED, label=f"skipped:{reason}")

    @classmethod
    def fallback(cls, value, reason: str = "") -> "RecognitionResult":
        """기본값으로 대체된 결과."""
        return cls(value=value, score=0.0,
                   source=RecogSource.FALLBACK, label=f"fallback:{reason}")


# ── 신뢰도 구간 상수 ──────────────────────────────────────
# score 가 이 두 임계값 사이(SCORE_UNCERTAIN ~ SCORE_CONFIDENT)면
# uncertain=True 로 마킹
SCORE_CONFIDENT  = 0.75   # 이상이면 확실
SCORE_UNCERTAIN  = 0.55   # 이상 CONFIDENT 미만이면 불확실
                           # 미만이면 실패(value=None 처리)


def _make_result(
    value:    Optional[int | str],
    score:    float,
    source:   RecogSource,
    *,
    confident_thresh:  float = SCORE_CONFIDENT,
    uncertain_thresh:  float = SCORE_UNCERTAIN,
) -> RecognitionResult:
    """
    score 구간에 따라 uncertain 플래그를 자동 설정하는 팩토리.

    score >= confident_thresh → uncertain=False
    score >= uncertain_thresh → uncertain=True  (애매한 결과지만 반환)
    score <  uncertain_thresh → value=None, uncertain=True (실패)
    """
    if value is None:
        return RecognitionResult(value=None, score=score,
                                 source=source, uncertain=True)
    if score >= confident_thresh:
        return RecognitionResult(value=value, score=score,
                                 source=source, uncertain=False)
    if score >= uncertain_thresh:
        return RecognitionResult(value=value, score=score,
                                 source=source, uncertain=True)
    # score 미달 → 실패
    return RecognitionResult(value=None, score=score,
                             source=source, uncertain=True)


# ── 템플릿 접근 헬퍼 ──────────────────────────────────────

def _tmpl(path: str) -> Optional[TemplateEntry]:
    """
    경로로 캐시에서 TemplateEntry 조회.
    캐시 미스 시 on-demand 로드 후 반환.
    파일 없으면 None.
    """
    cache = get_cache()
    entry = cache.get_by_path(path)
    if entry is not None:
        return entry
    # warmup 에 포함되지 않은 파일 — on-demand 로드
    return cache.load(path)


# ══════════════════════════════════════════════════════════
# 매칭 임계값
# ══════════════════════════════════════════════════════════

THRESHOLD         = 0.80
THRESHOLD_LOOSE   = 0.72
THRESHOLD_LOBBY   = 0.90
THRESHOLD_STUDENT_MENU = 0.90
THRESHOLD_STUDENT_ADDITIONAL_MENU = 0.90
THRESHOLD_STUDENT_TAB_ON = 0.90
TEXTURE_THRESHOLD        = 0.60
TEXTURE_MARGIN_REQUIRED  = 0.05
STUDENT_TEXTURE_TOP_K = 10
STUDENT_TEXTURE_SHORTCUT_SCORE = 0.86
STUDENT_TEXTURE_SHORTCUT_MARGIN = 0.10
STUDENT_TEXTURE_TOP_K_ENV = "BA_STUDENT_TOPK"
STUDENT_TEXTURE_TOPK_METHOD_ENV = "BA_STUDENT_TOPK_METHOD"
STUDENT_TEXTURE_TOPK_SHADOW_ENV = "BA_STUDENT_TOPK_SHADOW"
STUDENT_TEXTURE_TOPK_METHODS = {"fusion", "hybrid", "thumb", "hist", "hash"}
WEAPON_STATE_MIN_SCORE = 0.62
WEAPON_EQUIPPED_MIN_SCORE = 0.78
WEAPON_EQUIPPED_MARGIN_REQUIRED = 0.12
WEAPON_EQUIPPED_ORANGE_RATIO = 0.12


# ══════════════════════════════════════════════════════════
# 디렉터리 / 파일 상수
# ══════════════════════════════════════════════════════════

STUDENT_TEXTURE_DIR = "students"
WEAPON_STATE_DIR    = "weapon_state"
SKILL_CHECK_DIR     = "skillcheck"
BASIC_SKILL_DIR     = "basic_skill"
EQUIP_CHECK_DIR     = "equipcheck"

WEAPON_STATE_FILES = {
    "no_weapon":       "NO_WEAPON_SYSTEM.png",
    "weapon_locked":   "WEAPON_UNLOCKED_NOT_EQUIPPED.png",
    "weapon_unlocked": "WEAPON_EQUIPPED.png",
}

STAT_DIRS = {
    "hp":   "stat_hp",
    "atk":  "stat_atk",
    "heal": "stat_heal",
}


# ══════════════════════════════════════════════════════════
# Enum
# ══════════════════════════════════════════════════════════

class WeaponState(Enum):
    NO_WEAPON_SYSTEM             = "no_weapon_system"
    WEAPON_EQUIPPED              = "weapon_equipped"
    WEAPON_UNLOCKED_NOT_EQUIPPED = "weapon_unlocked_not_equipped"

WeaponStatus = WeaponState   # 하위 호환


class CheckFlag(Enum):
    TRUE       = "true"
    FALSE      = "false"
    IMPOSSIBLE = "impossible"


class EquipSlotFlag(Enum):
    NORMAL       = "normal"
    EMPTY        = "empty"
    LEVEL_LOCKED = "level_locked"
    LOVE_LOCKED  = "love_locked"
    NULL         = "null"


# ── _load_tmpl 은 제거됨 → _tmpl() 헬퍼 사용 (파일 상단)


# ══════════════════════════════════════════════════════════
# 기본 매칭 함수
# ══════════════════════════════════════════════════════════

def match_score(crop: Image.Image, tmpl_path: str) -> float:
    """
    원본 해상도 TM_CCOEFF_NORMED 매칭 (알파 마스크 지원).
    파일 I/O 없음 — _tmpl() 캐시에서 읽음.
    """
    entry = _tmpl(tmpl_path)
    if entry is None:
        return 0.0
    bgr_c = to_bgr(crop)
    if entry.bgr.shape[0] > bgr_c.shape[0] or entry.bgr.shape[1] > bgr_c.shape[1]:
        return 0.0
    try:
        if entry.has_alpha and entry.alpha.max() > 0:
            res = cv2.matchTemplate(bgr_c, entry.bgr, cv2.TM_CCORR_NORMED,
                                    mask=entry.alpha)
        else:
            res = cv2.matchTemplate(bgr_c, entry.bgr, cv2.TM_CCOEFF_NORMED)
        _, val, _, _ = cv2.minMaxLoc(res)
        return float(val)
    except cv2.error as e:
        log_cv2_error(_log, "match_score 실패", e,
                      ctx=MatchCtx(roi=Path(tmpl_path).stem))
        return 0.0


def match_score_resized(
    crop: Image.Image,
    tmpl_path: str,
    focus_center: bool = False,
) -> float:
    """
    crop 을 템플릿 크기에 맞춰 리사이즈 후 이진화 비교.
    전처리: preprocess_for_template()
    점수: NCC 0.7 + pixel_diff 0.3
    파일 I/O 없음 — _tmpl() 캐시에서 읽음.
    """
    entry = _tmpl(tmpl_path)
    if entry is None:
        return 0.0

    h_t, w_t = entry.gray.shape[:2]
    if h_t < 2 or w_t < 2:
        return 0.0

    crop_proc = preprocess_for_template(crop, w_t, h_t, use_focus_crop=focus_center)
    tmpl_proc = _preprocess_tmpl_gray(entry.gray, w_t, h_t, use_focus_crop=focus_center)

    return _ncc_diff_score(crop_proc, tmpl_proc)


def match_score_resized_raw(
    crop: Image.Image,
    tmpl_path: str,
) -> float:
    """
    Resize-only color template score for item/equipment images.

    This intentionally does not normalize, binarize, grayscale, or otherwise
    preprocess the image. Inventory icons/detail art rely on their original
    color and texture; preprocessing is reserved for text, numbers, and UI
    state templates.
    """
    entry = _tmpl(tmpl_path)
    if entry is None:
        return 0.0

    h_t, w_t = entry.bgr.shape[:2]
    if h_t < 2 or w_t < 2:
        return 0.0

    crop_bgr = to_bgr(crop)
    crop_bgr = cv2.resize(crop_bgr, (w_t, h_t), interpolation=cv2.INTER_AREA)
    tmpl_bgr = entry.bgr

    try:
        if entry.has_alpha and entry.alpha is not None and entry.alpha.max() > 0:
            alpha = cv2.resize(entry.alpha, (w_t, h_t), interpolation=cv2.INTER_NEAREST)
            valid = alpha > ALPHA_THRESH
            if not np.any(valid):
                return 0.0
            diff = np.mean(
                np.abs(
                    crop_bgr.astype(np.float32) - tmpl_bgr.astype(np.float32)
                )[valid]
            ) / 255.0
            return max(0.0, min(1.0, 1.0 - float(diff)))

        res = cv2.matchTemplate(crop_bgr, tmpl_bgr, cv2.TM_CCOEFF_NORMED)
        _, ncc, _, _ = cv2.minMaxLoc(res)
        diff = np.mean(
            np.abs(crop_bgr.astype(np.float32) - tmpl_bgr.astype(np.float32))
        ) / 255.0
        return 0.65 * float(ncc) + 0.35 * (1.0 - float(diff))
    except cv2.error as e:
        log_cv2_error(_log, "match_score_resized_raw failed", e,
                      ctx=MatchCtx(roi=Path(tmpl_path).stem))
        return 0.0


def match_score_resized_masked(
    crop: Image.Image,
    tmpl_path: str,
    focus_center: bool = False,
    binarize_flag: bool = True,
) -> float:
    """
    알파 마스크 기반 리사이즈 매칭.
    전처리: preprocess_for_masked_template()
    점수: corr 0.50 + diff 0.30 + edge 0.20
    파일 I/O 없음 — _tmpl() 캐시에서 읽음.
    """
    entry = _tmpl(tmpl_path)
    if entry is None:
        return 0.0

    h_t, w_t = entry.gray.shape[:2]
    if h_t < 2 or w_t < 2:
        return 0.0

    crop_proc, alpha_r = preprocess_for_masked_template(
        crop, w_t, h_t, entry.alpha,
        use_focus_crop=focus_center,
        do_binarize=binarize_flag,
    )
    tmpl_proc = _preprocess_tmpl_gray(entry.gray, w_t, h_t,
                                      use_focus_crop=focus_center,
                                      do_binarize=binarize_flag)

    # alpha_r 이 focus_crop 으로 잘렸을 수 있으니 크기 재확인
    h_p, w_p = crop_proc.shape[:2]
    if alpha_r is None:
        alpha_r = np.full((h_p, w_p), 255, dtype=np.uint8)
    else:
        alpha_r = cv2.resize(alpha_r, (w_p, h_p), interpolation=cv2.INTER_NEAREST)

    valid = alpha_r > 0
    if not np.any(valid):
        return 0.0

    crop_f = crop_proc.astype(np.float32)
    tmpl_f = tmpl_proc.astype(np.float32)

    masked_diff = np.abs(crop_f - tmpl_f)[valid].mean() / 255.0
    diff_score  = 1.0 - float(masked_diff)

    cv_  = crop_f[valid] - crop_f[valid].mean()
    tv_  = tmpl_f[valid] - tmpl_f[valid].mean()
    dnom = np.linalg.norm(cv_) * np.linalg.norm(tv_)
    corr = 0.0 if dnom < 1e-6 else float(np.dot(cv_, tv_) / dnom)
    corr = max(0.0, min(1.0, (corr + 1.0) / 2.0))

    crop_edge = cv2.Canny(crop_proc, 50, 150)
    tmpl_edge = cv2.Canny(tmpl_proc, 50, 150)
    edge_score = 1.0 - float(
        np.abs(crop_edge.astype(np.float32) - tmpl_edge.astype(np.float32))[valid].mean() / 255.0
    )

    return 0.50 * corr + 0.30 * diff_score + 0.20 * edge_score


def match_score_textonly(crop: Image.Image, tmpl_path: str) -> float:
    """
    텍스트(숫자) 픽셀만 추출해서 비교.
    전처리: preprocess_for_text_template()
    점수: NCC 0.7 + pixel_diff 0.3
    파일 I/O 없음 — _tmpl() 캐시에서 읽음.
    """
    entry = _tmpl(tmpl_path)
    if entry is None:
        return 0.0

    h_t, w_t = entry.gray.shape[:2]
    if h_t < 2 or w_t < 2:
        return 0.0

    crop_proc = preprocess_for_text_template(crop, w_t, h_t)
    tmpl_proc = preprocess_for_text_template(
        Image.fromarray(entry.gray), w_t, h_t
    )
    return _ncc_diff_score(crop_proc, tmpl_proc)


# ── 내부 헬퍼 ─────────────────────────────────────────────

def _preprocess_tmpl_gray(
    tmpl_g: np.ndarray,
    w: int,
    h: int,
    use_focus_crop: bool = False,
    do_binarize: bool = True,
) -> np.ndarray:
    """
    이미 로드된 템플릿 gray ndarray 를 동일 파이프라인으로 전처리.
    (PIL Image 변환 없이 바로 처리해 속도 절감)
    """
    arr = cv2.resize(tmpl_g, (w, h), interpolation=cv2.INTER_AREA)
    arr = normalize_hist(arr)
    if do_binarize:
        arr = binarize(arr)
    if use_focus_crop:
        arr, _ = focus_center_crop(arr)
    return arr


def _ncc_diff_score(a: np.ndarray, b: np.ndarray) -> float:
    """NCC 0.7 + pixel_diff 0.3 점수."""
    if a.shape != b.shape:
        b = cv2.resize(b, (a.shape[1], a.shape[0]), interpolation=cv2.INTER_AREA)
    try:
        res = cv2.matchTemplate(a, b, cv2.TM_CCOEFF_NORMED)
        _, ncc, _, _ = cv2.minMaxLoc(res)
        diff = np.mean(np.abs(a.astype(np.float32) - b.astype(np.float32))) / 255.0
        return 0.7 * float(ncc) + 0.3 * (1.0 - float(diff))
    except cv2.error as e:
        log_cv2_error(_log, "_ncc_diff_score 실패", e)
        return 0.0


# ══════════════════════════════════════════════════════════
# 마스크 매칭 표준화 레이어
# ══════════════════════════════════════════════════════════
#
# 규칙:
#   - RGBA 템플릿  → 알파 채널을 마스크로 사용  (has_alpha=True)
#   - RGB 템플릿   → 마스크 없음, 전체 픽셀 비교
#   - 알파 threshold: ALPHA_THRESH (기본 30) 이상인 픽셀만 유효
#   - 호출 지점 구분:
#       별 / 무기별 / 아이콘  → match_masked_icon()   사용
#       일반 UI 템플릿        → match_score_resized()  사용
#       텍스트/숫자           → match_score_textonly() 사용
#   - 두 경로를 섞어 쓰지 않도록 read_star / read_weapon_star 등에서
#     반드시 match_masked_icon() 만 호출할 것
#
# ══════════════════════════════════════════════════════════

# 알파 유효 픽셀 최소값 (0~255). 이 값 미만은 배경으로 간주.
ALPHA_THRESH: int = 30

# 마스크 매칭 점수 가중치
_MASK_W_CORR = 0.50
_MASK_W_DIFF = 0.30
_MASK_W_EDGE = 0.20


def _build_alpha_mask(
    alpha: Optional[np.ndarray],
    target_h: int,
    target_w: int,
    thresh: int = ALPHA_THRESH,
) -> np.ndarray:
    """
    알파 채널 → boolean 마스크 (유효 픽셀 = True).

    Parameters
    ----------
    alpha    : 템플릿 알파 채널 (H×W uint8). None 이면 전체 유효.
    target_h : 리사이즈 목표 높이
    target_w : 리사이즈 목표 너비
    thresh   : 유효 픽셀 최소 알파값

    Returns
    -------
    bool ndarray (target_h × target_w)
    """
    if alpha is None:
        return np.ones((target_h, target_w), dtype=bool)

    resized = cv2.resize(alpha, (target_w, target_h),
                         interpolation=cv2.INTER_NEAREST)
    return resized >= thresh


def _masked_score(
    crop_g: np.ndarray,
    tmpl_g: np.ndarray,
    mask:   np.ndarray,
) -> float:
    """
    마스크 영역만 비교하는 점수 계산.
    corr 0.50 + diff 0.30 + edge 0.20

    Parameters
    ----------
    crop_g : 전처리된 crop grayscale (H×W uint8)
    tmpl_g : 전처리된 template grayscale (H×W uint8)
    mask   : 유효 픽셀 boolean mask (H×W)

    Returns
    -------
    float 0.0 ~ 1.0
    """
    if not np.any(mask):
        return 0.0

    cf = crop_g.astype(np.float32)
    tf = tmpl_g.astype(np.float32)

    # ── diff score ────────────────────────────────────────
    diff_score = 1.0 - float(np.abs(cf - tf)[mask].mean() / 255.0)

    # ── correlation score ─────────────────────────────────
    cv_ = cf[mask] - cf[mask].mean()
    tv_ = tf[mask] - tf[mask].mean()
    dnom = np.linalg.norm(cv_) * np.linalg.norm(tv_)
    corr_raw = 0.0 if dnom < 1e-6 else float(np.dot(cv_, tv_) / dnom)
    corr = max(0.0, min(1.0, (corr_raw + 1.0) / 2.0))

    # ── edge score ────────────────────────────────────────
    # Canny 는 uint8 배열 필요
    crop_u8 = crop_g
    tmpl_u8 = tmpl_g
    crop_edge = cv2.Canny(crop_u8, 50, 150)
    tmpl_edge = cv2.Canny(tmpl_u8, 50, 150)
    edge_score = 1.0 - float(
        np.abs(crop_edge.astype(np.float32)
               - tmpl_edge.astype(np.float32))[mask].mean() / 255.0
    )

    return (_MASK_W_CORR * corr
            + _MASK_W_DIFF * diff_score
            + _MASK_W_EDGE * edge_score)


def match_masked_icon(
    crop:      Image.Image,
    tmpl_path: str,
    *,
    target_size: Optional[tuple[int, int]] = None,
    thresh:      int = ALPHA_THRESH,
) -> float:
    """
    아이콘/별/무기별 전용 마스크 매칭 함수.

    - RGBA 템플릿이면 알파를 마스크로 사용 → 배경 완전 무시
    - RGB  템플릿이면 전체 픽셀 비교 (하위 호환)
    - 항상 캐시에서 템플릿 읽음 (파일 I/O 없음)

    Parameters
    ----------
    crop        : 비교 대상 PIL Image (이미 crop 된 ROI)
    tmpl_path   : 템플릿 파일 절대 경로
    target_size : (w, h) 리사이즈 목표. None 이면 템플릿 원본 크기 사용.
    thresh      : 유효 픽셀 최소 알파값 (ALPHA_THRESH)

    Returns
    -------
    float 0.0 ~ 1.0
    """
    entry = _tmpl(tmpl_path)
    if entry is None:
        return 0.0

    # 목표 크기 결정
    if target_size is not None:
        w_t, h_t = target_size
    else:
        h_t, w_t = entry.gray.shape[:2]

    if h_t < 2 or w_t < 2:
        return 0.0

    # crop 전처리 (gray + normalize + binarize)
    crop_proc = preprocess_for_template(crop, w_t, h_t)

    # 템플릿 전처리 (캐시된 gray 재사용)
    tmpl_proc = _preprocess_tmpl_gray(entry.gray, w_t, h_t)

    # 마스크 생성
    mask = _build_alpha_mask(entry.alpha, h_t, w_t, thresh=thresh)

    return _masked_score(crop_proc, tmpl_proc, mask)


def best_match_masked_icons(
    crop:       Image.Image,
    candidates: dict[str, str],
    threshold:  float = 0.68,
    thresh:     int   = ALPHA_THRESH,
) -> tuple[Optional[str], float]:
    """
    후보 아이콘 집합에서 마스크 매칭으로 최고 점수 라벨 반환.

    Parameters
    ----------
    crop       : 비교 대상 PIL Image
    candidates : {label: tmpl_path} 매핑
    threshold  : 최소 점수 (이 이상일 때만 반환)
    thresh     : 유효 픽셀 최소 알파값

    Returns
    -------
    (best_label, best_score)  점수 미달 시 (None, best_score)
    """
    best_lbl:  Optional[str] = None
    best_scr:  float         = threshold

    for lbl, path in candidates.items():
        s = match_masked_icon(crop, path, thresh=thresh)
        if s > best_scr:
            best_scr = s
            best_lbl = lbl

    return best_lbl, best_scr


def best_match(
    crop: Image.Image,
    candidates: dict[str, str],
    threshold: float = THRESHOLD,
    resized: bool = False,
    focus_center: bool = False,
    masked: bool = False,
) -> tuple[Optional[str], float]:
    """
    후보 집합에서 최고 점수 라벨 반환.

    Parameters
    ----------
    masked : True 이면 match_masked_icon() 으로 위임.
             별/아이콘 인식은 best_match_masked_icons() 를 직접 호출할 것.
             이 파라미터는 하위 호환을 위해 유지하되 내부에서 표준 경로로 위임.
    """
    if masked:
        return best_match_masked_icons(crop, candidates, threshold=threshold)

    best_lbl, best_scr = None, threshold
    for lbl, path in candidates.items():
        s = (match_score_resized(crop, path, focus_center=focus_center)
             if resized else match_score(crop, path))
        if s > best_scr:
            best_scr, best_lbl = s, lbl
    return best_lbl, best_scr


# ══════════════════════════════════════════════════════════
# 로비 감지
# ══════════════════════════════════════════════════════════

_MENU_DETECT_DIR = TEMPLATE_DIR / "menu_detect_flag"
_LOBBY_TMPL = str(_MENU_DETECT_DIR / "lobby_template.png")
_STUDENT_MENU_TMPL = str(_MENU_DETECT_DIR / "student_menu__menu_detect_flag.png")
_STUDENT_ADDITIONAL_MENU_ON_TMPL = str(_MENU_DETECT_DIR / "student_additional_menu_on_flag.png")
_LEVELCHECK_BUTTON_ON_TMPL = str(_MENU_DETECT_DIR / "student_data__levelcheck_button_on.png")
_BASIC_INFO_BUTTON_ON_TMPL = str(_MENU_DETECT_DIR / "student_data__basic_info_button_on.png")
_STAR_MENU_BUTTON_ON_TMPL = str(_MENU_DETECT_DIR / "student_data__star_menu_button_on.png")


def _match_menu_flag(
    img: Image.Image,
    region: dict,
    tmpl_path: str,
    *,
    label: str,
    threshold: float,
) -> bool:
    from core.capture import crop_region
    crop  = crop_region(img, region)
    score = match_score(crop, tmpl_path)
    _log.debug(f"{label}: {score:.3f}")
    return score >= threshold


def is_lobby(img: Image.Image, region: dict) -> bool:
    return _match_menu_flag(
        img,
        region,
        _LOBBY_TMPL,
        label="is_lobby",
        threshold=THRESHOLD_LOBBY,
    )


def is_student_menu(img: Image.Image, region: dict) -> bool:
    return _match_menu_flag(
        img,
        region,
        _STUDENT_MENU_TMPL,
        label="is_student_menu",
        threshold=THRESHOLD_STUDENT_MENU,
    )


def is_student_additional_menu_on(img: Image.Image, region: dict) -> bool:
    return _match_menu_flag(
        img,
        region,
        _STUDENT_ADDITIONAL_MENU_ON_TMPL,
        label="is_student_additional_menu_on",
        threshold=THRESHOLD_STUDENT_ADDITIONAL_MENU,
    )


def is_level_tab_on(img: Image.Image, region: dict) -> bool:
    return _match_menu_flag(
        img,
        region,
        _LEVELCHECK_BUTTON_ON_TMPL,
        label="is_level_tab_on",
        threshold=THRESHOLD_STUDENT_TAB_ON,
    )


def is_basic_info_tab_on(img: Image.Image, region: dict) -> bool:
    return _match_menu_flag(
        img,
        region,
        _BASIC_INFO_BUTTON_ON_TMPL,
        label="is_basic_info_tab_on",
        threshold=THRESHOLD_STUDENT_TAB_ON,
    )


def is_star_tab_on(img: Image.Image, region: dict) -> bool:
    return _match_menu_flag(
        img,
        region,
        _STAR_MENU_BUTTON_ON_TMPL,
        label="is_star_tab_on",
        threshold=THRESHOLD_STUDENT_TAB_ON,
    )


# ══════════════════════════════════════════════════════════
# 학생 텍스처 매칭
# ══════════════════════════════════════════════════════════

def _color_hist_score(crop: Image.Image, tmpl_path: str) -> float:
    """컬러 히스토그램 유사도. 파일 I/O 없음 — _tmpl() 캐시에서 읽음."""
    entry = _tmpl(tmpl_path)
    if entry is None:
        return 0.0
    try:
        hsv_c = preprocess_for_color_hist(crop)
        tmpl_small = cv2.resize(entry.bgr, (64, 64), interpolation=cv2.INTER_AREA)
        hsv_t = cv2.cvtColor(tmpl_small, cv2.COLOR_BGR2HSV)
        hc = calc_color_hist(hsv_c)
        ht = calc_color_hist(hsv_t)
        return max(0.0, float(cv2.compareHist(hc, ht, cv2.HISTCMP_CORREL)))
    except cv2.error as e:
        log_cv2_error(_log, "color_hist_score 실패", e,
                      ctx=MatchCtx(roi=Path(tmpl_path).stem))
        return 0.0


@dataclass(frozen=True)
class _StudentTextureFeature:
    sid: str
    path: str
    thumb: np.ndarray
    hist: np.ndarray
    ahash: np.ndarray


_STUDENT_TEXTURE_FEATURE_CACHE: dict[str, _StudentTextureFeature] | None = None
_STUDENT_TEXTURE_TOPK_CONFIG_LOGGED: set[tuple[str, int]] = set()


def _student_texture_thumb(img: Image.Image) -> np.ndarray:
    small = img.convert("RGB").resize((32, 32), Image.BILINEAR)
    return np.asarray(small, dtype=np.float32) / 255.0


def _student_texture_hist(img: Image.Image) -> np.ndarray:
    arr = np.asarray(img.convert("RGB").resize((48, 48), Image.BILINEAR), dtype=np.uint8)
    bins = 4
    quantized = np.clip(arr // (256 // bins), 0, bins - 1)
    idx = (
        quantized[:, :, 0].astype(np.int32) * bins * bins
        + quantized[:, :, 1].astype(np.int32) * bins
        + quantized[:, :, 2].astype(np.int32)
    )
    hist = np.bincount(idx.ravel(), minlength=bins ** 3).astype(np.float32)
    total = float(hist.sum())
    if total > 0:
        hist /= total
    return hist


def _student_texture_hash(img: Image.Image) -> np.ndarray:
    gray = img.convert("L").resize((16, 16), Image.BILINEAR)
    arr = np.asarray(gray, dtype=np.float32)
    return (arr >= float(arr.mean())).astype(np.uint8)


def _student_texture_topk_from_env(default: int = STUDENT_TEXTURE_TOP_K) -> int:
    raw = os.environ.get(STUDENT_TEXTURE_TOP_K_ENV, "").strip()
    if not raw:
        return default
    try:
        return max(0, int(raw))
    except ValueError:
        _log.warning("invalid %s=%r -> using %d", STUDENT_TEXTURE_TOP_K_ENV, raw, default)
        return default


def _student_texture_topk_method_from_env() -> str:
    raw = os.environ.get(STUDENT_TEXTURE_TOPK_METHOD_ENV, "fusion").strip().lower()
    if raw in STUDENT_TEXTURE_TOPK_METHODS:
        return raw
    _log.warning(
        "invalid %s=%r -> using fusion",
        STUDENT_TEXTURE_TOPK_METHOD_ENV,
        raw,
    )
    return "fusion"


def _student_texture_topk_shadow_from_env() -> bool:
    return os.environ.get(STUDENT_TEXTURE_TOPK_SHADOW_ENV, "").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def _log_student_texture_topk_config(method: str, top_k: int) -> None:
    key = (method, top_k)
    if key in _STUDENT_TEXTURE_TOPK_CONFIG_LOGGED:
        return
    _STUDENT_TEXTURE_TOPK_CONFIG_LOGGED.add(key)
    _log.info(
        "student_texture_topk_config experiment=%r method=%s k=%d shadow=%s env_%s=%r env_%s=%r",
        os.environ.get("BA_STUDENT_TOPK_EXPERIMENT"),
        method,
        top_k,
        str(_student_texture_topk_shadow_from_env()).lower(),
        STUDENT_TEXTURE_TOPK_METHOD_ENV,
        os.environ.get(STUDENT_TEXTURE_TOPK_METHOD_ENV),
        STUDENT_TEXTURE_TOP_K_ENV,
        os.environ.get(STUDENT_TEXTURE_TOP_K_ENV),
    )


def _student_texture_feature_score(
    crop_thumb: np.ndarray,
    crop_hist: np.ndarray,
    crop_hash: np.ndarray,
    feature: _StudentTextureFeature,
    method: str,
) -> float:
    thumb_score = 1.0 - float(np.mean(np.abs(crop_thumb - feature.thumb)))
    hist_score = float(np.minimum(crop_hist, feature.hist).sum())
    hash_score = 1.0 - float(np.mean(crop_hash != feature.ahash))
    if method == "thumb":
        return thumb_score
    if method == "hist":
        return hist_score
    if method == "hash":
        return hash_score
    if method == "hybrid":
        return 0.65 * thumb_score + 0.35 * hist_score
    return 0.45 * thumb_score + 0.35 * hist_score + 0.20 * hash_score


def _student_texture_features() -> dict[str, _StudentTextureFeature]:
    import core.student_meta as _sn
    global _STUDENT_TEXTURE_FEATURE_CACHE
    if _STUDENT_TEXTURE_FEATURE_CACHE is not None:
        return _STUDENT_TEXTURE_FEATURE_CACHE

    texture_dir = TEMPLATE_DIR / STUDENT_TEXTURE_DIR
    features: dict[str, _StudentTextureFeature] = {}
    if not texture_dir.exists():
        _STUDENT_TEXTURE_FEATURE_CACHE = features
        return features

    for sid in _sn.all_ids():
        path = texture_dir / _sn.template_path(sid)
        if not path.exists():
            continue
        try:
            with Image.open(path) as raw:
                img = raw.convert("RGB")
            features[sid] = _StudentTextureFeature(
                sid=sid,
                path=str(path),
                thumb=_student_texture_thumb(img),
                hist=_student_texture_hist(img),
                ahash=_student_texture_hash(img),
            )
        except Exception:
            _log.debug("failed to build student texture feature: %s", path, exc_info=True)

    _STUDENT_TEXTURE_FEATURE_CACHE = features
    return features


def _student_texture_candidates(candidate_ids: Iterable[str] | None = None) -> dict[str, str]:
    features = _student_texture_features()
    if candidate_ids is None:
        return {sid: feature.path for sid, feature in features.items()}
    requested = set(candidate_ids)
    return {sid: feature.path for sid, feature in features.items() if sid in requested}


def _top_student_texture_candidates(
    crop: Image.Image,
    cands: dict[str, str],
    top_k: int,
    method: str,
) -> dict[str, str]:
    if top_k <= 0 or len(cands) <= top_k:
        return cands
    features = _student_texture_features()
    crop_thumb = _student_texture_thumb(crop)
    crop_hist = _student_texture_hist(crop)
    crop_hash = _student_texture_hash(crop)
    ranked = sorted(
        (
            (
                sid,
                _student_texture_feature_score(
                    crop_thumb,
                    crop_hist,
                    crop_hash,
                    features[sid],
                    method,
                ),
            )
            for sid in cands
            if sid in features
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    selected = {sid for sid, _score in ranked[:top_k]}
    _log.debug(
        "texture_topk: method=%s pool=%d k=%d top=%s",
        method,
        len(cands),
        min(top_k, len(cands)),
        " ".join(f"{sid}({score:.3f})" for sid, score in ranked[:5]),
    )
    return {sid: cands[sid] for sid in selected}


def _match_student_texture_precise(
    crop: Image.Image,
    cands: dict[str, str],
    *,
    label: str,
) -> tuple[Optional[str], float, float]:
    if not cands:
        return None, 0.0, 0.0

    scores = sorted(
        [
            (sid, 0.55 * match_score_resized(crop, p)
                + 0.45 * _color_hist_score(crop, p))
            for sid, p in cands.items()
        ],
        key=lambda x: x[1],
        reverse=True,
    )
    best_id, best_s = scores[0]
    second_s = scores[1][1] if len(scores) > 1 else 0.0
    margin = best_s - second_s

    _log.debug(
        f"texture[{label}]: pool={len(cands)} "
        f"1st={best_id}({best_s:.3f}) "
        f"2nd={scores[1][0] if len(scores)>1 else '-'}({second_s:.3f}) "
        f"margin={margin:.3f}"
    )

    if best_s < TEXTURE_THRESHOLD or margin < TEXTURE_MARGIN_REQUIRED:
        return None, best_s, margin
    return best_id, best_s, margin


def _match_student_texture_with_topk(
    crop: Image.Image,
    cands: dict[str, str],
    *,
    label: str,
    top_k: int,
    method: str,
) -> tuple[Optional[str], float, float]:
    if not cands:
        return None, 0.0, 0.0

    if top_k > 0 and len(cands) > top_k:
        top_cands = _top_student_texture_candidates(crop, cands, top_k, method)
        sid, score, margin = _match_student_texture_precise(
            crop,
            top_cands,
            label=f"{label}:topk",
        )
        if (
            sid is not None
            and score >= STUDENT_TEXTURE_SHORTCUT_SCORE
            and margin >= STUDENT_TEXTURE_SHORTCUT_MARGIN
        ):
            _log.debug(
                "texture_topk_accept: method=%s k=%d sid=%s score=%.3f margin=%.3f pool=%d",
                method,
                top_k,
                sid,
                score,
                margin,
                len(cands),
            )
            if _student_texture_topk_shadow_from_env():
                full_sid, full_score, full_margin = _match_student_texture_precise(
                    crop,
                    cands,
                    label=f"{label}:shadow_full",
                )
                matched = sid == full_sid
                _log.info(
                    "texture_topk_shadow: method=%s k=%d topk_sid=%s full_sid=%s "
                    "matched=%s topk_score=%.3f full_score=%.3f full_margin=%.3f pool=%d",
                    method,
                    top_k,
                    sid,
                    full_sid,
                    str(matched).lower(),
                    score,
                    full_score,
                    full_margin,
                    len(cands),
                )
                return full_sid, full_score, full_margin
            return sid, score, margin
        _log.debug(
            "texture_topk_fallback: method=%s k=%d sid=%s score=%.3f margin=%.3f pool=%d",
            method,
            top_k,
            sid,
            score,
            margin,
            len(cands),
        )

    return _match_student_texture_precise(crop, cands, label=label)


def _match_student_texture_optimized(
    crop: Image.Image,
    candidate_ids: Iterable[str] | None = None,
    *,
    fallback_candidate_ids: Iterable[str] | None = None,
    top_k: int | None = None,
) -> tuple[Optional[str], float]:
    actual_top_k = _student_texture_topk_from_env() if top_k is None else max(0, top_k)
    method = _student_texture_topk_method_from_env()
    _log_student_texture_topk_config(method, actual_top_k)
    primary_cands = _student_texture_candidates(candidate_ids)
    sid, score, margin = _match_student_texture_with_topk(
        crop,
        primary_cands,
        label="primary",
        top_k=actual_top_k,
        method=method,
    )

    if fallback_candidate_ids is None:
        return sid, score

    if (
        sid is not None
        and score >= STUDENT_TEXTURE_SHORTCUT_SCORE
        and margin >= STUDENT_TEXTURE_SHORTCUT_MARGIN
    ):
        return sid, score

    fallback_cands = _student_texture_candidates(fallback_candidate_ids)
    fallback_sid, fallback_score, _fallback_margin = _match_student_texture_with_topk(
        crop,
        fallback_cands,
        label="fallback",
        top_k=actual_top_k,
        method=method,
    )
    return fallback_sid, fallback_score


def match_student_texture(
    crop: Image.Image,
    candidate_ids: Iterable[str] | None = None,
    *,
    fallback_candidate_ids: Iterable[str] | None = None,
    top_k: int | None = None,
) -> tuple[Optional[str], float]:
    return _match_student_texture_optimized(
        crop,
        candidate_ids,
        fallback_candidate_ids=fallback_candidate_ids,
        top_k=top_k,
    )

def _match_student_texture_legacy(crop: Image.Image) -> tuple[Optional[str], float]:
    import core.student_meta as _sn
    texture_dir = TEMPLATE_DIR / STUDENT_TEXTURE_DIR
    if not texture_dir.exists():
        return None, 0.0

    cands = {
        sid: str(texture_dir / _sn.template_path(sid))
        for sid in _sn.all_ids()
        if (texture_dir / _sn.template_path(sid)).exists()
    }
    if not cands:
        return None, 0.0

    scores = sorted(
        [
            (sid, 0.55 * match_score_resized(crop, p)
                + 0.45 * _color_hist_score(crop, p))
            for sid, p in cands.items()
        ],
        key=lambda x: x[1],
        reverse=True,
    )
    best_id, best_s = scores[0]
    second_s = scores[1][1] if len(scores) > 1 else 0.0
    margin   = best_s - second_s

    _log.debug(
        f"texture: 1위={best_id}({best_s:.3f}) "
        f"2위={scores[1][0] if len(scores)>1 else '-'}({second_s:.3f}) "
        f"margin={margin:.3f}"
    )

    if best_s < TEXTURE_THRESHOLD or margin < TEXTURE_MARGIN_REQUIRED:
        return None, best_s
    return best_id, best_s

identify_student_by_texture = match_student_texture   # 하위 호환


# ══════════════════════════════════════════════════════════
# 무기 상태
# ══════════════════════════════════════════════════════════

def detect_weapon_state(crop: Image.Image) -> tuple[WeaponState, float]:
    d = TEMPLATE_DIR / WEAPON_STATE_DIR
    mapping = {
        "no_weapon":       WeaponState.NO_WEAPON_SYSTEM,
        "weapon_locked":   WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED,
        "weapon_unlocked": WeaponState.WEAPON_EQUIPPED,
    }
    scores = {
        k: (match_score_resized(crop, str(d / WEAPON_STATE_FILES[k]))
            if (d / WEAPON_STATE_FILES[k]).exists() else 0.0)
        for k in mapping
    }

    if not any(v > 0 for v in scores.values()):
        return WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED, 0.0

    best_key = max(scores, key=lambda k: scores[k])
    best_val = scores[best_key]
    _log.debug(f"weapon_state: { {k: f'{v:.3f}' for k,v in scores.items()} } → {best_key}")

    if best_val < WEAPON_STATE_MIN_SCORE:
        return WeaponState.NO_WEAPON_SYSTEM, best_val
    if best_key == "weapon_unlocked":
        rival = max(scores["no_weapon"], scores["weapon_locked"])
        if (
            best_val < WEAPON_EQUIPPED_MIN_SCORE
            or (best_val - rival) < WEAPON_EQUIPPED_MARGIN_REQUIRED
            or _orange_pixel_ratio(crop) < WEAPON_EQUIPPED_ORANGE_RATIO
        ):
            fallback_key = "weapon_locked" if scores["weapon_locked"] >= scores["no_weapon"] else "no_weapon"
            return mapping[fallback_key], scores[fallback_key]
    return mapping[best_key], best_val

detect_weapon_status = detect_weapon_state   # 하위 호환


def _orange_pixel_ratio(crop: Image.Image) -> float:
    try:
        img = crop.convert("RGB")
    except Exception:
        return 0.0
    width, height = img.size
    total = max(1, width * height)
    orange = 0
    for r, g, b in img.getdata():
        if r >= 180 and 85 <= g <= 215 and b <= 105 and (r - g) >= 20:
            orange += 1
    return orange / total


# ══════════════════════════════════════════════════════════
# Check 플래그
# ══════════════════════════════════════════════════════════

def read_check_flag(crop: Image.Image, folder: str) -> CheckFlag:
    d = TEMPLATE_DIR / folder
    cands = {
        flag: str(d / f"{flag}.png")
        for flag in ("true", "false")
        if (d / f"{flag}.png").exists()
    }
    if not cands:
        return CheckFlag.FALSE
    lbl, score = best_match(crop, cands, threshold=0.55, resized=True)
    if lbl is None:
        return CheckFlag.FALSE
    _log.debug(f"check_flag({folder}): {lbl} ({score:.3f})")
    return CheckFlag(lbl)


def read_skill_check(crop: Image.Image) -> CheckFlag:
    return read_check_flag(crop, SKILL_CHECK_DIR)


def read_equip_check(crop: Image.Image) -> CheckFlag:
    d = TEMPLATE_DIR / EQUIP_CHECK_DIR

    explicit: dict[str, float] = {}
    for flag in ("possible", "impossible"):
        p = d / f"{flag}.png"
        if p.exists():
            explicit[flag] = match_score_resized(crop, str(p), focus_center=True)

    if explicit:
        _log.debug(f"equip_check explicit: "
              + " ".join(f"{k}={v:.3f}" for k, v in explicit.items()))

        possible_s   = explicit.get("possible",   0.0)
        impossible_s = explicit.get("impossible", 0.0)
        best_label   = max(explicit, key=explicit.get)
        best_score   = explicit[best_label]
        margin       = abs(possible_s - impossible_s)

        if best_label == "impossible" and (best_score >= 0.50 or margin >= 0.03):
            _log.warning(f"equip_check → IMPOSSIBLE")
            return CheckFlag.IMPOSSIBLE
        return CheckFlag.FALSE

    IMPOSSIBLE_TF_MAX = 0.45
    TRUE_THRESHOLD    = 0.55

    scores: dict[str, float] = {
        flag: match_score_resized(crop, str(d / f"{flag}.png"))
        for flag in ("impossible", "true", "false")
        if (d / f"{flag}.png").exists()
    }
    _log.debug(f"equip_check legacy: "
          + " ".join(f"{k}={v:.3f}" for k, v in scores.items()))

    true_s  = scores.get("true",  0.0)
    false_s = scores.get("false", 0.0)
    if max(true_s, false_s) < IMPOSSIBLE_TF_MAX:
        return CheckFlag.IMPOSSIBLE
    if true_s >= TRUE_THRESHOLD:
        return CheckFlag.TRUE
    return CheckFlag.FALSE


def read_equip_check_inside(crop: Image.Image) -> CheckFlag:
    TRUE_THRESHOLD = 0.55
    TRUE_RELATIVE_THRESHOLD = 0.20
    TRUE_MARGIN = 0.08
    d = TEMPLATE_DIR / EQUIP_CHECK_DIR
    scores = {
        flag: match_score_resized(crop, str(d / f"{flag}.png"))
        for flag in ("true", "false")
        if (d / f"{flag}.png").exists()
    }
    _log.debug(f"equip_check_inside: "
          + " ".join(f"{k}={v:.3f}" for k, v in scores.items()))
    true_s = scores.get("true", 0.0)
    false_s = scores.get("false", 0.0)
    if true_s >= TRUE_THRESHOLD:
        return CheckFlag.TRUE
    if true_s >= TRUE_RELATIVE_THRESHOLD and true_s >= false_s + TRUE_MARGIN:
        return CheckFlag.TRUE
    return CheckFlag.FALSE


# ══════════════════════════════════════════════════════════
# 장비 슬롯 플래그
# ══════════════════════════════════════════════════════════

def read_equip_slot_flag(crop: Image.Image, slot: int) -> EquipSlotFlag:
    d = TEMPLATE_DIR / f"equip{slot}_flag"
    flag_files: dict[str, str] = {
        "empty": f"equip{slot}_empty.png",
    }
    if slot in (2, 3):
        flag_files["level_locked"] = f"equip{slot}_level_locked.png"
    if slot == 4:
        flag_files["love_locked"] = "equip4_love_locked.png"
        flag_files["null"]        = "equip4_null.png"

    cands = {k: str(d / v) for k, v in flag_files.items() if (d / v).exists()}
    if not cands:
        return EquipSlotFlag.NORMAL

    lbl, score = best_match(crop, cands, threshold=0.60, resized=True)
    if lbl is None:
        return EquipSlotFlag.NORMAL
    _log.debug(f"equip{slot}_flag: {lbl} ({score:.3f})")
    return EquipSlotFlag(lbl)


# ══════════════════════════════════════════════════════════
# 스탯
# ══════════════════════════════════════════════════════════

def read_stat_value(crop: Image.Image, stat_key: str) -> Optional[int]:
    folder = STAT_DIRS.get(stat_key)
    if not folder:
        return None
    d = TEMPLATE_DIR / folder
    if not d.exists():
        return None
    cands = {
        str(i): str(d / f"{i}.png")
        for i in range(26)
        if (d / f"{i}.png").exists()
    }
    if not cands:
        return None
    scores: dict[str, tuple[float, float, float]] = {}
    for lbl, path in cands.items():
        ui = match_score_resized(crop, path, focus_center=True)
        text = match_score_textonly(crop, path)
        final = 0.35 * ui + 0.65 * text
        scores[lbl] = (final, ui, text)

    ranked = sorted(scores.items(), key=lambda x: x[1][0], reverse=True)
    if not ranked:
        return None
    best_lbl, (best_score, best_ui, best_text) = ranked[0]

    if best_lbl == "4" and "0" in scores:
        zero_score, zero_ui, zero_text = scores["0"]
        if best_score < 0.72 and zero_score >= best_score - 0.03 and zero_text >= best_text:
            best_lbl = "0"
            best_score, best_ui, best_text = zero_score, zero_ui, zero_text

    if best_score < 0.60:
        return None

    _log.debug(
        f"stat_{stat_key}: {best_lbl} "
        f"(final={best_score:.3f} ui={best_ui:.3f} text={best_text:.3f})"
    )
    return int(best_lbl)


def read_stat_value_result(crop: Image.Image, stat_key: str) -> RecognitionResult:
    """
    read_stat_value() 의 RecognitionResult 반환 버전.
    """
    folder = STAT_DIRS.get(stat_key)
    if not folder:
        return RecognitionResult.skipped(f"no_stat_dir:{stat_key}")
    d = TEMPLATE_DIR / folder
    if not d.exists():
        return RecognitionResult.skipped(f"dir_missing:{folder}")
    cands = {
        str(i): str(d / f"{i}.png")
        for i in range(26)
        if (d / f"{i}.png").exists()
    }
    if not cands:
        return RecognitionResult.skipped("no_templates")
    scores: dict[str, tuple[float, float, float]] = {}
    for lbl, path in cands.items():
        ui = match_score_resized(crop, path, focus_center=True)
        text = match_score_textonly(crop, path)
        final = 0.35 * ui + 0.65 * text
        scores[lbl] = (final, ui, text)

    ranked = sorted(scores.items(), key=lambda x: x[1][0], reverse=True)
    if not ranked:
        return RecognitionResult.skipped("no_scores")

    best_lbl, (best_score, best_ui, best_text) = ranked[0]

    if best_lbl == "4" and "0" in scores:
        zero_score, zero_ui, zero_text = scores["0"]
        if best_score < 0.72 and zero_score >= best_score - 0.03 and zero_text >= best_text:
            best_lbl = "0"
            best_score, best_ui, best_text = zero_score, zero_ui, zero_text

    _log.debug(
        f"stat_{stat_key}_result: {best_lbl} "
        f"(final={best_score:.3f} ui={best_ui:.3f} text={best_text:.3f})"
    )
    value = int(best_lbl) if best_score >= 0.60 else None
    return _make_result(value, best_score, RecogSource.COMBINED)


# ══════════════════════════════════════════════════════════
# Digit 폴더 읽기 (장비 레벨 / 무기 레벨 / 학생 레벨 공통)
# ══════════════════════════════════════════════════════════

def _read_digit_from_folder(
    folder: Path,
    prefix: int,
    crop: Image.Image,
    *,
    threshold: float = 0.55,
) -> Optional[str]:
    if not folder.exists():
        return None
    cands = {
        p.stem.split("_", 1)[1]: str(p)
        for p in folder.glob(f"{prefix}_*.png")
    }
    if not cands:
        return None
    lbl, score = best_match(crop, cands, threshold=threshold,
                             resized=True, focus_center=True)
    _log.debug(f"{folder.name}: {lbl} ({score:.3f})")
    return lbl


def _rank_digit_candidates(
    folder: Path,
    prefix: int,
    crop: Image.Image,
) -> tuple[Optional[str], float, float]:
    candidates = {
        path.stem.split("_", 1)[1]: str(path)
        for path in folder.glob(f"{prefix}_*.png")
    }
    ranked = sorted(
        (
            (label, match_score_resized(crop, path, focus_center=True))
            for label, path in candidates.items()
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    if not ranked:
        return None, 0.0, 0.0
    label, score = ranked[0]
    second = ranked[1][1] if len(ranked) > 1 else 0.0
    return label, score, score - second


def _normalize_dark_digit_glyph(crop: Image.Image) -> np.ndarray | None:
    gray = cv2.cvtColor(np.asarray(crop.convert("RGB")), cv2.COLOR_RGB2GRAY)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    _threshold, foreground = cv2.threshold(
        gray,
        0,
        255,
        cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU,
    )
    return normalize_binary_glyph(foreground)


def _rank_adaptive_digit(
    crop: Image.Image,
    templates: dict[str, list[np.ndarray]] | None,
) -> tuple[Optional[str], float, float]:
    glyph = _normalize_dark_digit_glyph(crop)
    if glyph is None or not templates:
        return None, 0.0, 0.0
    ranked = sorted(
        (
            (
                label,
                max(binary_glyph_similarity(glyph, template) for template in variants),
            )
            for label, variants in templates.items()
            if variants
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    if not ranked:
        return None, 0.0, 0.0
    label, score = ranked[0]
    second = ranked[1][1] if len(ranked) > 1 else 0.0
    return label, score, score - second


def _read_adaptive_equip_digit(
    folder: Path,
    prefix: int,
    crop: Image.Image,
    templates: dict[str, list[np.ndarray]] | None,
) -> Optional[str]:
    static_label, static_score, static_margin = _rank_digit_candidates(folder, prefix, crop)
    adaptive_label, adaptive_score, adaptive_margin = _rank_adaptive_digit(crop, templates)

    label: Optional[str] = None
    learned_label_count = sum(
        1 for variants in (templates or {}).values() if variants
    )
    if adaptive_label is not None and adaptive_score >= 0.72 and adaptive_margin >= 0.06:
        if static_label == adaptive_label or (
            static_score < 0.55 and learned_label_count >= 2
        ):
            label = adaptive_label
    if label is None and static_label is not None and static_score >= 0.55:
        label = static_label

    # Only an independently strong static match may become a run-local sample.
    # This prevents a weak adaptive guess from teaching itself as ground truth.
    if (
        templates is not None
        and static_label is not None
        and static_label.isdigit()
        and static_score >= 0.78
        and static_margin >= 0.06
    ):
        glyph = _normalize_dark_digit_glyph(crop)
        if glyph is not None:
            variants = templates.setdefault(static_label, [])
            variants.append(glyph)
            del variants[:-4]
            _log.debug(
                "equip_level_calibration: learned position=%d digit=%s score=%.3f margin=%.3f variants=%d",
                prefix,
                static_label,
                static_score,
                static_margin,
                len(variants),
            )
    return label


def read_equip_level(
    img: Image.Image,
    slot: int,
    d1_region: dict,
    d2_region: dict,
    adaptive_templates: dict[int, dict[str, list[np.ndarray]]] | None = None,
) -> Optional[int]:
    from core.capture import crop_region
    folder1 = TEMPLATE_DIR / f"equip{slot}level_digit1"
    folder2 = TEMPLATE_DIR / f"equip{slot}level_digit2"
    d1 = _read_adaptive_equip_digit(
        folder1,
        1,
        crop_region(img, d1_region),
        adaptive_templates.setdefault(1, {}) if adaptive_templates is not None else None,
    )
    d2 = _read_adaptive_equip_digit(
        folder2,
        2,
        crop_region(img, d2_region),
        adaptive_templates.setdefault(2, {}) if adaptive_templates is not None else None,
    )

    if not d1 or d1 == "v":
        if d2:
            try: return int(d2)
            except ValueError as e: _log.debug(f"equip_level d2 변환 실패: {e}"); pass
        return None
    if d2:
        try: return int(d1 + d2)
        except ValueError as e: _log.debug(f"equip_level d1+d2 변환 실패: {e}"); pass
    try: return int(d1)
    except ValueError as e: _log.debug(f"equip_level d1 변환 실패: {e}"); return None


def read_weapon_level(
    img: Image.Image,
    d1_region: dict,
    d2_region: dict,
) -> Optional[int]:
    from core.capture import crop_region
    folder1 = TEMPLATE_DIR / "weaponlevel_digit1"
    folder2 = TEMPLATE_DIR / "weaponlevel_digit2"
    d1 = _read_digit_from_folder(
        folder1,
        1,
        crop_region(img, d1_region),
        threshold=0.48,
    )
    d2 = _read_digit_from_folder(folder2, 2, crop_region(img, d2_region))

    if not d2 or d2 == "null":
        if d1:
            try: return int(d1)
            except ValueError: pass
        return None
    if d1:
        try: return int(d1 + d2)
        except ValueError: pass
    try: return int(d2)
    except ValueError: return None


def read_basic_weapon_level_result(image: Image.Image, region: dict) -> RecognitionResult:
    """Read the weapon level directly from the compact basic-info weapon card."""
    output_size = tuple(region.get("output_size", (64, 48)))
    crop = warp_quad_region(image, region, output_size=output_size)
    if crop is None:
        return RecognitionResult.fallback(None, "basic_weapon_level_region_missing")
    return _read_weapon_level_glyph_result(crop)


@lru_cache(maxsize=1)
def _weapon_level_glyph_templates() -> dict[str, np.ndarray]:
    directory = TEMPLATE_DIR / "weaponlevel_glyph"
    templates: dict[str, np.ndarray] = {}
    for path in sorted(directory.glob("*.png")):
        if path.stem not in {str(value) for value in range(10)}:
            continue
        image = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if image is not None:
            templates[path.stem] = image
    return templates


def _read_weapon_level_glyph_result(crop: Image.Image) -> RecognitionResult:
    templates = _weapon_level_glyph_templates()
    if not templates:
        return RecognitionResult.fallback(None, "no_weapon_level_glyph_templates")

    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    if rgb.size == 0:
        return RecognitionResult.fallback(None, "empty_weapon_level_crop")

    # Digit fill is nearly neutral white; the panel and weapon art are either
    # blue-tinted or darker. This mask therefore survives both bright and dark
    # weapon backgrounds without deleting the digit itself.
    chroma = rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2).astype(np.int16)
    binary = ((rgb.min(axis=2) >= 238) & (chroma <= 28)).astype(np.uint8) * 255
    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(binary)
    height, width = binary.shape
    components: list[tuple[int, int]] = []
    for index in range(1, count):
        x, y, component_w, component_h, area = stats[index]
        if area < max(12, int(round(binary.size * 0.012))):
            continue
        if not (0.36 * height <= component_h <= 0.78 * height):
            continue
        if y > 0.52 * height or component_w > 0.48 * width:
            continue
        components.append((int(x), index))

    components.sort()
    components = components[:2]
    if not components:
        return RecognitionResult.fallback(None, "weapon_level_glyph_missing")

    digits: list[str] = []
    scores: list[float] = []
    margins: list[float] = []
    for _x, component_index in components:
        component = np.zeros_like(binary)
        component[labels == component_index] = 255
        glyph = normalize_binary_glyph(component)
        if glyph is None:
            return RecognitionResult.fallback(None, "weapon_level_glyph_normalize_fail")
        ranked = sorted(
            (
                (digit, binary_glyph_similarity(glyph, template))
                for digit, template in templates.items()
            ),
            key=lambda item: item[1],
            reverse=True,
        )
        if not ranked:
            return RecognitionResult.fallback(None, "weapon_level_glyph_match_fail")
        digit, score = ranked[0]
        second_score = ranked[1][1] if len(ranked) > 1 else 0.0
        digits.append(digit)
        scores.append(score)
        margins.append(score - second_score)

    value = int("".join(digits))
    score = min(scores)
    margin = min(margins)
    valid = 1 <= value <= 60
    uncertain = not valid or score < 0.72 or margin < 0.08
    _log.debug(
        "weapon_level_glyph: value=%s score=%.3f margin=%.3f uncertain=%s",
        value,
        score,
        margin,
        uncertain,
    )
    return RecognitionResult(
        value=value if valid else None,
        score=score,
        source=RecogSource.COMBINED,
        uncertain=uncertain,
        label=f"weapon_level_glyph:{value}({score:.3f},margin={margin:.3f})",
    )


# ══════════════════════════════════════════════════════════
# 별 등급
# ══════════════════════════════════════════════════════════

def read_star(crop: Image.Image, folder: str, max_n: int) -> int:
    """
    별 등급 인식.
    RGBA 템플릿의 알파를 마스크로 사용 → 배경 색상 변화에 강건.
    match_masked_icon() 경로로만 처리. best_match(masked=True) 혼용 금지.
    """
    d = TEMPLATE_DIR / folder
    cands = {
        str(i): str(d / f"star_{i}.png")
        for i in range(max_n, 0, -1)
        if (d / f"star_{i}.png").exists()
    }
    if not cands:
        _log.warning(f"{folder}: 템플릿 없음 → 1")
        return 1

    lbl, score = best_match_masked_icons(crop, cands, threshold=0.68)
    _log.debug(f"{folder} star: {lbl} ({score:.3f})")
    return int(lbl) if lbl else 1


def read_star_result(crop: Image.Image, folder: str, max_n: int) -> RecognitionResult:
    """
    read_star() 의 RecognitionResult 반환 버전.
    별 개수 + score + source + uncertain 플래그 포함.
    """
    d = TEMPLATE_DIR / folder
    cands = {
        str(i): str(d / f"star_{i}.png")
        for i in range(max_n, 0, -1)
        if (d / f"star_{i}.png").exists()
    }
    if not cands:
        return RecognitionResult.fallback(1, "no_templates")

    lbl, score = best_match_masked_icons(crop, cands, threshold=0.60)
    _log.debug(f"{folder} star_result: {lbl} ({score:.3f})")
    value = int(lbl) if lbl else None
    return _make_result(value, score, RecogSource.TEMPLATE_MASKED)


def read_student_star(crop: Image.Image) -> int:
    return read_star(crop, "star", 5)


def read_weapon_star(crop: Image.Image) -> int:
    return read_star(crop, "weapon_star", 4)


def is_weapon_equipped(crop: Image.Image) -> bool:
    return detect_weapon_state(crop)[0] == WeaponState.WEAPON_EQUIPPED

read_weapon_unlocked = is_weapon_equipped   # 하위 호환


# ══════════════════════════════════════════════════════════
# 학생 레벨
# ══════════════════════════════════════════════════════════

def read_level_digit(crop: Image.Image, digit_pos: int) -> Optional[str]:
    folder = TEMPLATE_DIR / f"studentlevel_digit{digit_pos}"
    if not folder.exists():
        return None
    start = 1 if digit_pos == 1 else 0
    cands = {
        str(i): str(folder / f"{digit_pos}_{i}.png")
        for i in range(start, 10)
        if (folder / f"{digit_pos}_{i}.png").exists()
    }
    if not cands:
        return None
    lbl, score = best_match(crop, cands, threshold=0.55,
                             resized=True, focus_center=True)
    _log.debug(f"level_digit{digit_pos}: {lbl} ({score:.3f})")
    return lbl


def read_student_level(
    img: Image.Image,
    digit1_region: dict,
    digit2_region: dict,
) -> str:
    from core.capture import crop_region
    d1 = read_level_digit(crop_region(img, digit1_region), 1)
    d2 = read_level_digit(crop_region(img, digit2_region), 2)

    if not d2 or d2 == "null":
        if d1:
            _log.debug(f"student_level: 1자리 → {d1}")
            return d1
        return "unknown"
    return f"{d1}{d2}" if d1 else d2


# ══════════════════════════════════════════════════════════
# 스킬 레벨
# ══════════════════════════════════════════════════════════

def read_skill(crop: Image.Image, skill_key: str) -> str:
    d = TEMPLATE_DIR / skill_key
    max_lv = 5 if skill_key == "EX_Skill" else 10
    cands: dict[str, str] = {}

    if skill_key == "EX_Skill":
        for i in range(max_lv, 0, -1):
            p = d / f"EX_Skill_{i}.png"
            if p.exists():
                cands[str(i)] = str(p)
    else:
        prefix = skill_key.replace("Skill", "Skill_")
        locked = d / f"{prefix}_locked.png"
        if locked.exists():
            cands["locked"] = str(locked)
        for i in range(max_lv, 0, -1):
            p = d / f"{prefix}_{i}.png"
            if p.exists():
                cands[str(i)] = str(p)

    if not cands:
        return "unknown"

    scores: dict[str, tuple[float, float, float]] = {}
    for lbl, path in cands.items():
        ui   = match_score_resized(crop, path, focus_center=True)
        text = match_score_textonly(crop, path) if lbl != "locked" else 0.0
        final = ui if lbl == "locked" else (0.55 * ui + 0.45 * text)
        scores[lbl] = (final, ui, text)

    ranked = sorted(scores.items(), key=lambda x: x[1][0], reverse=True)
    best_lbl, (best_score, best_ui, best_text) = ranked[0]

    if len(ranked) >= 2:
        second_lbl, (second_score, _, _) = ranked[1]
        if {best_lbl, second_lbl} == {"1", "2"} and abs(best_score - second_score) <= 0.035:
            chosen   = "1" if scores["1"][2] >= scores["2"][2] else "2"
            best_lbl = chosen
            best_score, best_ui, best_text = scores[chosen]

    _log.debug(f"{skill_key}: {best_lbl} "
          f"(final={best_score:.3f} ui={best_ui:.3f} text={best_text:.3f})")
    return best_lbl if best_score >= 0.60 else "unknown"


def read_skill_result(crop: Image.Image, skill_key: str) -> RecognitionResult:
    """
    read_skill() 의 RecognitionResult 반환 버전.
    score 와 uncertain 플래그가 함께 반환됨.
    """
    d = TEMPLATE_DIR / skill_key
    max_lv = 5 if skill_key == "EX_Skill" else 10
    cands: dict[str, str] = {}

    if skill_key == "EX_Skill":
        for i in range(max_lv, 0, -1):
            p = d / f"EX_Skill_{i}.png"
            if p.exists():
                cands[str(i)] = str(p)
    else:
        prefix = skill_key.replace("Skill", "Skill_")
        locked = d / f"{prefix}_locked.png"
        if locked.exists():
            cands["locked"] = str(locked)
        for i in range(max_lv, 0, -1):
            p = d / f"{prefix}_{i}.png"
            if p.exists():
                cands[str(i)] = str(p)

    if not cands:
        return RecognitionResult.fallback("unknown", "no_templates")

    scores: dict[str, tuple[float, float, float]] = {}
    for lbl, path in cands.items():
        ui   = match_score_resized(crop, path, focus_center=True)
        text = match_score_textonly(crop, path) if lbl != "locked" else 0.0
        final = ui if lbl == "locked" else (0.55 * ui + 0.45 * text)
        scores[lbl] = (final, ui, text)

    ranked = sorted(scores.items(), key=lambda x: x[1][0], reverse=True)
    best_lbl, (best_score, best_ui, best_text) = ranked[0]

    if len(ranked) >= 2:
        second_lbl, (second_score, _, _) = ranked[1]
        if {best_lbl, second_lbl} == {"1", "2"} and abs(best_score - second_score) <= 0.035:
            chosen   = "1" if scores["1"][2] >= scores["2"][2] else "2"
            best_lbl = chosen
            best_score, best_ui, best_text = scores[chosen]

    _log.debug(f"{skill_key}: {best_lbl} "
          f"(final={best_score:.3f} ui={best_ui:.3f} text={best_text:.3f})")

    value = best_lbl if best_score >= 0.60 else None
    try:
        int_val = int(value) if value and value != "locked" else value
    except (TypeError, ValueError):
        int_val = value

    return _make_result(int_val, best_score, RecogSource.COMBINED)


def read_basic_skill_result(crop: Image.Image, *, is_ex: bool) -> RecognitionResult:
    """Read a skill level from the compact cards on the student basic-info tab."""
    group = "ex" if is_ex else "normal"
    directory = TEMPLATE_DIR / BASIC_SKILL_DIR / group
    template_paths = sorted(directory.glob("*.png"))
    if not template_paths:
        return RecognitionResult.fallback(None, "no_basic_skill_templates")

    scores: dict[str, tuple[float, float, float]] = {}
    for path in template_paths:
        label = path.stem.split("_", 1)[0]
        ui = match_score_resized(crop, str(path))
        text = match_score_textonly(crop, str(path))
        final = 0.15 * ui + 0.85 * text
        if label not in scores or final > scores[label][0]:
            scores[label] = (final, ui, text)

    ranked = sorted(scores.items(), key=lambda item: item[1][0], reverse=True)
    best_label, (best_score, best_ui, best_text) = ranked[0]
    second_score = ranked[1][1][0] if len(ranked) > 1 else 0.0
    margin = best_score - second_score
    max_level = 5 if is_ex else 10
    value = max_level if best_label == "max" else int(best_label)
    uncertain = best_score < 0.70 or margin < 0.04
    _log.debug(
        "basic_skill[%s]: %s final=%.3f ui=%.3f text=%.3f margin=%.3f uncertain=%s",
        group,
        best_label,
        best_score,
        best_ui,
        best_text,
        margin,
        str(uncertain).lower(),
    )
    return RecognitionResult(
        value=value if best_score >= 0.58 else None,
        score=best_score,
        source=RecogSource.COMBINED,
        uncertain=uncertain or best_score < 0.58,
        label=f"basic_skill:{group}:{best_label}:margin={margin:.3f}",
    )


@lru_cache(maxsize=1)
def _basic_level_digit_templates() -> dict[str, tuple[np.ndarray, ...]]:
    directory = TEMPLATE_DIR / "basic_student" / "level_digits"
    grouped: dict[str, list[np.ndarray]] = {}
    for path in sorted(directory.glob("*.png")):
        label = path.stem.split("_", 1)[0]
        if label not in {str(value) for value in range(10)}:
            continue
        image = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if image is not None:
            grouped.setdefault(label, []).append(image)
    return {label: tuple(images) for label, images in grouped.items()}


def _match_basic_level_digit(
    binary: np.ndarray,
    adaptive_templates: dict[str, list[np.ndarray]] | None = None,
) -> tuple[str | None, float, float]:
    glyph = normalize_binary_glyph(binary)
    if glyph is None:
        return None, 0.0, 0.0
    scores: list[tuple[str, float]] = []
    labels = set(_basic_level_digit_templates())
    if adaptive_templates:
        labels.update(adaptive_templates)
    for label in labels:
        templates = list(_basic_level_digit_templates().get(label, ()))
        if adaptive_templates:
            templates.extend(adaptive_templates.get(label, ()))
        if not templates:
            continue
        score = max(binary_glyph_similarity(glyph, template) for template in templates)
        scores.append((label, score))
    scores.sort(key=lambda item: item[1], reverse=True)
    if not scores:
        return None, 0.0, 0.0
    best_label, best_score = scores[0]
    second_score = scores[1][1] if len(scores) > 1 else 0.0
    return best_label, best_score, best_score - second_score


def _basic_level_cell_has_digit(binary: np.ndarray) -> bool:
    count, _labels, stats, _centroids = cv2.connectedComponentsWithStats(binary)
    components = [stats[index] for index in range(1, count) if stats[index, cv2.CC_STAT_AREA] >= 12]
    if not components:
        return False
    dominant = max(components, key=lambda stat: stat[cv2.CC_STAT_AREA])
    left = int(dominant[cv2.CC_STAT_LEFT])
    # The optional second digit begins at the left edge of its canonical cell.
    # On narrow layouts the EXP bar can enter from the right; do not mistake
    # that tall right-edge block for a digit.
    return left <= max(3, int(round(binary.shape[1] * 0.30)))


def extract_basic_student_level_glyphs(
    image: Image.Image,
    region: dict,
) -> tuple[list[np.ndarray], bool]:
    """Return normalized digit glyphs and whether the second cell is occupied."""
    output_size = tuple(region.get("output_size", (58, 46)))
    warped = warp_quad_region(image, region, output_size=output_size)
    if warped is None:
        return [], False
    binary = otsu_binary(warped)
    midpoint = binary.shape[1] // 2
    cells = (binary[:, :midpoint], binary[:, midpoint:])
    has_second_digit = _basic_level_cell_has_digit(cells[1])
    selected_cells = cells if has_second_digit else cells[:1]
    glyphs = [normalize_binary_glyph(cell) for cell in selected_cells]
    if any(glyph is None for glyph in glyphs):
        return [], has_second_digit
    return [glyph for glyph in glyphs if glyph is not None], has_second_digit


def read_basic_student_level_result(
    image: Image.Image,
    region: dict,
    adaptive_templates: dict[int, dict[str, list[np.ndarray]]] | None = None,
) -> RecognitionResult:
    """Read the compact left-card level after rectifying its slanted digit strip."""
    output_size = tuple(region.get("output_size", (58, 46)))
    warped = warp_quad_region(image, region, output_size=output_size)
    if warped is None or not _basic_level_digit_templates():
        return RecognitionResult.fallback(None, "basic_level_assets_missing")

    binary = otsu_binary(warped)
    midpoint = binary.shape[1] // 2
    cells = (binary[:, :midpoint], binary[:, midpoint:])
    results = [
        _match_basic_level_digit(
            cell,
            adaptive_templates.get(position) if adaptive_templates else None,
        )
        for position, cell in enumerate(cells)
    ]
    first_label, first_score, first_margin = results[0]
    second_label, second_score, second_margin = results[1]

    second_occupancy = float(np.count_nonzero(cells[1])) / float(cells[1].size)
    has_second_digit = _basic_level_cell_has_digit(cells[1])
    if first_label is None:
        return RecognitionResult(value=None, score=0.0, source=RecogSource.COMBINED, uncertain=True)

    labels = [first_label]
    scores = [first_score]
    margins = [first_margin]
    if has_second_digit:
        if second_label is None:
            return RecognitionResult(value=None, score=0.0, source=RecogSource.COMBINED, uncertain=True)
        labels.append(second_label)
        scores.append(second_score)
        margins.append(second_margin)

    value = int("".join(labels))
    score = min(scores)
    margin = min(margins)
    valid = 1 <= value <= 90
    uncertain = not valid or score < 0.70 or margin < 0.035
    _log.debug(
        "basic_level: value=%s score=%.3f margin=%.3f second_occ=%.3f adaptive=%d uncertain=%s",
        value,
        score,
        margin,
        second_occupancy,
        sum(
            len(templates)
            for position in (adaptive_templates or {}).values()
            for templates in position.values()
        ),
        str(uncertain).lower(),
    )
    return RecognitionResult(
        value=value if valid else None,
        score=score,
        source=RecogSource.COMBINED,
        uncertain=uncertain,
        label=f"basic_level:{value}:margin={margin:.3f}",
    )


def read_basic_student_star_result(image: Image.Image, region: dict) -> RecognitionResult:
    """Count the right-aligned yellow star strip using an HSV foreground mask."""
    output_size = tuple(region.get("output_size", (185, 80)))
    warped = warp_quad_region(image, region, output_size=output_size)
    if warped is None:
        return RecognitionResult.fallback(None, "basic_star_region_missing")

    rgb = np.asarray(warped.convert("RGB"), dtype=np.uint8)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    mask = cv2.inRange(
        hsv,
        np.array((15, 80, 120), dtype=np.uint8),
        np.array((42, 255, 255), dtype=np.uint8),
    )
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((3, 3), dtype=np.uint8))
    count, _labels, stats, _centroids = cv2.connectedComponentsWithStats(mask)
    components = [stats[index] for index in range(1, count) if stats[index, cv2.CC_STAT_AREA] >= 20]
    if not components:
        return RecognitionResult(value=None, score=0.0, source=RecogSource.COMBINED, uncertain=True)

    x1 = min(int(stat[cv2.CC_STAT_LEFT]) for stat in components)
    y1 = min(int(stat[cv2.CC_STAT_TOP]) for stat in components)
    x2 = max(int(stat[cv2.CC_STAT_LEFT] + stat[cv2.CC_STAT_WIDTH]) for stat in components)
    y2 = max(int(stat[cv2.CC_STAT_TOP] + stat[cv2.CC_STAT_HEIGHT]) for stat in components)
    width = x2 - x1
    height = y2 - y1
    if height < 8:
        return RecognitionResult(value=None, score=0.0, source=RecogSource.COMBINED, uncertain=True)

    raw_count = 1.0 + max(0.0, width - height) / (0.79 * height)
    value = max(1, min(5, int(round(raw_count))))
    residual = abs(raw_count - value)
    score = max(0.0, min(1.0, 1.0 - residual / 0.35))
    uncertain = residual > 0.20
    _log.debug(
        "basic_star_color: value=%s score=%.3f width=%d height=%d raw=%.3f uncertain=%s",
        value,
        score,
        width,
        height,
        raw_count,
        str(uncertain).lower(),
    )
    return RecognitionResult(
        value=value,
        score=score,
        source=RecogSource.COMBINED,
        uncertain=uncertain,
        label=f"basic_star:{value}:raw={raw_count:.3f}",
    )


# ══════════════════════════════════════════════════════════
# 장비 티어
# ══════════════════════════════════════════════════════════

def rank_equip_tier_candidates(crop: Image.Image, slot: int) -> list[tuple[str, float]]:
    d = TEMPLATE_DIR / f"equip{slot}"
    candidates: dict[str, str] = {}

    empty_p = d / f"equip{slot}_empty.png"
    if empty_p.exists():
        candidates["empty"] = str(empty_p)
    for p in d.glob(f"equip{slot}_T*.png"):
        candidates[p.stem.replace(f"equip{slot}_", "")] = str(p)

    return sorted(
        (
            (
                lbl,
                0.60 * match_score_resized(crop, path)
                + 0.40 * _color_hist_score(crop, path),
            )
            for lbl, path in candidates.items()
        ),
        key=lambda x: x[1],
        reverse=True,
    )


def read_equip_tier(crop: Image.Image, slot: int) -> str:
    d = TEMPLATE_DIR / f"equip{slot}"
    candidates: dict[str, str] = {}

    empty_p = d / f"equip{slot}_empty.png"
    if empty_p.exists():
        candidates["empty"] = str(empty_p)
    for p in d.glob(f"equip{slot}_T*.png"):
        candidates[p.stem.replace(f"equip{slot}_", "")] = str(p)

    if not candidates:
        _log.warning(f"equip{slot}: 템플릿 없음 → unknown")
        return "unknown"

    scores = {
        lbl: (0.60 * match_score_resized(crop, path)
              + 0.40 * _color_hist_score(crop, path))
        for lbl, path in candidates.items()
    }
    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    _log.debug(f"equip{slot} tier: "
          + " ".join(f"{t}={s:.3f}" for t, s in ranked))

    best_lbl, best_score = ranked[0]
    if best_score < THRESHOLD_LOOSE:
        _log.debug(f"equip{slot}: {best_lbl}({best_score:.3f}) < {THRESHOLD_LOOSE} → unknown")
        return "unknown"
    return best_lbl


# ══════════════════════════════════════════════════════════
# V5 공식 인터페이스 (하위 호환)
# ══════════════════════════════════════════════════════════

def read_student_star_v5(crop: Image.Image) -> Optional[int]:
    """
    학생 성작 인식 (v5 호환 인터페이스).
    내부적으로 match_masked_icon() 경로 사용.
    """
    d = TEMPLATE_DIR / "star"
    cands = {
        str(i): str(d / f"star_{i}.png")
        for i in range(5, 0, -1)
        if (d / f"star_{i}.png").exists()
    }
    if not cands:
        return None
    lbl, score = best_match_masked_icons(crop, cands, threshold=0.65)
    _log.debug(f"student_star_v5: {lbl} ({score:.3f})")
    return int(lbl) if lbl is not None else None


def read_student_star_v5_result(crop: Image.Image) -> RecognitionResult:
    """학생 성작 인식 — RecognitionResult 반환."""
    d = TEMPLATE_DIR / "star"
    cands = {
        str(i): str(d / f"star_{i}.png")
        for i in range(5, 0, -1)
        if (d / f"star_{i}.png").exists()
    }
    if not cands:
        return RecognitionResult.fallback(None, "no_templates")
    lbl, score = best_match_masked_icons(crop, cands, threshold=0.60)
    _log.debug(f"student_star_v5_result: {lbl} ({score:.3f})")
    value = int(lbl) if lbl is not None else None
    return _make_result(value, score, RecogSource.TEMPLATE_MASKED)


def read_weapon_star_v5(crop: Image.Image) -> Optional[int]:
    """
    무기 성작 인식 (v5 호환 인터페이스).
    내부적으로 match_masked_icon() 경로 사용.
    """
    d = TEMPLATE_DIR / "weapon_star"
    cands = {
        str(i): str(d / f"star_{i}.png")
        for i in range(4, 0, -1)
        if (d / f"star_{i}.png").exists()
    }
    if not cands:
        return None
    lbl, score = best_match_masked_icons(crop, cands, threshold=0.65)
    _log.debug(f"weapon_star_v5: {lbl} ({score:.3f})")
    return int(lbl) if lbl is not None else None


@lru_cache(maxsize=1)
def _weapon_star_reference_glyph() -> np.ndarray | None:
    reference_path = TEMPLATE_DIR / "weapon_star" / "star_1.png"
    if not reference_path.exists():
        return None
    with Image.open(reference_path) as raw:
        reference_rgb = np.asarray(raw.convert("RGB"), dtype=np.uint8)
    reference_hsv = cv2.cvtColor(reference_rgb, cv2.COLOR_RGB2HSV)
    reference_mask = cv2.inRange(
        reference_hsv,
        np.array((80, 60, 100), dtype=np.uint8),
        np.array((115, 255, 255), dtype=np.uint8),
    )
    return normalize_binary_glyph(
        reference_mask,
        output_size=(32, 40),
        padding=1,
    )


def _count_weapon_star_slots(
    mask: np.ndarray,
    *,
    centers: tuple[float, ...],
    half_width: float,
    y1_ratio: float,
    y2_ratio: float,
    threshold: float = 0.70,
) -> tuple[Optional[int], float, tuple[float, ...]]:
    reference_glyph = _weapon_star_reference_glyph()
    if reference_glyph is None or mask.size == 0:
        return None, 0.0, ()
    height, width = mask.shape
    scores: list[float] = []
    for center in centers:
        x1 = max(0, int(round((center - half_width) * width)))
        x2 = min(width, int(round((center + half_width) * width)))
        y1 = max(0, int(round(y1_ratio * height)))
        y2 = min(height, int(round(y2_ratio * height)))
        glyph = normalize_binary_glyph(
            mask[y1:y2, x1:x2],
            output_size=(32, 40),
            padding=1,
        )
        scores.append(
            binary_glyph_similarity(glyph, reference_glyph)
            if glyph is not None
            else 0.0
        )
    for index, slot_score in enumerate(scores):
        if slot_score >= threshold:
            value = len(centers) - index
            score = min(1.0, 0.75 + (slot_score - threshold))
            return value, score, tuple(scores)
    return None, 0.0, tuple(scores)


def read_basic_weapon_star_result(crop: Image.Image) -> RecognitionResult:
    """Count 1-5 cyan stars on the compact basic-info weapon card."""
    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    if rgb.size == 0:
        return RecognitionResult.fallback(None, "empty_basic_weapon_star_crop")
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    mask = cv2.inRange(
        hsv,
        np.array((80, 60, 100), dtype=np.uint8),
        np.array((115, 255, 255), dtype=np.uint8),
    )
    slot_value, slot_score, slot_scores = _count_weapon_star_slots(
        mask,
        centers=(0.225, 0.3875, 0.55, 0.7125, 0.875),
        half_width=0.0813,
        y1_ratio=0.02,
        y2_ratio=1.0,
        threshold=0.62,
    )
    if slot_value is not None:
        _log.debug(
            "basic_weapon_star_slots: %s (score=%.3f slots=%s)",
            slot_value,
            slot_score,
            " ".join(f"{item:.3f}" for item in slot_scores),
        )
        return RecognitionResult(
            value=slot_value,
            score=slot_score,
            source=RecogSource.COMBINED,
            uncertain=False,
            label=f"basic_weapon_star_slots:{slot_value}({slot_score:.3f})",
        )

    count, _labels, stats, _centroids = cv2.connectedComponentsWithStats(mask)
    components = [stats[index] for index in range(1, count) if stats[index, cv2.CC_STAT_AREA] >= 8]
    if not components:
        return RecognitionResult.fallback(None, "basic_weapon_stars_missing")

    x1 = min(int(stat[cv2.CC_STAT_LEFT]) for stat in components)
    y1 = min(int(stat[cv2.CC_STAT_TOP]) for stat in components)
    x2 = max(int(stat[cv2.CC_STAT_LEFT] + stat[cv2.CC_STAT_WIDTH]) for stat in components)
    y2 = max(int(stat[cv2.CC_STAT_TOP] + stat[cv2.CC_STAT_HEIGHT]) for stat in components)
    width = x2 - x1
    height = y2 - y1
    if height < 4:
        return RecognitionResult.fallback(None, "basic_weapon_star_height_invalid")

    raw_count = width / (0.97 * height)
    value = int(round(raw_count))
    residual = abs(raw_count - value)
    valid = 1 <= value <= 5 and residual <= 0.22
    score = max(0.0, min(1.0, 1.0 - residual / 0.50))
    _log.debug(
        "basic_weapon_star_color: %s (score=%.3f width=%d height=%d raw=%.3f valid=%s)",
        value,
        score,
        width,
        height,
        raw_count,
        valid,
    )
    return RecognitionResult(
        value=value if valid else None,
        score=score,
        source=RecogSource.COMBINED,
        uncertain=not valid,
        label=f"basic_weapon_star:{value}({score:.3f},raw={raw_count:.3f})",
    )


def _weapon_star_count_from_color(crop: Image.Image) -> tuple[Optional[int], float]:
    """Count the contiguous cyan weapon-star strip, independent of its x offset."""
    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    if rgb.size == 0:
        return None, 0.0

    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    mask = cv2.inRange(
        hsv,
        np.array((80, 60, 100), dtype=np.uint8),
        np.array((115, 255, 255), dtype=np.uint8),
    )
    # Match the four fixed, right-aligned star slots independently. A large
    # cyan/white weapon can run behind this strip and connect to one of the
    # stars; slot silhouettes keep that background from changing the count.
    reference_path = TEMPLATE_DIR / "weapon_star" / "star_1.png"
    if reference_path.exists():
        reference_rgb = np.asarray(Image.open(reference_path).convert("RGB"), dtype=np.uint8)
        reference_hsv = cv2.cvtColor(reference_rgb, cv2.COLOR_RGB2HSV)
        reference_mask = cv2.inRange(
            reference_hsv,
            np.array((80, 60, 100), dtype=np.uint8),
            np.array((115, 255, 255), dtype=np.uint8),
        )
        reference_glyph = normalize_binary_glyph(
            reference_mask,
            output_size=(32, 40),
            padding=1,
        )
        if reference_glyph is not None:
            height, width = mask.shape
            centers = (0.186, 0.371, 0.557, 0.743)
            slot_scores: list[float] = []
            for center in centers:
                x1 = max(0, int(round((center - 0.093) * width)))
                x2 = min(width, int(round((center + 0.093) * width)))
                y1 = max(0, int(round(0.25 * height)))
                y2 = min(height, int(round(0.87 * height)))
                glyph = normalize_binary_glyph(
                    mask[y1:y2, x1:x2],
                    output_size=(32, 40),
                    padding=1,
                )
                slot_scores.append(
                    binary_glyph_similarity(glyph, reference_glyph)
                    if glyph is not None
                    else 0.0
                )
            for index, slot_score in enumerate(slot_scores):
                if slot_score >= 0.70:
                    value = 4 - index
                    score = min(1.0, 0.75 + (slot_score - 0.70))
                    _log.debug(
                        "weapon_star_slots: %s (score=%.3f slots=%s)",
                        value,
                        score,
                        " ".join(f"{item:.3f}" for item in slot_scores),
                    )
                    return value, score

    count, _, stats, _ = cv2.connectedComponentsWithStats(mask)
    components = [stats[i] for i in range(1, count) if stats[i, cv2.CC_STAT_AREA] >= 8]
    if not components:
        return None, 0.0

    x1 = min(int(stat[cv2.CC_STAT_LEFT]) for stat in components)
    y1 = min(int(stat[cv2.CC_STAT_TOP]) for stat in components)
    x2 = max(int(stat[cv2.CC_STAT_LEFT] + stat[cv2.CC_STAT_WIDTH]) for stat in components)
    y2 = max(int(stat[cv2.CC_STAT_TOP] + stat[cv2.CC_STAT_HEIGHT]) for stat in components)
    width = x2 - x1
    height = y2 - y1
    if height < 4:
        return None, 0.0

    # Current stars are spaced at about 0.97 star-heights per slot.
    raw_count = width / (0.97 * height)
    value = max(1, min(4, int(round(raw_count))))
    residual = abs(raw_count - value)
    score = max(0.0, min(1.0, 1.0 - residual / 0.45))
    _log.debug(
        "weapon_star_color: %s (score=%.3f width=%d height=%d raw=%.3f)",
        value, score, width, height, raw_count,
    )
    return value, score


def read_weapon_star_v5_result(crop: Image.Image) -> RecognitionResult:
    """무기 성작 인식 — RecognitionResult 반환."""
    color_value, color_score = _weapon_star_count_from_color(crop)
    if color_value is not None and color_score >= 0.75:
        return _make_result(
            color_value,
            color_score,
            RecogSource.COMBINED,
            confident_thresh=0.75,
        )

    d = TEMPLATE_DIR / "weapon_star"
    cands = {
        str(i): str(d / f"star_{i}.png")
        for i in range(4, 0, -1)
        if (d / f"star_{i}.png").exists()
    }
    if not cands:
        return RecognitionResult.fallback(None, "no_templates")
    lbl, score = best_match_masked_icons(crop, cands, threshold=0.60)
    _log.debug(f"weapon_star_v5_result: {lbl} ({score:.3f})")
    value = int(lbl) if lbl is not None else None
    return _make_result(value, score, RecogSource.TEMPLATE_MASKED)


def read_student_level_v5(
    img: Image.Image,
    digit1_region: dict,
    digit2_region: dict,
) -> Optional[int]:
    raw = read_student_level(img, digit1_region, digit2_region)
    try:
        return int(raw)
    except (TypeError, ValueError) as e:
        _log.warning(f"read_student_level_v5: 변환 실패 (raw={raw!r}) — {e}")
        return None
