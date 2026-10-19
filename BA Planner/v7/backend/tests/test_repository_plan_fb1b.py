from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from core.application_protocol_v1 import ApplicationProtocolV1
from core.planning import GrowthPlan, StudentGoal
from core.planning_calc import calculate_plan_totals
from core.planning_document import calculate_document_projection, planning_document_from_wire
from core.repository_dto import InventorySnapshot, StudentGoalRecord
from core.repository_plan import canonical_active_document, document_from_goals, goals_from_document
from core.repository_store import JsonRepository, RepositoryError
from core.scenario_store import ScenarioStore
from core.v6_migration import V6Account
from tools.seed_ui_test_profile import seed

CONTRACTS = Path(__file__).parents[2] / 'contracts'


class RepositoryPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.policies = json.loads((CONTRACTS / 'fixtures/repository_plan_migration_v1.json').read_text(encoding='utf-8'))['cases']
        cls.wire = json.loads((CONTRACTS / 'fixtures/repository_plan_v1.json').read_text(encoding='utf-8'))['cases']
        schemas = [json.loads(path.read_text(encoding='utf-8')) for path in CONTRACTS.glob('*.schema.json')]
        registry = Registry().with_resources((value['$id'], Resource.from_contents(value)) for value in schemas)
        schema = next(value for value in schemas if value['$id'].endswith('/repository-protocol-v1.schema.json'))
        cls.validator = Draft202012Validator(schema, registry=registry)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = JsonRepository(self.root)
        self.pid = self.repo.create_profile('Plan', 'fb1b')['profile']['profile_id']
        self.path = self.repo._profile_path(self.pid)

    def case(self, name):
        return copy.deepcopy(next(value for value in self.policies if value['id'] == name))

    def legacy(self, case, revision=4):
        profile = json.loads(self.path.read_text(encoding='utf-8'))
        profile.pop('plan', None)
        profile.pop('current_history', None)  # A legacy file predates history.
        profile.update(revision=revision, goals=case['legacy_goals'], students=case.get('students', []))
        profile['idempotency'] = {'old-write': {'fingerprint': 'a' * 64, 'response': {'revision': revision}}}
        self.path.write_text(json.dumps(profile), encoding='utf-8')
        catalog = json.loads(self.repo.catalog_path.read_text(encoding='utf-8'))
        catalog['profiles'][0]['revision'] = revision
        self.repo.catalog_path.write_text(json.dumps(catalog), encoding='utf-8')

    def bytes(self):
        return self.path.read_bytes(), self.repo.catalog_path.read_bytes()

    def test_policy_fixtures_migrate_once_without_current_value_fill(self):
        for case in self.policies:
            if 'expected_document' not in case:
                continue
            with self.subTest(case=case['id']):
                self.legacy(case)
                result = self.repo.get_plan(self.pid)
                self.assertEqual(result['revision'], 5)
                self.assertEqual(result['document'], case['expected_document'])
                self.assertEqual(self.repo.get_state(self.pid)['goals'], case['expected_goals'])
                persisted = json.loads(self.path.read_text(encoding='utf-8'))
                self.assertEqual(persisted['idempotency']['old-write']['response'], {'revision': 4})
                before = self.bytes()
                self.assertEqual(JsonRepository(self.root).get_plan(self.pid), result)
                self.assertEqual(self.bytes(), before)
                self.assertEqual(self.repo.list_profiles()['profiles'][0]['revision'], 5)

    def test_state_get_uses_the_same_migration(self):
        self.legacy(self.case('null_bond_known_current'))
        self.assertEqual(self.repo.get_state(self.pid)['revision'], 5)
        self.assertEqual(self.repo.get_plan(self.pid)['revision'], 5)

    def test_duplicate_costs_are_not_silently_folded_and_corrupt_files_survive(self):
        duplicate = self.case('duplicate_goals')
        self.legacy(duplicate)
        before = self.bytes()
        for read in (self.repo.get_state, self.repo.get_plan):
            with self.assertRaises(RepositoryError) as raised:
                read(self.pid)
            self.assertEqual(raised.exception.code, 'legacy_goals_conflict')
            self.assertEqual(raised.exception.details['student_ids'], ['aru'])
            self.assertEqual(self.bytes(), before)
        goals = [StudentGoal(**goal) for goal in duplicate['legacy_goals']['goals']]
        totals = calculate_plan_totals({'aru': SimpleNamespace(level=1)}, GrowthPlan(goals=goals))
        single = calculate_plan_totals({'aru': SimpleNamespace(level=1)}, GrowthPlan(goals=[goals[-1]]))
        self.assertGreater(totals.credits, single.credits)
        self.path.write_text(self.case('corrupt_legacy')['file_contents'], encoding='utf-8')
        before = self.bytes()
        with self.assertRaises(RepositoryError) as raised:
            self.repo.get_plan(self.pid)
        self.assertEqual(raised.exception.code, 'corrupt_data')
        self.assertEqual(self.bytes(), before)

    def test_concurrent_first_load_rechecks_under_lock_and_only_increments_once(self):
        self.legacy(self.case('empty_legacy'))
        entered, proceed = threading.Event(), threading.Event()
        failures = []
        def fault(stage):
            if stage == 'before_write' and not entered.is_set():
                entered.set()
                if not proceed.wait(5):
                    raise TimeoutError('test reader did not release')
        def read():
            try:
                JsonRepository(self.root, fault=fault).get_plan(self.pid)
            except Exception as error:
                failures.append(error)
        worker = threading.Thread(target=read)
        worker.start()
        try:
            self.assertTrue(entered.wait(5))
            with self.assertRaises(RepositoryError) as raised:
                self.repo.get_plan(self.pid)
            self.assertEqual(raised.exception.code, 'repository_busy')
            self.assertTrue(raised.exception.retryable)
        finally:
            proceed.set()
            worker.join(5)
        self.assertFalse(worker.is_alive())
        self.assertEqual(failures, [])
        self.assertEqual(self.repo.get_plan(self.pid)['revision'], 5)

    def test_final_stage_derivation_preserves_order_metadata_null_and_zero(self):
        doc = self.case('partial_goal_explicit_zero')['expected_document']
        first = doc['phases'][0]['stages'][0]
        second_student = copy.deepcopy(first)
        second_student.update(stage_id='other', student_id='ayane')
        doc['phases'][0]['stages'].append(second_student)
        doc['goal_metadata']['ayane'] = {'favorite': True, 'notes': ''}
        last = copy.deepcopy(first)
        last['stage_id'] = 'aru-last'
        last['targets'].update(level=90, bond_rank=50)
        doc['phases'].append({'phase_id': 'last', 'name': 'Last', 'stages': [last]})
        self.repo.save_plan(self.pid, doc, 0, 'multi')
        goals = self.repo.get_state(self.pid)['goals']['goals']
        self.assertEqual([goal['student_id'] for goal in goals], ['aru', 'ayane'])
        self.assertEqual(goals[0]['target_level'], 90)
        self.assertEqual(goals[0]['target_stat_hp'], 0)
        self.assertIsNone(goals[0]['target_star'])
        self.assertEqual(goals[0]['notes'], '부분 목표')
        self.assertNotIn('bond_rank', goals[0])
        self.assertEqual(self.repo.get_plan(self.pid)['document'], doc)

    def test_saved_empty_document_is_authoritative_after_restart(self):
        doc = self.case('null_bond_known_current')['expected_document']
        self.repo.save_plan(self.pid, doc, 0, 'first')
        empty = self.case('saved_empty_is_authoritative')['document']
        self.repo.save_plan(self.pid, empty, 1, 'empty')
        restored = JsonRepository(self.root)
        self.assertEqual(restored.get_plan(self.pid)['document'], empty)
        self.assertEqual(restored.get_state(self.pid)['goals'], {'version': 1, 'goals': []})
        self.assertEqual(restored.get_plan(self.pid)['revision'], 2)

    def test_current_inventory_and_profile_changes_only_recompute_summary(self):
        doc = self.case('null_bond_unknown_current')['expected_document']
        self.repo.save_plan(self.pid, doc, 0, 'plan')
        goals = self.repo.get_state(self.pid)['goals']
        self.repo.update_students(self.pid, [{'version': 1, 'student_id': 'aru', 'values': {'level': 10, 'bond_rank': None}}], 1, 'current')
        self.repo.update_inventory(self.pid, {'version': 1, 'entries': []}, 2, 'inventory')
        self.repo.rename_profile(self.pid, 'Renamed', 3, 'rename')
        active = self.repo.get_plan(self.pid)
        self.assertEqual(active['revision'], 4)
        self.assertEqual(active['document'], doc)
        self.assertEqual(self.repo.get_state(self.pid)['goals'], goals)
        self.assertEqual(active['calculation']['credits'], 0)

    def test_revision_idempotency_scope_and_stale_legacy_write(self):
        doc = self.case('all_null_goal')['expected_document']
        self.assertEqual(self.repo.save_plan(self.pid, doc, 0, 'once'), {'revision': 1})
        before = self.bytes()
        self.assertEqual(self.repo.save_plan(self.pid, doc, 0, 'once'), {'revision': 1})
        self.assertEqual(self.bytes(), before)
        for key, rev, changed, code in [('stale', 0, doc, 'revision_conflict'), ('once', 1, doc, 'idempotency_conflict'), ('once', 0, {**doc, 'name': 'changed'}, 'idempotency_conflict')]:
            with self.assertRaises(RepositoryError) as raised:
                self.repo.save_plan(self.pid, changed, rev, key)
            self.assertEqual(raised.exception.code, code)
            self.assertEqual(self.bytes(), before)
        self.legacy(self.case('empty_legacy'))
        with self.assertRaises(RepositoryError) as raised:
            self.repo.save_plan(self.pid, doc, 4, 'pre-migration')
        self.assertEqual(raised.exception.code, 'revision_conflict')
        self.assertEqual(raised.exception.details['current_revision'], 5)

    def test_plan_save_and_migration_roll_back_both_files_on_failure(self):
        for migration in (False, True):
            for stage in ('before_write', 'before_fsync', 'before_replace', 'catalog_replace'):
                with self.subTest(migration=migration, stage=stage):
                    if migration:
                        self.legacy(self.case('null_bond_unknown_current'))
                    before = self.bytes()
                    replaces = 0
                    def fault(actual):
                        nonlocal replaces
                        if actual == 'before_replace': replaces += 1
                        if actual == stage or (stage == 'catalog_replace' and actual == 'before_replace' and replaces == 2):
                            raise OSError('injected failure')
                    failing = JsonRepository(self.root, fault=fault)
                    with self.assertRaises(RepositoryError) as raised:
                        if migration: failing.get_plan(self.pid)
                        else: failing.save_plan(self.pid, self.case('all_null_goal')['expected_document'], 0, 'failure')
                    self.assertEqual(raised.exception.code, 'persistence_failed')
                    self.assertEqual(self.bytes(), before)
                    self.assertEqual(list(self.path.parent.glob('*.tmp')), [])

    def test_legacy_writer_uses_same_conversion_and_blocks_loss(self):
        case = self.case('partial_goal_explicit_zero')
        self.assertEqual(self.repo.save_goals(self.pid, case['legacy_goals'], 0, 'legacy'), {'revision': 1})
        self.assertEqual(self.repo.get_plan(self.pid)['document'], case['expected_document'])
        for reason in ('multiple_phases', 'multiple_student_stages', 'bond_target'):
            doc = copy.deepcopy(case['expected_document'])
            if reason == 'multiple_phases': doc['phases'].append({'phase_id': 'empty', 'name': 'Keep', 'stages': []})
            elif reason == 'multiple_student_stages':
                stage = copy.deepcopy(doc['phases'][0]['stages'][0]); stage['stage_id'] = 'second'
                doc['phases'][0]['stages'].append(stage)
            else: doc['phases'][0]['stages'][0]['targets']['bond_rank'] = 20
            rev = self.repo.get_plan(self.pid)['revision']
            self.repo.save_plan(self.pid, doc, rev, reason)
            before = self.bytes()
            with self.assertRaises(RepositoryError) as raised:
                self.repo.save_goals(self.pid, {'version': 1, 'goals': []}, rev + 1, 'loss-' + reason)
            self.assertEqual(raised.exception.code, 'plan_lossy_write')
            self.assertIn(reason, raised.exception.details['reasons'])
            self.assertEqual(self.bytes(), before)
        # A successful earlier retry keeps its original response even after a richer plan.
        self.assertEqual(self.repo.save_goals(self.pid, case['legacy_goals'], 0, 'legacy'), {'revision': 1})
        before = self.bytes()
        with self.assertRaises(RepositoryError) as raised:
            self.repo.save_goals(self.pid, self.case('duplicate_goals')['legacy_goals'], 4, 'duplicates')
        self.assertEqual(raised.exception.code, 'legacy_goals_conflict')
        self.assertEqual(self.bytes(), before)

    def test_stored_document_or_derived_goals_corruption_does_not_revive_legacy(self):
        original = self.path.read_bytes()
        for field in ('document', 'goals'):
            value = json.loads(original)
            if field == 'document': value['plan']['kind'] = 'scenario'
            else: value['goals']['goals'] = [{'student_id': 'aru'}]
            self.path.write_text(json.dumps(value), encoding='utf-8')
            before = self.bytes()
            with self.assertRaises(RepositoryError) as raised:
                self.repo.get_plan(self.pid)
            self.assertEqual(raised.exception.code, 'corrupt_data')
            self.assertEqual(self.bytes(), before)
        self.path.write_bytes(original)

    def test_summary_uses_same_scenario_projection_and_failure_is_null(self):
        case = self.case('null_bond_known_current')
        self.repo.update_students(self.pid, case['students'], 0, 'students')
        self.repo.save_plan(self.pid, case['expected_document'], 1, 'document')
        state = self.repo.get_state(self.pid)
        active = self.repo.get_plan(self.pid)
        scenarios = ScenarioStore(self.root, profile_revision=lambda _: state['revision'], profile_state=lambda _: state, id_factory=lambda: 'b' * 32)
        doc = {**active['document'], 'kind': 'scenario'}
        scenarios.create(self.pid, 0, 'scenario', 'Same', '', state['revision'], doc)
        self.assertEqual(scenarios.list(self.pid)['scenarios'][0]['calculation'], active['calculation'])
        old_cost = calculate_plan_totals({'aru': SimpleNamespace(**case['students'][0]['values'])}, GrowthPlan(goals=[StudentGoalRecord.from_dict({'version': 1, 'goal': state['goals']['goals'][0]}).goal]))
        projection = calculate_document_projection({'aru': SimpleNamespace(**case['students'][0]['values'])}, planning_document_from_wire(doc), InventorySnapshot.from_dict(state['inventory']))
        self.assertEqual(active['calculation']['credits'], old_cost.credits)
        self.assertEqual(projection['overall']['cost']['credits'], old_cost.credits)
        with patch('core.planning_summary.calculate_document_projection', side_effect=RuntimeError('unavailable')):
            result = self.repo.get_plan(self.pid)
            self.assertIsNone(result['calculation'])
            self.assertEqual(result['document'], active['document'])

    def test_scenario_first_access_migrates_before_shared_writer_lock(self):
        self.legacy(self.case('empty_legacy'))
        application = ApplicationProtocolV1(storage_root=self.root)
        response = application.handle({'protocol': 1, 'id': 'first-scenario', 'type': 'request', 'method': 'repository.scenario.create', 'payload': {
            'profile_id': self.pid, 'expected_revision': 0, 'idempotency_key': 'first-scenario', 'name': 'Old base', 'description': '',
            'base_profile_revision': 4, 'document': {**self.case('empty_legacy')['expected_document'], 'kind': 'scenario'},
        }})
        self.assertNotIn('error', response['payload'])
        self.assertEqual(self.repo.get_state(self.pid)['revision'], 5)
        # Original scenario base remains historic; migration doesn't rewrite it.
        scenario = json.loads((self.root / 'scenarios' / f'{self.pid}.json').read_text(encoding='utf-8'))['scenarios'][0]
        self.assertEqual(scenario['base_profile_revision'], 4)

    def test_scenario_duplicate_migration_error_matches_its_contract(self):
        self.legacy(self.case('duplicate_goals'))
        application = ApplicationProtocolV1(storage_root=self.root)
        before = self.bytes()
        response = application.handle({'protocol': 1, 'id': 'duplicate-scenario', 'type': 'request',
            'method': 'repository.scenario.list', 'payload': {'profile_id': self.pid}})
        self.assertEqual(response['payload']['error']['code'], 'legacy_goals_conflict')
        scenario_schema = json.loads((CONTRACTS / 'scenario-protocol-v1.schema.json').read_text(encoding='utf-8'))
        Draft202012Validator(scenario_schema['$defs']['error']).validate(response['payload'])
        self.assertEqual(self.bytes(), before)

    def test_seed_import_and_repeat_use_authoritative_state_revision(self):
        # Isolated bulk profile; skip optional list KPI work to test seed persistence.
        account = V6Account(profile_key='profile_12345678', display_name='Seed source', avatar_student_id='aru',
            students=tuple({'version': 1, 'student_id': f'seed-{i}', 'values': {'level': 1}} for i in range(200)),
            inventory={'version': 1, 'entries': [{'key': f'seed-item-{i}', 'quantity': '0'} for i in range(500)]},
            goals=self.case('empty_legacy')['legacy_goals'], warnings=())
        with patch('core.repository_store.load_v6_accounts', return_value=(account,)), patch.object(ScenarioStore, '_safe_calculation_summary', return_value=None):
            first = seed(self.root, self.root / 'unused-v6', profile_key=account.profile_key, profile_name='FB1b seed')
            second = seed(self.root, self.root / 'unused-v6', profile_key=account.profile_key, profile_name='FB1b seed')
        self.assertTrue(first['created'])
        self.assertFalse(second['created'])
        self.assertEqual(first['profile_id'], second['profile_id'])
        pid = first['profile_id']
        self.assertEqual(self.repo.get_plan(pid)['revision'], 1)  # rename, no extra migration
        collection = json.loads((self.root / 'scenarios' / f'{pid}.json').read_text(encoding='utf-8'))
        self.assertEqual(collection['revision'], 8)
        self.assertEqual(len(collection['scenarios']), 8)
        self.assertTrue(all(item['base_profile_revision'] == 1 for item in collection['scenarios']))

    def test_new_profile_and_v6_import_include_document_at_revision_zero(self):
        self.assertEqual(self.repo.get_plan(self.pid)['revision'], 0)
        v6 = self.root / 'v6'
        source_key = 'profile_12345678'
        current = v6 / 'profiles' / source_key / 'data' / 'current'
        current.mkdir(parents=True)
        (v6 / 'config.json').write_text(json.dumps({'profiles': [{'key': source_key, 'name': 'Old'}]}), encoding='utf-8')
        case = self.case('null_bond_unknown_current')
        (current / 'growth_plan.json').write_text(json.dumps(case['legacy_goals']), encoding='utf-8')
        (current / 'students.json').write_text('{}', encoding='utf-8')
        (current / 'inventory.json').write_text('{}', encoding='utf-8')
        source_before = {path: path.read_bytes() for path in v6.rglob('*') if path.is_file()}
        imported = self.repo.import_v6_profile(str(v6), source_key)
        pid = imported['profile']['profile_id']
        self.assertEqual(self.repo.get_plan(pid)['revision'], 0)
        self.assertEqual(self.repo.get_plan(pid)['document'], case['expected_document'])
        self.assertEqual(self.repo.get_state(pid)['goals'], case['expected_goals'])
        self.assertEqual({path: path.read_bytes() for path in source_before}, source_before)
        # Duplicate imports fail before creation, without altering existing v7 data.
        (current / 'growth_plan.json').write_text(json.dumps(self.case('duplicate_goals')['legacy_goals']), encoding='utf-8')
        catalog_before = self.repo.catalog_path.read_bytes()
        profiles_before = {path: path.read_bytes() for path in self.path.parent.glob('*.json')}
        with self.assertRaises(RepositoryError) as raised:
            self.repo.import_v6_profile(str(v6), source_key)
        self.assertEqual(raised.exception.code, 'legacy_goals_conflict')
        self.assertEqual(self.repo.catalog_path.read_bytes(), catalog_before)
        self.assertEqual({path: path.read_bytes() for path in self.path.parent.glob('*.json')}, profiles_before)

    def test_shared_contract_strictness_and_protocol_round_trip(self):
        for case in self.wire:
            with self.subTest(case=case['id']):
                self.assertEqual(self.validator.is_valid(case['message']), case['valid'])
        application = ApplicationProtocolV1(storage_root=self.root)
        document = self.case('all_null_goal')['expected_document']
        payload = {'profile_id': self.pid, 'expected_revision': 0, 'idempotency_key': 'wire', 'document': document}
        for method, data in [('repository.plan.save', payload), ('repository.plan.get', {'profile_id': self.pid})]:
            request = {'protocol': 1, 'id': method, 'type': 'request', 'method': method, 'payload': data}
            self.validator.validate(request)
            response = application.handle(request)
            self.validator.validate(response)
            self.assertNotIn('error', response['payload'])
        for changed in ({**document, 'version': 1}, {**document, 'kind': 'scenario'}):
            before = self.bytes()
            with self.assertRaises(ValueError): canonical_active_document(changed)
            self.assertEqual(self.bytes(), before)


if __name__ == '__main__':
    unittest.main()
