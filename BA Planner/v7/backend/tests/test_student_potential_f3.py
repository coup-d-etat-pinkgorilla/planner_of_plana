from copy import deepcopy
import hashlib
import json
from pathlib import Path
from threading import Event
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StatMenuCaptureAdapter, StudentMatcherAdapter, Match
from core.scanner_session import ScannerError
from core.student_candidate_validation import StudentCandidateValidator
from core.student_potential_recognizer import StudentPotentialRecognizer, POTENTIAL_FIELDS
from core.student_scan_recognizer import Observation, ratio_crop
from test_student_weapon_s2w import StableBasicCapture
from test_student_panel_f2 import ScriptedUI, FakeRecognizer, FastEvent
from core.student_panel_recovery import StudentPanelRecovery

FIXTURES = Path(__file__).parent / "fixtures"


def obs(value, source="fixture", status="ok"):
    return Observation(value, 1 if value is not None else 0, status, source, "")


class Menu:
    def __init__(self, error=None):
        self.opens = self.recaptures = self.closes = 0
        self.error = error
        self.recovery = SimpleNamespace(state="basic", recognizer=SimpleNamespace(classify=lambda frame:"basic"))
    def capture_stat_menu(self, target, cancel):
        self.opens += 1
        if self.error: raise self.error
        return Image.new("RGB", (4,4))
    def recapture_stat_menu(self, target, cancel):
        self.recaptures += 1
        return Image.new("RGB", (4,4))
    def close_stat_menu(self, target): self.closes += 1


