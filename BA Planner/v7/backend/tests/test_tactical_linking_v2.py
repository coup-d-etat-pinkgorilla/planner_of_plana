from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest

from jsonschema import Draft202012Validator, FormatChecker

from core.repository_store import JsonRepository, RepositoryError
from core.tactical_v2 import TacticalV2Store, V6TacticalImporter
from tests.test_tactical_v2 import create_v6_database


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "contracts" / "tactical-protocol-v2.schema.json"
LINK_FIXTURE = ROOT / "contracts" / "fixtures" / "tactical_linking_v2.json"


def slot(position: int, student_id: str | None, role: str) -> dict:
    visible = student_id is not None
    return {
        "version": 2, "position": position, "student_id": student_id,
        "state": "visible_lobby" if visible else "unknown",
        "source": "visible_lobby" if visible else "hidden_lobby",
        "confidence": 0.99 if visible else None,
        "review_status": "confirmed" if visible else "review_required",
        "wildcard": False,
    }


def lobby_payload(refresh: str, observed_at: str = "2026-03-23T00:10:00+09:00") -> dict:
    rows = []
    values = [
        (5, "Fixture Rival Renamed", "shiroko", "serina", None),
        (6, "Unbattled A", "eimi", "hibiki", "yakumo"),
        (7, "Unbattled B", "tsubaki", "michiru_dress", "hibiki"),
    ]
    for index, (rank, name, striker, special1, special2) in enumerate(values):
        rows.append({
            "index": index,
            "rank": {"value": rank, "proposed_value": rank, "confidence": 0.99, "margin": 0.1, "review_status": "confirmed"},
            "opponent": {"display_name": name, "proposed_display_name": name, "confidence": 0.99, "margin": 0.1, "review_status": "confirmed"},
            "public_defense": {
                "version": 2,
                "strikers": [slot(0, striker, "striker"), slot(1, None, "striker"), slot(2, None, "striker"), slot(3, None, "striker")],
                "specials": [slot(0, special1, "special"), slot(1, special2, "special")],
            },
            "confidence": 0.99, "review_status": "confirmed",
        })
    return {
        "version": 1, "roi_profile_id": "tactical-lobby-2560x1440-v1",
        "observed_at": observed_at, "screen_hash": "a" * 64,
        "refresh_generation": refresh, "frame_complete": True,
        "current_rank": {"value": 8, "proposed_value": 8, "confidence": 0.99, "margin": 0.1, "review_status": "confirmed"},
        "rows": rows, "overall_confidence": 0.99, "review_status": "confirmed",
    }


