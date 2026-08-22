from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path

from PIL import Image

from core import student_meta
from core.recognition_assets import RecognitionAssetCatalog
from core.student_scan_recognizer import StudentBasicCropSet


def export_probe(source: Path, spec_path: Path, assets: Path, output: Path) -> None:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    rows = spec.get("screenshots")
    if not isinstance(rows, list) or len(rows) != 6:
        raise ValueError("promotion probe spec must contain the six reviewed screenshots")
    catalog = RecognitionAssetCatalog(assets)
    regions = catalog.region("student")
    records: list[dict[str, object]] = []
    columns = 9
    atlas = Image.new("RGB", (columns * 48, 2 * 36))
    for screenshot_index, row in enumerate(rows):
        path = source / str(row["file"])
        digest = sha256(path.read_bytes()).hexdigest()
        if digest != row["sha256"]:
            raise ValueError(f"source hash mismatch: {path.name}")
        expected = row.get("expected")
        if not isinstance(expected, list) or len(expected) != 3:
            raise ValueError(f"expected levels missing: {path.name}")
        student_ref = str(row["expected_student"])
        student_id, _form = student_meta.split_form_ref(student_ref)
        families = student_meta.equipment_slots(student_id)
        tier = "T1" if screenshot_index < 3 else "T2"
        with Image.open(path) as frame:
            crops = StudentBasicCropSet.from_frame(frame.convert("RGB"), regions)
        try:
            for slot, expected_value in enumerate(expected, start=1):
                crop = crops.images[f"basic_equipment_{slot}_level_digits_quad"]
                index = len(records)
                x = (index % columns) * 48
                y = (index // columns) * 36
                atlas.paste(crop.convert("RGB"), (x, y))
                records.append({
                    "source_file": path.name,
                    "source_sha256": digest,
                    "source_size": list(crops.source_size),
                    "student_ref": student_ref,
                    "family": families[slot - 1],
                    "tier": tier,
                    "slot": slot,
                    "expected_value": int(expected_value),
                    "atlas_box": [x, y, x + 48, y + 36],
                    "review_status": "visual_verified",
                })
        finally:
            crops.close()
    output.mkdir(parents=True, exist_ok=True)
    atlas_path = output / "roi_atlas.png"
    atlas_size = list(atlas.size)
    atlas.save(atlas_path)
    atlas.close()
    manifest = {
        "schema_version": 1,
        "reviewed_at": spec["reviewed_at"],
        "source_screenshot_count": len(rows),
        "reviewed_roi_count": len(records),
        "ground_truth": {
            "method": "manual visual review of six exact 2560x1440 screenshots",
            "template_leakage": False,
            "reason": "generated text templates do not contain pixels from validation captures",
        },
        "coverage": {
            "values": sorted({int(record["expected_value"]) for record in records}),
            "single_digit_values": [1, 8, 9],
            "two_digit_values": [12, 16, 18],
            "students": sorted({str(record["student_ref"]) for record in records}),
            "tiers": ["T1", "T2"],
            "slots": [1, 2, 3],
            "resolutions": ["2560x1440"],
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
    print(json.dumps({"screenshots": len(rows), "rois": len(records)}, sort_keys=True))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("spec", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--assets", type=Path, required=True)
    args = parser.parse_args()
    export_probe(args.source, args.spec, args.assets, args.output)


if __name__ == "__main__":
    main()
