from __future__ import annotations

import hashlib
import json
import os
from datetime import date
from pathlib import Path
import re
from typing import Any, Callable
import uuid

from core import student_meta
from core.repository_dto import canonical_json
from core.repository_store import JsonRepository, RepositoryError


_PROFILE_ID = re.compile(r"^[0-9a-f]{24}$")
_RECORD_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")


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


def canonical_deck(value: object, *, own: bool, owned: set[str]) -> dict[str, Any]:
    data = _exact(value, {"version", "strikers", "specials"}, "deck")
    if data["version"] != 1 or isinstance(data["version"], bool):
        raise RepositoryError("invalid_payload", "deck version must be 1")
    result: dict[str, Any] = {"version": 1}
    seen: set[str] = set()
    for field, expected_class, size in (("strikers", "striker", 4), ("specials", "special", 2)):
        slots = data[field]
        if not isinstance(slots, list) or len(slots) != size:
            raise RepositoryError("invalid_payload", f"{field} must contain exactly {size} slots")
        normalized: list[str | None] = []
        for item in slots:
            if item is None:
                normalized.append(None)
                continue
            student_id = _text(item, f"{field} student_id", required=True)
            if student_id in seen:
                raise RepositoryError("invalid_payload", "a deck cannot contain duplicate student IDs")
            if student_id not in student_meta.STUDENTS:
                raise RepositoryError("invalid_payload", f"unknown catalog student_id: {student_id}")
            if student_meta.combat_class(student_id) != expected_class:
                raise RepositoryError("invalid_payload", f"{student_id} does not match {expected_class} slot")
            if own and student_id not in owned:
                raise RepositoryError("invalid_payload", f"{student_id} is not confirmed in this profile")
            seen.add(student_id)
            normalized.append(student_id)
        result[field] = normalized
    return result


def _date(value: object) -> str | None:
    if value is None:
        return None
    text = _text(value, "occurred_on", required=True)
    try:
        if date.fromisoformat(text).isoformat() != text:
            raise ValueError
    except ValueError as error:
        raise RepositoryError("invalid_payload", "occurred_on must be an ISO YYYY-MM-DD date or null") from error
    return text


def canonical_match(value: object, owned: set[str]) -> dict[str, Any]:
    keys = {"version", "match_id", "kind", "occurred_on", "season", "opponent", "result", "attack_deck", "defense_deck", "notes"}
    data = _exact(value, keys, "match")
    if data["version"] != 1 or isinstance(data["version"], bool):
        raise RepositoryError("invalid_payload", "match version must be 1")
    kind = data["kind"]
    result = data["result"]
    if kind not in {"attack", "defense"}:
        raise RepositoryError("invalid_payload", "kind must be attack or defense")
    if result not in {"win", "loss"}:
        raise RepositoryError("invalid_payload", "result must be win or loss")
    return {
        "version": 1,
        "match_id": _record_id(data["match_id"], "match_id"),
        "kind": kind,
        "occurred_on": _date(data["occurred_on"]),
        "season": _text(data["season"], "season"),
        "opponent": _text(data["opponent"], "opponent", required=True),
        "result": result,
        "attack_deck": canonical_deck(data["attack_deck"], own=kind == "attack", owned=owned),
        "defense_deck": canonical_deck(data["defense_deck"], own=kind == "defense", owned=owned),
        "notes": _text(data["notes"], "notes"),
    }


def canonical_jokbo(value: object, owned: set[str]) -> dict[str, Any]:
    data = _exact(value, {"version", "jokbo_id", "defense_deck", "attack_deck", "notes"}, "jokbo")
    if data["version"] != 1 or isinstance(data["version"], bool):
        raise RepositoryError("invalid_payload", "jokbo version must be 1")
    defense = canonical_deck(data["defense_deck"], own=False, owned=owned)
    attack = canonical_deck(data["attack_deck"], own=True, owned=owned)
    if not any(defense["strikers"] + defense["specials"]) or not any(attack["strikers"] + attack["specials"]):
        raise RepositoryError("invalid_payload", "jokbo attack and defense decks must not be empty")
    return {"version": 1, "jokbo_id": _record_id(data["jokbo_id"], "jokbo_id"),
            "defense_deck": defense, "attack_deck": attack, "notes": _text(data["notes"], "notes")}


