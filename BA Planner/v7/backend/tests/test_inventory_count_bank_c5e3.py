"""C5e-3: grid count labels read with glyphs learned from detail-confirmed quantities (real 1280 tiles)."""
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from core.inventory_count_bank import CountBank, CountRead, count_label

ROOT = Path(__file__).parent / "fixtures/inventory_count_bank_c5e3"
RARITY = Path(__file__).resolve().parents[1] / "assets/recognition/spec/item-rarity-v1.json"


def fixture_tiles(scan):
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    for row in manifest["tiles"]:
        if row["scan"] == scan:
            with Image.open(ROOT / row["file"]) as image:
                yield row, image.convert("RGB")


def exact(quantity):
    return quantity is not None and quantity.isdigit() and int(quantity) < 10000


def synthetic_seeds():
    from core.recognition_asset_extract import find_game_dir
    from core.recognition_synth_provider import SynthProvider
    if not (find_game_dir() and RARITY.is_file()):
        return None
    with tempfile.TemporaryDirectory() as root:
        return dict(SynthProvider(Path(root) / "a", Path(root) / "s", RARITY)("equipment", (1280, 720)).glyphs)


class CountBankFixtureTests(unittest.TestCase):
    """Two live equipment scans: learn from the first, read the second (C5e-3 parity fixture)."""

    @classmethod
    def setUpClass(cls):
        cls.seeds = synthetic_seeds()

    def learned(self, seeds):
        bank = CountBank(scale=1.0)
        if seeds:
            bank.set_seeds(seeds)
        for row, crop in fixture_tiles("a"):
            if row["quantity"]:
                bank.learn(crop, row["quantity"])
        return bank

    def check_reads(self, bank):
        confident = wrong = 0
        for row, crop in fixture_tiles("b"):
            read = bank.read(crop)
            if not exact(row["quantity"]):
                # Abbreviated labels (x25K ...) are never an exact value.
                self.assertIsNone(read.value, row["identity"])
                continue
            if read.confident:
                confident += 1
                wrong += read.value != row["quantity"]
        return confident, wrong

    def test_learned_glyphs_read_the_second_scan_without_confident_errors(self):
        for label, seeds in (("synthetic seeds", self.seeds), ("no seeds", None)):
            if label == "synthetic seeds" and not seeds:
                continue
            with self.subTest(label):
                bank = self.learned(seeds)
                self.assertTrue(bank.ready())
                confident, wrong = self.check_reads(bank)
                self.assertEqual(0, wrong)
                if seeds:
                    self.assertGreaterEqual(confident, 30)

    def test_abbreviated_labels_teach_the_k_and_read_as_abbreviated(self):
        if not self.seeds:
            self.skipTest("K alignment needs the synthetic seed")
        bank = self.learned(self.seeds)
        self.assertTrue(bank.samples.get("K"))
        texts = [bank.read(crop).text for row, crop in fixture_tiles("b") if not exact(row["quantity"])]
        self.assertTrue(texts and all(text.endswith("K") for text in texts), texts)

    def test_label_and_unready_bank(self):
        row, crop = next(fixture_tiles("b"))
        ink = count_label(crop, 14)
        self.assertIsNotNone(ink)
        self.assertLessEqual(ink.height, 14)
        self.assertEqual(CountRead(None, "", 0.0, 0.0), CountBank(scale=1.0).read(crop))

    def test_non_numeric_quantities_teach_nothing(self):
        _row, crop = next(fixture_tiles("a"))
        bank = CountBank(scale=1.0)
        self.assertEqual(0, bank.learn(crop, "12K"))
        self.assertEqual(0, bank.learn(crop, ""))


if __name__ == "__main__":
    unittest.main()
