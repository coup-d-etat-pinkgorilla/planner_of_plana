from __future__ import annotations

import json
from pathlib import Path
import unittest

from core.student_stats import (
    calculate_student_stats,
    interpolate_equipment_stat,
    relationship_stat_values,
)
from core.student_stats_catalog import (
    DEFAULT_STUDENT_STAT_CATALOG_PATH,
    load_student_stat_catalog,
    student_stat_record,
)
from core.student_stats_types import (
    EquipmentLevelV1,
    PotentialLevelsV1,
    RelationshipLevelsV1,
    StudentStatBuildV1,
    StudentStatCatalogV1,
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
        )
        result = calculate_student_stats(student, build, self.catalog)
        self.assertEqual("complete", result.status)
        self.assertEqual(fixture["expected"], result.values)
        self.assertEqual(1032, result.contributions["unique_weapon"].separated_flat["AttackPower"])
        self.assertEqual(883, result.contributions["potential"].separated_flat["MaxHP"])

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
            ),
            self.catalog,
        )
        self.assertEqual("dependency_missing", result.status)
        self.assertIsNone(result.values)
        self.assertEqual(
            {("equipment", "slot:2"), ("equipment", "slot:3"), ("current_relationship", "10000")},
            {(item.kind, item.key) for item in result.missing_dependencies},
        )

    def test_favorite_gear_primary_stat_is_a_separated_flat_contribution(self) -> None:
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
            with_gear.contributions["favorite_gear"].separated_flat["MaxHP"],
        )


if __name__ == "__main__":
    unittest.main()
