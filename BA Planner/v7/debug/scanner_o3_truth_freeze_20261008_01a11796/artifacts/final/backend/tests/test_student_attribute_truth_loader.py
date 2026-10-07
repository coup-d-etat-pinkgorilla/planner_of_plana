"""The public loader accepts signed CSV truth and rejects malformed substitutes."""

import copy
import json
from pathlib import Path
import tempfile
import unittest

from tools.student_attribute_truth import AXES, ROOT, REVIEW_SHA256, load_approved_truth


TRUTH = ROOT / "debug/scanner_o3_truth_freeze_20261008_01a11796/artifacts/approved-attribute-truth-v2.json"


class PublicAttributeTruthLoaderTests(unittest.TestCase):
    def test_fifteen_fields_and_actual_reviewer_signature_with_integrity_rejection(self):
        truth = load_approved_truth(TRUTH)
        self.assertEqual(15, len(truth["observations"]))
        self.assertEqual(["user-l01x"] * 15, truth["reviewer_ids"])
        self.assertEqual(REVIEW_SHA256, truth["review_csv"]["sha256"])
        for oid in ("F8A001", "F8A002", "F8A003"):
            rows = [row for row in truth["observations"] if row["review"]["observation_id"] == oid]
            self.assertEqual(set(AXES), {row["review"]["axis"] for row in rows})
            for row in rows:
                self.assertEqual("observed_readable", row["review"]["visibility_human"])
                self.assertEqual("user-l01x", row["review"]["reviewer_id"])
                self.assertEqual(row["review"]["normalized_value_human"], row["approved_truth_value"])
                self.assertEqual(4, len(row["roi_xyxy_exclusive"]))
                self.assertEqual(64, len(row["source_png_sha256"]))
        with tempfile.TemporaryDirectory(prefix="f8truth-") as directory:
            path = Path(directory) / "invalid.json"
            for name, mutate in (
                ("missing observation", lambda data: data["observations"].pop()),
                ("invented reviewer", lambda data: data["observations"][0]["review"].update(reviewer_id="assistant")),
                ("value backfill", lambda data: data["observations"][0].update(approved_truth_value="mystic")),
                ("source mismatch", lambda data: data["review_csv"].update(sha256="0" * 64)),
                ("private source", lambda data: data["roi_source"].update(path="debug/holdout/private.json")),
            ):
                with self.subTest(name=name):
                    invalid = copy.deepcopy(truth)
                    mutate(invalid)
                    path.write_text(json.dumps(invalid, ensure_ascii=False), encoding="utf-8")
                    with self.assertRaises(ValueError):
                        load_approved_truth(path)


if __name__ == "__main__":
    unittest.main()
