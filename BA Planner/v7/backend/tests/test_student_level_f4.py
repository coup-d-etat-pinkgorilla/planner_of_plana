import hashlib
import json
from pathlib import Path
from threading import Event
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter, LevelMenuCaptureAdapter, Match
from core.scanner_session import ScannerError
from core.student_level_recognizer import StudentLevelRecognizer
from core.student_panel_recovery import StudentPanelRecovery, StudentPanelRecognizer
from core.student_scan_recognizer import Observation, ratio_crop
from core.student_potential_recognizer import StudentPotentialRecognizer, POTENTIAL_FIELDS
from test_student_panel_f2 import ScriptedUI, FakeRecognizer, FastEvent
from test_student_weapon_s2w import StableBasicCapture

FIXTURES = Path(__file__).parent/"fixtures"
LIVE = FIXTURES/"student_level_f4_live"


def obs(value, source="fixture", status=None):
    return Observation(value,1 if value is not None else 0,status or ("ok" if value is not None else "uncertain"),source,"")


class Menu:
    def __init__(self, error=None, cancel=None):
        self.opens = self.recaptures = self.closes = 0
        self.error,self.cancel = error,cancel
        self.recovery = SimpleNamespace(state="basic",recognizer=SimpleNamespace(classify=lambda _:"basic"))
    def capture_level_menu(self,target,cancel):
        self.opens += 1
        if self.error: raise self.error
        if self.cancel: self.cancel.set()
        return Image.new("RGB",(8,8))
    def recapture_level_menu(self,target,cancel):
        self.recaptures += 1
        return Image.new("RGB",(8,8))
    def close_level_menu(self,target): self.closes += 1


