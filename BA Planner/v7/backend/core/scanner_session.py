from __future__ import annotations

from concurrent.futures import Future, ThreadPoolExecutor
from copy import deepcopy
from dataclasses import dataclass, field
from inspect import Parameter, signature
from threading import Event, RLock
from typing import Any, Callable, Mapping, Protocol
from uuid import uuid4

from PIL import Image

from core.repository_dto import ConfirmedStudent, InventorySnapshot, RepositoryDTOError


NON_REVIEW_EVIDENCE_STATUSES = {
    "ok", "inferred", "skipped", "verified", "deferred", "shadow",
}


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


@dataclass(slots=True)
class ScanBatchResult:
    """Internal ownership handoff. Images never enter the protocol envelope."""

    candidates: list[dict[str, Any]]
    outcome: str = "completed"
    error: ScannerError | None = None
    screen_state: str = "unknown"
    coverage_complete: bool = False


Matcher = Callable[[dict[str, Any], Event, Callable[..., None]], list[dict[str, Any]] | ScanBatchResult]
EventSink = Callable[[dict[str, Any]], None]
TacticalLobbyCommitter = Callable[[str, dict[str, Any], int, str], dict[str, Any]]
StudentValidator = Callable[[Mapping[str, Any], str | None, Mapping[int, int] | None], dict[str, Any]]
CandidateReviewHook = Callable[[str, str, str, dict[str, Any], dict[str, Any], str, bool], int | None]


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
    validation_relationship_ranks: dict[int, int] = field(default_factory=dict)
    answer_specimen: dict[str, Any] = field(default_factory=dict, repr=False)

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
    profile_id: str | None = None
    student_scan_mode: str = "single"
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
        tactical_lobby_matcher: Matcher | None = None,
        tactical_lobby_committer: TacticalLobbyCommitter | None = None,
        repository: RepositoryCommitPort,
        asset_status: Callable[[], dict[str, Any]],
        event_sink: EventSink | None = None,
        id_factory: Callable[[], str] | None = None,
        executor: ThreadPoolExecutor | None = None,
        student_validator: StudentValidator | None = None,
        candidate_review_hook: CandidateReviewHook | None = None,
        resource_close_hook: Callable[[], None] | None = None,
    ) -> None:
        self._target_provider = target_provider
        self._matchers = {"student": student_matcher, "inventory": inventory_matcher}
        if tactical_lobby_matcher is not None:
            self._matchers["tactical_lobby"] = tactical_lobby_matcher
        self._repository = repository
        self._tactical_lobby_committer = tactical_lobby_committer
        self._asset_status = asset_status
        self._event_sink = event_sink or (lambda _event: None)
        self._id_factory = id_factory or (lambda: uuid4().hex)
        self._executor = executor or ThreadPoolExecutor(max_workers=1, thread_name_prefix="scanner")
        self._student_validator = student_validator
        self._candidate_review_hook = candidate_review_hook
        self._resource_close_hook = resource_close_hook
        self._student_validator_accepts_context = False
        if student_validator is not None:
            parameters = signature(student_validator).parameters.values()
            self._student_validator_accepts_context = (
                any(item.kind == Parameter.VAR_POSITIONAL for item in parameters)
                or len(tuple(signature(student_validator).parameters.values())) >= 3
            )
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

    def set_event_sink(self, event_sink: EventSink) -> None:
        with self._lock:
            if self._active is not None and self._active.terminal is None:
                raise ScannerError("scanner_busy", "cannot replace event sink during a session")
            self._event_sink = event_sink

    def start(
        self,
        scan_kind: str,
        target_id: str,
        profile_id: str | None = None,
        student_scan_mode: str = "single",
        inventory_scan_profile: str | None = None,
    ) -> dict[str, Any]:
        if scan_kind not in self._matchers:
            raise ScannerError("invalid_payload", "scan_kind must be student, inventory, or tactical_lobby")
        target = next((item for item in self.targets() if item.get("target_id") == target_id), None)
        if target is None:
            raise ScannerError("target_not_found", "capture target was not found")
        if student_scan_mode not in {"single", "full"}:
            raise ScannerError("invalid_payload", "student_scan_mode must be single or full")
        inventory_profiles = {
            "student_elephs", "tech_notes", "tactical_bd", "ooparts",
            "activity_reports", "presents", "equipment",
        }
        if inventory_scan_profile is not None and inventory_scan_profile not in inventory_profiles:
            raise ScannerError("invalid_payload", "inventory_scan_profile is not supported")
        if scan_kind != "inventory" and inventory_scan_profile is not None:
            raise ScannerError("invalid_payload", "inventory_scan_profile is only valid for inventory scans")
        target["student_scan_mode"] = student_scan_mode if scan_kind == "student" else "single"
        target["profile_id"] = profile_id
        if inventory_scan_profile is not None:
            target["inventory_scan_profile"] = inventory_scan_profile
        with self._lock:
            if self._active is not None and self._active.terminal is None:
                raise ScannerError("scanner_busy", "another scanner session is active")
            self._generation += 1
            session = _Session(
                self._id_factory(), self._generation, scan_kind, target, profile_id,
                student_scan_mode if scan_kind == "student" else "single",
            )
            self._active = session
            session.target["_scanner_cancel"] = session.cancel
            session.target["_scanner_session_id"] = session.session_id
            session.target["_scanner_generation"] = session.generation
            self._sessions[session.session_id] = session
            # The session is registered before the worker can publish its first event.
            session.future = self._executor.submit(self._run, session)
            result = {
                "session_id": session.session_id,
                "generation": session.generation,
                "scan_kind": session.scan_kind,
            }
            if scan_kind == "student":
                result["student_scan_mode"] = session.student_scan_mode
            return result

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

    def revalidate(
        self, session_id: str, generation: int, candidate_id: str,
        expected_candidate_revision: int,
        relationship_ranks: Mapping[int, int] | None = None,
    ) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            item = session.candidates.get(candidate_id)
            if item is None:
                raise ScannerError("candidate_not_found", "scanner candidate was not found")
            if item.revision != expected_candidate_revision:
                raise ScannerError("candidate_revision_conflict", "candidate revision is stale")
            if item.scan_kind != "student" or self._student_validator is None:
                raise ScannerError("revalidation_unavailable", "student revalidation is unavailable")
            item.evidence = [entry for entry in item.evidence if entry.get("field") != "student_stat_validation"]
            if relationship_ranks is not None:
                item.validation_relationship_ranks.update(relationship_ranks)
            item.evidence.append(self._validate_student(
                item.payload, session.profile_id, item.validation_relationship_ranks,
            ))
            item.review_required = any(
                entry.get("status") not in NON_REVIEW_EVIDENCE_STATUSES
                for entry in item.evidence if isinstance(entry, dict)
            )
            item.revision += 1
            item.approved = False
            item.audit.append({"from_revision": item.revision - 1, "source": "second_pass_revalidation"})
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
        relationship_ranks: Mapping[int, int] | None = None,
    ) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            item = session.candidates.get(candidate_id)
            if item is None:
                raise ScannerError("candidate_not_found", "scanner candidate was not found")
            if item.revision != expected_candidate_revision:
                raise ScannerError("candidate_revision_conflict", "candidate revision is stale")
            self._validated_payload(item.scan_kind, payload)
            if (
                self._candidate_review_hook is not None
                and session.profile_id is not None
                and item.answer_specimen
                and (
                    (item.scan_kind == "student" and reason == "edited_and_revalidated_in_scan_page")
                    or (item.scan_kind == "inventory" and approve)
                )
            ):
                try:
                    sample_count = self._candidate_review_hook(
                        item.scan_kind, session.profile_id, item.candidate_id,
                        item.answer_specimen, payload, reason, approve,
                    )
                    item.audit.append({
                        "source": "user_confirmed_answer_sample",
                        "sample_count": sample_count or 0,
                    })
                except (OSError, ValueError) as exc:
                    item.audit.append({
                        "source": "user_confirmed_answer_sample",
                        "status": "storage_failed",
                        "message": str(exc),
                    })
            if item.answer_specimen and (
                approve or reason in {"discarded_in_scan_page", "discarded_in_student_page"}
            ):
                self._close_specimen(item.answer_specimen)
                item.answer_specimen = {}
            if (
                item.scan_kind == "student"
                and reason == "edited_and_revalidated_in_scan_page"
            ):
                values = payload.get("values") if isinstance(payload, dict) else None
                if isinstance(values, dict):
                    reviewed: list[dict[str, Any]] = []
                    for evidence in item.evidence:
                        replacement = deepcopy(evidence)
                        if (
                            isinstance(replacement, dict)
                            and replacement.get("field") in values
                            and replacement.get("status")
                            not in {"ok", "inferred", "skipped", "verified", "deferred"}
                        ):
                            replacement.update({
                                "status": "verified",
                                "source": "user_review",
                                "confidence": 1.0,
                                "note": "field confirmed in scanner review workspace",
                            })
                        reviewed.append(replacement)
                    item.evidence = reviewed
            item.audit.append({
                "from_revision": item.revision,
                "reason": reason,
                "approved": approve,
                "source": "user_review",
            })
            item.payload = deepcopy(payload)
            if item.scan_kind == "student" and self._student_validator is not None:
                if relationship_ranks is not None:
                    item.validation_relationship_ranks.update(relationship_ranks)
                item.evidence = [entry for entry in item.evidence if entry.get("field") != "student_stat_validation"]
                item.evidence.append(self._validate_student(
                    item.payload, session.profile_id, item.validation_relationship_ranks,
                ))
                item.review_required = any(
                    entry.get("status") not in NON_REVIEW_EVIDENCE_STATUSES
                    for entry in item.evidence if isinstance(entry, dict)
                )
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
        elif item.scan_kind == "inventory":
            result = self._repository.update_inventory(
                profile_id, payload.to_dict(), expected_repository_revision, idempotency_key
            )
        else:
            if self._tactical_lobby_committer is None:
                raise ScannerError(
                    "persistence_deferred",
                    "tactical lobby persistence is not configured",
                )
            result = self._tactical_lobby_committer(
                profile_id, payload, expected_repository_revision, idempotency_key
            )
        with self._lock:
            self._close_specimen(item.answer_specimen)
            item.answer_specimen = {}
        return {
            "candidate_id": candidate_id,
            "candidate_revision": candidate_revision,
            "profile_id": profile_id,
            **result,
        }

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
        if self._resource_close_hook is not None:
            self._resource_close_hook()
        with self._lock:
            for session in self._sessions.values():
                for candidate in session.candidates.values():
                    self._close_specimen(candidate.answer_specimen)
                    candidate.answer_specimen = {}

    @classmethod
    def _close_specimen(cls, value: object) -> None:
        if isinstance(value, Image.Image):
            value.close()
        elif isinstance(value, Mapping):
            for nested in value.values():
                cls._close_specimen(nested)
        elif isinstance(value, (tuple, list)):
            for nested in value:
                cls._close_specimen(nested)

    @classmethod
    def _close_raw_specimens(cls, candidates: object) -> None:
        if not isinstance(candidates, list):
            return
        for raw in candidates:
            if isinstance(raw, Mapping):
                cls._close_specimen(raw.get("_answer_specimen"))

    def _session(self, session_id: str, generation: int) -> _Session:
        with self._lock:
            session = self._sessions.get(session_id)
            if session is None:
                raise ScannerError("session_not_found", "scanner session was not found")
            if session.generation != generation:
                raise ScannerError("stale_generation", "scanner generation is stale")
            return session

    @staticmethod
    def _validated_payload(scan_kind: str, payload: object) -> ConfirmedStudent | InventorySnapshot | dict[str, Any]:
        if scan_kind == "tactical_lobby":
            from core.tactical_lobby_scanner import canonical_tactical_lobby_candidate
            return canonical_tactical_lobby_candidate(payload)
        try:
            return (
                ConfirmedStudent.from_dict(payload)
                if scan_kind == "student"
                else InventorySnapshot.from_dict(payload)
            )
        except RepositoryDTOError as exc:
            raise ScannerError("invalid_candidate", str(exc)) from exc

    def _run(self, session: _Session) -> None:
        candidates = []
        transferred = 0
        try:
            self._emit(session, "phase", {"phase": "capturing"})
            if session.cancel.is_set():
                self._terminal(session, "cancelled")
                return

            def progress(
                current: int,
                total: int | None,
                message_key: str,
                feedback: Mapping[str, Any] | None = None,
            ) -> None:
                if not session.cancel.is_set():
                    self._emit(session, "progress", {
                        "current": current, "total": total, "message_key": message_key,
                    })
                    if feedback is not None:
                        student_id = feedback.get("student_id")
                        values = feedback.get("values")
                        field = feedback.get("field")
                        if (
                            isinstance(student_id, str)
                            and student_id
                            and isinstance(values, Mapping)
                            and isinstance(field, str)
                            and field
                        ):
                            self._emit(session, "feedback", {
                                "student_id": student_id,
                                "field": field,
                                "values": dict(values),
                            })
            progress.supports_feedback = True  # type: ignore[attr-defined]

            result = self._matchers[session.scan_kind](session.target, session.cancel, progress)
            batch = result if isinstance(result, ScanBatchResult) else ScanBatchResult(result)
            if not isinstance(batch.candidates, list):
                raise ScannerError("matcher_failed", "matcher returned invalid candidates")
            candidates = batch.candidates
            if batch.outcome not in {"completed", "failed", "cancelled"}:
                raise ScannerError("matcher_failed", "matcher returned invalid outcome")
            batch_relationship_ranks = (
                self._batch_relationship_ranks(candidates)
                if session.scan_kind == "student" and session.student_scan_mode == "full"
                else {}
            )
            for raw in candidates:
                candidate = self._make_candidate(session, raw, batch_relationship_ranks)
                with self._lock:
                    session.candidates[candidate.candidate_id] = candidate
                transferred += 1
                self._emit(session, "candidate", {"candidate": candidate.to_wire()})
            outcome = "cancelled" if session.cancel.is_set() else batch.outcome
            self._terminal(
                session, outcome,
                code=batch.error.code if batch.error and outcome == "failed" else None,
                message=batch.error.message if batch.error and outcome == "failed" else None,
            )
        except ScannerError as exc:
            self._terminal(session, "cancelled" if session.cancel.is_set() or exc.code == "cancelled" else "failed", code=exc.code, message=exc.message)
        except Exception as exc:
            self._terminal(session, "failed", code="matcher_failed", message=str(exc))
        finally:
            self._close_raw_specimens(candidates[transferred:])

    def _make_candidate(
        self,
        session: _Session,
        raw: Mapping[str, Any],
        relationship_ranks: Mapping[int, int] | None = None,
    ) -> SessionCandidate:
        if not isinstance(raw, Mapping):
            raise ScannerError("matcher_failed", "matcher candidate must be an object")
        payload = raw.get("payload")
        evidence = raw.get("evidence", [])
        if not isinstance(payload, dict) or not isinstance(evidence, list):
            raise ScannerError("matcher_failed", "matcher candidate has invalid payload/evidence")
        self._validated_payload(session.scan_kind, payload)
        if session.scan_kind == "student" and self._student_validator is not None:
            evidence = [item for item in evidence if item.get("field") != "student_stat_validation"]
            evidence.append(self._validate_student(payload, session.profile_id, relationship_ranks))
        review_required = bool(raw.get("review_required", False)) or any(
            isinstance(item, dict) and item.get("status") not in NON_REVIEW_EVIDENCE_STATUSES
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
            validation_relationship_ranks=dict(relationship_ranks or {}),
            answer_specimen=(
                dict(raw.get("_answer_specimen", {}))
                if isinstance(raw.get("_answer_specimen"), Mapping)
                else {}
            ),
        )

    def _batch_relationship_ranks(self, candidates: list[dict[str, Any]]) -> dict[int, int]:
        ranks: dict[int, int] = {}
        if self._student_validator is None:
            return ranks
        catalog = getattr(self._student_validator, "catalog", None)
        if catalog is None:
            return ranks
        from core.student_stats_catalog import student_stat_record
        for raw in candidates:
            payload = raw.get("payload") if isinstance(raw, Mapping) else None
            values = payload.get("values") if isinstance(payload, Mapping) else None
            student_id = payload.get("student_id") if isinstance(payload, Mapping) else None
            rank = values.get("bond_rank") if isinstance(values, Mapping) else None
            if not isinstance(student_id, str) or not isinstance(rank, int) or isinstance(rank, bool):
                continue
            try:
                ranks[student_stat_record(student_id, catalog=catalog).schaledb_id] = rank
            except (KeyError, ValueError):
                continue
        return ranks

    def _validate_student(
        self,
        payload: Mapping[str, Any],
        profile_id: str | None,
        relationship_ranks: Mapping[int, int] | None,
    ) -> dict[str, Any]:
        if self._student_validator is None:
            raise ScannerError("revalidation_unavailable", "student revalidation is unavailable")
        if self._student_validator_accepts_context:
            return self._student_validator(payload, profile_id, relationship_ranks)
        return self._student_validator(payload, profile_id)  # type: ignore[call-arg]

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
