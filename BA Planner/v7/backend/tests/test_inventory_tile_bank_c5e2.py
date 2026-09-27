"""C5e-2: tile bank fast path, order prior, and learning from detail-confirmed tiles."""
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from PIL import Image, ImageDraw

from core.inventory_detail_recovery import DetailCount, DetailRecoveryResult, DetailResult
from core.inventory_navigation import PageMove, PreparedInventory
from core.inventory_tile_bank import BankMatch, TileBank
from core.recognition_image_ops import icon_vector_similarity, icon_vectors, ncc_per_channel_icon
from core.scanner_matchers import CountMatch, InventoryMatcherAdapter, Match, _InventoryScan
from core.scanner_session import ScanBatchResult, ScannerError
from test_inventory_detail_f9 import GridUI, SLOTS, ITEM, OTHER
from test_student_panel_f2 import FastEvent


def tile(colour, shape=0):
    image = Image.new("RGB", (117, 96), (230, 230, 230))
    draw = ImageDraw.Draw(image)
    draw.polygon([(30, 10 + shape), (85, 14), (80, 70), (26, 66 - shape)], fill=colour)
    draw.ellipse((45 + shape, 25, 65, 45 + shape), fill=(20, 20, 20))
    return image


class VectorAndBankTests(unittest.TestCase):
    def test_precomputed_vectors_give_the_same_m4(self):
        a, b = tile((210, 50, 50)), tile((50, 50, 210), 6)
        self.assertAlmostEqual(ncc_per_channel_icon(a, b), icon_vector_similarity(icon_vectors(a), icon_vectors(b)), places=9)
        self.assertAlmostEqual(1.0, icon_vector_similarity(icon_vectors(a), icon_vectors(a)), places=9)

    def test_bank_ranks_by_identity_and_reports_the_margin(self):
        bank = TileBank()
        bank.add("red", tile((210, 50, 50)))
        bank.add("blue", tile((50, 50, 210)))
        result = bank.match(tile((210, 50, 50)))
        self.assertEqual("red", result.identity)
        self.assertTrue(result.confident)
        self.assertAlmostEqual(result.score - dict(result.ranked)["blue"], result.margin)
        self.assertEqual("blue", bank.match(tile((210, 50, 50)), candidates={"blue"}).identity)
        self.assertIsNone(TileBank().match(tile((1, 2, 3))).identity)

    def test_user_confirmed_tier_outranks_session_for_the_same_identity(self):
        bank = TileBank()
        bank.add("red", tile((210, 50, 50)))
        bank.add("red", tile((212, 52, 50)), "user_confirmed")
        self.assertEqual("user_confirmed", bank.match(tile((210, 50, 50))).tier)
        self.assertEqual(2, len(bank.entries["red"].samples))

    def test_order_prior_restricts_candidates_to_the_neighbours_interval(self):
        # Two colour tiers of one shape (the "colour play" case): only the one ordered between the neighbours
        # is a candidate, so a slot the unrestricted bank ranks outside the interval is not confirmed.
        bank = TileBank()
        for name, colour in (("t1", (200, 60, 60)), ("t2", (205, 62, 58)), ("t3", (60, 60, 200))):
            bank.add(name, tile(colour))
        order = {"t1": 1, "t2": 2, "t3": 3}
        overall, between = bank.match_between(tile((205, 62, 58)), None, order, 1, 3)
        self.assertEqual("t2", between.identity)
        self.assertEqual(("t2",), tuple(identity for identity, _ in between.ranked))
        overall, between = bank.match_between(tile((200, 60, 60)), None, order, 1, 3)
        self.assertEqual("t1", overall.identity)
        self.assertNotEqual(overall.identity, between.identity)


class ScriptedBank:
    """Bank double: fixed guesses per call, records learning."""
    def __init__(self, guesses, between=None):
        self.guesses = list(guesses)
        self.between = between
        self.added = []
        self.entries = {"zzz_other_profile": None}

    def __len__(self):
        return 1

    def match(self, crop, candidates=None, vectors=None, allow_synth=True):
        return self.guesses.pop(0)

    def match_between(self, crop, allowed, order, low, high, allow_synth=True):
        return self.between

    def add(self, identity, crop, tier="session"):
        self.added.append(identity)


