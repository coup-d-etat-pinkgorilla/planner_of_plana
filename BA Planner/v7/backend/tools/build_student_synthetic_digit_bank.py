from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
import shutil
from typing import Any

from PIL import Image, ImageChops, ImageDraw, ImageFont

from core.recognition_assets import RecognitionAssetCatalog
from core.student_scan_recognizer import _binary_iou, _normalize_mask


BACKEND = Path(__file__).resolve().parents[1]
REPOSITORY = BACKEND.parent
ASSETS = BACKEND / "assets" / "recognition" / "v1"
OUTPUT = ASSETS / "templates" / "student_numeric_synthetic"
FONT_SOURCE = REPOSITORY / "frontend" / "assets" / "fonts" / "GyeonggiTitle-Medium.ttf"
FONT_TARGET = OUTPUT / "GyeonggiTitle-Medium.ttf"
SPEC_TARGET = OUTPUT / "renderer_spec.json"
WHOLE_BANK_TARGET = OUTPUT / "whole_value_bank.json"
PURPOSE = "student-synthetic-digit-template"
WHOLE_PURPOSE = "student-synthetic-whole-value-bank"


FIELD_RULES: dict[str, dict[str, Any]] = {
    "student_level": {
        "source_purpose": "student-basic-level-digit-template",
        "shear": -0.20,
        "mask_variants": ["fill"],
        "font_sizes": list(range(20, 41)),
        "stroke_widths": [1, 2],
        "fill": "#FFFFFF",
        "outline": "#505878",
        "layouts": [1, 2],
        "valid_range": [1, 90],
        "output_size": [52, 42],
        "center_trim": 3,
    },
    "weapon_level": {
        "source_purpose": "student-basic-weapon-level-digit-template",
        "shear": -0.25,
        "mask_variants": ["fill", "combined"],
        "font_sizes": list(range(16, 37)),
        "stroke_widths": [1, 2],
        "fill": "#FFFFFF",
        "outline": "#505878",
        "layouts": [1, 2],
        "valid_range": [1, 60],
        "output_size": [64, 48],
        "center_trim": 1,
    },
    "relationship_rank": {
        "source_purpose": "student-relationship-rank-digit-template",
        "shear": 0.0,
        "mask_variants": ["fill", "combined", "outline"],
        "font_sizes": list(range(20, 45)),
        "stroke_widths": [1, 2, 3, 4],
        "fill": "#FFFFFF",
        "outline": "#3A465D",
        "layouts": [1, 2, 3],
        "valid_range": [1, 100],
        "output_size": [72, 96],
    },
}


def _render_planes(
    font_path: Path,
    digit: str,
    *,
    font_size: int,
    stroke_width: int,
    shear: float,
) -> tuple[Image.Image, Image.Image, Image.Image]:
    font = ImageFont.truetype(str(font_path), font_size)
    canvas_size = max(96, font_size * 3)
    fill = Image.new("L", (canvas_size, canvas_size))
    combined = Image.new("L", fill.size)
    fill_draw = ImageDraw.Draw(fill)
    combined_draw = ImageDraw.Draw(combined)
    box = combined_draw.textbbox(
        (0, 0), digit, font=font, stroke_width=stroke_width,
    )
    width = box[2] - box[0]
    height = box[3] - box[1]
    anchor = (
        round((canvas_size - width) / 2 - box[0]),
        round((canvas_size - height) / 2 - box[1]),
    )
    fill_draw.text(anchor, digit, font=font, fill=255)
    combined_draw.text(
        anchor,
        digit,
        font=font,
        fill=255,
        stroke_width=stroke_width,
        stroke_fill=255,
    )
    if shear:
        affine = (1, -shear, 0, 0, 1, 0)
        fill = fill.transform(
            fill.size, Image.Transform.AFFINE, affine,
            resample=Image.Resampling.BICUBIC,
        )
        combined = combined.transform(
            combined.size, Image.Transform.AFFINE, affine,
            resample=Image.Resampling.BICUBIC,
        )
    fill = fill.point(lambda value: 255 if value >= 96 else 0)
    combined = combined.point(lambda value: 255 if value >= 96 else 0)
    outline = ImageChops.subtract(combined, fill).point(
        lambda value: 255 if value >= 127 else 0,
    )
    return fill, outline, combined


