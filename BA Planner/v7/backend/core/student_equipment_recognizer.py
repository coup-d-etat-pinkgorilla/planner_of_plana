from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
import json
from pathlib import Path
from math import sqrt
from time import perf_counter
from typing import Any, Iterable

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageStat

from core import student_meta
from core.recognition_assets import RecognitionAssetCatalog
from core.student_scan_recognizer import Observation, StudentBasicCropSet


EQUIPMENT_MAX_LEVEL = {
    "T1": 10, "T2": 20, "T3": 30, "T4": 40, "T5": 45,
    "T6": 50, "T7": 55, "T8": 60, "T9": 65, "T10": 70,
}
EQUIPMENT_UNLOCK_LEVEL = {1: 1, 2: 10, 3: 20}
EQUIPMENT_SLOT_CARD_X = {1: 1356, 2: 1542, 3: 1728}
EQUIPMENT_SLOT_TEXT_X = {1: 1419, 2: 1605, 3: 1791}
EQUIPMENT_CARD_Y = 1114
EQUIPMENT_REFERENCE_SIZE = (2560, 1440)
GENERATED_BINARY_VARIANTS = ("outline", "fill_outline", "fill")


def _pixels(image: Image.Image):
    flattened = getattr(image, "get_flattened_data", None)
    return flattened() if flattened is not None else image.getdata()


def equipment_level_matches_tier(level: int, tier: str) -> bool:
    maximum = EQUIPMENT_MAX_LEVEL.get(tier)
    return maximum is not None and 1 <= level <= maximum


def _mean_difference(left: Image.Image, right: Image.Image) -> float:
    right = right.resize(left.size, Image.Resampling.BILINEAR)
    stat = ImageStat.Stat(ImageChops.difference(left, right))
    return max(0.0, 1.0 - sum(stat.mean) / (len(stat.mean) * 255.0))


def _normalized_correlation(left: Image.Image, right: Image.Image) -> float:
    right = right.resize(left.size, Image.Resampling.BILINEAR)
    a = list(_pixels(left.convert("L")))
    b = list(_pixels(right.convert("L")))
    if not a:
        return 0.0
    mean_a = sum(a) / len(a)
    mean_b = sum(b) / len(b)
    numerator = sum((x - mean_a) * (y - mean_b) for x, y in zip(a, b))
    denominator_a = sum((x - mean_a) ** 2 for x in a) ** 0.5
    denominator_b = sum((y - mean_b) ** 2 for y in b) ** 0.5
    if denominator_a == 0.0 or denominator_b == 0.0:
        return 0.0
    return max(0.0, min(1.0, numerator / (denominator_a * denominator_b)))


def _normalize_gray(image: Image.Image) -> Image.Image:
    gray = image.convert("L").filter(ImageFilter.GaussianBlur(radius=0.7))
    histogram = gray.histogram()
    count = max(1, gray.width * gray.height)
    low_target, high_target = count * 0.02, count * 0.98
    cumulative = 0
    low = 0
    high = 255
    for index, amount in enumerate(histogram):
        cumulative += amount
        if cumulative >= low_target:
            low = index
            break
    cumulative = 0
    for index, amount in enumerate(histogram):
        cumulative += amount
        if cumulative >= high_target:
            high = index
            break
    if high <= low:
        return Image.new("L", gray.size)
    return gray.point(lambda value: max(0, min(255, round((value - low) * 255 / (high - low)))))


