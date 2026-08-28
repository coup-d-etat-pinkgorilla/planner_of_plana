from __future__ import annotations

from collections import deque
from dataclasses import replace
import json
from pathlib import Path

from PIL import Image, ImageDraw

from core.studio_roi_suggestion import extract_studio_roi, load_studio_suggestion
from tools.benchmark_student_studio_text_archive import REPORT, SCREENSHOTS, _rank
from tools.build_student_studio_text_templates import (
    DEBUG,
    ROOT,
    SUGGESTION,
    _binary_mask,
    _font,
    _keep_digit_component,
    _panel,
    _source_digit_mask,
    build,
)


OUTPUT = DEBUG / "suggestion_text_postprocess_comparison.png"


def _legacy_component(mask: Image.Image) -> Image.Image:
    active = {
        (x, y)
        for y in range(mask.height)
        for x in range(mask.width)
        if mask.getpixel((x, y)) >= 127
    }
    components: list[list[tuple[int, int]]] = []
    while active:
        start = active.pop()
        queue = deque([start])
        component = [start]
        while queue:
            x, y = queue.popleft()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    point = (x + dx, y + dy)
                    if point in active:
                        active.remove(point)
                        queue.append(point)
                        component.append(point)
        components.append(component)
    result = Image.new("L", mask.size)
    if not components:
        return result

    def score(component: list[tuple[int, int]]) -> tuple[int, int, float]:
        touches = sum(
            x in (0, mask.width - 1) or y in (0, mask.height - 1)
            for x, y in component
        )
        center = sum(abs(x - (mask.width - 1) / 2.0) for x, _y in component) / len(component)
        return -touches, len(component), -center

    for x, y in max(components, key=score):
        result.putpixel((x, y), 255)
    return result


def _source(name: str) -> Path:
    matches = list(SCREENSHOTS.rglob(name))
    if not matches:
        raise ValueError(f"missing screenshot {name}")
    return matches[0]


def _paste(sheet: Image.Image, draw: ImageDraw.ImageDraw, image: Image.Image, x: int, y: int, label: str) -> None:
    draw.rounded_rectangle((x, y, x + 210, y + 134), radius=8, fill="#20364B", outline="#5D7891")
    draw.text((x + 8, y + 7), label, font=_font(15), fill="#F1F7FC")
    fitted = _panel(image, (194, 94))
    sheet.paste(fitted, (x + 8, y + 32))
    fitted.close()


def export() -> Path:
    result = build()
    spec = json.loads(Path(result["spec"]).read_text(encoding="utf-8"))
    bank: dict[str, dict[str, Image.Image]] = {}
    for row in spec["templates"]:
        with Image.open(ROOT / row["path"]) as opened:
            bank.setdefault(row["roi"], {})[row["digit"]] = opened.convert("L")
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    suggestion = load_studio_suggestion(SUGGESTION)
    rois = {roi.name: roi for roi in suggestion.rois}
    student = next(
        row for row in report["legacy_agreement_rows"]
        if row["field"] == "student_level"
        and int(row["expected"]) == 90
        and "211446" in str(row["source_file"])
    )
    relationship = next(
        row for row in report["visual_ground_truth_rows"]
        if row["field"] == "relationship_rank" and int(row["expected"]) == 50
    )
    visual_rows = []
    for title, row, roi_name, expected, field, shift in (
        ("Student level 90 / first digit", student, "studentlevel_digit1", "9", "student_level", 0),
        ("Relationship rank 50 / second digit", relationship, "affectionlevel_digit2", "0", "relationship_rank", -2),
    ):
        with Image.open(_source(row["source_file"])) as opened:
            frame = opened.convert("RGBA")
        base_roi = extract_studio_roi(frame, rois[roi_name], reference_size=suggestion.reference_size)
        broad = _binary_mask(
            base_roi,
            (lambda pixel: min(pixel) >= 185 and max(pixel) - min(pixel) <= 85)
            if field == "student_level"
            else (lambda pixel: max(pixel) < 185 and max(pixel) - min(pixel) < 105),
        )
        legacy = _legacy_component(broad)
        refined_roi = extract_studio_roi(
            frame,
            replace(rois[roi_name], points=tuple((x + shift, y) for x, y in rois[roi_name].points)),
            reference_size=suggestion.reference_size,
        )
        refined, _stats = _source_digit_mask(refined_roi, field)
        legacy_pick = _rank(legacy, bank[roi_name])[0]
        refined_pick = _rank(refined, bank[roi_name])[0]
        visual_rows.append((
            title,
            f"expected {expected} / old {legacy_pick} / refined {refined_pick}",
            (base_roi, broad, legacy, refined_roi, refined, bank[roi_name][expected]),
        ))
        frame.close()
    sheet = Image.new("RGB", (1390, 390), "#14263A")
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 14), "Color-mask post-processing comparison", font=_font(28), fill="#F1F7FC")
    labels = ("Original ROI", "Color mask", "Old component", "Adjusted ROI", "Refined component", "Expected template")
    for index, (title, result_text, images) in enumerate(visual_rows):
        y = 62 + index * 160
        draw.text((24, y), title, font=_font(17), fill="#58E6FF")
        draw.text((930, y), result_text, font=_font(16), fill="#FFD166")
        for column, (image, label) in enumerate(zip(images, labels)):
            _paste(sheet, draw, image, 24 + column * 226, y + 24, label)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)
    sheet.close()
    for _title, _result, images in visual_rows:
        for image in images[:-1]:
            image.close()
    for templates in bank.values():
        for image in templates.values():
            image.close()
    return OUTPUT


if __name__ == "__main__":
    print(export())
