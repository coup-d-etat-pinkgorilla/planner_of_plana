from __future__ import annotations

import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
from time import perf_counter
from typing import Any

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_scan_recognizer import (
    StudentBasicCropSet,
    _binary_iou,
    _luminance,
    _mask_from_predicate,
    _ncc_difference_score,
    _normalize_mask,
    _pixels,
    relationship_rank_number_mask,
    split_relationship_rank_digits,
)


BACKEND = Path(__file__).resolve().parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
ROOT = ASSETS / "templates" / "student_numeric_synthetic"
SPEC = ROOT / "renderer_spec.json"
RELATIONSHIP_FIXTURE = BACKEND / "tests" / "fixtures" / "student_relationship_s4"
SERIKA_FRAME = BACKEND / "tests" / "fixtures" / "student_scan_s2_serika_new_year.png"
SERIKA_ANSWERS = {"student_level": 12, "weapon_level": 50, "relationship_rank": 24}
SHADOW_GATES = {
    "student_level": {"score": 0.45, "margin": 0.05},
    "weapon_level": {"score": 0.44, "margin": 0.05},
    "relationship_rank": {"score": 0.45, "margin": 0.05},
}
ATTACHED_FRAMES = (
    (
        Path(r"C:\Users\brigh\AppData\Local\Temp\codex-clipboard-5a9ae2c9-a048-480c-8d46-52c492e5b433.png"),
        {"student_level": 90, "weapon_level": 60, "relationship_rank": 41},
    ),
    (
        Path(r"C:\Users\brigh\AppData\Local\Temp\codex-clipboard-c41a51be-ae40-4e82-a75a-48b0fce9317b.png"),
        {"student_level": 90, "weapon_level": 60, "relationship_rank": 74},
    ),
)


def _templates(field: str, layout: int, position: int) -> dict[str, tuple[Image.Image, ...]]:
    root = ROOT / field / f"layout_{layout}" / f"position_{position}"
    result: dict[str, tuple[Image.Image, ...]] = {}
    for digit in "0123456789":
        samples: list[Image.Image] = []
        for path in sorted(root.glob(f"{digit}_v*.png")):
            with Image.open(path) as opened:
                samples.append(opened.convert("L").copy())
        if not samples:
            raise FileNotFoundError(f"synthetic templates missing: {field}:{layout}:{position}:{digit}")
        result[digit] = tuple(samples)
    return result


def _close_templates(templates: dict[str, tuple[Image.Image, ...]]) -> None:
    for samples in templates.values():
        for sample in samples:
            sample.close()


def _rank_synthetic(
    glyph: Image.Image | None,
    templates: dict[str, tuple[Image.Image, ...]],
) -> tuple[str | None, float, float]:
    if glyph is None:
        return None, 0.0, 0.0
    ranked = sorted(
        (
            (
                label,
                max(
                    0.75 * _binary_iou(glyph, sample)
                    + 0.25 * _ncc_difference_score(glyph, sample)
                    for sample in samples
                ),
            )
            for label, samples in templates.items()
            if samples
        ),
        key=lambda row: row[1],
        reverse=True,
    )
    if not ranked:
        return None, 0.0, 0.0
    return ranked[0][0], ranked[0][1], ranked[0][1] - (ranked[1][1] if len(ranked) > 1 else 0.0)


def _read_fixed_two_cell(
    crop: Image.Image,
    *,
    field: str,
    center_trim: int,
    second_occupancy_gate: float,
    predicate,
) -> dict[str, Any]:
    mask = _mask_from_predicate(crop.convert("RGB"), predicate)
    midpoint = mask.width // 2
    cells = (
        mask.crop((0, 0, max(1, midpoint - center_trim), mask.height)),
        mask.crop((midpoint + center_trim, 0, mask.width, mask.height)),
    )
    occupancy = sum(value >= 127 for value in _pixels(cells[1])) / max(1, cells[1].width * cells[1].height)
    layout = 2 if occupancy >= second_occupancy_gate else 1
    ranked: list[tuple[str | None, float, float]] = []
    try:
        for position in range(layout):
            templates = _templates(field, layout, position)
            try:
                ranked.append(_rank_synthetic(_normalize_mask(cells[position]), templates))
            finally:
                _close_templates(templates)
    finally:
        mask.close()
        for cell in cells:
            cell.close()
    if not ranked or any(item[0] is None for item in ranked):
        return {"value": None, "score": 0.0, "margin": 0.0, "layout": layout}
    return {
        "value": int("".join(str(item[0]) for item in ranked)),
        "score": min(item[1] for item in ranked),
        "margin": min(item[2] for item in ranked),
        "layout": layout,
    }


def read_student_level(crop: Image.Image) -> dict[str, Any]:
    return _read_fixed_two_cell(
        crop,
        field="student_level",
        center_trim=3,
        second_occupancy_gate=0.025,
        predicate=lambda pixel: _luminance(pixel) >= 150 and max(pixel) - min(pixel) <= 95,
    )


def read_weapon_level(crop: Image.Image) -> dict[str, Any]:
    return _read_fixed_two_cell(
        crop,
        field="weapon_level",
        center_trim=1,
        second_occupancy_gate=0.012,
        predicate=lambda pixel: min(pixel) >= 238 and max(pixel) - min(pixel) <= 28,
    )


