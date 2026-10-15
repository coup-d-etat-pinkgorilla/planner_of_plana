from __future__ import annotations

from concurrent.futures import Future, ThreadPoolExecutor
import base64
from copy import deepcopy
from dataclasses import dataclass, field
from io import BytesIO
import inspect
import json
from threading import Event, RLock
from typing import Any, Callable, Mapping, Protocol
from uuid import uuid4

from PIL import Image

from core.inventory_catalog import BY_KEY, CATALOG_REVISION, SCAN_PROFILES, canonical_resource_key
from core.repository_inventory import rebase_inventory_snapshot
from core.current_history import HistoryError, canonical_students
from core.scan_commit_history_context import ScanCommitHistoryContext
from core.scan_context import ScanContext
from core.scanner_pause_control import ScannerPauseControl
from core.student_fallback_evidence import attach_student_fallback_details, remove_student_crop_images
from core.repository_dto import ConfirmedStudent, InventorySnapshot, RepositoryDTOError, canonical_json


NON_REVIEW_EVIDENCE_STATUSES = {
    "ok", "inferred", "skipped", "verified", "deferred", "shadow",
}


# Entry fields that describe the scan, not the stored inventory (C1 X05).
SCANNER_ONLY_ENTRY_FIELDS = frozenset({"inventory_scan_profile"})


