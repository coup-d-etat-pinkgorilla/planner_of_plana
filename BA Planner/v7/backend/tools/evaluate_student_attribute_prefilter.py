"""One fixed-public-sample off/on observation using the current recognizer.

Human attribute truth and existing identity labels are used only by metrics.
Synthetic truth is excluded: synthetic = tool tests only. No O3 promotion.
"""

import argparse
import copy
from datetime import datetime, timezone
import json
from pathlib import Path
import platform

from tools.student_attribute_truth import ROOT, digest, load_approved_truth, public_path


PUBLIC_SAMPLES = (
    ("F8A001", "mika.png", "661e64a533a0993a9c51204381da9dc4b7a839f4ec9c57c4c34d19e59ac04cf8"),
    ("F8A002", "hoshino-form1.png", "8ea3effd149a5b766b0e3d757cdaf23815e947f9c6243ec88bc98138c90a4ca6"),
    ("F8A003", "hoshino-form2.png", "48ae0272bad1dfedeebfb8346c88fa3c0aecab28a57ff1199b4b2129b91b6b63"),
)
FROZEN_FILES = (
    "backend/core/runtime_paths.py", "backend/core/student_attribute_filter.py", "backend/core/student_identity_recovery.py",
    "backend/core/student_matcher_adapter.py", "backend/core/scanner_matching.py",
    "backend/core/recognition_image_ops.py", "backend/core/recognition_thresholds.py",
    "backend/core/student_scan_recognizer.py", "backend/core/student_meta.py",
    "backend/core/student_meta_data.py", "backend/core/student_name_matcher.py",
    "backend/core/scanner_protocol_v1.py", "backend/core/scanner_session.py",
    "backend/core/windows_scanner_adapter.py", "backend/tests/test_student_selected_filters.py",
    "backend/data/metadata/v1/student_catalog.json",
    "backend/assets/recognition/spec/student-attribute-prefilter-v1.json",
    "backend/assets/recognition/v1/regions/student_identity_regions.json",
    "backend/assets/recognition/v1/student_identity_manifest.json",
    "backend/tools/student_attribute_truth.py", "backend/tools/evaluate_student_attribute_prefilter.py",
)


def source_freeze():
    return {path: digest(public_path(path).read_bytes()) for path in FROZEN_FILES}


def infer_public_samples():
    """Recognition receives pixels/mode only, never truth values or expected IDs."""
    from PIL import Image, __version__ as pillow_version
    from core.recognition_assets import RecognitionAssetCatalog
    from core.scanner_matching import TemplateMatcher
    from core.student_identity_recovery import StudentIdentityRecognizer
    from core.student_matcher_adapter import StudentMatcherAdapter
    from core import recognition_thresholds as rt
    from core.runtime_paths import resolve_metadata_catalog_path, resolve_recognition_asset_dir

    class AttributesOff(StudentIdentityRecognizer):
        def attributes(self, frame):
            # Evaluator-local ablation: bypass only the five-axis image reader.
            # All ranking, thresholds, global authority and form guards are real.
            return {}

    catalog = RecognitionAssetCatalog()
    texture_region = catalog.region("student")["student_texture_region"]
    predictions = {"off": [], "on": []}
    input_hashes = {}
    for oid, filename, expected_sha in PUBLIC_SAMPLES:
        path = public_path(f"backend/tests/fixtures/student_identity_f8_live/{filename}")
        data = path.read_bytes()
        if digest(data) != expected_sha:
            raise ValueError("fixed public PNG changed before inference")
        input_hashes[oid] = expected_sha
    # Same fixed pixels, catalog and runtime thresholds; one inference per mode/frame.
    for mode, recognizer_type in (("off", AttributesOff), ("on", StudentIdentityRecognizer)):
        reader = recognizer_type(catalog)
        matcher = TemplateMatcher(catalog, "student", "student-template")
        try:
            for oid, filename, _sha in PUBLIC_SAMPLES:
                path = public_path(f"backend/tests/fixtures/student_identity_f8_live/{filename}")
                with Image.open(path) as frame:
                    if frame.size != (1280, 720):
                        raise ValueError("fixed public sample dimensions changed")
                    result = reader.identify(
                        frame, matcher, texture_region, StudentMatcherAdapter._canonical_student_ref,
                        rt.value("student.identity.template.score"),
                        rt.value("student.identity.template.margin"),
                    )
                note = copy.deepcopy(reader.last_filter_evidence)
                # Top-1 is the pipeline's selected full-form candidate, before
                # status gating: resolved form, effective conditional winner,
                # or the global winner when no effective filter remains.
                match = (note["conditional_match"] if note["final_candidate_filter_applied"]
                         and note["conditional_match"] else note["global_match"])
                top1 = result.student_ref if result is not None else (match or {}).get("student_ref")
                predictions[mode].append({
                    "observation_id": oid, "source_png_sha256": input_hashes[oid],
                    "top1_student_ref": top1,
                    "final_student_ref": None if result is None else result.student_ref,
                    "identity_source": None if result is None else result.source,
                    "filter_evidence": note,
                })
        finally:
            reader.close()
            if callable(getattr(matcher, "close", None)):
                matcher.close()
    metadata_path = resolve_metadata_catalog_path()
    return predictions, {
        "python": platform.python_version(), "Pillow": pillow_version,
        "metadata_path": str(metadata_path), "metadata_sha256": digest(metadata_path.read_bytes()),
        "recognition_asset_dir": str(resolve_recognition_asset_dir()),
    }


