from __future__ import annotations

from datetime import datetime, timezone
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from jsonschema import Draft202012Validator, FormatChecker

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.tactical_v2 import TacticalV2Store, V6TacticalImporter
from core.tactical_stats_v2 import TacticalStatisticsV2
from tests.test_tactical_linking_v2 import lobby_payload
from tests.test_tactical_v2 import create_v6_database


def filters(**changes):
    value = {
        "season": None, "sources": [], "opponent_identity_id": None,
        "public_signature": None, "date_from": None, "date_to": None,
        "limit": 50,
    }
    value.update(changes)
    return value


class TacticalStatisticsV2Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        source = root / "legacy.db"
        create_v6_database(source)
        repository = JsonRepository(root / "state")
        self.profile_id = repository.create_profile("P10", "p10")["profile"]["profile_id"]
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
        lobby = self.store.commit_lobby(
            self.profile_id,
            lobby_payload("refresh-111111111111111111111111"),
            "10", "urban",
            [{"display_index": 0, "opponent_identity_id": self.rival["identity_id"]}],
            1, "lobby",
        )
        self.public_signature = "shiroko|serina|?"
        self.store.select_candidate(
            self.profile_id, lobby["candidate_ids"][0],
            "2026-03-23T00:20:00+09:00", 2, "select",
        )
        self.store.link_match(
            self.profile_id, self.attack["match_id"], None, "auto", 3, "link",
        )
        self.state_path = root / "state" / "tactical" / f"{self.profile_id}.v2.json"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_signature_opponent_attack_and_quality_aggregates(self) -> None:
        fixture = json.loads(
            (Path(__file__).parents[2] / "contracts" / "fixtures" / "tactical_statistics_v2.json").read_text(encoding="utf-8")
        )["expected"]
        before = hashlib.sha256(self.state_path.read_bytes()).hexdigest()
        result = self.store.statistics(self.profile_id, filters())
        after = hashlib.sha256(self.state_path.read_bytes()).hexdigest()
        self.assertEqual(before, after)
        self.assertEqual(fixture["population"], result["population"])
        signature = next(item for item in result["public_signatures"] if item["public_signature"] == fixture["public_signature"])
        self.assertEqual(
            (fixture["signature_exposure_count"], fixture["signature_linked_match_count"], fixture["signature_wins"], fixture["signature_losses"]),
            (signature["exposure_count"], signature["linked_match_count"], signature["wins"], signature["losses"]),
        )
        self.assertEqual(1.0, signature["observed_win_rate"])
        self.assertGreater(signature["wilson95_low"], 0.0)
        self.assertLess(signature["wilson95_low"], signature["wilson95_high"])
        self.assertEqual(1, signature["full_defense_total"])
        self.assertEqual(1, signature["attack_deck_total"])
        self.assertEqual((1, 1), (result["attack_patterns"]["exact_total"], result["attack_patterns"]["exact"][0]["count"]))
        self.assertEqual((fixture["dated_match_count"], fixture["undated_match_count"]), (result["quality"]["dated_match_count"], result["quality"]["undated_match_count"]))
        self.assertEqual(fixture["date_coverage"], result["quality"]["date_coverage"])
        self.assertEqual("observed_win_rate", result["terminology"]["rate_label"])

    def test_filters_limit_numerator_and_denominator_together(self) -> None:
        opponent = self.store.statistics(
            self.profile_id,
            filters(opponent_identity_id=self.rival["identity_id"], public_signature=self.public_signature),
        )
        self.assertEqual((1, 1, 1, 1), (
            opponent["population"]["refresh_count"],
            opponent["population"]["exposure_count"],
            opponent["population"]["match_count"],
            opponent["population"]["opponent_count"],
        ))
        dated = self.store.statistics(
            self.profile_id,
            filters(date_from="2026-03-22T00:00:00+09:00", date_to="2026-03-24T00:00:00+09:00"),
        )
        self.assertEqual(1, dated["population"]["match_count"])
        self.assertEqual(0, dated["quality"]["undated_match_count"])
        imported = self.store.statistics(self.profile_id, filters(sources=["v6_import"]))
        self.assertEqual((0, 0, 2), (
            imported["population"]["refresh_count"],
            imported["population"]["exposure_count"],
            imported["population"]["match_count"],
        ))
        lobby_only = self.store.statistics(self.profile_id, filters(sources=["lobby_scan"]))
        self.assertEqual((1, 3, 0), (
            lobby_only["population"]["refresh_count"],
            lobby_only["population"]["exposure_count"],
            lobby_only["population"]["match_count"],
        ))

    def test_undated_full_snapshot_is_not_presented_as_recent(self) -> None:
        result = self.store.statistics(self.profile_id, filters())
        rival2 = next(item for item in result["opponents"] if item["display_name"] == "Fixture Rival 2")
        self.assertIsNone(rival2["latest_full"])

    def test_prediction_records_are_never_counted_as_observed_results(self) -> None:
        state = copy.deepcopy(self.store.state(self.profile_id))
        prediction = copy.deepcopy(self.attack)
        prediction["match_id"] = "match-prediction-000000000000"
        prediction["source"] = "prediction"
        state["matches"].append(prediction)
        result = TacticalStatisticsV2.query(state, filters(sources=["prediction"]))
        self.assertEqual(0, result["population"]["match_count"])
        self.assertEqual({}, result["quality"]["source_counts"])

    def test_strict_filters_reject_unknown_source_and_bad_ranges(self) -> None:
        with self.assertRaises(RepositoryError):
            self.store.statistics(self.profile_id, filters(sources=["made_up"]))
        with self.assertRaises(RepositoryError):
            self.store.statistics(
                self.profile_id,
                filters(date_from="2026-03-24T00:00:00Z", date_to="2026-03-23T00:00:00Z"),
            )
        with self.assertRaises(RepositoryError):
            self.store.statistics(self.profile_id, {"limit": 10})

    def test_protocol_schema_and_dispatch_return_the_same_deterministic_result(self) -> None:
        query_filters = filters(season="10")
        expected = self.store.statistics(self.profile_id, query_filters)
        message = {
            "protocol": 1, "id": "stats", "type": "response",
            "method": "tactical.v2.stats.query", "payload": expected,
        }
        schema = json.loads(
            (Path(__file__).parents[2] / "contracts" / "tactical-protocol-v2.schema.json").read_text(encoding="utf-8")
        )
        self.assertEqual([], list(Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(message)))
        app = ApplicationProtocolV1(storage_root=self.state_path.parents[1])
        response = app.handle({
            "protocol": 1, "id": "stats", "type": "request",
            "method": "tactical.v2.stats.query",
            "payload": {"profile_id": self.profile_id, "filters": query_filters},
        })
        self.assertEqual(expected, response["payload"])


if __name__ == "__main__":
    unittest.main()
