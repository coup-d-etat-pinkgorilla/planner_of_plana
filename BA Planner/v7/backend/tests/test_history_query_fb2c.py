from copy import deepcopy
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from core.current_history import append_history, apply_event, empty_history, history_from_wire, projection
from core.history_query import events_request, diff_request, query_events, query_diff, quantity_delta
from core.repository_store import JsonRepository, RepositoryError
from core.repository_protocol_v1 import RepositoryProtocolV1
from core.repository_transaction import write_transaction

ROOT = Path(__file__).parents[2]


class HistoryQueryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture=json.loads((ROOT/'contracts/fixtures/repository_history_query_v1.json').read_text(encoding='utf-8'))
        schemas=[json.loads(p.read_text(encoding='utf-8')) for p in (ROOT/'contracts').glob('*.schema.json')]
        registry=Registry().with_resources((s['$id'],Resource.from_contents(s)) for s in schemas)
        schema=next(s for s in schemas if s['$id'].endswith('/repository-history-query-v1.schema.json'))
        cls.validators={key:Draft202012Validator({**schema,'oneOf':[{'$ref':'#/$defs/'+key}]},registry=registry)
            for key in ('eventsRequest','diffRequest','eventsResult','diffResult')}
        cls.protocol=Draft202012Validator(next(s for s in schemas if s['$id'].endswith('/repository-protocol-v1.schema.json')),registry=registry)

    def setUp(self):
        self.h=deepcopy(self.fixture['history']);self.current=deepcopy(self.fixture['current'])
        self.pid=self.fixture['profile_id'];self.revision=self.fixture['revision']

    def events(self,**kw):
        return query_events(self.pid,self.revision,self.h,{'profile_id':self.pid,**kw})

    def diff(self,a,b,**kw):
        return query_diff(self.pid,self.revision,self.h,self.current,{'profile_id':self.pid,'from':a,'to':b,**kw})

    def test_shared_policy_fixture_schema_python_and_protocol(self):
        for case in self.fixture['cases']:
            with self.subTest(case=case['id']):
                h=case.get('history',self.h); current=case.get('current',self.current)
                if h is not None: history_from_wire(h,current=current)
                method=case['method'];req=case['request']
                self.validators[method+'Request'].validate(req)
                result=query_events(self.pid,self.revision,h,req) if method=='events' else query_diff(self.pid,self.revision,h,current,req)
                self.assertEqual(result,case['result'])
                self.validators[method+'Result'].validate(result)
                for type_,payload in [('request',req),('response',result)]:
                    self.protocol.validate({'protocol':1,'id':case['id'],'type':type_,'method':'repository.history.'+method,'payload':payload})
                result['coverage']['reasons'].append('test-mutation')
                self.assertEqual(self.h,self.fixture['history'])

    def test_strict_invalid_requests(self):
        for case in self.fixture['invalid_requests']:
            self.assertEqual(not list(self.validators[case['method']+'Request'].iter_errors(case['request'])),case['schema_valid'],case['id'])
            with self.subTest(case=case['id']),self.assertRaises((ValueError,TypeError)):
                if case['method']=='events': self.events(**{k:v for k,v in case['request'].items() if k!='profile_id'})
                else: query_diff(self.pid,self.revision,self.h,self.current,case['request'])

    def test_invalid_response_schema_and_runtime_relationship_fixture(self):
        for case in self.fixture['invalid_results']:
            with self.subTest(case=case['id']):
                self.assertEqual(not list(self.validators[case['method']+'Result'].iter_errors(case['result'])),case['schema_valid'])

    def test_arbitrary_precision_quantity_delta(self):
        self.assertEqual(quantity_delta('1'+'0'*5000,'9'*5000),'-1')
        self.assertEqual(quantity_delta('9'*5000,'1'+'0'*5000),'1')
        self.assertEqual(quantity_delta('0','0'),'0')

    def test_cursor_capacity_covers_escaped_maximum_target_filters(self):
        ids=['\x00'*1019+str(i).zfill(4) for i in range(256)]
        page=self.events(limit=1,student_ids=ids,resource_keys=['a',*ids[:255]])
        self.assertGreater(len(page['next_cursor']),1024*1024)
        self.validators['eventsResult'].validate(page)
        second=self.events(limit=1,student_ids=ids,resource_keys=['a',*ids[:255]],cursor=page['next_cursor'])
        self.assertEqual(second['events'][0]['sequence'],2)

    def test_half_open_times_state_before_boundary_and_same_timestamp(self):
        from_at=self.h['events'][1]['recorded_at'];to_at=self.h['events'][3]['recorded_at']
        self.assertEqual([e['sequence'] for e in self.events(from_at=from_at,to_at=to_at)['events']],[2,3])
        d=self.diff({'at':from_at},{'at':to_at},resource_keys=['a'],student_ids=[])
        self.assertEqual((d['from_point']['sequence'],d['to_point']['sequence']),(1,3))
        self.assertEqual(d['inventory_changes'][0]['delta'],'10')
        self.h['events'][3]['recorded_at']=to_at=self.h['events'][2]['recorded_at']
        self.h['last_applied_at']['scan']=self.h['events'][-1]['recorded_at']
        d=self.diff({'at':to_at},{'sequence':4},resource_keys=['a'],student_ids=[])
        self.assertEqual(d['from_point']['sequence'],2)
        self.assertEqual([e['sequence'] for e in self.events(from_at=to_at,to_at=to_at)['events']],[])

    def test_all_sources_restore_actual_state_without_display_filter_leaking(self):
        d=self.diff({'scan':'latest','inventory_scan_profile':None,'resource_key':'a'},{'sequence':5},resource_keys=['a'],student_ids=['aru'])
        self.assertEqual(d['from_point']['sequence'],4) # same session's last application, even different scope
        self.assertEqual(d['inventory_changes'][0]['before']['quantity'],'20') # intervening manual
        self.assertEqual(d['inventory_changes'][0]['after']['quantity'],'18') # unattributed
        self.assertEqual(d['inventory_changes'][0]['delta'],'-2')
        self.assertEqual(d['student_changes'][0]['after']['value']['values']['level'],81)
        self.assertEqual(d['scan_commit_count'],0)

    def test_raw_exact_null_omitted_unknown_scope_and_nochange_scan(self):
        all_=self.events(scan_kind=' Future Kind ',resource_keys=['a'])
        null=self.events(scan_kind=' Future Kind ',resource_keys=['a'],inventory_scan_profile=None)
        self.assertEqual(all_['scan_commit_count'],4)
        self.assertEqual(all_['scan_session_count'],3)
        self.assertEqual([p['sequence'] for p in all_['scan_points']],[4,7,9])
        self.assertTrue(all_['trend_eligible'])
        self.assertEqual(null['scan_commit_count'],1);self.assertEqual(null['scan_session_count'],1)
        self.assertFalse(null['trend_eligible'])
        self.assertEqual(self.events(scan_kind='Future Kind')['events'],[])
        self.assertEqual(self.events(resource_keys=['unknown-future'])['scan_points'],[])
        self.assertEqual(self.h['events'][5]['inventory_changes'],[])

    def test_scan_previous_is_distinct_session_not_candidate_commit(self):
        d=self.diff({'scan':'previous','scan_kind':' Future Kind ','resource_key':'a'},
                    {'scan':'latest','scan_kind':' Future Kind ','resource_key':'a'},resource_keys=['a'],student_ids=[])
        self.assertEqual((d['from_point']['sequence'],d['to_point']['sequence']),(7,9))
        self.assertEqual(d['inventory_changes'][0]['delta'],'9')
        self.assertEqual((d['scan_commit_count'],d['scan_session_count']),(1,1))

    def test_session_end_outside_time_window_is_not_a_trend_point(self):
        r=self.events(from_at=self.h['events'][1]['recorded_at'],to_at=self.h['events'][3]['recorded_at'],resource_keys=['a'])
        self.assertEqual(r['scan_commit_count'],1)
        self.assertEqual(r['scan_session_count'],0)

    def test_cursor_anchor_survives_writes_restart_changed_limit_and_query_order(self):
        page=self.events(limit=2,resource_keys=['b','a'])
        cursor=page['next_cursor'];anchor=page['history_sequence']
        state=deepcopy(self.current);state['inventory'][0]['quantity']='100'
        self.h=append_history(self.h,self.current,state,source='manual',recorded_at='2026-01-01T00:00:11.000000Z',revision_before=9,revision_after=10,catalog_revision=None)
        self.current=state;self.revision=10
        seq=[e['sequence'] for e in page['events']]
        while cursor:
            r=self.events(limit=3,resource_keys=['a','b'],cursor=cursor)
            self.assertEqual(r['history_sequence'],anchor)
            self.assertEqual(r['scan_points'],page['scan_points'])
            self.assertEqual(r['matching_event_count'],page['matching_event_count'])
            seq.extend(e['sequence'] for e in r['events']);cursor=r['next_cursor']
        self.assertEqual(seq,list(range(1,11)))
        with self.assertRaisesRegex(ValueError,'match profile/filters'):
            self.events(cursor=page['next_cursor'],resource_keys=['a'])
        for bad in ('!',page['next_cursor']+'=', 'W10', 'bnVsbA'):
            with self.subTest(cursor=bad),self.assertRaises(ValueError): self.events(cursor=bad)

    def test_compaction_expires_cursor_replays_baseline_and_never_fills_missing(self):
        cursor=self.events(limit=2)['next_cursor']
        self.h=append_history(self.h,self.current,self.current,source='manual',recorded_at='2026-01-01T00:00:11.000000Z',revision_before=9,revision_after=10,catalog_revision=None,max_events=3)
        self.revision=10
        with self.assertRaises(ValueError) as error: self.events(cursor=cursor)
        self.assertEqual(error.exception.reason,'history_cursor_expired')
        self.assertEqual(self.h['baseline']['sequence'],8)
        d=self.diff({'sequence':8},{'current':True},resource_keys=['a'],student_ids=[])
        self.assertTrue(d['coverage']['complete']);self.assertEqual(d['inventory_changes'][0]['delta'],'7')
        d=self.diff({'sequence':7},{'current':True},resource_keys=['a'],student_ids=[])
        self.assertFalse(d['from_point']['available']);self.assertIsNone(d['inventory_changes'][0]['delta'])
        self.assertIn('before_retention',d['coverage']['reasons'])
        self.assertTrue(self.events(from_at='2026-01-01T00:00:08.000001Z')['coverage']['complete'])
        self.assertFalse(self.events(from_at='2026-01-01T00:00:08.000000Z')['coverage']['complete'])

    def test_unknown_quantity_missing_zero_deleted_and_large_signed_delta(self):
        d=self.diff({'sequence':2},{'current':True},resource_keys=['a','unknown','zero','missing','large'],student_ids=[])
        rows={r['resource_key']:r for r in d['inventory_changes']}
        self.assertEqual(rows['a']['delta'],'20');self.assertEqual(rows['large']['delta'],'0')
        for key in ('unknown','zero','missing'): self.assertIsNone(rows[key]['delta'])
        self.assertEqual(rows['zero']['before'],{'present':True,'quantity':'0'})
        self.assertEqual(rows['zero']['after'],{'present':False,'quantity':None})
        self.assertIn('unknown_quantity',d['coverage']['reasons'])

    def test_clock_rollback_keeps_sequence_states_but_suppresses_deltas_and_trend(self):
        self.h['events'][7]['recorded_at']='2026-01-01T00:00:01.000000Z'
        r=self.events();self.assertFalse(r['coverage']['timestamps_monotonic']);self.assertFalse(r['trend_eligible'])
        d=self.diff({'sequence':2},{'current':True},resource_keys=['a'],student_ids=[])
        self.assertEqual(d['to_point']['inventory'][0]['quantity'],'32')
        self.assertIsNone(d['inventory_changes'][0]['delta']);self.assertIn('clock_rollback',d['coverage']['reasons'])
        d=self.diff({'at':'2026-01-01T00:00:05Z'},{'current':True},resource_keys=['a'],student_ids=[])
        self.assertFalse(d['from_point']['available'])

    def test_legacy_unknown_time_and_unrecorded_get_are_read_only(self):
        with tempfile.TemporaryDirectory() as root:
            repo=JsonRepository(Path(root),id_factory=lambda:self.pid)
            pid=repo.create_profile('Read','once')['profile']['profile_id']
            path=repo._profile_path(pid);profile=json.loads(path.read_text(encoding='utf-8'))
            del profile['current_history'];del profile['plan'];profile.pop('plan_authoring',None)
            profile['inventory']={'version':1,'entries':[{'key':'a','quantity':'7'}]}
            path.write_text(json.dumps(profile),encoding='utf-8');before=path.read_bytes()
            r=repo.get_history_events({'profile_id':pid})
            self.assertEqual(r['coverage']['reasons'],['unrecorded'])
            d=repo.get_history_diff({'profile_id':pid,'from':{'at':'2026-01-01T00:00:00Z'},'to':{'current':True},'resource_keys':['a'],'student_ids':[]})
            self.assertEqual(d['to_point']['inventory'],[{'resource_key':'a','quantity':'7'}])
            self.assertIsNone(d['inventory_changes'][0]['delta'])
            self.assertEqual(path.read_bytes(),before)

    def test_queries_recover_prepared_and_committed_journal_before_reading(self):
        for committed in (False,True):
            with self.subTest(committed=committed),tempfile.TemporaryDirectory() as root:
                repo=JsonRepository(Path(root),id_factory=lambda:self.pid)
                pid=repo.create_profile('Recovery','create')['profile']['profile_id']
                path=repo._profile_path(pid);before=json.loads(path.read_text(encoding='utf-8'));after=deepcopy(before)
                after.update(revision=self.revision,current_history=self.h,students=self.current['students'],inventory={'version':1,'entries':[{'key':r['resource_key'],'quantity':r['quantity']} for r in self.current['inventory']]})
                class Stop(BaseException): pass
                def fault(stage):
                    if stage==('journal_committed' if committed else 'profile_written'): raise Stop()
                with self.assertRaises(Stop): write_transaction(Path(root),[(path,after)],repo._atomic_write,fault,RepositoryError)
                read=JsonRepository(Path(root))
                e=read.get_history_events({'profile_id':pid})
                self.assertEqual(e['history_sequence'],10 if committed else 0)
                d=read.get_history_diff({'profile_id':pid,'from':{'current':True},'to':{'current':True},'student_ids':[],'resource_keys':['a'] if committed else []})
                self.assertEqual(d['history_sequence'],e['history_sequence'])
                self.assertFalse((Path(root)/'.repository.transaction.json').exists())

    def test_protocol_errors_keep_existing_codes_and_reason(self):
        with tempfile.TemporaryDirectory() as root:
            protocol=RepositoryProtocolV1(JsonRepository(Path(root)))
            def send(payload):return protocol.handle({'protocol':1,'id':'q','type':'request','method':'repository.history.events','payload':payload})
            result=send({'profile_id':self.pid})
            self.assertEqual(result['payload']['error']['code'],'profile_not_found');self.protocol.validate(result)
            result=send({'profile_id':self.pid,'limit':201})
            self.assertEqual(result['payload']['error']['code'],'invalid_payload')
            self.assertEqual(result['payload']['error']['details']['reason'],'invalid_history_query')
            self.protocol.validate(result)


if __name__=='__main__': unittest.main()
