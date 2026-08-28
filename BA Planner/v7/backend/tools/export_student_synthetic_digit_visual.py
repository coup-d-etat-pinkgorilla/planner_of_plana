from __future__ import annotations

import json
from pathlib import Path
import re
from typing import Any, Callable

from PIL import Image, ImageDraw, ImageFont, ImageOps

from core.recognition_assets import RecognitionAssetCatalog
from core.slanted_digit_roi import (
    draw_parallelogram_boundaries,
    split_parallelogram_digit_cells,
)
from core.student_equipment_recognizer import StudentEquipmentRecognizer, _text_mask_variants
from core.student_scan_recognizer import (
    StudentBasicCropSet,
    _mask_from_predicate,
    relationship_rank_number_crop,
    relationship_rank_number_mask,
)
from tools.benchmark_student_synthetic_digits import (
    ASSETS,
    ATTACHED_FRAMES,
    BACKEND,
    RELATIONSHIP_FIXTURE,
    SERIKA_ANSWERS,
    SERIKA_FRAME,
    SHADOW_GATES,
    _templates,
    read_relationship_rank,
    read_student_level,
    read_weapon_level,
)


OUTPUT = BACKEND.parent / "debug" / "student_synthetic_digits"
SYNTHETIC_SPEC = ASSETS / "templates" / "student_numeric_synthetic" / "renderer_spec.json"
LABEL_FONT = BACKEND.parent / "frontend" / "assets" / "fonts" / "GyeonggiTitle-Medium.ttf"
BG = "#14263A"
PANEL = "#20364B"
GRID = "#5D7891"
TEXT = "#F1F7FC"
OK = "#64E6B1"
BAD = "#FF7084"
FALLBACK = "#FFD166"


def _font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(LABEL_FONT), size)


def _fit(image: Image.Image, size: tuple[int, int], *, nearest: bool = False) -> Image.Image:
    source = image.convert("RGB")
    result = Image.new("RGB", size, PANEL)
    fitted = ImageOps.contain(
        source,
        size,
        Image.Resampling.NEAREST if nearest else Image.Resampling.LANCZOS,
    )
    result.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    fitted.close()
    source.close()
    return result


