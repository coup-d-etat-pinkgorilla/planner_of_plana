from copy import deepcopy
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from core.current_history import HistoryError
from core.inventory_review import from_wire, keys_from_wire
from core.repository_protocol_v1 import RepositoryProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.scan_commit_history_context import ScanCommitHistoryContext

ROOT = Path(__file__).resolve().parents[2]
A = 'Item_Icon_SkillBook_Abydos_0'
B = 'Item_Icon_SkillBook_Abydos_1'
C = 'Item_Icon_SkillBook_Abydos_2'
AT = datetime(2026, 10, 12, 0, 0, tzinfo=timezone.utc)


def snapshot(a='3', b='9'):
    return {'version': 1, 'entries': [{'key': A, 'item_id': A, 'quantity': a},
                                    {'key': B, 'item_id': B, 'quantity': b},
                                    {'key': C, 'item_id': C, 'quantity': '7'}]}


def context(applied=(A,), excluded=(B,)):
    return ScanCommitHistoryContext.from_wire({
        'source': 'scan', 'session_id': 'review-scan', 'generation': 1,
        'candidate_id': 'review-candidate', 'candidate_revision': 1,
        'scan_kind': 'inventory', 'inventory_scan_profile': 'bd',
        'applied_keys': list(applied), 'excluded_keys': list(excluded), 'retry_of': None,
    }, bucket='inventory')


