from __future__ import annotations

import hashlib
import json
from pathlib import Path
from threading import Event
import unittest
from unittest.mock import patch

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import Match, StudentMatcherAdapter, WeaponMenuCaptureAdapter
from core.student_scan_recognizer import Observation
from core.student_weapon_recognizer import StudentWeaponRecognizer


BACKEND = Path(__file__).parents[1]
ASSETS = BACKEND / "assets" / "recognition" / "v1"
FIXTURES = Path(__file__).parent / "fixtures"
PARITY = FIXTURES / "student_weapon_s2w_v6_parity.json"
BASIC_FRAME = FIXTURES / "student_scan_s2_serika_new_year.png"


def _observation(
    value: int | str | None,
    *,
    status: str = "ok",
) -> Observation:
    return Observation(value, 1.0 if value is not None else 0.0, status, "fixture", "")


class StableBasicCapture:
    def wait_stable(self, _target, cancel, timeout=2.0):
        if cancel.is_set():
            raise AssertionError("unexpected cancellation")
        return Image.open(BASIC_FRAME).convert("RGB")

    def capture(self, _target):
        raise AssertionError("unexpected capture")

    def scroll(self, _target, _delta):
        raise AssertionError("unexpected scroll")


class ScriptedWeaponMenu:
    def __init__(self, frames: list[Image.Image]) -> None:
        self.frames = frames
        self.captures = 0
        self.recaptures = 0
        self.closes = 0

    def capture_weapon_menu(self, _target, _cancel):
        self.captures += 1
        return self.frames[0].copy()

    def recapture_weapon_menu(self, _target, _cancel):
        self.recaptures += 1
        return self.frames[self.recaptures].copy()

    def close_weapon_menu(self, _target):
        self.closes += 1


class ClickCapture:
    def __init__(self) -> None:
        self.clicks: list[tuple[float, float]] = []
        self.waits = 0

    def click(self, _target, x_ratio, y_ratio):
        self.clicks.append((x_ratio, y_ratio))

    def wait_stable(self, _target, _cancel, timeout=2.0):
        self.waits += 1
        return Image.new("RGB", (2560, 1440), "black")


