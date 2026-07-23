from __future__ import annotations

import hashlib
from pathlib import Path
import tempfile
import unittest

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.tactical_store import TacticalStore


def deck(striker: str | None = None, special: str | None = None) -> dict:
    return {"version": 1, "strikers": [striker, None, None, None], "specials": [special, None]}


def match(match_id: str = "m1", *, own: str = "hoshino") -> dict:
    return {"version": 1, "match_id": match_id, "kind": "attack", "occurred_on": None,
            "season": " S1 ", "opponent": " Rival ", "result": "win",
            "attack_deck": deck(own, "ayane"), "defense_deck": deck("shiroko", "serika_new_year"), "notes": " note "}


class TacticalPersistenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.repository = JsonRepository(self.root)
        self.profile_id = self.repository.create_profile("Main", "main")["profile"]["profile_id"]
        students = [{"version": 1, "student_id": item, "values": {}} for item in ("hoshino", "ayane")]
        self.repository.update_students(self.profile_id, students, 0, "owned")
        self.store = TacticalStore(self.root, self.repository)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_match_crud_restart_revision_and_idempotency(self) -> None:
        result = self.store.upsert_match(self.profile_id, match(), 0, "save")
        self.assertEqual({"revision": 1}, result)
        self.assertEqual(result, self.store.upsert_match(self.profile_id, match(), 0, "save"))
        restored = TacticalStore(self.root, JsonRepository(self.root)).state(self.profile_id)
        self.assertEqual("S1", restored["matches"][0]["season"])
        self.assertEqual("Rival", restored["matches"][0]["opponent"])
        self.assertEqual([None, None, None], restored["matches"][0]["attack_deck"]["strikers"][1:])
        with self.assertRaises(RepositoryError) as stale:
            self.store.delete_match(self.profile_id, "m1", 0, "stale")
        self.assertEqual("revision_conflict", stale.exception.code)
        self.assertEqual(2, self.store.delete_match(self.profile_id, "m1", 1, "delete")["revision"])
        self.assertEqual([], self.store.state(self.profile_id)["matches"])

    def test_class_duplicate_owned_and_date_validation(self) -> None:
        bad = match()
        bad["attack_deck"] = deck("shiroko")
        with self.assertRaisesRegex(RepositoryError, "not confirmed"):
            self.store.upsert_match(self.profile_id, bad, 0, "not-owned")
        bad = match()
        bad["attack_deck"]["strikers"][0] = None
        bad["attack_deck"]["specials"][0] = "hoshino"
        with self.assertRaisesRegex(RepositoryError, "special"):
            self.store.upsert_match(self.profile_id, bad, 0, "class")
        bad = match()
        bad["occurred_on"] = "2026-02-30"
        with self.assertRaisesRegex(RepositoryError, "ISO"):
            self.store.upsert_match(self.profile_id, bad, 0, "date")
        bad = match()
        bad["attack_deck"]["strikers"][1] = "hoshino"
        with self.assertRaisesRegex(RepositoryError, "duplicate"):
            self.store.upsert_match(self.profile_id, bad, 0, "duplicate")

    def test_jokbo_profile_isolation_and_repository_separation(self) -> None:
        jokbo = {"version": 1, "jokbo_id": "j1", "defense_deck": deck("shiroko"),
                 "attack_deck": deck("hoshino", "ayane"), "notes": ""}
        self.store.upsert_jokbo(self.profile_id, jokbo, 0, "jokbo")
        second = self.repository.create_profile("Second", "second")["profile"]["profile_id"]
        self.assertEqual([], self.store.state(second)["jokbo"])
        repository_state = self.repository.get_state(self.profile_id)
        self.assertNotIn("tactical", repository_state)
        self.assertEqual(1, self.store.delete_jokbo(self.profile_id, "j1", 1, "delete")["revision"] - 1)

    def test_atomic_failure_preserves_existing_state(self) -> None:
        self.store.upsert_match(self.profile_id, match(), 0, "save")
        path = self.store._path(self.profile_id)
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        def fail(stage: str) -> None:
            if stage == "before_replace":
                raise OSError("injected")
        failing = TacticalStore(self.root, self.repository, fault=fail)
        with self.assertRaises(RepositoryError):
            failing.upsert_match(self.profile_id, match("m2"), 1, "fail")
        self.assertEqual(before, hashlib.sha256(path.read_bytes()).hexdigest())
        self.assertEqual(1, self.store.state(self.profile_id)["revision"])

    def test_application_dispatches_strict_tactical_messages(self) -> None:
        app = ApplicationProtocolV1(storage_root=self.root)
        response = app.handle({"protocol": 1, "id": "r", "type": "request",
                               "method": "tactical.state.get", "payload": {"profile_id": self.profile_id}})
        self.assertEqual(0, response["payload"]["revision"])
        invalid = app.handle({"protocol": 1, "id": "x", "type": "request",
                              "method": "tactical.state.get", "payload": {"profile_id": self.profile_id, "x": 1}})
        self.assertEqual("invalid_payload", invalid["payload"]["error"]["code"])


if __name__ == "__main__":
    unittest.main()
