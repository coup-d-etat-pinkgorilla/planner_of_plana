"""Read-only current history queries; all sources share the persisted replay core.

Query timestamps are UTC RFC3339 (Z or +00:00, 0..6 fractional digits),
normalized to the stored six-digit Z format. Sequence always orders state.
"""
from __future__ import annotations

import base64
from copy import deepcopy
from datetime import datetime
from decimal import Decimal, localcontext
import json
import re

from core.current_history import (
    HistoryError, apply_event, integer, obj, text, unique, utc_timestamp,
    summary, _presence,
)
from core.repository_dto import canonical_json

REASONS = ('unrecorded', 'before_retention', 'legacy_time_unknown',
           'clock_rollback', 'scan_not_found', 'unknown_quantity', 'unknown_student')
# Covers canonical JSON escaping of two 256-ID filters (1024 UTF-8 bytes/ID).
MAX_CURSOR_BYTES = 8 * 1024 * 1024


def invalid(message, reason='invalid_history_query'):
    raise HistoryError(reason, message)


def query_time(value):
    if not isinstance(value, str) or not re.fullmatch(
        r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|\+00:00)', value
    ):
        invalid('Expected UTC RFC3339 timestamp')
    try:
        return utc_timestamp(datetime.fromisoformat(value.replace('Z', '+00:00')))
    except ValueError:
        invalid('Invalid UTC date/time')


def _shape(value, required, optional=()):
    if not isinstance(value, dict) or not set(required) <= set(value) <= set(required) | set(optional):
        invalid('Unexpected history query fields')
    return deepcopy(value)


def _targets(data):
    for field in ('student_ids', 'resource_keys'):
        if field in data:
            unique(data[field], lambda v: text(v, raw=True))
            if len(data[field]) > 256:
                invalid('History target filter exceeds 256 IDs')
            data[field] = sorted(data[field])


def _raw(data):
    if 'scan_kind' in data:
        text(data['scan_kind'], raw=True)
    if 'inventory_scan_profile' in data and data['inventory_scan_profile'] is not None:
        text(data['inventory_scan_profile'], raw=True)


def _profile(data):
    if not isinstance(data['profile_id'], str) or not re.fullmatch('[0-9a-f]{24}', data['profile_id']):
        invalid('Invalid profile ID')


def events_request(value):
    data = _shape(value, {'profile_id'}, {'from_at', 'to_at', 'source', 'scan_kind',
        'inventory_scan_profile', 'student_ids', 'resource_keys', 'cursor', 'limit'})
    _profile(data); _raw(data); _targets(data)
    for key in ('from_at', 'to_at'):
        if key in data:
            data[key] = query_time(data[key])
    if 'from_at' in data and 'to_at' in data and data['from_at'] > data['to_at']:
        invalid('from_at must not be after to_at')
    if 'source' in data and data['source'] not in ('scan', 'manual', 'import', 'unattributed'):
        invalid('Unknown history source')
    limit = integer(data.get('limit', 100), 1)
    if limit > 200:
        invalid('History limit must be 1..200')
    data['limit'] = limit
    if 'cursor' in data:
        if not isinstance(data['cursor'], str) or not 1 <= len(data['cursor']) <= MAX_CURSOR_BYTES:
            invalid('Invalid history cursor')
    return data


def endpoint(value):
    if isinstance(value, dict) and set(value) == {'at'}:
        return {'at': query_time(value['at'])}
    if isinstance(value, dict) and set(value) == {'sequence'}:
        integer(value['sequence'])
        return deepcopy(value)
    if isinstance(value, dict) and set(value) == {'current'} and value['current'] is True:
        return {'current': True}
    data = _shape(value, {'scan'}, {'scan_kind', 'inventory_scan_profile', 'student_id', 'resource_key'})
    if data['scan'] not in ('latest', 'previous'):
        invalid('Unknown scan selector')
    _raw(data)
    if 'student_id' in data and 'resource_key' in data:
        invalid('Scan selector may identify only one target')
    for field in ('student_id', 'resource_key'):
        if field in data:
            text(data[field], raw=True)
    return data


