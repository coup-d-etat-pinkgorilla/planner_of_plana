from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import colorsys
from typing import Any

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_session import ScannerError


S2_VALUE_FIELDS = (
    "level", "student_star", "ex_skill", "skill1", "skill2", "skill3",
    "weapon_state", "weapon_star", "weapon_level", "combat_hp", "combat_atk",
    "combat_def", "combat_heal",
)


def _pixels(image: Image.Image):
    flattened = getattr(image, "get_flattened_data", None)
    return flattened() if flattened is not None else image.getdata()


def ratio_crop(image: Image.Image, region: dict[str, Any]) -> Image.Image:
    try:
        box = (
            round(image.width * float(region["x1"])),
            round(image.height * float(region["y1"])),
            round(image.width * float(region["x2"])),
            round(image.height * float(region["y2"])),
        )
    except (KeyError, TypeError, ValueError) as exc:
        raise ScannerError("region_missing", "invalid ratio region") from exc
    if box[0] >= box[2] or box[1] >= box[3]:
        raise ScannerError("region_missing", "ratio region is empty")
    return image.crop(box)


def quad_crop(image: Image.Image, region: dict[str, Any]) -> Image.Image:
    points = region.get("points_ratio")
    output_size = region.get("output_size")
    if not isinstance(points, list) or len(points) != 4 or not isinstance(output_size, list):
        raise ScannerError("region_missing", "invalid quad region")
    try:
        scaled = [
            (float(point["x"]) * image.width, float(point["y"]) * image.height)
            for point in points
        ]
        size = (int(output_size[0]), int(output_size[1]))
    except (KeyError, TypeError, ValueError, IndexError) as exc:
        raise ScannerError("region_missing", "invalid quad region") from exc
    if size[0] <= 0 or size[1] <= 0:
        raise ScannerError("region_missing", "quad output is empty")
    top_left, top_right, bottom_right, bottom_left = scaled
    return image.transform(
        size,
        Image.Transform.QUAD,
        (*top_left, *bottom_left, *bottom_right, *top_right),
        resample=Image.Resampling.BICUBIC,
    )


@dataclass(slots=True)
class StudentBasicCropSet:
    """Owned S2/S3 crops derived from one stable frame; the full frame is not retained."""

    images: dict[str, Image.Image]
    cell_groups: dict[str, tuple[Image.Image, ...]]
    source_size: tuple[int, int]
    regions: dict[str, Any]

    IMAGE_KEYS = (
        "student_texture_region", "basic_level_digits_quad", "basic_student_stars_quad",
        "basic_EX_skill", "basic_Skill_1", "basic_Skill_2", "basic_Skill_3",
        "basic_weapon_level_digits_quad", "basic_weapon_star_region",
        "basic_equipment_1_level_digits_quad", "basic_equipment_2_level_digits_quad",
        "basic_equipment_3_level_digits_quad", "basic_equipment_1_icon_region",
        "basic_equipment_2_icon_region", "basic_equipment_3_icon_region",
        "basic_equipment_1_empty_dot_region", "basic_equipment_2_empty_dot_region",
        "basic_equipment_3_empty_dot_region", "basic_favorite_empty_dot_region",
        "basic_favorite_tier_region",
    )
    COMBAT_KEYS = (
        "basic_combat_hp_digits", "basic_combat_atk_digits",
        "basic_combat_def_digits", "basic_combat_heal_digits",
    )

    @classmethod
    def from_frame(cls, frame: Image.Image, regions: dict[str, Any]) -> "StudentBasicCropSet":
        images: dict[str, Image.Image] = {}
        cell_groups: dict[str, tuple[Image.Image, ...]] = {}
        for key in cls.IMAGE_KEYS:
            region = regions.get(key)
            if not isinstance(region, dict):
                continue
            images[key] = (
                quad_crop(frame, region) if "points_ratio" in region else ratio_crop(frame, region)
            ).copy()
        for key in cls.COMBAT_KEYS:
            region = regions.get(key)
            cells = region.get("cells") if isinstance(region, dict) else None
            if isinstance(cells, list):
                cell_groups[key] = tuple(
                    ratio_crop(frame, cell).copy() for cell in cells if isinstance(cell, dict)
                )
        return cls(images=images, cell_groups=cell_groups, source_size=frame.size, regions=regions)

    def close(self) -> None:
        for image in self.images.values():
            image.close()
        for cells in self.cell_groups.values():
            for image in cells:
                image.close()
        self.images.clear()
        self.cell_groups.clear()
        self.regions = {}


