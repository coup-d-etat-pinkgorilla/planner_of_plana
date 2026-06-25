"""
core/matcher.py ??BA Analyzer v6
OpenCV ??쀫탣??筌띲끉臾??遺우춭

癰궰野껋럩??(v5 ??v6):
  - ?袁⑹퓗???꾨뗀諭???볤탢 ??core/preprocess.py ?袁⑹뿫
  - ???뵬 I/O ??볤탢 ??core/template_cache.py ?袁⑹뿫
    夷?_load_tmpl (lru_cache) ?袁⑹읈 ??볤탢
    夷?筌뤴뫀諭???쀫탣???臾롫젏?? _tmpl(path) ???곭몴????퉸 筌?Ŋ??癒?퐣筌???뚯벉
  - ??λ땾 ?????Image.open / cv2.imread / lru_cache ??곸벉
  - ?遺얠쒔域?嚥≪뮄?????????뵬: [Matcher] {??λ땾筌?: {野껉퀗?? ({?癒?땾:.3f})
"""

from __future__ import annotations

import cv2
import numpy as np
import os
from functools import lru_cache
from enum import Enum
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
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


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ?紐꾨뻼 野껉퀗??筌롫???類ｋ궖 ????
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

from dataclasses import dataclass, field as dc_field
from enum import Enum as _Enum


class RecogSource(_Enum):
    """?紐꾨뻼 獄쎻뫖苡???볥젃 ???遺얠쒔域??곕뗄???"""
    TEMPLATE_RESIZED = "template_resized"   # match_score_resized
    TEMPLATE_MASKED  = "template_masked"    # match_masked_icon
    TEMPLATE_TEXT    = "template_text"      # match_score_textonly
    TEMPLATE_RAW     = "template_raw"       # match_score (?癒?궚 ??由?
    COLOR_HIST       = "color_hist"         # _color_hist_score
    COMBINED         = "combined"           # ????獄쎻뫖苡???노?
    OCR              = "ocr"                # EasyOCR
    SKIPPED          = "skipped"            # 鈺곌퀗援?沃섎챷?먫?源놁몵嚥???쎄땁
    FALLBACK         = "fallback"           # 疫꿸퀡??첎?????


@dataclass
class RecognitionResult:
    """
    ?紐꾨뻼 野껉퀗??+ ?醫듚??筌롫???類ｋ궖.

    Attributes
    ----------
    value      : ?紐꾨뻼??揶?(int / str / None)
    score      : ?醫롪텢???癒?땾 0.0~1.0 (?誘れ뱽??롮쨯 ?類ㅻ뼄)
    source     : ??堉?獄쎻뫖苡??곗쨮 ?紐꾨뻼??덈뮉筌왖
    uncertain  : True ????score 揶쎛 UNCERTAIN ?닌덉퍢 (?????亦낅슣??
    label      : 嚥≪뮄???筌욁룂? ??살구 (?癒?짗 ??밴쉐)

    ??????
    -------
    r = read_skill_result(crop, "EX_Skill")
    if r.uncertain:
        log(f"[野껋럡?? EX ??쎄텢 ?紐꾨뻼 ?븍뜇??? {r.value} ({r.score:.3f})")
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
        """鈺곌퀗援?沃섎챷?먫?源놁몵嚥???쎄땁??野껉퀗??"""
        return cls(value=None, score=0.0,
                   source=RecogSource.SKIPPED, label=f"skipped:{reason}")

    @classmethod
    def fallback(cls, value, reason: str = "") -> "RecognitionResult":
        """疫꿸퀡??첎誘れ몵嚥???筌ｋ?留?野껉퀗??"""
        return cls(value=value, score=0.0,
                   source=RecogSource.FALLBACK, label=f"fallback:{reason}")


# ???? ?醫듚???닌덉퍢 ?怨몃땾 ????????????????????????????????????????????????????????????????????????????
# score 揶쎛 ?????袁㏉롥첎?????SCORE_UNCERTAIN ~ SCORE_CONFIDENT)筌?
# uncertain=True 嚥?筌띾뜇沅?
SCORE_CONFIDENT  = 0.75   # ??곴맒?????類ㅻ뼄
SCORE_UNCERTAIN  = 0.55   # ??곴맒 CONFIDENT 沃섎챶彛?????븍뜇???
                           # 沃섎챶彛??????쎈솭(value=None 筌ｌ꼶??


def _make_result(
    value:    Optional[int | str],
    score:    float,
    source:   RecogSource,
    *,
    confident_thresh:  float = SCORE_CONFIDENT,
    uncertain_thresh:  float = SCORE_UNCERTAIN,
) -> RecognitionResult:
    """
    score ?닌덉퍢???怨뺤뵬 uncertain ???삋域밸챶? ?癒?짗 ??쇱젟??롫뮉 ??븍꽅??

    score >= confident_thresh ??uncertain=False
    score >= uncertain_thresh ??uncertain=True  (?醫듼꼻??野껉퀗?듸쭪?筌?獄쏆꼹??
    score <  uncertain_thresh ??value=None, uncertain=True (??쎈솭)
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
    # score 沃섎챶??????쎈솭
    return RecognitionResult(value=None, score=score,
                             source=source, uncertain=True)


# ???? ??쀫탣???臾롫젏 ????????????????????????????????????????????????????????????????????????????????

def _tmpl(path: str) -> Optional[TemplateEntry]:
    """
    野껋럥以덃에?筌?Ŋ??癒?퐣 TemplateEntry 鈺곌퀬??
    筌?Ŋ??沃섎챷????on-demand 嚥≪뮆諭???獄쏆꼹??
    ???뵬 ??곸몵筌?None.
    """
    cache = get_cache()
    entry = cache.get_by_path(path)
    if entry is not None:
        return entry
    # warmup ????釉??? ??? ???뵬 ??on-demand 嚥≪뮆諭?
    return cache.load(path)


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# 筌띲끉臾??袁㏉롥첎?
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

THRESHOLD         = 0.80
THRESHOLD_LOOSE   = 0.72
THRESHOLD_LOBBY   = 0.90
THRESHOLD_STUDENT_MENU = 0.90
THRESHOLD_STUDENT_ADDITIONAL_MENU = 0.90
THRESHOLD_STUDENT_TAB_ON = 0.90
TEXTURE_THRESHOLD        = 0.60
TEXTURE_MARGIN_REQUIRED  = 0.05
STUDENT_TEXTURE_TOP_K = 10
STUDENT_TEXTURE_CONSENSUS_SCORE_FLOOR = 0.86
STUDENT_TEXTURE_CONSENSUS_MARGIN = 0.10
STUDENT_TEXTURE_PREFILTER_MARGIN = 0.008
STUDENT_TEXTURE_ROBUST_WIDTH = 160
STUDENT_TEXTURE_ROBUST_SCALES = (0.96, 1.0, 1.04)
STUDENT_TEXTURE_TOP_K_ENV = "BA_STUDENT_TOPK"
STUDENT_TEXTURE_TOPK_METHOD_ENV = "BA_STUDENT_TOPK_METHOD"
STUDENT_TEXTURE_TOPK_SHADOW_ENV = "BA_STUDENT_TOPK_SHADOW"
STUDENT_TEXTURE_TOPK_METHODS = {"fusion", "hybrid", "thumb", "hist", "hash"}
WEAPON_STATE_MIN_SCORE = 0.62
WEAPON_EQUIPPED_MIN_SCORE = 0.78
WEAPON_EQUIPPED_MARGIN_REQUIRED = 0.12
WEAPON_EQUIPPED_ORANGE_RATIO = 0.12


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ?遺얠젂?怨뺚봺 / ???뵬 ?怨몃땾
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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
BASIC_ADDITIONAL_STAT_VALUE_DIR = "basic_additional_stat_values"


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# Enum
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

class WeaponState(Enum):
    NO_WEAPON_SYSTEM             = "no_weapon_system"
    WEAPON_EQUIPPED              = "weapon_equipped"
    WEAPON_UNLOCKED_NOT_EQUIPPED = "weapon_unlocked_not_equipped"

WeaponStatus = WeaponState   # ??륁맄 ?紐낆넎


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


# ???? _load_tmpl ?? ??볤탢????_tmpl() ????????(???뵬 ?怨룸뼊)


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# 疫꿸퀡??筌띲끉臾???λ땾
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

def match_score(crop: Image.Image, tmpl_path: str) -> float:
    """
    ?癒?궚 ??곴맒??TM_CCOEFF_NORMED 筌띲끉臾?(??곕솁 筌띾뜆???筌왖??.
    ???뵬 I/O ??곸벉 ??_tmpl() 筌?Ŋ??癒?퐣 ??뚯벉.
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
        log_cv2_error(_log, "match_score ??쎈솭", e,
                      ctx=MatchCtx(roi=Path(tmpl_path).stem))
        return 0.0


def match_score_resized(
    crop: Image.Image,
    tmpl_path: str,
    focus_center: bool = False,
) -> float:
    """
    crop ????쀫탣????由??筌띿쉸???귐딄텢??곸グ ????곸춭????쑨??
    ?袁⑹퓗?? preprocess_for_template()
    ?癒?땾: NCC 0.7 + pixel_diff 0.3
    ???뵬 I/O ??곸벉 ??_tmpl() 筌?Ŋ??癒?퐣 ??뚯벉.
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
    ??곕솁 筌띾뜆???疫꿸퀡而??귐딄텢??곸グ 筌띲끉臾?
    ?袁⑹퓗?? preprocess_for_masked_template()
    ?癒?땾: corr 0.50 + diff 0.30 + edge 0.20
    ???뵬 I/O ??곸벉 ??_tmpl() 筌?Ŋ??癒?퐣 ??뚯벉.
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

    # alpha_r ??focus_crop ??곗쨮 ??롮죬??????됱몵????由??????
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
    ??용뮞????ъ쁽) ???筌??곕뗄???곴퐣 ??쑨??
    ?袁⑹퓗?? preprocess_for_text_template()
    ?癒?땾: NCC 0.7 + pixel_diff 0.3
    ???뵬 I/O ??곸벉 ??_tmpl() 筌?Ŋ??癒?퐣 ??뚯벉.
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


# ???? ??? ??????????????????????????????????????????????????????????????????????????????????????????????

def _preprocess_tmpl_gray(
    tmpl_g: np.ndarray,
    w: int,
    h: int,
    use_focus_crop: bool = False,
    do_binarize: bool = True,
) -> np.ndarray:
    """
    ??? 嚥≪뮆諭????쀫탣??gray ndarray ????덉뵬 ???뵠?袁⑥뵬?紐꾩몵嚥??袁⑹퓗??
    (PIL Image 癰궰????곸뵠 獄쏅뗀以?筌ｌ꼶?????얜즲 ??뉗빵)
    """
    arr = cv2.resize(tmpl_g, (w, h), interpolation=cv2.INTER_AREA)
    arr = normalize_hist(arr)
    if do_binarize:
        arr = binarize(arr)
    if use_focus_crop:
        arr, _ = focus_center_crop(arr)
    return arr


