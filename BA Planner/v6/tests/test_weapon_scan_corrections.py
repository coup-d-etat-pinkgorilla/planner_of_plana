import json
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import numpy as np
from PIL import Image, ImageDraw

from core.matcher import (
    RecogSource,
    RecognitionResult,
    WeaponState,
    _read_adaptive_equip_digit,
    _read_weapon_level_glyph_result,
    read_basic_weapon_star_result,
    read_weapon_star_v5_result,
)
from core.merge import merge_student_entry
from core.scanner import FieldMeta, FieldSource, Scanner, StudentEntry


class WeaponRegionConfigurationTests(unittest.TestCase):
    def test_menu_and_basic_weapon_regions_are_kept_separate(self) -> None:
        menu_regions = json.loads(
            Path("regions/student_weaponmenu_regions.json").read_text(encoding="utf-8")
        )
        basic_regions = json.loads(
            Path("regions/student_normal_info_regions.json").read_text(encoding="utf-8")
        )
        digit1 = menu_regions["weapon_level_digit1"]
        digit2 = menu_regions["weapon_level_digit2"]
        star = menu_regions["weapon_star_region"]
        basic_quad = basic_regions["basic_weapon_level_digits_quad"]["points_ratio"]
        basic_star = basic_regions["basic_weapon_star_region"]

        self.assertLess(digit1["x2"], 0.30)
        self.assertLess(digit2["x2"], 0.30)
        self.assertLess(star["x2"], 0.60)
        self.assertNotIn("weapon_level_digits_quad", menu_regions)
        self.assertGreater(min(point["x"] for point in basic_quad), 0.60)
        self.assertGreater(basic_star["x1"], 0.70)
        self.assertLessEqual(basic_star["x1"], 0.772)
        self.assertLess(basic_star["y2"] - basic_star["y1"], 0.04)


class WeaponBasicFastPathTests(unittest.TestCase):
    def _scanner(self) -> Scanner:
        scanner = Scanner.__new__(Scanner)
        scanner.r = {
            "student": {
                "basic_weapon_level_digits_quad": {"points_ratio": [{}] * 4},
                "basic_weapon_star_region": {"x1": 0, "y1": 0, "x2": 1, "y2": 1},
                "weapon_star_region": {"x1": 0, "y1": 0, "x2": 1, "y2": 1},
                "weapon_level_digit1": {"x1": 0, "y1": 0, "x2": 0.5, "y2": 1},
                "weapon_level_digit2": {"x1": 0.5, "y1": 0, "x2": 1, "y2": 1},
            }
        }
        scanner._status = lambda *_args, **_kwargs: None
        scanner._on_progress = None
        scanner._get_student_basic_capture = lambda: Image.new("RGB", (32, 32))
        scanner._click_student_region_and_wait = Mock(return_value=Image.new("RGB", (32, 32)))
        scanner._close_student_panel = Mock()
        return scanner

    def test_confident_basic_card_skips_weapon_menu(self) -> None:
        scanner = self._scanner()
        entry = StudentEntry(student_id="test", weapon_state=WeaponState.WEAPON_EQUIPPED)
        entry.set_meta("weapon_state", FieldMeta.ok(FieldSource.TEMPLATE, score=1.0))
        level_result = RecognitionResult(60, 0.90, RecogSource.COMBINED, False)
        star_result = RecognitionResult(4, 0.91, RecogSource.COMBINED, False)

        with (
            patch("core.scanner.read_basic_weapon_level_result", return_value=level_result),
            patch("core.scanner.read_basic_weapon_star_result", return_value=star_result),
        ):
            scanner.read_weapon(entry)

        self.assertEqual(entry.weapon_level, 60)
        self.assertEqual(entry.weapon_star, 4)
        self.assertEqual(entry.get_meta("weapon_level").note, "basic_info")
        scanner._click_student_region_and_wait.assert_not_called()

    def test_uncertain_basic_card_opens_weapon_menu_fallback(self) -> None:
        scanner = self._scanner()
        entry = StudentEntry(student_id="test", weapon_state=WeaponState.WEAPON_EQUIPPED)
        entry.set_meta("weapon_state", FieldMeta.ok(FieldSource.TEMPLATE, score=1.0))
        uncertain_level = RecognitionResult(60, 0.60, RecogSource.COMBINED, True)
        menu_star = RecognitionResult(4, 0.91, RecogSource.COMBINED, False)

        with (
            patch("core.scanner.read_basic_weapon_level_result", return_value=uncertain_level),
            patch("core.scanner.read_basic_weapon_star_result", return_value=menu_star),
            patch("core.matcher.read_weapon_star_v5_result", return_value=menu_star),
            patch("core.scanner.read_weapon_level", return_value=60),
        ):
            scanner.read_weapon(entry)

        self.assertEqual(entry.weapon_level, 60)
        self.assertEqual(entry.weapon_star, 4)
        scanner._click_student_region_and_wait.assert_called_once()
        scanner._close_student_panel.assert_called_once()


