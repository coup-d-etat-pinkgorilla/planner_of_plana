"""FB7 preview and one atomic batch; source workbooks remain read-only."""
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
import re

from core.repository_store import RepositoryError
from core.repository_participant_lock import release_participant
from core.tactical_store import TacticalStore
from core.tactical_fb6_store import apply_match, ensure_v2_write_mode, legacy_convert, metadata, owned_path
from core.tactical_v2 import _exact, _revision, _text
from core.tactical_excel_reader import read_source, SourceReadError
from core.tactical_excel_interpreter import (
    catalog_context, digest, interpret, validate_mapping, validate_resolutions, validate_rules,
)


METHODS = frozenset(('tactical.v2.excel.preview', 'tactical.v2.excel.commit'))
CHOICES = {'profile_id', 'source_path', 'sheet_name', 'delimiter', 'column_mapping',
           'resolutions', 'row_decisions', 'on_conflict'}


def choices(raw):
    data = _exact(raw, CHOICES, 'Excel import choices')
    source = _text(data['source_path'], 'source_path', required=True)
    if data['sheet_name'] is not None and (not isinstance(data['sheet_name'], str) or not data['sheet_name']):
        raise RepositoryError('invalid_payload', 'sheet_name must be null or a nonempty exact name')
    if data['delimiter'] not in (',', '\t'):
        raise RepositoryError('invalid_payload', 'CSV delimiter must be comma or tab')
    if data['column_mapping'] is not None:
        validate_mapping(data['column_mapping'])
    validate_resolutions(data['resolutions'])
    return {**deepcopy(data), 'source_path': str(Path(source).expanduser().resolve())}


def _preview_locked(store, data, value):
    owned_path(store.root, store._path(data['profile_id']))
    try:
        document = read_source(data['source_path'], sheet_name=data['sheet_name'], delimiter=data['delimiter'])
    except SourceReadError as error:
        raise RepositoryError('import_source_unreadable', 'Excel source cannot be read', details={'reason': error.reason}) from error
    owned = {s['student_id'] for s in store.repository._profile(data['profile_id'])['students']}
    context = catalog_context(owned, value['opponents'], value['matches'])
    context['profile_id'] = data['profile_id']
    context['reader_options'] = {'format': document.format, 'delimiter': data['delimiter']}
    context['source_rows'] = deepcopy(value.get('excel_import_receipts', {}))
    result = interpret(document, context, column_mapping=data['column_mapping'], resolutions=data['resolutions'],
                       row_decisions=data['row_decisions'], rules=value.get('excel_import_rules'),
                       on_conflict=data['on_conflict'])
    result['current_revision'] = value['revision']
    result['rules_revision'] = value.get('excel_import_rules', {}).get('revision', 0)
    legacy, fp, converted = legacy_convert(store, data['profile_id'], read_only=True)
    result['legacy_migration_required'] = 'legacy_v1' not in value and bool(legacy['matches'] or legacy['jokbo'])
    if result['legacy_migration_required']:
        result['issues'].append({'code': 'legacy_migration_required', 'source_revision': legacy['revision'],
                                 'source_fingerprint': fp})
    return result


def preview(store, raw):
    data = choices(raw)
    owned_path(store.root, store._path(data['profile_id']))
    # Same fixed participant order as profile deletion/migration: root -> v1 -> v2.
    v1 = TacticalStore(store.root, store.repository)._lock()
    try:
        v2 = store._lock()
        try:
            return _preview_locked(store, data, store._read(data['profile_id'], migrate_profile=False))
        finally:
            release_participant(v2)
    finally:
        release_participant(v1)


def _saved_rules(value, data):
    previous = validate_rules(value.get('excel_import_rules'))
    merged = {(r['field'], r['raw']): r for r in previous['resolutions']}
    for item in data['resolutions']:
        if 'row' not in item and item['action'] != 'skip':
            merged[(item['field'], item['raw'])] = deepcopy(item)
    rules = {'version': 1, 'revision': previous['revision'], 'column_mapping': deepcopy(data['column_mapping']),
             'resolutions': [merged[k] for k in sorted(merged)]}
    changed = rules != previous
    if changed:
        rules['revision'] += 1
    validate_rules(rules)
    return rules, changed