def render_digit_mask(
    font_path: Path,
    digit: str,
    *,
    font_size: int,
    stroke_width: int,
    shear: float,
    mask_variant: str,
) -> Image.Image:
    fill, outline, combined = _render_planes(
        font_path,
        digit,
        font_size=font_size,
        stroke_width=stroke_width,
        shear=shear,
    )
    try:
        selected = {"fill": fill, "outline": outline, "combined": combined}[mask_variant]
        normalized = _normalize_mask(selected)
        if normalized is None:
            raise ValueError(f"empty rendered glyph: {digit}")
        return normalized
    finally:
        fill.close()
        outline.close()
        combined.close()


def _representative_text(layout_width: int, position: int, digit: str) -> str:
    anchors = list("100")[:layout_width]
    anchors[position] = digit
    return "".join(anchors)


def render_position_mask(
    font_path: Path,
    field: str,
    digit: str,
    *,
    layout_width: int,
    position: int,
    font_size: int,
    stroke_width: int,
    shear: float,
    mask_variant: str,
    output_size: tuple[int, int],
    center_trim: int = 0,
) -> Image.Image:
    text = _representative_text(layout_width, position, digit)
    font = ImageFont.truetype(str(font_path), font_size)
    # Render at the native ROI raster scale.  The game text is rasterized before
    # the client ROI is sampled; supersampling the font here and shrinking it
    # afterwards changes the binary stroke topology that the matcher compares.
    canvas = Image.new("L", output_size)
    fill = Image.new("L", canvas.size)
    combined = Image.new("L", canvas.size)
    fill_draw = ImageDraw.Draw(fill)
    combined_draw = ImageDraw.Draw(combined)
    box = combined_draw.textbbox((0, 0), text, font=font, stroke_width=stroke_width)
    anchor = (
        round((canvas.width - (box[2] - box[0])) / 2 - box[0]),
        round((canvas.height - (box[3] - box[1])) / 2 - box[1]),
    )
    fill_draw.text(anchor, text, font=font, fill=255)
    combined_draw.text(
        anchor, text, font=font, fill=255,
        stroke_width=stroke_width, stroke_fill=255,
    )
    if shear:
        affine = (1, -shear, 0, 0, 1, 0)
        fill = fill.transform(fill.size, Image.Transform.AFFINE, affine, resample=Image.Resampling.BICUBIC)
        combined = combined.transform(combined.size, Image.Transform.AFFINE, affine, resample=Image.Resampling.BICUBIC)
    fill = fill.point(lambda value: 255 if value >= 96 else 0)
    combined = combined.point(lambda value: 255 if value >= 96 else 0)
    outline = ImageChops.subtract(combined, fill).point(lambda value: 255 if value >= 127 else 0)
    try:
        selected = {"fill": fill, "outline": outline, "combined": combined}[mask_variant]
        from core.student_scan_recognizer import split_relationship_rank_digits

        # Split the completed string at its actual low-ink valleys.  Cutting the
        # synthetic canvas at its arithmetic midpoint clips italic/sheared glyphs
        # and can leak the adjacent digit into a cell (for example 60 -> "6|0").
        # The runtime ROI is still fixed-cell, but its glyphs are already separated;
        # the generated side must preserve each complete glyph before canonicalizing.
        cells = split_relationship_rank_digits(selected, layout_width)
        if len(cells) != layout_width:
            raise ValueError(f"cannot split generated {field} text: {text}")
        normalized = cells[position].copy()
        for candidate in cells:
            candidate.close()
        if normalized is None:
            raise ValueError(f"empty generated position glyph: {field}:{layout_width}:{position}:{digit}")
        return normalized
    finally:
        fill.close()
        outline.close()
        combined.close()


def _calibration_templates(
    catalog: RecognitionAssetCatalog,
    purpose: str,
) -> dict[str, tuple[Image.Image, ...]]:
    grouped: dict[str, list[Image.Image]] = {}
    for asset in catalog.assets("student", purpose):
        if asset.identity not in set("0123456789"):
            continue
        with Image.open(catalog.resolve(asset.path)) as opened:
            normalized = _normalize_mask(opened.convert("L"))
        if normalized is not None:
            grouped.setdefault(str(asset.identity), []).append(normalized)
    return {digit: tuple(samples) for digit, samples in grouped.items()}


