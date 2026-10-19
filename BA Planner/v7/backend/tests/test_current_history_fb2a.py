from copy import deepcopy
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from core.current_history import (
    CurrentHistory, HistoryError, ScanHistoryContext, append_history, apply_event,
    empty_history, history_from_wire, projection, summary, utc_timestamp,
)
from core.repository_dto import canonical_json
from core.repository_protocol_v1 import RepositoryProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.repository_transaction import JOURNAL

ROOT = Path(__file__).parents[2]
AT = datetime(2026, 10, 9, 14, 25, 0, 123456, tzinfo=timezone.utc)
STAMP = utc_timestamp(AT)
STAGES = ('before_journal','journal_prepared','profile_written','catalog_written','before_commit','journal_committed','journal_removed')

def student(values=None):
    return {'version':1,'student_id':'aru','values':values or {}}

def state(students=None, entries=None):
    return projection(students or [], {'version':1,'entries':entries or []})

def scan(scope=None, session='session', kind=' New Kind ', profile=' 未知 profile '):
    return ScanHistoryContext.from_wire({'source':'scan','scan_kind':kind,'inventory_scan_profile':profile,
        'scan_context':{'session_id':session,'generation':1,'candidate_id':'candidate','candidate_revision':0},
        'applied_scope':scope or {'student_ids':['aru'],'resource_keys':[]}})

def write(path, value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value),encoding='utf-8')

def v6_fixture(root):
    write(root/'config.json', {'profiles':[{'key':'profile_deadbeef','name':'Imported'}]})
    current = root/'profiles/profile_deadbeef/data/current'
    write(current/'students.json', {'aru':{'student_id':'aru','level':80,'bond_rank':12}})
    write(current/'inventory.json', {'future':{'item_id':'future','quantity':7}})
    write(current/'growth_plan.json', {'version':1,'goals':[]})

def snapshot(root):
    return {path.relative_to(root).as_posix():path.read_bytes() for path in [root/'catalog.json',*(root/'profiles').glob('*.json')] if path.exists()}

def operation(repo, mode, pid, v6):
    if mode == 'current': return repo.update_students(pid,[student({'level':80})],0,'once',manual=True)
    if mode == 'create': return repo.create_profile('New','new')
    return repo.import_v6_profile(str(v6),'profile_deadbeef')

CHILD = '''
from datetime import datetime,timezone
from pathlib import Path
import os,sys
from core.repository_store import JsonRepository
root,pid,v6,mode,stage=sys.argv[1:]
def fault(point):
    if point==stage: os._exit(73)
repo=JsonRepository(Path(root),id_factory=lambda:'b'*32,fault=fault,clock=lambda:datetime(2026,10,9,14,25,0,123456,tzinfo=timezone.utc))
if mode=='current': repo.update_students(pid,[{'version':1,'student_id':'aru','values':{'level':80}}],0,'once',manual=True)
elif mode=='create': repo.create_profile('New','new')
else: repo.import_v6_profile(v6,'profile_deadbeef')
'''


class CurrentHistoryPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((ROOT/'contracts/fixtures/current_history_v1.json').read_text(encoding='utf-8'))
        schemas = [json.loads(path.read_text(encoding='utf-8')) for path in (ROOT/'contracts').glob('*.schema.json')]
        registry = Registry().with_resources((item['$id'],Resource.from_contents(item)) for item in schemas)
        # JSON Schema format is an annotation; calendar validity is pinned by
        # both runtime validators, independent of optional format packages.
        cls.schema = Draft202012Validator(next(s for s in schemas if s['$id'].endswith('/current-history-v1.schema.json')),registry=registry)
        cls.protocol_schema = Draft202012Validator(next(s for s in schemas if s['$id'].endswith('/repository-protocol-v1.schema.json')),registry=registry)

    def test_shared_schema_python_fixtures_and_detached_dto(self):
        for case in self.fixture['cases']:
            with self.subTest(case=case['id']):
                self.assertEqual(not list(self.schema.iter_errors(case['history'])),case.get('schema_valid',case['valid']))
                if case['valid']:
                    parsed = CurrentHistory.from_wire(case['history'])
                    self.assertEqual(parsed.to_wire(),case['history'])
                    exported = parsed.to_wire(); exported['events'].clear()
                    self.assertEqual(parsed.to_wire(),case['history'])
                else:
                    with self.assertRaises((ValueError,TypeError)):
                        CurrentHistory.from_wire(case['history'])
        for case in self.fixture['messages']:
            with self.subTest(message=case['id']):
                self.assertEqual(not list(self.protocol_schema.iter_errors(case['message'])),case['valid'])

    def test_resource_missing_null_zero_large_values_deletion_and_student_field_presence(self):
        h = self.fixture['cases'][1]['history']
        changes = h['events'][1]['inventory_changes']
        deleted = next(item for item in changes if item['resource_key']=='zero')
        self.assertEqual(deleted['before'],{'present':True,'quantity':'0'})
        self.assertEqual(deleted['after'],{'present':False,'quantity':None})
        unknown = next(item for item in changes if item['resource_key']=='future-present')
        self.assertEqual(unknown['before'],{'present':True,'quantity':None})
        self.assertEqual(unknown['after'],{'present':True,'quantity':'0'})
        s = h['events'][1]['student_changes'][0]
        self.assertIsNone(s['before']['value']['values']['bond_rank'])
        self.assertNotIn('bond_rank',s['after']['value']['values'])
        self.assertEqual(summary('a'*24,4,h),self.fixture['summary'])
        self.assertEqual(summary('a'*24,4,h)['total_scan_session_count'],1)
        self.assertEqual(summary('a'*24,4,h)['total_counts']['scan'],2)

    def test_array_catalog_position_and_name_changes_are_not_economic_diffs(self):
        a = projection([student({'level':0})],{'version':1,'entries':[{'key':'unknown','quantity':None,'index':1,'name':'a'}]})
        b = projection([student({'level':0})],{'version':1,'entries':[{'key':'unknown','quantity':None,'index':99,'name':'b'}]})
        h = append_history(empty_history([student({'level':0})],{'version':1,'entries':[{'key':'unknown','quantity':None}]},legacy=True),a,b,source='manual',recorded_at=STAMP,revision_before=1,revision_after=2,catalog_revision=None)
        self.assertEqual(h['events'][0]['student_changes'],[])
        self.assertEqual(h['events'][0]['inventory_changes'],[])
        alias = projection([],{'version':1,'entries':[{'key':'Item_Icon_SkillBook_Ultimate_Piece','quantity':'1'}]})
        self.assertEqual(alias['inventory'][0]['resource_key'],'Item_Icon_SkillBook_Ultimate')

    def test_provenance_only_and_form_object_changes_are_preserved(self):
        a = student({'form_combat_stats':{'a':{'hp':0}}}); a['provenance']={'level':'scanner'}
        b = deepcopy(a); b['provenance']={'level':'review'}; b['values']['form_combat_stats']={'a':{'hp':None}}
        old,new = state([a]),state([b])
        h = append_history(empty_history([a],legacy=True),old,new,source='manual',recorded_at=STAMP,revision_before=0,revision_after=1,catalog_revision=None)
        self.assertEqual(history_from_wire(h,current=new),h)
        self.assertEqual(h['events'][0]['student_changes'][0]['after']['value'],b)

    def test_prefix_count_age_byte_pruning_keeps_state_indexes_and_lifetime_counts(self):
        current = state([student({'level':0})])
        h = empty_history([student({'level':0})],legacy=True)
        for i in range(4):
            h = append_history(h,current,current,source='scan',recorded_at=utc_timestamp(AT+timedelta(days=i)),revision_before=i,revision_after=i+1,catalog_revision=None,context=scan(session=f'session-{i}'),max_events=2)
        self.assertEqual(h['baseline']['sequence'],2)
        self.assertEqual(h['total_counts']['scan'],4)
        self.assertEqual(len(h['scan_session_ids']),4)
        self.assertEqual(h['latest_scans']['by_student_id'][0]['sequence'],4)
        aged = append_history(h,current,current,source='manual',recorded_at=utc_timestamp(AT+timedelta(days=367)),revision_before=4,revision_after=5,catalog_revision=None)
        self.assertEqual(len(aged['events']),3)  # day 2 is exactly 365 days old
        aged = append_history(aged,current,current,source='manual',recorded_at=utc_timestamp(AT+timedelta(days=368)),revision_before=5,revision_after=6,catalog_revision=None)
        self.assertEqual(len(aged['events']),3)
        self.assertEqual(aged['latest_scans'],h['latest_scans'])
        self.assertFalse(summary('a'*24,6,aged)['coverage']['complete'])
        base = append_history(h,current,current,source='manual',recorded_at=STAMP,revision_before=4,revision_after=5,catalog_revision=None,max_events=1)
        byte_bound = len(canonical_json(base).encode()) + 10
        pruned = append_history(h,current,current,source='manual',recorded_at=STAMP,revision_before=4,revision_after=5,catalog_revision=None,max_bytes=byte_bound)
        self.assertEqual(pruned,base)
        self.assertEqual(history_from_wire(pruned,current=current),pruned)
        with self.assertRaises(HistoryError) as caught:
            append_history(h,current,current,source='manual',recorded_at=STAMP,revision_before=4,revision_after=5,catalog_revision=None,max_bytes=100)
        self.assertEqual(caught.exception.reason,'history_capacity_exceeded')

    def test_raw_scope_validation_and_clock_rollback(self):
        for change in [{'scan_kind':''},{'inventory_scan_profile':'한'*342},{'scan_context':None},{'applied_scope':{'student_ids':[],'resource_keys':[]}}]:
            wire = scan().to_wire(); wire.update(change)
            with self.subTest(change=change), self.assertRaises(HistoryError): ScanHistoryContext.from_wire(wire)
        h = deepcopy(self.fixture['cases'][1]['history'])
        current = state([{'version':1,'student_id':'aru','values':{'level':0,'form_combat_stats':{'normal':{'hp':0}}},'provenance':{'level':'user_review'}}],[{'key':'future-present','quantity':'0'},{'key':'large','quantity':'1000000000000000000000000000000000000'}])
        h = append_history(h,current,current,source='manual',recorded_at=utc_timestamp(AT-timedelta(days=1)),revision_before=4,revision_after=5,catalog_revision=None)
        self.assertFalse(summary('a'*24,5,h)['coverage']['timestamps_monotonic'])
        self.assertEqual(h['events'][-1]['recorded_at'],utc_timestamp(AT-timedelta(days=1)))

    def test_actual_profile_shape_fits_full_apply_and_10000_commits(self):
        fixture = json.loads((ROOT/'backend/tests/fixtures/current_history_profile_shape.json').read_text(encoding='utf-8'))
        self.assertEqual((fixture['student_count'],fixture['inventory_count']),(217,614))
        before = state()
        after = projection(fixture['students'],fixture['inventory'])
        seed = append_history(empty_history(),before,after,source='import',recorded_at=STAMP,revision_before=0,revision_after=0,catalog_revision=None)
        history = deepcopy(seed)
        context = scan({'student_ids':[fixture['students'][0]['student_id']],'resource_keys':[]})
        sample = append_history(history,after,after,source='scan',recorded_at=STAMP,revision_before=0,revision_after=1,catalog_revision=None,context=context)['events'][-1]
        history['events'] += [{**deepcopy(sample),'sequence':i+1,'revision_before':i-1,'revision_after':i} for i in range(1,10000)]
        history['next_sequence']=10001; history['total_counts']['scan']=9999
        history['last_applied_at']['scan']=STAMP; history['scan_session_ids']=['session']
        entry = {'sequence':10000,'recorded_at':STAMP,'session_id':'session','scan_kind':sample['scan_kind'],'inventory_scan_profile':sample['inventory_scan_profile']}
        history['latest_scans']={'by_kind':[entry],'by_student_id':[{'student_id':fixture['students'][0]['student_id'],**entry}],'by_resource_key':[]}
        start=time.perf_counter()
        history = append_history(history,after,after,source='scan',recorded_at=STAMP,revision_before=9999,revision_after=10000,catalog_revision=None,context=context)
        history_from_wire(history,current=after,revision=10000)
        elapsed=time.perf_counter()-start
        self.assertEqual(len(history['events']),10000)
        sizes={'student_count':217,'inventory_count':614,'import_seed_bytes':len(canonical_json(seed).encode()),'baseline_bytes':len(canonical_json(history['baseline']).encode()),'history_10000_commits_bytes':len(canonical_json(history).encode()),'retained_scan_commits':10000,'scan_sessions':1,'append_and_validate_seconds':round(elapsed,4),'limit_bytes':16*1024*1024}
        self.assertLess(sizes['history_10000_commits_bytes'],16*1024*1024)
        replacement=deepcopy(after)
        for item in replacement['students']: item['values']['level']=1
        for item in replacement['inventory']: item['quantity']='1' if item['quantity'] is None else '0'
        legacy=empty_history(fixture['students'],fixture['inventory'],legacy=True)
        full=append_history(legacy,after,replacement,source='manual',recorded_at=STAMP,revision_before=0,revision_after=1,catalog_revision=None)
        sizes['legacy_full_replacement_history_bytes']=len(canonical_json(full).encode())
        self.assertLess(sizes['legacy_full_replacement_history_bytes'],16*1024*1024)
        with tempfile.TemporaryDirectory() as temp:
            repo=JsonRepository(Path(temp),clock=lambda:AT)
            pid=repo.create_profile('Anonymous','shape')['profile']['profile_id']
            path=repo._profile_path(pid); raw=json.loads(path.read_text(encoding='utf-8')); raw.pop('current_history'); raw.update(students=fixture['students'],inventory=fixture['inventory']); write(path,raw)
            def measure(stage):
                if stage=='before_commit': sizes['actual_journal_bytes']=(Path(temp)/JOURNAL).stat().st_size
            repo._fault=measure
            changed=deepcopy(fixture['students'])
            for item in changed: item['values']['level']=1
            started=time.perf_counter(); repo.update_students(pid,changed,0,'full',manual=True)
            sizes['durable_full_student_write_seconds']=round(time.perf_counter()-started,4)
            sizes['actual_profile_after_bytes']=path.stat().st_size
        (ROOT/'debug/frontend_fb2a/size-measurement.json').write_text(json.dumps(sizes,indent=2)+'\n',encoding='utf-8')


class HistoryRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'repository'
        self.clock_calls=0
        def clock(): self.clock_calls+=1; return AT
        self.repo=JsonRepository(self.root,clock=clock,id_factory=lambda:'b'*32)
        self.pid=self.repo.create_profile('Main','main')['profile']['profile_id']
        self.protocol=RepositoryProtocolV1(self.repo)

    def call(self,method,payload):
        return self.protocol.handle({'protocol':1,'id':'history','type':'request','method':method,'payload':payload})['payload']

    def history(self): return self.repo._profile(self.pid)['current_history']
    def summary(self): return self.repo.get_history_summary([self.pid])['profiles'][0]

    def test_new_legacy_unknown_baseline_and_read_has_no_write(self):
        self.assertEqual(self.summary()['coverage']['origin'],'empty')
        before=snapshot(self.root); self.summary(); self.assertEqual(before,snapshot(self.root)); self.assertEqual(self.clock_calls,0)
        path=self.repo._profile_path(self.pid); raw=json.loads(path.read_text(encoding='utf-8')); raw.pop('current_history'); raw['students']=[student({'level':80})]; write(path,raw)
        before=snapshot(self.root); self.assertEqual(self.summary()['coverage']['origin'],'unrecorded'); self.assertEqual(before,snapshot(self.root))
        self.repo.update_students(self.pid,[student({'level':80})],0,'first',manual=True)
        history=self.history(); self.assertEqual(history['baseline']['origin'],'legacy'); self.assertIsNone(history['baseline']['recorded_at']); self.assertEqual(history['baseline']['students'],[student({'level':80})])
        self.assertEqual(history['events'][0]['student_changes'],[])

    def test_public_manual_source_nochange_retry_restart_and_old_cache(self):
        payload={'profile_id':self.pid,'expected_revision':0,'idempotency_key':'once','students':[student({'level':0,'bond_rank':None})]}
        self.assertEqual(self.call('repository.students.update',payload),{'revision':1})
        saved=snapshot(self.root); first=self.summary(); self.assertEqual(first['last_manual_at'],STAMP)
        self.assertEqual(self.call('repository.students.update',payload),{'revision':1}); self.assertEqual(saved,snapshot(self.root)); self.assertEqual(self.clock_calls,1)
        fresh=JsonRepository(self.root,clock=lambda:self.fail('Replay must not read clock'))
        self.assertEqual(fresh.get_history_summary([self.pid])['profiles'][0],first)
        self.assertEqual(fresh.update_students(self.pid,payload['students'],0,'once',manual=True),{'revision':1})
        # A pre-history cache has only {revision}; replay cannot initialize history.
        path=self.repo._profile_path(self.pid); raw=json.loads(path.read_text(encoding='utf-8')); raw.pop('current_history'); write(path,raw)
        self.assertEqual(self.call('repository.students.update',payload),{'revision':1})
        self.assertNotIn('current_history',json.loads(path.read_text(encoding='utf-8')))
        payload.update(expected_revision=1,idempotency_key='nochange')
        self.assertEqual(self.call('repository.students.update',payload),{'revision':2})
        self.assertEqual(self.history()['events'][0]['student_changes'],[])
        self.assertEqual(self.summary()['total_counts']['manual'],1)

    def test_no_context_is_unattributed_and_explicit_scan_scope_is_atomic(self):
        self.repo.update_students(self.pid,[student({'level':0})],0,'legacy-scan')
        self.assertIsNone(self.summary()['last_manual_at']); self.assertEqual(self.summary()['total_counts']['unattributed'],1)
        ctx=scan()
        self.repo.update_students(self.pid,[student({'level':0})],1,'scan',history_context=ctx)
        history=self.history(); self.assertEqual(history['events'][-1]['student_changes'],[])
        self.assertEqual(history['latest_scans']['by_student_id'][0]['scan_kind'],' New Kind ')
        self.assertEqual(self.summary()['total_scan_session_count'],1)
        before=snapshot(self.root)
        wrong=scan({'student_ids':['unapproved'],'resource_keys':[]})
        with self.assertRaises(RepositoryError): self.repo.update_students(self.pid,[student({'level':1})],2,'wrong',history_context=wrong)
        self.assertEqual(before,snapshot(self.root))
        with self.assertRaises(RepositoryError) as caught: self.repo.update_students(self.pid,[student({'level':0})],1,'scan',history_context=scan(session='different'))
        self.assertEqual(caught.exception.code,'idempotency_conflict')

    def test_manual_inventory_scope_partial_scan_and_untouched_index(self):
        inventory={'version':1,'entries':[{'key':'a','quantity':None},{'key':'b','quantity':'0'}]}
        payload={'profile_id':self.pid,'expected_revision':0,'idempotency_key':'inventory','inventory':inventory}
        self.assertEqual(self.call('repository.inventory.update',payload),{'revision':1})
        ctx=scan({'student_ids':[],'resource_keys':['a']},profile=None)
        self.repo.update_inventory(self.pid,inventory,1,'scan-a',history_context=ctx)
        self.assertEqual([item['resource_key'] for item in self.history()['latest_scans']['by_resource_key']],['a'])
        self.assertIsNone(self.history()['events'][-1]['inventory_scan_profile'])
        empty={'version':1,'entries':[]}
        self.repo.update_inventory(self.pid,empty,2,'delete',manual=True)
        event=self.history()['events'][-1]
        self.assertEqual(event['applied_scope'],{'student_ids':[],'resource_keys':['a','b']})
        self.assertEqual(event['inventory_changes'][0]['before'],{'present':True,'quantity':None})

    def test_duplicate_new_direct_v6_and_stored_profile_are_explicit_errors(self):
        before=snapshot(self.root)
        with self.assertRaises(RepositoryError) as caught: self.repo.update_students(self.pid,[student(),student()],0,'duplicate')
        self.assertEqual(caught.exception.code,'invalid_payload'); self.assertEqual(before,snapshot(self.root))
        v6=Path(self.temp.name)/'v6'; v6_fixture(v6)
        write(v6/'profiles/profile_deadbeef/data/current/students.json',{'one':{'student_id':'aru','level':1},'two':{'student_id':'aru','level':2}})
        with self.assertRaises(RepositoryError) as caught: self.repo.import_v6_profile(str(v6),'profile_deadbeef')
        self.assertEqual(caught.exception.code,'invalid_payload'); self.assertEqual(before,snapshot(self.root))
        path=self.repo._profile_path(self.pid); raw=json.loads(path.read_text(encoding='utf-8')); raw.pop('current_history'); raw['students']=[student(),student()]; write(path,raw)
        before=snapshot(self.root)
        with self.assertRaises(RepositoryError) as caught: self.repo.get_state(self.pid)
        self.assertEqual(caught.exception.code,'corrupt_data'); self.assertEqual(caught.exception.details['reason'],'duplicate_identity'); self.assertEqual(before,snapshot(self.root))

    def test_meta_plan_migration_save_replace_and_goals_preserve_history_only(self):
        self.repo.update_students(self.pid,[student({'level':0})],0,'manual',manual=True)
        history=self.history(); self.repo.rename_profile(self.pid,'Renamed',1,'rename')
        document=self.repo.get_plan(self.pid)['document']
        self.repo.save_plan(self.pid,document,2,'plan')
        self.repo.save_goals(self.pid,{'version':1,'goals':[]},3,'goals')
        self.repo.replace_plan(self.pid,document,4,0,'replace','Archive','')
        self.assertEqual(self.history(),history); self.assertEqual(self.clock_calls,1)
        path=self.repo._profile_path(self.pid); raw=json.loads(path.read_text(encoding='utf-8')); raw.pop('plan'); write(path,raw)
        self.repo.get_plan(self.pid); self.assertEqual(self.history(),history)
        self.assertEqual(self.summary()['revision'],6)

    def test_import_seed_uses_backend_time_not_scan_and_preserves_source(self):
        v6=Path(self.temp.name)/'v6'; v6_fixture(v6); before={path: path.read_bytes() for path in v6.rglob('*') if path.is_file()}
        result=self.repo.import_v6_profile(str(v6),'profile_deadbeef'); pid=result['profile']['profile_id']
        h=self.repo._profile(pid)['current_history']; s=self.repo.get_history_summary([pid])['profiles'][0]
        self.assertEqual(h['events'][0]['source'],'import'); self.assertEqual((h['events'][0]['revision_before'],h['events'][0]['revision_after']),(0,0)); self.assertEqual(s['last_import_at'],STAMP)
        self.assertEqual(s['total_counts']['scan'],0); self.assertEqual(s['total_scan_session_count'],0)
        self.assertEqual({path:path.read_bytes() for path in before},before)

    def test_corrupt_history_never_reset_and_capacity_failure_leaves_all_before(self):
        before=snapshot(self.root)
        with patch('core.repository_store.append_history',side_effect=HistoryError('history_capacity_exceeded','capacity')):
            error=self.call('repository.students.update',{'profile_id':self.pid,'expected_revision':0,'idempotency_key':'capacity','students':[student()]})['error']
        self.assertEqual(error['code'],'invalid_payload'); self.assertEqual(error['details']['reason'],'history_capacity_exceeded'); self.assertEqual(before,snapshot(self.root))
        path=self.repo._profile_path(self.pid); raw=json.loads(path.read_text(encoding='utf-8')); raw['current_history']=None; write(path,raw)
        before=snapshot(self.root)
        with self.assertRaises(RepositoryError) as caught: self.summary()
        self.assertEqual(caught.exception.code,'corrupt_data'); self.assertEqual(before,snapshot(self.root))

    def test_minimal_summary_protocol_strict_and_does_not_migrate_legacy_plan(self):
        path=self.repo._profile_path(self.pid); raw=json.loads(path.read_text(encoding='utf-8')); raw.pop('plan'); raw.pop('current_history'); write(path,raw)
        before=snapshot(self.root); result=self.call('repository.history.summary',{'profile_ids':[self.pid]})
        self.assertEqual(result['profiles'][0]['revision'],0); self.assertEqual(before,snapshot(self.root))
        for ids in [[],[self.pid,self.pid],['a'*24]*129,[True]]:
            self.assertEqual(self.call('repository.history.summary',{'profile_ids':ids})['error']['code'],'invalid_payload')
        self.assertEqual(self.call('repository.history.summary',{'profile_ids':[self.pid],'scan_kind':'invented'})['error']['code'],'invalid_payload')
        self.assertEqual(self.call('repository.students.update',{'profile_id':self.pid,'expected_revision':0,'idempotency_key':'forge','students':[],'history_context':{}})['error']['code'],'invalid_payload')

    def test_exceptions_and_process_exit_at_every_boundary_for_current_create_import(self):
        v6=Path(self.temp.name)/'v6'; v6_fixture(v6)
        for mode in ('current','create','import'):
            with tempfile.TemporaryDirectory() as expected_temp:
                expected_repo=JsonRepository(Path(expected_temp),clock=lambda:AT,id_factory=lambda:'b'*32)
                pid=expected_repo.create_profile('Main','main')['profile']['profile_id']; operation(expected_repo,mode,pid,v6)
                expected_after=snapshot(Path(expected_temp))
            for crash in (False,True):
                for stage in STAGES:
                    with self.subTest(mode=mode,crash=crash,stage=stage), tempfile.TemporaryDirectory() as temp:
                        root=Path(temp); repo=JsonRepository(root,clock=lambda:AT,id_factory=lambda:'b'*32); pid=repo.create_profile('Main','main')['profile']['profile_id']; before=snapshot(root)
                        if crash:
                            child=subprocess.run([sys.executable,'-X','utf8','-c',CHILD,str(root),pid,str(v6),mode,stage],cwd=ROOT/'backend',capture_output=True,timeout=20)
                            self.assertEqual(child.returncode,73,child.stderr)
                        else:
                            def fault(point):
                                if point==stage: raise OSError(stage)
                            with self.assertRaises(RepositoryError) as caught: operation(JsonRepository(root,clock=lambda:AT,id_factory=lambda:'b'*32,fault=fault),mode,pid,v6)
                            self.assertEqual(caught.exception.code,'persistence_failed')
                        fresh=JsonRepository(root)
                        profiles=fresh.list_profiles()['profiles']  # recovers before reading
                        fresh.get_history_summary([item['profile_id'] for item in profiles])
                        self.assertEqual(snapshot(root),expected_after if stage in ('journal_committed','journal_removed') else before)
                        self.assertFalse((root/JOURNAL).exists())
                        if mode=='current' and stage in ('journal_committed','journal_removed'):
                            replay=JsonRepository(root,clock=lambda:self.fail('Replay read clock'))
                            operation(replay,mode,pid,v6); self.assertEqual(snapshot(root),expected_after)

    def test_atomic_target_write_failures_and_interrupted_recovery_are_repeatable(self):
        before=snapshot(self.root)
        for stage in ('before_write','before_fsync','before_replace'):
            for target in (1,2):
                counter=0
                def fault(point):
                    nonlocal counter
                    if point==stage:
                        counter+=1
                        if counter==target: raise OSError(stage)
                with self.subTest(stage=stage,target=target), self.assertRaises(RepositoryError): operation(JsonRepository(self.root,clock=lambda:AT,fault=fault),'current',self.pid,None)
                self.assertEqual(snapshot(self.root),before)
        child=subprocess.run([sys.executable,'-c',CHILD,str(self.root),self.pid,'unused','current','catalog_written'],cwd=ROOT/'backend',capture_output=True,timeout=20)
        self.assertEqual(child.returncode,73,child.stderr)
        from core import repository_transaction as tx
        original=tx._write_bytes
        def failed(path,content):
            if path.name=='catalog.json': raise OSError('interrupted recovery')
            return original(path,content)
        with patch.object(tx,'_write_bytes',failed), self.assertRaises(RepositoryError): self.summary()
        self.assertTrue((self.root/JOURNAL).exists())
        self.summary(); self.assertEqual(snapshot(self.root),before)


if __name__ == '__main__': unittest.main()