class LevelF4Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = RecognitionAssetCatalog()
        cls.reader = StudentLevelRecognizer(cls.catalog)
    @classmethod
    def tearDownClass(cls): cls.reader.close()

    def frame(self, text, size=(2560,1440)):
        frame = Image.new("RGB",size,"white")
        for position,digit in enumerate(text,1):
            region = self.reader.regions[f"level_digit_{position}"]
            box = tuple(round(value*scale) for value,scale in zip(
                (region["x1"],region["y1"],region["x2"],region["y2"]),(size[0],size[1],size[0],size[1])))
            if digit == "?":
                tile = Image.new("RGB",(box[2]-box[0],box[3]-box[1]),(120,120,120))
            else:
                with Image.open(self.catalog.resolve(f"templates/student_level/{position}_{digit}.png")) as source:
                    tile = source.resize((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS)
            frame.paste(tile,box[:2]);tile.close()
        self.addCleanup(frame.close)
        return frame

    def test_v6_parity_regions_and_all_single_double_levels(self):
        parity = json.loads((FIXTURES/"student_level_f4_v6_parity.json").read_text())
        self.assertEqual(parity["regions"],self.reader.regions)
        for value in range(1,91):
            with self.subTest(value=value), self.frame(str(value)) as frame:
                result = self.reader.recognize_menu(frame)["level"]
                self.assertEqual(value,result.value)
                self.assertTrue(result.confirmed)

    def test_blank_or_dark_screen_is_not_level(self):
        for color in ("black","white",(120,120,120)):
            with Image.new("RGB",(1280,720),color) as frame:
                self.assertIsNone(self.reader.recognize_menu(frame)["level"].value)

    def test_unknown_second_digit_does_not_shorten_number(self):
        self.assertIsNone(self.reader.recognize_menu(self.frame("9?"))["level"].value)

    def test_failed_first_digit_does_not_promote_second(self):
        self.assertIsNone(self.reader.recognize_menu(self.frame("?8"))["level"].value)

    def test_out_of_range_is_not_confirmed(self):
        self.assertIsNone(self.reader.recognize_menu(self.frame("99"))["level"].value)

    def test_basic_success_does_not_click_or_load_detail_bank(self):
        menu = Menu()
        with patch.object(self.reader,"recognize_menu",side_effect=AssertionError("unnecessary read")):
            result = self.reader.resolve({"level":obs(90)},menu,{},Event())
        self.assertEqual(90,result["level"].value)
        self.assertEqual((0,0,0),(menu.opens,menu.recaptures,menu.closes))

    def test_missing_menu_keeps_previous_uncertain_value(self):
        previous = obs(None)
        self.assertIs(previous,self.reader.resolve({"level":previous},None,{},Event())["level"])

    def test_failure_then_third_read_success_closes_once(self):
        menu = Menu()
        with patch.object(self.reader,"recognize_menu",side_effect=[{"level":obs(None)},{"level":obs(None)},{"level":obs(12,"level_tab_template")}]) as read:
            result = self.reader.resolve({"level":obs(None)},menu,{},Event())
        self.assertEqual(12,result["level"].value)
        self.assertEqual((1,2,1,3),(menu.opens,menu.recaptures,menu.closes,read.call_count))

    def test_exhaustion_retains_other_fields_and_partial_evidence(self):
        menu = Menu()
        original = {"level":obs(None),"skill1":obs(10),"weapon_level":obs(60)}
        with patch.object(self.reader,"recognize_menu",return_value={"level":obs(None)}) as read:
            result = self.reader.resolve(original,menu,{},Event())
        self.assertIsNone(result["level"].value)
        self.assertEqual("partial",result["level_panel"].status)
        self.assertEqual(10,original["skill1"].value)
        self.assertEqual(60,original["weapon_level"].value)
        self.assertEqual((1,2,1,3),(menu.opens,menu.recaptures,menu.closes,read.call_count))

    def test_safe_open_failure_closes_and_stays_partial(self):
        menu = Menu(ScannerError("panel_open_failed","no change"))
        result = self.reader.resolve({"level":obs(None)},menu,{},Event())
        self.assertEqual("partial",result["level_panel"].status)
        self.assertEqual(1,menu.closes)

    def test_restore_failure_propagates_even_after_successful_read(self):
        menu = Menu()
        menu.close_level_menu = lambda _: (_ for _ in ()).throw(ScannerError("panel_restore_failed","unsafe"))
        with patch.object(self.reader,"recognize_menu",return_value={"level":obs(90)}):
            with self.assertRaises(ScannerError) as caught:
                self.reader.resolve({"level":obs(None)},menu,{},Event())
        self.assertEqual("panel_restore_failed",caught.exception.code)

    def test_cancel_after_open_prevents_read_and_closes(self):
        cancel = Event();menu = Menu(cancel=cancel)
        with patch.object(self.reader,"recognize_menu") as read:
            with self.assertRaises(ScannerError) as caught:
                self.reader.resolve({"level":obs(None)},menu,{},cancel)
            self.assertEqual("cancelled",caught.exception.code)
            read.assert_not_called()
        self.assertEqual(1,menu.closes)

    def test_existing_conflict_stays_sticky_without_click(self):
        previous = obs(90,"panel_value_conflict","uncertain")
        menu = Menu()
        self.assertIs(previous,self.reader.resolve({"level":previous},menu,{},Event())["level"])
        self.assertEqual(0,menu.opens)

    def test_level_tab_uses_basic_tab_for_return_not_panel_close(self):
        ui = ScriptedUI(["basic","level","level","basic"])
        recovery = StudentPanelRecovery(ui,None,recognizer=FakeRecognizer())
        self.addCleanup(recovery.close)
        adapter = LevelMenuCaptureAdapter(ui,self.catalog,recovery=recovery)
        with patch("core.student_panel_recovery.Event",FastEvent):
            adapter.capture_level_menu({},FastEvent()).close();adapter.close_level_menu({})
        self.assertEqual("basic",recovery.state)
        self.assertEqual(2,len(ui.actions))
        self.assertEqual(("click",*recovery._center(recovery.regions["basic_info_button"])),ui.actions[-1])

    def test_return_to_other_student_is_not_success(self):
        ui = ScriptedUI(["basic","level","other-student"])
        recovery = StudentPanelRecovery(ui,None,recognizer=FakeRecognizer())
        self.addCleanup(recovery.close)
        adapter = LevelMenuCaptureAdapter(ui,self.catalog,recovery=recovery)
        with patch("core.student_panel_recovery.Event",FastEvent):
            adapter.capture_level_menu({},FastEvent()).close()
            with self.assertRaises(ScannerError) as caught: adapter.close_level_menu({})
        self.assertEqual("panel_restore_failed",caught.exception.code)

    def test_matcher_resolves_level_before_dependent_potential_and_equipment(self):
        menu = Menu();matcher = StudentMatcherAdapter(StableBasicCapture(),self.catalog,level_menu=menu)
        self.addCleanup(matcher.level_recognizer.close);self.addCleanup(matcher.potential_recognizer.close)
        basic = {"level":obs(None),"student_star":obs(5),"skill1":obs(10),"weapon_level":obs(None),"weapon_star":obs(None)}
        def potential(images,observations,*args):
            self.assertEqual(90,observations["level"].value)
            return {}
        with patch.object(matcher.matcher,"match",return_value=Match("mika",1,1)), \
             patch.object(matcher.basic_recognizer,"recognize",return_value=basic), \
             patch.object(matcher.level_recognizer,"recognize_menu",return_value={"level":obs(90,"level_tab_template")}), \
             patch.object(matcher.potential_recognizer,"resolve",side_effect=potential), \
             patch.object(matcher.weapon_recognizer,"read_state",return_value=obs("weapon_unlocked_not_equipped")), \
             patch.object(matcher.equipment_recognizer,"recognize",return_value=({},())) as equipment:
            result = matcher._scan_current({},Event(),lambda *args:None)[0]
        self.addCleanup(matcher._close_answer_specimens,[result])
        self.assertEqual(90,equipment.call_args.kwargs["student_level"])
        self.assertEqual(10,result["payload"]["values"]["skill1"])
        self.assertEqual("level_tab_template",result["payload"]["provenance"]["level"])
        self.assertEqual((1,0,1),(menu.opens,menu.recaptures,menu.closes))

    def test_native1280_low_max_level_state_and_return(self):
        recognizer = StudentPanelRecognizer(self.catalog)
        self.addCleanup(recognizer.close)
        for row in json.loads((LIVE/"manifest.json").read_text())["assets"]:
            path = LIVE/row["file"]
            self.assertEqual(row["sha256"],hashlib.sha256(path.read_bytes()).hexdigest())
            with self.subTest(file=row["file"]), Image.open(path) as frame:
                self.assertEqual((1280,720),frame.size)
                self.assertEqual(row["state"],recognizer.classify(frame))
                if row["state"] == "level":
                    self.assertEqual(row["level"],self.reader.recognize_menu(frame)["level"].value)

    def test_native1280_potential_recheck_without_synthetic_resize(self):
        recognizer = StudentPotentialRecognizer(self.catalog)
        self.addCleanup(recognizer.close)
        for filename,expected in (("f3-mika-stat.png",[25,25,25]),("f3-hina-stat.png",[25,25,0])):
            with self.subTest(file=filename), Image.open(LIVE/filename) as frame:
                result = recognizer.recognize_menu(frame)
                self.assertEqual(expected,[result[f].value for f in POTENTIAL_FIELDS])
                self.assertTrue(all(result[f].confirmed for f in POTENTIAL_FIELDS))


if __name__ == "__main__": unittest.main()
