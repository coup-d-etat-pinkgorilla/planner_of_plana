from __future__ import annotations

from dataclasses import asdict, dataclass, fields
import json
from typing import Any, ClassVar

from core.planning import (
    MAX_TARGET_EQUIP4_TIER, MAX_TARGET_EQUIP_LEVEL, MAX_TARGET_EQUIP_TIER,
    MAX_TARGET_EX_SKILL, MAX_TARGET_LEVEL, MAX_TARGET_SKILL, MAX_TARGET_STAR,
    MAX_TARGET_STAT, MAX_TARGET_WEAPON_LEVEL, MAX_TARGET_WEAPON_STAR,
    StudentGoal,
)


DTO_VERSION = 1


class RepositoryDTOError(ValueError):
    """Raised when repository boundary data is not canonical and safe."""


def canonical_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise RepositoryDTOError(f"{label} must be an object")
    return value


def _strict(data: dict[str, Any], allowed: set[str], required: set[str], label: str) -> None:
    unknown = set(data) - allowed
    missing = required - set(data)
    if unknown:
        raise RepositoryDTOError(f"{label} contains unknown fields: {sorted(unknown)}")
    if missing:
        raise RepositoryDTOError(f"{label} is missing required fields: {sorted(missing)}")


def _text(value: object, label: str, *, nullable: bool = False) -> str | None:
    if value is None and nullable:
        return None
    if not isinstance(value, str) or not value:
        raise RepositoryDTOError(f"{label} must be a non-empty string")
    return value


def _optional_int(value: object, label: str) -> int | None:
    if value is None:
        return None
    if not isinstance(value, int) or isinstance(value, bool):
        raise RepositoryDTOError(f"{label} must be an integer or null")
    return value


def _version(data: dict[str, Any], label: str) -> None:
    if data.get("version") != DTO_VERSION or isinstance(data.get("version"), bool):
        raise RepositoryDTOError(f"{label}.version must be {DTO_VERSION}")


CONFIRMED_STUDENT_VALUE_FIELDS = (
    "level", "student_star", "weapon_state", "weapon_star",
    "weapon_level", "ex_skill", "skill1", "skill2", "skill3", "equip1",
    "equip2", "equip3", "equip4", "equip1_level", "equip2_level",
    "equip3_level", "combat_hp", "combat_atk", "combat_def", "combat_heal",
    "form_combat_stats", "stat_hp", "stat_atk", "stat_heal",
)
# Backward-compatible name; this set describes v7 confirmed current only, not
# the wider v6 merge-parity field set in repository_merge.STUDENT_FIELDS.
STUDENT_VALUE_FIELDS = CONFIRMED_STUDENT_VALUE_FIELDS
_STRING_FIELDS = {"weapon_state", "equip1", "equip2", "equip3", "equip4"}
_DICT_FIELDS = {"form_combat_stats"}
_FORBIDDEN_BUCKET_FIELDS = {
    "metadata", "student_meta", "goal", "goals", "plan", "cost", "costs",
    "shortage", "shortages", "required_materials", "total_cost",
}
FORBIDDEN_BUCKET_FIELDS = frozenset(_FORBIDDEN_BUCKET_FIELDS)
_GOAL_MAXIMUMS = {
    "target_level": MAX_TARGET_LEVEL,
    "target_star": MAX_TARGET_STAR,
    "target_weapon_level": MAX_TARGET_WEAPON_LEVEL,
    "target_weapon_star": MAX_TARGET_WEAPON_STAR,
    "target_ex_skill": MAX_TARGET_EX_SKILL,
    "target_skill1": MAX_TARGET_SKILL,
    "target_skill2": MAX_TARGET_SKILL,
    "target_skill3": MAX_TARGET_SKILL,
    "target_equip1_tier": MAX_TARGET_EQUIP_TIER,
    "target_equip2_tier": MAX_TARGET_EQUIP_TIER,
    "target_equip3_tier": MAX_TARGET_EQUIP_TIER,
    "target_equip1_level": MAX_TARGET_EQUIP_LEVEL,
    "target_equip2_level": MAX_TARGET_EQUIP_LEVEL,
    "target_equip3_level": MAX_TARGET_EQUIP_LEVEL,
    "target_equip4_tier": MAX_TARGET_EQUIP4_TIER,
    "target_stat_hp": MAX_TARGET_STAT,
    "target_stat_atk": MAX_TARGET_STAT,
    "target_stat_heal": MAX_TARGET_STAT,
}


