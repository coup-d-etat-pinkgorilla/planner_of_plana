from __future__ import annotations

from concurrent.futures import Future, ThreadPoolExecutor
from copy import deepcopy
from dataclasses import dataclass, field
from threading import Event, RLock
from typing import Any, Callable, Mapping, Protocol
from uuid import uuid4

from core.repository_dto import ConfirmedStudent, InventorySnapshot, RepositoryDTOError


class ScannerError(RuntimeError):
    def __init__(self, code: str, message: str, *, details: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details or {}


class RepositoryCommitPort(Protocol):
    def get_state(self, profile_id: str) -> dict[str, Any]: ...

    def update_students(
        self, profile_id: str, students: list[dict[str, Any]], expected_revision: int,
        idempotency_key: str,
    ) -> dict[str, Any]: ...

    def update_inventory(
        self, profile_id: str, inventory: dict[str, Any], expected_revision: int,
        idempotency_key: str,
    ) -> dict[str, Any]: ...


Matcher = Callable[[dict[str, Any], Event, Callable[[int, int | None, str], None]], list[dict[str, Any]]]
EventSink = Callable[[dict[str, Any]], None]


@dataclass(slots=True)
class SessionCandidate:
    candidate_id: str
    session_id: str
    generation: int
    scan_kind: str
    payload: dict[str, Any]
    evidence: list[dict[str, Any]]
    review_required: bool
    revision: int = 1
    approved: bool = False
    audit: list[dict[str, Any]] = field(default_factory=list)

    def to_wire(self) -> dict[str, Any]:
        return {
            "candidate_id": self.candidate_id,
            "session_id": self.session_id,
            "generation": self.generation,
            "revision": self.revision,
            "scan_kind": self.scan_kind,
            "payload": deepcopy(self.payload),
            "evidence": deepcopy(self.evidence),
            "review_required": self.review_required,
            "approved": self.approved,
            "audit": deepcopy(self.audit),
        }


@dataclass(slots=True)
class _Session:
    session_id: str
    generation: int
    scan_kind: str
    target: dict[str, Any]
    cancel: Event = field(default_factory=Event)
    sequence: int = 0
    terminal: str | None = None
    events: list[dict[str, Any]] = field(default_factory=list)
    candidates: dict[str, SessionCandidate] = field(default_factory=dict)
    future: Future[None] | None = None


class ScannerSessionService:
    """Headless scanner lifecycle, independent from UI and Windows imports."""

    def __init__(
        self,
        *,
        target_provider: Callable[[], list[dict[str, Any]]],
        student_matcher: Matcher,
        inventory_matcher: Matcher,
        repository: RepositoryCommitPort,
        asset_status: Callable[[], dict[str, Any]],
        event_sink: EventSink | None = None,
        id_factory: Callable[[], str] | None = None,
        executor: ThreadPoolExecutor | None = None,
    ) -> None:
        self._target_provider = target_provider
        self._matchers = {"student": student_matcher, "inventory": inventory_matcher}
        self._repository = repository
        self._asset_status = asset_status
        self._event_sink = event_sink or (lambda _event: None)
        self._id_factory = id_factory or (lambda: uuid4().hex)
        self._executor = executor or ThreadPoolExecutor(max_workers=1, thread_name_prefix="scanner")
        self._owns_executor = executor is None
        self._lock = RLock()
        self._generation = 0
        self._active: _Session | None = None
        self._sessions: dict[str, _Session] = {}

    def targets(self) -> list[dict[str, Any]]:
        targets = self._target_provider()
        if not isinstance(targets, list) or any(not isinstance(item, dict) for item in targets):
            raise ScannerError("target_provider_failed", "target provider returned invalid data")
        return deepcopy(targets)

    def recognition_status(self) -> dict[str, Any]:
        value = self._asset_status()
        if not isinstance(value, dict):
            raise ScannerError("asset_catalog_failed", "asset status must be an object")
        return deepcopy(value)

    def start(self, scan_kind: str, target_id: str) -> dict[str, Any]:
        if scan_kind not in self._matchers:
            raise ScannerError("invalid_payload", "scan_kind must be student or inventory")
        target = next((item for item in self.targets() if item.get("target_id") == target_id), None)
        if target is None:
            raise ScannerError("target_not_found", "capture target was not found")
        with self._lock:
            if self._active is not None and self._active.terminal is None:
                raise ScannerError("scanner_busy", "another scanner session is active")
            self._generation += 1
            session = _Session(self._id_factory(), self._generation, scan_kind, target)
            self._active = session
            self._sessions[session.session_id] = session
            # The session is registered before the worker can publish its first event.
            session.future = self._executor.submit(self._run, session)
            return {
                "session_id": session.session_id,
                "generation": session.generation,
                "scan_kind": session.scan_kind,
            }

    def cancel(self, session_id: str, generation: int) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            already_terminal = session.terminal is not None
            session.cancel.set()
            return {"accepted": not already_terminal, "terminal": session.terminal}

    def snapshot(self, session_id: str, generation: int) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            return {
                "session_id": session.session_id,
                "generation": session.generation,
                "scan_kind": session.scan_kind,
                "last_sequence": session.sequence,
                "terminal": session.terminal,
                "events": deepcopy(session.events),
                "candidates": [item.to_wire() for item in session.candidates.values()],
            }

    def candidate(self, session_id: str, generation: int, candidate_id: str) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            item = session.candidates.get(candidate_id)
            if item is None:
                raise ScannerError("candidate_not_found", "scanner candidate was not found")
            return item.to_wire()

    def review(
        self,
        session_id: str,
        generation: int,
        candidate_id: str,
        expected_candidate_revision: int,
        payload: dict[str, Any],
        *,
        approve: bool,
        reason: str,
    ) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            item = session.candidates.get(candidate_id)
            if item is None:
                raise ScannerError("candidate_not_found", "scanner candidate was not found")
            if item.revision != expected_candidate_revision:
                raise ScannerError("candidate_revision_conflict", "candidate revision is stale")
            self._validated_payload(item.scan_kind, payload)
            item.audit.append({
                "from_revision": item.revision,
                "reason": reason,
                "approved": approve,
                "source": "user_review",
            })
            item.payload = deepcopy(payload)
            item.revision += 1
            item.approved = approve
            return item.to_wire()

    def commit(
        self,
        *,
        session_id: str,
        generation: int,
        candidate_id: str,
        candidate_revision: int,
        profile_id: str,
        expected_repository_revision: int,
        idempotency_key: str,
    ) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            item = session.candidates.get(candidate_id)
            if item is None:
                raise ScannerError("candidate_not_found", "scanner candidate was not found")
            if item.revision != candidate_revision:
                raise ScannerError("candidate_revision_conflict", "candidate revision is stale")
            if session.terminal != "completed":
                raise ScannerError("session_not_committable", "only a completed session can commit")
            if item.review_required and not item.approved:
                raise ScannerError("review_required", "candidate requires explicit review approval")
            payload = self._validated_payload(item.scan_kind, item.payload)

        if item.scan_kind == "student":
            state = self._repository.get_state(profile_id)
            student = payload.to_dict()
            students = [
                existing for existing in state["students"]
                if existing.get("student_id") != student["student_id"]
            ]
            students.append(student)
            result = self._repository.update_students(
                profile_id, students, expected_repository_revision, idempotency_key
            )
        else:
            result = self._repository.update_inventory(
                profile_id, payload.to_dict(), expected_repository_revision, idempotency_key
            )
        return {"candidate_id": candidate_id, "candidate_revision": candidate_revision, **result}

    def wait(self, session_id: str, timeout: float = 5.0) -> None:
        session = self._sessions.get(session_id)
        if session is None:
            raise ScannerError("session_not_found", "scanner session was not found")
        if session.future is not None:
            session.future.result(timeout=timeout)

    def close(self) -> None:
        with self._lock:
            active = self._active
            if active is not None:
                active.cancel.set()
        if self._owns_executor:
            self._executor.shutdown(wait=True, cancel_futures=True)

    def _session(self, session_id: str, generation: int) -> _Session:
        with self._lock:
            session = self._sessions.get(session_id)
            if session is None:
                raise ScannerError("session_not_found", "scanner session was not found")
            if session.generation != generation:
                raise ScannerError("stale_generation", "scanner generation is stale")
            return session

    @staticmethod
    def _validated_payload(scan_kind: str, payload: object) -> ConfirmedStudent | InventorySnapshot:
        try:
            return (
                ConfirmedStudent.from_dict(payload)
                if scan_kind == "student"
                else InventorySnapshot.from_dict(payload)
            )
        except RepositoryDTOError as exc:
            raise ScannerError("invalid_candidate", str(exc)) from exc

    def _run(self, session: _Session) -> None:
        try:
            self._emit(session, "phase", {"phase": "capturing"})
            if session.cancel.is_set():
                self._terminal(session, "cancelled")
                return

            def progress(current: int, total: int | None, message_key: str) -> None:
                if not session.cancel.is_set():
                    self._emit(session, "progress", {
                        "current": current, "total": total, "message_key": message_key,
                    })

            candidates = self._matchers[session.scan_kind](session.target, session.cancel, progress)
            if session.cancel.is_set():
                self._terminal(session, "cancelled")
                return
            if not isinstance(candidates, list):
                raise ScannerError("matcher_failed", "matcher returned invalid candidates")
            for raw in candidates:
                if session.cancel.is_set():
                    self._terminal(session, "cancelled")
                    return
                candidate = self._make_candidate(session, raw)
                with self._lock:
                    session.candidates[candidate.candidate_id] = candidate
                self._emit(session, "candidate", {"candidate": candidate.to_wire()})
            self._terminal(session, "completed")
        except ScannerError as exc:
            self._terminal(session, "failed", code=exc.code, message=exc.message)
        except Exception as exc:
            self._terminal(session, "failed", code="matcher_failed", message=str(exc))

    def _make_candidate(self, session: _Session, raw: Mapping[str, Any]) -> SessionCandidate:
        if not isinstance(raw, Mapping):
            raise ScannerError("matcher_failed", "matcher candidate must be an object")
        payload = raw.get("payload")
        evidence = raw.get("evidence", [])
        if not isinstance(payload, dict) or not isinstance(evidence, list):
            raise ScannerError("matcher_failed", "matcher candidate has invalid payload/evidence")
        self._validated_payload(session.scan_kind, payload)
        review_required = bool(raw.get("review_required", False)) or any(
            isinstance(item, dict) and item.get("status") not in {"ok", "inferred", "skipped"}
            for item in evidence
        )
        return SessionCandidate(
            candidate_id=str(raw.get("candidate_id") or self._id_factory()),
            session_id=session.session_id,
            generation=session.generation,
            scan_kind=session.scan_kind,
            payload=deepcopy(payload),
            evidence=deepcopy(evidence),
            review_required=review_required,
        )

    def _emit(self, session: _Session, event_kind: str, data: dict[str, Any]) -> None:
        with self._lock:
            if session.terminal is not None:
                return
            session.sequence += 1
            event = {
                "protocol": 1,
                "type": "event",
                "method": "scanner.session.event",
                "payload": {
                    "session_id": session.session_id,
                    "generation": session.generation,
                    "sequence": session.sequence,
                    "scan_kind": session.scan_kind,
                    "event_kind": event_kind,
                    **deepcopy(data),
                },
            }
            session.events.append(event)
        self._event_sink(deepcopy(event))

    def _terminal(
        self, session: _Session, outcome: str, *, code: str | None = None,
        message: str | None = None,
    ) -> None:
        with self._lock:
            if session.terminal is not None:
                return
            session.sequence += 1
            session.terminal = outcome
            payload: dict[str, Any] = {
                "session_id": session.session_id,
                "generation": session.generation,
                "sequence": session.sequence,
                "scan_kind": session.scan_kind,
                "event_kind": "terminal",
                "outcome": outcome,
            }
            if code is not None:
                payload["error"] = {"code": code, "message": message or code}
            event = {
                "protocol": 1, "type": "event", "method": "scanner.session.event",
                "payload": payload,
            }
            session.events.append(event)
            if self._active is session:
                self._active = None
        self._event_sink(deepcopy(event))


@dataclass(slots=True)
class ScannerEventCursor:
    """Deterministic consumer policy shared by fixtures and typed clients."""

    session_id: str
    generation: int
    last_sequence: int = 0
    terminal: bool = False

    def consume(self, event: Mapping[str, Any]) -> str:
        payload = event.get("payload")
        if not isinstance(payload, Mapping):
            return "invalid"
        if payload.get("session_id") != self.session_id or payload.get("generation") != self.generation:
            return "stale"
        sequence = payload.get("sequence")
        if not isinstance(sequence, int) or isinstance(sequence, bool) or sequence < 1:
            return "invalid"
        if self.terminal:
            return "after_terminal"
        if sequence <= self.last_sequence:
            return "duplicate_or_out_of_order"
        if sequence != self.last_sequence + 1:
            return "snapshot_required"
        self.last_sequence = sequence
        if payload.get("event_kind") == "terminal":
            self.terminal = True
        return "accepted"
