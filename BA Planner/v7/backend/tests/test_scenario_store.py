from __future__ import annotations

import itertools
from pathlib import Path
import tempfile
import unittest

from core.repository_store import JsonRepository
from core.scenario_store import ScenarioStore, ScenarioStoreError


def targets(level: int) -> dict[str, int]:
    return {
        "level": level, "bond_rank": 1, "student_star": 1,
        "weapon_level": 0, "weapon_star": 0, "ex_skill": 1,
        "skill1": 1, "skill2": 0, "skill3": 0,
        "equip1_tier": 1,
        "equip2_tier": 1 if level >= 10 else 0,
        "equip3_tier": 1 if level >= 20 else 0,
        "equip1_level": 1,
        "equip2_level": 1 if level >= 10 else 0,
        "equip3_level": 1 if level >= 20 else 0,
        "equip4_tier": 0, "stat_hp": 0, "stat_atk": 0, "stat_heal": 0,
    }


def document(name: str, level: int = 10) -> dict:
    return {
        "version": 1,
        "document_id": f"doc-{name}",
        "name": name,
        "kind": "scenario",
        "phases": [{
            "phase_id": "phase-1",
            "name": "페이즈 1",
            "stages": [{
                "stage_id": "stage-1",
                "student_id": "ayane",
                "name": "목표",
                "targets": targets(level),
            }],
        }],
    }


class ScenarioStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.repository = JsonRepository(self.root)
        created = self.repository.create_profile("Main", "profile-main")
        self.profile_id = created["profile"]["profile_id"]
        ids = itertools.count(1)
        times = itertools.count(1)
        self.store = ScenarioStore(
            self.root,
            profile_revision=lambda profile_id: self.repository.get_state(profile_id)["revision"],
            id_factory=lambda: f"{next(ids):024x}" + "0" * 8,
            clock=lambda: f"2026-08-05T00:00:{next(times):02d}Z",
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_crud_duplicate_restart_and_plan_bucket_isolation(self) -> None:
        profile_path = self.repository._profile_path(self.profile_id)
        profile_before = profile_path.read_bytes()
        created = self.store.create(
            self.profile_id, 0, "create", "후보 A", "설명", 0, document("후보 A"),
        )
        self.assertEqual(created, {"revision": 1, "scenario_id": "0" * 23 + "1"})
        self.assertEqual(
            self.store.create(self.profile_id, 0, "create", "후보 A", "설명", 0, document("후보 A")),
            created,
        )
        self.assertEqual(profile_path.read_bytes(), profile_before)
        self.assertEqual(self.repository.get_state(self.profile_id)["revision"], 0)

        listed = self.store.list(self.profile_id)
        self.assertEqual(listed["revision"], 1)
        self.assertEqual(listed["scenarios"][0]["student_count"], 1)
        loaded = self.store.get(self.profile_id, created["scenario_id"])["scenario"]
        self.assertEqual(loaded["document"]["kind"], "scenario")

        updated = self.store.update(
            self.profile_id, created["scenario_id"], 1, 0, "update",
            "후보 A 수정", "", 0, document("후보 A 수정", 20),
        )
        self.assertEqual(updated["revision"], 2)
        self.assertEqual(self.store.get(self.profile_id, created["scenario_id"])["scenario"]["revision"], 1)

        copied = self.store.duplicate(
            self.profile_id, created["scenario_id"], 2, 1, "duplicate",
        )
        self.assertEqual(copied["revision"], 3)
        copied_record = self.store.get(self.profile_id, copied["scenario_id"])["scenario"]
        self.assertEqual(copied_record["name"], "후보 A 수정 (복사본)")
        self.assertEqual(copied_record["document"]["document_id"], copied["scenario_id"])

        restarted = ScenarioStore(
            self.root,
            profile_revision=lambda profile_id: JsonRepository(self.root).get_state(profile_id)["revision"],
        )
        self.assertEqual(len(restarted.list(self.profile_id)["scenarios"]), 2)
        deleted = restarted.delete(
            self.profile_id, copied["scenario_id"], 3, 0, "delete",
        )
        self.assertEqual(deleted["revision"], 4)
        self.assertEqual(len(restarted.list(self.profile_id)["scenarios"]), 1)

    def test_validation_revision_conflict_and_atomic_failure(self) -> None:
        with self.assertRaisesRegex(ScenarioStoreError, "kind"):
            invalid = {**document("bad"), "kind": "plan"}
            self.store.create(self.profile_id, 0, "bad", "Bad", "", 0, invalid)
        with self.assertRaisesRegex(ScenarioStoreError, "newer"):
            self.store.create(self.profile_id, 0, "future", "Future", "", 1, document("Future"))

        created = self.store.create(
            self.profile_id, 0, "create", "후보", "", 0, document("후보"),
        )
        with self.assertRaises(ScenarioStoreError) as raised:
            self.store.update(
                self.profile_id, created["scenario_id"], 0, 0, "stale",
                "후보", "", 0, document("후보"),
            )
        self.assertEqual(raised.exception.code, "revision_conflict")

        path = self.root / "scenarios" / f"{self.profile_id}.json"
        before = path.read_bytes()
        failing = ScenarioStore(
            self.root,
            profile_revision=lambda profile_id: self.repository.get_state(profile_id)["revision"],
            fault=lambda stage: (_ for _ in ()).throw(RuntimeError(stage)) if stage == "before_replace" else None,
        )
        with self.assertRaises(ScenarioStoreError) as failed:
            failing.duplicate(self.profile_id, created["scenario_id"], 1, 0, "fail")
        self.assertEqual(failed.exception.code, "persistence_failed")
        self.assertEqual(path.read_bytes(), before)

    def test_profile_deletion_removes_scenario_collection(self) -> None:
        self.store.create(self.profile_id, 0, "create", "후보", "", 0, document("후보"))
        scenario_path = self.root / "scenarios" / f"{self.profile_id}.json"
        self.assertTrue(scenario_path.exists())
        self.repository.delete_profile(self.profile_id, 0, "delete-profile")
        self.assertFalse(scenario_path.exists())

    def test_list_includes_current_projection_and_ordered_student_ids(self) -> None:
        self.repository.update_students(
            self.profile_id,
            [{"version": 1, "student_id": "ayane", "values": {"level": 1}}],
            0,
            "students",
        )
        self.repository.update_inventory(
            self.profile_id,
            {
                "version": 1,
                "entries": [{"key": "credits", "quantity": "0"}],
            },
            1,
            "inventory",
        )
        store = ScenarioStore(
            self.root,
            profile_revision=lambda profile_id: self.repository.get_state(profile_id)["revision"],
            profile_state=self.repository.get_state,
            id_factory=lambda: "f" * 32,
        )
        store.create(
            self.profile_id,
            0,
            "calculated",
            "계산 후보",
            "",
            2,
            document("계산 후보"),
        )

        summary = store.list(self.profile_id)["scenarios"][0]
        self.assertEqual(summary["student_ids"], ["ayane"])
        calculation = summary["calculation"]
        self.assertIsNotNone(calculation)
        self.assertGreater(calculation["credits"], 0)
        self.assertGreater(calculation["required_resource_type_count"], 0)
        self.assertGreater(calculation["known_shortage_type_count"], 0)
        self.assertFalse(calculation["inventory_complete"])
        self.assertEqual(calculation["first_bottleneck_phase_number"], 1)
        self.assertEqual(
            calculation["representative_shortage"]["display_name"],
            "크레딧",
        )


if __name__ == "__main__":
    unittest.main()