def _ncc_diff_score(a: np.ndarray, b: np.ndarray) -> float:
    """NCC 0.7 + pixel_diff 0.3 ?癒?땾."""
    if a.shape != b.shape:
        b = cv2.resize(b, (a.shape[1], a.shape[0]), interpolation=cv2.INTER_AREA)
    try:
        res = cv2.matchTemplate(a, b, cv2.TM_CCOEFF_NORMED)
        _, ncc, _, _ = cv2.minMaxLoc(res)
        diff = np.mean(np.abs(a.astype(np.float32) - b.astype(np.float32))) / 255.0
        return 0.7 * float(ncc) + 0.3 * (1.0 - float(diff))
    except cv2.error as e:
        log_cv2_error(_log, "_ncc_diff_score ??쎈솭", e)
        return 0.0


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# 筌띾뜆???筌띲끉臾????????됱뵠??
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
#
# 域뱀뮇??
#   - RGBA ??쀫탣?? ????곕솁 筌?쑬瑗??筌띾뜆???以????? (has_alpha=True)
#   - RGB ??쀫탣??  ??筌띾뜆?????곸벉, ?袁⑷퍥 ??? ??쑨??
#   - ??곕솁 threshold: ALPHA_THRESH (疫꿸퀡??30) ??곴맒?????筌??醫륁뒞
#   - ?紐꾪뀱 筌왖???닌됲뀋:
#       癰?/ ?얜떯由계퉪?/ ?袁⑹뵠?? ??match_masked_icon()   ????
#       ??곗뺘 UI ??쀫탣??       ??match_score_resized()  ????
#       ??용뮞????ъ쁽           ??match_score_textonly() ????
#   - ??野껋럥以덄몴???롫선 ?怨? ??낅즲嚥?read_star / read_weapon_star ?源녿퓠??
#     獄쏆꼶諭??match_masked_icon() 筌??紐꾪뀱??野?
#
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

# ??곕솁 ?醫륁뒞 ??? 筌ㅼ뮇?쇔첎?(0~255). ??揶?沃섎챶彛?? 獄쏄퀗瑗??곗쨮 揶쏄쑴竊?
ALPHA_THRESH: int = 30

# 筌띾뜆???筌띲끉臾??癒?땾 揶쎛餓λ쵐??
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
    ??곕솁 筌?쑬瑗???boolean 筌띾뜆???(?醫륁뒞 ??? = True).

    Parameters
    ----------
    alpha    : ??쀫탣????곕솁 筌?쑬瑗?(H?얱 uint8). None ?????袁⑷퍥 ?醫륁뒞.
    target_h : ?귐딄텢??곸グ 筌뤴뫚紐??誘れ뵠
    target_w : ?귐딄텢??곸グ 筌뤴뫚紐???덊돩
    thresh   : ?醫륁뒞 ??? 筌ㅼ뮇????곕솁揶?

    Returns
    -------
    bool ndarray (target_h ??target_w)
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
    筌띾뜆????怨몃열筌???쑨???롫뮉 ?癒?땾 ?④쑴沅?
    corr 0.50 + diff 0.30 + edge 0.20

    Parameters
    ----------
    crop_g : ?袁⑹퓗?귐됰쭆 crop grayscale (H?얱 uint8)
    tmpl_g : ?袁⑹퓗?귐됰쭆 template grayscale (H?얱 uint8)
    mask   : ?醫륁뒞 ??? boolean mask (H?얱)

    Returns
    -------
    float 0.0 ~ 1.0
    """
    if not np.any(mask):
        return 0.0

    cf = crop_g.astype(np.float32)
    tf = tmpl_g.astype(np.float32)

    # ???? diff score ????????????????????????????????????????????????????????????????????????????????
    diff_score = 1.0 - float(np.abs(cf - tf)[mask].mean() / 255.0)

    # ???? correlation score ??????????????????????????????????????????????????????????????????
    cv_ = cf[mask] - cf[mask].mean()
    tv_ = tf[mask] - tf[mask].mean()
    dnom = np.linalg.norm(cv_) * np.linalg.norm(tv_)
    corr_raw = 0.0 if dnom < 1e-6 else float(np.dot(cv_, tv_) / dnom)
    corr = max(0.0, min(1.0, (corr_raw + 1.0) / 2.0))

    # ???? edge score ????????????????????????????????????????????????????????????????????????????????
    # Canny ??uint8 獄쏄퀣肉??袁⑹뒄
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
    ?袁⑹뵠??癰??얜떯由계퉪??袁⑹뒠 筌띾뜆???筌띲끉臾???λ땾.

    - RGBA ??쀫탣?깆슦?좑쭖???곕솁??筌띾뜆???以???????獄쏄퀗瑗??袁⑹읈 ?얜똻??
    - RGB  ??쀫탣?깆슦?좑쭖??袁⑷퍥 ??? ??쑨??(??륁맄 ?紐낆넎)
    - ??湲?筌?Ŋ??癒?퐣 ??쀫탣????뚯벉 (???뵬 I/O ??곸벉)

    Parameters
    ----------
    crop        : ??쑨??????PIL Image (??? crop ??ROI)
    tmpl_path   : ??쀫탣?????뵬 ??? 野껋럥以?
    target_size : (w, h) ?귐딄텢??곸グ 筌뤴뫚紐? None ??????쀫탣???癒?궚 ??由?????
    thresh      : ?醫륁뒞 ??? 筌ㅼ뮇????곕솁揶?(ALPHA_THRESH)

    Returns
    -------
    float 0.0 ~ 1.0
    """
    entry = _tmpl(tmpl_path)
    if entry is None:
        return 0.0

    # 筌뤴뫚紐???由?野껉퀣??
    if target_size is not None:
        w_t, h_t = target_size
    else:
        h_t, w_t = entry.gray.shape[:2]

    if h_t < 2 or w_t < 2:
        return 0.0

    # crop ?袁⑹퓗??(gray + normalize + binarize)
    crop_proc = preprocess_for_template(crop, w_t, h_t)

    # ??쀫탣???袁⑹퓗??(筌?Ŋ???gray ??沅??
    tmpl_proc = _preprocess_tmpl_gray(entry.gray, w_t, h_t)

    # 筌띾뜆?????밴쉐
    mask = _build_alpha_mask(entry.alpha, h_t, w_t, thresh=thresh)

    return _masked_score(crop_proc, tmpl_proc, mask)


