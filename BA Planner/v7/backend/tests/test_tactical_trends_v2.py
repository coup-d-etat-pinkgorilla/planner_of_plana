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
from core.tactical_trends_v2 import TacticalTrendsV2
from core.tactical_v2 import TacticalV2Store, V6TacticalImporter
from tests.test_tactical_linking_v2 import lobby_payload
from tests.test_tactical_v2 import create_v6_database


ROOT = Path(__file__).parents[2]


def trend_filters(**changes):
    value = {
        "season": "10", "sources": [], "opponent_identity_id": None,
        "public_signature": None, "date_from": None, "date_to": None,
        "rank_difference_min": None, "rank_difference_max": None,
        "as_of": "2026-03-24T00:00:00+09:00", "stale_after_hours": 12, "limit": 50,
    }
    value.update(changes)
    return value


class TacticalTrendsV2Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        source = root / "legacy.db"
        create_v6_database(source)
        repository = JsonRepository(root / "state")
        self.profile_id = repository.create_profile("P11", "p11")["profile"]["profile_id"]
        clock = lambda: datetime(2026, 7, 29, 12, 0, tzinfo=timezone.utc)
        self.store = TacticalV2Store(root / "state", repository, importer=V6TacticalImporter(clock))
        preview = self.store.preview(self.profile_id, str(source), "legacy")
        self.store.commit(
            self.profile_id, str(source), "legacy", preview["source_fingerprint"],
            [item["issue_id"] for item in preview["issues"]], 0, "import",
        )
        state = self.store.state(self.profile_id)
        self.attack = next(item for item in state["matches"] if item["kind"] == "attack")
        self.rival = next(item for item in state["opponents"] if item["current_display_name"] == "Fixture Rival")
        self.candidates: list[str] = []
        times = ["00:10", "01:10", "02:10", "03:10"]
        for index, short_time in enumerate(times, start=1):
            payload = lobby_payload(
                f"refresh-{str(index) * 24}", f"2026-03-23T{short_time}:00+09:00",
            )
            if index == 3:
                payload["rows"][0]["public_defense"]["strikers"][0]["student_id"] = "eimi"
            committed = self.store.commit_lobby(
                self.profile_id, payload, "10", "urban",
                [{"display_index": 0, "opponent_identity_id": self.rival["identity_id"]}],
                index, f"lobby-{index}",
            )
            self.candidates.append(committed["candidate_ids"][0])
        self.store.select_candidate(
            self.profile_id, self.candidates[0], "2026-03-23T00:20:00+09:00", 5, "select",
        )
        self.store.link_match(self.profile_id, self.attack["match_id"], self.candidates[0], "manual", 6, "link")
        self.state_path = root / "state" / "tactical" / f"{self.profile_id}.v2.json"

        self.state = copy.deepcopy(self.store.state(self.profile_id))
        second_match = copy.deepcopy(self.attack)
        second_match["match_id"] = "match-trend-second"
        second_match["occurred_at"] = "2026-03-23T01:20:00+09:00"
        second_match["observed_at"] = "2026-03-23T01:20:00+09:00"
        second_match["result"] = "loss"
        second_match["source_record_id"] = "attack:trend-second"
        second_match["defense_deck"]["strikers"][0]["student_id"] = "eimi"
        self.state["matches"].append(second_match)
        second_candidate = next(item for item in self.state["lobby_candidates"] if item["candidate_id"] == self.candidates[1])
        second_candidate["selected_at"] = "2026-03-23T01:15:00+09:00"
        second_candidate["match_id"] = second_match["match_id"]
        second_candidate["link_status"] = "manual"
        original_snapshot = next(item for item in self.state["snapshots"] if item["match_id"] == self.attack["match_id"])
        second_snapshot = copy.deepcopy(original_snapshot)
        second_snapshot["snapshot_id"] = "snapshot-trend-second"
        second_snapshot["match_id"] = second_match["match_id"]
        second_snapshot["occurred_at"] = second_match["occurred_at"]
        second_snapshot["observed_at"] = second_match["observed_at"]
        second_snapshot["source_record_id"] = "attack:trend-second:defense"
        second_snapshot["deck"] = copy.deepcopy(second_match["defense_deck"])
        self.state["snapshots"].append(second_snapshot)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_change_funnel_retention_and_freshness_match_independent_fixture(self) -> None:
        fixture = json.loads((ROOT / "contracts" / "fixtures" / "tactical_trends_v2.json").read_text(encoding="utf-8"))["expected"]
        result = TacticalTrendsV2.query(self.state, trend_filters())
        for key in (
            "refresh_count", "exposure_count", "selection_count", "battle_count",
            "result_count", "wins", "losses", "observed_win_rate",
        ):
            self.assertEqual(fixture[key], result["funnel"][key])
        changes = result["changes"]
        self.assertEqual(fixture["public_signature_change_count"], changes["public_signature_total"])
        self.assertEqual(fixture["public_run_count"], changes["public_run_total"])
        self.assertEqual(fixture["public_reuse_count"], changes["public_reuse_total"])
        self.assertEqual(fixture["stable_public_full_defense_change_count"], changes["full_defense_change_total"])
        first_change = changes["public_signature"][0]
        self.assertLess(first_change["interval_start"], first_change["interval_end"])
        retention = result["exposure"]["retention"]
        self.assertEqual(fixture["eligible_transition_count"], retention["eligible_transition_count"])
        self.assertEqual(fixture["retained_transition_count"], retention["retained_transition_count"])
        self.assertEqual(fixture["retention_rate"], retention["retention_rate"])
        self.assertEqual([-1, -2, -3], [row["rank_difference"] for row in result["exposure"]["by_rank_difference"]])
        self.assertTrue(result["freshness"][0]["stale"])
        self.assertFalse(result["freshness"][0]["verified_after_latest_public"])
        self.assertEqual("observed_exposure_rate", result["terminology"]["exposure_rate_label"])

    def test_as_of_rank_and_signature_filters_limit_the_same_population(self) -> None:
        early = TacticalTrendsV2.query(
            self.state,
            trend_filters(as_of="2026-03-23T01:30:00+09:00", rank_difference_min=-3, rank_difference_max=-3),
        )
        self.assertEqual((2, 2, 2), (
            early["funnel"]["refresh_count"], early["funnel"]["exposure_count"], early["funnel"]["battle_count"],
        ))
        signature = TacticalTrendsV2.query(
            self.state, trend_filters(public_signature="eimi|serina|?"),
        )
        self.assertEqual((1, 1, 0), (
            signature["funnel"]["refresh_count"], signature["funnel"]["exposure_count"], signature["funnel"]["battle_count"],
        ))

    def test_duplicate_generation_and_undated_match_do_not_change_time_analysis(self) -> None:
        baseline = TacticalTrendsV2.query(self.state, trend_filters())
        duplicate = copy.deepcopy(self.state["lobby_scans"][0])
        duplicate["scan_id"] = "scan-duplicate-generation"
        duplicate["observed_at"] = "2026-03-23T00:11:00+09:00"
        self.state["lobby_scans"].append(duplicate)
        undated = copy.deepcopy(self.attack)
        undated["match_id"] = "match-undated-trend"
        undated["occurred_at"] = None
        undated["observed_at"] = None
        self.state["matches"].append(undated)
        third_candidate = next(
            item for item in self.state["lobby_candidates"] if item["candidate_id"] == self.candidates[2]
        )
        third_candidate["match_id"] = undated["match_id"]
        third_candidate["link_status"] = "manual"
        result = TacticalTrendsV2.query(self.state, trend_filters())
        self.assertEqual(baseline["funnel"]["refresh_count"], result["funnel"]["refresh_count"])
        self.assertEqual(baseline["funnel"]["exposure_count"], result["funnel"]["exposure_count"])
        self.assertEqual(baseline["funnel"]["battle_count"] + 1, result["funnel"]["battle_count"])
        self.assertEqual(baseline["changes"], result["changes"])
        self.assertEqual(baseline["freshness"], result["freshness"])

    def test_query_is_pure_and_protocol_dispatch_is_schema_valid(self) -> None:
        before = hashlib.sha256(self.state_path.read_bytes()).hexdigest()
        expected = self.store.trends(self.profile_id, trend_filters())
        self.assertEqual(before, hashlib.sha256(self.state_path.read_bytes()).hexdigest())
        app = ApplicationProtocolV1(storage_root=self.state_path.parents[1])
        response = app.handle({
            "protocol": 1, "id": "trends", "type": "request", "method": "tactical.v2.trends.query",
            "payload": {"profile_id": self.profile_id, "filters": trend_filters()},
        })
        self.assertEqual(expected, response["payload"])
        schema = json.loads((ROOT / "contracts" / "tactical-protocol-v2.schema.json").read_text(encoding="utf-8"))
        self.assertEqual([], list(Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(response)))

    def test_strict_filter_validation(self) -> None:
        with self.assertRaises(RepositoryError):
            TacticalTrendsV2.query(self.state, {"as_of": "2026-03-24T00:00:00+09:00"})
        with self.assertRaises(RepositoryError):
            TacticalTrendsV2.query(self.state, trend_filters(stale_after_hours=0))
        with self.assertRaises(RepositoryError):
            TacticalTrendsV2.query(self.state, trend_filters(rank_difference_min=2, rank_difference_max=1))
        with self.assertRaises(RepositoryError):
            TacticalTrendsV2.query(self.state, trend_filters(as_of="2026-03-24T00:00:00"))


if __name__ == "__main__":
    unittest.main()