def _validate_stored_deck(value: object) -> None:
    data = _exact(value, {"version", "strikers", "specials"}, "stored deck")
    if data["version"] != 1 or isinstance(data["version"], bool):
        raise ValueError("stored deck version")
    seen: set[str] = set()
    for field, expected, size in (("strikers", "striker", 4), ("specials", "special", 2)):
        slots = data[field]
        if not isinstance(slots, list) or len(slots) != size:
            raise ValueError("stored deck slots")
        for item in slots:
            if item is None:
                continue
            if not isinstance(item, str) or not item or item in seen:
                raise ValueError("stored deck identity")
            # Unknown legacy IDs remain evidence, but known catalog IDs must retain class integrity.
            if item in student_meta.STUDENTS and student_meta.combat_class(item) != expected:
                raise ValueError("stored deck class")
            seen.add(item)


class TacticalStore:
    """Profile-scoped tactical persistence, deliberately separate from repository state."""

    def __init__(self, root: Path, repository: JsonRepository, *, fault: Callable[[str], None] | None = None) -> None:
        self.root = Path(root)
        self.repository = repository
        self._fault = fault or (lambda _stage: None)

    def _path(self, profile_id: str) -> Path:
        if not isinstance(profile_id, str) or _PROFILE_ID.fullmatch(profile_id) is None:
            raise RepositoryError("invalid_payload", "profile_id must be a stable 24-character lowercase hex ID")
        return self.root / "tactical" / f"{profile_id}.json"

    @staticmethod
    def _empty(profile_id: str) -> dict[str, Any]:
        return {"version": 1, "profile_id": profile_id, "revision": 0, "matches": [], "jokbo": [], "idempotency": {}}

    def _owned(self, profile_id: str) -> set[str]:
        return {item["student_id"] for item in self.repository.get_state(profile_id)["students"]}

    def _read(self, profile_id: str) -> dict[str, Any]:
        self.repository.get_state(profile_id)  # profile existence is authoritative
        path = self._path(profile_id)
        if not path.exists():
            return self._empty(profile_id)
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise RepositoryError("corrupt_data", "tactical state cannot be read") from error
        required = {"version", "profile_id", "revision", "matches", "jokbo", "idempotency"}
        if not isinstance(value, dict) or set(value) != required or value.get("version") != 1 or value.get("profile_id") != profile_id:
            raise RepositoryError("corrupt_data", "tactical state has an invalid shape or version")
        revision = value["revision"]
        if not isinstance(revision, int) or isinstance(revision, bool) or revision < 0:
            raise RepositoryError("corrupt_data", "tactical revision must be a non-negative integer")
        if not isinstance(value["matches"], list) or not isinstance(value["jokbo"], list) or not isinstance(value["idempotency"], dict):
            raise RepositoryError("corrupt_data", "tactical collections have an invalid shape")
        try:
            match_ids: set[str] = set()
            for item in value["matches"]:
                data = _exact(item, {"version", "match_id", "kind", "occurred_on", "season", "opponent",
                                     "result", "attack_deck", "defense_deck", "notes"}, "stored match")
                match_id = _record_id(data["match_id"], "stored match_id")
                if match_id in match_ids or data["version"] != 1 or data["kind"] not in {"attack", "defense"} or data["result"] not in {"win", "loss"}:
                    raise ValueError("stored match identity or enum")
                if _date(data["occurred_on"]) != data["occurred_on"]:
                    raise ValueError("stored match date")
                for field in ("season", "opponent", "notes"):
                    if _text(data[field], field, required=field == "opponent") != data[field]:
                        raise ValueError("stored match text")
                _validate_stored_deck(data["attack_deck"])
                _validate_stored_deck(data["defense_deck"])
                match_ids.add(match_id)
            jokbo_ids: set[str] = set()
            for item in value["jokbo"]:
                data = _exact(item, {"version", "jokbo_id", "defense_deck", "attack_deck", "notes"}, "stored jokbo")
                jokbo_id = _record_id(data["jokbo_id"], "stored jokbo_id")
                if jokbo_id in jokbo_ids or data["version"] != 1 or _text(data["notes"], "notes") != data["notes"]:
                    raise ValueError("stored jokbo identity")
                _validate_stored_deck(data["defense_deck"])
                _validate_stored_deck(data["attack_deck"])
                if not any(data["defense_deck"]["strikers"] + data["defense_deck"]["specials"]) or not any(data["attack_deck"]["strikers"] + data["attack_deck"]["specials"]):
                    raise ValueError("stored empty jokbo")
                jokbo_ids.add(jokbo_id)
            for key, record in value["idempotency"].items():
                if (not isinstance(key, str) or not key or not isinstance(record, dict) or
                    set(record) != {"fingerprint", "response"} or
                    not isinstance(record["fingerprint"], str) or re.fullmatch(r"[0-9a-f]{64}", record["fingerprint"]) is None or
                    not isinstance(record["response"], dict) or set(record["response"]) != {"revision"} or
                    not isinstance(record["response"]["revision"], int) or isinstance(record["response"]["revision"], bool) or
                    not 0 <= record["response"]["revision"] <= revision):
                    raise ValueError("stored idempotency")
        except (RepositoryError, TypeError, ValueError) as error:
            raise RepositoryError("corrupt_data", "tactical state contains invalid records") from error
        return value

    def state(self, profile_id: str) -> dict[str, Any]:
        value = self._read(profile_id)
        return {key: value[key] for key in ("version", "profile_id", "revision", "matches", "jokbo")}

    def _lock(self) -> int:
        self.root.mkdir(parents=True, exist_ok=True)
        try:
            return os.open(self.root / ".tactical.lock", os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError as error:
            raise RepositoryError("repository_busy", "another tactical writer holds the lock", retryable=True) from error

    def _write(self, path: Path, value: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
        try:
            self._fault("before_write")
            with temporary.open("w", encoding="utf-8", newline="\n") as stream:
                stream.write(canonical_json(value))
                stream.flush()
                self._fault("before_fsync")
                os.fsync(stream.fileno())
            self._fault("before_replace")
            os.replace(temporary, path)
        except Exception as error:
            temporary.unlink(missing_ok=True)
            raise RepositoryError("persistence_failed", "atomic tactical write failed", retryable=True) from error

    def _mutate(self, profile_id: str, expected_revision: int, key: str, operation: dict[str, Any],
                change: Callable[[dict[str, Any], set[str]], None]) -> dict[str, Any]:
        if not isinstance(expected_revision, int) or isinstance(expected_revision, bool) or expected_revision < 0:
            raise RepositoryError("invalid_payload", "expected_revision must be a non-negative integer")
        key = _text(key, "idempotency_key", required=True)
        descriptor = self._lock()
        try:
            value = self._read(profile_id)
            fingerprint = hashlib.sha256(canonical_json(operation).encode()).hexdigest()
            cached = value["idempotency"].get(key)
            if cached is not None:
                if not isinstance(cached, dict) or cached.get("fingerprint") != fingerprint:
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another tactical mutation")
                return cached["response"]
            if value["revision"] != expected_revision:
                raise RepositoryError("revision_conflict", "expected tactical revision is stale",
                                      details={"current_revision": value["revision"]})
            change(value, self._owned(profile_id))
            value["revision"] += 1
            response = {"revision": value["revision"]}
            value["idempotency"][key] = {"fingerprint": fingerprint, "response": response}
            self._write(self._path(profile_id), value)
            return response
        finally:
            os.close(descriptor)
            (self.root / ".tactical.lock").unlink(missing_ok=True)

    def upsert_match(self, profile_id: str, match: object, revision: int, key: str) -> dict[str, Any]:
        def change(state: dict[str, Any], owned: set[str]) -> None:
            item = canonical_match(match, owned)
            state["matches"] = [old for old in state["matches"] if old.get("match_id") != item["match_id"]] + [item]
        return self._mutate(profile_id, revision, key, {"method": "match.upsert", "match": match}, change)

    def delete_match(self, profile_id: str, match_id: object, revision: int, key: str) -> dict[str, Any]:
        match_id = _record_id(match_id, "match_id")
        def change(state: dict[str, Any], _owned: set[str]) -> None:
            if not any(item.get("match_id") == match_id for item in state["matches"]):
                raise RepositoryError("record_not_found", "tactical match does not exist")
            state["matches"] = [item for item in state["matches"] if item.get("match_id") != match_id]
        return self._mutate(profile_id, revision, key, {"method": "match.delete", "match_id": match_id}, change)

    def upsert_jokbo(self, profile_id: str, jokbo: object, revision: int, key: str) -> dict[str, Any]:
        def change(state: dict[str, Any], owned: set[str]) -> None:
            item = canonical_jokbo(jokbo, owned)
            state["jokbo"] = [old for old in state["jokbo"] if old.get("jokbo_id") != item["jokbo_id"]] + [item]
        return self._mutate(profile_id, revision, key, {"method": "jokbo.upsert", "jokbo": jokbo}, change)

    def delete_jokbo(self, profile_id: str, jokbo_id: object, revision: int, key: str) -> dict[str, Any]:
        jokbo_id = _record_id(jokbo_id, "jokbo_id")
        def change(state: dict[str, Any], _owned: set[str]) -> None:
            if not any(item.get("jokbo_id") == jokbo_id for item in state["jokbo"]):
                raise RepositoryError("record_not_found", "tactical jokbo does not exist")
            state["jokbo"] = [item for item in state["jokbo"] if item.get("jokbo_id") != jokbo_id]
        return self._mutate(profile_id, revision, key, {"method": "jokbo.delete", "jokbo_id": jokbo_id}, change)