def best_match_masked_icons(
    crop:       Image.Image,
    candidates: dict[str, str],
    threshold:  float = 0.68,
    thresh:     int   = ALPHA_THRESH,
) -> tuple[Optional[str], float]:
    """
    ?袁⑤궖 ?袁⑹뵠??筌욌쵑鍮?癒?퐣 筌띾뜆???筌띲끉臾??곗쨮 筌ㅼ뮄???癒?땾 ??곌볼 獄쏆꼹??

    Parameters
    ----------
    crop       : ??쑨??????PIL Image
    candidates : {label: tmpl_path} 筌띲끋釉?
    threshold  : 筌ㅼ뮇???癒?땾 (????곴맒?????춸 獄쏆꼹??
    thresh     : ?醫륁뒞 ??? 筌ㅼ뮇????곕솁揶?

    Returns
    -------
    (best_label, best_score)  ?癒?땾 沃섎챶????(None, best_score)
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
    ?袁⑤궖 筌욌쵑鍮?癒?퐣 筌ㅼ뮄???癒?땾 ??곌볼 獄쏆꼹??

    Parameters
    ----------
    masked : True ????match_masked_icon() ??곗쨮 ?袁⑹뿫.
             癰??袁⑹뵠???紐꾨뻼?? best_match_masked_icons() ??筌욊낯???紐꾪뀱??野?
             ?????뵬沃섎챸苑????륁맄 ?紐낆넎???袁る퉸 ?醫???롫┷ ????癒?퐣 ??? 野껋럥以덃에??袁⑹뿫.
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


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# 嚥≪뮆??揶쏅Ŋ?
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ??덇문 ??용뮞筌?筌띲끉臾?
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

def _color_hist_score(crop: Image.Image, tmpl_path: str) -> float:
    """?뚎됱쑎 ??됰뮞?醫됰젃???醫롪텢?? ???뵬 I/O ??곸벉 ??_tmpl() 筌?Ŋ??癒?퐣 ??뚯벉."""
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
        log_cv2_error(_log, "color_hist_score ??쎈솭", e,
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


def _student_texture_prefilter_decision(
    crop: Image.Image,
    cands: dict[str, str],
    method: str,
) -> tuple[Optional[str], float, float]:
    """Return the cheap feature winner and margin for shortlist consensus."""
    if not cands:
        return None, 0.0, 0.0
    features = _student_texture_features()
    crop_thumb = _student_texture_thumb(crop)
    crop_hist = _student_texture_hist(crop)
    crop_hash = _student_texture_hash(crop)
    ranked = sorted(
        (
            (
                sid,
                _student_texture_feature_score(
                    crop_thumb, crop_hist, crop_hash, features[sid], method
                ),
            )
            for sid in cands
            if sid in features
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    if not ranked:
        return None, 0.0, 0.0
    best_sid, best_score = ranked[0]
    second_score = ranked[1][1] if len(ranked) > 1 else 0.0
    return best_sid, best_score, best_score - second_score


def _student_texture_robust_score(crop: Image.Image, template_path: str) -> float:
    """Score one portrait after low-resolution, center-aligned scale matching."""
    entry = _tmpl(template_path)
    if entry is None:
        return 0.0
    crop_gray = cv2.cvtColor(to_bgr(crop), cv2.COLOR_BGR2GRAY)
    template_gray = entry.gray
    if crop_gray.size == 0 or template_gray.size == 0:
        return 0.0

    width = STUDENT_TEXTURE_ROBUST_WIDTH
    height = max(32, int(round(width * template_gray.shape[0] / template_gray.shape[1])))
    sample = cv2.resize(crop_gray, (width, height), interpolation=cv2.INTER_AREA)
    template = cv2.resize(template_gray, (width, height), interpolation=cv2.INTER_AREA)

    best_ncc = -1.0
    for scale in STUDENT_TEXTURE_ROBUST_SCALES:
        scaled_w = max(8, int(round(width * scale)))
        scaled_h = max(8, int(round(height * scale)))
        scaled = cv2.resize(template, (scaled_w, scaled_h), interpolation=cv2.INTER_AREA)

        # Compare only center-aligned regions. Searching arbitrary offsets can
        # align one student's background with another and raise false accepts.
        common_w = min(width, scaled_w)
        common_h = min(height, scaled_h)
        sample_x = (width - common_w) // 2
        sample_y = (height - common_h) // 2
        scaled_x = (scaled_w - common_w) // 2
        scaled_y = (scaled_h - common_h) // 2
        sample_center = sample[
            sample_y : sample_y + common_h,
            sample_x : sample_x + common_w,
        ]
        scaled_center = scaled[
            scaled_y : scaled_y + common_h,
            scaled_x : scaled_x + common_w,
        ]
        result = cv2.matchTemplate(sample_center, scaled_center, cv2.TM_CCOEFF_NORMED)
        _min_val, max_val, _min_loc, _max_loc = cv2.minMaxLoc(result)
        best_ncc = max(best_ncc, float(max_val))

    color_score = _color_hist_score(crop, template_path)
    return max(0.0, min(1.0, 0.72 * best_ncc + 0.28 * color_score))


def _match_student_texture_robust(
    crop: Image.Image,
    cands: dict[str, str],
    *,
    label: str,
) -> tuple[Optional[str], float, float]:
    if not cands:
        return None, 0.0, 0.0
    scores = sorted(
        ((sid, _student_texture_robust_score(crop, path)) for sid, path in cands.items()),
        key=lambda item: item[1],
        reverse=True,
    )
    best_sid, best_score = scores[0]
    second_score = scores[1][1] if len(scores) > 1 else 0.0
    margin = best_score - second_score
    _log.debug(
        "texture_robust[%s]: pool=%d 1st=%s(%.3f) 2nd=%s(%.3f) margin=%.3f",
        label,
        len(cands),
        best_sid,
        best_score,
        scores[1][0] if len(scores) > 1 else "-",
        second_score,
        margin,
    )
    return best_sid, best_score, margin


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


def _match_student_texture_with_topk_decision(
    crop: Image.Image,
    cands: dict[str, str],
    *,
    label: str,
    top_k: int,
    method: str,
    injected_candidate_ids: Iterable[str] | None = None,
) -> tuple[Optional[str], float, float, bool]:
    if not cands:
        return None, 0.0, 0.0, False

    if top_k > 0 and len(cands) > top_k:
        top_cands = _top_student_texture_candidates(crop, cands, top_k, method)
        injected_ids = set(injected_candidate_ids or ()).intersection(cands)
        if injected_ids:
            top_cands.update({sid: cands[sid] for sid in injected_ids})
            _log.debug(
                "texture_topk_attribute_inject: visual=%d injected=%d union=%d",
                min(top_k, len(cands)), len(injected_ids), len(top_cands),
            )
        feature_sid, feature_score, feature_margin = _student_texture_prefilter_decision(
            crop, top_cands, method
        )
        sid, score, margin = _match_student_texture_robust(
            crop,
            top_cands,
            label=f"{label}:topk_robust",
        )
        consensus = (
            sid is not None
            and sid == feature_sid
            and score >= STUDENT_TEXTURE_CONSENSUS_SCORE_FLOOR
            and margin >= STUDENT_TEXTURE_CONSENSUS_MARGIN
            and feature_margin >= STUDENT_TEXTURE_PREFILTER_MARGIN
            and (not injected_ids or sid in injected_ids)
        )
        _log.debug(
            "texture_topk_consensus: method=%s k=%d robust_sid=%s feature_sid=%s "
            "robust_score=%.3f robust_margin=%.3f feature_score=%.3f "
            "feature_margin=%.3f accepted=%s pool=%d",
            method,
            top_k,
            sid,
            feature_sid,
            score,
            margin,
            feature_score,
            feature_margin,
            str(consensus).lower(),
            len(cands),
        )
        if consensus:
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
                return full_sid, full_score, full_margin, False
            return sid, score, margin, True
        _log.debug(
            "texture_topk_fallback: method=%s k=%d sid=%s score=%.3f margin=%.3f pool=%d",
            method,
            top_k,
            sid,
            score,
            margin,
            len(cands),
        )

    sid, score, margin = _match_student_texture_precise(crop, cands, label=label)
    return sid, score, margin, False


def _match_student_texture_with_topk(
    crop: Image.Image,
    cands: dict[str, str],
    *,
    label: str,
    top_k: int,
    method: str,
    injected_candidate_ids: Iterable[str] | None = None,
) -> tuple[Optional[str], float, float]:
    """Compatibility wrapper returning the public three-value match tuple."""
    sid, score, margin, _shortcut = _match_student_texture_with_topk_decision(
        crop, cands, label=label, top_k=top_k, method=method,
        injected_candidate_ids=injected_candidate_ids,
    )
    return sid, score, margin


def _match_student_texture_optimized(
    crop: Image.Image,
    candidate_ids: Iterable[str] | None = None,
    *,
    fallback_candidate_ids: Iterable[str] | None = None,
    top_k: int | None = None,
    injected_candidate_ids: Iterable[str] | None = None,
) -> tuple[Optional[str], float]:
    actual_top_k = _student_texture_topk_from_env() if top_k is None else max(0, top_k)
    method = _student_texture_topk_method_from_env()
    _log_student_texture_topk_config(method, actual_top_k)
    primary_cands = _student_texture_candidates(candidate_ids)
    sid, score, margin, primary_shortcut = _match_student_texture_with_topk_decision(
        crop,
        primary_cands,
        label="primary",
        top_k=actual_top_k,
        method=method,
        injected_candidate_ids=injected_candidate_ids,
    )

    if fallback_candidate_ids is None:
        return sid, score

    if primary_shortcut:
        return sid, score

    fallback_cands = _student_texture_candidates(fallback_candidate_ids)
    fallback_sid, fallback_score, _fallback_margin, _fallback_shortcut = (
        _match_student_texture_with_topk_decision(
        crop,
        fallback_cands,
        label="fallback",
        top_k=actual_top_k,
        method=method,
        injected_candidate_ids=injected_candidate_ids,
        )
    )
    return fallback_sid, fallback_score


def match_student_texture(
    crop: Image.Image,
    candidate_ids: Iterable[str] | None = None,
    *,
    fallback_candidate_ids: Iterable[str] | None = None,
    top_k: int | None = None,
    injected_candidate_ids: Iterable[str] | None = None,
) -> tuple[Optional[str], float]:
    return _match_student_texture_optimized(
        crop,
        candidate_ids,
        fallback_candidate_ids=fallback_candidate_ids,
        top_k=top_k,
        injected_candidate_ids=injected_candidate_ids,
    )


_STUDENT_BASIC_ATTRIBUTE_FIELDS = {
    "attack_type", "defense_type", "position", "combat_class", "role",
}


@lru_cache(maxsize=None)
def _student_basic_attribute_templates(field: str) -> tuple[tuple[str, str], ...]:
    if field not in _STUDENT_BASIC_ATTRIBUTE_FIELDS:
        return ()
    directory = TEMPLATE_DIR / "student_basic_attributes" / field
    return tuple((path.stem, str(path)) for path in sorted(directory.glob("*.png")))


def read_basic_student_attribute_result(crop: Image.Image, field: str) -> RecognitionResult:
    """Classify one fixed basic-card attribute label."""
    templates = _student_basic_attribute_templates(field)
    if not templates:
        return RecognitionResult.fallback(None, f"student_attribute_templates_missing:{field}")
    ranked = sorted(
        ((label, match_score_resized_raw(crop, path)) for label, path in templates),
        key=lambda item: item[1],
        reverse=True,
    )
    label, score = ranked[0]
    second_score = ranked[1][1] if len(ranked) > 1 else 0.0
    margin = score - second_score
    uncertain = score < 0.90 or margin < 0.10
    return RecognitionResult(
        value=None if uncertain else label,
        score=score,
        source=RecogSource.TEMPLATE_RAW,
        uncertain=uncertain,
        label=f"student_attribute:{field}:{label}({score:.3f},margin={margin:.3f})",
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
        f"texture: 1??{best_id}({best_s:.3f}) "
        f"2??{scores[1][0] if len(scores)>1 else '-'}({second_s:.3f}) "
        f"margin={margin:.3f}"
    )

    if best_s < TEXTURE_THRESHOLD or margin < TEXTURE_MARGIN_REQUIRED:
        return None, best_s
    return best_id, best_s

identify_student_by_texture = match_student_texture   # ??륁맄 ?紐낆넎


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ?얜떯由??怨밴묶
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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
    _log.debug(f"weapon_state: { {k: f'{v:.3f}' for k,v in scores.items()} } ??{best_key}")

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

detect_weapon_status = detect_weapon_state   # ??륁맄 ?紐낆넎


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


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# Check ???삋域?
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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
            _log.warning(f"equip_check ??IMPOSSIBLE")
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


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ?貫?????????삋域?
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ??쎄틛
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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
    read_stat_value() ??RecognitionResult 獄쏆꼹??甕곌쑴??
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


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# Digit ??????꾨┛ (?貫????덇볼 / ?얜떯由???덇볼 / ??덇문 ??덇볼 ?⑤벏??
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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
            except ValueError as e: _log.debug(f"equip_level d2 癰궰????쎈솭: {e}"); pass
        return None
    if d2:
        try: return int(d1 + d2)
        except ValueError as e: _log.debug(f"equip_level d1+d2 癰궰????쎈솭: {e}"); pass
    try: return int(d1)
    except ValueError as e: _log.debug(f"equip_level d1 癰궰????쎈솭: {e}"); return None


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
    return _read_weapon_level_glyph_result(
        crop,
        center_trim=int(region.get("center_trim_pixels", 0) or 0),
    )


def _normalize_basic_equipment_glyph(crop: Image.Image) -> np.ndarray | None:
    """Keep the navy/blue glyph while discarding the equipment artwork."""
    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    if rgb.size == 0:
        return None
    red = rgb[:, :, 0].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    value = rgb.max(axis=2)
    mask = ((blue - red >= 10) & (value < 195)).astype(np.uint8) * 255
    return normalize_binary_glyph(mask)


def _normalize_basic_equipment_tier_glyph(crop: Image.Image) -> np.ndarray | None:
    """Normalize the complete ``Tn`` text group, not the surrounding badge."""
    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    if rgb.size == 0:
        return None
    height, width = rgb.shape[:2]
    # The text is anchored at the badge's left side. Excluding the far-right
    # and extreme vertical edges prevents item art and the badge border from
    # becoming part of the learned sample.
    rgb = rgb[
        max(0, int(height * 0.06)):max(1, int(height * 0.94)),
        :max(1, int(width * 0.86)),
    ]
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    binary = (
        (blue >= 125)
        & (blue - red >= 45)
        & (blue - green >= 8)
    ).astype(np.uint8) * 255
    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(binary)
    keep = [
        index for index in range(1, count)
        if stats[index, cv2.CC_STAT_AREA] >= 4
        and stats[index, cv2.CC_STAT_HEIGHT] >= max(5, int(binary.shape[0] * 0.18))
        and not (
            stats[index, cv2.CC_STAT_WIDTH] >= int(binary.shape[1] * 0.80)
            and stats[index, cv2.CC_STAT_HEIGHT] >= int(binary.shape[0] * 0.70)
        )
    ]
    if not keep:
        return None
    cleaned = np.zeros_like(binary)
    for index in keep:
        cleaned[labels == index] = 255
    ys, xs = np.where(cleaned > 0)
    if xs.size == 0:
        return None
    group = cleaned[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    dst_w, dst_h = 40, 32
    scale = min((dst_w - 4) / group.shape[1], (dst_h - 4) / group.shape[0])
    resized = cv2.resize(
        group,
        (max(1, int(round(group.shape[1] * scale))),
         max(1, int(round(group.shape[0] * scale)))),
        interpolation=cv2.INTER_NEAREST,
    )
    canvas = np.zeros((dst_h, dst_w), dtype=np.uint8)
    x = (dst_w - resized.shape[1]) // 2
    y = (dst_h - resized.shape[0]) // 2
    canvas[y:y + resized.shape[0], x:x + resized.shape[1]] = resized
    return canvas


def _rank_run_glyph(
    glyph: np.ndarray | None,
    templates: dict[str, list[np.ndarray]] | None,
) -> tuple[str | None, float, float, int]:
    if glyph is None or not templates:
        return None, 0.0, 0.0, 0
    ranked = sorted(
        (
            (label, max(binary_glyph_similarity(glyph, sample) for sample in samples))
            for label, samples in templates.items()
            if samples
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    if not ranked:
        return None, 0.0, 0.0, 0
    label, score = ranked[0]
    second = ranked[1][1] if len(ranked) > 1 else 0.0
    return label, score, score - second, len(ranked)


def _basic_equipment_quad(image: Image.Image, region: dict) -> Image.Image | None:
    return warp_quad_region(
        image,
        region,
        output_size=tuple(region.get("output_size", (32, 44))),
    )


def _basic_equipment_level_cells(
    image: Image.Image,
    region: dict,
) -> tuple[Image.Image, Image.Image] | None:
    crop = _basic_equipment_quad(image, region)
    if crop is None:
        return None
    midpoint = crop.width // 2
    center_trim = max(0, int(region.get("center_trim_pixels", 0) or 0))
    center_trim = min(center_trim, max(0, midpoint - 1))
    return (
        crop.crop((0, 0, midpoint - center_trim, crop.height)),
        crop.crop((midpoint + center_trim, 0, crop.width, crop.height)),
    )


def read_basic_equipment_level_result(
    image: Image.Image,
    region: dict,
    templates: dict[int, dict[str, list[np.ndarray]]] | None,
) -> RecognitionResult:
    cells = _basic_equipment_level_cells(image, region)
    if cells is None:
        return RecognitionResult.fallback(None, "basic_equip_level_region_missing")
    glyphs = [_normalize_basic_equipment_glyph(cell) for cell in cells]
    digits: list[str] = []
    scores: list[float] = []
    margins: list[float] = []
    for position, glyph in enumerate(glyphs, start=1):
        label, score, margin, label_count = _rank_run_glyph(
            glyph,
            (templates or {}).get(position),
        )
        # A run-local classifier needs competing labels before it may decide.
        # Outlined 2/8 glyphs are intentionally similar; exact card-position
        # samples still separate them, but with a much smaller margin.
        if label is None or label_count < 2 or score < 0.74 or margin < 0.015:
            if position == 2 and glyph is None and digits:
                break
            return RecognitionResult.fallback(None, f"basic_equip_level_digit{position}_uncertain")
        digits.append(label)
        scores.append(score)
        margins.append(margin)
    if not digits:
        return RecognitionResult.fallback(None, "basic_equip_level_missing")
    value = int("".join(digits))
    valid = 1 <= value <= 70
    detail = ",".join(
        f"pos{position}={digit}:{score:.3f}/{margin:.3f}"
        for position, (digit, score, margin) in enumerate(zip(digits, scores, margins), start=1)
    )
    return RecognitionResult(
        value=value if valid else None,
        score=min(scores),
        source=RecogSource.COMBINED,
        uncertain=not valid,
        label=f"basic_equip_level:{value}:{detail}",
    )


def learn_basic_equipment_level(
    image: Image.Image,
    region: dict,
    value: int,
    templates: dict[int, dict[str, list[np.ndarray]]],
) -> None:
    cells = _basic_equipment_level_cells(image, region)
    if cells is None:
        return
    digits = str(value)
    for position, (digit, cell) in enumerate(zip(digits, cells), start=1):
        glyph = _normalize_basic_equipment_glyph(cell)
        if glyph is None:
            continue
        samples = templates.setdefault(position, {}).setdefault(digit, [])
        samples.append(glyph)
        del samples[:-4]
        _log.debug(
            "basic_equip_level_calibration: position=%d digit=%s variants=%d",
            position, digit, len(samples),
        )

def _crop_equipment_icon_inner(image: Image.Image, crop_ratio: dict) -> Image.Image:
    width, height = image.size
    left = float(crop_ratio.get("left", 0.15))
    right = float(crop_ratio.get("right", 0.15))
    top = float(crop_ratio.get("top", 0.20))
    bottom = float(crop_ratio.get("bottom", 0.30))
    x1 = max(0, min(width - 1, int(round(width * left))))
    x2 = max(x1 + 1, min(width, int(round(width * (1.0 - right)))))
    y1 = max(0, min(height - 1, int(round(height * top))))
    y2 = max(y1 + 1, min(height, int(round(height * (1.0 - bottom)))))
    return image.crop((x1, y1, x2, y2))


def _template_asset_path(value: str | None, fallback: str) -> Path:
    raw = str(value or fallback).strip() or fallback
    path = Path(raw)
    if path.is_absolute():
        return path
    return TEMPLATE_DIR / path


@lru_cache(maxsize=256)
def _basic_equipment_icon_template(
    equipment_family: str,
    tier: int,
    output_width: int,
    output_height: int,
    crop_left: float,
    crop_right: float,
    crop_top: float,
    crop_bottom: float,
    icon_width_ratio: float = 1.0,
    icon_height_ratio: float = 1.0,
    icon_offset_x_ratio: float = 0.0,
    icon_offset_y_ratio: float = 0.0,
    background_relpath: str = "icons/temp/square.png",
) -> np.ndarray | None:
    icon_path = TEMPLATE_DIR / "icons" / "equipment" / f"Equipment_Icon_{equipment_family}_Tier{tier}.png"
    background_path = _template_asset_path(background_relpath, "icons/temp/square.png")
    if not icon_path.exists() or not background_path.exists():
        return None
    source_icon = Image.open(icon_path).convert("RGBA")
    precise_geometry = (
        icon_width_ratio != 1.0 or icon_height_ratio != 1.0
        or icon_offset_x_ratio != 0.0 or icon_offset_y_ratio != 0.0
    )
    if not precise_geometry:
        background = Image.open(background_path).convert("RGBA").resize(
            source_icon.size, Image.Resampling.LANCZOS,
        )
        composite = Image.alpha_composite(background, source_icon)
    else:
        full_width = max(
            1,
            int(round(output_width / max(0.01, 1.0 - crop_left - crop_right))),
        )
        full_height = max(
            1,
            int(round(output_height / max(0.01, 1.0 - crop_top - crop_bottom))),
        )
        icon = source_icon.resize(
            (max(1, round(full_width * icon_width_ratio)),
             max(1, round(full_height * icon_height_ratio))),
            Image.Resampling.LANCZOS,
        )
        background = Image.open(background_path).convert("RGBA").resize(
            (full_width, full_height), Image.Resampling.LANCZOS,
        )
        composite = background.copy()
        composite.alpha_composite(
            icon,
            dest=(round(full_width * icon_offset_x_ratio),
                  round(full_height * icon_offset_y_ratio)),
        )
    inner = _crop_equipment_icon_inner(
        composite,
        {
            "left": crop_left,
            "right": crop_right,
            "top": crop_top,
            "bottom": crop_bottom,
        },
    ).convert("RGB")
    return np.asarray(
        inner.resize((output_width, output_height), Image.Resampling.LANCZOS)
    ).copy()


_BASIC_EQUIPMENT_LEVEL_RANGES = {
    1: range(1, 11), 2: range(11, 21), 3: range(21, 31), 4: range(31, 41),
    5: range(41, 46), 6: range(46, 51), 7: range(51, 56), 8: range(56, 61),
    9: range(61, 66), 10: range(66, 71),
}
_BASIC_EQUIPMENT_CARD_X = {1: 1356, 2: 1542, 3: 1728}
_BASIC_EQUIPMENT_TEXT_X = {1: 1419, 2: 1605, 3: 1791}


def _basic_equipment_font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    font_dir = TEMPLATE_DIR.parent / "gui" / "font"
    candidates = [
        font_dir / "GyeonggiTitle_Bold.ttf",
        *sorted(font_dir.glob("*Bold.ttf")),
        Path("C:/Windows/Fonts/arialbd.ttf"),
    ]
    for path in candidates:
        try:
            if path.exists():
                return ImageFont.truetype(str(path), 28)
        except OSError:
            continue
    return ImageFont.load_default()


def _render_basic_equipment_level_text(value: int) -> Image.Image:
    canvas = Image.new("RGBA", (179, 63), (0, 0, 0, 0))
    font = _basic_equipment_font()
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (2, 2), f" {value}", font=font, fill="#FFFFFF",
        stroke_width=1, stroke_fill="#505878",
    )
    shear = -0.25
    shift = abs(shear) * canvas.height
    expanded = Image.new("RGBA", (canvas.width + round(shift), canvas.height), (0, 0, 0, 0))
    expanded.alpha_composite(canvas)
    return expanded.transform(
        expanded.size,
        Image.Transform.AFFINE,
        (1, -shear, 0, 0, 1, 0),
        resample=Image.Resampling.BICUBIC,
    ).crop((0, 0, canvas.width, canvas.height))


def _basic_equipment_template_card(
    equipment_family: str,
    tier: int,
    *,
    background_relpath: str,
    icon_width_ratio: float,
    icon_height_ratio: float,
    icon_offset_x_ratio: float,
    icon_offset_y_ratio: float,
) -> Image.Image | None:
    icon_path = (
        TEMPLATE_DIR / "icons" / "equipment"
        / f"Equipment_Icon_{equipment_family}_Tier{tier}.png"
    )
    background_path = _template_asset_path(background_relpath, "icons/temp/square.png")
    if not icon_path.exists() or not background_path.exists():
        return None
    card_width, card_height = 200, 160
    card = Image.open(background_path).convert("RGBA").resize(
        (card_width, card_height), Image.Resampling.LANCZOS,
    )
    icon = Image.open(icon_path).convert("RGBA").resize(
        (
            max(1, round(card_width * icon_width_ratio)),
            max(1, round(card_height * icon_height_ratio)),
        ),
        Image.Resampling.LANCZOS,
    )
    card.alpha_composite(
        icon,
        dest=(
            round(card_width * icon_offset_x_ratio),
            round(card_height * icon_offset_y_ratio),
        ),
    )
    return card


@lru_cache(maxsize=768)
def _basic_equipment_generated_level_crop(
    slot: int,
    equipment_family: str,
    tier: int,
    level: int,
    points: tuple[float, ...],
    output_width: int,
    output_height: int,
    background_relpath: str,
    icon_width_ratio: float,
    icon_height_ratio: float,
    icon_offset_x_ratio: float,
    icon_offset_y_ratio: float,
) -> np.ndarray | None:
    if slot not in _BASIC_EQUIPMENT_CARD_X:
        return None
    card = _basic_equipment_template_card(
        equipment_family,
        tier,
        background_relpath=background_relpath,
        icon_width_ratio=icon_width_ratio,
        icon_height_ratio=icon_height_ratio,
        icon_offset_x_ratio=icon_offset_x_ratio,
        icon_offset_y_ratio=icon_offset_y_ratio,
    )
    if card is None:
        return None
    card.alpha_composite(
        _render_basic_equipment_level_text(level),
        dest=(_BASIC_EQUIPMENT_TEXT_X[slot] - _BASIC_EQUIPMENT_CARD_X[slot], 6),
    )
    reference = Image.new("RGB", (2560, 1440), "black")
    reference.paste(card.convert("RGB"), (_BASIC_EQUIPMENT_CARD_X[slot], 1114))
    local_region = {
        "points_ratio": [
            {"x": points[index], "y": points[index + 1]}
            for index in range(0, len(points), 2)
        ],
        "output_size": [output_width, output_height],
    }
    crop = warp_quad_region(reference, local_region, output_size=(output_width, output_height))
    return np.asarray(crop.convert("RGB")).copy() if crop is not None else None


def _split_basic_equipment_level_rgb(
    crop: Image.Image | np.ndarray,
    region: dict,
) -> tuple[np.ndarray, np.ndarray] | None:
    if isinstance(crop, np.ndarray):
        array = crop
    else:
        array = np.asarray(crop.convert("RGB"))
    if array.size == 0 or array.shape[1] < 2:
        return None
    midpoint = array.shape[1] // 2
    center_trim = max(0, int(region.get("center_trim_pixels", 0) or 0))
    center_trim = min(center_trim, max(0, midpoint - 1))
    return (
        array[:, :midpoint - center_trim].copy(),
        array[:, midpoint + center_trim:].copy(),
    )


@lru_cache(maxsize=256)
def _basic_equipment_generated_digit_templates(
    slot: int,
    equipment_family: str,
    tier: int,
    points: tuple[float, ...],
    output_width: int,
    output_height: int,
    center_trim_pixels: int,
    background_relpath: str,
    icon_width_ratio: float,
    icon_height_ratio: float,
    icon_offset_x_ratio: float,
    icon_offset_y_ratio: float,
) -> tuple[tuple[int, str, tuple[np.ndarray, ...]], ...]:
    candidates = _BASIC_EQUIPMENT_LEVEL_RANGES.get(tier)
    if not candidates:
        return ()
    local_region = {"center_trim_pixels": center_trim_pixels}
    grouped: dict[tuple[int, str], list[np.ndarray]] = {}
    for level in candidates:
        crop = _basic_equipment_generated_level_crop(
            slot,
            equipment_family,
            tier,
            int(level),
            points,
            output_width,
            output_height,
            background_relpath,
            icon_width_ratio,
            icon_height_ratio,
            icon_offset_x_ratio,
            icon_offset_y_ratio,
        )
        cells = _split_basic_equipment_level_rgb(crop, local_region) if crop is not None else None
        if cells is None:
            continue
        text = str(int(level))
        labels = (text, "blank") if len(text) == 1 else (text[-2], text[-1])
        for position, label, cell in ((1, labels[0], cells[0]), (2, labels[1], cells[1])):
            grouped.setdefault((position, label), []).append(cell)
    return tuple(
        (position, label, tuple(samples))
        for (position, label), samples in sorted(grouped.items())
    )


def _generated_digit_gray_plane(image: np.ndarray) -> np.ndarray:
    if image.ndim == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
    else:
        gray = image.astype(np.uint8, copy=False)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    low, high = np.percentile(gray, (2.0, 98.0))
    if high - low < 1.0:
        return np.zeros_like(gray, dtype=np.uint8)
    normalized = (gray.astype(np.float32) - float(low)) * (255.0 / float(high - low))
    return np.clip(normalized, 0, 255).astype(np.uint8)


def _generated_digit_edge_plane(gray: np.ndarray) -> np.ndarray:
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    magnitude = cv2.magnitude(gx, gy)
    max_value = float(np.max(magnitude)) if magnitude.size else 0.0
    if max_value <= 0.0:
        return np.zeros_like(gray, dtype=np.uint8)
    return np.clip(magnitude * (255.0 / max_value), 0, 255).astype(np.uint8)


def _generated_digit_plane_similarity(screen: np.ndarray, candidate: np.ndarray) -> float:
    screen_f = screen.astype(np.float32)
    candidate_f = candidate.astype(np.float32)
    diff_score = 1.0 - float(np.mean(np.abs(screen_f - candidate_f)) / 255.0)
    diff_score = max(0.0, min(1.0, diff_score))
    score_map = cv2.matchTemplate(screen, candidate, cv2.TM_CCOEFF_NORMED)
    corr = float(score_map[0, 0]) if score_map.size else 0.0
    if not np.isfinite(corr):
        corr = 0.0
    corr = max(0.0, min(1.0, corr))
    return 0.65 * corr + 0.35 * diff_score


def _generated_digit_rgb_similarity(screen: np.ndarray, candidate: np.ndarray) -> float:
    if candidate.shape[:2] != screen.shape[:2]:
        candidate = cv2.resize(
            candidate,
            (screen.shape[1], screen.shape[0]),
            interpolation=cv2.INTER_AREA,
        )
    screen_f = screen.astype(np.float32)
    candidate_f = candidate.astype(np.float32)
    diff_score = 1.0 - float(np.mean(np.abs(screen_f - candidate_f)) / 255.0)
    diff_score = max(0.0, min(1.0, diff_score))
    score_map = cv2.matchTemplate(screen, candidate, cv2.TM_CCOEFF_NORMED)
    corr = float(score_map[0, 0]) if score_map.size else 0.0
    if not np.isfinite(corr):
        corr = 0.0
    corr = max(0.0, min(1.0, corr))
    return 0.55 * corr + 0.45 * diff_score

def _generated_digit_similarity(screen: np.ndarray, candidate: np.ndarray) -> float:
    if candidate.shape[:2] != screen.shape[:2]:
        candidate = cv2.resize(
            candidate,
            (screen.shape[1], screen.shape[0]),
            interpolation=cv2.INTER_AREA,
        )
    screen_gray = _generated_digit_gray_plane(screen)
    candidate_gray = _generated_digit_gray_plane(candidate)
    gray_score = _generated_digit_plane_similarity(screen_gray, candidate_gray)
    screen_edge = _generated_digit_edge_plane(screen_gray)
    candidate_edge = _generated_digit_edge_plane(candidate_gray)
    edge_score = _generated_digit_plane_similarity(screen_edge, candidate_edge)
    return 0.70 * gray_score + 0.30 * edge_score


def _rank_generated_digit_cell(
    screen: np.ndarray,
    templates: dict[str, tuple[np.ndarray, ...]],
    *,
    ignore_color: bool = True,
) -> tuple[str | None, float, float, int]:
    if screen.size == 0 or not templates:
        return None, 0.0, 0.0, 0
    ranked: list[tuple[str, float]] = []
    similarity = _generated_digit_similarity if ignore_color else _generated_digit_rgb_similarity
    for label, samples in templates.items():
        scores = [similarity(screen, sample) for sample in samples]
        if scores:
            ranked.append((label, max(scores)))
    ranked.sort(key=lambda item: item[1], reverse=True)
    if not ranked:
        return None, 0.0, 0.0, 0
    label, score = ranked[0]
    second = ranked[1][1] if len(ranked) > 1 else 0.0
    return label, score, score - second, len(ranked)

def read_basic_equipment_generated_level_result(
    image: Image.Image,
    region: dict,
    slot: int,
    equipment_family: str | None,
    tier: str | None,
    icon_region: dict | None = None,
) -> RecognitionResult:
    if not equipment_family or not tier or not tier.startswith("T"):
        return RecognitionResult.fallback(None, "basic_equip_generated_context_missing")
    try:
        tier_number = int(tier[1:])
    except ValueError:
        return RecognitionResult.fallback(None, "basic_equip_generated_tier_invalid")
    candidates = _BASIC_EQUIPMENT_LEVEL_RANGES.get(tier_number)
    points_rows = region.get("points_ratio") or []
    if (
        candidates is None
        or len(points_rows) != 4
        or any("x" not in row or "y" not in row for row in points_rows)
    ):
        return RecognitionResult.fallback(None, "basic_equip_generated_region_missing")
    screen_crop = _basic_equipment_quad(image, region)
    if screen_crop is None:
        return RecognitionResult.fallback(None, "basic_equip_generated_crop_missing")
    screen_cells = _split_basic_equipment_level_rgb(screen_crop, region)
    if screen_cells is None:
        return RecognitionResult.fallback(None, "basic_equip_generated_cells_missing")
    points = tuple(
        coordinate
        for row in points_rows
        for coordinate in (float(row["x"]), float(row["y"]))
    )
    icon_region = icon_region or {}
    geometry = icon_region.get("template_geometry") or {}
    template_rows = _basic_equipment_generated_digit_templates(
        slot,
        equipment_family,
        tier_number,
        points,
        screen_crop.width,
        screen_crop.height,
        int(region.get("center_trim_pixels", 0) or 0),
        str(icon_region.get("template_background") or "icons/temp/square.png"),
        float(geometry.get("icon_width_ratio", 0.995)),
        float(geometry.get("icon_height_ratio", 0.98125)),
        float(geometry.get("icon_offset_x_ratio", 0.0)),
        float(geometry.get("icon_offset_y_ratio", 0.0)),
    )
    if not template_rows:
        return RecognitionResult.fallback(None, "basic_equip_generated_templates_missing")
    templates: dict[int, dict[str, tuple[np.ndarray, ...]]] = {1: {}, 2: {}}
    for position, label, samples in template_rows:
        templates.setdefault(position, {})[label] = samples
    labels: list[str] = []
    scores: list[float] = []
    details: list[str] = []
    for position, screen_cell in enumerate(screen_cells, start=1):
        label, score, margin, label_count = _rank_generated_digit_cell(
            screen_cell,
            templates.get(position, {}),
        )
        if label is None:
            return RecognitionResult.fallback(None, f"basic_equip_generated_digit{position}_missing")
        if score < 0.60 or (label_count > 1 and margin < 0.025):
            return RecognitionResult(
                value=None,
                score=score,
                source=RecogSource.TEMPLATE_RESIZED,
                uncertain=True,
                label=(
                    f"basic_equip_generated_digit{position}_uncertain:"
                    f"{label}:score={score:.3f}:margin={margin:.3f}"
                ),
            )
        labels.append(label)
        scores.append(score)
        second = max(0.0, score - margin)
        details.append(f"pos{position}={label}:{score:.3f}/{margin:.3f}/second={second:.3f}")
    digit_text = "".join(label for label in labels if label != "blank")
    if not digit_text:
        return RecognitionResult.fallback(None, "basic_equip_generated_blank")
    try:
        value = int(digit_text)
    except ValueError:
        return RecognitionResult.fallback(None, "basic_equip_generated_value_invalid")
    valid = value in set(candidates)
    score = min(scores) if scores else 0.0
    return RecognitionResult(
        value=value if valid else None,
        score=score,
        source=RecogSource.TEMPLATE_RESIZED,
        uncertain=not valid,
        label=f"basic_equip_generated:{value}:mode=shape,{','.join(details)}",
    )
@lru_cache(maxsize=8)
def _basic_favorite_templates(width: int, height: int) -> tuple[tuple[str, np.ndarray], ...]:
    directory = TEMPLATE_DIR / "equip4_basic"
    loaded: list[tuple[str, np.ndarray]] = []
    for tier in ("T1", "T2"):
        path = directory / f"equip4_{tier}.png"
        if not path.exists():
            continue
        template = Image.open(path).convert("RGB").resize(
            (width, height), Image.Resampling.LANCZOS,
        )
        loaded.append((tier, np.asarray(template).copy()))
    return tuple(loaded)

def read_basic_favorite_tier_result(
    image: Image.Image,
    region: dict,
) -> RecognitionResult:
    """Read the T1/T2 favorite-item marker directly from the basic screen."""
    from core.capture import crop_region

    crop = crop_region(image, region).convert("RGB")
    if crop.width < 2 or crop.height < 2:
        return RecognitionResult.fallback(None, "basic_favorite_region_missing")
    screen = np.asarray(crop)
    ranked: list[tuple[str, float]] = []
    for tier, template in _basic_favorite_templates(crop.width, crop.height):
        score_map = cv2.matchTemplate(screen, template, cv2.TM_CCOEFF_NORMED)
        score = float(score_map[0, 0]) if score_map.size else 0.0
        if not np.isfinite(score):
            score = 0.0
        ranked.append((tier, score))
    ranked.sort(key=lambda item: item[1], reverse=True)
    if not ranked:
        return RecognitionResult.fallback(None, "basic_favorite_templates_missing")
    label, score = ranked[0]
    second = ranked[1][1] if len(ranked) > 1 else 0.0
    margin = score - second
    uncertain = score < 0.70 or margin < 0.10
    return RecognitionResult(
        value=label if not uncertain else None,
        score=score,
        source=RecogSource.TEMPLATE_RESIZED,
        uncertain=uncertain,
        label=f"basic_favorite:{label}:margin={margin:.3f}",
    )

def read_basic_equipment_icon_tier_result(
    image: Image.Image,
    region: dict,
    equipment_family: str | None,
) -> RecognitionResult:
    if not equipment_family:
        return RecognitionResult.fallback(None, "basic_equip_icon_family_missing")
    from core.capture import crop_region
    full_crop = crop_region(image, region)
    if full_crop.width < 2 or full_crop.height < 2:
        return RecognitionResult.fallback(None, "basic_equip_icon_region_missing")
    crop_ratio = region.get("crop_ratio") or {}
    screen_crop = _crop_equipment_icon_inner(full_crop, crop_ratio).convert("RGB")
    screen = np.asarray(screen_crop)
    output_width, output_height = screen_crop.size
    geometry = region.get("template_geometry") or {}
    ranked: list[tuple[str, float]] = []
    for tier in range(1, 11):
        template_rgb = _basic_equipment_icon_template(
            equipment_family,
            tier,
            output_width,
            output_height,
            float(crop_ratio.get("left", 0.15)),
            float(crop_ratio.get("right", 0.15)),
            float(crop_ratio.get("top", 0.20)),
            float(crop_ratio.get("bottom", 0.30)),
            float(geometry.get("icon_width_ratio", 1.0)),
            float(geometry.get("icon_height_ratio", 1.0)),
            float(geometry.get("icon_offset_x_ratio", 0.0)),
            float(geometry.get("icon_offset_y_ratio", 0.0)),
            str(region.get("template_background") or "icons/temp/square.png"),
        )
        if template_rgb is None:
            continue
        score_map = cv2.matchTemplate(
            screen,
            template_rgb,
            cv2.TM_CCOEFF_NORMED,
        )
        texture_score = float(score_map[0, 0]) if score_map.size else 0.0
        if not np.isfinite(texture_score):
            texture_score = 0.0
        screen_mean = screen.reshape(-1, 3).mean(axis=0)
        template_mean = template_rgb.reshape(-1, 3).mean(axis=0)
        color_distance = float(np.linalg.norm(screen_mean - template_mean))
        color_score = max(0.0, 1.0 - color_distance / 220.0)
        score = 0.85 * max(0.0, texture_score) + 0.15 * color_score
        ranked.append((f"T{tier}", score))
    ranked.sort(key=lambda item: item[1], reverse=True)
    if not ranked:
        return RecognitionResult.fallback(None, "basic_equip_icon_templates_missing")
    label, score = ranked[0]
    second = ranked[1][1] if len(ranked) > 1 else 0.0
    margin = score - second
    uncertain = score < 0.35 or margin < 0.08
    return RecognitionResult(
        value=label,
        score=score,
        source=RecogSource.TEMPLATE_RESIZED,
        uncertain=uncertain,
        label=f"basic_equip_icon:{equipment_family}:{label}:margin={margin:.3f}",
    )


@lru_cache(maxsize=1)
def _basic_combat_stat_digit_templates() -> dict[str, list[np.ndarray]]:
    directory = TEMPLATE_DIR / "basic_combat_stat_digits"
    templates: dict[str, list[np.ndarray]] = {}
    for digit in range(10):
        samples: list[np.ndarray] = []
        for path in sorted((directory / str(digit)).glob("*.png")):
            image = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
            if image is not None:
                samples.append(image)
        if samples:
            templates[str(digit)] = samples
    return templates


@lru_cache(maxsize=1)
def _basic_combat_stat_position_templates() -> dict[tuple[str, int], dict[str, list[np.ndarray]]]:
    """Index samples by (stat field, digit position) encoded in each filename."""
    directory = TEMPLATE_DIR / "basic_combat_stat_digits"
    indexed: dict[tuple[str, int], dict[str, list[np.ndarray]]] = {}
    for digit in range(10):
        for path in sorted((directory / str(digit)).glob("*.png")):
            parts = path.stem.rsplit("_", 2)
            if len(parts) != 3 or parts[1] not in {"hp", "atk", "def", "heal"}:
                continue
            try:
                position = int(parts[2])
            except ValueError:
                continue
            image = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
            if image is not None:
                indexed.setdefault((parts[1], position), {}).setdefault(str(digit), []).append(image)
    return indexed


def _basic_combat_cell_state(crop: Image.Image) -> tuple[str, float]:
    """Return DIGIT, EMPTY, or LV before digit template matching."""
    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    badge_blue = (
        (blue - red > 25)
        & (blue - green > 5)
        & (blue >= 70)
        & (blue <= 190)
        & (red < 150)
    )
    blue_ratio = float(badge_blue.mean())
    if blue_ratio >= 0.08:
        return "LV", blue_ratio
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    neutral_dark = (maximum < 180) & (maximum.astype(np.int16) - minimum.astype(np.int16) < 90)
    dark_ratio = float(neutral_dark.mean())
    if dark_ratio <= 0.02:
        return "EMPTY", 1.0 - dark_ratio
    return "DIGIT", dark_ratio


def _normalize_basic_combat_stat_digit(crop: Image.Image) -> np.ndarray | None:
    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    if rgb.size == 0:
        return None
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    chroma = maximum.astype(np.int16) - minimum.astype(np.int16)
    binary = ((maximum < 180) & (chroma < 90)).astype(np.uint8) * 255
    return normalize_binary_glyph(binary, output_size=(20, 28), padding=2)


def read_basic_combat_stat_result(image: Image.Image, region: dict) -> RecognitionResult:
    templates = _basic_combat_stat_digit_templates()
    position_templates = _basic_combat_stat_position_templates()
    template_group = str(region.get("template_group", ""))
    if not templates:
        return RecognitionResult.fallback(None, "basic_combat_digit_templates_missing")
    width, height = image.size
    x0 = float(region["x1"])
    y0 = float(region["y1"])
    cell_width = float(region["cell_width"])
    cell_height = float(region["cell_height"])
    cells = region.get("cells") if isinstance(region.get("cells"), list) else None
    max_digits = len(cells) if cells else max(1, int(region.get("max_digits", 6)))
    min_digits = max(1, int(region.get("min_digits", 1)))
    digits: list[str] = []
    scores: list[float] = []
    margins: list[float] = []
    terminal_state = "LIMIT"
    terminal_position = max_digits + 1
    for position in range(max_digits):
        if cells:
            cell = cells[position]
            crop_box = (
                round(float(cell["x1"]) * width),
                round(float(cell["y1"]) * height),
                round(float(cell["x2"]) * width),
                round(float(cell["y2"]) * height),
            )
        else:
            crop_box = (
                round((x0 + position * cell_width) * width),
                round(y0 * height),
                round((x0 + (position + 1) * cell_width) * width),
                round((y0 + cell_height) * height),
            )
        crop = image.crop(crop_box)
        cell_state, _state_score = _basic_combat_cell_state(crop)
        if cell_state in {"EMPTY", "LV"}:
            terminal_state = cell_state
            terminal_position = position + 1
            break
        glyph = _normalize_basic_combat_stat_digit(crop)
        if glyph is None:
            break
        ranked: list[tuple[str, float]] = []
        local_templates = position_templates.get((template_group, position), {})
        for label, shared_samples in templates.items():
            samples = local_templates.get(label) or shared_samples
            ranked.append((label, max(binary_glyph_similarity(glyph, sample) for sample in samples)))
        ranked.sort(key=lambda item: item[1], reverse=True)
        label, score = ranked[0]
        margin = score - (ranked[1][1] if len(ranked) > 1 else 0.0)
        if score < 0.72 or margin < 0.02:
            return RecognitionResult(
                value=None,
                score=score,
                source=RecogSource.TEMPLATE_MASKED,
                uncertain=True,
                label=f"basic_combat_digit{position + 1}_uncertain:{label}:margin={margin:.3f}",
            )
        digits.append(label)
        scores.append(score)
        margins.append(margin)
    if len(digits) < min_digits:
        return RecognitionResult.fallback(None, "basic_combat_digits_missing")
    value = int("".join(digits))
    return RecognitionResult(
        value=value,
        score=min(scores),
        source=RecogSource.TEMPLATE_MASKED,
        uncertain=False,
        label=(
            f"basic_combat_stat:{value}:digits={len(digits)}:"
            f"margin={min(margins):.3f}:stop={terminal_state}@{terminal_position}"
        ),
    )


def read_basic_additional_stat_badge_result(image: Image.Image, region: dict) -> RecognitionResult:
    from core.capture import crop_region
    crop = np.asarray(crop_region(image, region).convert("RGB"), dtype=np.uint8)
    if crop.size == 0:
        return RecognitionResult.fallback(None, "basic_stat_badge_region_missing")
    red = crop[:, :, 0].astype(np.int16)
    green = crop[:, :, 1].astype(np.int16)
    blue = crop[:, :, 2].astype(np.int16)
    mask = (
        (blue - red > 25)
        & (blue - green > 5)
        & (blue >= 70)
        & (blue <= 190)
        & (red < 150)
    )
    ratio = float(mask.mean())
    if ratio >= 0.08:
        return RecognitionResult(True, min(1.0, ratio / 0.15), RecogSource.COLOR_HIST, False,
                                 f"basic_stat_badge:present:ratio={ratio:.3f}")
    if ratio <= 0.02:
        return RecognitionResult(False, min(1.0, 1.0 - ratio / 0.02), RecogSource.COLOR_HIST, False,
                                 f"basic_stat_badge:absent:ratio={ratio:.3f}")
    return RecognitionResult(None, ratio, RecogSource.COLOR_HIST, True,
                             f"basic_stat_badge:uncertain:ratio={ratio:.3f}")




def _basic_additional_stat_blue_mask(crop: Image.Image) -> np.ndarray:
    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    if rgb.size == 0:
        return np.zeros((0, 0), dtype=np.uint8)
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    mask = (
        (blue - red > 25)
        & (blue - green > 5)
        & (blue >= 70)
        & (blue <= 190)
        & (red < 150)
    )
    return mask.astype(np.uint8) * 255


def _normalize_basic_additional_stat_value_text(crop: Image.Image) -> tuple[np.ndarray | None, float]:
    blue_mask = _basic_additional_stat_blue_mask(crop)
    if blue_mask.size == 0:
        return None, 0.0
    blue_ratio = float((blue_mask > 0).mean())
    ys, xs = np.where(blue_mask > 0)
    if xs.size == 0:
        return None, blue_ratio

    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    sub = rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    maximum = sub.max(axis=2)
    minimum = sub.min(axis=2)
    chroma = maximum.astype(np.int16) - minimum.astype(np.int16)
    white = ((maximum > 185) & (chroma < 70)).astype(np.uint8) * 255

    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(white)
    cleaned = np.zeros_like(white)
    for index in range(1, count):
        area = stats[index, cv2.CC_STAT_AREA]
        height = stats[index, cv2.CC_STAT_HEIGHT]
        if area >= 20 and height >= 4:
            cleaned[labels == index] = 255
    ys2, xs2 = np.where(cleaned > 0)
    if xs2.size == 0:
        return None, blue_ratio

    glyph = cleaned[ys2.min():ys2.max() + 1, xs2.min():xs2.max() + 1]
    dst_w, dst_h = 64, 32
    padding = 2
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
    return canvas, blue_ratio


@lru_cache(maxsize=1)
def _basic_additional_stat_value_templates() -> dict[str, list[np.ndarray]]:
    directory = TEMPLATE_DIR / BASIC_ADDITIONAL_STAT_VALUE_DIR
    templates: dict[str, list[np.ndarray]] = {}
    for path in sorted(directory.glob("*.png")):
        if not path.stem.isdigit():
            continue
        value = int(path.stem)
        if not 1 <= value <= 25:
            continue
        try:
            image = Image.open(path).convert("RGB")
        except OSError:
            continue
        glyph, _ratio = _normalize_basic_additional_stat_value_text(image)
        if glyph is not None:
            templates.setdefault(str(value), []).append(glyph)
    return templates


def read_basic_additional_stat_value_result(image: Image.Image, region: dict) -> RecognitionResult:
    from core.capture import crop_region
    templates = _basic_additional_stat_value_templates()
    if not templates:
        return RecognitionResult.fallback(None, "basic_additional_stat_value_templates_missing")
    crop = crop_region(image, region)
    glyph, blue_ratio = _normalize_basic_additional_stat_value_text(crop)
    if glyph is None:
        if blue_ratio <= 0.02:
            return RecognitionResult(
                0,
                min(1.0, 1.0 - blue_ratio / 0.02),
                RecogSource.COLOR_HIST,
                False,
                f"basic_additional_stat_value:absent:ratio={blue_ratio:.3f}",
            )
        return RecognitionResult(
            None,
            blue_ratio,
            RecogSource.COMBINED,
            True,
            f"basic_additional_stat_value_text_missing:ratio={blue_ratio:.3f}",
        )

    ranked: list[tuple[str, float]] = []
    for label, samples in templates.items():
        ranked.append((label, max(binary_glyph_similarity(glyph, sample) for sample in samples)))
    ranked.sort(key=lambda item: item[1], reverse=True)
    if not ranked:
        return RecognitionResult.skipped("basic_additional_stat_value_no_scores")
    label, score = ranked[0]
    second = ranked[1][1] if len(ranked) > 1 else 0.0
    margin = score - second
    confident = (score >= 0.78 and margin >= 0.035) or (
        score >= 0.62 and margin >= 0.30 and blue_ratio >= 0.08
    )
    uncertain = not confident
    return RecognitionResult(
        int(label) if not uncertain else None,
        score,
        RecogSource.TEMPLATE_MASKED,
        uncertain,
        f"basic_additional_stat_value:{label}:score={score:.3f}:margin={margin:.3f}:ratio={blue_ratio:.3f}",
    )

def read_basic_equipment_tier_result(
    image: Image.Image,
    region: dict,
    templates: dict[str, list[np.ndarray]] | None,
) -> RecognitionResult:
    crop = _basic_equipment_quad(image, region)
    glyph = _normalize_basic_equipment_tier_glyph(crop) if crop is not None else None
    label, score, margin, label_count = _rank_run_glyph(glyph, templates)
    valid = label in {f"T{tier}" for tier in range(1, 11)}
    uncertain = not valid or label_count < 2 or score < 0.76 or margin < 0.07
    return RecognitionResult(
        value=label if valid else None,
        score=score,
        source=RecogSource.COMBINED,
        uncertain=uncertain,
        label=f"basic_equip_tier:{label or 'missing'}",
    )


def learn_basic_equipment_tier(
    image: Image.Image,
    region: dict,
    tier: str,
    templates: dict[str, list[np.ndarray]],
) -> None:
    crop = _basic_equipment_quad(image, region)
    glyph = _normalize_basic_equipment_tier_glyph(crop) if crop is not None else None
    if glyph is None or tier not in {f"T{value}" for value in range(1, 11)}:
        return
    samples = templates.setdefault(tier, [])
    samples.append(glyph)
    del samples[:-4]
    _log.debug(
        "basic_equip_tier_calibration: tier=%s variants=%d",
        tier, len(samples),
    )


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


def _weapon_level_cells(crop: Image.Image, center_trim: int = 0) -> tuple[np.ndarray, np.ndarray]:
    """Mask the white level text and split it into independent digit cells."""
    rgb = np.asarray(crop.convert("RGB"), dtype=np.uint8)
    if rgb.size == 0:
        empty = np.zeros((1, 1), dtype=np.uint8)
        return empty, empty

    # Digit fill is nearly neutral white; the panel and weapon art are either
    # blue-tinted or darker. This mask therefore survives both bright and dark
    # weapon backgrounds without deleting the digit itself.
    chroma = rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2).astype(np.int16)
    binary = ((rgb.min(axis=2) >= 238) & (chroma <= 28)).astype(np.uint8) * 255
    midpoint = binary.shape[1] // 2
    center_trim = max(0, min(int(center_trim), max(0, midpoint - 1)))
    return binary[:, :midpoint - center_trim], binary[:, midpoint + center_trim:]


def _read_weapon_level_glyph_result(
    crop: Image.Image,
    *,
    center_trim: int = 0,
) -> RecognitionResult:
    templates = _weapon_level_glyph_templates()
    if not templates:
        return RecognitionResult.fallback(None, "no_weapon_level_glyph_templates")

    cells = _weapon_level_cells(crop, center_trim=center_trim)
    if not any(cell.size and np.count_nonzero(cell) for cell in cells):
        return RecognitionResult.fallback(None, "empty_weapon_level_crop")

    digits: list[str] = []
    scores: list[float] = []
    margins: list[float] = []
    for index, cell in enumerate(cells):
        occupancy = float(np.count_nonzero(cell)) / float(max(1, cell.size))
        if index == 1 and occupancy < 0.012:
            break
        glyph = normalize_binary_glyph(cell)
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

    if not digits:
        return RecognitionResult.fallback(None, "weapon_level_glyph_missing")
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

# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# 癰??源껎닋
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

def read_star(crop: Image.Image, folder: str, max_n: int) -> int:
    """
    癰??源껎닋 ?紐꾨뻼.
    RGBA ??쀫탣?깆슦????곕솁??筌띾뜆???以???????獄쏄퀗瑗???깃맒 癰궰?遺용퓠 揶쏅벚援?
    match_masked_icon() 野껋럥以덃에?뺤춸 筌ｌ꼶?? best_match(masked=True) ??깆뒠 疫뀀뜆?.
    """
    d = TEMPLATE_DIR / folder
    cands = {
        str(i): str(d / f"star_{i}.png")
        for i in range(max_n, 0, -1)
        if (d / f"star_{i}.png").exists()
    }
    if not cands:
        _log.warning(f"{folder}: ??쀫탣????곸벉 ??1")
        return 1

    lbl, score = best_match_masked_icons(crop, cands, threshold=0.68)
    _log.debug(f"{folder} star: {lbl} ({score:.3f})")
    return int(lbl) if lbl else 1


def read_star_result(crop: Image.Image, folder: str, max_n: int) -> RecognitionResult:
    """
    read_star() ??RecognitionResult 獄쏆꼹??甕곌쑴??
    癰?揶쏆뮇??+ score + source + uncertain ???삋域???釉?
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

