from __future__ import annotations

from typing import Any

from core.scenario_store import ScenarioStore, ScenarioStoreError


METHODS = frozenset({
    "repository.scenario.list",
    "repository.scenario.get",
    "repository.scenario.create",
    "repository.scenario.update",
    "repository.scenario.delete",
    "repository.scenario.duplicate",
})


def _response(request: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "protocol": 1,
        "id": request["id"],
        "type": "response",
        "method": request["method"],
        "payload": payload,
    }


def _require(value: object, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise ScenarioStoreError("invalid_payload", f"payload must contain exactly {sorted(keys)}")
    return value


def _text(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ScenarioStoreError("invalid_payload", f"{label} must be a non-empty string")
    return value


def _revision(value: object, label: str = "expected_revision") -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise ScenarioStoreError("invalid_payload", f"{label} must be a non-negative integer")
    return value


class ScenarioProtocolV1:
    def __init__(self, store: ScenarioStore) -> None:
        self.store = store

    def handle(self, request: dict[str, Any]) -> dict[str, Any]:
        try:
            return _response(request, self._dispatch(request["method"], request["payload"]))
        except ScenarioStoreError as error:
            wire = {"code": error.code, "message": str(error), "retryable": error.retryable}
            if error.details:
                wire["details"] = error.details
            return _response(request, {"error": wire})

    def _dispatch(self, method: str, payload: object) -> dict[str, Any]:
        if method == "repository.scenario.list":
            data = _require(payload, {"profile_id"})
            return self.store.list(_text(data["profile_id"], "profile_id"))
        if method == "repository.scenario.get":
            data = _require(payload, {"profile_id", "scenario_id"})
            return self.store.get(
                _text(data["profile_id"], "profile_id"),
                _text(data["scenario_id"], "scenario_id"),
            )
        common = {"profile_id", "expected_revision", "idempotency_key"}
        if method == "repository.scenario.create":
            data = _require(payload, common | {"name", "description", "base_profile_revision", "document"})
            return self.store.create(
                _text(data["profile_id"], "profile_id"),
                _revision(data["expected_revision"]),
                _text(data["idempotency_key"], "idempotency_key"),
                data["name"], data["description"], data["base_profile_revision"], data["document"],
            )
        mutation = common | {"scenario_id", "expected_scenario_revision"}
        if method == "repository.scenario.update":
            data = _require(payload, mutation | {"name", "description", "base_profile_revision", "document"})
            return self.store.update(
                _text(data["profile_id"], "profile_id"),
                _text(data["scenario_id"], "scenario_id"),
                _revision(data["expected_revision"]),
                _revision(data["expected_scenario_revision"], "expected_scenario_revision"),
                _text(data["idempotency_key"], "idempotency_key"),
                data["name"], data["description"], data["base_profile_revision"], data["document"],
            )
        if method in {"repository.scenario.delete", "repository.scenario.duplicate"}:
            data = _require(payload, mutation)
            function = self.store.delete if method.endswith("delete") else self.store.duplicate
            return function(
                _text(data["profile_id"], "profile_id"),
                _text(data["scenario_id"], "scenario_id"),
                _revision(data["expected_revision"]),
                _revision(data["expected_scenario_revision"], "expected_scenario_revision"),
                _text(data["idempotency_key"], "idempotency_key"),
            )
        raise ScenarioStoreError("unknown_method", f"Unknown scenario repository method: {method}")
