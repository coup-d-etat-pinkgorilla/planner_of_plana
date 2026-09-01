from __future__ import annotations

from collections import deque
from dataclasses import dataclass
import json
from pathlib import Path
from threading import RLock

from PIL import Image, ImageChops

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_session import ScannerError


@dataclass(frozen=True, slots=True)
class StudioNumericMatch:
    value: int | None
    score: float
    margin: float
    labels: tuple[str, ...]
    shifts: tuple[tuple[int, int], ...]
    complete: bool
    used_user_sample: bool = False
    used_session_sample: bool = False


def _pixels(image: Image.Image):
    flattened = getattr(image, "get_flattened_data", None)
    return flattened() if flattened is not None else image.getdata()


def _components(mask: Image.Image) -> list[list[tuple[int, int]]]:
    active = {
        (x, y)
        for y in range(mask.height)
        for x in range(mask.width)
        if mask.getpixel((x, y)) >= 127
    }
    result: list[list[tuple[int, int]]] = []
    while active:
        start = active.pop()
        queue = deque([start])
        component = [start]
        while queue:
            x, y = queue.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if not dx and not dy:
                        continue
                    point = (x + dx, y + dy)
                    if point in active:
                        active.remove(point)
                        queue.append(point)
                        component.append(point)
        result.append(component)
    return result


def _keep_component(mask: Image.Image, *, prefer_largest_tall: bool) -> Image.Image:
    components = _components(mask)
    result = Image.new("L", mask.size)
    if not components:
        return result
    if prefer_largest_tall:
        minimum_height = max(3, round(mask.height * 0.30))
        tall = [
            component
            for component in components
            if max(y for _x, y in component) - min(y for _x, y in component) + 1
            >= minimum_height
        ]
        kept = max(tall or components, key=len)
    else:
        def score(component: list[tuple[int, int]]) -> tuple[int, int, float]:
            touches = sum(
                x in (0, mask.width - 1) or y in (0, mask.height - 1)
                for x, y in component
            )
            center = sum(abs(x - (mask.width - 1) / 2.0) for x, _y in component) / len(component)
            return -touches, len(component), -center

        kept = max(components, key=score)
    pixels = result.load()
    for x, y in kept:
        pixels[x, y] = 255
    return result


def source_digit_mask(image: Image.Image, field: str) -> Image.Image:
    rgba = image.convert("RGBA")
    raw = Image.new("L", rgba.size)
    output = raw.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = rgba.getpixel((x, y))
            if alpha < 64:
                continue
            if field == "relationship_rank":
                selected = (
                    red < 150
                    and 3 <= green - red <= 38
                    and 5 <= blue - green <= 45
                )
            else:
                selected = min(red, green, blue) >= 185 and max(red, green, blue) - min(red, green, blue) <= 85
            if selected:
                output[x, y] = 255
    rgba.close()
    cleaned = _keep_component(
        raw,
        prefer_largest_tall=field in {"student_level", "relationship_rank"},
    )
    raw.close()
    return cleaned


def _mask_from_bits(width: int, height: int, bits: int) -> Image.Image:
    mask = Image.new("L", (width, height))
    mask.putdata([255 if bits & (1 << index) else 0 for index in range(width * height)])
    return mask


def _iou(left: Image.Image, right: Image.Image) -> float:
    intersection = ImageChops.logical_and(left.convert("1"), right.convert("1"))
    union = ImageChops.logical_or(left.convert("1"), right.convert("1"))
    intersection_count = sum(bool(value) for value in _pixels(intersection))
    union_count = sum(bool(value) for value in _pixels(union))
    intersection.close()
    union.close()
    return intersection_count / union_count if union_count else 0.0


def _best_shift(source: Image.Image, template: Image.Image) -> tuple[float, int, int]:
    prepared = (
        template.resize(source.size, Image.Resampling.NEAREST)
        if template.size != source.size
        else template.copy()
    )
    best = (-1.0, 0, 0)
    try:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                shifted = Image.new("L", source.size)
                shifted.paste(prepared, (dx, dy))
                score = _iou(source, shifted)
                shifted.close()
                if score > best[0]:
                    best = score, dx, dy
        return best
    finally:
        prepared.close()


def _shape_normalized_iou(source: Image.Image, template: Image.Image) -> float:
    """Compare glyph shape independently of source resolution and raster bounds."""
    source_box = source.getbbox()
    template_box = template.getbbox()
    if source_box is None or template_box is None:
        return 0.0
    source_glyph = source.crop(source_box)
    template_glyph = template.crop(template_box)
    try:
        normalized_size = (32, 32)
        normalized_source = source_glyph.resize(normalized_size, Image.Resampling.NEAREST)
        normalized_template = template_glyph.resize(normalized_size, Image.Resampling.NEAREST)
        try:
            return _iou(normalized_source, normalized_template)
        finally:
            normalized_source.close()
            normalized_template.close()
    finally:
        source_glyph.close()
        template_glyph.close()


