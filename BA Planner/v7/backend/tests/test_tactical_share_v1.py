from __future__ import annotations

import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from jsonschema import Draft202012Validator, FormatChecker

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.tactical_share_v1 import TacticalShareV1Store
from core.tactical_v2 import TacticalV2Store, V6TacticalImporter
from tests.test_tactical_linking_v2 import lobby_payload
from tests.test_tactical_v2 import create_v6_database


ROOT = Path(__file__).parents[2]


def analytics_filters(**changes):
    value = {
        "scope_id": "scope-season-10", "season": "10", "patch": "2026.07", "map": "urban",
        "public_signature": None, "defense_signature": None,
        "rank_difference_min": None, "rank_difference_max": None,
        "as_of": "2026-07-29T23:00:00+00:00", "min_independent_contributors": 2,
        "min_independent_opponents": 2, "limit": 20,
    }
    value.update(changes)
    return value


def shared_record(index: int, contributor: str, opponent: str, session: str, attempt: int, result: str, *, attack="ayane,hoshino,?,empty|serina,*", defense="shiroko,eimi,?,empty|serina,*"):
    occurred = f"2026-07-{20 + index:02d}T0{index % 9}:00:00+00:00"
    return {
        "version": 1, "share_id": f"share-{index}", "scope_id": "scope-season-10",
        "contributor_id": contributor, "consent_scope": "scope-season-10",
        "consented_at": "2026-07-01T00:00:00+00:00", "shared_at": "2026-07-29T12:00:00+00:00",
        "occurred_at": occurred, "attempt_session_id": session, "attempt_index": attempt,
        "defense_snapshot_id": f"shared-snapshot-{opponent}-{index}",
        "anonymous_opponent_id": opponent, "season": "10", "patch": "2026.07", "map": "urban",
        "rank_difference": -3, "public_signature": "shiroko|serina|?",
        "defense_signature": defense, "attack_signature": attack, "result": result,
        "source_identity": f"source-{index}", "source_type": "battle_result",
    }


