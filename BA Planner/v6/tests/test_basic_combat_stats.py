import json
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import numpy as np
from PIL import Image

import core.matcher as matcher
from core.matcher import (
    _basic_combat_cell_state,
    _basic_combat_stat_digit_templates,
    _basic_combat_stat_position_templates,
    read_basic_additional_stat_value_result,
    read_basic_combat_stat_result,
)
from core.scanner import Scanner, StudentEntry


class BasicCombatStatMatcherTests(unittest.TestCase):
    def test_digit_regions_use_recursive_fixed_cells(self) -> None:
        regions = json.loads(Path("regions/student_normal_info_regions.json").read_text(encoding="utf-8"))
        self.assertEqual(regions["basic_combat_hp_digits"]["max_digits"], 7)
        self.assertEqual(len(regions["basic_combat_hp_digits"]["cells"]), 7)
        for key in ("hp", "atk", "def", "heal"):
            region = regions[f"basic_combat_{key}_digits"]
            self.assertAlmostEqual(region["cell_width"], 20 / 2560)
            self.assertAlmostEqual(region["cell_height"], 33 / 1440)
            self.assertGreaterEqual(region["max_digits"], region["min_digits"])
            cells = region["cells"]
            self.assertEqual(len(cells), region["max_digits"])
            for cell in cells:
                self.assertAlmostEqual(cell["x2"] - cell["x1"], 16 / 2560)
                self.assertAlmostEqual(cell["y2"] - cell["y1"], 26 / 1440)
            for left, right in zip(cells, cells[1:]):
                self.assertAlmostEqual(right["x1"] - left["x2"], 4 / 2560)

    def test_every_position_has_all_digit_candidates_and_terminal_states(self) -> None:
        regions = json.loads(Path("regions/student_normal_info_regions.json").read_text(encoding="utf-8"))
        shared = _basic_combat_stat_digit_templates()
        positioned = _basic_combat_stat_position_templates()
        self.assertEqual(set(shared), set("0123456789"))
        for field in ("hp", "atk", "def", "heal"):
            maximum = regions[f"basic_combat_{field}_digits"]["max_digits"]
            for position in range(maximum):
                effective = set(shared) | set(positioned.get((field, position), {}))
                self.assertEqual(effective, set("0123456789"))

        empty = Image.new("RGB", (20, 33), "white")
        self.assertEqual(_basic_combat_cell_state(empty)[0], "EMPTY")
        lv = Image.new("RGB", (20, 33), (55, 90, 145))
        self.assertEqual(_basic_combat_cell_state(lv)[0], "LV")

    def test_one_template_fits_fixed_cell(self) -> None:
        template_path = next(Path("templates/basic_combat_stat_digits/1").glob("*.png"))
        template = np.asarray(Image.open(template_path).convert("L"))
        canvas = Image.new("RGB", (40, 33), "white")
        glyph = Image.fromarray(255 - template).convert("RGB")
        canvas.paste(glyph, (0, 2))
        region = {
            "x1": 0.0, "y1": 0.0,
            "cell_width": 0.5, "cell_height": 1.0,
            "min_digits": 1, "max_digits": 2,
        }
        result = read_basic_combat_stat_result(canvas, region)
        self.assertEqual(result.value, 1)
        self.assertFalse(result.uncertain)

    def test_basic_additional_stat_templates_self_match(self) -> None:
        template_dir = Path("templates/basic_additional_stat_values")
        paths = sorted(template_dir.glob("*.png"), key=lambda path: int(path.stem))
        self.assertEqual([int(path.stem) for path in paths], list(range(1, 26)))
        full_region = {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0}
        for path in paths:
            with self.subTest(value=path.stem):
                result = read_basic_additional_stat_value_result(Image.open(path).convert("RGB"), full_region)
                self.assertEqual(result.value, int(path.stem))
                self.assertFalse(result.uncertain, result.label)

    def test_basic_additional_stat_accepts_high_margin_heal_shape(self) -> None:
        glyph = np.ones((32, 64), dtype=np.uint8) * 255
        templates = {"25": [glyph], "24": [glyph], "4": [glyph]}
        scores = iter([0.74, 0.31, 0.20])
        with patch.object(matcher, "_normalize_basic_additional_stat_value_text", return_value=(glyph, 0.145)), \
             patch.object(matcher, "_basic_additional_stat_value_templates", return_value=templates), \
             patch.object(matcher, "binary_glyph_similarity", side_effect=lambda _glyph, _sample: next(scores)):
            result = read_basic_additional_stat_value_result(
                Image.new("RGB", (10, 10)), {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0}
            )
        self.assertEqual(result.value, 25)
        self.assertFalse(result.uncertain, result.label)

    def test_basic_additional_stat_rejects_low_margin_shape(self) -> None:
        glyph = np.ones((32, 64), dtype=np.uint8) * 255
        templates = {"25": [glyph], "4": [glyph]}
        scores = iter([0.74, 0.738])
        with patch.object(matcher, "_normalize_basic_additional_stat_value_text", return_value=(glyph, 0.145)), \
             patch.object(matcher, "_basic_additional_stat_value_templates", return_value=templates), \
             patch.object(matcher, "binary_glyph_similarity", side_effect=lambda _glyph, _sample: next(scores)):
            result = read_basic_additional_stat_value_result(
                Image.new("RGB", (10, 10)), {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0}
            )
        self.assertIsNone(result.value)
        self.assertTrue(result.uncertain, result.label)


