from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path
import re
from types import SimpleNamespace
from typing import Any, Callable
import uuid

from core.planning_document import (
    PlanningDocumentError,
    calculate_document_projection,
    planning_document_from_wire,
    planning_document_to_wire,
)
from core.repository_dto import ConfirmedStudent, InventorySnapshot, canonical_json


STORE_VERSION = 1
_ID = re.compile(r"[0-9a-f]{24}")


class ScenarioStoreError(RuntimeError):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        retryable: bool = False,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.retryable = retryable
        self.details = details or {}


def _default_clock() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class ScenarioStore:
    """Profile-scoped hypothetical goals stored outside the active plan bucket."""

    def __init__(
        self,
        root: Path,
        *,
        profile_revision: Callable[[str], int],
        profile_state: Callable[[str], dict[str, Any]] | None = None,
        id_factory: Callable[[], str] | None = None,
        clock: Callable[[], str] | None = None,
        fault: Callable[[str], None] | None = None,
    ) -> None:
        self.root = Path(root)
        self._profile_revision = profile_revision
        self._profile_state = profile_state
        self._id_factory = id_factory or (lambda: uuid.uuid4().hex)
        self._clock = clock or _default_clock
        self._fault = fault or (lambda _stage: None)

    def _path(self, profile_id: str) -> Path:
        if not isinstance(profile_id, str) or _ID.fullmatch(profile_id) is None:
            raise ScenarioStoreError("invalid_payload", "profile_id must be a canonical 24-character ID")
        return self.root / "scenarios" / f"{profile_id}.json"

    @staticmethod
    def _integer(value: object, label: str, *, corrupt: bool = False) -> int:
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            code = "corrupt_data" if corrupt else "invalid_payload"
            raise ScenarioStoreError(code, f"{label} must be a non-negative integer")
        return value

    @staticmethod
    def _text(value: object, label: str, *, allow_empty: bool = False) -> str:
        if not isinstance(value, str) or (not allow_empty and not value.strip()):
            raise ScenarioStoreError("invalid_payload", f"{label} must be a {'string' if allow_empty else 'non-empty string'}")
        return value.strip() if not allow_empty else value.strip()

    def _profile_current_revision(self, profile_id: str) -> int:
        try:
            revision = self._profile_revision(profile_id)
        except Exception as error:
            code = getattr(error, "code", "profile_not_found")
            raise ScenarioStoreError(code, str(error)) from error
        return self._integer(revision, "profile revision", corrupt=True)

    def _empty(self, profile_id: str) -> dict[str, Any]:
        return {
            "version": STORE_VERSION,
            "profile_id": profile_id,
            "revision": 0,
            "scenarios": [],
            "idempotency": {},
        }

    def _read(self, profile_id: str) -> dict[str, Any]:
        self._profile_current_revision(profile_id)
        path = self._path(profile_id)
        if not path.exists():
            return self._empty(profile_id)
        try:
            import json

            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, ValueError) as error:
            raise ScenarioStoreError("corrupt_data", "scenario collection cannot be read") from error
        if not isinstance(value, dict) or set(value) != {"version", "profile_id", "revision", "scenarios", "idempotency"}:
            raise ScenarioStoreError("corrupt_data", "scenario collection has an invalid shape")
        if value["version"] != STORE_VERSION or isinstance(value["version"], bool):
            raise ScenarioStoreError("migration_required", "scenario collection has an unsupported version")
        if value["profile_id"] != profile_id:
            raise ScenarioStoreError("corrupt_data", "scenario collection belongs to another profile")
        revision = self._integer(value["revision"], "scenario collection revision", corrupt=True)
        if not isinstance(value["scenarios"], list) or not isinstance(value["idempotency"], dict):
            raise ScenarioStoreError("corrupt_data", "scenario collection has invalid members")
        ids: set[str] = set()
        for item in value["scenarios"]:
            self._validate_record(item, profile_id, corrupt=True)
            if item["scenario_id"] in ids:
                raise ScenarioStoreError("corrupt_data", "scenario IDs must be unique")
            ids.add(item["scenario_id"])
        for key, item in value["idempotency"].items():
            if (
                not isinstance(key, str)
                or not key
                or not isinstance(item, dict)
                or set(item) != {"fingerprint", "response"}
                or not isinstance(item["fingerprint"], str)
                or re.fullmatch(r"[0-9a-f]{64}", item["fingerprint"]) is None
                or not isinstance(item["response"], dict)
                or set(item["response"]) != {"revision", "scenario_id"}
            ):
                raise ScenarioStoreError("corrupt_data", "scenario collection has invalid idempotency data")
            cached_revision = self._integer(item["response"]["revision"], "cached scenario revision", corrupt=True)
            if cached_revision > revision or not isinstance(item["response"]["scenario_id"], str):
                raise ScenarioStoreError("corrupt_data", "scenario idempotency response is invalid")
        return value

    def _validate_record(self, value: object, profile_id: str, *, corrupt: bool = False) -> dict[str, Any]:
        code = "corrupt_data" if corrupt else "invalid_payload"
        required = {
            "version", "scenario_id", "revision", "profile_id", "name", "description",
            "base_profile_revision", "document", "created_at", "updated_at",
        }
        if not isinstance(value, dict) or set(value) != required or value.get("version") != 1:
            raise ScenarioStoreError(code, "scenario record has an invalid shape")
        if not isinstance(value["scenario_id"], str) or _ID.fullmatch(value["scenario_id"]) is None:
            raise ScenarioStoreError(code, "scenario_id is invalid")
        if value["profile_id"] != profile_id:
            raise ScenarioStoreError(code, "scenario record belongs to another profile")
        self._integer(value["revision"], "scenario revision", corrupt=corrupt)
        self._integer(value["base_profile_revision"], "base profile revision", corrupt=corrupt)
        if not isinstance(value["name"], str) or not value["name"].strip():
            raise ScenarioStoreError(code, "scenario name must be non-empty")
        if not isinstance(value["description"], str):
            raise ScenarioStoreError(code, "scenario description must be a string")
        if not all(isinstance(value[key], str) and value[key] for key in ("created_at", "updated_at")):
            raise ScenarioStoreError(code, "scenario timestamps must be non-empty strings")
        try:
            document = planning_document_from_wire(value["document"])
        except PlanningDocumentError as error:
            raise ScenarioStoreError(code, f"scenario document is invalid: {error}") from error
        if document.kind != "scenario":
            raise ScenarioStoreError(code, "scenario document kind must be scenario")
        return value

    def _canonical_document(self, value: object) -> dict[str, Any]:
        try:
            document = planning_document_from_wire(value)
        except PlanningDocumentError as error:
            raise ScenarioStoreError("invalid_payload", str(error)) from error
        if document.kind != "scenario":
            raise ScenarioStoreError("invalid_payload", "scenario document kind must be scenario")
        return planning_document_to_wire(document)

    def _lock(self) -> int:
        self.root.mkdir(parents=True, exist_ok=True)
        try:
            return os.open(self.root / ".repository.lock", os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError as error:
            raise ScenarioStoreError("repository_busy", "another repository writer holds the lock", retryable=True) from error

    def _unlock(self, descriptor: int) -> None:
        os.close(descriptor)
        (self.root / ".repository.lock").unlink(missing_ok=True)

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
            raise ScenarioStoreError("persistence_failed", "scenario write failed", retryable=True) from error

    def _calculation_summary(
        self,
        item: dict[str, Any],
        state: dict[str, Any] | None,
    ) -> dict[str, Any] | None:
        if state is None:
            return None
        students = [ConfirmedStudent.from_dict(value) for value in state["students"]]
        records = {
            student.student_id: SimpleNamespace(
                student_id=student.student_id,
                **student.values,
            )
            for student in students
        }
        inventory = InventorySnapshot.from_dict(state["inventory"])
        document = planning_document_from_wire(item["document"])
        projection = calculate_document_projection(records, document, inventory)
        resources = projection["overall"]["resources"]
        known_shortages = [
            resource
            for resource in resources
            if resource["shortage"] is not None and resource["shortage"] > 0
        ]
        representative = max(
            known_shortages,
            key=lambda resource: (resource["shortage"], resource["display_name"]),
            default=None,
        )
        bottlenecks = projection["bottlenecks"]
        return {
            "credits": int(projection["overall"]["cost"]["credits"]),
            "required_resource_type_count": len(resources),
            "known_shortage_type_count": len(known_shortages),
            "inventory_complete": all(resource["owned"] is not None for resource in resources),
            "first_bottleneck_phase_number": (
                int(bottlenecks[0]["phase_number"]) if bottlenecks else None
            ),
            "representative_shortage": None if representative is None else {
                "resource_key": representative["resource_key"],
                "item_id": representative["item_id"],
                "display_name": representative["display_name"],
                "category": representative["category"],
                "shortage": int(representative["shortage"]),
            },
        }

    def _safe_calculation_summary(
        self,
        item: dict[str, Any],
        state: dict[str, Any] | None,
    ) -> dict[str, Any] | None:
        try:
            return self._calculation_summary(item, state)
        except Exception:
            # Calculation is derived list data. Keep the persisted scenario
            # discoverable when current-state projection is temporarily unavailable.
            return None

    def _summary(
        self,
        item: dict[str, Any],
        state: dict[str, Any] | None,
    ) -> dict[str, Any]:
        stages = [stage for phase in item["document"]["phases"] for stage in phase["stages"]]
        student_ids = list(dict.fromkeys(stage["student_id"] for stage in stages))
        return {
            "scenario_id": item["scenario_id"],
            "revision": item["revision"],
            "name": item["name"],
            "description": item["description"],
            "base_profile_revision": item["base_profile_revision"],
            "phase_count": len(item["document"]["phases"]),
            "stage_count": len(stages),
            "student_count": len(student_ids),
            "student_ids": student_ids,
            "calculation": self._safe_calculation_summary(item, state),
            "created_at": item["created_at"],
            "updated_at": item["updated_at"],
        }

    def list(self, profile_id: str) -> dict[str, Any]:
        collection = self._read(profile_id)
        state = self._profile_state(profile_id) if self._profile_state is not None else None
        return {
            "profile_id": profile_id,
            "revision": collection["revision"],
            "current_profile_revision": self._profile_current_revision(profile_id),
            "scenarios": [self._summary(item, state) for item in collection["scenarios"]],
        }

    def get(self, profile_id: str, scenario_id: str) -> dict[str, Any]:
        collection = self._read(profile_id)
        item = self._find(collection, scenario_id)
        return {
            "profile_id": profile_id,
            "revision": collection["revision"],
            "current_profile_revision": self._profile_current_revision(profile_id),
            "scenario": item,
        }

    @staticmethod
    def _find(collection: dict[str, Any], scenario_id: str) -> dict[str, Any]:
        if not isinstance(scenario_id, str) or _ID.fullmatch(scenario_id) is None:
            raise ScenarioStoreError("invalid_payload", "scenario_id must be a canonical 24-character ID")
        item = next((item for item in collection["scenarios"] if item["scenario_id"] == scenario_id), None)
        if item is None:
            raise ScenarioStoreError("scenario_not_found", "scenario does not exist")
        return item

    def _new_id(self, collection: dict[str, Any]) -> str:
        existing = {item["scenario_id"] for item in collection["scenarios"]}
        for _attempt in range(16):
            candidate = self._id_factory()[:24].lower()
            if _ID.fullmatch(candidate) is None:
                raise ScenarioStoreError("persistence_failed", "scenario ID factory returned an invalid ID")
            if candidate not in existing:
                return candidate
        raise ScenarioStoreError("persistence_failed", "could not allocate a unique scenario ID")

    def _mutate(
        self,
        profile_id: str,
        expected_revision: int,
        idempotency_key: str,
        operation: dict[str, Any],
        callback: Callable[[dict[str, Any]], str],
    ) -> dict[str, Any]:
        self._integer(expected_revision, "expected_revision")
        if not isinstance(idempotency_key, str) or not idempotency_key:
            raise ScenarioStoreError("invalid_payload", "idempotency_key must be non-empty")
        descriptor = self._lock()
        try:
            collection = self._read(profile_id)
            fingerprint = hashlib.sha256(canonical_json({"operation": operation, "expected_revision": expected_revision}).encode()).hexdigest()
            cached = collection["idempotency"].get(idempotency_key)
            if cached:
                if cached["fingerprint"] != fingerprint:
                    raise ScenarioStoreError("idempotency_conflict", "idempotency key was used for another scenario mutation")
                return cached["response"]
            if collection["revision"] != expected_revision:
                raise ScenarioStoreError("revision_conflict", "scenario collection revision is stale", details={"current_revision": collection["revision"]})
            scenario_id = callback(collection)
            collection["revision"] += 1
            response = {"revision": collection["revision"], "scenario_id": scenario_id}
            collection["idempotency"][idempotency_key] = {"fingerprint": fingerprint, "response": response}
            self._write(self._path(profile_id), collection)
            return response
        finally:
            self._unlock(descriptor)

    def create(
        self,
        profile_id: str,
        expected_revision: int,
        idempotency_key: str,
        name: object,
        description: object,
        base_profile_revision: object,
        document: object,
    ) -> dict[str, Any]:
        canonical_name = self._text(name, "name")
        canonical_description = self._text(description, "description", allow_empty=True)
        base_revision = self._integer(base_profile_revision, "base_profile_revision")
        canonical_document = self._canonical_document(document)

        def callback(collection: dict[str, Any]) -> str:
            current_profile_revision = self._profile_current_revision(profile_id)
            if base_revision > current_profile_revision:
                raise ScenarioStoreError("invalid_payload", "base_profile_revision cannot be newer than the profile")
            scenario_id = self._new_id(collection)
            now = self._clock()
            collection["scenarios"].append({
                "version": 1,
                "scenario_id": scenario_id,
                "revision": 0,
                "profile_id": profile_id,
                "name": canonical_name,
                "description": canonical_description,
                "base_profile_revision": base_revision,
                "document": canonical_document,
                "created_at": now,
                "updated_at": now,
            })
            return scenario_id

        return self._mutate(profile_id, expected_revision, idempotency_key, {
            "type": "create", "name": canonical_name, "description": canonical_description,
            "base_profile_revision": base_revision, "document": canonical_document,
        }, callback)

    def update(
        self,
        profile_id: str,
        scenario_id: str,
        expected_revision: int,
        expected_scenario_revision: int,
        idempotency_key: str,
        name: object,
        description: object,
        base_profile_revision: object,
        document: object,
    ) -> dict[str, Any]:
        canonical_name = self._text(name, "name")
        canonical_description = self._text(description, "description", allow_empty=True)
        base_revision = self._integer(base_profile_revision, "base_profile_revision")
        scenario_revision = self._integer(expected_scenario_revision, "expected_scenario_revision")
        canonical_document = self._canonical_document(document)

        def callback(collection: dict[str, Any]) -> str:
            item = self._find(collection, scenario_id)
            if item["revision"] != scenario_revision:
                raise ScenarioStoreError("revision_conflict", "scenario revision is stale", details={"current_scenario_revision": item["revision"]})
            current_profile_revision = self._profile_current_revision(profile_id)
            if base_revision > current_profile_revision:
                raise ScenarioStoreError("invalid_payload", "base_profile_revision cannot be newer than the profile")
            item.update({
                "revision": item["revision"] + 1,
                "name": canonical_name,
                "description": canonical_description,
                "base_profile_revision": base_revision,
                "document": canonical_document,
                "updated_at": self._clock(),
            })
            return scenario_id

        return self._mutate(profile_id, expected_revision, idempotency_key, {
            "type": "update", "scenario_id": scenario_id, "expected_scenario_revision": scenario_revision,
            "name": canonical_name, "description": canonical_description,
            "base_profile_revision": base_revision, "document": canonical_document,
        }, callback)

    def delete(
        self,
        profile_id: str,
        scenario_id: str,
        expected_revision: int,
        expected_scenario_revision: int,
        idempotency_key: str,
    ) -> dict[str, Any]:
        scenario_revision = self._integer(expected_scenario_revision, "expected_scenario_revision")

        def callback(collection: dict[str, Any]) -> str:
            item = self._find(collection, scenario_id)
            if item["revision"] != scenario_revision:
                raise ScenarioStoreError("revision_conflict", "scenario revision is stale", details={"current_scenario_revision": item["revision"]})
            collection["scenarios"].remove(item)
            return scenario_id

        return self._mutate(profile_id, expected_revision, idempotency_key, {
            "type": "delete", "scenario_id": scenario_id,
            "expected_scenario_revision": scenario_revision,
        }, callback)

    def duplicate(
        self,
        profile_id: str,
        scenario_id: str,
        expected_revision: int,
        expected_scenario_revision: int,
        idempotency_key: str,
    ) -> dict[str, Any]:
        scenario_revision = self._integer(expected_scenario_revision, "expected_scenario_revision")

        def callback(collection: dict[str, Any]) -> str:
            source = self._find(collection, scenario_id)
            if source["revision"] != scenario_revision:
                raise ScenarioStoreError("revision_conflict", "scenario revision is stale", details={"current_scenario_revision": source["revision"]})
            scenario_id_new = self._new_id(collection)
            existing_names = {item["name"].casefold() for item in collection["scenarios"]}
            base_name = f'{source["name"]} (복사본)'
            name = base_name
            suffix = 2
            while name.casefold() in existing_names:
                name = f'{source["name"]} (복사본 {suffix})'
                suffix += 1
            now = self._clock()
            collection["scenarios"].append({
                **source,
                "scenario_id": scenario_id_new,
                "revision": 0,
                "name": name,
                "document": {**source["document"], "document_id": scenario_id_new, "name": name},
                "created_at": now,
                "updated_at": now,
            })
            return scenario_id_new

        return self._mutate(profile_id, expected_revision, idempotency_key, {
            "type": "duplicate", "scenario_id": scenario_id,
            "expected_scenario_revision": scenario_revision,
        }, callback)
