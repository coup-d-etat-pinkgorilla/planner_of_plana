from __future__ import annotations

from copy import deepcopy
import unittest

from core.student_candidate_validation import StudentCandidateValidator


def student(student_id: str, rank: int | None) -> dict:
    return {"version": 1, "student_id": student_id, "values": {"bond_rank": rank}}


class Repository:
    def __init__(self) -> None:
        self.students = [student("hoshino", 29), student("hoshino_battle", None)]

    def get_state(self, _profile_id: str) -> dict:
        return {"students": deepcopy(self.students)}


class StudentCandidateValidationS4Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.repository = Repository()
        self.validator = StudentCandidateValidator(self.repository)
        self.payload = {
            "version": 1,
            "student_id": "hoshino_swimsuit",
            "values": {
                "level": 90, "student_star": 5, "bond_rank": 37,
                "skill2": 10,
                "equip1": "T1", "equip1_level": 1,
                "equip2": "T1", "equip2_level": 1,
                "equip3": "T1", "equip3_level": 1,
                "weapon_state": "weapon_unlocked_not_equipped",
                "stat_hp": 0, "stat_atk": 0, "stat_heal": 0,
            },
        }

    def test_hoshino_missing_owned_alternate_requires_rank_input(self) -> None:
        evidence = self.validator(self.payload, "profile-1")
        self.assertEqual("dependency_missing", evidence["status"])
        self.assertIn(
            {"kind": "alternate_relationship", "key": "10098"},
            evidence["details"]["dependencies"],
        )
        self.assertEqual(
            "provide_alternate_relationship_ranks",
            evidence["details"]["suggestion"]["action"],
        )

    def test_missing_ownership_context_still_blocks_alternate_dependency(self) -> None:
        evidence = self.validator(self.payload, None)
        self.assertEqual("dependency_missing", evidence["status"])
        self.assertEqual(
            "provide_alternate_relationship_ranks",
            evidence["details"]["suggestion"]["action"],
        )

    def test_single_scan_override_completes_owned_alternate_context(self) -> None:
        evidence = self.validator(self.payload, "profile-1", {10098: 24})
        self.assertNotEqual("dependency_missing", evidence["status"])
        rows = evidence["details"]["relationship_contributions"]
        self.assertEqual(24, rows[2]["rank"])
        self.assertTrue(rows[2]["owned"])
        self.assertTrue(rows[2]["applied"])

    def test_second_pass_uses_confirmed_29_37_24_relationship_ranks(self) -> None:
        self.repository.students[1] = student("hoshino_battle", 24)
        evidence = self.validator(self.payload, "profile-1")
        self.assertNotEqual("dependency_missing", evidence["status"])
        self.assertEqual([], evidence["details"]["dependencies"])
        self.assertEqual("partial", evidence["status"])
        rows = evidence["details"]["relationship_contributions"]
        self.assertEqual(
            [("hoshino_swimsuit", 37, True), ("hoshino", 29, True), ("hoshino_battle", 24, True)],
            [(row["student_id"], row["rank"], row["applied"]) for row in rows],
        )
        self.assertTrue(all(row["modifier"] for row in rows))

    def test_basic_info_validation_excludes_passive_skill_buffs(self) -> None:
        self.repository.students[1] = student("hoshino_battle", 24)
        missing = deepcopy(self.payload)
        del missing["values"]["skill2"]
        evidence = self.validator(missing, "profile-1")
        self.assertNotIn(
            {"kind": "candidate_field", "key": "skill2"},
            evidence["details"]["dependencies"],
        )

        evidence = self.validator(self.payload, "profile-1")
        self.assertNotIn("passive_skill", evidence["details"]["contributions"])

    def test_attached_mika_basic_info_values_match_game_display(self) -> None:
        self.repository.students = [
            {
                "version": 1,
                "student_id": "mika",
                "values": {
                    "bond_rank": 74,
                    "stat_hp": 25,
                    "stat_atk": 25,
                    "stat_heal": 25,
                },
            },
            {
                "version": 1,
                "student_id": "mika_swimsuit",
                "values": {
                    "bond_rank": 41,
                    "stat_hp": 0,
                    "stat_atk": 25,
                    "stat_heal": 0,
                },
            },
        ]
        common = {
            "level": 90,
            "student_star": 5,
            "skill2": 10,
            "equip1": "T10",
            "equip1_level": 70,
            "equip2": "T10",
            "equip2_level": 70,
            "equip3": "T10",
            "equip3_level": 70,
            "weapon_state": "weapon_equipped",
            "weapon_star": 4,
            "weapon_level": 60,
        }
        cases = (
            ("mika", 74, 95756, 6893, 121, 5948, (25,25,25)),
            ("mika_swimsuit", 41, 61848, 8637, 93, 5820, (0,25,0)),
        )
        for student_id, rank, hp, attack, defense, heal, potential in cases:
            payload = {
                "version": 1,
                "student_id": student_id,
                "values": {
                    **common,
                    "bond_rank": rank,
                    "combat_hp": hp,
                    "combat_atk": attack,
                    "combat_def": defense,
                    "combat_heal": heal,
                },
            }
            with self.subTest(student_id=student_id):
                evidence = self.validator(payload, "profile-1")
                # Stored potential still explains the calculation, but F3 requires
                # fresh field evidence before calling the scan verified.
                self.assertEqual("dependency_missing", evidence["status"])
                self.assertTrue(all(row["source"] == "profile_fallback" for row in evidence["details"]["potential_inputs"].values()))
                payload["values"].update(dict(zip(("stat_hp","stat_atk","stat_heal"), potential)))
                evidence = self.validator(payload, "profile-1")
                self.assertEqual("verified", evidence["status"])
                self.assertEqual(
                    {
                        "MaxHP": hp,
                        "AttackPower": attack,
                        "DefensePower": defense,
                        "HealPower": heal,
                    },
                    evidence["details"]["expected"],
                )

    def test_hoshino_battle_forms_accept_scan_tolerance_and_resolve_form_ref(self) -> None:
        self.repository.students = [
            student("hoshino", 29),
            student("hoshino_swimsuit", 37),
        ]
        common = {
            "level": 90,
            "bond_rank": 24,
            "student_star": 5,
            "skill2": 10,
            "weapon_state": "weapon_equipped",
            "weapon_star": 4,
            "weapon_level": 60,
            "stat_hp": 25,
            "stat_atk": 25,
            "stat_heal": 0,
            "equip1": "T10",
            "equip1_level": 70,
            "equip2": "T10",
            "equip2_level": 70,
            "equip3": "T10",
            "equip3_level": 70,
        }
        # 106747/3383/2771/4538 is the in-game capture. The SchaleDB-style formula was off by
        # -1/+2 here; the in-client formula (GAME_RULES.md section 4) reproduces it exactly, so the
        # tolerance cases below are synthetic offsets from the exact value.
        cases = (
            (
                "form-1-exact-game-capture", "hoshino_battle",
                106747, 3383, 2771, 4538, "verified",
                {"MaxHP": 0, "AttackPower": 0, "DefensePower": 0, "HealPower": 0},
            ),
            (
                "form-1-tolerance", "hoshino_battle",
                106746, 3385, 2771, 4538, "verified",
                {"MaxHP": -1, "AttackPower": 2, "DefensePower": 0, "HealPower": 0},
            ),
            (
                "form-1-outside-tolerance", "hoshino_battle",
                106746, 3386, 2771, 4538, "suspicious",
                {"MaxHP": -1, "AttackPower": 3, "DefensePower": 0, "HealPower": 0},
            ),
            (
                "form-2-exact", "hoshino_battle#2",
                48823, 8633, 1949, 5674, "verified",
                {"MaxHP": 0, "AttackPower": 0, "DefensePower": 0, "HealPower": 0},
            ),
        )
        for case, student_id, hp, attack, defense, heal, status, delta in cases:
            payload = {
                "version": 1,
                "student_id": student_id,
                "values": {
                    **common,
                    "combat_hp": hp,
                    "combat_atk": attack,
                    "combat_def": defense,
                    "combat_heal": heal,
                },
            }
            with self.subTest(case=case):
                evidence = self.validator(payload, "profile-1")
                self.assertEqual(status, evidence["status"])
                self.assertEqual(delta, evidence["details"]["delta"])

    def test_rank_above_star_semantic_cap_is_suspicious_without_mutation(self) -> None:
        payload = deepcopy(self.payload)
        payload["values"]["student_star"] = 1
        original = deepcopy(payload)
        evidence = self.validator(payload, "profile-1")
        self.assertEqual("suspicious", evidence["status"])
        self.assertEqual(original, payload)

    def test_confirmed_empty_equipment_is_calculated_as_no_contribution(self) -> None:
        payload = {
            "version": 1,
            "student_id": "chise_swimsuit",
            "values": {
                "level": 90, "student_star": 3, "bond_rank": 14, "skill2": 1,
                "equip1": "empty", "equip2": "empty", "equip3": "empty",
                "combat_hp": 23564, "combat_atk": 2632,
                "combat_def": 108, "combat_heal": 4657,
            },
        }
        evidence = self.validator(payload, "profile-1", {13001: 27})
        self.assertEqual("verified", evidence["status"])
        self.assertEqual(
            {"MaxHP": 0, "AttackPower": 0, "DefensePower": 0, "HealPower": 0},
            evidence["details"]["delta"],
        )
        self.assertFalse(any(
            item.get("kind") == "candidate_field" and item.get("key", "").startswith("equip")
            for item in evidence["details"]["dependencies"]
        ))

    def test_level_locked_equipment_is_calculated_as_no_contribution(self) -> None:
        payload = {
            "version": 1,
            "student_id": "cherino_hot_springs",
            "values": {
                "level": 1, "student_star": 5, "bond_rank": 22, "skill2": 1,
                "equip1": "empty", "equip2": "level_locked", "equip3": "level_locked",
                "weapon_state": "weapon_equipped", "weapon_star": 4, "weapon_level": 50,
                "stat_hp": 0, "stat_atk": 0, "stat_heal": 0,
                "combat_hp": 6922, "combat_atk": 1928,
                "combat_def": 19, "combat_heal": 3392,
            },
        }
        evidence = self.validator(payload, "profile-1")
        self.assertNotEqual("partial", evidence["status"])
        self.assertFalse(any(
            item.get("kind") == "candidate_field" and item.get("key", "").startswith("equip")
            for item in evidence["details"]["dependencies"]
        ))

    def test_unobserved_five_star_weapon_is_a_dependency_not_zero(self) -> None:
        payload = {
            "version": 1,
            "student_id": "mika",
            "values": {
                "level": 90, "student_star": 5, "bond_rank": 74, "skill2": 10,
                "equip1": "T10", "equip1_level": 70,
                "equip2": "T10", "equip2_level": 70,
                "equip3": "T10", "equip3_level": 70,
                "stat_hp": 25, "stat_atk": 25, "stat_heal": 25,
                "combat_hp": 95756, "combat_atk": 6893,
                "combat_def": 121, "combat_heal": 5948,
            },
        }
        evidence = self.validator(payload, "profile-1")
        self.assertEqual("dependency_missing", evidence["status"])
        self.assertIn(
            {"kind": "candidate_field", "key": "weapon_state"},
            evidence["details"]["dependencies"],
        )
        self.assertEqual("provide_weapon_values", evidence["details"]["suggestion"]["action"])

    def test_equipped_weapon_with_missing_level_is_a_dependency(self) -> None:
        payload = {
            "version": 1,
            "student_id": "mika",
            "values": {
                "level": 90, "student_star": 5, "bond_rank": 74, "skill2": 10,
                "equip1": "T10", "equip1_level": 70,
                "equip2": "T10", "equip2_level": 70,
                "equip3": "T10", "equip3_level": 70,
                "weapon_state": "weapon_equipped", "weapon_star": 4,
                "stat_hp": 25, "stat_atk": 25, "stat_heal": 25,
                "combat_hp": 95756, "combat_atk": 6893,
                "combat_def": 121, "combat_heal": 5948,
            },
        }
        evidence = self.validator(payload, "profile-1")
        self.assertEqual("dependency_missing", evidence["status"])
        self.assertIn(
            {"kind": "candidate_field", "key": "weapon_level"},
            evidence["details"]["dependencies"],
        )

    def test_unobserved_unstored_potential_is_not_silently_zero(self) -> None:
        payload = {
            "version": 1,
            "student_id": "mika",
            "values": {
                "level": 90, "student_star": 5, "bond_rank": 74, "skill2": 10,
                "equip1": "T10", "equip1_level": 70,
                "equip2": "T10", "equip2_level": 70,
                "equip3": "T10", "equip3_level": 70,
                "weapon_state": "weapon_equipped", "weapon_star": 4, "weapon_level": 60,
                "combat_hp": 95756, "combat_atk": 6893,
                "combat_def": 121, "combat_heal": 5948,
            },
        }
        evidence = self.validator(payload, "profile-1")
        self.assertEqual("dependency_missing", evidence["status"])
        self.assertEqual(
            {"stat_hp", "stat_atk", "stat_heal"},
            {
                item["key"] for item in evidence["details"]["dependencies"]
                if item.get("kind") == "candidate_field" and item.get("key", "").startswith("stat_")
            },
        )
        self.assertEqual("provide_potential_levels", evidence["details"]["suggestion"]["action"])


if __name__ == "__main__":
    unittest.main()
