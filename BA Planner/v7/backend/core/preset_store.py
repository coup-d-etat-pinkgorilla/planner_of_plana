"""Profile-scoped presets: independent collection revision and one atomic file."""
from __future__ import annotations

import hashlib
import re
from typing import Any

from core.planning_document import PlanningDocumentError, planning_targets_from_wire
from core.repository_dto import canonical_json
from core.repository_store import JsonRepository, RepositoryError
from core.repository_transaction import locked

LIMITS = {
    "stage_presets": 100, "stages_per_preset": 50, "total_stages": 1000,
    "student_groups": 100, "students_per_group": 1000, "total_memberships": 10000,
    "name_length": 120, "id_length": 128,
}


def _text(value: object, label: str, *, name: bool = False) -> str:
    maximum = LIMITS["name_length" if name else "id_length"]
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise ValueError(f"{label} requires non-blank text of at most {maximum} code points")
    return value.strip() if name else value


def _array(value: object, label: str, maximum: int) -> list:
    if not isinstance(value, list) or len(value) > maximum:
        raise ValueError(f"{label} requires an array of at most {maximum} entries")
    return value


def _shape(value: object, keys: set[str], label: str) -> dict:
    if not isinstance(value, dict) or set(value) != keys:
        raise ValueError(f"{label} has an invalid shape")
    return value


def preset_bundle_from_wire(stage_presets: object, student_groups: object) -> dict[str, list]:
    """Validate/copy without current-state expansion or catalog filtering."""
    presets, groups = [], []
    preset_ids, group_ids = set(), set()
    total_stages = total_memberships = 0
    for index, item in enumerate(_array(stage_presets, "stage_presets", LIMITS["stage_presets"])):
        label = f"stage_presets[{index}]"
        raw = _shape(item, {"preset_id", "name", "stages"}, label)
        preset_id = _text(raw["preset_id"], f"{label}.preset_id")
        if preset_id in preset_ids:
            raise ValueError("preset IDs must be unique")
        preset_ids.add(preset_id)
        stages, previous = [], None
        for stage_index, item in enumerate(_array(raw["stages"], f"{label}.stages", LIMITS["stages_per_preset"])):
            stage_label = f"{label}.stages[{stage_index}]"
            stage = _shape(item, {"name", "targets"}, stage_label)
            targets = planning_targets_from_wire(stage["targets"], label=stage_label, nullable=True, previous=previous)
            stages.append({"name": _text(stage["name"], f"{stage_label}.name", name=True), "targets": targets})
            previous = targets
        total_stages += len(stages)
        if total_stages > LIMITS["total_stages"]:
            raise ValueError("total preset stages exceed 1000")
        presets.append({"preset_id": preset_id, "name": _text(raw["name"], f"{label}.name", name=True), "stages": stages})
    for index, item in enumerate(_array(student_groups, "student_groups", LIMITS["student_groups"])):
        label = f"student_groups[{index}]"
        raw = _shape(item, {"group_id", "name", "student_ids"}, label)
        group_id = _text(raw["group_id"], f"{label}.group_id")
        if group_id in group_ids:
            raise ValueError("group IDs must be unique")
        group_ids.add(group_id)
        student_ids = [_text(item, f"{label}.student_ids") for item in _array(raw["student_ids"], f"{label}.student_ids", LIMITS["students_per_group"])]
        if len(set(student_ids)) != len(student_ids):
            raise ValueError("student IDs within a group must be unique")
        total_memberships += len(student_ids)
        if total_memberships > LIMITS["total_memberships"]:
            raise ValueError("total group memberships exceed 10000")
        groups.append({"group_id": group_id, "name": _text(raw["name"], f"{label}.name", name=True), "student_ids": student_ids})
    return {"stage_presets": presets, "student_groups": groups}


class PresetStore:
    def __init__(self, repository: JsonRepository) -> None:
        self.repository = repository
        self.root = repository.root

    def _read(self, profile_id: str) -> dict[str, Any]:
        # Raw profile validation deliberately avoids first-load plan migration.
        self.repository._profile(profile_id)
        path = self.root / "presets" / f"{profile_id}.json"
        if not path.exists():
            return {"version": 1, "profile_id": profile_id, "revision": 0,
                    "stage_presets": [], "student_groups": [], "idempotency": {}}
        raw = self.repository._read(path, "preset collection")
        try:
            _shape(raw, {"version", "profile_id", "revision", "stage_presets", "student_groups", "idempotency"}, "preset collection")
            if raw["profile_id"] != profile_id or type(raw["revision"]) is not int or raw["revision"] < 0:
                raise ValueError("invalid collection identity or revision")
            bundle = preset_bundle_from_wire(raw["stage_presets"], raw["student_groups"])
            if not isinstance(raw["idempotency"], dict):
                raise ValueError("invalid collection idempotency")
            for key, record in raw["idempotency"].items():
                if not isinstance(key, str) or not key:
                    raise ValueError("invalid idempotency key")
                _shape(record, {"fingerprint", "response"}, "idempotency record")
                if not isinstance(record["fingerprint"], str) or re.fullmatch(r"[0-9a-f]{64}", record["fingerprint"]) is None:
                    raise ValueError("invalid idempotency fingerprint")
                response = _shape(record["response"], {"revision"}, "idempotency response")
                if type(response["revision"]) is not int or not 1 <= response["revision"] <= raw["revision"]:
                    raise ValueError("invalid idempotency revision")
            return {**raw, **bundle}
        except (ValueError, PlanningDocumentError) as error:
            raise RepositoryError("corrupt_data", str(error)) from error

    @locked(RepositoryError)
    def get(self, profile_id: str) -> dict[str, Any]:
        value = self._read(profile_id)
        return {key: value[key] for key in ("profile_id", "revision", "stage_presets", "student_groups")}

    @locked(RepositoryError)
    def save(self, profile_id: str, expected_revision: int, idempotency_key: str,
             stage_presets: object, student_groups: object) -> dict[str, int]:
        if type(expected_revision) is not int or expected_revision < 0 or not isinstance(idempotency_key, str) or not idempotency_key:
            raise RepositoryError("invalid_payload", "invalid expected_revision or idempotency_key")
        try:
            bundle = preset_bundle_from_wire(stage_presets, student_groups)
        except (ValueError, PlanningDocumentError) as error:
            raise RepositoryError("invalid_payload", str(error)) from error
        fingerprint = hashlib.sha256(canonical_json({"operation": "presets.save", "expected_revision": expected_revision, **bundle}).encode("utf-8")).hexdigest()
        value = self._read(profile_id)
        cached = value["idempotency"].get(idempotency_key)
        if cached is not None:
            if cached["fingerprint"] != fingerprint:
                raise RepositoryError("idempotency_conflict", "idempotency key was used for another preset save")
            return dict(cached["response"])
        if value["revision"] != expected_revision:
            raise RepositoryError("revision_conflict", "expected preset revision is stale", details={"current_revision": value["revision"]})
        response = {"revision": expected_revision + 1}
        value.update(bundle, revision=response["revision"])
        value["idempotency"][idempotency_key] = {"fingerprint": fingerprint, "response": response}
        try:
            self.repository._atomic_write(self.root / "presets" / f"{profile_id}.json", value)
        except OSError as error:
            raise RepositoryError("persistence_failed", "preset collection write failed", retryable=True) from error
        return response
