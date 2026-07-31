from __future__ import annotations

import hashlib
import json
import os
from copy import deepcopy
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
import re
import sqlite3
from typing import Any, Callable, Iterable
import uuid

from core import student_meta
from core.repository_dto import canonical_json
from core.repository_store import JsonRepository, RepositoryError


METHODS = frozenset({
    "tactical.v2.state.get",
    "tactical.v2.import.preview",
    "tactical.v2.import.commit",
    "tactical.v2.lobby.commit",
    "tactical.v2.candidate.select",
    "tactical.v2.match.link",
    "tactical.v2.lobby.delete",
    "tactical.v2.opponent.alias",
    "tactical.v2.stats.query",
    "tactical.v2.trends.query",
    "tactical.v2.recommend.query",
    "tactical.v2.recommend.save",
    "tactical.v2.recommend.get",
    "tactical.v2.share.state.get",
    "tactical.v2.share.prepare",
    "tactical.v2.share.import",
    "tactical.v2.share.withdraw",
    "tactical.v2.share.analytics.query",
})
_PROFILE_ID = re.compile(r"^[0-9a-f]{24}$")
_RECORD_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
_KST = timezone(timedelta(hours=9))


def _exact(value: object, keys: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise RepositoryError("invalid_payload", f"{label} must contain exactly {sorted(keys)}")
    return value


def _text(value: object, label: str, *, required: bool = False) -> str:
    if not isinstance(value, str):
        raise RepositoryError("invalid_payload", f"{label} must be a string")
    result = value.strip()
    if required and not result:
        raise RepositoryError("invalid_payload", f"{label} must be non-empty")
    return result


def _record_id(value: object, label: str) -> str:
    result = _text(value, label, required=True)
    if _RECORD_ID.fullmatch(result) is None:
        raise RepositoryError("invalid_payload", f"{label} is not a stable record ID")
    return result


def _revision(value: object) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise RepositoryError("invalid_payload", "expected_revision must be a non-negative integer")
    return value


def _fingerprint(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
    except OSError as error:
        raise RepositoryError("import_source_unreadable", "v6 tactical database cannot be read") from error
    return digest.hexdigest()


def _name_key(value: object) -> str:
    return re.sub(r"\s+", "", str(value or "").strip()).casefold()


def _student_name_index() -> dict[tuple[str, str], str]:
    result: dict[tuple[str, str], str] = {}
    duplicates: set[tuple[str, str]] = set()
    for student_id in student_meta.STUDENTS:
        key = (_name_key(student_meta.display_name(student_id)), student_meta.combat_class(student_id))
        if key in result:
            duplicates.add(key)
        else:
            result[key] = student_id
    for key in duplicates:
        result.pop(key, None)
    return result


_EXACT_STUDENT_NAMES = _student_name_index()


def _iso_date(value: str, label: str) -> str | None:
    value = value.strip()
    if not value:
        return None
    try:
        parsed = date.fromisoformat(value)
    except ValueError as error:
        raise ValueError(f"{label} is not an ISO date") from error
    return datetime(parsed.year, parsed.month, parsed.day, tzinfo=_KST).isoformat()


def _iso_created(value: str) -> str | None:
    value = value.strip()
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError as error:
        raise ValueError("created_at is not an ISO timestamp") from error
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=_KST)
    return parsed.isoformat()


def _stable_id(prefix: str, *parts: str) -> str:
    digest = hashlib.sha256("\0".join(parts).encode("utf-8")).hexdigest()[:32]
    return f"{prefix}-{digest}"


def _slot(
    position: int,
    raw_name: str,
    role: str,
    observation: str,
    issue: Callable[[str, str], None],
) -> dict[str, Any]:
    name = raw_name.strip()
    wildcard = name == "*"
    student_id: str | None = None
    state = observation if name and not wildcard else "unknown"
    if name and not wildcard:
        student_id = _EXACT_STUDENT_NAMES.get((_name_key(name), role))
        if student_id is None:
            issue("unknown_student", f"{role} slot {position + 1} cannot map '{name}'")
    return {
        "version": 2,
        "position": position,
        "student_id": student_id,
        "state": state,
        "source": "v6_import",
        "confidence": None,
        "review_status": "confirmed" if student_id is not None or wildcard else "unreviewed",
        "wildcard": wildcard,
    }


def _deck(
    raw: str,
    observation: str,
    issue: Callable[[str, str], None],
) -> dict[str, Any]:
    if "|" in raw:
        striker_raw, special_raw = raw.split("|", 1)
    else:
        striker_raw, special_raw = raw, ""
    striker_names = striker_raw.split(",")[:4] if striker_raw else []
    special_names = special_raw.split(",")[:2] if special_raw else []
    striker_names += [""] * (4 - len(striker_names))
    special_names += [""] * (2 - len(special_names))
    slots = [
        *[_slot(index, name, "striker", observation, issue) for index, name in enumerate(striker_names)],
        *[_slot(index, name, "special", observation, issue) for index, name in enumerate(special_names)],
    ]
    ids = [item["student_id"] for item in slots if item["student_id"] is not None]
    if len(ids) != len(set(ids)):
        issue("duplicate_student", "one deck contains the same canonical student more than once")
    return {"version": 2, "strikers": slots[:4], "specials": slots[4:]}


def _observation_for_source(source_label: str) -> str:
    if source_label == "타인 전적":
        return "community_reported"
    if source_label == "스크린샷":
        return "revealed_after_battle"
    return "manual"


def _source_record_id(kind: str, source_id: str) -> str:
    return f"{kind}:{source_id}"


class V6TacticalImporter:
    """Read-only v6 SQLite adapter. It never imports or executes v6 Python."""

    REQUIRED_MATCH_COLUMNS = {
        "id", "date", "season", "opponent", "result", "my_attack", "opponent_defense",
        "my_defense", "opponent_attack", "source", "notes", "created_at",
    }
    REQUIRED_JOKBO_COLUMNS = {"id", "defense", "attack", "wins", "losses", "notes", "updated_at"}

    def __init__(self, clock: Callable[[], datetime] | None = None) -> None:
        self.clock = clock or (lambda: datetime.now(timezone.utc))

    def _connect(self, path: Path) -> sqlite3.Connection:
        if path.suffix.casefold() not in {".db", ".sqlite", ".sqlite3"} or not path.is_file():
            raise RepositoryError("import_source_invalid", "source_path must be an existing SQLite database")
        try:
            connection = sqlite3.connect(f"file:{path.resolve().as_posix()}?mode=ro", uri=True)
            connection.row_factory = sqlite3.Row
            if connection.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise RepositoryError("import_source_corrupt", "v6 tactical database failed integrity_check")
            tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if not {"matches", "jokbo"}.issubset(tables):
                raise RepositoryError("import_source_invalid", "v6 tactical database tables are missing")
            match_columns = {row[1] for row in connection.execute("PRAGMA table_info(matches)")}
            jokbo_columns = {row[1] for row in connection.execute("PRAGMA table_info(jokbo)")}
            if not self.REQUIRED_MATCH_COLUMNS.issubset(match_columns) or not self.REQUIRED_JOKBO_COLUMNS.issubset(jokbo_columns):
                raise RepositoryError("import_source_invalid", "v6 tactical database columns are incompatible")
            return connection
        except RepositoryError:
            connection.close() if "connection" in locals() else None
            raise
        except sqlite3.Error as error:
            raise RepositoryError("import_source_invalid", "v6 tactical database cannot be opened read-only") from error

    def convert(self, path: Path, batch_id: str) -> dict[str, Any]:
        batch_id = _record_id(batch_id, "import_batch_id")
        imported_at = self.clock().astimezone(timezone.utc).isoformat()
        fingerprint = _fingerprint(path)
        issues: list[dict[str, Any]] = []
        matches: list[dict[str, Any]] = []
        jokbo: list[dict[str, Any]] = []
        identities: dict[str, dict[str, Any]] = {}
        snapshots: list[dict[str, Any]] = []

        def issue_for(record_id: str, code: str, message: str) -> None:
            issues.append({
                "issue_id": _stable_id("issue", batch_id, record_id, code),
                "source_record_id": record_id,
                "code": code,
                "message": message,
            })

        connection = self._connect(path)
        try:
            for row in connection.execute("SELECT * FROM matches ORDER BY id"):
                source_id = _source_record_id("match", str(row["id"]))
                before = len(issues)
                local_issue = lambda code, message, sid=source_id: issue_for(sid, code, message)
                attack_mode = bool(str(row["my_attack"] or "").strip() or str(row["opponent_defense"] or "").strip())
                defense_mode = bool(str(row["my_defense"] or "").strip() or str(row["opponent_attack"] or "").strip())
                if attack_mode == defense_mode:
                    local_issue("ambiguous_direction", "match must contain exactly one attack/defense direction")
                kind = "attack" if attack_mode else "defense"
                attack_raw = str(row["my_attack"] if kind == "attack" else row["opponent_attack"] or "")
                defense_raw = str(row["opponent_defense"] if kind == "attack" else row["my_defense"] or "")
                source_label = str(row["source"] or "").strip()
                observation = _observation_for_source(source_label)
                try:
                    occurred_at = _iso_date(str(row["date"] or ""), "date")
                    created_at = _iso_created(str(row["created_at"] or "")) or imported_at
                except ValueError as error:
                    local_issue("invalid_timestamp", str(error))
                    occurred_at, created_at = None, imported_at
                display_name = str(row["opponent"] or "").strip()
                if not display_name:
                    local_issue("missing_opponent", "match opponent is empty")
                identity_id = _stable_id("opponent", display_name.casefold())
                identities.setdefault(identity_id, {
                    "version": 2,
                    "identity_id": identity_id,
                    "current_display_name": display_name,
                    "aliases": [display_name] if display_name else [],
                    "first_observed_at": occurred_at,
                    "last_observed_at": occurred_at,
                    "review_status": "review_required",
                    "name_template_ids": [],
                })
                identity = identities[identity_id]
                observed_values = [value for value in (identity["first_observed_at"], occurred_at) if value]
                identity["first_observed_at"] = min(observed_values) if observed_values else None
                observed_values = [value for value in (identity["last_observed_at"], occurred_at) if value]
                identity["last_observed_at"] = max(observed_values) if observed_values else None
                match_id = _stable_id("match", batch_id, source_id)
                attack_deck = _deck(attack_raw, observation, local_issue)
                defense_deck = _deck(defense_raw, observation, local_issue)
                result = str(row["result"] or "").strip().casefold()
                if result not in {"win", "loss"}:
                    local_issue("invalid_result", "result must be win or loss")
                record = {
                    "version": 2,
                    "match_id": match_id,
                    "kind": kind,
                    "occurred_at": occurred_at,
                    "observed_at": None,
                    "imported_at": imported_at,
                    "created_at": created_at,
                    "source": "v6_import",
                    "source_label": source_label,
                    "import_batch_id": batch_id,
                    "source_record_id": source_id,
                    "confidence": None,
                    "review_status": "confirmed" if len(issues) == before else "review_required",
                    "season": str(row["season"] or "").strip(),
                    "opponent_identity_id": identity_id,
                    "opponent_display_name": display_name,
                    "result": result,
                    "attack_deck": attack_deck,
                    "defense_deck": defense_deck,
                    "notes": str(row["notes"] or "").strip(),
                }
                matches.append(record)
                if kind == "attack" and any(slot["student_id"] for slot in defense_deck["strikers"] + defense_deck["specials"]):
                    snapshots.append({
                        "version": 2,
                        "snapshot_id": _stable_id("snapshot", batch_id, source_id),
                        "opponent_identity_id": identity_id,
                        "occurred_at": occurred_at,
                        "observed_at": None,
                        "imported_at": imported_at,
                        "source": "v6_import",
                        "source_record_id": source_id,
                        "confidence": None,
                        "review_status": record["review_status"],
                        "season": record["season"],
                        "deck": defense_deck,
                        "match_id": match_id,
                    })

            for row in connection.execute("SELECT * FROM jokbo ORDER BY id"):
                source_id = _source_record_id("jokbo", str(row["id"]))
                before = len(issues)
                local_issue = lambda code, message, sid=source_id: issue_for(sid, code, message)
                try:
                    created_at = _iso_created(str(row["updated_at"] or "")) or imported_at
                except ValueError as error:
                    local_issue("invalid_timestamp", str(error))
                    created_at = imported_at
                item = {
                    "version": 2,
                    "jokbo_id": _stable_id("jokbo", batch_id, source_id),
                    "defense_deck": _deck(str(row["defense"] or ""), "manual", local_issue),
                    "attack_deck": _deck(str(row["attack"] or ""), "manual", local_issue),
                    "wins": int(row["wins"]),
                    "losses": int(row["losses"]),
                    "notes": str(row["notes"] or "").strip(),
                    "created_at": created_at,
                    "imported_at": imported_at,
                    "source": "v6_import",
                    "source_label": "manual_jokbo",
                    "import_batch_id": batch_id,
                    "source_record_id": source_id,
                    "confidence": None,
                    "review_status": "confirmed" if len(issues) == before else "review_required",
                }
                if item["wins"] < 0 or item["losses"] < 0:
                    local_issue("invalid_counts", "jokbo wins/losses must be non-negative")
                    item["review_status"] = "review_required"
                jokbo.append(item)
        finally:
            connection.close()
        invalid_sources = {item["source_record_id"] for item in issues}
        return {
            "fingerprint": fingerprint,
            "imported_at": imported_at,
            "matches": matches,
            "jokbo": jokbo,
            "opponents": list(identities.values()),
            "snapshots": snapshots,
            "issues": issues,
            "invalid_sources": invalid_sources,
        }

    def preview(self, path: Path, batch_id: str) -> dict[str, Any]:
        converted = self.convert(path, batch_id)
        invalid = converted["invalid_sources"]
        return {
            "version": 2,
            "import_batch_id": batch_id,
            "source_fingerprint": converted["fingerprint"],
            "match_count": len(converted["matches"]),
            "jokbo_count": len(converted["jokbo"]),
            "opponent_count": len(converted["opponents"]),
            "snapshot_count": len(converted["snapshots"]),
            "valid_record_count": len(converted["matches"]) + len(converted["jokbo"]) - len(invalid),
            "issue_count": len(converted["issues"]),
            "issues": converted["issues"],
        }


class TacticalV2Store:
    def __init__(
        self,
        root: Path,
        repository: JsonRepository,
        *,
        importer: V6TacticalImporter | None = None,
        fault: Callable[[str], None] | None = None,
    ) -> None:
        self.root = Path(root)
        self.repository = repository
        self.importer = importer or V6TacticalImporter()
        self._fault = fault or (lambda _stage: None)

    def _path(self, profile_id: str) -> Path:
        if not isinstance(profile_id, str) or _PROFILE_ID.fullmatch(profile_id) is None:
            raise RepositoryError("invalid_payload", "profile_id must be a stable 24-character lowercase hex ID")
        return self.root / "tactical" / f"{profile_id}.v2.json"

    @staticmethod
    def _empty(profile_id: str) -> dict[str, Any]:
        return {
            "version": 2,
            "profile_id": profile_id,
            "revision": 0,
            "matches": [],
            "jokbo": [],
            "opponents": [],
            "snapshots": [],
            "lobby_scans": [],
            "lobby_candidates": [],
            "predictions": [],
            "import_batches": [],
            "idempotency": {},
        }

    def _read(self, profile_id: str) -> dict[str, Any]:
        self.repository.get_state(profile_id)
        path = self._path(profile_id)
        if not path.exists():
            return self._empty(profile_id)
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise RepositoryError("corrupt_data", "tactical v2 state cannot be read") from error
        legacy = {"version", "profile_id", "revision", "matches", "jokbo", "opponents", "snapshots", "import_batches", "idempotency"}
        p9_shape = legacy | {"lobby_scans", "lobby_candidates"}
        required = p9_shape | {"predictions"}
        if isinstance(value, dict) and set(value) == legacy:
            value["lobby_scans"] = []
            value["lobby_candidates"] = []
            value["predictions"] = []
        elif isinstance(value, dict) and set(value) == p9_shape:
            value["predictions"] = []
        if not isinstance(value, dict) or set(value) != required or value.get("version") != 2 or value.get("profile_id") != profile_id:
            raise RepositoryError("corrupt_data", "tactical v2 state has an invalid shape or version")
        if not isinstance(value["revision"], int) or isinstance(value["revision"], bool) or value["revision"] < 0:
            raise RepositoryError("corrupt_data", "tactical v2 revision is invalid")
        for key in ("matches", "jokbo", "opponents", "snapshots", "lobby_scans", "lobby_candidates", "predictions", "import_batches"):
            if not isinstance(value[key], list):
                raise RepositoryError("corrupt_data", f"tactical v2 {key} is invalid")
        for opponent in value["opponents"]:
            if isinstance(opponent, dict):
                opponent.setdefault("name_template_ids", [])
        if not isinstance(value["idempotency"], dict):
            raise RepositoryError("corrupt_data", "tactical v2 idempotency is invalid")
        return value

    def state(self, profile_id: str) -> dict[str, Any]:
        value = self._read(profile_id)
        return {key: value[key] for key in ("version", "profile_id", "revision", "matches", "jokbo", "opponents", "snapshots", "lobby_scans", "lobby_candidates", "predictions", "import_batches")}

    def preview(self, profile_id: str, source_path: str, batch_id: str) -> dict[str, Any]:
        self.repository.get_state(profile_id)
        return self.importer.preview(Path(_text(source_path, "source_path", required=True)), batch_id)

    def _lock(self) -> int:
        self.root.mkdir(parents=True, exist_ok=True)
        try:
            return os.open(self.root / ".tactical-v2.lock", os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError as error:
            raise RepositoryError("repository_busy", "another tactical v2 writer holds the lock", retryable=True) from error

    def _write(self, path: Path, value: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
        try:
            with temporary.open("w", encoding="utf-8", newline="\n") as stream:
                stream.write(canonical_json(value))
                stream.flush()
                os.fsync(stream.fileno())
            self._fault("before_replace")
            os.replace(temporary, path)
        except Exception as error:
            temporary.unlink(missing_ok=True)
            raise RepositoryError("persistence_failed", "atomic tactical v2 write failed", retryable=True) from error

    def _mutation(
        self, profile_id: str, expected_revision: int, idempotency_key: str,
        operation: dict[str, Any], apply: Callable[[dict[str, Any]], dict[str, Any]],
    ) -> dict[str, Any]:
        expected_revision = _revision(expected_revision)
        idempotency_key = _text(idempotency_key, "idempotency_key", required=True)
        fingerprint = hashlib.sha256(canonical_json(operation).encode()).hexdigest()
        descriptor = self._lock()
        try:
            value = self._read(profile_id)
            cached = value["idempotency"].get(idempotency_key)
            if cached is not None:
                if cached.get("fingerprint") != fingerprint:
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another tactical v2 mutation")
                return deepcopy(cached["response"])
            if value["revision"] != expected_revision:
                raise RepositoryError("revision_conflict", "expected tactical v2 revision is stale", details={"current_revision": value["revision"]})
            response = apply(value)
            no_change = bool(response.pop("_no_change", False))
            if not no_change:
                value["revision"] += 1
            response = {"revision": value["revision"], **response}
            value["idempotency"][idempotency_key] = {"fingerprint": fingerprint, "response": response}
            self._write(self._path(profile_id), value)
            return deepcopy(response)
        finally:
            os.close(descriptor)
            (self.root / ".tactical-v2.lock").unlink(missing_ok=True)

    @staticmethod
    def _timestamp(value: object, label: str) -> str:
        text = _text(value, label, required=True)
        try:
            parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError as error:
            raise RepositoryError("invalid_payload", f"{label} must be an ISO timestamp") from error
        if parsed.tzinfo is None:
            raise RepositoryError("invalid_payload", f"{label} must include a timezone")
        return parsed.astimezone(timezone.utc).isoformat()

    @staticmethod
    def _public_deck(deck: dict[str, Any]) -> dict[str, Any]:
        result = {"version": 2, "strikers": [], "specials": []}
        for role in ("strikers", "specials"):
            for slot in deck[role]:
                result[role].append({
                    "version": 2,
                    "position": slot["position"],
                    "student_id": slot["student_id"],
                    "state": slot["state"],
                    "source": "lobby_scan",
                    "confidence": slot["confidence"],
                    "review_status": slot["review_status"],
                    "wildcard": False,
                })
        return result

    @staticmethod
    def _public_signature(deck: dict[str, Any]) -> str:
        values = [
            deck["strikers"][0]["student_id"],
            deck["specials"][0]["student_id"],
            deck["specials"][1]["student_id"],
        ]
        return "|".join(value or "?" for value in values)

    def commit_lobby(
        self, profile_id: str, candidate_payload: object, season: str, map_name: str,
        identity_bindings: object, expected_revision: int, idempotency_key: str,
    ) -> dict[str, Any]:
        from core.tactical_lobby_scanner import canonical_tactical_lobby_candidate

        payload = canonical_tactical_lobby_candidate(candidate_payload)
        if payload["review_status"] != "confirmed":
            raise RepositoryError("review_required", "tactical lobby candidate must be confirmed before persistence")
        season = _text(season, "season")
        map_name = _text(map_name, "map")
        if not isinstance(identity_bindings, list):
            raise RepositoryError("invalid_payload", "identity_bindings must be a list")
        bindings: dict[int, str] = {}
        for item in identity_bindings:
            if not isinstance(item, dict) or set(item) != {"display_index", "opponent_identity_id"}:
                raise RepositoryError("invalid_payload", "identity binding shape is invalid")
            index, identity_id = item["display_index"], _record_id(item["opponent_identity_id"], "opponent_identity_id")
            if not isinstance(index, int) or isinstance(index, bool) or index not in range(3) or index in bindings:
                raise RepositoryError("invalid_payload", "identity binding index is invalid or duplicated")
            bindings[index] = identity_id
        operation = {
            "method": "lobby.commit", "candidate_payload": payload, "season": season,
            "map": map_name, "identity_bindings": identity_bindings,
        }

        def apply(value: dict[str, Any]) -> dict[str, Any]:
            existing = next((item for item in value["lobby_scans"] if item["refresh_generation"] == payload["refresh_generation"]), None)
            if existing is not None:
                return {"_no_change": True, "scan_id": existing["scan_id"], "candidate_ids": [item["candidate_id"] for item in value["lobby_candidates"] if item["scan_id"] == existing["scan_id"]], "created": False}
            observed_at = self._timestamp(payload["observed_at"], "observed_at")
            scan_id = _stable_id("scan", profile_id, payload["refresh_generation"])
            scan = {
                "version": 2, "scan_id": scan_id, "observed_at": observed_at,
                "season": season, "map": map_name,
                "current_rank": payload["current_rank"]["value"],
                "refresh_generation": payload["refresh_generation"],
                "screen_hash": payload["screen_hash"], "roi_profile_id": payload["roi_profile_id"],
                "confidence": payload["overall_confidence"], "review_status": payload["review_status"],
            }
            value["lobby_scans"].append(scan)
            candidate_ids: list[str] = []
            for row in payload["rows"]:
                index = row["index"]
                name = row["opponent"]["display_name"]
                if not name:
                    raise RepositoryError("review_required", f"rows[{index}] opponent name is unresolved")
                identity: dict[str, Any] | None = None
                if index in bindings:
                    identity = next((item for item in value["opponents"] if item["identity_id"] == bindings[index]), None)
                    if identity is None:
                        raise RepositoryError("opponent_not_found", f"identity binding for row {index} was not found")
                else:
                    normalized = _name_key(name)
                    matches = [item for item in value["opponents"] if normalized in {_name_key(alias) for alias in item["aliases"]}]
                    if len(matches) > 1:
                        raise RepositoryError("identity_ambiguous", f"rows[{index}] name maps to multiple opponents")
                    identity = matches[0] if matches else None
                if identity is None:
                    identity = {
                        "version": 2, "identity_id": _stable_id("opponent", profile_id, _name_key(name)),
                        "current_display_name": name, "aliases": [name],
                        "first_observed_at": observed_at, "last_observed_at": observed_at,
                        "review_status": "confirmed",
                        "name_template_ids": [],
                    }
                    value["opponents"].append(identity)
                else:
                    if name not in identity["aliases"]:
                        identity["aliases"].append(name)
                    identity["current_display_name"] = name
                    identity["first_observed_at"] = min(filter(None, [identity["first_observed_at"], observed_at]))
                    identity["last_observed_at"] = max(filter(None, [identity["last_observed_at"], observed_at]))
                candidate_id = _stable_id("candidate", scan_id, str(index))
                snapshot_id = _stable_id("snapshot", scan_id, str(index))
                deck = self._public_deck(row["public_defense"])
                value["lobby_candidates"].append({
                    "version": 2, "candidate_id": candidate_id, "scan_id": scan_id,
                    "display_index": index, "opponent_identity_id": identity["identity_id"],
                    "opponent_rank": row["rank"]["value"],
                    "public_signature": self._public_signature(deck),
                    "confidence": row["confidence"], "review_status": row["review_status"],
                    "selected_at": None, "match_id": None, "link_status": "unlinked",
                    "snapshot_id": snapshot_id,
                })
                value["snapshots"].append({
                    "version": 2, "snapshot_id": snapshot_id,
                    "opponent_identity_id": identity["identity_id"],
                    "occurred_at": None, "observed_at": observed_at,
                    "imported_at": datetime.now(timezone.utc).isoformat(),
                    "source": "lobby_scan", "source_record_id": scan_id,
                    "confidence": row["confidence"], "review_status": row["review_status"],
                    "season": season, "deck": deck, "match_id": None,
                })
                candidate_ids.append(candidate_id)
            return {"scan_id": scan_id, "candidate_ids": candidate_ids, "created": True}

        return self._mutation(profile_id, expected_revision, idempotency_key, operation, apply)

    def select_candidate(
        self, profile_id: str, candidate_id: str, selected_at: str,
        expected_revision: int, idempotency_key: str,
    ) -> dict[str, Any]:
        candidate_id = _record_id(candidate_id, "candidate_id")
        selected_at = self._timestamp(selected_at, "selected_at")
        operation = {"method": "candidate.select", "candidate_id": candidate_id, "selected_at": selected_at}

        def apply(value: dict[str, Any]) -> dict[str, Any]:
            candidate = next((item for item in value["lobby_candidates"] if item["candidate_id"] == candidate_id), None)
            if candidate is None:
                raise RepositoryError("candidate_not_found", "lobby candidate was not found")
            candidate["selected_at"] = selected_at
            return {"candidate_id": candidate_id, "selected_at": selected_at}

        return self._mutation(profile_id, expected_revision, idempotency_key, operation, apply)

    @staticmethod
    def _match_signature(match: dict[str, Any]) -> str:
        return TacticalV2Store._public_signature(match["defense_deck"])

    def link_match(
        self, profile_id: str, match_id: str, candidate_id: str | None, mode: str,
        expected_revision: int, idempotency_key: str,
    ) -> dict[str, Any]:
        match_id = _record_id(match_id, "match_id")
        if mode not in {"auto", "manual", "unlink"}:
            raise RepositoryError("invalid_payload", "mode must be auto, manual, or unlink")
        if candidate_id is not None:
            candidate_id = _record_id(candidate_id, "candidate_id")
        if (mode == "manual") != (candidate_id is not None) or mode == "unlink" and candidate_id is not None:
            raise RepositoryError("invalid_payload", "candidate_id is required only for manual mode")
        operation = {"method": "match.link", "match_id": match_id, "candidate_id": candidate_id, "mode": mode}

        def apply(value: dict[str, Any]) -> dict[str, Any]:
            match = next((item for item in value["matches"] if item["match_id"] == match_id), None)
            if match is None:
                raise RepositoryError("match_not_found", "tactical match was not found")
            if match["kind"] != "attack":
                raise RepositoryError("link_conflict", "lobby candidates can only link to attack matches")
            linked = [item for item in value["lobby_candidates"] if item["match_id"] == match_id]
            if mode == "unlink":
                for item in linked:
                    item["match_id"] = None
                    item["link_status"] = "unlinked"
                return {"status": "unlinked", "candidate_id": None, "match_id": match_id}
            if mode == "manual":
                candidates = [item for item in value["lobby_candidates"] if item["candidate_id"] == candidate_id]
            else:
                occurred = match.get("occurred_at")
                if occurred is None:
                    raise RepositoryError("link_review_required", "automatic link requires match occurred_at")
                occurred_dt = datetime.fromisoformat(occurred)
                candidates = []
                for item in value["lobby_candidates"]:
                    if item["match_id"] not in {None, match_id} or item["selected_at"] is None:
                        continue
                    scan = next(scan for scan in value["lobby_scans"] if scan["scan_id"] == item["scan_id"])
                    selected_dt = datetime.fromisoformat(item["selected_at"])
                    if (
                        item["opponent_identity_id"] == match["opponent_identity_id"]
                        and item["public_signature"] == self._match_signature(match)
                        and (not scan["season"] or not match["season"] or scan["season"] == match["season"])
                        and abs((occurred_dt - selected_dt).total_seconds()) <= 6 * 3600
                    ):
                        candidates.append(item)
                if len(candidates) != 1:
                    status = "ambiguous" if len(candidates) > 1 else "unresolved"
                    for item in candidates:
                        item["link_status"] = "review_required"
                    return {"status": status, "candidate_id": None, "match_id": match_id, "candidate_count": len(candidates)}
            if len(candidates) != 1:
                raise RepositoryError("candidate_not_found", "manual lobby candidate was not found")
            candidate = candidates[0]
            if candidate["opponent_identity_id"] != match["opponent_identity_id"]:
                raise RepositoryError("link_conflict", "candidate and match opponent identities differ")
            for item in linked:
                if item["candidate_id"] != candidate["candidate_id"]:
                    item["match_id"] = None
                    item["link_status"] = "unlinked"
            if candidate["match_id"] not in {None, match_id}:
                raise RepositoryError("link_conflict", "candidate is already linked to another match")
            candidate["match_id"] = match_id
            candidate["link_status"] = "manual" if mode == "manual" else "automatic"
            return {"status": candidate["link_status"], "candidate_id": candidate["candidate_id"], "match_id": match_id}

        return self._mutation(profile_id, expected_revision, idempotency_key, operation, apply)

    def delete_lobby(
        self, profile_id: str, scan_id: str, expected_revision: int, idempotency_key: str,
    ) -> dict[str, Any]:
        scan_id = _record_id(scan_id, "scan_id")
        operation = {"method": "lobby.delete", "scan_id": scan_id}

        def apply(value: dict[str, Any]) -> dict[str, Any]:
            before = len(value["lobby_scans"])
            candidate_ids = {item["candidate_id"] for item in value["lobby_candidates"] if item["scan_id"] == scan_id}
            snapshot_ids = {item["snapshot_id"] for item in value["lobby_candidates"] if item["scan_id"] == scan_id}
            value["lobby_scans"] = [item for item in value["lobby_scans"] if item["scan_id"] != scan_id]
            value["lobby_candidates"] = [item for item in value["lobby_candidates"] if item["candidate_id"] not in candidate_ids]
            value["snapshots"] = [item for item in value["snapshots"] if item["snapshot_id"] not in snapshot_ids]
            return {"scan_id": scan_id, "deleted": before != len(value["lobby_scans"]), "deleted_candidates": len(candidate_ids)}

        return self._mutation(profile_id, expected_revision, idempotency_key, operation, apply)

    def alias_opponent(
        self, profile_id: str, identity_id: str, display_name: str, name_template_id: str | None,
        expected_revision: int, idempotency_key: str,
    ) -> dict[str, Any]:
        identity_id = _record_id(identity_id, "opponent_identity_id")
        display_name = _text(display_name, "display_name", required=True)
        if name_template_id is not None:
            name_template_id = _record_id(name_template_id, "name_template_id")
        operation = {"method": "opponent.alias", "identity_id": identity_id, "display_name": display_name, "name_template_id": name_template_id}

        def apply(value: dict[str, Any]) -> dict[str, Any]:
            opponent = next((item for item in value["opponents"] if item["identity_id"] == identity_id), None)
            if opponent is None:
                raise RepositoryError("opponent_not_found", "opponent identity was not found")
            if display_name not in opponent["aliases"]:
                opponent["aliases"].append(display_name)
            opponent["current_display_name"] = display_name
            templates = opponent.setdefault("name_template_ids", [])
            if name_template_id is not None and name_template_id not in templates:
                templates.append(name_template_id)
            return {"opponent_identity_id": identity_id, "current_display_name": display_name, "aliases": opponent["aliases"], "name_template_ids": templates}

        return self._mutation(profile_id, expected_revision, idempotency_key, operation, apply)

    def statistics(self, profile_id: str, filters: object) -> dict[str, Any]:
        from core.tactical_stats_v2 import TacticalStatisticsV2

        return TacticalStatisticsV2.query(self._read(profile_id), filters)

    def trends(self, profile_id: str, filters: object) -> dict[str, Any]:
        from core.tactical_trends_v2 import TacticalTrendsV2

        return TacticalTrendsV2.query(self._read(profile_id), filters)

    def recommendations(self, profile_id: str, filters: object) -> dict[str, Any]:
        from core.tactical_recommend_v2 import TacticalRecommendationV2

        return TacticalRecommendationV2.query(self._read(profile_id), filters)

    def save_recommendation(
        self, profile_id: str, filters: object, expected_revision: int, idempotency_key: str,
    ) -> dict[str, Any]:
        from core.tactical_recommend_v2 import TacticalRecommendationV2, canonical_recommend_filters

        canonical = canonical_recommend_filters(filters)
        operation = {"method": "recommend.save", "filters": canonical}

        def apply(value: dict[str, Any]) -> dict[str, Any]:
            result = TacticalRecommendationV2.query(value, canonical)
            prediction_id = _stable_id(
                "prediction", profile_id, str(value["revision"]), canonical_json(canonical),
            )
            record = {
                "version": 2,
                "prediction_id": prediction_id,
                "as_of": canonical["as_of"],
                "state_revision": value["revision"],
                "filters": canonical,
                "result": result,
            }
            value["predictions"].append(record)
            return {"prediction_id": prediction_id, "created": True, "prediction": record}

        return self._mutation(profile_id, expected_revision, idempotency_key, operation, apply)

    def get_recommendation(self, profile_id: str, prediction_id: object) -> dict[str, Any]:
        target = _record_id(prediction_id, "prediction_id")
        value = self._read(profile_id)
        record = next((item for item in value["predictions"] if item.get("prediction_id") == target), None)
        if record is None:
            raise RepositoryError("prediction_not_found", "saved tactical prediction was not found")
        return deepcopy(record)

    def _share_store(self):
        from core.tactical_share_v1 import TacticalShareV1Store

        return TacticalShareV1Store(self.root, self.repository, self)

    def share_state(self, profile_id: str) -> dict[str, Any]:
        return self._share_store().state(profile_id)

    def prepare_share(self, profile_id: str, request: object) -> dict[str, Any]:
        return self._share_store().prepare(profile_id, request)

    def import_shares(
        self, profile_id: str, shares: object, expected_revision: object, idempotency_key: object,
    ) -> dict[str, Any]:
        return self._share_store().import_records(profile_id, shares, expected_revision, idempotency_key)

    def withdraw_shares(
        self, profile_id: str, share_ids: object, withdrawn_at: object, reason: object,
        expected_revision: object, idempotency_key: object,
    ) -> dict[str, Any]:
        return self._share_store().withdraw(
            profile_id, share_ids, withdrawn_at, reason, expected_revision, idempotency_key,
        )

    def share_analytics(self, profile_id: str, filters: object) -> dict[str, Any]:
        return self._share_store().analytics(profile_id, filters)

    def commit(
        self,
        profile_id: str,
        source_path: str,
        batch_id: str,
        expected_fingerprint: str,
        accepted_issue_ids: Iterable[str],
        expected_revision: int,
        idempotency_key: str,
    ) -> dict[str, Any]:
        batch_id = _record_id(batch_id, "import_batch_id")
        expected_revision = _revision(expected_revision)
        idempotency_key = _text(idempotency_key, "idempotency_key", required=True)
        if not isinstance(expected_fingerprint, str) or re.fullmatch(r"[0-9a-f]{64}", expected_fingerprint) is None:
            raise RepositoryError("invalid_payload", "expected_fingerprint must be SHA-256")
        if not isinstance(accepted_issue_ids, list) or not all(isinstance(item, str) and item for item in accepted_issue_ids):
            raise RepositoryError("invalid_payload", "accepted_issue_ids must be a string list")
        if len(accepted_issue_ids) != len(set(accepted_issue_ids)):
            raise RepositoryError("invalid_payload", "accepted_issue_ids must not contain duplicates")
        converted = self.importer.convert(Path(_text(source_path, "source_path", required=True)), batch_id)
        if converted["fingerprint"] != expected_fingerprint:
            raise RepositoryError("import_source_changed", "v6 tactical database changed after preview")
        issue_ids = {item["issue_id"] for item in converted["issues"]}
        accepted = set(accepted_issue_ids)
        if accepted != issue_ids:
            raise RepositoryError(
                "import_review_required",
                "all preview issues must be acknowledged exactly before commit",
                details={"required_issue_ids": sorted(issue_ids)},
            )
        descriptor = self._lock()
        try:
            value = self._read(profile_id)
            operation = {
                "method": "import.commit",
                "batch_id": batch_id,
                "fingerprint": expected_fingerprint,
                "accepted_issue_ids": sorted(accepted),
            }
            operation_fingerprint = hashlib.sha256(canonical_json(operation).encode()).hexdigest()
            cached = value["idempotency"].get(idempotency_key)
            if cached is not None:
                if cached.get("fingerprint") != operation_fingerprint:
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another tactical v2 mutation")
                return cached["response"]
            if value["revision"] != expected_revision:
                raise RepositoryError("revision_conflict", "expected tactical v2 revision is stale", details={"current_revision": value["revision"]})
            existing_batch = next((item for item in value["import_batches"] if item["import_batch_id"] == batch_id), None)
            if existing_batch is not None:
                if existing_batch["source_fingerprint"] != expected_fingerprint:
                    raise RepositoryError("import_batch_conflict", "import_batch_id already refers to another source")
                response = {
                    "revision": value["revision"],
                    "imported_matches": 0,
                    "imported_jokbo": 0,
                    "skipped_issues": len(converted["invalid_sources"]),
                    "skipped_existing": len(converted["matches"]) + len(converted["jokbo"]) - len(converted["invalid_sources"]),
                }
                value["idempotency"][idempotency_key] = {"fingerprint": operation_fingerprint, "response": response}
                self._write(self._path(profile_id), value)
                return response
            invalid = converted["invalid_sources"]
            accepted_matches = [item for item in converted["matches"] if item["source_record_id"] not in invalid]
            accepted_jokbo = [item for item in converted["jokbo"] if item["source_record_id"] not in invalid]
            accepted_match_ids = {item["match_id"] for item in accepted_matches}
            accepted_identity_ids = {item["opponent_identity_id"] for item in accepted_matches}
            value["matches"].extend(accepted_matches)
            value["jokbo"].extend(accepted_jokbo)
            existing_identity_ids = {item["identity_id"] for item in value["opponents"]}
            value["opponents"].extend(
                item for item in converted["opponents"]
                if item["identity_id"] in accepted_identity_ids and item["identity_id"] not in existing_identity_ids
            )
            value["snapshots"].extend(item for item in converted["snapshots"] if item["match_id"] in accepted_match_ids)
            value["import_batches"].append({
                "version": 2,
                "import_batch_id": batch_id,
                "source_fingerprint": expected_fingerprint,
                "imported_at": converted["imported_at"],
                "match_count": len(accepted_matches),
                "jokbo_count": len(accepted_jokbo),
                "skipped_issue_count": len(invalid),
            })
            value["revision"] += 1
            response = {
                "revision": value["revision"],
                "imported_matches": len(accepted_matches),
                "imported_jokbo": len(accepted_jokbo),
                "skipped_issues": len(invalid),
                "skipped_existing": 0,
            }
            value["idempotency"][idempotency_key] = {"fingerprint": operation_fingerprint, "response": response}
            self._write(self._path(profile_id), value)
            return response
        finally:
            os.close(descriptor)
            (self.root / ".tactical-v2.lock").unlink(missing_ok=True)


class TacticalProtocolV2:
    def __init__(self, store: TacticalV2Store) -> None:
        self.store = store

    def handle(self, request: dict[str, Any]) -> dict[str, Any]:
        try:
            payload = self._dispatch(request["method"], request["payload"])
        except RepositoryError as error:
            wire: dict[str, Any] = {"code": error.code, "message": str(error), "retryable": error.retryable}
            if error.details:
                wire["details"] = error.details
            payload = {"error": wire}
        except (TypeError, ValueError) as error:
            payload = {"error": {"code": "invalid_payload", "message": str(error), "retryable": False}}
        return {"protocol": 1, "id": request["id"], "type": "response", "method": request["method"], "payload": payload}

    def _dispatch(self, method: str, payload: object) -> dict[str, Any]:
        if method == "tactical.v2.state.get":
            data = _exact(payload, {"profile_id"}, "payload")
            return self.store.state(_text(data["profile_id"], "profile_id", required=True))
        if method == "tactical.v2.import.preview":
            data = _exact(payload, {"profile_id", "source_path", "import_batch_id"}, "payload")
            return self.store.preview(
                _text(data["profile_id"], "profile_id", required=True),
                _text(data["source_path"], "source_path", required=True),
                _record_id(data["import_batch_id"], "import_batch_id"),
            )
        if method == "tactical.v2.import.commit":
            data = _exact(payload, {
                "profile_id", "source_path", "import_batch_id", "expected_fingerprint",
                "accepted_issue_ids", "expected_revision", "idempotency_key",
            }, "payload")
            return self.store.commit(
                _text(data["profile_id"], "profile_id", required=True),
                _text(data["source_path"], "source_path", required=True),
                _record_id(data["import_batch_id"], "import_batch_id"),
                data["expected_fingerprint"],
                data["accepted_issue_ids"],
                data["expected_revision"],
                data["idempotency_key"],
            )
        if method == "tactical.v2.lobby.commit":
            data = _exact(payload, {
                "profile_id", "candidate_payload", "season", "map", "identity_bindings",
                "expected_revision", "idempotency_key",
            }, "payload")
            return self.store.commit_lobby(
                _text(data["profile_id"], "profile_id", required=True),
                data["candidate_payload"], data["season"], data["map"],
                data["identity_bindings"], data["expected_revision"], data["idempotency_key"],
            )
        if method == "tactical.v2.candidate.select":
            data = _exact(payload, {
                "profile_id", "candidate_id", "selected_at", "expected_revision", "idempotency_key",
            }, "payload")
            return self.store.select_candidate(
                _text(data["profile_id"], "profile_id", required=True), data["candidate_id"],
                data["selected_at"], data["expected_revision"], data["idempotency_key"],
            )
        if method == "tactical.v2.match.link":
            data = _exact(payload, {
                "profile_id", "match_id", "candidate_id", "mode", "expected_revision", "idempotency_key",
            }, "payload")
            return self.store.link_match(
                _text(data["profile_id"], "profile_id", required=True), data["match_id"],
                data["candidate_id"], data["mode"], data["expected_revision"], data["idempotency_key"],
            )
        if method == "tactical.v2.lobby.delete":
            data = _exact(payload, {"profile_id", "scan_id", "expected_revision", "idempotency_key"}, "payload")
            return self.store.delete_lobby(
                _text(data["profile_id"], "profile_id", required=True), data["scan_id"],
                data["expected_revision"], data["idempotency_key"],
            )
        if method == "tactical.v2.opponent.alias":
            data = _exact(payload, {
                "profile_id", "opponent_identity_id", "display_name", "name_template_id",
                "expected_revision", "idempotency_key",
            }, "payload")
            return self.store.alias_opponent(
                _text(data["profile_id"], "profile_id", required=True), data["opponent_identity_id"],
                data["display_name"], data["name_template_id"], data["expected_revision"], data["idempotency_key"],
            )
        if method == "tactical.v2.stats.query":
            data = _exact(payload, {"profile_id", "filters"}, "payload")
            return self.store.statistics(
                _text(data["profile_id"], "profile_id", required=True), data["filters"]
            )
        if method == "tactical.v2.trends.query":
            data = _exact(payload, {"profile_id", "filters"}, "payload")
            return self.store.trends(
                _text(data["profile_id"], "profile_id", required=True), data["filters"]
            )
        if method == "tactical.v2.recommend.query":
            data = _exact(payload, {"profile_id", "filters"}, "payload")
            return self.store.recommendations(
                _text(data["profile_id"], "profile_id", required=True), data["filters"]
            )
        if method == "tactical.v2.recommend.save":
            data = _exact(
                payload, {"profile_id", "filters", "expected_revision", "idempotency_key"}, "payload",
            )
            return self.store.save_recommendation(
                _text(data["profile_id"], "profile_id", required=True), data["filters"],
                _revision(data["expected_revision"]), _text(data["idempotency_key"], "idempotency_key", required=True),
            )
        if method == "tactical.v2.recommend.get":
            data = _exact(payload, {"profile_id", "prediction_id"}, "payload")
            return self.store.get_recommendation(
                _text(data["profile_id"], "profile_id", required=True), data["prediction_id"],
            )
        if method == "tactical.v2.share.state.get":
            data = _exact(payload, {"profile_id"}, "payload")
            return self.store.share_state(_text(data["profile_id"], "profile_id", required=True))
        if method == "tactical.v2.share.prepare":
            data = _exact(payload, {
                "profile_id", "match_id", "scope_id", "contributor_id", "consent",
                "attempt_session_id", "attempt_index", "shared_at", "patch",
            }, "payload")
            return self.store.prepare_share(
                _text(data["profile_id"], "profile_id", required=True),
                {key: data[key] for key in data if key != "profile_id"},
            )
        if method == "tactical.v2.share.import":
            data = _exact(payload, {"profile_id", "shares", "expected_revision", "idempotency_key"}, "payload")
            return self.store.import_shares(
                _text(data["profile_id"], "profile_id", required=True), data["shares"],
                data["expected_revision"], data["idempotency_key"],
            )
        if method == "tactical.v2.share.withdraw":
            data = _exact(payload, {
                "profile_id", "share_ids", "withdrawn_at", "reason", "expected_revision", "idempotency_key",
            }, "payload")
            return self.store.withdraw_shares(
                _text(data["profile_id"], "profile_id", required=True), data["share_ids"],
                data["withdrawn_at"], data["reason"], data["expected_revision"], data["idempotency_key"],
            )
        if method == "tactical.v2.share.analytics.query":
            data = _exact(payload, {"profile_id", "filters"}, "payload")
            return self.store.share_analytics(
                _text(data["profile_id"], "profile_id", required=True), data["filters"],
            )
        raise RepositoryError("unknown_method", f"Unknown tactical v2 method: {method}")
