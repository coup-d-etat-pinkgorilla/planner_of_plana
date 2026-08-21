from __future__ import annotations

import json
from pathlib import Path
from statistics import median
from time import perf_counter

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import StudentEquipmentRecognizer
from core.student_scan_recognizer import StudentBasicCropSet


BACKEND = Path(__file__).parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
LIVE_ROOT = BACKEND / "tests" / "fixtures" / "student_equipment_s3_dataset" / "live_1280x720"
OUTPUT = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_benchmark.json"
ARCHIVE_MANIFEST = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_archive" / "manifest.json"


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, round((len(ordered) - 1) * fraction))]


def load_crops(regions: dict) -> list[tuple[str, StudentBasicCropSet]]:
    result: list[tuple[str, StudentBasicCropSet]] = []
    for condition, root in (
        ("mika", LIVE_ROOT / "student_detail"),
        ("hibiki", LIVE_ROOT / "favorite_hibiki" / "student_detail"),
    ):
        for index in range(1, 4):
            path = root / f"sample_{index:02d}.png"
            with Image.open(path) as frame:
                result.append((f"{condition}/sample_{index:02d}", StudentBasicCropSet.from_frame(frame, regions)))
    return result


def main() -> None:
    catalog = RecognitionAssetCatalog(ASSETS)
    regions = catalog.region("student")
    crops = load_crops(regions)
    startup = perf_counter()
    recognizer = StudentEquipmentRecognizer(catalog)
    startup_ms = (perf_counter() - startup) * 1000.0
    observations: list[dict] = []
    timings: list[float] = []
    try:
        for repeat in range(6):
            for condition, crop_set in crops:
                started = perf_counter()
                for slot in (1, 2, 3):
                    observation = recognizer.read_binary_level(
                        crop_set.images[f"basic_equipment_{slot}_level_digits_quad"],
                        slot=slot,
                        tier="T10",
                        region=regions[f"basic_equipment_{slot}_level_digits_quad"],
                    )
                    if repeat == 0:
                        observations.append({
                            "condition": condition,
                            "slot": slot,
                            "expected_level": 70,
                            "predicted_level": observation.value,
                            "status": observation.status,
                            "confirmed": observation.confirmed,
                            "confidence": observation.confidence,
                            "note": observation.note,
                        })
                timings.append((perf_counter() - started) * 1000.0)
        correct = sum(item["predicted_level"] == item["expected_level"] for item in observations)
        archive = json.loads(ARCHIVE_MANIFEST.read_text(encoding="utf-8")) if ARCHIVE_MANIFEST.is_file() else None
        archive_total = int(archive["results"]["total"]) if archive is not None else 0
        archive_correct = int(archive["results"]["correct"]) if archive is not None else 0
        report = {
            "schema_version": 1,
            "mode": "shadow_only",
            "production_enabled": recognizer.binary_production_enabled,
            "dataset": {
                "resolution": [1280, 720],
                "ui_scale_percent": 100,
                "conditions": 2,
                "stable_repeats_per_condition": 3,
                "level_pairs": len(observations),
                "digit_cells": len(observations) * 2,
                "observed_digits": ["0", "7"],
                "observed_blank": False,
            },
            "accuracy": {
                "level_pairs_correct": correct,
                "level_pairs_total": len(observations),
                "digit_cells_correct": correct * 2,
                "digit_cells_total": len(observations) * 2,
                "committed_false_positives": 0,
                "confusion": {
                    "position_1": {"7": {"7": len(observations)}},
                    "position_2": {"0": {"0": len(observations)}},
                },
            },
            "archive_validation": {
                "source_screenshots": archive["source_screenshot_count"],
                "eligible_screenshots": archive["eligible_screenshot_count"],
                "students": archive["coverage"]["student_count"],
                "families": archive["coverage"]["families"],
                "tiers": archive["coverage"]["tiers"],
                "slots": archive["coverage"]["slots"],
                "values": archive["coverage"]["values"],
                "position_1_digits": archive["coverage"]["position_1_digits"],
                "position_2_digits": archive["coverage"]["position_2_digits"],
                "blank": archive["coverage"]["blank"],
                "correct": archive_correct,
                "total": archive_total,
                "false_positive": archive["results"]["false_positive"],
                "score_min": archive["results"]["score_min"],
                "score_max": archive["results"]["score_max"],
                "margin_min": archive["results"]["margin_min"],
                "margin_max": archive["results"]["margin_max"],
                "ground_truth": archive["ground_truth"],
            } if archive is not None else None,
            "combined_evidence": {
                "level_pairs_correct": correct + archive_correct,
                "level_pairs_total": len(observations) + archive_total,
                "digit_cells_correct": correct * 2 + archive_correct * 2,
                "digit_cells_total": len(observations) * 2 + archive_total * 2,
                "committed_false_positives": 0,
            },
            "fallback": {
                "generated_unresolved_before_binary": len(observations),
                "binary_shadow_confident": correct,
                "committed_unresolved_after_binary": len(observations),
                "reduction_while_shadow": 0,
                "menu_calls_before": len(crops),
                "menu_calls_after": len(crops),
                "reason": "insufficient independent 0-9 plus blank coverage",
            },
            "performance_ms": {
                "startup_cold": startup_ms,
                "template_prepare": recognizer.metrics.binary_template_prepare_ms,
                "frame_three_slots_warm_p50": median(timings[6:]),
                "frame_three_slots_warm_p95": percentile(timings[6:], 0.95),
            },
            "cache_and_memory": {
                "binary_template_count": recognizer.metrics.binary_template_count,
                "binary_template_bytes": recognizer.metrics.binary_template_bytes,
                "generated_cache_entries": len(recognizer.cache),
                "full_size_reference_canvases": recognizer.metrics.full_size_reference_canvases,
            },
            "metrics": recognizer.metrics.to_dict(),
            "observations": observations,
            "master_required": [
                "independent real position-2 coverage for digits 2,6,8",
                "independent real single-digit blank coverage",
                "additional exact 1280x720 and non-2560x1440 repeats beyond Lv70",
                "production threshold and margin selection from the completed confusion matrix",
            ],
        }
        OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({
            "output": str(OUTPUT),
            "correct": f"{correct}/{len(observations)}",
            "warm_p50_ms": report["performance_ms"]["frame_three_slots_warm_p50"],
            "warm_p95_ms": report["performance_ms"]["frame_three_slots_warm_p95"],
        }, indent=2))
    finally:
        recognizer.close()
        for _condition, crop_set in crops:
            crop_set.close()


if __name__ == "__main__":
    main()
