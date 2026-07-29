from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timezone
from itertools import combinations
import math
import re
from typing import Any, Iterable

from core.repository_store import RepositoryError


FILTER_FIELDS = {
    "season", "sources", "opponent_identity_id", "public_signature",
    "date_from", "date_to", "limit",
}
SOURCES = {"v6_import", "manual", "lobby_scan", "battle_result", "community_report", "prediction"}


def _timestamp(value: object, label: str) -> datetime | None:
    if value is None:
        return None
    if not isinstance(value, str) or not value:
        raise RepositoryError("invalid_payload", f"{label} must be an ISO timestamp or null")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise RepositoryError("invalid_payload", f"{label} must be an ISO timestamp or null") from error
    if parsed.tzinfo is None:
        raise RepositoryError("invalid_payload", f"{label} must include a timezone")
    return parsed.astimezone(timezone.utc)


def canonical_stats_filters(value: object) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != FILTER_FIELDS:
        raise RepositoryError("invalid_payload", f"filters must contain exactly {sorted(FILTER_FIELDS)}")
    season = value["season"]
    if season is not None and not isinstance(season, str):
        raise RepositoryError("invalid_payload", "season must be a string or null")
    sources = value["sources"]
    if not isinstance(sources, list) or any(not isinstance(item, str) or not item for item in sources):
        raise RepositoryError("invalid_payload", "sources must be a string list")
    if len(sources) != len(set(sources)):
        raise RepositoryError("invalid_payload", "sources must not contain duplicates")
    if any(item not in SOURCES for item in sources):
        raise RepositoryError("invalid_payload", "sources contains an unsupported provenance")
    opponent = value["opponent_identity_id"]
    signature = value["public_signature"]
    for item, label in ((opponent, "opponent_identity_id"), (signature, "public_signature")):
        if item is not None and (not isinstance(item, str) or not item):
            raise RepositoryError("invalid_payload", f"{label} must be a non-empty string or null")
    if opponent is not None and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", opponent) is None:
        raise RepositoryError("invalid_payload", "opponent_identity_id is not a stable record ID")
    date_from = _timestamp(value["date_from"], "date_from")
    date_to = _timestamp(value["date_to"], "date_to")
    if date_from is not None and date_to is not None and date_from > date_to:
        raise RepositoryError("invalid_payload", "date_from must not be after date_to")
    limit = value["limit"]
    if not isinstance(limit, int) or isinstance(limit, bool) or not 1 <= limit <= 100:
        raise RepositoryError("invalid_payload", "limit must be an integer from 1 to 100")
    return {
        "season": season, "sources": sorted(sources),
        "opponent_identity_id": opponent, "public_signature": signature,
        "date_from": value["date_from"], "date_to": value["date_to"], "limit": limit,
    }


def _in_period(value: object, date_from: datetime | None, date_to: datetime | None) -> bool:
    if date_from is None and date_to is None:
        return True
    parsed = _timestamp(value, "record timestamp")
    if parsed is None:
        return False
    return (date_from is None or parsed >= date_from) and (date_to is None or parsed <= date_to)


def _slot_key(slot: dict[str, Any]) -> str:
    if slot.get("student_id"):
        return str(slot["student_id"])
    if slot.get("wildcard"):
        return "*"
    return "empty" if slot.get("state") == "empty" else "?"


def deck_signature(deck: dict[str, Any]) -> str:
    return ",".join(_slot_key(item) for item in deck["strikers"]) + "|" + ",".join(
        _slot_key(item) for item in deck["specials"]
    )


def _result(count: int, wins: int, losses: int) -> dict[str, Any]:
    observed = wins + losses
    if observed == 0:
        return {"count": count, "wins": wins, "losses": losses, "observed_win_rate": None, "wilson95_low": None, "wilson95_high": None}
    rate = wins / observed
    z = 1.959963984540054
    denominator = 1 + z * z / observed
    center = (rate + z * z / (2 * observed)) / denominator
    spread = z * math.sqrt(rate * (1 - rate) / observed + z * z / (4 * observed * observed)) / denominator
    return {
        "count": count, "wins": wins, "losses": losses,
        "observed_win_rate": rate,
        "wilson95_low": max(0.0, center - spread),
        "wilson95_high": min(1.0, center + spread),
    }


