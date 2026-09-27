from __future__ import annotations

import json
from pathlib import Path
import unittest

from core.student_stats import (
    calculate_student_stats,
    interpolate_equipment_stat,
    interpolate_student_stat,
    interpolate_weapon_stat,
    relationship_stat_values,
)
from core.student_stats_catalog import (
    DEFAULT_STUDENT_STAT_CATALOG_PATH,
    DEFAULT_STUDENT_STAT_FORMULA_PATH,
    load_student_stat_catalog,
    load_student_stat_formula,
    student_stat_record,
)
from core.student_stats_types import (
    EquipmentAbsentV1,
    EquipmentLevelV1,
    PotentialLevelsV1,
    RelationshipLevelsV1,
    StudentStatBuildV1,
    StudentStatCatalogV1,
    StudentStatFormulaV1,
    StudentStatsDataError,
    UniqueWeaponLevelV1,
)


FIXTURE_PATH = Path(__file__).parent / "fixtures" / "student_stats_s1_parity.json"


class StudentStatCalculationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = load_student_stat_catalog()
        cls.fixture = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))

    def test_generated_catalog_is_versioned_compact_and_resolves_forms(self) -> None:
        self.assertEqual(1, self.catalog.version)
        self.assertGreaterEqual(len(self.catalog.students), 250)
        self.assertEqual(90, len(self.catalog.equipment))
        self.assertLess(DEFAULT_STUDENT_STAT_CATALOG_PATH.stat().st_size, 250_000)
        self.assertEqual(10000, student_stat_record("aru", catalog=self.catalog).schaledb_id)
        self.assertEqual(
            10099,
            student_stat_record("hoshino_battle", 2, catalog=self.catalog).schaledb_id,
        )
        self.assertEqual(
            10099,
            student_stat_record("hoshino_battle#2", catalog=self.catalog).schaledb_id,
        )
        raw_text = DEFAULT_STUDENT_STAT_CATALOG_PATH.read_text(encoding="utf-8")
        self.assertNotIn('"Skills"', raw_text)
        self.assertNotIn('"Name"', raw_text)

    def test_catalog_rejects_unknown_version(self) -> None:
        raw = json.loads(DEFAULT_STUDENT_STAT_CATALOG_PATH.read_text(encoding="utf-8"))
        raw["version"] = 2
        with self.assertRaisesRegex(StudentStatsDataError, "version must be 1"):
            StudentStatCatalogV1.from_dict(raw)

    def test_aru_relationship_rank_parity(self) -> None:
        student = student_stat_record(self.fixture["student"], catalog=self.catalog)
        self.assertEqual(self.fixture["schaledb_id"], student.schaledb_id)
        for case in self.fixture["relationship"]:
            with self.subTest(rank=case["rank"]):
                self.assertEqual(case["expected"], relationship_stat_values(student, case["rank"]))

    def test_equipment_level_one_middle_and_max_parity(self) -> None:
        for case in self.fixture["equipment_interpolation"]:
            record = self.catalog.equipment[(case["category"], case["tier"])]
            stat = next(item for item in record.stats if item.stat == case["stat"])
            with self.subTest(case=case):
                self.assertEqual(
                    case["expected"],
                    interpolate_equipment_stat(stat, case["level"], record.max_level),
                )

    def test_star_one_through_five_edges(self) -> None:
        fixture = self.fixture["star_edges"]
        student = student_stat_record(fixture["student"], catalog=self.catalog)
        equipment = tuple(
            EquipmentLevelV1(item["tier"], item["level"]) if item is not None else None
            for item in fixture["equipment"]
        )
        for star_text, expected in fixture["expected"].items():
            star = int(star_text)
            build = StudentStatBuildV1(
                level=fixture["level"],
                star=star,
                equipment=equipment,
                relationship=RelationshipLevelsV1(
                    current_rank=1,
                    alternate_ranks={},
                    unowned_alternate_ids=frozenset(student.relationship.alternate_ids),
                ),
                passive_skill_level=None if star == 1 else 10,
            )
            with self.subTest(star=star):
                result = calculate_student_stats(student, build, self.catalog)
                self.assertEqual("complete", result.status)
                self.assertEqual(expected, result.values)

    def test_full_build_parity_covers_weapon_potential_and_mixed_equipment_levels(self) -> None:
        fixture = self.fixture["full_build"]
        student = student_stat_record(self.fixture["student"], catalog=self.catalog)
        build = StudentStatBuildV1(
            level=fixture["level"],
            star=fixture["star"],
            equipment=tuple(
                EquipmentLevelV1(item["tier"], item["level"])
                for item in fixture["equipment"]
            ),
            relationship=RelationshipLevelsV1(
                current_rank=fixture["relationship_rank"],
                alternate_ranks={},
                unowned_alternate_ids=frozenset(fixture["unowned_alternate_ids"]),
            ),
            weapon=UniqueWeaponLevelV1(**fixture["weapon"]),
            favorite_gear_tier=fixture["favorite_gear_tier"],
            potential=PotentialLevelsV1(**fixture["potential"]),
            passive_skill_level=10,
        )
        result = calculate_student_stats(student, build, self.catalog)
        self.assertEqual("complete", result.status)
        self.assertEqual(fixture["expected"], result.values)
        self.assertEqual(1032, result.contributions["unique_weapon"].flat["AttackPower"])
        self.assertEqual(883, result.contributions["potential"].flat["MaxHP"])

    def test_unknown_alternate_relationship_is_not_treated_as_zero(self) -> None:
        student = student_stat_record("aru", catalog=self.catalog)
        equipment = (
            EquipmentLevelV1(1, 10),
            EquipmentLevelV1(1, 10),
            EquipmentLevelV1(1, 10),
        )
        missing = calculate_student_stats(
            student,
            StudentStatBuildV1(
                level=90,
                star=5,
                equipment=equipment,
                relationship=RelationshipLevelsV1(current_rank=20, alternate_ranks={}),
                passive_skill_level=10,
            ),
            self.catalog,
        )
        unowned = calculate_student_stats(
            student,
            StudentStatBuildV1(
                level=90,
                star=5,
                equipment=equipment,
                relationship=RelationshipLevelsV1(
                    current_rank=20,
                    alternate_ranks={},
                    unowned_alternate_ids=frozenset(student.relationship.alternate_ids),
                ),
                passive_skill_level=10,
            ),
            self.catalog,
        )
        self.assertEqual("dependency_missing", missing.status)
        self.assertIsNone(missing.values)
        self.assertEqual(
            [("alternate_relationship", "10031"), ("alternate_relationship", "10089")],
            [(item.kind, item.key) for item in missing.missing_dependencies],
        )
        self.assertEqual("complete", unowned.status)
        self.assertIsNotNone(unowned.values)
        self.assertEqual(missing.partial_values, unowned.values)

    def test_missing_current_relationship_and_equipment_are_explicit_dependencies(self) -> None:
        student = student_stat_record("aru", catalog=self.catalog)
        result = calculate_student_stats(
            student,
            StudentStatBuildV1(
                level=20,
                star=3,
                equipment=(EquipmentLevelV1(1, 1), None, None),
                relationship=RelationshipLevelsV1(
                    current_rank=None,
                    alternate_ranks={},
                    unowned_alternate_ids=frozenset(student.relationship.alternate_ids),
                ),
                passive_skill_level=10,
            ),
            self.catalog,
        )
        self.assertEqual("dependency_missing", result.status)
        self.assertIsNone(result.values)
        self.assertEqual(
            {("equipment", "slot:2"), ("equipment", "slot:3"), ("current_relationship", "10000")},
            {(item.kind, item.key) for item in result.missing_dependencies},
        )

    def test_observed_empty_equipment_is_not_a_missing_dependency(self) -> None:
        student = student_stat_record("chise_swimsuit", catalog=self.catalog)
        result = calculate_student_stats(
            student,
            StudentStatBuildV1(
                level=90,
                star=3,
                equipment=(EquipmentAbsentV1(), EquipmentAbsentV1(), EquipmentAbsentV1()),
                relationship=RelationshipLevelsV1(
                    current_rank=14,
                    alternate_ranks={},
                    unowned_alternate_ids=frozenset(student.relationship.alternate_ids),
                ),
                passive_skill_level=1,
            ),
            self.catalog,
        )
        self.assertEqual("complete", result.status)
        self.assertEqual((), result.missing_dependencies)

    def test_favorite_gear_primary_stat_is_a_multiplier_eligible_flat_contribution(self) -> None:
        student = student_stat_record("eimi", catalog=self.catalog)
        equipment = (
            EquipmentLevelV1(1, 1),
            EquipmentLevelV1(1, 1),
            EquipmentLevelV1(1, 1),
        )
        common = dict(
            level=20,
            star=3,
            equipment=equipment,
            relationship=RelationshipLevelsV1(
                current_rank=20,
                alternate_ranks={},
                unowned_alternate_ids=frozenset(student.relationship.alternate_ids),
            ),
            passive_skill_level=10,
        )
        without_gear = calculate_student_stats(
            student, StudentStatBuildV1(**common), self.catalog
        )
        with_gear = calculate_student_stats(
            student, StudentStatBuildV1(**common, favorite_gear_tier=1), self.catalog
        )
        self.assertEqual(10_000, with_gear.values["MaxHP"] - without_gear.values["MaxHP"])
        self.assertEqual(
            10_000,
            with_gear.contributions["favorite_gear"].flat["MaxHP"],
        )

    def test_passive_and_weapon_passive_primary_stats_are_level_aware(self) -> None:
        student = student_stat_record("hoshino", catalog=self.catalog)
        build = StudentStatBuildV1(
            level=90,
            star=5,
            equipment=(
                EquipmentLevelV1(1, 10),
                EquipmentLevelV1(1, 10),
                EquipmentLevelV1(1, 10),
            ),
            relationship=RelationshipLevelsV1(
                current_rank=29,
                alternate_ranks={},
                unowned_alternate_ids=frozenset(student.relationship.alternate_ids),
            ),
            weapon=UniqueWeaponLevelV1(star=2, level=40),
            passive_skill_level=10,
        )
        result = calculate_student_stats(student, build, self.catalog)
        self.assertEqual("complete", result.status)
        self.assertEqual(
            {"DefensePower": 2660},
            result.contributions["passive_skill"].coefficient_basis_points,
        )
        self.assertEqual(
            {"DefensePower": 380},
            result.contributions["weapon_passive_skill"].flat,
        )


