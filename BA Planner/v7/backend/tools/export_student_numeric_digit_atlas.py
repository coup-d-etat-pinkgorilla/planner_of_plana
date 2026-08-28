from __future__ import annotations

from collections import Counter, defaultdict
from hashlib import sha256
import json
from math import ceil
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageOps

from core.studio_roi_suggestion import extract_studio_roi, load_studio_suggestion
from tools.benchmark_student_studio_text_archive import REPORT, SCREENSHOTS
from tools.benchmark_student_level_studio_archive import REPORT as STUDENT_LEVEL_REPORT
from tools.build_student_studio_text_templates import (
    DEBUG,
    ROOT,
    SUGGESTION,
    _font,
    _source_digit_mask,
    build,
)


OUTPUT = DEBUG / "digit_atlas"
SUMMARY = OUTPUT / "digit_atlas_summary.json"
CARD_WIDTH = 480
CARD_HEIGHT = 154
CARDS_PER_ROW = 3


def _source_index(names: set[str]) -> dict[str, Path]:
    result: dict[str, Path] = {}
    for path in SCREENSHOTS.rglob("*"):
        if path.is_file() and path.name in names:
            result.setdefault(path.name, path)
    missing = names - result.keys()
    if missing:
        raise ValueError(f"missing screenshot sources: {sorted(missing)}")
    return result


def _load_bank() -> dict[str, dict[str, Image.Image]]:
    built = build()
    spec = json.loads(Path(built["spec"]).read_text(encoding="utf-8"))
    bank: dict[str, dict[str, Image.Image]] = defaultdict(dict)
    for row in spec["templates"]:
        with Image.open(ROOT / row["path"]) as opened:
            bank[str(row["roi"])][str(row["digit"])] = opened.convert("L")
    return dict(bank)


