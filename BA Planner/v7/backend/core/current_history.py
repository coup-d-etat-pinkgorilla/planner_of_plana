"""Confirmed current history. No goals, catalog positions, or scanner dependencies.

Sequence orders applications; UTC timestamps retain the backend clock, including
clock rollback. Stored diffs and the baseline reconstruct current exactly.
"""
from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import re
from typing import Any

from core.inventory_catalog import canonical_resource_key
from core.repository_dto import ConfirmedStudent, InventorySnapshot, canonical_json

SOURCES = ("scan", "manual", "import", "unattributed")
MAX_EVENTS = 10_000
MAX_BYTES = 16 * 1024 * 1024
MAX_AGE_DAYS = 365


class HistoryError(ValueError):
    def __init__(self, reason: str, message: str):
        super().__init__(message)
        self.reason = reason


def fail(message: str, reason: str = "invalid_history") -> None:
    raise HistoryError(reason, message)


def obj(value: object, keys: set[str]) -> dict:
    if not isinstance(value, dict) or set(value) != keys:
        fail(f"Expected exactly {sorted(keys)}")
    return value


def integer(value: object, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        fail("Expected a non-negative integer")
    return value


def text(value: object, *, raw: bool = False) -> str:
    if not isinstance(value, str) or not value or (raw and len(value.encode('utf-8')) > 1024):
        fail("Expected non-empty text (raw identifiers: at most 1024 UTF-8 bytes)")
    return value


def timestamp(value: object, *, nullable: bool = False) -> datetime | None:
    if value is None and nullable:
        return None
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z", value):
        fail("Expected backend UTC timestamp with six fractional digits")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        fail("Invalid UTC date/time")


def utc_timestamp(now: datetime) -> str:
    if now.tzinfo is None or now.utcoffset() is None:
        fail("History clock must be timezone aware")
    return now.astimezone(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def unique(values: object, key=None) -> list:
    if not isinstance(values, list):
        fail("Expected array")
    identities = [key(item) if key else text(item) for item in values]
    if len(set(identities)) != len(identities):
        fail("Duplicate identity", "duplicate_identity")
    return values


def canonical_students(values: object) -> list[dict]:
    if not isinstance(values, list):
        fail("students must be an array")
    students = [ConfirmedStudent.from_dict(item).to_dict() for item in values]
    unique(students, lambda item: item['student_id'])
    return students


def projection(students: object, inventory: object) -> dict:
    canonical = canonical_students(students)
    snapshot = InventorySnapshot.from_dict(inventory)
    resources = [{"resource_key": canonical_resource_key(item.item_id or item.key), "quantity": item.quantity} for item in snapshot.entries]
    unique(resources, lambda item: item['resource_key'])
    return {"students": sorted(canonical, key=lambda item: item['student_id']),
            "inventory": sorted(resources, key=lambda item: item['resource_key'])}


def validate_projection(value: object) -> dict:
    data = obj(value, {'students', 'inventory'})
    students = canonical_students(data['students'])
    if any(type(raw['version']) is not int or raw != canonical for raw, canonical in zip(data['students'], students)):
        fail('History students must use canonical confirmed records')
    def resource(item):
        obj(item, {'resource_key', 'quantity'})
        text(item['resource_key'])
        quantity = item['quantity']
        if quantity is not None and (not isinstance(quantity, str) or not re.fullmatch(r'0|[1-9][0-9]*', quantity)):
            fail('Invalid quantity')
        return item['resource_key']
    unique(data['inventory'], resource)
    return data


def empty_history(students=None, inventory=None, *, legacy: bool = False) -> dict:
    state = projection(students or [], inventory or {'version': 1, 'entries': []})
    return {'version': 1, 'next_sequence': 1,
            'baseline': {'sequence': 0, 'recorded_at': None, 'origin': 'legacy' if legacy else 'empty', **state},
            'events': [], 'total_counts': {source: 0 for source in SOURCES},
            'last_applied_at': {source: None for source in SOURCES},
            'scan_session_ids': [],
            'latest_scans': {'by_kind': [], 'by_student_id': [], 'by_resource_key': []}}


@dataclass(frozen=True)
class ScanHistoryContext:
    """Server-only optional port; never accepted from a public RPC payload."""
    wire: dict[str, Any]

    @classmethod
    def from_wire(cls, value: object) -> 'ScanHistoryContext':
        data = obj(value, {'source', 'scan_kind', 'inventory_scan_profile', 'scan_context', 'applied_scope'})
        if data['source'] != 'scan':
            fail('Internal context source must be scan')
        text(data['scan_kind'], raw=True)
        if data['inventory_scan_profile'] is not None:
            text(data['inventory_scan_profile'], raw=True)
        context = obj(data['scan_context'], {'session_id', 'generation', 'candidate_id', 'candidate_revision'})
        text(context['session_id'], raw=True)
        text(context['candidate_id'], raw=True)
        integer(context['generation'], 1)
        integer(context['candidate_revision'])
        scope = obj(data['applied_scope'], {'student_ids', 'resource_keys'})
        unique(scope['student_ids'])
        unique(scope['resource_keys'])
        if not scope['student_ids'] and not scope['resource_keys']:
            fail('Scan scope must be non-empty', 'empty_scan_scope')
        return cls(deepcopy(data))

    def to_wire(self) -> dict:
        return deepcopy(self.wire)


def _presence(state: dict, identity: str, *, quantity: bool) -> dict:
    name = 'quantity' if quantity else 'value'
    return {'present': identity in state, name: state.get(identity)}


def changes(before: dict, after: dict) -> tuple[list, list]:
    results = []
    for bucket, identity, quantity in (('students', 'student_id', False), ('inventory', 'resource_key', True)):
        a = {item[identity]: item['quantity'] if quantity else item for item in before[bucket]}
        b = {item[identity]: item['quantity'] if quantity else item for item in after[bucket]}
        results.append([{identity: key, 'before': _presence(a, key, quantity=quantity), 'after': _presence(b, key, quantity=quantity)}
                        for key in sorted(a.keys() | b.keys()) if _presence(a, key, quantity=quantity) != _presence(b, key, quantity=quantity)])
    return results[0], results[1]


def apply_event(state: dict, event: dict) -> dict:
    result = {}
    for bucket, identity, change_key, name in (('students', 'student_id', 'student_changes', 'value'), ('inventory', 'resource_key', 'inventory_changes', 'quantity')):
        items = {item[identity]: item['quantity'] if name == 'quantity' else item for item in state[bucket]}
        for change in event[change_key]:
            key = change[identity]
            if change['before'] != _presence(items, key, quantity=name == 'quantity'):
                fail('History before value does not match the preceding state')
            if change['after']['present']:
                items[key] = deepcopy(change['after'][name])
            else:
                items.pop(key, None)
        result[bucket] = [({'resource_key': key, 'quantity': value} if name == 'quantity' else value) for key, value in sorted(items.items())]
    return result


def validate_event(event: object) -> dict:
    data = obj(event, {'sequence', 'recorded_at', 'source', 'revision_before', 'revision_after', 'scan_kind', 'inventory_scan_profile', 'scan_context', 'applied_scope', 'student_changes', 'inventory_changes', 'catalog_revision'})
    integer(data['sequence'], 1)
    timestamp(data['recorded_at'])
    if data['source'] not in SOURCES:
        fail('Unknown history source')
    before, after = integer(data['revision_before']), integer(data['revision_after'])
    if (data['source'] == 'import' and (before, after) != (0, 0)) or (data['source'] != 'import' and after != before + 1):
        fail('Invalid application revisions')
    scope = obj(data['applied_scope'], {'student_ids', 'resource_keys'})
    unique(scope['student_ids']); unique(scope['resource_keys'])
    if data['source'] == 'scan':
        ScanHistoryContext.from_wire({key: data[key] for key in ('source', 'scan_kind', 'inventory_scan_profile', 'scan_context', 'applied_scope')})
    elif any(data[key] is not None for key in ('scan_kind', 'inventory_scan_profile', 'scan_context')):
        fail('Non-scan event must not claim scan metadata')
    sha = data['catalog_revision']
    if sha is not None and (not isinstance(sha, str) or not re.fullmatch('[0-9a-f]{64}', sha)):
        fail('Invalid catalog revision')
    for key, identity, name, scope_key in (('student_changes', 'student_id', 'value', 'student_ids'), ('inventory_changes', 'resource_key', 'quantity', 'resource_keys')):
        def check(change):
            obj(change, {identity, 'before', 'after'})
            text(change[identity])
            for side in ('before', 'after'):
                p = obj(change[side], {'present', name})
                if type(p['present']) is not bool or (not p['present'] and p[name] is not None):
                    fail('Invalid presence representation')
                if name == 'value' and p['present']:
                    student = ConfirmedStudent.from_dict(p['value'])
                    if type(p['value']['version']) is not int or student.to_dict() != p['value'] or student.student_id != change[identity]:
                        fail('Student diff identity mismatch')
                if name == 'quantity' and p[name] is not None and (not isinstance(p[name], str) or not re.fullmatch(r'0|[1-9][0-9]*', p[name])):
                    fail('Invalid diff quantity')
            if change['before'] == change['after'] or change[identity] not in scope[scope_key]:
                fail('Diff must change a value within the application scope')
            return change[identity]
        unique(data[key], check)
    return data


def history_from_wire(value: object, *, current: dict | None = None, revision: int | None = None) -> dict:
    data = obj(value, {'version', 'next_sequence', 'baseline', 'events', 'total_counts', 'last_applied_at', 'scan_session_ids', 'latest_scans'})
    if type(data['version']) is not int or data['version'] != 1:
        fail('Unsupported current_history version', 'unsupported_version')
    total = integer(data['next_sequence'], 1) - 1
    baseline = obj(data['baseline'], {'sequence', 'recorded_at', 'origin', 'students', 'inventory'})
    floor = integer(baseline['sequence'])
    timestamp(baseline['recorded_at'], nullable=True)
    if baseline['origin'] not in ('empty', 'legacy', 'compacted') or floor > total:
        fail('Invalid history baseline')
    if (floor == 0 and (baseline['origin'] == 'compacted' or baseline['recorded_at'] is not None)) or (floor > 0 and (baseline['origin'] != 'compacted' or baseline['recorded_at'] is None)):
        fail('Baseline sequence/time/origin mismatch')
    state = validate_projection({key: baseline[key] for key in ('students', 'inventory')})
    if baseline['origin'] == 'empty' and (state['students'] or state['inventory']):
        fail('Empty baseline must be empty')
    counts = obj(data['total_counts'], set(SOURCES))
    if sum(integer(counts[source]) for source in SOURCES) != total or counts['import'] > 1:
        fail('Lifetime counts must equal applied sequences')
    last = obj(data['last_applied_at'], set(SOURCES))
    for source in SOURCES:
        timestamp(last[source], nullable=True)
        if (last[source] is None) != (counts[source] == 0):
            fail('Last application timestamp/count mismatch')
    sessions = unique(data['scan_session_ids'], lambda item: text(item, raw=True))
    if len(sessions) > counts['scan'] or (not sessions) != (counts['scan'] == 0):
        fail('Scan session/commit counts mismatch')
    if not isinstance(data['events'], list) or len(data['events']) > MAX_EVENTS or len(data['events']) != total - floor:
        fail('Invalid retained event count')
    retained_counts = {source: 0 for source in SOURCES}
    latest_retained = {}
    preceding_revision = -1
    for sequence, raw in enumerate(data['events'], floor + 1):
        event = validate_event(raw)
        if event['source'] == 'import' and sequence != 1:
            fail('Import is the single initial seed')
        if event['sequence'] != sequence or event['revision_before'] < preceding_revision or (revision is not None and event['revision_after'] > revision):
            fail('History sequence/revision is inconsistent')
        preceding_revision = event['revision_after']
        retained_counts[event['source']] += 1
        latest_retained[event['source']] = event['recorded_at']
        if event['source'] == 'scan' and event['scan_context']['session_id'] not in sessions:
            fail('Missing scan session')
        state = apply_event(state, event)
    for source in SOURCES:
        if retained_counts[source] > counts[source] or (source in latest_retained and latest_retained[source] != last[source]):
            fail('Retained application counts/time mismatch')
    index = obj(data['latest_scans'], {'by_kind', 'by_student_id', 'by_resource_key'})
    for bucket, identity in (('by_kind', None), ('by_student_id', 'student_id'), ('by_resource_key', 'resource_key')):
        def validate_index(item):
            obj(item, {'sequence', 'recorded_at', 'session_id', 'scan_kind', 'inventory_scan_profile'} | ({identity} if identity else set()))
            if not 1 <= integer(item['sequence'], 1) <= total or not counts['scan']:
                fail('Invalid latest scan sequence')
            timestamp(item['recorded_at']); text(item['scan_kind'], raw=True)
            if item['inventory_scan_profile'] is not None:
                text(item['inventory_scan_profile'], raw=True)
            if text(item['session_id'], raw=True) not in sessions:
                fail('Latest scan references an unknown session')
            return text(item[identity]) if identity else (item['scan_kind'], item['inventory_scan_profile'])
        unique(index[bucket], validate_index)
    if bool(index['by_kind']) != bool(counts['scan']):
        fail('Missing latest scan index')
    # Entries older than the baseline remain valid. Retained scans must agree
    # with the persisted latest index, including no-change applications.
    retained_index = {'by_kind': {}, 'by_student_id': {}, 'by_resource_key': {}}
    for event in data['events']:
        if event['source'] != 'scan':
            continue
        entry = {key: event[key] for key in ('sequence', 'recorded_at', 'scan_kind', 'inventory_scan_profile')}
        entry['session_id'] = event['scan_context']['session_id']
        retained_index['by_kind'][(entry['scan_kind'], entry['inventory_scan_profile'])] = entry
        for bucket, identity, scope in (('by_student_id', 'student_id', 'student_ids'), ('by_resource_key', 'resource_key', 'resource_keys')):
            for key in event['applied_scope'][scope]:
                retained_index[bucket][key] = {identity: key, **entry}
    for bucket, identity in (('by_kind', None), ('by_student_id', 'student_id'), ('by_resource_key', 'resource_key')):
        persisted = {(item[identity] if identity else (item['scan_kind'], item['inventory_scan_profile'])): item for item in index[bucket]}
        if any(persisted.get(key) != entry for key, entry in retained_index[bucket].items()):
            fail('Latest scan index does not match retained applications')
    if len(canonical_json(data).encode('utf-8')) > MAX_BYTES:
        fail('Stored history exceeds capacity')
    if current is not None and canonical_json(state) != canonical_json(current):
        fail('History does not reconstruct confirmed current')
    return deepcopy(data)


@dataclass(frozen=True)
class CurrentHistory:
    wire: dict

    @classmethod
    def from_wire(cls, value: object) -> 'CurrentHistory':
        return cls(history_from_wire(value))

    def to_wire(self) -> dict:
        return deepcopy(self.wire)


def append_history(history: dict, before: dict, after: dict, *, source: str, recorded_at: str, revision_before: int, revision_after: int, catalog_revision: str | None, context: ScanHistoryContext | None = None, applied_scope: dict | None = None, max_events: int = MAX_EVENTS, max_bytes: int = MAX_BYTES, max_age_days: int = MAX_AGE_DAYS) -> dict:
    result = deepcopy(history)
    student_changes, inventory_changes = changes(before, after)
    scope = {'student_ids': sorted({item['student_id'] for item in before['students'] + after['students']}),
             'resource_keys': sorted({item['resource_key'] for item in before['inventory'] + after['inventory']})}
    if applied_scope is not None:
        scope = applied_scope
    metadata = {'source': source, 'scan_kind': None, 'inventory_scan_profile': None, 'scan_context': None, 'applied_scope': scope}
    if context is not None:
        metadata = context.to_wire()
    event = {'sequence': result['next_sequence'], 'recorded_at': recorded_at, 'revision_before': revision_before, 'revision_after': revision_after,
             **metadata, 'student_changes': student_changes, 'inventory_changes': inventory_changes, 'catalog_revision': catalog_revision}
    validate_event(event)
    result['events'].append(event)
    result['next_sequence'] += 1
    result['total_counts'][source] += 1
    result['last_applied_at'][source] = recorded_at
    if source == 'scan':
        session = event['scan_context']['session_id']
        if session not in result['scan_session_ids']:
            result['scan_session_ids'].append(session)
        entry = {key: event[key] for key in ('sequence', 'recorded_at', 'scan_kind', 'inventory_scan_profile')}
        entry['session_id'] = session
        index = result['latest_scans']
        key = (event['scan_kind'], event['inventory_scan_profile'])
        index['by_kind'] = [item for item in index['by_kind'] if (item['scan_kind'], item['inventory_scan_profile']) != key] + [entry]
        for bucket, identity, scope_key in (('by_student_id', 'student_id', 'student_ids'), ('by_resource_key', 'resource_key', 'resource_keys')):
            mapping = {item[identity]: item for item in index[bucket]}
            mapping.update({key: {identity: key, **entry} for key in event['applied_scope'][scope_key]})
            index[bucket] = [item for _, item in sorted(mapping.items())]
    cutoff = timestamp(recorded_at) - timedelta(days=max_age_days)
    def fold():
        removed = result['events'].pop(0)
        baseline = result['baseline']
        state = apply_event({key: baseline[key] for key in ('students', 'inventory')}, removed)
        result['baseline'] = {'sequence': removed['sequence'], 'recorded_at': removed['recorded_at'], 'origin': 'compacted', **state}
    while len(result['events']) > 1 and (len(result['events']) > max_events or timestamp(result['events'][0]['recorded_at']) < cutoff):
        fold()
    while len(canonical_json(result).encode('utf-8')) > max_bytes:
        if len(result['events']) <= 1:
            fail('Baseline/index and the newest application cannot fit within history capacity', 'history_capacity_exceeded')
        fold()
    return result


def summary(profile_id: str, revision: int, history: dict | None) -> dict:
    counts = history['total_counts'] if history else {source: 0 for source in SOURCES}
    events = history['events'] if history else []
    retained = {source: sum(event['source'] == source for event in events) for source in SOURCES}
    baseline = history['baseline'] if history else None
    times = ([baseline['recorded_at']] if baseline and baseline['recorded_at'] else []) + [event['recorded_at'] for event in events]
    return {'profile_id': profile_id, 'revision': revision,
            'history_sequence': history['next_sequence'] - 1 if history else 0,
            'last_manual_at': history['last_applied_at']['manual'] if history else None,
            'last_import_at': history['last_applied_at']['import'] if history else None,
            'total_event_count': sum(counts.values()), 'retained_event_count': len(events),
            'total_counts': deepcopy(counts), 'retained_counts': retained,
            'total_scan_session_count': len(history['scan_session_ids']) if history else 0,
            'retained_scan_session_count': len({event['scan_context']['session_id'] for event in events if event['source'] == 'scan'}),
            'coverage': {'origin': baseline['origin'] if baseline else 'unrecorded',
                         'baseline_sequence': baseline['sequence'] if baseline else 0,
                         'baseline_at': baseline['recorded_at'] if baseline else None,
                         'first_retained_at': events[0]['recorded_at'] if events else None,
                         'complete': baseline is not None and baseline['origin'] == 'empty',
                         'timestamps_monotonic': all(a <= b for a, b in zip(times, times[1:]))}}
