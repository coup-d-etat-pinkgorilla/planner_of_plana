from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime
import math
import re
from typing import Any, Callable

from core import student_meta
from core.repository_store import RepositoryError
from core.tactical_stats_v2 import deck_signature


_FILTER_KEYS = {
    "season", "opponent_identity_id", "public_signature", "rank_difference",
    "as_of", "half_life_hours", "min_target_samples", "top_k", "owned_student_ids",
}
_RECORD_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
_STUDENTS = frozenset(student_meta.STUDENTS)
_STAGES = (
    (1, "same_opponent_signature_season"),
    (2, "same_opponent_signature"),
    (3, "same_opponent_recent_full"),
    (4, "same_season_signature"),
    (5, "same_rank_condition_signature"),
    (6, "all_opponents_signature"),
)


def _time(value: object, label: str) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise RepositoryError("invalid_payload", f"{label} must be an ISO timestamp")
    try:
        result = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError as error:
        raise RepositoryError("invalid_payload", f"{label} must be an ISO timestamp") from error
    if result.tzinfo is None:
        raise RepositoryError("invalid_payload", f"{label} must include a timezone")
    return result


def canonical_recommend_filters(raw: object) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != _FILTER_KEYS:
        raise RepositoryError("invalid_payload", f"filters must contain exactly {sorted(_FILTER_KEYS)}")
    season = raw["season"]
    opponent = raw["opponent_identity_id"]
    signature = raw["public_signature"]
    if not isinstance(season, str) or not season:
        raise RepositoryError("invalid_payload", "season must be a non-empty string")
    if not isinstance(opponent, str) or _RECORD_ID.fullmatch(opponent) is None:
        raise RepositoryError("invalid_payload", "opponent_identity_id must be a stable record ID")
    if not isinstance(signature, str) or not signature:
        raise RepositoryError("invalid_payload", "public_signature must be non-empty")
    rank = raw["rank_difference"]
    if rank is not None and (not isinstance(rank, int) or isinstance(rank, bool) or not -100000 <= rank <= 100000):
        raise RepositoryError("invalid_payload", "rank_difference must be null or an integer")
    integers = (
        ("half_life_hours", 1, 8760), ("min_target_samples", 1, 20), ("top_k", 1, 10),
    )
    for key, minimum, maximum in integers:
        value = raw[key]
        if not isinstance(value, int) or isinstance(value, bool) or not minimum <= value <= maximum:
            raise RepositoryError("invalid_payload", f"{key} must be an integer from {minimum} to {maximum}")
    owned = raw["owned_student_ids"]
    if not isinstance(owned, list) or any(not isinstance(item, str) or item not in _STUDENTS for item in owned):
        raise RepositoryError("invalid_payload", "owned_student_ids must contain canonical student IDs")
    if len(owned) != len(set(owned)):
        raise RepositoryError("invalid_payload", "owned_student_ids must not contain duplicates")
    return {
        "season": season,
        "opponent_identity_id": opponent,
        "public_signature": signature,
        "rank_difference": rank,
        "as_of": _time(raw["as_of"], "as_of").isoformat(),
        "half_life_hours": raw["half_life_hours"],
        "min_target_samples": raw["min_target_samples"],
        "top_k": raw["top_k"],
        "owned_student_ids": sorted(owned),
    }


def _slot_key(slot: dict[str, Any]) -> str:
    if slot.get("student_id"):
        return str(slot["student_id"])
    if slot.get("wildcard"):
        return "*"
    return "empty" if slot.get("state") == "empty" else "?"


def _deck_slots(deck: dict[str, Any]) -> list[tuple[str, str]]:
    return [
        *[(f"striker:{item['position']}", _slot_key(item)) for item in deck["strikers"]],
        *[(f"special:{item['position']}", _slot_key(item)) for item in deck["specials"]],
    ]


def _known_students(deck: dict[str, Any]) -> list[str]:
    return sorted({
        item["student_id"] for item in (*deck["strikers"], *deck["specials"])
        if item.get("student_id") is not None
    })


