from __future__ import annotations

from collections import Counter, defaultdict
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
from statistics import mean, median
from typing import Any, Callable
import uuid

from core.repository_dto import canonical_json
from core.repository_store import JsonRepository, RepositoryError
from core.tactical_stats_v2 import deck_signature


SHARE_FIELDS = {
    "version", "share_id", "scope_id", "contributor_id", "consent_scope", "consented_at",
    "shared_at", "occurred_at", "attempt_session_id", "attempt_index", "defense_snapshot_id",
    "anonymous_opponent_id", "season", "patch", "map", "rank_difference", "public_signature",
    "defense_signature", "attack_signature", "result", "source_identity", "source_type",
}
FILTER_FIELDS = {
    "scope_id", "season", "patch", "map", "public_signature", "defense_signature",
    "rank_difference_min", "rank_difference_max", "as_of", "min_independent_contributors",
    "min_independent_opponents", "limit",
}
SOURCE_TYPES = {"v6_import", "manual", "battle_result", "community_report"}
_PROFILE_ID = re.compile(r"^[0-9a-f]{24}$")
_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
_TOKEN = re.compile(r"^[A-Za-z0-9_?*.-]+$")


def _exact(value: object, fields: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != fields:
        raise RepositoryError("invalid_payload", f"{label} must contain exactly {sorted(fields)}")
    return value


def _text(value: object, label: str, *, required: bool = True) -> str:
    if not isinstance(value, str):
        raise RepositoryError("invalid_payload", f"{label} must be a string")
    result = value.strip()
    if required and not result:
        raise RepositoryError("invalid_payload", f"{label} must be non-empty")
    return result


def _identifier(value: object, label: str) -> str:
    result = _text(value, label)
    if _ID.fullmatch(result) is None:
        raise RepositoryError("invalid_payload", f"{label} is not a stable identifier")
    return result


def _timestamp(value: object, label: str) -> str:
    result = _text(value, label)
    try:
        parsed = datetime.fromisoformat(result.replace("Z", "+00:00"))
    except ValueError as error:
        raise RepositoryError("invalid_payload", f"{label} must be an ISO timestamp") from error
    if parsed.tzinfo is None:
        raise RepositoryError("invalid_payload", f"{label} must include a timezone")
    return parsed.astimezone(timezone.utc).isoformat()


def _stable_id(prefix: str, *parts: str) -> str:
    digest = hashlib.sha256("\0".join(parts).encode("utf-8")).hexdigest()[:32]
    return f"{prefix}-{digest}"


def _signature(value: object, label: str, *, public: bool = False) -> str:
    result = _text(value, label)
    segments = result.split("|")
    expected = 3 if public else 2
    if len(segments) != expected:
        raise RepositoryError("invalid_payload", f"{label} has an invalid segment count")
    tokens = segments if public else [*segments[0].split(","), *segments[1].split(",")]
    if (not public and (len(segments[0].split(",")) != 4 or len(segments[1].split(",")) != 2)) or any(
        not token or _TOKEN.fullmatch(token) is None for token in tokens
    ):
        raise RepositoryError("invalid_payload", f"{label} has invalid slots")
    return result


def canonical_share_payload(value: object) -> dict[str, Any]:
    item = _exact(value, SHARE_FIELDS, "share")
    if item["version"] != 1:
        raise RepositoryError("invalid_payload", "share.version must be 1")
    result = deepcopy(item)
    for field in (
        "share_id", "scope_id", "contributor_id", "attempt_session_id", "defense_snapshot_id",
        "anonymous_opponent_id", "source_identity",
    ):
        result[field] = _identifier(item[field], field)
    result["consent_scope"] = _text(item["consent_scope"], "consent_scope")
    if result["consent_scope"] != result["scope_id"]:
        raise RepositoryError("invalid_payload", "consent_scope must equal scope_id")
    for field in ("consented_at", "shared_at", "occurred_at"):
        result[field] = _timestamp(item[field], field)
    if result["consented_at"] > result["shared_at"] or result["occurred_at"] > result["shared_at"]:
        raise RepositoryError("invalid_payload", "consent and occurrence must not be after sharing")
    if not isinstance(item["attempt_index"], int) or isinstance(item["attempt_index"], bool) or item["attempt_index"] < 1:
        raise RepositoryError("invalid_payload", "attempt_index must be a positive integer")
    if not isinstance(item["rank_difference"], int) or isinstance(item["rank_difference"], bool):
        raise RepositoryError("invalid_payload", "rank_difference must be an integer")
    for field in ("season", "patch", "map"):
        result[field] = _text(item[field], field)
    result["public_signature"] = _signature(item["public_signature"], "public_signature", public=True)
    result["defense_signature"] = _signature(item["defense_signature"], "defense_signature")
    result["attack_signature"] = _signature(item["attack_signature"], "attack_signature")
    if item["result"] not in {"win", "loss"}:
        raise RepositoryError("invalid_payload", "result must be win or loss")
    if item["source_type"] not in SOURCE_TYPES:
        raise RepositoryError("invalid_payload", "source_type is not shareable")
    return result


def canonical_analytics_filters(value: object) -> dict[str, Any]:
    item = _exact(value, FILTER_FIELDS, "filters")
    result = deepcopy(item)
    result["scope_id"] = _identifier(item["scope_id"], "scope_id")
    for field in ("season", "patch", "map"):
        if item[field] is not None:
            result[field] = _text(item[field], field)
    for field, public in (("public_signature", True), ("defense_signature", False)):
        if item[field] is not None:
            result[field] = _signature(item[field], field, public=public)
    for field in ("rank_difference_min", "rank_difference_max"):
        if item[field] is not None and (not isinstance(item[field], int) or isinstance(item[field], bool)):
            raise RepositoryError("invalid_payload", f"{field} must be an integer or null")
    if item["rank_difference_min"] is not None and item["rank_difference_max"] is not None and item["rank_difference_min"] > item["rank_difference_max"]:
        raise RepositoryError("invalid_payload", "rank_difference_min must not exceed rank_difference_max")
    result["as_of"] = _timestamp(item["as_of"], "as_of")
    for field in ("min_independent_contributors", "min_independent_opponents"):
        if not isinstance(item[field], int) or isinstance(item[field], bool) or not 1 <= item[field] <= 100:
            raise RepositoryError("invalid_payload", f"{field} must be from 1 to 100")
    if not isinstance(item["limit"], int) or isinstance(item["limit"], bool) or not 1 <= item["limit"] <= 100:
        raise RepositoryError("invalid_payload", "limit must be from 1 to 100")
    return result


class TacticalShareV1Store:
    """Opt-in, redacted tactical sharing store. No transport is performed here."""

    def __init__(self, root: Path, repository: JsonRepository, tactical_reader: Any) -> None:
        self.root = Path(root)
        self.repository = repository
        self.tactical_reader = tactical_reader

    def _path(self, profile_id: str) -> Path:
        if not isinstance(profile_id, str) or _PROFILE_ID.fullmatch(profile_id) is None:
            raise RepositoryError("invalid_payload", "profile_id must be a stable 24-character lowercase hex ID")
        return self.root / "tactical-share" / f"{profile_id}.v1.json"

    @staticmethod
    def _empty(profile_id: str) -> dict[str, Any]:
        records: list[dict[str, Any]] = []
        return {
            "version": 1, "profile_id": profile_id, "revision": 0, "records": records,
            "tombstones": [], "aggregate_cache": TacticalShareV1Store._cache(records), "idempotency": {},
        }

    @staticmethod
    def _cache(records: list[dict[str, Any]]) -> dict[str, Any]:
        ordered = sorted(records, key=lambda item: item["share_id"])
        return {
            "fingerprint": hashlib.sha256(canonical_json(ordered).encode("utf-8")).hexdigest(),
            "active_record_count": len(records),
            "contributor_count": len({item["contributor_id"] for item in records}),
            "opponent_count": len({item["anonymous_opponent_id"] for item in records}),
            "attempt_session_count": len({(item["contributor_id"], item["attempt_session_id"]) for item in records}),
            "source_counts": dict(sorted(Counter(item["source_type"] for item in records).items())),
        }

    def _read(self, profile_id: str) -> dict[str, Any]:
        self.repository.get_state(profile_id)
        path = self._path(profile_id)
        if not path.exists():
            return self._empty(profile_id)
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise RepositoryError("corrupt_data", "tactical share state cannot be read") from error
        fields = {"version", "profile_id", "revision", "records", "tombstones", "aggregate_cache", "idempotency"}
        if not isinstance(value, dict) or set(value) != fields or value.get("version") != 1 or value.get("profile_id") != profile_id:
            raise RepositoryError("corrupt_data", "tactical share state has an invalid shape or version")
        if not isinstance(value["revision"], int) or value["revision"] < 0 or not isinstance(value["records"], list) or not isinstance(value["tombstones"], list) or not isinstance(value["idempotency"], dict):
            raise RepositoryError("corrupt_data", "tactical share state collections are invalid")
        try:
            value["records"] = [canonical_share_payload(item) for item in value["records"]]
        except RepositoryError as error:
            raise RepositoryError("corrupt_data", "tactical share record is invalid") from error
        if value["aggregate_cache"] != self._cache(value["records"]):
            raise RepositoryError("corrupt_data", "tactical share aggregate cache is inconsistent")
        return value

    def _write(self, profile_id: str, value: dict[str, Any]) -> None:
        path = self._path(profile_id)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
        try:
            with temporary.open("w", encoding="utf-8", newline="\n") as stream:
                stream.write(canonical_json(value))
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
        except Exception as error:
            temporary.unlink(missing_ok=True)
            raise RepositoryError("persistence_failed", "atomic tactical share write failed", retryable=True) from error

    def _mutate(
        self, profile_id: str, expected_revision: object, idempotency_key: object,
        operation: dict[str, Any], apply: Callable[[dict[str, Any]], dict[str, Any]],
    ) -> dict[str, Any]:
        if not isinstance(expected_revision, int) or isinstance(expected_revision, bool) or expected_revision < 0:
            raise RepositoryError("invalid_payload", "expected_revision must be non-negative")
        key = _text(idempotency_key, "idempotency_key")
        fingerprint = hashlib.sha256(canonical_json(operation).encode("utf-8")).hexdigest()
        self.root.mkdir(parents=True, exist_ok=True)
        lock = self.root / ".tactical-share-v1.lock"
        try:
            descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError as error:
            raise RepositoryError("repository_busy", "another tactical share writer holds the lock", retryable=True) from error
        try:
            value = self._read(profile_id)
            cached = value["idempotency"].get(key)
            if cached is not None:
                if cached["fingerprint"] != fingerprint:
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another share mutation")
                return deepcopy(cached["response"])
            if value["revision"] != expected_revision:
                raise RepositoryError("revision_conflict", "expected tactical share revision is stale", details={"current_revision": value["revision"]})
            response = apply(value)
            if not response.pop("_no_change", False):
                value["revision"] += 1
            value["aggregate_cache"] = self._cache(value["records"])
            response = {"revision": value["revision"], **response, "aggregate_cache": deepcopy(value["aggregate_cache"])}
            value["idempotency"][key] = {"fingerprint": fingerprint, "response": response}
            self._write(profile_id, value)
            return deepcopy(response)
        finally:
            os.close(descriptor)
            lock.unlink(missing_ok=True)

    def state(self, profile_id: str) -> dict[str, Any]:
        value = self._read(profile_id)
        return {key: deepcopy(value[key]) for key in ("version", "profile_id", "revision", "records", "tombstones", "aggregate_cache")}

    def prepare(self, profile_id: str, request: object) -> dict[str, Any]:
        fields = {
            "match_id", "scope_id", "contributor_id", "consent", "attempt_session_id",
            "attempt_index", "shared_at", "patch",
        }
        data = _exact(request, fields, "prepare")
        consent = _exact(data["consent"], {"enabled", "scope_id", "contributor_id", "consented_at", "include_original_media"}, "consent")
        if consent["enabled"] is not True or consent["include_original_media"] is not False:
            raise RepositoryError("consent_required", "sharing requires opt-in consent with original media disabled")
        scope_id = _identifier(data["scope_id"], "scope_id")
        contributor_id = _identifier(data["contributor_id"], "contributor_id")
        if consent["scope_id"] != scope_id or consent["contributor_id"] != contributor_id:
            raise RepositoryError("consent_required", "consent identity and scope must match the share")
        consented_at = _timestamp(consent["consented_at"], "consented_at")
        shared_at = _timestamp(data["shared_at"], "shared_at")
        if consented_at > shared_at:
            raise RepositoryError("invalid_payload", "consented_at must not be after shared_at")
        attempt_session_id = _identifier(data["attempt_session_id"], "attempt_session_id")
        if not isinstance(data["attempt_index"], int) or isinstance(data["attempt_index"], bool) or data["attempt_index"] < 1:
            raise RepositoryError("invalid_payload", "attempt_index must be positive")
        patch = _text(data["patch"], "patch")
        match_id = _identifier(data["match_id"], "match_id")
        tactical = self.tactical_reader._read(profile_id)
        match = next((item for item in tactical["matches"] if item.get("match_id") == match_id), None)
        if match is None:
            raise RepositoryError("match_not_found", "tactical match was not found")
        if match.get("kind") != "attack" or match.get("source") == "prediction":
            raise RepositoryError("not_shareable", "only observed attack matches can be shared")
        if match.get("occurred_at") is None:
            raise RepositoryError("not_shareable", "actual occurred_at is required")
        candidate = next((item for item in tactical["lobby_candidates"] if item.get("match_id") == match_id), None)
        if candidate is None or candidate.get("link_status") not in {"automatic", "manual"}:
            raise RepositoryError("not_shareable", "a confirmed lobby link is required")
        scan = next((item for item in tactical["lobby_scans"] if item.get("scan_id") == candidate["scan_id"]), None)
        snapshot = next((item for item in tactical["snapshots"] if item.get("match_id") == match_id and item.get("source") != "lobby_scan"), None)
        if scan is None or snapshot is None:
            raise RepositoryError("not_shareable", "linked scan and observed defense snapshot are required")
        local_opponent = str(match["opponent_identity_id"])
        anonymous_opponent_id = _stable_id("anon", scope_id, str(scan["season"]), local_opponent)
        anonymous_snapshot_id = _stable_id("shared-snapshot", scope_id, str(snapshot["snapshot_id"]))
        source_local = f"{match.get('source', '')}:{match.get('source_record_id', match_id)}"
        source_identity = _stable_id("source", scope_id, contributor_id, source_local)
        share_id = _stable_id("share", contributor_id, source_identity, attempt_session_id, str(data["attempt_index"]))
        payload = {
            "version": 1, "share_id": share_id, "scope_id": scope_id, "contributor_id": contributor_id,
            "consent_scope": scope_id, "consented_at": consented_at, "shared_at": shared_at,
            "occurred_at": _timestamp(match["occurred_at"], "occurred_at"),
            "attempt_session_id": attempt_session_id, "attempt_index": data["attempt_index"],
            "defense_snapshot_id": anonymous_snapshot_id, "anonymous_opponent_id": anonymous_opponent_id,
            "season": _text(scan["season"], "season"), "patch": patch, "map": _text(scan["map"], "map"),
            "rank_difference": int(scan["current_rank"]) - int(candidate["opponent_rank"]),
            "public_signature": _signature(candidate["public_signature"], "public_signature", public=True),
            "defense_signature": deck_signature(match["defense_deck"]),
            "attack_signature": deck_signature(match["attack_deck"]), "result": match["result"],
            "source_identity": source_identity, "source_type": match["source"],
        }
        return {
            "share": canonical_share_payload(payload),
            "redaction": {
                "original_media_included": False, "local_identity_included": False,
                "name_or_roi_included": False, "prediction_included": False,
            },
        }

    def import_records(
        self, profile_id: str, shares: object, expected_revision: object, idempotency_key: object,
    ) -> dict[str, Any]:
        if not isinstance(shares, list) or not 1 <= len(shares) <= 100:
            raise RepositoryError("invalid_payload", "shares must contain from 1 to 100 records")
        canonical = [canonical_share_payload(item) for item in shares]
        if len({item["share_id"] for item in canonical}) != len(canonical):
            raise RepositoryError("invalid_payload", "share_ids must not repeat in one import")
        operation = {"method": "share.import", "shares": canonical}

        def apply(value: dict[str, Any]) -> dict[str, Any]:
            existing_by_id = {item["share_id"]: item for item in value["records"]}
            existing_sources = {(item["scope_id"], item["contributor_id"], item["source_identity"]) for item in value["records"]}
            withdrawn_ids = {item["share_id"] for item in value["tombstones"]}
            withdrawn_sources = {(item["scope_id"], item["contributor_id"], item["source_identity"]) for item in value["tombstones"]}
            imported = duplicate = withdrawn = 0
            for item in canonical:
                current = existing_by_id.get(item["share_id"])
                if current is not None:
                    if current != item:
                        raise RepositoryError("share_conflict", "share_id refers to another payload")
                    duplicate += 1
                    continue
                source_key = (item["scope_id"], item["contributor_id"], item["source_identity"])
                if item["share_id"] in withdrawn_ids or source_key in withdrawn_sources:
                    withdrawn += 1
                    continue
                if source_key in existing_sources:
                    duplicate += 1
                    continue
                value["records"].append(item)
                existing_by_id[item["share_id"]] = item
                existing_sources.add(source_key)
                imported += 1
            return {"imported": imported, "skipped_duplicate": duplicate, "skipped_withdrawn": withdrawn, "_no_change": imported == 0}

        return self._mutate(profile_id, expected_revision, idempotency_key, operation, apply)

    def withdraw(
        self, profile_id: str, share_ids: object, withdrawn_at: object, reason: object,
        expected_revision: object, idempotency_key: object,
    ) -> dict[str, Any]:
        if not isinstance(share_ids, list) or not share_ids or any(not isinstance(item, str) for item in share_ids):
            raise RepositoryError("invalid_payload", "share_ids must be a non-empty string list")
        ids = [_identifier(item, "share_id") for item in share_ids]
        if len(ids) != len(set(ids)):
            raise RepositoryError("invalid_payload", "share_ids must not repeat")
        when = _timestamp(withdrawn_at, "withdrawn_at")
        why = _text(reason, "reason")
        operation = {"method": "share.withdraw", "share_ids": sorted(ids), "withdrawn_at": when, "reason": why}

        def apply(value: dict[str, Any]) -> dict[str, Any]:
            targets = [item for item in value["records"] if item["share_id"] in ids]
            known = {item["share_id"] for item in value["tombstones"]}
            for item in targets:
                if item["share_id"] not in known:
                    value["tombstones"].append({
                        "share_id": item["share_id"], "scope_id": item["scope_id"],
                        "contributor_id": item["contributor_id"], "source_identity": item["source_identity"],
                        "withdrawn_at": when, "reason": why,
                    })
            value["records"] = [item for item in value["records"] if item["share_id"] not in ids]
            return {"withdrawn": len(targets), "not_found": len(ids) - len(targets), "_no_change": not targets}

        return self._mutate(profile_id, expected_revision, idempotency_key, operation, apply)

    @staticmethod
    def _attempt_metrics(records: list[dict[str, Any]]) -> dict[str, Any]:
        sessions: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
        for item in records:
            sessions[(item["contributor_id"], item["attempt_session_id"])].append(item)
        first = [min(items, key=lambda item: item["attempt_index"]) for items in sessions.values()]
        successes: list[int] = []
        for items in sessions.values():
            won = [item["attempt_index"] for item in items if item["result"] == "win"]
            if won:
                successes.append(min(won))
        total = len(sessions)
        return {
            "attempt_session_count": total,
            "first_attempt_count": len(first),
            "first_attempt_wins": sum(item["result"] == "win" for item in first),
            "first_attempt_observed_win_rate": (sum(item["result"] == "win" for item in first) / len(first)) if first else None,
            "mean_attempts_to_first_success": mean(successes) if successes else None,
            "median_attempts_to_first_success": median(successes) if successes else None,
            "cumulative_success_within": {
                str(limit): (sum(value <= limit for value in successes) / total if total else None) for limit in (1, 2, 3)
            },
        }

    @staticmethod
    def _group_result(records: list[dict[str, Any]]) -> dict[str, Any]:
        ordered = sorted(records, key=lambda item: (item["occurred_at"], item["shared_at"], item["share_id"]))
        contributors = Counter(item["contributor_id"] for item in records)
        wins = sum(item["result"] == "win" for item in records)
        discoverer = ordered[0]["contributor_id"]
        discoverer_records = [item for item in records if item["contributor_id"] == discoverer]
        other_records = [item for item in records if item["contributor_id"] != discoverer]
        occurred = [datetime.fromisoformat(item["occurred_at"]) for item in records]

        def observed(items: list[dict[str, Any]]) -> dict[str, Any]:
            item_wins = sum(item["result"] == "win" for item in items)
            return {"match_count": len(items), "wins": item_wins, "observed_win_rate": item_wins / len(items) if items else None}

        return {
            "defense_signature": records[0]["defense_signature"], "attack_signature": records[0]["attack_signature"],
            "season": records[0]["season"], "patch": records[0]["patch"], "map": records[0]["map"],
            "rank_difference": records[0]["rank_difference"], "match_count": len(records),
            "contributor_count": len(contributors), "opponent_count": len({item["anonymous_opponent_id"] for item in records}),
            "wins": wins, "losses": len(records) - wins, "observed_win_rate": wins / len(records),
            "max_contributor_share": max(contributors.values()) / len(records),
            "attempts": TacticalShareV1Store._attempt_metrics(records),
            "discoverer": observed(discoverer_records), "other_contributors": observed(other_records),
            "first_verified_at": min(item["occurred_at"] for item in records),
            "last_verified_at": max(item["occurred_at"] for item in records),
            "lifetime_hours": (max(occurred) - min(occurred)).total_seconds() / 3600,
            "source_counts": dict(sorted(Counter(item["source_type"] for item in records).items())),
        }

    @staticmethod
    def _slot_difference(left: str, right: str) -> int | None:
        left_slots = [*left.split("|")[0].split(","), *left.split("|")[1].split(",")]
        right_slots = [*right.split("|")[0].split(","), *right.split("|")[1].split(",")]
        changed = [index for index, pair in enumerate(zip(left_slots, right_slots)) if pair[0] != pair[1]]
        return changed[0] if len(changed) == 1 else None

    def analytics(self, profile_id: str, filters: object) -> dict[str, Any]:
        canonical = canonical_analytics_filters(filters)
        state = self._read(profile_id)
        selected = [item for item in state["records"] if item["scope_id"] == canonical["scope_id"]]
        for field in ("season", "patch", "map", "public_signature", "defense_signature"):
            if canonical[field] is not None:
                selected = [item for item in selected if item[field] == canonical[field]]
        if canonical["rank_difference_min"] is not None:
            selected = [item for item in selected if item["rank_difference"] >= canonical["rank_difference_min"]]
        if canonical["rank_difference_max"] is not None:
            selected = [item for item in selected if item["rank_difference"] <= canonical["rank_difference_max"]]
        selected = [item for item in selected if item["occurred_at"] <= canonical["as_of"]]
        grouped: dict[tuple[Any, ...], list[dict[str, Any]]] = defaultdict(list)
        for item in selected:
            key = (item["season"], item["patch"], item["map"], item["rank_difference"], item["defense_signature"], item["attack_signature"])
            grouped[key].append(item)
        visible: list[dict[str, Any]] = []
        suppressed = 0
        for records in grouped.values():
            if len({item["contributor_id"] for item in records}) < canonical["min_independent_contributors"] or len({item["anonymous_opponent_id"] for item in records}) < canonical["min_independent_opponents"]:
                suppressed += 1
            else:
                visible.append(self._group_result(records))
        visible.sort(key=lambda item: (-item["contributor_count"], -item["match_count"], item["defense_signature"], item["attack_signature"]))
        substitutions: list[dict[str, Any]] = []
        for index, left in enumerate(visible):
            for right in visible[index + 1:]:
                context = ("season", "patch", "map", "rank_difference", "defense_signature")
                if any(left[field] != right[field] for field in context):
                    continue
                position = self._slot_difference(left["attack_signature"], right["attack_signature"])
                if position is not None:
                    substitutions.append({
                        "defense_signature": left["defense_signature"], "changed_position": position,
                        "left": {key: left[key] for key in ("attack_signature", "match_count", "contributor_count", "opponent_count", "observed_win_rate")},
                        "right": {key: right[key] for key in ("attack_signature", "match_count", "contributor_count", "opponent_count", "observed_win_rate")},
                    })
        by_opponent: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for item in selected:
            by_opponent[item["anonymous_opponent_id"]].append(item)
        changes = revalidated = 0
        for items in by_opponent.values():
            ordered = sorted(items, key=lambda item: item["occurred_at"])
            for previous, current in zip(ordered, ordered[1:]):
                if previous["defense_snapshot_id"] != current["defense_snapshot_id"] and previous["defense_signature"] != current["defense_signature"]:
                    changes += 1
                    if current["result"] in {"win", "loss"}:
                        revalidated += 1
        return {
            "version": 1, "filters": canonical,
            "population": {
                "match_count": len(selected), "contributor_count": len({item["contributor_id"] for item in selected}),
                "opponent_count": len({item["anonymous_opponent_id"] for item in selected}),
                "attempt_session_count": len({(item["contributor_id"], item["attempt_session_id"]) for item in selected}),
            },
            "privacy": {
                "min_independent_contributors": canonical["min_independent_contributors"],
                "min_independent_opponents": canonical["min_independent_opponents"],
                "suppressed_group_count": suppressed, "raw_identifiers_returned": False,
            },
            "groups": visible[:canonical["limit"]], "one_slot_substitutions": substitutions[:canonical["limit"]],
            "revalidation": {"defense_change_count": changes, "revalidated_change_count": revalidated},
            "terminology": {
                "win_rate_label": "observed_win_rate", "dataset_scope": "opt_in_shared_observations",
                "warning": "공유에 동의한 관측 경기만 집계한 결과이며 전체 사용자나 미래 승률을 대표하지 않습니다.",
            },
            "ml": {"implemented": False, "required_for_completion": False},
        }
