from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from core.application_protocol_v1 import ApplicationProtocolV1
from core.planning_document import TARGET_MAXIMUMS
from core.preset_store import LIMITS, PresetStore, preset_bundle_from_wire
from core.repository_store import JsonRepository, RepositoryError
from core.v6_migration import V6Account

CONTRACTS = Path(__file__).parents[2] / 'contracts'


class RepositoryPresetsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((CONTRACTS / 'fixtures/repository_presets_v1.json').read_text(encoding='utf-8'))
        schemas = [json.loads(path.read_text(encoding='utf-8')) for path in CONTRACTS.glob('*.schema.json')]
        registry = Registry().with_resources((value['$id'], Resource.from_contents(value)) for value in schemas)
        schema = next(value for value in schemas if value['$id'].endswith('/repository-protocol-v1.schema.json'))
        cls.validator = Draft202012Validator(schema, registry=registry)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = JsonRepository(self.root)
        self.pid = self.repo.create_profile('Presets', 'fb14-profile')['profile']['profile_id']
        self.store = PresetStore(self.repo)
        self.path = self.root / 'presets' / f'{self.pid}.json'
        self.bundle = copy.deepcopy(self.fixture['cases'][0]['message']['payload'])
        self.bundle = {key: self.bundle[key] for key in ('stage_presets', 'student_groups')}

    def save(self, revision=0, key='first', bundle=None):
        return self.store.save(self.pid, revision, key, **(bundle or self.bundle))

    def profile_bytes(self):
        return self.repo._profile_path(self.pid).read_bytes(), self.repo.catalog_path.read_bytes()

    def assert_error(self, code, call):
        with self.assertRaises(RepositoryError) as raised:
            call()
        self.assertEqual(raised.exception.code, code)
        return raised.exception

    def test_fixture_schema_and_runtime(self):
        self.assertEqual(self.fixture['limits'], LIMITS)
        app = ApplicationProtocolV1(storage_root=self.root)
        for case in self.fixture['cases']:
            with self.subTest(case=case['id']):
                message = copy.deepcopy(case['message'])
                self.assertEqual(self.validator.is_valid(message), case['schema_valid'])
                if message['type'] != 'request':
                    continue
                if message['payload'].get('profile_id') == 'a' * 24:
                    message['payload']['profile_id'] = self.pid
                if message['method'] == 'repository.presets.save':
                    if message['payload'].get('idempotency_key'):
                        message['payload']['idempotency_key'] = case['id']
                    if type(message['payload'].get('expected_revision')) is int and message['payload']['expected_revision'] >= 0:
                        message['payload']['expected_revision'] = self.store.get(self.pid)['revision']
                response = app.handle(message)
                self.assertEqual('error' not in response['payload'], case['valid'], response)
                if not case['valid']:
                    self.assertEqual(response['payload']['error']['code'], 'invalid_payload')

    def test_new_and_legacy_profile_get_save_never_migrates_or_mutates_profile(self):
        before = self.profile_bytes()
        self.assertEqual(self.store.get(self.pid), {'profile_id': self.pid, 'revision': 0, 'stage_presets': [], 'student_groups': []})
        self.assertFalse(self.path.exists())
        self.assertEqual(self.profile_bytes(), before)
        self.save()
        self.assertEqual(self.profile_bytes(), before)
        path = self.repo._profile_path(self.pid)
        legacy = json.loads(path.read_text(encoding='utf-8')); del legacy['plan']
        path.write_text(json.dumps(legacy), encoding='utf-8')
        before = self.profile_bytes()
        self.store.get(self.pid)
        self.save(1, 'legacy')
        self.assertEqual(self.profile_bytes(), before)
        self.assertNotIn('plan', json.loads(path.read_text(encoding='utf-8')))
        self.assertEqual(self.repo.get_plan(self.pid)['revision'], 1)
        self.assertEqual(self.store.get(self.pid)['revision'], 2)

    def test_roundtrip_unknown_ids_nullable_zero_and_whole_replacement(self):
        self.assertEqual(self.save(), {'revision': 1})
        state = PresetStore(JsonRepository(self.root)).get(self.pid)
        self.assertEqual(state, {'profile_id': self.pid, 'revision': 1, **self.bundle})
        self.assertIn('future-student', state['student_groups'][0]['student_ids'])
        targets = state['stage_presets'][0]['stages'][1]['targets']
        self.assertEqual(targets['level'], 0)
        self.assertIsNone(targets['student_star'])
        self.assertEqual(self.save(1, 'clear', {'stage_presets': [], 'student_groups': []}), {'revision': 2})
        self.assertEqual(self.store.get(self.pid)['stage_presets'], [])
        self.assertEqual(self.store.get(self.pid)['student_groups'], [])

    def test_revision_and_idempotency_replay_after_later_save_restart(self):
        self.save()
        self.save(1, 'second')
        before = self.path.read_bytes()
        self.store = PresetStore(JsonRepository(self.root))
        self.assertEqual(self.save(), {'revision': 1})
        self.assertEqual(self.path.read_bytes(), before)
        error = self.assert_error('revision_conflict', lambda: self.save(0, 'stale'))
        self.assertEqual(error.details, {'current_revision': 2})
        self.assert_error('idempotency_conflict', lambda: self.save(1, 'first'))
        self.assert_error('idempotency_conflict', lambda: self.save(0, 'first', {'stage_presets': [], 'student_groups': []}))
        self.assertEqual(self.path.read_bytes(), before)

    def test_profile_plan_mutations_do_not_change_collection_and_profiles_are_isolated(self):
        self.save(); before = self.path.read_bytes()
        self.repo.rename_profile(self.pid, 'Rename', 0, 'rename')
        plan = self.repo.get_plan(self.pid)
        self.repo.save_plan(self.pid, plan['document'], 1, 'plan')
        self.assertEqual(self.path.read_bytes(), before)
        pid2 = self.repo.create_profile('Second', 'second-profile')['profile']['profile_id']
        self.assertEqual(self.store.get(pid2)['revision'], 0)
        self.store.save(pid2, 0, 'first', [], [])
        self.assertEqual(self.path.read_bytes(), before)

    def test_v6_import_empty_collection(self):
        account = V6Account('v6-key', 'Imported', 'hasumi', (), {'version': 1, 'entries': []}, {'version': 1, 'goals': []}, ())
        with patch('core.repository_store.load_v6_accounts', return_value=[account]):
            imported = self.repo.import_v6_profile('unused', 'v6-key')['profile']['profile_id']
        self.assertEqual(self.store.get(imported), {'profile_id': imported, 'revision': 0, 'stage_presets': [], 'student_groups': []})
        self.assertEqual(self.repo.get_state(imported)['revision'], 0)

    def test_atomic_failures_preserve_both_lists_revision_and_replay_cache(self):
        for existing in (False, True):
            if existing: self.save()
            before = self.path.read_bytes() if existing else None
            profile = self.profile_bytes()
            for stage in ('before_write', 'before_fsync', 'before_replace'):
                with self.subTest(existing=existing, stage=stage):
                    def fault(point):
                        if point == stage: raise OSError(stage)
                    failing = PresetStore(JsonRepository(self.root, fault=fault))
                    error = self.assert_error('persistence_failed', lambda: failing.save(self.pid, int(existing), 'failed', [], []))
                    self.assertTrue(error.retryable)
                    self.assertEqual(self.path.read_bytes() if self.path.exists() else None, before)
                    self.assertEqual(self.profile_bytes(), profile)
                    self.assertFalse(list((self.root / 'presets').glob('.*.tmp')))

    def test_delete_cleanup_and_failure_restores_collection(self):
        self.save()
        before = self.path.read_bytes(), self.profile_bytes()
        unlink = Path.unlink
        def fail(path, *args, **kwargs):
            if path == self.path: raise OSError('presets deletion')
            return unlink(path, *args, **kwargs)
        with patch.object(Path, 'unlink', fail):
            self.assert_error('persistence_failed', lambda: self.repo.delete_profile(self.pid, 0, 'delete'))
        self.assertEqual((self.path.read_bytes(), self.profile_bytes()), before)
        self.assertEqual(self.repo.delete_profile(self.pid, 0, 'delete'), {'revision': 1})
        self.assertFalse(self.path.exists())
        self.assert_error('profile_not_found', lambda: self.store.get(self.pid))

    def test_corrupt_collection_not_overwritten(self):
        self.save()
        original = json.loads(self.path.read_text(encoding='utf-8'))
        for label, corrupt in [('json', '{bad'), ('shape', {**original, 'extra': 1}), ('revision', {**original, 'revision': True}), ('cache', {**original, 'idempotency': {'x': {'fingerprint': 'bad', 'response': {'revision': 1}}}}), ('regression', {**original, 'stage_presets': [{'preset_id': 'x', 'name': 'X', 'stages': [{'name': '1', 'targets': {key: 1 for key in TARGET_MAXIMUMS}}, {'name': '2', 'targets': {key: None for key in TARGET_MAXIMUMS}}]}]})]:
            with self.subTest(label=label):
                self.path.write_text(corrupt if isinstance(corrupt, str) else json.dumps(corrupt), encoding='utf-8')
                before = self.path.read_bytes()
                self.assert_error('corrupt_data', lambda: self.store.get(self.pid))
                self.assert_error('corrupt_data', lambda: self.save())
                self.assertEqual(self.path.read_bytes(), before)

    def test_shared_lock_serializes_with_profile_delete(self):
        entered, finish = threading.Event(), threading.Event()
        def fault(stage):
            if stage == 'before_replace':
                entered.set(); self.assertTrue(finish.wait(5))
        store = PresetStore(JsonRepository(self.root, fault=fault))
        errors = []
        def save():
            try: store.save(self.pid, 0, 'blocked', [], [])
            except Exception as error: errors.append(error)
        worker = threading.Thread(target=save)
        worker.start()
        try:
            self.assertTrue(entered.wait(5))
            self.assert_error('repository_busy', lambda: self.repo.delete_profile(self.pid, 0, 'delete'))
            self.assert_error('repository_busy', lambda: self.store.get(self.pid))
        finally:
            finish.set(); worker.join(5)
        self.assertFalse(worker.is_alive()); self.assertEqual(errors, [])
        self.repo.delete_profile(self.pid, 0, 'delete')
        self.assertFalse(self.path.exists())

    def test_caps_boundaries_and_names(self):
        targets = {key: None for key in TARGET_MAXIMUMS}
        stage = {'name': '단계', 'targets': targets}
        def preset(index, count=0): return {'preset_id': str(index), 'name': '프리셋', 'stages': [copy.deepcopy(stage) for _ in range(count)]}
        def group(index, count=0): return {'group_id': str(index), 'name': '그룹', 'student_ids': [str(i) for i in range(count)]}
        cases = [
            ([preset(i) for i in range(100)], [], True), ([preset(i) for i in range(101)], [], False),
            ([preset(0, 50)], [], True), ([preset(0, 51)], [], False),
            ([preset(i, 50) for i in range(20)], [], True), ([preset(i, 50) for i in range(21)], [], False),
            ([], [group(i) for i in range(100)], True), ([], [group(i) for i in range(101)], False),
            ([], [group(0, 1000)], True), ([], [group(0, 1001)], False),
            ([], [group(i, 1000) for i in range(10)], True), ([], [group(i, 1000) for i in range(11)], False),
        ]
        for index, (presets, groups, valid) in enumerate(cases):
            with self.subTest(index=index):
                if valid: preset_bundle_from_wire(presets, groups)
                else:
                    with self.assertRaises(ValueError): preset_bundle_from_wire(presets, groups)
        for value, valid in [('😀'*120, True), ('😀'*121, False), ('x'*120, True)]:
            with self.subTest(name_length=len(value)):
                raw = {**preset(0), 'name': value}
                if valid: self.assertEqual(preset_bundle_from_wire([raw], [])['stage_presets'][0]['name'], value)
                else:
                    with self.assertRaises(ValueError): preset_bundle_from_wire([raw], [])
        self.assertEqual(preset_bundle_from_wire([{**preset(0), 'name': '  이름  '}], [])['stage_presets'][0]['name'], '이름')


if __name__ == '__main__':
    unittest.main()
