"""M3 read-only field preview. A candidate association is never source evidence."""
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json

from core.client_data_store import ClientDataStore
from core.canonical_metadata import CanonicalMetadataCatalog

FIELDS = {'school': 'school', 'rarity': 'default_star_grade',
          'attack_type': 'bullet_type', 'defense_type': 'armor_type',
          'role': 'tactic_role', 'weapon_type': 'weapon_type'}


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
        separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def preview(catalog, reader: ClientDataStore, crosswalk=None):
    """No catalog writes, automatic enum inference, or provider renaming."""
    baseline = catalog.to_payload()
    proposed = deepcopy(baseline)
    table = reader.read_json_extract('jp', 'exceldb-json', 'CharacterExcel.json')
    if not isinstance(table, dict) or set(table) != {'data_list'} or not isinstance(table['data_list'], list):
        raise ValueError('CharacterExcel must contain data_list')
    rows = {}
    for row in table['data_list']:
        if not isinstance(row, dict) or type(row.get('id')) is not int or row['id'] in rows:
            raise ValueError('duplicate or invalid CharacterExcel id')
        rows[row['id']] = row
    lock_sha = digest(reader.lock)
    mapping = {}
    if crosswalk is not None:
        if (not isinstance(crosswalk, dict) or set(crosswalk) != {'version', 'lock_sha256', 'catalog_sha256', 'students'}
                or type(crosswalk['version']) is not int or crosswalk['version'] != 1
                or crosswalk['lock_sha256'] != lock_sha or crosswalk['catalog_sha256'] != digest(baseline)
                or not isinstance(crosswalk['students'], dict)):
            raise ValueError('crosswalk must bind the exact lock and frozen catalog')
        mapping = crosswalk['students']
    fields, changes = {}, []
    stamp = datetime.now(timezone.utc).isoformat()
    version = reader.lock['pins']['jp']['version_id']
    for sid, spec in mapping.items():
        if (sid not in catalog.students or not isinstance(spec, dict) or set(spec) != {'row_id', 'fields'}
                or type(spec['row_id']) is not int or spec['row_id'] not in rows
                or not isinstance(spec['fields'], dict) or not spec['fields']):
            raise ValueError('invalid explicit student crosswalk')
        row = rows[spec['row_id']]
        for field, rule in spec['fields'].items():
            if (field not in FIELDS or field not in catalog.students[sid] or not isinstance(rule, dict)
                    or set(rule) != {'source', 'values'} or rule['source'] != FIELDS[field]
                    or not isinstance(rule['values'], dict) or not rule['values']):
                raise ValueError('unsupported field or explicit enum translation missing')
            raw = row.get(rule['source'])
            key = json.dumps(raw, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)
            if raw is None or key not in rule['values']:
                raise ValueError('unmapped source enum; no fallback')
            value = rule['values'][key]
            original = catalog.students[sid][field]
            if type(value) is not type(original):
                raise ValueError('projected field type differs from canonical field')
            path = f'students.{sid}.{field}'
            proposed['students'][sid][field] = deepcopy(value)
            fields[path] = {'value': value, 'provenance': {'kind': 'exceldb-json', 'versionId': version,
                'table': 'CharacterExcel', 'rowSha': digest(row), 'tool': 'metadata-store-preview-v1', 'extractedAt': stamp}}
            if value != original:
                changes.append({'path': path, 'before': original, 'after': value})
    CanonicalMetadataCatalog.from_payload(proposed)
    old_ids = catalog.provider_student_ids.get('schaledb', {})
    candidates = [{'student_id': sid, 'row_id': row_id, 'present': row_id in rows,
                   'association': 'unverified-existing-crosswalk'} for sid, row_id in sorted(old_ids.items())]
    return {'version': 1, 'state': 'preview-only', 'lock_sha256': lock_sha,
        'catalog_sha256': digest(baseline), 'candidate_associations': candidates,
        'projected_fields': fields, 'selected_field_changes': changes,
        'selected_field_difference_count': len(changes), 'proposed_catalog': proposed,
        'removal_comparison': {'state': 'blocked', 'difference_count': None,
            'reasons': ['Gift ItemExcel/affinity-specific fields are not lock-pinned or mapped.',
                        'Provider IDs/aliases/merge paths need an approved crosswalk; equal IDs are insufficient.',
                        'Partial selected-field equality does not prove SchaleDB removal parity.']},
        'preserved_sections': ['forms', 'server_availability', 'favorite_items', 'provider_refs', 'gift_affinities'],
        'unmapped_fields': 'retained local values; no store provenance is assigned'}