def _validate_goal(goal: object) -> StudentGoal:
    if not isinstance(goal, StudentGoal):
        raise RepositoryDTOError("student_goal_record.goal must be a StudentGoal")
    _text(goal.student_id, "student_goal_record.goal.student_id")
    if not isinstance(goal.favorite, bool):
        raise RepositoryDTOError("student_goal_record.goal.favorite must be a boolean")
    if not isinstance(goal.notes, str):
        raise RepositoryDTOError("student_goal_record.goal.notes must be a string")
    for name, maximum in _GOAL_MAXIMUMS.items():
        value = getattr(goal, name)
        if value is None:
            continue
        if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= maximum:
            raise RepositoryDTOError(
                f"student_goal_record.goal.{name} must be null or an integer from 0 to {maximum}"
            )
    return goal


@dataclass(frozen=True, slots=True)
class ConfirmedStudent:
    student_id: str
    values: dict[str, Any]
    provenance: dict[str, str] | None = None
    version: int = DTO_VERSION

    @classmethod
    def from_dict(cls, value: object) -> "ConfirmedStudent":
        data = _object(value, "confirmed_student")
        _strict(data, {"version", "student_id", "values", "provenance"}, {"version", "student_id", "values"}, "confirmed_student")
        _version(data, "confirmed_student")
        student_id = _text(data["student_id"], "confirmed_student.student_id")
        values = _object(data["values"], "confirmed_student.values")
        if set(values) & _FORBIDDEN_BUCKET_FIELDS:
            raise RepositoryDTOError("confirmed_student.values crosses a data-bucket boundary")
        unknown = set(values) - set(CONFIRMED_STUDENT_VALUE_FIELDS)
        if unknown:
            raise RepositoryDTOError(f"confirmed_student.values contains unknown fields: {sorted(unknown)}")
        canonical: dict[str, Any] = {}
        for key, item in values.items():
            if key in _STRING_FIELDS:
                if item is not None and not isinstance(item, str):
                    raise RepositoryDTOError(f"confirmed_student.values.{key} must be a string or null")
            elif key in _DICT_FIELDS:
                if not isinstance(item, dict):
                    raise RepositoryDTOError("confirmed_student.values.form_combat_stats must be an object")
            else:
                _optional_int(item, f"confirmed_student.values.{key}")
            canonical[key] = item
        provenance = data.get("provenance")
        if provenance is not None:
            provenance = _object(provenance, "confirmed_student.provenance")
            if not all(isinstance(k, str) and isinstance(v, str) for k, v in provenance.items()):
                raise RepositoryDTOError("confirmed_student.provenance values must be strings")
        return cls(student_id=student_id, values=canonical, provenance=provenance)

    def to_dict(self) -> dict[str, Any]:
        result = {"version": self.version, "student_id": self.student_id, "values": self.values}
        if self.provenance is not None:
            result["provenance"] = self.provenance
        return result


@dataclass(frozen=True, slots=True)
class InventoryEntry:
    key: str
    quantity: str | None
    item_id: str | None = None
    name: str | None = None
    index: int | None = None
    profile_id: str | None = None

    @classmethod
    def from_dict(cls, value: object) -> "InventoryEntry":
        data = _object(value, "inventory_entry")
        allowed = {item.name for item in fields(cls)}
        _strict(data, allowed, {"key", "quantity"}, "inventory_entry")
        key = _text(data["key"], "inventory_entry.key")
        for name in ("quantity", "item_id", "name", "profile_id"):
            if data.get(name) is not None and not isinstance(data[name], str):
                raise RepositoryDTOError(f"inventory_entry.{name} must be a string or null")
        index = _optional_int(data.get("index"), "inventory_entry.index")
        return cls(key=key, quantity=data["quantity"], item_id=data.get("item_id"), name=data.get("name"), index=index, profile_id=data.get("profile_id"))

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class InventorySnapshot:
    entries: tuple[InventoryEntry, ...]
    version: int = DTO_VERSION

    @classmethod
    def from_dict(cls, value: object) -> "InventorySnapshot":
        data = _object(value, "inventory_snapshot")
        _strict(data, {"version", "entries"}, {"version", "entries"}, "inventory_snapshot")
        _version(data, "inventory_snapshot")
        if not isinstance(data["entries"], list):
            raise RepositoryDTOError("inventory_snapshot.entries must be an array")
        return cls(entries=tuple(InventoryEntry.from_dict(item) for item in data["entries"]))

    def to_dict(self) -> dict[str, Any]:
        return {"version": self.version, "entries": [item.to_dict() for item in self.entries]}


