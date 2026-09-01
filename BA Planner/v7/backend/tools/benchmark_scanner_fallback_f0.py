"""Offline F0 measurement; never opens a game or writes profiles/templates."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import time

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.student_candidate_validation import StudentCandidateValidator
from core.student_scan_recognizer import StudentBasicCropSet, StudentBasicRecognizer
from core.student_stats_catalog import student_stat_record
from core.student_weapon_recognizer import StudentWeaponRecognizer
from core.scanner_matchers import ratio_crop
from tools import benchmark_student_studio_text_archive as archive

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "backend/tests/fixtures/scanner_fallback_restoration"
DEFAULT_OUTPUT = ROOT / "docs/migration/scanner-fallback-restoration"


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run(output: Path, screenshots: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    spec = ROOT / "debug/student_suggestion_rois/templates/renderer_spec.json"
    if not spec.is_file():
        raise FileNotFoundError("Existing Studio bank is required; F0 does not regenerate it")
    # The existing archive routine normally calls build(). Use its existing bank,
    # and direct all report output to F0 so no old artifact or template is replaced.
    old = archive.build, archive.REPORT, archive.CONTACT_SHEET, archive.SCREENSHOTS
    try:
        archive.build = lambda: {"spec": str(spec)}
        archive.REPORT = output / "f0-archive.json"
        archive.CONTACT_SHEET = output / "f0-archive.png"
        archive.SCREENSHOTS = screenshots
        report = archive.benchmark()
    finally:
        archive.build, archive.REPORT, archive.CONTACT_SHEET, archive.SCREENSHOTS = old

    diagnostic_path = ROOT / "debug/scan test/ba-planner-student-scan-2026-08-29T00-49-15.526282Z-full.json"
    diagnostic = json.loads(diagnostic_path.read_text(encoding="utf-8"))

    class FrozenRepository:
        def get_state(self, _profile_id):
            return {"students": diagnostic["repository_context"]["confirmed_students"]}

    validator = StudentCandidateValidator(FrozenRepository())
    ranks = {}
    for candidate in diagnostic["candidates"]:
        payload = candidate["payload"]
        rank = payload["values"].get("bond_rank")
        if isinstance(rank, int) and not isinstance(rank, bool) and 1 <= rank <= 100:
            record = student_stat_record(payload["student_id"], catalog=validator.catalog)
            ranks[record.schaledb_id] = rank
    replay = [
        {"candidate_id": row["candidate_id"], "student_id": row["payload"]["student_id"],
         "validation": validator(row["payload"], "frozen-diagnostic-context", ranks)}
        for row in diagnostic["candidates"]
    ]
    write_json(output / "f0-diagnostic-replay.json", {
        "mode": "old_json_revalidation_no_ocr_no_screenshot_corrections",
        "source_sha256": digest(diagnostic_path), "rows": replay,
    })

    catalog = RecognitionAssetCatalog(ROOT / "backend/assets/recognition/v1")
    basic = StudentBasicRecognizer(catalog)
    weapon = StudentWeaponRecognizer(catalog)
    feedback = json.loads((FIXTURE / "feedback1-manifest.json").read_text(encoding="utf-8"))
    frame_rows = []
    try:
        for record in feedback["records"]:
            path = screenshots / "feedback1" / record["source_file"]
            if digest(path) != record["source_sha256"]:
                raise ValueError(f"Feedback source hash mismatch: {path}")
            with Image.open(path) as opened:
                if list(opened.size) != record["source_size"]:
                    raise ValueError(f"Feedback source size mismatch: {path}")
                for scale in (1, 2):
                    frame = opened.convert("RGB")
                    if scale == 2:
                        reduced = frame.resize((frame.width // 2, frame.height // 2), Image.Resampling.LANCZOS)
                        frame.close()
                        frame = reduced
                    try:
                        crop = ratio_crop(frame, weapon.regions["basic_weapon_state_region"])
                        try:
                            # No student-star shortcut: measure the independent flag.
                            state = weapon.read_state(crop, student_star=None)
                        finally:
                            crop.close()
                        truth = record["visual_truth"]
                        frame_rows.append({
                            "source_file": record["source_file"], "student_ref": record["student_ref"],
                            "kind": "original_2560" if scale == 1 else "derived_1280_not_live",
                            "expected_state": truth["weapon_state"], "observed_state": state.value,
                            "state_correct": state.confirmed and state.value == truth["weapon_state"],
                        })
                    finally:
                        frame.close()
    finally:
        weapon.close()

    # The archive tool has no student-level visual series loop. Measure it here,
    # rather than mislabelling its 122 legacy-agreement rows as human truth.
    level_spec = ROOT / "backend/tests/fixtures/student_level_studio_archive_source_spec.json"
    index = archive._file_index() if screenshots == archive.SCREENSHOTS else None
    if index is None:
        index = {}
        for path in screenshots.rglob("*"):
            if path.is_file():
                index.setdefault(path.name, []).append(path)
    resolved = {}
    levels = []
    for record in json.loads(level_spec.read_text(encoding="utf-8"))["records"]:
        path = archive._resolve_source(index, record, resolved)
        with Image.open(path) as opened:
            frame = opened.convert("RGB")
        try:
            crops = StudentBasicCropSet.from_frame(frame, catalog.region("student"))
        finally:
            frame.close()
        try:
            observed = basic.recognize(crops)["level"]
            levels.append({"source_file": record["source_file"], "expected": record["student_level"],
                           "observed": observed.value, "status": observed.status,
                           "correct": observed.confirmed and observed.value == record["student_level"]})
        finally:
            crops.close()

    summary = {
        "schema_version": 1, "measured_at": datetime.now(timezone.utc).isoformat(),
        "duration_seconds": time.monotonic() - started,
        "mode": "offline_archive_existing_bank_and_old_json_revalidation",
        "live_game_inputs": 0, "profile_writes": 0, "template_regeneration": False,
        "renderer_spec_sha256": digest(spec),
        "archive": {key: report[key] for key in (
            "screenshot_files", "resolved_answer_files", "template_count", "unsupported_layouts", "summaries")},
        "diagnostic": {"source_sha256": digest(diagnostic_path), "candidate_count": len(replay),
                       "status_counts": dict(Counter(r["validation"]["status"] for r in replay))},
        "feedback_state_frame_replay": frame_rows,
        "student_level_visual_series": levels,
        "limitations": ["No live game scan or input trace", "Derived 1280 frames are not actual 1280 captures",
                        "Existing bank and validation partition provenance retained; not a newly held-out benchmark",
                        "Archive skips nine one-digit equipment records"],
    }
    write_json(output / "f0-baseline.json", summary)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--screenshots", type=Path, default=Path("C:/Users/brigh/Pictures/Screenshots/BA"))
    args = parser.parse_args()
    result = run(args.output.resolve(), args.screenshots.resolve())
    print(json.dumps({"output": str(args.output), "seconds": result["duration_seconds"],
                      "diagnostic": result["diagnostic"],
                      "feedback_correct": sum(r["state_correct"] for r in result["feedback_state_frame_replay"]),
                      "feedback_total": len(result["feedback_state_frame_replay"]),
                      "level_correct": sum(r["correct"] for r in result["student_level_visual_series"])}))