def read_relationship_rank(crop: Image.Image) -> dict[str, Any]:
    mask = relationship_rank_number_mask(crop)
    candidates: list[dict[str, Any]] = []
    try:
        for layout in (1, 2, 3):
            glyphs = split_relationship_rank_digits(mask, layout)
            if len(glyphs) != layout:
                continue
            ranked: list[tuple[str | None, float, float]] = []
            try:
                for position, glyph in enumerate(glyphs):
                    templates = _templates("relationship_rank", layout, position)
                    try:
                        ranked.append(_rank_synthetic(glyph, templates))
                    finally:
                        _close_templates(templates)
            finally:
                for glyph in glyphs:
                    glyph.close()
            if any(item[0] is None for item in ranked):
                continue
            text = "".join(str(item[0]) for item in ranked)
            if text.startswith("0"):
                continue
            value = int(text)
            if not 1 <= value <= 100 or (layout == 3 and value != 100):
                continue
            candidates.append({
                "value": value,
                "score": min(item[1] for item in ranked),
                "margin": min(item[2] for item in ranked),
                "layout": layout,
            })
    finally:
        mask.close()
    return max(candidates, key=lambda item: (item["score"], item["margin"]), default={
        "value": None, "score": 0.0, "margin": 0.0, "layout": 0,
    })


def _frame_result(path: Path, answers: dict[str, int], regions: dict[str, Any]) -> dict[str, Any]:
    with Image.open(path) as opened:
        frame = opened.convert("RGB")
        crops = StudentBasicCropSet.from_frame(frame, regions)
    started = perf_counter()
    try:
        observed = {
            "student_level": read_student_level(crops.images["basic_level_digits_quad"]),
            "weapon_level": read_weapon_level(crops.images["basic_weapon_level_digits_quad"]),
            "relationship_rank": read_relationship_rank(crops.images["basic_relationship_rank_region"]),
        }
    finally:
        crops.close()
    for field, answer in answers.items():
        observed[field]["expected"] = answer
        observed[field]["correct"] = observed[field]["value"] == answer
        gate = SHADOW_GATES[field]
        observed[field]["accepted"] = (
            observed[field]["score"] >= gate["score"]
            and observed[field]["margin"] >= gate["margin"]
        )
    return {
        "source": path.name,
        "source_sha256": sha256(path.read_bytes()).hexdigest(),
        "observed": observed,
        "elapsed_ms": round((perf_counter() - started) * 1000.0, 6),
    }


def benchmark() -> dict[str, Any]:
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    catalog = RecognitionAssetCatalog(ASSETS)
    regions = catalog.region("student")
    frames = [_frame_result(SERIKA_FRAME, SERIKA_ANSWERS, regions)]
    for path, answers in ATTACHED_FRAMES:
        if path.is_file():
            frames.append(_frame_result(path, answers, regions))

    relationship_manifest = json.loads((RELATIONSHIP_FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    relationship_rows: list[dict[str, Any]] = []
    confusion: Counter[tuple[int, int | None]] = Counter()
    with Image.open(RELATIONSHIP_FIXTURE / relationship_manifest["atlas"]["path"]) as atlas:
        for record in relationship_manifest["records"]:
            crop = atlas.crop(record["atlas_box"])
            observed = read_relationship_rank(crop)
            crop.close()
            expected = int(record["rank"])
            confusion[(expected, observed["value"])] += 1
            relationship_rows.append({
                "partition": record["partition"],
                "source": record["source_file"],
                "expected": expected,
                **observed,
                "correct": observed["value"] == expected,
                "accepted": (
                    observed["score"] >= SHADOW_GATES["relationship_rank"]["score"]
                    and observed["margin"] >= SHADOW_GATES["relationship_rank"]["margin"]
                ),
            })
    partitions: dict[str, dict[str, Any]] = {}
    for partition in sorted({row["partition"] for row in relationship_rows}):
        rows = [row for row in relationship_rows if row["partition"] == partition]
        correct = sum(bool(row["correct"]) for row in rows)
        accepted_correct = sum(bool(row["correct"] and row["accepted"]) for row in rows)
        accepted_wrong = sum(bool(not row["correct"] and row["accepted"]) for row in rows)
        partitions[partition] = {
            "samples": len(rows),
            "correct": correct,
            "accepted_correct": accepted_correct,
            "accepted_wrong": accepted_wrong,
            "fallback": len(rows) - accepted_correct - accepted_wrong,
            "accuracy": correct / len(rows) if rows else None,
            "minimum_score": min((float(row["score"]) for row in rows), default=0.0),
            "minimum_margin": min((float(row["margin"]) for row in rows), default=0.0),
        }
    return {
        "schema_version": 1,
        "mode": "synthetic-shadow-no-runtime-promotion",
        "renderer_spec": spec,
        "shadow_gates": SHADOW_GATES,
        "basic_frames": frames,
        "relationship_partitions": partitions,
        "relationship_confusion": [
            {"expected": expected, "observed": observed, "count": count}
            for (expected, observed), count in sorted(confusion.items(), key=lambda row: (row[0][0], -1 if row[0][1] is None else row[0][1]))
        ],
        "relationship_rows": relationship_rows,
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
