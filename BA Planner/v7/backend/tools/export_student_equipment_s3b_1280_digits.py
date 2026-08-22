from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path

from PIL import Image

from core import student_meta
from core.recognition_assets import RecognitionAssetCatalog
from core.student_scan_recognizer import StudentBasicCropSet


def export_digits(source: Path, spec_path: Path, assets: Path, output: Path) -> None:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    rows = spec.get("screenshots")
    if not isinstance(rows, list) or not rows:
        raise ValueError("digit probe spec must contain screenshots")
    catalog = RecognitionAssetCatalog(assets)
    regions = catalog.region("student")
    records: list[dict[str, object]] = []
    atlas = Image.new("RGB", (6 * 48, ((len(rows) * 3 + 5) // 6) * 36))
    for row in rows:
        path = source / str(row["file"])
        digest = sha256(path.read_bytes()).hexdigest()
        if digest != row["sha256"]:
            raise ValueError(f"source hash mismatch: {path.name}")
        expected = row.get("expected")
        if not isinstance(expected, list) or len(expected) != 3:
            raise ValueError(f"three expected levels required: {path.name}")
        student_ref = str(row["student_ref"])
        student_id, _form = student_meta.split_form_ref(student_ref)
        families = student_meta.equipment_slots(student_id)
        with Image.open(path) as frame:
            crops = StudentBasicCropSet.from_frame(frame.convert("RGB"), regions)
        try:
            expected_size = tuple(row["source_size"])
            if crops.source_size != expected_size:
                raise ValueError(f"source size mismatch: {path.name}: {crops.source_size}")
            for slot, expected_value in enumerate(expected, start=1):
                crop = crops.images[f"basic_equipment_{slot}_level_digits_quad"]
                index = len(records)
                x, y = (index % 6) * 48, (index // 6) * 36
                atlas.paste(crop.convert("RGB"), (x, y))
                records.append({
                    "source_file": path.name,
                    "source_sha256": digest,
                    "source_size": list(crops.source_size),
                    "evidence_class": row["evidence_class"],
                    "student_ref": student_ref,
                    "family": families[slot - 1],
                    "tier": str(row["tiers"][slot - 1]),
                    "slot": slot,
                    "expected_value": int(expected_value),
                    "atlas_box": [x, y, x + 48, y + 36],
                    "review_status": "visual_verified",
                })
        finally:
            crops.close()
    output.mkdir(parents=True, exist_ok=True)
    atlas_path = output / "roi_atlas.png"
    atlas.save(atlas_path)
    atlas.close()
    exact = [record for record in records if record["evidence_class"] == "exact_1280x720"]
    with Image.open(atlas_path) as atlas_check:
        atlas_size = list(atlas_check.size)
    manifest = {
        "schema_version": 1,
        "reviewed_at": spec["reviewed_at"],
        "source_screenshot_count": len(rows),
        "reviewed_roi_count": len(records),
        "exact_1280x720_roi_count": len(exact),
        "ground_truth": {
            "method": "manual visual review of the user-supplied equipment levels",
            "template_leakage": False,
            "runtime_assets_contain_source_pixels": False,
        },
        "coverage": {
            "exact_1280x720_values": sorted({int(record["expected_value"]) for record in exact}),
            "exact_1280x720_ones_digits": sorted({int(record["expected_value"]) % 10 for record in exact}),
            "slots": [1, 2, 3],
            "tiers": sorted({str(record["tier"]) for record in exact}),
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
    export_digits(args.source, args.spec, args.assets, args.output)


if __name__ == "__main__":
    main()
