from __future__ import annotations

from typing import Any

from core.repository_store import RepositoryError
from core.tactical_store import TacticalStore


METHODS = frozenset({"tactical.state.get", "tactical.match.upsert", "tactical.match.delete",
                     "tactical.jokbo.upsert", "tactical.jokbo.delete"})


def _require(value: object, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise RepositoryError("invalid_payload", f"payload must contain exactly {sorted(keys)}")
    return value


def _text(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise RepositoryError("invalid_payload", f"{label} must be a non-empty string")
    return value


def _revision(value: object) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise RepositoryError("invalid_payload", "expected_revision must be a non-negative integer")
    return value


class TacticalProtocolV1:
    def __init__(self, store: TacticalStore) -> None:
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
        if method == "tactical.state.get":
            data = _require(payload, {"profile_id"})
            return self.store.state(_text(data["profile_id"], "profile_id"))
        suffix = method.removeprefix("tactical.")
        item_key = "match" if suffix == "match.upsert" else "match_id" if suffix == "match.delete" else "jokbo" if suffix == "jokbo.upsert" else "jokbo_id"
        data = _require(payload, {"profile_id", "expected_revision", "idempotency_key", item_key})
        args = (_text(data["profile_id"], "profile_id"), data[item_key],
                _revision(data["expected_revision"]), _text(data["idempotency_key"], "idempotency_key"))
        if suffix == "match.upsert": return self.store.upsert_match(*args)
        if suffix == "match.delete": return self.store.delete_match(*args)
        if suffix == "jokbo.upsert": return self.store.upsert_jokbo(*args)
        if suffix == "jokbo.delete": return self.store.delete_jokbo(*args)
        raise RepositoryError("unknown_method", f"Unknown tactical method: {method}")