@dataclass(frozen=True, slots=True)
class StudentGoalRecord:
    goal: StudentGoal
    version: int = DTO_VERSION

    def __post_init__(self) -> None:
        if self.version != DTO_VERSION or isinstance(self.version, bool):
            raise RepositoryDTOError(f"student_goal_record.version must be {DTO_VERSION}")
        _validate_goal(self.goal)

    def to_dict(self) -> dict[str, Any]:
        _validate_goal(self.goal)
        return {"version": self.version, "goal": asdict(self.goal)}

    @classmethod
    def from_dict(cls, value: object) -> "StudentGoalRecord":
        data = _object(value, "student_goal_record")
        _strict(data, {"version", "goal"}, {"version", "goal"}, "student_goal_record")
        _version(data, "student_goal_record")
        goal = _object(data["goal"], "student_goal_record.goal")
        allowed = {item.name for item in fields(StudentGoal)}
        _strict(goal, allowed, {"student_id"}, "student_goal_record.goal")
        return cls(StudentGoal(**goal))


@dataclass(frozen=True, slots=True)
class FieldEvidence:
    field: str
    status: str
    source: str
    confidence: float | None = None
    note: str = ""

    STATUSES: ClassVar[frozenset[str]] = frozenset({"ok", "inferred", "uncertain", "failed", "skipped", "region_missing"})

    @classmethod
    def from_dict(cls, value: object) -> "FieldEvidence":
        data = _object(value, "field_evidence")
        allowed = {item.name for item in fields(cls)}
        _strict(data, allowed, {"field", "status", "source"}, "field_evidence")
        field_name = _text(data["field"], "field_evidence.field")
        status = _text(data["status"], "field_evidence.status")
        source = _text(data["source"], "field_evidence.source")
        if status not in cls.STATUSES:
            raise RepositoryDTOError(f"unsupported field evidence status: {status}")
        confidence = data.get("confidence")
        if confidence is not None and (isinstance(confidence, bool) or not isinstance(confidence, (int, float)) or not 0 <= confidence <= 1):
            raise RepositoryDTOError("field_evidence.confidence must be a number from 0 to 1 or null")
        note = data.get("note", "")
        if not isinstance(note, str):
            raise RepositoryDTOError("field_evidence.note must be a string")
        return cls(field=field_name, status=status, source=source, confidence=float(confidence) if confidence is not None else None, note=note)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class ScannerCandidate:
    candidate_id: str
    session_id: str
    target_kind: str
    payload: dict[str, Any]
    evidence: tuple[FieldEvidence, ...]
    review_required: bool
    version: int = DTO_VERSION

    @classmethod
    def from_dict(cls, value: object) -> "ScannerCandidate":
        data = _object(value, "scanner_candidate")
        allowed = {"version", "candidate_id", "session_id", "target_kind", "payload", "evidence", "review_required"}
        _strict(data, allowed, allowed, "scanner_candidate")
        _version(data, "scanner_candidate")
        if data["target_kind"] not in {"student", "inventory"}:
            raise RepositoryDTOError("scanner_candidate.target_kind must be student or inventory")
        payload = _object(data["payload"], "scanner_candidate.payload")
        if set(payload) & _FORBIDDEN_BUCKET_FIELDS:
            raise RepositoryDTOError("scanner_candidate.payload crosses a data-bucket boundary")
        if not isinstance(data["evidence"], list) or not isinstance(data["review_required"], bool):
            raise RepositoryDTOError("scanner_candidate evidence/review_required has an invalid type")
        return cls(candidate_id=_text(data["candidate_id"], "scanner_candidate.candidate_id"), session_id=_text(data["session_id"], "scanner_candidate.session_id"), target_kind=data["target_kind"], payload=payload, evidence=tuple(FieldEvidence.from_dict(item) for item in data["evidence"]), review_required=data["review_required"])

    def to_dict(self) -> dict[str, Any]:
        return {"version": self.version, "candidate_id": self.candidate_id, "session_id": self.session_id, "target_kind": self.target_kind, "payload": self.payload, "evidence": [item.to_dict() for item in self.evidence], "review_required": self.review_required}