def _wilson_low(wins: int, losses: int) -> float | None:
    count = wins + losses
    if not count:
        return None
    rate = wins / count
    z = 1.959963984540054
    denominator = 1 + z * z / count
    center = (rate + z * z / (2 * count)) / denominator
    spread = z * math.sqrt(rate * (1 - rate) / count + z * z / (4 * count * count)) / denominator
    return max(0.0, center - spread)


def _age_hours(observed: datetime, as_of: datetime) -> float:
    return max(0.0, (as_of - observed).total_seconds() / 3600)


def _stage_predicate(stage: int, target: dict[str, Any]) -> Callable[[dict[str, Any]], bool]:
    opponent = target["opponent_identity_id"]
    signature = target["public_signature"]
    season = target["season"]
    rank = target["rank_difference"]
    return {
        1: lambda item: item["linked"] and item["opponent_identity_id"] == opponent and item["public_signature"] == signature and item["season"] == season,
        2: lambda item: item["linked"] and item["opponent_identity_id"] == opponent and item["public_signature"] == signature,
        3: lambda item: item["opponent_identity_id"] == opponent,
        4: lambda item: item["linked"] and item["season"] == season and item["public_signature"] == signature,
        5: lambda item: rank is not None and item["linked"] and item["rank_difference"] == rank and item["public_signature"] == signature,
        6: lambda item: item["linked"] and item["public_signature"] == signature,
    }[stage]


def _select_evidence(
    rows: list[dict[str, Any]], target: dict[str, Any], minimum: int,
) -> tuple[int | None, list[dict[str, Any]], list[dict[str, Any]]]:
    stage_rows = {stage: [item for item in rows if _stage_predicate(stage, target)(item)] for stage, _ in _STAGES}
    selected = next((stage for stage, _ in _STAGES if stage_rows[stage]), None)
    path: list[dict[str, Any]] = []
    if selected is None:
        return None, [], [
            {"stage": stage, "name": name, "eligible_snapshot_count": 0, "contributed_snapshot_count": 0, "weight_discount": 0.0}
            for stage, name in _STAGES
        ]
    included: dict[str, dict[str, Any]] = {}
    for stage, name in _STAGES:
        eligible = stage_rows[stage]
        contributed = 0
        discount = 0.0
        if stage >= selected and (not included or len(included) < minimum):
            discount = math.pow(0.5, stage - selected)
            for item in eligible:
                if item["snapshot_id"] not in included:
                    included[item["snapshot_id"]] = {**item, "stage": stage, "stage_weight": discount}
                    contributed += 1
        path.append({
            "stage": stage, "name": name, "eligible_snapshot_count": len(eligible),
            "contributed_snapshot_count": contributed, "weight_discount": discount,
        })
    return selected, list(included.values()), path


def _scenario_rows(
    evidence: list[dict[str, Any]], as_of: datetime, half_life: int,
    target_opponent_id: str,
) -> list[dict[str, Any]]:
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in evidence:
        recency = math.pow(0.5, _age_hours(item["observed_time"], as_of) / half_life)
        groups[item["defense_signature"]].append({**item, "weight": recency * item["stage_weight"]})
    total_weight = sum(item["weight"] for group in groups.values() for item in group)
    rows: list[dict[str, Any]] = []
    for signature, group in groups.items():
        weight = sum(item["weight"] for item in group)
        latest = max(group, key=lambda item: (item["observed_time"], item["snapshot_id"]))
        rows.append({
            "defense_signature": signature,
            "evidence_weight": weight,
            "evidence_weight_share": weight / total_weight,
            "snapshot_count": len(group),
            "target_opponent_snapshot_count": sum(
                item["opponent_identity_id"] == target_opponent_id for item in group
            ),
            "target_opponent_evidence_share": sum(
                item["weight"] for item in group
                if item["opponent_identity_id"] == target_opponent_id
            ) / weight,
            "distinct_opponent_count": len({item["opponent_identity_id"] for item in group}),
            "match_count": len({item["match_id"] for item in group if item["match_id"] is not None}),
            "last_confirmed_at": latest["observed_time"].isoformat(),
            "supporting_snapshot_ids": sorted(item["snapshot_id"] for item in group),
            "source_counts": dict(sorted(Counter(item["source"] for item in group).items())),
            "deck": latest["deck"],
        })
    rows.sort(key=lambda item: (-item["evidence_weight"], item["defense_signature"]))
    return rows


