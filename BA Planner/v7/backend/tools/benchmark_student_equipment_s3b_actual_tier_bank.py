from __future__ import annotations

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
LIVE = BACKEND / "tests" / "fixtures" / "student_equipment_s3_dataset" / "live_1280x720"
PILOT_SPEC = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_direct_tier_spec.json"
OUTPUT = BACKEND / "tests" / "fixtures" / "student_equipment_s3b_actual_tier_benchmark.json"


def margin(note: str) -> float:
    found = re.search(r"(?:^|;)margin=([0-9.]+)(?:;|$)", note)
    return float(found.group(1)) if found else 0.0


def percentile(values: list[float], ratio: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, round((len(ordered) - 1) * ratio))]


def main() -> None:
    cold_started = perf_counter()
    catalog = RecognitionAssetCatalog(ASSETS)
    recognizer = StudentEquipmentRecognizer(catalog)
    cold_ms = (perf_counter() - cold_started) * 1000.0
    regions = catalog.region("student")
    metadata_path = ASSETS / "templates" / "student_equipment" / "basic_tier_inner_rois.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    with Image.open(ASSETS / metadata["atlas_path"]) as opened:
        atlas = opened.convert("RGB")
    self_rows = []
    try:
        for record in metadata["records"]:
            inner = atlas.crop(tuple(record["atlas_box"]))
            full = Image.new("RGB", (100, 80), "white")
            full.paste(inner, (15, 16))
            observation = recognizer.read_direct_tier(
                full, record["family"],
                {"crop_ratio": {"left": .15, "right": .15, "top": .20, "bottom": .30}},
            )
            self_rows.append({
                "family": record["family"], "expected": record["tier"],
                "candidate": observation.value, "score": observation.confidence,
                "margin": margin(observation.note),
            })
            inner.close()
            full.close()
    finally:
        atlas.close()

    independent_rows = []
    warm: list[float] = []
    pilot = json.loads(PILOT_SPEC.read_text(encoding="utf-8"))
    for row in pilot["screenshots"]:
        if row["split"] != "validation":
            continue
        with Image.open(Path(pilot["source_folder"]) / row["file"]) as opened:
            crops = StudentBasicCropSet.from_frame(opened.convert("RGB"), regions)
        try:
            for slot, family in enumerate(pilot["families"], start=1):
                started = perf_counter()
                observation = recognizer.read_tier(
                    crops.images[f"basic_equipment_{slot}_icon_region"], family,
                    regions[f"basic_equipment_{slot}_icon_region"],
                )
                warm.append((perf_counter() - started) * 1000.0)
                independent_rows.append({
                    "dataset": "kurumi_t2", "family": family, "expected": "T2",
                    "candidate": observation.value, "source": observation.source,
                    "score": observation.confidence, "margin": margin(observation.note),
                })
        finally:
            crops.close()
    for root, student_ref, families in (
        (LIVE / "student_detail", "mika", ("Hat", "Badge", "Watch")),
        (LIVE / "favorite_hibiki" / "student_detail", "hibiki", ("Hat", "Hairpin", "Watch")),
    ):
        for index in range(1, 4):
            with Image.open(root / f"sample_{index:02d}.png") as opened:
                crops = StudentBasicCropSet.from_frame(opened.convert("RGB"), regions)
            try:
                for slot, family in enumerate(families, start=1):
                    started = perf_counter()
                    observation = recognizer.read_tier(
                        crops.images[f"basic_equipment_{slot}_icon_region"], family,
                        regions[f"basic_equipment_{slot}_icon_region"],
                    )
                    warm.append((perf_counter() - started) * 1000.0)
                    independent_rows.append({
                        "dataset": f"{student_ref}_t10", "family": family, "expected": "T10",
                        "candidate": observation.value, "source": observation.source,
                        "score": observation.confidence, "margin": margin(observation.note),
                    })
            finally:
                crops.close()
    report = {
        "schema_version": 1,
        "mode": "actual_fixed-inner-roi-production-gate",
        "production_enabled": recognizer.direct_tier_production_enabled,
        "validation_policy": metadata["validation_policy"],
        "bank": {
            "templates": metadata["template_count"], "families": len(metadata["families"]),
            "tiers": len(metadata["tiers"]), "prepared_bytes": recognizer.metrics.direct_tier_template_bytes,
            "prepare_ms": recognizer.metrics.direct_tier_template_prepare_ms,
            "cold_recognizer_ms": cold_ms,
        },
        "template_self_check": {
            "correct": sum(row["candidate"] == row["expected"] for row in self_rows),
            "total": len(self_rows), "wrong": sum(row["candidate"] != row["expected"] for row in self_rows),
            "score_min": min(row["score"] for row in self_rows), "margin_min": min(row["margin"] for row in self_rows),
        },
        "available_independent_regression": {
            "correct": sum(row["candidate"] == row["expected"] for row in independent_rows),
            "total": len(independent_rows), "wrong": sum(row["candidate"] != row["expected"] for row in independent_rows),
            "direct_source": sum(row["source"] == "equipment_direct_icon_tier" for row in independent_rows),
            "score_min": min(row["score"] for row in independent_rows), "margin_min": min(row["margin"] for row in independent_rows),
            "warm_one_roi_p50_ms": median(warm), "warm_one_roi_p95_ms": percentile(warm, .95),
            "rows": independent_rows,
        },
        "decision": "production selected; synthesized reader retained only as uncertainty/missing-asset fallback",
    }
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    recognizer.close()


if __name__ == "__main__":
    main()
