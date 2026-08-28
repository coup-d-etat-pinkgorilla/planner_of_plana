from __future__ import annotations

from hashlib import sha256
import json
from pathlib import Path
from statistics import mean
from typing import Any

from PIL import Image

from core.studio_roi_suggestion import extract_studio_roi, load_studio_suggestion
from tools.benchmark_student_studio_text_archive import SCREENSHOTS, _rank
from tools.build_student_studio_text_templates import (
    DEBUG,
    ROOT,
    SUGGESTION,
    _source_digit_mask,
    build,
)


SOURCE_SPEC = ROOT / "backend" / "tests" / "fixtures" / "student_level_studio_archive_source_spec.json"
REPORT = DEBUG / "student_level_reviewed_benchmark.json"


def _source(record: dict[str, Any]) -> Path:
    matches = [
        path for path in SCREENSHOTS.rglob(str(record["source_file"]))
        if sha256(path.read_bytes()).hexdigest() == record["source_sha256"]
    ]
    if len(matches) != 1:
        raise ValueError(f"expected one hash-matched source for {record['source_file']}, got {len(matches)}")
    return matches[0]


def benchmark() -> dict[str, Any]:
    source_spec = json.loads(SOURCE_SPEC.read_text(encoding="utf-8"))
    suggestion = load_studio_suggestion(SUGGESTION)
    roi_lookup = {roi.name: roi for roi in suggestion.rois}
    built = build()
    renderer = json.loads(Path(built["spec"]).read_text(encoding="utf-8"))
    bank: dict[str, dict[str, Image.Image]] = {}
    for template in renderer["templates"]:
        roi_name = str(template["roi"])
        if not roi_name.startswith("studentlevel_"):
            continue
        with Image.open(ROOT / template["path"]) as opened:
            bank.setdefault(roi_name, {})[str(template["digit"])] = opened.convert("L")
    rows: list[dict[str, Any]] = []
    try:
        for record in source_spec["records"]:
            expected = str(record["student_level"])
            with Image.open(_source(record)) as opened:
                frame = opened.convert("RGBA")
            digits: list[dict[str, Any]] = []
            try:
                for position, expected_digit in enumerate(expected, start=1):
                    roi_name = f"studentlevel_digit{position}"
                    digit_roi = extract_studio_roi(
                        frame, roi_lookup[roi_name], reference_size=suggestion.reference_size,
                    )
                    mask, cleanup = _source_digit_mask(digit_roi, "student_level")
                    observed, score, margin, shift = _rank(mask, bank[roi_name])
                    digit_roi.close()
                    mask.close()
                    digits.append({
                        "position": position,
                        "roi": roi_name,
                        "expected": expected_digit,
                        "observed": observed,
                        "correct": observed == expected_digit,
                        "score": score,
                        "margin": margin,
                        "shift": shift,
                        "cleanup": cleanup,
                    })
                blank_second = None
                if len(expected) == 1:
                    roi_name = "studentlevel_digit2"
                    blank_roi = extract_studio_roi(
                        frame, roi_lookup[roi_name], reference_size=suggestion.reference_size,
                    )
                    blank_mask, cleanup = _source_digit_mask(blank_roi, "student_level")
                    blank_second = {
                        "roi": roi_name,
                        "blank": blank_mask.getbbox() is None,
                        "cleanup": cleanup,
                    }
                    blank_roi.close()
                    blank_mask.close()
            finally:
                frame.close()
            observed_value = int("".join(digit["observed"] for digit in digits))
            rows.append({
                "field": "student_level",
                "source_file": record["source_file"],
                "source_sha256": record["source_sha256"],
                "expected": int(expected),
                "observed": observed_value,
                "correct": observed_value == int(expected),
                "evidence": "visual_ground_truth",
                "digits": digits,
                "single_digit_second_cell": blank_second,
            })
    finally:
        for templates in bank.values():
            for image in templates.values():
                image.close()
    digit_rows = [digit for row in rows for digit in row["digits"]]
    payload = {
        "schema_version": 1,
        "method": "reviewed BA level series + Studio position ROI + pale color mask + white synthetic template",
        "values": len(rows),
        "value_correct": sum(row["correct"] for row in rows),
        "digits": len(digit_rows),
        "digit_correct": sum(digit["correct"] for digit in digit_rows),
        "minimum_score": min(digit["score"] for digit in digit_rows),
        "average_score": mean(digit["score"] for digit in digit_rows),
        "minimum_margin": min(digit["margin"] for digit in digit_rows),
        "average_margin": mean(digit["margin"] for digit in digit_rows),
        "single_digit_blank_correct": sum(
            row["single_digit_second_cell"] is not None
            and row["single_digit_second_cell"]["blank"]
            for row in rows
        ),
        "coverage": {
            "values": [row["expected"] for row in rows],
            "position_1_digits": sorted({str(row["expected"])[0] for row in rows}),
            "position_2_digits": sorted({str(row["expected"])[1] for row in rows if row["expected"] >= 10}),
        },
        "rows": rows,
    }
    REPORT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return payload


if __name__ == "__main__":
    result = benchmark()
    print(json.dumps({key: result[key] for key in (
        "values", "value_correct", "digits", "digit_correct", "minimum_score",
        "minimum_margin", "single_digit_blank_correct", "coverage",
    )}, ensure_ascii=False, indent=2))
