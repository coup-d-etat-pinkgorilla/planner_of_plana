"""C5e-3 (X19): inventory quantity labels read from the grid with a calibrated glyph bank.

The count label ``x{n}`` (Gyeonggi Bold italic, ink #2D4664) sits at the bottom right of a tile. Glyphs are
learned in the session from tiles whose quantity the detail panel confirmed (user-approved samples persist,
D1): the label is split with the known text and each character becomes a sample. Reading an unknown label
tries each digit count, splits by the learned widths and classifies every digit with a small sliding search.
Synthetic glyphs (C5e-6a, D20) align the known-text split and are the lowest, evidence-only tier until a
profile passes the gate (``numeric.synth.enabled_profiles`` is empty). Counts of 10,000 or more are shown
abbreviated (``x11K``) and are never read as exact values here.

Live 1280 (two scans, samples from the first, reads of the second): at score .85 / margin .08, 13/45 tech
notes, 32/56 presents and 32/90 equipment counts were confident, all correct.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from PIL import Image

from core import recognition_thresholds as rt
from core.recognition_image_ops import ncc_unit_bilinear
from core.recognition_synth import ink_map

DIGITS = "0123456789"
# Count strip of a runtime slot crop (117x95 @720p): from x 28, y 62 to the bottom right.
STRIP = (28 / 117, 62 / 95)
MAX_SAMPLES = 6
# Glyph advance widths at 720p when no synthetic glyph is available (measured means).
DEFAULT_WIDTHS_720 = {"x": 13, **{digit: 10 for digit in DIGITS}, "1": 8, "K": 14}
NUMERIC_SYNTH_ENABLED_PROFILES: frozenset[str] = frozenset()


@dataclass(frozen=True)
class CountRead:
    value: str | None
    text: str
    score: float
    margin: float
    source: str = "count_bank_session"

    @property
    def confident(self) -> bool:
        return (self.value is not None and self.score >= rt.value("inventory.count_bank.score")
                and self.margin >= rt.value("inventory.count_bank.margin"))


def count_label(crop: Image.Image, digit_height: int) -> Image.Image | None:
    """The label's ink: the bottom-most band of strong ink rows, its rightmost run of columns (icon art and the
    equipment tier badge sit further left), cut to the digit height from the bottom."""
    width, height = crop.size
    strip = ink_map(crop.crop((round(STRIP[0] * width), round(STRIP[1] * height), width, height)))
    strong = strip.point(lambda v: 255 if v > rt.value("inventory.count_label.ink_strong") else 0)
    w, h = strong.size
    data = strong.tobytes()
    rows = [sum(1 for x in range(w) if data[y * w + x]) for y in range(h)]
    bottom = max((y for y in range(h) if rows[y] >= 2), default=None)
    if bottom is None:
        return None
    top = bottom
    while top > 0 and rows[top - 1] >= 2:
        top -= 1
    band = strip.crop((0, top, w, bottom + 1))
    # Columns use a softer ink level so thin diagonal strokes (the 7) keep the label connected; italic digit
    # pairs can be 5 px apart at 720p (live "1" "7").
    soft = band.point(lambda v: 255 if v > rt.value("inventory.count_label.ink_soft") else 0)
    data, h = soft.tobytes(), soft.height
    columns = [any(data[y * w + x] for y in range(h)) for x in range(w)]
    right = max((x for x in range(w) if columns[x]), default=None)
    if right is None:
        return None
    left, blank = right, 0
    for x in range(right, -1, -1):
        if columns[x]:
            left, blank = x, 0
        else:
            blank += 1
            if blank > 6:
                break
    ink = band.crop((left, 0, right + 1, h))
    if ink.height > digit_height:
        ink = ink.crop((0, ink.height - digit_height, ink.width, ink.height))
    box = ink.point(lambda v: 255 if v > rt.value("inventory.count_label.ink_strong") else 0).getbbox()
    return ink.crop((box[0], 0, box[2], ink.height)) if box else None


@dataclass
class CountBank:
    """Per client-size glyph samples: ``session`` (detail-confirmed) and ``user_confirmed`` tiers, plus ``seed``
    synthetic glyphs for alignment and evidence."""
    scale: float = 1.0  # window height / 720
    samples: dict[str, list[tuple[str, Image.Image]]] = field(default_factory=dict)
    # Synthetic glyphs, one variant per em candidate: the right em is not known from one label (live: the
    # first tech-notes label picked em 20, with which "8" never aligned), so alignment takes the best variant.
    seed: dict[str, list[Image.Image]] = field(default_factory=dict)

    def set_seeds(self, candidates: dict[int, dict[str, Image.Image]]) -> None:
        self.seed = {}
        for glyphs in candidates.values():
            for char, image in glyphs.items():
                self.seed.setdefault(char, []).append(image)

    @property
    def digit_height(self) -> int:
        if self.seed:
            # Per variant the tallest digit; the smallest em's height keeps art above the label out.
            variants = zip(*(self.seed[digit] for digit in DIGITS if digit in self.seed))
            return min(max(image.height for image in variant) for variant in variants)
        return round(14 * self.scale)

    def width(self, char: str) -> int:
        learned = [image.width for _tier, image in self.samples.get(char, [])]
        if learned:
            return round(sum(learned) / len(learned))
        if char in self.seed:
            return round(sum(image.width for image in self.seed[char]) / len(self.seed[char]))
        return round(DEFAULT_WIDTHS_720[char] * self.scale)

    def ready(self) -> bool:
        return all(self.samples.get(digit) for digit in DIGITS)

    def learn(self, crop: Image.Image, quantity: str, tier: str = "session") -> int:
        """Split a label whose quantity is known into per-character samples; returns how many were added."""
        if not quantity.isdigit():
            return 0
        ink = count_label(crop, self.digit_height)
        if ink is None:
            return 0
        if int(quantity) >= 10000:
            # Abbreviated ("x25K"; rounding unknown, C5-2): only the trailing K is certain, so only it is learned.
            return self._learn_last(ink, "K", tier)
        text = "x" + quantity
        widths = [self.width(char) for char in text]
        scale, x, added = ink.width / sum(widths), 0.0, 0
        if not .8 <= scale <= 1.25:
            return 0
        for char, width in zip(text, widths):
            start, x = x, x + width * scale
            references = self.seed.get(char)
            best = None
            # Without a synthetic reference there is nothing to align to: take the proportional position.
            for dx in (range(-2, 3) if references else (0,)):
                left = round(start + dx)
                if left < 0 or left + width > ink.width:
                    continue
                part = ink.crop((left, 0, left + width, ink.height))
                score = max(ncc_unit_bilinear(part, reference) for reference in references) if references else 1.0
                if best is None or score > best[0]:
                    best = (score, part)
            if best is None or best[0] < .6:
                continue
            samples = self.samples.setdefault(char, [])
            if tier == "user_confirmed":
                samples.insert(0, (tier, best[1]))
            elif len(samples) < MAX_SAMPLES:
                samples.append((tier, best[1]))
            else:
                continue
            added += 1
        return added

    def _learn_last(self, ink: Image.Image, char: str, tier: str) -> int:
        width = self.width(char)
        references = self.seed.get(char, [])
        best = None
        for dx in range(0, 3):
            right = ink.width - dx
            if right - width < 0:
                continue
            part = ink.crop((right - width, 0, right, ink.height))
            score = max((ncc_unit_bilinear(part, reference) for reference in references), default=1.0)
            if best is None or score > best[0]:
                best = (score, part)
        samples = self.samples.setdefault(char, [])
        if best is None or best[0] < .6 or len(samples) >= MAX_SAMPLES:
            return 0
        samples.append((tier, best[1]))
        return 1

    def read(self, crop: Image.Image, *, use_seed: bool = False) -> CountRead:
        """Read an unknown label: best digit-count hypothesis, each digit classified with +-2 px sliding."""
        tier = "seed" if use_seed else "session"
        glyphs = ({digit: list(self.seed[digit]) for digit in DIGITS if digit in self.seed} if use_seed
                  else {digit: [image for _tier, image in self.samples.get(digit, [])] for digit in DIGITS})
        if len([digit for digit in DIGITS if glyphs.get(digit)]) < len(DIGITS):
            return CountRead(None, "", 0.0, 0.0, f"count_bank_{tier}")
        ink = count_label(crop, self.digit_height)
        if ink is None:
            return CountRead(None, "", 0.0, 0.0, f"count_bank_{tier}")
        widths = {char: self.width(char) for char in DIGITS}
        widths["x"] = self.width("x")
        digit_width = sum(widths[digit] for digit in DIGITS) / len(DIGITS)
        # Counts of 10,000+ end in K (live: "x25K" read as 153 before K hypotheses existed).
        k_glyphs = [image for _tier, image in self.samples.get("K", [])] + list(self.seed.get("K", []))
        widths["K"] = self.width("K") if k_glyphs else 0
        best = None
        for count, abbreviated in [(n, k) for n in range(1, 6) for k in ((False, True) if k_glyphs else (False,))]:
            scale = ink.width / (widths["x"] + count * digit_width + (widths["K"] if abbreviated else 0))
            if not .8 <= scale <= 1.25:
                continue
            x = widths["x"] * scale
            chars, scores, margins = [], [], []
            for _ in range(count):
                ranked = []
                for digit in DIGITS:
                    width, score = widths[digit], 0.0
                    for dx in range(-2, 3):
                        left = round(x + dx)
                        if 0 <= left and left + width <= ink.width:
                            part = ink.crop((left, 0, left + width, ink.height))
                            score = max(score, max(ncc_unit_bilinear(part, sample) for sample in glyphs[digit]))
                    ranked.append((score, digit))
                ranked.sort(reverse=True)
                chars.append(ranked[0][1])
                scores.append(ranked[0][0])
                margins.append(ranked[0][0] - ranked[1][0])
                x += widths[ranked[0][1]] * scale
            if abbreviated:
                k_score = 0.0
                for dx in range(0, 3):
                    right = ink.width - dx
                    if right - widths["K"] >= 0:
                        part = ink.crop((right - widths["K"], 0, right, ink.height))
                        k_score = max(k_score, max(ncc_unit_bilinear(part, glyph) for glyph in k_glyphs))
                scores.append(k_score)
                chars.append("K")
            mean = sum(scores) / len(scores)
            if best is None or mean > best[0]:
                best = (mean, "".join(chars), min(scores), min(margins))
        if best is None:
            return CountRead(None, "", 0.0, 0.0, f"count_bank_{tier}")
        _mean, digits, score, margin = best
        # An abbreviated count is never an exact value; the detail panel reads it.
        exact = digits and not digits.endswith("K") and (digits[0] != "0" or digits == "0")
        return CountRead(digits if exact else None, "x" + digits, score, margin, f"count_bank_{tier}")

