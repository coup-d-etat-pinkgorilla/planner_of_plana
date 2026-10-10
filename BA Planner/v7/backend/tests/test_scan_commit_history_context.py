from copy import deepcopy
from dataclasses import FrozenInstanceError
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from jsonschema import Draft202012Validator
from core.current_history import HistoryError, ScanHistoryContext
from core.repository_dto import canonical_json
from core.repository_protocol_v1 import RepositoryProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.scan_commit_history_context import FIELDS, ScanCommitHistoryContext

ROOT = Path(__file__).resolve().parents[2]
TMP = ROOT / "debug/xb_history_context_finalize_20261010/artifacts/runtime_tmp"
AT = datetime(2026, 10, 10, 6, 0, tzinfo=timezone.utc)


class ScanCommitContextTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((ROOT / "contracts/fixtures/scan_commit_history_context_v1.json").read_text(encoding="utf-8"))
        cls.schema = json.loads((ROOT / "contracts/scan-commit-history-context-v1.schema.json").read_text(encoding="utf-8"))
        cls.validator = Draft202012Validator(cls.schema)
        TMP.mkdir(parents=True, exist_ok=True)

    def repository(self, *, clock=None):
        temporary = tempfile.TemporaryDirectory(dir=TMP)
        self.addCleanup(temporary.cleanup)
        repo = JsonRepository(Path(temporary.name), clock=clock or (lambda: AT))
        pid = repo.create_profile("Synthetic H1", "synthetic-h1")["profile"]["profile_id"]
        return repo, pid

    def context(self, **updates):
        raw = deepcopy(self.fixture["cases"][0]["context"])
        raw.update(updates)
        return ScanCommitHistoryContext.from_wire(raw, bucket="students")

    @staticmethod
    def current():
        return [{"version": 1, "student_id": "aru", "values": {"level": 0}},
                {"version": 1, "student_id": "shiroko", "values": {"level": 0}}]

    def seed_scan(self):
        repo, pid = self.repository()
        payload = self.current()
        repo.update_students(pid, payload, 0, "seed", manual=True)
        repo.update_students(pid, payload, 1, "scan", history_context=self.context())
        return repo, pid, payload

    def test_shared_policy_fixture_schema_and_strict_runtime_boundaries(self):
        Draft202012Validator.check_schema(self.schema)
        self.assertEqual(set(FIELDS), set(self.schema["required"]))
        self.assertNotIn("version", self.schema["properties"])
        self.assertNotIn("DRAFT", json.dumps(self.schema))
        self.assertNotIn("CM_REQUIRED", json.dumps(self.schema))
        for case in self.fixture["cases"]:
            with self.subTest(case=case["id"]):
                self.assertEqual(case["schema_valid"], not list(self.validator.iter_errors(case["context"])))
                if case["valid"]:
                    context = ScanCommitHistoryContext.from_wire(case["context"], bucket=case["bucket"])
                    self.assertEqual(case["canonical"], context.to_wire())
                else:
                    with self.assertRaises(HistoryError):
                        ScanCommitHistoryContext.from_wire(case["context"], bucket=case["bucket"])

    def test_immutable_detached_flat_and_nested_adapter(self):
        raw = deepcopy(self.fixture["cases"][0]["context"])
        context = ScanCommitHistoryContext.from_wire(raw, bucket="students")
        raw["applied_keys"].clear()
        self.assertEqual(("aru",), context.applied_keys)
        with self.assertRaises(FrozenInstanceError):
            context.retry_of = "changed"
        exported = context.to_wire()
        exported["excluded_keys"].clear()
        nested = context.to_history_context().to_wire()
        self.assertEqual({"student_ids": ["aru"], "resource_keys": []}, nested["applied_scope"])
        self.assertEqual({"source", "scan_kind", "inventory_scan_profile", "scan_context", "applied_scope"}, set(nested))
        nested["applied_scope"]["student_ids"].clear()
        self.assertEqual(["aru"], context.to_wire()["applied_keys"])
        self.assertEqual(["shiroko"], context.to_wire()["excluded_keys"])

    def test_shared_repository_first_and_nochange_cases_preserve_event_shape_and_exclusions(self):
        for case in self.fixture["repository_cases"]:
            with self.subTest(case=case["id"]):
                repo, pid = self.repository()
                update = repo.update_students if case["bucket"] == "students" else repo.update_inventory
                update(pid, case["initial"], 0, "seed", manual=True)
                context = ScanCommitHistoryContext.from_wire(case["context"], bucket=case["bucket"])
                self.assertEqual({"revision": 2}, update(pid, case["payload"], 1, "scan", history_context=context))
                history = repo._profile(pid)["current_history"]
                event = history["events"][-1]
                self.assertNotIn("excluded_keys", event)
                self.assertNotIn("retry_of", event)
                change_key = "student_changes" if case["bucket"] == "students" else "inventory_changes"
                self.assertEqual(case["nochange"], not event[change_key])
                bucket, identity = (("by_student_id", "student_id") if case["bucket"] == "students" else ("by_resource_key", "resource_key"))
                self.assertEqual(context.applied_keys, tuple(row[identity] for row in history["latest_scans"][bucket]))
                self.assertEqual(1, history["total_counts"]["scan"])
                self.assertEqual({"revision": 2}, update(pid, case["payload"], 1, "scan", history_context=context))
                self.assertEqual(history, repo._profile(pid)["current_history"])

    def test_exclusion_retry_and_other_flat_field_changes_conflict_with_original_key(self):
        repo, pid, payload = self.seed_scan()
        before = repo._profile_path(pid).read_bytes()
        changes = [dict(excluded_keys=[]), dict(retry_of="original-key"),
                   dict(session_id="other"), dict(candidate_id="other"),
                   dict(generation=2), dict(candidate_revision=1),
                   dict(scan_kind="Other Raw Kind"), dict(inventory_scan_profile=None),
                   dict(applied_keys=["aru", "shiroko"], excluded_keys=[])]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(RepositoryError) as caught:
                repo.update_students(pid, payload, 1, "scan", history_context=self.context(**change))
            self.assertEqual("idempotency_conflict", caught.exception.code)
            self.assertEqual(before, repo._profile_path(pid).read_bytes())

    def test_replay_after_restart_and_intervening_write_preserves_first_response_and_current(self):
        repo, pid, payload = self.seed_scan()
        changed = deepcopy(payload)
        changed[0]["values"]["level"] = 1
        repo.update_students(pid, changed, 2, "external-write", manual=True)
        before = repo._profile_path(pid).read_bytes()
        def clock():
            self.fail("Replay must not read a clock")
        fresh = JsonRepository(repo.root, clock=clock)
        self.assertEqual({"revision": 2}, fresh.update_students(pid, payload, 1, "scan", history_context=self.context()))
        self.assertEqual(before, repo._profile_path(pid).read_bytes())
        self.assertEqual(changed, fresh.get_state(pid)["students"])
        self.assertEqual(3, fresh.get_history_summary([pid])["profiles"][0]["total_event_count"])

    def test_writer_mismatch_scope_outside_and_excluded_mutation_are_atomic_errors(self):
        repo, pid, payload = self.seed_scan()
        before = repo._profile_path(pid).read_bytes()
        with self.assertRaises(RepositoryError):
            repo.update_inventory(pid, {"version": 1, "entries": []}, 2, "wrong-bucket", history_context=self.context())
        with self.assertRaises(RepositoryError):
            repo.update_students(pid, payload, 2, "outside", history_context=self.context(applied_keys=["unknown"]))
        changed = deepcopy(payload)
        changed[1]["values"]["level"] = 1
        with self.assertRaises(RepositoryError):
            repo.update_students(pid, changed, 2, "excluded-diff", history_context=self.context())
        self.assertEqual(before, repo._profile_path(pid).read_bytes())

    def test_legacy_nested_and_contextless_fingerprints_cache_and_long_scope_keep_old_rules(self):
        for mode in ("unattributed", "manual", "nested"):
            with self.subTest(mode=mode):
                repo, pid = self.repository()
                student_id = "x" * 1025
                payload = [{"version": 1, "student_id": student_id, "values": {}}]
                kwargs = {"manual": True} if mode == "manual" else {}
                nested = None
                if mode == "nested":
                    nested = ScanHistoryContext.from_wire({"source": "scan", "scan_kind": " Old ", "inventory_scan_profile": None,
                        "scan_context": {"session_id": "old", "generation": 1, "candidate_id": "old", "candidate_revision": 0},
                        "applied_scope": {"student_ids": [student_id], "resource_keys": []}})
                    kwargs = {"history_context": nested}
                repo.update_students(pid, payload, 0, "legacy", **kwargs)
                operation = "students:" + canonical_json(payload)
                if nested:
                    operation = "students-history:" + canonical_json({"current": payload, "history_context": nested.to_wire()})
                fingerprint = hashlib.sha256(canonical_json({"operation": operation, "expected_revision": 0}).encode()).hexdigest()
                self.assertEqual(fingerprint, repo._profile(pid)["idempotency"]["legacy"]["fingerprint"])
                raw = repo._profile(pid)
                raw.pop("current_history")
                path = repo._profile_path(pid)
                path.write_text(json.dumps(raw), encoding="utf-8")
                before = path.read_bytes()
                fresh = JsonRepository(repo.root, clock=lambda: self.fail("Old cache replay sampled clock"))
                self.assertEqual({"revision": 1}, fresh.update_students(pid, payload, 0, "legacy", **kwargs))
                self.assertEqual(before, path.read_bytes())
                self.assertNotIn("current_history", fresh._profile(pid))

    def test_public_rpc_forged_context_and_manual_internal_context_are_rejected(self):
        repo, pid = self.repository()
        protocol = RepositoryProtocolV1(repo)
        for method, bucket in (("repository.students.update", "students"), ("repository.inventory.update", "inventory")):
            payload = {"profile_id": pid, "expected_revision": 0, "idempotency_key": "forge",
                       bucket: [] if bucket == "students" else {"version": 1, "entries": []}}
            for key, value in (("history_context", self.context().to_wire()), ("source", "scan")):
                wire = {"protocol": 1, "id": "forged", "type": "request", "method": method, "payload": {**payload, key: value}}
                self.assertEqual("invalid_payload", protocol.handle(wire)["payload"]["error"]["code"])
        with self.assertRaises(RepositoryError):
            repo.update_students(pid, self.current(), 0, "manual-forge", manual=True, history_context=self.context())
        self.assertEqual(0, repo.get_history_summary([pid])["profiles"][0]["total_event_count"])


if __name__ == "__main__":
    unittest.main()