def _dark_ink_mask(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    mask = Image.new("L", rgb.size)
    mask.putdata([
        255 if blue - red >= 10 and max(red, green, blue) < 195 else 0
        for red, green, blue in _pixels(rgb)
    ])
    return mask


def _light_text_mask(image: Image.Image) -> Image.Image:
    """Extract the near-white level fill without accepting the pale card background."""

    rgba = image.convert("RGBA")
    mask = Image.new("L", rgba.size)
    mask.putdata([
        255 if alpha >= 32 and min(red, green, blue) >= 238
        and max(red, green, blue) - min(red, green, blue) <= 18 else 0
        for red, green, blue, alpha in _pixels(rgba)
    ])
    rgba.close()
    return mask


def _retain_tall_components(mask: Image.Image) -> Image.Image:
    """Keep digit-sized 8-connected components and reject card/icon speckles."""

    binary = mask.convert("L").point(lambda value: 255 if value >= 127 else 0)
    width, height = binary.size
    pixels = binary.load()
    seen: set[tuple[int, int]] = set()
    retained: list[list[tuple[int, int]]] = []
    minimum_height = max(6, round(height * 0.45))
    for y in range(height):
        for x in range(width):
            if not pixels[x, y] or (x, y) in seen:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            component: list[tuple[int, int]] = []
            while stack:
                current_x, current_y = stack.pop()
                component.append((current_x, current_y))
                for offset_y in (-1, 0, 1):
                    for offset_x in (-1, 0, 1):
                        next_x, next_y = current_x + offset_x, current_y + offset_y
                        if (
                            (offset_x or offset_y)
                            and 0 <= next_x < width and 0 <= next_y < height
                            and pixels[next_x, next_y]
                            and (next_x, next_y) not in seen
                        ):
                            seen.add((next_x, next_y))
                            stack.append((next_x, next_y))
            xs = [point[0] for point in component]
            ys = [point[1] for point in component]
            if len(component) >= 6 and max(xs) - min(xs) + 1 >= 2 and max(ys) - min(ys) + 1 >= minimum_height:
                retained.append(component)
    result = Image.new("L", binary.size)
    output = result.load()
    for component in retained:
        for x, y in component:
            output[x, y] = 255
    binary.close()
    return result


def _component_count(mask: Image.Image) -> int:
    binary = mask.convert("L").point(lambda value: 255 if value >= 127 else 0)
    width, height = binary.size
    pixels = binary.load()
    seen: set[tuple[int, int]] = set()
    count = 0
    for y in range(height):
        for x in range(width):
            if not pixels[x, y] or (x, y) in seen:
                continue
            count += 1
            stack = [(x, y)]
            seen.add((x, y))
            while stack:
                current_x, current_y = stack.pop()
                for offset_y in (-1, 0, 1):
                    for offset_x in (-1, 0, 1):
                        next_point = (current_x + offset_x, current_y + offset_y)
                        if (
                            (offset_x or offset_y)
                            and 0 <= next_point[0] < width and 0 <= next_point[1] < height
                            and pixels[next_point[0], next_point[1]]
                            and next_point not in seen
                        ):
                            seen.add(next_point)
                            stack.append(next_point)
    binary.close()
    return count


def _text_mask_variants(image: Image.Image) -> dict[str, Image.Image]:
    """Return text-only fill/outline masks using the white fill as the locality seed."""

    light = _light_text_mask(image)
    fill = _retain_tall_components(light)
    light.close()
    dark = _dark_ink_mask(image)
    locality = fill.filter(ImageFilter.MaxFilter(7))
    outline = ImageChops.multiply(dark, locality)
    fill_outline = ImageChops.lighter(fill, outline)
    dark.close()
    locality.close()
    return {"outline": outline, "fill_outline": fill_outline, "fill": fill}


def _normalize_mask(mask: Image.Image, size: tuple[int, int] = (20, 28)) -> Image.Image | None:
    source = mask.convert("L").point(lambda value: 255 if value >= 127 else 0)
    box = source.getbbox()
    if box is None:
        return None
    glyph = source.crop(box)
    scale = min((size[0] - 4) / glyph.width, (size[1] - 4) / glyph.height)
    glyph = glyph.resize(
        (max(1, round(glyph.width * scale)), max(1, round(glyph.height * scale))),
        Image.Resampling.NEAREST,
    )
    result = Image.new("L", size)
    result.paste(glyph, ((size[0] - glyph.width) // 2, (size[1] - glyph.height) // 2))
    return result


def _binary_iou(left: Image.Image, right: Image.Image) -> float:
    right = right.resize(left.size, Image.Resampling.NEAREST)
    a = [value >= 127 for value in _pixels(left.convert("L"))]
    b = [value >= 127 for value in _pixels(right.convert("L"))]
    union = sum(x or y for x, y in zip(a, b))
    return sum(x and y for x, y in zip(a, b)) / union if union else 0.0


@dataclass(frozen=True, slots=True)
class PreparedBinaryGlyph:
    """Compact 20x28 binary glyph used by the S3B equipment-only matcher."""

    bits: int
    ink: int
    pixels: int

    @classmethod
    def from_mask(cls, mask: Image.Image | None) -> "PreparedBinaryGlyph | None":
        if mask is None:
            return None
        bits = 0
        ink = 0
        values = list(_pixels(mask.convert("L")))
        for index, value in enumerate(values):
            if value >= 127:
                bits |= 1 << index
                ink += 1
        return cls(bits=bits, ink=ink, pixels=len(values)) if ink else None

    def compare(self, other: "PreparedBinaryGlyph") -> tuple[float, float, float]:
        if self.pixels != other.pixels or not self.ink or not other.ink:
            return 0.0, 0.0, 0.0
        intersection = (self.bits & other.bits).bit_count()
        union = self.ink + other.ink - intersection
        iou = intersection / union if union else 0.0
        denominator = sqrt(
            self.ink * (self.pixels - self.ink)
            * other.ink * (other.pixels - other.ink)
        )
        correlation = (
            (self.pixels * intersection - self.ink * other.ink) / denominator
            if denominator else 0.0
        )
        correlation = max(-1.0, min(1.0, correlation))
        normalized_correlation = (correlation + 1.0) / 2.0
        return 0.75 * iou + 0.25 * normalized_correlation, iou, normalized_correlation


@dataclass(frozen=True, slots=True)
class PreparedFeature:
    rgb: Image.Image
    gray: Image.Image
    edge: Image.Image
    glyph: Image.Image | None

    @classmethod
    def from_image(cls, image: Image.Image) -> "PreparedFeature":
        rgb = image.convert("RGB")
        gray = _normalize_gray(rgb)
        edge = gray.filter(ImageFilter.FIND_EDGES)
        glyph = _normalize_mask(_dark_ink_mask(rgb))
        return cls(rgb=rgb, gray=gray, edge=edge, glyph=glyph)

    @property
    def byte_size(self) -> int:
        return self.rgb.width * self.rgb.height * 3 + self.gray.width * self.gray.height * 2 + (
            self.glyph.width * self.glyph.height if self.glyph is not None else 0
        )

    def close(self) -> None:
        self.rgb.close()
        self.gray.close()
        self.edge.close()
        if self.glyph is not None:
            self.glyph.close()


@dataclass(slots=True)
class EquipmentMetrics:
    template_load_ms: float = 0.0
    feature_prepare_ms: float = 0.0
    match_ms: float = 0.0
    cache_hits: int = 0
    cache_misses: int = 0
    generated_cards: int = 0
    prepared_features: int = 0
    loaded_files: int = 0
    menu_captures: int = 0
    peak_cache_entries: int = 0
    peak_cache_bytes: int = 0
    full_size_reference_canvases: int = 0
    empirical_attempts: int = 0
    empirical_hits: int = 0
    calibration_samples: int = 0
    binary_template_prepare_ms: float = 0.0
    binary_template_count: int = 0
    binary_template_bytes: int = 0
    binary_attempts: int = 0
    binary_shadow_hits: int = 0
    binary_shift_retries: int = 0
    binary_match_ms: float = 0.0
    generated_binary_template_prepare_ms: float = 0.0
    generated_binary_template_count: int = 0
    generated_binary_template_bytes: int = 0
    generated_binary_attempts: int = 0
    generated_binary_shadow_hits: int = 0
    generated_binary_match_ms: float = 0.0
    position_binary_template_prepare_ms: float = 0.0
    position_binary_template_count: int = 0
    position_binary_template_bytes: int = 0
    position_binary_attempts: int = 0
    position_binary_shadow_hits: int = 0
    position_binary_match_ms: float = 0.0
    direct_tier_template_prepare_ms: float = 0.0
    direct_tier_template_count: int = 0
    direct_tier_template_bytes: int = 0
    direct_tier_attempts: int = 0
    direct_tier_hits: int = 0
    direct_tier_match_ms: float = 0.0

    def to_dict(self) -> dict[str, float | int]:
        return {name: getattr(self, name) for name in self.__dataclass_fields__}


class PreparedFeatureCache:
    """Bounded LRU that owns only compact candidate cells, never source captures."""

    def __init__(self, maximum: int, metrics: EquipmentMetrics) -> None:
        if maximum < 1:
            raise ValueError("feature cache maximum must be positive")
        self.maximum = maximum
        self.metrics = metrics
        self._entries: OrderedDict[tuple[Any, ...], PreparedFeature] = OrderedDict()

    def get(self, key: tuple[Any, ...]) -> PreparedFeature | None:
        value = self._entries.get(key)
        if value is None:
            self.metrics.cache_misses += 1
            return None
        self._entries.move_to_end(key)
        self.metrics.cache_hits += 1
        return value

    def put(self, key: tuple[Any, ...], value: PreparedFeature) -> PreparedFeature:
        replaced = self._entries.pop(key, None)
        if replaced is not None:
            replaced.close()
        self._entries[key] = value
        while len(self._entries) > self.maximum:
            _old_key, old_value = self._entries.popitem(last=False)
            old_value.close()
        size = sum(item.byte_size for item in self._entries.values())
        self.metrics.peak_cache_entries = max(self.metrics.peak_cache_entries, len(self._entries))
        self.metrics.peak_cache_bytes = max(self.metrics.peak_cache_bytes, size)
        return value

    def close(self) -> None:
        for value in self._entries.values():
            value.close()
        self._entries.clear()

    def __len__(self) -> int:
        return len(self._entries)


def _feature_similarity(screen: PreparedFeature, candidate: PreparedFeature) -> float:
    rgb = _mean_difference(screen.rgb, candidate.rgb)
    gray = _mean_difference(screen.gray, candidate.gray)
    edge = _mean_difference(screen.edge, candidate.edge)
    return 0.15 * rgb + 0.60 * gray + 0.25 * edge


class StudentEquipmentRecognizer:
    """v7 S3 basic-screen equipment fast path with a small-ROI generated fallback."""

    def __init__(
        self,
        catalog: RecognitionAssetCatalog,
        *,
        cache_size: int = 384,
        level_threshold: float = 0.60,
        level_margin: float = 0.025,
        binary_shadow_threshold: float = 0.52,
        binary_shadow_margin: float = 0.04,
        direct_tier_threshold: float = 0.65,
        direct_tier_margin: float = 0.08,
    ) -> None:
        started = perf_counter()
        self.catalog = catalog
        self.metrics = EquipmentMetrics()
        self.cache = PreparedFeatureCache(cache_size, self.metrics)
        self.level_threshold = level_threshold
        self.level_margin = level_margin
        # Shared binary gates. Legacy menu-domain and whole-string paths remain shadow-only.
        self.binary_shadow_threshold = binary_shadow_threshold
        self.binary_shadow_margin = binary_shadow_margin
        self.direct_tier_threshold = direct_tier_threshold
        self.direct_tier_margin = direct_tier_margin
        self.binary_production_enabled = False
        self.generated_binary_production_enabled = False
        self.position_binary_production_enabled = True
        self.direct_tier_production_enabled = True
        self._card_cache: OrderedDict[tuple[str, str], Image.Image] = OrderedDict()
        self._font: ImageFont.FreeTypeFont | ImageFont.ImageFont | None = None
        self._favorite_templates = self._load_images("student-equipment-favorite-template")
        binary_started = perf_counter()
        self._binary_templates = self._load_binary_templates()
        self.metrics.binary_template_prepare_ms = (perf_counter() - binary_started) * 1000.0
        self._generated_binary_templates: dict[str, dict[int, PreparedBinaryGlyph]] = {}
        self.last_binary_shadow: dict[str, Observation] = {}
        self.last_generated_binary_shadow: dict[str, Observation] = {}
        position_started = perf_counter()
        self._position_binary_templates = self._load_position_binary_templates()
        self.metrics.position_binary_template_prepare_ms = (perf_counter() - position_started) * 1000.0
        self.last_position_binary_shadow: dict[str, Observation] = {}
        direct_tier_started = perf_counter()
        self._direct_tier_templates = self._load_direct_tier_templates()
        self.metrics.direct_tier_template_prepare_ms = (perf_counter() - direct_tier_started) * 1000.0
        self._empirical: dict[tuple[int, int], dict[str, list[Image.Image]]] = {}
        self.metrics.template_load_ms = (perf_counter() - started) * 1000.0

    def _load_images(self, purpose: str) -> dict[str, Image.Image]:
        result: dict[str, Image.Image] = {}
        for asset in self.catalog.assets("student", purpose):
            if asset.identity is None:
                continue
            with Image.open(self.catalog.resolve(asset.path)) as source:
                result[asset.identity] = source.convert("RGB")
            self.metrics.loaded_files += 1
        return result

    def _load_binary_templates(
        self,
    ) -> dict[tuple[int, int], dict[str, tuple[PreparedBinaryGlyph, ...]]]:
        grouped: dict[tuple[int, int], dict[str, list[PreparedBinaryGlyph]]] = {}
        for asset in self.catalog.assets("student", "student-equipment-menu-digit-template"):
            if asset.identity is None:
                continue
            parts = asset.identity.split(":", 2)
            if len(parts) != 3 or not parts[0].isdigit() or not parts[1].isdigit():
                continue
            slot, position, label = int(parts[0]), int(parts[1]), parts[2]
            if slot not in (1, 2, 3) or position not in (1, 2) or not label.isdigit():
                continue
            with Image.open(self.catalog.resolve(asset.path)) as source:
                normalized = _normalize_mask(source.convert("L"))
            prepared = PreparedBinaryGlyph.from_mask(normalized)
            if normalized is not None:
                normalized.close()
            if prepared is None:
                continue
            grouped.setdefault((slot, position), {}).setdefault(label, []).append(prepared)
            self.metrics.loaded_files += 1
            self.metrics.binary_template_count += 1
            self.metrics.binary_template_bytes += (prepared.pixels + 7) // 8
        return {
            key: {label: tuple(samples) for label, samples in labels.items()}
            for key, labels in grouped.items()
        }

    def _load_position_binary_templates(self) -> dict[int, dict[str, PreparedBinaryGlyph]]:
        path = self._asset("student-equipment-position-digit-bank")
        if path is None:
            return {}
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError, TypeError):
            return {}
        result: dict[int, dict[str, PreparedBinaryGlyph]] = {}
        for raw in payload.get("templates", []):
            try:
                position = int(raw["position"])
                digit = str(raw["digit"])
                prepared = PreparedBinaryGlyph(
                    bits=int(str(raw["bits_hex"]), 16),
                    ink=int(raw["ink"]),
                    pixels=int(raw["pixels"]),
                )
            except (KeyError, TypeError, ValueError):
                continue
            if position not in (1, 2) or not digit.isdigit() or len(digit) != 1:
                continue
            result.setdefault(position, {})[digit] = prepared
            self.metrics.position_binary_template_count += 1
            self.metrics.position_binary_template_bytes += (prepared.pixels + 7) // 8
        self.metrics.loaded_files += int(bool(result))
        return result

    def _load_direct_tier_templates(self) -> dict[str, dict[str, PreparedFeature]]:
        metadata_path = self._asset("student-equipment-basic-tier-roi-metadata")
        if metadata_path is None:
            return {}
        try:
            payload = json.loads(metadata_path.read_text(encoding="utf-8"))
            atlas_path = self.catalog.resolve(str(payload["atlas_path"]))
            with Image.open(atlas_path) as source:
                atlas = source.convert("RGB")
        except (OSError, ValueError, TypeError, KeyError):
            return {}
        result: dict[str, dict[str, PreparedFeature]] = {}
        try:
            for raw in payload.get("records", []):
                try:
                    family = str(raw["family"])
                    tier = str(raw["tier"])
                    box = tuple(int(value) for value in raw["atlas_box"])
                except (KeyError, TypeError, ValueError):
                    continue
                if tier not in EQUIPMENT_MAX_LEVEL or len(box) != 4:
                    continue
                crop = atlas.crop(box)
                prepared = PreparedFeature.from_image(crop)
                crop.close()
                result.setdefault(family, {})[tier] = prepared
                self.metrics.direct_tier_template_count += 1
                self.metrics.direct_tier_template_bytes += prepared.byte_size
        finally:
            atlas.close()
        if any(set(group) != set(EQUIPMENT_MAX_LEVEL) for group in result.values()):
            for group in result.values():
                for prepared in group.values():
                    prepared.close()
            return {}
        self.metrics.loaded_files += 2
        return result

    @staticmethod
    def _position_fill_glyph(cell: Image.Image) -> PreparedBinaryGlyph | None:
        variants = _text_mask_variants(cell)
        normalized: Image.Image | None = None
        try:
            if _component_count(variants["fill"]) != 1:
                return None
            normalized = _normalize_mask(variants["fill"])
            return PreparedBinaryGlyph.from_mask(normalized)
        finally:
            if normalized is not None:
                normalized.close()
            for mask in variants.values():
                mask.close()

    def read_position_binary_level(
        self,
        crop: Image.Image | None,
        *,
        tier: str,
        region: dict[str, Any],
    ) -> Observation:
        """Read fixed first/second level positions from the 19-mask compact bank."""

        self.metrics.position_binary_attempts += 1
        started = perf_counter()
        if crop is None or tier not in EQUIPMENT_MAX_LEVEL or set(self._position_binary_templates) != {1, 2}:
            self.metrics.position_binary_match_ms += (perf_counter() - started) * 1000.0
            return Observation(
                None, 0.0, "shadow", "equipment_position_binary_shadow",
                "context_crop_or_templates_missing;production_enabled=false",
            )
        cells = self._level_cells(crop, region)
        labels: list[str] = []
        scores: list[float] = []
        margins: list[float] = []
        try:
            for position, cell in enumerate(cells, start=1):
                screen = self._position_fill_glyph(cell)
                if screen is None:
                    if position == 2 and labels:
                        labels.append("blank")
                        scores.append(1.0)
                        margins.append(1.0)
                        continue
                    return Observation(
                        None, 0.0, "shadow", "equipment_position_binary_shadow",
                        f"position={position};feature_missing;production_enabled=false",
                    )
                ranked = sorted(
                    (
                        (digit, *screen.compare(template))
                        for digit, template in self._position_binary_templates[position].items()
                    ),
                    key=lambda item: item[1], reverse=True,
                )
                if len(ranked) < 2:
                    return Observation(
                        None, 0.0, "shadow", "equipment_position_binary_shadow",
                        f"position={position};competitors_missing;production_enabled=false",
                    )
                labels.append(ranked[0][0])
                scores.append(ranked[0][1])
                margins.append(ranked[0][1] - ranked[1][1])
            value = int("".join(label for label in labels if label != "blank"))
            confident = (
                equipment_level_matches_tier(value, tier)
                and min(scores) >= self.binary_shadow_threshold
                and min(margins) >= self.binary_shadow_margin
            )
            if confident:
                self.metrics.position_binary_shadow_hits += 1
            production = confident and self.position_binary_production_enabled
            return Observation(
                value if confident else None,
                min(scores),
                "ok" if production else "shadow",
                "equipment_position_binary" if production else "equipment_position_binary_shadow",
                (
                    f"tier={tier};candidate={value};labels={labels};margin={min(margins):.6f};"
                    f"production_enabled={str(self.position_binary_production_enabled).lower()}"
                ),
            )
        finally:
            self.metrics.position_binary_match_ms += (perf_counter() - started) * 1000.0
            for cell in cells:
                cell.close()

    def _asset(self, purpose: str) -> Path | None:
        assets = self.catalog.assets("student", purpose)
        return self.catalog.resolve(assets[0].path) if assets else None

    def _get_font(self):
        if self._font is None:
            path = self._asset("student-equipment-font")
            self._font = ImageFont.truetype(str(path), 28) if path is not None else ImageFont.load_default()
            self.metrics.loaded_files += int(path is not None)
        return self._font

    def _base_card(self, family: str, tier: str) -> Image.Image | None:
        key = (family, tier)
        cached = self._card_cache.get(key)
        if cached is not None:
            self._card_cache.move_to_end(key)
            return cached
        background_path = self._asset("student-equipment-card-background")
        icon_path = self.catalog.root / "templates" / "inventory" / "equipment" / f"Equipment_Icon_{family}_{tier.replace('T', 'Tier')}.png"
        if background_path is None or not icon_path.is_file():
            return None
        with Image.open(background_path) as source:
            card = source.convert("RGBA").resize((200, 160), Image.Resampling.LANCZOS)
        with Image.open(icon_path) as source:
            icon = source.convert("RGBA").resize((199, 157), Image.Resampling.LANCZOS)
        card.alpha_composite(icon)
        icon.close()
        self.metrics.loaded_files += 2
        self._card_cache[key] = card
        while len(self._card_cache) > 96:
            _old_key, old = self._card_cache.popitem(last=False)
            old.close()
        return card

    def _render_level(self, value: int) -> Image.Image:
        canvas = Image.new("RGBA", (179, 63))
        ImageDraw.Draw(canvas).text(
            (2, 2), f" {value}", font=self._get_font(), fill="#FFFFFF",
            stroke_width=1, stroke_fill="#505878",
        )
        shear = -0.25
        return canvas.transform(
            canvas.size, Image.Transform.AFFINE, (1, -shear, 0, 0, 1, 0),
            resample=Image.Resampling.BICUBIC,
        )

    def _generated_text_crop(
        self, slot: int, value: int, region: dict[str, Any],
    ) -> Image.Image | None:
        points = region.get("points_ratio")
        output = region.get("output_size", (48, 36))
        if slot not in EQUIPMENT_SLOT_TEXT_X or not isinstance(points, list) or len(points) != 4:
            return None
        layer = Image.new("RGBA", (200, 160))
        text_layer = self._render_level(value)
        layer.alpha_composite(
            text_layer,
            dest=(EQUIPMENT_SLOT_TEXT_X[slot] - EQUIPMENT_SLOT_CARD_X[slot], 6),
        )
        text_layer.close()
        try:
            reference_width, reference_height = EQUIPMENT_REFERENCE_SIZE
            local = [
                (
                    float(point["x"]) * reference_width - EQUIPMENT_SLOT_CARD_X[slot],
                    float(point["y"]) * reference_height - EQUIPMENT_CARD_Y,
                )
                for point in points
            ]
            top_left, top_right, bottom_right, bottom_left = local
            return layer.transform(
                (int(output[0]), int(output[1])), Image.Transform.QUAD,
                (*top_left, *bottom_left, *bottom_right, *top_right),
                resample=Image.Resampling.BICUBIC,
            )
        finally:
            layer.close()

    def _load_generated_binary_variant(
        self, variant: str,
    ) -> dict[int, PreparedBinaryGlyph]:
        regions = self.catalog.region("student")
        region = regions.get("basic_equipment_1_level_digits_quad", {})
        result: dict[int, PreparedBinaryGlyph] = {}
        if not isinstance(region, dict):
            return result
        for value in range(1, max(EQUIPMENT_MAX_LEVEL.values()) + 1):
            crop = self._generated_text_crop(1, value, region)
            if crop is None:
                continue
            variants = _text_mask_variants(crop)
            crop.close()
            try:
                normalized = _normalize_mask(variants[variant], size=(40, 28))
                prepared = PreparedBinaryGlyph.from_mask(normalized)
                if normalized is not None:
                    normalized.close()
                if prepared is None:
                    continue
                result[value] = prepared
                self.metrics.generated_binary_template_count += 1
                self.metrics.generated_binary_template_bytes += (prepared.pixels + 7) // 8
            finally:
                for mask in variants.values():
                    mask.close()
        return result

    def _ensure_generated_binary_variant(self, variant: str) -> None:
        if variant in self._generated_binary_templates:
            return
        started = perf_counter()
        self._generated_binary_templates[variant] = self._load_generated_binary_variant(variant)
        if variant != "fill":
            self.metrics.generated_binary_template_prepare_ms += (
                perf_counter() - started
            ) * 1000.0

    def read_generated_binary_level(
        self,
        crop: Image.Image | None,
        *,
        slot: int,
        tier: str,
        variant: str = "outline",
    ) -> Observation:
        """Rank a full level string against text-only generated glyphs in shadow mode."""

        self.metrics.generated_binary_attempts += 1
        started = perf_counter()
        if crop is None or tier not in EQUIPMENT_MAX_LEVEL or variant not in GENERATED_BINARY_VARIANTS:
            self.metrics.generated_binary_match_ms += (perf_counter() - started) * 1000.0
            return Observation(
                None, 0.0, "shadow", "equipment_generated_binary_shadow",
                f"slot={slot};tier={tier};variant={variant};context_or_crop_missing;production_enabled=false",
            )
        variants = _text_mask_variants(crop)
        normalized: Image.Image | None = None
        try:
            self._ensure_generated_binary_variant(variant)
            normalized = _normalize_mask(variants[variant], size=(40, 28))
            screen = PreparedBinaryGlyph.from_mask(normalized)
            candidates = self._generated_binary_templates.get(variant, {})
            ranked = sorted(
                (
                    (value, *screen.compare(template))
                    for value, template in candidates.items()
                    if value <= EQUIPMENT_MAX_LEVEL[tier]
                ),
                key=lambda item: item[1],
                reverse=True,
            ) if screen is not None else []
            if not ranked:
                return Observation(
                    None, 0.0, "shadow", "equipment_generated_binary_shadow",
                    f"slot={slot};tier={tier};variant={variant};feature_or_templates_missing;production_enabled=false",
                )
            value, score, iou, correlation = ranked[0]
            margin = score - (ranked[1][1] if len(ranked) > 1 else 0.0)
            confident = (
                equipment_level_matches_tier(value, tier)
                and score >= self.binary_shadow_threshold
                and margin >= self.binary_shadow_margin
            )
            if confident:
                self.metrics.generated_binary_shadow_hits += 1
            return Observation(
                value if confident else None,
                score,
                "shadow",
                "equipment_generated_binary_shadow",
                (
                    f"slot={slot};tier={tier};variant={variant};value={value};"
                    f"margin={margin:.6f};iou={iou:.6f};correlation={correlation:.6f};"
                    "layout=full_roi;production_enabled=false"
                ),
            )
        finally:
            self.metrics.generated_binary_match_ms += (perf_counter() - started) * 1000.0
            if normalized is not None:
                normalized.close()
            for mask in variants.values():
                mask.close()

    @staticmethod
    def _level_cells(crop: Image.Image, region: dict[str, Any]) -> tuple[Image.Image, Image.Image]:
        midpoint = crop.width // 2
        trim = min(max(0, int(region.get("center_trim_pixels", 0) or 0)), max(0, midpoint - 1))
        return (
            crop.crop((0, 0, midpoint - trim, crop.height)),
            crop.crop((midpoint + trim, 0, crop.width, crop.height)),
        )

    @staticmethod
    def _shifted_binary_glyph(cell: Image.Image, x_offset: int) -> PreparedBinaryGlyph | None:
        shifted = Image.new("RGB", cell.size)
        shifted.paste(cell.convert("RGB"), (x_offset, 0))
        normalized = _normalize_mask(_dark_ink_mask(shifted))
        shifted.close()
        prepared = PreparedBinaryGlyph.from_mask(normalized)
        if normalized is not None:
            normalized.close()
        return prepared

    def _rank_binary_glyphs(
        self,
        glyphs: list[PreparedBinaryGlyph],
        *,
        slot: int,
        position: int,
    ) -> tuple[str | None, float, float, float, float]:
        templates = self._binary_templates.get((slot, position), {})
        ranked: list[tuple[str, float, float, float]] = []
        for label, samples in templates.items():
            comparisons = [glyph.compare(sample) for glyph in glyphs for sample in samples]
            if comparisons:
                score, iou, correlation = max(comparisons, key=lambda item: item[0])
                ranked.append((label, score, iou, correlation))
        ranked.sort(key=lambda item: item[1], reverse=True)
        if not ranked:
            return None, 0.0, 0.0, 0.0, 0.0
        label, score, iou, correlation = ranked[0]
        margin = score - (ranked[1][1] if len(ranked) > 1 else 0.0)
        return label, score, margin, iou, correlation

    def read_binary_level(
        self,
        crop: Image.Image | None,
        *,
        slot: int,
        tier: str,
        region: dict[str, Any],
    ) -> Observation:
        """Return non-committing S3B evidence until the real 0-9/blank gate is met."""

        self.metrics.binary_attempts += 1
        started = perf_counter()
        if crop is None or tier not in EQUIPMENT_MAX_LEVEL:
            self.metrics.binary_match_ms += (perf_counter() - started) * 1000.0
            return Observation(
                None, 0.0, "shadow", "equipment_binary_shadow",
                f"slot={slot};tier={tier};context_or_crop_missing;production_enabled=false",
            )
        cells = self._level_cells(crop, region)
        labels: list[str] = []
        scores: list[float] = []
        margins: list[float] = []
        ious: list[float] = []
        correlations: list[float] = []
        shift_retry = False
        try:
            for position, cell in enumerate(cells, start=1):
                exact = self._shifted_binary_glyph(cell, 0)
                if exact is None:
                    if position == 2 and labels:
                        labels.append("blank")
                        scores.append(1.0)
                        margins.append(1.0)
                        ious.append(1.0)
                        correlations.append(1.0)
                        continue
                    return Observation(
                        None, 0.0, "shadow", "equipment_binary_shadow",
                        f"slot={slot};position={position};feature_missing;production_enabled=false",
                    )
                variants = [exact]
                ranked = self._rank_binary_glyphs(variants, slot=slot, position=position)
                label, score, margin, iou, correlation = ranked
                if score < self.binary_shadow_threshold or margin < self.binary_shadow_margin:
                    shift_retry = True
                    self.metrics.binary_shift_retries += 1
                    variants.extend(
                        glyph for offset in (-1, 1)
                        if (glyph := self._shifted_binary_glyph(cell, offset)) is not None
                    )
                    label, score, margin, iou, correlation = self._rank_binary_glyphs(
                        variants, slot=slot, position=position,
                    )
                if label is None:
                    return Observation(
                        None, 0.0, "shadow", "equipment_binary_shadow",
                        f"slot={slot};position={position};templates_missing;production_enabled=false",
                    )
                labels.append(label)
                scores.append(score)
                margins.append(margin)
                ious.append(iou)
                correlations.append(correlation)
            try:
                value = int("".join(label for label in labels if label != "blank"))
            except ValueError:
                value = 0
            confident = (
                equipment_level_matches_tier(value, tier)
                and min(scores) >= self.binary_shadow_threshold
                and min(margins) >= self.binary_shadow_margin
            )
            if confident:
                self.metrics.binary_shadow_hits += 1
            return Observation(
                value if confident else None,
                min(scores),
                "shadow",
                "equipment_binary_shadow",
                (
                    f"slot={slot};tier={tier};value={value};labels={labels};"
                    f"margin={min(margins):.6f};iou={min(ious):.6f};"
                    f"correlation={min(correlations):.6f};shift_retry={shift_retry};"
                    "production_enabled=false;coverage=digits_7_0_only"
                ),
            )
        finally:
            self.metrics.binary_match_ms += (perf_counter() - started) * 1000.0
            for cell in cells:
                cell.close()

    def _generated_level_crop(
        self, slot: int, family: str, tier: str, level: int, region: dict[str, Any], source_size: tuple[int, int],
    ) -> Image.Image | None:
        base = self._base_card(family, tier)
        points = region.get("points_ratio")
        output = region.get("output_size", (48, 36))
        if base is None or not isinstance(points, list) or len(points) != 4:
            return None
        card = base.copy()
        text = self._render_level(level)
        card.alpha_composite(text, dest=(EQUIPMENT_SLOT_TEXT_X[slot] - EQUIPMENT_SLOT_CARD_X[slot], 6))
        text.close()
        try:
            scaled = [
                (
                    float(point["x"]) * source_size[0] - EQUIPMENT_SLOT_CARD_X[slot],
                    float(point["y"]) * source_size[1] - EQUIPMENT_CARD_Y,
                )
                for point in points
            ]
            top_left, top_right, bottom_right, bottom_left = scaled
            return card.convert("RGB").transform(
                (int(output[0]), int(output[1])), Image.Transform.QUAD,
                (*top_left, *bottom_left, *bottom_right, *top_right),
                resample=Image.Resampling.BICUBIC,
            )
        finally:
            card.close()

    def _candidate(
        self,
        slot: int,
        family: str,
        tier: str,
        level: int,
        position: int,
        region: dict[str, Any],
        source_size: tuple[int, int],
    ) -> PreparedFeature | None:
        key = (slot, family, tier, level, position, source_size, tuple(region.get("output_size", (48, 36))))
        cached = self.cache.get(key)
        if cached is not None:
            return cached
        crop = self._generated_level_crop(slot, family, tier, level, region, source_size)
        if crop is None:
            return None
        cells = self._level_cells(crop, region)
        started = perf_counter()
        prepared = (PreparedFeature.from_image(cells[0]), PreparedFeature.from_image(cells[1]))
        self.metrics.feature_prepare_ms += (perf_counter() - started) * 1000.0
        self.metrics.prepared_features += 2
        self.metrics.generated_cards += 1
        crop.close()
        cells[0].close()
        cells[1].close()
        for item_position, item in enumerate(prepared, start=1):
            item_key = (slot, family, tier, level, item_position, source_size, tuple(region.get("output_size", (48, 36))))
            self.cache.put(item_key, item)
        return prepared[position - 1]

    def read_generated_level(
        self,
        crop: Image.Image | None,
        *,
        slot: int,
        family: str,
        tier: str,
        region: dict[str, Any],
        source_size: tuple[int, int],
    ) -> Observation:
        if crop is None or tier not in EQUIPMENT_MAX_LEVEL:
            return Observation(None, 0.0, "uncertain", "equipment_small_roi_features", "context or crop missing")
        screen_cells = self._level_cells(crop, region)
        started = perf_counter()
        screen = [[PreparedFeature.from_image(cell)] for cell in screen_cells]
        self.metrics.feature_prepare_ms += (perf_counter() - started) * 1000.0
        self.metrics.prepared_features += 2

        def rank_current() -> tuple[int, list[str], list[float], list[float]] | None:
            labels: list[str] = []
            scores: list[float] = []
            margins: list[float] = []
            maximum = EQUIPMENT_MAX_LEVEL[tier]
            for position in (1, 2):
                grouped: dict[str, float] = {}
                for level in range(1, maximum + 1):
                    text = str(level)
                    label = (text if len(text) == 2 else text + "blank")[position - 1]
                    candidate = self._candidate(slot, family, tier, level, position, region, source_size)
                    if candidate is not None:
                        grouped[label] = max(
                            grouped.get(label, 0.0),
                            max(_feature_similarity(variant, candidate) for variant in screen[position - 1]),
                        )
                ranked = sorted(grouped.items(), key=lambda item: item[1], reverse=True)
                if not ranked:
                    return None
                label, score = ranked[0]
                labels.append(label)
                scores.append(score)
                margins.append(score - (ranked[1][1] if len(ranked) > 1 else 0.0))
            text = "".join(label for label in labels if label != "b")
            try:
                value = int(text)
            except ValueError:
                value = 0
            return value, labels, scores, margins

        try:
            ranked = rank_current()
            if ranked is None:
                return Observation(None, 0.0, "uncertain", "equipment_small_roi_features", f"slot={slot};catalog missing")
            value, labels, scores, margins = ranked
            confident = equipment_level_matches_tier(value, tier) and min(scores) >= self.level_threshold and min(margins) >= self.level_margin
            retry = not confident
            if retry:
                retry_started = perf_counter()
                for position, cell in enumerate(screen_cells):
                    for x_offset in (-1, 1):
                        shifted = Image.new("RGB", cell.size)
                        shifted.paste(cell.convert("RGB"), (x_offset, 0))
                        screen[position].append(PreparedFeature.from_image(shifted))
                        shifted.close()
                self.metrics.feature_prepare_ms += (perf_counter() - retry_started) * 1000.0
                self.metrics.prepared_features += 4
                ranked = rank_current()
                if ranked is not None:
                    value, labels, scores, margins = ranked
                    confident = equipment_level_matches_tier(value, tier) and min(scores) >= self.level_threshold and min(margins) >= self.level_margin
            return Observation(
                value if confident else None,
                min(scores),
                "ok" if confident else "uncertain",
                "equipment_small_roi_features",
                f"slot={slot};tier={tier};value={value};labels={labels};margin={min(margins):.6f};shift_retry={retry}",
            )
        finally:
            self.metrics.match_ms += (perf_counter() - started) * 1000.0
            for variants in screen:
                for item in variants:
                    item.close()
            for item in screen_cells:
                item.close()

    def read_empirical_level(
        self,
        crop: Image.Image | None,
        *,
        slot: int,
        tier: str,
        region: dict[str, Any],
    ) -> Observation:
        self.metrics.empirical_attempts += 1
        if crop is None:
            return Observation(None, 0.0, "uncertain", "equipment_empirical_glyph", "crop missing")
        cells = self._level_cells(crop, region)
        labels: list[str] = []
        scores: list[float] = []
        margins: list[float] = []
        try:
            for position, cell in enumerate(cells, start=1):
                glyph = _normalize_mask(_dark_ink_mask(cell))
                templates = self._empirical.get((slot, position), {})
                if glyph is None and position == 2 and labels:
                    labels.append("blank")
                    scores.append(1.0)
                    margins.append(1.0)
                    continue
                if glyph is None or len(templates) < 2:
                    return Observation(None, 0.0, "uncertain", "equipment_empirical_glyph", f"slot={slot};position={position};competing samples missing")
                ranked = sorted(
                    (
                        (label, max(_binary_iou(glyph, sample) for sample in samples))
                        for label, samples in templates.items() if samples
                    ),
                    key=lambda item: item[1], reverse=True,
                )
                label, score = ranked[0]
                margin = score - ranked[1][1]
                labels.append(label)
                scores.append(score)
                margins.append(margin)
            value = int("".join(label for label in labels if label != "blank"))
            confident = equipment_level_matches_tier(value, tier) and min(scores) >= 0.74 and min(margins) >= 0.015
            if confident:
                self.metrics.empirical_hits += 1
            return Observation(
                value if confident else None, min(scores), "ok" if confident else "uncertain",
                "equipment_empirical_glyph",
                f"slot={slot};tier={tier};value={value};margin={min(margins):.6f}",
            )
        finally:
            for cell in cells:
                cell.close()

    def learn_basic_level(
        self,
        crop: Image.Image | None,
        *,
        slot: int,
        value: int,
        region: dict[str, Any],
    ) -> None:
        if crop is None or not 1 <= value <= 70:
            return
        cells = self._level_cells(crop, region)
        try:
            for position, (digit, cell) in enumerate(zip(str(value), cells), start=1):
                glyph = _normalize_mask(_dark_ink_mask(cell))
                if glyph is None:
                    continue
                samples = self._empirical.setdefault((slot, position), {}).setdefault(digit, [])
                samples.append(glyph)
                while len(samples) > 4:
                    samples.pop(0).close()
                self.metrics.calibration_samples += 1
        finally:
            for cell in cells:
                cell.close()

    @staticmethod
    def empty_dot(crop: Image.Image | None) -> bool:
        if crop is None:
            return False
        pixels = list(_pixels(crop.convert("RGB")))
        matches = sum(
            red > 230 and 145 < green < 220 and blue < 100 and red - green > 25
            for red, green, blue in pixels
        )
        return matches >= 40 and matches / max(1, len(pixels)) >= 0.035

    @staticmethod
    def _inner_icon(crop: Image.Image, region: dict[str, Any]) -> Image.Image:
        ratio = region.get("crop_ratio") or {}
        left = round(crop.width * float(ratio.get("left", 0.15)))
        right = round(crop.width * (1.0 - float(ratio.get("right", 0.15))))
        top = round(crop.height * float(ratio.get("top", 0.20)))
        bottom = round(crop.height * (1.0 - float(ratio.get("bottom", 0.30))))
        return crop.crop((left, top, max(left + 1, right), max(top + 1, bottom)))

    def read_direct_tier(self, crop: Image.Image | None, family: str, region: dict[str, Any]) -> Observation:
        self.metrics.direct_tier_attempts += 1
        started = perf_counter()
        templates = self._direct_tier_templates.get(family, {})
        if crop is None or set(templates) != set(EQUIPMENT_MAX_LEVEL):
            self.metrics.direct_tier_match_ms += (perf_counter() - started) * 1000.0
            return Observation(None, 0.0, "uncertain", "equipment_direct_icon_tier", f"family={family};templates_missing")
        inner = self._inner_icon(crop, region)
        screen = PreparedFeature.from_image(inner)
        inner.close()
        try:
            ranked = sorted(
                ((tier, _feature_similarity(screen, template)) for tier, template in templates.items()),
                key=lambda item: item[1], reverse=True,
            )
        finally:
            screen.close()
            self.metrics.direct_tier_match_ms += (perf_counter() - started) * 1000.0
        tier, score = ranked[0]
        margin = score - ranked[1][1]
        confident = (
            self.direct_tier_production_enabled
            and score >= self.direct_tier_threshold
            and margin >= self.direct_tier_margin
        )
        self.metrics.direct_tier_hits += int(confident)
        return Observation(
            tier if confident else None, score, "ok" if confident else "uncertain",
            "equipment_direct_icon_tier",
            f"family={family};tier={tier};margin={margin:.6f};production_enabled={str(self.direct_tier_production_enabled).lower()}",
        )

    def _read_synthesized_tier(self, crop: Image.Image | None, family: str, region: dict[str, Any]) -> Observation:
        if crop is None:
            return Observation(None, 0.0, "region_missing", "equipment_icon_tier", "crop missing")
        screen = self._inner_icon(crop, region).convert("RGB")
        ranked: list[tuple[str, float]] = []
        background_path = self._asset("student-equipment-card-background")
        if background_path is None:
            screen.close()
            return Observation(None, 0.0, "uncertain", "equipment_icon_tier", "background missing")
        for number in range(1, 11):
            tier = f"T{number}"
            icon_path = self.catalog.root / "templates" / "inventory" / "equipment" / f"Equipment_Icon_{family}_Tier{number}.png"
            if not icon_path.is_file():
                continue
            with Image.open(icon_path) as source:
                icon = source.convert("RGBA")
            with Image.open(background_path) as source:
                background = source.convert("RGBA").resize(icon.size, Image.Resampling.LANCZOS)
            template = Image.alpha_composite(background, icon)
            inner = self._inner_icon(template, region).convert("RGB").resize(screen.size, Image.Resampling.LANCZOS)
            score = 0.85 * _normalized_correlation(screen.convert("L"), inner.convert("L")) + 0.15 * _mean_difference(screen, inner)
            ranked.append((tier, score))
            icon.close()
            background.close()
            template.close()
            inner.close()
        screen.close()
        ranked.sort(key=lambda item: item[1], reverse=True)
        if not ranked:
            return Observation(None, 0.0, "uncertain", "equipment_icon_tier", "family templates missing")
        tier, score = ranked[0]
        margin = score - (ranked[1][1] if len(ranked) > 1 else 0.0)
        confident = score >= 0.35 and margin >= 0.08
        return Observation(tier if confident else None, score, "ok" if confident else "uncertain", "equipment_icon_tier", f"family={family};tier={tier};margin={margin:.6f}")

    def read_tier(self, crop: Image.Image | None, family: str, region: dict[str, Any]) -> Observation:
        direct = self.read_direct_tier(crop, family, region)
        if direct.confirmed:
            return direct
        fallback = self._read_synthesized_tier(crop, family, region)
        return Observation(
            fallback.value, fallback.confidence, fallback.status, fallback.source,
            fallback.note + f";direct={direct.note}",
        )

    def read_favorite(self, crop: Image.Image | None) -> Observation:
        if crop is None or not self._favorite_templates:
            return Observation(None, 0.0, "uncertain", "favorite_tier_template", "crop or templates missing")
        ranked = sorted(
            ((tier, _normalized_correlation(crop.convert("L"), template.convert("L"))) for tier, template in self._favorite_templates.items()),
            key=lambda item: item[1], reverse=True,
        )
        tier, score = ranked[0]
        margin = score - (ranked[1][1] if len(ranked) > 1 else 0.0)
        confident = score >= 0.70 and margin >= 0.10
        return Observation(tier if confident else None, score, "ok" if confident else "uncertain", "favorite_tier_template", f"tier={tier};margin={margin:.6f}")

    def recognize(
        self,
        crops: StudentBasicCropSet,
        *,
        student_ref: str,
        student_level: int | None,
        favorite_growth_active: bool | None = None,
    ) -> tuple[dict[str, Observation], tuple[int, ...]]:
        student_id, _form = student_meta.split_form_ref(student_ref)
        observations: dict[str, Observation] = {}
        self.last_binary_shadow = {}
        self.last_generated_binary_shadow = {}
        self.last_position_binary_shadow = {}
        unresolved: list[int] = []
        families = student_meta.equipment_slots(student_id)
        for slot in (1, 2, 3):
            equip_field = f"equip{slot}"
            level_field = f"equip{slot}_level"
            if student_level is not None and student_level < EQUIPMENT_UNLOCK_LEVEL[slot]:
                observations[equip_field] = Observation("level_locked", 1.0, "inferred", "student_level_unlock_rule", f"student_level={student_level};unlock={EQUIPMENT_UNLOCK_LEVEL[slot]}")
                observations[level_field] = Observation(None, 1.0, "skipped", "student_level_unlock_rule", "slot locked")
                continue
            if self.empty_dot(crops.images.get(f"basic_equipment_{slot}_empty_dot_region")):
                observations[equip_field] = Observation("empty", 1.0, "inferred", "equipment_empty_dot", "orange dot present")
                observations[level_field] = Observation(None, 1.0, "skipped", "equipment_empty_dot", "slot empty")
                continue
            family = families[slot - 1] if slot <= len(families) else None
            icon_region = crops.regions.get(f"basic_equipment_{slot}_icon_region", {})
            level_region = crops.regions.get(f"basic_equipment_{slot}_level_digits_quad", {})
            if not family:
                observations[equip_field] = Observation(None, 0.0, "uncertain", "equipment_family_metadata", "family missing")
                observations[level_field] = Observation(None, 0.0, "uncertain", "equipment_family_metadata", "family missing")
                unresolved.append(slot)
                continue
            tier = self.read_tier(crops.images.get(f"basic_equipment_{slot}_icon_region"), family, icon_region)
            binary = self.read_binary_level(
                crops.images.get(f"basic_equipment_{slot}_level_digits_quad"),
                slot=slot, tier=str(tier.value) if tier.confirmed else "", region=level_region,
            )
            self.last_binary_shadow[level_field] = binary
            position_binary = self.read_position_binary_level(
                crops.images.get(f"basic_equipment_{slot}_level_digits_quad"),
                tier=str(tier.value) if tier.confirmed else "", region=level_region,
            )
            if not position_binary.confirmed:
                self.last_position_binary_shadow[level_field] = position_binary
            if position_binary.value is None:
                generated_binary = self.read_generated_binary_level(
                    crops.images.get(f"basic_equipment_{slot}_level_digits_quad"),
                    slot=slot, tier=str(tier.value) if tier.confirmed else "", variant="fill",
                )
                self.last_generated_binary_shadow[level_field] = generated_binary
            level = position_binary if position_binary.confirmed else self.read_empirical_level(
                crops.images.get(f"basic_equipment_{slot}_level_digits_quad"),
                slot=slot, tier=str(tier.value) if tier.confirmed else "", region=level_region,
            )
            if not level.confirmed:
                level = self.read_generated_level(
                    crops.images.get(f"basic_equipment_{slot}_level_digits_quad"),
                    slot=slot, family=family, tier=str(tier.value) if tier.confirmed else "",
                    region=level_region, source_size=crops.source_size,
                )
            compatible = tier.confirmed and level.confirmed and equipment_level_matches_tier(int(level.value), str(tier.value))
            if compatible:
                observations[equip_field] = tier
                observations[level_field] = level
            else:
                observations[equip_field] = tier if tier.confirmed else tier
                observations[level_field] = Observation(None, level.confidence, "uncertain", level.source, level.note + ";tier_level_pair_unresolved")
                unresolved.append(slot)
        if not student_meta.favorite_item_enabled(student_id):
            observations["equip4"] = Observation(None, 1.0, "skipped", "favorite_metadata", "favorite item unsupported on kr")
        elif self.empty_dot(crops.images.get("basic_favorite_empty_dot_region")):
            observations["equip4"] = Observation("empty", 1.0, "inferred", "equipment_empty_dot", "favorite orange dot present")
        elif favorite_growth_active is False:
            observations["equip4"] = Observation("love_locked", 1.0, "inferred", "favorite_growth_lock", "growth action inactive")
        else:
            favorite = self.read_favorite(crops.images.get("basic_favorite_tier_region"))
            observations["equip4"] = favorite
            if not favorite.confirmed:
                unresolved.append(4)
        return observations, tuple(unresolved)

    def close(self) -> None:
        self.cache.close()
        for image in self._card_cache.values():
            image.close()
        self._card_cache.clear()
        for image in self._favorite_templates.values():
            image.close()
        self._favorite_templates.clear()
        for tiers in self._direct_tier_templates.values():
            for template in tiers.values():
                template.close()
        self._direct_tier_templates.clear()
        for labels in self._empirical.values():
            for samples in labels.values():
                for image in samples:
                    image.close()
        self._empirical.clear()


class EquipmentMenuRecognizer:
    """Reads only requested slots from one already-open equipment-menu capture."""

    def __init__(self, catalog: RecognitionAssetCatalog) -> None:
        self.catalog = catalog
        self.regions = catalog.region_for_purpose("student", "student-equipment-menu-regions")
        self.tiers = self._group("student-equipment-menu-tier-template")
        self.digits = self._group("student-equipment-menu-digit-template")
        self.flags = self._group("student-equipment-menu-flag-template")

    def _group(self, purpose: str) -> dict[str, list[Image.Image]]:
        result: dict[str, list[Image.Image]] = {}
        for asset in self.catalog.assets("student", purpose):
            if asset.identity is None:
                continue
            with Image.open(self.catalog.resolve(asset.path)) as source:
                result.setdefault(asset.identity, []).append(source.convert("RGB"))
        return result

    @staticmethod
    def _rank(crop: Image.Image, templates: dict[str, list[Image.Image]]) -> tuple[str | None, float, float]:
        ranked = sorted(
            ((label, max(_normalized_correlation(crop.convert("L"), sample.convert("L")) for sample in samples)) for label, samples in templates.items()),
            key=lambda item: item[1], reverse=True,
        )
        if not ranked:
            return None, 0.0, 0.0
        return ranked[0][0], ranked[0][1], ranked[0][1] - (ranked[1][1] if len(ranked) > 1 else 0.0)

    def recognize(self, frame: Image.Image, slots: Iterable[int]) -> dict[str, Observation]:
        result: dict[str, Observation] = {}
        for slot in tuple(dict.fromkeys(slots)):
            flag_region = self.regions.get(f"equip{slot}_flag")
            flag_templates = {key.split(":", 1)[1]: value for key, value in self.flags.items() if key.startswith(f"{slot}:")}
            if isinstance(flag_region, dict) and flag_templates:
                flag, score, margin = self._rank(_ratio_crop(frame, flag_region), flag_templates)
                if flag is not None and score >= 0.60:
                    result[f"equip{slot}"] = Observation(flag, score, "inferred", "equipment_menu_flag", f"margin={margin:.6f}")
                    if slot <= 3:
                        result[f"equip{slot}_level"] = Observation(None, score, "skipped", "equipment_menu_flag", f"flag={flag}")
                    continue
            tier_region = self.regions.get(f"equipment_{slot}")
            tier_templates = {key.split(":", 1)[1]: value for key, value in self.tiers.items() if key.startswith(f"{slot}:")}
            tier, tier_score, tier_margin = self._rank(_ratio_crop(frame, tier_region), tier_templates) if isinstance(tier_region, dict) else (None, 0.0, 0.0)
            tier_ok = tier in EQUIPMENT_MAX_LEVEL and tier_score >= 0.60
            result[f"equip{slot}"] = Observation(tier if tier_ok else None, tier_score, "ok" if tier_ok else "uncertain", "equipment_menu_tier", f"margin={tier_margin:.6f}")
            if slot > 3:
                continue
            digits: list[str] = []
            digit_scores: list[float] = []
            for position in (1, 2):
                region = self.regions.get(f"equipment_{slot}_level_digit_{position}")
                templates = {key.split(":", 2)[2]: value for key, value in self.digits.items() if key.startswith(f"{slot}:{position}:")}
                label, score, _margin = self._rank(_ratio_crop(frame, region), templates) if isinstance(region, dict) else (None, 0.0, 0.0)
                if label and label != "v":
                    digits.append(label)
                    digit_scores.append(score)
            value = int("".join(digits)) if digits else 0
            valid = tier_ok and equipment_level_matches_tier(value, str(tier)) and min(digit_scores, default=0.0) >= 0.55
            result[f"equip{slot}_level"] = Observation(value if valid else None, min(digit_scores, default=0.0), "ok" if valid else "uncertain", "equipment_menu_digit", f"value={value};tier={tier}")
        return result


def _ratio_crop(image: Image.Image, region: dict[str, Any]) -> Image.Image:
    return image.crop((
        round(image.width * float(region["x1"])), round(image.height * float(region["y1"])),
        round(image.width * float(region["x2"])), round(image.height * float(region["y2"])),
    ))
