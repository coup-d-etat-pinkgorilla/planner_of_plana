from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from jsonschema import Draft202012Validator, FormatChecker
from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.tactical_v2 import TacticalV2Store
from core.tactical_store import TacticalStore
from core.tactical_fb6 import legacy_deck
from core.tactical_fb6_store import put_match, put_jokbo, delete_match, legacy_preview, legacy_commit
from tests.test_tactical_fb6_primitives import deck


def match(mid='m1'):
    return {'version': 2, 'match_id': mid, 'kind': 'attack', 'occurred_at': '2026-10-13T21:10:00+09:00', 'occurred_precision': 'instant', 'season': '34', 'opponent_identity_id': 'opponent-one', 'opponent_display_name': 'Rival', 'result': 'win', 'attack_deck': deck(), 'defense_deck': deck(), 'notes': 'original', 'attempt_count': 3}


def v1_match():
    return {'version': 1, 'match_id': 'm1', 'kind': 'attack', 'occurred_on': '2026-10-13', 'season': '34', 'opponent': 'Rival', 'result': 'win', 'attack_deck': {'version': 1, 'strikers': ['shiroko', None, None, None], 'specials': ['serina', None]}, 'defense_deck': {'version': 1, 'strikers': ['akane', None, None, None], 'specials': ['hibiki', None]}, 'notes': 'retain'}


