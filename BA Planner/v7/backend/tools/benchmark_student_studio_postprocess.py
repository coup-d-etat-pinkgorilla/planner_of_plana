from __future__ import annotations

from collections import Counter
from dataclasses import replace
import json
from pathlib import Path
from typing import Callable

from PIL import Image

from core.studio_roi_suggestion import extract_studio_roi, load_studio_suggestion
from tools.benchmark_student_studio_text_archive import (
    REPORT as ARCHIVE_REPORT,
    SCREENSHOTS,
    _rank,
)
from tools.build_student_studio_text_templates import (
    ROOT,
    SUGGESTION,
    _binary_mask,
    _components,
    build,
)


OUTPUT = ROOT / "debug" / "student_suggestion_rois" / "suggestion_text_postprocess_benchmark.json"


def _keep_largest_tall_component(mask: Image.Image) -> Image.Image:
    """Discard short dot fragments, then retain the largest digit-like component."""

    components = _components(mask)
    result = Image.new("L", mask.size)
    if not components:
        return result
    minimum_height = max(3, round(mask.height * 0.30))
    tall = [
        component
        for component in components
        if max(y for _x, y in component) - min(y for _x, y in component) + 1 >= minimum_height
    ]
    candidates = tall or components
    kept = max(candidates, key=len)
    pixels = result.load()
    for x, y in kept:
        pixels[x, y] = 255
    return result


def _student_current(pixel: tuple[int, int, int]) -> bool:
    return min(pixel) >= 185 and max(pixel) - min(pixel) <= 85


def _student_pale_blue(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    return red >= 165 and -6 <= green - red <= 32 and -6 <= blue - green <= 32


def _relationship_current(pixel: tuple[int, int, int]) -> bool:
    return max(pixel) < 185 and max(pixel) - min(pixel) < 105


def _relationship_navy(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    return red < 150 and 3 <= green - red <= 38 and 5 <= blue - green <= 45


def _near(pixel: tuple[int, int, int], target: tuple[int, int, int], radius: int) -> bool:
    return sum((value - expected) ** 2 for value, expected in zip(pixel, target)) <= radius ** 2


def _relationship_navy_distance_24(pixel: tuple[int, int, int]) -> bool:
    return _near(pixel, (54, 72, 94), 24)


def _relationship_navy_distance_36(pixel: tuple[int, int, int]) -> bool:
    return _near(pixel, (54, 72, 94), 36)


def _relationship_navy_distance_48(pixel: tuple[int, int, int]) -> bool:
    return _near(pixel, (54, 72, 94), 48)


MASKS: dict[str, tuple[str, Callable[[tuple[int, int, int]], bool]]] = {
    "student_current_largest_tall": ("student_level", _student_current),
    "student_pale_blue_largest_tall": ("student_level", _student_pale_blue),
    "relationship_current_largest_tall": ("relationship_rank", _relationship_current),
    "relationship_navy_largest_tall": ("relationship_rank", _relationship_navy),
    "relationship_navy_distance24": ("relationship_rank", _relationship_navy_distance_24),
    "relationship_navy_distance36": ("relationship_rank", _relationship_navy_distance_36),
    "relationship_navy_distance48": ("relationship_rank", _relationship_navy_distance_48),
}


def _shifted(roi, dx: int):
    return replace(roi, points=tuple((x + dx, y) for x, y in roi.points))


def _source_index(rows: list[dict]) -> dict[str, Path]:
    names = {str(row["source_file"]) for row in rows}
    result: dict[str, Path] = {}
    for path in SCREENSHOTS.rglob("*"):
        if path.is_file() and path.name in names:
            result.setdefault(path.name, path)
    missing = names - result.keys()
    if missing:
        raise ValueError(f"missing archive sources: {sorted(missing)}")
    return result


def benchmark() -> dict:
    build_result = build()
    build_spec = json.loads(Path(build_result["spec"]).read_text(encoding="utf-8"))
    suggestion = load_studio_suggestion(SUGGESTION)
    roi_lookup = {roi.name: roi for roi in suggestion.rois}
    bank: dict[str, dict[str, Image.Image]] = {}
    for template in build_spec["templates"]:
        roi_name = str(template["roi"])
        digit = str(template["digit"])
        with Image.open(ROOT / template["path"]) as opened:
            bank.setdefault(roi_name, {})[digit] = opened.convert("L")

    archive = json.loads(ARCHIVE_REPORT.read_text(encoding="utf-8"))
    rows = [
        row
        for row in archive["visual_ground_truth_rows"] + archive["legacy_agreement_rows"]
        if row["field"] in {"student_level", "relationship_rank"}
    ]
    sources = _source_index(rows)
    results: list[dict] = []
    for variant, (field, predicate) in MASKS.items():
        field_rows = [row for row in rows if row["field"] == field]
        for dx in (0, -1, -2):
            correct_values = 0
            digit_correct = 0
            digit_total = 0
            confusion: Counter[str] = Counter()
            samples: list[dict] = []
            for row in field_rows:
                with Image.open(sources[str(row["source_file"])]) as opened:
                    frame = opened.convert("RGBA")
                observed_digits: list[str] = []
                digit_rows: list[dict] = []
                try:
                    for expected_digit, digit in zip(str(row["expected"]), row["digits"]):
                        roi_name = str(digit["roi"])
                        source_roi = extract_studio_roi(
                            frame,
                            _shifted(roi_lookup[roi_name], dx),
                            reference_size=suggestion.reference_size,
                        )
                        raw = _binary_mask(source_roi, predicate)
                        source_mask = _keep_largest_tall_component(raw)
                        observed, score, margin, shift = _rank(source_mask, bank[roi_name])
                        source_roi.close()
                        raw.close()
                        source_mask.close()
                        observed_digits.append(observed)
                        digit_total += 1
                        if observed == expected_digit:
                            digit_correct += 1
                        else:
                            confusion[f"{expected_digit}->{observed}"] += 1
                        digit_rows.append({"expected": expected_digit, "observed": observed,
                                           "score": score, "margin": margin, "shift": shift})
                finally:
                    frame.close()
                observed_value = int("".join(observed_digits))
                correct = observed_value == int(row["expected"])
                correct_values += int(correct)
                if not correct and len(samples) < 12:
                    samples.append({
                        "source_file": row["source_file"],
                        "expected": row["expected"],
                        "observed": observed_value,
                        "digits": digit_rows,
                    })
            results.append({
                "variant": variant,
                "field": field,
                "reference_dx": dx,
                "values": len(field_rows),
                "value_correct": correct_values,
                "value_accuracy": correct_values / len(field_rows),
                "digits": digit_total,
                "digit_correct": digit_correct,
                "digit_accuracy": digit_correct / digit_total,
                "confusion": dict(confusion),
                "failure_samples": samples,
            })
    for templates in bank.values():
        for image in templates.values():
            image.close()
    payload = {"schema_version": 1, "results": results}
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return payload


def main() -> None:
    payload = benchmark()
    print(json.dumps([
        {key: row[key] for key in (
            "variant", "reference_dx", "value_correct", "values", "value_accuracy",
            "digit_correct", "digits", "digit_accuracy", "confusion",
        )}
        for row in payload["results"]
    ], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
