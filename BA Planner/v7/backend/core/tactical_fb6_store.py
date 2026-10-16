"""FB-6 mutations against the existing v2 atomic store; legacy source stays intact."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re

from core import student_meta
from core.repository_dto import canonical_json
from core.repository_store import RepositoryError
from core.repository_participant_lock import release_participant
from core.tactical_fb6 import canonical_attempt_count, canonical_deck, complete_confirmed_deck, legacy_date, legacy_deck, lineage_id
from core.tactical_store import TacticalStore
from core.tactical_v2 import _exact, _record_id, _revision, _text, _stable_id


METHODS = frozenset('tactical.v2.' + suffix for suffix in (
    'match.upsert', 'match.delete', 'jokbo.upsert', 'jokbo.delete', 'legacy.preview', 'legacy.commit',
))
MATCH_FIELDS = {'version', 'match_id', 'kind', 'occurred_at', 'occurred_precision', 'season', 'opponent_identity_id', 'opponent_display_name', 'result', 'attack_deck', 'defense_deck', 'notes', 'attempt_count'}
JOKBO_FIELDS = {'version', 'jokbo_id', 'name', 'attack_deck', 'defense_deck', 'notes'}
MARKER_FIELDS = {'version', 'source_revision', 'source_fingerprint', 'match_count', 'jokbo_count'}


def validate_marker(marker):
    if not isinstance(marker, dict) or set(marker) != MARKER_FIELDS or type(marker['version']) is not int or marker['version'] != 1:
        raise RepositoryError('corrupt_data', 'legacy migration marker is invalid')
    if any(type(marker[k]) is not int or marker[k] < 0 for k in ('source_revision', 'match_count', 'jokbo_count')) or not isinstance(marker['source_fingerprint'], str) or re.fullmatch('[0-9a-f]{64}', marker['source_fingerprint']) is None:
        raise RepositoryError('corrupt_data', 'legacy migration marker fields are invalid')


def owned_path(root, path):
    root = Path(root).resolve()
    if (root / 'tactical').is_symlink() or path.is_symlink() or not path.resolve().is_relative_to(root):
        raise RepositoryError('corrupt_data', 'tactical path must remain within owned storage')


def v1_read_only(root, profile_id):
    # Called under the v1 participant/root guard, after its original cached retry.
    path = Path(root) / 'tactical' / f'{profile_id}.v2.json'
    owned_path(root, path)
    if not path.exists():
        return False
    try:
        value = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError, UnicodeError) as error:
        raise RepositoryError('corrupt_data', 'v2 migration state cannot be read') from error
    if not isinstance(value, dict):
        raise RepositoryError('corrupt_data', 'v2 migration state is invalid')
    if 'legacy_v1' not in value:
        return False
    validate_marker(value['legacy_v1'])
    return True


def metadata(record_id, *, label='manual_record', now=None):
    stamp = now or datetime.now(timezone.utc).isoformat()
    return {'created_at': stamp, 'imported_at': stamp, 'source': 'manual', 'source_label': label,
            'import_batch_id': 'manual' if label != 'v7_v1_migration' else 'legacy-v1',
            'source_record_id': record_id, 'confidence': None, 'review_status': 'confirmed'}


def request_match(raw):
    data = _exact(raw, MATCH_FIELDS, 'match')
    if type(data['version']) is not int or data['version'] != 2 or not isinstance(data['kind'], str) or data['kind'] not in {'attack', 'defense'} or not isinstance(data['result'], str) or data['result'] not in {'win', 'loss'}:
        raise RepositoryError('invalid_payload', 'match version/kind/result is invalid')
    precision, occurred = data['occurred_precision'], data['occurred_at']
    if not isinstance(precision, str) or precision not in {'date', 'instant', 'unknown'} or (precision == 'unknown') != (occurred is None):
        raise RepositoryError('invalid_payload', 'occurred_at and precision disagree')
    if occurred is not None:
        if not isinstance(occurred, str):
            raise RepositoryError('invalid_payload', 'occurred_at must be a zoned timestamp')
        try:
            parsed = datetime.fromisoformat(occurred.replace('Z', '+00:00'))
        except ValueError as error:
            raise RepositoryError('invalid_payload', 'occurred_at must be a zoned timestamp') from error
        if parsed.tzinfo is None or (precision == 'date' and (parsed.time().isoformat() != '00:00:00' or parsed.utcoffset() != timedelta(hours=9))):
            raise RepositoryError('invalid_payload', 'date precision requires KST midnight; instant requires timezone')
        occurred = parsed.isoformat() if precision == 'date' else parsed.astimezone(timezone.utc).isoformat()
    anonymous = data['kind'] == 'defense' and data['opponent_identity_id'] is None and data['opponent_display_name'] is None
    opponent_id = None if anonymous else _record_id(data['opponent_identity_id'], 'opponent_identity_id')
    opponent_name = None if anonymous else _text(data['opponent_display_name'], 'opponent_display_name', required=True)
    return {**deepcopy(data), 'match_id': _record_id(data['match_id'], 'match_id'),
            'opponent_identity_id': opponent_id,
            'opponent_display_name': opponent_name,
            'season': _text(data['season'], 'season'), 'notes': _text(data['notes'], 'notes'),
            'occurred_at': occurred, 'attempt_count': canonical_attempt_count(data['attempt_count']),
            'attack_deck': canonical_deck(data['attack_deck']), 'defense_deck': canonical_deck(data['defense_deck'])}


def reviewed(deck):
    return all(slot['review_status'] == 'confirmed' for role in ('strikers', 'specials') for slot in deck[role])


def derived_jokbo(value, match):
    if match['kind'] != 'attack':
        return []
    identity = lineage_id(match['defense_deck'], match['attack_deck'])
    if not any(item['jokbo_id'] == identity for item in value['jokbo']):
        first = next((s['student_id'] for s in match['attack_deck']['strikers'] if s['student_id']), None)
        name = student_meta.display_name(first) if first else '미확인 편성'
        value['jokbo'].append({**metadata('derived:' + identity), 'version': 2, 'jokbo_id': identity,
                              'name': f'족보 {identity[8:14]} · {name}', 'attack_deck': deepcopy(match['attack_deck']),
                              'defense_deck': deepcopy(match['defense_deck']), 'wins': 0, 'losses': 0, 'notes': '',
                              'review_status': match['review_status']})
    return [identity]


def ensure_v2_write_mode(store, profile_id, value, *, read_only=False):
    if 'legacy_v1' in value:
        return
    state, fingerprint, converted = legacy_convert(store, profile_id, read_only=read_only)
    if state['matches'] or state['jokbo']:
        raise RepositoryError('legacy_migration_required', 'preview and migrate existing v1 records before a new v2 record write')
    # With no legacy rows, the first v2 write atomically claims the sole write
    # store. Do not leave the old UI able to create a second independent history.
    value['legacy_v1'] = {'version': 1, 'source_revision': state['revision'], 'source_fingerprint': fingerprint, 'match_count': 0, 'jokbo_count': 0}


def put_match(store, profile_id, raw, revision, key):
    owned_path(store.root, store._path(profile_id))
    item = request_match(raw)
    operation = {'method': 'match.upsert', 'match': item}

    def apply(value):
        owned_path(store.root, store._path(profile_id))
        ensure_v2_write_mode(store, profile_id, value)
        return apply_match(store, profile_id, value, item)

    return store._mutation(profile_id, revision, key, operation, apply)


def apply_match(store, profile_id, value, item, *, record_metadata=None, owned=None):
    """Apply one canonical match to caller-owned memory; never persist a row.

    The caller holds the root/v2 guard and owns the sole atomic replacement.
    Manual upsert keeps its original provenance and behavior. FB7 can supply
    explicit source-row metadata while retaining the original creation time.
    """
    if owned is None:
        owned = {s['student_id'] for s in store.repository.get_state(profile_id)['students']}
    canonical_deck(item['attack_deck'] if item['kind'] == 'attack' else item['defense_deck'], owned=owned)
    opponent = next((o for o in value['opponents'] if o['identity_id'] == item['opponent_identity_id']), None)
    if opponent is not None and item['opponent_display_name'] not in {opponent['current_display_name'], *opponent['aliases']}:
        raise RepositoryError('opponent_alias_required', 'name must match explicit identity or recorded alias')
    for linked in value['lobby_candidates']:
        if linked['match_id'] == item['match_id'] and (item['kind'] != 'attack' or linked['opponent_identity_id'] != item['opponent_identity_id'] or linked['public_signature'] != store._match_signature(item)):
            raise RepositoryError('link_conflict', 'unlink the lobby candidate before changing its match identity/signature')
    old = next((m for m in value['matches'] if m['match_id'] == item['match_id']), None)
    record = {**(metadata('manual:' + item['match_id']) if record_metadata is None else deepcopy(record_metadata)), **item, 'observed_at': None}
    if old is not None:
        for field in (('created_at', 'imported_at', 'import_batch_id', 'source_record_id') if record_metadata is None else ('created_at',)):
            record[field] = old[field]
        if record_metadata is None:
            record['source_label'] = 'manual_edit'
    record['review_status'] = 'confirmed' if reviewed(item['attack_deck']) and reviewed(item['defense_deck']) else 'review_required'
    if opponent is None and item['opponent_identity_id'] is not None:
        value['opponents'].append({'version': 2, 'identity_id': item['opponent_identity_id'], 'current_display_name': item['opponent_display_name'], 'aliases': [item['opponent_display_name']], 'first_observed_at': item['occurred_at'], 'last_observed_at': item['occurred_at'], 'review_status': 'confirmed', 'name_template_ids': []})
    value['matches'] = [m for m in value['matches'] if m['match_id'] != item['match_id']] + [record]
    value['snapshots'] = [s for s in value['snapshots'] if s.get('match_id') != item['match_id']]
    if record['kind'] == 'attack' and record['review_status'] == 'confirmed' and complete_confirmed_deck(record['defense_deck']):
        value['snapshots'].append({'version': 2, 'snapshot_id': _stable_id('snapshot', 'fb6', item['match_id']), 'opponent_identity_id': record['opponent_identity_id'], 'occurred_at': record['occurred_at'], 'observed_at': None, 'imported_at': record['imported_at'], 'source': 'manual', 'source_record_id': record['source_record_id'], 'confidence': None, 'review_status': 'confirmed', 'season': record['season'], 'deck': deepcopy(record['defense_deck']), 'match_id': record['match_id']})
    return {'match': record, 'jokbo_ids': derived_jokbo(value, record)}


def delete_match(store, profile_id, match_id, revision, key):
    owned_path(store.root, store._path(profile_id))
    match_id = _record_id(match_id, 'match_id')

    def apply(value):
        if not any(m['match_id'] == match_id for m in value['matches']):
            raise RepositoryError('record_not_found', 'match does not exist')
        value['matches'] = [m for m in value['matches'] if m['match_id'] != match_id]
        value['snapshots'] = [s for s in value['snapshots'] if s.get('match_id') != match_id]
        for candidate in value['lobby_candidates']:
            if candidate['match_id'] == match_id:
                candidate.update(match_id=None, link_status='unlinked')
        return {'match_id': match_id}

    return store._mutation(profile_id, revision, key, {'method': 'match.delete', 'match_id': match_id}, apply)


def put_jokbo(store, profile_id, raw, revision, key):
    owned_path(store.root, store._path(profile_id))
    data = _exact(raw, JOKBO_FIELDS, 'jokbo')
    if type(data['version']) is not int or data['version'] != 2:
        raise RepositoryError('invalid_payload', 'jokbo version must be 2')
    item = {**deepcopy(data), 'jokbo_id': _record_id(data['jokbo_id'], 'jokbo_id'), 'name': _text(data['name'], 'name', required=True), 'notes': _text(data['notes'], 'notes'), 'attack_deck': canonical_deck(data['attack_deck']), 'defense_deck': canonical_deck(data['defense_deck'])}

    def apply(value):
        owned = {s['student_id'] for s in store.repository.get_state(profile_id)['students']}
        ensure_v2_write_mode(store, profile_id, value)
        canonical_deck(item['attack_deck'], owned=owned)
        if not any(s['student_id'] for s in item['attack_deck']['strikers'] + item['attack_deck']['specials']):
            raise RepositoryError('invalid_payload', 'jokbo requires at least one known attack student')
        old = next((j for j in value['jokbo'] if j['jokbo_id'] == item['jokbo_id']), None)
        if item['jokbo_id'].startswith('lineage-') and lineage_id(item['defense_deck'], item['attack_deck']) != item['jokbo_id']:
            raise RepositoryError('lineage_conflict', 'copy to a new ID to change a derived lineage pair')
        record = {**(deepcopy(old) if old else metadata('manual:' + item['jokbo_id'])), 'wins': old['wins'] if old else 0, 'losses': old['losses'] if old else 0, **item}
        value['jokbo'] = [j for j in value['jokbo'] if j['jokbo_id'] != item['jokbo_id']] + [record]
        return {'jokbo': record}

    return store._mutation(profile_id, revision, key, {'method': 'jokbo.upsert', 'jokbo': item}, apply)


def delete_jokbo(store, profile_id, jokbo_id, revision, key):
    owned_path(store.root, store._path(profile_id))
    jokbo_id = _record_id(jokbo_id, 'jokbo_id')

    def apply(value):
        if not any(j['jokbo_id'] == jokbo_id for j in value['jokbo']):
            raise RepositoryError('record_not_found', 'jokbo does not exist')
        value['jokbo'] = [j for j in value['jokbo'] if j['jokbo_id'] != jokbo_id]
        return {'jokbo_id': jokbo_id}

    return store._mutation(profile_id, revision, key, {'method': 'jokbo.delete', 'jokbo_id': jokbo_id}, apply)


def legacy_convert(store, profile_id, *, read_only=False):
    legacy = TacticalStore(store.root, store.repository)
    path = legacy._path(profile_id)
    owned_path(store.root, path)
    state = legacy._read(profile_id) if not read_only else legacy._read(profile_id, migrate_profile=False)
    raw = path.read_bytes() if path.exists() else canonical_json(state).encode('utf-8')
    fingerprint = hashlib.sha256(raw).hexdigest()
    converted = {'matches': [], 'jokbo': [], 'opponents': [], 'issues': []}
    identities = {}
    stamp = datetime.now(timezone.utc).isoformat()
    for source in state['matches']:
        try:
            rid = _stable_id('legacy-match', profile_id, source['match_id'])
            oid = _stable_id('legacy-opponent', profile_id, source['opponent'])
            item = {**metadata('v7-v1:match:' + source['match_id'], label='v7_v1_migration', now=stamp), 'version': 2, 'match_id': rid, 'kind': source['kind'], **legacy_date(source['occurred_on']), 'observed_at': None, 'season': source['season'], 'opponent_identity_id': oid, 'opponent_display_name': source['opponent'], 'result': source['result'], 'attack_deck': legacy_deck(source['attack_deck']), 'defense_deck': legacy_deck(source['defense_deck']), 'notes': source['notes'], 'attempt_count': None}
            item['review_status'] = 'confirmed' if reviewed(item['attack_deck']) and reviewed(item['defense_deck']) else 'review_required'
            converted['matches'].append(item)
            identities.setdefault(oid, {'version': 2, 'identity_id': oid, 'current_display_name': source['opponent'], 'aliases': [source['opponent']], 'first_observed_at': None, 'last_observed_at': None, 'review_status': 'review_required', 'name_template_ids': []})
        except RepositoryError as error:
            converted['issues'].append({'record_kind': 'match', 'record_id': source['match_id'], 'code': error.code, 'message': str(error)})
    for source in state['jokbo']:
        try:
            rid = _stable_id('legacy-jokbo', profile_id, source['jokbo_id'])
            converted['jokbo'].append({**metadata('v7-v1:jokbo:' + source['jokbo_id'], label='v7_v1_migration', now=stamp), 'version': 2, 'jokbo_id': rid, 'name': f'족보 {rid[-6:]}', 'attack_deck': legacy_deck(source['attack_deck']), 'defense_deck': legacy_deck(source['defense_deck']), 'wins': 0, 'losses': 0, 'notes': source['notes']})
        except RepositoryError as error:
            converted['issues'].append({'record_kind': 'jokbo', 'record_id': source['jokbo_id'], 'code': error.code, 'message': str(error)})
    converted['opponents'] = list(identities.values())
    return state, fingerprint, converted


def legacy_preview(store, profile_id):
    v1 = TacticalStore(store.root, store.repository)._lock()
    try:
        v2 = store._lock()
        try:
            state, fingerprint, converted = legacy_convert(store, profile_id)
            return {'source_revision': state['revision'], 'source_fingerprint': fingerprint, 'match_count': len(state['matches']), 'jokbo_count': len(state['jokbo']), 'issues': converted['issues'], 'v1_writes_disabled': 'legacy_v1' in store._read(profile_id)}
        finally:
            release_participant(v2)
    finally:
        release_participant(v1)


def legacy_commit(store, profile_id, source_revision, fingerprint, revision, key):
    source_revision, revision = _revision(source_revision), _revision(revision)
    key = _text(key, 'idempotency_key', required=True)
    if not isinstance(fingerprint, str) or re.fullmatch('[0-9a-f]{64}', fingerprint) is None:
        raise RepositoryError('invalid_payload', 'expected_fingerprint must be SHA256')
    operation = {'method': 'legacy.commit', 'source_revision': source_revision, 'fingerprint': fingerprint}
    digest = hashlib.sha256(canonical_json(operation).encode('utf-8')).hexdigest()
    v1 = TacticalStore(store.root, store.repository)._lock()
    try:
        v2 = store._lock()
        try:
            value = store._read(profile_id)
            cached = value['idempotency'].get(key)
            if cached is not None:
                if cached['fingerprint'] != digest:
                    raise RepositoryError('idempotency_conflict', 'key belongs to another mutation')
                return deepcopy(cached['response'])
            if value['revision'] != revision:
                raise RepositoryError('revision_conflict', 'expected tactical v2 revision is stale', details={'current_revision': value['revision']})
            if 'legacy_v1' in value:
                raise RepositoryError('legacy_already_migrated', 'v1 migration already committed; use its original retry key')
            state, actual, converted = legacy_convert(store, profile_id)
            if state['revision'] != source_revision or actual != fingerprint:
                raise RepositoryError('import_source_changed', 'v1 revision or fingerprint changed after preview')
            if converted['issues']:
                raise RepositoryError('import_review_required', 'legacy conversion issues must be resolved in v1 before migration', details={'issues': converted['issues']})
            for field, idfield in (('matches', 'match_id'), ('jokbo', 'jokbo_id'), ('opponents', 'identity_id')):
                existing = {item[idfield] for item in value[field]}
                if any(item[idfield] in existing for item in converted[field]):
                    raise RepositoryError('migration_conflict', 'namespaced legacy IDs already exist')
                value[field].extend(converted[field])
            for match in converted['matches']:
                derived_jokbo(value, match)
            value['legacy_v1'] = {'version': 1, 'source_revision': source_revision, 'source_fingerprint': fingerprint, 'match_count': len(converted['matches']), 'jokbo_count': len(converted['jokbo'])}
            value['revision'] += 1
            response = {'revision': value['revision'], 'imported_matches': len(converted['matches']), 'imported_jokbo': len(converted['jokbo']), 'v1_writes_disabled': True}
            value['idempotency'][key] = {'fingerprint': digest, 'response': response}
            owned_path(store.root, store._path(profile_id))
            store._write(store._path(profile_id), value)
            return deepcopy(response)
        finally:
            release_participant(v2)
    finally:
        release_participant(v1)


def dispatch(store, method, payload):
    if method == 'tactical.v2.legacy.preview':
        data = _exact(payload, {'profile_id'}, 'payload')
        return legacy_preview(store, data['profile_id'])
    fields = {'profile_id', 'expected_revision', 'idempotency_key'}
    args = {'tactical.v2.match.upsert': ('match', put_match), 'tactical.v2.match.delete': ('match_id', delete_match), 'tactical.v2.jokbo.upsert': ('jokbo', put_jokbo), 'tactical.v2.jokbo.delete': ('jokbo_id', delete_jokbo)}
    if method in args:
        field, function = args[method]
        data = _exact(payload, fields | {field}, 'payload')
        return function(store, data['profile_id'], data[field], data['expected_revision'], data['idempotency_key'])
    data = _exact(payload, fields | {'expected_source_revision', 'expected_fingerprint'}, 'payload')
    return legacy_commit(store, data['profile_id'], data['expected_source_revision'], data['expected_fingerprint'], data['expected_revision'], data['idempotency_key'])