class StudioNumericBank:
    PURPOSE = "student-studio-numeric-digit-bank"

    def __init__(self, templates: dict[str, dict[str, Image.Image]]) -> None:
        self.templates = templates
        self.user_templates: dict[str, dict[str, dict[str, Image.Image]]] = {}
        self.session_templates: dict[str, dict[str, dict[str, Image.Image]]] = {}
        self._lock = RLock()

    def add_user_template(
        self, roi_name: str, digit: str, image: Image.Image, *, sample_id: str
    ) -> None:
        with self._lock:
            if roi_name not in self.templates or digit not in "0123456789":
                return
            samples = self.user_templates.setdefault(roi_name, {}).setdefault(digit, {})
            if sample_id not in samples:
                samples[sample_id] = image.convert("L")

    def clear_user_templates(self) -> None:
        with self._lock:
            for templates in self.user_templates.values():
                for samples in templates.values():
                    for image in samples.values():
                        image.close()
            self.user_templates.clear()

    def add_session_template(
        self, roi_name: str, digit: str, image: Image.Image, *, sample_id: str
    ) -> None:
        with self._lock:
            if roi_name not in self.templates or digit not in "0123456789":
                return
            samples = self.session_templates.setdefault(roi_name, {}).setdefault(digit, {})
            if sample_id not in samples:
                samples[sample_id] = image.convert("L")

    def clear_session_templates(self) -> None:
        with self._lock:
            for templates in self.session_templates.values():
                for samples in templates.values():
                    for image in samples.values():
                        image.close()
            self.session_templates.clear()

    @classmethod
    def from_catalog(cls, catalog: RecognitionAssetCatalog) -> "StudioNumericBank":
        assets = catalog.assets("student", cls.PURPOSE)
        if len(assets) != 1:
            raise ScannerError("template_missing", "Studio numeric digit bank is missing")
        try:
            payload = json.loads(catalog.resolve(assets[0].path).read_text(encoding="utf-8"))
        except (OSError, ValueError, TypeError) as exc:
            raise ScannerError("template_missing", "Studio numeric digit bank is invalid") from exc
        grouped: dict[str, dict[str, Image.Image]] = {}
        for row in payload.get("templates", []):
            try:
                roi = str(row["roi"])
                digit = str(row["digit"])
                width = int(row["width"])
                height = int(row["height"])
                bits = int(str(row["bits_hex"]), 16)
            except (KeyError, TypeError, ValueError) as exc:
                raise ScannerError("template_missing", "Studio numeric template row is invalid") from exc
            grouped.setdefault(roi, {})[digit] = _mask_from_bits(width, height, bits)
        if not grouped or any(set(templates) != set("0123456789") for templates in grouped.values()):
            raise ScannerError("template_missing", "Studio numeric position templates are incomplete")
        return cls(grouped)

    def match(
        self,
        cells: tuple[Image.Image, ...] | None,
        *,
        field: str,
        roi_names: tuple[str, ...],
        allow_trailing_blank: bool = False,
    ) -> StudioNumericMatch:
        with self._lock:
            return self._match_locked(
                cells, field=field, roi_names=roi_names,
                allow_trailing_blank=allow_trailing_blank,
            )

    def _match_locked(
        self,
        cells: tuple[Image.Image, ...] | None,
        *,
        field: str,
        roi_names: tuple[str, ...],
        allow_trailing_blank: bool = False,
    ) -> StudioNumericMatch:
        if not cells or len(cells) != len(roi_names):
            return StudioNumericMatch(None, 0.0, 0.0, (), (), False)
        labels: list[str] = []
        scores: list[float] = []
        margins: list[float] = []
        shifts: list[tuple[int, int]] = []
        used_user_sample = False
        used_session_sample = False
        for position, (cell, roi_name) in enumerate(zip(cells, roi_names)):
            source = source_digit_mask(cell, field)
            try:
                if source.getbbox() is None:
                    if allow_trailing_blank and position > 0 and labels:
                        break
                    return StudioNumericMatch(None, 0.0, 0.0, tuple(labels), tuple(shifts), False)
                templates = self.templates.get(roi_name, {})
                ranked: list[tuple[str, float, int, int, str]] = []
                bonus = {"bundled": 0.0, "session": 0.04, "user": 0.08}
                for digit, template in templates.items():
                    variants = [(template, "bundled"), *(
                        (sample, "session")
                        for sample in self.session_templates.get(roi_name, {}).get(digit, {}).values()
                    ), *(
                        (sample, "user")
                        for sample in self.user_templates.get(roi_name, {}).get(digit, {}).values()
                    )]
                    if field == "weapon_level":
                        best = max(
                            ((_shape_normalized_iou(source, variant), 0, 0, provenance)
                             for variant, provenance in variants),
                            key=lambda item: item[0] + bonus[item[3]],
                        )
                    else:
                        best = max(
                            ((*_best_shift(source, variant), provenance)
                             for variant, provenance in variants),
                            key=lambda item: item[0] + bonus[item[3]],
                        )
                    ranked.append((digit, *best))
                ranked.sort(key=lambda item: item[1] + bonus[item[4]], reverse=True)
                if len(ranked) < 2:
                    return StudioNumericMatch(None, 0.0, 0.0, tuple(labels), tuple(shifts), False)
                labels.append(ranked[0][0])
                scores.append(ranked[0][1])
                margins.append(
                    ranked[0][1] + bonus[ranked[0][4]]
                    - ranked[1][1] - bonus[ranked[1][4]]
                )
                shifts.append((ranked[0][2], ranked[0][3]))
                used_user_sample = used_user_sample or ranked[0][4] == "user"
                used_session_sample = used_session_sample or ranked[0][4] == "session"
            finally:
                source.close()
        if not labels or labels[0] == "0":
            return StudioNumericMatch(None, 0.0, 0.0, tuple(labels), tuple(shifts), False)
        return StudioNumericMatch(
            int("".join(labels)), min(scores), min(margins), tuple(labels), tuple(shifts), True,
            used_user_sample, used_session_sample,
        )

    def close(self) -> None:
        for templates in self.templates.values():
            for image in templates.values():
                image.close()
        self.clear_user_templates()
        self.clear_session_templates()
        self.templates.clear()