def _aggregate_patterns(matches: Iterable[dict[str, Any]], limit: int) -> dict[str, Any]:
    exact: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0])
    strikers: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0])
    specials: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0])
    cores: dict[tuple[int, str], list[int]] = defaultdict(lambda: [0, 0, 0])
    deck_parts: dict[str, list[str]] = {}
    for match in matches:
        signature = deck_signature(match["attack_deck"])
        parts = signature.replace("|", ",").split(",")
        deck_parts[signature] = parts
        win = int(match.get("result") == "win")
        loss = int(match.get("result") == "loss")
        for target, key in (
            (exact, signature),
            (strikers, signature.split("|", 1)[0]),
            (specials, signature.split("|", 1)[1]),
        ):
            target[key][0] += 1
            target[key][1] += win
            target[key][2] += loss
        ids = sorted({part for part in parts if part not in {"?", "*", "empty"}})
        for size in (3, 4):
            for core in combinations(ids, size):
                bucket = cores[(size, ",".join(core))]
                bucket[0] += 1
                bucket[1] += win
                bucket[2] += loss

    def ranked(values: dict[str, list[int]], pattern_type: str) -> tuple[list[dict[str, Any]], int]:
        result = [
            {"pattern_type": pattern_type, "key": key, **_result(*counts)}
            for key, counts in values.items()
        ]
        result.sort(key=lambda item: (-item["count"], item["key"]))
        return result[:limit], len(result)

    core_values = {f"{size}:{key}": counts for (size, key), counts in cores.items()}
    variant_families: dict[str, set[str]] = defaultdict(set)
    variant_counts: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0])
    for signature, parts in deck_parts.items():
        counts = exact[signature]
        for position in range(6):
            key_parts = list(parts)
            key_parts[position] = "_"
            key = f"{position}:" + ",".join(key_parts)
            variant_families[key].add(signature)
            bucket = variant_counts[key]
            for index in range(3):
                bucket[index] += counts[index]
    variant_counts = {
        key: counts for key, counts in variant_counts.items()
        if len(variant_families[key]) >= 2
    }
    exact_rows, exact_total = ranked(exact, "exact")
    striker_rows, striker_total = ranked(strikers, "strikers")
    special_rows, special_total = ranked(specials, "specials")
    core_rows, core_total = ranked(core_values, "core")
    variant_rows, variant_total = ranked(variant_counts, "one_slot_variant")
    return {
        "exact": exact_rows, "exact_total": exact_total,
        "strikers": striker_rows, "strikers_total": striker_total,
        "specials": special_rows, "specials_total": special_total,
        "cores": core_rows, "cores_total": core_total,
        "one_slot_variants": variant_rows, "one_slot_variants_total": variant_total,
    }