def _mask_panel(mask: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgb = Image.new("RGB", mask.size, "#0C1724")
    rgb.paste("#FFFFFF", mask=mask.convert("L"))
    result = _fit(rgb, size, nearest=True)
    rgb.close()
    return result


def _template_text(field: str, value: int, size: tuple[int, int]) -> Image.Image:
    text = str(value)
    canvas = Image.new("L", (max(1, len(text) * 24), 32))
    for position, digit in enumerate(text):
        templates = _templates(field, len(text), position)
        try:
            sample = templates[digit][2 if len(templates[digit]) >= 3 else 0]
            canvas.paste(sample, (position * 24 + 2, 2), sample)
        finally:
            for samples in templates.values():
                for image in samples:
                    image.close()
    return _mask_panel(canvas, size)


def _smooth_template_text(field: str, value: int, size: tuple[int, int]) -> Image.Image:
    if field == "equipment_level":
        rule = {
            "font_size": 30, "stroke_width": 1, "shear": -0.25,
            "fill": "#FFFFFF", "outline": "#505878",
        }
        font_path = ASSETS / "templates" / "student_equipment" / "equipment_level_medium.ttf"
    else:
        spec = json.loads(SYNTHETIC_SPEC.read_text(encoding="utf-8"))
        rule = spec["fields"][field]
        font_path = ASSETS / spec["font"]["path"]
    scale = 4
    font = ImageFont.truetype(str(font_path), int(rule["font_size"]) * scale)
    text = str(value)
    probe = Image.new("RGBA", (512, 256))
    draw = ImageDraw.Draw(probe)
    stroke = int(rule["stroke_width"]) * scale
    box = draw.textbbox((0, 0), text, font=font, stroke_width=stroke)
    anchor = (32 - box[0], 24 - box[1])
    draw.text(
        anchor, text, font=font, fill=str(rule["fill"]),
        stroke_width=stroke, stroke_fill=str(rule["outline"]),
    )
    shear = float(rule["shear"])
    if shear:
        probe = probe.transform(
            probe.size, Image.Transform.AFFINE, (1, -shear, 0, 0, 1, 0),
            resample=Image.Resampling.BICUBIC,
        )
    alpha_box = probe.getchannel("A").getbbox()
    rendered = probe.crop(alpha_box) if alpha_box is not None else probe.copy()
    result = _fit(rendered, size)
    rendered.close()
    probe.close()
    return result


def _equipment_template_text(value: int, size: tuple[int, int]) -> Image.Image:
    payload = json.loads(
        (ASSETS / "templates" / "student_equipment" / "basic_position_digits.json")
        .read_text(encoding="utf-8")
    )
    grouped = {
        (int(item["position"]), str(item["digit"])): item
        for item in payload["templates"]
    }
    text = str(value)
    canvas = Image.new("L", (len(text) * 24, 32))
    for index, digit in enumerate(text, start=1):
        item = grouped[(index, digit)]
        bits = int(str(item["bits_hex"]), 16)
        pixels = int(item["pixels"])
        glyph = Image.new("L", (20, pixels // 20))
        glyph.putdata([255 if bits & (1 << offset) else 0 for offset in range(pixels)])
        canvas.paste(glyph, ((index - 1) * 24 + 2, 2), glyph)
        glyph.close()
    result = _mask_panel(canvas, size)
    canvas.close()
    return result


def _whole_value_template(field: str, value: int, size: tuple[int, int]) -> Image.Image:
    payload = json.loads(
        (ASSETS / "templates" / "student_numeric_synthetic" / "whole_value_bank.json")
        .read_text(encoding="utf-8")
    )
    item = next(
        record for record in payload["fields"][field]["templates"]
        if int(record["value"]) == value
    )
    pixels = int(item["pixels"])
    bits = int(str(item["bits_hex"]), 16)
    mask = Image.new("L", tuple(payload["match_size"]))
    mask.putdata([255 if bits & (1 << index) else 0 for index in range(pixels)])
    result = _mask_panel(mask, size)
    mask.close()
    return result


def _paste_cell(
    sheet: Image.Image,
    draw: ImageDraw.ImageDraw,
    image: Image.Image,
    box: tuple[int, int, int, int],
    label: str,
) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle(box, radius=8, fill=PANEL, outline=GRID, width=1)
    draw.text((x1 + 8, y1 + 6), label, font=_font(15), fill=TEXT)
    fitted = _fit(image, (x2 - x1 - 12, y2 - y1 - 34), nearest=image.mode == "L")
    sheet.paste(fitted, (x1 + 6, y1 + 28))
    fitted.close()


def _level_mask(crop: Image.Image) -> Image.Image:
    return _mask_from_predicate(
        crop.convert("RGB"),
        # ROI-first diagnostic: keep the pale level fill while rejecting the
        # bright blue/yellow backing that polluted the former luminance mask.
        lambda pixel: min(pixel) >= 215 and max(pixel) - min(pixel) <= 50,
    )


def _weapon_mask(crop: Image.Image) -> Image.Image:
    return _mask_from_predicate(
        crop.convert("RGB"),
        lambda pixel: min(pixel) >= 238 and max(pixel) - min(pixel) <= 28,
    )


def export_basic() -> Path:
    rows: list[tuple[Path, dict[str, int]]] = [(SERIKA_FRAME, SERIKA_ANSWERS)]
    rows.extend((path, answers) for path, answers in ATTACHED_FRAMES if path.is_file())
    catalog = RecognitionAssetCatalog(ASSETS)
    regions = catalog.region("student")
    width = 2040
    header = 86
    row_height = 300
    sheet = Image.new("RGB", (width, header + row_height * len(rows)), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 16), "Synthetic numeric templates - Basic screen ROI comparison", font=_font(28), fill=TEXT)
    draw.text(
        (24, 52),
        "Actual ROI | extracted mask | smooth font render | expected match mask | selected match mask",
        font=_font(17), fill="#AFC3D5",
    )
    fields: tuple[tuple[str, str, Callable[[Image.Image], Image.Image], Callable[[Image.Image], dict[str, Any]]], ...] = (
        ("student_level", "basic_level_digits_quad", _level_mask, read_student_level),
        ("weapon_level", "basic_weapon_level_digits_quad", _weapon_mask, read_weapon_level),
        ("relationship_rank", "basic_relationship_rank_region", relationship_rank_number_mask, read_relationship_rank),
    )
    for row_index, (path, answers) in enumerate(rows):
        y = header + row_index * row_height
        with Image.open(path) as opened:
            crops = StudentBasicCropSet.from_frame(opened.convert("RGB"), regions)
        try:
            draw.text((24, y + 8), path.name, font=_font(18), fill="#8DD9FF")
            for field_index, (field, crop_key, mask_fn, read_fn) in enumerate(fields):
                crop = crops.images[crop_key]
                observed = read_fn(crop)
                expected = int(answers[field])
                base_x = 24 + field_index * 664
                draw.text((base_x, y + 40), field.replace("_", " "), font=_font(17), fill=TEXT)
                mask = mask_fn(crop)
                display_crop = relationship_rank_number_crop(crop) if field == "relationship_rank" else crop
                smooth_image = _smooth_template_text(field, expected, (118, 112))
                expected_image = _template_text(field, expected, (118, 112))
                observed_image = _template_text(field, int(observed["value"]), (118, 112))
                _paste_cell(sheet, draw, display_crop, (base_x, y + 66, base_x + 126, y + 236), "Numeric ROI" if field == "relationship_rank" else "Actual ROI")
                _paste_cell(sheet, draw, mask, (base_x + 134, y + 66, base_x + 260, y + 236), "Extracted")
                _paste_cell(sheet, draw, smooth_image, (base_x + 268, y + 66, base_x + 394, y + 236), f"Font {expected}")
                _paste_cell(sheet, draw, expected_image, (base_x + 402, y + 66, base_x + 528, y + 236), f"Expected {expected}")
                _paste_cell(sheet, draw, observed_image, (base_x + 536, y + 66, base_x + 662, y + 236), f"Selected {observed['value']}")
                correct = observed["value"] == expected
                accepted = (
                    observed["score"] >= SHADOW_GATES[field]["score"]
                    and observed["margin"] >= SHADOW_GATES[field]["margin"]
                )
                status = "PASS" if accepted and correct else "FALLBACK" if not accepted else "WRONG"
                status_color = OK if status == "PASS" else FALLBACK if status == "FALLBACK" else BAD
                draw.text(
                    (base_x, y + 248),
                    f"{status}  raw {observed['value']} / {expected}  score {observed['score']:.3f}  margin {observed['margin']:.3f}",
                    font=_font(16), fill=status_color,
                )
                mask.close()
                if display_crop is not crop:
                    display_crop.close()
                smooth_image.close()
                expected_image.close()
                observed_image.close()
        finally:
            crops.close()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / "basic_screen_roi_comparison.png"
    sheet.save(target)
    sheet.close()
    return target


def export_relationship_validation() -> Path:
    manifest = json.loads((RELATIONSHIP_FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    records = [record for record in manifest["records"] if record["partition"] == "validation"]
    width = 1320
    header = 90
    row_height = 154
    sheet = Image.new("RGB", (width, header + row_height * len(records)), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 16), "Relationship rank - independent 1280x720 validation", font=_font(28), fill=TEXT)
    draw.text((24, 52), "Actual ROI | extracted mask | smooth font render | expected match mask | selected match mask", font=_font(17), fill="#AFC3D5")
    with Image.open(RELATIONSHIP_FIXTURE / manifest["atlas"]["path"]) as atlas:
        for index, record in enumerate(records):
            y = header + index * row_height
            crop = atlas.crop(record["atlas_box"])
            mask = relationship_rank_number_mask(crop)
            observed = read_relationship_rank(crop)
            expected = int(record["rank"])
            smooth_image = _smooth_template_text("relationship_rank", expected, (156, 104))
            expected_image = _template_text("relationship_rank", expected, (156, 104))
            selected_image = _template_text("relationship_rank", int(observed["value"]), (156, 104))
            numeric_crop = relationship_rank_number_crop(crop)
            _paste_cell(sheet, draw, numeric_crop, (24, y + 8, 210, y + 140), "Numeric ROI")
            _paste_cell(sheet, draw, mask, (220, y + 8, 406, y + 140), "Extracted mask")
            _paste_cell(sheet, draw, smooth_image, (416, y + 8, 602, y + 140), f"Font {expected}")
            _paste_cell(sheet, draw, expected_image, (612, y + 8, 798, y + 140), f"Expected {expected}")
            _paste_cell(sheet, draw, selected_image, (808, y + 8, 994, y + 140), f"Selected {observed['value']}")
            accepted = observed["score"] >= 0.45 and observed["margin"] >= 0.05
            correct = observed["value"] == expected
            status = "PASS" if accepted and correct else "FALLBACK" if not accepted else "WRONG"
            color = OK if status == "PASS" else FALLBACK if status == "FALLBACK" else BAD
            draw.text((1016, y + 24), status, font=_font(22), fill=color)
            draw.text((1016, y + 60), f"raw {observed['value']} / {expected}", font=_font(17), fill=TEXT)
            draw.text((1016, y + 88), f"score {observed['score']:.3f}", font=_font(16), fill="#BFD0DF")
            draw.text((1016, y + 112), f"margin {observed['margin']:.3f}", font=_font(16), fill="#BFD0DF")
            crop.close()
            numeric_crop.close()
            mask.close()
            smooth_image.close()
            expected_image.close()
            selected_image.close()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / "relationship_validation_roi_comparison.png"
    sheet.save(target)
    sheet.close()
    return target


def export_equipment_validation() -> Path:
    fixture_roots = (
        BACKEND / "tests" / "fixtures" / "student_equipment_s3b_archive",
        BACKEND / "tests" / "fixtures" / "student_equipment_s3b_promotion_probe",
        BACKEND / "tests" / "fixtures" / "student_equipment_s3b_1280_digits",
    )
    wanted = (1, 8, 9, 12, 50, 60, 70)
    selected: dict[int, tuple[Image.Image, dict[str, Any]]] = {}
    for root in fixture_roots:
        manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
        with Image.open(root / manifest["atlas"]["path"]) as atlas:
            for record in manifest["records"]:
                value = int(record["expected_value"])
                if value in wanted and value not in selected:
                    selected[value] = (atlas.crop(tuple(record["atlas_box"])), record)
    catalog = RecognitionAssetCatalog(ASSETS)
    recognizer = StudentEquipmentRecognizer(catalog)
    regions = catalog.region("student")
    width, header, row_height = 1320, 90, 154
    rows = [selected[value] for value in wanted if value in selected]
    sheet = Image.new("RGB", (width, header + row_height * len(rows)), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 16), "Equipment level - Medium position-bank validation", font=_font(28), fill=TEXT)
    draw.text((24, 52), "Actual ROI | extracted fill | smooth Medium render | expected position mask | selected position mask", font=_font(17), fill="#AFC3D5")
    try:
        for index, (crop, record) in enumerate(rows):
            y = header + index * row_height
            expected = int(record["expected_value"])
            region = regions[f"basic_equipment_{record['slot']}_level_digits_quad"]
            observed = recognizer.read_position_binary_level(crop, tier=str(record["tier"]), region=region)
            match = re.search(r"candidate=(\d+)", observed.note)
            value = int(match.group(1)) if match else expected
            variants = _text_mask_variants(crop)
            smooth = _smooth_template_text("equipment_level", expected, (156, 104))
            expected_image = _equipment_template_text(expected, (156, 104))
            selected_image = _equipment_template_text(value, (156, 104))
            _paste_cell(sheet, draw, crop, (24, y + 8, 210, y + 140), "Actual ROI")
            _paste_cell(sheet, draw, variants["fill"], (220, y + 8, 406, y + 140), "Extracted fill")
            _paste_cell(sheet, draw, smooth, (416, y + 8, 602, y + 140), f"Font {expected}")
            _paste_cell(sheet, draw, expected_image, (612, y + 8, 798, y + 140), f"Expected {expected}")
            _paste_cell(sheet, draw, selected_image, (808, y + 8, 994, y + 140), f"Selected {value}")
            correct = value == expected and observed.confirmed
            draw.text((1016, y + 35), "PASS" if correct else "WRONG", font=_font(22), fill=OK if correct else BAD)
            draw.text((1016, y + 76), f"score {observed.confidence:.3f}", font=_font(16), fill=TEXT)
            margin = re.search(r"margin=([0-9.]+)", observed.note)
            draw.text((1016, y + 104), f"margin {float(margin.group(1)) if margin else 0.0:.3f}", font=_font(16), fill="#BFD0DF")
            for image in variants.values():
                image.close()
            smooth.close()
            expected_image.close()
            selected_image.close()
    finally:
        recognizer.close()
        for crop, _record in rows:
            crop.close()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / "equipment_level_roi_comparison.png"
    sheet.save(target)
    sheet.close()
    return target


def export_whole_value_validation() -> Path:
    report = json.loads(
        (BACKEND / "tests" / "fixtures" / "student_whole_value_benchmark.json")
        .read_text(encoding="utf-8")
    )
    catalog = RecognitionAssetCatalog(ASSETS)
    regions = catalog.region("student")
    source_frames = {SERIKA_FRAME.name: SERIKA_FRAME}
    source_frames.update({path.name: path for path, _answers in ATTACHED_FRAMES if path.is_file()})
    relationship_manifest = json.loads((RELATIONSHIP_FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    relationship_records = {
        str(record["source_file"]): record for record in relationship_manifest["records"]
        if record["partition"] == "validation"
    }
    display_rows: list[tuple[str, dict[str, Any], Image.Image, Image.Image]] = []
    for field in ("student_level", "weapon_level"):
        crop_key = "basic_level_digits_quad" if field == "student_level" else "basic_weapon_level_digits_quad"
        mask_fn = _level_mask if field == "student_level" else _weapon_mask
        for row in report["fields"][field]["rows"]:
            with Image.open(source_frames[str(row["source"])]) as opened:
                crops = StudentBasicCropSet.from_frame(opened.convert("RGB"), regions)
            crop = crops.images[crop_key].copy()
            mask = mask_fn(crop)
            crops.close()
            display_rows.append((field, row, crop, mask))
    with Image.open(RELATIONSHIP_FIXTURE / relationship_manifest["atlas"]["path"]) as atlas:
        for row in report["fields"]["relationship_rank"]["rows"]:
            record = relationship_records[str(row["source"])]
            heart = atlas.crop(tuple(record["atlas_box"]))
            crop = relationship_rank_number_crop(heart)
            mask = relationship_rank_number_mask(heart)
            heart.close()
            display_rows.append(("relationship_rank", row, crop, mask))
    width, header, row_height = 1320, 90, 154
    sheet = Image.new("RGB", (width, header + row_height * len(display_rows)), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 16), "Whole-value templates - ROI and timing validation", font=_font(28), fill=TEXT)
    draw.text((24, 52), "Numeric ROI | full extracted mask | smooth font | expected whole mask | selected whole mask", font=_font(17), fill="#AFC3D5")
    try:
        for index, (field, row, crop, mask) in enumerate(display_rows):
            y = header + index * row_height
            expected = int(row["expected"])
            observed = int(row["observed"])
            smooth = _smooth_template_text(field, expected, (156, 104))
            expected_image = _whole_value_template(field, expected, (156, 104))
            selected_image = _whole_value_template(field, observed, (156, 104))
            _paste_cell(sheet, draw, crop, (24, y + 8, 210, y + 140), f"{field} ROI")
            _paste_cell(sheet, draw, mask, (220, y + 8, 406, y + 140), "Full mask")
            _paste_cell(sheet, draw, smooth, (416, y + 8, 602, y + 140), f"Font {expected}")
            _paste_cell(sheet, draw, expected_image, (612, y + 8, 798, y + 140), f"Expected {expected}")
            _paste_cell(sheet, draw, selected_image, (808, y + 8, 994, y + 140), f"Selected {observed}")
            correct = bool(row["correct"])
            draw.text((1016, y + 26), "PASS" if correct else "WRONG", font=_font(22), fill=OK if correct else BAD)
            draw.text((1016, y + 66), f"score {float(row['score']):.3f}", font=_font(16), fill=TEXT)
            draw.text((1016, y + 94), f"margin {float(row['margin']):.3f}", font=_font(16), fill="#BFD0DF")
            smooth.close()
            expected_image.close()
            selected_image.close()
    finally:
        for _field, _row, crop, mask in display_rows:
            crop.close()
            mask.close()
    draw.text((1016, 8), f"cold {report['templates']['cold_load_ms']:.3f} ms | 250 templates | 64 KB", font=_font(15), fill="#8DD9FF")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / "whole_value_roi_comparison.png"
    sheet.save(target)
    sheet.close()
    return target


def export_parallelogram_digit_rois() -> Path:
    """Export the ROI-first gate without scoring any recognition template."""

    catalog = RecognitionAssetCatalog(ASSETS)
    regions = catalog.region("student")
    rows: list[tuple[str, str, int, float, Image.Image, Image.Image]] = []
    basic_sources: list[tuple[Path, dict[str, int]]] = [(SERIKA_FRAME, SERIKA_ANSWERS)]
    basic_sources.extend((path, answers) for path, answers in ATTACHED_FRAMES if path.is_file())
    for path, answers in basic_sources:
        with Image.open(path) as opened:
            crops = StudentBasicCropSet.from_frame(opened.convert("RGB"), regions)
        try:
            for field, crop_key, mask_fn, shear in (
                ("student_level", "basic_level_digits_quad", _level_mask, -0.20),
                ("weapon_level", "basic_weapon_level_digits_quad", _weapon_mask, -0.25),
            ):
                crop = crops.images[crop_key].copy()
                rows.append((field, path.name, int(answers[field]), shear, crop, mask_fn(crop)))
        finally:
            crops.close()

    relationship_manifest = json.loads((RELATIONSHIP_FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    with Image.open(RELATIONSHIP_FIXTURE / relationship_manifest["atlas"]["path"]) as atlas:
        for record in relationship_manifest["records"]:
            if record["partition"] != "validation":
                continue
            heart = atlas.crop(tuple(record["atlas_box"]))
            crop = relationship_rank_number_crop(heart)
            mask = relationship_rank_number_mask(heart)
            heart.close()
            rows.append(
                ("relationship_rank", str(record["source_file"]), int(record["rank"]), 0.0, crop, mask)
            )

    equipment_roots = (
        BACKEND / "tests" / "fixtures" / "student_equipment_s3b_archive",
        BACKEND / "tests" / "fixtures" / "student_equipment_s3b_promotion_probe",
        BACKEND / "tests" / "fixtures" / "student_equipment_s3b_1280_digits",
    )
    wanted = (1, 8, 9, 12, 50, 60, 70)
    equipment: dict[int, tuple[Image.Image, dict[str, Any], str]] = {}
    for root in equipment_roots:
        manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
        with Image.open(root / manifest["atlas"]["path"]) as atlas:
            for record in manifest["records"]:
                value = int(record["expected_value"])
                if value in wanted and value not in equipment:
                    equipment[value] = (atlas.crop(tuple(record["atlas_box"])), record, root.name)
    for value in wanted:
        if value not in equipment:
            continue
        crop, record, source = equipment[value]
        variants = _text_mask_variants(crop)
        mask = variants["fill"].copy()
        for variant in variants.values():
            variant.close()
        rows.append(("equipment_level", f"{source}/slot{record['slot']}", value, -0.25, crop, mask))

    width, header, row_height = 1500, 106, 142
    sheet = Image.new("RGB", (width, header + len(rows) * row_height), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 14), "ROI-first parallelogram digit extraction", font=_font(28), fill=TEXT)
    draw.text(
        (24, 50),
        "Original numeric ROI | slanted boundaries on original pixels | digit 1 | digit 2 | digit 3",
        font=_font(17), fill="#AFC3D5",
    )
    draw.text(
        (24, 76),
        "No inverse shear, affine deskew or glyph resampling is applied during the split.",
        font=_font(15), fill="#8DD9FF",
    )
    try:
        for index, (field, source, expected, shear, crop, mask) in enumerate(rows):
            y = header + index * row_height
            digit_count = len(str(expected))
            cells = split_parallelogram_digit_cells(mask, digit_count, shear=shear)
            overlay = draw_parallelogram_boundaries(crop, cells)
            draw.text((24, y + 6), f"{field}  value={expected}  shear={shear:+.2f}  {source}", font=_font(16), fill=TEXT)
            _paste_cell(sheet, draw, crop, (24, y + 30, 258, y + 134), "Numeric ROI")
            _paste_cell(sheet, draw, overlay, (270, y + 30, 504, y + 134), "Parallelogram bounds")
            for position in range(3):
                image = cells[position].image if position < len(cells) else Image.new("L", (1, 1))
                _paste_cell(
                    sheet, draw, image,
                    (516 + position * 246, y + 30, 750 + position * 246, y + 134),
                    f"Digit {position + 1}" if position < len(cells) else "Unused",
                )
                if position >= len(cells):
                    image.close()
            status = "ROI OK" if len(cells) == digit_count else "EMPTY CELL"
            draw.text((1268, y + 66), status, font=_font(18), fill=OK if len(cells) == digit_count else BAD)
            overlay.close()
            for cell in cells:
                cell.close()
    finally:
        for _field, _source, _expected, _shear, crop, mask in rows:
            crop.close()
            mask.close()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / "parallelogram_digit_roi_comparison.png"
    sheet.save(target)
    sheet.close()
    return target


def main() -> None:
    print(export_basic())
    print(export_relationship_validation())
    print(export_equipment_validation())
    print(export_whole_value_validation())
    print(export_parallelogram_digit_rois())


if __name__ == "__main__":
    main()
