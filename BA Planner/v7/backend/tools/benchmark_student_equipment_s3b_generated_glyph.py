from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import re
from statistics import median
from time import perf_counter

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import GENERATED_BINARY_VARIANTS, StudentEquipmentRecognizer
from core.student_scan_recognizer import StudentBasicCropSet


BACKEND = Path(__file__).parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
ARCHIVE = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_archive"
PROMOTION = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_promotion_probe"
LIVE = BACKEND / "tests" / "fixtures" / "student_equipment_s3_dataset" / "live_1280x720"
OUTPUT = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_generated_glyph_benchmark.json"
METHODS = ("menu_binary", *(f"generated_{variant}" for variant in GENERATED_BINARY_VARIANTS))


def _candidate(note: str) -> int | None:
    match = re.search(r"(?:^|;)value=(\d+)(?:;|$)", note)
    return int(match.group(1)) if match else None


def _margin(note: str) -> float | None:
    match = re.search(r"(?:^|;)margin=([0-9.]+)(?:;|$)", note)
    return float(match.group(1)) if match else None


def _empty_stats() -> dict[str, object]:
    return {
        "top1_correct": 0,
        "accepted_correct": 0,
        "accepted_wrong": 0,
        "fallback": 0,
        "total": 0,
        "scores": [],
        "margins": [],
        "confusion": defaultdict(lambda: defaultdict(int)),
    }


def _record(stats: dict[str, object], expected: int, observation) -> None:
    candidate = _candidate(observation.note)
    margin = _margin(observation.note)
    stats["total"] += 1
    stats["top1_correct"] += int(candidate == expected)
    stats["accepted_correct"] += int(observation.value == expected)
    stats["accepted_wrong"] += int(observation.value is not None and observation.value != expected)
    stats["fallback"] += int(observation.value is None)
    if candidate is not None:
        stats["scores"].append(observation.confidence)
        if margin is not None:
            stats["margins"].append(margin)
        stats["confusion"][str(expected)][str(candidate)] += 1


def _observe(recognizer, method: str, crop, record, regions):
    slot = int(record["slot"])
    tier = str(record["tier"])
    if method == "menu_binary":
        return recognizer.read_binary_level(
            crop,
            slot=slot,
            tier=tier,
            region=regions[f"basic_equipment_{slot}_level_digits_quad"],
        )
    return recognizer.read_generated_binary_level(
        crop, slot=slot, tier=tier, variant=method.removeprefix("generated_"),
    )


def _evaluate_atlas(recognizer, fixture: Path, regions, stats_by_method) -> int:
    manifest = json.loads((fixture / "manifest.json").read_text(encoding="utf-8"))
    with Image.open(fixture / manifest["atlas"]["path"]) as atlas:
        for record in manifest["records"]:
            crop = atlas.crop(tuple(record["atlas_box"]))
            try:
                for method in METHODS:
                    _record(
                        stats_by_method[method],
                        int(record["expected_value"]),
                        _observe(recognizer, method, crop, record, regions),
                    )
            finally:
                crop.close()
    return int(manifest["reviewed_roi_count"])


def _evaluate_live(recognizer, regions, stats_by_method) -> int:
    total = 0
    roots = (LIVE / "student_detail", LIVE / "favorite_hibiki" / "student_detail")
    for root in roots:
        for index in range(1, 4):
            with Image.open(root / f"sample_{index:02d}.png") as frame:
                crops = StudentBasicCropSet.from_frame(frame.convert("RGB"), regions)
            try:
                for slot in (1, 2, 3):
                    record = {"slot": slot, "tier": "T10"}
                    crop = crops.images[f"basic_equipment_{slot}_level_digits_quad"]
                    for method in METHODS:
                        _record(
                            stats_by_method[method], 70,
                            _observe(recognizer, method, crop, record, regions),
                        )
                    total += 1
            finally:
                crops.close()
    return total