class AdapterBankTests(unittest.TestCase):
    def adapter(self, count, bank):
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
        adapter.tile_banks = {(40, 40): bank}
        nav = Mock()
        nav.phase_residuals.return_value = [0.0, 0.0]
        nav.prepare.return_value = PreparedInventory("item", "tech_notes", True, True)
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
    def bank_note(row):
        return next(e["note"] for e in row["evidence"] if e["field"] == "tile_bank")

    def test_banked_identity_with_a_confident_grid_count_skips_the_detail_panel(self):
        adapter = self.adapter("42", ScriptedBank([BankMatch(ITEM, .96, .05, "session")]))
        row = self.scan(adapter)
        adapter.detail_recovery.read.assert_not_called()
        adapter.detail_recovery.begin_page.assert_not_called()
        entry, = [e for e in row["payload"]["entries"] if e["observed_slot"] == 0]
        self.assertEqual((ITEM, "42"), (entry["item_id"], entry["quantity"]))
        self.assertIn("tile_bank_session", [e["source"] for e in row["evidence"]])
        self.assertIn("skipped_detail=1", self.bank_note(row))

    def test_without_a_grid_count_the_detail_panel_reads_it_and_the_bank_learns(self):
        bank = ScriptedBank([BankMatch(ITEM, .96, .05, "session")])
        adapter = self.adapter(None, bank)
        row = self.scan(adapter)
        adapter.detail_recovery.read.assert_called_once()
        self.assertEqual([ITEM], bank.added)
        self.assertIn("agree=1", self.bank_note(row))
        self.assertIn("learned=1", self.bank_note(row))

    def test_disagreement_with_the_detail_panel_is_recorded_and_the_detail_wins(self):
        bank = ScriptedBank([BankMatch(OTHER, .96, .05, "session")])
        adapter = self.adapter(None, bank)
        row = self.scan(adapter)
        self.assertEqual(ITEM, [e for e in row["payload"]["entries"] if e["observed_slot"] == 0][0]["item_id"])
        self.assertIn("disagree=1", self.bank_note(row))
        self.assertEqual("uncertain", next(e["status"] for e in row["evidence"] if e["field"] == "tile_bank"))

    def test_a_tile_the_detail_panel_reads_but_cannot_name_is_unknown_new(self):
        adapter = self.adapter(None, ScriptedBank([BankMatch(None, 0.0, 0.0)]))
        adapter.detail_recovery.read.return_value = DetailRecoveryResult(DetailResult(None, .4, 0, DetailCount(None, reason="weak_x_match")))
        row = self.scan(adapter)
        slot, = [e for e in row["evidence"] if e["field"] == "slots[0]"]
        self.assertTrue(slot["note"].startswith("unknown_new;"))
        self.assertIn("unknown_new=1", self.bank_note(row))

    def test_a_failed_detail_read_is_not_unknown_new(self):
        adapter = self.adapter(None, ScriptedBank([BankMatch(None, 0.0, 0.0)]))
        adapter.detail_recovery.read.return_value = DetailRecoveryResult(restored=False, failure=ScannerError("capture_failed", "fixture"))
        row = self.scan(adapter)
        slot, = [e for e in row["evidence"] if e["field"] == "slots[0]"]
        self.assertFalse(slot["note"].startswith("unknown_new;"))

    def count_bank(self, read, ready=True):
        from core.inventory_count_bank import CountRead
        bank = Mock()
        bank.ready.return_value = ready
        bank.read.return_value = CountRead(*read) if read else CountRead(None, "", 0.0, 0.0)
        bank.seed = {}
        bank.learn.return_value = 1
        return bank

    def test_c5e3_confident_count_bank_read_feeds_the_fast_path(self):
        adapter = self.adapter(None, ScriptedBank([BankMatch(ITEM, .96, .05, "session")]))
        adapter.count_banks = {(40, 40): self.count_bank(("42", "x42", .95, .2))}
        row = self.scan(adapter)
        adapter.detail_recovery.read.assert_not_called()
        quantity = [e for e in row["evidence"] if e["field"].endswith(".quantity")][0]
        self.assertEqual("count_bank_session", quantity["source"])
        self.assertEqual("42", [e for e in row["payload"]["entries"] if e["observed_slot"] == 0][0]["quantity"])
        self.assertIn("count_read=1", self.bank_note(row))

    def test_c5e3_unconfident_count_read_keeps_the_detail_panel(self):
        adapter = self.adapter(None, ScriptedBank([BankMatch(ITEM, .96, .05, "session")]))
        adapter.count_banks = {(40, 40): self.count_bank(("42", "x42", .7, .2))}
        self.scan(adapter)
        adapter.detail_recovery.read.assert_called_once()

    def test_c5e3_detail_quantities_check_the_grid_read_then_teach_it(self):
        bank = self.count_bank(("9", "x9", .95, .2))
        adapter = self.adapter(None, ScriptedBank([BankMatch(OTHER, .5, .0, "session")]))
        adapter.count_banks = {(40, 40): bank}
        row = self.scan(adapter)  # grid says 9 (not used: identity unconfident); detail says 7
        note = self.bank_note(row)
        self.assertIn("count_checked=1", note)
        self.assertIn("count_disagree=1", note)
        bank.learn.assert_called_once()
        self.assertEqual("7", bank.learn.call_args.args[1])
        self.assertEqual("uncertain", next(e["status"] for e in row["evidence"] if e["field"] == "tile_bank"))

    def test_an_unconfident_bank_match_never_skips_the_detail_panel(self):
        adapter = self.adapter("42", ScriptedBank([BankMatch(ITEM, .80, .05, "session")]))
        self.scan(adapter)
        adapter.detail_recovery.read.assert_called_once()


