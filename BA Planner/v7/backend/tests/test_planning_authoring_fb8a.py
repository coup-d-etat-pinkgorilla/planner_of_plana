from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from core.planning_authoring import PlanningAuthoringError, default_authoring, planning_authoring_from_wire
from core.repository_plan import document_from_goals, goals_from_document
from core.repository_dto import canonical_json
from core.repository_protocol_v1 import RepositoryProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.repository_transaction import JOURNAL
from core.scenario_store import ScenarioStore, ScenarioStoreError
from core.planning_summary import safe_calculation_summary
from core.preset_store import PresetStore

ROOT = Path(__file__).parents[2]
POLICIES = json.loads((ROOT / 'contracts/fixtures/planning_authoring_v1.json').read_text(encoding='utf-8'))['cases']

def policy(name):
    return copy.deepcopy(next(case for case in POLICIES if case['name'] == name))

CHILD = '''
import json, os, sys
from pathlib import Path
from core.repository_store import JsonRepository
root, pid, document, authoring, point = sys.argv[1:]
def fault(stage):
    if stage == point: os._exit(73)
JsonRepository(Path(root), id_factory=lambda: 'b'*32, fault=fault).replace_plan(
    pid, json.loads(document), 1, 1, 'replace', 'Archive', '', json.loads(authoring))
'''


class AuthoringContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        schemas = [json.loads(path.read_text(encoding='utf-8')) for path in (ROOT / 'contracts').glob('*.schema.json')]
        registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas)
        cls.validators = {s['$id'].split('/')[-1]: Draft202012Validator(s, registry=registry) for s in schemas}

    def test_all_shared_policy_cases_and_canonical_order(self):
        for case in POLICIES:
            with self.subTest(case=case['name']):
                if case['valid']:
                    canonical = planning_authoring_from_wire(case['authoring'], case['document'])
                    self.assertEqual(canonical, case['canonical'])
                    self.validators['planning-authoring-v1.schema.json'].validate(canonical)
                else:
                    with self.assertRaises(PlanningAuthoringError) as caught:
                        planning_authoring_from_wire(case['authoring'], case['document'])
                    self.assertEqual(caught.exception.reason, case['reason'])

    def test_wire_schema_fixture_and_repository_protocol(self):
        fixture = json.loads((ROOT / 'contracts/fixtures/repository_plan_authoring_v1.json').read_text(encoding='utf-8'))
        for case in fixture['cases']:
            name = 'scenario-protocol-v1.schema.json' if case['message']['method'].startswith('repository.scenario.') else 'repository-protocol-v1.schema.json'
            with self.subTest(case=case['id']):
                self.assertEqual(self.validators[name].is_valid(case['message']), case['valid'])
        with tempfile.TemporaryDirectory() as tmp:
            repo = JsonRepository(Path(tmp), id_factory=lambda: 'a'*32)
            pid = repo.create_profile('Protocol', 'create')['profile']['profile_id']
            protocol = RepositoryProtocolV1(repo)
            request = copy.deepcopy(fixture['cases'][0]['message'])
            request['payload']['profile_id'] = pid
            self.assertEqual(protocol.handle(request)['payload'], {'revision':1})
            request['payload']['authoring'] = None
            request['payload']['idempotency_key'] = 'bad'
            error = protocol.handle(request)['payload']['error']
            self.assertEqual((error['code'], error['details']['reason']), ('invalid_payload', 'invalid_shape'))

    def test_sidecar_preserves_legacy_document_version_and_does_not_mutate_inputs(self):
        case = policy('deferred-targets-selected-order')
        before = copy.deepcopy(case)
        planning_authoring_from_wire(case['authoring'], case['document'])
        self.assertEqual(case, before)
        v1 = {**case['document'], 'version':1}
        v1.pop('goal_metadata')
        # The common record validator preserves v1; active plans still require v2.
        v1['phases'] = []
        self.assertEqual(planning_authoring_from_wire(default_authoring(v1),v1),default_authoring(v1))
        self.assertEqual(v1['version'],1)


class ActiveAuthoringTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = JsonRepository(self.root, id_factory=lambda:'b'*32)
        self.pid = self.repo.create_profile('Authoring', 'create')['profile']['profile_id']
        case = policy('deferred-targets-selected-order')
        self.old, self.authoring = case['document'], case['canonical']
        new = policy('selected-only')
        self.new, self.new_authoring = new['document'], new['canonical']
        self.store = ScenarioStore(self.root, profile_revision=lambda p:self.repo.get_state(p)['revision'], profile_state=self.repo.get_state, id_factory=lambda:'c'*32)

    def save(self, document=None, authoring=None, revision=0, key='save'):
        return self.repo.save_plan(self.pid, document or self.old, revision, key, authoring if authoring is not None else self.authoring)

    def prepare_replace(self):
        self.save()
        self.store.create(self.pid, 0, 'scenario', 'Existing', '', 1, {**self.old, 'kind':'scenario'})

    def replace(self, repo=None):
        return (repo or self.repo).replace_plan(self.pid, self.new, 1, 1, 'replace', 'Archive', '', self.new_authoring)

    def paths(self):
        return [self.repo._profile_path(self.pid), self.repo.catalog_path, self.store._path(self.pid)]

    def snapshot(self):
        return [p.read_bytes() if p.exists() else None for p in self.paths()]

    def restore(self, images):
        for path, image in zip(self.paths(), images):
            if image is None: path.unlink(missing_ok=True)
            else: path.write_bytes(image)

    def assert_after(self):
        fresh = JsonRepository(self.root)
        result = fresh.get_plan(self.pid)
        self.assertEqual((result['revision'], result['document'], result['authoring']), (2, self.new, self.new_authoring))
        self.assertEqual(fresh.get_state(self.pid)['goals'], goals_from_document(self.new))
        self.assertEqual(fresh.list_profiles()['profiles'][0]['revision'], 2)
        archived = self.store.get(self.pid, 'b'*24)['scenario']
        self.assertEqual(archived['authoring'], self.authoring)
        self.assertEqual(archived['document'], {**self.old, 'kind':'scenario', 'document_id':'b'*24})
        listed = self.store.list(self.pid)
        self.assertEqual((listed['revision'], len(listed['scenarios'])), (2,2))
        self.assertFalse((self.root / JOURNAL).exists())

    def test_legacy_absence_and_first_get_does_not_write_authoring(self):
        path = self.repo._profile_path(self.pid)
        raw = json.loads(path.read_text(encoding='utf-8'))
        raw.pop('plan')
        path.write_text(json.dumps(raw), encoding='utf-8')
        first = self.repo.get_plan(self.pid)
        self.assertEqual(first['revision'], 1)
        self.assertNotIn('authoring', first)
        before = self.snapshot()
        self.assertEqual(JsonRepository(self.root).get_plan(self.pid), first)
        self.assertEqual(self.snapshot(), before)
        self.assertNotIn('plan_authoring', json.loads(path.read_text(encoding='utf-8')))

    def test_save_restart_deferred_exclusion_and_source_targets(self):
        self.save()
        result = JsonRepository(self.root).get_plan(self.pid)
        self.assertEqual(result['document'], self.old)
        self.assertEqual(result['authoring'], self.authoring)
        state = self.repo.get_state(self.pid)
        self.assertEqual(state['goals'], goals_from_document(self.old))
        self.assertEqual([g['student_id'] for g in state['goals']['goals']], ['aru','ayane'])
        self.assertEqual(result['calculation'], safe_calculation_summary(self.old, self.repo._profile(self.pid)))
        self.assertEqual(result['authoring']['deferred_stages'][0]['targets']['bond_rank'],50)
        self.assertIsNone(result['document']['phases'][1]['stages'][0]['targets']['bond_rank'])

    def test_all_deferred_has_empty_goals_and_calculation_and_archives(self):
        case = policy('all-deferred')
        self.save(case['document'], case['canonical'])
        self.assertEqual(self.repo.get_state(self.pid)['goals']['goals'], [])
        self.assertEqual(self.repo.get_plan(self.pid)['calculation']['credits'], 0)
        replaced = self.repo.replace_plan(self.pid, self.new, 1, 0, 'replace', 'Later', '')
        self.assertEqual(replaced['scenario_revision'],1)
        self.assertIsNotNone(replaced['archived_scenario_id'])
        archived = self.store.get(self.pid, replaced['archived_scenario_id'])['scenario']
        self.assertEqual(archived['authoring'],case['canonical'])
        self.assertEqual(archived['document']['phases'],[])
        self.assertNotIn('authoring', self.repo.get_plan(self.pid))

    def test_selected_only_archives_but_completely_empty_does_not(self):
        self.save(self.new,self.new_authoring)
        first = self.repo.replace_plan(self.pid,self.new,1,0,'first','Selected','')
        self.assertIsNotNone(first['archived_scenario_id'])
        second = self.repo.replace_plan(self.pid,self.new,2,1,'second','Empty','',default_authoring(self.new))
        self.assertIsNone(second['archived_scenario_id'])
        self.assertEqual(second['scenario_revision'],1)

    def test_save_omission_preserves_or_requires_explicit_authoring_and_default_clears(self):
        self.save()
        changed = copy.deepcopy(self.old)
        changed['name'] = 'Rename'
        self.repo.save_plan(self.pid,changed,1,'preserve')
        self.assertEqual(self.repo.get_plan(self.pid)['authoring'],self.authoring)
        before = self.snapshot()
        with self.assertRaises(RepositoryError) as caught:
            self.repo.save_plan(self.pid,self.new,2,'incompatible')
        self.assertEqual(caught.exception.details['reason'],'authoring_required')
        self.assertEqual(before,self.snapshot())
        self.repo.save_plan(self.pid,changed,2,'clear',default_authoring(changed))
        self.assertEqual(self.repo.get_plan(self.pid)['authoring'],default_authoring(changed))
        with self.assertRaises(RepositoryError): self.repo.save_plan(self.pid,changed,3,'null',None)

    def test_metadata_only_revision_and_fingerprint_conflict_replay(self):
        self.save()
        changed = copy.deepcopy(self.authoring)
        changed['goal_metadata']['unknown-selected']['notes'] = 'changed only metadata'
        response = self.repo.save_plan(self.pid,self.old,1,'metadata',changed)
        self.assertEqual(response,{'revision':2})
        self.assertEqual(self.repo.get_state(self.pid)['goals'],goals_from_document(self.old))
        self.assertEqual(self.repo.list_profiles()['profiles'][0]['revision'],2)
        self.assertEqual(self.repo.save_plan(self.pid,self.old,1,'metadata',changed),response)
        with self.assertRaises(RepositoryError) as caught:
            self.repo.save_plan(self.pid,self.old,1,'metadata',self.authoring)
        self.assertEqual(caught.exception.code,'idempotency_conflict')

    def test_omitted_old_fingerprint_and_cached_replay_precedes_compatibility(self):
        self.repo.save_plan(self.pid,self.old,0,'old-no-authoring')
        expected = hashlib.sha256(canonical_json({'operation':f'plan:{canonical_json(self.old)}','expected_revision':0}).encode()).hexdigest()
        self.assertEqual(self.repo._profile(self.pid)['idempotency']['old-no-authoring']['fingerprint'],expected)
        self.repo.save_plan(self.pid,self.new,1,'different-bundle',self.new_authoring)
        before = self.snapshot()
        self.assertEqual(self.repo.save_plan(self.pid,self.old,0,'old-no-authoring'),{'revision':1})
        self.assertEqual(self.snapshot(),before)

    def test_legacy_goals_loss_reason_and_explicit_default_safe_write(self):
        doc = document_from_goals({'version':1,'goals':[{'student_id':'aru','target_level':10}]})
        meta = default_authoring(doc)
        meta['student_order'].append('selected')
        meta['stage_order_by_student']['selected'] = []
        meta['goal_metadata']['selected'] = {'favorite':False,'notes':''}
        self.save(doc,meta)
        with self.assertRaises(RepositoryError) as caught:
            self.repo.save_goals(self.pid,goals_from_document(doc),1,'legacy')
        self.assertEqual(caught.exception.code,'plan_lossy_write')
        self.assertEqual(caught.exception.details['reasons'],['authoring_metadata'])
        self.repo.save_plan(self.pid,doc,1,'clear',default_authoring(doc))
        self.repo.save_goals(self.pid,{'version':1,'goals':[]},2,'safe')
        self.assertEqual(self.repo.get_plan(self.pid)['authoring'],default_authoring(self.new))

    def test_corrupt_stored_authoring_is_not_defaulted(self):
        self.save()
        path = self.repo._profile_path(self.pid)
        original = path.read_bytes()
        for value, code in [(None,'corrupt_data'), ({**self.authoring,'version':2},'migration_required'), ({**self.authoring,'student_order':[]},'corrupt_data')]:
            raw = json.loads(original)
            raw['plan_authoring'] = value
            path.write_text(json.dumps(raw),encoding='utf-8')
            before = path.read_bytes()
            with self.subTest(code=code), self.assertRaises(RepositoryError) as caught:
                self.repo.get_plan(self.pid)
            self.assertEqual(caught.exception.code,code)
            self.assertEqual(path.read_bytes(),before)
        path.write_bytes(original)

    def test_replace_full_bundle_and_replay_after_later_metadata_change(self):
        self.prepare_replace()
        response = self.replace()
        self.assert_after()
        self.repo.save_plan(self.pid,self.new,2,'later',default_authoring(self.new))
        before = self.snapshot()
        self.assertEqual(self.replace(),response)
        self.assertEqual(before,self.snapshot())

    def test_omitted_replace_fingerprint_and_cache_remain_unchanged(self):
        self.repo.save_plan(self.pid,self.old,0,'save-bare')
        response = self.repo.replace_plan(self.pid,self.new,1,0,'replace-bare','Archive','')
        operation = {'type':'replace','document':self.new,'archive_name':'Archive','archive_description':'',
                     'expected_revision':1,'expected_scenario_revision':0}
        expected = hashlib.sha256(canonical_json(operation).encode()).hexdigest()
        self.assertEqual(self.repo._profile(self.pid)['idempotency']['replace-bare']['fingerprint'],expected)
        self.repo.save_plan(self.pid,self.new,2,'later-authoring',self.new_authoring)
        before = self.snapshot()
        self.assertEqual(self.repo.replace_plan(self.pid,self.new,1,0,'replace-bare','Archive',''),response)
        self.assertEqual(self.snapshot(),before)

    def test_other_profile_writers_preserve_authoring_and_presets_revision_is_independent(self):
        self.save()
        presets = PresetStore(self.repo)
        self.assertEqual(presets.save(self.pid,0,'presets',[],[]),{'revision':1})
        self.assertEqual(self.repo.get_plan(self.pid)['revision'],1)
        self.repo.update_students(self.pid,[],1,'students')
        self.repo.update_inventory(self.pid,{'version':1,'entries':[]},2,'inventory')
        self.repo.rename_profile(self.pid,'Renamed',3,'rename')
        self.repo.select_profile(self.pid,4,'select')
        self.assertEqual(self.repo.get_plan(self.pid)['authoring'],self.authoring)
        self.assertEqual(presets.get(self.pid)['revision'],1)

    def test_preserved_scenario_get_duplicate_and_legacy_update_guard(self):
        self.prepare_replace(); self.replace()
        self.store._id_factory = lambda:'d'*32
        copied = self.store.duplicate(self.pid,'b'*24,2,0,'copy')
        record = self.store.get(self.pid,copied['scenario_id'])['scenario']
        self.assertEqual(record['authoring'],self.authoring)
        self.store.update(self.pid,'b'*24,3,0,'rename','Renamed','',2,{**self.old,'kind':'scenario','document_id':'b'*24})
        self.assertEqual(self.store.get(self.pid,'b'*24)['scenario']['authoring'],self.authoring)
        with self.assertRaises(ScenarioStoreError) as caught:
            self.store.update(self.pid,'b'*24,4,1,'bad-update','Bad','',2,{**self.new,'kind':'scenario'})
        self.assertEqual(caught.exception.details['reason'],'authoring_required')

    def test_exceptions_between_every_replace_write_restore_whole_bundle(self):
        self.prepare_replace()
        before = self.snapshot()
        for stage in ['before_journal','journal_prepared','profile_written','catalog_written','scenarios_written','before_commit','journal_committed','journal_removed']:
            with self.subTest(stage=stage):
                self.restore(before)
                def fault(point):
                    if point == stage: raise OSError(stage)
                with self.assertRaises(RepositoryError): self.replace(JsonRepository(self.root,id_factory=lambda:'b'*32,fault=fault))
                if stage in ('journal_committed','journal_removed'): self.assert_after()
                else: self.assertEqual(before,self.snapshot())

    def test_atomic_file_failures_and_save_rollback_include_authoring(self):
        self.prepare_replace(); before = self.snapshot()
        for stage in ('before_write','before_fsync','before_replace'):
            for number in (1,2,3):
                with self.subTest(stage=stage,number=number):
                    self.restore(before)
                    count = 0
                    def fault(point):
                        nonlocal count
                        if point == stage:
                            count += 1
                            if count == number: raise OSError(stage)
                    with self.assertRaises(RepositoryError): self.replace(JsonRepository(self.root,id_factory=lambda:'b'*32,fault=fault))
                    self.assertEqual(before,self.snapshot())
        changed = copy.deepcopy(self.authoring)
        changed['goal_metadata']['unknown-selected']['notes'] = 'failure'
        def fail(point):
            if point == 'before_replace': raise OSError(point)
        with self.assertRaises(RepositoryError):
            JsonRepository(self.root,fault=fail).save_plan(self.pid,self.old,1,'save-fail',changed)
        self.assertEqual(before,self.snapshot())

    def crash(self, point):
        child = subprocess.run([sys.executable,'-X','utf8','-c',CHILD,str(self.root),self.pid,json.dumps(self.new),json.dumps(self.new_authoring),point],cwd=ROOT/'backend',capture_output=True,timeout=15)
        self.assertEqual(child.returncode,73,child.stderr.decode(errors='replace'))

    def test_process_exit_each_boundary_and_replay_once(self):
        self.prepare_replace(); before = self.snapshot()
        for stage in ['before_journal','journal_prepared','profile_written','catalog_written','scenarios_written','before_commit','journal_committed','journal_removed']:
            with self.subTest(stage=stage):
                self.restore(before); self.crash(stage)
                JsonRepository(self.root).get_plan(self.pid)
                if stage in ('journal_committed','journal_removed'): self.assert_after()
                else: self.assertEqual(before,self.snapshot())
                self.replace(); self.assert_after()

    def test_all_related_readers_recover_metadata_before_returning(self):
        self.prepare_replace(); before = self.snapshot()
        readers = [lambda:self.repo.get_plan(self.pid),lambda:self.repo.get_state(self.pid),lambda:self.store.list(self.pid),lambda:self.store.get(self.pid,'c'*24)]
        for reader in readers:
            for stage in ('catalog_written','journal_committed'):
                with self.subTest(reader=reader,stage=stage):
                    self.restore(before); self.crash(stage); reader()
                    if stage == 'journal_committed': self.assert_after()
                    else: self.assertEqual(before,self.snapshot())

    def test_interrupted_journal_recovery_is_repeatable_with_sidecars(self):
        self.prepare_replace(); before = self.snapshot(); self.crash('catalog_written')
        from core import repository_transaction
        write = repository_transaction._write_bytes
        count = 0
        def fail(path, content):
            nonlocal count
            count += 1
            if count == 2: raise OSError('interrupted recovery')
            return write(path,content)
        with patch.object(repository_transaction,'_write_bytes',side_effect=fail), self.assertRaises(RepositoryError): self.repo.get_plan(self.pid)
        self.assertTrue((self.root/JOURNAL).exists())
        self.repo.get_state(self.pid)
        self.assertEqual(before,self.snapshot())


if __name__ == '__main__': unittest.main()