read_weapon_unlocked = is_weapon_equipped   # ??륁맄 ?紐낆넎


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ??덇문 ??덇볼
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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
            _log.debug(f"student_level: 1?癒?봺 ??{d1}")
            return d1
        return "unknown"
    return f"{d1}{d2}" if d1 else d2


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ??쎄텢 ??덇볼
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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
    read_skill() ??RecognitionResult 獄쏆꼹??甕곌쑴??
    score ?? uncertain ???삋域밸㈇? ??ｍ뜞 獄쏆꼹???
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


_BASIC_STUDENT_LEVEL_TEMPLATE_SIZE = (2560, 1440)
_BASIC_STUDENT_LEVEL_TEXT_LAYERS = (
    {"x": 108, "y": 1194, "width": 180, "height": 60, "shear": -0.2},
    {"x": 126, "y": 1194, "width": 180, "height": 60, "shear": -0.2},
)
_BASIC_STUDENT_LEVEL_FILL = "#DDEAFF"
_BASIC_STUDENT_LEVEL_STROKE = "#6C7288"
_BASIC_STUDENT_LEVEL_STROKE_WIDTH = 2
_BASIC_STUDENT_LEVEL_FONT_SIZE = 35
_BASIC_STUDENT_LEVEL_CANDIDATES = tuple(range(1, 91))


