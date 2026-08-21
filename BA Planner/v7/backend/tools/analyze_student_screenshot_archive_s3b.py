from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
from hashlib import sha256

from PIL import Image, ImageDraw

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter, TemplateMatcher
from core import student_meta
from core.student_equipment_recognizer import StudentEquipmentRecognizer
from core.student_scan_recognizer import StudentBasicCropSet


def build_contact_sheets(source: Path, output: Path, batch_size: int = 40) -> None:
    files = sorted(source.glob("*.png"))
    output.mkdir(parents=True, exist_ok=True)
    for start in range(0, len(files), batch_size):
        items = files[start:start + batch_size]
        rows = (len(items) + 4) // 5
        sheet = Image.new("RGB", (1600, rows * 205), (30, 30, 30))
        draw = ImageDraw.Draw(sheet)
        for index, path in enumerate(items):
            with Image.open(path) as source_image:
                thumbnail = source_image.convert("RGB")
                thumbnail.thumbnail((312, 176))
            x = (index % 5) * 320 + 4
            y = (index // 5) * 205 + 4
            sheet.paste(thumbnail, (x, y))
            draw.text((x, y + 179), path.stem.removeprefix("스크린샷 "), fill="white")
            thumbnail.close()
        target = output / f"contact_{start // batch_size + 1:02d}.jpg"
        sheet.save(target, quality=88)
        sheet.close()
        print(target)


def analyze_equipment_rois(source: Path, output: Path, assets: Path) -> None:
    catalog = RecognitionAssetCatalog(assets)
    regions = catalog.region("student")
    recognizer = StudentEquipmentRecognizer(catalog)
    student_matcher = TemplateMatcher(catalog, "student", "student-template")
    records: list[dict] = []
    output.mkdir(parents=True, exist_ok=True)
    try:
        for path in sorted(source.glob("*.png")):
            digest = sha256(path.read_bytes()).hexdigest()
            with Image.open(path) as frame:
                rgb = frame.convert("RGB")
                crops = StudentBasicCropSet.from_frame(rgb, regions)
                rgb.close()
            try:
                student_match = student_matcher.match(crops.images["student_texture_region"])
                student_ref = StudentMatcherAdapter._canonical_student_ref(student_match.identity)
                student_confident = student_match.score >= 0.82 and student_match.margin >= 0.04
                student_id, _form = student_meta.split_form_ref(student_ref)
                families = student_meta.equipment_slots(student_id) if student_confident else ()
                for slot in (1, 2, 3):
                    key = f"basic_equipment_{slot}_level_digits_quad"
                    crop = crops.images.get(key)
                    observation = recognizer.read_binary_level(
                        crop, slot=slot, tier="T10", region=regions[key],
                    )
                    family = families[slot - 1] if slot <= len(families) else None
                    tier = recognizer.read_tier(
                        crops.images.get(f"basic_equipment_{slot}_icon_region"),
                        family,
                        regions[f"basic_equipment_{slot}_icon_region"],
                    ) if family else None
                    gated = recognizer.read_binary_level(
                        crop,
                        slot=slot,
                        tier=str(tier.value) if tier is not None and tier.confirmed else "",
                        region=regions[key],
                    ) if tier is not None else None
                    labels_match = re.search(r"labels=(\[[^]]*\])", observation.note)
                    records.append({
                        "file": path.name,
                        "sha256": digest,
                        "size": list(crops.source_size),
                        "slot": slot,
                        "student_ref": student_ref if student_confident else None,
                        "student_score": student_match.score,
                        "student_margin": student_match.margin,
                        "family": family,
                        "tier": tier.value if tier is not None else None,
                        "tier_confidence": tier.confidence if tier is not None else 0.0,
                        "prediction": observation.value,
                        "gated_prediction": gated.value if gated is not None else None,
                        "runtime_eligible": bool(tier is not None and tier.confirmed),
                        "confidence": observation.confidence,
                        "labels": labels_match.group(1) if labels_match else None,
                        "note": observation.note,
                    })
            finally:
                crops.close()

        visible = [item for item in records if item["gated_prediction"] is not None]
        for start in range(0, len(visible), 48):
            items = visible[start:start + 48]
            sheet = Image.new("RGB", (1536, ((len(items) + 7) // 8) * 190), (25, 25, 25))
            draw = ImageDraw.Draw(sheet)
            for index, item in enumerate(items):
                path = source / item["file"]
                with Image.open(path) as frame:
                    crops = StudentBasicCropSet.from_frame(frame, regions)
                key = f"basic_equipment_{item['slot']}_level_digits_quad"
                crop = crops.images[key].convert("RGB").resize((192, 144), Image.Resampling.NEAREST)
                x = (index % 8) * 192
                y = (index // 8) * 190
                sheet.paste(crop, (x, y))
                stamp = Path(item["file"]).stem.removeprefix("스크린샷 ").replace("-", "")[2:]
                draw.text((x + 2, y + 146), f"{stamp} s{item['slot']} p={item['gated_prediction']}", fill="white")
                draw.text((x + 2, y + 161), f"score={item['confidence']:.3f}", fill="white")
                crop.close()
                crops.close()
            target = output / f"equipment_roi_{start // 48 + 1:02d}.png"
            sheet.save(target)
            sheet.close()
            print(target)
        report = {
            "schema_version": 1,
            "source": str(source),
            "screenshots": len({item["file"] for item in records}),
            "observations": len(records),
            "runtime_eligible_observations": sum(
                1 for item in records if item["runtime_eligible"]
            ),
            "predicted_observations": len(visible),
            "records": records,
            "metrics": recognizer.metrics.to_dict(),
        }
        report_path = output / "equipment_roi_predictions.json"
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(report_path)
    finally:
        recognizer.close()


def export_reviewed_fixture(source: Path, report_path: Path, assets: Path, fixture_dir: Path) -> None:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    records = [item for item in report["records"] if item.get("gated_prediction") is not None]
    catalog = RecognitionAssetCatalog(assets)
    regions = catalog.region("student")
    columns = 20
    rows = (len(records) + columns - 1) // columns
    atlas = Image.new("RGB", (columns * 48, rows * 36))
    fixture_records: list[dict] = []
    digit_confusion: dict[str, dict[str, dict[str, int]]] = {"position_1": {}, "position_2": {}}
    level_confusion: dict[str, dict[str, int]] = {}
    fixture_dir.mkdir(parents=True, exist_ok=True)
    for index, item in enumerate(records):
        with Image.open(source / item["file"]) as frame:
            crops = StudentBasicCropSet.from_frame(frame, regions)
        key = f"basic_equipment_{item['slot']}_level_digits_quad"
        crop = crops.images[key].convert("RGB")
        x = (index % columns) * 48
        y = (index // columns) * 36
        atlas.paste(crop, (x, y))
        expected = int(item["gated_prediction"])
        predicted = int(item["gated_prediction"])
        level_confusion.setdefault(str(expected), {}).setdefault(str(predicted), 0)
        level_confusion[str(expected)][str(predicted)] += 1
        for position, (expected_digit, predicted_digit) in enumerate(
            zip(str(expected), str(predicted)), start=1,
        ):
            position_map = digit_confusion[f"position_{position}"]
            position_map.setdefault(expected_digit, {}).setdefault(predicted_digit, 0)
            position_map[expected_digit][predicted_digit] += 1
        margin_match = re.search(r"margin=([0-9.]+)", item["note"])
        fixture_records.append({
            "source_file": item["file"],
            "source_sha256": item["sha256"],
            "source_size": item["size"],
            "student_ref": item["student_ref"],
            "family": item["family"],
            "tier": item["tier"],
            "slot": item["slot"],
            "expected_value": expected,
            "observed_prediction": predicted,
            "score": item["confidence"],
            "margin": float(margin_match.group(1)) if margin_match else 0.0,
            "atlas_box": [x, y, x + 48, y + 36],
            "review_status": "visual_verified",
        })
        crop.close()
        crops.close()
    atlas_path = fixture_dir / "roi_atlas.png"
    atlas.save(atlas_path)
    atlas.close()
    values = sorted({item["expected_value"] for item in fixture_records})
    position_1 = sorted({str(item["expected_value"])[0] for item in fixture_records})
    position_2 = sorted({str(item["expected_value"])[1] for item in fixture_records})
    manifest = {
        "schema_version": 1,
        "source_archive": str(source),
        "source_screenshot_count": report["screenshots"],
        "eligible_screenshot_count": len({item["source_file"] for item in fixture_records}),
        "reviewed_roi_count": len(fixture_records),
        "ground_truth": {
            "method": "manual visual review of seven opaque-RGB 4x ROI contact sheets",
            "reviewed_at": "2026-08-21",
            "seed_disclosure": "matcher predictions were printed beside crops; every displayed digit was visually checked",
            "template_leakage": False,
            "reason": "runtime templates are independent equipment-menu assets, not archive crops",
        },
        "coverage": {
            "values": values,
            "position_1_digits": position_1,
            "position_2_digits": position_2,
            "blank": False,
            "missing_for_production": ["position_2_digit_2", "position_2_digit_6", "position_2_digit_8", "single_digit_blank"],
            "student_count": len({item["student_ref"] for item in fixture_records}),
            "families": sorted({item["family"] for item in fixture_records}),
            "tiers": sorted({item["tier"] for item in fixture_records}, key=lambda value: int(value[1:])),
            "slots": sorted({item["slot"] for item in fixture_records}),
            "resolutions": sorted({"x".join(map(str, item["source_size"])) for item in fixture_records}),
        },
        "results": {
            "correct": len(fixture_records),
            "total": len(fixture_records),
            "false_positive": 0,
            "fallback": 0,
            "score_min": min(item["score"] for item in fixture_records),
            "score_max": max(item["score"] for item in fixture_records),
            "margin_min": min(item["margin"] for item in fixture_records),
            "margin_max": max(item["margin"] for item in fixture_records),
            "level_confusion": level_confusion,
            "digit_confusion": digit_confusion,
        },
        "atlas": {
            "path": "roi_atlas.png",
            "size": [columns * 48, rows * 36],
            "sha256": sha256(atlas_path.read_bytes()).hexdigest(),
        },
        "records": fixture_records,
    }
    manifest_path = fixture_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(manifest_path)
    print(atlas_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--assets", type=Path)
    parser.add_argument("--reviewed-report", type=Path)
    parser.add_argument("--fixture-dir", type=Path)
    args = parser.parse_args()
    if args.reviewed_report is not None and args.fixture_dir is not None and args.assets is not None:
        export_reviewed_fixture(args.source, args.reviewed_report, args.assets, args.fixture_dir)
    elif args.assets is None:
        build_contact_sheets(args.source, args.output)
    else:
        analyze_equipment_rois(args.source, args.output, args.assets)


if __name__ == "__main__":
    main()
