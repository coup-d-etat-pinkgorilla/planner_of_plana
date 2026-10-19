"""Preserve v1; package byte-identical public source inputs in a new truth version."""

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import sys


ARTIFACTS = Path(__file__).resolve().parent
ROOT = ARTIFACTS.parents[2]
sys.path.insert(0, str(ROOT / "backend"))
from tools.student_attribute_truth import load_approved_truth
from tools.evaluate_student_attribute_prefilter import FROZEN_FILES


def record(path):
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def main():
    v1 = ARTIFACTS / "approved-attribute-truth-v1.json"
    truth = load_approved_truth(v1)
    bundle = ARTIFACTS / "source-inputs"
    bundle.mkdir(exist_ok=True)

    def snapshot(source, filename):
        original_path = source["path"]
        destination = bundle / filename
        if destination.exists():
            raise FileExistsError(destination)
        shutil.copyfile(ROOT / original_path, destination)
        copied = record(destination)
        if copied["sha256"] != source["sha256"] or copied["bytes"] != source["bytes"]:
            raise ValueError("source snapshot changed")
        copied["original_source_path"] = original_path
        return copied

    truth["review_csv"] = snapshot(truth["review_csv"], "human-review-2026-10-08.csv")
    truth["label_policy"]["source"] = snapshot(truth["label_policy"]["source"], "human-review-protocol.md")
    for key, filename in (("vocabulary_source", "attribute-vocabulary.json"),
                          ("roi_source", "student_identity_regions.json"),
                          ("roi_crop_source_snapshot", "ratio-crop.txt"),
                          ("identity_manifest_source", "f8-manifest.json"),
                          ("model_draft_source", "attribute-observations-model-draft.json")):
        truth[key] = snapshot(truth[key], filename)
    for sample in truth["samples"]:
        sample["review_png"] = snapshot(sample["review_png"], sample["observation_id"] + ".png")
    truth["bundle_version"] = 2
    truth["bundle_materialized_at_utc"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    truth["previous_approved_version"] = record(v1)
    truth["change_history"].append({"action": "package public source inputs byte-identically for self-contained checkout",
                                   "review_values_changed": 0, "previous_truth_overwritten": False})
    v2 = ARTIFACTS / "approved-attribute-truth-v2.json"
    if v2.exists():
        raise FileExistsError(v2)
    v2.write_text(json.dumps(truth, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    load_approved_truth(v2)
    freeze = {"approved_truth": record(v2), "candidate_files": [record(ROOT / path) for path in FROZEN_FILES],
              "source_snapshots": [record(path) for path in sorted(bundle.iterdir())],
              "scope": "before inference; v1 preserved; no label value changes"}
    target = ARTIFACTS / "final-pre-evaluation-freeze.json"
    if target.exists():
        raise FileExistsError(target)
    target.write_text(json.dumps(freeze, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"source_snapshot_files": len(freeze["source_snapshots"]),
                      "approved_truth_sha256": freeze["approved_truth"]["sha256"]}))


if __name__ == "__main__":
    main()
