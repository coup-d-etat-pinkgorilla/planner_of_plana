from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_plan import document_from_goals, goals_from_document
from core.repository_store import JsonRepository, RepositoryError
from core.repository_transaction import JOURNAL
from core.scenario_store import ScenarioStore

CONTRACTS = Path(__file__).parents[2] / 'contracts'
CHILD = '''
import json, os, sys, time
from pathlib import Path
from core.repository_store import JsonRepository
root, pid, document, stage, mode = sys.argv[1:]
def fault(point):
    if point == stage:
        if mode == 'kill':
            (Path(root) / 'ready').write_text('ready')
            while True: time.sleep(.05)
        os._exit(73)
repo = JsonRepository(Path(root), id_factory=lambda: 'b' * 32, fault=fault)
repo.replace_plan(pid, json.loads(document), 1, 1, 'replace-once', ' Archive ', ' retained ')
'''


class RepositoryReplaceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.wire = json.loads((CONTRACTS / 'fixtures/repository_plan_replace_v1.json').read_text(encoding='utf-8'))['cases']
        schemas = [json.loads(path.read_text(encoding='utf-8')) for path in CONTRACTS.glob('*.schema.json')]
        registry = Registry().with_resources((schema['$id'], Resource.from_contents(schema)) for schema in schemas)
        cls.validator = Draft202012Validator(next(s for s in schemas if s['$id'].endswith('/repository-protocol-v1.schema.json')), registry=registry)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = JsonRepository(self.root, id_factory=lambda: 'b' * 32)
        self.pid = self.repo.create_profile('Replace', 'fb1c')['profile']['profile_id']
        self.old = document_from_goals({'version': 1, 'goals': [{'student_id': 'aru', 'target_level': 10, 'favorite': False, 'notes': ' old notes '}]})
        self.old['phases'][0]['stages'][0]['targets']['bond_rank'] = 35
        self.repo.save_plan(self.pid, self.old, 0, 'save-old')
        self.new = document_from_goals({'version': 1, 'goals': [{'student_id': 'ayane', 'target_level': 20, 'target_stat_hp': 0, 'notes': 'new'}]})
        self.store = ScenarioStore(self.root, profile_revision=lambda pid: self.repo.get_state(pid)['revision'], profile_state=self.repo.get_state, id_factory=lambda: 'c' * 32)
        self.store.create(self.pid, 0, 'initial-scenario', 'Existing v1', '', 1, {**self.old, 'kind': 'scenario'})
        self.paths = [self.repo._profile_path(self.pid), self.repo.catalog_path, self.store._path(self.pid)]

    def replace(self, repo=None, **kwargs):
        args = dict(profile_id=self.pid, document=self.new, expected_revision=1, expected_scenario_revision=1, idempotency_key='replace-once', archive_name=' Archive ', archive_description=' retained ')
        args.update(kwargs)
        return (repo or self.repo).replace_plan(**args)

    def snapshot(self):
        return [path.read_bytes() if path.exists() else None for path in self.paths]

    def restore(self, content):
        for path, raw in zip(self.paths, content):
            if raw is None: path.unlink(missing_ok=True)
            else: path.write_bytes(raw)

    def assert_after(self):
        fresh = JsonRepository(self.root)
        state = fresh.get_state(self.pid)
        self.assertEqual(state['revision'], 2)
        self.assertEqual(state['goals'], goals_from_document(self.new))
        self.assertEqual(fresh.get_plan(self.pid)['document'], self.new)
        self.assertEqual(fresh.list_profiles()['profiles'][0]['revision'], 2)
        listed = self.store.list(self.pid)
        self.assertEqual(listed['revision'], 2)
        self.assertEqual(len(listed['scenarios']), 2)
        archived = self.store.get(self.pid, 'b' * 24)['scenario']
        self.assertEqual(archived['document'], {**self.old, 'kind': 'scenario', 'document_id': 'b' * 24})
        self.assertEqual(archived['base_profile_revision'], 1)
        self.assertEqual(archived['revision'], 0)
        self.assertEqual((archived['name'], archived['description']), ('Archive', 'retained'))
        self.assertFalse((self.root / JOURNAL).exists())
        return fresh

    def test_replace_preserves_complete_document_and_existing_scenarios(self):
        before = self.store.get(self.pid, 'c' * 24)['scenario']
        response = self.replace()
        self.assertEqual(response, {'revision': 2, 'scenario_revision': 2, 'archived_scenario_id': 'b' * 24})
        self.assert_after()
        self.assertEqual(self.store.get(self.pid, 'c' * 24)['scenario'], before)
        self.assertEqual(self.repo._profile(self.pid)['idempotency']['save-old']['response'], {'revision': 1})

    def test_empty_phases_skip_archive_and_collection_write_but_require_both_revisions(self):
        empty = document_from_goals({'version': 1, 'goals': []})
        self.repo.save_plan(self.pid, empty, 1, 'clear')
        scenario_bytes = self.paths[2].read_bytes()
        response = self.replace(expected_revision=2)
        self.assertEqual(response, {'revision': 3, 'scenario_revision': 1, 'archived_scenario_id': None})
        self.assertEqual(self.paths[2].read_bytes(), scenario_bytes)
        self.repo.save_plan(self.pid, empty, 3, 'clear-again')
        with self.assertRaises(RepositoryError) as caught:
            self.replace(expected_revision=4, expected_scenario_revision=0, idempotency_key='stale-empty')
        self.assertEqual(caught.exception.details['revision_scope'], 'scenario')

    def test_empty_absent_collection_remains_absent(self):
        self.paths[2].unlink()
        self.repo.save_plan(self.pid, document_from_goals({'version': 1, 'goals': []}), 1, 'clear')
        self.assertEqual(self.replace(expected_revision=2, expected_scenario_revision=0), {'revision': 3, 'scenario_revision': 0, 'archived_scenario_id': None})
        self.assertFalse(self.paths[2].exists())

    def test_revision_scopes_validation_and_idempotent_replay_after_later_writes(self):
        before = self.snapshot()
        for profile_rev, scenario_rev, scope in [(0, 1, 'profile'), (1, 0, 'scenario'), (0, 0, 'both')]:
            with self.subTest(scope=scope), self.assertRaises(RepositoryError) as caught:
                self.replace(expected_revision=profile_rev, expected_scenario_revision=scenario_rev)
            self.assertEqual(caught.exception.details, {'revision_scope': scope, 'current_revision': 1, 'current_scenario_revision': 1})
            self.assertEqual(before, self.snapshot())
        response = self.replace()
        self.repo.save_plan(self.pid, self.old, 2, 'later-plan')
        self.store.delete(self.pid, 'b' * 24, 2, 0, 'delete-archive')
        later = self.snapshot()
        self.assertEqual(self.replace(), response)
        self.assertEqual(later, self.snapshot())
        for changed in [{'document': self.old}, {'archive_name': 'different'}, {'expected_scenario_revision': 3}, {'expected_revision': 3}]:
            with self.subTest(changed=changed), self.assertRaises(RepositoryError) as caught:
                self.replace(**changed)
            self.assertEqual(caught.exception.code, 'idempotency_conflict')
        with self.assertRaises(RepositoryError) as caught:
            self.repo.save_plan(self.pid, self.new, 1, 'replace-once')
        self.assertEqual(caught.exception.code, 'idempotency_conflict')

    def test_exceptions_between_every_write_select_complete_before_or_after(self):
        before = self.snapshot()
        for stage in ['before_journal', 'journal_prepared', 'profile_written', 'catalog_written', 'scenarios_written', 'before_commit', 'journal_committed', 'journal_removed']:
            with self.subTest(stage=stage):
                self.restore(before)
                def fault(point):
                    if point == stage: raise OSError(stage)
                with self.assertRaises(RepositoryError) as caught:
                    self.replace(JsonRepository(self.root, id_factory=lambda: 'b' * 32, fault=fault))
                self.assertEqual(caught.exception.code, 'persistence_failed')
                if stage in ('journal_committed', 'journal_removed'):
                    self.assert_after()
                    self.assertEqual(self.replace()['revision'], 2)
                else:
                    self.assertEqual(before, self.snapshot())
                    self.assertFalse((self.root / JOURNAL).exists())

    def test_atomic_write_faults_for_all_three_target_files_roll_back(self):
        before = self.snapshot()
        for stage in ('before_write', 'before_fsync', 'before_replace'):
            for number in (1, 2, 3):
                with self.subTest(stage=stage, number=number):
                    self.restore(before)
                    count = 0
                    def fault(point):
                        nonlocal count
                        if point == stage:
                            count += 1
                            if count == number: raise OSError(stage)
                    with self.assertRaises(RepositoryError):
                        self.replace(JsonRepository(self.root, id_factory=lambda: 'b' * 32, fault=fault))
                    self.assertEqual(before, self.snapshot())
                    self.assertFalse((self.root / JOURNAL).exists())

    def crash(self, stage, mode='exit'):
        process = subprocess.Popen([sys.executable, '-X', 'utf8', '-c', CHILD, str(self.root), self.pid, json.dumps(self.new), stage, mode], cwd=Path(__file__).parents[1], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if mode == 'kill':
            ready = self.root / 'ready'
            deadline = time.monotonic() + 10
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(.02)
            if not ready.exists():
                process.kill()
                stdout, stderr = process.communicate(timeout=5)
                self.fail(f'child did not reach {stage}: {stdout!r} {stderr!r}')
            with self.assertRaises(RepositoryError) as caught:
                self.repo.get_state(self.pid)
            self.assertEqual(caught.exception.code, 'repository_busy')
            process.kill()
        stdout, stderr = process.communicate(timeout=10)
        self.assertNotEqual(process.returncode, 0, (stdout, stderr))
        if mode == 'exit': self.assertEqual(process.returncode, 73, stderr)

    def test_process_exit_at_each_boundary_and_replay_never_double_archive(self):
        before = self.snapshot()
        for stage in ['before_journal', 'journal_prepared', 'profile_written', 'catalog_written', 'scenarios_written', 'before_commit', 'journal_committed', 'journal_removed']:
            with self.subTest(stage=stage):
                self.restore(before)
                self.crash(stage)
                fresh = JsonRepository(self.root)
                fresh.get_plan(self.pid)
                if stage in ('journal_committed', 'journal_removed'):
                    self.assert_after()
                else:
                    self.assertEqual(before, self.snapshot())
                # Replaying or applying the same original request creates exactly one archive.
                self.replace(JsonRepository(self.root, id_factory=lambda: 'b' * 32))
                self.assert_after()

    def test_each_related_read_recovers_before_returning_a_snapshot(self):
        before = self.snapshot()
        for name, reader in [('plan', lambda: self.repo.get_plan(self.pid)), ('state', lambda: self.repo.get_state(self.pid)), ('list', lambda: self.store.list(self.pid)), ('get', lambda: self.store.get(self.pid, 'c' * 24))]:
            for stage in ('catalog_written', 'journal_committed'):
                with self.subTest(reader=name, stage=stage):
                    self.restore(before)
                    self.crash(stage)
                    reader()
                    if stage == 'journal_committed': self.assert_after()
                    else: self.assertEqual(before, self.snapshot())
                    self.assertFalse((self.root / JOURNAL).exists())

    def test_external_process_kill_releases_guard_and_restores_all_before(self):
        before = self.snapshot()
        self.crash('catalog_written', mode='kill')
        self.store.list(self.pid)
        self.assertEqual(before, self.snapshot())

    def test_recovery_can_itself_be_interrupted_and_repeated(self):
        before = self.snapshot()
        self.crash('catalog_written')
        from core import repository_transaction
        original = repository_transaction._write_bytes
        count = 0
        def fail(path, content):
            nonlocal count
            if path.name != '.repository.lock':
                count += 1
                if count == 2: raise OSError('recovery interrupted')
            return original(path, content)
        with patch.object(repository_transaction, '_write_bytes', side_effect=fail), self.assertRaises(RepositoryError) as caught:
            self.repo.get_plan(self.pid)
        self.assertEqual(caught.exception.code, 'persistence_failed')
        self.assertTrue((self.root / JOURNAL).exists())
        self.repo.get_state(self.pid)
        self.assertEqual(before, self.snapshot())

    def test_corrupt_journal_never_overwrites_targets(self):
        self.crash('profile_written')
        journal = self.root / JOURNAL
        original = json.loads(journal.read_text(encoding='utf-8'))
        before = self.snapshot()
        for change in ('path', 'image', 'header'):
            value = copy.deepcopy(original)
            if change == 'path': value['writes'][-1]['path'] = '../outside.json'
            elif change == 'image': value['writes'][-1]['before']['sha256'] = '0' * 64
            else: value['state'] = 'unknown'
            journal.write_text(json.dumps(value), encoding='utf-8')
            with self.subTest(change=change), self.assertRaises(RepositoryError) as caught:
                self.repo.get_state(self.pid)
            self.assertEqual(caught.exception.code, 'corrupt_data')
            self.assertEqual(before, self.snapshot())
            self.assertTrue(journal.exists())
        journal.write_text(json.dumps(original), encoding='utf-8')
        self.repo.get_state(self.pid)

    def test_live_writer_blocks_other_thread_and_nested_reads_do_not_deadlock(self):
        lease = self.repo._lock()
        errors = []
        try:
            self.store.list(self.pid)  # nested callbacks read the same root
            def read():
                try: JsonRepository(self.root).get_state(self.pid)
                except RepositoryError as error: errors.append(error.code)
            thread = threading.Thread(target=read)
            thread.start(); thread.join(timeout=3)
            self.assertFalse(thread.is_alive())
            self.assertEqual(errors, ['repository_busy'])
        finally:
            self.repo._unlock(lease)

    def test_failed_recovery_lock_cleanup_does_not_strand_a_live_guard(self):
        journal = self.root / JOURNAL
        journal.write_text('{}', encoding='utf-8')
        original = Path.unlink
        def fail_marker(path, *args, **kwargs):
            if path.name == '.repository.lock':
                raise OSError('marker cleanup failed')
            return original(path, *args, **kwargs)
        with patch.object(Path, 'unlink', fail_marker), self.assertRaises(RepositoryError) as caught:
            self.repo.get_state(self.pid)
        self.assertEqual(caught.exception.code, 'persistence_failed')
        with self.assertRaises(RepositoryError) as caught:
            self.repo.get_state(self.pid)
        self.assertEqual(caught.exception.code, 'corrupt_data')
        journal.unlink()
        self.assertEqual(self.repo.get_state(self.pid)['revision'], 1)

    def test_shared_contract_and_protocol_strict_replace(self):
        for case in self.wire:
            with self.subTest(case=case['id']): self.assertEqual(self.validator.is_valid(case['message']), case['valid'])
        protocol = ApplicationProtocolV1(storage_root=self.root)
        request = copy.deepcopy(self.wire[0]['message'])
        request['payload'].update(profile_id=self.pid, expected_revision=1, expected_scenario_revision=1, document=self.new)
        response = protocol.handle(request)
        self.validator.validate(response)
        self.assertEqual(response['payload']['revision'], 2)
        self.assertEqual(protocol.handle(request), response)
        for key, value in [('expected_revision', True), ('expected_scenario_revision', True), ('archive_name', '  '), ('archive_description', None)]:
            invalid = copy.deepcopy(request); invalid['payload'][key] = value
            wire = protocol.handle(invalid)
            self.assertEqual(wire['payload']['error']['code'], 'invalid_payload')
            self.validator.validate(wire)


if __name__ == '__main__':
    unittest.main()
