from __future__ import annotations

import json
from pathlib import Path
from statistics import median
from time import perf_counter
from typing import Any

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import PreparedBinaryGlyph
from core.student_scan_recognizer import (
    StudentBasicCropSet,
    _luminance,
    _mask_from_predicate,
    _normalize_mask,
    relationship_rank_number_mask,
)
from tools.benchmark_student_synthetic_digits import (
    ASSETS,
    ATTACHED_FRAMES,
    BACKEND,
    RELATIONSHIP_FIXTURE,
    SERIKA_ANSWERS,
    SERIKA_FRAME,
)


BANK = ASSETS / "templates" / "student_numeric_synthetic" / "whole_value_bank.json"
OUTPUT = BACKEND / "tests" / "fixtures" / "student_whole_value_benchmark.json"


def _percentile(values: list[float], percentile: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, max(0, round((len(ordered) - 1) * percentile)))]


def _prepare(mask: Image.Image) -> PreparedBinaryGlyph:
    normalized = _normalize_mask(mask, size=(64, 32), padding=2)
    prepared = PreparedBinaryGlyph.from_mask(normalized)
    if normalized is not None:
        normalized.close()
    if prepared is None:
        raise ValueError("empty whole-value feature")
    return prepared


def _load_bank() -> tuple[dict[str, dict[int, PreparedBinaryGlyph]], int]:
    payload = json.loads(BANK.read_text(encoding="utf-8"))
    grouped: dict[str, dict[int, PreparedBinaryGlyph]] = {}
    for field, raw in payload["fields"].items():
        grouped[field] = {
            int(item["value"]): PreparedBinaryGlyph(
                bits=int(str(item["bits_hex"]), 16),
                ink=int(item["ink"]),
                pixels=int(item["pixels"]),
            )
            for item in raw["templates"]
        }
    prepared_bytes = sum((item.pixels + 7) // 8 for group in grouped.values() for item in group.values())
    return grouped, prepared_bytes


def _rank(feature: PreparedBinaryGlyph, templates: dict[int, PreparedBinaryGlyph]) -> tuple[int, float, float]:
    ranked = sorted(
        ((value, feature.compare(template)[0]) for value, template in templates.items()),
        key=lambda row: row[1],
        reverse=True,
    )
    return ranked[0][0], ranked[0][1], ranked[0][1] - ranked[1][1]


def _basic_samples(regions: dict[str, Any]) -> dict[str, list[tuple[int, PreparedBinaryGlyph, str]]]:
    result = {"student_level": [], "weapon_level": []}
    for path, answers in [(SERIKA_FRAME, SERIKA_ANSWERS), *ATTACHED_FRAMES]:
        if not path.is_file():
            continue
        with Image.open(path) as opened:
            crops = StudentBasicCropSet.from_frame(opened.convert("RGB"), regions)
        try:
            level = _mask_from_predicate(
                crops.images["basic_level_digits_quad"].convert("RGB"),
                lambda pixel: _luminance(pixel) >= 150 and max(pixel) - min(pixel) <= 95,
            )
            weapon = _mask_from_predicate(
                crops.images["basic_weapon_level_digits_quad"].convert("RGB"),
                lambda pixel: min(pixel) >= 238 and max(pixel) - min(pixel) <= 28,
            )
            result["student_level"].append((int(answers["student_level"]), _prepare(level), path.name))
            result["weapon_level"].append((int(answers["weapon_level"]), _prepare(weapon), path.name))
            level.close()
            weapon.close()
        finally:
            crops.close()
    return result


def _relationship_samples() -> list[tuple[int, PreparedBinaryGlyph, str]]:
    manifest = json.loads((RELATIONSHIP_FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    result: list[tuple[int, PreparedBinaryGlyph, str]] = []
    with Image.open(RELATIONSHIP_FIXTURE / manifest["atlas"]["path"]) as atlas:
        for record in manifest["records"]:
            if record["partition"] != "validation":
                continue
            crop = atlas.crop(tuple(record["atlas_box"]))
            mask = relationship_rank_number_mask(crop)
            result.append((int(record["rank"]), _prepare(mask), str(record["source_file"])))
            crop.close()
            mask.close()
    return result


def benchmark(repeats: int = 200) -> dict[str, Any]:
    cold_started = perf_counter()
    templates, prepared_bytes = _load_bank()
    cold_ms = (perf_counter() - cold_started) * 1000.0
    regions = RecognitionAssetCatalog(ASSETS).region("student")
    samples = _basic_samples(regions)
    samples["relationship_rank"] = _relationship_samples()
    fields: dict[str, Any] = {}
    for field, rows in samples.items():
        details = []
        timings: list[float] = []
        for expected, feature, source in rows:
            observed, score, margin = _rank(feature, templates[field])
            details.append({
                "source": source,
                "expected": expected,
                "observed": observed,
                "score": score,
                "margin": margin,
                "correct": observed == expected,
            })
        for index in range(repeats):
            _expected, feature, _source = rows[index % len(rows)]
            started = perf_counter()
            _rank(feature, templates[field])
            timings.append((perf_counter() - started) * 1000.0)
        fields[field] = {
            "samples": len(rows),
            "correct": sum(bool(row["correct"]) for row in details),
            "warm_p50_ms": median(timings),
            "warm_p95_ms": _percentile(timings, 0.95),
            "rows": details,
        }
    return {
        "schema_version": 1,
        "mode": "whole-value-synthetic-shadow-benchmark",
        "templates": {
            "count": sum(len(group) for group in templates.values()),
            "json_bytes": BANK.stat().st_size,
            "prepared_bytes": prepared_bytes,
            "cold_load_ms": cold_ms,
        },
        "fields": fields,
        "decision": {
            "production": "not promoted",
            "reason": "runtime cost is bounded, but student and relationship validation accuracy is insufficient",
        },
    }


def main() -> None:
    report = benchmark()
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"templates": report["templates"], "fields": {
        key: {name: value for name, value in field.items() if name != "rows"}
        for key, field in report["fields"].items()
    }}, ensure_ascii=False))


if __name__ == "__main__":
    main()
