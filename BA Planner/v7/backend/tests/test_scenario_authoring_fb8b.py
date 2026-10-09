from __future__ import annotations

from copy import deepcopy
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from core.planning_authoring import AUTHORING_UNSET, default_authoring
from core.repository_dto import canonical_json
from core.repository_store import JsonRepository
from core.scenario_protocol_v1 import ScenarioProtocolV1
from core.scenario_store import ScenarioStore, ScenarioStoreError
from tests.test_planning_authoring_fb8a import POLICIES, policy
from tests.test_scenario_store import document as legacy_document

ROOT = Path(__file__).parents[2]


def bundle(name='deferred-targets-selected-order'):
    case = policy(name)
    return {**case['document'], 'kind': 'scenario'}, case['canonical']


class ScenarioAuthoringTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = JsonRepository(self.root, id_factory=lambda: 'a'*32)
        self.pid = self.repo.create_profile('Authoring', 'profile')['profile']['profile_id']
        self.ids = itertools.count(1)
        self.store = self.restart()
        self.doc, self.auth = bundle()

    def restart(self, fault=None):
        return ScenarioStore(self.root, profile_revision=lambda pid: self.repo.get_state(pid)['revision'],
            id_factory=lambda: f'{next(self.ids):024x}' + '0'*8, clock=lambda: '2026-10-09T00:00:00Z', fault=fault)

    def create(self, authoring=AUTHORING_UNSET, doc=None, key='create', revision=0):
        return self.store.create(self.pid, revision, key, 'Candidate', '', 0, doc or self.doc, authoring)

    def update(self, created, revision, record_revision, key, doc=None, authoring=AUTHORING_UNSET):
        return self.store.update(self.pid, created['scenario_id'], revision, record_revision, key,
            'Candidate', '', 0, doc or self.doc, authoring)

    def record(self, result):
        return self.store.get(self.pid, result['scenario_id'])['scenario']

    def test_create_update_metadata_only_duplicate_restart_and_profile_isolation(self):
        profile = self.repo._profile_path(self.pid).read_bytes()
        created = self.create(self.auth)
        self.assertEqual(self.record(created)['authoring'], self.auth)
        changed = deepcopy(self.auth)
        changed['student_order'].reverse()
        changed['goal_metadata']['unknown-selected']['notes'] = 'metadata only\n'
        updated = self.update(created, 1, 0, 'metadata', authoring=changed)
        self.assertEqual(updated['revision'], 2)
        self.assertEqual(self.record(created)['revision'], 1)
        self.assertEqual(self.record(created)['document'], self.doc)
        copied = self.store.duplicate(self.pid, created['scenario_id'], 2, 1, 'copy')
        self.store = self.restart()
        self.assertEqual(self.record(copied)['authoring'], changed)
        self.assertEqual(self.record(copied)['document']['phases'], self.doc['phases'])
        self.assertEqual(self.record(copied)['document']['document_id'], copied['scenario_id'])
        self.assertEqual(self.record(copied)['revision'], 0)
        self.assertEqual(self.store.duplicate(self.pid, created['scenario_id'], 2, 1, 'copy'), copied)
        self.assertEqual(len(self.store.list(self.pid)['scenarios']), 2)
        # Replacing copy metadata cannot alter the source.
        self.update(copied, 3, 0, 'copy-clear', authoring=default_authoring(self.record(copied)['document']),
                    doc=self.record(copied)['document'])
        self.assertEqual(self.record(created)['authoring'], changed)
        self.assertEqual(self.repo._profile_path(self.pid).read_bytes(), profile)

    def test_omission_preserves_and_incompatible_document_requires_explicit_replacement(self):
        created = self.create(self.auth)
        self.update(created, 1, 0, 'preserve')
        self.assertEqual(self.record(created)['authoring'], self.auth)
        empty, empty_auth = bundle('empty-default')
        before = self.store._path(self.pid).read_bytes()
        with self.assertRaises(ScenarioStoreError) as caught:
            self.update(created, 2, 1, 'bad-omission', doc=empty)
        self.assertEqual(caught.exception.code, 'invalid_payload')
        self.assertEqual(caught.exception.details['reason'], 'authoring_required')
        self.assertIn('authoring_reason', caught.exception.details)
        self.assertEqual(self.store._path(self.pid).read_bytes(), before)
        self.update(created, 2, 1, 'explicit', doc=empty, authoring=empty_auth)
        self.assertEqual(self.record(created)['authoring'], empty_auth)

    def test_cached_omission_checked_before_current_metadata_compatibility(self):
        empty, auth = bundle('empty-default')
        created = self.create(doc=empty)
        first = self.update(created, 1, 0, 'old-update', doc=empty)
        self.update(created, 2, 1, 'new-bundle', authoring=self.auth)
        self.store = self.restart()
        self.assertEqual(self.update(created, 1, 0, 'old-update', doc=empty), first)
        self.assertEqual(self.record(created)['authoring'], self.auth)
        self.assertEqual(self.store.list(self.pid)['revision'], 3)

    def test_explicit_null_cannot_clear_and_default_object_can(self):
        with self.assertRaises(ScenarioStoreError) as caught:
            self.create(None)
        self.assertEqual(caught.exception.details['reason'], 'invalid_shape')
        created = self.create(self.auth)
        with self.assertRaises(ScenarioStoreError):
            self.update(created, 1, 0, 'null', authoring=None)
        self.update(created, 1, 0, 'clear', authoring=default_authoring(self.doc))
        self.assertEqual(self.record(created)['authoring'], default_authoring(self.doc))

    def test_metadata_in_fingerprint_and_first_response_survives_later_writes_and_delete(self):
        created = self.create(self.auth)
        self.assertEqual(self.create(deepcopy(self.auth)), created)
        reordered = deepcopy(self.auth); reordered['prerequisites'].reverse()
        self.assertEqual(self.create(reordered), created)
        changed = deepcopy(self.auth); changed['student_order'].reverse()
        with self.assertRaises(ScenarioStoreError) as caught:
            self.create(changed)
        self.assertEqual(caught.exception.code, 'idempotency_conflict')
        first = self.update(created, 1, 0, 'meta', authoring=changed)
        self.store.delete(self.pid, created['scenario_id'], 2, 1, 'delete')
        self.store = self.restart()
        self.assertEqual(self.create(self.auth), created)
        self.assertEqual(self.update(created, 1, 0, 'meta', authoring=changed), first)
        self.assertEqual(self.store.list(self.pid)['revision'], 3)
        self.assertEqual(self.store.list(self.pid)['scenarios'], [])

    def test_legacy_v1_v2_bytes_and_fingerprints_unchanged(self):
        for index, doc in enumerate([legacy_document('v1'), self.doc]):
            revision = index * 2
            key = f'old-{index}'
            created = self.create(doc=doc, key=key, revision=revision)
            record = self.record(created)
            self.assertNotIn('authoring', record)
            self.assertEqual(record['document'], doc)
            first = self.update(created, revision+1, 0, key+'-update', doc=doc)
            collection = json.loads(self.store._path(self.pid).read_text(encoding='utf-8'))
            for kind, expected, cache_key in [('create', revision, key), ('update',revision+1,key+'-update')]:
                operation = dict(type=kind,name='Candidate',description='',base_profile_revision=0,document=doc)
                if kind=='update': operation.update(scenario_id=created['scenario_id'],expected_scenario_revision=0)
                old = hashlib.sha256(canonical_json({'operation':operation,'expected_revision':expected}).encode()).hexdigest()
                self.assertEqual(collection['idempotency'][cache_key]['fingerprint'],old)
            before = self.store._path(self.pid).read_bytes()
            self.store = self.restart()
            self.store.get(self.pid,created['scenario_id']); self.store.list(self.pid)
            self.assertEqual(self.store._path(self.pid).read_bytes(),before)
            self.assertEqual(self.update(created,revision+1,0,key+'-update',doc=doc),first)

    def test_all_shared_policy_fixtures_through_scenario_store(self):
        revision = 0
        for case in POLICIES:
            with self.subTest(case=case['name']):
                doc = {**deepcopy(case['document']), 'kind':'scenario'}
                if case['valid']:
                    result = self.create(case['authoring'],doc=doc,key=case['name'],revision=revision)
                    self.assertEqual(self.record(result)['authoring'],case['canonical'])
                    revision += 1
                else:
                    with self.assertRaises(ScenarioStoreError) as caught:
                        self.create(case['authoring'],doc=doc,key=case['name'],revision=revision)
                    self.assertEqual(caught.exception.code,'invalid_payload')
                    self.assertEqual(caught.exception.details['reason'],case['reason'])

    def test_deferred_only_selected_only_counts_and_calculation_are_empty(self):
        for i, name in enumerate(['all-deferred','selected-only']):
            doc, auth = bundle(name)
            self.create(auth, doc=doc, key=name, revision=i)
        for summary in self.store.list(self.pid)['scenarios']:
            self.assertEqual((summary['phase_count'],summary['stage_count'],summary['student_count']),(0,0,0))
            self.assertEqual(summary['student_ids'],[])
            # Without a state callback summaries may be null; actual calculation
            # exclusion is verified through the process compare E2E.

    def test_exception_during_metadata_save_leaves_complete_old_bundle_and_cache(self):
        created = self.create(self.auth)
        before = self.store._path(self.pid).read_bytes()
        for point in ['before_write','before_fsync','before_replace']:
            with self.subTest(point=point):
                def fault(stage):
                    if stage==point: raise OSError('injected')
                self.store = self.restart(fault)
                changed = deepcopy(self.auth); changed['student_order'].reverse()
                with self.assertRaises(ScenarioStoreError) as caught:
                    self.update(created,1,0,'failure',authoring=changed)
                self.assertEqual(caught.exception.code,'persistence_failed')
                self.assertEqual(self.store._path(self.pid).read_bytes(),before)
                self.store = self.restart()
                self.assertEqual(self.record(created)['authoring'],self.auth)
        self.assertEqual(self.update(created,1,0,'failure',authoring=changed)['revision'],2)

    def test_process_exit_before_atomic_replace_and_restart_replay(self):
        created = self.create(self.auth)
        before = self.store._path(self.pid).read_bytes()
        changed = deepcopy(self.auth); changed['student_order'].reverse()
        child = '''
import json, os, sys
from pathlib import Path
from core.scenario_store import ScenarioStore
root,pid,sid,doc,auth,point=sys.argv[1:]
def fault(stage):
    if stage==point: os._exit(73)
ScenarioStore(Path(root),profile_revision=lambda _:0,fault=fault).update(pid,sid,1,0,'crash','Candidate','',0,json.loads(doc),json.loads(auth))
'''
        for point in ['before_write','before_fsync','before_replace']:
            result = subprocess.run([sys.executable,'-X','utf8','-c',child,str(self.root),self.pid,
                created['scenario_id'],json.dumps(self.doc),json.dumps(changed),point],cwd=ROOT/'backend',capture_output=True)
            self.assertEqual(result.returncode,73,result.stderr.decode())
            self.store = self.restart()
            self.assertEqual(self.store._path(self.pid).read_bytes(),before)
            self.assertEqual(self.record(created)['authoring'],self.auth)
        response = self.update(created,1,0,'crash',authoring=changed)
        self.store = self.restart()
        self.assertEqual(self.record(created)['authoring'],changed)
        self.assertEqual(self.update(created,1,0,'crash',authoring=changed),response)


