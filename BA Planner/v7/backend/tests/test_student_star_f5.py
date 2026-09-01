import hashlib
import json
from pathlib import Path
from threading import Event
import unittest
from unittest.mock import patch

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter, StarMenuCaptureAdapter, Match
from core.scanner_session import ScannerError
from core.student_candidate_validation import StudentCandidateValidator
from core.student_panel_recovery import StudentPanelRecovery, StudentPanelRecognizer
from core.student_scan_recognizer import Observation
from core.student_star_recognizer import StudentStarRecognizer
from core.student_weapon_recognizer import StudentWeaponRecognizer
from test_student_panel_f2 import ScriptedUI, FakeRecognizer, FastEvent
from test_student_weapon_s2w import StableBasicCapture

FIXTURES = Path(__file__).parent / "fixtures"


def obs(value, source="basic_star_color", status=None):
    return Observation(value,1 if value is not None else 0,status or ("ok" if value is not None else "uncertain"),source,"")


class Menu:
    def __init__(self, error=None, cancel=None):
        self.opens = self.closes = 0
        self.error, self.cancel = error, cancel
        self.recovery = type("Recovery", (), {"state": "basic"})()
    def capture_star_menu(self, target, cancel):
        self.opens += 1
        if self.error: raise self.error
        if self.cancel: self.cancel.set()
        return Image.new("RGB", (8,8))
    def close_star_menu(self, target): self.closes += 1


