from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from threading import Event, RLock
from typing import Any, Callable, Protocol

from PIL import Image, ImageChops, ImageStat
from statistics import median
from core.recognition_image_ops import ncc_per_channel_icon
from core.inventory_tile_bank import TileBank
from core.inventory_order_rules import increasing_run
from core.recognition_synth import SYNTH_ENABLED_PROFILES, SynthUnavailable
from core.recognition_synth_cache import SynthDriftGuard
from core.inventory_count_bank import CountBank

from core.recognition_assets import RecognitionAssetCatalog
from core.recognition_answer_samples import RecognitionAnswerSampleStore
from core import recognition_thresholds as rt
from core.inventory_catalog import CATALOG, CATALOG_REVISION
from core.scanner_session import ScanBatchResult, ScannerError
from core.scan_context import ScanContext
from core.student_scan_recognizer import Observation, StudentBasicCropSet, StudentBasicRecognizer
from core.student_equipment_recognizer import EquipmentMenuRecognizer, StudentEquipmentRecognizer
from core.student_weapon_recognizer import StudentWeaponRecognizer
from core.student_panel_recovery import PanelMenu, StudentPanelRecovery, read_panel_fields
from core.student_potential_recognizer import StudentPotentialRecognizer
from core.student_level_recognizer import StudentLevelRecognizer
from core.student_star_recognizer import StudentStarRecognizer
from core.student_skill_recognizer import StudentSkillRecognizer
from core.student_equipment_recovery import EquipmentControlRecognizer, resolve_equipment_menu
from core.student_identity_recovery import StudentIdentityRecognizer
from core.student_form_recovery import StudentFormRecovery
from core.studio_numeric_bank import source_digit_mask
from core.session_calibration import SessionCalibrationStore
from core import student_meta


class CapturePort(Protocol):
    def capture(self, target: dict[str, Any]) -> Image.Image: ...
    def scroll(self, target: dict[str, Any], delta: int) -> None: ...
    def wait_stable(self, target: dict[str, Any], cancel: Event, timeout: float = 2.0) -> Image.Image: ...


class ClickCapturePort(CapturePort, Protocol):
    def click(self, target: dict[str, Any], x_ratio: float, y_ratio: float) -> None: ...
    def press_key(self, target: dict[str, Any], key: str) -> bool: ...


class SkillMenuCaptureAdapter:
    """Open, positively enable show-all once, then return one verified skill frame."""

    def __init__(self, capture, catalog, *, recovery=None, recognizer=None):
        self.port = capture
        self.recovery = recovery or StudentPanelRecovery(capture,catalog)
        self.recognizer = recognizer or StudentSkillRecognizer(catalog)

    def capture(self, target, cancel):
        frame = self.recovery.open(target,cancel,"skill",self.recognizer.regions["skill_menu_button"])
        try:
            if cancel.is_set(): raise ScannerError("cancelled","skill open cancelled")
            check = self.recognizer.read_check(frame)
            self.recovery.trace.append({"show_all":check.value,"status":check.status})
            if not check.confirmed:
                raise ScannerError("panel_read_failed","skill show-all state is unknown")
            if check.value is False:
                if cancel.is_set(): raise ScannerError("cancelled","skill check cancelled")
                self.port.click(ScanContext.of(target).replace(cancel=cancel),
                    *self.recovery._center(self.recognizer.regions["skill_all_view_check_region"]))
                self.recovery.trace.append({"input":"enable_show_all","panel":"skill"})
                frame.close()
                frame = None
                frame = self.recovery.recapture(target,cancel,"skill")
                if cancel.is_set(): raise ScannerError("cancelled","skill recapture cancelled")
                check = self.recognizer.read_check(frame)
                self.recovery.trace.append({"show_all":check.value,"status":check.status})
                if not check.confirmed or check.value is not True:
                    raise ScannerError("panel_read_failed","skill show-all enable was not verified")
            return frame
        except Exception:
            if frame is not None: frame.close()
            self.recovery.restore(target)
            raise

    def close(self, target):
        self.recovery.restore(target)


class StarMenuCaptureAdapter:
    """Read-only star tab navigation, with F2 verified basic return."""

    def __init__(self, capture, catalog, *, recovery=None):
        self.recovery = recovery or StudentPanelRecovery(capture, catalog)

    def capture(self, target, cancel):
        return self.recovery.open(target, cancel, "star", self.recovery.regions["star_menu_button"])

    def close(self, target):
        self.recovery.restore(target)


class EquipmentMenuCaptureAdapter:
    """Equipment detail transport backed by verified panel transitions."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog, *, recovery=None, controls=None) -> None:
        self.port = capture
        self.regions = catalog.region_for_purpose("student", "student-equipment-menu-regions")
        self.recovery = recovery or StudentPanelRecovery(capture, catalog)
        self.controls = controls or EquipmentControlRecognizer(catalog)

    def _check(self, frame, cancel):
        if cancel.is_set():
            raise ScannerError("cancelled", "equipment check cancelled")
        check = self.controls.read_check(frame)
        self.recovery.trace.append({"show_all": check.value, "status": check.status, "panel": "equipment"})
        if not check.confirmed:
            raise ScannerError("panel_read_failed", "equipment show-all state unknown")
        return check.value

    def capture(self, target, cancel):
        frame = self.recovery.open(target, cancel, "equipment", self.regions["equipment_button"])
        try:
            checked = self._check(frame, cancel)
            if checked is False:
                frame.close()
                frame = None
                frame = self.recovery.recapture(target, cancel, "equipment")
                checked = self._check(frame, cancel)
            if checked is False:
                if cancel.is_set(): raise ScannerError("cancelled", "equipment enable cancelled")
                self.port.click(ScanContext.of(target).replace(cancel=cancel),
                    *self.recovery._center(self.regions["equipment_all_view_check_region"]))
                self.recovery.trace.append({"input": "enable_show_all", "panel": "equipment"})
                frame.close()
                frame = None
                frame = self.recovery.recapture(target, cancel, "equipment")
                if self._check(frame, cancel) is not True:
                    raise ScannerError("panel_read_failed", "equipment show-all enable unconfirmed")
            return frame
        except Exception:
            if frame is not None: frame.close()
            self.recovery.restore(target)
            raise

    def recapture(self, target, cancel):
        frame = self.recovery.recapture(target, cancel, "equipment")
        try:
            if self._check(frame, cancel) is not True:
                raise ScannerError("panel_read_failed", "equipment show-all changed during retry")
            return frame
        except Exception:
            frame.close()
            raise

    def close(self, target):
        self.recovery.restore(target)


class WeaponMenuCaptureAdapter:
    """Weapon detail transport backed by the same panel state contract."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog, *, recovery=None) -> None:
        self.port = capture
        self.regions = catalog.region_for_purpose("student", "student-weapon-regions")
        self.recovery = recovery or StudentPanelRecovery(capture, catalog)

    def capture(self, target, cancel):
        return self.recovery.open(target, cancel, "weapon", self.regions["weapon_info_menu_button"])

    def recapture(self, target, cancel):
        return self.recovery.recapture(target, cancel, "weapon")

    def close(self, target):
        self.recovery.restore(target)


class StatMenuCaptureAdapter:
    """Read-only ability-release panel using F2 same-student recovery."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog, *, recovery=None):
        self.regions = catalog.region_for_purpose("student", "student-potential-regions")
        self.recovery = recovery or StudentPanelRecovery(capture, catalog)

    def capture(self, target, cancel):
        return self.recovery.open(target, cancel, "stat", self.regions["stat_menu_button"])

    def recapture(self, target, cancel):
        return self.recovery.recapture(target, cancel, "stat")

    def close(self, target):
        self.recovery.restore(target)


class LevelMenuCaptureAdapter:
    """Level tab transport; the only input is tab navigation, never growth."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog, *, recovery=None):
        self.recovery = recovery or StudentPanelRecovery(capture,catalog)

    def capture(self, target, cancel):
        return self.recovery.open(target,cancel,"level",self.recovery.regions["levelcheck_button"])

    def recapture(self, target, cancel):
        return self.recovery.recapture(target,cancel,"level")

    def close(self, target):
        self.recovery.restore(target)


# Kind-named aliases of the PanelMenu methods, kept until C6 for tools and the F12 audit matrix.
SkillMenuCaptureAdapter.capture_skill_menu = SkillMenuCaptureAdapter.capture
SkillMenuCaptureAdapter.close_skill_menu = SkillMenuCaptureAdapter.close
StarMenuCaptureAdapter.capture_star_menu = StarMenuCaptureAdapter.capture
StarMenuCaptureAdapter.close_star_menu = StarMenuCaptureAdapter.close
EquipmentMenuCaptureAdapter.capture_equipment_menu = EquipmentMenuCaptureAdapter.capture
EquipmentMenuCaptureAdapter.recapture_equipment_menu = EquipmentMenuCaptureAdapter.recapture
EquipmentMenuCaptureAdapter.close_equipment_menu = EquipmentMenuCaptureAdapter.close
WeaponMenuCaptureAdapter.capture_weapon_menu = WeaponMenuCaptureAdapter.capture
WeaponMenuCaptureAdapter.recapture_weapon_menu = WeaponMenuCaptureAdapter.recapture
WeaponMenuCaptureAdapter.close_weapon_menu = WeaponMenuCaptureAdapter.close
StatMenuCaptureAdapter.capture_stat_menu = StatMenuCaptureAdapter.capture
StatMenuCaptureAdapter.recapture_stat_menu = StatMenuCaptureAdapter.recapture
StatMenuCaptureAdapter.close_stat_menu = StatMenuCaptureAdapter.close
LevelMenuCaptureAdapter.capture_level_menu = LevelMenuCaptureAdapter.capture
LevelMenuCaptureAdapter.recapture_level_menu = LevelMenuCaptureAdapter.recapture
LevelMenuCaptureAdapter.close_level_menu = LevelMenuCaptureAdapter.close


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
    if visible / max(1, luminance.width * luminance.height) < rt.value("inventory.visible_content.ratio"):
        return False
    # C5d: an empty grid tile at the list end is one flat grey; filled tiles carry icon and count texture.
    width, height = luminance.size
    with luminance.crop((int(width * .18), int(height * .18), int(width * .82), int(height * .82))) as inner:
        return ImageStat.Stat(inner).stddev[0] > rt.value("inventory.empty_tile.stddev")


