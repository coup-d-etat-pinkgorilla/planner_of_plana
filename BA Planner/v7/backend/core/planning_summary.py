"""One calculation-summary boundary for scenarios and the active document."""
from types import SimpleNamespace
from typing import Any

from core.planning_document import calculate_document_projection, planning_document_from_wire
from core.repository_dto import ConfirmedStudent, InventorySnapshot


def calculation_summary(document: object, state: dict[str, Any] | None) -> dict[str, Any] | None:
    if state is None:
        return None
    students = [ConfirmedStudent.from_dict(value) for value in state['students']]
    records = {student.student_id: SimpleNamespace(student_id=student.student_id, **student.values) for student in students}
    inventory = InventorySnapshot.from_dict(state['inventory'])
    projection = calculate_document_projection(records, planning_document_from_wire(document), inventory)
    resources = projection['overall']['resources']
    known_shortages = [resource for resource in resources if resource['shortage'] is not None and resource['shortage'] > 0]
    representative = max(known_shortages, key=lambda resource: (resource['shortage'], resource['display_name']), default=None)
    bottlenecks = projection['bottlenecks']
    return {
        'credits': int(projection['overall']['cost']['credits']),
        'required_resource_type_count': len(resources),
        'known_shortage_type_count': len(known_shortages),
        'inventory_complete': all(resource['owned'] is not None for resource in resources),
        'first_bottleneck_phase_number': int(bottlenecks[0]['phase_number']) if bottlenecks else None,
        'representative_shortage': None if representative is None else {
            'resource_key': representative['resource_key'], 'item_id': representative['item_id'],
            'display_name': representative['display_name'], 'category': representative['category'],
            'shortage': int(representative['shortage']),
        },
    }


def safe_calculation_summary(document: object, state: dict[str, Any]) -> dict[str, Any] | None:
    try:
        return calculation_summary(document, state)
    except Exception:
        # Derived data must not prevent retrieval of a valid persisted document.
        return None