class StudentStatGameFormulaTests(unittest.TestCase):
    """In-client formula details (data/extracted/GAME_RULES.md section 4)."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = load_student_stat_catalog()
        cls.formula = load_student_stat_formula()

    def test_formula_tables_load_and_reject_unknown_version(self) -> None:
        self.assertEqual(100, self.formula.end_level)
        self.assertEqual({"Standard": 0, "Premature": 1, "LateBloom": 2}, dict(self.formula.growth_types))
        self.assertEqual(10000, self.formula.level_interpolation[100][0])
        raw = json.loads(DEFAULT_STUDENT_STAT_FORMULA_PATH.read_text(encoding="utf-8"))
        raw["version"] = 2
        with self.assertRaisesRegex(StudentStatsDataError, "version must be 1"):
            StudentStatFormulaV1.from_dict(raw)

    def test_equipment_level_maps_onto_the_hundred_level_table(self) -> None:
        # Lv2 of a 10-level item reads table level 20 (ratio 0.1919), not (2-1)/(10-1).
        record = self.catalog.equipment[("Bag", 1)]
        stat = next(item for item in record.stats if item.stat == "MaxHP_Base")
        self.assertEqual([375, 418], [interpolate_equipment_stat(stat, level, 10) for level in (1, 2)])
        self.assertEqual(stat.level_max, interpolate_equipment_stat(stat, 10, 10))

    def test_star_and_potential_bonus_share_one_ceiling(self) -> None:
        aru = student_stat_record("aru", catalog=self.catalog)
        hp = next(item for item in aru.base_stats if item.stat == "MaxHP")
        star = sum(self.formula.transcendence_default["MaxHP"][:5])
        potential_one = self.formula.potential_default["MaxHP"][1]
        self.assertEqual(23873, interpolate_student_stat(hp.level_1, hp.level_max, 90, star + potential_one))

    def test_non_standard_weapon_growth_uses_its_table_column(self) -> None:
        hina = student_stat_record("hina", catalog=self.catalog)
        self.assertEqual("LateBloom", hina.weapon.growth_type)
        low, high = hina.weapon.attack
        self.assertEqual(472, interpolate_weapon_stat(low, high, 22, "LateBloom"))
        self.assertEqual(1031, interpolate_weapon_stat(low, high, 60, "LateBloom"))

    def test_exact_relationship_increments_cover_mine_idol_rank_41(self) -> None:
        mine = self.catalog.students[16016]
        self.assertIsNotNone(mine.relationship.increments)
        before = relationship_stat_values(mine, 40)["AttackPower"]
        self.assertEqual(3, relationship_stat_values(mine, 41)["AttackPower"] - before)


if __name__ == "__main__":
    unittest.main()