@dataclass(frozen=True, slots=True)
class Match:
    identity: str
    score: float
    margin: float
    source: str = "bundled"


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
        self.user_templates: dict[str, tuple[str, Image.Image]] = {}
        self._lock = RLock()

    def replace_user_templates(
        self, samples: list[tuple[str, str, Image.Image]]
    ) -> None:
        with self._lock:
            for _identity, image in self.user_templates.values():
                image.close()
            self.user_templates = {
                sample_id: (identity, image.convert("RGB").resize(self._MATCH_SIZE, Image.Resampling.BILINEAR))
                for sample_id, identity, image in samples
            }

    def add_user_template(self, sample_id: str, identity: str, image: Image.Image) -> None:
        with self._lock:
            if sample_id in self.user_templates:
                return
            self.user_templates[sample_id] = (
                identity, image.convert("RGB").resize(self._MATCH_SIZE, Image.Resampling.BILINEAR)
            )

    @classmethod
    def _load_template(cls, path: Path) -> Image.Image:
        with Image.open(path) as image:
            return image.convert("RGB").resize(cls._MATCH_SIZE, Image.Resampling.BILINEAR)

    @staticmethod
    def _center(image: Image.Image, trim: float) -> Image.Image:
        if trim <= 0:
            return image
        return image.crop((round(image.width * trim), round(image.height * trim), round(image.width * (1 - trim)), round(image.height * (1 - trim))))

    def match(
        self, image: Image.Image, *, center_trim: float = 0.0,
        prefer_user: bool = False, threshold: float = 0.0, margin: float = 0.0,
        allowed_identities: set[str] | None = None,
    ) -> Match:
        with self._lock:
            if prefer_user and self.user_templates:
                preferred = self._match_preferred(image, center_trim, allowed_identities)
                if (
                    preferred.source == "user_confirmed"
                    and preferred.score >= threshold and preferred.margin >= margin
                ):
                    return preferred
            templates = self.templates if allowed_identities is None else [
                item for item in self.templates if item[0] in allowed_identities
            ]
            if not templates:
                raise ScannerError("template_missing", "no templates match the requested inventory profile")
            return self._match_templates(image, templates, center_trim, "bundled")

    def _match_preferred(
        self, image: Image.Image, center_trim: float,
        allowed_identities: set[str] | None = None,
    ) -> Match:
        best_by_identity: dict[str, tuple[float, str]] = {}
        variants = [
            *((identity, template, "bundled") for identity, template in self.templates),
            *((identity, template, "user_confirmed") for identity, template in self.user_templates.values()),
        ]
        if allowed_identities is not None:
            variants = [item for item in variants if item[0] in allowed_identities]
        if not variants:
            raise ScannerError("template_missing", "no templates match the requested inventory profile")
        for identity, template, source in variants:
            score = image_similarity(
                self._center(image, center_trim), self._center(template, center_trim),
            )
            previous = best_by_identity.get(identity)
            if previous is None or score > previous[0] or (
                score == previous[0] and source == "user_confirmed"
            ):
                best_by_identity[identity] = (score, source)
        ranked = sorted(best_by_identity.items(), key=lambda item: item[1][0], reverse=True)
        identity, (score, source) = ranked[0]
        second = ranked[1][1][0] if len(ranked) > 1 else 0.0
        return Match(identity, score, score - second, source)

    def _match_templates(
        self, image: Image.Image, templates: list[tuple[str, Image.Image]],
        center_trim: float, source: str,
    ) -> Match:
        best_by_identity: dict[str, float] = {}
        for identity, template in templates:
            score = image_similarity(
                self._center(image, center_trim),
                self._center(template, center_trim),
            )
            best_by_identity[identity] = max(score, best_by_identity.get(identity, 0.0))
        ranked = sorted(best_by_identity.items(), key=lambda item: item[1], reverse=True)
        best_id, best_score = ranked[0]
        second = ranked[1][1] if len(ranked) > 1 else 0.0
        return Match(best_id, best_score, best_score - second, source)

    def rank(self, image: Image.Image) -> list[tuple[str, float]]:
        """Full bundled portrait ranking; no candidate hint may remove a competitor."""
        with self._lock:
            scores: dict[str, float] = {}
            for identity, template in self.templates:
                scores[identity] = max(image_similarity(image, template), scores.get(identity, 0.0))
            return sorted(scores.items(), key=lambda item: item[1], reverse=True)


@dataclass(frozen=True, slots=True)
class CountMatch:
    value: str | None
    score: float
    margin: float


class SlotCountMatcher:
    """Read the v6 inventory count glyph row without an OCR dependency."""

    _INK = (45, 70, 99)
    _REFERENCE_SIZE = (234.0, 190.0)

    def __init__(self, catalog: RecognitionAssetCatalog, *, threshold: float = rt.value("inventory.slot_count.score"), margin: float = rt.value("inventory.slot_count.margin")) -> None:
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


class _CollectedProgress:
    """Full-scan ProgressSink: every step reports the number of students collected so far."""

    def __init__(self, progress, results: list[dict[str, Any]]) -> None:
        self._progress, self._results = progress, results
        self.supports_feedback = getattr(progress, "supports_feedback", False)

    def __call__(self, _current: int, _total: int | None, message: str,
                 feedback: dict[str, Any] | None = None) -> None:
        if feedback is None:
            self._progress(len(self._results), None, message)
        else:
            self._progress(len(self._results), None, message, feedback)


class _StudentWalker:
    """Moves to the next student by arrow key, falling back to the on-screen arrow button."""

    BUTTON_X = {"right": 0.9777, "left": 0.0223}
    BUTTON_Y = 0.53465

    def __init__(self, capture, click, target, cancel: Event) -> None:
        self.capture, self.click, self.target, self.cancel = capture, click, target, cancel
        self.direction = "right"
        self.pending_button_fallback = False

    def navigate(self) -> None:
        if self.cancel.is_set():
            raise ScannerError("cancelled", "navigation cancelled")
        press_key = getattr(self.capture, "press_key", None)
        try:
            used_key = callable(press_key) and bool(press_key(self.target, self.direction))
        except ScannerError as exc:
            # Only an API failure before insertion is safe to retry as a click.
            if exc.code != "input_failed":
                raise
            used_key = False
        self.pending_button_fallback = used_key
        if not used_key:
            if self.cancel.is_set():
                raise ScannerError("cancelled", "navigation cancelled")
            self.click(self.target, self.BUTTON_X[self.direction], self.BUTTON_Y)

    def step(self) -> bool:
        if self.cancel.is_set():
            return False
        self.navigate()
        return True

    def retry_button(self) -> None:
        """A key that did not move the list is retried once with the button."""
        self.click(self.target, self.BUTTON_X[self.direction], self.BUTTON_Y)
        self.pending_button_fallback = False


