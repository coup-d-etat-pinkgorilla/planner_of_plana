from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
from statistics import median
from time import perf_counter
import tracemalloc

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import StudentEquipmentRecognizer
from core.student_scan_recognizer import StudentBasicCropSet


BACKEND = Path(__file__).resolve().parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
FIXTURE = BACKEND / "tests" / "fixtures" / "student_scan_s2_serika_new_year.png"
V6_BASELINE = BACKEND / "tests" / "fixtures" / "student_equipment_s3_v6_baseline.json"
LIVE_MASTER = BACKEND / "tests" / "fixtures" / "student_equipment_s3_live_master.json"


def _percentile(values: list[float], percentile: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, round((len(ordered) - 1) * percentile)))
    return ordered[index]


def _asset_bytes() -> int:
    manifest = json.loads((ASSETS / "student_equipment_manifest.json").read_text(encoding="utf-8"))
    return sum(int(item["bytes"]) for item in manifest["assets"])


def benchmark() -> dict[str, object]:
    v6_baseline = json.loads(V6_BASELINE.read_text(encoding="utf-8"))
    live_master = json.loads(LIVE_MASTER.read_text(encoding="utf-8"))
    start = perf_counter()
    catalog = RecognitionAssetCatalog(ASSETS)
    catalog.verify()
    recognizer = StudentEquipmentRecognizer(catalog)
    startup_ms = (perf_counter() - start) * 1000.0
    regions = catalog.region("student")
    region = regions["basic_equipment_1_level_digits_quad"]

    with Image.open(FIXTURE) as frame:
        crops = StudentBasicCropSet.from_frame(frame, regions)
    actual_started = perf_counter()
    actual, actual_unresolved = recognizer.recognize(
        crops, student_ref="serika_new_year", student_level=12,
    )
    actual_ms = (perf_counter() - actual_started) * 1000.0
    actual_answers = {"equip1": "empty", "equip2": "empty", "equip3": "level_locked"}
    actual_predicted = {field: actual[field].value for field in actual_answers}
    crops.close()

    crop = recognizer._generated_level_crop(1, "Shoes", "T10", 70, region, (2560, 1440))
    cold_started = perf_counter()
    cold = recognizer.read_generated_level(
        crop, slot=1, family="Shoes", tier="T10", region=region,
        source_size=(2560, 1440),
    )
    cold_ms = (perf_counter() - cold_started) * 1000.0
    warm_times: list[float] = []
    warm_values: list[int | None] = []
    for _index in range(20):
        warm_started = perf_counter()
        result = recognizer.read_generated_level(
            crop, slot=1, family="Shoes", tier="T10", region=region,
            source_size=(2560, 1440),
        )
        warm_times.append((perf_counter() - warm_started) * 1000.0)
        warm_values.append(result.value if isinstance(result.value, int) else None)
    crop.close()

    answer_levels = (1, 9, 10, 20, 30, 40, 45, 50, 55, 60, 65, 70)
    confusion: Counter[tuple[str, str]] = Counter()
    digit_confusion: Counter[tuple[str, str]] = Counter()
    tier_confusion: Counter[tuple[str, str]] = Counter()
    fallback_count = 0
    for expected in answer_levels:
        sample = recognizer._generated_level_crop(1, "Shoes", "T10", expected, region, (2560, 1440))
        observed = recognizer.read_generated_level(
            sample, slot=1, family="Shoes", tier="T10", region=region,
            source_size=(2560, 1440),
        )
        sample.close()
        predicted = str(observed.value) if observed.value is not None else "fallback"
        fallback_count += int(observed.value is None)
        confusion[(str(expected), predicted)] += 1
        expected_cells = list(str(expected)) if expected >= 10 else [str(expected), "blank"]
        predicted_cells = (
            list(predicted) if predicted != "fallback" and int(predicted) >= 10
            else [predicted, "blank"]
        )
        for expected_digit, predicted_digit in zip(expected_cells, predicted_cells):
            digit_confusion[(expected_digit, predicted_digit)] += 1

    icon_region = regions["basic_equipment_1_icon_region"]
    for number in range(1, 11):
        expected_tier = f"T{number}"
        card = recognizer._base_card("Shoes", expected_tier).copy().convert("RGB")
        tier_result = recognizer.read_tier(card, "Shoes", icon_region)
        card.close()
        tier_confusion[(expected_tier, str(tier_result.value or "fallback"))] += 1

    shifted = recognizer._generated_level_crop(1, "Shoes", "T10", 70, region, (2560, 1440))
    shifted_canvas = Image.new("RGB", shifted.size)
    shifted_canvas.paste(shifted, (1, 0))
    shifted_result = recognizer.read_generated_level(
        shifted_canvas, slot=1, family="Shoes", tier="T10", region=region,
        source_size=(2560, 1440),
    )
    shifted.close()
    shifted_canvas.close()
    metrics = recognizer.metrics.to_dict()
    recognizer.close()
    tracemalloc.start()
    memory_recognizer = StudentEquipmentRecognizer(catalog)
    memory_crop = memory_recognizer._generated_level_crop(
        1, "Shoes", "T10", 70, region, (2560, 1440),
    )
    memory_recognizer.read_generated_level(
        memory_crop, slot=1, family="Shoes", tier="T10", region=region,
        source_size=(2560, 1440),
    )
    _current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    memory_crop.close()
    memory_recognizer.close()
    synthetic_correct = sum(count for (expected, predicted), count in confusion.items() if expected == predicted)
    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "fixture": str(FIXTURE.relative_to(BACKEND.parent)).replace("\\", "/"),
        "environment": {
            "python": "3.11",
            "matcher": "pure Pillow prepared RGB/gray/edge; dark-ink glyph retained",
            "source_size": [2560, 1440],
            "cache_limit": 384,
        },
        "v6_offline_baseline": {
            "status": "reproduced_in_isolated_dependency_complete_environment",
            "fixture": str(V6_BASELINE.relative_to(BACKEND.parent)).replace("\\", "/"),
            **v6_baseline,
        },
        "v7_timing_ms": {
            "cold_start_and_template_load": round(startup_ms, 6),
            "actual_fast_path_first": round(actual_ms, 6),
            "t10_small_roi_cold": round(cold_ms, 6),
            "t10_small_roi_warm_p50": round(median(warm_times), 6),
            "t10_small_roi_warm_p95": round(_percentile(warm_times, 0.95), 6),
            "t10_small_roi_warm_samples": [round(value, 6) for value in warm_times],
            "template_load_counter": round(float(metrics["template_load_ms"]), 6),
            "feature_prepare_counter": round(float(metrics["feature_prepare_ms"]), 6),
        },
        "answers": {
            "real_master": live_master,
            "actual_fixture": {
                "expected": actual_answers,
                "predicted": actual_predicted,
                "correct": actual_answers == actual_predicted,
                "unresolved_slots": list(actual_unresolved),
            },
            "synthetic_same-generator": {
                "sample_count": len(answer_levels),
                "correct": synthetic_correct,
                "misread": len(answer_levels) - synthetic_correct - fallback_count,
                "fallback": fallback_count,
                "accuracy": synthetic_correct / len(answer_levels),
                "confusion": [
                    {"expected": expected, "predicted": predicted, "count": count}
                    for (expected, predicted), count in sorted(confusion.items())
                ],
                "digit_confusion": [
                    {"expected": expected, "predicted": predicted, "count": count}
                    for (expected, predicted), count in sorted(digit_confusion.items())
                ],
                "tier_confusion": [
                    {"expected": expected, "predicted": predicted, "count": count}
                    for (expected, predicted), count in sorted(tier_confusion.items())
                ],
                "slot_confusion": [
                    {"slot": field, "expected": expected, "predicted": actual_predicted[field]}
                    for field, expected in actual_answers.items()
                ],
                "one_pixel_shift_expected": 70,
                "one_pixel_shift_predicted": shifted_result.value,
            },
        },
        "boundary_validation": {
            "tiers_checked": list(range(1, 11)),
            "level_answers_checked": list(answer_levels),
            "single_digit_blank_checked": True,
            "invalid_tier_level_rejection": "covered by tests.test_student_equipment_s3",
            "empty_locked_unknown_favorite_locked": "covered by real fixture and tests.test_student_equipment_s3",
        },
        "cache_and_memory": {
            **metrics,
            "tracemalloc_peak_bytes": peak,
            "installed_asset_increase_bytes": _asset_bytes(),
        },
        "method_comparison": [
            {
                "method": "v6 generated RGB offline",
                "status": "measured",
                "accuracy": 1.0 if v6_baseline["result"]["correct"] else 0.0,
                "cold_ms": v6_baseline["result"]["cold_ms"],
                "warm_p50_ms": v6_baseline["result"]["warm_p50_ms"],
            },
            {
                "method": "prepared RGB/gray/edge bundle",
                "status": "measured",
                "accuracy": synthetic_correct / len(answer_levels),
            },
            {
                "method": "empirical navy/dark-ink glyph",
                "status": "MASTER_REQUIRED",
                "accuracy": None,
                "reason": "one accepted real screen has no equipped level glyph and cannot establish thresholds/confusion pairs",
            },
            {
                "method": "empirical-first plus small ROI fallback",
                "status": "partially_measured",
                "accuracy": synthetic_correct / len(answer_levels),
                "reason": "fast empty/locked answer is real; level fallback answer set is same-generator synthetic",
            },
        ],
        "storage_decision": {
            "selected": "bounded in-memory prepared features generated from one packaged font/background and existing equipment icons",
            "individual_cell_pngs": "rejected_without_4005/8010-file deployment",
            "npz": "not selected because numpy is not a v7 backend dependency",
            "atlas": "deferred until empirical dataset coverage exists",
        },
        "master_required": [
        ],
        "future_calibration_coverage": live_master["remaining_coverage"],
        "v6_to_v7_timing_ratio": {
            "cold_speedup": round(float(v6_baseline["result"]["cold_ms"]) / cold_ms, 6),
            "warm_p50_speedup": round(
                float(v6_baseline["result"]["warm_p50_ms"]) / median(warm_times), 6
            ),
        },
        "cold_warm_identical": cold.value == 70 and all(value == 70 for value in warm_values),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = benchmark()
    content = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output is None:
        print(content, end="")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