@lru_cache(maxsize=1)
def _basic_student_level_font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    font_dir = TEMPLATE_DIR.parent / "gui" / "font"
    candidates = [
        *sorted(font_dir.glob("*Medium.ttf")),
        *sorted(font_dir.glob("*Bold.ttf")),
        Path(r"C:\Windows\Fonts\arialbd.ttf"),
        Path(r"C:\Windows\Fonts\arial.ttf"),
    ]
    for path in candidates:
        try:
            if path.exists():
                return ImageFont.truetype(str(path), _BASIC_STUDENT_LEVEL_FONT_SIZE)
        except OSError:
            continue
    return ImageFont.load_default()


def _render_basic_student_level_digit_text(label: str) -> Image.Image:
    layer = _BASIC_STUDENT_LEVEL_TEXT_LAYERS[0]
    canvas = Image.new("RGBA", (int(layer["width"]), int(layer["height"])), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (0, 0),
        f" {label}",
        font=_basic_student_level_font(),
        fill=_BASIC_STUDENT_LEVEL_FILL,
        stroke_width=_BASIC_STUDENT_LEVEL_STROKE_WIDTH,
        stroke_fill=_BASIC_STUDENT_LEVEL_STROKE,
    )
    shear = float(layer["shear"])
    if shear == 0.0:
        return canvas
    shift = abs(shear) * canvas.height
    expanded = Image.new("RGBA", (canvas.width + round(shift), canvas.height), (0, 0, 0, 0))
    expanded.alpha_composite(canvas)
    return expanded.transform(
        expanded.size,
        Image.Transform.AFFINE,
        (1, -shear, 0, 0, 1, 0),
        resample=Image.Resampling.BICUBIC,
    ).crop((0, 0, canvas.width, canvas.height))