def diff_request(value):
    data = _shape(value, {'profile_id', 'from', 'to'}, {'student_ids', 'resource_keys'})
    _profile(data); _targets(data)
    data['from'] = endpoint(data['from']); data['to'] = endpoint(data['to'])
    for field in ('at', 'sequence'):
        if field in data['from'] and field in data['to'] and data['from'][field] > data['to'][field]:
            invalid('History endpoints are reversed')
    return data


def _scope_matches(scope, data):
    filters = [key for key in ('student_ids', 'resource_keys') if key in data]
    return not filters or any(set(scope[key]) & set(data[key]) for key in filters)


def _raw_matches(event, data):
    return all(key not in data or event[key] == data[key] for key in ('scan_kind', 'inventory_scan_profile'))


def _time_matches(event, data):
    return ('from_at' not in data or event['recorded_at'] >= data['from_at']) and ('to_at' not in data or event['recorded_at'] < data['to_at'])


def _matches(event, data):
    return ('source' not in data or data['source'] == event['source']) and _raw_matches(event, data) and _time_matches(event, data) and _scope_matches(event['applied_scope'], data)


def _sessions(events):
    """A point is the last scan application of the entire retained session.

Scope is the union of that session's approved targets. A filtered target may
have been applied earlier, but its point includes the actual state at the end.
"""
    sessions = {}
    for event in events:
        if event['source'] != 'scan':
            continue
        session = event['scan_context']['session_id']
        prior = sessions.get(session)
        scope = {key: sorted(set(event['applied_scope'][key]) | (set(prior['scope'][key]) if prior else set())) for key in ('student_ids', 'resource_keys')}
        sessions[session] = {'event': event, 'scope': scope}
    return sorted(sessions.values(), key=lambda item: item['event']['sequence'])


def _point_index(sessions):
    return [{'session_id': item['event']['scan_context']['session_id'],
             **{key: item['event'][key] for key in ('sequence', 'recorded_at', 'scan_kind', 'inventory_scan_profile')}} for item in sessions]


def _coverage(profile_id, revision, history, *, anchor=None):
    coverage = summary(profile_id, revision, history)['coverage']
    if anchor is not None and history:
        times = ([history['baseline']['recorded_at']] if history['baseline']['recorded_at'] else []) + [event['recorded_at'] for event in history['events'] if event['sequence'] <= anchor]
        coverage['first_retained_at'] = next((e['recorded_at'] for e in history['events'] if e['sequence'] <= anchor), None)
        coverage['timestamps_monotonic'] = all(a <= b for a, b in zip(times, times[1:]))
    coverage['reasons'] = []
    return coverage


def _finish_coverage(coverage, reasons):
    coverage['reasons'] = [reason for reason in REASONS if reason in reasons]
    coverage['complete'] = not coverage['reasons']
    return coverage


def _cursor_query(data):
    return {key: value for key, value in data.items() if key not in ('cursor', 'limit')}


def _encode_cursor(data):
    return base64.urlsafe_b64encode(canonical_json(data).encode()).decode().rstrip('=')


def _decode_cursor(value):
    try:
        if not re.fullmatch('[A-Za-z0-9_-]+', value):
            invalid('Malformed history cursor')
        decoded = base64.b64decode(value + '=' * (-len(value) % 4), altchars=b'-_', validate=True)
        data = json.loads(decoded)
        obj(data, {'version', 'query', 'anchor_sequence', 'baseline_sequence', 'after_sequence'})
        if type(data['version']) is not int or data['version'] != 1 or _encode_cursor(data) != value:
            invalid('Malformed history cursor')
        for field in ('anchor_sequence', 'baseline_sequence', 'after_sequence'):
            integer(data[field])
        if not data['baseline_sequence'] <= data['after_sequence'] < data['anchor_sequence']:
            invalid('Invalid cursor sequence bounds')
        return data
    except (ValueError, TypeError, KeyError, UnicodeError) as error:
        invalid(f'Invalid history cursor: {error}')