class StudentMatcherAdapter:
    def __init__(
        self,
        capture: CapturePort,
        catalog: RecognitionAssetCatalog,
        *,
        threshold: float = rt.value("student.identity.template.score"),
        margin: float = rt.value("student.identity.template.margin"),
        equipment_menu: PanelMenu | None = None,
        weapon_menu: PanelMenu | None = None,
        stat_menu: PanelMenu | None = None,
        level_menu: PanelMenu | None = None,
        star_menu: PanelMenu | None = None,
        skill_menu: PanelMenu | None = None,
        answer_samples: RecognitionAnswerSampleStore | None = None,
        entry_recovery=None,
        form_recovery=None,
    ) -> None:
        self.capture = capture
        self.catalog = catalog
        self.threshold = threshold
        self.margin = margin
        self.matcher = TemplateMatcher(catalog, "student", "student-template")
        self.identity_recognizer = StudentIdentityRecognizer(catalog)
        self.entry_recovery = entry_recovery
        self.form_recovery = form_recovery
        self.regions = catalog.region("student")
        self.texture_region = self.regions.get("student_texture_region")
        if not isinstance(self.texture_region, dict):
            raise ScannerError("region_missing", "student texture region is missing")
        self.basic_recognizer = StudentBasicRecognizer(catalog)
        self.equipment_recognizer = StudentEquipmentRecognizer(catalog)
        self.equipment_menu = equipment_menu
        self.equipment_controls = getattr(equipment_menu, "controls", None) or EquipmentControlRecognizer(catalog)
        self.equipment_menu_recognizer = EquipmentMenuRecognizer(catalog) if equipment_menu is not None else None
        self.weapon_menu = weapon_menu
        self.weapon_recognizer = StudentWeaponRecognizer(catalog)
        self.stat_menu = stat_menu
        self.potential_recognizer = StudentPotentialRecognizer(catalog)
        self.level_menu = level_menu
        self.level_recognizer = StudentLevelRecognizer(catalog)
        self.star_menu = star_menu
        self.star_recognizer = StudentStarRecognizer(catalog)
        self.skill_menu = skill_menu
        self.skill_recognizer = getattr(skill_menu,"recognizer",None) or StudentSkillRecognizer(catalog)
        self.answer_samples = answer_samples
        self.session_calibration: SessionCalibrationStore | None = None

    @staticmethod
    def _numeric_groups(crops: StudentBasicCropSet) -> dict[str, tuple[Image.Image, ...]]:
        return {
            key: tuple(image.copy() for image in cells)
            for key, cells in crops.cell_groups.items()
            if key in StudentBasicCropSet.STUDIO_NUMERIC_KEYS
        }

    @staticmethod
    def _close_answer_specimens(candidates: list[dict[str, Any]]) -> None:
        for candidate in candidates:
            specimen = candidate.get("_answer_specimen")
            if not isinstance(specimen, dict):
                continue
            groups = specimen.get("numeric_groups")
            if isinstance(groups, dict):
                for cells in groups.values():
                    if isinstance(cells, tuple):
                        for image in cells:
                            if isinstance(image, Image.Image):
                                image.close()
            candidate["_answer_specimen"] = {}

    def _activate_numeric_samples(
        self, profile_id: str | None, source_size: tuple[int, int], student_ref: str
    ) -> None:
        banks = (
            self.basic_recognizer.studio_numeric_bank,
            self.equipment_recognizer.studio_numeric_bank,
        )
        for bank in banks:
            bank.clear_user_templates()
            bank.clear_session_templates()
        if self.answer_samples is not None and profile_id is not None:
            samples = self.answer_samples.load_numeric(profile_id, source_size)
            try:
                for sample in samples:
                    for bank in banks:
                        bank.add_user_template(
                            sample.roi_name, sample.digit, sample.image,
                            sample_id=sample.sample_id,
                        )
            finally:
                self.answer_samples.close(samples)
        calibration = self.session_calibration
        if calibration is None or not calibration.bind_scope(profile_id, source_size):
            return
        for sample in calibration.numeric_samples(
            profile_id=profile_id, source_size=source_size, student_ref=student_ref,
        ):
            for bank in banks:
                bank.add_session_template(
                    sample.roi_name, sample.digit, sample.image,
                    sample_id=sample.sample_id,
                )

    def _add_session_numeric_sample(
        self,
        *,
        target: dict[str, Any],
        source_size: tuple[int, int],
        student_ref: str,
        field: str,
        value: int,
        cells: tuple[Image.Image, ...] | None,
        roi_names: tuple[str, ...],
        detail_source: str,
        conflict: bool = False,
    ) -> int:
        calibration = self.session_calibration
        if calibration is None:
            return 0
        return calibration.add_numeric(
            profile_id=target.get("profile_id"),
            source_size=source_size,
            student_ref=student_ref,
            field=field,
            value=value,
            cells=cells,
            roi_names=roi_names,
            detail_source=detail_source,
            detail_panel_verified=True,
            value_confirmed=True,
            conflict=conflict,
        )

    def _clear_active_session_templates(self) -> None:
        for recognizer_name in ("basic_recognizer", "equipment_recognizer"):
            recognizer = getattr(self, recognizer_name, None)
            bank = getattr(recognizer, "studio_numeric_bank", None)
            clear = getattr(bank, "clear_session_templates", None)
            if callable(clear):
                clear()

    @staticmethod
    def _numeric_spec(field: str, value: int) -> tuple[str, str, tuple[str, ...]] | None:
        if field == "level":
            return "student_level", "basic_student_level_studio_cells", (
                "studentlevel_digit1", "studentlevel_digit2",
            )
        if field == "weapon_level":
            return "weapon_level", "basic_weapon_level_studio_cells", (
                "weaponlevel_digit1", "weaponlevel_digit2",
            )
        if field == "bond_rank":
            digits = len(str(value))
            rois = {
                1: ("affectionlevel_1digit_digit1",),
                2: ("affectionlevel_digit1", "affectionlevel_digit2"),
                3: (
                    "affectionlevel_3digit_digit1", "affectionlevel_3digit_digit2",
                    "affectionlevel_3digit_digit3",
                ),
            }.get(digits)
            return None if rois is None else (
                "relationship_rank", f"basic_relationship_rank_studio_{digits}_cells", rois,
            )
        if field in {"equip1_level", "equip2_level", "equip3_level"}:
            slot = int(field[5])
            return "equipment_level", f"basic_equipment_{slot}_level_studio_cells", (
                f"equip{slot}level_digit1", f"equip{slot}level_digit2",
            )
        return None

    def train_user_answer(
        self, profile_id: str, candidate_id: str, specimen: dict[str, Any],
        payload: dict[str, Any],
    ) -> int:
        if self.answer_samples is None:
            return 0
        source_size = specimen.get("source_size")
        groups = specimen.get("numeric_groups")
        values = payload.get("values")
        if (
            not isinstance(source_size, tuple) or len(source_size) != 2
            or not isinstance(groups, dict) or not isinstance(values, dict)
        ):
            return 0
        saved = 0
        for field in ("level", "bond_rank", "weapon_level", "equip1_level", "equip2_level", "equip3_level"):
            value = values.get(field)
            if not isinstance(value, int) or isinstance(value, bool):
                continue
            spec = self._numeric_spec(field, value)
            if spec is None:
                continue
            sample_field, group_name, roi_names = spec
            cells = groups.get(group_name)
            digits = str(value)
            if not isinstance(cells, tuple) or len(cells) < len(digits) or len(roi_names) < len(digits):
                continue
            for cell, roi_name, digit in zip(cells, roi_names, digits):
                mask = source_digit_mask(cell, sample_field)
                try:
                    if mask.getbbox() is None:
                        continue
                    sample_id = self.answer_samples.save_numeric(
                        profile_id, source_size, field=sample_field, roi_name=roi_name,
                        digit=digit, mask=mask, candidate_id=candidate_id,
                    )
                    for bank in (
                        self.basic_recognizer.studio_numeric_bank,
                        self.equipment_recognizer.studio_numeric_bank,
                    ):
                        bank.add_user_template(roi_name, digit, mask, sample_id=sample_id)
                    saved += 1
                finally:
                    mask.close()
        return saved

    @staticmethod
    def _canonical_student_ref(identity: str) -> str:
        for student_id in student_meta.all_ids():
            for form_index in student_meta.form_indexes(student_id):
                template_stem = Path(student_meta.template_path_for_form(student_id, form_index)).stem
                if template_stem == identity:
                    return student_meta.format_form_ref(student_id, form_index)
        return identity

    @staticmethod
    def _report_student_feedback(
        progress: Callable[..., None],
        current: int,
        total: int | None,
        message: str,
        student_id: str,
        field: str,
        values: dict[str, Any],
    ) -> None:
        if not getattr(progress, "supports_feedback", False):
            return
        progress(current, total, message, {
            "student_id": student_id,
            "field": field,
            "values": values,
        })

    def _capture_identified(self, target, cancel):
        recovery = self._panel_recovery()
        attempts, entered = 0, False
        while attempts < 2:
            if cancel.is_set():
                raise ScannerError('cancelled', 'identity capture cancelled')
            frame = self.capture.wait_stable(target, cancel)
            try:
                state = (self.entry_recovery.classify(frame) if self.entry_recovery is not None else
                         recovery.recognizer.classify(frame) if recovery is not None else 'basic')
                if recovery is not None:
                    recovery.state = state
                if state != 'basic':
                    frame.close()
                    if not entered and attempts == 0 and ScanContext.of(target).first_student is not False and self.entry_recovery is not None:
                        entered = True
                        self.entry_recovery.recover(target, cancel, state)
                        continue
                    raise ScannerError('panel_wrong_start', 'identity requires verified basic tab')
                attempts += 1
                identity = self.identity_recognizer.identify(frame, self.matcher, self.texture_region,
                    self._canonical_student_ref, self.threshold, self.margin)
                if identity is not None:
                    return frame, identity
            except Exception:
                frame.close()
                raise
            frame.close()
            if attempts < 2 and cancel.wait(.6):
                raise ScannerError('cancelled', 'identity retry cancelled')
        raise ScannerError('identity_unconfirmed', 'student identity unresolved after two independent captures')

    def _panel_recovery(self):
        """The shared StudentPanelRecovery behind whichever panel menus are wired."""
        return (getattr(self.weapon_menu, "recovery", None) or getattr(self.equipment_menu, "recovery", None)
                or getattr(self.stat_menu, "recovery", None) or getattr(self.level_menu, "recovery", None)
                or getattr(self.star_menu, "recovery", None) or getattr(self.skill_menu, "recovery", None))

    def _scan_current(self, target: dict[str, Any], cancel: Event, progress: Callable[..., None]) -> list[dict[str, Any]]:
        """identify -> basic reads -> panel fallbacks -> assemble, for the student on screen."""
        if cancel.is_set():
            return []
        progress(0, 4, "scanner.student.capture")
        frame, identity = self._capture_identified(target, cancel)
        if cancel.is_set():
            frame.close()
            return []
        crops = self._basic_crops(frame)
        fallback_evidence: list[dict[str, Any]] = []
        try:
            student_ref = identity.student_ref
            self._activate_numeric_samples(
                target.get("profile_id"), crops.source_size, student_ref,
            )
            progress(1, 4, "scanner.student.identify")
            if target.get("student_scan_mode") == "full":
                self._report_student_feedback(
                    progress, 1, 4, "scanner.student.identify",
                    student_ref, "student_id", {},
                )
            if cancel.is_set():
                return []
            progress(2, 4, "scanner.student.basic_fields")
            observations, independent_weapon = self._read_growth_fields(crops, student_ref, target, cancel)
            fallback_evidence = self._resolve_weapon(observations, independent_weapon, target, cancel)
            self._resolve_equipment(crops, observations, student_ref, target, cancel, progress)
            answer_specimen = {
                "source_size": crops.source_size,
                "numeric_groups": self._numeric_groups(crops),
            }
        finally:
            crops.close()
        candidate = self._assemble_student(identity, student_ref, observations, fallback_evidence, answer_specimen)
        progress(4, 4, "scanner.student.matched")
        return [candidate]

    def _basic_crops(self, frame: Image.Image) -> StudentBasicCropSet:
        """Verify the basic tab and cut every basic-screen crop; the frame is closed here."""
        try:
            recovery = self._panel_recovery()
            if recovery is not None:
                recovery.state = recovery.recognizer.classify(frame)
                if recovery.state != "basic":
                    raise ScannerError("panel_wrong_start", "student reading requires verified basic tab")
            crops = StudentBasicCropSet.from_frame(frame, self.regions)
            for key, region in self.potential_recognizer.regions["basic"].items():
                crops.images["potential_badge_"+key] = ratio_crop(frame, region)
            state_region = self.weapon_recognizer.regions.get("basic_weapon_state_region")
            if isinstance(state_region, dict):
                crops.images["basic_weapon_state_region"] = ratio_crop(frame, state_region)
            crops.images["equipment_growth_button"] = ratio_crop(frame, self.equipment_controls.regions["equipment_button"])
            return crops
        finally:
            frame.close()

    def _read_growth_fields(self, crops, student_ref, target, cancel):
        """Basic fields, then level/star/skill/potential with their own panel fallbacks, in that order."""
        observations = self.basic_recognizer.recognize(crops)
        basic_level = observations.get("level")
        observations.update(self.level_recognizer.resolve(
            observations, self.level_menu, target, cancel,
        ))
        resolved_level = observations.get("level")
        if (
            (basic_level is None or not basic_level.confirmed)
            and resolved_level is not None
            and resolved_level.confirmed
            and resolved_level.source == "level_tab_template"
        ):
            self._add_session_numeric_sample(
                target=target,
                source_size=crops.source_size,
                student_ref=student_ref,
                field="student_level",
                value=int(resolved_level.value),
                cells=crops.cell_groups.get("basic_student_level_studio_cells"),
                roi_names=("studentlevel_digit1", "studentlevel_digit2"),
                detail_source=resolved_level.source,
            )
        independent_weapon = self.weapon_recognizer.read_state(
            crops.images.get("basic_weapon_state_region"), student_star=None,
        )
        observations.update(self.star_recognizer.resolve(
            observations, independent_weapon, self.star_menu, target, cancel,
        ))
        observations.update(self.skill_recognizer.resolve(observations,self.skill_menu,target,cancel))
        observations.update(self.potential_recognizer.resolve(
            crops.images, observations, self.stat_menu, target, cancel,
        ))
        return observations, independent_weapon

    def _resolve_weapon(self, observations, independent_weapon, target, cancel) -> list[dict[str, Any]]:
        """Gate weapon fields by weapon state; open the weapon panel only for an equipped, unresolved weapon."""
        student_star = observations.get("student_star")
        observations["weapon_state"] = independent_weapon
        if student_star is not None and student_star.confirmed and int(student_star.value) < 5:
            observations["weapon_state"] = Observation(
                "no_weapon_system", 1.0, "inferred", "student_star_gate",
                f"student_star={student_star.value}",
            )
        weapon_state = observations["weapon_state"]
        fields = ("weapon_level", "weapon_star")
        if weapon_state.confirmed and weapon_state.value != "weapon_equipped":
            for field in fields:
                observations[field] = Observation(
                    None, weapon_state.confidence, "skipped",
                    "basic_weapon_state_template", f"state={weapon_state.value}",
                )
            return []
        if not (
            weapon_state.confirmed
            and weapon_state.value == "weapon_equipped"
            and not all(observations[field].confirmed for field in fields)
            and self.weapon_menu is not None
        ):
            return []
        unresolved_weapon = {field: observations[field] for field in fields if not observations[field].confirmed}
        observations.update(read_panel_fields(
            self.weapon_menu, "weapon", target, cancel, observations,
            fields, self.weapon_recognizer.recognize_menu,
            attempts=3,
        ))
        evidence = []
        for field, trigger in unresolved_weapon.items():
            result = observations.get(field)
            recovered = result is not None and result.confirmed
            evidence.append({
                "field": f"{field}_fallback",
                "status": "ok" if recovered else "uncertain",
                "source": "weapon_panel_fallback",
                "confidence": result.confidence if result is not None else 0.0,
                "note": (
                    f"trigger_status={trigger.status};trigger_source={trigger.source};"
                    f"trigger_confidence={trigger.confidence:.6f};"
                    f"trigger_note={trigger.note};result_source="
                    f"{result.source if result is not None else 'missing'}"
                ),
            })
        return evidence

    def _resolve_equipment(self, crops, observations, student_ref, target, cancel, progress) -> None:
        """Basic equipment reads, then the equipment panel for unresolved slots (learning confirmed digits)."""
        equipment_observations, unresolved = self.equipment_recognizer.recognize(
            crops,
            student_ref=student_ref,
            student_level=(
                int(observations["level"].value)
                if observations.get("level") is not None and observations["level"].confirmed
                else None
            ),
            favorite_growth_active=self.equipment_controls.read_growth(crops.images.get("equipment_growth_button")).value,
        )
        observations.update(equipment_observations)
        progress(3, 4, "scanner.student.equipment_fields")
        if not (unresolved and self.equipment_menu is not None and self.equipment_menu_recognizer is not None):
            return
        self.equipment_recognizer.metrics.menu_captures += 1
        fallback = resolve_equipment_menu(self.equipment_menu, self.equipment_menu_recognizer,
            target, cancel, observations, unresolved)
        observations.update(fallback)
        for slot in unresolved:
            learned = fallback.get(f"equip{slot}_level")
            if (
                slot <= 3
                and learned is not None
                and learned.confirmed
                and learned.source == "equipment_menu_digit"
            ):
                self._add_session_numeric_sample(
                    target=target,
                    source_size=crops.source_size,
                    student_ref=student_ref,
                    field="equipment_level",
                    value=int(learned.value),
                    cells=crops.cell_groups.get(
                        f"basic_equipment_{slot}_level_studio_cells"
                    ),
                    roi_names=(
                        f"equip{slot}level_digit1",
                        f"equip{slot}level_digit2",
                    ),
                    detail_source=learned.source,
                )

    @staticmethod
    def _evidence_rows(observations: dict[str, Observation]) -> list[dict[str, Any]]:
        return [{
            "field": field,
            "status": observation.status,
            "source": observation.source,
            "confidence": observation.confidence,
            "note": observation.note,
        } for field, observation in observations.items()]

    def _assemble_student(self, identity, student_ref, observations, fallback_evidence, answer_specimen) -> dict[str, Any]:
        kept = {field: observation for field, observation in observations.items()
                if observation.confirmed or observation.source == "panel_value_conflict"}
        values = {field: observation.value for field, observation in kept.items()}
        provenance = {"student_id": identity.source}
        provenance.update({field: observation.source for field, observation in kept.items()})
        evidence = [{
            "field": "student_id", "status": "ok",
            "source": identity.source, "confidence": identity.score,
            "note": f"margin={identity.margin:.6f};form_ref={student_ref}",
        }]
        evidence.extend(self._evidence_rows(observations))
        evidence.extend(fallback_evidence)
        evidence.extend(self._evidence_rows(self.equipment_recognizer.last_binary_shadow))
        evidence.extend(self._evidence_rows(self.equipment_recognizer.last_generated_binary_shadow))
        evidence.extend(self._evidence_rows(self.equipment_recognizer.last_position_binary_shadow))
        review_required = any(
            observation.status not in {"ok", "inferred", "skipped"}
            for observation in observations.values()
        )
        return {
            "payload": {"version": 1, "student_id": student_ref, "values": values, "provenance": provenance},
            "evidence": evidence,
            "review_required": review_required,
            "_answer_specimen": answer_specimen,
        }

    def _scan_with_forms(self, target, cancel, progress):
        rows = self._scan_current(target, cancel, progress)
        if not rows or getattr(self, 'form_recovery', None) is None:
            return rows
        original = rows[0]
        original_ref = original['payload']['student_id']
        base, _ = student_meta.split_form_ref(original_ref)
        if not student_meta.is_multi_form(base) or base in (ScanContext.of(target).seen_students or ()):
            return rows
        combat = {'combat_hp': ('hp', 4), 'combat_atk': ('atk', 2),
                  'combat_def': ('def', 1), 'combat_heal': ('heal', 2)}
        def read_form(frame, identity):
            form_ref = identity.student_ref
            crops = StudentBasicCropSet.from_frame(frame, self.regions)
            try:
                observations = {key: self.basic_recognizer.read_combat(
                    crops.cell_groups.get(f'basic_combat_{group}_digits'), group, minimum)
                    for key, (group, minimum) in combat.items()}
            finally:
                crops.close()
            # Shared growth values are safe; combat values and training specimens are not shared.
            payload = original['payload']
            values = {k: v for k, v in payload['values'].items() if k not in combat}
            provenance = {k: v for k, v in payload['provenance'].items() if k not in combat}
            provenance['student_id'] = 'student_form_verified'
            evidence = [dict(e) for e in original['evidence'] if e['field'] not in {*combat, 'student_id'}]
            evidence.append(dict(field='student_id', status='ok', source='student_form_verified',
                                 confidence=identity.score, note=f'form_ref={form_ref};margin={identity.margin:.6f}'))
            for key, observation in observations.items():
                if observation.confirmed:
                    values[key] = observation.value
                    provenance[key] = observation.source
                evidence.append(dict(field=key, status=observation.status, source=observation.source,
                                     confidence=observation.confidence, note=observation.note))
            rows.append(dict(payload=dict(version=1, student_id=form_ref, values=values, provenance=provenance),
                evidence=evidence, review_required=original['review_required'] or any(not o.confirmed for o in observations.values())))
        try:
            self.form_recovery.collect(target, cancel, original_ref, self._capture_identified, read_form)
        except Exception as exc:
            error = exc if isinstance(exc, ScannerError) else ScannerError('form_read_failed', str(exc))
            if (error.details.get('form_restored') and error.code in {'form_unconfirmed', 'region_missing',
                    'form_read_failed', 'identity_unconfirmed', 'capture_failed', 'capture_timeout'} and not cancel.is_set()):
                original['evidence'].append(dict(field='student_forms', status='partial', source='student_form_recovery',
                    confidence=0.0, note=error.code+';original form restored'))
                original['review_required'] = True
                return rows
            error.completed_candidates = rows
            raise error
        return rows

    def __call__(self, target: dict[str, Any], cancel: Event, progress: Callable[..., None]) -> list[dict[str, Any]] | ScanBatchResult:
        target = ScanContext.of(target).replace(cancel=cancel)
        session_id = str(target.session_id or "standalone")
        generation = target.generation if target.generation is not None else 1
        self.session_calibration = SessionCalibrationStore(
            session_id,
            int(generation) if isinstance(generation, int) and not isinstance(generation, bool) else 1,
        )
        try:
            if target.get("student_scan_mode", "single") != "full":
                try:
                    return self._scan_with_forms(target, cancel, progress)
                except ScannerError as exc:
                    if not hasattr(exc, 'completed_candidates'):
                        raise
                    return ScanBatchResult(
                        exc.completed_candidates,
                        'cancelled' if cancel.is_set() or exc.code == 'cancelled' else 'failed',
                        exc,
                    )
            results: list[dict[str, Any]] = []
            try:
                complete = self._scan_full(target, cancel, progress, results)
                return ScanBatchResult(
                    results, "cancelled" if cancel.is_set() else "completed",
                    screen_state="unknown", coverage_complete=complete,
                )
            except Exception as exc:
                error = exc if isinstance(exc, ScannerError) else ScannerError("matcher_failed", str(exc))
                return ScanBatchResult(
                    results,
                    "cancelled" if cancel.is_set() or error.code == "cancelled" else "failed",
                    error,
                )
        finally:
            self._clear_active_session_templates()
            if self.session_calibration is not None:
                self.session_calibration.close()
            self.session_calibration = None

    def _scan_full(self, target, cancel, progress, results) -> bool:
        """Walk the student list until the first student comes around again (True) or the walk stops."""
        click = getattr(self.capture, "click", None)
        if not callable(click):
            raise ScannerError("input_unavailable", "full student scan requires click input")
        walker = _StudentWalker(self.capture, click, target, cancel)
        seen: set[str] = set()
        previous_student_id: str | None = None
        for _index in range(500):
            if cancel.is_set():
                break
            scanned = self._scan_full_student(target, cancel, progress, results, seen)
            if scanned is None:
                break
            student_id, rows = scanned
            if student_id in seen:
                self._close_answer_specimens(rows)
                action = self._revisit(walker, student_id, previous_student_id, progress, results)
                if action == "complete":
                    return True
                if action == "break":
                    break
                if action == "moved":
                    previous_student_id = student_id
                continue
            seen.add(student_id)
            previous_student_id = student_id
            results.extend(rows)
            progress(len(results), None, "scanner.student.full.collected")
            if not walker.step():
                break
            progress(len(results), None, "scanner.student.full.navigating")
            if cancel.wait(0.45):
                break
        else:
            raise ScannerError("navigation_limit", "student navigation budget exhausted")
        return False

    def _scan_full_student(self, target, cancel, progress, results, seen):
        """Scan the student on screen; (base student id, rows), or None when cancelled without a candidate."""
        current_progress = _CollectedProgress(progress, results)
        try:
            scanned = self._scan_with_forms(ScanContext.of(target).replace(first_student=not seen, seen_students=tuple(seen)), cancel, current_progress)
        except ScannerError as exc:
            results.extend(getattr(exc, 'completed_candidates', []))
            raise
        if not scanned:
            if cancel.is_set():
                return None
            raise ScannerError("identity_unconfirmed", "student capture returned no candidate")
        student_id = scanned[0].get("payload", {}).get("student_id")
        if not isinstance(student_id, str):
            self._close_answer_specimens(scanned)
            raise ScannerError("matcher_failed", "student candidate identity is missing")
        if any(e.get("field") == "student_id" and e.get("status") != "ok"
               for item in scanned for e in item.get("evidence", [])):
            self._close_answer_specimens(scanned)
            raise ScannerError("identity_unconfirmed", "student identity is not confirmed")
        student_id, _form = student_meta.split_form_ref(student_id)
        return student_id, scanned

    @staticmethod
    def _revisit(walker: "_StudentWalker", student_id, previous_student_id, progress, results) -> str:
        """Decide what an already-seen student means: retry, reverse, completion or a plain move."""
        cancel = walker.cancel
        if student_id == previous_student_id and walker.pending_button_fallback:
            progress(len(results), None, "scanner.student.full.navigation_retry")
            if cancel.is_set():
                return "break"
            walker.retry_button()
            return "break" if cancel.wait(0.45) else "retried"
        if student_id == previous_student_id and walker.direction == "right":
            walker.direction = "left"
            progress(
                len(results), None,
                "scanner.student.full.navigation_reverse",
            )
            if not walker.step():
                return "break"
            return "break" if cancel.wait(0.45) else "reversed"
        if student_id == previous_student_id:
            raise ScannerError("navigation_unconfirmed", "no movement after key/button; edge is not verified")
        if walker.direction == "right":
            progress(
                len(results), len(results),
                "scanner.student.full.complete",
            )
            return "complete"
        if not walker.step():
            return "break"
        progress(len(results), None, "scanner.student.full.navigating")
        return "break" if cancel.wait(0.45) else "moved"


