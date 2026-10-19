"""Seven-path profile deletion plus a durable retry tombstone under one root guard.

Prepared records roll back, committed records roll forward. All images and paths
are validated before recovery writes. This does not certify power-loss durability.
"""
from contextlib import ExitStack, contextmanager
from copy import deepcopy
import base64
import hashlib
import json
from pathlib import Path
import re
from uuid import uuid4

from core.repository_dto import canonical_json
from core.repository_transaction import _write_bytes
from core.repository_participant_lock import MARKERS, acquire_participant, release_participant

JOURNAL = '.profile-delete.transaction.json'
TOMBSTONES = '.profile-delete.tombstones.json'


def targets(profile_id):
    if not isinstance(profile_id, str) or re.fullmatch(r'[0-9a-f]{24}', profile_id) is None:
        raise ValueError('invalid deletion profile id')
    return ['catalog.json', f'profiles/{profile_id}.json', f'tactical/{profile_id}.json',
            f'tactical/{profile_id}.v2.json', f'scenarios/{profile_id}.json',
            f'presets/{profile_id}.json', f'tactical-share/{profile_id}.v1.json']


def path_for(root, name):
    path = root / name
    if path.is_symlink() or path.resolve() != path or not path.resolve().is_relative_to(root):
        raise ValueError('deletion path is not canonical')
    return path


def image(raw):
    if raw is None:
        return None
    return {'data': base64.b64encode(raw).decode('ascii'), 'sha256': hashlib.sha256(raw).hexdigest()}


def decode(value):
    if value is None:
        return None
    if not isinstance(value, dict) or set(value) != {'data', 'sha256'}:
        raise ValueError('invalid deletion journal image')
    if not isinstance(value['data'], str) or not isinstance(value['sha256'], str):
        raise ValueError('invalid deletion image fields')
    raw = base64.b64decode(value['data'], validate=True)
    if hashlib.sha256(raw).hexdigest() != value['sha256']:
        raise ValueError('deletion image checksum mismatch')
    return raw


def validate_tombstones(value):
    if not isinstance(value, dict) or set(value) != {'version', 'profiles'} or type(value['version']) is not int or value['version'] != 1 or not isinstance(value['profiles'], dict):
        raise ValueError('invalid deletion tombstones')
    for profile_id, item in value['profiles'].items():
        targets(profile_id)
        if not isinstance(item, dict) or set(item) != {'idempotency_key', 'fingerprint', 'response'}:
            raise ValueError('invalid deletion tombstone')
        if not isinstance(item['idempotency_key'], str) or not item['idempotency_key']:
            raise ValueError('invalid tombstone idempotency key')
        if not isinstance(item['fingerprint'], str) or re.fullmatch('[0-9a-f]{64}', item['fingerprint']) is None:
            raise ValueError('invalid tombstone fingerprint')
        response = item['response']
        if not isinstance(response, dict) or set(response) != {'revision'} or type(response['revision']) is not int or response['revision'] < 1:
            raise ValueError('invalid tombstone response')
    return value


def read_tombstones(root, error_type):
    try:
        path = path_for(root.resolve(), TOMBSTONES)
        if not path.exists():
            return {'version': 1, 'profiles': {}}
        return validate_tombstones(json.loads(path.read_text(encoding='utf-8')))
    except (ValueError, TypeError, KeyError, OSError, UnicodeError) as error:
        raise error_type('corrupt_data', 'profile deletion tombstones cannot be read') from error


def _fingerprint(profile_id, revision):
    return hashlib.sha256(canonical_json({'method': 'profile.delete', 'profile_id': profile_id,
                                         'expected_revision': revision}).encode('utf-8')).hexdigest()


def _catalog_after(before, profile_id):
    result = deepcopy(before)
    result['profiles'] = [item for item in result['profiles'] if item['profile_id'] != profile_id]
    if result['selected_profile_id'] == profile_id:
        result['selected_profile_id'] = result['profiles'][0]['profile_id'] if result['profiles'] else None
    return result


def _backups(root, profile_id, tx_id):
    return [path_for(root, f'tactical/.{profile_id}{suffix}.{tx_id}.delete')
            for suffix in ('.json', '.v2.json')]


