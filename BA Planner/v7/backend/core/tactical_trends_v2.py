from __future__ import annotations

from collections import defaultdict
from datetime import datetime
import math
from typing import Any, Callable

from core.repository_store import RepositoryError
from core.tactical_stats_v2 import canonical_stats_filters, deck_signature


_FILTER_KEYS = {
    "season", "sources", "opponent_identity_id", "public_signature",
    "date_from", "date_to", "rank_difference_min", "rank_difference_max",
    "as_of", "stale_after_hours", "limit",
}


def _time(value: object, label: str, *, required: bool = False) -> datetime | None:
    if value is None and not required:
        return None
    if not isinstance(value, str) or not value.strip():
        raise RepositoryError("invalid_payload", f"{label} must be an ISO timestamp")
    try:
        result = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError as error:
        raise RepositoryError("invalid_payload", f"{label} must be an ISO timestamp") from error
    if result.tzinfo is None:
        raise RepositoryError("invalid_payload", f"{label} must include a timezone")
    return result


def canonical_trend_filters(raw: object) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != _FILTER_KEYS:
        raise RepositoryError("invalid_payload", f"filters must contain exactly {sorted(_FILTER_KEYS)}")
    base = canonical_stats_filters({
        key: raw[key] for key in (
            "season", "sources", "opponent_identity_id", "public_signature",
            "date_from", "date_to", "limit",
        )
    })
    as_of = _time(raw["as_of"], "as_of", required=True)
    stale = raw["stale_after_hours"]
    rank_min = raw["rank_difference_min"]
    rank_max = raw["rank_difference_max"]
    if not isinstance(stale, int) or isinstance(stale, bool) or not 1 <= stale <= 8760:
        raise RepositoryError("invalid_payload", "stale_after_hours must be an integer from 1 to 8760")
    for value, label in ((rank_min, "rank_difference_min"), (rank_max, "rank_difference_max")):
        if value is not None and (
            not isinstance(value, int) or isinstance(value, bool) or not -100000 <= value <= 100000
        ):
            raise RepositoryError("invalid_payload", f"{label} must be null or an integer")
    if rank_min is not None and rank_max is not None and rank_min > rank_max:
        raise RepositoryError("invalid_payload", "rank_difference_min must not exceed rank_difference_max")
    return {
        **base,
        "rank_difference_min": rank_min,
        "rank_difference_max": rank_max,
        "as_of": as_of.isoformat(),
        "stale_after_hours": stale,
    }


def _in_period(value: object, start: datetime | None, end: datetime | None) -> bool:
    if start is None and end is None:
        return True
    parsed = _time(value, "observation timestamp")
    return parsed is not None and (start is None or parsed >= start) and (end is None or parsed <= end)


def _rate(numerator: int, denominator: int) -> float | None:
    return numerator / denominator if denominator else None


def _hours(start: datetime, end: datetime) -> float:
    return max(0.0, (end - start).total_seconds() / 3600)


def _metrics(items: list[dict[str, Any]], candidate_matches: dict[str, dict[str, Any]]) -> dict[str, Any]:
    selected = sum(item["selected_at"] is not None for item in items)
    battles = [candidate_matches[item["candidate_id"]] for item in items if item["candidate_id"] in candidate_matches]
    results = [item for item in battles if item["result"] in {"win", "loss"}]
    wins = sum(item["result"] == "win" for item in battles)
    losses = sum(item["result"] == "loss" for item in battles)
    return {
        "exposure_count": len(items),
        "selection_count": selected,
        "selection_rate": _rate(selected, len(items)),
        "battle_count": len(battles),
        "result_count": len(results),
        "wins": wins,
        "losses": losses,
        "observed_win_rate": _rate(wins, len(results)),
    }


def _breakdown(
    candidates: list[dict[str, Any]],
    candidate_matches: dict[str, dict[str, Any]],
    key: Callable[[dict[str, Any]], object],
    field: str,
    total_exposures: int,
) -> list[dict[str, Any]]:
    groups: dict[object, list[dict[str, Any]]] = defaultdict(list)
    for item in candidates:
        groups[key(item)].append(item)
    rows = [
        {
            field: group_key,
            **_metrics(group, candidate_matches),
            "exposure_rate": _rate(len(group), total_exposures),
        }
        for group_key, group in groups.items()
    ]
    rows.sort(key=lambda item: (-item["exposure_count"], str(item[field])))
    return rows