def query_events(profile_id, revision, history, value):
    data = events_request(value)
    total = history['next_sequence'] - 1 if history else 0
    floor = history['baseline']['sequence'] if history else 0
    anchor, after = total, floor
    if 'cursor' in data:
        cursor = _decode_cursor(data['cursor'])
        if cursor['query'] != _cursor_query(data):
            invalid('Cursor does not match profile/filters')
        anchor, after = cursor['anchor_sequence'], cursor['after_sequence']
        if anchor > total or cursor['baseline_sequence'] < floor:
            invalid('Required history prefix is no longer retained', 'history_cursor_expired')
        if cursor['baseline_sequence'] != floor:
            invalid('Cursor baseline does not match history')
    events = [event for event in history['events'] if event['sequence'] <= anchor] if history else []
    selected = [e for e in events if _matches(e, data)]
    page = [e for e in selected if e['sequence'] > after][:data['limit']]
    next_cursor = None
    if page and any(e['sequence'] > page[-1]['sequence'] for e in selected):
        next_cursor = _encode_cursor({'version': 1, 'query': _cursor_query(data),
            'anchor_sequence': anchor, 'baseline_sequence': floor, 'after_sequence': page[-1]['sequence']})
    coverage = _coverage(profile_id, revision, history, anchor=anchor)
    reasons = set()
    if history is None:
        reasons.add('unrecorded')
    elif history['baseline']['origin'] != 'empty':
        lower = data.get('from_at')
        if history['baseline']['origin'] == 'legacy':
            if lower is None or not events or lower < events[0]['recorded_at']:
                reasons.add('legacy_time_unknown')
        elif lower is None or lower <= history['baseline']['recorded_at']:
            reasons.add('before_retention')
    if not coverage['timestamps_monotonic']:
        reasons.add('clock_rollback')
    _finish_coverage(coverage, reasons)
    sessions = [item for item in _sessions(events) if _raw_matches(item['event'], data) and _time_matches(item['event'], data) and _scope_matches(item['scope'], data)] if data.get('source', 'scan') == 'scan' else []
    return {'profile_id': profile_id, 'revision': revision, 'history_sequence': anchor,
            'coverage': coverage, 'events': deepcopy(page), 'matching_event_count': len(selected),
            'scan_commit_count': sum(e['source'] == 'scan' for e in selected),
            'scan_session_count': len(sessions), 'scan_points': _point_index(sessions),
            'trend_eligible': coverage['complete'] and len(sessions) >= 3, 'next_cursor': next_cursor}


def _select_state(state, data):
    return {bucket: [deepcopy(item) for item in state[bucket] if filter_key not in data or item[identity] in data[filter_key]]
            for bucket, identity, filter_key in (('students', 'student_id', 'student_ids'), ('inventory', 'resource_key', 'resource_keys'))}


def quantity_delta(before, after):
    # Decimal strings may exceed Python's configurable int conversion limit.
    with localcontext() as context:
        context.prec = max(len(before), len(after)) + 1
        context.Emax = max(context.Emax, context.prec)
        return format(Decimal(after) - Decimal(before), 'f')