def _fit_field(
    font_path: Path,
    targets: dict[str, tuple[Image.Image, ...]],
    rule: dict[str, Any],
) -> dict[str, Any]:
    ranked: list[tuple[float, float, int, int, str]] = []
    for font_size in rule["font_sizes"]:
        for stroke_width in rule["stroke_widths"]:
            for mask_variant in rule["mask_variants"]:
                scores: list[float] = []
                generated: dict[str, Image.Image] = {}
                try:
                    for digit in sorted(targets):
                        generated[digit] = render_digit_mask(
                            font_path,
                            digit,
                            font_size=font_size,
                            stroke_width=stroke_width,
                            shear=float(rule["shear"]),
                            mask_variant=str(mask_variant),
                        )
                        scores.extend(
                            _binary_iou(sample, generated[digit])
                            for sample in targets[digit]
                        )
                finally:
                    for image in generated.values():
                        image.close()
                if scores:
                    ranked.append((
                        sum(scores) / len(scores), min(scores), font_size,
                        stroke_width, str(mask_variant),
                    ))
    if not ranked:
        raise ValueError("no renderer candidates")
    mean_score, minimum_score, font_size, stroke_width, mask_variant = max(
        ranked, key=lambda row: (row[0], row[1], -row[2], -row[3]),
    )
    return {
        "font_size": font_size,
        "stroke_width": stroke_width,
        "mask_variant": mask_variant,
        "calibration_mean_iou": round(mean_score, 6),
        "calibration_min_iou": round(minimum_score, 6),
    }


def _entry(path: Path, **extra: Any) -> dict[str, Any]:
    content = path.read_bytes()
    return {
        "path": path.relative_to(ASSETS).as_posix(),
        "scan_kind": "student",
        "purpose": PURPOSE,
        "required": True,
        "bytes": len(content),
        "sha256": sha256(content).hexdigest(),
        **extra,
    }


def _mask_bits(mask: Image.Image) -> tuple[str, int, int]:
    values = list(mask.convert("L").getdata())
    bits = 0
    ink = 0
    for index, value in enumerate(values):
        if value >= 127:
            bits |= 1 << index
            ink += 1
    return format(bits, "x"), ink, len(values)


def _build_whole_value_bank(font_path: Path, fields: dict[str, Any]) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema_version": 1,
        "purpose": "compact synthetic whole-value shadow bank",
        "match_size": [64, 32],
        "fields": {},
    }
    for field, rule in fields.items():
        records: list[dict[str, Any]] = []
        for value in range(int(rule["valid_range"][0]), int(rule["valid_range"][1]) + 1):
            fill, outline, combined = _render_planes(
                font_path,
                str(value),
                font_size=int(rule["font_size"]),
                stroke_width=int(rule["stroke_width"]),
                shear=float(rule["shear"]),
            )
            try:
                selected = {"fill": fill, "outline": outline, "combined": combined}[str(rule["mask_variant"])]
                normalized = _normalize_mask(selected, size=(64, 32), padding=2)
                if normalized is None:
                    raise ValueError(f"empty whole-value template: {field}:{value}")
                bits_hex, ink, pixels = _mask_bits(normalized)
                normalized.close()
            finally:
                fill.close()
                outline.close()
                combined.close()
            records.append({"value": value, "bits_hex": bits_hex, "ink": ink, "pixels": pixels})
        payload["fields"][field] = {
            "mask_variant": rule["mask_variant"],
            "valid_range": rule["valid_range"],
            "templates": records,
        }
    return payload


