"""Validate the separately frozen, human-reviewed public F8 attribute truth.

This module deliberately imports neither student metadata nor recognition code.
Synthetic classifier fixtures are tool tests, never approved evaluation truth.
"""

import csv
from datetime import datetime
import hashlib
import io
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PREP = "debug/scanner_o3_attribute_truth_prep_f8_20261003_sol/artifacts"
REVIEW_PATH = f"{PREP}/human-review-2026-10-08.csv"
REVIEW_SHA256 = "a4c158abe7a23e7e0111d7969dbcaf25c70ce30921a1159f6442d889c9e9e5cc"
AXES = ("attack_type", "defense_type", "role", "position", "combat_class")
OBSERVATION_IDS = ("F8A001", "F8A002", "F8A003")
SCHEMA = "public-f8-approved-attribute-truth-v1"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def public_path(relative):
    """Require a repository-relative public source; reject private/traversal paths."""
    path = Path(relative)
    if (path.is_absolute() or ".." in path.parts
            or any(token in str(path).lower() for token in ("holdout", "evaluator-only"))):
        raise ValueError("source must be a repository-relative public path")
    resolved = (ROOT / path).resolve()
    if not resolved.is_relative_to(ROOT):
        raise ValueError("source escapes repository")
    return resolved


def verified_bytes(record):
    data = public_path(record["path"]).read_bytes()
    if digest(data) != record["sha256"] or len(data) != record["bytes"]:
        raise ValueError(f"source integrity mismatch: {record['path']}")
    return data


def load_approved_truth(path):
    """Load exactly the 15 signed observations and verify their immutable sources."""
    truth = json.loads(Path(path).read_bytes())
    if (truth.get("schema") != SCHEMA or truth.get("schema_version") != 1
            or truth.get("partition") != "development_regression_not_holdout_or_runtime_learning"
            or truth.get("label_origin") != "human_visual_review"
            or truth.get("approved_truth_observations") != 15):
        raise ValueError("not the approved public F8 truth schema/cohort")
    if (truth.get("classifier_predictions_used_for_labels") is not False
            or truth.get("student_DB_attributes_used_for_labels") is not False):
        raise ValueError("labels must be independent of DB/predictions")
    freeze_time = datetime.fromisoformat(truth["frozen_at_utc"].replace("Z", "+00:00"))
    if freeze_time.utcoffset() is None or freeze_time.utcoffset().total_seconds() != 0:
        raise ValueError("freeze time must be UTC")
    review_source = truth["review_csv"]
    if (review_source.get("original_source_path", review_source["path"]) != REVIEW_PATH
            or review_source["sha256"] != REVIEW_SHA256):
        raise ValueError("unexpected reviewed CSV")
    reviews = list(csv.DictReader(io.StringIO(verified_bytes(review_source).decode("utf-8"))))
    vocabulary = json.loads(verified_bytes(truth["vocabulary_source"]))
    verified_bytes(truth["label_policy"]["source"])
    verified_bytes(truth["roi_source"])
    verified_bytes(truth["roi_crop_source_snapshot"])
    manifest = json.loads(verified_bytes(truth["identity_manifest_source"]))
    verified_bytes(truth["model_draft_source"])
    if truth["label_policy"]["version"] != "public-F8-human-review-protocol-v1":
        raise ValueError("unsupported human label policy")
    rows = truth["observations"]
    expected_keys = {(oid, axis) for oid in OBSERVATION_IDS for axis in AXES}
    if len(rows) != 15 or len(reviews) != 15:
        raise ValueError("expected 15 reviewed observations")
    by_key = {(row["observation_id"], row["axis"]): row for row in reviews}
    keys = {(row["review"]["observation_id"], row["review"]["axis"]) for row in rows}
    if set(by_key) != expected_keys or keys != expected_keys:
        raise ValueError("each public observation must have all five axes exactly once")
    samples = truth["samples"]
    if len(samples) != 3 or {row["observation_id"] for row in samples} != set(OBSERVATION_IDS):
        raise ValueError("expected the three public F8 screens")
    sources = {sample["observation_id"]: sample for sample in samples}
    assets = {asset["file"]: asset for asset in manifest["assets"] if asset["state"] == "basic"}
    for sample in samples:
        verified_bytes(sample["source_png"])
        verified_bytes(sample["review_png"])
        asset = assets[sample["source_fixture_file"]]
        if (sample["source_png"]["sha256"] != sample["review_png"]["sha256"]
                or asset["sha256"] != sample["source_png"]["sha256"]
                or sample["student_ref_for_metrics_only"] != asset["identity"]):
            raise ValueError("public sample/independent identity mismatch")
    for row in rows:
        review = row["review"]
        key = (review["observation_id"], review["axis"])
        if review != by_key[key]:
            raise ValueError("reviewed CSV fields changed in frozen truth")
        if review["reviewer_id"] != "user-l01x" or review["review_status"] != "reviewed":
            raise ValueError("all observations require the actual user signature")
        reviewed_at = datetime.fromisoformat(review["reviewed_at_utc"].replace("Z", "+00:00"))
        if reviewed_at.utcoffset() is None or reviewed_at.utcoffset().total_seconds() != 0:
            raise ValueError("review time must be UTC")
        if freeze_time < reviewed_at:
            raise ValueError("freeze predates review")
        value = review["normalized_value_human"] or None
        visibility = review["visibility_human"]
        if visibility not in ("observed_readable", "unknown", "unobserved"):
            raise ValueError("invalid visibility")
        if visibility == "observed_readable":
            if not review["screen_text_human"] or value not in vocabulary[review["axis"]]:
                raise ValueError("readable field requires screen text and a normalized enum")
        elif value is not None or review["screen_text_human"]:
            raise ValueError("unknown/unobserved fields must remain empty")
        if row["approved_truth_value"] != value:
            raise ValueError("approved value must equal the unmodified human CSV")
        roi = [int(token) for token in review["roi_xyxy_exclusive"].split(",")]
        if row["roi_xyxy_exclusive"] != roi or row["roi_source_sha256"] != truth["roi_source"]["sha256"]:
            raise ValueError("ROI does not match the reviewed CSV/source")
        sample = sources[review["observation_id"]]
        if review["evidence_png"] != f"pixels/{review['observation_id']}.png":
            raise ValueError("unexpected review evidence PNG")
        if row["source_png_sha256"] != sample["source_png"]["sha256"]:
            raise ValueError("observation PNG provenance mismatch")
    if truth["reviewer_ids"] != [row["review"]["reviewer_id"] for row in rows]:
        raise ValueError("reviewer provenance list mismatch")
    return truth
