from __future__ import annotations

from collections import Counter, defaultdict
from hashlib import sha256
import json
from pathlib import Path
from statistics import mean
from typing import Any

from PIL import Image, ImageDraw, ImageFont, ImageOps

from core.recognition_assets import RecognitionAssetCatalog
from core.studio_roi_suggestion import extract_studio_roi, load_studio_suggestion
from core.student_scan_recognizer import StudentBasicCropSet, StudentBasicRecognizer
from tools.build_student_studio_text_templates import (
    DEBUG,
    ROOT,
    SUGGESTION,
    _best_shift,
    _source_digit_mask,
    build,
)


SCREENSHOTS = Path(r"C:\Users\brigh\Pictures\Screenshots\BA")
ASSETS = ROOT / "backend" / "assets" / "recognition" / "v1"
EQUIPMENT_MANIFESTS = (
    ROOT / "backend" / "tests" / "fixtures" / "student_equipment_s3b_archive" / "manifest.json",
    ROOT / "backend" / "tests" / "fixtures" / "student_equipment_s3b_promotion_probe" / "manifest.json",
)
RELATIONSHIP_MANIFEST = (
    ROOT / "backend" / "tests" / "fixtures" / "student_relationship_s4" / "manifest.json"
)
REPORT = DEBUG / "suggestion_text_archive_benchmark.json"
CONTACT_SHEET = DEBUG / "suggestion_text_archive_comparison.png"
LABEL_FONT = ROOT / "frontend" / "assets" / "fonts" / "GyeonggiTitle-Medium.ttf"


def _digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def _file_index() -> dict[str, list[Path]]:
    result: dict[str, list[Path]] = defaultdict(list)
    for path in SCREENSHOTS.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg"}:
            result[path.name].append(path)
    return result


def _resolve_source(
    index: dict[str, list[Path]],
    record: dict[str, Any],
    cache: dict[tuple[str, str], Path],
) -> Path:
    key = (str(record["source_file"]), str(record["source_sha256"]))
    if key in cache:
        return cache[key]
    matches = [path for path in index.get(key[0], []) if _digest(path) == key[1]]
    if len(matches) != 1:
        raise ValueError(f"source resolution failed for {key[0]}: {len(matches)} hash matches")
    cache[key] = matches[0]
    return matches[0]


def _load_bank(spec: dict[str, Any]) -> dict[str, dict[str, Image.Image]]:
    result: dict[str, dict[str, Image.Image]] = defaultdict(dict)
    for row in spec["templates"]:
        with Image.open(ROOT / row["path"]) as opened:
            result[str(row["roi"])][str(row["digit"])] = opened.convert("L")
    return dict(result)


def _rank(
    source: Image.Image,
    templates: dict[str, Image.Image],
) -> tuple[str, float, float, list[int]]:
    ranked: list[tuple[str, float, int, int]] = []
    for digit, template in templates.items():
        score, dx, dy, shifted = _best_shift(source, template)
        shifted.close()
        ranked.append((digit, score, dx, dy))
    ranked.sort(key=lambda item: item[1], reverse=True)
    first, second = ranked[0], ranked[1]
    return first[0], first[1], first[1] - second[1], [first[2], first[3]]


