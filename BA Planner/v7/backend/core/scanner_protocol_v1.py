from __future__ import annotations

from typing import Any, Callable

from core.repository_store import RepositoryError
from core.scanner_session import ScannerError, ScannerSessionService


METHODS = frozenset({
    "scanner.target.list",
    "scanner.recognition.status",
    "scanner.session.start",
    "scanner.session.cancel",
    "scanner.session.snapshot",
    "scanner.candidate.get",
    "scanner.candidate.review",
    "scanner.candidate.commit",
})


class ScannerProtocolV1:
    def __init__(self, service: ScannerSessionService) -> None:
        self.service = service

    def handle(self, request: dict[str, Any]) -> dict[str, Any]:
        request_id = request.get("id")
        method = request.get("method")
        if not isinstance(request_id, str) or not request_id or method not in METHODS:
            return self._error(str(request_id or "unknown"), str(method or "unknown"), "unknown_method", "unknown scanner method")
        try:
            payload = self._object(request.get("payload"), "payload")
            result = self._dispatch(method, payload)
            return {"protocol": 1, "id": request_id, "type": "response", "method": method, "payload": result}
        except ScannerError as exc:
            return self._error(request_id, method, exc.code, exc.message, exc.details)
        except RepositoryError as exc:
            details = dict(exc.details)
            details["retryable"] = exc.retryable
            return self._error(request_id, method, exc.code, exc.message, details)

    def _dispatch(self, method: str, payload: dict[str, Any]) -> dict[str, Any]:
        if method == "scanner.target.list":
            self._exact(payload, set())
            return {"targets": self.service.targets()}
        if method == "scanner.recognition.status":
            self._exact(payload, set())
            return self.service.recognition_status()
        if method == "scanner.session.start":
            self._exact(payload, {"scan_kind", "target_id"})
            return self.service.start(self._text(payload["scan_kind"], "scan_kind"), self._text(payload["target_id"], "target_id"))
        if method in {"scanner.session.cancel", "scanner.session.snapshot"}:
            self._exact(payload, {"session_id", "generation"})
            args = (self._text(payload["session_id"], "session_id"), self._integer(payload["generation"], "generation", minimum=1))
            return self.service.cancel(*args) if method.endswith("cancel") else self.service.snapshot(*args)
        if method == "scanner.candidate.get":
            self._exact(payload, {"session_id", "generation", "candidate_id"})
            candidate = self.service.candidate(
                self._text(payload["session_id"], "session_id"),
                self._integer(payload["generation"], "generation", minimum=1),
                self._text(payload["candidate_id"], "candidate_id"),
            )
            return {"candidate": candidate}
        if method == "scanner.candidate.review":
            required = {"session_id", "generation", "candidate_id", "expected_candidate_revision", "candidate_payload", "approve", "reason"}
            self._exact(payload, required)
            candidate_payload = self._object(payload["candidate_payload"], "candidate_payload")
            if not isinstance(payload["approve"], bool):
                raise ScannerError("invalid_payload", "approve must be a boolean")
            candidate = self.service.review(
                self._text(payload["session_id"], "session_id"),
                self._integer(payload["generation"], "generation", minimum=1),
                self._text(payload["candidate_id"], "candidate_id"),
                self._integer(payload["expected_candidate_revision"], "expected_candidate_revision", minimum=1),
                candidate_payload,
                approve=payload["approve"],
                reason=self._string(payload["reason"], "reason"),
            )
            return {"candidate": candidate}
        if method == "scanner.candidate.commit":
            required = {"session_id", "generation", "candidate_id", "candidate_revision", "profile_id", "expected_repository_revision", "idempotency_key"}
            self._exact(payload, required)
            return self.service.commit(
                session_id=self._text(payload["session_id"], "session_id"),
                generation=self._integer(payload["generation"], "generation", minimum=1),
                candidate_id=self._text(payload["candidate_id"], "candidate_id"),
                candidate_revision=self._integer(payload["candidate_revision"], "candidate_revision", minimum=1),
                profile_id=self._text(payload["profile_id"], "profile_id"),
                expected_repository_revision=self._integer(payload["expected_repository_revision"], "expected_repository_revision", minimum=0),
                idempotency_key=self._text(payload["idempotency_key"], "idempotency_key"),
            )
        raise ScannerError("unknown_method", "unknown scanner method")

    @staticmethod
    def _error(request_id: str, method: str, code: str, message: str, details: dict[str, Any] | None = None) -> dict[str, Any]:
        error: dict[str, Any] = {"code": code, "message": message}
        if details:
            error["details"] = details
        return {"protocol": 1, "id": request_id, "type": "response", "method": method, "payload": {"error": error}}

    @staticmethod
    def _object(value: object, label: str) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise ScannerError("invalid_payload", f"{label} must be an object")
        return value

    @staticmethod
    def _exact(value: dict[str, Any], fields: set[str]) -> None:
        if set(value) != fields:
            raise ScannerError("invalid_payload", f"payload fields must be {sorted(fields)}")

    @staticmethod
    def _text(value: object, label: str) -> str:
        if not isinstance(value, str) or not value:
            raise ScannerError("invalid_payload", f"{label} must be a non-empty string")
        return value

    @staticmethod
    def _string(value: object, label: str) -> str:
        if not isinstance(value, str):
            raise ScannerError("invalid_payload", f"{label} must be a string")
        return value

    @staticmethod
    def _integer(value: object, label: str, *, minimum: int) -> int:
        if not isinstance(value, int) or isinstance(value, bool) or value < minimum:
            raise ScannerError("invalid_payload", f"{label} must be an integer >= {minimum}")
        return value
