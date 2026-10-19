"""Authoring v1 is adjacent to a calculation document, never part of its targets."""
from __future__ import annotations

from collections import deque
from typing import Any, NoReturn

from core.planning_document import (
    PlanningDocumentError, planning_document_from_wire, planning_document_to_wire,
    planning_targets_from_wire,
)

AUTHORING_UNSET = object()


class PlanningAuthoringError(ValueError):
    def __init__(self, reason: str, message: str, **details: Any) -> None:
        super().__init__(message)
        self.reason = reason
        self.details = {"reason": reason, **details}


def _fail(reason: str, message: str, **details: Any) -> NoReturn:
    raise PlanningAuthoringError(reason, message, **details)


def _text(value: object, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        _fail("invalid_shape", f"{label} must be non-empty text")
    return value.strip()


def default_authoring(document: object) -> dict[str, Any]:
    document = planning_document_to_wire(planning_document_from_wire(document))
    order: dict[str, list[str]] = {}
    for phase in document["phases"]:
        for stage in phase["stages"]:
            order.setdefault(stage["student_id"], []).append(stage["stage_id"])
    return {"version": 1, "prerequisites": [], "deferred_stages": [],
            "student_order": list(order), "stage_order_by_student": order, "goal_metadata": {}}


def planning_authoring_from_wire(value: object, document: object) -> dict[str, Any]:
    """Validate the whole bundle; preserve every meaningful array order."""
    document = planning_document_to_wire(planning_document_from_wire(document))
    required = {"version", "prerequisites", "deferred_stages", "student_order", "stage_order_by_student", "goal_metadata"}
    if not isinstance(value, dict) or set(value) != required:
        _fail("invalid_shape", "authoring must contain exactly the six v1 keys")
    if type(value["version"]) is not int or value["version"] != 1:
        _fail("unsupported_version", "authoring.version must be 1")
    for key in ("prerequisites", "deferred_stages", "student_order"):
        if not isinstance(value[key], list):
            _fail("invalid_shape", f"authoring.{key} must be an array")
    if not isinstance(value["stage_order_by_student"], dict) or not isinstance(value["goal_metadata"], dict):
        _fail("invalid_shape", "authoring orders and metadata must be objects")
    students = [_text(item, "student_order entry") for item in value["student_order"]]
    if len(set(students)) != len(students):
        _fail("student_order", "student_order contains duplicate IDs")
    stages: dict[str, dict[str, Any]] = {}
    positions: dict[str, tuple[int, int]] = {}
    placed: dict[str, list[str]] = {}
    deferred: dict[str, list[str]] = {}
    for lane, phase in enumerate(document["phases"]):
        for index, stage in enumerate(phase["stages"]):
            stages[stage["stage_id"]] = stage
            positions[stage["stage_id"]] = (lane, index)
            placed.setdefault(stage["student_id"], []).append(stage["stage_id"])
    deferred_stages = []
    for index, raw in enumerate(value["deferred_stages"]):
        if not isinstance(raw, dict) or set(raw) != {"stage_id", "student_id", "name", "targets"}:
            _fail("invalid_shape", "deferred stage has an invalid shape")
        stage = {key: _text(raw[key], f"deferred_stages[{index}].{key}") for key in ("stage_id", "student_id", "name")}
        if stage["stage_id"] in stages:
            _fail("stage_set", "stage IDs must be globally unique", stage_id=stage["stage_id"])
        try:
            stage["targets"] = planning_targets_from_wire(raw["targets"], label=f"deferred_stages[{index}]", nullable=True)
        except PlanningDocumentError as error:
            _fail("targets", str(error), stage_id=stage["stage_id"])
        stages[stage["stage_id"]] = stage
        positions[stage["stage_id"]] = (len(document["phases"]), index)
        deferred.setdefault(stage["student_id"], []).append(stage["stage_id"])
        deferred_stages.append(stage)
    stage_students = {stage["student_id"] for stage in stages.values()}
    if not stage_students.issubset(students) or set(value["stage_order_by_student"]) != set(students):
        _fail("student_order", "selected students and order keys must cover every stage student")
    orders = {}
    edges: set[tuple[str, str]] = set()
    for student in students:
        ids = value["stage_order_by_student"][student]
        if not isinstance(ids, list) or any(not isinstance(item, str) for item in ids):
            _fail("invalid_shape", "student stage order must be an array of IDs")
        expected = placed.get(student, []) + deferred.get(student, [])
        if len(set(ids)) != len(ids) or set(ids) != set(expected):
            _fail("stage_set", "student stage order must cover exactly its own stages", student_id=student)
        if ids != expected:
            _fail("stage_chain", "placed prefix and deferred suffix must follow the student chain", student_id=student)
        previous = None
        for stage_id in ids:
            try:
                previous = planning_targets_from_wire(stages[stage_id]["targets"], label=stage_id, nullable=True, previous=previous)
            except PlanningDocumentError as error:
                _fail("target_regression", str(error), stage_id=stage_id)
        orders[student] = list(ids)
        edges.update(zip(ids, ids[1:]))
    metadata = value["goal_metadata"]
    if set(metadata) != set(students) - set(placed):
        _fail("goal_metadata", "authoring goal_metadata must match selected students absent from the document")
    canonical_metadata = {}
    for student, entry in metadata.items():
        if not isinstance(entry, dict) or set(entry) != {"favorite", "notes"} or type(entry["favorite"]) is not bool or not isinstance(entry["notes"], str):
            _fail("goal_metadata", "metadata requires favorite bool and notes string", student_id=student)
        canonical_metadata[student] = dict(entry)
    explicit: set[tuple[str, str]] = set()
    for pair in value["prerequisites"]:
        if not isinstance(pair, dict) or set(pair) != {"stage_id", "requires_stage_id"}:
            _fail("invalid_shape", "prerequisite requires exactly two stage IDs")
        dependent = _text(pair["stage_id"], "stage_id")
        prerequisite = _text(pair["requires_stage_id"], "requires_stage_id")
        if dependent not in stages or prerequisite not in stages:
            _fail("stage_reference", "prerequisite references an absent stage", stage_id=dependent, requires_stage_id=prerequisite)
        if dependent == prerequisite:
            _fail("self_reference", "a stage cannot require itself", stage_id=dependent)
        if stages[dependent]["student_id"] == stages[prerequisite]["student_id"]:
            _fail("same_student_prerequisite", "same-student prerequisites belong to the implicit chain")
        edge = (prerequisite, dependent)
        if edge in explicit:
            _fail("duplicate_prerequisite", "prerequisites must be unique")
        explicit.add(edge)
    edges.update(explicit)
    successors = {stage_id: [] for stage_id in stages}
    indegree = dict.fromkeys(stages, 0)
    for source, target in edges:
        successors[source].append(target)
        indegree[target] += 1
    queue = deque(stage_id for stage_id in stages if indegree[stage_id] == 0)
    visited = 0
    while queue:
        stage_id = queue.popleft()
        visited += 1
        for successor in successors[stage_id]:
            indegree[successor] -= 1
            if indegree[successor] == 0:
                queue.append(successor)
    if visited != len(stages):
        _fail("cycle", "implicit and direct prerequisites must form a DAG")
    for source, target in sorted(edges):
        if positions[source][0] > positions[target][0]:
            _fail("lane_order", "a prerequisite cannot occupy a later lane", stage_id=target, requires_stage_id=source)
        if positions[source][0] == positions[target][0] and positions[source][1] >= positions[target][1]:
            _fail("stage_order", "same-lane array order must place the prerequisite first", stage_id=target, requires_stage_id=source)
    return {"version": 1, "prerequisites": [{"stage_id": target, "requires_stage_id": source} for source, target in sorted(explicit)],
            "deferred_stages": deferred_stages, "student_order": students,
            "stage_order_by_student": orders, "goal_metadata": canonical_metadata}


def authoring_is_default(authoring: dict[str, Any], document: object) -> bool:
    return authoring == default_authoring(document)


def authoring_has_content(authoring: dict[str, Any]) -> bool:
    return bool(authoring["student_order"] or authoring["deferred_stages"])