def _display(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    background = Image.new("RGB", image.size, "#091725")
    if image.mode == "L":
        background.paste("#FFFFFF", mask=image)
    else:
        rgba = image.convert("RGBA")
        background.paste(rgba.convert("RGB"), mask=rgba.getchannel("A"))
        rgba.close()
    result = Image.new("RGB", size, "#20364B")
    fitted = ImageOps.contain(background, size, Image.Resampling.NEAREST)
    result.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    fitted.close()
    background.close()
    return result


def _draw_card(
    sheet: Image.Image,
    draw: ImageDraw.ImageDraw,
    sample: dict[str, Any],
    x: int,
    y: int,
) -> None:
    draw.rounded_rectangle(
        (x, y, x + CARD_WIDTH - 10, y + CARD_HEIGHT - 8),
        radius=9,
        fill="#20364B",
        outline="#5D7891" if sample["correct"] else "#FF7084",
        width=2 if not sample["correct"] else 1,
    )
    filename = str(sample["source_file"])
    if len(filename) > 32:
        filename = filename[:29] + "..."
    draw.text((x + 10, y + 7), filename, font=_font(13), fill="#DDEAF4")
    result_color = "#64E6B1" if sample["correct"] else "#FF7084"
    draw.text(
        (x + 10, y + 28),
        f"expected {sample['expected']} / observed {sample['observed']}  "
        f"shift {tuple(sample['shift'])}  n={sample['occurrences']}",
        font=_font(13),
        fill=result_color,
    )
    labels = ("Digit ROI", "Color mask", "Expected template", "Selected template")
    for column, (image, label) in enumerate(zip(sample["images"], labels)):
        panel_x = x + 10 + column * 113
        draw.text((panel_x, y + 51), label, font=_font(11), fill="#AFC3D5")
        panel = _display(image, (102, 72))
        sheet.paste(panel, (panel_x, y + 70))
        panel.close()


def _render_page(
    *,
    field: str,
    position: int | None,
    groups: dict[str, list[dict[str, Any]]],
    path: Path,
    note: str,
) -> None:
    group_heights = {
        digit: 54 + ceil(len(samples) / CARDS_PER_ROW) * CARD_HEIGHT
        for digit, samples in groups.items()
    }
    width = 32 + CARDS_PER_ROW * CARD_WIDTH
    height = 112 + sum(group_heights.values())
    sheet = Image.new("RGB", (width, height), "#14263A")
    draw = ImageDraw.Draw(sheet)
    position_text = "all positions" if position is None else f"position {position}"
    draw.text((24, 14), f"{field} digit atlas - {position_text}", font=_font(28), fill="#F1F7FC")
    draw.text(
        (24, 52),
        "Digit ROI  ->  field color mask  ->  expected template  ->  matcher-selected template",
        font=_font(16),
        fill="#58E6FF",
    )
    draw.text((24, 78), note, font=_font(13), fill="#AFC3D5")
    y = 110
    for digit, samples in sorted(groups.items()):
        observed = Counter(str(sample["observed"]) for sample in samples for _ in range(sample["occurrences"]))
        shifts = Counter(tuple(sample["shift"]) for sample in samples for _ in range(sample["occurrences"]))
        total = sum(sample["occurrences"] for sample in samples)
        correct = sum(sample["occurrences"] for sample in samples if sample["correct"])
        draw.text(
            (24, y + 4),
            f"expected digit {digit} | {correct}/{total} correct | observed {dict(observed)} | shifts {dict(shifts)}",
            font=_font(16),
            fill="#FFD166",
        )
        y += 42
        for index, sample in enumerate(samples):
            row, column = divmod(index, CARDS_PER_ROW)
            _draw_card(sheet, draw, sample, 24 + column * CARD_WIDTH, y + row * CARD_HEIGHT)
        y += ceil(len(samples) / CARDS_PER_ROW) * CARD_HEIGHT + 12
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    sheet.close()


def export() -> dict[str, Any]:
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    suggestion = load_studio_suggestion(SUGGESTION)
    roi_lookup = {roi.name: roi for roi in suggestion.rois}
    relationship_rows = [
        row for row in report["visual_ground_truth_rows"] if row["field"] == "relationship_rank"
    ]
    reviewed_student = json.loads(STUDENT_LEVEL_REPORT.read_text(encoding="utf-8"))
    student_rows = reviewed_student["rows"]
    source_paths = _source_index(
        {str(row["source_file"]) for row in relationship_rows + student_rows}
    )
    bank = _load_bank()
    relationship_collected = {
        digit_count: {
            position: defaultdict(list)
            for position in range(1, digit_count + 1)
        }
        for digit_count in (1, 2, 3)
    }
    student_collected = {1: defaultdict(list), 2: defaultdict(list)}
    summary: dict[str, Any] = {"schema_version": 1, "fields": {}}
    for field, rows in (("relationship_rank", relationship_rows), ("student_level", student_rows)):
        deduplicated: dict[tuple[int, str, str], dict[str, Any]] = {}
        for row in rows:
            with Image.open(source_paths[str(row["source_file"])]) as opened:
                frame = opened.convert("RGBA")
            try:
                for position, digit_row in enumerate(row["digits"], start=1):
                    roi_name = str(digit_row["roi"])
                    roi = roi_lookup[roi_name]
                    digit_roi = extract_studio_roi(frame, roi, reference_size=suggestion.reference_size)
                    color_mask, _stats = _source_digit_mask(digit_roi, field)
                    expected = str(digit_row["expected"])
                    mask_hash = sha256(color_mask.tobytes()).hexdigest()
                    key = (position, expected, mask_hash)
                    sample = {
                        "source_file": row["source_file"],
                        "expected": expected,
                        "observed": str(digit_row["observed"]),
                        "correct": bool(digit_row["correct"]),
                        "score": float(digit_row["score"]),
                        "margin": float(digit_row["margin"]),
                        "shift": list(digit_row["shift"]),
                        "occurrences": 1,
                        "mask_sha256": mask_hash,
                        "images": (
                            digit_roi,
                            color_mask,
                            bank[roi_name][expected],
                            bank[roi_name][str(digit_row["observed"])],
                        ),
                    }
                    if field == "student_level" and key in deduplicated:
                        deduplicated[key]["occurrences"] += 1
                        digit_roi.close()
                        color_mask.close()
                    else:
                        deduplicated[key] = sample
                        if field == "relationship_rank":
                            layout = int(row.get("layout_digit_count", len(row["digits"])))
                            relationship_collected[layout][position][expected].append(sample)
                        else:
                            student_collected[position][expected].append(sample)
            finally:
                frame.close()
        def summarize_positions(position_groups):
            return {
                str(position): {
                    digit: {
                        "samples": sum(sample["occurrences"] for sample in samples),
                        "displayed_variants": len(samples),
                        "correct": sum(sample["occurrences"] for sample in samples if sample["correct"]),
                        "observed": dict(Counter(
                            sample["observed"]
                            for sample in samples
                            for _ in range(sample["occurrences"])
                        )),
                        "best_shifts": {
                            str(shift): count
                            for shift, count in Counter(
                                tuple(sample["shift"])
                                for sample in samples
                                for _ in range(sample["occurrences"])
                            ).items()
                        },
                    }
                    for digit, samples in sorted(groups.items())
                }
                for position, groups in position_groups.items()
            }

        if field == "relationship_rank":
            field_summary = {
                "layouts": {
                    str(layout): summarize_positions(positions)
                    for layout, positions in relationship_collected.items()
                }
            }
        else:
            field_summary = summarize_positions(student_collected)
        summary["fields"][field] = field_summary

    paths = []
    for layout, positions in relationship_collected.items():
        for position, groups in positions.items():
            filename = (
                f"relationship_rank_position{position}.png"
                if layout == 2
                else f"relationship_rank_{layout}digit_position{position}.png"
            )
            path = OUTPUT / filename
            _render_page(
                field=f"relationship_rank ({layout}-digit layout)",
                position=position,
                groups=groups,
                path=path,
                note=f"All available visually verified {layout}-digit samples are shown. Red cards are mismatches.",
            )
            paths.append(path)
    student_groups = {
        f"P{position} available digits": [
            sample
            for digit in sorted(groups)
            for sample in groups[digit]
        ]
        for position, groups in student_collected.items()
    }
    student_path = OUTPUT / "student_level_all_positions.png"
    _render_page(
        field="student_level",
        position=None,
        groups=student_groups,
        path=student_path,
        note="Visually reviewed levels 1/12/23/34/45/56/67/78/89/90; each available digit-position case is shown.",
    )
    paths.append(student_path)
    summary["images"] = [path.relative_to(ROOT).as_posix() for path in paths]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    all_position_groups = [
        *student_collected.values(),
        *(
            groups
            for positions in relationship_collected.values()
            for groups in positions.values()
        ),
    ]
    for groups in all_position_groups:
        for samples in groups.values():
            for sample in samples:
                sample["images"][0].close()
                sample["images"][1].close()
    for templates in bank.values():
        for image in templates.values():
            image.close()
    return summary


if __name__ == "__main__":
    print(json.dumps(export(), ensure_ascii=False, indent=2))
