from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import StudentEquipmentRecognizer
from core.student_scan_recognizer import StudentBasicCropSet


FAMILY_ORDER = ("Hat", "Gloves", "Shoes", "Bag", "Badge", "Hairpin", "Charm", "Watch", "Necklace")


def build(spec_path: Path, assets: Path, output_dir: Path) -> None:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    catalog = RecognitionAssetCatalog(assets)
    regions = catalog.region("student")
    gathered: dict[tuple[str, str], tuple[Image.Image, dict[str, object]]] = {}
    for dataset in spec["datasets"]:
        source_root = Path(dataset["source_folder"])
        families = dataset["families"]
        rows = dataset["screenshots"]
        if len(families) != 3 or len(rows) != 10:
            raise ValueError("each dataset must contain three families and T1-T10")
        for number, (filename, expected_hash) in enumerate(rows, start=1):
            path = source_root / filename
            digest = sha256(path.read_bytes()).hexdigest()
            if digest != expected_hash:
                raise ValueError(f"source hash mismatch: {filename}")
            with Image.open(path) as opened:
                frame = opened.convert("RGB")
                if frame.size != (1280, 720):
                    raise ValueError(f"exact 1280x720 required: {filename}: {frame.size}")
                crops = StudentBasicCropSet.from_frame(frame, regions)
            try:
                for slot, family in enumerate(families, start=1):
                    region = regions[f"basic_equipment_{slot}_icon_region"]
                    inner = StudentEquipmentRecognizer._inner_icon(
                        crops.images[f"basic_equipment_{slot}_icon_region"], region,
                    ).convert("RGB")
                    if inner.size != (70, 40):
                        raise ValueError(f"unexpected inner ROI size: {filename}: {inner.size}")
                    key = (family, f"T{number}")
                    if key in gathered:
                        raise ValueError(f"duplicate tier ROI: {key}")
                    gathered[key] = (inner, {
                        "source_file": filename,
                        "source_sha256": digest,
                        "student_ref": dataset["student_ref"],
                        "slot": slot,
                    })
            finally:
                crops.close()
    expected = {(family, f"T{tier}") for family in FAMILY_ORDER for tier in range(1, 11)}
    if set(gathered) != expected:
        raise ValueError(f"tier bank coverage mismatch: missing={sorted(expected - set(gathered))}")
    output_dir.mkdir(parents=True, exist_ok=True)
    atlas_path = output_dir / "basic_tier_inner_rois.png"
    metadata_path = output_dir / "basic_tier_inner_rois.json"
    atlas = Image.new("RGB", (10 * 70, len(FAMILY_ORDER) * 40))
    records = []
    for row, family in enumerate(FAMILY_ORDER):
        for column, number in enumerate(range(1, 11)):
            tier = f"T{number}"
            crop, provenance = gathered[(family, tier)]
            x, y = column * 70, row * 40
            atlas.paste(crop, (x, y))
            records.append({
                "family": family, "tier": tier, "atlas_box": [x, y, x + 70, y + 40],
                **provenance,
            })
            crop.close()
    atlas.save(atlas_path, optimize=True)
    atlas.close()
    metadata = {
        "schema_version": 1,
        "source": "actual exact-1280x720 basic-screen inner icon ROIs",
        "validation_policy": spec["validation_policy"],
        "roi_size": [70, 40],
        "template_count": len(records),
        "families": list(FAMILY_ORDER),
        "tiers": [f"T{number}" for number in range(1, 11)],
        "atlas_path": "templates/student_equipment/basic_tier_inner_rois.png",
        "atlas_sha256": sha256(atlas_path.read_bytes()).hexdigest(),
        "records": records,
    }
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("spec", type=Path)
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    build(args.spec, args.assets, args.output_dir)


if __name__ == "__main__":
    main()
