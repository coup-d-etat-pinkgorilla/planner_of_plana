from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import re
from statistics import median
from time import perf_counter

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import StudentEquipmentRecognizer
from core.student_scan_recognizer import StudentBasicCropSet


BACKEND = Path(__file__).parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
FIXTURES = (
    BACKEND / "tests" / "fixtures" / "student_equipment_s3b_archive",
    BACKEND / "tests" / "fixtures" / "student_equipment_s3b_promotion_probe",
    BACKEND / "tests" / "fixtures" / "student_equipment_s3b_1280_digits",
)
LIVE = BACKEND / "tests" / "fixtures" / "student_equipment_s3_dataset" / "live_1280x720"
OUTPUT = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_position_benchmark.json"


def _candidate(note: str) -> int | None:
    match = re.search(r"(?:^|;)candidate=(\d+)(?:;|$)", note)
    return int(match.group(1)) if match else None


def _margin(note: str) -> float:
    match = re.search(r"(?:^|;)margin=([0-9.]+)(?:;|$)", note)
    return float(match.group(1)) if match else 0.0


def main() -> None:
    cold_started = perf_counter()
    catalog = RecognitionAssetCatalog(ASSETS)
    recognizer = StudentEquipmentRecognizer(catalog)
    cold_ms = (perf_counter() - cold_started) * 1000.0
    regions = catalog.region("student")
    rows: list[tuple[Image.Image, dict[str, object]]] = []
    for fixture in FIXTURES:
        manifest = json.loads((fixture / "manifest.json").read_text(encoding="utf-8"))
        with Image.open(fixture / manifest["atlas"]["path"]) as atlas:
            for record in manifest["records"]:
                rows.append((atlas.crop(tuple(record["atlas_box"])), record))
    integration_frames = integration_menu_calls = integration_unresolved_slots = 0
    roots = (
        (LIVE / "student_detail", "mika"),
        (LIVE / "favorite_hibiki" / "student_detail", "hibiki"),
    )
    for root, student_ref in roots:
        for index in range(1, 4):
            with Image.open(root / f"sample_{index:02d}.png") as frame:
                crops = StudentBasicCropSet.from_frame(frame.convert("RGB"), regions)
            for slot in (1, 2, 3):
                rows.append((
                    crops.images[f"basic_equipment_{slot}_level_digits_quad"].copy(),
                    {"slot": slot, "tier": "T10", "expected_value": 70, "evidence_class": "exact_1280x720"},
                ))
            _values, unresolved = recognizer.recognize(
                crops, student_ref=student_ref, student_level=90,
            )
            equipment_unresolved = [slot for slot in unresolved if slot <= 3]
            integration_frames += 1
            integration_menu_calls += int(bool(equipment_unresolved))
            integration_unresolved_slots += len(equipment_unresolved)
            crops.close()
    confusion: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    scores: list[float] = []
    margins: list[float] = []
    correct = accepted_correct = wrong = fallback = exact_correct = exact_total = 0
    warm: list[float] = []
    try:
        for crop, record in rows:
            started = perf_counter()
            observation = recognizer.read_position_binary_level(
                crop,
                tier=str(record["tier"]),
                region=regions[f"basic_equipment_{record['slot']}_level_digits_quad"],
            )
            warm.append((perf_counter() - started) * 1000.0)
            expected = int(record["expected_value"])
            candidate = _candidate(observation.note)
            if candidate is None:
                fallback += 1
            else:
                confusion[str(expected)][str(candidate)] += 1
                correct += int(candidate == expected)
                wrong += int(candidate != expected)
                scores.append(observation.confidence)
                margins.append(_margin(observation.note))
            accepted_correct += int(observation.value == expected and observation.confirmed)
            if record.get("evidence_class") == "exact_1280x720":
                exact_total += 1
                exact_correct += int(candidate == expected)
    finally:
        for crop, _record in rows:
            crop.close()
    ordered = sorted(warm)
    report = {
        "schema_version": 1,
        "mode": "position_binary_shadow_gate",
        "production_enabled": recognizer.position_binary_production_enabled,
        "datasets": {
            "combined_level_pairs": len(rows),
            "prior_frozen_and_live": 334,
            "new_digit_probe": 15,
            "exact_1280x720_pairs": exact_total,
        },
        "accuracy": {
            "top1_correct": correct,
            "accepted_correct": accepted_correct,
            "accepted_wrong": wrong,
            "feature_fallback": fallback,
            "exact_1280x720_correct": exact_correct,
            "score_min": min(scores, default=0.0),
            "margin_min": min(margins, default=0.0),
            "confusion": {key: dict(value) for key, value in confusion.items()},
        },
        "templates": {
            "count": recognizer.metrics.position_binary_template_count,
            "bytes": recognizer.metrics.position_binary_template_bytes,
            "first_position": list("123456789"),
            "second_position": list("0123456789"),
            "source_pixels_in_runtime_assets": False,
        },
        "performance_ms": {
            "cold_recognizer_with_position_bank": cold_ms,
            "position_bank_load": recognizer.metrics.position_binary_template_prepare_ms,
            "one_roi_warm_p50": median(warm),
            "one_roi_warm_p95": ordered[max(0, round(len(ordered) * 0.95) - 1)],
        },
        "runtime_fallback": {
            "integration_frames": integration_frames,
            "menu_calls_before_position_bank": 6,
            "menu_calls_after_position_bank": integration_menu_calls,
            "unresolved_equipment_slots_after": integration_unresolved_slots,
            "whole_string_templates_built": recognizer.metrics.generated_binary_template_count,
        },
        "decision": {
            "position_bank": "production selected",
            "production": "enabled only for the 19-mask fixed-position level path",
        },
    }
    recognizer.close()
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["accuracy"], ensure_ascii=False))


if __name__ == "__main__":
    main()