class TacticalLinkingV2Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        self.state_root = root / "state"
        source = root / "tactical_challenge.db"
        create_v6_database(source)
        repository = JsonRepository(self.state_root)
        self.repository = repository
        self.profile_id = repository.create_profile("P9", "p9")['profile']['profile_id']
        clock = lambda: datetime(2026, 7, 29, 12, 0, tzinfo=timezone.utc)
        self.store = TacticalV2Store(self.state_root, repository, importer=V6TacticalImporter(clock))
        preview = self.store.preview(self.profile_id, str(source), "legacy")
        self.store.commit(
            self.profile_id, str(source), "legacy", preview["source_fingerprint"],
            [item["issue_id"] for item in preview["issues"]], 0, "import",
        )
        state = self.store.state(self.profile_id)
        self.match = next(item for item in state["matches"] if item["kind"] == "attack")
        self.identity = next(item for item in state["opponents"] if item["current_display_name"] == "Fixture Rival")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def commit_lobby(self, refresh: str, revision: int, key: str):
        return self.store.commit_lobby(
            self.profile_id, lobby_payload(refresh), "10", "urban",
            [{"display_index": 0, "opponent_identity_id": self.identity["identity_id"]}],
            revision, key,
        )

    def test_public_history_identity_alias_and_duplicate_refresh(self) -> None:
        defense = next(item for item in self.store.state(self.profile_id)["matches"] if item["kind"] == "defense")
        with self.assertRaises(RepositoryError) as wrong_direction:
            self.store.link_match(
                self.profile_id, defense["match_id"], None, "auto", 1, "defense-link",
            )
        self.assertEqual("link_conflict", wrong_direction.exception.code)
        committed = self.commit_lobby("refresh-111111111111111111111111", 1, "lobby-1")
        self.assertTrue(committed["created"])
        self.assertEqual(2, committed["revision"])
        state = self.store.state(self.profile_id)
        self.assertEqual((1, 3), (len(state["lobby_scans"]), len(state["lobby_candidates"])))
        self.assertEqual(4, len(state["snapshots"]))
        opponent = next(item for item in state["opponents"] if item["identity_id"] == self.identity["identity_id"])
        self.assertEqual(["Fixture Rival", "Fixture Rival Renamed"], opponent["aliases"])
        public = next(item for item in state["snapshots"] if item["source"] == "lobby_scan")
        self.assertIsNone(public["match_id"])
        self.assertEqual("unknown", public["deck"]["strikers"][1]["state"])
        restarted = TacticalV2Store(self.state_root, self.repository).state(self.profile_id)
        self.assertEqual((1, 3), (len(restarted["lobby_scans"]), len(restarted["lobby_candidates"])))

        repeated = self.commit_lobby("refresh-111111111111111111111111", 2, "lobby-repeat")
        self.assertFalse(repeated["created"])
        self.assertEqual(2, repeated["revision"])
        self.assertEqual(1, len(self.store.state(self.profile_id)["lobby_scans"]))

    def test_automatic_ambiguous_manual_relink_unlink_and_delete(self) -> None:
        first = self.commit_lobby("refresh-111111111111111111111111", 1, "lobby-1")
        first_candidate = first["candidate_ids"][0]
        selected_at = "2026-03-23T00:20:00+09:00"
        self.store.select_candidate(self.profile_id, first_candidate, selected_at, 2, "select-1")
        automatic = self.store.link_match(self.profile_id, self.match["match_id"], None, "auto", 3, "auto")
        self.assertEqual(("automatic", first_candidate), (automatic["status"], automatic["candidate_id"]))
        unlinked = self.store.link_match(self.profile_id, self.match["match_id"], None, "unlink", 4, "unlink")
        self.assertEqual("unlinked", unlinked["status"])

        second = self.commit_lobby("refresh-222222222222222222222222", 5, "lobby-2")
        second_candidate = second["candidate_ids"][0]
        self.store.select_candidate(self.profile_id, second_candidate, selected_at, 6, "select-2")
        ambiguous = self.store.link_match(self.profile_id, self.match["match_id"], None, "auto", 7, "ambiguous")
        self.assertEqual(("ambiguous", 2), (ambiguous["status"], ambiguous["candidate_count"]))
        manual = self.store.link_match(self.profile_id, self.match["match_id"], second_candidate, "manual", 8, "manual-2")
        self.assertEqual(("manual", second_candidate), (manual["status"], manual["candidate_id"]))
        reassigned = self.store.link_match(self.profile_id, self.match["match_id"], first_candidate, "manual", 9, "manual-1")
        self.assertEqual(first_candidate, reassigned["candidate_id"])
        state = self.store.state(self.profile_id)
        self.assertEqual(first_candidate, next(item for item in state["lobby_candidates"] if item["match_id"] == self.match["match_id"])["candidate_id"])

        aliased = self.store.alias_opponent(
            self.profile_id, self.identity["identity_id"], "Fixture Rival Final", "template-2",
            10, "alias",
        )
        self.assertIn("Fixture Rival Final", aliased["aliases"])
        self.assertEqual(["template-2"], aliased["name_template_ids"])
        deleted = self.store.delete_lobby(self.profile_id, second["scan_id"], 11, "delete")
        self.assertTrue(deleted["deleted"])
        final = self.store.state(self.profile_id)
        self.assertTrue(any(item["match_id"] == self.match["match_id"] for item in final["lobby_candidates"]))
        self.assertTrue(any(item["match_id"] is None for item in final["lobby_candidates"]))

    def test_state_and_mutation_messages_match_schema(self) -> None:
        committed = self.commit_lobby("refresh-111111111111111111111111", 1, "lobby")
        validator = Draft202012Validator(json.loads(SCHEMA.read_text(encoding="utf-8")), format_checker=FormatChecker())
        state_message = {"protocol": 1, "id": "state", "type": "response", "method": "tactical.v2.state.get", "payload": self.store.state(self.profile_id)}
        commit_message = {"protocol": 1, "id": "commit", "type": "response", "method": "tactical.v2.lobby.commit", "payload": committed}
        self.assertEqual([], list(validator.iter_errors(state_message)))
        self.assertEqual([], list(validator.iter_errors(commit_message)))
        fixture = json.loads(LINK_FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(["automatic-link", "ambiguous-link", "manual-relink", "unlink", "delete-scan"], [item["name"] for item in fixture["cases"]])

    def test_p9_atomic_failure_and_idempotency_conflict_do_not_mutate_history(self) -> None:
        committed = self.commit_lobby("refresh-111111111111111111111111", 1, "lobby")
        candidate_id = committed["candidate_ids"][0]
        failing = TacticalV2Store(
            self.state_root, self.repository,
            fault=lambda stage: (_ for _ in ()).throw(OSError("injected")) if stage == "before_replace" else None,
        )
        with self.assertRaises(RepositoryError) as failure:
            failing.select_candidate(
                self.profile_id, candidate_id, "2026-03-23T00:20:00+09:00",
                2, "select-fail",
            )
        self.assertEqual("persistence_failed", failure.exception.code)
        state = self.store.state(self.profile_id)
        self.assertEqual(2, state["revision"])
        self.assertIsNone(state["lobby_candidates"][0]["selected_at"])
        with self.assertRaises(RepositoryError) as conflict:
            self.store.select_candidate(
                self.profile_id, candidate_id, "2026-03-23T00:21:00+09:00",
                2, "lobby",
            )
        self.assertEqual("idempotency_conflict", conflict.exception.code)


if __name__ == "__main__":
    unittest.main()