class TacticalStatisticsV2:
    @staticmethod
    def query(state: dict[str, Any], raw_filters: object) -> dict[str, Any]:
        filters = canonical_stats_filters(raw_filters)
        date_from = _timestamp(filters["date_from"], "date_from")
        date_to = _timestamp(filters["date_to"], "date_to")
        sources = set(filters["sources"])
        season = filters["season"]
        opponent_filter = filters["opponent_identity_id"]
        signature_filter = filters["public_signature"]
        limit = filters["limit"]

        scans = {
            item["scan_id"]: item for item in state["lobby_scans"]
            if (season is None or item["season"] == season)
            and (not sources or "lobby_scan" in sources)
            and _in_period(item["observed_at"], date_from, date_to)
        }
        candidates = [
            item for item in state["lobby_candidates"]
            if item["scan_id"] in scans
            and (opponent_filter is None or item["opponent_identity_id"] == opponent_filter)
            and (signature_filter is None or item["public_signature"] == signature_filter)
        ]
        candidate_by_match = {
            item["match_id"]: item for item in candidates if item["match_id"] is not None
        }
        matches = [
            item for item in state["matches"]
            if (season is None or item["season"] == season)
            and item["source"] != "prediction"
            and (not sources or item["source"] in sources)
            and (opponent_filter is None or item["opponent_identity_id"] == opponent_filter)
            and _in_period(item.get("occurred_at") or item.get("observed_at"), date_from, date_to)
            and (signature_filter is None or item["match_id"] in candidate_by_match)
        ]
        matches_by_id = {item["match_id"]: item for item in matches}
        full_snapshots = [
            item for item in state["snapshots"]
            if item["source"] != "lobby_scan"
            and item["match_id"] in matches_by_id
            and (not sources or item["source"] in sources)
        ]
        identities = {item["identity_id"]: item for item in state["opponents"]}

        signature_groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for candidate in candidates:
            signature_groups[candidate["public_signature"]].append(candidate)
        signature_rows: list[dict[str, Any]] = []
        for signature, group in signature_groups.items():
            linked = [matches_by_id[item["match_id"]] for item in group if item["match_id"] in matches_by_id]
            attack_counts: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0])
            source_counts = Counter({"lobby_scan": len(group)})
            source_counts.update(item["source"] for item in linked)
            defense_counts = Counter(
                deck_signature(snapshot["deck"])
                for snapshot in full_snapshots
                if snapshot["match_id"] in {item["match_id"] for item in linked}
            )
            for match in linked:
                key = deck_signature(match["attack_deck"])
                attack_counts[key][0] += 1
                attack_counts[key][1] += int(match["result"] == "win")
                attack_counts[key][2] += int(match["result"] == "loss")
            attacks = [{"signature": key, **_result(*counts)} for key, counts in attack_counts.items()]
            attacks.sort(key=lambda item: (-item["count"], item["signature"]))
            defenses = [{"signature": key, "count": count} for key, count in defense_counts.items()]
            defenses.sort(key=lambda item: (-item["count"], item["signature"]))
            wins = sum(item["result"] == "win" for item in linked)
            losses = sum(item["result"] == "loss" for item in linked)
            signature_rows.append({
                "public_signature": signature,
                "exposure_count": len(group),
                "opponent_count": len({item["opponent_identity_id"] for item in group}),
                "selected_count": sum(item["selected_at"] is not None for item in group),
                "linked_match_count": len(linked),
                **{key: value for key, value in _result(len(linked), wins, losses).items() if key != "count"},
                "source_counts": dict(sorted(source_counts.items())),
                "attack_decks": attacks[:limit], "attack_deck_total": len(attacks),
                "full_defenses": defenses[:limit], "full_defense_total": len(defenses),
            })
        signature_rows.sort(key=lambda item: (-item["exposure_count"], item["public_signature"]))

        opponent_ids = {item["opponent_identity_id"] for item in candidates} | {item["opponent_identity_id"] for item in matches}
        opponent_rows: list[dict[str, Any]] = []
        for identity_id in opponent_ids:
            exposed = [item for item in candidates if item["opponent_identity_id"] == identity_id]
            opponent_matches = [item for item in matches if item["opponent_identity_id"] == identity_id]
            public = max(exposed, key=lambda item: scans[item["scan_id"]]["observed_at"], default=None)
            complete = max(
                (
                    item for item in full_snapshots
                    if item["opponent_identity_id"] == identity_id
                    and (item.get("occurred_at") or item.get("observed_at")) is not None
                ),
                key=lambda item: _timestamp(
                    item.get("occurred_at") or item.get("observed_at"),
                    "snapshot timestamp",
                ),
                default=None,
            )
            attack_matches = [item for item in opponent_matches if item["kind"] == "attack"]
            defense_matches = [item for item in opponent_matches if item["kind"] == "defense"]
            attack_wins = sum(item["result"] == "win" for item in attack_matches)
            attack_losses = sum(item["result"] == "loss" for item in attack_matches)
            defense_wins = sum(item["result"] == "win" for item in defense_matches)
            defense_losses = sum(item["result"] == "loss" for item in defense_matches)
            opponent_rows.append({
                "opponent_identity_id": identity_id,
                "display_name": identities.get(identity_id, {}).get("current_display_name", ""),
                "exposure_count": len(exposed), "selected_count": sum(item["selected_at"] is not None for item in exposed),
                "match_count": len(opponent_matches),
                "attack_results": _result(len(attack_matches), attack_wins, attack_losses),
                "defense_results": _result(len(defense_matches), defense_wins, defense_losses),
                "latest_public": None if public is None else {
                    "public_signature": public["public_signature"],
                    "observed_at": scans[public["scan_id"]]["observed_at"],
                    "snapshot_id": public["snapshot_id"],
                },
                "latest_full": None if complete is None else {
                    "deck_signature": deck_signature(complete["deck"]),
                    "observed_at": complete.get("occurred_at") or complete.get("observed_at"),
                    "snapshot_id": complete["snapshot_id"],
                },
            })
        opponent_rows.sort(key=lambda item: (-item["exposure_count"], -item["match_count"], item["opponent_identity_id"]))

        source_counts: Counter[str] = Counter()
        if candidates:
            source_counts["lobby_scan"] = len(candidates)
        source_counts.update(item["source"] for item in matches)
        dated = sum((item.get("occurred_at") or item.get("observed_at")) is not None for item in matches)
        fingerprints = Counter(
            (
                item["kind"], item["opponent_identity_id"], item.get("occurred_at"), item["result"],
                deck_signature(item["attack_deck"]), deck_signature(item["defense_deck"]), item["source"],
            )
            for item in matches
        )
        attack_matches = [item for item in matches if item["kind"] == "attack"]
        defense_matches = [item for item in matches if item["kind"] == "defense"]
        filtered_refresh_count = (
            len({item["scan_id"] for item in candidates})
            if opponent_filter is not None or signature_filter is not None
            else len(scans)
        )
        result = {
            "version": 2,
            "filters": filters,
            "population": {
                "refresh_count": filtered_refresh_count, "exposure_count": len(candidates),
                "selected_count": sum(item["selected_at"] is not None for item in candidates),
                "linked_match_count": len(set(candidate_by_match) & set(matches_by_id)),
                "match_count": len(matches), "attack_match_count": len(attack_matches),
                "defense_match_count": len(defense_matches), "opponent_count": len(opponent_ids),
            },
            "public_signatures": signature_rows[:limit],
            "public_signature_total": len(signature_rows),
            "opponents": opponent_rows[:limit], "opponent_total": len(opponent_rows),
            "attack_patterns": _aggregate_patterns(attack_matches, limit),
            "quality": {
                "dated_match_count": dated, "undated_match_count": len(matches) - dated,
                "date_coverage": dated / len(matches) if matches else None,
                "distinct_opponent_count": len({item["opponent_identity_id"] for item in matches}),
                "match_kind_counts": {"attack": len(attack_matches), "defense": len(defense_matches)},
                "source_counts": dict(sorted(source_counts.items())),
                "suspected_duplicate_count": sum(count - 1 for count in fingerprints.values() if count > 1),
            },
            "terminology": {
                "rate_label": "observed_win_rate",
                "population_warning": "Observed attack records are not the population win rate or defense success rate.",
            },
        }
        return result
