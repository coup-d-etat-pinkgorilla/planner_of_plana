from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository, RepositoryError


def student(student_id: str = "s1", level: int = 80) -> dict:
    return {"version": 1, "student_id": student_id, "values": {"level": level}}


class RepositoryPersistenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.repository = JsonRepository(self.root)
        self.created = self.repository.create_profile("Main", "create-main")
        self.profile_id = self.created["profile"]["profile_id"]

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_profile_create_list_select_rename_conflict_and_retry(self) -> None:
        retried = self.repository.create_profile("Main", "create-main")
        self.assertEqual(retried, self.created)
        second = self.repository.create_profile("Second", "create-second")
        second_id = second["profile"]["profile_id"]
        selected = self.repository.select_profile(second_id, 0, "select-second")
        self.assertEqual(selected["revision"], 1)
        self.assertEqual(self.repository.current_profile()["profile"]["profile_id"], second_id)
        self.assertEqual(sum(item["selected"] for item in self.repository.list_profiles()["profiles"]), 1)
        renamed = self.repository.rename_profile(second_id, "Renamed", 1, "rename-second")
        self.assertEqual(renamed["revision"], 2)
        with self.assertRaisesRegex(RepositoryError, "already exists"):
            self.repository.rename_profile(second_id, "Main", 2, "rename-conflict")

    def test_current_inventory_goals_restore_in_new_instance(self) -> None:
        result = self.repository.update_students(self.profile_id, [student()], 0, "students")
        result = self.repository.update_inventory(self.profile_id, {"version":1,"entries":[{"key":"a","quantity":"0"}]}, result["revision"], "inventory")
        result = self.repository.save_goals(self.profile_id, {"version":1,"goals":[{"student_id":"s1","target_level":90}]}, result["revision"], "goals")
        restored = JsonRepository(self.root).get_state(self.profile_id)
        self.assertEqual(restored["revision"], 3)
        self.assertEqual(restored["students"][0]["values"]["level"], 80)
        self.assertEqual(restored["inventory"]["entries"][0]["quantity"], "0")
        self.assertEqual(restored["goals"]["goals"][0]["target_level"], 90)
        serialized = json.dumps(restored, sort_keys=True)
        for forbidden in ("display_name", "total_cost", "shortage", "shortages", "credits"):
            self.assertNotIn(forbidden, serialized)

    def test_stale_revision_and_idempotent_retry_do_not_write(self) -> None:
        first = self.repository.update_students(self.profile_id, [student()], 0, "same")
        before = self.repository._profile_path(self.profile_id).read_bytes()
        self.assertEqual(self.repository.update_students(self.profile_id, [student()], 0, "same"), first)
        self.assertEqual(before, self.repository._profile_path(self.profile_id).read_bytes())
        with self.assertRaisesRegex(RepositoryError, "stale"):
            self.repository.update_students(self.profile_id, [student(level=70)], 0, "stale")
        self.assertEqual(before, self.repository._profile_path(self.profile_id).read_bytes())

    def test_atomic_failure_preserves_hash_revision_and_cleans_temp(self) -> None:
        path = self.repository._profile_path(self.profile_id)
        for failure_stage in ("before_write", "before_fsync", "before_replace"):
            before_hash = hashlib.sha256(path.read_bytes()).hexdigest()
            def fail(stage: str) -> None:
                if stage == failure_stage: raise OSError(f"injected {stage} failure")
            failing = JsonRepository(self.root, fault=fail)
            with self.subTest(stage=failure_stage), self.assertRaises(RepositoryError) as raised:
                failing.update_students(self.profile_id, [student()], 0, f"failure-{failure_stage}")
            self.assertEqual(raised.exception.code, "persistence_failed")
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before_hash)
            self.assertEqual(self.repository.get_state(self.profile_id)["revision"], 0)
            self.assertEqual(list(path.parent.glob("*.tmp")), [])

    def test_inventory_resolver_reports_source_and_sqlite_error(self) -> None:
        sqlite = JsonRepository.resolve_inventory_input([{"item_id":"a","quantity":"1"}], {"a":{"item_id":"a","quantity":"9"}})
        self.assertEqual(sqlite["source"], "sqlite")
        fallback = JsonRepository.resolve_inventory_input([], {"a":{"item_id":"a","quantity":"9"}}, sqlite_error="locked")
        self.assertEqual(fallback["source"], "json")
        self.assertEqual(fallback["sqlite_error"], "locked")

    def test_second_file_failure_rolls_back_profile_and_catalog(self) -> None:
        profile_path = self.repository._profile_path(self.profile_id)
        catalog_before = self.repository.catalog_path.read_bytes()
        profile_before = profile_path.read_bytes()
        replaces = 0
        def fail(stage: str) -> None:
            nonlocal replaces
            if stage == "before_replace":
                replaces += 1
                if replaces == 2: raise OSError("injected catalog replace failure")
        failing = JsonRepository(self.root, fault=fail)
        with self.assertRaises(RepositoryError):
            failing.update_students(self.profile_id, [student()], 0, "catalog-failure")
        self.assertEqual(profile_path.read_bytes(), profile_before)
        self.assertEqual(self.repository.catalog_path.read_bytes(), catalog_before)
        self.assertEqual(self.repository.get_state(self.profile_id)["revision"], 0)

    def test_corruption_unknown_version_partial_data_and_lock_fail_closed(self) -> None:
        path = self.repository._profile_path(self.profile_id)
        for content, code in (("{bad", "corrupt_data"), ('{"version":2}', "migration_required"), ('{"version":1}', "corrupt_data")):
            original = path.read_bytes()
            path.write_text(content, encoding="utf-8")
            with self.assertRaises(RepositoryError) as raised:
                self.repository.get_state(self.profile_id)
            self.assertEqual(raised.exception.code, code)
            path.write_bytes(original)
        lock = self.root / ".repository.lock"
        lock.write_text("held", encoding="utf-8")
        with self.assertRaises(RepositoryError) as raised:
            self.repository.update_students(self.profile_id, [student()], 0, "locked")
        self.assertEqual(raised.exception.code, "repository_busy")
        lock.unlink()

    def test_protocol_dispatch_errors_and_migration_boundary(self) -> None:
        protocol = ApplicationProtocolV1(storage_root=self.root)
        request = {"protocol":1,"id":"list","type":"request","method":"repository.profile.list","payload":{}}
        response = protocol.handle(request)
        self.assertEqual(response["id"], "list")
        self.assertEqual(response["payload"]["selected_profile_id"], self.profile_id)
        migration = protocol.handle({**request,"id":"migration","method":"repository.migration.preview","payload":{"source_path":"C:/v6","profile_id":self.profile_id}})
        self.assertEqual(migration["payload"]["error"]["code"], "migration_not_supported")
        invalid = protocol.handle({**request,"id":"invalid","method":"repository.profile.list","payload":{"extra":1}})
        self.assertEqual(invalid["payload"]["error"]["code"], "invalid_payload")

    def test_process_restart_persists_repository_state(self) -> None:
        backend = Path(__file__).parents[1]
        environment = {**os.environ, "BA_PLANNER_STORAGE_ROOT": str(self.root)}
        profile_id = hashlib.sha256(b"process-create").hexdigest()[:24]
        def message(identifier: str, method: str, payload: dict) -> dict:
            return {"protocol":1,"id":identifier,"type":"request","method":method,"payload":payload}
        messages = [
            message("create","repository.profile.create",{"display_name":"Process","idempotency_key":"process-create"}),
            message("students","repository.students.update",{"profile_id":profile_id,"expected_revision":0,"idempotency_key":"process-students","students":[student()]}),
            message("inventory","repository.inventory.update",{"profile_id":profile_id,"expected_revision":1,"idempotency_key":"process-inventory","inventory":{"version":1,"entries":[{"key":"a","quantity":"3"}]}}),
            message("goals","repository.goals.save",{"profile_id":profile_id,"expected_revision":2,"idempotency_key":"process-goals","goals":{"version":1,"goals":[{"student_id":"s1","target_level":90}]}}),
        ]
        process = subprocess.run([sys.executable,"-m","core.backend_process"], cwd=backend, env=environment, input="\n".join(json.dumps(item) for item in messages)+"\n", capture_output=True, text=True, encoding="utf-8", timeout=10)
        self.assertEqual(process.returncode, 0, process.stderr)
        responses = [json.loads(line) for line in process.stdout.splitlines()]
        self.assertEqual([item["payload"].get("revision") for item in responses[1:]], [1,2,3])
        state_request = message("state","repository.state.get",{"profile_id":profile_id})
        restarted = subprocess.run([sys.executable,"-m","core.backend_process"], cwd=backend, env=environment, input=json.dumps(state_request)+"\n", capture_output=True, text=True, encoding="utf-8", timeout=10)
        self.assertEqual(restarted.returncode, 0, restarted.stderr)
        state = json.loads(restarted.stdout)["payload"]
        self.assertEqual(state["revision"], 3)
        self.assertEqual(state["students"][0]["student_id"], "s1")
        self.assertEqual(state["inventory"]["entries"][0]["quantity"], "3")
        self.assertEqual(state["goals"]["goals"][0]["target_level"], 90)


if __name__ == "__main__":
    unittest.main()