def build() -> dict[str, Any]:
    if not FONT_SOURCE.is_file():
        raise FileNotFoundError(FONT_SOURCE)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    FONT_TARGET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(FONT_SOURCE, FONT_TARGET)
    catalog = RecognitionAssetCatalog(ASSETS)
    renderer_fields: dict[str, Any] = {}
    entries: list[dict[str, Any]] = []
    for field, source_rule in FIELD_RULES.items():
        rule = dict(source_rule)
        targets = _calibration_templates(catalog, str(rule["source_purpose"]))
        if set(targets) != set("0123456789"):
            raise ValueError(f"incomplete calibration bank for {field}: {sorted(targets)}")
        fitted = _fit_field(FONT_TARGET, targets, rule)
        field_spec = {
            "font_size": fitted["font_size"],
            "fill": rule["fill"],
            "outline": rule["outline"],
            "stroke_width": fitted["stroke_width"],
            "shear": rule["shear"],
            "mask_variant": fitted["mask_variant"],
            "layouts": rule["layouts"],
            "valid_range": rule["valid_range"],
            "output_size": rule["output_size"],
            "center_trim": int(rule.get("center_trim", 0)),
            "calibration_source_purpose": rule["source_purpose"],
            "calibration_mean_iou": fitted["calibration_mean_iou"],
            "calibration_min_iou": fitted["calibration_min_iou"],
            "selection": "user-verified font/shear; bounded size/stroke search against calibration partition",
            "render_pipeline": "complete_string_native_raster->field_roi->low_ink_split->20x28_binary_glyph",
            "raster_size_offsets": [-2, -1, 0, 1, 2],
        }
        renderer_fields[field] = field_spec
        field_root = OUTPUT / field
        if field_root.exists():
            shutil.rmtree(field_root)
        for layout_width in rule["layouts"]:
            for position in range(layout_width):
                for digit in "0123456789":
                    for variant, size_offset in enumerate((-2, -1, 0, 1, 2)):
                        glyph = render_position_mask(
                            FONT_TARGET,
                            field,
                            digit,
                            layout_width=layout_width,
                            position=position,
                            font_size=int(fitted["font_size"]) + size_offset,
                            stroke_width=int(fitted["stroke_width"]),
                            shear=float(rule["shear"]),
                            mask_variant=str(fitted["mask_variant"]),
                            output_size=tuple(int(value) for value in rule["output_size"]),
                            center_trim=int(rule.get("center_trim", 0)),
                        )
                        target = (
                            field_root / f"layout_{layout_width}" / f"position_{position}"
                            / f"{digit}_v{variant}.png"
                        )
                        target.parent.mkdir(parents=True, exist_ok=True)
                        glyph.save(target)
                        glyph.close()
                        entries.append(_entry(
                            target,
                            digit=digit,
                            numeric_field=field,
                            layout_width=layout_width,
                            position=position,
                            raster_variant=variant,
                            font_size=int(fitted["font_size"]) + size_offset,
                            source_path="generated:user-verified-gyeonggi-medium-v1",
                        ))
        for samples in targets.values():
            for sample in samples:
                sample.close()
    font_bytes = FONT_TARGET.read_bytes()
    spec = {
        "schema_version": 1,
        "purpose": "student numeric deterministic synthetic renderer",
        "font": {
            "path": FONT_TARGET.relative_to(ASSETS).as_posix(),
            "family": "GyeonggiTitle",
            "weight": "Medium",
            "sha256": sha256(font_bytes).hexdigest(),
            "bytes": len(font_bytes),
        },
        "review_basis": "manual visual review in v6 Template Alignment Studio",
        "fields": renderer_fields,
    }
    SPEC_TARGET.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    whole_bank = _build_whole_value_bank(FONT_TARGET, renderer_fields)
    WHOLE_BANK_TARGET.write_text(
        json.dumps(whole_bank, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    entries.extend([
        _entry(FONT_TARGET, asset_role="font", source_path="frontend/assets/fonts/GyeonggiTitle-Medium.ttf"),
        _entry(SPEC_TARGET, asset_role="renderer_spec", source_path="generated:user-verified-renderer-spec-v1"),
        _entry(
            WHOLE_BANK_TARGET,
            purpose=WHOLE_PURPOSE,
            asset_role="weapon_level_fallback_other_fields_shadow",
            source_path="generated:complete-string-64x32-bitset-shadow-v1",
        ),
    ])
    manifest_path = ASSETS / "student_basic_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["assets"] = [
        item for item in manifest["assets"]
        if item.get("purpose") not in {PURPOSE, WHOLE_PURPOSE}
    ]
    manifest["assets"].extend(entries)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return {"template_count": 600, "whole_value_templates": 250, "fields": renderer_fields}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.parse_args()
    print(json.dumps(build(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
