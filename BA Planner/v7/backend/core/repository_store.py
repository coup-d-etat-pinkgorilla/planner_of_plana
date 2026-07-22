from __future__ import annotations

from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path
import re
import time
from typing import Any, Callable
import uuid

from core.planning import GrowthPlan, StudentGoal
from core.repository_dto import ConfirmedStudent, InventorySnapshot, StudentGoalRecord, canonical_json
from core.repository_merge import resolve_inventory_snapshot


STORE_VERSION = 1


class RepositoryError(RuntimeError):
    def __init__(self, code: str, message: str, *, retryable: bool = False, details: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.retryable = retryable
        self.details = details or {}


class JsonRepository:
    """Single-writer, atomic JSON repository. Importing it performs no I/O."""

    def __init__(self, root: Path, *, id_factory: Callable[[], str] | None = None, fault: Callable[[str], None] | None = None) -> None:
        self.root = Path(root)
        self._id_factory = id_factory or (lambda: uuid.uuid4().hex)
        self._fault = fault or (lambda _stage: None)

    @property
    def catalog_path(self) -> Path:
        return self.root / "catalog.json"

    def _profile_path(self, profile_id: str) -> Path:
        if not isinstance(profile_id, str) or re.fullmatch(r"[0-9a-f]{24}", profile_id) is None:
            raise RepositoryError("invalid_payload", "profile_id must be a stable 24-character lowercase hex ID")
        return self.root / "profiles" / f"{profile_id}.json"

    def _read(self, path: Path, label: str) -> dict[str, Any]:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError as error:
            raise RepositoryError("profile_not_found", f"{label} does not exist") from error
        except (OSError, json.JSONDecodeError, UnicodeError) as error:
            raise RepositoryError("corrupt_data", f"{label} cannot be read", details={"reason": type(error).__name__}) from error
        if not isinstance(value, dict):
            raise RepositoryError("corrupt_data", f"{label} must be an object")
        if "version" not in value:
            raise RepositoryError("corrupt_data", f"{label} is missing its format version")
        if value.get("version") != STORE_VERSION or isinstance(value.get("version"), bool):
            raise RepositoryError("migration_required", f"{label} has an unsupported format version")
        return value

    @staticmethod
    def _stored_revision(value: object, label: str) -> int:
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            raise RepositoryError("corrupt_data", f"{label} must be a non-negative integer")
        return value

    @staticmethod
    def _stored_profile_id(value: object, label: str) -> str:
        if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{24}", value) is None:
            raise RepositoryError("corrupt_data", f"{label} must be a canonical profile ID")
        return value

    def _catalog(self, *, allow_missing: bool = True) -> dict[str, Any]:
        if allow_missing and not self.catalog_path.exists():
            return {"version": STORE_VERSION, "selected_profile_id": None, "profiles": []}
        value = self._read(self.catalog_path, "profile catalog")
        if set(value) != {"version", "selected_profile_id", "profiles"} or not isinstance(value["profiles"], list):
            raise RepositoryError("corrupt_data", "profile catalog has an invalid shape")
        selected = value["selected_profile_id"]
        if selected is not None:
            self._stored_profile_id(selected, "profile catalog selected_profile_id")
        ids: set[str] = set()
        names: set[str] = set()
        for item in value["profiles"]:
            if not isinstance(item, dict) or set(item) != {"profile_id", "display_name", "revision"}:
                raise RepositoryError("corrupt_data", "profile catalog contains an invalid summary")
            profile_id = self._stored_profile_id(item["profile_id"], "profile summary profile_id")
            display_name = item["display_name"]
            if not isinstance(display_name, str) or not display_name.strip():
                raise RepositoryError("corrupt_data", "profile summary display_name must be non-empty")
            self._stored_revision(item["revision"], "profile summary revision")
            folded = display_name.casefold()
            if profile_id in ids or folded in names:
                raise RepositoryError("corrupt_data", "profile catalog contains duplicate profiles")
            ids.add(profile_id)
            names.add(folded)
        if selected is not None and selected not in ids:
            raise RepositoryError("corrupt_data", "selected profile is absent from catalog")
        return value

    def _profile(self, profile_id: str) -> dict[str, Any]:
        value = self._read(self._profile_path(profile_id), "profile")
        required = {"version", "profile_id", "revision", "students", "inventory", "goals", "idempotency"}
        if set(value) != required or value["profile_id"] != profile_id:
            raise RepositoryError("corrupt_data", "profile has an invalid shape")
        revision = self._stored_revision(value["revision"], "profile revision")
        if not isinstance(value["students"], list):
            raise RepositoryError("corrupt_data", "profile students must be an array")
        goals = value["goals"]
        if not isinstance(goals, dict) or set(goals) != {"version", "goals"} or goals.get("version") != 1 or isinstance(goals.get("version"), bool) or not isinstance(goals.get("goals"), list):
            raise RepositoryError("corrupt_data", "profile goals must be a version 1 goal plan")
        idempotency = value["idempotency"]
        if not isinstance(idempotency, dict):
            raise RepositoryError("corrupt_data", "profile idempotency must be an object")
        for key, record in idempotency.items():
            if not isinstance(key, str) or not key or not isinstance(record, dict) or set(record) != {"fingerprint", "response"}:
                raise RepositoryError("corrupt_data", "profile contains an invalid idempotency record")
            fingerprint = record["fingerprint"]
            response = record["response"]
            if not isinstance(fingerprint, str) or re.fullmatch(r"[0-9a-f]{64}", fingerprint) is None or not isinstance(response, dict) or set(response) != {"revision"}:
                raise RepositoryError("corrupt_data", "profile contains an invalid idempotency record")
            cached_revision = self._stored_revision(response["revision"], "idempotency response revision")
            if cached_revision > revision:
                raise RepositoryError("corrupt_data", "idempotency response revision exceeds profile revision")
        try:
            for student in value["students"]:
                ConfirmedStudent.from_dict(student)
            InventorySnapshot.from_dict(value["inventory"])
            for goal in goals["goals"]:
                StudentGoalRecord.from_dict({"version": 1, "goal": goal})
        except (TypeError, ValueError, AttributeError, KeyError) as error:
            raise RepositoryError("corrupt_data", "profile contains invalid repository data") from error
        return value

    def _lock(self) -> int:
        self.root.mkdir(parents=True, exist_ok=True)
        lock_path = self.root / ".repository.lock"
        try:
            return os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError as error:
            raise RepositoryError("repository_busy", "another repository writer holds the lock", retryable=True) from error

    def _unlock(self, descriptor: int) -> None:
        os.close(descriptor)
        try:
            (self.root / ".repository.lock").unlink()
        except FileNotFoundError:
            pass

    def _atomic_write(self, path: Path, value: dict[str, Any]) -> None:
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
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass
            if isinstance(error, RepositoryError):
                raise
            raise RepositoryError("persistence_failed", "atomic repository write failed", retryable=True, details={"stage": str(error)}) from error

    @staticmethod
    def _profile_summary(profile: dict[str, Any], selected: str | None) -> dict[str, Any]:
        return {"profile_id": profile["profile_id"], "display_name": profile["display_name"], "revision": profile["revision"], "selected": profile["profile_id"] == selected}

    def list_profiles(self) -> dict[str, Any]:
        catalog = self._catalog()
        profiles = [
            {**item, "selected": item["profile_id"] == catalog["selected_profile_id"]}
            for item in catalog["profiles"]
        ]
        return {"profiles": sorted(profiles, key=lambda item: item["profile_id"]), "selected_profile_id": catalog["selected_profile_id"]}

    def create_profile(self, display_name: str, idempotency_key: str) -> dict[str, Any]:
        if not isinstance(display_name, str) or not display_name.strip():
            raise RepositoryError("invalid_payload", "display_name must be non-empty")
        if not isinstance(idempotency_key, str) or not idempotency_key:
            raise RepositoryError("invalid_payload", "idempotency_key must be non-empty")
        descriptor = self._lock()
        try:
            catalog = self._catalog()
            profile_id = hashlib.sha256(idempotency_key.encode("utf-8")).hexdigest()[:24]
            existing = next((item for item in catalog["profiles"] if item["profile_id"] == profile_id), None)
            if existing is not None:
                if existing["display_name"] != display_name.strip():
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another profile")
                return {"profile": {**existing, "selected": catalog["selected_profile_id"] == profile_id}, "revision": existing["revision"]}
            if any(item["display_name"].casefold() == display_name.strip().casefold() for item in catalog["profiles"]):
                raise RepositoryError("profile_name_conflict", "profile display name already exists")
            profile = {"version": 1, "profile_id": profile_id, "revision": 0, "students": [], "inventory": {"version": 1, "entries": []}, "goals": {"version": 1, "goals": []}, "idempotency": {}}
            summary = {"profile_id": profile_id, "display_name": display_name.strip(), "revision": 0, "selected": catalog["selected_profile_id"] is None}
            if catalog["selected_profile_id"] is None:
                catalog["selected_profile_id"] = profile_id
            catalog["profiles"].append({key: summary[key] for key in ("profile_id", "display_name", "revision")})
            self._atomic_write(self._profile_path(profile_id), profile)
            try:
                self._atomic_write(self.catalog_path, catalog)
            except Exception:
                try: self._profile_path(profile_id).unlink()
                except OSError: pass
                raise
            return {"profile": summary, "revision": 0}
        finally:
            self._unlock(descriptor)

    def current_profile(self) -> dict[str, Any]:
        catalog = self._catalog()
        selected = catalog["selected_profile_id"]
        if selected is None:
            return {"profile": None}
        summary = next((item for item in catalog["profiles"] if item["profile_id"] == selected), None)
        if summary is None:
            raise RepositoryError("corrupt_data", "selected profile is absent from catalog")
        return {"profile": {**summary, "selected": True}}

    def _catalog_mutation(self, profile_id: str, expected_revision: int, idempotency_key: str, operation: str, mutate: Callable[[dict[str, Any], dict[str, Any]], None]) -> dict[str, Any]:
        if not isinstance(idempotency_key, str) or not idempotency_key:
            raise RepositoryError("invalid_payload", "idempotency_key must be non-empty")
        if not isinstance(expected_revision, int) or isinstance(expected_revision, bool) or expected_revision < 0:
            raise RepositoryError("invalid_payload", "expected_revision must be a non-negative integer")
        descriptor = self._lock()
        try:
            catalog, profile = self._catalog(allow_missing=False), self._profile(profile_id)
            catalog_before = self.catalog_path.read_bytes()
            profile_path = self._profile_path(profile_id)
            profile_before = profile_path.read_bytes()
            fingerprint = hashlib.sha256(canonical_json({"operation": operation, "expected_revision": expected_revision}).encode()).hexdigest()
            cached = profile["idempotency"].get(idempotency_key)
            if cached:
                if cached["fingerprint"] != fingerprint:
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another mutation")
                return cached["response"]
            if profile["revision"] != expected_revision:
                raise RepositoryError("revision_conflict", "expected revision is stale", details={"current_revision": profile["revision"]})
            mutate(catalog, profile)
            profile["revision"] += 1
            response = {"revision": profile["revision"]}
            profile["idempotency"][idempotency_key] = {"fingerprint": fingerprint, "response": response}
            for item in catalog["profiles"]:
                if item["profile_id"] == profile_id:
                    item["revision"] = profile["revision"]
            try:
                self._atomic_write(profile_path, profile)
                self._atomic_write(self.catalog_path, catalog)
            except Exception:
                self._restore(profile_path, profile_before)
                self._restore(self.catalog_path, catalog_before)
                raise
            return response
        finally:
            self._unlock(descriptor)

    @staticmethod
    def _restore(path: Path, content: bytes) -> None:
        temporary = path.with_name(f".{path.name}.rollback.tmp")
        with temporary.open("wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)

    def select_profile(self, profile_id: str, expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        def mutate(catalog: dict[str, Any], _profile: dict[str, Any]) -> None:
            catalog["selected_profile_id"] = profile_id
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, "select", mutate)

    def rename_profile(self, profile_id: str, display_name: str, expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        name = display_name.strip() if isinstance(display_name, str) else ""
        if not name:
            raise RepositoryError("invalid_payload", "display_name must be non-empty")
        def mutate(catalog: dict[str, Any], _profile: dict[str, Any]) -> None:
            if any(item["profile_id"] != profile_id and item["display_name"].casefold() == name.casefold() for item in catalog["profiles"]):
                raise RepositoryError("profile_name_conflict", "profile display name already exists")
            for item in catalog["profiles"]:
                if item["profile_id"] == profile_id: item["display_name"] = name
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"rename:{name}", mutate)

    def get_state(self, profile_id: str) -> dict[str, Any]:
        profile = self._profile(profile_id)
        return {key: profile[key] for key in ("profile_id", "revision", "students", "inventory", "goals")}

    def update_students(self, profile_id: str, students: list[dict[str, Any]], expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        canonical = [ConfirmedStudent.from_dict(item).to_dict() for item in students]
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"students:{canonical_json(canonical)}", lambda _c, p: p.__setitem__("students", canonical))

    def update_inventory(self, profile_id: str, inventory: dict[str, Any], expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        canonical = InventorySnapshot.from_dict(inventory).to_dict()
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"inventory:{canonical_json(canonical)}", lambda _c, p: p.__setitem__("inventory", canonical))

    def save_goals(self, profile_id: str, goals: dict[str, Any], expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        if not isinstance(goals, dict) or goals.get("version") != 1 or not isinstance(goals.get("goals"), list) or set(goals) != {"version", "goals"}:
            raise RepositoryError("invalid_payload", "goals must be a version 1 goal plan")
        canonical_goals = [StudentGoalRecord.from_dict({"version": 1, "goal": item}).to_dict()["goal"] for item in goals["goals"]]
        canonical = {"version": 1, "goals": canonical_goals}
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"goals:{canonical_json(canonical)}", lambda _c, p: p.__setitem__("goals", canonical))

    @staticmethod
    def migration_preview(_source_path: str, _profile_id: str) -> dict[str, Any]:
        raise RepositoryError("migration_not_supported", "v6 migration is not supported in P4")

    @staticmethod
    def resolve_inventory_input(sqlite_rows: list[dict[str, Any]] | None, json_snapshot: dict[str, dict[str, Any]] | list[dict[str, Any]] | None, *, sqlite_error: str | None = None) -> dict[str, Any]:
        resolved = resolve_inventory_snapshot(sqlite_rows, json_snapshot, sqlite_error=sqlite_error)
        entries = [dict(entry) for entry in resolved.snapshot.values()]
        return {"inventory": {"version": 1, "entries": entries}, "source": resolved.source, "sqlite_error": resolved.sqlite_error}
