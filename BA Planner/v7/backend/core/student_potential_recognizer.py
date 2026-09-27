"""Ability release levels, independent of combat numbers and stored profiles."""
from __future__ import annotations

from PIL import Image, ImageFilter, ImageOps

from core.student_scan_recognizer import (
    Observation,
    ratio_crop,
    _normalize_mask,
    _binary_iou,
    _ncc_difference_score,
    _otsu_binary,
)
from core.student_weapon_recognizer import _normalized_correlation
from core.student_panel_recovery import read_panel_fields
from core import recognition_thresholds as rt


POTENTIAL_FIELDS = ("stat_hp", "stat_atk", "stat_heal")


def _blue(pixel):
    r, g, b = pixel
    return b-r > 25 and b-g > 5 and 70 <= b <= 190 and r < 150


def _mask(image, predicate):
    rgb = image.convert("RGB")
    try:
        mask = Image.new("L", rgb.size)
        mask.putdata([255 if predicate(p) else 0 for p in rgb.getdata()])
        return mask
    finally:
        rgb.close()


def _blue_ratio(image):
    rgb = image.convert("RGB")
    try:
        pixels = list(rgb.getdata())
    finally:
        rgb.close()
    return sum(_blue(pixel) for pixel in pixels) / max(1, len(pixels))


def _basic_template_pattern(image):
    """Normalize the complete v6 ``Lv.value`` pattern for 1..25 matching."""
    blue = _mask(image, _blue)
    try:
        box = blue.getbbox()
    finally:
        blue.close()
    if box is None:
        return None
    crop = image.crop(box)
    text = _mask(crop, lambda p: max(p) > 185 and max(p)-min(p) < 70)
    crop.close()

    # Preserve the v6 whole-pattern contract. In particular, retain the shared
    # ``Lv`` prefix and compare the complete rendered label against each of the
    # 25 value templates instead of classifying individual number glyphs.
    pixels = text.load()
    remaining = {(x, y) for y in range(text.height) for x in range(text.width) if pixels[x, y]}
    cleaned = Image.new("L", text.size)
    out = cleaned.load()
    while remaining:
        seed = remaining.pop()
        component = [seed]
        pending = [seed]
        while pending:
            x, y = pending.pop()
            for dx, dy in ((-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)):
                point = (x+dx, y+dy)
                if point in remaining:
                    remaining.remove(point)
                    pending.append(point)
                    component.append(point)
        height = max(y for _, y in component)-min(y for _, y in component)+1
        if len(component) >= 20 and height >= 4:
            for point in component:
                out[point] = 255
    text.close()
    try:
        return _normalize_mask(cleaned, size=(64, 32))
    finally:
        cleaned.close()


def _detail_ui_feature(image, size):
    """Reproduce the v6 full-ROI UI preprocessing with its center focus crop."""
    gray = image.convert("L").resize(size, Image.Resampling.BILINEAR)
    equalized = ImageOps.equalize(gray)
    gray.close()
    blurred = equalized.filter(ImageFilter.GaussianBlur(radius=.8))
    binary = _otsu_binary(blurred)
    blurred.close()
    equalized.close()
    box = (
        int(binary.width * .18),
        int(binary.height * .08),
        int(binary.width * .82),
        int(binary.height * .95),
    )
    focused = binary.crop(box)
    binary.close()
    return focused


def _detail_text_feature(image, size):
    """Reproduce the v6 text-only mask without splitting the numeric glyphs."""
    gray = image.convert("L").resize(size, Image.Resampling.BILINEAR)
    blurred = gray.filter(ImageFilter.GaussianBlur(radius=.8))
    mask = _otsu_binary(blurred, inverse=True)
    blurred.close()
    gray.close()
    box = mask.getbbox()
    if box is None:
        mask.close()
        return Image.new("L", (96, 30))
    padded = (
        max(0, box[0] - 2),
        max(0, box[1] - 2),
        min(mask.width, box[2] + 2),
        min(mask.height, box[3] + 2),
    )
    cropped = mask.crop(padded)
    mask.close()
    result = cropped.resize((96, 30), Image.Resampling.BILINEAR)
    cropped.close()
    return result