@dataclass(frozen=True, slots=True)
class RepositoryCommitCommand:
    command_id: str
    candidate_id: str
    target_kind: str
    confirmed_payload: ConfirmedStudent | InventorySnapshot
    replace: bool = False
    profile_ids: tuple[str, ...] = ()
    version: int = DTO_VERSION

    def __post_init__(self) -> None:
        if self.version != DTO_VERSION or isinstance(self.version, bool):
            raise RepositoryDTOError(f"repository_commit.version must be {DTO_VERSION}")
        _text(self.command_id, "repository_commit.command_id")
        _text(self.candidate_id, "repository_commit.candidate_id")
        if self.target_kind == "student":
            if not isinstance(self.confirmed_payload, ConfirmedStudent):
                raise RepositoryDTOError("repository_commit student payload must be ConfirmedStudent")
            ConfirmedStudent.from_dict(self.confirmed_payload.to_dict())
            if self.profile_ids:
                raise RepositoryDTOError("repository_commit student profile_ids must be empty")
        elif self.target_kind == "inventory":
            if not isinstance(self.confirmed_payload, InventorySnapshot):
                raise RepositoryDTOError("repository_commit inventory payload must be InventorySnapshot")
            InventorySnapshot.from_dict(self.confirmed_payload.to_dict())
            if self.replace:
                raise RepositoryDTOError("repository_commit inventory replace must be false; use profile_ids")
        else:
            raise RepositoryDTOError("repository_commit.target_kind must be student or inventory")
        if not isinstance(self.replace, bool):
            raise RepositoryDTOError("repository_commit.replace must be a boolean")
        if not isinstance(self.profile_ids, tuple) or not all(isinstance(item, str) and item for item in self.profile_ids):
            raise RepositoryDTOError("repository_commit.profile_ids must contain non-empty strings")

    @classmethod
    def from_dict(cls, value: object) -> "RepositoryCommitCommand":
        data = _object(value, "repository_commit")
        allowed = {"version", "command_id", "candidate_id", "target_kind", "confirmed_payload", "replace", "profile_ids"}
        _strict(data, allowed, {"version", "command_id", "candidate_id", "target_kind", "confirmed_payload", "replace", "profile_ids"}, "repository_commit")
        _version(data, "repository_commit")
        if data["target_kind"] not in {"student", "inventory"} or not isinstance(data["replace"], bool) or not isinstance(data["profile_ids"], list) or not all(isinstance(item, str) and item for item in data["profile_ids"]):
            raise RepositoryDTOError("repository_commit contains invalid target/options")
        payload = (
            ConfirmedStudent.from_dict(data["confirmed_payload"])
            if data["target_kind"] == "student"
            else InventorySnapshot.from_dict(data["confirmed_payload"])
        )
        return cls(command_id=_text(data["command_id"], "repository_commit.command_id"), candidate_id=_text(data["candidate_id"], "repository_commit.candidate_id"), target_kind=data["target_kind"], confirmed_payload=payload, replace=data["replace"], profile_ids=tuple(data["profile_ids"]))

    def to_dict(self) -> dict[str, Any]:
        self.__post_init__()
        return {"version": self.version, "command_id": self.command_id, "candidate_id": self.candidate_id, "target_kind": self.target_kind, "confirmed_payload": self.confirmed_payload.to_dict(), "replace": self.replace, "profile_ids": list(self.profile_ids)}
