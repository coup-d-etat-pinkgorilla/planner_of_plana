"""C5e-6b: incremental synthetic-template cache and the synth drift guard."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from core.recognition_asset_extract import AssetCache, extract, find_game_dir
from core.recognition_synth import SynthTemplateSet, synthesize
from core.recognition_synth_cache import SynthCache, SynthDriftGuard, drift_scores

BACKEND = Path(__file__).resolve().parents[1]
RARITY = BACKEND / "assets/recognition/spec/item-rarity-v1.json"
GAME = find_game_dir()


class DriftGuardTests(unittest.TestCase):
    def test_two_low_scans_in_a_row_disable_the_profile_tier(self):
        guard = SynthDriftGuard()
        low, good = [.5] * 10, [.97] * 10
        self.assertEqual("uncertain", guard.record("presents", low)["status"])
        self.assertTrue(guard.enabled("presents"))
        guard.record("presents", good)  # a good scan resets the run
        guard.record("presents", low)
        self.assertTrue(guard.enabled("presents"))
        evidence = guard.record("presents", low)
        self.assertIn("synth_drift_detected", evidence["note"])
        self.assertFalse(guard.enabled("presents"))
        self.assertTrue(guard.enabled("tech_notes"))
        self.assertNotIn("synth_drift_detected", guard.record("presents", low)["note"])  # reported once

    def test_no_confirmed_tiles_is_not_evidence_either_way(self):
        guard = SynthDriftGuard()
        self.assertEqual("uncertain", guard.record("equipment", [])["status"])
        self.assertEqual({}, {k: v for k, v in guard.low_runs.items() if v})

    def test_drift_scores_compare_confirmed_crops_to_their_own_tile(self):
        tile = Image.new("RGB", (96, 96), (200, 60, 60))
        for x in range(20, 70):
            tile.putpixel((x, 40), (10, 10, 10))
        synth = SynthTemplateSet("presents", tiles={"a": tile})
        scores = drift_scores(synth, [("a", tile.resize((98, 91))), ("unknown", tile)])
        self.assertEqual(1, len(scores))
        self.assertGreater(scores[0], .9)


@unittest.skipUnless(GAME and RARITY.is_file(), "local Steam client and rarity snapshot required")
class LiveCacheTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.TemporaryDirectory()
        cls.assets = extract(GAME, Path(cls.root.name) / "assets", RARITY)
        cls.rarity = json.loads(cls.assets.rarity_path.read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls):
        cls.root.cleanup()

    def test_hit_miss_change_and_damage(self):
        with tempfile.TemporaryDirectory() as root:
            first = SynthCache(Path(root)).templates(self.assets, self.rarity, profile="tech_notes", glyph_sizes=())
            self.assertEqual(54, len(first.tiles))
            cache = SynthCache(Path(root))
            second = cache.templates(self.assets, self.rarity, profile="tech_notes", glyph_sizes=())
            self.assertEqual({"hit": 54, "built": 0, "repaired": 0}, cache.stats)
            direct = synthesize(self.assets, self.rarity, profile="tech_notes", identities=["Item_Icon_SkillBook_Abydos_2"], glyph_sizes=())
            self.assertEqual(direct.tiles["Item_Icon_SkillBook_Abydos_2"].tobytes(), second.tiles["Item_Icon_SkillBook_Abydos_2"].tobytes())
            self.assertEqual(direct.details["Item_Icon_SkillBook_Abydos_2"].tobytes(), second.details["Item_Icon_SkillBook_Abydos_2"].tobytes())

            # A changed icon (e.g. a game patch) rebuilds that identity only.
            manifest = copy.deepcopy(self.assets.manifest)
            manifest["icons"]["Item_Icon_SkillBook_Abydos_2"]["pixel_sha256"] = "0" * 64
            patched = AssetCache(self.assets.root, manifest)
            cache = SynthCache(Path(root))
            cache.templates(patched, self.rarity, profile="tech_notes", glyph_sizes=())
            self.assertEqual({"hit": 53, "built": 1, "repaired": 0}, cache.stats)

            # A damaged blob is rebuilt; a damaged index rebuilds everything.
            directory = Path(root) / "kr" / "1.0.0"
            index = json.loads((directory / "index.json").read_text(encoding="utf-8"))
            offset, length = index["entries"]["Item_Icon_SkillBook_Gehenna_1"]["tile"]
            data = bytearray((directory / "pack.bin").read_bytes())
            data[offset:offset + length] = bytes(length)
            (directory / "pack.bin").write_bytes(bytes(data))
            cache = SynthCache(Path(root))
            repaired = cache.templates(patched, self.rarity, profile="tech_notes", glyph_sizes=())
            self.assertEqual(1, cache.stats["repaired"])
            self.assertEqual(synthesize(self.assets, self.rarity, profile="tech_notes", identities=["Item_Icon_SkillBook_Gehenna_1"],
                                        glyph_sizes=()).tiles["Item_Icon_SkillBook_Gehenna_1"].tobytes(),
                             repaired.tiles["Item_Icon_SkillBook_Gehenna_1"].tobytes())
            (directory / "index.json").write_text("{", encoding="utf-8")
            cache = SynthCache(Path(root))
            cache.templates(patched, self.rarity, profile="tech_notes", glyph_sizes=())
            self.assertEqual(54, cache.stats["built"])

    def test_glyphs_follow_the_window(self):
        with tempfile.TemporaryDirectory() as root:
            small = SynthCache(Path(root)).templates(self.assets, self.rarity, profile="presents", window=(1280, 720))
            large = SynthCache(Path(root)).templates(self.assets, self.rarity, profile="presents", window=(2560, 1440))
            self.assertEqual([19, 20, 21], sorted(small.glyphs))
            self.assertEqual([38, 39, 40], sorted(large.glyphs))  # round(44 x .865) + 1 = 39
            self.assertEqual(small.tiles["Item_Icon_Favor_0"].tobytes(), large.tiles["Item_Icon_Favor_0"].tobytes())


if __name__ == "__main__":
    unittest.main()
