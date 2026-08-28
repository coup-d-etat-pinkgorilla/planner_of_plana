from __future__ import annotations

from collections import deque
from dataclasses import replace
from hashlib import sha256
import json
from pathlib import Path
import shutil
from typing import Any

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps

from core.studio_roi_suggestion import (
    StudioRoiSuggestion,
    StudioTextLayer,
    extract_studio_roi,
    load_studio_suggestion,
    load_studio_text_layers,
    render_studio_text_layer,
)


ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
SUGGESTION = ROOT / "suggestion.json"
TEXT_SUGGESTION = ROOT / "suggestion_text.json"
RELATIONSHIP_LAYOUT_TEXT_SUGGESTIONS = {
    1: ROOT / "suggestion_text_1.json",
    3: ROOT / "suggestion_text_100.json",
}
DEBUG = ROOT / "debug" / "student_suggestion_rois"
OUTPUT = DEBUG / "templates"
LABEL_FONT = ROOT / "frontend" / "assets" / "fonts" / "GyeonggiTitle-Medium.ttf"


def _roi_field(roi: StudioRoiSuggestion) -> str:
    if roi.name.startswith("weaponlevel_"):
        return "weapon_level"
    if roi.name.startswith("equip"):
        return "equipment_level"
    if roi.name.startswith("studentlevel_"):
        return "student_level"
    if roi.name.startswith("affectionlevel_"):
        return "relationship_rank"
    raise ValueError(f"unsupported ROI name {roi.name!r}")


def _layer_field(layer: StudioTextLayer) -> str:
    if layer.font_size == 37:
        return "weapon_level"
    if layer.font_size == 28:
        return "equipment_level"
    if layer.font_size == 33:
        return "student_level"
    if layer.font_size == 32:
        return "relationship_rank"
    raise ValueError(f"unsupported Studio text size {layer.font_size}")


def _associate(
    rois: tuple[StudioRoiSuggestion, ...],
    layers: tuple[StudioTextLayer, ...],
) -> list[tuple[StudioRoiSuggestion, StudioTextLayer]]:
    result: list[tuple[StudioRoiSuggestion, StudioTextLayer]] = []
    for field in ("weapon_level", "equipment_level", "student_level", "relationship_rank"):
        field_rois = sorted(
            (roi for roi in rois if _roi_field(roi) == field),
            key=lambda roi: min(x for x, _y in roi.points),
        )
        field_layers = sorted(
            (layer for layer in layers if _layer_field(layer) == field),
            key=lambda layer: layer.x,
        )
        if len(field_rois) != len(field_layers):
            raise ValueError(f"{field} ROI/layer count mismatch")
        result.extend(zip(field_rois, field_layers))
    return result


def _relationship_layout_rois(
    rois: tuple[StudioRoiSuggestion, ...],
    digit_count: int,
) -> tuple[StudioRoiSuggestion, ...]:
    if digit_count == 2:
        names = {"affectionlevel_digit1", "affectionlevel_digit2"}
    else:
        names = {
            f"affectionlevel_{digit_count}digit_digit{position}"
            for position in range(1, digit_count + 1)
        }
    return tuple(roi for roi in rois if roi.name in names)


def _relationship_layout_calibrations(
    rois: tuple[StudioRoiSuggestion, ...],
) -> list[tuple[StudioRoiSuggestion, StudioTextLayer, Path, tuple[int, int]]]:
    result: list[tuple[StudioRoiSuggestion, StudioTextLayer, Path, tuple[int, int]]] = []
    paths = {2: TEXT_SUGGESTION, **RELATIONSHIP_LAYOUT_TEXT_SUGGESTIONS}
    for digit_count in (1, 2, 3):
        reference, size, layers = load_studio_text_layers(paths[digit_count])
        field_layers = sorted(
            (layer for layer in layers if _layer_field(layer) == "relationship_rank"),
            key=lambda layer: layer.x,
        )
        field_rois = sorted(
            _relationship_layout_rois(rois, digit_count),
            key=lambda roi: min(x for x, _y in roi.points),
        )
        if len(field_rois) != digit_count or len(field_layers) != digit_count:
            raise ValueError(f"relationship {digit_count}-digit ROI/layer count mismatch")
        result.extend((roi, layer, reference, size) for roi, layer in zip(field_rois, field_layers))
    return result


def _binary_mask(image: Image.Image, predicate) -> Image.Image:
    rgba = image.convert("RGBA")
    mask = Image.new("L", rgba.size)
    pixels = mask.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = rgba.getpixel((x, y))
            if alpha >= 64 and predicate((red, green, blue)):
                pixels[x, y] = 255
    rgba.close()
    return mask


