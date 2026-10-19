"""O2-R native label grammar and bounded, diverse glyph sampling.

No game input, v6 dependency, template copying or resolution promotion lives here.
The caller supplies a complete label and independently verified x anchor.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from itertools import pairwise

from PIL import Image

from core import recognition_thresholds as rt
from core.recognition_image_ops import ncc_unit_bilinear


@dataclass(frozen=True)
class CountSequence:
    text: str
    score: float
    margin: float
    mean: float
    sequence_margin: float = 0.0
    prefix_score: float = 0.0


def label_components(ink, scale):
    """Undo the documented .10 italic shear and split bounded ink runs.

    The existing soft-ink threshold is reused. Empty columns delimit glyphs;
    joined runs split at a bounded ink valley. Padding preserves affine edges.
    """
    pad = max(2, round(0.1 * ink.height) + 1)
    with Image.new("L", (ink.width + 2 * pad, ink.height), 0) as padded:
        padded.paste(ink, (pad, 0))
        upright = padded.transform(
            padded.size,
            Image.Transform.AFFINE,
            (1, -0.10, 0.10 * ink.height / 2, 0, 1, 0),
            Image.Resampling.BILINEAR,
        )
    pixels = upright.tobytes()
    cutoff = rt.value("inventory.count_label.ink_soft")
    occupied = [
        any(pixels[y * upright.width + x] > cutoff for y in range(upright.height))
        for x in range(upright.width)
    ]
    runs = []
    start = last = None
    bridge = 0
    for x, has_ink in enumerate(occupied):
        if has_ink:
            if start is None:
                start = x
            elif x - last - 1 > bridge:
                runs.append((start, last + 1))
                start = x
            last = x
    if start is not None:
        runs.append((start, last + 1))
    parts = []
    for left, right in runs:
        with upright.crop((left, 0, right, upright.height)) as part:
            with part.point(lambda p: 255 if p > cutoff else 0) as binary:
                bbox = binary.getbbox()
            if bbox is not None and sum(p > cutoff for p in part.tobytes()) >= max(
                4, round(8 * scale)
            ):
                # Italic antialiasing can bridge adjacent glyphs. Split only
                # runs wider than a single measured digit, at a bounded
                # vertical-ink valley; never insert an inferred character.
                tight = part.crop(bbox)
                if tight.width <= round(12 * scale):
                    parts.append(tight)
                    continue
                count = max(2, round(tight.width / (10.5 * scale)))
                pixels = tight.tobytes()
                columns = [
                    sum(
                        pixels[y * tight.width + x] > cutoff
                        for y in range(tight.height)
                    )
                    for x in range(tight.width)
                ]
                cuts = [0]
                radius = max(1, round(2 * scale))
                for index in range(1, count):
                    center = round(tight.width * index / count)
                    options = range(
                        max(cuts[-1] + 2, center - radius),
                        min(tight.width - 1, center + radius + 1),
                    )
                    cut = min(
                        options,
                        key=lambda x: (columns[x], abs(x - center)),
                        default=center,
                    )
                    cuts.append(cut)
                cuts.append(tight.width)
                for start, end in pairwise(cuts):
                    with tight.crop((start, 0, end, tight.height)) as piece:
                        with piece.point(lambda p: 255 if p > cutoff else 0) as binary:
                            bb = binary.getbbox()
                        if bb is not None:
                            parts.append(piece.crop(bb))
                tight.close()
    upright.close()
    return parts


def classify_components(ink, samples, *, scale):
    parts = label_components(ink, scale)
    try:
        if not 2 <= len(parts) <= 6 or not samples.get("x"):
            return None
        if parts[0].height > round(10 * scale):
            return None
        prefix = max(ncc_unit_bilinear(parts[0], im) for _tier, im in samples["x"])
        if prefix < 0.6:
            return None
        chars, scores, margins = [], [], []
        for part in parts[1:]:
            ranked = sorted(
                (
                    (
                        max((phase_score(part, im) for _tier, im in refs), default=0),
                        char,
                    )
                    for char, refs in samples.items()
                    if char != "x"
                ),
                reverse=True,
            )
            if len(ranked) < 2:
                return None
            scores.append(ranked[0][0])
            margins.append(ranked[0][0] - ranked[1][0])
            chars.append(ranked[0][1])
        text = "".join(chars)
        number = text.removesuffix("K")
        if (
            not number.isdigit()
            or len(number) > 4
            or (number.startswith("0") and number != "0")
        ):
            return None
        # The nearest different string changes at least one classified glyph.
        return CountSequence(
            text,
            min(scores),
            min(margins),
            sum(scores) / len(scores),
            min(margins),
            prefix,
        )
    finally:
        for part in parts:
            part.close()


def phase_score(left, right):
    """NCC with a bounded half-native-pixel raster phase search.

    Tight ink boxes can retain opposite antialiasing fringe phases. Search only
    half a pixel in each axis, on a padded canvas; retain every competing glyph
    under the same transform budget and the existing score/margin gates.
    """
    with (
        right.resize(left.size, Image.Resampling.BILINEAR) as resized,
        Image.new("L", (left.width + 4, left.height + 4), 0) as target,
    ):
        target.paste(left, (2, 2))
        with Image.new("L", target.size, 0) as reference:
            reference.paste(resized, (2, 2))
            best = 0.0
            for dx in (-0.5, 0, 0.5):
                for dy in (-0.5, 0, 0.5):
                    with reference.transform(
                        reference.size,
                        Image.Transform.AFFINE,
                        (1, 0, dx, 0, 1, dy),
                        Image.Resampling.BILINEAR,
                    ) as shifted:
                        best = max(best, ncc_unit_bilinear(target, shifted))
            return best


def diverse_sample(samples, sample, tier, limit):
    """Keep a bounded phase/shape reservoir; exact duplicates add no information.

    Retain explicitly confirmed samples ahead of session samples. Within a tier,
    discard the most redundant pair member, preferring the sharper ink mask.
    This does not grant a provenance score bonus or change classification gates.
    """
    digest = sha256(sample.tobytes()).digest()
    if any(
        image.size == sample.size and sha256(image.tobytes()).digest() == digest
        for _, image in samples
    ):
        sample.close()
        return False
    pool = samples + [(tier, sample)]
    if len(pool) <= limit:
        samples[:] = pool
        return True
    removable = [i for i, (source, _) in enumerate(pool) if source != "user_confirmed"]
    if not removable:
        removable = list(range(len(pool)))

    def sharpness(image):
        values = image.tobytes()
        return sum(v in (0, 255) for v in values) / max(1, len(values))

    def redundancy(i):
        image = pool[i][1]
        similarity = max(
            ncc_unit_bilinear(image, other)
            for j, (_, other) in enumerate(pool)
            if j != i
        )
        return similarity, -sharpness(image), -i

    removed = max(removable, key=redundancy)
    discarded = pool.pop(removed)[1]
    discarded.close()
    samples[:] = pool
    return removed != len(samples)


def parse_sequences(ink, widths, glyphs, *, scale, k_glyphs=()):
    """Parse x -> 1..4 digits -> K/end with scale-aware bounded alignment.

    Competing distinct strings are retained for a sequence-level runner-up.
    A path must consume the full label; digits cannot silently skip a suffix.
    The glyph score and margin gates remain the caller's existing gates.
    """
    digits = "0123456789"
    radius = max(1, round(2 * scale))
    digit_width = sum(widths[d] for d in digits) / len(digits)
    candidates = {}
    for count in range(1, 5):
        for abbreviated in (False, True) if k_glyphs else (False,):
            factor = ink.width / (
                widths["x"] + count * digit_width + (widths["K"] if abbreviated else 0)
            )
            if not 0.8 <= factor <= 1.25:
                continue
            cursor = widths["x"] * factor
            text, scores, margins = [], [], []
            for _ in range(count):
                ranked = []
                for digit in digits:
                    width = widths[digit]
                    score = 0.0
                    for dx in range(-radius, radius + 1):
                        left = round(cursor + dx)
                        if 0 <= left and left + width <= ink.width:
                            with ink.crop((left, 0, left + width, ink.height)) as part:
                                score = max(
                                    score,
                                    max(
                                        ncc_unit_bilinear(part, im)
                                        for im in glyphs[digit]
                                    ),
                                )
                    ranked.append((score, digit))
                ranked.sort(reverse=True)
                scores.append(ranked[0][0])
                margins.append(ranked[0][0] - ranked[1][0])
                text.append(ranked[0][1])
                cursor += widths[text[-1]] * factor
            if abbreviated:
                score = 0.0
                for dx in range(radius + 1):
                    right = ink.width - dx
                    if right >= widths["K"]:
                        with ink.crop(
                            (right - widths["K"], 0, right, ink.height)
                        ) as part:
                            score = max(
                                score,
                                max(ncc_unit_bilinear(part, im) for im in k_glyphs),
                            )
                scores.append(score)
                text.append("K")
                cursor += widths["K"] * factor
            label = "".join(text)
            if label.startswith("0") and label not in ("0",):
                continue
            if abs(cursor - ink.width) > radius + 0.5:
                continue
            sequence = CountSequence(
                label, min(scores), min(margins), sum(scores) / len(scores)
            )
            if label not in candidates or candidates[label].mean < sequence.mean:
                candidates[label] = sequence
    ordered = sorted(
        candidates.values(), key=lambda result: (-result.mean, result.text)
    )
    if not ordered:
        return None
    best = ordered[0]
    margin = best.mean - ordered[1].mean if len(ordered) > 1 else 1.0
    return CountSequence(best.text, best.score, best.margin, best.mean, margin)
