from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path

from PIL import Image

from core.student_scan_recognizer import relationship_rank_mask, ratio_crop


REGION = {"x1": 0.033, "y1": 0.765, "x2": 0.056, "y2": 0.825}
PURPOSE = "student-relationship-rank-template"
DIGIT_PURPOSE = "student-relationship-rank-digit-template"


def export(source_root: Path, spec_path: Path, backend_root: Path) -> None:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    rows = spec["screenshots"]
    fixture_root = backend_root / "tests" / "fixtures" / "student_relationship_s4"
    template_root = backend_root / "assets" / "recognition" / "v1" / "templates" / "student_relationship_rank"
    fixture_root.mkdir(parents=True, exist_ok=True)
    template_root.mkdir(parents=True, exist_ok=True)

    records: list[dict[str, object]] = []
    rois: list[Image.Image] = []
    manifest_entries: list[dict[str, object]] = []
    for row in rows:
        source = source_root / Path(str(row["relative_path"]))
        digest = sha256(source.read_bytes()).hexdigest()
        if digest != row["sha256"]:
            raise ValueError(f"source hash mismatch: {source}")
        with Image.open(source) as opened:
            frame = opened.convert("RGB")
            if list(frame.size) != row["source_size"]:
                raise ValueError(f"source size mismatch: {source.name}: {frame.size}")
            roi = ratio_crop(frame, REGION).copy()
        rois.append(roi)
        record = {
            "source_file": source.name,
            "source_sha256": digest,
            "source_size": row["source_size"],
            "rank": row["rank"],
            "student_ref": row["student_ref"],
            "partition": row["partition"],
            "review_status": "visual_verified",
        }
        records.append(record)
        if row["partition"] not in {"calibration", "calibration_only"}:
            continue
        normalized = relationship_rank_mask(roi)
        if normalized is None:
            raise ValueError(f"empty rank glyph: {source.name}")
        label = str(row["rank"])
        relative = Path("templates") / "student_relationship_rank" / label / f"{source.stem}.png"
        target = backend_root / "assets" / "recognition" / "v1" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        normalized.save(target)
        content = target.read_bytes()
        manifest_entries.append({
            "path": relative.as_posix(), "scan_kind": "student", "purpose": PURPOSE,
            "relationship_rank": label, "required": True, "bytes": len(content),
            "sha256": sha256(content).hexdigest(), "source_sha256": digest,
        })

    cell = (72, 96)
    columns = 6
    atlas = Image.new("RGB", (columns * cell[0], ((len(rois) + columns - 1) // columns) * cell[1]))
    for index, (roi, record) in enumerate(zip(rois, records)):
        x, y = (index % columns) * cell[0], (index // columns) * cell[1]
        atlas.paste(roi.resize(cell, Image.Resampling.NEAREST), (x, y))
        record["atlas_box"] = [x, y, x + cell[0], y + cell[1]]
        roi.close()
    atlas_path = fixture_root / "roi_atlas.png"
    atlas.save(atlas_path)
    atlas.close()
    verified_ranks = sorted({int(row["rank"]) for row in rows})
    fixture = {
        "schema_version": 1,
        "reviewed_at": spec["reviewed_at"],
        "ground_truth": {
            "method": "manual review of user-supplied relationship ranks",
            "full_screenshots_retained": False,
            "template_leakage": False,
        },
        "coverage": {
            "verified_ranks": verified_ranks,
            "not_verified": [rank for rank in (1, 9, 100) if rank not in verified_ranks],
            "resolutions": sorted({"x".join(str(value) for value in row["source_size"]) for row in rows}),
        },
        "atlas": {"path": atlas_path.name, "sha256": sha256(atlas_path.read_bytes()).hexdigest()},
        "records": records,
    }
    (fixture_root / "manifest.json").write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    manifest_path = backend_root / "assets" / "recognition" / "v1" / "student_basic_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assets = manifest["assets"]
    insertion_index = 0
    for item in assets:
        if item.get("purpose") in {PURPOSE, DIGIT_PURPOSE}:
            break
        if item.get("purpose") != PURPOSE:
            insertion_index += 1
    assets = [item for item in assets if item.get("purpose") != PURPOSE]
    manifest_entries.sort(key=lambda item: str(item["path"]))
    assets[insertion_index:insertion_index] = manifest_entries
    manifest["assets"] = assets
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--backend-root", type=Path, required=True)
    args = parser.parse_args()
    export(args.source_root, args.spec, args.backend_root)


if __name__ == "__main__":
    main()