class InventoryReviewFB10bTests(unittest.TestCase):
    def repository(self):
        tmp = tempfile.TemporaryDirectory(); self.addCleanup(tmp.cleanup)
        repo = JsonRepository(Path(tmp.name), clock=lambda: AT)
        pid = repo.create_profile('Review fixture', 'review-profile')['profile']['profile_id']
        repo.update_inventory(pid, snapshot(), 0, 'seed', manual=True)
        return repo, pid

    def seed_flag(self, repo, pid, *, both=False):
        repo.update_inventory(pid, snapshot(), 1, 'flag', history_context=context())
        if both:
            repo.update_inventory(pid, snapshot(), 2, 'flag-a', history_context=context((C,), (A, B)))

    def bytes(self, repo, pid):
        return repo._profile_path(pid).read_bytes(), repo.catalog_path.read_bytes()

    def test_partial_scan_is_durable_without_quantity_or_state_dto_changes(self):
        repo, pid = self.repository()
        repo.update_inventory(pid, snapshot('5'), 1, 'scan', history_context=context())
        result = JsonRepository(repo.root).get_inventory_review(pid)
        self.assertEqual(result, {'version': 1, 'profile_id': pid, 'revision': 2, 'needs_review_keys': [B]})
        result['needs_review_keys'].clear()
        before = self.bytes(repo, pid)
        self.assertEqual(JsonRepository(repo.root).get_inventory_review(pid)['needs_review_keys'], [B])
        self.assertEqual(self.bytes(repo, pid), before)
        state = repo.get_state(pid)
        self.assertEqual(set(state), {'profile_id', 'revision', 'students', 'inventory', 'goals'})
        self.assertEqual({e['key']: e['quantity'] for e in state['inventory']['entries']}, {A:'5', B:'9', C:'7'})
        latest = repo._profile(pid)['current_history']['latest_scans']
        keys = {row['resource_key'] for row in latest['by_resource_key']}
        self.assertIn(A, keys); self.assertNotIn(B, keys)

    def test_explicit_unchanged_manual_acknowledgement_clears_only_that_key(self):
        repo, pid = self.repository(); self.seed_flag(repo, pid, both=True)
        latest = deepcopy(repo._profile(pid)['current_history']['latest_scans'])
        repo.update_inventory(pid, snapshot(), 3, 'ack', manual=True, applied_resource_keys=[A])
        self.assertEqual(repo.get_inventory_review(pid)['needs_review_keys'], [B])
        self.assertEqual(repo._profile(pid)['current_history']['latest_scans'], latest)
        self.assertEqual(repo._profile(pid)['current_history']['events'][-1]['source'], 'manual')

    def test_legacy_full_snapshot_clears_actual_changes_preserves_unchanged_flags(self):
        repo, pid = self.repository(); self.seed_flag(repo, pid, both=True)
        repo.update_inventory(pid, snapshot('4'), 3, 'legacy', manual=True)
        self.assertEqual(repo.get_inventory_review(pid)['needs_review_keys'], [B])

    def test_replay_original_scope_and_revision_survives_restart_other_scope_conflicts(self):
        repo, pid = self.repository(); self.seed_flag(repo, pid, both=True)
        response = repo.update_inventory(pid, snapshot(), 3, 'ack', manual=True, applied_resource_keys=[B])
        restarted = JsonRepository(repo.root); before = self.bytes(repo, pid)
        self.assertEqual(restarted.update_inventory(pid, snapshot(), 3, 'ack', manual=True, applied_resource_keys=[B]), response)
        self.assertEqual(self.bytes(repo, pid), before)
        for revision, scope in ((3, [A]), (4, [B])):
            with self.assertRaises(RepositoryError) as caught:
                restarted.update_inventory(pid, snapshot(), revision, 'ack', manual=True, applied_resource_keys=scope)
            self.assertEqual(caught.exception.code, 'idempotency_conflict')
        self.assertEqual(self.bytes(repo, pid), before)

    def test_changed_quantity_outside_manual_scope_is_rejected_without_writes(self):
        repo, pid = self.repository(); self.seed_flag(repo, pid)
        before = self.bytes(repo, pid)
        with self.assertRaises(RepositoryError) as caught:
            repo.update_inventory(pid, snapshot(b='10'), 2, 'wrong', manual=True, applied_resource_keys=[A])
        self.assertEqual(caught.exception.details, {'reason':'scan_scope_mismatch'})
        self.assertEqual(self.bytes(repo, pid), before)

    def test_scan_cannot_change_excluded_quantity_or_install_a_fake_unresolved_quantity(self):
        repo, pid = self.repository(); before = self.bytes(repo, pid)
        with self.assertRaises(RepositoryError) as caught:
            repo.update_inventory(pid, snapshot(b='10'), 1, 'wrong-scan', history_context=context())
        self.assertEqual(caught.exception.details, {'reason':'scan_scope_mismatch'})
        self.assertEqual(self.bytes(repo, pid), before)
        repo.update_inventory(pid, snapshot(), 1, 'identified-absent', history_context=context((A,), ('identified-absent',)))
        self.assertEqual(repo.get_inventory_review(pid)['needs_review_keys'], ['identified-absent'])
        self.assertEqual({e['key'] for e in repo.get_state(pid)['inventory']['entries']}, {A, B, C})

    def test_empty_applied_scope_does_not_commit_or_write_flags(self):
        repo, pid = self.repository(); before = self.bytes(repo, pid)
        with self.assertRaises(HistoryError):
            context((), (A, B))
        self.assertEqual(self.bytes(repo, pid), before)

    def test_other_buckets_and_unattributed_writes_do_not_clear_flags(self):
        repo, pid = self.repository(); self.seed_flag(repo, pid)
        repo.update_students(pid, [], 2, 'students', manual=True)
        repo.update_inventory(pid, snapshot(b='10'), 3, 'unattributed')
        self.assertEqual(repo.get_inventory_review(pid)['needs_review_keys'], [B])

    def test_sparse_legacy_read_neither_migrates_plan_nor_adds_private_field(self):
        repo, pid = self.repository()
        raw = json.loads(repo._profile_path(pid).read_text(encoding='utf-8'))
        raw.pop('plan'); repo._profile_path(pid).write_text(json.dumps(raw), encoding='utf-8')
        before = self.bytes(repo, pid)
        self.assertEqual(repo.get_inventory_review(pid)['needs_review_keys'], [])
        self.assertEqual(repo.get_inventory_review(pid)['revision'], 1)
        self.assertEqual(self.bytes(repo, pid), before)

    def test_corrupt_private_metadata_is_not_downgraded_to_false_flags(self):
        for metadata, code in (({'version':True,'needs_review_keys':[]},'corrupt_data'),
                               ({'version':2,'needs_review_keys':[]},'migration_required'),
                               ({'version':1,'needs_review_keys':[B,A]},'corrupt_data'),
                               ({'version':1,'needs_review_keys':[A,A]},'corrupt_data')):
            with self.subTest(metadata=metadata):
                repo,pid=self.repository(); raw=json.loads(repo._profile_path(pid).read_text(encoding='utf-8'))
                raw['inventory_review']=metadata;repo._profile_path(pid).write_text(json.dumps(raw),encoding='utf-8')
                before=self.bytes(repo,pid)
                with self.assertRaises(RepositoryError) as caught: repo.get_inventory_review(pid)
                self.assertEqual(caught.exception.code,code)
                self.assertEqual(self.bytes(repo,pid),before)

    def test_invalid_scopes_fail_before_write(self):
        repo,pid=self.repository();before=self.bytes(repo,pid)
        for scope in ([A,A], [True], [''], ['x'*1025], ['\ud800'], None):
            request={'protocol':1,'id':'bad','type':'request','method':'repository.inventory.update','payload':{
                'profile_id':pid,'inventory':snapshot(),'expected_revision':1,'idempotency_key':'bad','applied_resource_keys':scope}}
            with self.subTest(scope=repr(scope)):
                self.assertEqual(RepositoryProtocolV1(repo).handle(request)['payload']['error']['code'],'invalid_payload')
                self.assertEqual(self.bytes(repo,pid),before)

    def test_actual_scanner_partial_commit_and_original_receipt_replay(self):
        from test_scanner_commit_history_sfb2b import ScannerCommitHistoryIntegrationTests
        helper=ScannerCommitHistoryIntegrationTests(methodName='runTest')
        helper.setUpClass();self.addCleanup(helper.doCleanups)
        case=next(c for c in helper.fixture['cases'] if c['id']=='inventory_partial_first')
        repo,port,service,request,case=helper.setup_case(case)
        response=service.commit(**request)
        self.assertEqual(repo.get_inventory_review(request['profile_id'])['needs_review_keys'],case['excluded_keys'])
        before=self.bytes(repo,request['profile_id'])
        self.assertEqual(service.commit(**request),response)
        self.assertEqual(self.bytes(repo,request['profile_id']),before)

    def test_actual_process_termination_recovers_quantities_flags_revision_as_one_transaction(self):
        script='''import os,sys
from pathlib import Path
from core.repository_store import JsonRepository
from core.scan_commit_history_context import ScanCommitHistoryContext
import json
repo=JsonRepository(Path(sys.argv[1]),fault=lambda stage: os._exit(73) if stage==sys.argv[3] else None)
repo.update_inventory(sys.argv[2],json.loads(sys.argv[4]),1,'crash',history_context=ScanCommitHistoryContext.from_wire(json.loads(sys.argv[5]),bucket='inventory'))
'''
        for stage,committed in (('journal_prepared',False),('profile_written',False),('catalog_written',False),('journal_committed',True)):
            with self.subTest(stage=stage):
                repo,pid=self.repository();before=self.bytes(repo,pid)
                proc=subprocess.run([sys.executable,'-c',script,str(repo.root),pid,stage,json.dumps(snapshot('5')),json.dumps(context().to_wire())],cwd=ROOT/'backend',capture_output=True,timeout=30)
                self.assertEqual(proc.returncode,73,proc.stderr.decode('utf-8','replace'))
                restart=JsonRepository(repo.root)
                result=restart.get_inventory_review(pid)
                self.assertEqual((result['revision'],result['needs_review_keys']),(2,[B]) if committed else (1,[]))
                self.assertEqual(restart.get_inventory_review(pid),result)
                if committed:
                    self.assertEqual(restart.update_inventory(pid,snapshot('5'),1,'crash',history_context=context()),{'revision':2})
                else:
                    self.assertEqual(self.bytes(repo,pid),before)

    def test_profile_deletion_removes_inline_flags_and_preserves_other_profile(self):
        repo,pid=self.repository();self.seed_flag(repo,pid)
        other=repo.create_profile('Other fixture','other-profile')['profile']['profile_id']
        path=repo._profile_path(other);before=path.read_bytes()
        self.assertEqual(repo.delete_profile(pid,2,'delete'),{'revision':3})
        self.assertFalse(repo._profile_path(pid).exists());self.assertEqual(path.read_bytes(),before)
        with self.assertRaises(RepositoryError) as caught: repo.get_inventory_review(pid)
        self.assertEqual(caught.exception.code,'profile_not_found')

    def test_shared_policy_fixture_and_strict_request_response_schema(self):
        fixture=json.loads((ROOT/'contracts/fixtures/inventory_review_fb10b_v1.json').read_text(encoding='utf-8'))
        schemas=[json.loads(p.read_text(encoding='utf-8')) for p in (ROOT/'contracts').glob('*.schema.json')]
        registry=Registry().with_resources((s['$id'],Resource.from_contents(s)) for s in schemas)
        root=next(s for s in schemas if s['$id'].endswith('/repository-protocol-v1.schema.json'))
        validator=Draft202012Validator(root,registry=registry)
        for case in fixture['messages']:
            self.assertEqual(validator.is_valid(case['message']),case['valid'],case['id'])
        repo,pid=self.repository();self.seed_flag(repo,pid)
        request={'protocol':1,'id':'get','type':'request','method':'repository.inventory.review.get','payload':{'profile_id':pid}}
        response=RepositoryProtocolV1(repo).handle(request)
        validator.validate(request);validator.validate(response)
        self.assertEqual(response['payload']['needs_review_keys'],[B])
        bad=deepcopy(response);bad['payload']['needs_review']=True;self.assertFalse(validator.is_valid(bad))


if __name__=='__main__':
    unittest.main()