def _finalize(stats: dict[str, object]) -> dict[str, object]:
    scores = stats.pop("scores")
    margins = stats.pop("margins")
    confusion = stats.pop("confusion")
    return {
        **stats,
        "score_min": min(scores, default=0.0),
        "score_max": max(scores, default=0.0),
        "margin_min": min(margins, default=0.0),
        "margin_max": max(margins, default=0.0),
        "confusion": {expected: dict(predicted) for expected, predicted in confusion.items()},
    }


def main() -> None:
    started = perf_counter()
    catalog = RecognitionAssetCatalog(ASSETS)
    recognizer = StudentEquipmentRecognizer(catalog)
    startup_ms = (perf_counter() - started) * 1000.0
    initial_generated_prepare_ms = recognizer.metrics.generated_binary_template_prepare_ms
    initial_generated_count = recognizer.metrics.generated_binary_template_count
    initial_generated_bytes = recognizer.metrics.generated_binary_template_bytes
    regions = catalog.region("student")
    stats_by_method = {method: _empty_stats() for method in METHODS}
    try:
        archive_count = _evaluate_atlas(recognizer, ARCHIVE, regions, stats_by_method)
        promotion_count = _evaluate_atlas(recognizer, PROMOTION, regions, stats_by_method)
        live_count = _evaluate_live(recognizer, regions, stats_by_method)
        with Image.open(LIVE / "student_detail" / "sample_01.png") as frame:
            crops = StudentBasicCropSet.from_frame(frame.convert("RGB"), regions)
        warm_samples: list[float] = []
        try:
            for _index in range(25):
                warm_started = perf_counter()
                for slot in (1, 2, 3):
                    recognizer.read_generated_binary_level(
                        crops.images[f"basic_equipment_{slot}_level_digits_quad"],
                        slot=slot, tier="T10", variant="fill",
                    )
                warm_samples.append((perf_counter() - warm_started) * 1000.0)
        finally:
            crops.close()
        ordered = sorted(warm_samples)
        report = {
            "schema_version": 1,
            "mode": "shadow_only_generated_glyph_experiment",
            "production_enabled": False,
            "datasets": {
                "archive_2560x1440": archive_count,
                "promotion_probe_2560x1440": promotion_count,
                "live_1280x720": live_count,
                "combined_level_pairs": archive_count + promotion_count + live_count,
            },
            "methods": {method: _finalize(stats) for method, stats in stats_by_method.items()},
            "lead_shadow_candidate": "generated_fill",
            "selection_status": "benchmark_lead_not_production_selected",
            "selection_reason": (
                "highest separation on the frozen single/two-digit probe and no regression on the "
                "frozen replay; an independent calibration set is still required"
            ),
            "performance_ms": {
                "cold_start_menu_plus_fill_templates": startup_ms,
                "generated_fill_template_prepare": initial_generated_prepare_ms,
                "generated_all_variant_prepare_after_lazy_benchmark": recognizer.metrics.generated_binary_template_prepare_ms,
                "fill_three_slots_warm_p50": median(warm_samples),
                "fill_three_slots_warm_p95": ordered[max(0, round(len(ordered) * 0.95) - 1)],
            },
            "cache_and_memory": {
                "menu_binary_template_count": recognizer.metrics.binary_template_count,
                "menu_binary_template_bytes": recognizer.metrics.binary_template_bytes,
                "generated_fill_template_count": initial_generated_count,
                "generated_fill_template_bytes": initial_generated_bytes,
                "generated_all_variant_template_count_after_lazy_benchmark": recognizer.metrics.generated_binary_template_count,
                "generated_all_variant_template_bytes_after_lazy_benchmark": recognizer.metrics.generated_binary_template_bytes,
                "full_size_reference_canvases": recognizer.metrics.full_size_reference_canvases,
            },
            "remaining_master_gates": [
                "pass independent non-Lv70 1275x720 client-area validation; current Lv65 is accepted as 6",
                "resolve the Kurumi T2 slot-3 tier gate miss on end-to-end replay",
                "fallback/menu-call reduction after runtime shadow integration",
                "production threshold calibration on a set separate from frozen validation",
                "reduce and remeasure generated fill cold preparation cost",
                "explicit master acceptance",
            ],
        }
        OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(OUTPUT)
    finally:
        recognizer.close()


if __name__ == "__main__":
    main()
