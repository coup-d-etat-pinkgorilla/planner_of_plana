"""O0 safety gates pinned to real count tiles and user-review digit masks."""
import hashlib
import json
from pathlib import Path
import unittest

from PIL import Image

from core.inventory_count_bank import COUNT_FASTPATH_ENABLED_WINDOWS, CountBank, count_label
from core.recognition_assets import RecognitionAssetCatalog
from core.student_scan_recognizer import StudentBasicRecognizer
from core.studio_numeric_bank import StudioNumericBank

BACKEND = Path(__file__).resolve().parents[1]
COUNTS = BACKEND / "tests/fixtures/inventory_count_bank_c5e3/1080-leading-digit"
NUMERIC = BACKEND / "tests/fixtures/studio_numeric_o0"


class CountSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = json.loads((COUNTS / "manifest.json").read_text(encoding="utf-8"))["tiles"]
        cls.bank = CountBank(scale=1.5)
        for row in cls.rows:
            path = COUNTS / row["file"]
            if hashlib.sha256(path.read_bytes()).hexdigest() != row["sha256"]:
                raise AssertionError(f"fixture changed: {path}")
            with Image.open(path) as crop:
                cls.bank.learn(crop, row["quantity"])

    def test_only_shadow_verified_720_window_can_skip_detail(self):
        self.assertEqual(frozenset({(1280, 720), (1920, 1080), (2560, 1440)}), COUNT_FASTPATH_ENABLED_WINDOWS)

    def test_all_23_truncated_labels_are_structurally_rejected(self):
        truncated = wrong = 0
        for row in self.rows:
            if int(row["quantity"]) >= 10000:
                continue
            with Image.open(COUNTS / row["file"]) as crop:
                ink = count_label(crop, self.bank.digit_height)
                read = self.bank.read(crop)
            ratio = ink.width / sum(self.bank.width(c) for c in "x" + row["quantity"]) if ink else 0
            if ratio < .8:
                truncated += 1
                self.assertTrue(read.structural_flags, row["file"])
                self.assertFalse(read.confident, row["file"])
            wrong += read.confident and read.value != row["quantity"]
        self.assertEqual(23, truncated)
        self.assertEqual(0, wrong)

    def test_four_leading_digit_regressions_are_correct_or_require_detail(self):
        expected = {38: "1062", 42: "1747", 45: "1012", 50: "2194"}
        for slot, quantity in expected.items():
            with self.subTest(slot=slot), Image.open(COUNTS / f"slot-{slot:03d}.png") as crop:
                read = self.bank.read(crop)
                self.assertTrue(not read.confident or read.value == quantity, read)


class NumericSafetyTests(unittest.TestCase):
    def setUp(self):
        self.bank = StudioNumericBank.from_catalog(RecognitionAssetCatalog(BACKEND / "assets/recognition/v1"))
        self.addCleanup(self.bank.close)
        manifest = json.loads((NUMERIC / "manifest.json").read_text(encoding="utf-8-sig"))
        for row in manifest["masks"]:
            self.assertEqual(row["sha256"], hashlib.sha256((NUMERIC / row["file"]).read_bytes()).hexdigest())

    def cells(self, rank):
        cells = []
        for position in (1, 2):
            with Image.open(NUMERIC / f"rank{rank}-digit{position}.png") as mask:
                cell = Image.new("RGB", mask.size, "white")
                cell.paste((45, 70, 100), (0, 0, *mask.size), mask)
            cells.append(cell)
            self.addCleanup(cell.close)
        return tuple(cells)

    def match(self, rank):
        return self.bank.match(self.cells(rank), field="relationship_rank",
                               roi_names=("affectionlevel_digit1", "affectionlevel_digit2"))

    def add_sample(self, tier, file, digit):
        with Image.open(NUMERIC / file) as mask:
            getattr(self.bank, f"add_{tier}_template")("affectionlevel_digit2", digit, mask, sample_id=file)

    def test_quarantined_crop_bundled_reads_actual_26_and_normal_10(self):
        self.assertEqual(26, self.match(26).value)
        self.assertEqual(10, self.match(10).value)

    def test_mislabeled_actual_6_cannot_be_confirmed_by_user_or_session(self):
        for tier in ("user", "session"):
            with self.subTest(tier=tier):
                self.add_sample(tier, "rank26-digit2.png", "0")
                result = self.match(26)
                self.assertIsNone(result.value)
                self.assertTrue(result.bundled_conflict)
                observation = StudentBasicRecognizer._studio_numeric_observation(
                    result, minimum=1, maximum=100, score_gate=.60, margin_gate=.025, source="test")
                self.assertEqual("uncertain", observation.status)
                getattr(self.bank, f"clear_{tier}_templates")()

    def test_existing_normal_zero_bonus_cannot_turn_26_into_20_but_keeps_10(self):
        self.add_sample("user", "rank10-digit2.png", "0")
        result = self.match(26)
        self.assertIsNone(result.value)
        self.assertTrue(result.bundled_conflict)
        normal = self.match(10)
        self.assertEqual(10, normal.value)
        self.assertTrue(normal.used_user_sample)


if __name__ == "__main__":
    unittest.main()