class BasicAdditionalStatSkipTests(unittest.TestCase):
    def _scanner(self) -> Scanner:
        scanner = Scanner.__new__(Scanner)
        scanner._status = Mock()
        scanner._on_progress = Mock()
        scanner._saved_student = Mock(return_value=None)
        scanner._stats_maxed_from_saved_data = Mock(return_value=False)
        scanner._click_student_region_and_wait = Mock(return_value=None)
        scanner._esc = Mock()
        return scanner

    def _entry(self) -> StudentEntry:
        return StudentEntry(
            student_id="test", level=90, student_star=5,
            combat_hp=10000, combat_atk=1000, combat_def=100, combat_heal=2000,
        )

    def test_all_absent_badges_skip_menu_and_set_zero(self) -> None:
        scanner = self._scanner()
        entry = self._entry()
        entry._basic_additional_badges = {"hp": False, "atk": False, "heal": False}
        scanner.read_stats(entry)
        self.assertEqual((entry.stat_hp, entry.stat_atk, entry.stat_heal), (0, 0, 0))
        scanner._click_student_region_and_wait.assert_not_called()

    def test_present_badge_with_basic_value_skips_menu(self) -> None:
        scanner = self._scanner()
        entry = self._entry()
        entry._basic_additional_badges = {"hp": False, "atk": True, "heal": False}
        entry._basic_additional_values = {"hp": 0, "atk": 12, "heal": 0}
        scanner.read_stats(entry)
        self.assertEqual((entry.stat_hp, entry.stat_atk, entry.stat_heal), (0, 12, 0))
        scanner._click_student_region_and_wait.assert_not_called()

    def test_three_confirmed_basic_values_skip_even_without_combat_values(self) -> None:
        scanner = self._scanner()
        entry = StudentEntry(student_id="test", level=90, student_star=5)
        entry._basic_additional_badges = {"hp": True, "atk": True, "heal": True}
        entry._basic_additional_values = {"hp": 25, "atk": 24, "heal": 23}
        scanner.read_stats(entry)
        self.assertEqual((entry.stat_hp, entry.stat_atk, entry.stat_heal), (25, 24, 23))
        scanner._click_student_region_and_wait.assert_not_called()

    def test_partial_basic_values_keep_menu_fallback_without_partial_write(self) -> None:
        scanner = self._scanner()
        entry = self._entry()
        entry._basic_additional_badges = {"hp": True, "atk": True, "heal": False}
        entry._basic_additional_values = {"hp": 25, "atk": None, "heal": 0}
        scanner.read_stats(entry)
        self.assertEqual((entry.stat_hp, entry.stat_atk, entry.stat_heal), (None, None, None))
        scanner._click_student_region_and_wait.assert_called_once()

    def test_present_or_uncertain_badge_without_value_keeps_menu_fallback(self) -> None:
        for badges in (
            {"hp": False, "atk": True, "heal": False},
            {"hp": False, "atk": None, "heal": False},
        ):
            scanner = self._scanner()
            entry = self._entry()
            entry._basic_additional_badges = badges
            scanner.read_stats(entry)
            scanner._click_student_region_and_wait.assert_called_once()

    def test_combat_values_round_trip(self) -> None:
        entry = self._entry()
        restored = StudentEntry.from_dict(entry.to_dict())
        self.assertEqual(
            (restored.combat_hp, restored.combat_atk, restored.combat_def, restored.combat_heal),
            (10000, 1000, 100, 2000),
        )

class FieldConfirmedStatusTests(unittest.TestCase):
    def _scanner(self) -> Scanner:
        scanner = Scanner.__new__(Scanner)
        scanner._status = Mock(return_value=1)
        return scanner

    def test_field_confirmed_uses_static_stat_labels(self) -> None:
        scanner = self._scanner()
        entry = StudentEntry(student_id="test", display_name="Test")

        scanner._field_confirmed(entry, "level", 90, display_value="Lv.90")
        scanner._field_confirmed(entry, "stat_atk", 12)
        scanner._field_confirmed(entry, "stat_heal", 23)

        labels = [call.kwargs["label"] for call in scanner._status.call_args_list]
        self.assertEqual(labels, ["level", "bonus atk", "bonus heal"])


if __name__ == "__main__":
    unittest.main()
