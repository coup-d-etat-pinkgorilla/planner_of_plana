"""Immutable server-internal scan provenance; not a public RPC/event DTO."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from core.current_history import HistoryError, ScanHistoryContext
from core.inventory_catalog import canonical_resource_key

FIELDS = (
    "source", "session_id", "generation", "candidate_id", "candidate_revision",
    "scan_kind", "inventory_scan_profile", "applied_keys", "excluded_keys", "retry_of",
)


def _fail(message: str, reason: str = "invalid_history") -> None:
    raise HistoryError(reason, message)


def _text(value: object) -> str:
    if not isinstance(value, str):
        _fail("Scan commit identifiers must be text")
    try:
        size = len(value.encode("utf-8"))
    except UnicodeEncodeError:
        _fail("Scan commit identifiers must be valid UTF-8")
    if not 1 <= size <= 1024:
        _fail("Scan commit identifiers must be 1..1024 UTF-8 bytes")
    return value


@dataclass(frozen=True, init=False)
class ScanCommitHistoryContext:
    source: str
    session_id: str
    generation: int
    candidate_id: str
    candidate_revision: int
    scan_kind: str
    inventory_scan_profile: str | None
    applied_keys: tuple[str, ...]
    excluded_keys: tuple[str, ...]
    retry_of: str | None
    bucket: str

    @classmethod
    def from_wire(cls, value: object, *, bucket: str) -> "ScanCommitHistoryContext":
        if bucket not in ("students", "inventory"):
            _fail("Writer bucket must be students or inventory", "scan_scope_mismatch")
        if not isinstance(value, dict) or set(value) != set(FIELDS):
            _fail("Scan commit history context must have exactly the ten v1 keys")
        if value["source"] != "scan":
            _fail("Internal scan commit source must be scan")
        canonical = dict(value)
        for field in ("session_id", "candidate_id", "scan_kind"):
            canonical[field] = _text(value[field])
        for field in ("inventory_scan_profile", "retry_of"):
            if value[field] is not None:
                canonical[field] = _text(value[field])
        for field, minimum in (("generation", 1), ("candidate_revision", 0)):
            if type(value[field]) is not int or value[field] < minimum:
                _fail(f"{field} must be an exact integer >= {minimum}")
        for field in ("applied_keys", "excluded_keys"):
            if not isinstance(value[field], list):
                _fail(f"{field} must be an array")
            keys = [_text(key) for key in value[field]]
            if bucket == "inventory":
                keys = [_text(canonical_resource_key(key)) for key in keys]
            if len(set(keys)) != len(keys):
                _fail("Duplicate canonical scan identity", "duplicate_identity")
            canonical[field] = tuple(keys)
        if not canonical["applied_keys"]:
            _fail("Scan applied scope must be non-empty", "empty_scan_scope")
        if set(canonical["applied_keys"]) & set(canonical["excluded_keys"]):
            _fail("Applied and excluded canonical identities must be disjoint", "scan_scope_mismatch")
        result = object.__new__(cls)
        for field in FIELDS:
            object.__setattr__(result, field, canonical[field])
        object.__setattr__(result, "bucket", bucket)
        return result

    def to_wire(self) -> dict[str, Any]:
        result = {field: getattr(self, field) for field in FIELDS}
        for field in ("applied_keys", "excluded_keys"):
            result[field] = list(result[field])
        return result

    def to_history_context(self) -> ScanHistoryContext:
        """Persist only existing nested v1 metadata; keep provenance in the hash."""
        return ScanHistoryContext.from_wire({
            "source": self.source, "scan_kind": self.scan_kind,
            "inventory_scan_profile": self.inventory_scan_profile,
            "scan_context": {field: getattr(self, field) for field in
                             ("session_id", "generation", "candidate_id", "candidate_revision")},
            "applied_scope": {
                "student_ids": list(self.applied_keys) if self.bucket == "students" else [],
                "resource_keys": list(self.applied_keys) if self.bucket == "inventory" else [],
            },
        })
