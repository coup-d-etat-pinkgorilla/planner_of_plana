from __future__ import annotations

import json
from pathlib import Path
from statistics import median
from time import perf_counter

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import (
    PreparedFeature, StudentEquipmentRecognizer, _feature_similarity,
    _mean_difference, _normalized_correlation,
)
from core.student_scan_recognizer import StudentBasicCropSet


BACKEND = Path(__file__).parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
FIXTURE = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_direct_tier"
SPEC = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_direct_tier_spec.json"
OUTPUT = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_direct_tier_benchmark.json"


def score(left: Image.Image, right: Image.Image) -> float:
    return 0.85 * _normalized_correlation(left.convert("L"), right.convert("L")) + 0.15 * _mean_difference(left, right)


def rank(crop: Image.Image, templates: dict[str, Image.Image]) -> tuple[str, float, float]:
    ranked = sorted(((tier, score(crop, template)) for tier, template in templates.items()), key=lambda item: item[1], reverse=True)
    return ranked[0][0], ranked[0][1], ranked[0][1] - ranked[1][1]


def rank_mean(crop: Image.Image, templates: dict[str, Image.Image]) -> tuple[str, float, float]:
    ranked = sorted(((tier, _mean_difference(crop, template)) for tier, template in templates.items()), key=lambda item: item[1], reverse=True)
    return ranked[0][0], ranked[0][1], ranked[0][1] - ranked[1][1]


def rank_feature(crop: Image.Image, templates: dict[str, PreparedFeature]) -> tuple[str, float, float]:
    screen = PreparedFeature.from_image(crop)
    try:
        ranked = sorted(((tier, _feature_similarity(screen, template)) for tier, template in templates.items()), key=lambda item: item[1], reverse=True)
        return ranked[0][0], ranked[0][1], ranked[0][1] - ranked[1][1]
    finally:
        screen.close()


def percentile(values: list[float], ratio: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, round((len(ordered) - 1) * ratio))]