class PotentialF3Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = RecognitionAssetCatalog()
        cls.recognizer = StudentPotentialRecognizer(cls.catalog)
    @classmethod
    def tearDownClass(cls): cls.recognizer.close()
    def gate(self, level=90, star=5):
        return {"level": obs(level), "student_star": obs(star)}
    def values(self, *values): return dict(zip(POTENTIAL_FIELDS, (obs(v) for v in values)))
    def resolve(self, basic, detail=None, menu=None, gate=None):
        with patch.object(self.recognizer, "recognize_basic", return_value=basic), \
             patch.object(self.recognizer, "recognize_menu", return_value=detail or {}) as read:
            result = self.recognizer.resolve({}, gate or self.gate(), menu, {}, Event())
            return result, read.call_count

    def test_parity_regions_and_all_template_labels(self):
        parity = json.loads((FIXTURES/"student_potential_f3_v6_parity.json").read_text())
        self.assertEqual(parity["basic_regions"], self.recognizer.regions["basic"])
        self.assertEqual(parity["detail_regions"], self.recognizer.regions["detail"])
        basic_bank = self.recognizer._bank("basic")
        self.assertEqual(set(range(1, 26)), set(basic_bank))
        self.assertTrue(all(len(variants) == 1 for variants in basic_bank.values()))
        for kind in ("hp", "atk", "heal"):
            detail_bank = self.recognizer._detail_bank(kind)
            self.assertEqual(set(range(26)), set(detail_bank))
        for asset in self.catalog.assets("student", "student-potential-template"):
            kind, value = asset.identity.split(":")
            with self.subTest(kind=kind, value=value), Image.open(self.catalog.resolve(asset.path)) as crop:
                result = self.recognizer.read_value(crop, kind)
                self.assertEqual(int(value), result.value)
                self.assertTrue(result.confirmed)

    def test_locked_gate_no_panel(self):
        for level, star in ((89,5),(90,4),(None,3),(20,None)):
            menu = Menu()
            result = self.recognizer.resolve({}, self.gate(level,star), menu, {}, Event())
            self.assertEqual([0,0,0], [result[f].value for f in POTENTIAL_FIELDS])
            self.assertEqual(0, menu.opens)

    def test_readiness_and_locked_gate_do_not_decode_numeric_banks(self):
        with patch(
            "core.student_potential_recognizer._basic_template_pattern",
            side_effect=AssertionError("unneeded template decode"),
        ), patch(
            "core.student_potential_recognizer._detail_ui_feature",
            side_effect=AssertionError("unneeded detail decode"),
        ), patch(
            "core.student_potential_recognizer._detail_text_feature",
            side_effect=AssertionError("unneeded detail decode"),
        ):
            recognizer = StudentPotentialRecognizer(self.catalog)
            self.addCleanup(recognizer.close)
            result = recognizer.resolve({}, self.gate(1,3), Menu(), {}, Event())
            self.assertEqual([0,0,0], [result[f].value for f in POTENTIAL_FIELDS])

    def test_unknown_gate_no_panel_or_zero(self):
        menu = Menu()
        result = self.recognizer.resolve({}, self.gate(90,None), menu, {}, Event())
        self.assertTrue(all(result[f].status == "dependency_missing" and result[f].value is None for f in POTENTIAL_FIELDS))
        self.assertEqual(0, menu.opens)

    def test_unconfirmed_level_does_not_unlock(self):
        gate = self.gate()
        gate["level"] = obs(90, status="uncertain")
        self.assertEqual("unknown", self.recognizer.gate(gate))

    def test_blank_dark_or_ambiguous_badge_never_zero(self):
        for color in ("black", "white", (110,110,110)):
            with Image.new("RGB", (100,60), color) as crop:
                self.assertIsNone(self.recognizer.badge(crop).value)
                self.assertIsNone(self.recognizer.read_value(crop, "basic").value)
        with Image.new("RGB", (100,60), (235,242,247)) as crop:
            ImageDraw.Draw(crop).rectangle((0,0,4,59), fill=(65,95,145))
            self.assertIsNone(self.recognizer.badge(crop).value)

    def test_confirmed_absence_all_zero_and_no_menu(self):
        with Image.new("RGB", (100,60), (235,242,247)) as crop:
            ImageDraw.Draw(crop).rectangle((1,20,8,32), fill=(30,30,30))
            images = {"potential_badge_"+k:crop for k in ("hp","atk","heal")}
            menu = Menu()
            result = self.recognizer.resolve(images, self.gate(), menu, {}, Event())
            self.assertEqual([0,0,0], [result[f].value for f in POTENTIAL_FIELDS])
            self.assertTrue(all(result[f].source == "potential_badge_absent" for f in POTENTIAL_FIELDS))
            self.assertEqual(0, menu.opens)

    def test_present_badge_without_digits_does_not_infer_zero(self):
        with Image.new("RGB", (100,60), (65,95,145)) as crop:
            self.assertEqual("present", self.recognizer.badge(crop).value)
            self.assertIsNone(self.recognizer.read_value(crop, "basic").value)

    def test_confirmed_basic_intermediate_and_partial_max_skip_detail(self):
        menu = Menu()
        result, calls = self.resolve(self.values(0,25,12), menu=menu)
        self.assertEqual(0, menu.opens)
        self.assertEqual(0, calls)
        self.assertEqual(12, result["stat_heal"].value)

    def test_unresolved_reads_detail_preserves_confirmed_and_closes(self):
        menu = Menu()
        result, calls = self.resolve(self.values(25,None,12), self.values(None,8,12), menu)
        self.assertEqual([25,8,12], [result[f].value for f in POTENTIAL_FIELDS])
        self.assertEqual((1,0,1,1), (menu.opens,menu.recaptures,menu.closes,calls))

    def test_conflict_keeps_first_value_and_review_source(self):
        result, _ = self.resolve(self.values(25,None,12), self.values(24,8,12), Menu())
        self.assertEqual(25, result["stat_hp"].value)
        self.assertEqual("panel_value_conflict", result["stat_hp"].source)
        self.assertFalse(result["stat_hp"].confirmed)

    def test_unknown_detail_bounded_three_reads(self):
        menu = Menu()
        basic = {f:obs(None, status="dependency_missing") for f in POTENTIAL_FIELDS}
        result, calls = self.resolve(basic, self.values(None,None,None), menu)
        self.assertEqual((1,2,1,3), (menu.opens,menu.recaptures,menu.closes,calls))
        self.assertTrue(all(result[f].status == "dependency_missing" for f in POTENTIAL_FIELDS))

    def test_safe_open_failure_retains_known_values(self):
        menu = Menu(ScannerError("panel_open_failed", "ignored"))
        result, calls = self.resolve(self.values(25,None,12), menu=menu)
        self.assertEqual(25, result["stat_hp"].value)
        self.assertIsNone(result["stat_atk"].value)
        self.assertEqual("partial", result["stat_panel"].status)
        self.assertEqual((1,0), (menu.closes,calls))

    def test_unsafe_return_failure_propagates(self):
        menu = Menu(ScannerError("panel_restore_failed", "unknown"))
        with self.assertRaises(ScannerError): self.resolve(self.values(25,None,12), menu=menu)
        self.assertEqual(1, menu.closes)

    def test_cancellation_closes_without_read(self):
        cancel = Event(); cancel.set()
        menu = Menu()
        with patch.object(self.recognizer, "recognize_menu") as read:
            with self.assertRaises(ScannerError):
                self.recognizer.resolve({}, self.gate(), menu, {}, cancel)
            read.assert_not_called()
        self.assertEqual(1, menu.closes)

    def test_stat_adapter_same_student_recovery(self):
        ui = ScriptedUI(["basic","stat","stat","basic"])
        recovery = StudentPanelRecovery(ui, None, recognizer=FakeRecognizer())
        self.addCleanup(recovery.close)
        menu = StatMenuCaptureAdapter(ui, self.catalog, recovery=recovery)
        with patch("core.student_panel_recovery.Event", FastEvent):
            menu.capture_stat_menu({}, FastEvent()).close()
            menu.close_stat_menu({})
        self.assertEqual("basic", recovery.state)
        self.assertEqual(2, len(ui.actions))

    def test_matcher_integration_fresh_fields_even_with_profile(self):
        menu = Menu()
        matcher = StudentMatcherAdapter(StableBasicCapture(), self.catalog, stat_menu=menu)
        self.addCleanup(matcher.potential_recognizer.close)
        basic = {**self.gate(), "weapon_level":obs(None), "weapon_star":obs(None)}
        with patch.object(matcher.matcher, "match", return_value=Match("mika",1,1)), \
             patch.object(matcher.basic_recognizer, "recognize", return_value=basic), \
             patch.object(matcher.weapon_recognizer, "read_state", return_value=obs("weapon_unlocked_not_equipped")), \
             patch.object(matcher.equipment_recognizer, "recognize", return_value=({},())), \
             patch.object(matcher.potential_recognizer, "recognize_basic", return_value=self.values(None,None,None)), \
             patch.object(matcher.potential_recognizer, "recognize_menu", return_value={f:obs(v,"potential_hp_template") for f,v in zip(POTENTIAL_FIELDS,(0,12,25))}):
            result = matcher._scan_current({"profile_id":"persisted-profile"}, Event(), lambda *args:None)[0]
        self.addCleanup(matcher._close_answer_specimens, [result])
        self.assertEqual(1, menu.opens)
        self.assertEqual([0,12,25], [result["payload"]["values"][f] for f in POTENTIAL_FIELDS])
        self.assertNotIn("combat_hp", result["payload"]["values"])

    def test_actual_1280_2560_basic_detail_and_locked_regression(self):
        root = FIXTURES/"student_potential_f3_live"
        manifest = json.loads((root/"manifest.json").read_text())
        for row in manifest["assets"]:
            with self.subTest(file=row["file"]):
                path = root/row["file"]
                self.assertEqual(row["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
                with Image.open(path) as frame:
                    if row["panel"] == "stat":
                        result = self.recognizer.recognize_menu(frame)
                    else:
                        images = {"potential_badge_"+k:ratio_crop(frame,v) for k,v in self.recognizer.regions["basic"].items()}
                        try:
                            result = self.recognizer.recognize_basic(images,self.gate(row["level"],row["student_star"]))
                        finally:
                            for crop in images.values(): crop.close()
                self.assertEqual(row["potential"], [result[f].value for f in POTENTIAL_FIELDS])
                self.assertTrue(all(result[f].confirmed for f in POTENTIAL_FIELDS))

    def test_native_1280_basic_uses_all_25_templates_without_detail(self):
        root = FIXTURES/"student_potential_f3_live"
        with Image.open(root/"mika-basic-1280.png") as frame:
            images = {"potential_badge_"+k:ratio_crop(frame,v) for k,v in self.recognizer.regions["basic"].items()}
        self.addCleanup(lambda: [crop.close() for crop in images.values()])
        menu = Menu()
        result = self.recognizer.resolve(images, self.gate(), menu, {}, Event())
        self.assertEqual([25,25,25], [result[f].value for f in POTENTIAL_FIELDS])
        self.assertEqual((0,0,0), (menu.opens,menu.recaptures,menu.closes))


class PotentialProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.payload = {"version":1, "student_id":"mika", "values":{
            "level":90, "student_star":5, "bond_rank":74, "skill2":10,
            "equip1":"T10", "equip1_level":70, "equip2":"T10", "equip2_level":70,
            "equip3":"T10", "equip3_level":70, "weapon_state":"weapon_equipped",
            "weapon_star":4, "weapon_level":60, "combat_hp":95756,"combat_atk":6893,
            "combat_def":121,"combat_heal":5948}}
        self.stored = {"student_id":"mika", "values":{f:25 for f in POTENTIAL_FIELDS}}
        self.validator = StudentCandidateValidator(SimpleNamespace(get_state=lambda _: {"students":[deepcopy(self.stored)]}))

    def test_profile_fallback_is_explicit_and_not_fresh(self):
        original = deepcopy(self.payload)
        evidence = self.validator(self.payload, "profile")
        self.assertEqual("dependency_missing", evidence["status"])
        self.assertTrue(all(row == {"value":25,"source":"profile_fallback","fresh":False} for row in evidence["details"]["potential_inputs"].values()))
        self.assertEqual(original, self.payload)

    def test_fresh_values_override_stale_profile(self):
        self.stored["values"] = {f:0 for f in POTENTIAL_FIELDS}
        self.payload["values"].update({f:25 for f in POTENTIAL_FIELDS})
        self.payload["provenance"] = {f:"potential_basic_template" for f in POTENTIAL_FIELDS}
        evidence = self.validator(self.payload, "profile")
        self.assertNotEqual("dependency_missing", evidence["status"])
        self.assertFalse(any(row.get("key") in POTENTIAL_FIELDS for row in evidence["details"]["dependencies"]))
        self.assertTrue(all(row["fresh"] and row["value"] == 25 for row in evidence["details"]["potential_inputs"].values()))

    def test_conflict_cannot_be_verified_even_when_preserved_value_matches(self):
        self.payload["values"].update({f:25 for f in POTENTIAL_FIELDS})
        self.payload["provenance"] = {"stat_hp":"panel_value_conflict"}
        self.assertEqual("dependency_missing", self.validator(self.payload, "profile")["status"])

    def test_locked_ignores_stale_profile_potential(self):
        self.payload["values"]["level"] = 89
        evidence = self.validator(self.payload, "profile")
        self.assertTrue(all(row["value"] == 0 and row["source"] == "potential_gate" for row in evidence["details"]["potential_inputs"].values()))

    def test_out_of_range_or_bool_not_accepted_as_fresh(self):
        self.payload["values"].update(dict(stat_hp=True,stat_atk=26,stat_heal=-1))
        evidence = self.validator(self.payload, "profile")
        self.assertEqual("dependency_missing", evidence["status"])
        self.assertTrue(all(not row["fresh"] for row in evidence["details"]["potential_inputs"].values()))


if __name__ == "__main__": unittest.main()