def validate(root, record):
    if not isinstance(record, dict) or set(record) != {'version', 'tx_id', 'profile_id', 'state', 'entries'}:
        raise ValueError('invalid deletion journal fields')
    if type(record['version']) is not int or record['version'] != 1 or record['state'] not in ('prepared', 'committed'):
        raise ValueError('invalid deletion journal header')
    if not isinstance(record['tx_id'], str) or re.fullmatch('[0-9a-f]{32}', record['tx_id']) is None:
        raise ValueError('invalid deletion transaction id')
    expected = targets(record['profile_id']) + [TOMBSTONES]
    if not isinstance(record['entries'], list) or len(record['entries']) != len(expected):
        raise ValueError('invalid deletion target count')
    entries = []
    for name, item in zip(expected, record['entries']):
        if not isinstance(item, dict) or set(item) != {'path', 'before', 'after'} or item['path'] != name:
            raise ValueError('unexpected or duplicate deletion path')
        before, after = decode(item['before']), decode(item['after'])
        if (name in ('catalog.json', TOMBSTONES)) != (after is not None):
            raise ValueError('invalid deletion after image')
        entries.append((path_for(root, name), before, after))
    _backups(root, record['profile_id'], record['tx_id'])
    if entries[0][1] is None or entries[1][1] is None:
        raise ValueError('deletion requires original catalog and profile')
    old_catalog, catalog = json.loads(entries[0][1]), json.loads(entries[0][2])
    profile = json.loads(entries[1][1])
    if not isinstance(profile, dict) or profile.get('profile_id') != record['profile_id'] or type(profile.get('revision')) is not int:
        raise ValueError('invalid deletion profile before image')
    if not any(item['profile_id'] == record['profile_id'] for item in old_catalog['profiles']):
        raise ValueError('deletion profile absent from before catalog')
    if catalog != _catalog_after(old_catalog, record['profile_id']):
        raise ValueError('deletion catalog transition mismatch')
    old_tombstones = {'version': 1, 'profiles': {}} if entries[-1][1] is None else validate_tombstones(json.loads(entries[-1][1]))
    tombstones = validate_tombstones(json.loads(entries[-1][2]))
    new = tombstones['profiles'].get(record['profile_id'])
    if record['profile_id'] in old_tombstones['profiles'] or new is None:
        raise ValueError('unexpected deletion tombstone transition')
    expected_tombstones = deepcopy(old_tombstones)
    expected_tombstones['profiles'][record['profile_id']] = new
    if tombstones != expected_tombstones or new['response'] != {'revision': profile['revision'] + 1} or new['fingerprint'] != _fingerprint(record['profile_id'], profile['revision']):
        raise ValueError('deletion tombstone mismatch')
    return entries


@contextmanager
def deletion_locks(root, error_type):
    with ExitStack() as stack:
        for name in MARKERS:  # root -> v1 -> v2 -> local share; reverse cleanup.
            lease = acquire_participant(root, name, error_type)
            stack.callback(release_participant, lease)
        yield


def _apply(path, raw):
    if raw is None:
        path.unlink(missing_ok=True)
    else:
        _write_bytes(path, raw)


def recover_profile_delete_locked(root, error_type, *, fault=lambda _stage: None):
    root = root.resolve()
    try:
        journal = path_for(root, JOURNAL)
        if not journal.exists():
            return
        record = json.loads(journal.read_text(encoding='utf-8'))
        entries = validate(root, record)
    except (ValueError, TypeError, KeyError, AttributeError, OSError, UnicodeError) as error:
        raise error_type('corrupt_data', 'profile deletion journal cannot be read') from error
    with deletion_locks(root, error_type):
        try:
            for number, (path, before, after) in enumerate(entries):
                _apply(path, before if record['state'] == 'prepared' else after)
                fault(f'recovered_{number}')
            for backup in _backups(root, record['profile_id'], record['tx_id']):
                backup.unlink(missing_ok=True)
            fault('before_recovery_cleanup')
            journal.unlink()
        except OSError as error:
            raise error_type('persistence_failed', 'profile deletion recovery failed', retryable=True) from error