def _evaluate_value(
    frame: Image.Image,
    *,
    field: str,
    expected: int,
    roi_names: list[str],
    roi_lookup,
    reference_size: tuple[int, int],
    bank: dict[str, dict[str, Image.Image]],
    source_file: str,
    evidence: str,
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    expected_text = str(expected)
    digits: list[dict[str, Any]] = []
    for position, (expected_digit, roi_name) in enumerate(zip(expected_text, roi_names), start=1):
        roi = roi_lookup[roi_name]
        source_roi = extract_studio_roi(frame, roi, reference_size=reference_size)
        source_mask, cleanup = _source_digit_mask(source_roi, field)
        observed, score, margin, shift = _rank(source_mask, bank[roi_name])
        source_roi.close()
        source_mask.close()
        digits.append(
            {
                "position": position,
                "roi": roi_name,
                "expected": expected_digit,
                "observed": observed,
                "correct": observed == expected_digit,
                "score": score,
                "margin": margin,
                "shift": shift,
                "cleanup": cleanup,
            }
        )
    observed_value = int("".join(row["observed"] for row in digits))
    result = {
        "field": field,
        "source_file": source_file,
        "evidence": evidence,
        "expected": expected,
        "observed": observed_value,
        "correct": observed_value == expected,
        "digits": digits,
    }
    if extra:
        result.update(extra)
    return result


def _summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    digits = [digit for row in rows for digit in row["digits"]]
    confusion = Counter(
        f"{digit['expected']}->{digit['observed']}"
        for digit in digits
        if not digit["correct"]
    )
    return {
        "values": len(rows),
        "value_correct": sum(row["correct"] for row in rows),
        "value_accuracy": sum(row["correct"] for row in rows) / len(rows) if rows else 0.0,
        "digits": len(digits),
        "digit_correct": sum(row["correct"] for row in digits),
        "digit_accuracy": sum(row["correct"] for row in digits) / len(digits) if digits else 0.0,
        "minimum_score": min((row["score"] for row in digits), default=0.0),
        "average_score": mean(row["score"] for row in digits) if digits else 0.0,
        "minimum_margin": min((row["margin"] for row in digits), default=0.0),
        "average_margin": mean(row["margin"] for row in digits) if digits else 0.0,
        "confusion": dict(sorted(confusion.items(), key=lambda item: (-item[1], item[0]))),
    }


def _font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(LABEL_FONT), size)


def _mask_panel(mask: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgb = Image.new("RGB", mask.size, "#0C1724")
    rgb.paste("#FFFFFF", mask=mask)
    result = Image.new("RGB", size, "#20364B")
    fitted = ImageOps.contain(rgb, size, Image.Resampling.NEAREST)
    result.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    fitted.close()
    rgb.close()
    return result


def _paste(sheet: Image.Image, draw: ImageDraw.ImageDraw, image: Image.Image, box, label: str) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle(box, radius=8, fill="#20364B", outline="#5D7891")
    draw.text((x1 + 8, y1 + 6), label, font=_font(15), fill="#F1F7FC")
    panel = _mask_panel(image, (x2 - x1 - 12, y2 - y1 - 34))
    sheet.paste(panel, (x1 + 6, y1 + 28))
    panel.close()


def _contact_sheet(
    rows: list[dict[str, Any]],
    sources: dict[str, Path],
    roi_lookup,
    reference_size: tuple[int, int],
    bank: dict[str, dict[str, Image.Image]],
) -> None:
    failures = [row for row in rows if not row["correct"]]
    successes = [row for row in rows if row["correct"]]
    selected = failures[:10] + successes[:6]
    maximum_digits = max((len(row["digits"]) for row in selected), default=2)
    width, header, row_height = max(1500, 24 + maximum_digits * 3 * 196 + 260), 92, 158
    sheet = Image.new("RGB", (width, header + row_height * len(selected)), "#14263A")
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 14), "BA archive - Studio white template replay", font=_font(28), fill="#F1F7FC")
    draw.text(
        (24, 50),
        "For each position: cleaned digit | expected template | selected template",
        font=_font(16), fill="#AFC3D5",
    )
    try:
        for index, row in enumerate(selected):
            y = header + index * row_height
            color = "#64E6B1" if row["correct"] else "#FF7084"
            draw.text(
                (24, y + 4),
                f"{row['field']}  {row['expected']} -> {row['observed']}  {row['source_file']}",
                font=_font(16), fill=color,
            )
            with Image.open(sources[row["source_file"]]) as opened:
                frame = opened.convert("RGBA")
            images: list[Image.Image] = []
            try:
                for digit in row["digits"]:
                    roi = roi_lookup[digit["roi"]]
                    source_roi = extract_studio_roi(frame, roi, reference_size=reference_size)
                    source_mask, _cleanup = _source_digit_mask(source_roi, row["field"])
                    source_roi.close()
                    images.extend(
                        [
                            source_mask,
                            bank[digit["roi"]][digit["expected"]],
                            bank[digit["roi"]][digit["observed"]],
                        ]
                    )
                for column, image in enumerate(images):
                    labels = ("Cleaned", "Expected", "Selected")
                    x = 24 + column * 196
                    _paste(sheet, draw, image, (x, y + 30, x + 184, y + 150), labels[column % 3])
                minimum_score = min(digit["score"] for digit in row["digits"])
                minimum_margin = min(digit["margin"] for digit in row["digits"])
                draw.text((1210, y + 54), f"score {minimum_score:.3f}", font=_font(15), fill="#BFD0DF")
                draw.text((1210, y + 82), f"margin {minimum_margin:.3f}", font=_font(15), fill="#BFD0DF")
                draw.text((1210, y + 110), row["evidence"], font=_font(14), fill="#FFD166")
            finally:
                for image_index, image in enumerate(images):
                    if image_index % 3 == 0:
                        image.close()
                frame.close()
    finally:
        sheet.save(CONTACT_SHEET)
        sheet.close()