class StudentWeaponS2WTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = RecognitionAssetCatalog(ASSETS)
        cls.recognizer = StudentWeaponRecognizer(cls.catalog)
        cls.parity = json.loads(PARITY.read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls) -> None:
        cls.recognizer.close()

    def _menu_frame(self, level: int = 60, star: int = 4) -> Image.Image:
        frame = Image.new("RGB", (2560, 1440), "black")
        regions = self.recognizer.regions
        for position, digit in enumerate(str(level), 1):
            template = self.recognizer.level_templates[f"{position}:{digit}"]
            region = regions[f"weapon_level_digit{position}"]
            box = (
                round(frame.width * region["x1"]), round(frame.height * region["y1"]),
                round(frame.width * region["x2"]), round(frame.height * region["y2"]),
            )
            frame.paste(template.resize((box[2] - box[0], box[3] - box[1])), box[:2])
        template = self.recognizer.star_templates[str(star)]
        region = regions["weapon_star_region"]
        box = (
            round(frame.width * region["x1"]), round(frame.height * region["y1"]),
            round(frame.width * region["x2"]), round(frame.height * region["y2"]),
        )
        frame.paste(template.resize((box[2] - box[0], box[3] - box[1])), box[:2])
        return frame

    def test_feedback_crops_cover_all_three_weapon_states(self) -> None:
        self.assertEqual(
            {"weapon_equipped", "weapon_unlocked_not_equipped", "no_weapon_system"},
            {record["expected"] for record in self.parity["state_visual_truth"]},
        )
        for record in self.parity["state_visual_truth"]:
            with self.subTest(expected=record["expected"]):
                path = FIXTURES / record["fixture_crop"]
                self.assertEqual(
                    record["fixture_crop_sha256"], hashlib.sha256(path.read_bytes()).hexdigest()
                )
                with Image.open(path) as crop:
                    sizes = (crop.size, (max(1, crop.width // 2), max(1, crop.height // 2)))
                    for size in sizes:
                        with self.subTest(size=size):
                            resized = crop.resize(size, Image.Resampling.LANCZOS)
                            try:
                                result = self.recognizer.read_state(resized, student_star=None)
                            finally:
                                resized.close()
                            self.assertEqual(record["expected"], result.value)
                            self.assertEqual("ok", result.status)

    def test_student_below_five_stars_is_independently_no_system(self) -> None:
        result = self.recognizer.read_state(None, student_star=4)
        self.assertEqual("no_weapon_system", result.value)
        self.assertEqual("inferred", result.status)

    def test_blank_state_roi_is_not_guessed_as_no_system(self) -> None:
        crop = Image.new("RGB", (57, 55), "black")
        try:
            result = self.recognizer.read_state(crop, student_star=5)
        finally:
            crop.close()
        self.assertIsNone(result.value)
        self.assertEqual("uncertain", result.status)

    def test_weapon_menu_reads_independent_level_and_star_rois(self) -> None:
        frame = self._menu_frame(level=60, star=4)
        try:
            result = self.recognizer.recognize_menu(frame)
        finally:
            frame.close()
        self.assertEqual(60, result["weapon_level"].value)
        self.assertEqual(4, result["weapon_star"].value)
        self.assertTrue(result["weapon_level"].confirmed)
        self.assertTrue(result["weapon_star"].confirmed)

    def test_basic_failure_opens_panel_retries_twice_and_closes(self) -> None:
        bad = Image.new("RGB", (2560, 1440), "black")
        good = self._menu_frame()
        menu = ScriptedWeaponMenu([bad, bad, good])
        adapter = StudentMatcherAdapter(
            StableBasicCapture(), self.catalog, weapon_menu=menu,
        )
        basic = {
            "level": _observation(90),
            "student_star": _observation(5),
            "weapon_level": _observation(None, status="uncertain"),
            "weapon_star": _observation(None, status="uncertain"),
        }
        try:
            with (
                patch.object(adapter.matcher, "match", return_value=Match("serika_new_year", 1.0, 1.0)),
                patch.object(adapter.basic_recognizer, "recognize", return_value=basic),
                patch.object(
                    adapter.weapon_recognizer,
                    "read_state",
                    return_value=_observation("weapon_equipped"),
                ),
                patch.object(adapter.equipment_recognizer, "recognize", return_value=({}, ())),
            ):
                result = adapter(
                    {"target_id": "fixture", "student_scan_mode": "single"},
                    Event(), lambda *_args: None,
                )[0]
        finally:
            bad.close()
            good.close()
        self.assertEqual(1, menu.captures)
        self.assertEqual(2, menu.recaptures)
        self.assertEqual(1, menu.closes)
        self.assertEqual(60, result["payload"]["values"]["weapon_level"])
        self.assertEqual(4, result["payload"]["values"]["weapon_star"])

    def test_non_equipped_states_skip_details_without_opening_panel(self) -> None:
        for state in ("weapon_unlocked_not_equipped", "no_weapon_system"):
            with self.subTest(state=state):
                frame = self._menu_frame()
                menu = ScriptedWeaponMenu([frame])
                adapter = StudentMatcherAdapter(
                    StableBasicCapture(), self.catalog, weapon_menu=menu,
                )
                basic = {
                    "level": _observation(90),
                    "student_star": _observation(5),
                    "weapon_level": _observation(60),
                    "weapon_star": _observation(4),
                }
                try:
                    with (
                        patch.object(adapter.matcher, "match", return_value=Match("serika_new_year", 1.0, 1.0)),
                        patch.object(adapter.basic_recognizer, "recognize", return_value=basic),
                        patch.object(
                            adapter.weapon_recognizer,
                            "read_state",
                            return_value=_observation(state),
                        ),
                        patch.object(adapter.equipment_recognizer, "recognize", return_value=({}, ())),
                    ):
                        result = adapter(
                            {"target_id": "fixture", "student_scan_mode": "single"},
                            Event(), lambda *_args: None,
                        )[0]
                finally:
                    frame.close()
                self.assertEqual(0, menu.captures)
                self.assertEqual(state, result["payload"]["values"]["weapon_state"])
                self.assertNotIn("weapon_level", result["payload"]["values"])
                self.assertNotIn("weapon_star", result["payload"]["values"])

    def test_unknown_state_does_not_open_weapon_panel(self):
        menu = ScriptedWeaponMenu([])
        adapter = StudentMatcherAdapter(StableBasicCapture(), self.catalog, weapon_menu=menu)
        basic = {"level":_observation(90), "student_star":_observation(5),
                 "weapon_level":_observation(None,status="uncertain"), "weapon_star":_observation(None,status="uncertain")}
        with (patch.object(adapter.matcher,"match",return_value=Match("serika_new_year",1,1)),
              patch.object(adapter.basic_recognizer,"recognize",return_value=basic),
              patch.object(adapter.weapon_recognizer,"read_state",return_value=_observation(None,status="uncertain")),
              patch.object(adapter.equipment_recognizer,"recognize",return_value=({},()))):
            adapter({"target_id":"fixture"},Event(),lambda *_a:None)
        self.assertEqual(0,menu.captures)

    def test_basic_weapon_value_survives_conflicting_detail_in_review_payload(self):
        frame = self._menu_frame(level=50,star=4)
        self.addCleanup(frame.close)
        menu = ScriptedWeaponMenu([frame])
        adapter = StudentMatcherAdapter(StableBasicCapture(),self.catalog,weapon_menu=menu)
        basic={"level":_observation(90),"student_star":_observation(5),
               "weapon_level":_observation(60),"weapon_star":_observation(None,status="uncertain")}
        with (patch.object(adapter.matcher,"match",return_value=Match("serika_new_year",1,1)),
              patch.object(adapter.basic_recognizer,"recognize",return_value=basic),
              patch.object(adapter.weapon_recognizer,"read_state",return_value=_observation("weapon_equipped")),
              patch.object(adapter.weapon_recognizer,"recognize_menu",return_value={"weapon_level":_observation(50),"weapon_star":_observation(4)}),
              patch.object(adapter.equipment_recognizer,"recognize",return_value=({},()))):
            result=adapter({"target_id":"fixture"},Event(),lambda *_a:None)[0]
        self.assertEqual(60,result["payload"]["values"]["weapon_level"])
        self.assertEqual(4,result["payload"]["values"]["weapon_star"])
        self.assertTrue(result["review_required"])
        self.assertTrue(any(row["source"]=="panel_value_conflict" and row["status"]=="uncertain" for row in result["evidence"]))
        self.assertEqual(1,menu.closes)

    def test_weapon_menu_adapter_rejects_unverified_basic_screen(self) -> None:
        capture = ClickCapture()
        adapter = WeaponMenuCaptureAdapter(capture, self.catalog)
        self.addCleanup(adapter.recovery.close)
        with self.assertRaisesRegex(Exception, "verified basic"):
            adapter.capture_weapon_menu({"target_id": "fixture"}, Event())
        self.assertEqual(1, capture.waits)
        self.assertEqual([], capture.clicks)


if __name__ == "__main__":
    unittest.main()
