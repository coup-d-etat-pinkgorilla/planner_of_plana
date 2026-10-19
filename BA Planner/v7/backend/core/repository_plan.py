"""Lossless active-plan conversion; no current-state or cost normalization."""
from typing import Any

from core.planning_document import planning_document_from_wire, planning_document_to_wire
from core.planning_growth_rules import TARGET_TO_GOAL
from core.repository_dto import StudentGoalRecord


class LegacyGoalsConflict(ValueError):
    def __init__(self, student_ids: list[str]) -> None:
        super().__init__('duplicate legacy goals cannot be converted without changing additive costs')
        self.student_ids = student_ids


def canonical_active_document(value: object) -> dict[str, Any]:
    document = planning_document_from_wire(value)
    if document.version != 2 or document.kind != 'plan':
        raise ValueError('active document must be version 2 with kind=plan')
    return planning_document_to_wire(document)


def goals_from_document(value: object) -> dict[str, Any]:
    document = planning_document_from_wire(canonical_active_document(value))
    # Updating a dict retains the student's first-appearance order.
    final = {}
    for phase in document.phases:
        for stage in phase.stages:
            final[stage.student_id] = stage
    goals = []
    for student_id, stage in final.items():
        metadata = document.goal_metadata[student_id]
        goal = {
            'student_id': student_id, 'favorite': metadata.favorite, 'notes': metadata.notes,
            **{field: stage.targets[key] for key, field in TARGET_TO_GOAL.items()},
        }
        goals.append(StudentGoalRecord.from_dict({'version': 1, 'goal': goal}).to_dict()['goal'])
    return {'version': 1, 'goals': goals}


def document_from_goals(value: object) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != {'version', 'goals'} or type(value['version']) is not int or value['version'] != 1 or not isinstance(value['goals'], list):
        raise ValueError('goals must be a version 1 goal plan')
    goals = [StudentGoalRecord.from_dict({'version': 1, 'goal': item}).to_dict()['goal'] for item in value['goals']]
    seen, duplicates = set(), []
    for goal in goals:
        student_id = goal['student_id']
        if student_id in seen and student_id not in duplicates:
            duplicates.append(student_id)
        seen.add(student_id)
    if duplicates:
        raise LegacyGoalsConflict(duplicates)
    stages = [{
        'stage_id': f"v6-{goal['student_id']}-1", 'student_id': goal['student_id'],
        'name': goal['notes'].strip() or 'v6 목표',
        'targets': {**{key: goal[field] for key, field in TARGET_TO_GOAL.items()}, 'bond_rank': None},
    } for goal in goals]
    return canonical_active_document({
        'version': 2, 'document_id': 'active-plan', 'name': '활성 계획', 'kind': 'plan',
        'phases': [{'phase_id': 'v6-imported-plan', 'name': 'v6 목표', 'stages': stages}] if stages else [],
        'goal_metadata': {goal['student_id']: {'favorite': goal['favorite'], 'notes': goal['notes']} for goal in goals},
    })


def legacy_write_loss(value: object) -> list[str]:
    document = planning_document_from_wire(canonical_active_document(value))
    stages = [stage for phase in document.phases for stage in phase.stages]
    reasons = []
    if len(document.phases) > 1:
        reasons.append('multiple_phases')
    if len({stage.student_id for stage in stages}) != len(stages):
        reasons.append('multiple_student_stages')
    if any(stage.targets['bond_rank'] is not None for stage in stages):
        reasons.append('bond_target')
    return reasons
