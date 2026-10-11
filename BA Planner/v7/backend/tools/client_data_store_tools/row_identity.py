"""Reviewed, opt-in flat ID comparison; unreviewed tables retain row-set hashes."""
from __future__ import annotations

import json
import re
from pathlib import Path

try:
    from ._common import canonical_json, read_json, sha256_bytes
    from ._validation import component
except ImportError:
    from _common import canonical_json, read_json, sha256_bytes
    from _validation import component


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON object key')
        result[key] = value
    return result


def load_reviewed_keys(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    obj = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=_unique_object)
    if not isinstance(obj, dict) or set(obj) != {'schema', 'tables'} or obj['schema'] != 'ba-client-data.reviewed-row-keys.v1' or not isinstance(obj['tables'], dict):
        raise ValueError('invalid reviewed row-key policy')
    result = {}
    for table, review in obj['tables'].items():
        component(table, 'table filename')
        if not table.endswith('.json') or table in ('SOURCE.json', 'provenance.json'):
            raise ValueError('invalid reviewed table filename')
        if not isinstance(review, dict) or set(review) != {'id_key', 'evidence'}:
            raise ValueError('each reviewed key needs id_key and evidence')
        if not isinstance(review['id_key'], str) or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', review['id_key']):
            raise ValueError('only a reviewed flat field name is supported')
        if not isinstance(review['evidence'], str) or not review['evidence'].strip():
            raise ValueError('review evidence is required')
        result[table] = review['id_key']
    return result


def table_rows(path: Path) -> list:
    obj = read_json(path)
    if isinstance(obj, list):
        rows = obj
    elif isinstance(obj, dict):
        rows = obj.get('data_list', obj.get('rows', []))
    else:
        raise ValueError('table must be an object or array')
    if not isinstance(rows, list):
        raise ValueError('table rows must be an array')
    return rows


def compare_rows(a: list, b: list, id_key: str | None = None) -> dict:
    base = {'rows_a': len(a), 'rows_b': len(b)}
    if id_key is None:
        ha = {sha256_bytes(canonical_json(row)) for row in a}
        hb = {sha256_bytes(canonical_json(row)) for row in b}
        return {**base, 'status': 'same' if ha == hb else 'changed',
                'comparison_mode': 'row_set_hash', 'id_key': None,
                'rows_added': len(hb - ha), 'rows_removed': len(ha - hb), 'rows_changed': None,
                'duplicate_rows_a': len(a) - len(ha), 'duplicate_rows_b': len(b) - len(hb),
                'limitation': 'No reviewed ID: order and duplicate multiplicity are ignored; changed rows are NOT_COMPUTED.'}
    indexes, errors = [], []
    for side, rows in (('a', a), ('b', b)):
        index = {}
        for position, row in enumerate(rows):
            if not isinstance(row, dict) or id_key not in row:
                errors.append({'side': side, 'row': position, 'reason': 'missing_id'})
                continue
            identity = row[id_key]
            if type(identity) not in (int, str) or (isinstance(identity, str) and not identity):
                errors.append({'side': side, 'row': position, 'reason': 'invalid_id_type_or_empty'})
                continue
            token = canonical_json(identity)
            if token in index:
                errors.append({'side': side, 'row': position, 'reason': 'duplicate_id'})
                continue
            index[token] = canonical_json(row)
        indexes.append(index)
    identity_base = {**base, 'comparison_mode': 'stable_id', 'id_key': id_key}
    if errors:
        return {**identity_base, 'status': 'invalid_identity', 'rows_added': None,
                'rows_removed': None, 'rows_changed': None, 'identity_errors': errors,
                'limitation': 'Identity validation failed; no identity counts or row-hash fallback were computed.'}
    ia, ib = indexes
    added, removed = len(ib.keys() - ia.keys()), len(ia.keys() - ib.keys())
    changed = sum(ia[key] != ib[key] for key in ia.keys() & ib.keys())
    return {**identity_base, 'status': 'same' if not (added or removed or changed) else 'changed',
            'rows_added': added, 'rows_removed': removed, 'rows_changed': changed}