@lru_cache(maxsize=128)
def _basic_student_generated_level_crop(
    level: int,
    points: tuple[float, ...],
    output_width: int,
    output_height: int,
) -> np.ndarray | None:
    if level not in _BASIC_STUDENT_LEVEL_CANDIDATES:
        return None
    reference = Image.new("RGBA", _BASIC_STUDENT_LEVEL_TEMPLATE_SIZE, (0, 0, 0, 255))
    for index, label in enumerate(str(level)):
        if index >= len(_BASIC_STUDENT_LEVEL_TEXT_LAYERS):
            break
        layer = _BASIC_STUDENT_LEVEL_TEXT_LAYERS[index]
        reference.alpha_composite(
            _render_basic_student_level_digit_text(label),
            dest=(int(layer["x"]), int(layer["y"])),
        )
    reference = reference.convert("RGB")
    local_region = {
        "points_ratio": [
            {"x": points[index], "y": points[index + 1]}
            for index in range(0, len(points), 2)
        ],
        "output_size": [output_width, output_height],
    }
    crop = warp_quad_region(reference, local_region, output_size=(output_width, output_height))
    return np.asarray(crop.convert("RGB")).copy() if crop is not None else None


def _split_basic_student_level_rgb(
    crop: Image.Image | np.ndarray,
    region: dict,
) -> tuple[np.ndarray, np.ndarray] | None:
    if isinstance(crop, np.ndarray):
        array = crop
    else:
        array = np.asarray(crop.convert("RGB"))
    if array.size == 0 or array.shape[1] < 2:
        return None
    midpoint = array.shape[1] // 2
    center_trim = max(0, int(region.get("center_trim_pixels", 0) or 0))
    center_trim = min(center_trim, max(0, midpoint - 1))
    return (
        array[:, :midpoint - center_trim].copy(),
        array[:, midpoint + center_trim:].copy(),
    )