def main() -> None:
    manifest = json.loads((FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    with Image.open(FIXTURE / manifest["atlas"]["path"]) as source:
        atlas = source.convert("RGB")
    templates: dict[str, dict[str, Image.Image]] = {family: {} for family in spec["families"]}
    validation: list[tuple[Image.Image, dict[str, object]]] = []
    for record in manifest["records"]:
        crop = atlas.crop(tuple(record["atlas_box"]))
        if record["split"] == "template":
            templates[record["family"]][record["tier"]] = crop
        else:
            validation.append((crop, record))
    atlas.close()

    prepared_started = perf_counter()
    prepared = {
        family: {tier: PreparedFeature.from_image(crop) for tier, crop in group.items()}
        for family, group in templates.items()
    }
    prepared_ms = (perf_counter() - prepared_started) * 1000.0

    calibration_rows = []
    for family, group in templates.items():
        for expected, crop in group.items():
            tier, confidence, margin = rank(crop, group)
            calibration_rows.append({"family": family, "expected": expected, "candidate": tier, "score": confidence, "margin": margin})

    direct_rows = []
    direct_times: list[float] = []
    mean_rows = []
    mean_times: list[float] = []
    feature_rows = []
    feature_times: list[float] = []
    for crop, record in validation:
        started = perf_counter()
        tier, confidence, margin = rank(crop, templates[record["family"]])
        direct_times.append((perf_counter() - started) * 1000.0)
        direct_rows.append({
            "source_file": record["source_file"], "family": record["family"],
            "expected": record["tier"], "candidate": tier,
            "score": confidence, "margin": margin,
        })
        started = perf_counter()
        mean_tier, mean_confidence, mean_margin = rank_mean(crop, templates[record["family"]])
        mean_times.append((perf_counter() - started) * 1000.0)
        mean_rows.append({"family": record["family"], "expected": record["tier"], "candidate": mean_tier, "score": mean_confidence, "margin": mean_margin})
        started = perf_counter()
        feature_tier, feature_confidence, feature_margin = rank_feature(crop, prepared[record["family"]])
        feature_times.append((perf_counter() - started) * 1000.0)
        feature_rows.append({"family": record["family"], "expected": record["tier"], "candidate": feature_tier, "score": feature_confidence, "margin": feature_margin})

    catalog = RecognitionAssetCatalog(ASSETS)
    recognizer = StudentEquipmentRecognizer(catalog)
    regions = catalog.region("student")
    source_root = Path(spec["source_folder"])
    synthetic_rows = []
    synthetic_times: list[float] = []
    for row in spec["screenshots"]:
        if row["split"] != "validation":
            continue
        with Image.open(source_root / row["file"]) as opened:
            crops = StudentBasicCropSet.from_frame(opened.convert("RGB"), regions)
        try:
            for slot, family in enumerate(spec["families"], start=1):
                started = perf_counter()
                observation = recognizer._read_synthesized_tier(
                    crops.images[f"basic_equipment_{slot}_icon_region"], family,
                    regions[f"basic_equipment_{slot}_icon_region"],
                )
                synthetic_times.append((perf_counter() - started) * 1000.0)
                synthetic_rows.append({
                    "source_file": row["file"], "family": family, "expected": "T2",
                    "candidate": observation.value, "score": observation.confidence,
                    "note": observation.note,
                })
        finally:
            crops.close()

    result = {
        "schema_version": 1,
        "mode": "direct_actual_inner_roi_pilot",
        "dataset": {
            "template_rois": sum(len(group) for group in templates.values()),
            "independent_validation_rois": len(validation),
            "families": spec["families"], "template_tiers": 10, "validation_tier": "T2",
        },
        "direct": {
            "top1_correct": sum(row["candidate"] == row["expected"] for row in direct_rows),
            "accepted_at_current_gate": sum(row["candidate"] == row["expected"] and row["score"] >= .35 and row["margin"] >= .08 for row in direct_rows),
            "wrong": sum(row["candidate"] != row["expected"] for row in direct_rows),
            "score_min": min(row["score"] for row in direct_rows),
            "margin_min": min(row["margin"] for row in direct_rows),
            "warm_one_roi_p50_ms": median(direct_times),
            "warm_one_roi_p95_ms": percentile(direct_times, .95),
            "rows": direct_rows,
        },
        "direct_rgb_mean": {
            "top1_correct": sum(row["candidate"] == row["expected"] for row in mean_rows),
            "wrong": sum(row["candidate"] != row["expected"] for row in mean_rows),
            "score_min": min(row["score"] for row in mean_rows),
            "margin_min": min(row["margin"] for row in mean_rows),
            "warm_one_roi_p50_ms": median(mean_times),
            "warm_one_roi_p95_ms": percentile(mean_times, .95),
            "rows": mean_rows,
        },
        "direct_prepared_feature": {
            "template_prepare_ms": prepared_ms,
            "template_prepared_bytes": sum(item.byte_size for group in prepared.values() for item in group.values()),
            "top1_correct": sum(row["candidate"] == row["expected"] for row in feature_rows),
            "wrong": sum(row["candidate"] != row["expected"] for row in feature_rows),
            "score_min": min(row["score"] for row in feature_rows),
            "margin_min": min(row["margin"] for row in feature_rows),
            "warm_one_roi_p50_ms": median(feature_times),
            "warm_one_roi_p95_ms": percentile(feature_times, .95),
            "rows": feature_rows,
        },
        "template_self_check": {
            "top1_correct": sum(row["candidate"] == row["expected"] for row in calibration_rows),
            "total": len(calibration_rows),
            "margin_min": min(row["margin"] for row in calibration_rows),
        },
        "synthetic_baseline": {
            "accepted_correct": sum(row["candidate"] == row["expected"] for row in synthetic_rows),
            "fallback": sum(row["candidate"] is None for row in synthetic_rows),
            "warm_one_roi_p50_ms": median(synthetic_times),
            "warm_one_roi_p95_ms": percentile(synthetic_times, .95),
            "rows": synthetic_rows,
        },
        "decision": "diagnostic until the independent validation result and remaining six-family coverage are reviewed",
    }
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for group in templates.values():
        for template in group.values():
            template.close()
    for group in prepared.values():
        for template in group.values():
            template.close()
    for crop, _record in validation:
        crop.close()


if __name__ == "__main__":
    main()