@dataclass(frozen=True, slots=True)
class Observation:
    value: int | str | None
    confidence: float
    status: str
    source: str
    note: str

    @property
    def confirmed(self) -> bool:
        return self.value is not None and self.status in {"ok", "inferred"}


def _mask_from_predicate(image: Image.Image, predicate) -> Image.Image:
    rgb = image.convert("RGB")
    result = Image.new("L", rgb.size)
    result.putdata([255 if predicate(pixel) else 0 for pixel in _pixels(rgb)])
    return result


def _normalize_mask(mask: Image.Image, *, size: tuple[int, int] = (20, 28), padding: int = 2) -> Image.Image | None:
    source = mask.convert("L").point(lambda value: 255 if value >= 127 else 0)
    box = source.getbbox()
    if box is None:
        return None
    glyph = source.crop(box)
    target_width = max(1, size[0] - padding * 2)
    target_height = max(1, size[1] - padding * 2)
    scale = min(target_width / glyph.width, target_height / glyph.height)
    resized = glyph.resize(
        (max(1, round(glyph.width * scale)), max(1, round(glyph.height * scale))),
        Image.Resampling.NEAREST,
    )
    result = Image.new("L", size)
    result.paste(resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2))
    return result


def _binary_iou(left: Image.Image, right: Image.Image) -> float:
    a = left.convert("L")
    b = right.convert("L").resize(a.size, Image.Resampling.NEAREST)
    left_bits = [value >= 127 for value in _pixels(a)]
    right_bits = [value >= 127 for value in _pixels(b)]
    intersection = sum(x and y for x, y in zip(left_bits, right_bits))
    union = sum(x or y for x, y in zip(left_bits, right_bits))
    return intersection / union if union else 0.0