class AnchorAndPriorTests(unittest.TestCase):
    def scan(self, guesses, entries=()):
        scan = _InventoryScan(frame=Image.new("RGB", (40, 40)), source_size=(40, 40), target={}, slots=[])
        scan.order = {"a": 1, "b": 2, "c": 3, "d": 4}
        scan.allowed_ids = set(scan.order)
        scan.entries = [dict(item_id=item, observed_slot=i) for i, item in enumerate(entries)]
        scan.read_until = len(entries) - 1
        scan.bank = ScriptedBank(guesses)
        return scan

    def test_confident_tiles_out_of_catalog_order_are_not_anchors(self):
        adapter = object.__new__(InventoryMatcherAdapter)
        visible = {i: dict(x1=0, x2=1, y1=0, y2=1) for i in (1, 2, 3)}
        scan = self.scan([BankMatch("c", .95, .05), BankMatch("b", .95, .05), BankMatch("d", .95, .05)], entries=("a",))
        with patch("core.scanner_matchers.image_has_visible_content", return_value=True):
            adapter._match_page_bank(scan, visible)
        self.assertEqual({1, 3}, scan.bank_anchors)  # "b" after "c" breaks the sorted order

    def test_identities_recorded_in_this_scan_are_never_bank_candidates(self):
        # Live first scans: every confident wrong bank match was an identity already read earlier in the scan.
        bank = TileBank()
        for name, colour in (("a", (200, 60, 60)), ("b", (60, 200, 60))):
            bank.add(name, tile(colour))
        scan = self.scan([], entries=("a",))
        scan.bank = bank
        adapter = object.__new__(InventoryMatcherAdapter)
        with patch("core.scanner_matchers.ratio_crop", side_effect=lambda frame, region: tile((200, 60, 60))),                 patch("core.scanner_matchers.image_has_visible_content", return_value=True):
            adapter._match_page_bank(scan, {1: dict(x1=0, x2=1, y1=0, y2=1)})
        self.assertEqual("b", scan.bank_guesses[1].identity)
        self.assertFalse(scan.bank_guesses[1].confident)

    def test_prior_confirms_only_when_the_overall_best_lies_between_the_neighbours(self):
        adapter = object.__new__(InventoryMatcherAdapter)
        scan = self.scan([], entries=("a",))
        scan.bank_guesses = {1: BankMatch("b", .85, .005), 2: BankMatch("d", .95, .05)}
        scan.bank_anchors = {2}
        scan.bank.between = BankMatch("b", .93, .04)
        with patch.object(ScriptedBank, "match_between", return_value=(BankMatch("b", .85, .005), BankMatch("b", .93, .04))) as between:
            self.assertEqual("b", adapter._bank_identity(scan, 1, Image.new("RGB", (4, 4))).identity)
        # "a" is already recorded in this scan, so it is no candidate for another tile
        self.assertEqual(({"b", "c", "d"}, scan.order, 1, 4, False), between.call_args.args[1:])
        # D23: the prior only narrows. A failed prior asks the whole bank: a confident match to an item that
        # cannot sit here is an order conflict; a weak or in-window match is not. The detail panel decides.
        scan.bank.guesses = [BankMatch("c", .88, .01), BankMatch("zzz_other_profile", .95, .1), BankMatch("zzz", .6, .1)]
        with patch.object(ScriptedBank, "match_between", return_value=(BankMatch("c", .88, .01), BankMatch("b", .93, .04))):
            for _ in range(3):
                self.assertIsNone(adapter._bank_identity(scan, 1, Image.new("RGB", (4, 4))))
        self.assertEqual(1, scan.bank_stats["order_conflict"])
        self.assertEqual(1, scan.bank_stats["order_prior"])


