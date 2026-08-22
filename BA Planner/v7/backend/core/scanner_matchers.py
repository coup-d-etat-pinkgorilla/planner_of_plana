from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from threading import Event
from typing import Any, Callable, Protocol

from PIL import Image, ImageChops, ImageStat

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_session import ScannerError
from core.student_scan_recognizer import StudentBasicCropSet, StudentBasicRecognizer
from core.student_equipment_recognizer import EquipmentMenuRecognizer, StudentEquipmentRecognizer
from core import student_meta


class CapturePort(Protocol):
    def capture(self, target: dict[str, Any]) -> Image.Image: ...
    def scroll(self, target: dict[str, Any], delta: int) -> None: ...
    def wait_stable(self, target: dict[str, Any], cancel: Event, timeout: float = 2.0) -> Image.Image: ...


class EquipmentMenuCapturePort(Protocol):
    """Input orchestration boundary; S3 consumes exactly one opened-menu frame."""

    def capture_equipment_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def close_equipment_menu(self, target: dict[str, Any]) -> None: ...


class ClickCapturePort(CapturePort, Protocol):
    def click(self, target: dict[str, Any], x_ratio: float, y_ratio: float) -> None: ...


class EquipmentMenuCaptureAdapter:
    """Minimal S3 input orchestrator; one stable menu frame is shared by unresolved slots."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog) -> None:
        self.capture = capture
        self.regions = catalog.region_for_purpose("student", "student-equipment-menu-regions")

    @staticmethod
    def _center(region: dict[str, Any]) -> tuple[float, float]:
        return (
            (float(region["x1"]) + float(region["x2"])) / 2.0,
            (float(region["y1"]) + float(region["y2"])) / 2.0,
        )

    def capture_equipment_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image:
        if cancel.is_set():
            raise ScannerError("cancelled", "equipment menu capture cancelled")
        region = self.regions.get("equipment_button")
        if not isinstance(region, dict):
            raise ScannerError("region_missing", "equipment button region is missing")
        self.capture.click(target, *self._center(region))
        try:
            if cancel.wait(0.35):
                raise ScannerError("cancelled", "equipment menu capture cancelled")
            return self.capture.wait_stable(target, cancel, timeout=3.0)
        except Exception:
            self.close_equipment_menu(target)
            raise

    def close_equipment_menu(self, target: dict[str, Any]) -> None:
        region = self.regions.get("equipmentmenu_quit_button")
        if isinstance(region, dict):
            self.capture.click(target, *self._center(region))


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


def image_has_visible_content(image: Image.Image) -> bool:
    """Reject capture padding before a large template catalog can guess an identity."""
    luminance = image.convert("L")
    histogram = luminance.histogram()
    visible = sum(histogram[13:])
    return visible / max(1, luminance.width * luminance.height) >= 0.12


@dataclass(frozen=True, slots=True)
class Match:
    identity: str
    score: float
    margin: float


class TemplateMatcher:
    _MATCH_SIZE = (96, 96)

    def __init__(self, catalog: RecognitionAssetCatalog, scan_kind: str, purpose: str) -> None:
        self.catalog = catalog
        self.templates = [
            (asset.identity, self._load_template(catalog.resolve(asset.path)))
            for asset in catalog.assets(scan_kind, purpose)
            if asset.identity is not None
        ]
        if not self.templates:
            raise ScannerError("template_missing", f"no {scan_kind} templates")

    @classmethod
    def _load_template(cls, path: Path) -> Image.Image:
        with Image.open(path) as image:
            return image.convert("RGB").resize(cls._MATCH_SIZE, Image.Resampling.BILINEAR)

    @staticmethod
    def _center(image: Image.Image, trim: float) -> Image.Image:
        if trim <= 0:
            return image
        return image.crop((round(image.width * trim), round(image.height * trim), round(image.width * (1 - trim)), round(image.height * (1 - trim))))

    def match(self, image: Image.Image, *, center_trim: float = 0.0) -> Match:
        best_by_identity: dict[str, float] = {}
        for identity, template in self.templates:
            score = image_similarity(
                self._center(image, center_trim),
                self._center(template, center_trim),
            )
            best_by_identity[identity] = max(score, best_by_identity.get(identity, 0.0))
        ranked = sorted(best_by_identity.items(), key=lambda item: item[1], reverse=True)
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
    def __init__(
        self,
        capture: CapturePort,
        catalog: RecognitionAssetCatalog,
        *,
        threshold: float = 0.82,
        margin: float = 0.04,
        equipment_menu: EquipmentMenuCapturePort | None = None,
    ) -> None:
        self.capture = capture
        self.catalog = catalog
        self.threshold = threshold
        self.margin = margin
        self.matcher = TemplateMatcher(catalog, "student", "student-template")
        self.regions = catalog.region("student")
        self.texture_region = self.regions.get("student_texture_region")
        if not isinstance(self.texture_region, dict):
            raise ScannerError("region_missing", "student texture region is missing")
        self.basic_recognizer = StudentBasicRecognizer(catalog)
        self.equipment_recognizer = StudentEquipmentRecognizer(catalog)
        self.equipment_menu = equipment_menu
        self.equipment_menu_recognizer = EquipmentMenuRecognizer(catalog) if equipment_menu is not None else None

    @staticmethod
    def _canonical_student_ref(identity: str) -> str:
        for student_id in student_meta.all_ids():
            for form_index in student_meta.form_indexes(student_id):
                template_stem = Path(student_meta.template_path_for_form(student_id, form_index)).stem
                if template_stem == identity:
                    return student_meta.format_form_ref(student_id, form_index)
        return identity

    def __call__(self, target: dict[str, Any], cancel: Event, progress: Callable[[int, int | None, str], None]) -> list[dict[str, Any]]:
        if cancel.is_set():
            return []
        progress(0, 4, "scanner.student.capture")
        frame = self.capture.wait_stable(target, cancel)
        if cancel.is_set():
            frame.close()
            return []
        try:
            crops = StudentBasicCropSet.from_frame(frame, self.regions)
        finally:
            frame.close()
        try:
            progress(1, 4, "scanner.student.identify")
            match = self.matcher.match(crops.images["student_texture_region"])
            student_ref = self._canonical_student_ref(match.identity)
            confident = match.score >= self.threshold and match.margin >= self.margin
            if cancel.is_set():
                return []
            progress(2, 4, "scanner.student.basic_fields")
            observations = self.basic_recognizer.recognize(crops)
            equipment_observations, unresolved = self.equipment_recognizer.recognize(
                crops,
                student_ref=student_ref,
                student_level=(
                    int(observations["level"].value)
                    if observations.get("level") is not None and observations["level"].confirmed
                    else None
                ),
            )
            observations.update(equipment_observations)
            progress(3, 4, "scanner.student.equipment_fields")
            if unresolved and self.equipment_menu is not None and self.equipment_menu_recognizer is not None:
                menu_frame = self.equipment_menu.capture_equipment_menu(target, cancel)
                self.equipment_recognizer.metrics.menu_captures += 1
                try:
                    fallback = self.equipment_menu_recognizer.recognize(menu_frame, unresolved)
                finally:
                    menu_frame.close()
                    self.equipment_menu.close_equipment_menu(target)
                for field, observation in fallback.items():
                    if field.removeprefix("equip").split("_", 1)[0].isdigit() and int(field.removeprefix("equip").split("_", 1)[0]) in unresolved:
                        observations[field] = observation
                for slot in unresolved:
                    learned = fallback.get(f"equip{slot}_level")
                    region = self.regions.get(f"basic_equipment_{slot}_level_digits_quad")
                    if slot <= 3 and learned is not None and learned.confirmed and isinstance(region, dict):
                        self.equipment_recognizer.learn_basic_level(
                            crops.images.get(f"basic_equipment_{slot}_level_digits_quad"),
                            slot=slot,
                            value=int(learned.value),
                            region=region,
                        )
        finally:
            crops.close()
        values = {
            field: observation.value
            for field, observation in observations.items()
            if observation.confirmed
        }
        provenance = {"student_id": "student_texture_template"}
        provenance.update({field: observation.source for field, observation in observations.items() if observation.confirmed})
        evidence = [{
            "field": "student_id", "status": "ok" if confident else "uncertain",
            "source": "student_texture_template", "confidence": match.score,
            "note": f"margin={match.margin:.6f};form_ref={student_ref}",
        }]
        evidence.extend({
            "field": field,
            "status": observation.status,
            "source": observation.source,
            "confidence": observation.confidence,
            "note": observation.note,
        } for field, observation in observations.items())
        evidence.extend({
            "field": field,
            "status": observation.status,
            "source": observation.source,
            "confidence": observation.confidence,
            "note": observation.note,
        } for field, observation in self.equipment_recognizer.last_binary_shadow.items())
        evidence.extend({
            "field": field,
            "status": observation.status,
            "source": observation.source,
            "confidence": observation.confidence,
            "note": observation.note,
        } for field, observation in self.equipment_recognizer.last_generated_binary_shadow.items())
        evidence.extend({
            "field": field,
            "status": observation.status,
            "source": observation.source,
            "confidence": observation.confidence,
            "note": observation.note,
        } for field, observation in self.equipment_recognizer.last_position_binary_shadow.items())
        review_required = (not confident) or any(
            observation.status not in {"ok", "inferred", "skipped"}
            for observation in observations.values()
        )
        progress(4, 4, "scanner.student.matched")
        return [{
            "payload": {"version": 1, "student_id": student_ref, "values": values, "provenance": provenance},
            "evidence": evidence,
            "review_required": review_required,
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
                if not image_has_visible_content(crop):
                    continue
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