class WeaponStarRecognitionTests(unittest.TestCase):
    def _basic_star_canvas(self, count: int) -> Image.Image:
        canvas = Image.new("RGB", (120, 40), "white")
        with Image.open("templates/weapon_star/star_1.png") as template:
            star = template.convert("RGB").crop((210, 3, 258, 51)).resize((24, 24))
        centers = (27, 47, 66, 86, 105)
        for center in centers[-count:]:
            canvas.paste(star, (center - 12, 8))
        return canvas

    def test_basic_weapon_star_reader_accepts_future_five_stars(self) -> None:
        canvas = self._basic_star_canvas(5)

        result = read_basic_weapon_star_result(canvas)

        self.assertEqual(result.value, 5)
        self.assertFalse(result.uncertain)

    def test_cyan_weapon_noise_does_not_turn_two_stars_into_four(self) -> None:
        canvas = self._basic_star_canvas(2)
        ImageDraw.Draw(canvas).rectangle((20, 16, 50, 21), fill=(40, 205, 245))

        result = read_basic_weapon_star_result(canvas)

        self.assertEqual(2, result.value)
        self.assertFalse(result.uncertain)

    def test_each_weapon_star_template_counts_correctly(self) -> None:
        template_dir = Path("templates/weapon_star")
        for expected in range(1, 5):
            with self.subTest(expected=expected):
                crop = Image.open(template_dir / f"star_{expected}.png")
                result = read_weapon_star_v5_result(crop)
                self.assertEqual(expected, result.value)
                self.assertFalse(result.uncertain)


class WeaponLevelRecognitionTests(unittest.TestCase):
    def _level_crop(self, digits: str) -> Image.Image:
        canvas = Image.new("L", (64, 48), 0)
        template_dir = Path("templates/weaponlevel_glyph")
        for index, digit in enumerate(digits):
            glyph = Image.open(template_dir / f"{digit}.png").convert("L")
            canvas.paste(glyph, (4 + index * 28, 8))
        return canvas.convert("RGB")

    def test_each_weapon_level_digit_glyph_is_recognized(self) -> None:
        for expected in range(10):
            with self.subTest(expected=expected):
                result = _read_weapon_level_glyph_result(self._level_crop(str(expected)))
                self.assertEqual(expected if expected > 0 else None, result.value)

    def test_two_digit_weapon_level_is_recognized(self) -> None:
        result = _read_weapon_level_glyph_result(self._level_crop("60"))

        self.assertEqual(60, result.value)
        self.assertFalse(result.uncertain)


class EquipmentLevelCalibrationTests(unittest.TestCase):
    def test_confident_static_digit_trains_and_rescues_later_match(self) -> None:
        crop = Image.new("RGB", (32, 40), "white")
        for x in range(10, 20):
            for y in range(5, 35):
                crop.putpixel((x, y), (20, 20, 20))
        templates: dict[str, list] = {}

        with patch(
            "core.matcher._rank_digit_candidates",
            return_value=("7", 0.91, 0.20),
        ):
            learned = _read_adaptive_equip_digit(
                Path("unused"), 1, crop, templates,
            )

        self.assertEqual("7", learned)
        self.assertIn("7", templates)
        self.assertEqual(1, len(templates["7"]))

        with patch(
            "core.matcher._rank_digit_candidates",
            return_value=(None, 0.20, 0.01),
        ):
            premature = _read_adaptive_equip_digit(
                Path("unused"), 1, crop, templates,
            )

        self.assertIsNone(premature)

        templates["1"] = [np.zeros_like(templates["7"][0])]
        with patch(
            "core.matcher._rank_digit_candidates",
            return_value=(None, 0.20, 0.01),
        ):
            rescued = _read_adaptive_equip_digit(
                Path("unused"), 1, crop, templates,
            )

        self.assertEqual("7", rescued)


class WeaponMergeCorrectionTests(unittest.TestCase):
    def test_verified_weapon_level_can_correct_higher_saved_value(self) -> None:
        old = {"weapon_star": 2, "weapon_level": 40}
        new = {"weapon_star": 1, "weapon_level": 20}
        merged = merge_student_entry(
            old,
            new,
            authoritative_fields={"weapon_star", "weapon_level"},
        )
        self.assertEqual(1, merged["weapon_star"])
        self.assertEqual(20, merged["weapon_level"])

    def test_unverified_lower_weapon_level_keeps_saved_value(self) -> None:
        old = {"weapon_star": 2, "weapon_level": 40}
        new = {"weapon_star": 1, "weapon_level": 20}
        merged = merge_student_entry(old, new)
        self.assertEqual(2, merged["weapon_star"])
        self.assertEqual(40, merged["weapon_level"])


class WeaponRequiredFieldTests(unittest.TestCase):
    def test_equipped_weapon_requires_star_and_level(self) -> None:
        entry = StudentEntry(weapon_state=WeaponState.WEAPON_EQUIPPED)

        missing = entry.missing_fields()

        self.assertIn("weapon_star", missing)
        self.assertIn("weapon_level", missing)

    def test_no_weapon_system_does_not_require_weapon_details(self) -> None:
        entry = StudentEntry(weapon_state=WeaponState.NO_WEAPON_SYSTEM)

        missing = entry.missing_fields()

        self.assertNotIn("weapon_star", missing)
        self.assertNotIn("weapon_level", missing)


if __name__ == "__main__":
    unittest.main()
