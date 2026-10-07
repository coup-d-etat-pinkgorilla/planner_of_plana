"""Freeze the already signed public CSV without changing any review values."""

import ast
import csv
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
ARTIFACTS = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))
from tools.student_attribute_truth import AXES, PREP, REVIEW_PATH, REVIEW_SHA256, SCHEMA, load_approved_truth
from tools.evaluate_student_attribute_prefilter import FROZEN_FILES


def sha(data):
    return hashlib.sha256(data).hexdigest()


def record(path):
    data = (ROOT / path).read_bytes()
    return {"path": path, "bytes": len(data), "sha256": sha(data)}


def write_new(filename, data):
    target = ARTIFACTS / filename
    if target.exists():
        raise FileExistsError(target)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    csv_bytes = (ROOT / REVIEW_PATH).read_bytes()
    if sha(csv_bytes) != REVIEW_SHA256:
        raise ValueError("reviewed CSV differs from orchestrator's pinned source")
    reviews = list(csv.DictReader(io.StringIO(csv_bytes.decode("utf-8"))))
    draft_path = f"{PREP}/attribute-observations-model-draft.json"
    draft = json.loads((ROOT / draft_path).read_bytes())
    draft_rows = {row["observation_id"]: row for row in draft["observations"]}
    manifest_path = "backend/tests/fixtures/student_identity_f8_live/manifest.json"
    manifest = json.loads((ROOT / manifest_path).read_bytes())
    assets = {row["file"]: row for row in manifest["assets"]}
    roi_source = record("backend/assets/recognition/v1/regions/student_identity_regions.json")
    samples = []
    for oid, row in draft_rows.items():
        source = record(row["source_fixture_path"])
        review_png = record(f"{PREP}/{row['evidence_png']}")
        if source["sha256"] != row["source_file_sha256"] or source["sha256"] != review_png["sha256"]:
            raise ValueError("public PNG differs from human-reviewed source")
        samples.append({"observation_id": oid, "source_fixture_file": row["source_fixture_file"],
                        "source_png": source, "review_png": review_png,
                        "source_size": row["source_size"], "source_state": "basic",
                        "student_ref_for_metrics_only": assets[row["source_fixture_file"]]["identity"],
                        "capture_provenance": "existing public F8; historic DPI/capture time/tool not verified"})
    observations, differences = [], []
    for review in reviews:
        oid, axis = review["observation_id"], review["axis"]
        prior = draft_rows[oid]["observations"][axis]
        roi = [int(token) for token in review["roi_xyxy_exclusive"].split(",")]
        if roi != prior["roi"]["pixel_box_xyxy_exclusive"]:
            raise ValueError("human review ROI differs from prepared pixel evidence")
        changed = {field: {"model_draft": prior[old], "human_review": review[new]}
                   for field, old, new in (("screen_text", "screen_text", "screen_text_human"),
                                            ("normalized_value", "proposed_value", "normalized_value_human"))
                   if prior[old] != review[new]}
        if changed:
            differences.append({"observation_id": oid, "axis": axis, "changes": changed})
        observations.append({"review": dict(review),
                             "approved_truth_value": review["normalized_value_human"] or None,
                             "roi_xyxy_exclusive": roi,
                             "roi_source_sha256": roi_source["sha256"],
                             "source_png_sha256": draft_rows[oid]["source_file_sha256"],
                             "approval_provenance": "actual human review from signed CSV; metadata normalization by orchestrator only"})
    source = (ROOT / "backend/core/student_scan_recognizer.py").read_text(encoding="utf-8")
    node = next(node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == "ratio_crop")
    truth = {
        "schema": SCHEMA, "schema_version": 1,
        "partition": "development_regression_not_holdout_or_runtime_learning",
        "label_origin": "human_visual_review", "approved_truth_observations": 15,
        "frozen_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "review_csv": record(REVIEW_PATH),
        "reviewer_ids": [row["reviewer_id"] for row in reviews],
        "student_DB_attributes_used_for_labels": False, "classifier_predictions_used_for_labels": False,
        "label_policy": {"version": "public-F8-human-review-protocol-v1",
                         "source": record(f"{PREP}/human-review-protocol.md"),
                         "unknown_policy": "unknown/unobserved values remain null; no identity/DB/prediction backfill"},
        "vocabulary_source": record(f"{PREP}/source-contracts/attribute-vocabulary.json"),
        "roi_source": roi_source,
        "roi_crop_source_snapshot": record(f"{PREP}/source-contracts/ratio-crop.txt"),
        "current_ratio_crop_ast_source": {"path": "backend/core/student_scan_recognizer.py",
                                          "symbol": "ratio_crop", "sha256": sha(ast.get_source_segment(source, node).encode("utf-8"))},
        "identity_manifest_source": record(manifest_path), "model_draft_source": record(draft_path),
        "change_history": [{"action": "copy signed review fields unchanged into a separate approved version",
                            "prior_package_modified": False, "csv_value_changes": 0,
                            "metadata_normalization": "previously performed by orchestrator; original input strings retained verbatim in review notes"}],
        "model_draft_vs_human_review": {"compared_observations": 15, "differences": differences},
        "samples": samples, "observations": observations,
    }
    write_new("approved-attribute-truth-v1.json", truth)
    approved = load_approved_truth(ARTIFACTS / "approved-attribute-truth-v1.json")
    protected = list(FROZEN_FILES) + [REVIEW_PATH, f"{PREP}/human-review-template.csv",
                                     f"{PREP}/README-human-review-2026-10-08.md"]
    write_new("pre-evaluation-freeze.json", {"frozen_at_utc": truth["frozen_at_utc"],
                                            "files": [record(path) for path in protected],
                                            "approved_truth": record(str((ARTIFACTS / "approved-attribute-truth-v1.json").relative_to(ROOT)).replace("\\", "/"))})
    print(json.dumps({"approved_rows": len(approved["observations"]), "csv_sha256": REVIEW_SHA256,
                      "model_draft_differences": len(differences), "frozen_at_utc": truth["frozen_at_utc"]}))


if __name__ == "__main__":
    main()
