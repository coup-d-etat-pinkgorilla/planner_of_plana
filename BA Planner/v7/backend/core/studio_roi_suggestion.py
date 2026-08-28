from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageDraw
from PIL import ImageColor, ImageFont


@dataclass(frozen=True, slots=True)
class StudioRoiSuggestion:
    name: str
    shape: str
    slant: int
    points: tuple[tuple[float, float], ...]


@dataclass(frozen=True, slots=True)
class StudioSuggestion:
    path: Path
    reference_path: Path
    reference_size: tuple[int, int]
    rois: tuple[StudioRoiSuggestion, ...]


@dataclass(frozen=True, slots=True)
class StudioTextLayer:
    name: str
    x: int
    y: int
    width: int
    height: int
    text: str
    font_path: Path
    font_size: int
    text_bold: bool
    fill: str
    stroke_width: int
    stroke_fill: str
    shear: float


def _validated_points(row: dict[str, Any]) -> tuple[tuple[float, float], ...]:
    points = row.get("points")
    if not isinstance(points, list) or len(points) != 4:
        raise ValueError(f"ROI {row.get('name', '<unnamed>')} must contain four points")
    try:
        result = tuple((float(point["x"]), float(point["y"])) for point in points)
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(f"ROI {row.get('name', '<unnamed>')} has invalid points") from exc
    if len(set(result)) != 4:
        raise ValueError(f"ROI {row.get('name', '<unnamed>')} is degenerate")
    return result


def load_studio_suggestion(path: Path) -> StudioSuggestion:
    source = path.resolve()
    payload = json.loads(source.read_text(encoding="utf-8"))
    reference_value = payload.get("reference_path")
    if not isinstance(reference_value, str) or not reference_value:
        raise ValueError("suggestion reference_path is missing")
    reference_path = Path(reference_value).expanduser()
    if not reference_path.is_absolute():
        reference_path = source.parent / reference_path
    reference_path = reference_path.resolve()
    with Image.open(reference_path) as reference:
        reference_size = reference.size
    rois: list[StudioRoiSuggestion] = []
    names: set[str] = set()
    for raw in payload.get("rois", []):
        if not isinstance(raw, dict) or not bool(raw.get("enabled", True)):
            continue
        name = str(raw.get("name", "")).strip()
        if not name or name in names:
            raise ValueError(f"suggestion ROI name is missing or duplicated: {name!r}")
        shape = str(raw.get("shape", "rectangle"))
        if shape not in {"rectangle", "parallelogram"}:
            raise ValueError(f"ROI {name} has unsupported shape {shape!r}")
        rois.append(
            StudioRoiSuggestion(
                name=name,
                shape=shape,
                slant=int(raw.get("slant", 0)) if shape == "parallelogram" else 0,
                points=_validated_points(raw),
            )
        )
        names.add(name)
    if not rois:
        raise ValueError("suggestion contains no enabled ROIs")
    return StudioSuggestion(source, reference_path, reference_size, tuple(rois))


def load_studio_text_layers(path: Path) -> tuple[Path, tuple[int, int], tuple[StudioTextLayer, ...]]:
    source = path.resolve()
    payload = json.loads(source.read_text(encoding="utf-8"))
    reference_value = payload.get("reference_path")
    if not isinstance(reference_value, str) or not reference_value:
        raise ValueError("text suggestion reference_path is missing")
    reference_path = Path(reference_value).expanduser()
    if not reference_path.is_absolute():
        reference_path = source.parent / reference_path
    reference_path = reference_path.resolve()
    with Image.open(reference_path) as reference:
        reference_size = reference.size
    layers: list[StudioTextLayer] = []
    for raw in payload.get("layers", []):
        if not isinstance(raw, dict) or raw.get("kind") != "text" or not bool(raw.get("visible", True)):
            continue
        font_path = Path(str(raw.get("font_path", ""))).expanduser()
        if not font_path.is_absolute():
            font_path = source.parent / font_path
        layers.append(
            StudioTextLayer(
                name=str(raw.get("name", "")),
                x=int(raw.get("x", 0)),
                y=int(raw.get("y", 0)),
                width=max(1, int(raw.get("width", 1))),
                height=max(1, int(raw.get("height", 1))),
                text=str(raw.get("text", "")),
                font_path=font_path.resolve(),
                font_size=max(1, int(raw.get("font_size", 1))),
                text_bold=bool(raw.get("text_bold", False)),
                fill=str(raw.get("fill", "#FFFFFF")),
                stroke_width=max(0, int(raw.get("stroke_width", 0))),
                stroke_fill=str(raw.get("stroke_fill", "#000000")),
                shear=float(raw.get("shear", 0.0)),
            )
        )
    if not layers:
        raise ValueError("text suggestion contains no visible text layers")
    return reference_path, reference_size, tuple(layers)