def tactical_profile_files_delete_locked(root, profile_id, tx_id, fault):
    """Durable outer journal and deletion_locks must already own this operation."""
    paths = [path_for(root, name) for name in targets(profile_id)[2:4]]
    backups = _backups(root, profile_id, tx_id)
    moved = []
    for number, (path, backup) in enumerate(zip(paths, backups), 1):
        if path.exists():
            assert not backup.exists(), 'Deletion backup already exists'
            path.rename(backup)
            moved.append(backup)
        fault(f'delete_renamed_v{number}')
    for number, backup in enumerate(backups, 1):
        if backup in moved:
            backup.unlink()
        fault(f'delete_unlinked_v{number}')
    return [path.relative_to(root).as_posix() for path, backup in zip(paths, backups) if backup in moved]


def delete_profile_locked(repository, profile_id, expected_revision, key, error_type):
    root = repository.root.resolve()
    try:
        names = targets(profile_id)
    except ValueError as error:
        raise error_type('invalid_payload', str(error)) from error
    if type(expected_revision) is not int or expected_revision < 0 or not isinstance(key, str) or not key:
        raise error_type('invalid_payload', 'deletion requires non-negative revision and non-empty idempotency key')
    tombstones = read_tombstones(root, error_type)
    fingerprint = _fingerprint(profile_id, expected_revision)
    cached = tombstones['profiles'].get(profile_id)
    if cached:
        if cached['idempotency_key'] != key:
            raise error_type('profile_not_found', 'profile has already been deleted')
        if cached['fingerprint'] != fingerprint:
            raise error_type('idempotency_conflict', 'delete retry differs from the original operation')
        return deepcopy(cached['response'])
    catalog, profile = repository._catalog(allow_missing=False), repository._profile(profile_id)
    if profile['revision'] != expected_revision:
        raise error_type('revision_conflict', 'expected revision is stale', details={'current_revision': profile['revision']})
    if key in profile['idempotency']:
        raise error_type('idempotency_conflict', 'idempotency key was used for another mutation')
    response = {'revision': expected_revision + 1}
    after_catalog = _catalog_after(catalog, profile_id)
    tombstones['profiles'][profile_id] = {'idempotency_key': key, 'fingerprint': fingerprint, 'response': response}
    tx_id = uuid4().hex
    journal = path_for(root, JOURNAL)
    with deletion_locks(root, error_type):
        entries = []
        for name in names + [TOMBSTONES]:
            path = path_for(root, name)
            after = canonical_json(after_catalog if name == 'catalog.json' else tombstones).encode('utf-8') if name in ('catalog.json', TOMBSTONES) else None
            entries.append({'path': name, 'before': image(path.read_bytes() if path.exists() else None), 'after': image(after)})
        record = {'version': 1, 'tx_id': tx_id, 'profile_id': profile_id, 'state': 'prepared', 'entries': entries}
        validated = validate(root, record)
        try:
            repository._fault('delete_before_journal')
            _write_bytes(journal, canonical_json(record).encode('utf-8'))
            repository._fault('delete_journal_prepared')
            repository._atomic_write(root / 'catalog.json', after_catalog)
            repository._fault('delete_catalog_written')
            _apply(validated[1][0], None)
            repository._fault('delete_profile_removed')
            tactical_profile_files_delete_locked(root, profile_id, tx_id, repository._fault)
            for label, index in (('scenario', 4), ('presets', 5), ('share', 6)):
                _apply(validated[index][0], None)
                repository._fault(f'delete_{label}_removed')
            _apply(validated[-1][0], validated[-1][2])
            repository._fault('delete_tombstones_written')
            record['state'] = 'committed'
            _write_bytes(journal, canonical_json(record).encode('utf-8'))
            repository._fault('delete_journal_committed')
            journal.unlink()
            repository._fault('delete_journal_removed')
        except Exception as error:
            # The next normal root acquisition performs recovery. Perform it now
            # without recursively reacquiring the already-held participant markers.
            if journal.exists():
                current = json.loads(journal.read_text(encoding='utf-8'))
                recovery_entries = validate(root, current)
                try:
                    for path, before, after in recovery_entries:
                        _apply(path, before if current['state'] == 'prepared' else after)
                    for backup in _backups(root, profile_id, tx_id):
                        backup.unlink(missing_ok=True)
                    journal.unlink()
                except OSError as failed:
                    raise error_type('persistence_failed', 'profile deletion rollback failed', retryable=True,
                                     details={'rollback_failed': True}) from failed
            if hasattr(error, 'code'):
                raise
            raise error_type('persistence_failed', 'profile deletion failed', retryable=True) from error
    return response