def _collect_evidence(state: dict[str, Any], as_of: datetime) -> tuple[list[dict[str, Any]], int]:
    scans = {item["scan_id"]: item for item in state["lobby_scans"]}
    candidates = {item["match_id"]: item for item in state["lobby_candidates"] if item["match_id"] is not None}
    matches = {item["match_id"]: item for item in state["matches"]}
    public_snapshots = {item["snapshot_id"]: item for item in state["snapshots"] if item["source"] == "lobby_scan"}
    rows: list[dict[str, Any]] = []
    undated = 0
    for snapshot in state["snapshots"]:
        if snapshot["source"] in {"lobby_scan", "prediction"} or snapshot["review_status"] != "confirmed":
            continue
        timestamp_value = snapshot.get("occurred_at") or snapshot.get("observed_at")
        if timestamp_value is None:
            undated += 1
            continue
        observed = _time(timestamp_value, "snapshot timestamp")
        if observed > as_of:
            continue
        candidate = candidates.get(snapshot["match_id"])
        scan = scans.get(candidate["scan_id"]) if candidate is not None else None
        match = matches.get(snapshot["match_id"])
        rows.append({
            "snapshot_id": snapshot["snapshot_id"], "match_id": snapshot["match_id"],
            "opponent_identity_id": snapshot["opponent_identity_id"],
            "season": snapshot["season"], "source": snapshot["source"],
            "observed_time": observed, "deck": snapshot["deck"],
            "defense_signature": deck_signature(snapshot["deck"]),
            "linked": candidate is not None and scan is not None,
            "public_signature": None if candidate is None else candidate["public_signature"],
            "rank_difference": None if candidate is None or scan is None else candidate["opponent_rank"] - scan["current_rank"],
            "public_deck": None if candidate is None else public_snapshots.get(candidate["snapshot_id"], {}).get("deck"),
            "result": None if match is None else match["result"],
        })
    rows.sort(key=lambda item: (item["observed_time"], item["snapshot_id"]))
    return rows, undated


def _hidden_slots(
    state: dict[str, Any], target: dict[str, Any], scenarios: list[dict[str, Any]], as_of: datetime,
) -> tuple[list[dict[str, Any]], int]:
    scans = {item["scan_id"]: item for item in state["lobby_scans"]}
    snapshots = {item["snapshot_id"]: item for item in state["snapshots"]}
    public_candidates = [
        item for item in state["lobby_candidates"]
        if item["opponent_identity_id"] == target["opponent_identity_id"]
        and item["public_signature"] == target["public_signature"]
        and item["scan_id"] in scans
        and _time(scans[item["scan_id"]]["observed_at"], "observed_at") <= as_of
    ]
    if not public_candidates:
        return [], 0
    latest = max(public_candidates, key=lambda item: (scans[item["scan_id"]]["observed_at"], item["candidate_id"]))
    public_deck = snapshots[latest["snapshot_id"]]["deck"]
    hidden = [position for position, value in _deck_slots(public_deck) if value in {"?", "*"}]
    known_count = 6 - len(hidden)
    rows: list[dict[str, Any]] = []
    for position in hidden:
        weights: dict[str, float] = defaultdict(float)
        counts: Counter[str] = Counter()
        for scenario in scenarios:
            value = dict(_deck_slots(scenario["deck"]))[position]
            weights[value] += scenario["evidence_weight"]
            counts[value] += scenario["snapshot_count"]
        total = sum(weights.values())
        candidates = [
            {"value": value, "evidence_weight_share": weight / total, "supporting_snapshot_count": counts[value]}
            for value, weight in weights.items()
        ]
        candidates.sort(key=lambda item: (-item["evidence_weight_share"], item["value"]))
        rows.append({"position": position, "candidates": candidates})
    return rows, known_count


