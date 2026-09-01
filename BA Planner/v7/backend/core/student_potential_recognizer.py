"""Ability release levels, independent of combat numbers and stored profiles."""
from __future__ import annotations

from collections import Counter
from PIL import Image

from core.student_scan_recognizer import Observation, ratio_crop, _normalize_mask, _binary_iou
from core.student_weapon_recognizer import _normalized_correlation
from core.student_panel_recovery import read_panel_fields


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


def _glyph(image, *, detail=False):
    """Normalize white/yellow level text inside the blue badge, excluding MAX outside it."""
    rgb = image.convert("RGB")
    try:
        colors = Counter(p for p in rgb.getdata() if _blue(p))
    finally:
        rgb.close()
    if not colors:
        return None
    background = colors.most_common(1)[0][0]
    # MAX outlines and row dividers also satisfy the broad presence predicate.
    # Bound text to the dominant badge surface, not those disconnected accents.
    blue = _mask(image, lambda p: _blue(p) and max(abs(a-b) for a,b in zip(p,background)) <= 12)
    try:
        box = blue.getbbox()
    finally:
        blue.close()
    if box is None:
        return None
    if detail:
        # The cyan "ability" prefix is shared by all 26 labels and otherwise
        # dominates the score. Keep the complete Lv.number text on its right.
        box = (box[0]+round((box[2]-box[0])*.40), box[1], box[2], box[3])
    crop = image.crop(box)
    text = _mask(crop, lambda p: (max(p) > 185 and max(p)-min(p) < 70)
                 or (p[0] > 190 and p[1] > 185 and p[2] < 120))
    crop.close()
    # 8-connected components, with resolution-relative noise rejection.
    pixels = text.load()
    remaining = {(x, y) for y in range(text.height) for x in range(text.width) if pixels[x, y]}
    cleaned = Image.new("L", text.size)
    out = cleaned.load()
    letters = []
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
        if len(component) >= max(2, round(text.height**2*.01)) and height >= text.height*.18:
            letters.append(component)
    text.close()
    # Every bundled badge contains Lv followed by one or two digits. Remove
    # those two shared letters so they cannot outweigh a mismatching number.
    letters.sort(key=lambda component: min(x for x,_ in component))
    if len(letters) not in (3,4):
        cleaned.close()
        return None
    for component in letters[2:]:
        for point in component:
            out[point] = 255
    try:
        return _normalize_mask(cleaned, size=(64, 32))
    finally:
        cleaned.close()


class StudentPotentialRecognizer:
    def __init__(self, catalog):
        self.catalog = catalog
        self.regions = catalog.region_for_purpose("student", "student-potential-regions")
        self.templates = {}

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
                # Recognition-only resolution variants from the fixed bundled
                # reference. No observed game pixels are added to this bank.
                half = source.resize((max(1,round(source.width/2)), max(1,round(source.height/2))), Image.Resampling.LANCZOS)
                try:
                    glyphs = [_glyph(sample, detail=kind != "basic") for sample in (source, half)]
                finally:
                    half.close()
            bank[int(value)] = [glyph for glyph in glyphs if glyph is not None]
        self.templates[kind] = bank
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
        if ratio >= .08:
            return Observation("present", min(1, ratio/.15), "ok", "potential_badge_color", note)
        light = sum(min(p) >= 180 and max(p)-min(p) < 55 for p in pixels)/count
        dark = sum(max(p) < 150 for p in pixels)/count
        if ratio <= .02 and light >= .65 and dark >= .005:
            return Observation("absent", 1-ratio/.02, "ok", "potential_badge_color", note)
        return Observation(None, 0, "dependency_missing", "potential_badge_color", note+";absence unconfirmed")

    def read_value(self, crop, kind):
        glyph = _glyph(crop, detail=kind != "basic")
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
        # Dedicated, title-verified detail ROIs tolerate small-font antialiasing;
        # basic badges retain the stricter v6 separation requirement.
        minimum_margin = .035 if kind == "basic" else .025
        confirmed = score >= .78 and margin >= minimum_margin and value is not None
        return Observation(value if confirmed else None, score, "ok" if confirmed else "dependency_missing",
                           "potential_"+kind+"_template", f"label={value};margin={margin:.6f}")

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