def _resolve(selector, history, current, sessions, monotonic):
    total = history['next_sequence'] - 1 if history else 0
    baseline = history['baseline'] if history else None
    events = history['events'] if history else []
    reason = None
    sequence = None
    if 'current' in selector:
        return {'selector': selector, 'sequence': total, 'recorded_at': events[-1]['recorded_at'] if events else baseline['recorded_at'] if baseline else None,
                'available': True, **deepcopy(current)}, None
    if not history:
        reason = 'unrecorded'
    elif 'sequence' in selector:
        sequence = selector['sequence']
        if sequence > total:
            invalid('Sequence is beyond the query anchor')
        if sequence < baseline['sequence']:
            reason = 'before_retention'
    elif 'scan' in selector:
        targets = {key + 's': [selector[key]] for key in ('student_id', 'resource_key') if key in selector}
        matching = [item for item in sessions if _raw_matches(item['event'], selector) and _scope_matches(item['scope'], targets)]
        offset = 1 if selector['scan'] == 'latest' else 2
        if len(matching) >= offset:
            sequence = matching[-offset]['event']['sequence']
        else:
            reason = 'before_retention' if baseline['origin'] == 'compacted' else 'scan_not_found'
    else:
        at = selector['at']
        if not monotonic:
            reason = 'clock_rollback'
        elif baseline['origin'] == 'compacted' and at <= baseline['recorded_at']:
            reason = 'before_retention'
        elif baseline['origin'] == 'legacy' and (not events or at <= events[0]['recorded_at']):
            reason = 'legacy_time_unknown'
        else:
            sequence = baseline['sequence']
            for event in events:
                if event['recorded_at'] >= at:
                    break
                sequence = event['sequence']
    if reason:
        return {'selector': selector, 'sequence': None, 'recorded_at': None, 'available': False, 'students': [], 'inventory': []}, reason
    state = {key: deepcopy(baseline[key]) for key in ('students', 'inventory')}
    recorded_at = baseline['recorded_at']
    for event in events:
        if event['sequence'] > sequence:
            break
        state = apply_event(state, event)
        recorded_at = event['recorded_at']
    return {'selector': selector, 'sequence': sequence, 'recorded_at': recorded_at, 'available': True, **state}, None


def query_diff(profile_id, revision, history, current, value):
    data = diff_request(value)
    coverage = _coverage(profile_id, revision, history)
    reasons = set()
    if history is None:
        reasons.add('unrecorded')
    if not coverage['timestamps_monotonic']:
        reasons.add('clock_rollback')
    sessions = _sessions(history['events']) if history else []
    a, ar = _resolve(data['from'], history, current, sessions, coverage['timestamps_monotonic'])
    b, br = _resolve(data['to'], history, current, sessions, coverage['timestamps_monotonic'])
    reasons.update(r for r in (ar, br) if r)
    if a['sequence'] is not None and b['sequence'] is not None and a['sequence'] > b['sequence']:
        invalid('History endpoints are reversed')
    temporal_complete = not reasons
    student_rows, inventory_rows = [], []
    for bucket, identity, filter_key, quantity, rows in (
        ('students', 'student_id', 'student_ids', False, student_rows),
        ('inventory', 'resource_key', 'resource_keys', True, inventory_rows)):
        before = {i[identity]: i['quantity'] if quantity else i for i in a[bucket]}
        after = {i[identity]: i['quantity'] if quantity else i for i in b[bucket]}
        identities = data[filter_key] if filter_key in data else sorted(before.keys() | after.keys())
        for key in identities:
            p, q = _presence(before, key, quantity=quantity), _presence(after, key, quantity=quantity)
            row = {identity: key, 'before': p, 'after': q}
            known = p['present'] and q['present'] and (not quantity or p['quantity'] is not None and q['quantity'] is not None)
            if not known:
                reasons.add('unknown_quantity' if quantity else 'unknown_student')
            if quantity:
                row['delta'] = quantity_delta(p['quantity'], q['quantity']) if known and temporal_complete else None
            rows.append(row)
    points = []
    raw_count = 0
    if a['sequence'] is not None and b['sequence'] is not None:
        def in_period(event):
            return a['sequence'] < event['sequence'] <= b['sequence']
        points = [item for item in sessions if in_period(item['event']) and _scope_matches(item['scope'], data)]
        raw_count = sum(e['source'] == 'scan' and in_period(e) and _scope_matches(e['applied_scope'], data) for e in history['events']) if history else 0
    for point in (a, b):
        point.update(_select_state(point, data))
    _finish_coverage(coverage, reasons)
    return {'profile_id': profile_id, 'revision': revision,
            'history_sequence': history['next_sequence'] - 1 if history else 0,
            'coverage': coverage, 'from_point': a, 'to_point': b,
            'student_changes': student_rows, 'inventory_changes': inventory_rows,
            'scan_commit_count': raw_count, 'scan_session_count': len(points),
            'scan_points': _point_index(points), 'trend_eligible': coverage['complete'] and len(points) >= 3}
