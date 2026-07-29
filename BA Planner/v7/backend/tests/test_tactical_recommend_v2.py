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
from core.tactical_recommend_v2 import TacticalRecommendationV2
from core.tactical_stats_v2 import deck_signature
from core.tactical_v2 import TacticalV2Store, V6TacticalImporter
from tests.test_tactical_linking_v2 import lobby_payload
from tests.test_tactical_v2 import create_v6_database


ROOT = Path(__file__).parents[2]


def recommendation_filters(**changes):
    value = {
        "season": "10", "opponent_identity_id": "opponent-placeholder",
        "public_signature": "shiroko|serina|?", "rank_difference": -3,
        "as_of": "2026-03-24T00:00:00+09:00", "half_life_hours": 24,
        "min_target_samples": 3, "top_k": 5,
        "owned_student_ids": ["ayane", "hoshino"],
    }
    value.update(changes)
    return value


class TacticalRecommendationV2Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        source = root / "legacy.db"
        create_v6_database(source)
        repository = JsonRepository(root / "state")
        self.profile_id = repository.create_profile("P12", "p12")["profile"]["profile_id"]
        clock = lambda: datetime(2026, 7, 29, 12, 0, tzinfo=timezone.utc)
        self.store = TacticalV2Store(root / "state", repository, importer=V6TacticalImporter(clock))
        preview = self.store.preview(self.profile_id, str(source), "legacy")
        self.store.commit(
            self.profile_id, str(source), "legacy", preview["source_fingerprint"],
            [item["issue_id"] for item in preview["issues"]], 0, "import",
        )
        initial = self.store.state(self.profile_id)
        self.attack = next(item for item in initial["matches"] if item["kind"] == "attack")
        self.rival = next(item for item in initial["opponents"] if item["current_display_name"] == "Fixture Rival")
        lobby = self.store.commit_lobby(
            self.profile_id, lobby_payload("refresh-111111111111111111111111"), "10", "urban",
            [{"display_index": 0, "opponent_identity_id": self.rival["identity_id"]}], 1, "lobby",
        )
        self.store.select_candidate(
            self.profile_id, lobby["candidate_ids"][0], "2026-03-23T00:20:00+09:00", 2, "select",
        )
        self.store.link_match(self.profile_id, self.attack["match_id"], lobby["candidate_ids"][0], "manual", 3, "link")
        self.state_path = root / "state" / "tactical" / f"{self.profile_id}.v2.json"
        self.state = copy.deepcopy(self.store.state(self.profile_id))
        self.target = recommendation_filters(opponent_identity_id=self.rival["identity_id"])
        base_candidate = next(item for item in self.state["lobby_candidates"] if item["match_id"] == self.attack["match_id"])
        base_snapshot = next(item for item in self.state["snapshots"] if item["match_id"] == self.attack["match_id"])

        second_match = copy.deepcopy(self.attack)
        second_match["match_id"] = "match-recommend-second"
        second_match["occurred_at"] = "2026-03-23T01:00:00+09:00"
        second_match["observed_at"] = second_match["occurred_at"]
        second_match["result"] = "loss"
        second_match["source_record_id"] = "attack:recommend-second"
        second_match["defense_deck"]["strikers"][1]["student_id"] = "eimi"
        second_match["defense_deck"]["strikers"][1]["state"] = "revealed_after_battle"
        second_match["defense_deck"]["strikers"][1]["review_status"] = "confirmed"
        self.state["matches"].append(second_match)
        second_candidate = copy.deepcopy(base_candidate)
        second_candidate["candidate_id"] = "candidate-recommend-second"
        second_candidate["match_id"] = second_match["match_id"]
        second_candidate["link_status"] = "manual"
        self.state["lobby_candidates"].append(second_candidate)
        second_snapshot = copy.deepcopy(base_snapshot)
        second_snapshot["snapshot_id"] = "snapshot-recommend-second"
        second_snapshot["match_id"] = second_match["match_id"]
        second_snapshot["occurred_at"] = second_match["occurred_at"]
        second_snapshot["observed_at"] = second_match["observed_at"]
        second_snapshot["source_record_id"] = "attack:recommend-second:defense"
        second_snapshot["deck"] = copy.deepcopy(second_match["defense_deck"])
        self.state["snapshots"].append(second_snapshot)

        older = copy.deepcopy(base_snapshot)
        older["snapshot_id"] = "snapshot-recommend-older"
        older["match_id"] = "match-recommend-older"
        older["occurred_at"] = "2026-03-22T00:00:00+09:00"
        older["observed_at"] = older["occurred_at"]
        older["source"] = "manual"
        older["source_record_id"] = "manual:recommend-older"
        older["season"] = "9"
        self.state["snapshots"].append(older)

        other_identity = next(
            item["opponent_identity_id"] for item in self.state["lobby_candidates"]
            if item["opponent_identity_id"] != self.rival["identity_id"]
        )
        other_match = copy.deepcopy(self.attack)
        other_match["match_id"] = "match-recommend-other"
        other_match["opponent_identity_id"] = other_identity
        other_match["opponent_display_name"] = "Unbattled A"
        other_match["occurred_at"] = "2026-03-23T02:00:00+09:00"
        other_match["observed_at"] = other_match["occurred_at"]
        other_match["source_record_id"] = "attack:recommend-other"
        other_match["attack_deck"]["strikers"][0]["student_id"] = "shiroko"
        self.state["matches"].append(other_match)
        other_candidate = copy.deepcopy(base_candidate)
        other_candidate["candidate_id"] = "candidate-recommend-other"
        other_candidate["opponent_identity_id"] = other_identity
        other_candidate["match_id"] = other_match["match_id"]
        other_candidate["link_status"] = "manual"
        self.state["lobby_candidates"].append(other_candidate)
        other_snapshot = copy.deepcopy(base_snapshot)
        other_snapshot["snapshot_id"] = "snapshot-recommend-other"
        other_snapshot["opponent_identity_id"] = other_identity
        other_snapshot["match_id"] = other_match["match_id"]
        other_snapshot["occurred_at"] = other_match["occurred_at"]
        other_snapshot["observed_at"] = other_match["observed_at"]
        other_snapshot["source_record_id"] = "attack:recommend-other:defense"
        self.state["snapshots"].append(other_snapshot)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_hierarchy_scenarios_hidden_slots_and_recommendation_components(self) -> None:
        fixture = json.loads(
            (ROOT / "contracts" / "fixtures" / "tactical_recommendation_v2.json").read_text(encoding="utf-8")
        )["expected"]
        result = TacticalRecommendationV2.query(self.state, self.target)
        self.assertEqual("available", result["availability"]["status"])
        self.assertEqual(fixture["selected_stage"], result["selected_stage"])
        self.assertEqual(fixture["included_snapshot_count"], result["evidence_summary"]["included_snapshot_count"])
        self.assertEqual(fixture["scenario_total"], result["scenario_total"])
        fallback = next(item for item in result["fallback_path"] if item["stage"] == fixture["fallback_stage"])
        self.assertEqual(fixture["fallback_contributed_snapshot_count"], fallback["contributed_snapshot_count"])
        self.assertEqual(fixture["public_known_slot_count"], result["ambiguity"]["public_known_slot_count"])
        self.assertEqual(fixture["variant_defense_possible"], result["ambiguity"]["variant_defense_possible"])
        self.assertEqual(fixture["confidence_grade"], result["confidence"]["grade"])
        self.assertEqual(fixture["calibration_gate_passed"], result["confidence"]["calibration_gate_passed"])
        self.assertEqual(fixture["recommendation_total"], result["recommendation_total"])
        self.assertEqual(
            {deck_signature(item["deck"]) for item in result["scenarios"]},
            {deck_signature(item["deck"]) for item in self.state["snapshots"] if item["snapshot_id"] in {
                "snapshot-recommend-second", "snapshot-recommend-older", base_snapshot_id(self.state, self.attack["match_id"]),
            }},
        )
        self.assertTrue(all(set(item["score_components"]) == {
            "observed_outcome", "recency", "sample", "opponent_specificity", "source_quality",
        } for item in result["recommendations"]))
        self.assertTrue(any(item["all_known_students_owned"] for item in result["recommendations"]))
        self.assertTrue(any("shiroko" in item["missing_student_ids"] for item in result["recommendations"]))

    def test_broader_stage_and_no_evidence_are_explicit_without_generated_fallback(self) -> None:
        broader = TacticalRecommendationV2.query(
            self.state, recommendation_filters(opponent_identity_id="opponent-not-observed", min_target_samples=1),
        )
        self.assertEqual(4, broader["selected_stage"])
        unavailable = TacticalRecommendationV2.query(
            self.state, recommendation_filters(
                opponent_identity_id="opponent-not-observed", public_signature="no|such|signature",
            ),
        )
        self.assertEqual("unavailable", unavailable["availability"]["status"])
        self.assertEqual("no_observed_full_defense_evidence", unavailable["availability"]["reason"])
        self.assertEqual([], unavailable["scenarios"])
        self.assertEqual([], unavailable["recommendations"])
        self.assertEqual("unavailable", unavailable["confidence"]["grade"])

    def test_time_ordered_backtest_has_no_snapshot_overlap_and_keeps_gate_closed(self) -> None:
        validation = TacticalRecommendationV2.query(self.state, self.target)["validation"]
        self.assertGreaterEqual(validation["evaluated_case_count"], 2)
        self.assertTrue(validation["time_ordered"])
        self.assertFalse(validation["same_snapshot_train_test_overlap"])
        self.assertIsNotNone(validation["top1_accuracy"])
        self.assertIsNotNone(validation["topk_accuracy"])
        self.assertIsNotNone(validation["brier_score"])
        self.assertIsNotNone(validation["log_loss"])
        self.assertFalse(validation["calibration_gate_passed"])

    def test_query_is_pure_and_protocol_dispatch_is_schema_valid(self) -> None:
        before = hashlib.sha256(self.state_path.read_bytes()).hexdigest()
        filters = recommendation_filters(opponent_identity_id=self.rival["identity_id"], min_target_samples=1)
        expected = self.store.recommendations(self.profile_id, filters)
        self.assertEqual(before, hashlib.sha256(self.state_path.read_bytes()).hexdigest())
        app = ApplicationProtocolV1(storage_root=self.state_path.parents[1])
        response = app.handle({
            "protocol": 1, "id": "recommend", "type": "request", "method": "tactical.v2.recommend.query",
            "payload": {"profile_id": self.profile_id, "filters": filters},
        })
        self.assertEqual(expected, response["payload"])
        schema = json.loads((ROOT / "contracts" / "tactical-protocol-v2.schema.json").read_text(encoding="utf-8"))
        self.assertEqual([], list(Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(response)))

    def test_saved_prediction_is_separate_from_observed_snapshots_and_restores(self) -> None:
        before = self.store.state(self.profile_id)
        filters = recommendation_filters(opponent_identity_id=self.rival["identity_id"], min_target_samples=1)
        saved = self.store.save_recommendation(
            self.profile_id, filters, before["revision"], "save-recommendation",
        )
        self.assertTrue(saved["created"])
        after = self.store.state(self.profile_id)
        self.assertEqual(len(before["snapshots"]), len(after["snapshots"]))
        self.assertEqual(1, len(after["predictions"]))
        self.assertEqual(saved["prediction_id"], after["predictions"][0]["prediction_id"])
        self.assertEqual(saved, self.store.save_recommendation(
            self.profile_id, filters, before["revision"], "save-recommendation",
        ))
        restored = TacticalV2Store(self.state_path.parents[1], self.store.repository).get_recommendation(
            self.profile_id, saved["prediction_id"],
        )
        self.assertEqual(saved["prediction"], restored)
        schema = json.loads((ROOT / "contracts" / "tactical-protocol-v2.schema.json").read_text(encoding="utf-8"))
        validator = Draft202012Validator(schema, format_checker=FormatChecker())
        for method, payload in (
            ("tactical.v2.recommend.save", saved),
            ("tactical.v2.recommend.get", restored),
            ("tactical.v2.state.get", after),
        ):
            message = {"protocol": 1, "id": method, "type": "response", "method": method, "payload": payload}
            self.assertEqual([], list(validator.iter_errors(message)))

    def test_strict_filter_validation(self) -> None:
        with self.assertRaises(RepositoryError):
            TacticalRecommendationV2.query(self.state, {"as_of": "2026-03-24T00:00:00+09:00"})
        with self.assertRaises(RepositoryError):
            TacticalRecommendationV2.query(self.state, recommendation_filters(half_life_hours=0))
        with self.assertRaises(RepositoryError):
            TacticalRecommendationV2.query(self.state, recommendation_filters(owned_student_ids=["not-canonical"]))
        with self.assertRaises(RepositoryError):
            TacticalRecommendationV2.query(self.state, recommendation_filters(as_of="2026-03-24T00:00:00"))


def base_snapshot_id(state: dict, match_id: str) -> str:
    return next(item["snapshot_id"] for item in state["snapshots"] if item["match_id"] == match_id)


if __name__ == "__main__":
    unittest.main()