class TacticalShareV1Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        source = root / "legacy.db"
        create_v6_database(source)
        self.repository = JsonRepository(root / "state")
        self.profile_id = self.repository.create_profile("P13", "p13")["profile"]["profile_id"]
        clock = lambda: datetime(2026, 7, 29, 12, 0, tzinfo=timezone.utc)
        self.store = TacticalV2Store(root / "state", self.repository, importer=V6TacticalImporter(clock))
        preview = self.store.preview(self.profile_id, str(source), "legacy")
        self.store.commit(
            self.profile_id, str(source), "legacy", preview["source_fingerprint"],
            [item["issue_id"] for item in preview["issues"]], 0, "import",
        )
        state = self.store.state(self.profile_id)
        self.attack = next(item for item in state["matches"] if item["kind"] == "attack")
        rival = next(item for item in state["opponents"] if item["current_display_name"] == "Fixture Rival")
        lobby = self.store.commit_lobby(
            self.profile_id, lobby_payload("refresh-222222222222222222222222"), "10", "urban",
            [{"display_index": 0, "opponent_identity_id": rival["identity_id"]}], 1, "lobby",
        )
        self.store.select_candidate(
            self.profile_id, lobby["candidate_ids"][0], "2026-03-23T00:20:00+09:00", 2, "select",
        )
        self.store.link_match(self.profile_id, self.attack["match_id"], lobby["candidate_ids"][0], "manual", 3, "link")
        self.share_store = TacticalShareV1Store(root / "state", self.repository, self.store)
        self.share_path = root / "state" / "tactical-share" / f"{self.profile_id}.v1.json"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def prepare(self):
        return self.share_store.prepare(self.profile_id, {
            "match_id": self.attack["match_id"], "scope_id": "scope-season-10",
            "contributor_id": "install-anonymous-a", "consent": {
                "enabled": True, "scope_id": "scope-season-10", "contributor_id": "install-anonymous-a",
                "consented_at": "2026-03-23T00:00:00+09:00", "include_original_media": False,
            }, "attempt_session_id": "attempt-session-a", "attempt_index": 1,
            "shared_at": "2026-07-29T12:00:00+00:00", "patch": "2026.07",
        })

    def test_prepare_requires_opt_in_and_removes_names_roi_media_and_local_ids(self) -> None:
        prepared = self.prepare()
        wire = json.dumps(prepared, ensure_ascii=False)
        self.assertFalse(any(prepared["redaction"].values()))
        for private in ("Fixture Rival", "screen_hash", "roi_profile_id", "opponent_display_name", self.attack["opponent_identity_id"], self.attack["match_id"]):
            self.assertNotIn(private, wire)
        invalid = {
            "match_id": self.attack["match_id"], "scope_id": "scope-season-10", "contributor_id": "install-a",
            "consent": {"enabled": False, "scope_id": "scope-season-10", "contributor_id": "install-a", "consented_at": "2026-03-23T00:00:00+09:00", "include_original_media": False},
            "attempt_session_id": "session-a", "attempt_index": 1, "shared_at": "2026-07-29T12:00:00+00:00", "patch": "2026.07",
        }
        with self.assertRaises(RepositoryError) as caught:
            self.share_store.prepare(self.profile_id, invalid)
        self.assertEqual("consent_required", caught.exception.code)

    def test_import_retry_withdraw_reimport_and_cache_stay_consistent(self) -> None:
        share = self.prepare()["share"]
        imported = self.share_store.import_records(self.profile_id, [share], 0, "import-one")
        self.assertEqual((1, 1), (imported["revision"], imported["aggregate_cache"]["active_record_count"]))
        self.assertEqual(imported, self.share_store.import_records(self.profile_id, [share], 0, "import-one"))
        duplicate = self.share_store.import_records(self.profile_id, [share], 1, "import-duplicate")
        self.assertEqual((1, 0, 1), (duplicate["revision"], duplicate["imported"], duplicate["skipped_duplicate"]))
        withdrawn = self.share_store.withdraw(
            self.profile_id, [share["share_id"]], "2026-07-29T13:00:00+00:00", "user_request", 1, "withdraw",
        )
        self.assertEqual((2, 1, 0), (withdrawn["revision"], withdrawn["withdrawn"], withdrawn["aggregate_cache"]["active_record_count"]))
        rejected = self.share_store.import_records(self.profile_id, [share], 2, "reimport")
        self.assertEqual((2, 1), (rejected["revision"], rejected["skipped_withdrawn"]))
        restored = TacticalShareV1Store(self.share_store.root, self.repository, self.store).state(self.profile_id)
        self.assertEqual((0, 1), (len(restored["records"]), len(restored["tombstones"])))

    def test_attempt_independence_concentration_lifetime_and_substitution(self) -> None:
        records = [
            shared_record(1, "contributor-a", "opponent-a", "session-a", 1, "loss"),
            shared_record(2, "contributor-a", "opponent-a", "session-a", 2, "win"),
            shared_record(3, "contributor-b", "opponent-b", "session-b", 1, "win"),
            shared_record(4, "contributor-c", "opponent-a", "session-c", 1, "loss"),
            shared_record(5, "contributor-c", "opponent-b", "session-c", 2, "loss"),
            shared_record(6, "contributor-c", "opponent-b", "session-c", 3, "win"),
            shared_record(7, "contributor-a", "opponent-a", "session-d", 1, "win", attack="ayane,eimi,?,empty|serina,*"),
            shared_record(8, "contributor-b", "opponent-b", "session-e", 1, "loss", attack="ayane,eimi,?,empty|serina,*"),
        ]
        self.share_store.import_records(self.profile_id, records, 0, "bulk")
        before = hashlib.sha256(self.share_path.read_bytes()).hexdigest()
        result = self.share_store.analytics(self.profile_id, analytics_filters())
        self.assertEqual(before, hashlib.sha256(self.share_path.read_bytes()).hexdigest())
        self.assertEqual({"match_count": 8, "contributor_count": 3, "opponent_count": 2, "attempt_session_count": 5}, result["population"])
        main = next(item for item in result["groups"] if item["match_count"] == 6)
        self.assertEqual((3, 0.5), (main["contributor_count"], main["max_contributor_share"]))
        self.assertAlmostEqual(1 / 3, main["attempts"]["first_attempt_observed_win_rate"])
        self.assertEqual((2, 2), (main["attempts"]["mean_attempts_to_first_success"], main["attempts"]["median_attempts_to_first_success"]))
        self.assertEqual({"1": 1 / 3, "2": 2 / 3, "3": 1.0}, main["attempts"]["cumulative_success_within"])
        self.assertEqual(1, len(result["one_slot_substitutions"]))
        self.assertFalse(result["privacy"]["raw_identifiers_returned"])
        self.assertFalse(result["ml"]["implemented"])

    def test_small_groups_are_suppressed_and_contributors_are_not_matches(self) -> None:
        records = [
            shared_record(1, "contributor-a", "opponent-a", "session-a", 1, "win"),
            shared_record(2, "contributor-a", "opponent-a", "session-a", 2, "loss"),
            shared_record(3, "contributor-b", "opponent-b", "session-b", 1, "win"),
        ]
        self.share_store.import_records(self.profile_id, records, 0, "small")
        result = self.share_store.analytics(self.profile_id, analytics_filters(min_independent_contributors=3))
        self.assertEqual((3, 2), (result["population"]["match_count"], result["population"]["contributor_count"]))
        self.assertEqual([], result["groups"])
        self.assertEqual(1, result["privacy"]["suppressed_group_count"])
        self.assertNotIn("opponent-a", json.dumps(result))

    def test_corrupt_cache_is_rejected(self) -> None:
        self.share_store.import_records(self.profile_id, [shared_record(1, "contributor-a", "opponent-a", "session-a", 1, "win")], 0, "one")
        value = json.loads(self.share_path.read_text(encoding="utf-8"))
        value["aggregate_cache"]["active_record_count"] = 999
        self.share_path.write_text(json.dumps(value), encoding="utf-8")
        with self.assertRaises(RepositoryError) as caught:
            self.share_store.state(self.profile_id)
        self.assertEqual("corrupt_data", caught.exception.code)

    def test_contract_fixture_and_application_dispatch(self) -> None:
        schema = json.loads((ROOT / "contracts/tactical-share-v1.schema.json").read_text(encoding="utf-8"))
        fixture = json.loads((ROOT / "contracts/fixtures/tactical_share_v1.json").read_text(encoding="utf-8"))
        validator = Draft202012Validator(schema, format_checker=FormatChecker())
        for case in fixture["cases"]:
            self.assertEqual(case["valid"], validator.is_valid(case["message"]), case["name"])
        app = ApplicationProtocolV1(storage_root=self.share_store.root)
        request = fixture["cases"][0]["message"]
        request["payload"]["profile_id"] = self.profile_id
        response = app.handle(request)
        self.assertEqual("response", response["type"])
        self.assertEqual(1, response["payload"]["version"])


if __name__ == "__main__":
    unittest.main()
