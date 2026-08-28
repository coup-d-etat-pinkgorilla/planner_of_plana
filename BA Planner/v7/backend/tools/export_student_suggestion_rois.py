from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont, ImageOps

from core.studio_roi_suggestion import (
    StudioRoiSuggestion,
    draw_suggestion_overlay,
    extract_studio_roi,
    load_studio_suggestion,
    scaled_roi_points,
)


ROOT = Path(__file__).resolve().parents[2]
SUGGESTION = ROOT / "suggestion.json"
OUTPUT = ROOT / "debug" / "student_suggestion_rois"
FONT = ROOT / "frontend" / "assets" / "fonts" / "GyeonggiTitle-Medium.ttf"
BG = "#14263A"
PANEL = "#20364B"
GRID = "#5D7891"
TEXT = "#F1F7FC"


def _font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT), size)


def _group_and_position(name: str) -> tuple[str, int]:
    patterns = (
        (r"weaponlevel_digit(\d+)$", "weapon level"),
        (r"equip(\d+)level_digit(\d+)$", "equipment"),
        (r"studentlevel_digit(\d+)$", "student level"),
        (r"affectionlevel_digit(\d+)$", "relationship rank"),
    )
    for pattern, label in patterns:
        match = re.fullmatch(pattern, name)
        if not match:
            continue
        if label == "equipment":
            return f"equipment {match.group(1)} level", int(match.group(2))
        return label, int(match.group(1))
    return name, 1


def _checker(size: tuple[int, int], step: int = 8) -> Image.Image:
    image = Image.new("RGB", size, "#E3E9EE")
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                draw.rectangle((x, y, x + step - 1, y + step - 1), fill="#B9C4CD")
    return image


def _fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    checker = _checker(size)
    fitted = ImageOps.contain(rgba, size, Image.Resampling.NEAREST)
    checker.paste(
        fitted.convert("RGB"),
        ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2),
        fitted.getchannel("A"),
    )
    fitted.close()
    rgba.close()
    return checker


def _cell(
    sheet: Image.Image,
    draw: ImageDraw.ImageDraw,
    image: Image.Image,
    box: tuple[int, int, int, int],
    label: str,
) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle(box, radius=8, fill=PANEL, outline=GRID)
    draw.text((x1 + 8, y1 + 6), label, font=_font(15), fill=TEXT)
    fitted = _fit(image, (x2 - x1 - 12, y2 - y1 - 34))
    sheet.paste(fitted, (x1 + 6, y1 + 28))
    fitted.close()


def _context_crop(
    source: Image.Image,
    rois: list[StudioRoiSuggestion],
    reference_size: tuple[int, int],
) -> Image.Image:
    points = [
        point
        for roi in rois
        for point in scaled_roi_points(roi, reference_size=reference_size, target_size=source.size)
    ]
    margin = 18
    box = (
        max(0, int(min(x for x, _y in points)) - margin),
        max(0, int(min(y for _x, y in points)) - margin),
        min(source.width, int(max(x for x, _y in points)) + margin),
        min(source.height, int(max(y for _x, y in points)) + margin),
    )
    overlay = draw_suggestion_overlay(source, load_studio_suggestion(SUGGESTION))
    result = overlay.crop(box)
    overlay.close()
    return result


def export() -> Path:
    suggestion = load_studio_suggestion(SUGGESTION)
    with Image.open(suggestion.reference_path) as opened:
        reference = opened.convert("RGBA")
    groups: dict[str, list[tuple[int, StudioRoiSuggestion]]] = defaultdict(list)
    for roi in suggestion.rois:
        group, position = _group_and_position(roi.name)
        groups[group].append((position, roi))

    OUTPUT.mkdir(parents=True, exist_ok=True)
    extracted: dict[str, Image.Image] = {}
    for roi in suggestion.rois:
        crop = extract_studio_roi(reference, roi, reference_size=suggestion.reference_size)
        crop.save(OUTPUT / f"{roi.name}.png")
        extracted[roi.name] = crop

    width, header, row_height = 1500, 112, 196
    ordered_groups = (
        "student level", "relationship rank", "weapon level",
        "equipment 1 level", "equipment 2 level", "equipment 3 level",
    )
    sheet = Image.new("RGB", (width, header + row_height * len(ordered_groups)), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 14), "v6 Studio suggestion.json - exact ROI extraction", font=_font(28), fill=TEXT)
    draw.text(
        (24, 50),
        "Studio context | digit 1 polygon crop | digit 2 polygon crop | combined source bounds | stored geometry",
        font=_font(17), fill="#AFC3D5",
    )
    draw.text(
        (24, 78),
        f"Reference {suggestion.reference_size[0]}x{suggestion.reference_size[1]} · points are used directly · no warp/resampling",
        font=_font(15), fill="#58E6FF",
    )
    try:
        for index, group in enumerate(ordered_groups):
            y = header + index * row_height
            records = sorted(groups[group], key=lambda item: item[0])
            rois = [roi for _position, roi in records]
            context = _context_crop(reference, rois, suggestion.reference_size)
            all_points = [point for roi in rois for point in roi.points]
            combined_box = (
                int(min(x for x, _y in all_points)), int(min(y for _x, y in all_points)),
                int(max(x for x, _y in all_points)), int(max(y for _x, y in all_points)),
            )
            combined = reference.crop(combined_box)
            draw.text((24, y + 8), group, font=_font(19), fill=TEXT)
            _cell(sheet, draw, context, (24, y + 38, 330, y + 184), "Studio polygon context")
            for position in (1, 2):
                roi = next((item for item_position, item in records if item_position == position), None)
                image = extracted[roi.name] if roi is not None else Image.new("RGBA", (1, 1))
                _cell(
                    sheet, draw, image,
                    (344 + (position - 1) * 250, y + 38, 580 + (position - 1) * 250, y + 184),
                    roi.name if roi is not None else f"digit {position} missing",
                )
                if roi is None:
                    image.close()
            _cell(sheet, draw, combined, (844, y + 38, 1080, y + 184), "Combined source bounds")
            for line, (position, roi) in enumerate(records):
                geometry = (
                    f"d{position}: {roi.shape} {roi.slant:+d}px  "
                    f"{int(max(x for x, _y in roi.points)-min(x for x, _y in roi.points))}x"
                    f"{int(max(y for _x, y in roi.points)-min(y for _x, y in roi.points))}"
                )
                draw.text((1100, y + 54 + line * 25), geometry, font=_font(15), fill="#FFD166")
            draw.text((1100, y + 108), "RGBA polygon mask", font=_font(15), fill="#BFD0DF")
            draw.text((1100, y + 134), "source pixels unchanged", font=_font(15), fill="#64E6B1")
            context.close()
            combined.close()
    finally:
        for image in extracted.values():
            image.close()
        reference.close()
    target = OUTPUT / "suggestion_roi_comparison.png"
    sheet.save(target)
    sheet.close()
    return target


def main() -> None:
    print(export())


if __name__ == "__main__":
    main()
