from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from threading import Event, RLock
from typing import Any, Callable, Protocol

from PIL import Image, ImageChops, ImageStat

from core.recognition_assets import RecognitionAssetCatalog
from core.recognition_answer_samples import RecognitionAnswerSampleStore
from core.inventory_catalog import CATALOG, CATALOG_REVISION
from core.scanner_session import ScanBatchResult, ScannerError
from core.student_scan_recognizer import Observation, StudentBasicCropSet, StudentBasicRecognizer
from core.student_equipment_recognizer import EquipmentMenuRecognizer, StudentEquipmentRecognizer
from core.student_weapon_recognizer import StudentWeaponRecognizer
from core.student_panel_recovery import StudentPanelRecovery, read_panel_fields
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


class EquipmentMenuCapturePort(Protocol):
    """One shared detail frame and one conditional F7 retry."""

    def capture_equipment_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def recapture_equipment_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def close_equipment_menu(self, target: dict[str, Any]) -> None: ...


class WeaponMenuCapturePort(Protocol):
    """Input boundary for one opened weapon panel and its bounded retries."""

    def capture_weapon_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def recapture_weapon_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def close_weapon_menu(self, target: dict[str, Any]) -> None: ...


class StatMenuCapturePort(Protocol):
    def capture_stat_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def recapture_stat_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def close_stat_menu(self, target: dict[str, Any]) -> None: ...


class LevelMenuCapturePort(Protocol):
    def capture_level_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def recapture_level_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def close_level_menu(self, target: dict[str, Any]) -> None: ...


class ClickCapturePort(CapturePort, Protocol):
    def click(self, target: dict[str, Any], x_ratio: float, y_ratio: float) -> None: ...
    def press_key(self, target: dict[str, Any], key: str) -> bool: ...


class StarMenuCapturePort(Protocol):
    def capture_star_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def close_star_menu(self, target: dict[str, Any]) -> None: ...


