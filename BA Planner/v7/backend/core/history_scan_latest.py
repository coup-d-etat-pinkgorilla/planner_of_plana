"""Read-only confirmed scan metadata from persisted latest indices.

No reconstruction from retained events, clock, repository, migration, or cache.
Validation here is confined to the new query/response boundary.
"""
from __future__ import annotations

from copy import deepcopy
import re

from core.current_history import HistoryError, timestamp
from core.inventory_catalog import canonical_resource_key

_ENTRY = {'sequence', 'recorded_at', 'session_id', 'scan_kind', 'inventory_scan_profile'}
_CONTROLS = {'by_kind_limit', 'by_kind_after_sequence', 'anchor_history_sequence'}
_OPTIONAL = {'student_ids', 'resource_keys', 'include_by_kind'} | _CONTROLS


def _fail(message: str, reason: str = 'invalid_history_query') -> None:
    raise HistoryError(reason, message)


def _text(value: object, *, reason: str = 'invalid_history_query') -> str:
    if not isinstance(value, str) or not value:
        _fail('Expected non-empty UTF-8 text', reason)
    if any(0xD800 <= ord(char) <= 0xDFFF for char in value):
        _fail('Invalid Unicode scalar text', reason)
    size = len(value.encode('utf-8'))
    if size > 1024:
        _fail('Text exceeds 1024 UTF-8 bytes', reason)
    return value


def _integer(value: object, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        _fail('Expected a non-negative exact integer')
    return value


def _targets(value: object, *, resources: bool = False) -> list[str]:
    if not isinstance(value, list) or len(value) > 256:
        _fail('Expected at most 256 target IDs')
    result = []
    for raw in value:
        key = _text(raw)
        result.append(_text(canonical_resource_key(key)) if resources else key)
    if len(set(result)) != len(result):
        _fail('Duplicate identity after canonicalization', 'duplicate_identity')
    return sorted(result)


def scan_latest_request(payload: object) -> dict:
    if not isinstance(payload, dict) or not {'profile_id'} <= set(payload) <= {'profile_id'} | _OPTIONAL:
        _fail('Invalid scan_latest request shape')
    pid = payload['profile_id']
    if not isinstance(pid, str) or not re.fullmatch('[0-9a-f]{24}', pid):
        _fail('Invalid profile_id')
    include = payload.get('include_by_kind', False)
    if type(include) is not bool:
        _fail('include_by_kind must be boolean')
    if not include and _CONTROLS & set(payload):
        _fail('Kind paging controls require include_by_kind=true')
    limit = _integer(payload.get('by_kind_limit', 100), 1)
    if limit > 200:
        _fail('by_kind_limit must be at most 200')
    after = _integer(payload.get('by_kind_after_sequence', 0))
    anchor = payload.get('anchor_history_sequence')
    if 'anchor_history_sequence' in payload:
        anchor = _integer(anchor)
    if after > 0 and anchor is None:
        _fail('Positive after_sequence requires a history anchor')
    if anchor is not None and after > anchor:
        _fail('after_sequence exceeds the anchor')
    return {'profile_id': pid,
            'student_ids': _targets(payload.get('student_ids', [])),
            'resource_keys': _targets(payload.get('resource_keys', []), resources=True),
            'include_by_kind': include, 'by_kind_limit': limit,
            'by_kind_after_sequence': after, 'anchor_history_sequence': anchor}


def _scan(item: dict, history_sequence: int, identity: str | None = None) -> dict:
    expected = _ENTRY | ({identity} if identity else set())
    if not isinstance(item, dict) or set(item) != expected:
        _fail('Invalid stored latest scan entry shape', 'corrupt_data')
    sequence = item['sequence']
    if type(sequence) is not int or not 1 <= sequence <= history_sequence:
        _fail('Invalid stored latest scan sequence', 'corrupt_data')
    try:
        timestamp(item['recorded_at'])
    except HistoryError as error:
        _fail(str(error), 'corrupt_data')
    for key in ('session_id', 'scan_kind'):
        _text(item[key], reason='corrupt_data')
    if item['inventory_scan_profile'] is not None:
        _text(item['inventory_scan_profile'], reason='corrupt_data')
    return deepcopy({key: item[key] for key in _ENTRY})


def query_scan_latest(profile_id: str, revision: int, history: dict | None, payload: object) -> dict:
    data = scan_latest_request(payload)
    if data['profile_id'] != profile_id:
        _fail('Query profile identity mismatch')
    hseq = history['next_sequence'] - 1 if history is not None else 0
    anchor = data['anchor_history_sequence']
    if anchor is not None and anchor != hseq:
        _fail('History changed; restart scan_latest from the first page', 'stale_scan_latest')
    last_scan = history['last_applied_at']['scan'] if history is not None else None
    result = {'profile_id': profile_id, 'revision': revision, 'history_sequence': hseq,
              'last_scan_at': last_scan, 'by_kind': [], 'by_student_id': [],
              'by_resource_key': [], 'by_kind_next_after_sequence': None}
    # Null profile scan time means no scan metadata, while requested rows stay.
    index = history['latest_scans'] if history is not None and last_scan is not None else None
    if index is not None:
        kinds = [_scan(item, hseq) for item in index['by_kind']]
        sequences = [item['sequence'] for item in kinds]
        tuples = [(item['scan_kind'], item['inventory_scan_profile']) for item in kinds]
        if len(set(sequences)) != len(sequences) or len(set(tuples)) != len(tuples):
            _fail('Impossible duplicate latest kind sequence or identity', 'corrupt_data')
        if data['include_by_kind']:
            page = sorted((item for item in kinds if item['sequence'] > data['by_kind_after_sequence']),
                          key=lambda item: item['sequence'])
            result['by_kind'] = page[:data['by_kind_limit']]
            if len(page) > data['by_kind_limit']:
                result['by_kind_next_after_sequence'] = result['by_kind'][-1]['sequence']
    reason = 'unrecorded' if history is None else 'scan_not_found'
    for bucket, identity, targets in (('by_student_id', 'student_id', data['student_ids']),
                                      ('by_resource_key', 'resource_key', data['resource_keys'])):
        mapping = {item[identity]: item for item in index[bucket]} if index is not None else {}
        for key in targets:
            entry = _scan(mapping[key], hseq, identity) if key in mapping else None
            result[bucket].append({identity: key, 'latest_scan': entry,
                                   'reason': None if entry is not None else reason})
    return result
