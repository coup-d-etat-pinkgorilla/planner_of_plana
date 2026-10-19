"""C5d-1: detail-panel counts read on the label's digit pitch (5-digit counts miss the v6 per-length cells)."""
import json
from pathlib import Path
import unittest

from PIL import Image

from core.inventory_detail_recovery import InventoryDetailRecognizer, binary_bits, bits_score, glyph_score
from core.recognition_assets import RecognitionAssetCatalog

ROOT = Path(__file__).parent / "fixtures/inventory_detail_count_c5d1"
PANEL = (23, 37, 63)


def fixture_frames():
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    for case in manifest["cases"]:
        frame = Image.new("RGB", tuple(manifest["frame_size"]), PANEL)
        with Image.open(ROOT / case["file"]) as strip:
            frame.paste(strip.convert("RGB"), tuple(case["offset"]))
        yield case, frame


class DetailPitchCountTests(unittest.TestCase):
    """Live 1280 strips (debug/scanner_c5e1d_live): five 5-digit counts and v6-readable 1-4 digit counts."""

    @classmethod
    def setUpClass(cls):
        cls.recognizer = InventoryDetailRecognizer(RecognitionAssetCatalog())

    def test_five_digit_counts_fall_back_to_the_pitch_reader(self):
        for case, frame in fixture_frames():
            if len(case["value"]) < 5:
                continue
            with self.subTest(case["file"]):
                self.assertIsNone(self.recognizer.count(frame, case["source"]).value)
                count = self.recognizer.read_count(frame, case["source"])
                self.assertEqual((case["value"], "inventory_detail_pitch"), (count.value, count.source))

    def test_pitch_reader_agrees_with_the_v6_cells_where_they_read(self):
        for case, frame in fixture_frames():
            if len(case["value"]) >= 5:
                continue
            with self.subTest(case["file"]):
                v6 = self.recognizer.read_count(frame, case["source"])
                self.assertEqual((case["value"], "inventory_detail_count"), (v6.value, v6.source))
                self.assertEqual(case["value"], self.recognizer.pitch_count(frame, case["source"]).value)

    def test_a_frame_without_a_count_label_reads_nothing(self):
        frame = Image.new("RGB", (1280, 720), PANEL)
        count = self.recognizer.read_count(frame, "equipment")
        self.assertIsNone(count.value)
        self.assertEqual("no_count_ink", self.recognizer.pitch_count(frame, "equipment").reason)

    def test_bitmask_score_equals_glyph_score(self):
        for seed in range(5):
            left, right = Image.effect_noise((20, 30), 60 + seed * 10), Image.effect_noise((23, 39), 80)
            self.assertAlmostEqual(glyph_score(left, right),
                                   bits_score(binary_bits(left, right.size), binary_bits(right, right.size), 23 * 39))


if __name__ == "__main__":
    unittest.main()