class SkillMenuCapturePort(Protocol):
    def capture_skill_menu(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def close_skill_menu(self, target: dict[str, Any]) -> None: ...


class SkillMenuCaptureAdapter:
    """Open, positively enable show-all once, then return one verified skill frame."""

    def __init__(self, capture, catalog, *, recovery=None, recognizer=None):
        self.capture = capture
        self.recovery = recovery or StudentPanelRecovery(capture,catalog)
        self.recognizer = recognizer or StudentSkillRecognizer(catalog)

    def capture_skill_menu(self, target, cancel):
        frame = self.recovery.open(target,cancel,"skill",self.recognizer.regions["skill_menu_button"])
        try:
            if cancel.is_set(): raise ScannerError("cancelled","skill open cancelled")
            check = self.recognizer.read_check(frame)
            self.recovery.trace.append({"show_all":check.value,"status":check.status})
            if not check.confirmed:
                raise ScannerError("panel_read_failed","skill show-all state is unknown")
            if check.value is False:
                if cancel.is_set(): raise ScannerError("cancelled","skill check cancelled")
                self.capture.click({**target,"_scanner_cancel":cancel},
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

    def close_skill_menu(self, target):
        self.recovery.restore(target)


class StarMenuCaptureAdapter:
    """Read-only star tab navigation, with F2 verified basic return."""

    def __init__(self, capture, catalog, *, recovery=None):
        self.recovery = recovery or StudentPanelRecovery(capture, catalog)

    def capture_star_menu(self, target, cancel):
        return self.recovery.open(target, cancel, "star", self.recovery.regions["star_menu_button"])

    def close_star_menu(self, target):
        self.recovery.restore(target)


class EquipmentMenuCaptureAdapter:
    """Equipment detail transport backed by verified panel transitions."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog, *, recovery=None, controls=None) -> None:
        self.capture = capture
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

    def capture_equipment_menu(self, target, cancel):
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
                self.capture.click({**target, "_scanner_cancel": cancel},
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

    def recapture_equipment_menu(self, target, cancel):
        frame = self.recovery.recapture(target, cancel, "equipment")
        try:
            if self._check(frame, cancel) is not True:
                raise ScannerError("panel_read_failed", "equipment show-all changed during retry")
            return frame
        except Exception:
            frame.close()
            raise

    def close_equipment_menu(self, target):
        self.recovery.restore(target)


class WeaponMenuCaptureAdapter:
    """Weapon detail transport backed by the same panel state contract."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog, *, recovery=None) -> None:
        self.capture = capture
        self.regions = catalog.region_for_purpose("student", "student-weapon-regions")
        self.recovery = recovery or StudentPanelRecovery(capture, catalog)

    def capture_weapon_menu(self, target, cancel):
        return self.recovery.open(target, cancel, "weapon", self.regions["weapon_info_menu_button"])

    def recapture_weapon_menu(self, target, cancel):
        return self.recovery.recapture(target, cancel, "weapon")

    def close_weapon_menu(self, target):
        self.recovery.restore(target)


class StatMenuCaptureAdapter:
    """Read-only ability-release panel using F2 same-student recovery."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog, *, recovery=None):
        self.regions = catalog.region_for_purpose("student", "student-potential-regions")
        self.recovery = recovery or StudentPanelRecovery(capture, catalog)

    def capture_stat_menu(self, target, cancel):
        return self.recovery.open(target, cancel, "stat", self.regions["stat_menu_button"])

    def recapture_stat_menu(self, target, cancel):
        return self.recovery.recapture(target, cancel, "stat")

    def close_stat_menu(self, target):
        self.recovery.restore(target)


class LevelMenuCaptureAdapter:
    """Level tab transport; the only input is tab navigation, never growth."""

    def __init__(self, capture: ClickCapturePort, catalog: RecognitionAssetCatalog, *, recovery=None):
        self.recovery = recovery or StudentPanelRecovery(capture,catalog)

    def capture_level_menu(self, target, cancel):
        return self.recovery.open(target,cancel,"level",self.recovery.regions["levelcheck_button"])

    def recapture_level_menu(self, target, cancel):
        return self.recovery.recapture(target,cancel,"level")

    def close_level_menu(self, target):
        self.recovery.restore(target)


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
        weapon_menu: WeaponMenuCapturePort | None = None,
        stat_menu: StatMenuCapturePort | None = None,
        level_menu: LevelMenuCapturePort | None = None,
        star_menu: StarMenuCapturePort | None = None,
        skill_menu: SkillMenuCapturePort | None = None,
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
        recovery = (getattr(self.weapon_menu, "recovery", None) or getattr(self.equipment_menu, "recovery", None)
                    or getattr(self.stat_menu, "recovery", None) or getattr(self.level_menu, "recovery", None)
                    or getattr(self.star_menu, "recovery", None) or getattr(self.skill_menu, "recovery", None))
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
                    if not entered and attempts == 0 and target.get('_first_student', True) and self.entry_recovery is not None:
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

    def _scan_current(self, target: dict[str, Any], cancel: Event, progress: Callable[..., None]) -> list[dict[str, Any]]:
        if cancel.is_set():
            return []
        progress(0, 4, "scanner.student.capture")
        frame, identity = self._capture_identified(target, cancel)
        if cancel.is_set():
            frame.close()
            return []
        try:
            recovery = (getattr(self.weapon_menu, "recovery", None) or getattr(self.equipment_menu, "recovery", None)
                        or getattr(self.stat_menu, "recovery", None) or getattr(self.level_menu, "recovery", None)
                        or getattr(self.star_menu, "recovery", None) or getattr(self.skill_menu, "recovery", None))
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
        finally:
            frame.close()
        fallback_evidence: list[dict[str, Any]] = []
        try:
            student_ref = identity.student_ref
            self._activate_numeric_samples(
                target.get("profile_id"), crops.source_size, student_ref,
            )
            progress(1, 4, "scanner.student.identify")
            confident = True
            if target.get("student_scan_mode") == "full":
                self._report_student_feedback(
                    progress, 1, 4, "scanner.student.identify",
                    student_ref, "student_id", {},
                )
            if cancel.is_set():
                return []
            progress(2, 4, "scanner.student.basic_fields")
            observations = self.basic_recognizer.recognize(crops)
            basic_level = observations.get("level")
            level_fallback = self.level_recognizer.resolve(
                observations, self.level_menu, target, cancel,
            )
            observations.update(level_fallback)
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
            student_star = observations.get("student_star")
            observations["weapon_state"] = independent_weapon
            if student_star is not None and student_star.confirmed and int(student_star.value) < 5:
                observations["weapon_state"] = Observation(
                    "no_weapon_system", 1.0, "inferred", "student_star_gate",
                    f"student_star={student_star.value}",
                )
            weapon_state = observations["weapon_state"]
            if weapon_state.confirmed and weapon_state.value != "weapon_equipped":
                for field in ("weapon_level", "weapon_star"):
                    observations[field] = Observation(
                        None, weapon_state.confidence, "skipped",
                        "basic_weapon_state_template", f"state={weapon_state.value}",
                    )
            elif (
                weapon_state.confirmed
                and weapon_state.value == "weapon_equipped"
                and not all(observations[field].confirmed for field in ("weapon_level", "weapon_star"))
                and self.weapon_menu is not None
            ):
                unresolved_weapon = {
                    field: observations[field]
                    for field in ("weapon_level", "weapon_star")
                    if not observations[field].confirmed
                }
                fallback = read_panel_fields(
                    self.weapon_menu, "weapon", target, cancel, observations,
                    ("weapon_level", "weapon_star"), self.weapon_recognizer.recognize_menu,
                    attempts=3,
                )
                observations.update(fallback)
                for field, trigger in unresolved_weapon.items():
                    result = observations.get(field)
                    recovered = result is not None and result.confirmed
                    fallback_evidence.append({
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
            if unresolved and self.equipment_menu is not None and self.equipment_menu_recognizer is not None:
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
            answer_specimen = {
                "source_size": crops.source_size,
                "numeric_groups": self._numeric_groups(crops),
            }
        finally:
            crops.close()
        values = {
            field: observation.value
            for field, observation in observations.items()
            if observation.confirmed or observation.source == "panel_value_conflict"
        }
        provenance = {"student_id": identity.source}
        provenance.update({field: observation.source for field, observation in observations.items() if observation.confirmed or observation.source == "panel_value_conflict"})
        evidence = [{
            "field": "student_id", "status": "ok" if confident else "uncertain",
            "source": identity.source, "confidence": identity.score,
            "note": f"margin={identity.margin:.6f};form_ref={student_ref}",
        }]
        evidence.extend({
            "field": field,
            "status": observation.status,
            "source": observation.source,
            "confidence": observation.confidence,
            "note": observation.note,
        } for field, observation in observations.items())
        evidence.extend(fallback_evidence)
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
            "_answer_specimen": answer_specimen,
        }]

    def _scan_with_forms(self, target, cancel, progress):
        rows = self._scan_current(target, cancel, progress)
        if not rows or getattr(self, 'form_recovery', None) is None:
            return rows
        original = rows[0]
        original_ref = original['payload']['student_id']
        base, _ = student_meta.split_form_ref(original_ref)
        if not student_meta.is_multi_form(base) or base in target.get('_seen_students', ()):
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
        target = {**target, "_scanner_cancel": cancel}
        session_id = str(target.get("_scanner_session_id") or "standalone")
        generation = target.get("_scanner_generation", 1)
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
        click = getattr(self.capture, "click", None)
        if not callable(click):
            raise ScannerError("input_unavailable", "full student scan requires click input")
        seen: set[str] = set()
        previous_student_id: str | None = None
        pending_button_fallback = False
        direction = "right"

        def navigate() -> None:
            nonlocal pending_button_fallback
            if cancel.is_set():
                raise ScannerError("cancelled", "navigation cancelled")
            press_key = getattr(self.capture, "press_key", None)
            try:
                used_key = callable(press_key) and bool(press_key(target, direction))
            except ScannerError as exc:
                # Only an API failure before insertion is safe to retry as a click.
                if exc.code != "input_failed":
                    raise
                used_key = False
            pending_button_fallback = used_key
            if not used_key:
                if cancel.is_set():
                    raise ScannerError("cancelled", "navigation cancelled")
                click(
                    target,
                    0.9777 if direction == "right" else 0.0223,
                    0.53465,
                )

        def navigate_next() -> bool:
            if cancel.is_set():
                return False
            navigate()
            return True

        for _index in range(500):
            if cancel.is_set():
                break
            def current_progress(
                _current: int,
                _total: int | None,
                message: str,
                feedback: dict[str, Any] | None = None,
            ) -> None:
                if feedback is None:
                    progress(len(results), None, message)
                else:
                    progress(len(results), None, message, feedback)

            current_progress.supports_feedback = getattr(  # type: ignore[attr-defined]
                progress, "supports_feedback", False
            )
            try:
                scanned = self._scan_with_forms({**target, '_first_student': not seen, '_seen_students': tuple(seen)}, cancel, current_progress)
            except ScannerError as exc:
                results.extend(getattr(exc, 'completed_candidates', []))
                raise
            if not scanned:
                if cancel.is_set():
                    break
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
            if student_id in seen:
                self._close_answer_specimens(scanned)
                if (
                    student_id == previous_student_id
                    and pending_button_fallback
                ):
                    progress(len(results), None, "scanner.student.full.navigation_retry")
                    if cancel.is_set():
                        break
                    click(
                        target,
                        0.9777 if direction == "right" else 0.0223,
                        0.53465,
                    )
                    pending_button_fallback = False
                    if cancel.wait(0.45):
                        break
                    continue
                if student_id == previous_student_id and direction == "right":
                    direction = "left"
                    progress(
                        len(results), None,
                        "scanner.student.full.navigation_reverse",
                    )
                    if not navigate_next():
                        break
                    if cancel.wait(0.45):
                        break
                    continue
                if student_id == previous_student_id:
                    raise ScannerError("navigation_unconfirmed", "no movement after key/button; edge is not verified")
                if direction == "right":
                    progress(
                        len(results), len(results),
                        "scanner.student.full.complete",
                    )
                    return True
                previous_student_id = student_id
                if not navigate_next():
                    break
                progress(len(results), None, "scanner.student.full.navigating")
                if cancel.wait(0.45):
                    break
                continue
            seen.add(student_id)
            previous_student_id = student_id
            results.extend(scanned)
            progress(len(results), None, "scanner.student.full.collected")
            if not navigate_next():
                break
            progress(len(results), None, "scanner.student.full.navigating")
            if cancel.wait(0.45):
                break
        else:
            raise ScannerError("navigation_limit", "student navigation budget exhausted")
        return False


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


class InventoryMatcherAdapter:
    def __init__(self, capture: CapturePort, catalog: RecognitionAssetCatalog, *, threshold: float = 0.80, margin: float = 0.03, max_pages: int = 60, answer_samples: RecognitionAnswerSampleStore | None = None, detail_recovery=None, navigation=None) -> None:
        self.capture = capture
        self.catalog = catalog
        self.threshold = threshold
        self.margin = margin
        self.max_pages = max_pages
        self.matcher = TemplateMatcher(catalog, "inventory", "inventory-template")
        self.count_matcher = SlotCountMatcher(catalog)
        self.answer_samples = answer_samples
        self.detail_recovery = detail_recovery
        self.navigation = navigation
        regions = catalog.region("inventory").get("item", {})
        self.slots = regions.get("grid_slots")
        if not isinstance(self.slots, list) or not self.slots:
            raise ScannerError("region_missing", "inventory grid slots are missing")

    def __call__(self, target: dict[str, Any], cancel: Event, progress: Callable[[int, int | None, str], None]) -> list[dict[str, Any]] | ScanBatchResult:
        target = {**target, "_scanner_cancel": cancel}
        frame = self.capture.wait_stable(target, cancel)
        source_size = frame.size
        entries: list[dict[str, Any]] = []
        slot_crops: dict[int, Image.Image] = {}
        evidence: list[dict[str, Any]] = []
        review_required = False
        completed = False
        coverage_complete = False
        try:
            detail_port = getattr(self, 'detail_recovery', None)
            navigation = getattr(self, 'navigation', None)
            prepared = None
            slots = self.slots
            if detail_port is not None:
                source_kind = detail_port.recognizer.classify(frame)
                if source_kind is None:
                    raise ScannerError('inventory_page_unknown', 'inventory detail input requires a verified item/equipment page')
                slots = detail_port.recognizer.regions['sources'][source_kind]['grid_slots']
            if navigation is not None:
                prepared = navigation.prepare(target,cancel,frame)
                frame.close();frame = self.capture.wait_stable(target,cancel)
                source_kind = prepared.source
                target = {**target,'inventory_scan_profile':prepared.profile_id}
            profile_id = target.get("profile_id")
            if self.answer_samples is not None and isinstance(profile_id, str):
                samples = self.answer_samples.load_inventory(profile_id, source_size)
                try:
                    self.matcher.replace_user_templates([
                        (sample.sample_id, sample.item_id, sample.image) for sample in samples
                    ])
                finally:
                    self.answer_samples.close(samples)
            else:
                self.matcher.replace_user_templates([])
            scan_indices = tuple(range(len(slots)))
            allowed_profile_ids = None if prepared is None else {
                row.item_id for row in CATALOG if row.profile_id == prepared.profile_id
            }
            observed_profile_ids: list[str] = []
            terminal_after_page = False
            for page in range(self.max_pages):
                page_ids: list[str] = []
                page_unresolved = False
                for slot_index in scan_indices:
                    region = slots[slot_index]
                    if cancel.is_set():
                        raise ScannerError("cancelled", "inventory scan cancelled")
                    crop = ratio_crop(frame, region)
                    try:
                        if not image_has_visible_content(crop):
                            continue
                        profile_membership_confirmed = allowed_profile_ids is None
                        if allowed_profile_ids is not None:
                            global_match = self.matcher.match(
                                crop, center_trim=0.15, prefer_user=True,
                                threshold=self.threshold, margin=self.margin,
                            )
                            if (
                                global_match.score >= 0.55
                                and global_match.identity not in allowed_profile_ids
                            ):
                                evidence.append({
                                    "field": f"slots[{page * len(slots) + slot_index}]",
                                    "status": "skipped",
                                    "source": "inventory_profile_catalog",
                                    "confidence": global_match.score,
                                    "note": "confident visible identity is outside the explicit scan profile",
                                })
                                continue
                            profile_membership_confirmed = (
                                global_match.score >= self.threshold
                                and global_match.margin >= self.margin
                                and global_match.identity in allowed_profile_ids
                            )
                        fast = self.matcher.match(
                            crop, center_trim=0.15, prefer_user=True,
                            threshold=self.threshold, margin=self.margin,
                            allowed_identities=allowed_profile_ids,
                        )
                        fast_confident = fast.score >= self.threshold and fast.margin >= self.margin
                        match = fast if fast_confident else self.matcher.match(
                            crop, allowed_identities=allowed_profile_ids,
                        )
                        source = (
                            "user_confirmed_grid_sample" if match.source == "user_confirmed"
                            else "grid_icon_template" if fast_confident else "grid_same_crop_rematch"
                        )
                        if match.score < 0.55 and detail_port is None:
                            continue
                        confident = match.score >= self.threshold and match.margin >= self.margin
                        index = page * len(slots) + slot_index
                        count = self.count_matcher.match(crop)
                        identity, score, match_margin = match.identity, match.score, match.margin
                        quantity, count_score, count_source = count.value, count.score, 'slot_count_glyph'
                        note = f'margin={count.margin:.6f}'
                        item_status = 'ok' if confident else 'uncertain'
                        if detail_port is not None and not (fast_confident and count.value is not None):
                            try:
                                detail = detail_port.resolve(target,cancel,frame,slot_index,identity,count.value,confident,
                                    profile_verified=target.get('_inventory_profile_verified') is True,
                                    scan_profile=target.get('inventory_scan_profile'))
                            except ScannerError as exc:
                                if not exc.details.get('inventory_restored') or exc.code not in {'inventory_detail_unconfirmed','capture_timeout','capture_failed'}:
                                    raise
                                detail = None;note = exc.code+';original selection restored'
                                item_status = 'partial'
                            if detail is not None:
                                if detail.identity is not None:
                                    identity,score,match_margin=detail.identity,detail.score,detail.margin
                                    confident=True;source=detail.source;item_status='ok'
                                    if detail.source=='verified_grid_detail_fallback':
                                        score,match_margin=match.score,match.margin
                                if detail.source=='inventory_detail_conflict':
                                    item_status='conflict';quantity=None;count_source=detail.source
                                elif detail.identity is not None:
                                    quantity,count_score,count_source=detail.count.value,detail.count.score,detail.count.source
                                    if detail.count.source=='verified_grid_count_fallback':count_score=count.score
                                else:
                                    quantity=None;item_status='partial'
                                note=detail.count.reason
                                if detail.identity is not None and allowed_profile_ids is not None:
                                    profile_membership_confirmed = detail.identity in allowed_profile_ids
                        if allowed_profile_ids is not None and identity not in allowed_profile_ids:
                            evidence.append({
                                "field": f"slots[{index}]", "status": "skipped",
                                "source": "inventory_profile_catalog",
                                "confidence": score,
                                "note": "visible identity is outside the explicit scan profile",
                            })
                            continue
                        if not profile_membership_confirmed:
                            evidence.append({
                                "field": f"slots[{index}]", "status": "skipped",
                                "source": "inventory_profile_catalog",
                                "confidence": score,
                                "note": "profile membership was not positively verified",
                            })
                            continue
                        if any(entry["item_id"] == identity for entry in entries):
                            continue
                        quantity_confident = quantity is not None
                        entry_profile = prepared.profile_id if prepared is not None else "visible-grid"
                        entries.append({"key": identity, "quantity": quantity, "item_id": identity, "name": None, "observed_slot": index,
                                        "profile_id": entry_profile,
                                        "inventory_scan_profile": prepared.profile_id if prepared is not None else None})
                        if isinstance(identity,str):page_ids.append(identity)
                        if item_status!='ok' or not quantity_confident:page_unresolved=True
                        slot_crops[index] = crop.copy()
                        evidence.extend([
                            {"field": f"entries[{index}].item_id", "status": item_status, "source": source, "confidence": score, "note": f"margin={match_margin:.6f}"},
                            {"field": f"entries[{index}].quantity", "status": "ok" if quantity_confident else "uncertain", "source": count_source, "confidence": count_score, "note": note},
                        ])
                        review_required = review_required or item_status!='ok' or not quantity_confident
                        progress(len(entries), None, "scanner.inventory.grid")
                    finally:
                        crop.close()
                if prepared is not None:
                    if page_ids and not navigation.verify_profile_order(prepared.profile_id,page_ids):
                        # The current client can sort the mixed item page by quantity/name,
                        # so catalog order is not guaranteed even when every recognized
                        # identity belongs to the explicit profile. Keep the observations,
                        # but mark coverage partial and prohibit zero-fill below.
                        evidence.append({
                            "field": "profile_order", "status": "partial",
                            "source": "inventory_profile_catalog", "confidence": 0.0,
                            "note": "visible items do not match monotonic scan profile order; no zero-fill",
                        })
                        review_required = True
                    observed_profile_ids.extend(page_ids)
                    target={**target,'_inventory_profile_verified':bool(page_ids) and not page_unresolved}
                if navigation is None and len(entries) >= len(self.matcher.templates):
                    coverage_complete = True
                    break
                if terminal_after_page:
                    # A residual tail page is only terminal when one more scroll shows no motion (X07).
                    coverage_complete=navigation.confirm_terminal(target,cancel,frame,source_kind)
                    evidence.append({"field":"scroll_terminal","status":"ok" if coverage_complete else "partial",
                        "source":"verified_tail_residual" if coverage_complete else "tail_recheck_moved",
                        "confidence":1.0 if coverage_complete else 0.0,
                        "note":"residual tail page scanned once; no-motion re-check "+("passed" if coverage_complete else "moved; no zero-fill")})
                    review_required = review_required or not coverage_complete
                    break
                if cancel.is_set():
                    raise ScannerError("cancelled", "inventory scan cancelled")
                if navigation is not None:
                    moved=navigation.advance(target,cancel,frame,source_kind)
                    next_frame=moved.frame
                    evidence.append({"field":"scroll_overlap","status":"ok","source":moved.reason,
                        "confidence":1.0,"note":f"rows={moved.overlap_rows};reason={moved.reason}"})
                    if moved.terminal:
                        coverage_complete=True;next_frame.close();break
                    scan_indices=moved.slot_indices
                    terminal_after_page=moved.terminal_after_page
                    frame.close();frame=next_frame
                    continue
                self.capture.scroll(target, -480)
                next_frame = self.capture.wait_stable(target, cancel)
                overlap = image_similarity(frame, next_frame)
                if overlap >= 0.995:
                    next_frame.close()
                    evidence.append({"field": "scroll_terminal", "status": "ok", "source": "stable_frame_overlap", "confidence": overlap, "note": "tail-or-no-motion"})
                    break
                if overlap <= 0.05:
                    evidence.append({"field": "scroll_overlap", "status": "uncertain", "source": "frame_overlap", "confidence": overlap, "note": "near-zero overlap; no zero-fill"})
                    review_required = True
                frame.close()
                frame = next_frame
            if prepared is not None:
                ordered_ok=navigation.verify_profile_order(prepared.profile_id,observed_profile_ids)
                unresolved=review_required or not ordered_ok
                if coverage_complete and not unresolved:
                    known={row.item_id:row for row in CATALOG if row.profile_id==prepared.profile_id and row.zero_fill_allowed}
                    present={entry['item_id'] for entry in entries}
                    for item_id,row in sorted(known.items(),key=lambda pair:pair[1].order_index):
                        if item_id in present:continue
                        entries.append({"key":item_id,"quantity":"0","item_id":item_id,"name":row.display_name,
                            "observed_slot":None,"profile_id":prepared.profile_id,
                            "inventory_scan_profile":prepared.profile_id})
                        evidence.append({"field":f"zero_fill[{row.resource_key}].quantity","status":"ok",
                            "source":"verified_profile_zero_fill","confidence":1.0,"note":"verified terminal and monotonic profile coverage"})
                evidence.append({"field":"scan_coverage","status":"ok" if coverage_complete and not unresolved else "partial",
                    "source":"inventory_navigation","confidence":1.0 if coverage_complete and not unresolved else 0.0,
                    "note":f"profile={prepared.profile_id};terminal={coverage_complete};ordered={ordered_ok}"})
                review_required = review_required or not coverage_complete or not ordered_ok
            completed = True
            return [{
                "payload": {"version": 1, "catalog_revision": CATALOG_REVISION, "entries": entries},
                "evidence": evidence,
                "review_required": review_required,
                "_answer_specimen": {"source_size": source_size, "slot_crops": slot_crops},
            }]
        except Exception as exc:
            error = exc if isinstance(exc, ScannerError) else ScannerError("matcher_failed", str(exc))
            if error.code == "inventory_scroll_unverified" and prepared is not None and not cancel.is_set():
                # Safe abort returns the list to its first page by re-applying verified settings (X10).
                try:
                    navigation.restore_first_page(target, Event(), frame)
                    restored, restore_note = True, "display settings re-applied; first page shown"
                except ScannerError as restore_error:
                    restored, restore_note = False, restore_error.code
                error.details["first_page_restored"] = restored
                evidence.append({"field": "inventory_restore", "status": "ok" if restored else "failed",
                                 "source": "inventory_first_page_restore", "confidence": 1.0 if restored else 0.0,
                                 "note": restore_note})
            retained = []
            if entries:
                retained = [{
                    "payload": {"version": 1, "catalog_revision": CATALOG_REVISION, "entries": entries},
                    "evidence": [*evidence, {"field": "scan_coverage", "status": "partial",
                        "source": "scan_interrupted", "confidence": 0.0, "note": error.code}],
                    "review_required": True,
                    "_answer_specimen": {"source_size": source_size, "slot_crops": slot_crops},
                }]
                completed = True  # ownership of complete slot specimens transfers to the session
            return ScanBatchResult(retained, "cancelled" if cancel.is_set() or error.code == "cancelled" else "failed", error)
        finally:
            frame.close()
            if not completed:
                for crop in slot_crops.values():
                    crop.close()

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