def _components(mask: Image.Image) -> list[list[tuple[int, int]]]:
    source = mask.convert("L")
    active = {
        (x, y)
        for y in range(source.height)
        for x in range(source.width)
        if source.getpixel((x, y)) >= 127
    }
    source.close()
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


def _keep_digit_component(
    mask: Image.Image,
    *,
    prefer_largest_tall: bool = False,
) -> tuple[Image.Image, dict[str, int]]:
    components = _components(mask)
    result = Image.new("L", mask.size)
    if not components:
        return result, {"components": 0, "removed_ink": 0, "kept_ink": 0}
    width, height = mask.size

    if prefer_largest_tall:
        minimum_height = max(3, round(height * 0.30))
        tall = [
            component
            for component in components
            if max(y for _x, y in component) - min(y for _x, y in component) + 1 >= minimum_height
        ]
        kept = max(tall or components, key=len)
    else:
        def score(component: list[tuple[int, int]]) -> tuple[int, int, float]:
            touches = sum(x in (0, width - 1) or y in (0, height - 1) for x, y in component)
            center = sum(abs(x - (width - 1) / 2.0) for x, _y in component) / len(component)
            return (-touches, len(component), -center)

        kept = max(components, key=score)
    pixels = result.load()
    for x, y in kept:
        pixels[x, y] = 255
    total = sum(len(component) for component in components)
    return result, {
        "components": len(components),
        "removed_ink": total - len(kept),
        "kept_ink": len(kept),
    }


def _source_digit_mask(image: Image.Image, field: str) -> tuple[Image.Image, dict[str, int]]:
    if field == "relationship_rank":
        raw = _binary_mask(
            image,
            lambda pixel: (
                pixel[0] < 150
                and 3 <= pixel[1] - pixel[0] <= 38
                and 5 <= pixel[2] - pixel[1] <= 45
            ),
        )
    else:
        raw = _binary_mask(
            image,
            lambda pixel: min(pixel) >= 185 and max(pixel) - min(pixel) <= 85,
        )
    cleaned, stats = _keep_digit_component(
        raw,
        prefer_largest_tall=field in {"student_level", "relationship_rank"},
    )
    raw.close()
    return cleaned, stats


def _synthetic_mask(image: Image.Image) -> Image.Image:
    alpha = image.convert("RGBA").getchannel("A").point(lambda value: 255 if value >= 32 else 0)
    cleaned, _stats = _keep_digit_component(alpha)
    alpha.close()
    return cleaned


def _iou(left: Image.Image, right: Image.Image) -> float:
    intersection = ImageChops.logical_and(left.convert("1"), right.convert("1"))
    union = ImageChops.logical_or(left.convert("1"), right.convert("1"))
    intersection_count = sum(bool(value) for value in intersection.getdata())
    union_count = sum(bool(value) for value in union.getdata())
    intersection.close()
    union.close()
    return intersection_count / union_count if union_count else 0.0


def _best_shift(source: Image.Image, template: Image.Image) -> tuple[float, int, int, Image.Image]:
    prepared = (
        template.resize(source.size, Image.Resampling.NEAREST)
        if template.size != source.size
        else template.copy()
    )
    best = (-1.0, 0, 0, prepared.copy())
    try:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                shifted = Image.new("L", source.size)
                shifted.paste(prepared, (dx, dy))
                score = _iou(source, shifted)
                if score > best[0]:
                    best[3].close()
                    best = (score, dx, dy, shifted)
                else:
                    shifted.close()
        return best
    finally:
        prepared.close()


def _render_roi(
    layer: StudioTextLayer,
    roi: StudioRoiSuggestion,
    reference_size: tuple[int, int],
    font_path: Path,
    *,
    include_stroke: bool,
) -> Image.Image:
    layer_image = render_studio_text_layer(
        layer,
        font_path=font_path,
        white_mask=True,
        include_stroke=include_stroke,
    )
    virtual = Image.new("RGBA", reference_size)
    virtual.alpha_composite(layer_image, dest=(layer.x, layer.y))
    layer_image.close()
    result = extract_studio_roi(
        virtual,
        roi,
        reference_size=reference_size,
        preserve_source_alpha=True,
    )
    virtual.close()
    return result


def _digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def _font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(LABEL_FONT), size)