# Pre-C1 inventory evidence names, kept so old diagnostic JSON reads with current meaning.
LEGACY_INVENTORY_EVIDENCE_SOURCES = {"detail_template_fallback": "grid_same_crop_rematch"}


def canonical_inventory_evidence(evidence: list[dict[str, Any]], entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Rename pre-C1 inventory evidence to the current field/source contract."""
    result = []
    for item in evidence:
        item = dict(item)
        item["source"] = LEGACY_INVENTORY_EVIDENCE_SOURCES.get(item.get("source"), item.get("source"))
        note = str(item.get("note", ""))
        if item.get("field") == "scroll_overlap" and item["source"] == "verified_row_overlap" and ";reason=" in note:
            item["source"] = note.rsplit(";reason=", 1)[1]
        field = str(item.get("field", ""))
        if item["source"] == "verified_profile_zero_fill" and field.startswith("entries[") and field.endswith("].quantity"):
            position = field[len("entries["):-len("].quantity")]
            if position.isdigit() and int(position) < len(entries):
                item["field"] = f"zero_fill[{entries[int(position)]['key']}].quantity"
        result.append(item)
    return result


# Detail read failures that stay per-slot partial once the original selection is verified.
DETAIL_RECOVERABLE_CODES = frozenset({"inventory_detail_unconfirmed", "capture_timeout", "capture_failed"})


@dataclass(slots=True)
class _SlotReading:
    """One slot's identity/quantity observation before it becomes an entry."""
    index: int
    identity: str | None
    score: float
    margin: float
    source: str
    status: str
    quantity: str | None
    count_score: float
    count_source: str
    note: str
    profile_confirmed: bool
    detail_identity: bool = False
    detail_read: bool = False


@dataclass
class _InventoryScan:
    """Mutable state of one inventory scan, owned by InventoryMatcherAdapter.__call__."""
    frame: Image.Image
    source_size: tuple[int, int]
    target: dict[str, Any]
    slots: list[dict[str, Any]]
    source_kind: str | None = None
    prepared: Any = None
    allowed_ids: set[str] | None = None
    entries: list[dict[str, Any]] = field(default_factory=list)
    evidence: list[dict[str, Any]] = field(default_factory=list)
    slot_crops: dict[int, Image.Image] = field(default_factory=dict)
    observed_profile_ids: list[str] = field(default_factory=list)
    review_required: bool = False
    coverage_complete: bool = False
    offset: float = 0.0
    read_until: int = -1
    gutter_calibration: float | None = None
    rows_per_move: int = 1
    row_centering: float = 0.0
    first_page: Image.Image | None = None
    seen_crops: dict[int, Image.Image] = field(default_factory=dict)
    selected_index: int | None = None
    bank: Any = None
    order: dict[str, int] = field(default_factory=dict)
    bank_guesses: dict[int, Any] = field(default_factory=dict)
    bank_anchors: set[int] = field(default_factory=set)
    bank_stats: dict[str, int] = field(default_factory=lambda: {"confident": 0, "order_prior": 0, "order_conflict": 0,
                                                                 "unknown_new": 0, "skipped_detail": 0, "agree": 0,
                                                                 "disagree": 0, "learned": 0, "count_read": 0,
                                                                 "count_checked": 0, "count_agree": 0, "count_disagree": 0,
                                                                 "numeric_synth_checked": 0, "numeric_synth_agree": 0})
    unknown_new: set[int] = field(default_factory=set)
    allow_synth: bool = False
    count_bank: Any = None
    glyph_seeds: dict[int, Any] = field(default_factory=dict)
    detail_confirmed: list[tuple[str, Image.Image]] = field(default_factory=list)
    completed: bool = False
    page_open: bool = False
    input_stopped: ScannerError | None = None

    def skip(self, index: int, confidence: float, note: str) -> None:
        self.evidence.append({"field": f"slots[{index}]", "status": "skipped",
                              "source": "inventory_profile_catalog", "confidence": confidence, "note": note})

    def candidate(self, evidence: list[dict[str, Any]], review_required: bool) -> dict[str, Any]:
        return {
            "payload": {"version": 1, "catalog_revision": CATALOG_REVISION, "entries": self.entries},
            "evidence": evidence,
            "review_required": review_required,
            "_answer_specimen": {"source_size": self.source_size, "slot_crops": self.slot_crops},
        }


class InventoryMatcherAdapter:
    def __init__(self, capture: CapturePort, catalog: RecognitionAssetCatalog, *, threshold: float = rt.value("inventory.grid_icon.score"), margin: float = rt.value("inventory.grid_icon.margin"), max_pages: int = 60, answer_samples: RecognitionAnswerSampleStore | None = None, detail_recovery=None, navigation=None, synth_provider=None) -> None:
        self.capture = capture
        self.catalog = catalog
        self.threshold = threshold
        self.margin = margin
        self.max_pages = max_pages
        self.matcher = TemplateMatcher(catalog, "inventory", "inventory-template")
        self.count_matcher = SlotCountMatcher(catalog)
        self.answer_samples = answer_samples
        self.detail_recovery = detail_recovery
        self.synth_provider = synth_provider
        self.navigation = navigation
        regions = catalog.region("inventory").get("item", {})
        self.slots = regions.get("grid_slots")
        if not isinstance(self.slots, list) or not self.slots:
            raise ScannerError("region_missing", "inventory grid slots are missing")

    def __call__(self, target: dict[str, Any], cancel: Event, progress: Callable[[int, int | None, str], None]) -> list[dict[str, Any]] | ScanBatchResult:
        target = ScanContext.of(target).replace(cancel=cancel)
        frame = self.capture.wait_stable(target, cancel)
        scan = _InventoryScan(frame=frame, source_size=frame.size, target=target, slots=self.slots)
        try:
            self._prepare_scan(scan, cancel)
            for page in range(self.max_pages):
                self._read_page(scan, page, cancel, progress)
                if not self._advance_page(scan, cancel):
                    break
            candidates = self._finalize(scan)
            scan.completed = True
            return candidates
        except Exception as exc:
            return self._interrupted(scan, exc, cancel)
        finally:
            scan.frame.close()
            if scan.first_page is not None:
                scan.first_page.close()
            for crop in scan.seen_crops.values():
                crop.close()
            for _identity, crop in scan.detail_confirmed:
                crop.close()
            if not scan.completed:
                for crop in scan.slot_crops.values():
                    crop.close()

    def _prepare_scan(self, scan: "_InventoryScan", cancel: Event) -> None:
        detail_port = getattr(self, 'detail_recovery', None)
        navigation = getattr(self, 'navigation', None)
        if detail_port is not None:
            scan.source_kind = detail_port.recognizer.classify(scan.frame)
            if scan.source_kind is None:
                raise ScannerError('inventory_page_unknown', 'inventory detail input requires a verified item/equipment page')
            scan.slots = detail_port.recognizer.regions['sources'][scan.source_kind]['grid_slots']
        if navigation is not None:
            scan.prepared = navigation.prepare(scan.target, cancel, scan.frame)
            scan.frame.close()
            scan.frame = self.capture.wait_stable(scan.target, cancel)
            scan.source_kind = scan.prepared.source
            scan.target = scan.target.replace(inventory_scan_profile=scan.prepared.profile_id)
            scan.gutter_calibration = self._gutter_phase(scan, 0.0)
            # C5e-1 (E6): move one row less than the fully readable rows, so one read row overlaps.
            first_rows = {index // 5 for index in navigation.page_slots(scan.source_kind, 0.0)}
            scan.rows_per_move = max(1, len(first_rows) - 1)
            scan.row_centering = navigation.row_centering(scan.source_kind)
            scan.first_page = scan.frame.copy()
        self._load_answer_samples(scan.target.get("profile_id"), scan.source_size)
        if scan.prepared is not None:
            scan.allowed_ids = {row.item_id for row in CATALOG if row.profile_id == scan.prepared.profile_id}
            scan.order = {row.item_id: row.order_index for row in CATALOG if row.profile_id == scan.prepared.profile_id}
            scan.bank = self._tile_bank(scan.source_size)
            scan.count_bank = self.__dict__.setdefault("count_banks", {}).setdefault(
                tuple(scan.source_size), CountBank(scale=scan.source_size[1] / 720))
            self._load_synth(scan)

    def _tile_bank(self, source_size: tuple[int, int]) -> TileBank:
        """C5e-2 session bank for this client size; it outlives one scan so later scans start from it."""
        banks = self.__dict__.setdefault("tile_banks", {})
        return banks.setdefault(tuple(source_size), TileBank())

    def _synth_guard(self) -> SynthDriftGuard:
        return self.__dict__.setdefault("synth_guard", SynthDriftGuard())

    def _load_synth(self, scan: "_InventoryScan") -> None:
        """C5e-6c: the synthetic tier below the session bank, for D16-gated profiles only."""
        provider = getattr(self, "synth_provider", None)
        profile = scan.prepared.profile_id
        if provider is None:
            return
        if profile not in SYNTH_ENABLED_PROFILES:
            # Count glyph seeds do not depend on the tile gate (C5e-3); the tiles stay out of the bank.
            try:
                scan.glyph_seeds = dict(provider(profile, scan.source_size).glyphs)
            except SynthUnavailable:
                pass
            return
        if not self._synth_guard().enabled(profile):
            scan.evidence.append({"field": "synth_tier", "status": "uncertain", "source": "synth_bank", "confidence": 0.0,
                                  "note": f"profile={profile};disabled after synth_drift_detected"})
            return
        try:
            templates = provider(profile, scan.source_size)
        except SynthUnavailable as exc:
            scan.evidence.append({"field": "synth_tier", "status": "uncertain", "source": "synth_bank", "confidence": 0.0,
                                  "note": f"profile={profile};unavailable;{exc.reason}"})
            return
        for identity, tile in templates.tiles.items():
            scan.bank.add_synth(identity, tile)
        scan.glyph_seeds = dict(templates.glyphs)
        scan.allow_synth = True
        scan.evidence.append({"field": "synth_tier", "status": "ok", "source": "synth_bank", "confidence": 1.0,
                              "note": f"profile={profile};tiles={len(templates.tiles)}"})

    def _load_answer_samples(self, profile_id: object, source_size: tuple[int, int]) -> None:
        if self.answer_samples is None or not isinstance(profile_id, str):
            self.matcher.replace_user_templates([])
            return
        samples = self.answer_samples.load_inventory(profile_id, source_size)
        try:
            self.matcher.replace_user_templates([
                (sample.sample_id, sample.item_id, sample.image) for sample in samples
            ])
            # User-approved tile samples (D1) are the bank's persistent tier.
            bank = self._tile_bank(source_size)
            for sample in samples:
                bank.add(sample.item_id, sample.image, "user_confirmed")
        finally:
            self.answer_samples.close(samples)

    def _visible_slots(self, scan: "_InventoryScan", page: int) -> dict[int, dict[str, Any]]:
        """Content index -> slot region on the current frame.

        With navigation the rows follow the measured scroll offset (C5), so an index names the same
        tile on every page; the navigation-free fallback keeps one fixed grid per page.
        """
        navigation = getattr(self, 'navigation', None)
        if navigation is not None and scan.prepared is not None:
            return navigation.page_slots(scan.source_kind, scan.offset)
        return {page * len(scan.slots) + position: slot for position, slot in enumerate(scan.slots)}

    def _read_page(self, scan: "_InventoryScan", page: int, cancel: Event, progress) -> None:
        page_ids: list[str] = []
        page_unresolved = False
        visible = self._visible_slots(scan, page)
        slots = [visible[index] for index in sorted(visible)]
        unread = [index for index in visible if index > scan.read_until]
        if scan.prepared is not None and unread and min(unread) != scan.read_until + 1:
            # A tile row that was never fully visible would otherwise be skipped silently.
            raise ScannerError("inventory_scroll_unverified", f"rows skipped: next visible index {min(unread)} after {scan.read_until}")
        self._match_page_bank(scan, visible)
        try:
            for position, index in enumerate(sorted(visible)):
                if index <= scan.read_until:
                    continue
                if cancel.is_set():
                    raise ScannerError("cancelled", "inventory scan cancelled")
                crop = ratio_crop(scan.frame, visible[index])
                try:
                    if scan.prepared is not None and image_has_visible_content(crop):
                        scan.seen_crops[index] = crop.copy()
                    reading = self._read_slot(scan, index, position, slots, crop, cancel)
                    if reading is not None and self._record_entry(scan, reading, crop):
                        if isinstance(reading.identity, str):
                            page_ids.append(reading.identity)
                        if reading.status != 'ok' or reading.quantity is None:
                            page_unresolved = True
                        progress(len(scan.entries), None, "scanner.inventory.grid")
                finally:
                    crop.close()
                if scan.input_stopped is not None:
                    # C5d: an unconfirmed selection already made its verified return; no further input.
                    raise scan.input_stopped
            if scan.page_open:
                # C5e-1: the last verified selection sits in the bottom rows and stays visible after the
                # next ~one-row drag, so a completed page keeps it instead of returning (no anchor click).
                scan.page_open = False
                self.detail_recovery.end_page(scan.target, keep_selection=True)
        finally:
            if scan.page_open:
                scan.page_open = False
                self.detail_recovery.end_page(scan.target)
        if visible:
            scan.read_until = max(scan.read_until, max(visible))
            # Only the rows a move can keep on screen are needed for the next overlap check.
            for index in [index for index in scan.seen_crops if index < scan.read_until - 10 * 5]:
                scan.seen_crops.pop(index).close()
        if scan.prepared is not None:
            # D23: order is judged once per scan at the end (longest increasing run); a page out of order only
            # withholds the verified-profile flag that permits grid-count fallbacks.
            ordered_page = bool(page_ids) and self.navigation.verify_profile_order(scan.prepared.profile_id, page_ids)
            scan.observed_profile_ids.extend(page_ids)
            scan.target = scan.target.replace(inventory_profile_verified=ordered_page and not page_unresolved)

    def _match_page_bank(self, scan: "_InventoryScan", visible: dict[int, dict[str, Any]]) -> None:
        """C5e-2 pass 1: match every new tile against the bank; confident tiles in catalog order are anchors."""
        scan.bank_guesses, scan.bank_anchors = {}, set()
        if scan.bank is None or not len(scan.bank):
            return
        previous = self._last_confirmed_order(scan)
        candidates = self._bank_candidates(scan, scan.allowed_ids)
        for index in sorted(visible):
            if index <= scan.read_until:
                continue
            with ratio_crop(scan.frame, visible[index]) as crop:
                if not image_has_visible_content(crop):
                    continue
                guess = scan.bank.match(crop, candidates, allow_synth=scan.allow_synth)
            scan.bank_guesses[index] = guess
            order = scan.order.get(guess.identity)
            # An anchor must continue the sorted order; a confident tile out of order goes to the detail panel.
            if guess.confident and order is not None and (previous is None or order > previous):
                scan.bank_anchors.add(index)
                previous = order

    @staticmethod
    def _learn_count(scan: "_InventoryScan", crop: Image.Image, quantity: str) -> None:
        """Check the grid read against the detail quantity (evidence), then learn the label's glyphs."""
        bank, stats = scan.count_bank, scan.bank_stats
        if scan.glyph_seeds and not bank.seed:
            bank.set_seeds(scan.glyph_seeds)
        if quantity.isdigit() and int(quantity) < 10000:
            if bank.ready():
                read = bank.read(crop)
                stats["count_checked"] += 1
                if read.confident:
                    stats["count_agree" if read.value == quantity else "count_disagree"] += 1
            if bank.seed:
                # D20: synthetic digits are evidence only until the profile passes the numeric gate.
                seed_read = bank.read(crop, use_seed=True)
                stats["numeric_synth_checked"] += 1
                stats["numeric_synth_agree"] += seed_read.value == quantity
        bank.learn(crop, quantity)

    @staticmethod
    def _bank_candidates(scan: "_InventoryScan", pool) -> set[str]:
        """Bank candidates for a new tile: each item appears once in the list, so identities already recorded
        in this scan cannot be it (live first scans: 14 of 14 confident wrong matches were such identities)."""
        recorded = {entry["item_id"] for entry in scan.entries}
        return set(pool if pool is not None else scan.bank.entries) - recorded

    @staticmethod
    def _last_confirmed_order(scan: "_InventoryScan") -> int | None:
        for entry in reversed(scan.entries):
            if entry.get("observed_slot") is not None and entry["item_id"] in scan.order:
                return scan.order[entry["item_id"]]
        return None

    def _bank_identity(self, scan: "_InventoryScan", index: int, crop: Image.Image) -> "Any | None":
        """C5e-2 pass 2: a confident bank identity for this tile, using the order prior when needed."""
        guess = scan.bank_guesses.get(index)
        if guess is None:
            return None
        if index in scan.bank_anchors:
            scan.bank_stats["confident"] += 1
            return guess
        low = self._last_confirmed_order(scan)
        later = [scan.order[scan.bank_guesses[i].identity] for i in sorted(scan.bank_anchors) if i > index]
        high = later[0] if later else None
        if low is None and high is None:
            return None
        overall, between = scan.bank.match_between(crop, self._bank_candidates(scan, scan.allowed_ids), scan.order, low, high,
                                                   scan.allow_synth)
        # The best candidate overall must itself lie between the neighbours; otherwise the detail panel decides.
        if between.confident and overall.identity == between.identity:
            scan.bank_stats["order_prior"] += 1
            return between
        # D23: the prior only narrows. A tile that confidently looks like a banked item (any profile) which
        # cannot sit between its neighbours is an order conflict; either way the detail panel decides.
        full = scan.bank.match(crop, self._bank_candidates(scan, None), allow_synth=scan.allow_synth)
        order = scan.order.get(full.identity)
        if full.confident and (order is None or (low is not None and order <= low) or (high is not None and order >= high)):
            scan.bank_stats["order_conflict"] += 1
        return None

    def _read_slot(self, scan: "_InventoryScan", index: int, position: int, slots: list[dict[str, Any]],
                   crop: Image.Image, cancel: Event) -> "_SlotReading | None":
        """Match one visible slot, consult the detail panel when needed and apply the profile gate."""
        if not image_has_visible_content(crop):
            return None
        detail_port = getattr(self, 'detail_recovery', None)
        allowed = scan.allowed_ids
        profile_confirmed = allowed is None
        # Bundled icon art does not match current-client tiles (C5 live: tech notes all rank as one icon,
        # equipment ranks as its blueprint piece), so a profile scan with a detail panel never skips or
        # labels from the grid alone: identity and membership come from the detail panel.
        detail_required = scan.prepared is not None and detail_port is not None
        banked = self._bank_identity(scan, index, crop) if detail_required else None
        # On the item page the verified category filter is the membership evidence, but only when the
        # detail panel names the tile; without it the F12 gate below still applies.
        category_filtered = detail_required and scan.prepared.source == "item"
        profile_confirmed = profile_confirmed or category_filtered
        if allowed is not None and not detail_required:
            global_match = self.matcher.match(
                crop, center_trim=0.15, prefer_user=True,
                threshold=self.threshold, margin=self.margin,
            )
            # A near-tie with an outside identity is not evidence of membership either way (C0-1):
            # it falls through to profile-restricted matching and the detail panel.
            if (global_match.score >= rt.value("inventory.profile_gate.outside_score")
                    and global_match.margin >= self.margin and global_match.identity not in allowed):
                scan.skip(index, global_match.score, "confident visible identity is outside the explicit scan profile")
                return None
            profile_confirmed = (
                global_match.score >= self.threshold
                and global_match.margin >= self.margin
                and global_match.identity in allowed
            )
        fast = self.matcher.match(
            crop, center_trim=0.15, prefer_user=True,
            threshold=self.threshold, margin=self.margin,
            allowed_identities=allowed,
        )
        fast_confident = fast.score >= self.threshold and fast.margin >= self.margin
        match = fast if fast_confident else self.matcher.match(crop, allowed_identities=allowed)
        source = (
            "user_confirmed_grid_sample" if match.source == "user_confirmed"
            else "grid_icon_template" if fast_confident else "grid_same_crop_rematch"
        )
        if match.score < rt.value("inventory.grid_icon.floor_without_detail") and detail_port is None:
            return None
        confident = match.score >= self.threshold and match.margin >= self.margin
        count = self.count_matcher.match(crop)
        count_source = 'slot_count_glyph'
        count_bank = getattr(scan, "count_bank", None)
        if count.value is None and count_bank is not None and count_bank.ready():
            # C5e-3: the session glyph bank reads the current client's labels (the v6 glyphs never do).
            read = count_bank.read(crop)
            if read.confident:
                count, count_source = CountMatch(read.value, read.score, read.margin), read.source
                scan.bank_stats["count_read"] += 1
        reading = _SlotReading(
            index=index, identity=match.identity, score=match.score, margin=match.margin, source=source,
            status='ok' if confident else 'uncertain', quantity=count.value, count_score=count.score,
            count_source=count_source, note=f'margin={count.margin:.6f}', profile_confirmed=profile_confirmed,
        )
        if banked is not None and count.value is not None:
            # C5e-2 fast path: a banked identity with a confident grid count needs no detail panel.
            reading.identity, reading.score, reading.margin = banked.identity, banked.score, banked.margin
            # A slot confirmed by a synthetic tile alone is recorded as such (C5e-6 principle).
            reading.source = "synth_bank" if banked.tier == "synth" else f"tile_bank_{banked.tier}"
            reading.status, reading.detail_identity = "ok", True
            reading.profile_confirmed = banked.identity in (scan.allowed_ids or ())
            scan.bank_stats["skipped_detail"] += 1
        elif detail_port is not None and (detail_required or not (fast_confident and count.value is not None)):
            self._apply_detail(scan, reading, position, slots, match, count, confident, cancel)
            if detail_required and reading.detail_identity and reading.source == "inventory_detail_template":
                if banked is not None:
                    scan.bank_stats["agree" if banked.identity == reading.identity else "disagree"] += 1
                if scan.bank is not None:
                    scan.bank.add(reading.identity, crop)
                    scan.bank_stats["learned"] += 1
                if scan.count_bank is not None and reading.quantity:
                    self._learn_count(scan, crop, reading.quantity)
                    if scan.allow_synth:
                        scan.detail_confirmed.append((reading.identity, crop.copy()))
        if detail_required and not reading.detail_identity:
            # Never record a grid-guessed identity on a profile scan: keep the slot as unresolved evidence.
            # D23: a tile the detail panel read but could not name is not a catalog item (new, or not yet in the
            # catalog like blueprint pieces); it waits for labeling (6e). A failed read is not a new item.
            flag = ""
            if reading.detail_read:
                scan.unknown_new.add(index)
                scan.bank_stats["unknown_new"] += 1
                flag = "unknown_new;"
            scan.evidence.append({"field": f"slots[{index}]", "status": "partial", "source": "inventory_detail_panel",
                                  "confidence": 0.0, "note": f"{flag}identity unresolved by detail panel;{reading.note}"})
            scan.review_required = True
            return None
        if allowed is not None and reading.identity not in allowed:
            scan.skip(index, reading.score, "visible identity is outside the explicit scan profile")
            return None
        if not reading.profile_confirmed:
            scan.skip(index, reading.score, "profile membership was not positively verified")
            return None
        return reading

    def _apply_detail(self, scan: "_InventoryScan", reading: "_SlotReading", position: int, slots: list[dict[str, Any]],
                      match: Match, count: CountMatch, confident: bool, cancel: Event) -> None:
        if not scan.page_open:
            # C5d batch selection: one page session, slots selected in order, one verified return at the end.
            self.detail_recovery.begin_page(scan.target, cancel, scan.frame, slots)
            scan.page_open = True
        outcome = self.detail_recovery.read(
            scan.target, cancel, position, reading.identity, count.value, confident,
            profile_verified=scan.target.inventory_profile_verified is True,
            scan_profile=scan.target.get('inventory_scan_profile'))
        if not outcome.stop:
            scan.selected_index = reading.index
        if outcome.failure is not None:
            if outcome.failure.code not in DETAIL_RECOVERABLE_CODES:
                raise outcome.failure
            if outcome.stop:
                # The session made its verified return already; this slot is partial and input stops.
                scan.page_open = False
                scan.input_stopped = outcome.failure
                reading.note = outcome.failure.code + ';original selection restored;input stopped'
            else:
                reading.note = outcome.failure.code + ';selection confirmed;detail unread'
            reading.status = 'partial'
            return
        reading.detail_read = True
        detail = outcome.detail
        reading.detail_identity = detail.identity is not None
        if detail.identity is not None:
            reading.identity, reading.score, reading.margin = detail.identity, detail.score, detail.margin
            reading.source, reading.status = detail.source, 'ok'
            if detail.source == 'verified_grid_detail_fallback':
                reading.score, reading.margin = match.score, match.margin
        if detail.source == 'inventory_detail_conflict':
            reading.status, reading.quantity, reading.count_source = 'conflict', None, detail.source
        elif detail.identity is not None:
            reading.quantity, reading.count_score, reading.count_source = detail.count.value, detail.count.score, detail.count.source
            if detail.count.source == 'verified_grid_count_fallback':
                reading.count_score = count.score
        else:
            reading.quantity, reading.status = None, 'partial'
        reading.note = detail.count.reason
        if detail.identity is not None and scan.allowed_ids is not None:
            reading.profile_confirmed = detail.identity in scan.allowed_ids

    @staticmethod
    def _record_entry(scan: "_InventoryScan", reading: "_SlotReading", crop: Image.Image) -> bool:
        previous = next((entry for entry in scan.entries if entry["item_id"] == reading.identity), None)
        if previous is not None:
            if scan.prepared is not None and previous["observed_slot"] != reading.index:
                # Every tile is read once by content index, so one identity at two indices means the
                # page's rows were mapped to the wrong content rows (C5e-1 live: a one-row shift alias).
                raise ScannerError("inventory_scroll_unverified",
                                   f"{reading.identity} seen at slots {previous['observed_slot']} and {reading.index}")
            return False
        scan_profile = scan.prepared.profile_id if scan.prepared is not None else None
        scan.entries.append({"key": reading.identity, "quantity": reading.quantity, "item_id": reading.identity,
                             "name": None, "observed_slot": reading.index,
                             "profile_id": scan_profile if scan_profile is not None else "visible-grid",
                             "inventory_scan_profile": scan_profile})
        scan.slot_crops[reading.index] = crop.copy()
        quantity_confident = reading.quantity is not None
        scan.evidence.extend([
            {"field": f"entries[{reading.index}].item_id", "status": reading.status, "source": reading.source,
             "confidence": reading.score, "note": f"margin={reading.margin:.6f}"},
            {"field": f"entries[{reading.index}].quantity", "status": "ok" if quantity_confident else "uncertain",
             "source": reading.count_source, "confidence": reading.count_score, "note": reading.note},
        ])
        scan.review_required = scan.review_required or reading.status != 'ok' or not quantity_confident
        return True

    def _advance_page(self, scan: "_InventoryScan", cancel: Event) -> bool:
        """Move to the next page; False ends the page loop.

        With navigation the list end is two drags without measured motion after the last rows were
        read, so a residual tail page is always followed by a no-motion check (X07, C2-2).
        """
        navigation = getattr(self, 'navigation', None)
        if navigation is None and len(scan.entries) >= len(self.matcher.templates):
            scan.coverage_complete = True
            return False
        if cancel.is_set():
            raise ScannerError("cancelled", "inventory scan cancelled")
        if navigation is None:
            return self._wheel_page(scan, cancel)
        moved = navigation.advance(scan.target, cancel, scan.frame, scan.source_kind, 
            self.navigation.page_distance(scan.source_kind, scan.offset, scan.rows_per_move, scan.row_centering))
        shift_px = round(moved.shift * scan.source_size[1])
        requested = getattr(moved, "requested", None)
        requested_note = "" if requested is None else f";requested_px={requested * scan.source_size[1]:.1f}"
        scan.evidence.append({"field": "scroll_overlap", "status": "ok", "source": moved.reason,
            "confidence": 1.0, "note": f"shift_px={shift_px};reason={moved.reason}{requested_note}"})
        if moved.terminal:
            moved.frame.close()
            self._require_tail_read(scan)
            scan.coverage_complete = True
            return False
        scan.offset += moved.shift
        scan.frame.close()
        scan.frame = moved.frame
        self._align_to_gutters(scan, cancel)
        self._verify_overlap(scan)
        return True

    def _require_tail_read(self, scan: "_InventoryScan") -> None:
        """At the verified end, a filled tile that never became readable is a coverage gap, not an end."""
        clipped = self.navigation.page_slots(scan.source_kind, scan.offset, readable=False)
        for index in sorted(clipped):
            if index <= scan.read_until:
                continue
            with ratio_crop(scan.frame, clipped[index]) as crop:
                if image_has_visible_content(crop):
                    raise ScannerError("inventory_scroll_unverified", f"tile {index} is filled but never readable at the list end")

    def _gutter_phase(self, scan: "_InventoryScan", calibration: float) -> float | None:
        """Median row-phase error of the gutters that agree with it, or None with fewer than two (C5e-1)."""
        errors = self.navigation.phase_residuals(scan.frame, scan.source_kind, scan.offset, calibration)
        if len(errors) < 2:
            return None
        middle = median(errors)
        tolerance = rt.value("inventory.gutter.agreement") * scan.source_size[1]
        agreeing = [error for error in errors if abs(error - middle) <= tolerance]
        return median(agreeing) if len(agreeing) >= 2 else None

    def _align_to_gutters(self, scan: "_InventoryScan", cancel: Event) -> None:
        """Verify the measured offset on the observed tile rows (C5e-1, E1/E6).

        A deterministic drag keeps the row phase, so the gutters normally confirm it within the phase
        tolerance; beyond it the frame is captured again before the gutters' phase is trusted.
        """
        height = scan.source_size[1]
        tolerance = rt.value("inventory.scroll.phase_tolerance_px") / 720 * height
        error = None if scan.gutter_calibration is None else self._gutter_phase(scan, scan.gutter_calibration)
        remeasured = False
        if error is not None and abs(error) > tolerance:
            scan.frame.close()
            scan.frame = self.capture.wait_stable(scan.target, cancel)
            error, remeasured = self._gutter_phase(scan, scan.gutter_calibration), True
        if error is None or abs(error) > rt.value("inventory.gutter.max_correction") * height:
            note = "no calibration" if scan.gutter_calibration is None else "fewer than two agreeing gutters" if error is None else f"correction_px={error:.1f}"
            raise ScannerError("inventory_scroll_unverified", f"tile row phase unverified: {note}")
        # Within the tolerance the move is verified; the observed phase still refines the offset, since a
        # row ending about a pixel from the list edge decides whether the last row is readable (live tail).
        scan.offset -= error / height
        scan.evidence.append({"field": "scroll_alignment", "status": "ok", "source": "gutter_phase", "confidence": 1.0,
                              "note": f"correction_px={error:.1f}{';remeasured' if remeasured else ''}"})

    def _verify_overlap(self, scan: "_InventoryScan") -> None:
        """Cross-check the content index of re-seen tiles against their first reading (C5e-1).

        The kept selection tints its own tile, so it is left out; a row mapped one row off scores like a
        different tile (live: <= .814 vs >= .905 for the same tile).
        """
        visible = self.navigation.page_slots(scan.source_kind, scan.offset)
        scores = []
        for index in sorted(visible):
            if index > scan.read_until or index == scan.selected_index or index not in scan.seen_crops:
                continue
            with ratio_crop(scan.frame, visible[index]) as crop:
                if image_has_visible_content(crop):
                    scores.append(ncc_per_channel_icon(scan.seen_crops[index], crop))
        if len(scores) < 2:
            scan.evidence.append({"field": "overlap_identity", "status": "uncertain", "source": "overlap_identity",
                                  "confidence": 0.0, "note": f"compared={len(scores)}"})
            return
        middle = median(scores)
        if middle < rt.value("inventory.scroll.overlap_icon"):
            raise ScannerError("inventory_scroll_unverified", f"re-seen tiles do not match their first reading: median={middle:.3f}")
        scan.evidence.append({"field": "overlap_identity", "status": "ok", "source": "overlap_identity",
                              "confidence": round(middle, 6), "note": f"compared={len(scores)}"})

    def _wheel_page(self, scan: "_InventoryScan", cancel: Event) -> bool:
        """Navigation-free fallback: wheel once and compare whole frames."""
        self.capture.scroll(scan.target, -480)
        next_frame = self.capture.wait_stable(scan.target, cancel)
        overlap = image_similarity(scan.frame, next_frame)
        if overlap >= rt.value("inventory.wheel.same_frame"):
            next_frame.close()
            scan.evidence.append({"field": "scroll_terminal", "status": "ok", "source": "stable_frame_overlap", "confidence": overlap, "note": "tail-or-no-motion"})
            return False
        if overlap <= rt.value("inventory.wheel.zero_overlap"):
            scan.evidence.append({"field": "scroll_overlap", "status": "uncertain", "source": "frame_overlap", "confidence": overlap, "note": "near-zero overlap; no zero-fill"})
            scan.review_required = True
        scan.frame.close()
        scan.frame = next_frame
        return True

    def _finalize(self, scan: "_InventoryScan") -> list[dict[str, Any]]:
        prepared = scan.prepared
        if prepared is not None and scan.allow_synth:
            # C5e-6b/D19: synth vs real on detail-confirmed tiles; two low scans switch the tier off.
            scores = [score for identity, crop in scan.detail_confirmed
                      if (score := scan.bank.synth_score(identity, crop)) is not None]
            scan.evidence.append(self._synth_guard().record(prepared.profile_id, scores))
        if prepared is not None and scan.bank is not None:
            stats = scan.bank_stats
            trusted = not stats["disagree"] and not stats["count_disagree"]
            scan.evidence.append({"field": "tile_bank", "status": "ok" if trusted else "uncertain",
                "source": "tile_bank", "confidence": 1.0 if trusted else 0.0,
                "note": ";".join(f"{key}={value}" for key, value in stats.items()) + f";bank={len(scan.bank)}"})
        if prepared is not None:
            excluded = self._order_outliers(scan)
            # A scan that observed no catalog item has no order evidence at all: never zero-fill from it.
            observed = any(entry.get("observed_slot") is not None and entry["item_id"] in scan.order for entry in scan.entries)
            ordered_ok = observed and not excluded
            verified = scan.coverage_complete and not scan.review_required and observed
            if verified:
                self._zero_fill(scan, excluded)
            scan.evidence.append({"field": "scan_coverage", "status": "ok" if verified else "partial",
                "source": "inventory_navigation", "confidence": 1.0 if verified else 0.0,
                "note": f"profile={prepared.profile_id};terminal={scan.coverage_complete};ordered={ordered_ok}"})
            scan.review_required = scan.review_required or not scan.coverage_complete or not ordered_ok
        return [scan.candidate(scan.evidence, scan.review_required)]

    @staticmethod
    def _order_outliers(scan: "_InventoryScan") -> list[tuple[int | None, int | None]]:
        """D23: flag observed entries outside the longest increasing catalog-order run.

        Returns, per flagged entry, the open catalog-order window between its in-run neighbours: a flagged
        tile may really be any item in that window, so those items are not zero-filled.
        """
        observed = [entry for entry in scan.entries if entry.get("observed_slot") is not None]
        orders = [scan.order.get(entry["item_id"]) for entry in observed]
        run = increasing_run(orders)
        windows = []
        for position, entry in enumerate(observed):
            if position in run:
                continue
            low = max((orders[i] for i in run if i < position), default=None)
            high = min((orders[i] for i in run if i > position), default=None)
            windows.append((low, high))
            scan.evidence.append({"field": f"entries[{entry['observed_slot']}].order", "status": "uncertain",
                "source": "inventory_order_run", "confidence": 0.0,
                "note": "outside the longest increasing catalog-order run" if orders[position] is not None
                        else "not in the profile catalog"})
        return windows

    @staticmethod
    def _zero_fill(scan: "_InventoryScan", excluded=()) -> None:
        profile_id = scan.prepared.profile_id
        known = {row.item_id: row for row in CATALOG if row.profile_id == profile_id and row.zero_fill_allowed}
        present = {entry['item_id'] for entry in scan.entries}
        for item_id, row in sorted(known.items(), key=lambda pair: pair[1].order_index):
            if item_id in present:
                continue
            if any((low is None or row.order_index > low) and (high is None or row.order_index < high) for low, high in excluded):
                continue
            scan.entries.append({"key": item_id, "quantity": "0", "item_id": item_id, "name": row.display_name,
                "observed_slot": None, "profile_id": profile_id, "inventory_scan_profile": profile_id})
            scan.evidence.append({"field": f"zero_fill[{row.resource_key}].quantity", "status": "ok",
                "source": "verified_profile_zero_fill", "confidence": 1.0, "note": "verified terminal and monotonic profile coverage"})

    def _interrupted(self, scan: "_InventoryScan", exc: Exception, cancel: Event) -> ScanBatchResult:
        error = exc if isinstance(exc, ScannerError) else ScannerError("matcher_failed", str(exc))
        if error.code == "inventory_scroll_unverified" and scan.prepared is not None and not cancel.is_set():
            # Safe abort returns the list to its first page by re-applying verified settings (X10).
            try:
                self.navigation.restore_first_page(scan.target, Event(), scan.frame, scan.first_page, scan.read_until // 5 + 1)
                restored, restore_note = True, "display settings re-applied; first page shown"
            except ScannerError as restore_error:
                restored, restore_note = False, restore_error.code
            error.details["first_page_restored"] = restored
            scan.evidence.append({"field": "inventory_restore", "status": "ok" if restored else "failed",
                                  "source": "inventory_first_page_restore", "confidence": 1.0 if restored else 0.0,
                                  "note": restore_note})
        retained = []
        if scan.entries:
            retained = [scan.candidate([*scan.evidence, {"field": "scan_coverage", "status": "partial",
                "source": "scan_interrupted", "confidence": 0.0, "note": error.code}], True)]
            scan.completed = True  # ownership of complete slot specimens transfers to the session
        return ScanBatchResult(retained, "cancelled" if cancel.is_set() or error.code == "cancelled" else "failed", error)

    def train_user_answer(
        self, profile_id: str, candidate_id: str, specimen: dict[str, Any],
        payload: dict[str, Any],
    ) -> int:
        if self.answer_samples is None:
            return 0
        source_size = specimen.get("source_size")
        slot_crops = specimen.get("slot_crops")
        entries = payload.get("entries")
        if not isinstance(source_size, tuple) or not isinstance(slot_crops, dict) or not isinstance(entries, list):
            return 0
        saved = 0
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            item_id = entry.get("item_id")
            observed_slot = entry.get("observed_slot")
            crop = slot_crops.get(observed_slot)
            if not isinstance(item_id, str) or not isinstance(observed_slot, int) or not isinstance(crop, Image.Image):
                continue
            sample_id = self.answer_samples.save_inventory(
                profile_id, source_size, item_id=item_id, crop=crop,
                candidate_id=candidate_id, observed_slot=observed_slot,
            )
            self.matcher.add_user_template(sample_id, item_id, crop)
            saved += 1
        return saved