class TacticalFB6WriteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ba_planner_fb6_')
        self.root = Path(self.temp.name)
        self.repository = JsonRepository(self.root)
        self.profile = self.repository.create_profile('Synthetic FB6', 'fb6')['profile']['profile_id']
        self.repository.update_students(self.profile, [{'version': 1, 'student_id': sid, 'values': {}} for sid in ('shiroko', 'akane', 'yuuka', 'mika', 'serina', 'hibiki')], 0, 'owned')
        self.store = TacticalV2Store(self.root, self.repository)
        self.legacy = TacticalStore(self.root, self.repository)

    def tearDown(self):
        self.temp.cleanup()

    def test_new_record_snapshot_lineage_restart_and_original_retry(self):
        payload = match()
        before = deepcopy(payload)
        first = put_match(self.store, self.profile, payload, 0, 'save')
        self.assertEqual(before, payload)
        self.assertEqual((1, 3), (first['revision'], first['match']['attempt_count']))
        self.assertEqual(1, len(first['jokbo_ids']))
        state = TacticalV2Store(self.root, JsonRepository(self.root)).state(self.profile)
        self.assertEqual((1, 1, 1, 1), tuple(len(state[k]) for k in ('matches', 'jokbo', 'opponents', 'snapshots')))
        modified = match(); modified['notes'] = 'changed'
        put_match(self.store, self.profile, modified, 1, 'edit')
        self.assertEqual(first, put_match(self.store, self.profile, payload, 0, 'save'))
        self.assertEqual('changed', self.store.state(self.profile)['matches'][0]['notes'])
        with self.assertRaises(RepositoryError) as conflict:
            put_match(self.store, self.profile, modified, 2, 'save')
        self.assertEqual('idempotency_conflict', conflict.exception.code)

    def test_partial_deck_retains_wildcard_and_never_fabricates_full_snapshot(self):
        payload = match()
        payload['defense_deck']['strikers'][3].update(student_id=None, state='unknown', wildcard=True)
        result = put_match(self.store, self.profile, payload, 0, 'partial')
        self.assertEqual(payload['defense_deck'], result['match']['defense_deck'])
        self.assertEqual([], self.store.state(self.profile)['snapshots'])
        self.assertEqual(1, len(self.store.state(self.profile)['matches']))

    def test_edited_lineage_name_survives_another_outcome_and_pair_cannot_be_redefined(self):
        first = put_match(self.store, self.profile, match(), 0, 'one')
        row = self.store.state(self.profile)['jokbo'][0]
        edit = {k: deepcopy(row[k]) for k in ('version', 'jokbo_id', 'name', 'attack_deck', 'defense_deck', 'notes')}
        edit.update(name='User name', notes='keep')
        put_jokbo(self.store, self.profile, edit, 1, 'rename')
        put_match(self.store, self.profile, match('m2'), 2, 'two')
        state = self.store.state(self.profile)
        self.assertEqual((1, 'User name', 0, 0), (len(state['jokbo']), state['jokbo'][0]['name'], state['jokbo'][0]['wins'], state['jokbo'][0]['losses']))
        edit['defense_deck']['strikers'][3].update(student_id=None, state='unknown', wildcard=True)
        with self.assertRaises(RepositoryError) as conflict:
            put_jokbo(self.store, self.profile, edit, 3, 'redefine')
        self.assertEqual('lineage_conflict', conflict.exception.code)

    def test_explicit_alias_and_profile_isolation(self):
        put_match(self.store, self.profile, match(), 0, 'one')
        altered = match('m2'); altered['opponent_display_name'] = 'Different'
        with self.assertRaises(RepositoryError) as error:
            put_match(self.store, self.profile, altered, 1, 'bad-alias')
        self.assertEqual('opponent_alias_required', error.exception.code)
        self.store.alias_opponent(self.profile, 'opponent-one', 'Different', None, 1, 'alias')
        put_match(self.store, self.profile, altered, 2, 'good-alias')
        other = self.repository.create_profile('Other', 'other')['profile']['profile_id']
        self.assertEqual([], self.store.state(other)['matches'])
        self.assertEqual(1, len(self.store.state(self.profile)['opponents']))

    def test_atomic_write_failure_keeps_previous_bytes_and_can_retry(self):
        put_match(self.store, self.profile, match(), 0, 'one')
        path = self.store._path(self.profile); before = path.read_bytes()
        def fail(stage):
            if stage == 'before_replace': raise OSError('injected')
        failing = TacticalV2Store(self.root, self.repository, fault=fail)
        with self.assertRaises(RepositoryError) as error:
            put_match(failing, self.profile, match('m2'), 1, 'two')
        self.assertEqual('persistence_failed', error.exception.code)
        self.assertEqual(before, path.read_bytes())
        self.assertEqual(2, put_match(self.store, self.profile, match('m2'), 1, 'two')['revision'])

    def test_delete_unlinks_lobby_and_snapshot_in_same_revision(self):
        put_match(self.store, self.profile, match(), 0, 'one')
        value = self.store._read(self.profile)
        value['lobby_candidates'].append({'candidate_id': 'synthetic-linked', 'match_id': 'm1', 'link_status': 'linked'})
        self.store._write(self.store._path(self.profile), value)
        result = delete_match(self.store, self.profile, 'm1', 1, 'delete')
        self.assertEqual(2, result['revision'])
        state = self.store.state(self.profile)
        self.assertEqual([], state['matches']); self.assertEqual([], state['snapshots'])
        self.assertIsNone(state['lobby_candidates'][0]['match_id'])
        self.assertEqual('unlinked', state['lobby_candidates'][0]['link_status'])

    def test_migration_preserves_v1_bytes_unknown_attempts_dates_and_stops_new_v1_writes(self):
        original = v1_match()
        old_receipt = self.legacy.upsert_match(self.profile, original, 0, 'legacy-one')
        path = self.legacy._path(self.profile); before = path.read_bytes()
        preview = legacy_preview(self.store, self.profile)
        self.assertEqual((1, []), (preview['match_count'], preview['issues']))
        result = legacy_commit(self.store, self.profile, preview['source_revision'], preview['source_fingerprint'], 0, 'migrate')
        self.assertTrue(result['v1_writes_disabled']); self.assertEqual(before, path.read_bytes())
        restored = TacticalV2Store(self.root, JsonRepository(self.root))
        row = restored.state(self.profile)['matches'][0]
        self.assertIsNone(row['attempt_count']); self.assertEqual('date', row['occurred_precision'])
        self.assertEqual('2026-10-13T00:00:00+09:00', row['occurred_at'])
        self.assertEqual((None, 'unknown', False), tuple(row['attack_deck']['strikers'][1][k] for k in ('student_id', 'state', 'wildcard')))
        self.assertEqual(old_receipt, self.legacy.upsert_match(self.profile, original, 0, 'legacy-one'))
        with self.assertRaises(RepositoryError) as blocked:
            self.legacy.delete_match(self.profile, 'm1', 1, 'new-v1')
        self.assertEqual('tactical_v1_read_only', blocked.exception.code)
        self.assertEqual(result, legacy_commit(restored, self.profile, preview['source_revision'], preview['source_fingerprint'], 0, 'migrate'))
        self.assertEqual(before, path.read_bytes())

    def test_changed_source_and_failed_migration_do_not_disable_v1(self):
        self.legacy.upsert_match(self.profile, v1_match(), 0, 'one')
        preview = legacy_preview(self.store, self.profile)
        changed = v1_match(); changed['notes'] = 'new'
        self.legacy.upsert_match(self.profile, changed, 1, 'two')
        with self.assertRaises(RepositoryError) as changed_error:
            legacy_commit(self.store, self.profile, preview['source_revision'], preview['source_fingerprint'], 0, 'stale-source')
        self.assertEqual('import_source_changed', changed_error.exception.code)
        preview = legacy_preview(self.store, self.profile)
        def fail(stage):
            if stage == 'before_replace': raise OSError('injected')
        failing = TacticalV2Store(self.root, self.repository, fault=fail)
        with self.assertRaises(RepositoryError):
            legacy_commit(failing, self.profile, preview['source_revision'], preview['source_fingerprint'], 0, 'failed')
        self.assertFalse(self.store._path(self.profile).exists())
        self.assertEqual(3, self.legacy.upsert_match(self.profile, changed, 2, 'after-failure')['revision'])

    def test_unrepresentable_legacy_identity_is_an_issue_not_silently_dropped(self):
        self.legacy.upsert_match(self.profile, v1_match(), 0, 'one')
        raw = self.legacy._read(self.profile)
        raw['matches'][0]['attack_deck']['strikers'][0] = 'historical-unknown-id'
        self.legacy._write(self.legacy._path(self.profile), raw)
        before = self.legacy._path(self.profile).read_bytes()
        preview = legacy_preview(self.store, self.profile)
        self.assertEqual(1, preview['match_count']); self.assertEqual(1, len(preview['issues']))
        with self.assertRaises(RepositoryError) as error:
            legacy_commit(self.store, self.profile, preview['source_revision'], preview['source_fingerprint'], 0, 'bad')
        self.assertEqual('import_review_required', error.exception.code)
        self.assertEqual(before, self.legacy._path(self.profile).read_bytes())
        self.assertFalse(self.store._path(self.profile).exists())

    def test_protocol_dispatch_and_schema_for_real_success_and_strict_error(self):
        app = ApplicationProtocolV1(storage_root=self.root)
        request = {'protocol': 1, 'type': 'request', 'id': 'fb6-one', 'method': 'tactical.v2.match.upsert', 'payload': {'profile_id': self.profile, 'match': match(), 'expected_revision': 0, 'idempotency_key': 'protocol-one'}}
        schema = json.loads((Path(__file__).resolve().parents[2] / 'contracts/tactical-protocol-v2.schema.json').read_text(encoding='utf-8'))
        validator = Draft202012Validator(schema, format_checker=FormatChecker())
        self.assertEqual([], list(validator.iter_errors(request)))
        response = app.handle(request)
        self.assertEqual(1, response['payload']['revision'])
        self.assertEqual([], list(validator.iter_errors(response)))
        bad = deepcopy(request); bad['payload']['unexpected'] = True
        response = app.handle(bad)
        self.assertEqual('invalid_payload', response['payload']['error']['code'])
        self.assertEqual([], list(validator.iter_errors(response)))

    def test_shared_new_method_fixture_and_migrated_public_state_match_schema(self):
        contracts = Path(__file__).resolve().parents[2] / 'contracts'
        validator = Draft202012Validator(json.loads((contracts / 'tactical-protocol-v2.schema.json').read_text(encoding='utf-8')), format_checker=FormatChecker())
        fixture = json.loads((contracts / 'fixtures/tactical_fb6_writes_v2.json').read_text(encoding='utf-8'))
        for case in fixture['cases']:
            with self.subTest(case=case['name']):
                self.assertEqual(case['valid'], not list(validator.iter_errors(case['message'])))
        self.legacy.upsert_match(self.profile, v1_match(), 0, 'one')
        preview = legacy_preview(self.store, self.profile)
        legacy_commit(self.store, self.profile, preview['source_revision'], preview['source_fingerprint'], 0, 'migration')
        app = ApplicationProtocolV1(storage_root=self.root)
        response = app.handle({'protocol': 1, 'type': 'request', 'id': 'state-after-migration', 'method': 'tactical.v2.state.get', 'payload': {'profile_id': self.profile}})
        self.assertNotIn('legacy_v1', response['payload'])
        self.assertEqual([], list(validator.iter_errors(response)))

    def test_two_write_stores_cannot_coexist_after_first_manual_v2_save(self):
        self.legacy.upsert_match(self.profile, v1_match(), 0, 'old')
        with self.assertRaises(RepositoryError) as error:
            put_match(self.store, self.profile, match(), 0, 'new-before-migration')
        self.assertEqual('legacy_migration_required', error.exception.code)
        preview = legacy_preview(self.store, self.profile)
        self.assertFalse(preview['v1_writes_disabled'])
        legacy_commit(self.store, self.profile, preview['source_revision'], preview['source_fingerprint'], 0, 'migration')
        put_match(self.store, self.profile, match(), 1, 'new-after-migration')
        self.assertEqual(2, len(self.store.state(self.profile)['matches']))
        other = self.repository.create_profile('Empty legacy', 'empty')['profile']['profile_id']
        self.repository.update_students(other, [{'version': 1, 'student_id': sid, 'values': {}} for sid in ('shiroko', 'akane', 'yuuka', 'mika', 'serina', 'hibiki')], 0, 'other-owned')
        put_match(self.store, other, match(), 0, 'first-v2')
        self.assertTrue(legacy_preview(self.store, other)['v1_writes_disabled'])
        with self.assertRaises(RepositoryError) as read_only:
            self.legacy.upsert_match(other, v1_match(), 0, 'first-v1')
        self.assertEqual('tactical_v1_read_only', read_only.exception.code)