@lru_cache(maxsize=16)
def _basic_student_generated_digit_templates(
    points: tuple[float, ...],
    output_width: int,
    output_height: int,
    center_trim_pixels: int,
) -> tuple[tuple[int, str, tuple[np.ndarray, ...]], ...]:
    local_region = {"center_trim_pixels": center_trim_pixels}
    grouped: dict[tuple[int, str], list[np.ndarray]] = {}
    for level in _BASIC_STUDENT_LEVEL_CANDIDATES:
        crop = _basic_student_generated_level_crop(level, points, output_width, output_height)
        cells = _split_basic_student_level_rgb(crop, local_region) if crop is not None else None
        if cells is None:
            continue
        text = str(level)
        labels = (text, "blank") if len(text) == 1 else (text[0], text[1])
        for position, label, cell in ((1, labels[0], cells[0]), (2, labels[1], cells[1])):
            grouped.setdefault((position, label), []).append(cell)
    return tuple(
        (position, label, tuple(samples))
        for (position, label), samples in sorted(grouped.items())
    )


def read_basic_student_generated_level_result(image: Image.Image, region: dict) -> RecognitionResult:
    points_rows = region.get("points_ratio") or []
    if (
        len(points_rows) != 4
        or any("x" not in row or "y" not in row for row in points_rows)
    ):
        return RecognitionResult.fallback(None, "basic_level_generated_region_missing")
    output_size = tuple(region.get("output_size", (58, 46)))
    screen_crop = warp_quad_region(image, region, output_size=output_size)
    if screen_crop is None:
        return RecognitionResult.fallback(None, "basic_level_generated_crop_missing")
    screen_cells = _split_basic_student_level_rgb(screen_crop, region)
    if screen_cells is None:
        return RecognitionResult.fallback(None, "basic_level_generated_cells_missing")
    points = tuple(
        coordinate
        for row in points_rows
        for coordinate in (float(row["x"]), float(row["y"]))
    )
    template_rows = _basic_student_generated_digit_templates(
        points,
        screen_crop.width,
        screen_crop.height,
        int(region.get("center_trim_pixels", 0) or 0),
    )
    if not template_rows:
        return RecognitionResult.fallback(None, "basic_level_generated_templates_missing")
    templates: dict[int, dict[str, tuple[np.ndarray, ...]]] = {1: {}, 2: {}}
    for position, label, samples in template_rows:
        templates.setdefault(position, {})[label] = samples

    labels: list[str] = []
    scores: list[float] = []
    margins: list[float] = []
    details: list[str] = []
    for position, screen_cell in enumerate(screen_cells, start=1):
        label, score, margin, label_count = _rank_generated_digit_cell(
            screen_cell,
            templates.get(position, {}),
            ignore_color=False,
        )
        if label is None:
            return RecognitionResult.fallback(None, f"basic_level_generated_digit{position}_missing")
        labels.append(label)
        scores.append(score)
        margins.append(margin)
        second = max(0.0, score - margin)
        details.append(f"pos{position}={label}:{score:.3f}/{margin:.3f}/second={second:.3f}")
        if score < 0.60 or (label_count > 1 and margin < 0.025):
            return RecognitionResult(
                value=None,
                score=score,
                source=RecogSource.TEMPLATE_RESIZED,
                uncertain=True,
                label=(
                    f"basic_level_generated_digit{position}_uncertain:"
                    f"{label}:score={score:.3f}:margin={margin:.3f}"
                ),
            )

    digit_text = "".join(label for label in labels if label != "blank")
    if not digit_text:
        return RecognitionResult.fallback(None, "basic_level_generated_blank")
    try:
        value = int(digit_text)
    except ValueError:
        return RecognitionResult.fallback(None, "basic_level_generated_value_invalid")
    valid = value in _BASIC_STUDENT_LEVEL_CANDIDATES
    score = min(scores) if scores else 0.0
    margin = min(margins) if margins else 0.0
    uncertain = (not valid) or score < 0.60 or margin < 0.025
    _log.debug(
        "basic_level_generated: value=%s score=%.3f margin=%.3f uncertain=%s details=%s",
        value,
        score,
        margin,
        str(uncertain).lower(),
        ",".join(details),
    )
    return RecognitionResult(
        value=value if valid else None,
        score=score,
        source=RecogSource.TEMPLATE_RESIZED,
        uncertain=uncertain,
        label=f"basic_level_generated:{value}:{','.join(details)}",
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


def _basic_student_level_lv_reference_crop(
    image: Image.Image,
    region: dict,
    output_size: tuple[int, int],
) -> Image.Image | None:
    points_rows = region.get("points_ratio") or []
    if (
        len(points_rows) != 4
        or any("x" not in row or "y" not in row for row in points_rows)
    ):
        return None
    points = [(float(row["x"]), float(row["y"])) for row in points_rows]
    top_left, top_right, bottom_right, bottom_left = points
    top_vec = (top_right[0] - top_left[0], top_right[1] - top_left[1])
    bottom_vec = (bottom_right[0] - bottom_left[0], bottom_right[1] - bottom_left[1])
    left_scale = float(region.get("lv_color_left_scale", 1.55) or 1.55)
    right_gap = float(region.get("lv_color_right_gap", 0.08) or 0.08)
    sample_region = {
        "points_ratio": [
            {"x": top_left[0] - top_vec[0] * left_scale, "y": top_left[1] - top_vec[1] * left_scale},
            {"x": top_left[0] - top_vec[0] * right_gap, "y": top_left[1] - top_vec[1] * right_gap},
            {"x": bottom_left[0] - bottom_vec[0] * right_gap, "y": bottom_left[1] - bottom_vec[1] * right_gap},
            {"x": bottom_left[0] - bottom_vec[0] * left_scale, "y": bottom_left[1] - bottom_vec[1] * left_scale},
        ],
    }
    sample_width = max(16, int(round(output_size[0] * (left_scale - right_gap))))
    return warp_quad_region(image, sample_region, output_size=(sample_width, output_size[1]))


def _basic_student_level_text_color_binary(
    image: Image.Image,
    region: dict,
    warped_digits: Image.Image,
) -> np.ndarray | None:
    reference = _basic_student_level_lv_reference_crop(image, region, warped_digits.size)
    if reference is None:
        return None
    sample_rgb = np.asarray(reference.convert("RGB"), dtype=np.uint8)
    digit_rgb = np.asarray(warped_digits.convert("RGB"), dtype=np.uint8)
    if sample_rgb.size == 0 or digit_rgb.size == 0:
        return None

    sample_gray = cv2.cvtColor(sample_rgb, cv2.COLOR_RGB2GRAY)
    sample_gray = cv2.GaussianBlur(sample_gray, (3, 3), 0)
    threshold, bright = cv2.threshold(
        sample_gray,
        0,
        255,
        cv2.THRESH_BINARY + cv2.THRESH_OTSU,
    )
    relaxed_threshold = max(0, int(round(float(threshold) - 28.0)))
    foreground = sample_gray >= relaxed_threshold
    foreground = cv2.morphologyEx(
        foreground.astype(np.uint8) * 255,
        cv2.MORPH_OPEN,
        np.ones((2, 2), dtype=np.uint8),
    ) > 0
    if int(np.count_nonzero(foreground)) < 8:
        foreground = bright > 0
    if int(np.count_nonzero(foreground)) < 8:
        return None

    sample_lab = cv2.cvtColor(sample_rgb, cv2.COLOR_RGB2LAB)
    selected = sample_lab[foreground].reshape(-1, 3).astype(np.float32)
    if selected.shape[0] < 8:
        return None
    cluster_count = min(3, selected.shape[0])
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 1.0)
    try:
        _compactness, labels, centers = cv2.kmeans(
            selected,
            cluster_count,
            None,
            criteria,
            3,
            cv2.KMEANS_PP_CENTERS,
        )
    except cv2.error:
        centers = np.asarray([np.median(selected, axis=0)], dtype=np.float32)

    background_l = float(np.median(sample_lab[~foreground, 0])) if np.any(~foreground) else 0.0
    centers = np.asarray(
        [center for center in centers if float(center[0]) >= background_l + 6.0],
        dtype=np.float32,
    )
    if centers.size == 0:
        centers = np.asarray([np.median(selected, axis=0)], dtype=np.float32)

    selected_distances = np.min(
        np.linalg.norm(selected[:, None, :] - centers[None, :, :], axis=2),
        axis=1,
    )
    max_distance = max(14.0, float(np.percentile(selected_distances, 92.0)) + 8.0)

    digit_lab = cv2.cvtColor(digit_rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    distances = np.min(
        np.linalg.norm(digit_lab[:, :, None, :] - centers[None, None, :, :], axis=3),
        axis=2,
    )
    digit_gray = cv2.cvtColor(digit_rgb, cv2.COLOR_RGB2GRAY)
    mask = (distances <= max_distance) & (digit_gray >= max(0.0, background_l - 18.0))
    mask = cv2.morphologyEx(
        mask.astype(np.uint8) * 255,
        cv2.MORPH_CLOSE,
        np.ones((2, 2), dtype=np.uint8),
    )
    ratio = float(np.count_nonzero(mask)) / float(mask.size)
    if ratio < 0.01 or ratio > 0.60:
        return None
    return mask

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


def _basic_student_level_cells(
    image: Image.Image,
    region: dict,
) -> tuple[tuple[np.ndarray, np.ndarray], bool]:
    """Rotate the whole rectified strip, resize it, then split digit cells."""
    output_size = tuple(region.get("output_size", (58, 46)))
    warped = warp_quad_region(image, region, output_size=output_size)
    if warped is None:
        empty = np.zeros((1, 1), dtype=np.uint8)
        return (empty, empty), False

    binary = otsu_binary(warped)
    midpoint = binary.shape[1] // 2
    center_trim = max(0, int(region.get("center_trim_pixels", 0) or 0))
    center_trim = min(center_trim, max(0, midpoint - 1))
    cells = (
        binary[:, :midpoint - center_trim],
        binary[:, midpoint + center_trim:],
    )
    has_second_digit = _basic_level_cell_has_digit(cells[1])
    return cells, has_second_digit


def extract_basic_student_level_glyphs(
    image: Image.Image,
    region: dict,
) -> tuple[list[np.ndarray], bool]:
    """Return normalized digit glyphs and whether the second cell is occupied."""
    cells, has_second_digit = _basic_student_level_cells(image, region)
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
    if not _basic_level_digit_templates():
        return RecognitionResult.fallback(None, "basic_level_assets_missing")

    cells, has_second_digit = _basic_student_level_cells(image, region)
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
        "basic_level_otsu: value=%s score=%.3f margin=%.3f second_occ=%.3f adaptive=%d uncertain=%s",
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
        source=RecogSource.TEMPLATE_TEXT,
        uncertain=uncertain,
        label=f"basic_level_otsu:{value}:margin={margin:.3f}",
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


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# ?貫???怨쀫선
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

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
        _log.warning(f"equip{slot}: ??쀫탣????곸벉 ??unknown")
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
        _log.debug(f"equip{slot}: {best_lbl}({best_score:.3f}) < {THRESHOLD_LOOSE} ??unknown")
        return "unknown"
    return best_lbl


# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름
# V5 ?⑤벊???紐낃숲??륁뵠??(??륁맄 ?紐낆넎)
# ?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름?癒λ름

def read_student_star_v5(crop: Image.Image) -> Optional[int]:
    """
    ??덇문 ?源놁삂 ?紐꾨뻼 (v5 ?紐낆넎 ?紐낃숲??륁뵠??.
    ????怨몄몵嚥?match_masked_icon() 野껋럥以?????
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
    """??덇문 ?源놁삂 ?紐꾨뻼 ??RecognitionResult 獄쏆꼹??"""
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
    ?얜떯由??源놁삂 ?紐꾨뻼 (v5 ?紐낆넎 ?紐낃숲??륁뵠??.
    ????怨몄몵嚥?match_masked_icon() 野껋럥以?????
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
    """?얜떯由??源놁삂 ?紐꾨뻼 ??RecognitionResult 獄쏆꼹??"""
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
        _log.warning(f"read_student_level_v5: 癰궰????쎈솭 (raw={raw!r}) ??{e}")
        return None
