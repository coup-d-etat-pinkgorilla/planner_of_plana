"""Session tile bank across scans whose slot crops sit a pixel off (live equipment --repeat 2, 2026-09-28).

The second scan's crops were 1 px lower than the first scan's; the universal blueprints differ only in a small
category mark, so the unshifted M4 read Charm and Badge as Gloves (confident) and failed the scan.
"""
import json
from pathlib import Path
import unittest

from PIL import Image

from core.inventory_tile_bank import TileBank, shifted_query_vectors

ROOT = Path(__file__).parent / "fixtures/inventory_tile_bank_shift_c5e"


def tiles(scan):
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    for row in manifest["tiles"]:
        if row["scan"] == scan:
            with Image.open(ROOT / row["file"]) as image:
                yield row, image.convert("RGB")


class ShiftedSecondScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bank = TileBank()
        for row, crop in tiles("first"):
            cls.bank.add(row["identity"], crop)

    def test_second_scan_blueprints_are_read_as_themselves(self):
        for row, crop in tiles("second"):
            with self.subTest(row["file"]):
                match = self.bank.match(crop)
                self.assertEqual(row["identity"], match.identity)
                self.assertTrue(match.confident, match)

    def test_order_prior_path_uses_the_same_alignment(self):
        _row, crop = next(row for row in tiles("second") if row[0]["slot"] == 6)
        overall, between = self.bank.match_between(crop, None, {}, None, None)
        self.assertEqual("Equipment_Icon_Charm_Useall_Piece", overall.identity)

    def test_an_identical_crop_keeps_its_perfect_score(self):
        row, crop = next(tiles("first"))
        self.assertAlmostEqual(1.0, self.bank.match(crop).score, places=6)
        self.assertEqual(row["identity"], self.bank.match(crop).identity)

    def test_shift_grid_scales_with_the_crop(self):
        crop = Image.new("RGB", (117, 95), "white")
        self.assertEqual(14, len(shifted_query_vectors(crop)))  # dy -2..2 x dx -1..1, without (0, 0)
        self.assertEqual(44, len(shifted_query_vectors(crop.resize((234, 190)))))  # dy -4..4 x dx -2..2


if __name__ == "__main__":
    unittest.main()
