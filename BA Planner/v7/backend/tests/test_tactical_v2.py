from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

from jsonschema import Draft202012Validator, FormatChecker

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.tactical_v2 import TacticalV2Store, V6TacticalImporter


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "contracts" / "fixtures" / "tactical_v6_import_v2.json"
PROTOCOL_FIXTURE = ROOT / "contracts" / "fixtures" / "tactical_protocol_v2.json"
SCHEMA = ROOT / "contracts" / "tactical-protocol-v2.schema.json"


def create_v6_database(path: Path) -> None:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    connection = sqlite3.connect(path)
    try:
        connection.executescript(
            """
            CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE matches(
              id TEXT PRIMARY KEY, date TEXT NOT NULL, season TEXT NOT NULL,
              opponent TEXT NOT NULL, result TEXT NOT NULL, my_attack TEXT NOT NULL,
              opponent_defense TEXT NOT NULL, my_defense TEXT NOT NULL,
              opponent_attack TEXT NOT NULL, source TEXT NOT NULL, notes TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            CREATE TABLE jokbo(
              id TEXT PRIMARY KEY, defense TEXT NOT NULL, attack TEXT NOT NULL,
              wins INTEGER NOT NULL, losses INTEGER NOT NULL, notes TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            """
        )
        connection.executemany("INSERT INTO settings(key,value) VALUES(?,?)", fixture["settings"].items())
        connection.executemany(
            "INSERT INTO matches VALUES(:id,:date,:season,:opponent,:result,:my_attack,:opponent_defense,:my_defense,:opponent_attack,:source,:notes,:created_at)",
            fixture["matches"],
        )
        connection.executemany(
            "INSERT INTO jokbo VALUES(:id,:defense,:attack,:wins,:losses,:notes,:updated_at)",
            fixture["jokbo"],
        )
        connection.commit()
    finally:
        connection.close()


class TacticalV2ContractTests(unittest.TestCase):
    def test_shared_protocol_fixture_matches_schema(self) -> None:
        schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
        validator = Draft202012Validator(schema, format_checker=FormatChecker())
        fixture = json.loads(PROTOCOL_FIXTURE.read_text(encoding="utf-8"))
        for case in fixture["cases"]:
            with self.subTest(case=case["name"]):
                self.assertEqual(case["valid"], not list(validator.iter_errors(case["message"])))

    def test_preview_commit_round_trip_and_batch_idempotency(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "tactical_challenge.db"
            create_v6_database(source)
            before = hashlib.sha256(source.read_bytes()).hexdigest()
            repository = JsonRepository(root / "state")
            profile_id = repository.create_profile("P7", "p7")["profile"]["profile_id"]
            clock = lambda: datetime(2026, 7, 29, 12, 0, tzinfo=timezone.utc)
            store = TacticalV2Store(root / "state", repository, importer=V6TacticalImporter(clock))

            preview = store.preview(profile_id, str(source), "legacy-batch")
            self.assertEqual((3, 1, 1), (preview["match_count"], preview["jokbo_count"], preview["issue_count"]))
            self.assertEqual("duplicate_student", preview["issues"][0]["code"])
            with self.assertRaises(RepositoryError) as unreviewed:
                store.commit(profile_id, str(source), "legacy-batch", preview["source_fingerprint"], [], 0, "commit")
            self.assertEqual("import_review_required", unreviewed.exception.code)

            accepted = [preview["issues"][0]["issue_id"]]
            result = store.commit(profile_id, str(source), "legacy-batch", preview["source_fingerprint"], accepted, 0, "commit")
            self.assertEqual({"revision": 1, "imported_matches": 2, "imported_jokbo": 1, "skipped_issues": 1, "skipped_existing": 0}, result)
            state = store.state(profile_id)
            self.assertEqual((2, 1, 2, 1), (len(state["matches"]), len(state["jokbo"]), len(state["opponents"]), len(state["snapshots"])))
            self.assertIsNone(next(item for item in state["matches"] if item["kind"] == "defense")["occurred_at"])
            unknown = state["matches"][0]["attack_deck"]["strikers"][1]
            self.assertEqual(("unknown", None), (unknown["state"], unknown["student_id"]))
            wildcard = state["jokbo"][0]["defense_deck"]["strikers"][1]
            self.assertEqual((True, None, "unknown"), (wildcard["wildcard"], wildcard["student_id"], wildcard["state"]))

            repeated = store.commit(profile_id, str(source), "legacy-batch", preview["source_fingerprint"], accepted, 1, "commit-again")
            self.assertEqual((1, 0, 3), (repeated["revision"], repeated["imported_matches"], repeated["skipped_existing"]))
            self.assertEqual(2, len(store.state(profile_id)["matches"]))
            self.assertEqual(before, hashlib.sha256(source.read_bytes()).hexdigest())

    def test_source_change_and_atomic_failure_do_not_mutate_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "tactical_challenge.db"
            create_v6_database(source)
            repository = JsonRepository(root / "state")
            profile_id = repository.create_profile("P7", "p7")["profile"]["profile_id"]
            importer = V6TacticalImporter(lambda: datetime(2026, 7, 29, tzinfo=timezone.utc))
            preview = importer.preview(source, "batch")
            connection = sqlite3.connect(source)
            connection.execute("UPDATE matches SET notes='changed' WHERE id='legacy-attack'")
            connection.commit()
            connection.close()
            store = TacticalV2Store(root / "state", repository, importer=importer)
            with self.assertRaises(RepositoryError) as changed:
                store.commit(profile_id, str(source), "batch", preview["source_fingerprint"], [item["issue_id"] for item in preview["issues"]], 0, "changed")
            self.assertEqual("import_source_changed", changed.exception.code)
            self.assertEqual(0, store.state(profile_id)["revision"])

            fresh = importer.preview(source, "batch")
            failing = TacticalV2Store(root / "state", repository, importer=importer, fault=lambda stage: (_ for _ in ()).throw(OSError("injected")) if stage == "before_replace" else None)
            with self.assertRaises(RepositoryError) as failure:
                failing.commit(profile_id, str(source), "batch", fresh["source_fingerprint"], [item["issue_id"] for item in fresh["issues"]], 0, "fail")
            self.assertEqual("persistence_failed", failure.exception.code)
            self.assertEqual(0, store.state(profile_id)["revision"])

    def test_application_dispatches_v2_and_rejects_extra_fields(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            storage_root = Path(temporary)
            profile = JsonRepository(storage_root).create_profile("P7", "p7")["profile"]
            app = ApplicationProtocolV1(storage_root=storage_root)
            response = app.handle({"protocol": 1, "id": "s", "type": "request", "method": "tactical.v2.state.get", "payload": {"profile_id": profile["profile_id"]}})
            self.assertEqual(2, response["payload"]["version"])
            invalid = app.handle({"protocol": 1, "id": "x", "type": "request", "method": "tactical.v2.state.get", "payload": {"profile_id": profile["profile_id"], "extra": True}})
            self.assertEqual("invalid_payload", invalid["payload"]["error"]["code"])


if __name__ == "__main__":
    unittest.main()
