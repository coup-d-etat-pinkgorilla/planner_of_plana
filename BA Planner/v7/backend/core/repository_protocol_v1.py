from __future__ import annotations

from pathlib import Path
from typing import Any

from core.repository_store import JsonRepository, RepositoryError


METHODS = frozenset({
    "repository.profile.list", "repository.profile.create", "repository.profile.current",
    "repository.profile.select", "repository.profile.rename", "repository.state.get",
    "repository.students.update", "repository.inventory.update", "repository.goals.save",
    "repository.migration.preview",
})


def _response(request: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
    return {"protocol": 1, "id": request["id"], "type": "response", "method": request["method"], "payload": payload}


def _require(data: object, keys: set[str]) -> dict[str, Any]:
    if not isinstance(data, dict) or set(data) != keys:
        raise RepositoryError("invalid_payload", f"payload must contain exactly {sorted(keys)}")
    return data


def _text(value: object, name: str) -> str:
    if not isinstance(value, str) or not value:
        raise RepositoryError("invalid_payload", f"{name} must be a non-empty string")
    return value


def _revision(value: object) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise RepositoryError("invalid_payload", "expected_revision must be a non-negative integer")
    return value


class RepositoryProtocolV1:
    def __init__(self, repository: JsonRepository) -> None:
        self.repository = repository

    def handle(self, request: dict[str, Any]) -> dict[str, Any]:
        try:
            payload = self._dispatch(request["method"], request["payload"])
            return _response(request, payload)
        except RepositoryError as error:
            wire = {"code": error.code, "message": str(error), "retryable": error.retryable}
            if error.details:
                wire["details"] = error.details
            return _response(request, {"error": wire})
        except (TypeError, ValueError) as error:
            return _response(request, {"error": {"code": "invalid_payload", "message": str(error), "retryable": False}})

    def _mutation(self, value: object, extra: set[str]) -> tuple[dict[str, Any], str, int, str]:
        data = _require(value, {"profile_id", "expected_revision", "idempotency_key"} | extra)
        return data, _text(data["profile_id"], "profile_id"), _revision(data["expected_revision"]), _text(data["idempotency_key"], "idempotency_key")

    def _dispatch(self, method: str, payload: object) -> dict[str, Any]:
        if method == "repository.profile.list":
            _require(payload, set())
            return self.repository.list_profiles()
        if method == "repository.profile.current":
            _require(payload, set())
            return self.repository.current_profile()
        if method == "repository.profile.create":
            data = _require(payload, {"display_name", "idempotency_key"})
            return self.repository.create_profile(_text(data["display_name"], "display_name"), _text(data["idempotency_key"], "idempotency_key"))
        if method == "repository.profile.select":
            data, profile_id, revision, key = self._mutation(payload, set())
            return self.repository.select_profile(profile_id, revision, key)
        if method == "repository.profile.rename":
            data, profile_id, revision, key = self._mutation(payload, {"display_name"})
            return self.repository.rename_profile(profile_id, _text(data["display_name"], "display_name"), revision, key)
        if method == "repository.state.get":
            data = _require(payload, {"profile_id"})
            return self.repository.get_state(_text(data["profile_id"], "profile_id"))
        if method == "repository.students.update":
            data, profile_id, revision, key = self._mutation(payload, {"students"})
            if not isinstance(data["students"], list): raise RepositoryError("invalid_payload", "students must be an array")
            return self.repository.update_students(profile_id, data["students"], revision, key)
        if method == "repository.inventory.update":
            data, profile_id, revision, key = self._mutation(payload, {"inventory"})
            return self.repository.update_inventory(profile_id, data["inventory"], revision, key)
        if method == "repository.goals.save":
            data, profile_id, revision, key = self._mutation(payload, {"goals"})
            return self.repository.save_goals(profile_id, data["goals"], revision, key)
        if method == "repository.migration.preview":
            data = _require(payload, {"source_path", "profile_id"})
            return self.repository.migration_preview(_text(data["source_path"], "source_path"), _text(data["profile_id"], "profile_id"))
        raise RepositoryError("unknown_method", f"Unknown repository method: {method}")
