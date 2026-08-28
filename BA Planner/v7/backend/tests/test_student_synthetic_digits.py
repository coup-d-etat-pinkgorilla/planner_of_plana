from __future__ import annotations

from hashlib import sha256
import json
from pathlib import Path
import unittest


BACKEND = Path(__file__).resolve().parents[1]
ROOT = BACKEND / "assets" / "recognition" / "v1" / "templates" / "student_numeric_synthetic"
BENCHMARK = BACKEND / "tests" / "fixtures" / "student_synthetic_digit_benchmark.json"
WHOLE_BENCHMARK = BACKEND / "tests" / "fixtures" / "student_whole_value_benchmark.json"


class StudentSyntheticDigitTests(unittest.TestCase):
    def test_renderer_spec_freezes_user_reviewed_font_and_shear(self) -> None:
        spec = json.loads((ROOT / "renderer_spec.json").read_text(encoding="utf-8"))
        self.assertEqual("GyeonggiTitle", spec["font"]["family"])
        self.assertEqual("Medium", spec["font"]["weight"])
        self.assertEqual(
            "da6fc2e29f3fdc1f25a1f94e18549040acef06ac8d7d9dc373e0f6eabbcae8da",
            spec["font"]["sha256"],
        )
        self.assertEqual(-0.2, spec["fields"]["student_level"]["shear"])
        self.assertEqual(-0.25, spec["fields"]["weapon_level"]["shear"])
        self.assertEqual(0.0, spec["fields"]["relationship_rank"]["shear"])
        self.assertEqual([1, 2], spec["fields"]["student_level"]["layouts"])
        self.assertEqual([1, 2], spec["fields"]["weapon_level"]["layouts"])
        self.assertEqual([1, 2, 3], spec["fields"]["relationship_rank"]["layouts"])
        for field in ("student_level", "weapon_level", "relationship_rank"):
            self.assertEqual(
                "complete_string_native_raster->field_roi->low_ink_split->20x28_binary_glyph",
                spec["fields"][field]["render_pipeline"],
            )

    def test_representative_generated_hashes_are_stable(self) -> None:
        expected = {
            "student_level/layout_2/position_1/2_v2.png": "ab52fbb7c48617d8bb775fd46a81183ba18fbd0a5a5c0527a3673e71a83fcbd1",
            "weapon_level/layout_2/position_1/0_v2.png": "209ed57259074f444021ba98f845e7ed7872030e99a37ccd09a362231462317b",
            "relationship_rank/layout_2/position_0/7_v2.png": "60cd15d5d25a6dda06afd8a7e8945ba0590828f9f5afe3b58337ba8b630f7341",
        }
        for relative, digest in expected.items():
            with self.subTest(path=relative):
                self.assertEqual(digest, sha256((ROOT / relative).read_bytes()).hexdigest())

    def test_layout_position_bank_is_complete(self) -> None:
        expected_groups = {"student_level": 3, "weapon_level": 3, "relationship_rank": 6}
        for field, group_count in expected_groups.items():
            with self.subTest(field=field):
                groups = sorted((ROOT / field).glob("layout_*/position_*"))
                self.assertEqual(group_count, len(groups))
                for group in groups:
                    self.assertEqual(50, len(list(group.glob("*_v*.png"))))

    def test_shadow_benchmark_blocks_unsafe_promotion(self) -> None:
        report = json.loads(BENCHMARK.read_text(encoding="utf-8"))
        self.assertEqual("synthetic-shadow-no-runtime-promotion", report["mode"])
        validation = report["relationship_partitions"]["validation"]
        self.assertEqual(8, validation["samples"])
        self.assertEqual(7, validation["correct"])
        self.assertEqual(0, validation["accepted_wrong"])
        self.assertEqual(2, validation["fallback"])
        serika = next(row for row in report["basic_frames"] if row["source"].startswith("student_scan_s2"))
        self.assertEqual(11, serika["observed"]["student_level"]["value"])
        self.assertFalse(serika["observed"]["student_level"]["correct"])
        self.assertEqual(50, serika["observed"]["weapon_level"]["value"])
        self.assertTrue(serika["observed"]["weapon_level"]["correct"])
        self.assertEqual(24, serika["observed"]["relationship_rank"]["value"])

    def test_whole_value_bank_is_fast_but_remains_shadow_only(self) -> None:
        report = json.loads(WHOLE_BENCHMARK.read_text(encoding="utf-8"))
        self.assertEqual(250, report["templates"]["count"])
        self.assertEqual(64000, report["templates"]["prepared_bytes"])
        self.assertLess(report["templates"]["json_bytes"], 200000)
        self.assertLess(report["templates"]["cold_load_ms"], 50.0)
        for field in ("student_level", "weapon_level", "relationship_rank"):
            self.assertLess(report["fields"][field]["warm_p95_ms"], 2.0)
        self.assertEqual(2, report["fields"]["student_level"]["correct"])
        self.assertEqual(3, report["fields"]["weapon_level"]["correct"])
        self.assertEqual(7, report["fields"]["relationship_rank"]["correct"])
        self.assertEqual("not promoted", report["decision"]["production"])


if __name__ == "__main__":
    unittest.main()
