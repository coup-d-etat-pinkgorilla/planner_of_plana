from copy import deepcopy
import csv
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from core.repository_store import JsonRepository, RepositoryError
from core.tactical_v2 import TacticalProtocolV2, TacticalV2Store
from core.tactical_store import TacticalStore
from core.tactical_fb6_store import delete_match, put_match
from core.tactical_excel_store import preview, commit
from tests.test_tactical_excel_interpreter import FIELDS, MAPPING, OWN, values, resolution, decision


class ExcelAtomicBatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ba_fb7_synthetic_')
        self.root = Path(self.temp.name) / 'profiles'
        self.repository = JsonRepository(self.root)
        self.profile = self.repository.create_profile('Synthetic Excel', 'fb7')['profile']['profile_id']
        self.repository.update_students(self.profile, [{'version': 1, 'student_id': sid, 'values': {}} for sid in OWN], 0, 'owned')
        self.store = TacticalV2Store(self.root, self.repository)
        self.path = Path(self.temp.name) / 'synthetic.csv'
        self.write(values(opponent='Rival'))
        self.data = {'profile_id': self.profile, 'source_path': str(self.path), 'sheet_name': None,
                     'delimiter': ',', 'column_mapping': MAPPING, 'resolutions': [resolution(
                         'opponent', 'Rival', value={'identity_id': 'opponent-one', 'display_name': 'Rival'})],
                     'row_decisions': [], 'on_conflict': 'skip'}

    def tearDown(self):
        self.temp.cleanup()

    def write(self, *rows):
        with self.path.open('w', encoding='utf-8-sig', newline='') as stream:
            writer = csv.writer(stream); writer.writerow(FIELDS)
            for row in rows:
                writer.writerow([row.get(f, '') for f in FIELDS])

    def request(self, key='import', save_rules=False):
        result = preview(self.store, self.data)
        return {**deepcopy(self.data), 'save_rules': save_rules, 'expected_fingerprint': result['fingerprint'],
                'expected_interpretation_fingerprint': result['interpretation_fingerprint'],
                'expected_revision': result['current_revision'], 'idempotency_key': key}

    def code(self, expected, function, *args):
        with self.assertRaises(RepositoryError) as error:
            function(*args)
        self.assertEqual(expected, error.exception.code)

    def test_preview_does_not_create_store_identity_rules_or_change_source(self):
        before = self.path.read_bytes()
        result = preview(self.store, self.data)
        self.assertEqual((1, 0, False), (result['summary']['eligible_rows'], result['current_revision'], result['legacy_migration_required']))
        self.assertFalse(self.store._path(self.profile).exists())
        self.assertEqual([], self.store.state(self.profile)['opponents'])
        self.assertEqual(before, self.path.read_bytes())
        self.assertFalse((self.root / '.tactical.lock').exists())
        self.assertFalse((self.root / '.tactical-v2.lock').exists())

    def test_two_battles_one_write_one_revision_snapshot_lineage_and_rules(self):
        self.write(values(opponent='Rival'), values(opponent='Rival', date='2026-10-15'))
        source = self.path.read_bytes(); raw = self.request(save_rules=True)
        with patch.object(self.store, '_write', wraps=self.store._write) as write:
            result = commit(self.store, raw)
        self.assertEqual(1, write.call_count)
        self.assertEqual((1, 2, 0, 0, True), tuple(result[k] for k in ('revision', 'imported_count', 'overwritten_count', 'skipped_count', 'rules_saved')))
        value = self.store._read(self.profile)
        self.assertEqual((2, 2, 1, 1, 2), tuple(len(value[k]) for k in ('matches', 'snapshots', 'jokbo', 'opponents', 'excel_import_receipts')))
        self.assertEqual(1, value['excel_import_rules']['revision'])
        self.assertEqual(1, value['import_batches'][0]['jokbo_count'])
        self.assertTrue(all(m['source_label'] == 'csv_import' and m['observed_at'] is None for m in value['matches']))
        self.assertNotIn('excel_import_rules', self.store.state(self.profile))
        self.assertNotIn(str(self.path), str(value['excel_import_rules']))
        self.assertEqual(source, self.path.read_bytes())

    def test_late_invalid_row_rejects_entire_batch_and_rules(self):
        self.write(values(opponent='Rival'), values(opponent='Rival', date='2026-10-15', attempts=''))
        self.code('import_review_required', commit, self.store, self.request(save_rules=True))
        self.assertFalse(self.store._path(self.profile).exists())
        self.assertEqual([], self.store.state(self.profile)['matches'])

    def test_atomic_replace_failure_preserves_old_bytes_rules_and_receipts(self):
        first = self.request(); commit(self.store, first)
        path = self.store._path(self.profile); original = path.read_bytes()
        self.write(values(opponent='Rival', date='2026-10-15'), values(opponent='Rival', date='2026-10-16'))
        request = self.request('two', save_rules=True)
        def fail(stage):
            if stage == 'before_replace':
                raise OSError('synthetic interruption')
        broken = TacticalV2Store(self.root, self.repository, fault=fail)
        self.code('persistence_failed', commit, broken, request)
        self.assertEqual(original, path.read_bytes())
        self.assertEqual([], list(path.parent.glob('*.tmp')))
        self.assertEqual((2, 2), (commit(self.store, request)['revision'], len(self.store.state(self.profile)['snapshots']) - 1))

    def test_original_retry_returns_before_file_reread_and_new_revision(self):
        raw = self.request(save_rules=True); first = commit(self.store, raw)
        self.write(values(opponent='Rival', date='2026-10-15'))
        commit(self.store, self.request('later'))
        self.path.unlink()
        restarted = TacticalV2Store(self.root, JsonRepository(self.root))
        with patch('core.tactical_excel_store.read_source', side_effect=AssertionError('retry must not read source')):
            self.assertEqual(first, commit(restarted, raw))
        self.assertEqual(2, restarted.state(self.profile)['revision'])
        changed = deepcopy(raw); changed['save_rules'] = False
        self.code('idempotency_conflict', commit, restarted, changed)

    def test_source_and_choices_changed_between_preview_and_commit_never_write(self):
        raw = self.request()
        self.write(values(opponent='Rival', attempts=3))
        self.code('import_source_changed', commit, self.store, raw)
        self.assertFalse(self.store._path(self.profile).exists())
        fresh = self.request(); fresh['resolutions'].append(resolution('notes', 'keep original', value='different'))
        self.code('import_interpretation_changed', commit, self.store, fresh)
        self.assertFalse(self.store._path(self.profile).exists())

    def test_owned_catalog_context_changed_after_preview_is_detected(self):
        raw = self.request()
        self.repository.update_students(self.profile, [{'version': 1, 'student_id': 'izuna', 'values': {}}], 1, 'changed-owned')
        self.code('import_interpretation_changed', commit, self.store, raw)
        self.assertFalse(self.store._path(self.profile).exists())

    def test_explicit_skip_allows_other_rows_and_counts_actual_records(self):
        self.write(values(opponent='Rival'), values(opponent='Rival', date='', attempts=''))
        self.data['row_decisions'] = [decision(3, 'skip')]
        result = commit(self.store, self.request())
        self.assertEqual((1, 1, 1), (result['imported_count'], result['skipped_count'], len(self.store.state(self.profile)['matches'])))
        self.assertEqual(1, len(result['skipped_row_ids']))

    def test_reimport_same_file_is_row_replay_even_after_manual_delete(self):
        first = commit(self.store, self.request())
        delete_match(self.store, self.profile, first['match_ids'][0], 1, 'delete')
        result = commit(self.store, self.request('again'))
        self.assertEqual((0, 1, 2), (result['imported_count'], result['skipped_count'], result['revision']))
        self.assertEqual([], self.store.state(self.profile)['matches'])

    def test_same_date_different_deck_imports_two_and_duplicate_needs_choices(self):
        self.write(values(opponent='Rival'), values(opponent='Rival', own_striker_1='akane', own_striker_2='shiroko'))
        self.assertEqual(2, commit(self.store, self.request())['imported_count'])
        self.write(values(opponent='Rival', date='2026-10-18'), values(opponent='Rival', date='2026-10-18', attempts=3))
        self.code('import_review_required', commit, self.store, self.request('duplicate'))
        self.data['row_decisions'] = [decision(2, 'keep_separate'), decision(3, 'keep_separate')]
        self.assertEqual(2, commit(self.store, self.request('distinct'))['imported_count'])

    def test_explicit_overwrite_retains_creation_time_and_replay_receipts(self):
        original = commit(self.store, self.request()); mid = original['match_ids'][0]
        old = deepcopy(self.store.state(self.profile)['matches'][0])
        self.write(values(opponent='Rival', notes='corrected', attempts=3))
        self.data.update(on_conflict='overwrite', row_decisions=[decision(2, 'overwrite', mid)])
        result = commit(self.store, self.request('correct'))
        self.assertEqual((0, 1, 1), (result['imported_count'], result['overwritten_count'], len(self.store.state(self.profile)['matches'])))
        new = self.store.state(self.profile)['matches'][0]
        self.assertEqual((old['created_at'], 'corrected', 3), (new['created_at'], new['notes'], new['attempt_count']))
        self.assertEqual(2, len(self.store._read(self.profile)['excel_import_receipts']))

    def test_late_alias_conflict_rolls_back_an_earlier_applied_row_in_memory(self):
        self.write(values(opponent='Rival'), values(opponent='Other', date='2026-10-15'))
        self.data['resolutions'].append(resolution('opponent', 'Other', value={'identity_id': 'opponent-two', 'display_name': 'Other'}))
        raw = self.request(save_rules=True)
        self.assertEqual(2, preview(self.store, self.data)['summary']['eligible_rows'])
        from core.tactical_fb6_store import apply_match
        def late_failure(store, profile, value, item, **kwargs):
            if item['opponent_identity_id'] == 'opponent-two':
                self.assertEqual(1, len(value['matches']))
                raise RepositoryError('opponent_alias_required', 'synthetic late validation failure')
            return apply_match(store, profile, value, item, **kwargs)
        with patch('core.tactical_excel_store.apply_match', side_effect=late_failure):
            self.code('opponent_alias_required', commit, self.store, raw)
        self.assertFalse(self.store._path(self.profile).exists())

    def test_contradictory_new_identity_names_are_preview_issues(self):
        self.write(values(opponent='Rival'), values(opponent='Other', date='2026-10-15'))
        self.data['resolutions'].append(resolution('opponent', 'Other', value={'identity_id': 'opponent-one', 'display_name': 'Other'}))
        result = preview(self.store, self.data)
        self.assertEqual((1, 1), (result['summary']['eligible_rows'], result['summary']['unresolved_rows']))
        self.assertEqual('opponent_alias_required', result['rows'][1]['issues'][0]['code'])

    def test_legacy_preview_is_read_only_and_import_requires_explicit_migration(self):
        legacy = TacticalStore(self.root, self.repository)
        raw = {'version': 1, 'match_id': 'legacy', 'kind': 'attack', 'occurred_on': '2026-10-13', 'season': '',
               'opponent': 'Old', 'result': 'win', 'attack_deck': {'version': 1, 'strikers': ['shiroko', None, None, None], 'specials': ['serina', None]},
               'defense_deck': {'version': 1, 'strikers': ['akane', None, None, None], 'specials': ['hibiki', None]}, 'notes': ''}
        legacy.upsert_match(self.profile, raw, 0, 'legacy')
        before = legacy._path(self.profile).read_bytes()
        result = preview(self.store, self.data)
        self.assertTrue(result['legacy_migration_required'])
        self.code('legacy_migration_required', commit, self.store, self.request())
        self.assertFalse(self.store._path(self.profile).exists())
        self.assertEqual(before, legacy._path(self.profile).read_bytes())

    def test_two_profiles_rules_and_records_are_private(self):
        commit(self.store, self.request(save_rules=True))
        other = self.repository.create_profile('Other Excel', 'other')['profile']['profile_id']
        data = deepcopy(self.data); data['profile_id'] = other
        result = preview(self.store, data)
        self.assertEqual((0, 0), (result['current_revision'], result['rules_revision']))
        self.assertEqual([], self.store.state(other)['matches'])
        self.assertFalse(self.store._path(other).exists())

    def test_saved_rule_applies_only_to_live_explicit_identity(self):
        commit(self.store, self.request(save_rules=True))
        self.write(values(opponent='Rival', date='2026-10-15'))
        self.data['resolutions'] = []
        self.assertEqual(1, preview(self.store, self.data)['summary']['eligible_rows'])
        value = self.store._read(self.profile); value['opponents'] = []
        self.store._write(self.store._path(self.profile), value)
        result = preview(self.store, self.data)
        self.assertIn('saved_opponent_identity_missing', [i['code'] for i in result['rows'][0]['issues']])

    def test_protocol_strict_request_unknown_fields_and_new_methods(self):
        protocol = TacticalProtocolV2(self.store)
        request = {'protocol': 1, 'id': 'p1', 'type': 'request', 'method': 'tactical.v2.excel.preview', 'payload': self.data}
        result = protocol.handle(request)
        self.assertEqual(1, result['payload']['summary']['eligible_rows'])
        bad = deepcopy(request); bad['payload']['auto_approve_fuzzy'] = True
        self.assertEqual('invalid_payload', protocol.handle(bad)['payload']['error']['code'])
        request['method'] = 'tactical.v2.excel.commit'; request['payload'] = self.request()
        self.assertEqual(1, protocol.handle(request)['payload']['imported_count'])

    def legacy_profile_bytes(self):
        path = self.repository._profile_path(self.profile)
        value = json.loads(path.read_text(encoding='utf-8'))
        value.pop('plan', None); value.pop('plan_authoring', None)
        path.write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')
        return path, path.read_bytes(), self.repository.catalog_path.read_bytes()

    def test_preview_legacy_profile_never_migrates_plan_or_catalog(self):
        path, old, catalog = self.legacy_profile_bytes()
        self.assertEqual(1, preview(self.store, self.data)['summary']['eligible_rows'])
        self.assertEqual(old, path.read_bytes())
        self.assertEqual(catalog, self.repository.catalog_path.read_bytes())
        self.assertFalse(self.store._path(self.profile).exists())

    def test_invalid_commit_legacy_profile_preserves_all_planning_bytes(self):
        path, old, catalog = self.legacy_profile_bytes()
        raw = self.request(); raw['expected_fingerprint'] = 'b' * 64
        self.code('import_source_changed', commit, self.store, raw)
        self.assertEqual(old, path.read_bytes())
        self.assertEqual(catalog, self.repository.catalog_path.read_bytes())
        self.assertFalse(self.store._path(self.profile).exists())

    def test_valid_commit_and_original_retry_leave_legacy_plan_unchanged(self):
        path, old, catalog = self.legacy_profile_bytes()
        raw = self.request(save_rules=True); first = commit(self.store, raw)
        self.path.unlink()
        self.assertEqual(first, commit(self.store, raw))
        self.assertEqual(old, path.read_bytes())
        self.assertEqual(catalog, self.repository.catalog_path.read_bytes())
        self.assertEqual(1, len(json.loads(self.store._path(self.profile).read_text(encoding='utf-8'))['matches']))

    def test_merged_rule_limit_rejects_without_truncation_or_partial_batch(self):
        value = self.store._empty(self.profile)
        value['excel_import_rules'] = {'version': 1, 'revision': 1, 'column_mapping': MAPPING,
            'resolutions': [resolution('notes', 'old-'+str(i), action='ignore') for i in range(4096)]}
        path = self.store._path(self.profile); self.store._write(path, value)
        old = path.read_bytes()
        self.code('invalid_payload', commit, self.store, self.request(save_rules=True))
        self.assertEqual(old, path.read_bytes())
        self.assertEqual(4096, len(self.store._read(self.profile)['excel_import_rules']['resolutions']))

    def test_csv_delimiter_is_bound_even_before_mapping_confirmation(self):
        data = {**self.data, 'column_mapping': None, 'resolutions': []}
        comma = preview(self.store, data)
        tab = preview(self.store, {**data, 'delimiter': '\t'})
        self.assertEqual(comma['fingerprint'], tab['fingerprint'])
        self.assertNotEqual(comma['interpretation_fingerprint'], tab['interpretation_fingerprint'])

    def test_preview_binds_profile_with_identical_owned_identity_context(self):
        raw = self.request()
        other = self.repository.create_profile('Identical ownership', 'same-context')['profile']['profile_id']
        self.repository.update_students(other, [{'version': 1, 'student_id': sid, 'values': {}} for sid in OWN], 0, 'other-owned')
        second = preview(self.store, {**self.data, 'profile_id': other})
        self.assertEqual(raw['expected_fingerprint'], second['fingerprint'])
        self.assertNotEqual(raw['expected_interpretation_fingerprint'], second['interpretation_fingerprint'])
        self.code('import_interpretation_changed', commit, self.store, {**raw, 'profile_id': other})
        self.assertFalse(self.store._path(self.profile).exists())
        self.assertFalse(self.store._path(other).exists())


if __name__ == '__main__':
    unittest.main()