def benchmark() -> dict[str, Any]:
    build_result = build()
    spec = json.loads(Path(build_result["spec"]).read_text(encoding="utf-8"))
    bank = _load_bank(spec)
    suggestion = load_studio_suggestion(SUGGESTION)
    roi_lookup = {roi.name: roi for roi in suggestion.rois}
    index = _file_index()
    resolved: dict[tuple[str, str], Path] = {}
    source_by_name: dict[str, Path] = {}
    equipment_records: list[dict[str, Any]] = []
    for manifest_path in EQUIPMENT_MANIFESTS:
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        for record in payload["records"]:
            if record.get("review_status") != "visual_verified":
                continue
            path = _resolve_source(index, record, resolved)
            source_by_name[str(record["source_file"])] = path
            equipment_records.append(record)
    relationship_payload = json.loads(RELATIONSHIP_MANIFEST.read_text(encoding="utf-8"))
    relationship_records: list[dict[str, Any]] = []
    for record in relationship_payload["records"]:
        if record.get("review_status") != "visual_verified":
            continue
        path = _resolve_source(index, record, resolved)
        source_by_name[str(record["source_file"])] = path
        relationship_records.append(record)

    ground_truth: list[dict[str, Any]] = []
    unsupported = Counter()
    equipment_by_source: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in equipment_records:
        equipment_by_source[str(record["source_file"])].append(record)
    for source_file, records in equipment_by_source.items():
        with Image.open(source_by_name[source_file]) as opened:
            frame = opened.convert("RGBA")
        try:
            for record in records:
                value = int(record["expected_value"])
                if len(str(value)) != 2:
                    unsupported["equipment_one_digit"] += 1
                    continue
                slot = int(record["slot"])
                ground_truth.append(
                    _evaluate_value(
                        frame,
                        field="equipment_level",
                        expected=value,
                        roi_names=[f"equip{slot}level_digit1", f"equip{slot}level_digit2"],
                        roi_lookup=roi_lookup,
                        reference_size=suggestion.reference_size,
                        bank=bank,
                        source_file=source_file,
                        evidence="visual_verified",
                        extra={"slot": slot, "tier": record["tier"]},
                    )
                )
        finally:
            frame.close()
    for record in relationship_records:
        rank = int(record["rank"])
        digit_count = len(str(rank))
        if digit_count == 1:
            roi_names = ["affectionlevel_1digit_digit1"]
        elif digit_count == 2:
            roi_names = ["affectionlevel_digit1", "affectionlevel_digit2"]
        elif digit_count == 3:
            roi_names = [
                "affectionlevel_3digit_digit1",
                "affectionlevel_3digit_digit2",
                "affectionlevel_3digit_digit3",
            ]
        else:
            unsupported[f"relationship_{digit_count}_digit"] += 1
            continue
        source_file = str(record["source_file"])
        with Image.open(source_by_name[source_file]) as opened:
            frame = opened.convert("RGBA")
        try:
            ground_truth.append(
                _evaluate_value(
                    frame,
                    field="relationship_rank",
                    expected=rank,
                    roi_names=roi_names,
                    roi_lookup=roi_lookup,
                    reference_size=suggestion.reference_size,
                    bank=bank,
                    source_file=source_file,
                    evidence="visual_verified",
                    extra={"partition": record["partition"], "layout_digit_count": digit_count},
                )
            )
        finally:
            frame.close()

    catalog = RecognitionAssetCatalog(ASSETS)
    basic = StudentBasicRecognizer(catalog)
    regions = catalog.region("student")
    agreement: list[dict[str, Any]] = []
    for source_file in sorted(equipment_by_source):
        with Image.open(source_by_name[source_file]) as opened:
            rgb = opened.convert("RGB")
        crops = StudentBasicCropSet.from_frame(rgb, regions)
        rgb.close()
        try:
            legacy = {
                "student_level": basic.read_level(crops.images.get("basic_level_digits_quad")),
                "weapon_level": basic.read_weapon_level(crops.images.get("basic_weapon_level_digits_quad")),
            }
            with Image.open(source_by_name[source_file]) as opened:
                frame = opened.convert("RGBA")
            try:
                for field, observation in legacy.items():
                    if not observation.confirmed or len(str(observation.value)) != 2:
                        continue
                    prefix = "studentlevel" if field == "student_level" else "weaponlevel"
                    agreement.append(
                        _evaluate_value(
                            frame,
                            field=field,
                            expected=int(observation.value),
                            roi_names=[f"{prefix}_digit1", f"{prefix}_digit2"],
                            roi_lookup=roi_lookup,
                            reference_size=suggestion.reference_size,
                            bank=bank,
                            source_file=source_file,
                            evidence="legacy_confirmed_agreement",
                        )
                    )
            finally:
                frame.close()
        finally:
            crops.close()
    fields = sorted({row["field"] for row in (*ground_truth, *agreement)})
    summaries = {
        field: {
            "visual_ground_truth": _summary([row for row in ground_truth if row["field"] == field]),
            "legacy_agreement": _summary([row for row in agreement if row["field"] == field]),
        }
        for field in fields
    }
    relationship_ground_truth = [
        row for row in ground_truth if row["field"] == "relationship_rank"
    ]
    summaries["relationship_rank"]["visual_ground_truth"]["layouts"] = {
        str(digit_count): _summary([
            row
            for row in relationship_ground_truth
            if int(row["layout_digit_count"]) == digit_count
        ])
        for digit_count in (1, 2, 3)
    }
    report = {
        "schema_version": 1,
        "screenshot_root": str(SCREENSHOTS),
        "screenshot_files": sum(len(paths) for paths in index.values()),
        "resolved_answer_files": len(resolved),
        "template_count": len(spec["templates"]),
        "method": "Studio points + field foreground cleanup + white per-position digit bank + +/-2px IoU",
        "unsupported_layouts": dict(unsupported),
        "summaries": summaries,
        "visual_ground_truth_rows": ground_truth,
        "legacy_agreement_rows": agreement,
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    _contact_sheet(
        [*ground_truth, *agreement],
        source_by_name,
        roi_lookup,
        suggestion.reference_size,
        bank,
    )
    for templates in bank.values():
        for image in templates.values():
            image.close()
    return report


def main() -> None:
    report = benchmark()
    print(json.dumps({
        "screenshot_files": report["screenshot_files"],
        "resolved_answer_files": report["resolved_answer_files"],
        "unsupported_layouts": report["unsupported_layouts"],
        "summaries": report["summaries"],
        "report": str(REPORT),
        "contact_sheet": str(CONTACT_SHEET),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