def _rank_glyph(glyph: Image.Image | None, templates: dict[str, tuple[Image.Image, ...]]) -> tuple[str | None, float, float]:
    if glyph is None:
        return None, 0.0, 0.0
    ranked = sorted(
        (
            (label, max(_binary_iou(glyph, sample) for sample in samples))
            for label, samples in templates.items() if samples
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    if not ranked:
        return None, 0.0, 0.0
    return ranked[0][0], ranked[0][1], ranked[0][1] - (ranked[1][1] if len(ranked) > 1 else 0.0)


def _luminance(pixel: tuple[int, int, int]) -> int:
    return round(0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2])


class StudentBasicRecognizer:
    """Pure-Pillow port of the v6 compact student basic-info readers."""

    def __init__(self, catalog: RecognitionAssetCatalog) -> None:
        self.catalog = catalog
        self.level_templates = self._digit_templates("student-basic-level-digit-template")
        self.weapon_level_templates = self._digit_templates("student-basic-weapon-level-digit-template")
        self.combat_templates, self.combat_position_templates = self._combat_templates()
        self.skill_templates = self._skill_templates()

    def _digit_templates(self, purpose: str) -> dict[str, tuple[Image.Image, ...]]:
        grouped: dict[str, list[Image.Image]] = {}
        for asset in self.catalog.assets("student", purpose):
            if asset.identity is None:
                continue
            with Image.open(self.catalog.resolve(asset.path)) as source:
                normalized = _normalize_mask(source.convert("L"))
            if normalized is not None:
                grouped.setdefault(asset.identity, []).append(normalized)
        if set(grouped) != set("0123456789"):
            raise ScannerError("template_missing", f"{purpose} templates are incomplete")
        return {label: tuple(samples) for label, samples in grouped.items()}

    def _skill_templates(self) -> dict[str, dict[str, tuple[Image.Image, ...]]]:
        grouped: dict[str, dict[str, list[Image.Image]]] = {"ex": {}, "normal": {}}
        for asset in self.catalog.assets("student", "student-basic-skill-template"):
            path = self.catalog.resolve(asset.path)
            group = "ex" if "/ex/" in asset.path else "normal"
            label = path.stem.split("_", 1)[0]
            with Image.open(path) as source:
                mask = _mask_from_predicate(
                    source,
                    lambda pixel: max(pixel) < 180 and max(pixel) - min(pixel) < 90,
                )
                normalized = _normalize_mask(mask, size=(48, 24), padding=1)
            if normalized is not None:
                grouped[group].setdefault(label, []).append(normalized)
        if not grouped["ex"] or not grouped["normal"]:
            raise ScannerError("template_missing", "student basic skill templates are incomplete")
        return {
            group: {label: tuple(samples) for label, samples in labels.items()}
            for group, labels in grouped.items()
        }

    def _combat_templates(self) -> tuple[
        dict[str, tuple[Image.Image, ...]],
        dict[tuple[str, int], dict[str, tuple[Image.Image, ...]]],
    ]:
        shared: dict[str, list[Image.Image]] = {}
        positioned: dict[tuple[str, int], dict[str, list[Image.Image]]] = {}
        for asset in self.catalog.assets("student", "student-basic-combat-digit-template"):
            if asset.identity is None:
                continue
            path = self.catalog.resolve(asset.path)
            with Image.open(path) as source:
                normalized = _normalize_mask(source.convert("L"))
            if normalized is None:
                continue
            shared.setdefault(asset.identity, []).append(normalized)
            parts = path.stem.rsplit("_", 2)
            if len(parts) == 3 and parts[1] in {"hp", "atk", "def", "heal"}:
                try:
                    position = int(parts[2])
                except ValueError:
                    continue
                positioned.setdefault((parts[1], position), {}).setdefault(asset.identity, []).append(normalized)
        if set(shared) != set("0123456789"):
            raise ScannerError("template_missing", "student combat digit templates are incomplete")
        return (
            {label: tuple(samples) for label, samples in shared.items()},
            {
                key: {label: tuple(samples) for label, samples in labels.items()}
                for key, labels in positioned.items()
            },
        )

    def read_skill(self, crop: Image.Image | None, *, is_ex: bool) -> Observation:
        if crop is None:
            return Observation(None, 0.0, "region_missing", "basic_skill_template", "crop missing")
        group = "ex" if is_ex else "normal"
        glyph = _normalize_mask(
            _mask_from_predicate(
                crop,
                lambda pixel: max(pixel) < 180 and max(pixel) - min(pixel) < 90,
            ),
            size=(48, 24),
            padding=1,
        )
        if glyph is None:
            return Observation(None, 0.0, "uncertain", "basic_skill_template", "glyph missing")
        ranked = sorted(
            (
                (label, max(_binary_iou(glyph, sample) for sample in samples))
                for label, samples in self.skill_templates[group].items()
            ),
            key=lambda item: item[1], reverse=True,
        )
        label, score = ranked[0]
        margin = score - (ranked[1][1] if len(ranked) > 1 else 0.0)
        value = (5 if is_ex else 10) if label == "max" else int(label)
        confident = score >= 0.70 and margin >= 0.05
        return Observation(
            value if confident else None, score, "ok" if confident else "uncertain",
            "basic_skill_template", f"group={group};label={label};margin={margin:.6f}",
        )

    def read_level(self, crop: Image.Image | None) -> Observation:
        if crop is None:
            return Observation(None, 0.0, "region_missing", "basic_level_glyph", "crop missing")
        rgb = crop.convert("RGB")
        mask = _mask_from_predicate(
            rgb,
            lambda pixel: _luminance(pixel) >= 150 and max(pixel) - min(pixel) <= 95,
        )
        midpoint = mask.width // 2
        cells = (mask.crop((0, 0, max(1, midpoint - 3), mask.height)), mask.crop((midpoint + 3, 0, mask.width, mask.height)))
        results = [_rank_glyph(_normalize_mask(cell), self.level_templates) for cell in cells]
        second_occupancy = sum(value >= 127 for value in _pixels(cells[1])) / max(1, cells[1].width * cells[1].height)
        selected = results if second_occupancy >= 0.025 else results[:1]
        if any(label is None for label, _score, _margin in selected):
            return Observation(None, 0.0, "uncertain", "basic_level_glyph", "glyph missing")
        value = int("".join(str(label) for label, _score, _margin in selected))
        score = min(item[1] for item in selected)
        margin = min(item[2] for item in selected)
        confident = 1 <= value <= 100 and score >= 0.58 and margin >= 0.02
        return Observation(
            value if confident else None, score, "ok" if confident else "uncertain",
            "basic_level_glyph", f"value={value};margin={margin:.6f};second_occupancy={second_occupancy:.6f}",
        )

    @staticmethod
    def _color_bbox(crop: Image.Image, hue_min: float, hue_max: float, saturation_min: float, value_min: float) -> tuple[int, int, int, int] | None:
        points: list[tuple[int, int]] = []
        rgb = crop.convert("RGB")
        for y in range(rgb.height):
            for x in range(rgb.width):
                red, green, blue = rgb.getpixel((x, y))
                hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
                degrees = hue * 360.0
                if hue_min <= degrees <= hue_max and saturation >= saturation_min and value >= value_min:
                    points.append((x, y))
        if not points:
            return None
        return min(x for x, _y in points), min(y for _x, y in points), max(x for x, _y in points) + 1, max(y for _x, y in points) + 1

    def read_student_star(self, crop: Image.Image | None) -> Observation:
        if crop is None:
            return Observation(None, 0.0, "region_missing", "basic_star_color", "crop missing")
        box = self._color_bbox(crop, 30.0, 84.0, 0.31, 0.47)
        if box is None:
            return Observation(None, 0.0, "uncertain", "basic_star_color", "yellow foreground missing")
        width, height = box[2] - box[0], box[3] - box[1]
        raw = 1.0 + max(0.0, width - height) / max(1.0, 0.79 * height)
        value = max(1, min(5, round(raw)))
        residual = abs(raw - value)
        score = max(0.0, min(1.0, 1.0 - residual / 0.35))
        confident = height >= 8 and residual <= 0.20
        return Observation(value if confident else None, score, "ok" if confident else "uncertain", "basic_star_color", f"raw={raw:.6f}")

    def read_weapon_level(self, crop: Image.Image | None) -> Observation:
        if crop is None:
            return Observation(None, 0.0, "region_missing", "basic_weapon_level_glyph", "crop missing")
        mask = _mask_from_predicate(crop, lambda pixel: min(pixel) >= 238 and max(pixel) - min(pixel) <= 28)
        midpoint = mask.width // 2
        cells = (mask.crop((0, 0, max(1, midpoint - 1), mask.height)), mask.crop((midpoint + 1, 0, mask.width, mask.height)))
        selected = []
        for index, cell in enumerate(cells):
            occupancy = sum(value >= 127 for value in _pixels(cell)) / max(1, cell.width * cell.height)
            if index == 1 and occupancy < 0.012:
                break
            selected.append(_rank_glyph(_normalize_mask(cell), self.weapon_level_templates))
        if not selected or any(label is None for label, _score, _margin in selected):
            return Observation(None, 0.0, "uncertain", "basic_weapon_level_glyph", "glyph missing")
        value = int("".join(str(item[0]) for item in selected))
        score = min(item[1] for item in selected)
        margin = min(item[2] for item in selected)
        confident = 1 <= value <= 60 and score >= 0.58 and margin >= 0.04
        return Observation(value if confident else None, score, "ok" if confident else "uncertain", "basic_weapon_level_glyph", f"value={value};margin={margin:.6f}")

    def read_weapon_star(self, crop: Image.Image | None) -> Observation:
        if crop is None:
            return Observation(None, 0.0, "region_missing", "basic_weapon_star_color", "crop missing")
        box = self._color_bbox(crop, 160.0, 230.0, 0.235, 0.39)
        if box is None:
            return Observation(None, 0.0, "uncertain", "basic_weapon_star_color", "cyan foreground missing")
        width, height = box[2] - box[0], box[3] - box[1]
        raw = width / max(1.0, 0.97 * height)
        value = round(raw)
        residual = abs(raw - value)
        score = max(0.0, min(1.0, 1.0 - residual / 0.50))
        confident = 1 <= value <= 5 and height >= 4 and residual <= 0.22
        return Observation(value if confident else None, score, "ok" if confident else "uncertain", "basic_weapon_star_color", f"raw={raw:.6f}")

    @staticmethod
    def _combat_state(crop: Image.Image) -> str:
        pixels = list(_pixels(crop.convert("RGB")))
        if sum(max(pixel) for pixel in pixels) / max(1, len(pixels)) < 30:
            return "EMPTY"
        blue = sum(
            pixel[2] - pixel[0] > 25 and pixel[2] - pixel[1] > 5 and 70 <= pixel[2] <= 190 and pixel[0] < 150
            for pixel in pixels
        ) / max(1, len(pixels))
        if blue >= 0.08:
            return "LV"
        dark = sum(max(pixel) < 180 and max(pixel) - min(pixel) < 90 for pixel in pixels) / max(1, len(pixels))
        return "EMPTY" if dark <= 0.02 else "DIGIT"

    def read_combat(self, cells: tuple[Image.Image, ...] | None, group: str, min_digits: int) -> Observation:
        if not cells:
            return Observation(None, 0.0, "region_missing", "basic_combat_digit", "cells missing")
        digits: list[str] = []
        scores: list[float] = []
        margins: list[float] = []
        terminal = "LIMIT"
        for position, crop in enumerate(cells):
            state = self._combat_state(crop)
            if state != "DIGIT":
                terminal = state
                break
            mask = _mask_from_predicate(crop, lambda pixel: max(pixel) < 180 and max(pixel) - min(pixel) < 90)
            local = self.combat_position_templates.get((group, position), {})
            templates = {
                label: local.get(label, samples)
                for label, samples in self.combat_templates.items()
            }
            label, score, margin = _rank_glyph(_normalize_mask(mask), templates)
            if label is None or score < 0.58 or margin < 0.015:
                return Observation(None, score, "uncertain", "basic_combat_digit", f"group={group};position={position + 1};label={label};margin={margin:.6f}")
            digits.append(label)
            scores.append(score)
            margins.append(margin)
        if len(digits) < min_digits:
            return Observation(None, min(scores, default=0.0), "uncertain", "basic_combat_digit", f"group={group};digits={len(digits)};stop={terminal}")
        value = int("".join(digits))
        return Observation(value, min(scores), "ok", "basic_combat_digit", f"group={group};margin={min(margins):.6f};stop={terminal}")

    def recognize(self, crops: StudentBasicCropSet) -> dict[str, Observation]:
        result = {
            "level": self.read_level(crops.images.get("basic_level_digits_quad")),
            "student_star": self.read_student_star(crops.images.get("basic_student_stars_quad")),
            "ex_skill": self.read_skill(crops.images.get("basic_EX_skill"), is_ex=True),
            "skill1": self.read_skill(crops.images.get("basic_Skill_1"), is_ex=False),
            "skill2": self.read_skill(crops.images.get("basic_Skill_2"), is_ex=False),
            "skill3": self.read_skill(crops.images.get("basic_Skill_3"), is_ex=False),
            "weapon_level": self.read_weapon_level(crops.images.get("basic_weapon_level_digits_quad")),
            "weapon_star": self.read_weapon_star(crops.images.get("basic_weapon_star_region")),
            "combat_hp": self.read_combat(crops.cell_groups.get("basic_combat_hp_digits"), "hp", 4),
            "combat_atk": self.read_combat(crops.cell_groups.get("basic_combat_atk_digits"), "atk", 2),
            "combat_def": self.read_combat(crops.cell_groups.get("basic_combat_def_digits"), "def", 1),
            "combat_heal": self.read_combat(crops.cell_groups.get("basic_combat_heal_digits"), "heal", 2),
        }
        weapon_evidence = (result["weapon_level"], result["weapon_star"])
        if all(item.confirmed for item in weapon_evidence):
            result["weapon_state"] = Observation("weapon_equipped", min(item.confidence for item in weapon_evidence), "inferred", "basic_weapon_values", "level and star both confirmed")
        else:
            result["weapon_state"] = Observation(None, min(item.confidence for item in weapon_evidence), "uncertain", "basic_weapon_values", "weapon values not both confirmed")
        return result
