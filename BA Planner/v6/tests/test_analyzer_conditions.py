from __future__ import annotations

import unittest

from core.analyzer import missing_fields


class AnalyzerConditionTests(unittest.TestCase):
    def test_one_star_does_not_require_locked_skill2_or_skill3(self) -> None:
        student = {
            "student_id": "shizuko_swimsuit",
            "level": 1,
            "student_star": 1,
            "weapon_state": "no_weapon_system",
            "ex_skill": 1,
            "skill1": 1,
            "skill2": None,
            "skill3": None,
            "equip1": "empty",
            "equip2": "level_locked",
            "equip3": "level_locked",
            "equip4": "null",
        }

        self.assertEqual(missing_fields(student), [])

    def test_locked_and_empty_fields_are_not_counted_as_missing(self) -> None:
        student = {
            "student_id": "nodoka",
            "level": 1,
            "student_star": 2,
            "weapon_state": "no_weapon_system",
            "ex_skill": 1,
            "skill1": 1,
            "skill2": 1,
            "skill3": None,
            "equip1": "empty",
            "equip1_level": None,
            "equip2": "level_locked",
            "equip2_level": None,
            "equip3": "level_locked",
            "equip3_level": None,
            "equip4": "null",
        }

        self.assertEqual(missing_fields(student), [])

    def test_equipped_slots_require_levels(self) -> None:
        student = {
            "student_id": "kanna",
            "level": 90,
            "student_star": 3,
            "weapon_state": "no_weapon_system",
            "ex_skill": 1,
            "skill1": 1,
            "skill2": 1,
            "skill3": 1,
            "equip1": "T1",
            "equip1_level": None,
            "equip2": "empty",
            "equip2_level": None,
            "equip3": "empty",
            "equip3_level": None,
            "equip4": "null",
        }

        self.assertEqual(missing_fields(student), ["equip1_level"])

    def test_stats_are_required_only_when_unlocked(self) -> None:
        student = {
            "student_id": "hiyori",
            "level": 90,
            "student_star": 5,
            "weapon_state": "no_weapon_system",
            "ex_skill": 1,
            "skill1": 1,
            "skill2": 1,
            "skill3": 1,
            "equip1": "empty",
            "equip2": "empty",
            "equip3": "empty",
            "equip4": "null",
            "stat_hp": None,
            "stat_atk": None,
            "stat_heal": None,
        }

        self.assertEqual(missing_fields(student), ["stat_hp", "stat_atk", "stat_heal"])


if __name__ == "__main__":
    unittest.main()