def commit(store, raw):
    extra = {'save_rules', 'expected_fingerprint', 'expected_interpretation_fingerprint', 'expected_revision', 'idempotency_key'}
    raw = _exact(raw, CHOICES | extra, 'Excel commit')
    data = choices({k: raw[k] for k in CHOICES})
    if type(raw['save_rules']) is not bool:
        raise RepositoryError('invalid_payload', 'save_rules must be boolean')
    for field in ('expected_fingerprint', 'expected_interpretation_fingerprint'):
        if not isinstance(raw[field], str) or re.fullmatch('[0-9a-f]{64}', raw[field]) is None:
            raise RepositoryError('invalid_payload', field + ' must be SHA256')
    revision = _revision(raw['expected_revision'])
    key = _text(raw['idempotency_key'], 'idempotency_key', required=True)
    operation = {'method': 'excel.commit', **data, 'save_rules': raw['save_rules'],
                 'expected_fingerprint': raw['expected_fingerprint'],
                 'expected_interpretation_fingerprint': raw['expected_interpretation_fingerprint']}
    owned_path(store.root, store._path(data['profile_id']))

    def apply(value):
        owned_path(store.root, store._path(data['profile_id']))
        # _mutation checks exact cached retries and revision before this first read.
        result = _preview_locked(store, data, value)
        if result['fingerprint'] != raw['expected_fingerprint']:
            raise RepositoryError('import_source_changed', 'source bytes changed after preview')
        if result['interpretation_fingerprint'] != raw['expected_interpretation_fingerprint']:
            raise RepositoryError('import_interpretation_changed', 'mapping, resolutions, rules or catalog context changed after preview')
        if result['legacy_migration_required']:
            raise RepositoryError('legacy_migration_required', 'explicitly migrate v1 records before Excel import')
        unresolved = [r['row_id'] for r in result['rows'] if r['status'] in {'unresolved', 'conflict'}]
        if unresolved or result['issues']:
            raise RepositoryError('import_review_required', 'resolve or explicitly skip every unresolved row', details={'row_ids': unresolved})
        planned = [r for r in result['rows'] if r['status'] in {'eligible', 'overwrite'}]
        rules, rules_changed = _saved_rules(value, data) if raw['save_rules'] else (None, False)
        if planned or rules_changed:
            ensure_v2_write_mode(store, data['profile_id'], value, read_only=True)
        owned = {s['student_id'] for s in store.repository._profile(data['profile_id'])['students']}
        stamp = datetime.now(timezone.utc).isoformat()
        batch_id = 'excel-batch-' + digest([result['fingerprint'], result['interpretation_fingerprint']])[:32]
        jokbo_before = len(value['jokbo'])
        imported, overwritten = [], []
        for row in planned:
            item = deepcopy(row['match'])
            if row['status'] == 'overwrite':
                item['match_id'] = row['target_match_id']
                overwritten.append(item['match_id'])
            else:
                imported.append(item['match_id'])
            info = {**metadata(row['row_id'], label=result['format'] + '_import', now=stamp),
                    'import_batch_id': batch_id}
            apply_match(store, data['profile_id'], value, item, record_metadata=info, owned=owned)
            value.setdefault('excel_import_receipts', {})[row['row_id']] = item['match_id']
        if planned:
            value['import_batches'].append({'version': 2, 'import_batch_id': batch_id,
                'source_fingerprint': result['fingerprint'], 'imported_at': stamp,
                'match_count': len(planned), 'jokbo_count': len(value['jokbo']) - jokbo_before,
                'skipped_issue_count': sum(r['status'] == 'skipped' for r in result['rows'])})
        if rules_changed:
            value['excel_import_rules'] = rules
        skipped = [r['row_id'] for r in result['rows'] if r['status'] in {'skipped', 'replay', 'conflict_skipped'}]
        return {'imported_count': len(imported), 'overwritten_count': len(overwritten),
                'skipped_count': len(skipped), 'skipped_row_ids': skipped, 'rules_saved': rules_changed,
                'match_ids': imported + overwritten, '_no_change': not planned and not rules_changed}

    v1 = TacticalStore(store.root, store.repository)._lock()
    try:
        return store._mutation(data['profile_id'], revision, key, operation, apply, migrate_profile=False)
    finally:
        release_participant(v1)


def dispatch(store, method, payload):
    if method == 'tactical.v2.excel.preview':
        return preview(store, payload)
    if method == 'tactical.v2.excel.commit':
        return commit(store, payload)
    raise RepositoryError('unknown_method', 'unknown Excel method')
