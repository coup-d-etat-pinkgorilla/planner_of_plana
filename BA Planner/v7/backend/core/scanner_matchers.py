from __future__ import annotations

from dataclasses import dataclass
from threading import Event
from typing import Any, Callable, Protocol

from PIL import Image, ImageChops, ImageStat

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_session import ScannerError


class CapturePort(Protocol):
    def capture(self, target: dict[str, Any]) -> Image.Image: ...
    def scroll(self, target: dict[str, Any], delta: int) -> None: ...
    def wait_stable(self, target: dict[str, Any], cancel: Event, timeout: float = 2.0) -> Image.Image: ...


def image_pixels(image: Image.Image):
    flattened = getattr(image, "get_flattened_data", None)
    return flattened() if flattened is not None else image.getdata()


def ratio_crop(image: Image.Image, region: dict[str, Any]) -> Image.Image:
    try:
        box = (
            round(image.width * float(region["x1"])), round(image.height * float(region["y1"])),
            round(image.width * float(region["x2"])), round(image.height * float(region["y2"])),
        )
    except (KeyError, TypeError, ValueError) as exc:
        raise ScannerError("region_missing", "invalid ratio region") from exc
    if box[0] >= box[2] or box[1] >= box[3]:
        raise ScannerError("region_missing", "ratio region is empty")
    return image.crop(box)


def image_similarity(left: Image.Image, right: Image.Image) -> float:
    size = (96, 96)
    a = left.convert("RGB").resize(size, Image.Resampling.BILINEAR)
    b = right.convert("RGB").resize(size, Image.Resampling.BILINEAR)
    stat = ImageStat.Stat(ImageChops.difference(a, b))
    mean = sum(stat.mean) / (len(stat.mean) * 255.0)
    return max(0.0, min(1.0, 1.0 - mean))


@dataclass(frozen=True, slots=True)
class Match:
    identity: str
    score: float
    margin: float


class TemplateMatcher:
    def __init__(self, catalog: RecognitionAssetCatalog, scan_kind: str, purpose: str) -> None:
        self.catalog = catalog
        self.templates = [
            (asset.identity, Image.open(catalog.resolve(asset.path)).convert("RGB"))
            for asset in catalog.assets(scan_kind, purpose)
            if asset.identity is not None
        ]
        if not self.templates:
            raise ScannerError("template_missing", f"no {scan_kind} templates")

    @staticmethod
    def _center(image: Image.Image, trim: float) -> Image.Image:
        if trim <= 0:
            return image
        return image.crop((round(image.width * trim), round(image.height * trim), round(image.width * (1 - trim)), round(image.height * (1 - trim))))

    def match(self, image: Image.Image, *, center_trim: float = 0.0) -> Match:
        ranked = sorted(
            ((identity, image_similarity(self._center(image, center_trim), self._center(template, center_trim))) for identity, template in self.templates),
            key=lambda item: item[1], reverse=True,
        )
        best_id, best_score = ranked[0]
        second = ranked[1][1] if len(ranked) > 1 else 0.0
        return Match(best_id, best_score, best_score - second)


@dataclass(frozen=True, slots=True)
class CountMatch:
    value: str | None
    score: float
    margin: float


class SlotCountMatcher:
    """Read the v6 inventory count glyph row without an OCR dependency."""

    _INK = (45, 70, 99)
    _REFERENCE_SIZE = (234.0, 190.0)

    def __init__(self, catalog: RecognitionAssetCatalog, *, threshold: float = 0.70, margin: float = 0.04) -> None:
        self.threshold = threshold
        self.margin = margin
        self.templates = {
            asset.identity: Image.open(catalog.resolve(asset.path)).convert("L")
            for asset in catalog.assets("inventory", "inventory-count-template")
            if asset.identity is not None
        }
        if set(self.templates) != set("0123456789"):
            raise ScannerError("template_missing", "inventory count digit templates are incomplete")

    @staticmethod
    def _binary_iou(left: Image.Image, right: Image.Image) -> float:
        a = left.convert("L")
        right = right.resize(a.size, Image.Resampling.NEAREST)
        left_bits = [value >= 127 for value in image_pixels(a)]
        right_bits = [value >= 127 for value in image_pixels(right)]
        intersection = sum(x and y for x, y in zip(left_bits, right_bits))
        union = sum(x or y for x, y in zip(left_bits, right_bits))
        return intersection / union if union else 0.0

    @classmethod
    def _ink_mask(cls, image: Image.Image) -> Image.Image:
        rgb = image.convert("RGB")
        target = cls._INK
        pixels = [
            255 if sum((pixel[index] - target[index]) ** 2 for index in range(3)) <= 12 ** 2 else 0
            for pixel in image_pixels(rgb)
        ]
        mask = Image.new("L", rgb.size)
        mask.putdata(pixels)
        return mask

    @classmethod
    def digit_box(cls, slot: Image.Image, position: int) -> tuple[int, int, int, int]:
        reference_width, reference_height = cls._REFERENCE_SIZE
        return (
            round(slot.width * (55 + 23 * position) / reference_width),
            round(slot.height * 144 / reference_height),
            round(slot.width * (77 + 23 * position) / reference_width),
            round(slot.height * 178 / reference_height),
        )

    def match(self, slot: Image.Image) -> CountMatch:
        digits: list[str] = []
        scores: list[float] = []
        margins: list[float] = []
        for position in range(6):
            crop = self._ink_mask(slot.crop(self.digit_box(slot, position)))
            ink_pixels = sum(value >= 127 for value in image_pixels(crop))
            if ink_pixels < max(2, round(crop.width * crop.height * 0.015)):
                break
            ranked = sorted(
                ((digit, self._binary_iou(crop, template)) for digit, template in self.templates.items()),
                key=lambda item: item[1], reverse=True,
            )
            best_digit, best_score = ranked[0]
            digit_margin = best_score - ranked[1][1]
            digits.append(best_digit)
            scores.append(best_score)
            margins.append(digit_margin)
        if not digits:
            return CountMatch(None, 0.0, 0.0)
        score = min(scores)
        match_margin = min(margins)
        value = "".join(digits) if score >= self.threshold and match_margin >= self.margin else None
        return CountMatch(value, score, match_margin)