class ProgressSink(Protocol):
    """Matcher progress callback. ``supports_feedback`` sinks also take per-field feedback."""

    supports_feedback: bool

    def __call__(self, current: int, total: int | None, message_key: str,
                 feedback: Mapping[str, Any] | None = None) -> None: ...


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
        idempotency_key: str, *, history_context: ScanCommitHistoryContext | None = None,
    ) -> dict[str, Any]: ...

    def update_inventory(
        self, profile_id: str, inventory: dict[str, Any], expected_revision: int,
        idempotency_key: str, *, history_context: ScanCommitHistoryContext | None = None,
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
CandidateReviewHook = Callable[[str, str, str, dict[str, Any], dict[str, Any], str, bool, tuple[str, ...]], int | None]
InventoryIdentityAssignmentHook = Callable[
    [str | None, tuple[int, int], str, Image.Image, str, int, bool], str | None
]


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
    identified_inventory_keys: tuple[str, ...] = field(default=(), repr=False)

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
    control: ScannerPauseControl | None = None


@dataclass(frozen=True, slots=True)
class _FrozenCurrentCommit:
    public_request_json: str
    bucket: str
    current_json: str
    context: ScanCommitHistoryContext


@dataclass(slots=True)
class _CurrentCommitReceipt:
    public_request_json: str
    request: _FrozenCurrentCommit | None
    response_json: str | None = None
    in_flight: bool = False


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
        inventory_identity_assignment_hook: InventoryIdentityAssignmentHook | None = None,
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
        self._inventory_identity_assignment_hook = inventory_identity_assignment_hook
        self._resource_close_hook = resource_close_hook
        self._owns_executor = executor is None
        self._lock = RLock()
        self._generation = 0
        self._active: _Session | None = None
        self._sessions: dict[str, _Session] = {}
        self._current_commits: dict[tuple[str, str], _CurrentCommitReceipt] = {}

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
        if inventory_scan_profile is not None and inventory_scan_profile not in SCAN_PROFILES:
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
            session.control = ScannerPauseControl(
                self._lock, session.cancel,
                lambda kind, payload: self._emit_unchecked(session, kind, payload),
            )
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
            session.control.wake()
            return {"accepted": not already_terminal, "terminal": session.terminal}

    def pause(self, session_id: str, generation: int) -> dict[str, Any]:
        return self._session(session_id, generation).control.pause()

    def resume(self, session_id: str, generation: int) -> dict[str, Any]:
        session = self._session(session_id, generation)
        if session.control.wire()['control_state'] != 'paused':
            return session.control.wire()
        diagnose = getattr(self._target_provider, 'diagnose', None)
        if callable(diagnose):
            ready = diagnose(session.target).get('status') == 'ready'
        else:
            ready = any(t.get('target_id') == session.target['target_id'] and t.get('status') == 'ready'
                        for t in self.targets())
        return session.control.resume(ready)

    def snapshot(self, session_id: str, generation: int) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            return {
                "session_id": session.session_id,
                "generation": session.generation,
                "scan_kind": session.scan_kind,
                "last_sequence": session.sequence,
                "terminal": session.terminal,
                "control_state": session.control.state,
                "reason": session.control.reason,
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

    def unresolved_slots(
        self, session_id: str, generation: int, candidate_id: str,
    ) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            item = session.candidates.get(candidate_id)
            if item is None:
                raise ScannerError("candidate_not_found", "scanner candidate was not found")
            if item.scan_kind != "inventory":
                raise ScannerError("invalid_candidate", "unresolved slots are only available for inventory candidates")
            return {
                "candidate_id": item.candidate_id,
                "candidate_revision": item.revision,
                "slots": self._unresolved_slots_wire(item),
            }

    def assign_inventory_identity(
        self,
        session_id: str,
        generation: int,
        candidate_id: str,
        expected_candidate_revision: int,
        slot: int,
        identity: str,
        persist: bool,
    ) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            item = session.candidates.get(candidate_id)
            if item is None:
                raise ScannerError("candidate_not_found", "scanner candidate was not found")
            if item.revision != expected_candidate_revision:
                raise ScannerError("candidate_revision_conflict", "candidate revision is stale")
            if item.scan_kind != "inventory":
                raise ScannerError("invalid_candidate", "identity assignment requires an inventory candidate")
            unresolved = item.answer_specimen.get("unresolved_slots")
            slot_crops = item.answer_specimen.get("slot_crops")
            source_size = item.answer_specimen.get("source_size")
            if (not isinstance(unresolved, dict) or slot not in unresolved
                    or not isinstance(slot_crops, dict) or not isinstance(slot_crops.get(slot), Image.Image)
                    or not isinstance(source_size, tuple) or len(source_size) != 2):
                raise ScannerError("unresolved_slot_not_found", "unresolved inventory slot was not found")
            metadata = unresolved[slot]
            profile = metadata.get("profile") if isinstance(metadata, dict) else None
            row = BY_KEY.get(canonical_resource_key(identity))
            if not isinstance(profile, str) or row is None or row.profile_id != profile:
                raise ScannerError("invalid_identity", "identity is not part of the unresolved slot profile")
            entries = item.payload.get("entries")
            if not isinstance(entries, list):
                raise ScannerError("invalid_candidate", "inventory candidate entries are invalid")
            if any(entry.get("item_id") == row.item_id for entry in entries if isinstance(entry, dict)):
                raise ScannerError("identity_conflict", "identity is already present in this candidate")
            if self._inventory_identity_assignment_hook is None:
                raise ScannerError("assignment_unavailable", "inventory identity assignment is unavailable")
            try:
                sample_id = self._inventory_identity_assignment_hook(
                    session.profile_id, source_size, row.item_id, slot_crops[slot],
                    item.candidate_id, slot, persist,
                )
            except (OSError, ValueError) as exc:
                raise ScannerError("sample_storage_failed", str(exc)) from exc

            entries.append({
                "key": row.resource_key,
                "quantity": None,
                "item_id": row.item_id,
                "name": row.display_name,
                "observed_slot": slot,
                "profile_id": profile,
                "inventory_scan_profile": profile,
            })
            self._remember_inventory_keys(item, item.payload)
            item.evidence = [
                evidence for evidence in item.evidence
                if not (isinstance(evidence, dict) and evidence.get("field") == f"slots[{slot}]")
            ]
            item.evidence.extend([
                {"field": f"entries[{slot}].item_id", "status": "verified", "source": "user_label",
                 "confidence": 1.0, "note": "identity assigned by user"},
                {"field": f"entries[{slot}].quantity", "status": "deferred", "source": "user_label",
                 "confidence": None, "note": "identity assignment does not infer quantity"},
            ])
            unresolved.pop(slot)
            assigned_slots = item.answer_specimen.setdefault("assigned_slots", set())
            if not isinstance(assigned_slots, set):
                raise ScannerError("invalid_candidate", "inventory assignment specimen is invalid")
            assigned_slots.add(slot)
            item.audit.append({
                "from_revision": item.revision,
                "source": "user_identity_assignment",
                "slot": slot,
                "identity": row.item_id,
                "persistence": "user_confirmed" if persist else "session",
                **({"sample_id": sample_id} if sample_id is not None else {}),
            })
            item.revision += 1
            item.approved = False
            item.review_required = True
            return {
                "candidate": item.to_wire(),
                "candidate_revision": item.revision,
                "slots": self._unresolved_slots_wire(item),
            }

    @staticmethod
    def _unresolved_slots_wire(item: SessionCandidate) -> list[dict[str, Any]]:
        unresolved = item.answer_specimen.get("unresolved_slots")
        crops = item.answer_specimen.get("slot_crops")
        source_size = item.answer_specimen.get("source_size")
        if not isinstance(unresolved, dict) or not isinstance(crops, dict):
            return []
        resolution = (
            {"width": source_size[0], "height": source_size[1]}
            if isinstance(source_size, tuple) and len(source_size) == 2 else None
        )
        result = []
        for slot in sorted(unresolved):
            metadata = unresolved[slot]
            crop = crops.get(slot)
            if not isinstance(slot, int) or not isinstance(metadata, dict) or not isinstance(crop, Image.Image):
                continue
            buffer = BytesIO()
            crop.save(buffer, format="PNG")
            result.append({
                "slot": slot,
                "profile": metadata.get("profile"),
                "resolution": resolution,
                "crop_png_base64": base64.b64encode(buffer.getvalue()).decode("ascii"),
                "candidates": deepcopy(metadata.get("candidates", [])),
            })
        return result

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
        confirmed_fields: list[str] | tuple[str, ...] | None = None,
    ) -> dict[str, Any]:
        session = self._session(session_id, generation)
        with self._lock:
            item = session.candidates.get(candidate_id)
            if item is None:
                raise ScannerError("candidate_not_found", "scanner candidate was not found")
            if item.revision != expected_candidate_revision:
                raise ScannerError("candidate_revision_conflict", "candidate revision is stale")
            self._validated_payload(item.scan_kind, payload)
            fields = self._confirmed_fields(item.scan_kind, payload, confirmed_fields)
            report = self._train_answer_sample(session, item, payload, reason, approve, fields)
            if approve or reason in {"discarded_in_scan_page", "discarded_in_student_page"}:
                self._release_candidate_images(session, item)
            if (
                item.scan_kind == "student"
                and reason == "edited_and_revalidated_in_scan_page"
            ):
                self._mark_user_verified(item, payload, fields, report.get("blocked_fields", []))
                for field in report.get("blocked_fields", []):
                    item.evidence.append({"field": field, "status": "uncertain",
                        "source": "recognition_sample_safety", "confidence": 0.0,
                        "note": "cross-label collision; confirm the value against the captured screen"})
            item.audit.append({
                "from_revision": item.revision,
                "reason": reason,
                "approved": approve,
                "source": "user_review",
                "confirmed_fields": list(fields),
            })
            if item.scan_kind == "inventory":
                self._remember_inventory_keys(item, payload)
            item.payload = deepcopy(payload)
            if item.scan_kind == "student" and self._student_validator is not None:
                self._revalidate_student(session, item, relationship_ranks)
            elif item.scan_kind == "student" and reason == "edited_and_revalidated_in_scan_page":
                item.review_required = any(
                    row.get("status") not in NON_REVIEW_EVIDENCE_STATUSES for row in item.evidence
                )
            item.revision += 1
            item.approved = approve
            return item.to_wire()

    @staticmethod
    def _confirmed_fields(scan_kind, payload, fields) -> tuple[str, ...]:
        if fields is None:
            return ()
        if (not isinstance(fields, (list, tuple)) or any(not isinstance(field, str) for field in fields)
                or len(set(fields)) != len(fields)):
            raise ScannerError("invalid_payload", "confirmed_fields must be distinct field names")
        values = payload.get("values", {}) if scan_kind == "student" else {}
        if any(field not in values for field in fields):
            raise ScannerError("invalid_payload", "confirmed_fields must belong to student values")
        return tuple(fields)

    def _train_answer_sample(self, session, item, payload, reason: str, approve: bool,
                             confirmed_fields: tuple[str, ...]) -> dict:
        """Only an explicit user answer becomes a stored recognition sample."""
        if not (
            self._candidate_review_hook is not None
            and session.profile_id is not None
            and item.answer_specimen
            and (
                (item.scan_kind == "student" and reason == "edited_and_revalidated_in_scan_page" and confirmed_fields)
                or (item.scan_kind == "inventory" and approve)
            )
        ):
            return {}
        try:
            sample_count = self._candidate_review_hook(
                item.scan_kind, session.profile_id, item.candidate_id,
                item.answer_specimen, payload, reason, approve,
                confirmed_fields,
            )
            report = item.answer_specimen.pop("_sample_training_report", {})
            item.audit.append({
                "source": "user_confirmed_answer_sample",
                "sample_count": sample_count or 0,
                **report,
            })
            return report
        except (OSError, ValueError) as exc:
            item.audit.append({
                "source": "user_confirmed_answer_sample",
                "status": "storage_failed",
                "message": str(exc),
            })
            return {}

    @staticmethod
    def _mark_user_verified(item, payload, confirmed_fields, blocked_fields=()) -> None:
        """Fields the user edited and revalidated no longer count as unresolved evidence."""
        values = payload.get("values") if isinstance(payload, dict) else None
        if not isinstance(values, dict):
            return
        reviewed: list[dict[str, Any]] = []
        for evidence in item.evidence:
            replacement = deepcopy(evidence)
            if (
                isinstance(replacement, dict)
                and replacement.get("field") in confirmed_fields
                and replacement.get("field") not in blocked_fields
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

    def _revalidate_student(self, session, item, relationship_ranks) -> None:
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
        request = {
            "session_id": session_id, "generation": generation,
            "candidate_id": candidate_id, "candidate_revision": candidate_revision,
            "profile_id": profile_id, "expected_repository_revision": expected_repository_revision,
            "idempotency_key": idempotency_key,
        }
        with self._lock:
            cached = self._current_commits.get((session_id, idempotency_key))
            if cached is not None and cached.public_request_json != canonical_json(request):
                raise ScannerError("idempotency_conflict", "idempotency key belongs to another scanner request")
            session = self._session(session_id, generation)
            if session.scan_kind in {"student", "inventory"}:
                return self._commit_current(session, request)
            item = self._committable_candidate(session, candidate_id, candidate_revision)
            payload = self._validated_payload(item.scan_kind, item.payload)
        # Tactical persistence remains its existing four-argument path.
        if self._tactical_lobby_committer is None:
            raise ScannerError("persistence_deferred", "tactical lobby persistence is not configured")
        result = self._tactical_lobby_committer(
            profile_id, payload, expected_repository_revision, idempotency_key,
        )
        with self._lock:
            self._close_specimen(item.answer_specimen)
            item.answer_specimen = {}
        return {"candidate_id": candidate_id, "candidate_revision": candidate_revision,
                "profile_id": profile_id, **result}

    @staticmethod
    def _committable_candidate(session, candidate_id, candidate_revision):
        item = session.candidates.get(candidate_id)
        if item is None:
            raise ScannerError("candidate_not_found", "scanner candidate was not found")
        if item.revision != candidate_revision:
            raise ScannerError("candidate_revision_conflict", "candidate revision is stale")
        if session.terminal != "completed":
            raise ScannerError("session_not_committable", "only a completed session can commit")
        if item.review_required and not item.approved:
            raise ScannerError("review_required", "candidate requires explicit review approval")
        return item

    @staticmethod
    def _inventory_keys(payload):
        return tuple(dict.fromkeys(canonical_resource_key(entry.get("item_id") or entry["key"])
                                  for entry in payload.get("entries", [])))

    @classmethod
    def _remember_inventory_keys(cls, item, payload):
        item.identified_inventory_keys = tuple(dict.fromkeys(
            (*item.identified_inventory_keys, *cls._inventory_keys(payload)),
        ))

    def _prepare_current_commit(self, session, item, request, public_request_json):
        payload = self._validated_payload(item.scan_kind, item.payload)
        bucket = "students" if item.scan_kind == "student" else "inventory"
        if bucket == "inventory":
            self._require_catalog_revision(item, payload)
        scanned = payload.to_dict()
        applied = ([scanned["student_id"]] if bucket == "students" else
                   [entry.get("item_id") or entry["key"] for entry in scanned["entries"]])
        canonical_applied = set(canonical_resource_key(key) for key in applied) if bucket == "inventory" else set(applied)
        excluded = [key for key in item.identified_inventory_keys if key not in canonical_applied] if bucket == "inventory" else []
        try:
            context = ScanCommitHistoryContext.from_wire({
                "source": "scan", "session_id": session.session_id, "generation": session.generation,
                "candidate_id": item.candidate_id, "candidate_revision": item.revision,
                "scan_kind": session.scan_kind,
                "inventory_scan_profile": session.target.get("inventory_scan_profile"),
                "applied_keys": applied, "excluded_keys": excluded, "retry_of": None,
            }, bucket=bucket)
            # Validate scope before get_state; empty/all-excluded never becomes an application.
            state = self._repository.get_state(request["profile_id"])
            if bucket == "students":
                current = canonical_students([
                    row for row in state["students"] if row["student_id"] != scanned["student_id"]
                ] + [scanned])
            else:
                current = rebase_inventory_snapshot(self._merged_inventory(state["inventory"], scanned))
        except (HistoryError, RepositoryDTOError) as error:
            raise ScannerError("invalid_candidate", str(error), details={"reason": getattr(error, "reason", "invalid_candidate")}) from error
        return _FrozenCurrentCommit(public_request_json, bucket, canonical_json(current), context)

    @staticmethod
    def _invoke_current_writer(writer, request, frozen):
        try:
            parameters = inspect.signature(writer).parameters
        except (TypeError, ValueError) as error:
            raise ScannerError("persistence_deferred", "repository writer signature is unavailable") from error
        supports_context = ("history_context" in parameters and
                            parameters["history_context"].kind != inspect.Parameter.POSITIONAL_ONLY)
        supports_context = supports_context or any(p.kind == inspect.Parameter.VAR_KEYWORD for p in parameters.values())
        args = (request["profile_id"], json.loads(frozen.current_json),
                request["expected_repository_revision"], request["idempotency_key"])
        # Legacy four-argument test/callback ports remain usable; never retry a TypeError after a write.
        return writer(*args, history_context=frozen.context) if supports_context else writer(*args)

    def _commit_current(self, session, request):
        """Called under the service lock: freeze once, replay before revision/merge checks."""
        cache_key = (request["session_id"], request["idempotency_key"])
        public_request_json = canonical_json(request)
        receipt = self._current_commits.get(cache_key)
        if receipt is not None:
            if receipt.public_request_json != public_request_json:
                raise ScannerError("idempotency_conflict", "idempotency key belongs to another scanner request")
            if receipt.response_json is not None:
                return json.loads(receipt.response_json)
            if receipt.in_flight:
                raise ScannerError("persistence_deferred", "scanner commit is already in flight")
        else:
            item = self._committable_candidate(session, request["candidate_id"], request["candidate_revision"])
            frozen = self._prepare_current_commit(session, item, request, public_request_json)
            receipt = _CurrentCommitReceipt(public_request_json, frozen)
            self._current_commits[cache_key] = receipt
        receipt.in_flight = True
        try:
            frozen = receipt.request
            assert frozen is not None  # Pending receipts always retain the original submission.
            writer = self._repository.update_students if frozen.bucket == "students" else self._repository.update_inventory
            result = self._invoke_current_writer(writer, request, frozen)
            response = {"candidate_id": request["candidate_id"],
                        "candidate_revision": request["candidate_revision"],
                        "profile_id": request["profile_id"], **result}
            # The receipt is ready even if closing the accepted specimen fails after durable write.
            receipt.response_json = canonical_json(response)
            receipt.request = None  # Keep signature/response; release full bucket/context before cleanup.
            item = session.candidates.get(request["candidate_id"])
            if item is not None:
                self._release_candidate_images(session, item)
            return json.loads(receipt.response_json)
        finally:
            receipt.in_flight = False

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
                active.control.wake()
        if self._owns_executor:
            self._executor.shutdown(wait=True, cancel_futures=True)
        if self._resource_close_hook is not None:
            self._resource_close_hook()
        with self._lock:
            for session in self._sessions.values():
                for candidate in session.candidates.values():
                    self._release_candidate_images(session, candidate)

    def _release_candidate_images(self, session, item) -> None:
        specimen, item.answer_specimen = item.answer_specimen, {}
        if item.scan_kind == "student":
            remove_student_crop_images(item.evidence)
            for event in session.events:
                candidate = event.get("payload", {}).get("candidate")
                if isinstance(candidate, dict) and candidate.get("candidate_id") == item.candidate_id:
                    remove_student_crop_images(candidate.get("evidence"))
        # Redact retained copies before closing PIL resources, including when a
        # resource close raises after a durable repository write.
        self._close_specimen(specimen)

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
    def _require_catalog_revision(item: SessionCandidate, payload: InventorySnapshot) -> None:
        """A scan is only meaningful against the catalog order it was recognized with."""
        if payload.catalog_revision == CATALOG_REVISION:
            return
        code = "catalog_revision_missing" if payload.catalog_revision is None else "catalog_revision_mismatch"
        details = {"expected": CATALOG_REVISION, "received": payload.catalog_revision}
        item.audit.append({"source": "catalog_revision_check", "status": "rejected", "code": code, **details})
        raise ScannerError(code, "inventory candidate catalog revision does not match the current catalog", details=details)

    @staticmethod
    def _merged_inventory(saved: dict[str, Any], scanned: dict[str, Any]) -> dict[str, Any]:
        """Upsert scanned entries by identity; a scan never deletes entries it did not observe."""
        def identity(entry: dict[str, Any]) -> str:
            return canonical_resource_key(entry.get("item_id") or entry["key"])
        updates = {identity(entry): entry for entry in scanned["entries"]}
        entries = [updates.pop(identity(entry), entry) for entry in saved.get("entries", [])]
        entries.extend(updates.values())
        return {"version": 1, "catalog_revision": scanned.get("catalog_revision"), "entries": entries}

    @staticmethod
    def _repository_inventory(payload: object) -> object:
        """Drop scanner-only entry fields; the repository keeps its catalog-derived profile_id."""
        if not isinstance(payload, dict) or not isinstance(payload.get("entries"), list):
            return payload
        entries = []
        for entry in payload["entries"]:
            if isinstance(entry, dict) and "inventory_scan_profile" in entry:
                scan_profile = entry["inventory_scan_profile"]
                if scan_profile is not None and scan_profile not in SCAN_PROFILES:
                    raise RepositoryDTOError("inventory_entry.inventory_scan_profile is not a scan profile")
                entry = {key: value for key, value in entry.items() if key not in SCANNER_ONLY_ENTRY_FIELDS}
            entries.append(entry)
        return {**payload, "entries": entries}

    @staticmethod
    def _validated_payload(scan_kind: str, payload: object) -> ConfirmedStudent | InventorySnapshot | dict[str, Any]:
        if scan_kind == "tactical_lobby":
            from core.tactical_lobby_scanner import canonical_tactical_lobby_candidate
            return canonical_tactical_lobby_candidate(payload)
        try:
            return (
                ConfirmedStudent.from_dict(payload)
                if scan_kind == "student"
                else InventorySnapshot.from_dict(ScannerSessionService._repository_inventory(payload))
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

            progress = _SessionProgress(self, session)

            context = ScanContext.of(session.target).replace(
                cancel=session.cancel, session_id=session.session_id, generation=session.generation,
                control=session.control,
            )
            result = self._matchers[session.scan_kind](context, session.cancel, progress)
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
                with session.control.operation():
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
        evidence = deepcopy(evidence)
        specimen = dict(raw.get("_answer_specimen", {})) if isinstance(raw.get("_answer_specimen"), Mapping) else {}
        if session.scan_kind == "student":
            attach_student_fallback_details(evidence, specimen)
        return SessionCandidate(
            candidate_id=str(raw.get("candidate_id") or self._id_factory()),
            session_id=session.session_id,
            generation=session.generation,
            scan_kind=session.scan_kind,
            payload=deepcopy(payload),
            evidence=evidence,
            review_required=review_required,
            identified_inventory_keys=(self._inventory_keys(payload) if session.scan_kind == "inventory" else ()),
            validation_relationship_ranks=dict(relationship_ranks or {}),
            answer_specimen=specimen,
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
        return self._student_validator(payload, profile_id, relationship_ranks)

    def _emit(self, session: _Session, event_kind: str, data: dict[str, Any]) -> None:
        with session.control.operation():
            self._emit_unchecked(session, event_kind, data)

    def _emit_unchecked(self, session: _Session, event_kind: str, data: dict[str, Any]) -> None:
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
        session.control.checkpoint()
        with self._lock:
            if session.terminal is not None:
                return
            session.sequence += 1
            session.terminal = outcome
            session.control.finish(outcome)
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


class _SessionProgress:
    """Emits progress and per-field feedback events for one running session."""

    supports_feedback = True

    def __init__(self, service: "ScannerSessionService", session: "_Session") -> None:
        self._service, self._session = service, session

    def __call__(self, current: int, total: int | None, message_key: str,
                 feedback: Mapping[str, Any] | None = None) -> None:
        session = self._session
        if session.cancel.is_set():
            return
        self._service._emit(session, "progress", {
            "current": current, "total": total, "message_key": message_key,
        })
        if feedback is None:
            return
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
            self._service._emit(session, "feedback", {
                "student_id": student_id,
                "field": field,
                "values": dict(values),
            })


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
