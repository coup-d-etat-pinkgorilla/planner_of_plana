from __future__ import annotations

from PIL import Image, ImageChops, ImageStat

from core.recognition_assets import RecognitionAssetCatalog
from core.student_scan_recognizer import Observation, ratio_crop


def _normalized_correlation(left: Image.Image, right: Image.Image) -> float:
    size = right.size
    source = left.convert("L").resize(size, Image.Resampling.LANCZOS)
    template = right.convert("L")
    try:
        source_values = list(source.getdata())
        template_values = list(template.getdata())
        source_mean = sum(source_values) / max(1, len(source_values))
        template_mean = sum(template_values) / max(1, len(template_values))
        numerator = sum(
            (a - source_mean) * (b - template_mean)
            for a, b in zip(source_values, template_values, strict=True)
        )
        left_square = sum((value - source_mean) ** 2 for value in source_values)
        right_square = sum((value - template_mean) ** 2 for value in template_values)
        denominator = (left_square * right_square) ** 0.5
        return 0.0 if denominator == 0 else max(-1.0, min(1.0, numerator / denominator))
    finally:
        source.close()
        template.close()


def _color_similarity(left: Image.Image, right: Image.Image) -> float:
    source = left.convert("RGB").resize(right.size, Image.Resampling.LANCZOS)
    template = right.convert("RGB")
    try:
        mean = ImageStat.Stat(ImageChops.difference(source, template)).mean
        return max(0.0, min(1.0, 1.0 - sum(mean) / (3.0 * 255.0)))
    finally:
        source.close()
        template.close()


class StudentWeaponRecognizer:
    """Independent basic-card state and opened weapon-panel field recognition."""

    def __init__(self, catalog: RecognitionAssetCatalog) -> None:
        self.catalog = catalog
        self.regions = catalog.region_for_purpose("student", "student-weapon-regions")
        self.state_templates = self._load("student-weapon-state-template")
        self.level_templates = self._load("student-weapon-menu-level-template")
        self.star_templates = self._load("student-weapon-menu-star-template")

    def _load(self, purpose: str) -> dict[str, Image.Image]:
        result: dict[str, Image.Image] = {}
        for asset in self.catalog.assets("student", purpose):
            if asset.identity is None:
                continue
            with Image.open(self.catalog.resolve(asset.path)) as source:
                result[asset.identity] = source.convert("RGB")
        return result

    @staticmethod
    def _rank(
        crop: Image.Image,
        templates: dict[str, Image.Image],
        *,
        color: bool = False,
    ) -> tuple[str | None, float, float]:
        scorer = _color_similarity if color else _normalized_correlation
        ranked = sorted(
            ((label, scorer(crop, template)) for label, template in templates.items()),
            key=lambda item: item[1],
            reverse=True,
        )
        if not ranked:
            return None, 0.0, 0.0
        runner_up = ranked[1][1] if len(ranked) > 1 else 0.0
        return ranked[0][0], ranked[0][1], ranked[0][1] - runner_up

    def read_state(
        self,
        crop: Image.Image | None,
        *,
        student_star: int | None,
    ) -> Observation:
        if isinstance(student_star, int) and student_star < 5:
            return Observation(
                "no_weapon_system", 1.0, "inferred", "student_star_gate",
                f"student_star={student_star}",
            )
        if crop is None:
            return Observation(
                None, 0.0, "region_missing", "basic_weapon_state_template", "crop missing"
            )
        gray = crop.convert("L")
        try:
            luminance = ImageStat.Stat(gray)
        finally:
            gray.close()
        if luminance.mean[0] < 35.0 or luminance.stddev[0] < 8.0:
            return Observation(
                None, 0.0, "uncertain", "basic_weapon_state_template",
                "state ROI has insufficient UI signal",
            )
        label, score, margin = self._rank(crop, self.state_templates, color=True)
        confirmed = (
            label in {
                "weapon_equipped", "weapon_unlocked_not_equipped", "no_weapon_system",
            }
            and score >= 0.72
            and margin >= 0.10
        )
        return Observation(
            label if confirmed else None,
            score,
            "ok" if confirmed else "uncertain",
            "basic_weapon_state_template",
            f"label={label};margin={margin:.6f}",
        )

    def recognize_menu(self, frame: Image.Image) -> dict[str, Observation]:
        star_region = self.regions.get("weapon_star_region")
        if isinstance(star_region, dict):
            star_crop = ratio_crop(frame, star_region)
            try:
                star_label, star_score, star_margin = self._rank(
                    star_crop, self.star_templates
                )
            finally:
                star_crop.close()
        else:
            star_label, star_score, star_margin = None, 0.0, 0.0
        star = int(star_label) if star_label and star_label.isdigit() else None
        star_ok = star in {1, 2, 3, 4} and star_score >= 0.60 and star_margin >= 0.02

        digits: list[str] = []
        digit_scores: list[float] = []
        digit_margins: list[float] = []
        for position in (1, 2):
            region = self.regions.get(f"weapon_level_digit{position}")
            templates = {
                identity.split(":", 1)[1]: template
                for identity, template in self.level_templates.items()
                if identity.startswith(f"{position}:")
            }
            if not isinstance(region, dict):
                continue
            crop = ratio_crop(frame, region)
            try:
                label, score, margin = self._rank(crop, templates)
            finally:
                crop.close()
            if position == 2 and label == "null" and score >= 0.60:
                break
            if label is None or not label.isdigit():
                digits.clear()
                break
            digits.append(label)
            digit_scores.append(score)
            digit_margins.append(margin)
        level = int("".join(digits)) if digits else None
        level_score = min(digit_scores, default=0.0)
        level_margin = min(digit_margins, default=0.0)
        level_ok = (
            level is not None and 1 <= level <= 60
            and level_score >= 0.55 and level_margin >= 0.015
        )
        return {
            "weapon_star": Observation(
                star if star_ok else None,
                star_score,
                "ok" if star_ok else "uncertain",
                "weapon_menu_star_template",
                f"value={star};margin={star_margin:.6f}",
            ),
            "weapon_level": Observation(
                level if level_ok else None,
                level_score,
                "ok" if level_ok else "uncertain",
                "weapon_menu_level_template",
                f"value={level};margin={level_margin:.6f}",
            ),
        }

    def close(self) -> None:
        for templates in (self.state_templates, self.level_templates, self.star_templates):
            for image in templates.values():
                image.close()
            templates.clear()