def _recommendations(
    state: dict[str, Any], target: dict[str, Any], scenarios: list[dict[str, Any]],
    as_of: datetime, half_life: int, owned: set[str], top_k: int,
) -> list[dict[str, Any]]:
    scenario_signatures = {item["defense_signature"] for item in scenarios}
    candidates = {item["match_id"]: item for item in state["lobby_candidates"] if item["match_id"] is not None}
    rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for match in state["matches"]:
        timestamp_value = match.get("occurred_at") or match.get("observed_at")
        if match["kind"] != "attack" or match["source"] == "prediction" or timestamp_value is None:
            continue
        observed = _time(timestamp_value, "match timestamp")
        if observed > as_of or not _known_students(match["attack_deck"]):
            continue
        candidate = candidates.get(match["match_id"])
        defense = deck_signature(match["defense_deck"])
        exact = defense in scenario_signatures
        same_opponent = match["opponent_identity_id"] == target["opponent_identity_id"]
        same_public = candidate is not None and candidate["public_signature"] == target["public_signature"]
        if not (exact or same_opponent or same_public):
            continue
        rows[deck_signature(match["attack_deck"])].append({
            "match": match, "observed": observed, "exact": exact,
            "same_opponent": same_opponent, "same_public": same_public,
        })
    result: list[dict[str, Any]] = []
    source_quality = {"battle_result": 1.0, "manual": 0.8, "v6_import": 0.7, "community_report": 0.5}
    for signature, group in rows.items():
        wins = sum(item["match"]["result"] == "win" for item in group)
        losses = sum(item["match"]["result"] == "loss" for item in group)
        recencies = [math.pow(0.5, _age_hours(item["observed"], as_of) / half_life) for item in group]
        components = {
            "observed_outcome": _wilson_low(wins, losses) or 0.0,
            "recency": sum(recencies) / len(recencies),
            "sample": min(1.0, len(group) / 5),
            "opponent_specificity": max(
                sum(item["same_opponent"] for item in group), sum(item["exact"] for item in group),
            ) / len(group),
            "source_quality": sum(source_quality.get(item["match"]["source"], 0.4) for item in group) / len(group),
        }
        score = (
            0.45 * components["observed_outcome"] + 0.20 * components["recency"]
            + 0.15 * components["sample"] + 0.10 * components["opponent_specificity"]
            + 0.10 * components["source_quality"]
        )
        deck = group[0]["match"]["attack_deck"]
        required = _known_students(deck)
        missing = sorted(set(required) - owned)
        result.append({
            "attack_signature": signature, "score": score, "score_components": components,
            "observed_match_count": len(group), "wins": wins, "losses": losses,
            "observed_win_rate": wins / (wins + losses) if wins + losses else None,
            "wilson95_low": _wilson_low(wins, losses),
            "evidence_scope": {
                "exact_defense_count": sum(item["exact"] for item in group),
                "same_opponent_count": sum(item["same_opponent"] for item in group),
                "same_public_signature_count": sum(item["same_public"] for item in group),
            },
            "source_counts": dict(sorted(Counter(item["match"]["source"] for item in group).items())),
            "last_observed_at": max(item["observed"] for item in group).isoformat(),
            "required_student_ids": required, "missing_student_ids": missing,
            "all_known_students_owned": not missing, "deck": deck,
        })
    result.sort(key=lambda item: (-item["score"], -item["observed_match_count"], item["attack_signature"]))
    return result[:top_k]