def _panel(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgb = Image.new("RGB", image.size, "#0C1724")
    if image.mode == "L":
        rgb.paste("#FFFFFF", mask=image)
    else:
        rgba = image.convert("RGBA")
        rgb.paste(rgba.convert("RGB"), mask=rgba.getchannel("A"))
        rgba.close()
    result = Image.new("RGB", size, "#20364B")
    fitted = ImageOps.contain(rgb, size, Image.Resampling.NEAREST)
    result.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    fitted.close()
    rgb.close()
    return result


def _paste(sheet: Image.Image, draw: ImageDraw.ImageDraw, image: Image.Image, box, label: str) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle(box, radius=8, fill="#20364B", outline="#5D7891")
    draw.text((x1 + 8, y1 + 6), label, font=_font(15), fill="#F1F7FC")
    fitted = _panel(image, (x2 - x1 - 12, y2 - y1 - 34))
    sheet.paste(fitted, (x1 + 6, y1 + 28))
    fitted.close()


def build() -> dict[str, Any]:
    roi_suggestion = load_studio_suggestion(SUGGESTION)
    text_reference, text_size, layers = load_studio_text_layers(TEXT_SUGGESTION)
    if text_reference != roi_suggestion.reference_path or text_size != roi_suggestion.reference_size:
        raise ValueError("ROI and text suggestions use different references")
    base_rois = tuple(
        roi
        for roi in roi_suggestion.rois
        if _roi_field(roi) != "relationship_rank"
    ) + _relationship_layout_rois(roi_suggestion.rois, 2)
    associations = [
        (roi, layer, text_reference, text_size)
        for roi, layer in _associate(base_rois, layers)
    ]
    associations.extend(_relationship_layout_calibrations(roi_suggestion.rois))
    unique_associations = {row[0].name: row for row in associations}
    associations = list(unique_associations.values())
    font_sources = {layer.font_path for _roi, layer, _reference, _size in associations}
    if len(font_sources) != 1:
        raise ValueError("text suggestion uses multiple font files")
    font_source = next(iter(font_sources))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    packaged_font = OUTPUT / "font.ttf"
    shutil.copyfile(font_source, packaged_font)
    references: dict[Path, Image.Image] = {}

    rows: list[dict[str, Any]] = []
    bank_rows: list[dict[str, Any]] = []
    visual_rows: list[tuple[dict[str, Any], Image.Image, Image.Image, Image.Image, Image.Image, Image.Image]] = []
    try:
        for roi, layer, reference_path, reference_size in associations:
            field = _roi_field(roi)
            if reference_path not in references:
                with Image.open(reference_path) as opened:
                    references[reference_path] = opened.convert("RGBA")
            source_roi = extract_studio_roi(
                references[reference_path], roi, reference_size=reference_size,
            )
            source_mask, source_stats = _source_digit_mask(source_roi, field)
            configured_roi = _render_roi(
                layer, roi, roi_suggestion.reference_size, packaged_font, include_stroke=True,
            )
            fill_roi = _render_roi(
                layer, roi, roi_suggestion.reference_size, packaged_font, include_stroke=False,
            )
            configured_mask = _synthetic_mask(configured_roi)
            fill_mask = _synthetic_mask(fill_roi)
            configured = _best_shift(source_mask, configured_mask)
            fill_only = _best_shift(source_mask, fill_mask)
            selected_name, selected = (
                ("configured_stroke", configured)
                if configured[0] >= fill_only[0]
                else ("fill_only", fill_only)
            )
            target = OUTPUT / f"{roi.name}.png"
            selected[3].save(target)
            row = {
                "roi": roi.name,
                "field": field,
                "digit": layer.text.strip(),
                "font_size": layer.font_size,
                "shear": layer.shear,
                "declared_fill": layer.fill,
                "declared_stroke_width": layer.stroke_width,
                "declared_stroke_fill": layer.stroke_fill,
                "text_bold": layer.text_bold,
                "layout_digit_count": (
                    1 if "_1digit_" in roi.name else 3 if "_3digit_" in roi.name else 2
                ),
                "template_color": "#FFFFFF",
                "selected_variant": selected_name,
                "score": selected[0],
                "shift": [selected[1], selected[2]],
                "configured_score": configured[0],
                "fill_only_score": fill_only[0],
                "source_cleanup": source_stats,
                "path": target.relative_to(ROOT).as_posix(),
                "sha256": _digest(target),
            }
            rows.append(row)
            leading = layer.text[: len(layer.text) - len(layer.text.lstrip())]
            bank_dir = OUTPUT / roi.name
            bank_dir.mkdir(parents=True, exist_ok=True)
            for digit in "0123456789":
                digit_layer = replace(layer, text=f"{leading}{digit}")
                digit_roi = _render_roi(
                    digit_layer,
                    roi,
                    roi_suggestion.reference_size,
                    packaged_font,
                    include_stroke=selected_name == "configured_stroke",
                )
                digit_mask = _synthetic_mask(digit_roi)
                digit_target = bank_dir / f"{digit}.png"
                digit_mask.save(digit_target)
                bank_rows.append(
                    {
                        "roi": roi.name,
                        "field": field,
                        "digit": digit,
                        "font_size": layer.font_size,
                        "shear": layer.shear,
                        "variant": selected_name,
                        "template_color": "#FFFFFF",
                        "path": digit_target.relative_to(ROOT).as_posix(),
                        "sha256": _digest(digit_target),
                    }
                )
                digit_mask.close()
                digit_roi.close()
            visual_rows.append(
                (
                    row,
                    source_roi,
                    source_mask,
                    configured_mask.copy(),
                    fill_mask.copy(),
                    selected[3].copy(),
                )
            )
            configured[3].close()
            fill_only[3].close()
            configured_roi.close()
            fill_roi.close()
            configured_mask.close()
            fill_mask.close()
    finally:
        for reference in references.values():
            reference.close()

    spec = {
        "schema_version": 1,
        "purpose": "student-studio-suggestion-white-digit-templates",
        "source": [
            SUGGESTION.name,
            TEXT_SUGGESTION.name,
            *(path.name for path in RELATIONSHIP_LAYOUT_TEXT_SUGGESTIONS.values()),
        ],
        "reference_size": list(roi_suggestion.reference_size),
        "font": {"path": "font.ttf", "sha256": _digest(packaged_font), "family": "GyeonggiTitle Bold"},
        "processing": {
            "source_foreground": "field threshold -> 8-connected components -> keep central non-border dominant digit",
            "template_color": "white binary mask; RGB layer colors are not retained",
            "comparison": "exact Studio polygon ROI; best integer shift within +/-2 px; binary IoU",
            "production": False,
        },
        "calibration": rows,
        "templates": bank_rows,
    }
    spec_path = OUTPUT / "renderer_spec.json"
    spec_path.write_text(json.dumps(spec, ensure_ascii=False, indent=2), encoding="utf-8")

    DEBUG.mkdir(parents=True, exist_ok=True)
    width, header, row_height = 1500, 102, 150
    sheet = Image.new("RGB", (width, header + row_height * len(visual_rows)), "#14263A")
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 14), "suggestion_text - white synthetic digit comparison", font=_font(28), fill="#F1F7FC")
    draw.text(
        (24, 50),
        "Original Studio ROI | cleaned white foreground | configured stroke | fill only | selected white template",
        font=_font(17), fill="#AFC3D5",
    )
    draw.text((24, 76), "Border/noise components are removed before comparison.", font=_font(15), fill="#58E6FF")
    try:
        for index, (row, source_roi, source_mask, configured_mask, fill_mask, selected_mask) in enumerate(visual_rows):
            y = header + index * row_height
            draw.text(
                (24, y + 4),
                f"{row['roi']}  digit={row['digit']}  {row['font_size']}px  shear={row['shear']:+.2f}",
                font=_font(16), fill="#F1F7FC",
            )
            for column, (image, label) in enumerate((
                (source_roi, "Original ROI"),
                (source_mask, "Cleaned white"),
                (configured_mask, f"Stroke {row['configured_score']:.3f}"),
                (fill_mask, f"Fill {row['fill_only_score']:.3f}"),
                (selected_mask, f"Selected {row['score']:.3f}"),
            )):
                x = 24 + column * 238
                _paste(sheet, draw, image, (x, y + 30, x + 224, y + 142), label)
            draw.text((1224, y + 44), str(row["selected_variant"]), font=_font(16), fill="#FFD166")
            draw.text((1224, y + 76), f"shift {row['shift']}", font=_font(15), fill="#BFD0DF")
            cleanup = row["source_cleanup"]
            draw.text(
                (1224, y + 104),
                f"components {cleanup['components']} / removed {cleanup['removed_ink']} px",
                font=_font(14), fill="#64E6B1",
            )
    finally:
        for _row, *images in visual_rows:
            for image in images:
                image.close()
    comparison_path = DEBUG / "suggestion_text_template_comparison.png"
    sheet.save(comparison_path)
    sheet.close()
    report_path = DEBUG / "suggestion_text_template_report.json"
    report_path.write_text(json.dumps(spec, ensure_ascii=False, indent=2), encoding="utf-8")
    return {
        "spec": spec_path,
        "comparison": comparison_path,
        "report": report_path,
        "rows": rows,
        "template_count": len(bank_rows),
    }


def main() -> None:
    result = build()
    print(result["spec"])
    print(result["comparison"])
    print(result["report"])


if __name__ == "__main__":
    main()