class StudentMatcherAdapter:
    def __init__(self, capture: CapturePort, catalog: RecognitionAssetCatalog, *, threshold: float = 0.82, margin: float = 0.04) -> None:
        self.capture = capture
        self.catalog = catalog
        self.threshold = threshold
        self.margin = margin
        self.matcher = TemplateMatcher(catalog, "student", "student-template")
        regions = catalog.region("student")
        self.texture_region = regions.get("student_texture_region")
        if not isinstance(self.texture_region, dict):
            raise ScannerError("region_missing", "student texture region is missing")

    def __call__(self, target: dict[str, Any], cancel: Event, progress: Callable[[int, int | None, str], None]) -> list[dict[str, Any]]:
        if cancel.is_set():
            return []
        progress(0, 1, "scanner.student.capture")
        frame = self.capture.wait_stable(target, cancel)
        if cancel.is_set():
            return []
        crop = ratio_crop(frame, self.texture_region)
        match = self.matcher.match(crop)
        confident = match.score >= self.threshold and match.margin >= self.margin
        progress(1, 1, "scanner.student.matched")
        return [{
            "payload": {"version": 1, "student_id": match.identity, "values": {}, "provenance": {"student_id": "template"}},
            "evidence": [{
                "field": "student_id", "status": "ok" if confident else "uncertain",
                "source": "student_texture_template", "confidence": match.score,
                "note": f"margin={match.margin:.6f}",
            }],
            "review_required": not confident,
        }]


class InventoryMatcherAdapter:
    def __init__(self, capture: CapturePort, catalog: RecognitionAssetCatalog, *, threshold: float = 0.80, margin: float = 0.03, max_pages: int = 5) -> None:
        self.capture = capture
        self.catalog = catalog
        self.threshold = threshold
        self.margin = margin
        self.max_pages = max_pages
        self.matcher = TemplateMatcher(catalog, "inventory", "inventory-template")
        self.count_matcher = SlotCountMatcher(catalog)
        regions = catalog.region("inventory").get("item", {})
        self.slots = regions.get("grid_slots")
        if not isinstance(self.slots, list) or not self.slots:
            raise ScannerError("region_missing", "inventory grid slots are missing")

    def __call__(self, target: dict[str, Any], cancel: Event, progress: Callable[[int, int | None, str], None]) -> list[dict[str, Any]]:
        frame = self.capture.wait_stable(target, cancel)
        entries: list[dict[str, Any]] = []
        evidence: list[dict[str, Any]] = []
        review_required = False
        for page in range(self.max_pages):
            for slot_index, region in enumerate(self.slots):
                if cancel.is_set():
                    return []
                crop = ratio_crop(frame, region)
                fast = self.matcher.match(crop, center_trim=0.15)
                fast_confident = fast.score >= self.threshold and fast.margin >= self.margin
                match = fast if fast_confident else self.matcher.match(crop)
                source = "grid_icon_template" if fast_confident else "detail_template_fallback"
                if match.score < 0.55:
                    continue
                confident = match.score >= self.threshold and match.margin >= self.margin
                if any(entry["item_id"] == match.identity for entry in entries):
                    continue
                index = page * len(self.slots) + slot_index
                count = self.count_matcher.match(crop)
                quantity_confident = count.value is not None
                entries.append({"key": match.identity, "quantity": count.value, "item_id": match.identity, "name": None, "index": index, "profile_id": "visible-grid"})
                evidence.extend([
                    {"field": f"entries[{index}].item_id", "status": "ok" if confident else "uncertain", "source": source, "confidence": match.score, "note": f"margin={match.margin:.6f}"},
                    {"field": f"entries[{index}].quantity", "status": "ok" if quantity_confident else "uncertain", "source": "slot_count_glyph", "confidence": count.score, "note": f"margin={count.margin:.6f}"},
                ])
                review_required = review_required or not confident or not quantity_confident
                progress(len(entries), None, "scanner.inventory.grid")
            if len(entries) >= len(self.matcher.templates):
                break
            if cancel.is_set():
                return []
            self.capture.scroll(target, -480)
            next_frame = self.capture.wait_stable(target, cancel)
            overlap = image_similarity(frame, next_frame)
            if overlap >= 0.995:
                evidence.append({"field": "scroll_terminal", "status": "ok", "source": "stable_frame_overlap", "confidence": overlap, "note": "tail-or-no-motion"})
                break
            if overlap <= 0.05:
                evidence.append({"field": "scroll_overlap", "status": "uncertain", "source": "frame_overlap", "confidence": overlap, "note": "near-zero overlap; no zero-fill"})
                review_required = True
            frame = next_frame
        return [{
            "payload": {"version": 1, "entries": entries},
            "evidence": evidence,
            "review_required": review_required,
        }]
