from __future__ import annotations

import json
from dataclasses import fields
from pathlib import Path
import sys
import unittest

from core.planning import StudentGoal
from core.planning_calc import PlanCostSummary
from core.repository_dto import (
    CONFIRMED_STUDENT_VALUE_FIELDS, ConfirmedStudent, DTO_VERSION,
    FORBIDDEN_BUCKET_FIELDS, InventoryEntry,
    InventorySnapshot, RepositoryCommitCommand, RepositoryDTOError,
    ScannerCandidate, StudentGoalRecord, canonical_json,
)
from core.repository_merge import (
    STUDENT_FIELDS, inventory_diff, merge_inventory, merge_student,
    normalize_inventory, order_inventory, resolve_inventory_snapshot,
)
from core.student_meta_types import StudentMeta


FIXTURE = Path(__file__).parents[2] / "contracts" / "fixtures" / "repository_v6_parity.json"


class RepositoryParityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_fixture_header_and_unique_case_ids(self) -> None:
        self.assertEqual(self.fixture["version"], 1)
        ids = [case["id"] for case in self.fixture["cases"]]
        self.assertGreaterEqual(len(ids), 14)
        self.assertEqual(len(ids), len(set(ids)))

    def test_all_fixture_cases(self) -> None:
        for case in self.fixture["cases"]:
            with self.subTest(case_id=case["id"]):
                operation = case["operation"]
                options = case.get("options", {})
                if operation == "student_merge":
                    actual = merge_student(case["old"], case["new"], **options)
                    actual = {key: actual.get(key) for key in case["expected"]}
                elif operation == "inventory_normalize":
                    actual = normalize_inventory(case["input"])
                elif operation == "inventory_merge":
                    actual = merge_inventory(case["old"], case["new"], **options)
                elif operation == "inventory_order":
                    actual = order_inventory(case["snapshot"], case["profile_order"])
                elif operation == "inventory_diff":
                    actual = [item.to_dict() for item in inventory_diff(case["old"], case["new"])]
                elif operation == "resolve":
                    result = resolve_inventory_snapshot(case["sqlite"], case["json"], **options)
                    actual = {"source": result.source, "snapshot": result.snapshot, "sqlite_error": result.sqlite_error}
                elif operation == "dto_error":
                    deserializers = {
                        "confirmed_student": ConfirmedStudent.from_dict,
                        "student_goal": StudentGoalRecord.from_dict,
                        "repository_commit": RepositoryCommitCommand.from_dict,
                    }
                    with self.assertRaises(RepositoryDTOError) as raised:
                        deserializers[case["dto"]](case["input"])
                    self.assertIn(case["error_contains"], str(raised.exception))
                    continue
                elif operation == "bucket_mapping":
                    confirmed_current_fields = set(CONFIRMED_STUDENT_VALUE_FIELDS)
                    current_fields = confirmed_current_fields | {item.name for item in fields(InventoryEntry)}
                    meta_fields = set(StudentMeta.__annotations__)
                    goal_fields = {item.name for item in fields(StudentGoal)}
                    total_fields = {item.name for item in fields(PlanCostSummary)}
                    expected = case["expected"]
                    self.assertTrue(set(expected["current"]) <= current_fields)
                    self.assertTrue(set(expected["metadata"]) <= meta_fields)
                    self.assertTrue(set(expected["goal"]) <= goal_fields)
                    self.assertTrue(set(expected["total_need"]) <= total_fields)
                    self.assertTrue(set(expected["shortage"]) <= FORBIDDEN_BUCKET_FIELDS)
                    self.assertTrue(confirmed_current_fields.isdisjoint(meta_fields))
                    self.assertIn("display_name", meta_fields)
                    self.assertNotIn("display_name", confirmed_current_fields)
                    self.assertIn("level", confirmed_current_fields)
                    self.assertIn("display_name", STUDENT_FIELDS)
                    self.assertNotEqual(confirmed_current_fields, set(STUDENT_FIELDS))
                    continue
                else:
                    self.fail(f"unhandled fixture operation: {operation}")
                self.assertEqual(actual, case["expected"], case["id"])

    def test_dto_canonical_round_trip(self) -> None:
        payload = {"version":1,"student_id":"s1","values":{"level":80,"equip1":None},"provenance":{"scan_id":"scan-1"}}
        dto = ConfirmedStudent.from_dict(payload)
        self.assertEqual(json.loads(canonical_json(dto.to_dict())), payload)
        snapshot = InventorySnapshot.from_dict({"version":1,"entries":[{"key":"a","quantity":"0"}]})
        self.assertEqual(InventorySnapshot.from_dict(snapshot.to_dict()), snapshot)
        goal = StudentGoalRecord(StudentGoal(student_id="s1", target_level=90))
        self.assertEqual(StudentGoalRecord.from_dict(goal.to_dict()), goal)
        student_commit = RepositoryCommitCommand.from_dict({"version":1,"command_id":"cmd-s","candidate_id":"cand-s","target_kind":"student","confirmed_payload":payload,"replace":True,"profile_ids":[]})
        self.assertEqual(RepositoryCommitCommand.from_dict(student_commit.to_dict()), student_commit)
        inventory_commit = RepositoryCommitCommand.from_dict({"version":1,"command_id":"cmd-i","candidate_id":"cand-i","target_kind":"inventory","confirmed_payload":snapshot.to_dict(),"replace":False,"profile_ids":["equipment"]})
        self.assertEqual(RepositoryCommitCommand.from_dict(inventory_commit.to_dict()), inventory_commit)

    def test_goal_types_ranges_and_direct_construction_are_strict(self) -> None:
        bad_values = [
            {"favorite":"yes"}, {"target_level":"bad"}, {"target_level":True},
            {"target_level":-1}, {"target_level":91}, {"target_star":6},
            {"target_weapon_level":61}, {"target_weapon_star":5},
            {"target_ex_skill":6}, {"target_skill1":11},
            {"target_equip1_tier":11}, {"target_equip1_level":71},
            {"target_equip4_tier":3}, {"target_stat_hp":26}, {"notes":7},
        ]
        for invalid in bad_values:
            payload = {"version":1,"goal":{"student_id":"s1", **invalid}}
            with self.subTest(invalid=invalid), self.assertRaises(RepositoryDTOError):
                StudentGoalRecord.from_dict(payload)
        with self.assertRaises(RepositoryDTOError):
            StudentGoalRecord(StudentGoal(student_id="", target_level=1))
        with self.assertRaises(RepositoryDTOError):
            StudentGoalRecord(StudentGoal(student_id="s1", target_level=True))

    def test_commit_target_options_and_bucket_leaks_are_strict(self) -> None:
        student = {"version":1,"student_id":"s1","values":{"level":80}}
        inventory = {"version":1,"entries":[]}
        base = {"version":1,"command_id":"cmd","candidate_id":"cand","replace":False,"profile_ids":[]}
        invalid = [
            {**base,"target_kind":"student","confirmed_payload":inventory},
            {**base,"target_kind":"inventory","confirmed_payload":student},
            {**base,"target_kind":"student","confirmed_payload":student,"profile_ids":["equipment"]},
            {**base,"target_kind":"inventory","confirmed_payload":inventory,"replace":True},
        ]
        for payload in invalid:
            with self.subTest(payload=payload), self.assertRaises(RepositoryDTOError):
                RepositoryCommitCommand.from_dict(payload)
        for forbidden in FORBIDDEN_BUCKET_FIELDS:
            payload = {**base,"target_kind":"student","confirmed_payload":{"version":1,"student_id":"s1","values":{forbidden:{}}}}
            with self.subTest(forbidden=forbidden), self.assertRaises(RepositoryDTOError):
                RepositoryCommitCommand.from_dict(payload)

    def test_candidate_is_not_confirmed_current_state(self) -> None:
        candidate = ScannerCandidate.from_dict({"version":1,"candidate_id":"c1","session_id":"scan1","target_kind":"student","payload":{"student_id":"s1","level":80},"evidence":[{"field":"level","status":"uncertain","source":"ocr","confidence":0.6}],"review_required":True})
        self.assertTrue(candidate.review_required)
        with self.assertRaises(RepositoryDTOError):
            ConfirmedStudent.from_dict(candidate.to_dict())

    def test_confirmed_current_is_disjoint_from_static_metadata(self) -> None:
        current_fields = set(CONFIRMED_STUDENT_VALUE_FIELDS)
        metadata_fields = set(StudentMeta.__annotations__)
        self.assertEqual(current_fields & metadata_fields, set())
        self.assertIn("display_name", metadata_fields)
        self.assertNotIn("display_name", current_fields)
        self.assertIn("level", current_fields)
        self.assertIn("display_name", STUDENT_FIELDS)
        valid = ConfirmedStudent.from_dict({"version":1,"student_id":"s1","values":{"level":80}})
        command = RepositoryCommitCommand.from_dict({"version":1,"command_id":"cmd","candidate_id":"cand","target_kind":"student","confirmed_payload":valid.to_dict(),"replace":False,"profile_ids":[]})
        self.assertEqual(RepositoryCommitCommand.from_dict(command.to_dict()), command)

    def test_unknown_version_field_missing_and_malformed_rejected(self) -> None:
        valid = {"version":DTO_VERSION,"student_id":"s1","values":{}}
        for payload in ({**valid,"version":2}, {**valid,"extra":1}, {"version":1,"student_id":"s1"}, {**valid,"values":{"level":"bad"}}):
            with self.subTest(payload=payload), self.assertRaises(RepositoryDTOError):
                ConfirmedStudent.from_dict(payload)

    def test_five_data_buckets_cannot_leak_into_current_or_candidate(self) -> None:
        for forbidden in ("metadata", "goals", "costs", "shortages"):
            with self.subTest(forbidden=forbidden), self.assertRaises(RepositoryDTOError):
                ConfirmedStudent.from_dict({"version":1,"student_id":"s1","values":{forbidden:{}}})
            with self.assertRaises(RepositoryDTOError):
                ScannerCandidate.from_dict({"version":1,"candidate_id":"c","session_id":"s","target_kind":"student","payload":{forbidden:{}},"evidence":[],"review_required":True})

    def test_json_is_deterministic_and_has_no_runtime_coupling(self) -> None:
        value = {"z":1,"가":2,"a":{"y":3,"x":4}}
        self.assertEqual(canonical_json(value), canonical_json(value))
        forbidden = ("core.scanner", "PySide6", "PyQt", "tkinter")
        self.assertFalse(any(name in sys.modules for name in forbidden))
        self.assertEqual(len(STUDENT_FIELDS), 25)


if __name__ == "__main__":
    unittest.main()