def _backtest(rows: list[dict[str, Any]], target: dict[str, Any], minimum: int, top_k: int, half_life: int) -> dict[str, Any]:
    evaluated = top1 = topk_hits = 0
    brier_total = log_total = 0.0
    hidden_correct = hidden_total = 0
    for holdout in rows:
        if not holdout["linked"]:
            continue
        train = [item for item in rows if item["observed_time"] < holdout["observed_time"]]
        historical_target = {
            "season": holdout["season"], "opponent_identity_id": holdout["opponent_identity_id"],
            "public_signature": holdout["public_signature"], "rank_difference": holdout["rank_difference"],
        }
        _, evidence, _ = _select_evidence(train, historical_target, minimum)
        all_scenarios = _scenario_rows(
            evidence, holdout["observed_time"], half_life,
            holdout["opponent_identity_id"],
        )
        if not all_scenarios:
            continue
        evaluated += 1
        actual = holdout["defense_signature"]
        predicted = [item["defense_signature"] for item in all_scenarios[:top_k]]
        top1 += int(predicted[0] == actual)
        topk_hits += int(actual in predicted)
        probabilities = {item["defense_signature"]: item["evidence_weight_share"] for item in all_scenarios}
        universe = set(probabilities) | {actual}
        brier_total += sum((probabilities.get(item, 0.0) - int(item == actual)) ** 2 for item in universe)
        log_total += -math.log(max(probabilities.get(actual, 0.0), 1e-15))
        if holdout["public_deck"] is not None:
            public_slots = dict(_deck_slots(holdout["public_deck"]))
            actual_slots = dict(_deck_slots(holdout["deck"]))
            predicted_slots = dict(_deck_slots(all_scenarios[0]["deck"]))
            for position, public_value in public_slots.items():
                if public_value in {"?", "*"}:
                    hidden_total += 1
                    hidden_correct += int(predicted_slots[position] == actual_slots[position])
    metrics = {
        "evaluated_case_count": evaluated,
        "top1_accuracy": top1 / evaluated if evaluated else None,
        "topk_accuracy": topk_hits / evaluated if evaluated else None,
        "hidden_slot_accuracy": hidden_correct / hidden_total if hidden_total else None,
        "brier_score": brier_total / evaluated if evaluated else None,
        "log_loss": log_total / evaluated if evaluated else None,
        "time_ordered": True, "same_snapshot_train_test_overlap": False,
    }
    metrics["calibration_gate_passed"] = bool(
        evaluated >= 20 and metrics["top1_accuracy"] is not None and metrics["top1_accuracy"] >= 0.5
        and metrics["brier_score"] is not None and metrics["brier_score"] <= 0.5
    )
    return metrics


class TacticalRecommendationV2:
    @staticmethod
    def query(state: dict[str, Any], raw_filters: object) -> dict[str, Any]:
        filters = canonical_recommend_filters(raw_filters)
        as_of = _time(filters["as_of"], "as_of")
        evidence_rows, undated = _collect_evidence(state, as_of)
        selected_stage, evidence, path = _select_evidence(evidence_rows, filters, filters["min_target_samples"])
        all_scenarios = _scenario_rows(
            evidence, as_of, filters["half_life_hours"],
            filters["opponent_identity_id"],
        )
        scenarios = all_scenarios[:filters["top_k"]]
        hidden, known_slots = _hidden_slots(state, filters, scenarios, as_of) if scenarios else ([], 0)
        top_share = scenarios[0]["evidence_weight_share"] if scenarios else None
        distinct = len(all_scenarios)
        if not scenarios:
            confidence = "unavailable"
            ambiguity = "unavailable"
        else:
            confidence = "high" if len(evidence) >= 5 and top_share >= 0.7 else "medium" if len(evidence) >= 2 else "low"
            ambiguity = "low" if top_share >= 0.75 else "medium" if top_share >= 0.5 else "high"
        validation = _backtest(
            evidence_rows, filters, filters["min_target_samples"], filters["top_k"], filters["half_life_hours"],
        )
        recommendations = _recommendations(
            state, filters, scenarios, as_of, filters["half_life_hours"],
            set(filters["owned_student_ids"]), filters["top_k"],
        ) if scenarios else []
        return {
            "version": 2, "filters": filters,
            "availability": {
                "status": "available" if scenarios else "unavailable",
                "reason": None if scenarios else "no_observed_full_defense_evidence",
            },
            "selected_stage": selected_stage,
            "fallback_path": path,
            "evidence_summary": {
                "included_snapshot_count": len(evidence),
                "distinct_opponent_count": len({item["opponent_identity_id"] for item in evidence}),
                "excluded_undated_snapshot_count": undated,
            },
            "scenarios": scenarios,
            "scenario_total": distinct,
            "hidden_slots": hidden,
            "ambiguity": {
                "grade": ambiguity, "variant_defense_possible": distinct > 1,
                "top_evidence_weight_share": top_share, "public_known_slot_count": known_slots,
            },
            "confidence": {
                "grade": confidence,
                "calibration_gate_passed": validation["calibration_gate_passed"],
                "precise_probability_available": validation["calibration_gate_passed"],
            },
            "recommendations": recommendations,
            "recommendation_total": len(recommendations),
            "validation": validation,
            "terminology": {
                "scenario_share_label": "evidence_weight_share_not_probability",
                "win_rate_label": "observed_win_rate",
                "warning": "Scenarios are observed full defenses, not generated slot combinations or guaranteed counters.",
            },
        }
