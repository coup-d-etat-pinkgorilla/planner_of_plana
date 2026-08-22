from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import StudentEquipmentRecognizer
from core.student_scan_recognizer import StudentBasicCropSet


def export_fixture(source: Path, spec_path: Path, assets: Path, output: Path) -> None:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    rows = spec["screenshots"]
    families = spec["families"]
    catalog = RecognitionAssetCatalog(assets)
    regions = catalog.region("student")
    records: list[dict[str, object]] = []
    atlas = Image.new("RGB", (10 * 70, ((len(rows) * 3 + 9) // 10) * 40))
    for row in rows:
        path = source / row["file"]
        digest = sha256(path.read_bytes()).hexdigest()
        if digest != row["sha256"]:
            raise ValueError(f"source hash mismatch: {path.name}")
        with Image.open(path) as opened:
            frame = opened.convert("RGB")
            if frame.size != (1280, 720):
                raise ValueError(f"exact 1280x720 required: {path.name}: {frame.size}")
            crops = StudentBasicCropSet.from_frame(frame, regions)
        try:
            for slot, family in enumerate(families, start=1):
                region = regions[f"basic_equipment_{slot}_icon_region"]
                inner = StudentEquipmentRecognizer._inner_icon(
                    crops.images[f"basic_equipment_{slot}_icon_region"], region,
                ).convert("RGB")
                if inner.size != (70, 40):
                    raise ValueError(f"unexpected inner ROI: {path.name}: slot {slot}: {inner.size}")
                index = len(records)
                x, y = (index % 10) * 70, (index // 10) * 40
                atlas.paste(inner, (x, y))
                records.append({
                    "source_file": path.name,
                    "source_sha256": digest,
                    "source_size": [1280, 720],
                    "student_ref": row["student_ref"],
                    "family": family,
                    "tier": row["tier"],
                    "slot": slot,
                    "split": row["split"],
                    "atlas_box": [x, y, x + 70, y + 40],
                    "review_status": "visual_verified",
                })
                inner.close()
        finally:
            crops.close()
    output.mkdir(parents=True, exist_ok=True)
    atlas_path = output / "inner_icon_atlas.png"
    atlas.save(atlas_path)
    atlas.close()
    with Image.open(atlas_path) as atlas_check:
        atlas_size = list(atlas_check.size)
    manifest = {
        "schema_version": 1,
        "reviewed_at": spec["reviewed_at"],
        "source_screenshot_count": len(rows),
        "roi_count": len(records),
        "roi_size": [70, 40],
        "ground_truth": {
            "method": "user tier sequence plus visual review",
            "template_split": "haruna_sportswear T1-T10",
            "independent_validation_split": "kurumi T2 four stable frames",
            "runtime_assets_contain_source_pixels": False,
        },
        "coverage": {
            "families": families,
            "template_tiers": [f"T{number}" for number in range(1, 11)],
            "validation_tiers": ["T2"],
            "validation_roi_count": sum(row["split"] == "validation" for row in records),
        },
        "atlas": {
            "path": atlas_path.name,
            "size": atlas_size,
            "sha256": sha256(atlas_path.read_bytes()).hexdigest(),
        },
        "records": records,
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("spec", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--assets", type=Path, required=True)
    args = parser.parse_args()
    export_fixture(args.source, args.spec, args.assets, args.output)


if __name__ == "__main__":
    main()