class TacticalTrendsV2:
    @staticmethod
    def query(state: dict[str, Any], raw_filters: object) -> dict[str, Any]:
        filters = canonical_trend_filters(raw_filters)
        start = _time(filters["date_from"], "date_from")
        end = _time(filters["date_to"], "date_to")
        as_of = _time(filters["as_of"], "as_of", required=True)
        effective_end = as_of if end is None or as_of < end else end
        sources = set(filters["sources"])
        season = filters["season"]
        opponent_filter = filters["opponent_identity_id"]
        signature_filter = filters["public_signature"]
        rank_min = filters["rank_difference_min"]
        rank_max = filters["rank_difference_max"]
        limit = filters["limit"]

        unique_scans: dict[str, dict[str, Any]] = {}
        for scan in state["lobby_scans"]:
            if (season is not None and scan["season"] != season) or (sources and "lobby_scan" not in sources):
                continue
            if not _in_period(scan["observed_at"], start, effective_end):
                continue
            previous = unique_scans.get(scan["refresh_generation"])
            if previous is None or (scan["observed_at"], scan["scan_id"]) < (previous["observed_at"], previous["scan_id"]):
                unique_scans[scan["refresh_generation"]] = scan
        scans = {item["scan_id"]: item for item in unique_scans.values()}
        candidates: list[dict[str, Any]] = []
        for item in state["lobby_candidates"]:
            scan = scans.get(item["scan_id"])
            if scan is None:
                continue
            difference = item["opponent_rank"] - scan["current_rank"]
            if opponent_filter is not None and item["opponent_identity_id"] != opponent_filter:
                continue
            if signature_filter is not None and item["public_signature"] != signature_filter:
                continue
            if rank_min is not None and difference < rank_min:
                continue
            if rank_max is not None and difference > rank_max:
                continue
            candidates.append({**item, "rank_difference": difference})

        candidate_by_id = {item["candidate_id"]: item for item in candidates}
        candidate_by_match = {item["match_id"]: item for item in candidates if item["match_id"] is not None}
        def match_in_period(item: dict[str, Any]) -> bool:
            timestamp = item.get("occurred_at") or item.get("observed_at")
            if timestamp is None:
                return start is None and end is None
            return _in_period(timestamp, start, effective_end)
        matches = {
            item["match_id"]: item for item in state["matches"]
            if item["kind"] == "attack"
            and item["source"] != "prediction"
            and item["match_id"] in candidate_by_match
            and (season is None or item["season"] == season)
            and (not sources or item["source"] in sources)
            and match_in_period(item)
        }
        candidate_matches = {
            candidate_by_match[match_id]["candidate_id"]: match for match_id, match in matches.items()
        }
        filtered_scan_ids = (
            {item["scan_id"] for item in candidates}
            if any(value is not None for value in (opponent_filter, signature_filter, rank_min, rank_max))
            else set(scans)
        )
        ordered_scans = sorted(
            (scans[item] for item in filtered_scan_ids),
            key=lambda item: (_time(item["observed_at"], "observed_at"), item["scan_id"]),
        )

        observations: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for item in candidates:
            scan = scans[item["scan_id"]]
            observations[item["opponent_identity_id"]].append({
                "observed_at": scan["observed_at"],
                "public_signature": item["public_signature"],
                "snapshot_id": item["snapshot_id"],
                "candidate_id": item["candidate_id"],
            })
        public_changes: list[dict[str, Any]] = []
        public_runs: list[dict[str, Any]] = []
        public_reuses: list[dict[str, Any]] = []
        latest_public: dict[str, dict[str, Any]] = {}
        latest_signature_observation: dict[tuple[str, str], datetime] = {}
        latest_signature_change: dict[tuple[str, str], datetime] = {}
        for opponent_id, rows in observations.items():
            rows.sort(key=lambda item: (_time(item["observed_at"], "observed_at"), item["snapshot_id"]))
            latest_public[opponent_id] = rows[-1]
            seen_runs: dict[str, dict[str, Any]] = {}
            run_start = 0
            for index, row in enumerate(rows):
                timestamp = _time(row["observed_at"], "observed_at", required=True)
                latest_signature_observation[(opponent_id, row["public_signature"])] = timestamp
                if index and rows[index - 1]["public_signature"] != row["public_signature"]:
                    previous = rows[index - 1]
                    change = {
                        "opponent_identity_id": opponent_id,
                        "from_public_signature": previous["public_signature"],
                        "to_public_signature": row["public_signature"],
                        "interval_start": previous["observed_at"],
                        "interval_end": row["observed_at"],
                    }
                    public_changes.append(change)
                    latest_signature_change[(opponent_id, row["public_signature"])] = timestamp
                    finished_rows = rows[run_start:index]
                    finished = {
                        "opponent_identity_id": opponent_id,
                        "public_signature": previous["public_signature"],
                        "first_observed_at": finished_rows[0]["observed_at"],
                        "last_observed_at": finished_rows[-1]["observed_at"],
                        "observation_count": len(finished_rows),
                        "observed_duration_hours": _hours(
                            _time(finished_rows[0]["observed_at"], "observed_at", required=True),
                            _time(finished_rows[-1]["observed_at"], "observed_at", required=True),
                        ),
                        "ended_by_change": True,
                    }
                    public_runs.append(finished)
                    seen_runs[finished["public_signature"]] = finished
                    if row["public_signature"] in seen_runs:
                        prior = seen_runs[row["public_signature"]]
                        public_reuses.append({
                            "opponent_identity_id": opponent_id,
                            "public_signature": row["public_signature"],
                            "previous_last_observed_at": prior["last_observed_at"],
                            "reused_at": row["observed_at"],
                        })
                    run_start = index
            active = rows[run_start:]
            public_runs.append({
                "opponent_identity_id": opponent_id,
                "public_signature": active[0]["public_signature"],
                "first_observed_at": active[0]["observed_at"],
                "last_observed_at": active[-1]["observed_at"],
                "observation_count": len(active),
                "observed_duration_hours": _hours(
                    _time(active[0]["observed_at"], "observed_at", required=True),
                    _time(active[-1]["observed_at"], "observed_at", required=True),
                ),
                "ended_by_change": False,
            })

        full_by_opponent: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for snapshot in state["snapshots"]:
            candidate = candidate_by_match.get(snapshot["match_id"])
            if snapshot["source"] == "lobby_scan" or candidate is None or snapshot["match_id"] not in matches:
                continue
            timestamp_value = snapshot.get("occurred_at") or snapshot.get("observed_at")
            timestamp = _time(timestamp_value, "snapshot timestamp")
            if timestamp is None:
                continue
            full_by_opponent[candidate["opponent_identity_id"]].append({
                "observed_at": timestamp.isoformat(),
                "public_signature": candidate["public_signature"],
                "full_defense_signature": deck_signature(snapshot["deck"]),
                "snapshot_id": snapshot["snapshot_id"],
            })
        full_changes: list[dict[str, Any]] = []
        for opponent_id, rows in full_by_opponent.items():
            rows.sort(key=lambda item: (item["observed_at"], item["snapshot_id"]))
            for previous, current in zip(rows, rows[1:]):
                previous_time = _time(previous["observed_at"], "snapshot timestamp", required=True)
                current_time = _time(current["observed_at"], "snapshot timestamp", required=True)
                public_changed_between = any(
                    item["opponent_identity_id"] == opponent_id
                    and previous_time < _time(item["interval_end"], "change interval", required=True) <= current_time
                    for item in public_changes
                )
                if (
                    previous["public_signature"] == current["public_signature"]
                    and previous["full_defense_signature"] != current["full_defense_signature"]
                    and not public_changed_between
                ):
                    full_changes.append({
                        "opponent_identity_id": opponent_id,
                        "public_signature": current["public_signature"],
                        "from_full_defense_signature": previous["full_defense_signature"],
                        "to_full_defense_signature": current["full_defense_signature"],
                        "interval_start": previous["observed_at"],
                        "interval_end": current["observed_at"],
                    })

        scan_candidates: dict[str, set[str]] = defaultdict(set)
        for item in candidates:
            scan_candidates[item["scan_id"]].add(item["opponent_identity_id"])
        retained = eligible = 0
        retention_by_opponent: dict[str, list[int]] = defaultdict(lambda: [0, 0])
        scan_groups: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
        for scan in ordered_scans:
            scan_groups[(scan["season"], scan["map"])].append(scan)
        for group in scan_groups.values():
            for previous, current in zip(group, group[1:]):
                prior_ids = scan_candidates[previous["scan_id"]]
                current_ids = scan_candidates[current["scan_id"]]
                eligible += len(prior_ids)
                retained += len(prior_ids & current_ids)
                for opponent_id in prior_ids:
                    retention_by_opponent[opponent_id][0] += 1
                    retention_by_opponent[opponent_id][1] += int(opponent_id in current_ids)

        freshness: list[dict[str, Any]] = []
        evidence: dict[tuple[str, str, str], list[dict[str, Any]]] = defaultdict(list)
        for candidate_id, match in candidate_matches.items():
            candidate = candidate_by_id[candidate_id]
            occurred = _time(match.get("occurred_at") or match.get("observed_at"), "match timestamp")
            if occurred is None:
                continue
            evidence[(
                candidate["opponent_identity_id"], candidate["public_signature"],
                deck_signature(match["attack_deck"]),
            )].append({"time": occurred, "result": match["result"]})
        for (opponent_id, signature, attack_signature), rows in evidence.items():
            rows.sort(key=lambda item: item["time"])
            last = rows[-1]["time"]
            latest_observed = latest_signature_observation[(opponent_id, signature)]
            change = latest_signature_change.get((opponent_id, signature))
            age = _hours(last, as_of)
            verified_public = last >= latest_observed
            verified_change = None if change is None else last >= change
            freshness.append({
                "opponent_identity_id": opponent_id,
                "public_signature": signature,
                "attack_signature": attack_signature,
                "is_current_public_signature": latest_public[opponent_id]["public_signature"] == signature,
                "last_battle_at": last.isoformat(),
                "last_success_at": next((item["time"].isoformat() for item in reversed(rows) if item["result"] == "win"), None),
                "last_failure_at": next((item["time"].isoformat() for item in reversed(rows) if item["result"] == "loss"), None),
                "latest_public_observed_at": latest_observed.isoformat(),
                "latest_public_change_at": None if change is None else change.isoformat(),
                "verified_after_latest_public": verified_public,
                "verified_after_latest_change": verified_change,
                "age_hours": age,
                "freshness_weight": math.pow(0.5, age / filters["stale_after_hours"]),
                "stale": age > filters["stale_after_hours"] or not verified_public or verified_change is False,
            })

        total_exposures = len(candidates)
        funnel = _metrics(candidates, candidate_matches)
        funnel["refresh_count"] = len(filtered_scan_ids)
        funnel["opponent_count"] = len({item["opponent_identity_id"] for item in candidates})
        funnel["exposures_per_refresh"] = _rate(total_exposures, len(filtered_scan_ids))
        retention_rows = [
            {
                "opponent_identity_id": opponent_id,
                "eligible_transition_count": counts[0],
                "retained_transition_count": counts[1],
                "retention_rate": _rate(counts[1], counts[0]),
            }
            for opponent_id, counts in retention_by_opponent.items()
        ]
        retention_rows.sort(key=lambda item: (-item["eligible_transition_count"], item["opponent_identity_id"]))
        for rows in (public_changes, public_runs, public_reuses, full_changes):
            rows.sort(key=lambda item: (item["opponent_identity_id"], item.get("interval_end") or item.get("reused_at") or item["first_observed_at"]))
        freshness.sort(key=lambda item: (item["stale"], -item["age_hours"], item["opponent_identity_id"], item["attack_signature"]))

        return {
            "version": 2,
            "filters": filters,
            "funnel": funnel,
            "exposure": {
                "by_opponent": _breakdown(candidates, candidate_matches, lambda item: item["opponent_identity_id"], "opponent_identity_id", total_exposures)[:limit],
                "by_public_signature": _breakdown(candidates, candidate_matches, lambda item: item["public_signature"], "public_signature", total_exposures)[:limit],
                "by_rank_difference": _breakdown(candidates, candidate_matches, lambda item: item["rank_difference"], "rank_difference", total_exposures)[:limit],
                "retention": {
                    "eligible_transition_count": eligible,
                    "retained_transition_count": retained,
                    "retention_rate": _rate(retained, eligible),
                    "by_opponent": retention_rows[:limit],
                },
            },
            "changes": {
                "public_signature": public_changes[:limit],
                "public_signature_total": len(public_changes),
                "public_runs": public_runs[:limit],
                "public_run_total": len(public_runs),
                "public_reuse": public_reuses[:limit],
                "public_reuse_total": len(public_reuses),
                "full_defense_while_public_stable": full_changes[:limit],
                "full_defense_change_total": len(full_changes),
            },
            "freshness": freshness[:limit],
            "freshness_total": len(freshness),
            "terminology": {
                "exposure_rate_label": "observed_exposure_rate",
                "selection_rate_label": "observed_selection_rate",
                "win_rate_label": "observed_win_rate",
                "population_warning": "Exposure describes choices shown to this user, not server-wide meta share.",
            },
        }