class StarF5Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.catalog = RecognitionAssetCatalog()

    def setUp(self):
        self.reader = StudentStarRecognizer(self.catalog)
        self.addCleanup(self.reader.close)

    def frame(self, value, size):
        frame = Image.new("RGB",size,"white")
        region = self.reader.regions["student_star_region"]
        box = tuple(round(region[key]*scale) for key,scale in zip(("x1","y1","x2","y2"),(size[0],size[1],size[0],size[1])))
        with Image.open(self.catalog.resolve(f"templates/student_star/star_{value}.png")) as source:
            with source.resize((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS) as crop:
                frame.paste(crop,box[:2])
        return frame

    def test_parity_all_five_stars_at_two_resolutions(self):
        parity = json.loads((FIXTURES/"student_star_f5_v6_parity.json").read_text())
        self.assertEqual(parity["regions"],self.reader.regions)
        for size in ((1280,720),(2560,1440)):
            for value in parity["labels"]:
                with self.subTest(size=size,value=value), self.frame(value,size) as frame:
                    self.assertEqual(value,self.reader.recognize_menu(frame)["student_star"].value)

    def test_blank_dark_and_uniform_frames_do_not_default_to_one(self):
        for color in ("black","white",(120,120,120)):
            with Image.new("RGB",(1280,720),color) as frame:
                self.assertIsNone(self.reader.recognize_menu(frame)["student_star"].value)

    def test_no_templates_is_uncertain(self):
        self.reader.templates = {}
        with self.frame(3,(1280,720)) as frame:
            self.assertIsNone(self.reader.recognize_menu(frame)["student_star"].value)

    def test_tied_template_candidates_are_uncertain(self):
        with self.frame(3,(1280,720)) as frame, patch.object(StudentWeaponRecognizer,"_rank",return_value=("3",.95,.01)):
            self.assertIsNone(self.reader.recognize_menu(frame)["student_star"].value)

    def test_real_f2_star_panel_is_five(self):
        with Image.open(FIXTURES/"student_panel_f2_live/star.png") as frame:
            self.assertEqual(5,self.reader.recognize_menu(frame)["student_star"].value)

    def test_native1280_current_stars_not_upgrade_preview_and_return(self):
        root = FIXTURES/"student_star_f5_live"
        panel = StudentPanelRecognizer(self.catalog)
        self.addCleanup(panel.close)
        for row in json.loads((root/"manifest.json").read_text())["assets"]:
            path = root/row["file"]
            self.assertEqual(row["sha256"],hashlib.sha256(path.read_bytes()).hexdigest())
            with self.subTest(file=row["file"]), Image.open(path) as frame:
                self.assertEqual((1280,720),frame.size)
                self.assertEqual(row["state"],panel.classify(frame))
                if row["state"] == "star":
                    self.assertEqual(row["student_star"],self.reader.recognize_menu(frame)["student_star"].value)

    def test_unavailable_menu_preserves_unresolved_observation(self):
        previous = obs(None)
        self.assertIs(previous,self.reader.resolve({"student_star":previous},obs(None),None,{},Event())["student_star"])

    def test_basic_success_no_click_no_bank(self):
        for value in range(1,6):
            menu = Menu()
            result = self.reader.resolve({"student_star":obs(value)},obs(None),menu,{},Event())
            self.assertEqual(value,result["student_star"].value)
            self.assertEqual((0,0),(menu.opens,menu.closes))
        self.assertIsNone(self.reader.templates)

    def test_independent_equipped_and_unlocked_empty_infer_five_without_click(self):
        weapon = StudentWeaponRecognizer(self.catalog)
        self.addCleanup(weapon.close)
        for state in ("weapon_equipped","weapon_unlocked_not_equipped"):
            with Image.open(FIXTURES/f"student_weapon_s2w_v6_parity/state/{state}.png") as crop:
                independent = weapon.read_state(crop,student_star=None)
            self.assertEqual(state,independent.value)
            menu = Menu()
            result = self.reader.resolve({"student_star":obs(None)},independent,menu,{},Event())["student_star"]
            self.assertEqual((5,"inferred","independent_weapon_flag"),(result.value,result.status,result.source))
            self.assertEqual(0,menu.opens)
        self.assertIsNone(self.reader.templates)

    def test_direct_star_conflicts_are_sticky_not_overwritten(self):
        for value in range(1,5):
            menu = Menu()
            result = self.reader.resolve({"student_star":obs(value)},obs("weapon_equipped","basic_weapon_state_template"),menu,{},Event())
            conflict = result["student_star"]
            self.assertEqual(value,conflict.value)
            self.assertFalse(conflict.confirmed)
            self.assertEqual("panel_value_conflict",conflict.source)
            self.assertIn("independent_weapon_flag=5",conflict.note)
            self.assertIs(conflict,self.reader.resolve(result,obs(None),menu,{},Event())["student_star"])
            self.assertEqual(0,menu.opens)

    def test_agreeing_five_preserves_direct_source(self):
        previous = obs(5)
        result = self.reader.resolve({"student_star":previous},obs("weapon_equipped","basic_weapon_state_template"),Menu(),{},Event())
        self.assertIs(previous,result["student_star"])

    def test_inferred_gates_and_values_never_create_circular_inference(self):
        for source,status in (("student_star_gate","inferred"),("basic_weapon_values","inferred"),
                              ("student_star_gate","ok"),("basic_weapon_state_template","inferred")):
            menu = Menu()
            with patch.object(self.reader,"recognize_menu",return_value={"student_star":obs(2,"star_tab_template")}):
                result = self.reader.resolve({"student_star":obs(None)},obs("weapon_equipped",source,status),menu,{},Event())
            self.assertEqual(2,result["student_star"].value)
            self.assertEqual((1,1),(menu.opens,menu.closes))

    def test_unknown_or_locked_weapon_uses_tab_and_preserves_other_fields(self):
        for state in (None,"no_weapon_system"):
            menu = Menu()
            initial = {"student_star":obs(None),"level":obs(90),"skill1":obs(10)}
            with patch.object(self.reader,"recognize_menu",return_value={"student_star":obs(4,"star_tab_template")}) as read:
                result = self.reader.resolve(initial,obs(state,"basic_weapon_state_template"),menu,{},Event())
            self.assertEqual(4,result["student_star"].value)
            self.assertEqual(1,read.call_count)
            self.assertEqual((1,1),(menu.opens,menu.closes))
            self.assertEqual(90,initial["level"].value)
            self.assertEqual(10,initial["skill1"].value)

    def test_safe_open_failure_is_partial(self):
        menu = Menu(ScannerError("panel_open_failed","ignored",details={"screen_state":"basic"}))
        result = self.reader.resolve({"student_star":obs(None)},obs(None),menu,{},Event())
        self.assertEqual("partial",result["star_panel"].status)

    def test_failed_detail_is_one_read_and_partial(self):
        menu = Menu()
        with patch.object(self.reader,"recognize_menu",return_value={"student_star":obs(None)}) as read:
            result = self.reader.resolve({"student_star":obs(None)},obs(None),menu,{},Event())
        self.assertEqual(1,read.call_count)
        self.assertEqual((1,1),(menu.opens,menu.closes))
        self.assertEqual("partial",result["star_panel"].status)

    def test_cancel_after_open_prevents_read_and_closes(self):
        cancel = Event(); menu = Menu(cancel=cancel)
        with patch.object(self.reader,"recognize_menu",side_effect=AssertionError("read after cancel")):
            with self.assertRaises(ScannerError) as caught:
                self.reader.resolve({"student_star":obs(None)},obs(None),menu,{},cancel)
        self.assertEqual("cancelled",caught.exception.code)
        self.assertEqual(1,menu.closes)

    def test_restore_failure_is_not_partial_success(self):
        menu = Menu()
        with patch.object(self.reader,"recognize_menu",return_value={"student_star":obs(3)}), \
             patch.object(menu,"close_star_menu",side_effect=ScannerError("panel_restore_failed","unsafe")):
            with self.assertRaises(ScannerError) as caught:
                self.reader.resolve({"student_star":obs(None)},obs(None),menu,{},Event())
        self.assertEqual("panel_restore_failed",caught.exception.code)

    def test_star_return_uses_basic_tab(self):
        ui = ScriptedUI(["basic","star","star","basic"])
        recovery = StudentPanelRecovery(ui,None,recognizer=FakeRecognizer())
        self.addCleanup(recovery.close)
        menu = StarMenuCaptureAdapter(ui,self.catalog,recovery=recovery)
        with patch("core.student_panel_recovery.Event",FastEvent):
            menu.capture_star_menu({},FastEvent()).close();menu.close_star_menu({})
        self.assertEqual(("click",*recovery._center(recovery.regions["basic_info_button"])),ui.actions[-1])
        self.assertEqual("basic",recovery.state)

    def test_different_student_return_fails(self):
        ui = ScriptedUI(["basic","star","other-student"])
        recovery = StudentPanelRecovery(ui,None,recognizer=FakeRecognizer())
        self.addCleanup(recovery.close)
        menu = StarMenuCaptureAdapter(ui,self.catalog,recovery=recovery)
        with patch("core.student_panel_recovery.Event",FastEvent):
            menu.capture_star_menu({},FastEvent()).close()
            with self.assertRaises(ScannerError): menu.close_star_menu({})

    def test_conflicting_star_cannot_be_validated_as_confirmed_stats(self):
        validator = StudentCandidateValidator(None)
        result = validator({"student_id":"mika","values":{"level":90,"student_star":3,"bond_rank":1},
                            "provenance":{"student_star":"panel_value_conflict"}},None)
        self.assertEqual("partial",result["status"])
        self.assertIn("conflict",result["note"])

    def test_matcher_independent_state_before_star_and_potential_gates(self):
        matcher = StudentMatcherAdapter(StableBasicCapture(),self.catalog)
        for r in (matcher.star_recognizer,matcher.level_recognizer,matcher.potential_recognizer,matcher.weapon_recognizer):
            self.addCleanup(r.close)
        basic = {"level":obs(90),"student_star":obs(None),"weapon_level":obs(None),"weapon_star":obs(None)}
        def potential(images, observations, *args):
            self.assertEqual(5,observations["student_star"].value)
            return {}
        with patch.object(matcher.matcher,"match",return_value=Match("mika",1,1)), \
             patch.object(matcher.basic_recognizer,"recognize",return_value=basic), \
             patch.object(matcher.weapon_recognizer,"read_state",return_value=obs("weapon_unlocked_not_equipped","basic_weapon_state_template")) as state, \
             patch.object(matcher.potential_recognizer,"resolve",side_effect=potential), \
             patch.object(matcher.equipment_recognizer,"recognize",return_value=({},())):
            result = matcher._scan_current({},Event(),lambda *a:None)[0]
        self.addCleanup(matcher._close_answer_specimens,[result])
        self.assertEqual(1,state.call_count)
        self.assertIsNone(state.call_args.kwargs["student_star"])
        self.assertEqual(5,result["payload"]["values"]["student_star"])
        self.assertEqual("independent_weapon_flag",result["payload"]["provenance"]["student_star"])

    def test_matcher_conflict_retains_direct_value_and_requires_review(self):
        matcher = StudentMatcherAdapter(StableBasicCapture(),self.catalog)
        for r in (matcher.star_recognizer,matcher.level_recognizer,matcher.potential_recognizer,matcher.weapon_recognizer):
            self.addCleanup(r.close)
        basic = {"level":obs(90),"student_star":obs(3),"weapon_level":obs(60),"weapon_star":obs(4)}
        def potential(images, observations, *args):
            self.assertFalse(observations["student_star"].confirmed)
            return {}
        with patch.object(matcher.matcher,"match",return_value=Match("mika",1,1)), \
             patch.object(matcher.basic_recognizer,"recognize",return_value=basic), \
             patch.object(matcher.weapon_recognizer,"read_state",return_value=obs("weapon_equipped","basic_weapon_state_template")), \
             patch.object(matcher.potential_recognizer,"resolve",side_effect=potential), \
             patch.object(matcher.equipment_recognizer,"recognize",return_value=({},())):
            result = matcher._scan_current({},Event(),lambda *a:None)[0]
        self.addCleanup(matcher._close_answer_specimens,[result])
        self.assertTrue(result["review_required"])
        self.assertEqual(3,result["payload"]["values"]["student_star"])
        self.assertEqual("panel_value_conflict",result["payload"]["provenance"]["student_star"])
        self.assertEqual("weapon_equipped",result["payload"]["values"]["weapon_state"])


if __name__ == "__main__": unittest.main()