class StudentPotentialRecognizer:
    def __init__(self, catalog):
        self.catalog = catalog
        self.regions = catalog.region_for_purpose("student", "student-potential-regions")
        self.templates = {}
        self.detail_templates = {}

    def _bank(self, kind):
        # Readiness/target listing and locked students do not need glyph banks.
        # Defer CPU/image decoding until this particular ROI is actually read.
        if kind in self.templates:
            return self.templates[kind]
        bank = {}
        for asset in self.catalog.assets("student", "student-potential-template"):
            asset_kind, value = asset.identity.split(":")
            if asset_kind != kind:
                continue
            with Image.open(self.catalog.resolve(asset.path)) as source:
                # v6 compares one complete Lv.value pattern for every basic
                # value 1..25. Do not synthesize resized glyph variants.
                glyphs = [_basic_template_pattern(source)]
            bank[int(value)] = [glyph for glyph in glyphs if glyph is not None]
        self.templates[kind] = bank
        return bank

    def _detail_bank(self, kind):
        # The v6 detail reader compares each complete field-specific ROI against
        # the original 0..25 templates. It does not isolate or classify digits.
        if kind in self.detail_templates:
            return self.detail_templates[kind]
        bank = {}
        for asset in self.catalog.assets("student", "student-potential-template"):
            asset_kind, value = asset.identity.split(":")
            if asset_kind != kind:
                continue
            with Image.open(self.catalog.resolve(asset.path)) as source:
                size = source.size
                bank[int(value)] = (
                    size,
                    _detail_ui_feature(source, size),
                    _detail_text_feature(source, size),
                )
        self.detail_templates[kind] = bank
        return bank

    @staticmethod
    def gate(observations):
        def known(field):
            item = observations.get(field)
            return item.value if item is not None and item.confirmed and type(item.value) is int else None
        level, star = known("level"), known("student_star")
        if (level is not None and level < 90) or (star is not None and star < 5):
            return "locked"
        return "unlocked" if level is not None and star is not None else "unknown"

    @staticmethod
    def badge(crop):
        if crop is None:
            return Observation(None, 0, "dependency_missing", "potential_badge_color", "ROI missing")
        rgb = crop.convert("RGB")
        try:
            pixels = list(rgb.getdata())
        finally:
            rgb.close()
        count = max(1, len(pixels))
        ratio = sum(_blue(p) for p in pixels)/count
        note = f"blue_ratio={ratio:.6f}"
        if ratio >= rt.value("student.potential.badge.blue_present"):
            return Observation("present", min(1, ratio/.15), "ok", "potential_badge_color", note)
        light = sum(min(p) >= 180 and max(p)-min(p) < 55 for p in pixels)/count
        dark = sum(max(p) < 150 for p in pixels)/count
        absent_ratio = rt.value("student.potential.badge.blue_absent")
        if ratio <= absent_ratio and light >= rt.value("student.potential.badge.light_absent") and dark >= rt.value("student.potential.badge.dark_absent"):
            return Observation("absent", 1-ratio/absent_ratio, "ok", "potential_badge_color", note)
        return Observation(None, 0, "dependency_missing", "potential_badge_color", note+";absence unconfirmed")

    def read_value(self, crop, kind):
        if kind != "basic":
            return self._read_detail_value(crop, kind)
        glyph = _basic_template_pattern(crop)
        if glyph is None:
            return Observation(None, 0, "dependency_missing", "potential_"+kind+"_template", "level glyph missing")
        try:
            scores = sorted(((value, max((.55*_binary_iou(glyph, template)
                              + .45*max(0, min(1, (_normalized_correlation(glyph, template)+1)/2))
                             for template in variants), default=0))
                             for value, variants in self._bank(kind).items()), key=lambda x:x[1], reverse=True)
        finally:
            glyph.close()
        value, score = scores[0] if scores else (None, 0)
        margin = score-scores[1][1] if len(scores) > 1 else 0
        # Basic uses the two v6 acceptance branches for whole-pattern matching.
        minimum_margin = rt.value("student.potential.basic.margin")
        blue_ratio = _blue_ratio(crop)
        confirmed = value is not None and (
            (score >= rt.value("student.potential.basic.score") and margin >= minimum_margin)
            or (score >= rt.value("student.potential.basic_badge.score") and margin >= rt.value("student.potential.basic_badge.margin") and blue_ratio >= rt.value("student.potential.badge.blue_present"))
        )
        return Observation(value if confirmed else None, score, "ok" if confirmed else "dependency_missing",
                           "potential_"+kind+"_template",
                           f"label={value};margin={margin:.6f}"
                           + f";blue_ratio={blue_ratio:.6f}")

    def _read_detail_value(self, crop, kind):
        bank = self._detail_bank(kind)
        ui_cache = {}
        text_cache = {}
        scores = {}
        try:
            for value, (size, template_ui, template_text) in bank.items():
                if size not in ui_cache:
                    ui_cache[size] = _detail_ui_feature(crop, size)
                    text_cache[size] = _detail_text_feature(crop, size)
                ui = _ncc_difference_score(ui_cache[size], template_ui)
                text = _ncc_difference_score(text_cache[size], template_text)
                scores[value] = (.35 * ui + .65 * text, ui, text)
        finally:
            for image in (*ui_cache.values(), *text_cache.values()):
                image.close()
        ranked = sorted(scores.items(), key=lambda item: item[1][0], reverse=True)
        if not ranked:
            return Observation(None, 0, "dependency_missing", "potential_"+kind+"_template", "no templates")
        value, (score, ui, text) = ranked[0]
        margin = score-ranked[1][1][0] if len(ranked) > 1 else 0

        # Preserve v6's narrow 4 -> 0 correction for low-confidence ties.
        if value == 4 and 0 in scores:
            zero_score, zero_ui, zero_text = scores[0]
            if score < rt.value("student.potential.zero_correction.below") and zero_score >= score-rt.value("student.potential.zero_correction.tolerance") and zero_text >= text:
                value, score, ui, text = 0, zero_score, zero_ui, zero_text

        confirmed = score >= rt.value("student.potential.menu.score")
        return Observation(
            value if confirmed else None,
            score,
            "ok" if confirmed else "dependency_missing",
            "potential_"+kind+"_template",
            f"label={value};margin={margin:.6f};ui={ui:.6f};text={text:.6f}",
        )

    def recognize_basic(self, images, observations):
        gate = self.gate(observations)
        if gate != "unlocked":
            return {field: Observation(0 if gate == "locked" else None, 1 if gate == "locked" else 0,
                    "inferred" if gate == "locked" else "dependency_missing", "potential_gate", gate)
                    for field in POTENTIAL_FIELDS}
        result = {}
        for field in POTENTIAL_FIELDS:
            key = field[5:]
            crop = images.get("potential_badge_"+key)
            badge = self.badge(crop)
            # Presence evidence must not become a repository value.
            result["potential_badge_"+key] = Observation(None, badge.confidence, badge.status,
                                                         badge.source, f"{badge.value};{badge.note}")
            if badge.value == "absent":
                result[field] = Observation(0, badge.confidence, "inferred", "potential_badge_absent", badge.note)
            elif badge.value == "present":
                result[field] = self.read_value(crop, "basic")
            else:
                result[field] = Observation(None, 0, "dependency_missing", "potential_badge_unknown", badge.note)
        return result

    def recognize_menu(self, frame):
        result = {}
        for field in POTENTIAL_FIELDS:
            key = field[5:]
            crop = ratio_crop(frame, self.regions["detail"][key])
            try:
                result[field] = self.read_value(crop, key)
            finally:
                crop.close()
        return result

    def resolve(self, images, observations, menu, target, cancel):
        result = self.recognize_basic(images, observations)
        if self.gate(observations) == "unlocked" and not all(result[f].confirmed for f in POTENTIAL_FIELDS) and menu is not None:
            result.update(read_panel_fields(menu, "stat", target, cancel, result, POTENTIAL_FIELDS,
                                            self.recognize_menu, attempts=3))
            # The basic badge may remain unknown after a successful dedicated value read.
            # Retain the historical evidence without falsely requiring another review.
            for field in POTENTIAL_FIELDS:
                key = "potential_badge_"+field[5:]
                if result[field].confirmed and key in result and result[key].status == "dependency_missing":
                    old = result[key]
                    result[key] = Observation(None, old.confidence, "skipped", old.source, old.note+";resolved in detail")
        return result

    def close(self):
        for bank in self.templates.values():
            for variants in bank.values():
                for image in variants:
                    image.close()
            bank.clear()
        self.templates.clear()
        for bank in self.detail_templates.values():
            for _, ui, text in bank.values():
                ui.close()
                text.close()
            bank.clear()
        self.detail_templates.clear()