def evaluate(truth_path):
    before = source_freeze()
    predictions, environment = infer_public_samples()
    # Only after prediction is complete do metrics read expected human labels.
    truth = load_approved_truth(truth_path)
    samples = {sample["observation_id"]: sample for sample in truth["samples"]}
    attributes = {(row["review"]["observation_id"], row["review"]["axis"]):
                  row["approved_truth_value"] for row in truth["observations"]}
    metrics = {}
    for mode, rows in predictions.items():
        for row in rows:
            oid = row["observation_id"]
            expected = samples[oid]["student_ref_for_metrics_only"]
            note = row["filter_evidence"]
            row["expected_student_ref_for_metrics_only"] = expected
            row["correct_candidate_dropped_before_fallback"] = bool(
                note["used_attributes"] and expected not in note["proposed_refs"])
            row["top1_correct"] = row["top1_student_ref"] == expected
            row["final_status"] = ("unconfirmed" if row["final_student_ref"] is None
                                   else "correct" if row["final_student_ref"] == expected else "wrong")
            row["human_attribute_comparison_for_metrics_only"] = {
                axis: {"approved_truth_value": attributes[oid, axis],
                       "observed": observed.get("value"), "top_value": observed.get("top_value"),
                       "accepted": observed.get("accepted"),
                       "accepted_value_agrees": (None if not observed.get("accepted")
                                                 else observed.get("value") == attributes[oid, axis])}
                for axis, observed in note["attribute_observations"].items()
                if (oid, axis) in attributes
            }
        metrics[mode] = {
            "correct_candidate_dropped": sum(row["correct_candidate_dropped_before_fallback"] for row in rows),
            "final_wrong": sum(row["final_status"] == "wrong" for row in rows),
            "top1_correct": sum(row["top1_correct"] for row in rows),
            "unconfirmed": sum(row["final_status"] == "unconfirmed" for row in rows),
        }
    after = source_freeze()
    if before != after:
        raise ValueError("candidate/source changed during the fixed public evaluation")
    off, on = metrics["off"], metrics["on"]
    passed = (on["correct_candidate_dropped"] == 0 and on["final_wrong"] == 0
              and on["top1_correct"] >= off["top1_correct"]
              and on["unconfirmed"] <= off["unconfirmed"])
    return {
        "schema": "public-f8-attribute-prefilter-off-on-evaluation-v1",
        "evaluated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "scope": "fixed public F8 basic 3 screens / 1280x720 / development only",
        "inference_count": "one off + one on per fixed public frame",
        "truth_sha256": digest(Path(truth_path).read_bytes()),
        "review_csv_sha256": truth["review_csv"]["sha256"],
        "truth_use": "metrics only, after all pixel inference; no DB/prediction backfill",
        "synthetic_truth": "excluded; synthetic = tool tests only",
        "off_control": "evaluator-local subclass bypasses the image attribute reader only",
        "top1_definition": "selected full-form pipeline candidate before status gating; resolved form or effective conditional/global winner",
        "denominator": 3, "metrics": metrics,
        "acceptance": "correct candidate dropped 0; final wrong 0; top1 nondecrease; unconfirmed nonincrease",
        "result": "PASS" if passed else "NOT_PASSED",
        "promotion": "not evaluated; no promotion decision",
        "predictions": predictions, "source_freeze_before": before,
        "source_freeze_after": after, "environment": environment,
        "limits": ["tiny existing development cohort, two forms of one base student",
                   "no holdout, live game, alternate resolution/DPI or name-shadow evaluation"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--truth", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError("preserve the single public evaluation; output already exists")
    report = evaluate(args.truth)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"result": report["result"], "metrics": report["metrics"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