def render_studio_text_layer(
    layer: StudioTextLayer,
    *,
    font_path: Path | None = None,
    white_mask: bool = False,
    include_stroke: bool = True,
) -> Image.Image:
    """Reproduce the v6 Studio text rasterization without importing v6."""

    canvas = Image.new("RGBA", (layer.width, layer.height))
    font = ImageFont.truetype(str(font_path or layer.font_path), layer.font_size)
    draw = ImageDraw.Draw(canvas)
    stroke_width = layer.stroke_width if include_stroke else 0
    fill = "#FFFFFF" if white_mask else layer.fill
    stroke_fill = "#FFFFFF" if white_mask else layer.stroke_fill
    offsets = ((0, 0), (1, 0)) if layer.text_bold else ((0, 0),)
    for dx, dy in offsets:
        draw.text(
            (stroke_width + 1 + dx, stroke_width + 1 + dy),
            layer.text,
            font=font,
            fill=ImageColor.getcolor(fill, "RGBA"),
            stroke_width=stroke_width,
            stroke_fill=ImageColor.getcolor(stroke_fill, "RGBA"),
        )
    if layer.shear:
        shift = abs(layer.shear) * layer.height
        expanded = Image.new("RGBA", (layer.width + round(shift), layer.height))
        expanded.alpha_composite(canvas)
        canvas.close()
        transformed = expanded.transform(
            expanded.size,
            Image.Transform.AFFINE,
            (1, -layer.shear, shift if layer.shear > 0 else 0, 0, 1, 0),
            resample=Image.Resampling.BICUBIC,
        )
        expanded.close()
        canvas = transformed.crop((0, 0, layer.width, layer.height))
        transformed.close()
    return canvas


def scaled_roi_points(
    roi: StudioRoiSuggestion,
    *,
    reference_size: tuple[int, int],
    target_size: tuple[int, int],
) -> tuple[tuple[float, float], ...]:
    if min(*reference_size, *target_size) <= 0:
        raise ValueError("reference and target sizes must be positive")
    scale_x = target_size[0] / reference_size[0]
    scale_y = target_size[1] / reference_size[1]
    return tuple((x * scale_x, y * scale_y) for x, y in roi.points)


def extract_studio_roi(
    image: Image.Image,
    roi: StudioRoiSuggestion,
    *,
    reference_size: tuple[int, int],
    preserve_source_alpha: bool = False,
) -> Image.Image:
    """Match v6 Studio export: bounding crop plus polygon alpha, without warp."""

    points = scaled_roi_points(roi, reference_size=reference_size, target_size=image.size)
    left = max(0, int(min(x for x, _y in points)))
    top = max(0, int(min(y for _x, y in points)))
    right = min(image.width, int(max(x for x, _y in points) + 0.999999))
    bottom = min(image.height, int(max(y for _x, y in points) + 0.999999))
    if left >= right or top >= bottom:
        raise ValueError(f"ROI {roi.name} lies outside the target image")
    crop = image.convert("RGBA").crop((left, top, right, bottom))
    if roi.shape == "parallelogram":
        mask = Image.new("L", crop.size)
        local = [(x - left, y - top) for x, y in points]
        ImageDraw.Draw(mask).polygon(local, fill=255)
        if preserve_source_alpha:
            source_alpha = crop.getchannel("A")
            combined = ImageChops.multiply(source_alpha, mask)
            crop.putalpha(combined)
            source_alpha.close()
            combined.close()
        else:
            crop.putalpha(mask)
        mask.close()
    return crop


def draw_suggestion_overlay(
    image: Image.Image,
    suggestion: StudioSuggestion,
) -> Image.Image:
    result = image.convert("RGB")
    draw = ImageDraw.Draw(result)
    colors = ("#58E6FF", "#FFD166", "#FF7084", "#9B7BFF")
    for index, roi in enumerate(suggestion.rois):
        points = scaled_roi_points(
            roi,
            reference_size=suggestion.reference_size,
            target_size=result.size,
        )
        rounded = [(round(x), round(y)) for x, y in points]
        draw.line((*rounded, rounded[0]), fill=colors[index % len(colors)], width=2)
    return result