class ScenarioAuthoringContractTests(unittest.TestCase):
    def test_schema_and_protocol_fixture(self):
        schemas = [json.loads(p.read_text(encoding='utf-8')) for p in (ROOT/'contracts').glob('*.schema.json')]
        registry = Registry().with_resources((s['$id'],Resource.from_contents(s)) for s in schemas)
        validator = Draft202012Validator(next(s for s in schemas if s['$id'].endswith('/scenario-protocol-v1.schema.json')),registry=registry)
        fixture = json.loads((ROOT/'contracts/fixtures/scenario_authoring_v1.json').read_text(encoding='utf-8'))
        for case in fixture['cases']:
            with self.subTest(case=case['id']):
                self.assertEqual(validator.is_valid(case['message']),case['valid'])
        with tempfile.TemporaryDirectory() as temporary:
            protocol = ScenarioProtocolV1(ScenarioStore(Path(temporary),profile_revision=lambda _:0,id_factory=lambda:'b'*32))
            create = deepcopy(next(c['message'] for c in fixture['cases'] if c['id']=='create-authoring'))
            self.assertEqual(protocol.handle(create)['payload'],{'revision':1,'scenario_id':'b'*24})
            update = deepcopy(next(c['message'] for c in fixture['cases'] if c['id']=='update-authoring'))
            self.assertEqual(protocol.handle(update)['payload'],{'revision':2,'scenario_id':'b'*24})
            null = deepcopy(update); null['payload']['authoring']=None
            error = protocol.handle(null)['payload']['error']
            self.assertEqual((error['code'],error['details']['reason']),('invalid_payload','invalid_shape'))


if __name__ == '__main__':
    unittest.main()
