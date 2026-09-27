"""C5e-6c: the synthetic tier sits below real bank tiers and only for D16-gated profiles."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from PIL import Image, ImageDraw

from core.inventory_detail_recovery import DetailCount, DetailRecoveryResult, DetailResult
from core.inventory_navigation import PageMove, PreparedInventory
from core.inventory_tile_bank import TileBank
from core.recognition_asset_extract import find_game_dir
from core.recognition_synth import SynthTemplateSet, SynthUnavailable, normalize_tile
from core.scanner_matchers import CountMatch, InventoryMatcherAdapter, Match
from core.scanner_session import ScanBatchResult
from test_inventory_detail_f9 import GridUI, SLOTS, ITEM
from test_student_panel_f2 import FastEvent

V7 = Path(__file__).resolve().parents[2]
RARITY = V7 / "backend/assets/recognition/spec/item-rarity-v1.json"
RECORDING = V7 / "debug/scanner_c5e1d_live/tech_notes"


def slot_crop(colour):
    """A 117x95 runtime slot crop whose dataset window (inset 1..2 px) holds a coloured icon."""
    crop = Image.new("RGB", (117, 95), (204, 204, 204))
    draw = ImageDraw.Draw(crop)
    draw.rectangle((2, 2, 100, 93), fill=(235, 235, 235))
    draw.polygon([(30, 12), (80, 16), (76, 66), (28, 62)], fill=colour)
    draw.ellipse((45, 28, 62, 45), fill=(20, 20, 20))
    return crop


def synthetic_tile(colour):
    with slot_crop(colour) as crop, crop.crop((1, 1, 99, 92)) as window:
        return normalize_tile(window)


class BankTierTests(unittest.TestCase):
    def test_synthetic_entries_match_runtime_slot_crops_and_yield_to_real_tiles(self):
        bank = TileBank()
        bank.add_synth("red", synthetic_tile((210, 50, 50)))
        bank.add_synth("blue", synthetic_tile((50, 50, 210)))
        found = bank.match(slot_crop((210, 50, 50)))
        self.assertEqual(("red", "synth"), (found.identity, found.tier))
        self.assertTrue(found.confident)
        self.assertIsNone(bank.match(slot_crop((210, 50, 50)), allow_synth=False).identity)
        bank.add("red", slot_crop((210, 50, 50)))
        self.assertEqual("session", bank.match(slot_crop((210, 50, 50))).tier)
        # The synthetic vectors stay for drift scoring after the real tile replaced the entry.
        self.assertGreater(bank.synth_score("red", slot_crop((210, 50, 50))), .9)
        bank.add_synth("red", synthetic_tile((210, 50, 50)))
        self.assertEqual("session", bank.entries["red"].tier)
        with self.assertRaises(ValueError):
            bank.add("red", slot_crop((1, 2, 3)), "synth")


class Provider:
    def __init__(self, tiles=None, error=None):
        self.tiles, self.error, self.calls = tiles or {}, error, []

    def __call__(self, profile, window):
        self.calls.append(profile)
        if self.error:
            raise SynthUnavailable(self.error)
        return SynthTemplateSet(profile, tiles=dict(self.tiles))


class AdapterSynthTests(unittest.TestCase):
    def adapter(self, provider, profile="tech_notes", count="42"):
        ui = GridUI()
        adapter = object.__new__(InventoryMatcherAdapter)
        adapter.capture = ui
        adapter.threshold, adapter.margin, adapter.max_pages, adapter.answer_samples = .8, .03, 1, None
        adapter.slots = SLOTS[:1]
        adapter.matcher = Mock(templates=[1])
        adapter.matcher.match.return_value = Match(ITEM, .7, .01)
        adapter.count_matcher = Mock()
        adapter.count_matcher.match.return_value = CountMatch(count, .9, .1)
        reader = ui.reader()
        reader.regions = {"sources": {"item": {"grid_slots": SLOTS[:1]}}}
        adapter.detail_recovery = Mock(recognizer=reader)
        adapter.detail_recovery.read.return_value = DetailRecoveryResult(DetailResult(ITEM, .95, .1, DetailCount("7", .9)))
        adapter.synth_provider = provider
        nav = Mock()
        nav.phase_residuals.return_value = [0.0, 0.0]
        nav.prepare.return_value = PreparedInventory("item", profile, True, True)
        nav.verify_profile_order.return_value = True
        nav.page_slots.return_value = {0: SLOTS[0]}
        nav.advance.side_effect = lambda *_: PageMove(ui.wait_stable({}, FastEvent()), 0.0, True, "verified_no_motion")
        adapter.navigation = nav
        self.enterContext(patch("core.scanner_matchers.image_has_visible_content", return_value=True))
        return adapter

    @staticmethod
    def scan(adapter):
        result = adapter({}, FastEvent(), lambda *_: None)
        rows = result.candidates if isinstance(result, ScanBatchResult) else result
        for row in rows:
            for crop in row.get("_answer_specimen", {}).get("slot_crops", {}).values():
                crop.close()
        return rows[0]

    @staticmethod
    def evidence(row, field):
        return [e for e in row["evidence"] if e["field"] == field]

    def test_enabled_profile_loads_the_tier_and_records_drift(self):
        provider = Provider({ITEM: Image.new("RGB", (96, 96), (200, 200, 200))})
        adapter = self.adapter(provider, count=None)
        row = self.scan(adapter)
        self.assertEqual(["tech_notes"], provider.calls)
        self.assertEqual("ok", self.evidence(row, "synth_tier")[0]["status"])
        self.assertEqual(1, len(self.evidence(row, "synth_drift")))
        self.assertIn(ITEM, adapter.tile_banks[(40, 40)].synth)  # loaded as the synthetic tier

    def test_gated_profiles_and_unavailable_tier_scan_without_it(self):
        provider = Provider({ITEM: Image.new("RGB", (96, 96), (200, 200, 200))})
        row = self.scan(self.adapter(provider, profile="equipment"))
        self.assertEqual([], provider.calls)
        self.assertEqual([], self.evidence(row, "synth_tier"))
        row = self.scan(self.adapter(Provider(error="game client folder not found")))
        tier, = self.evidence(row, "synth_tier")
        self.assertEqual("uncertain", tier["status"])
        self.assertIn("game client folder not found", tier["note"])
        self.assertEqual([], self.evidence(row, "synth_drift"))
        self.assertEqual(1, len([e for e in row["payload"]["entries"] if e["observed_slot"] == 0]))

    def test_drift_detected_disables_the_tier_for_the_session(self):
        adapter = self.adapter(Provider({ITEM: Image.new("RGB", (96, 96), (200, 200, 200))}))
        guard = adapter._synth_guard()
        guard.disabled.add("tech_notes")
        row = self.scan(adapter)
        self.assertIn("disabled after synth_drift_detected", self.evidence(row, "synth_tier")[0]["note"])
        self.assertEqual([], adapter.synth_provider.calls)

    def test_a_slot_confirmed_by_a_synthetic_tile_alone_is_synth_bank(self):
        from core.inventory_tile_bank import BankMatch
        adapter = self.adapter(Provider({}))
        bank = Mock(entries={}, synth={})
        bank.__len__ = lambda _self: 1
        bank.match.return_value = BankMatch(ITEM, .96, .05, "synth")
        adapter.tile_banks = {(40, 40): bank}
        row = self.scan(adapter)
        adapter.detail_recovery.read.assert_not_called()
        self.assertIn("synth_bank", [e["source"] for e in row["evidence"] if e["field"].endswith(".item_id")])


@unittest.skipUnless(find_game_dir() and RARITY.is_file() and any(RECORDING.glob("frame-*.png")),
                     "local Steam client, rarity snapshot and recording frames required")
class BankEmptySynthOnReplayTests(unittest.TestCase):
    def test_tech_notes_are_identified_by_the_synthetic_tier_alone(self):
        from core.recognition_assets import RecognitionAssetCatalog
        from core.recognition_synth_provider import SynthProvider
        from tools.scanner_consolidation_replay import LockedReplayCapture, ReplayCancel, build_inventory_matcher
        with tempfile.TemporaryDirectory() as root:
            capture = LockedReplayCapture(RECORDING)
            matcher, close = build_inventory_matcher(capture, RecognitionAssetCatalog(), None)
            matcher.synth_provider = SynthProvider(Path(root) / "assets", Path(root) / "synth", RARITY)
            try:
                result = matcher({"inventory_scan_profile": "tech_notes"}, ReplayCancel(), lambda *_: None)
                capture.close()  # the synthetic tier sends no input: the recording replays exactly
            finally:
                close()
        row = (result.candidates if hasattr(result, "candidates") else result)[0]
        note = next(e["note"] for e in row["evidence"] if e["field"] == "tile_bank")
        stats = dict(item.split("=") for item in note.split(";"))
        self.assertEqual("45", stats["confident"])
        self.assertEqual("45", stats["agree"])
        self.assertEqual("0", stats["disagree"])
        drift = next(e for e in row["evidence"] if e["field"] == "synth_drift")
        self.assertEqual("ok", drift["status"])


if __name__ == "__main__":
    unittest.main()