class OrderRunTests(unittest.TestCase):
    def test_longest_increasing_run_skips_outliers_and_unknowns(self):
        from core.inventory_order_rules import increasing_run
        self.assertEqual({0, 1, 3, 4}, increasing_run([1, 2, 9, 3, 4]))
        self.assertEqual({0, 2}, increasing_run([1, None, 5]))
        self.assertEqual(set(), increasing_run([]))

    def test_an_out_of_order_entry_is_flagged_and_only_its_window_skips_zero_fill(self):
        from core.inventory_catalog import CATALOG
        rows = sorted([row for row in CATALOG if row.profile_id == "tech_notes"], key=lambda row: row.order_index)
        scan = _InventoryScan(frame=Image.new("RGB", (4, 4)), source_size=(4, 4), target={}, slots=[])
        scan.prepared = PreparedInventory("item", "tech_notes", True, True)
        scan.order = {row.item_id: row.order_index for row in rows}
        seen = [rows[0], rows[1], rows[20], rows[2], rows[3]]  # rows[20] read out of order
        scan.entries = [dict(item_id=row.item_id, observed_slot=i, quantity="1") for i, row in enumerate(seen)]
        windows = InventoryMatcherAdapter._order_outliers(scan)
        self.assertEqual([(rows[1].order_index, rows[2].order_index)], windows)
        self.assertEqual(["entries[2].order"], [e["field"] for e in scan.evidence])
        InventoryMatcherAdapter._zero_fill(scan, windows)
        filled = {e["item_id"] for e in scan.entries if e["observed_slot"] is None}
        self.assertEqual({row.item_id for row in rows[4:]} - {rows[20].item_id}, filled)

    def test_an_outlier_window_holds_back_its_neighbourhood(self):
        from core.inventory_catalog import CATALOG
        rows = sorted([row for row in CATALOG if row.profile_id == "tech_notes"], key=lambda row: row.order_index)
        scan = _InventoryScan(frame=Image.new("RGB", (4, 4)), source_size=(4, 4), target={}, slots=[])
        scan.prepared = PreparedInventory("item", "tech_notes", True, True)
        scan.order = {row.item_id: row.order_index for row in rows}
        seen = [rows[0], rows[30], rows[10], rows[40]]  # rows[30] breaks the run between 0 and 10
        scan.entries = [dict(item_id=row.item_id, observed_slot=i, quantity="1") for i, row in enumerate(seen)]
        InventoryMatcherAdapter._zero_fill(scan, InventoryMatcherAdapter._order_outliers(scan))
        filled = {e["item_id"] for e in scan.entries if e["observed_slot"] is None}
        self.assertTrue(filled.isdisjoint(row.item_id for row in rows[1:10]))
        self.assertTrue({row.item_id for row in rows[11:30]} <= filled)


class OrderRulesTests(unittest.TestCase):
    def test_d23_rules_reproduce_the_observed_default_order(self):
        from core.inventory_catalog import CATALOG
        from core.inventory_order_rules import load_metadata, order_key
        meta = load_metadata()
        if not meta:
            self.skipTest("item rarity spec is not installed")
        for profile in ("tech_notes", "presents", "equipment"):
            rows = sorted([row for row in CATALOG if row.profile_id == profile], key=lambda row: row.order_index)
            ruled = sorted(rows, key=lambda row: order_key(profile, row.item_id, meta))
            self.assertEqual([row.item_id for row in rows], [row.item_id for row in ruled], profile)
        # The catalog is generated in rule order, so also hold the rule to a live scan's slot order.
        trace = Path(__file__).resolve().parents[2] / "debug/scanner_c5e1d_live/presents/trace.json"
        entries = json.loads(trace.read_text(encoding="utf-8"))["result"]["candidates"][0]["payload"]["entries"]
        observed = [e["item_id"] for e in sorted((e for e in entries if e["observed_slot"] is not None), key=lambda e: e["observed_slot"])]
        keys = [order_key("presents", item, meta) for item in observed]
        self.assertEqual(56, len(observed))
        self.assertEqual(sorted(keys), keys)



if __name__ == "__main__":
    unittest.main()
