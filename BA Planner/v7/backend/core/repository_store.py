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

from core.inventory_catalog import BY_KEY as INVENTORY_CATALOG_BY_KEY, CATALOG_REVISION, canonical_resource_key
from core.planning import GrowthPlan, StudentGoal
from core.repository_dto import ConfirmedStudent, InventorySnapshot, StudentGoalRecord, canonical_json
from core.repository_merge import resolve_inventory_snapshot
from core.repository_plan import canonical_active_document, document_from_goals, goals_from_document, legacy_write_loss, LegacyGoalsConflict
from core.planning_summary import safe_calculation_summary
from core.repository_transaction import Lease, acquire, release, locked, write_transaction
from core.v6_migration import V6MigrationError, load_v6_accounts


STORE_VERSION = 1
DEFAULT_PROFILE_AVATAR = "hasumi"


def rebase_inventory_snapshot(inventory: dict[str, Any]) -> dict[str, Any]:
    """Rebase version-scoped ordinals while retaining observed screen slots."""
    snapshot = InventorySnapshot.from_dict(inventory)
    entries: list[dict[str, Any]] = []
    for item in snapshot.entries:
        entry = item.to_dict()
        # D18: an old catalog key (e.g. 비의서 stored as *_Ultimate_Piece) is rebased to the current key.
        entry["key"] = canonical_resource_key(entry["key"])
        if entry.get("item_id") is not None:
            entry["item_id"] = canonical_resource_key(entry["item_id"])
        identity = entry.get("item_id") or entry["key"]
        catalog_row = INVENTORY_CATALOG_BY_KEY.get(identity)
        if catalog_row is not None:
            if (
                entry.get("observed_slot") is None
                and entry.get("profile_id") == "visible-grid"
                and entry.get("index") is not None
            ):
                entry["observed_slot"] = entry["index"]
            entry["index"] = catalog_row.order_index
            entry["profile_id"] = catalog_row.profile_id
        entries.append(entry)
    return InventorySnapshot.from_dict({
        "version": 1,
        "catalog_revision": CATALOG_REVISION,
        "entries": entries,
    }).to_dict()


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
            if not isinstance(item, dict) or not set(item).issubset({"profile_id", "display_name", "revision", "avatar_student_id"}) or not {"profile_id", "display_name", "revision"}.issubset(item):
                raise RepositoryError("corrupt_data", "profile catalog contains an invalid summary")
            profile_id = self._stored_profile_id(item["profile_id"], "profile summary profile_id")
            display_name = item["display_name"]
            if not isinstance(display_name, str) or not display_name.strip():
                raise RepositoryError("corrupt_data", "profile summary display_name must be non-empty")
            avatar = item.get("avatar_student_id", DEFAULT_PROFILE_AVATAR)
            if not isinstance(avatar, str) or not avatar.strip():
                raise RepositoryError("corrupt_data", "profile summary avatar_student_id must be non-empty")
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
        if set(value) not in (required, required | {"plan"}) or value["profile_id"] != profile_id:
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
            if not isinstance(fingerprint, str) or re.fullmatch(r"[0-9a-f]{64}", fingerprint) is None or not isinstance(response, dict) or set(response) not in ({"revision"}, {"revision", "scenario_revision", "archived_scenario_id"}):
                raise RepositoryError("corrupt_data", "profile contains an invalid idempotency record")
            cached_revision = self._stored_revision(response["revision"], "idempotency response revision")
            if cached_revision > revision:
                raise RepositoryError("corrupt_data", "idempotency response revision exceeds profile revision")
            if "scenario_revision" in response:
                self._stored_revision(response["scenario_revision"], "idempotency scenario revision")
                archived_id = response["archived_scenario_id"]
                if archived_id is not None:
                    self._stored_profile_id(archived_id, "idempotency archived scenario ID")
        try:
            for student in value["students"]:
                ConfirmedStudent.from_dict(student)
            InventorySnapshot.from_dict(value["inventory"])
            for goal in goals["goals"]:
                StudentGoalRecord.from_dict({"version": 1, "goal": goal})
            if "plan" in value:
                value["plan"] = canonical_active_document(value["plan"])
                if goals != goals_from_document(value["plan"]):
                    raise ValueError("stored goals do not match the active document")
        except (TypeError, ValueError, AttributeError, KeyError) as error:
            raise RepositoryError("corrupt_data", "profile contains invalid repository data") from error
        value["inventory"] = rebase_inventory_snapshot(value["inventory"])
        return value

    @staticmethod
    def _legacy_document(goals: dict[str, Any]) -> dict[str, Any]:
        try:
            return document_from_goals(goals)
        except LegacyGoalsConflict as error:
            raise RepositoryError("legacy_goals_conflict", str(error), details={"student_ids": error.student_ids}) from error

    def _write_profile_catalog(self, profile: dict[str, Any], catalog: dict[str, Any]) -> None:
        """Use the existing two-file transaction and byte-preserving rollback."""
        profile_path = self._profile_path(profile["profile_id"])
        profile_before, catalog_before = profile_path.read_bytes(), self.catalog_path.read_bytes()
        try:
            self._atomic_write(profile_path, profile)
            self._atomic_write(self.catalog_path, catalog)
        except Exception:
            self._restore(profile_path, profile_before)
            self._restore(self.catalog_path, catalog_before)
            raise

    def _ensure_plan_locked(self, profile_id: str, catalog: dict[str, Any] | None = None) -> dict[str, Any]:
        profile = self._profile(profile_id)
        if "plan" in profile:
            return profile
        catalog = self._catalog(allow_missing=False) if catalog is None else catalog
        summary = next((item for item in catalog["profiles"] if item["profile_id"] == profile_id), None)
        if summary is None:
            raise RepositoryError("corrupt_data", "legacy profile is absent from catalog")
        try:
            profile["plan"] = self._legacy_document(profile["goals"])
        except (TypeError, ValueError) as error:
            raise RepositoryError("corrupt_data", "legacy goals cannot form a valid active document", details={"reason": str(error)}) from error
        profile["goals"] = goals_from_document(profile["plan"])
        profile["revision"] += 1
        summary["revision"] = profile["revision"]
        self._write_profile_catalog(profile, catalog)
        return profile

    def _profile_with_plan(self, profile_id: str) -> dict[str, Any]:
        profile = self._profile(profile_id)
        if "plan" in profile:
            return profile
        descriptor = self._lock()
        try:
            # Another first reader may have completed migration before this lock.
            return self._ensure_plan_locked(profile_id)
        finally:
            self._unlock(descriptor)

    def _lock(self) -> Lease:
        return acquire(self.root, RepositoryError)

    def _unlock(self, descriptor: Lease) -> None:
        release(descriptor)

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
        return {"profile_id": profile["profile_id"], "display_name": profile["display_name"], "avatar_student_id": profile.get("avatar_student_id", DEFAULT_PROFILE_AVATAR), "revision": profile["revision"], "selected": profile["profile_id"] == selected}

    @locked(RepositoryError)
    def list_profiles(self) -> dict[str, Any]:
        catalog = self._catalog()
        profiles = [
            {**item, "avatar_student_id": item.get("avatar_student_id", DEFAULT_PROFILE_AVATAR), "selected": item["profile_id"] == catalog["selected_profile_id"]}
            for item in catalog["profiles"]
        ]
        return {"profiles": sorted(profiles, key=lambda item: item["profile_id"]), "selected_profile_id": catalog["selected_profile_id"]}

    def create_profile(self, display_name: str, idempotency_key: str, avatar_student_id: str = DEFAULT_PROFILE_AVATAR) -> dict[str, Any]:
        if not isinstance(display_name, str) or not display_name.strip():
            raise RepositoryError("invalid_payload", "display_name must be non-empty")
        if not isinstance(idempotency_key, str) or not idempotency_key:
            raise RepositoryError("invalid_payload", "idempotency_key must be non-empty")
        if not isinstance(avatar_student_id, str) or not avatar_student_id.strip():
            raise RepositoryError("invalid_payload", "avatar_student_id must be non-empty")
        descriptor = self._lock()
        try:
            catalog = self._catalog()
            profile_id = hashlib.sha256(idempotency_key.encode("utf-8")).hexdigest()[:24]
            existing = next((item for item in catalog["profiles"] if item["profile_id"] == profile_id), None)
            if existing is not None:
                if existing["display_name"] != display_name.strip():
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another profile")
                if existing.get("avatar_student_id", DEFAULT_PROFILE_AVATAR) != avatar_student_id:
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another profile")
                return {"profile": {**existing, "avatar_student_id": existing.get("avatar_student_id", DEFAULT_PROFILE_AVATAR), "selected": catalog["selected_profile_id"] == profile_id}, "revision": existing["revision"]}
            if any(item["display_name"].casefold() == display_name.strip().casefold() for item in catalog["profiles"]):
                raise RepositoryError("profile_name_conflict", "profile display name already exists")
            profile = {"version": 1, "profile_id": profile_id, "revision": 0, "students": [], "inventory": {"version": 1, "catalog_revision": CATALOG_REVISION, "entries": []}, "goals": {"version": 1, "goals": []}, "idempotency": {}}
            profile["plan"] = document_from_goals(profile["goals"])
            summary = {"profile_id": profile_id, "display_name": display_name.strip(), "avatar_student_id": avatar_student_id, "revision": 0, "selected": catalog["selected_profile_id"] is None}
            if catalog["selected_profile_id"] is None:
                catalog["selected_profile_id"] = profile_id
            catalog["profiles"].append({key: summary[key] for key in ("profile_id", "display_name", "avatar_student_id", "revision")})
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

    @locked(RepositoryError)
    def current_profile(self) -> dict[str, Any]:
        catalog = self._catalog()
        selected = catalog["selected_profile_id"]
        if selected is None:
            return {"profile": None}
        summary = next((item for item in catalog["profiles"] if item["profile_id"] == selected), None)
        if summary is None:
            raise RepositoryError("corrupt_data", "selected profile is absent from catalog")
        return {"profile": {**summary, "avatar_student_id": summary.get("avatar_student_id", DEFAULT_PROFILE_AVATAR), "selected": True}}

    def _catalog_mutation(self, profile_id: str, expected_revision: int, idempotency_key: str, operation: str, mutate: Callable[[dict[str, Any], dict[str, Any]], None]) -> dict[str, Any]:
        if not isinstance(idempotency_key, str) or not idempotency_key:
            raise RepositoryError("invalid_payload", "idempotency_key must be non-empty")
        if not isinstance(expected_revision, int) or isinstance(expected_revision, bool) or expected_revision < 0:
            raise RepositoryError("invalid_payload", "expected_revision must be a non-negative integer")
        descriptor = self._lock()
        try:
            catalog = self._catalog(allow_missing=False)
            profile = self._ensure_plan_locked(profile_id, catalog)
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
            self._write_profile_catalog(profile, catalog)
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

    def update_profile(self, profile_id: str, display_name: str, avatar_student_id: str, expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        name = display_name.strip() if isinstance(display_name, str) else ""
        avatar = avatar_student_id.strip() if isinstance(avatar_student_id, str) else ""
        if not name or not avatar:
            raise RepositoryError("invalid_payload", "display_name and avatar_student_id must be non-empty")
        def mutate(catalog: dict[str, Any], _profile: dict[str, Any]) -> None:
            if any(item["profile_id"] != profile_id and item["display_name"].casefold() == name.casefold() for item in catalog["profiles"]):
                raise RepositoryError("profile_name_conflict", "profile display name already exists")
            for item in catalog["profiles"]:
                if item["profile_id"] == profile_id:
                    item["display_name"] = name
                    item["avatar_student_id"] = avatar
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"update:{name}:{avatar}", mutate)

    def delete_profile(self, profile_id: str, expected_revision: int, _idempotency_key: str) -> dict[str, Any]:
        descriptor = self._lock()
        try:
            catalog, profile = self._catalog(allow_missing=False), self._profile(profile_id)
            if profile["revision"] != expected_revision:
                raise RepositoryError("revision_conflict", "expected revision is stale", details={"current_revision": profile["revision"]})
            catalog_before = self.catalog_path.read_bytes()
            profile_path = self._profile_path(profile_id)
            profile_before = profile_path.read_bytes()
            tactical_path = self.root / "tactical" / f"{profile_id}.json"
            tactical_before = tactical_path.read_bytes() if tactical_path.exists() else None
            scenario_path = self.root / "scenarios" / f"{profile_id}.json"
            scenario_before = scenario_path.read_bytes() if scenario_path.exists() else None
            presets_path = self.root / "presets" / f"{profile_id}.json"
            presets_before = presets_path.read_bytes() if presets_path.exists() else None
            catalog["profiles"] = [item for item in catalog["profiles"] if item["profile_id"] != profile_id]
            if catalog["selected_profile_id"] == profile_id:
                catalog["selected_profile_id"] = catalog["profiles"][0]["profile_id"] if catalog["profiles"] else None
            try:
                self._atomic_write(self.catalog_path, catalog)
                profile_path.unlink()
                if tactical_before is not None:
                    tactical_path.unlink()
                if scenario_before is not None:
                    scenario_path.unlink()
                if presets_before is not None:
                    presets_path.unlink()
            except Exception as error:
                self._restore(self.catalog_path, catalog_before)
                self._restore(profile_path, profile_before)
                if tactical_before is not None:
                    self._restore(tactical_path, tactical_before)
                if scenario_before is not None:
                    self._restore(scenario_path, scenario_before)
                if presets_before is not None:
                    self._restore(presets_path, presets_before)
                if isinstance(error, RepositoryError):
                    raise
                raise RepositoryError("persistence_failed", "profile deletion failed", retryable=True) from error
            return {"revision": expected_revision + 1}
        finally:
            self._unlock(descriptor)

    @locked(RepositoryError)
    def get_state(self, profile_id: str) -> dict[str, Any]:
        profile = self._profile_with_plan(profile_id)
        return {key: profile[key] for key in ("profile_id", "revision", "students", "inventory", "goals")}

    @locked(RepositoryError)
    def get_plan(self, profile_id: str) -> dict[str, Any]:
        profile = self._profile_with_plan(profile_id)
        return {"profile_id": profile_id, "revision": profile["revision"], "document": profile["plan"], "calculation": safe_calculation_summary(profile["plan"], profile)}

    def save_plan(self, profile_id: str, document: object, expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        canonical = canonical_active_document(document)
        goals = goals_from_document(canonical)
        def mutate(_catalog: dict[str, Any], profile: dict[str, Any]) -> None:
            profile["plan"], profile["goals"] = canonical, goals
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"plan:{canonical_json(canonical)}", mutate)

    def replace_plan(self, profile_id: str, document: object, expected_revision: int, expected_scenario_revision: int, idempotency_key: str, archive_name: object, archive_description: object) -> dict[str, Any]:
        from core.scenario_store import ScenarioStore, ScenarioStoreError
        canonical = canonical_active_document(document)
        for label, revision in (("expected_revision", expected_revision), ("expected_scenario_revision", expected_scenario_revision)):
            if type(revision) is not int or revision < 0:
                raise RepositoryError("invalid_payload", f"{label} must be a non-negative integer")
        if not isinstance(idempotency_key, str) or not idempotency_key:
            raise RepositoryError("invalid_payload", "idempotency_key must be non-empty")
        try:
            name = ScenarioStore._text(archive_name, "archive_name")
            description = ScenarioStore._text(archive_description, "archive_description", allow_empty=True)
        except ScenarioStoreError as error:
            raise RepositoryError(error.code, str(error)) from error
        operation = {"type": "replace", "document": canonical, "archive_name": name, "archive_description": description, "expected_revision": expected_revision, "expected_scenario_revision": expected_scenario_revision}
        fingerprint = hashlib.sha256(canonical_json(operation).encode("utf-8")).hexdigest()
        descriptor = self._lock()
        try:
            catalog = self._catalog(allow_missing=False)
            profile = self._ensure_plan_locked(profile_id, catalog)
            cached = profile["idempotency"].get(idempotency_key)
            if cached:
                if cached["fingerprint"] != fingerprint:
                    raise RepositoryError("idempotency_conflict", "idempotency key was used for another mutation")
                return cached["response"]
            store = ScenarioStore(self.root, profile_revision=lambda _pid: profile["revision"], id_factory=self._id_factory)
            try:
                collection = store._read(profile_id)
                profile_stale = profile["revision"] != expected_revision
                scenario_stale = collection["revision"] != expected_scenario_revision
                if profile_stale or scenario_stale:
                    scope = "both" if profile_stale and scenario_stale else "profile" if profile_stale else "scenario"
                    raise RepositoryError("revision_conflict", "plan replacement revisions are stale", details={"revision_scope": scope, "current_revision": profile["revision"], "current_scenario_revision": collection["revision"]})
                archived_id = None
                if profile["plan"]["phases"]:
                    archived_id = store._append_record(collection, name, description, profile["revision"], {**profile["plan"], "kind": "scenario"}, archive=True)
                    collection["revision"] += 1
            except ScenarioStoreError as error:
                raise RepositoryError(error.code, str(error), retryable=error.retryable, details=error.details) from error
            profile["revision"] += 1
            profile["plan"], profile["goals"] = canonical, goals_from_document(canonical)
            response = {"revision": profile["revision"], "scenario_revision": collection["revision"], "archived_scenario_id": archived_id}
            profile["idempotency"][idempotency_key] = {"fingerprint": fingerprint, "response": response}
            for summary in catalog["profiles"]:
                if summary["profile_id"] == profile_id:
                    summary["revision"] = profile["revision"]
            writes = [(self._profile_path(profile_id), profile), (self.catalog_path, catalog)]
            if archived_id is not None:
                writes.append((store._path(profile_id), collection))
            write_transaction(self.root, writes, self._atomic_write, self._fault, RepositoryError)
            return response
        finally:
            self._unlock(descriptor)

    def update_students(self, profile_id: str, students: list[dict[str, Any]], expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        canonical = [ConfirmedStudent.from_dict(item).to_dict() for item in students]
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"students:{canonical_json(canonical)}", lambda _c, p: p.__setitem__("students", canonical))

    def update_inventory(self, profile_id: str, inventory: dict[str, Any], expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        canonical = rebase_inventory_snapshot(inventory)
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"inventory:{canonical_json(canonical)}", lambda _c, p: p.__setitem__("inventory", canonical))

    def save_goals(self, profile_id: str, goals: dict[str, Any], expected_revision: int, idempotency_key: str) -> dict[str, Any]:
        if not isinstance(goals, dict) or goals.get("version") != 1 or not isinstance(goals.get("goals"), list) or set(goals) != {"version", "goals"}:
            raise RepositoryError("invalid_payload", "goals must be a version 1 goal plan")
        document = self._legacy_document(goals)
        canonical = goals_from_document(document)
        def mutate(_catalog: dict[str, Any], profile: dict[str, Any]) -> None:
            reasons = legacy_write_loss(profile["plan"])
            if reasons:
                raise RepositoryError("plan_lossy_write", "legacy goals writer would discard active document structure or bond targets", details={"reasons": reasons})
            profile["plan"], profile["goals"] = document, canonical
        return self._catalog_mutation(profile_id, expected_revision, idempotency_key, f"goals:{canonical_json(canonical)}", mutate)

    @staticmethod
    def migration_preview(source_path: str) -> dict[str, Any]:
        try:
            accounts = load_v6_accounts(Path(source_path))
        except V6MigrationError as error:
            raise RepositoryError("migration_source_invalid", str(error)) from error
        return {"accounts": [account.preview() for account in accounts]}

    def import_v6_profile(self, source_path: str, source_profile_key: str) -> dict[str, Any]:
        try:
            accounts = load_v6_accounts(Path(source_path))
        except V6MigrationError as error:
            raise RepositoryError("migration_source_invalid", str(error)) from error
        account = next((item for item in accounts if item.profile_key == source_profile_key), None)
        if account is None:
            raise RepositoryError("migration_source_invalid", "v6 profile was not found")
        document = self._legacy_document(account.goals)

        descriptor = self._lock()
        profile_path: Path | None = None
        catalog_before: bytes | None = None
        try:
            catalog = self._catalog()
            catalog_before = self.catalog_path.read_bytes() if self.catalog_path.exists() else None
            existing_names = {str(item["display_name"]).casefold() for item in catalog["profiles"]}
            base_name = account.display_name
            display_name = base_name
            if display_name.casefold() in existing_names:
                display_name = f"{base_name} (v6 가져오기)"
                suffix = 2
                while display_name.casefold() in existing_names:
                    display_name = f"{base_name} (v6 가져오기 {suffix})"
                    suffix += 1
            existing_ids = {str(item["profile_id"]) for item in catalog["profiles"]}
            profile_id = ""
            for _attempt in range(16):
                candidate = self._id_factory()[:24].lower()
                if re.fullmatch(r"[0-9a-f]{24}", candidate) is None:
                    raise RepositoryError("persistence_failed", "profile ID factory returned an invalid ID")
                if candidate not in existing_ids and not self._profile_path(candidate).exists():
                    profile_id = candidate
                    break
            if not profile_id:
                raise RepositoryError("persistence_failed", "could not allocate a unique profile ID")
            profile = {
                "version": STORE_VERSION,
                "profile_id": profile_id,
                "revision": 0,
                "students": list(account.students),
                "inventory": account.inventory,
                "goals": goals_from_document(document),
                "plan": document,
                "idempotency": {},
            }
            summary = {
                "profile_id": profile_id,
                "display_name": display_name,
                "avatar_student_id": account.avatar_student_id,
                "revision": 0,
            }
            catalog["profiles"].append(summary)
            catalog["selected_profile_id"] = profile_id
            profile_path = self._profile_path(profile_id)
            self._atomic_write(profile_path, profile)
            try:
                self._atomic_write(self.catalog_path, catalog)
            except Exception:
                profile_path.unlink(missing_ok=True)
                raise
            return {
                "profile": {**summary, "selected": True},
                "student_count": len(account.students),
                "inventory_count": len(account.inventory["entries"]),
                "goal_count": len(account.goals["goals"]),
                "warnings": list(account.warnings),
            }
        except Exception as error:
            if catalog_before is not None:
                self.catalog_path.write_bytes(catalog_before)
            elif self.catalog_path.exists():
                self.catalog_path.unlink(missing_ok=True)
            if profile_path is not None:
                profile_path.unlink(missing_ok=True)
            if isinstance(error, RepositoryError):
                raise
            raise RepositoryError("persistence_failed", "v6 profile import failed", details={"reason": type(error).__name__}) from error
        finally:
            self._unlock(descriptor)

    @staticmethod
    def resolve_inventory_input(sqlite_rows: list[dict[str, Any]] | None, json_snapshot: dict[str, dict[str, Any]] | list[dict[str, Any]] | None, *, sqlite_error: str | None = None) -> dict[str, Any]:
        resolved = resolve_inventory_snapshot(sqlite_rows, json_snapshot, sqlite_error=sqlite_error)
        entries = [dict(entry) for entry in resolved.snapshot.values()]
        return {"inventory": {"version": 1, "entries": entries}, "source": resolved.source, "sqlite_error": resolved.sqlite_error}
