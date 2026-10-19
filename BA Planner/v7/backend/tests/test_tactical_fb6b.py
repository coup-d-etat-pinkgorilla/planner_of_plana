from copy import deepcopy
import json
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator, FormatChecker
from core.repository_store import RepositoryError, JsonRepository
from core.repository_dto import canonical_json
from core.tactical_fb6 import canonical_attempt_count
from core.tactical_fb6_store import request_match, put_match, delete_match, legacy_preview, legacy_commit
from core.tactical_v2 import TacticalV2Store, TacticalProtocolV2
from core.tactical_stats_v2 import TacticalStatisticsV2
from core.tactical_trends_v2 import TacticalTrendsV2
from core.tactical_recommend_v2 import TacticalRecommendationV2
from core.tactical_share_v1 import TacticalShareV1Store
from tests import test_tactical_fb6_writes as base
from tests.test_tactical_stats_v2 import filters
from tests.test_tactical_trends_v2 import trend_filters
from tests.test_tactical_recommend_v2 import recommendation_filters

ROOT=Path(__file__).resolve().parents[2]
def anonymous(mid='defense-unknown'):
    data=base.match(mid);data.update(kind='defense',opponent_identity_id=None,opponent_display_name=None,attempt_count=None)
    return data

class TacticalFB6bTests(unittest.TestCase):
    def setUp(self):
        self.case=base.TacticalFB6WriteTests();self.case.setUp()
        self.root,self.profile,self.store,self.repository=self.case.root,self.case.profile,self.case.store,self.case.repository
        self.validator=Draft202012Validator(json.loads((ROOT/'contracts/tactical-protocol-v2.schema.json').read_text(encoding='utf-8')),format_checker=FormatChecker())
    def tearDown(self):self.case.tearDown()
    def error(self,code,action,*args):
        with self.assertRaises(RepositoryError) as caught:action(*args)
        self.assertEqual(code,caught.exception.code)
    def test_null_positive_and_invalid_attempt_values(self):
        self.assertIsNone(canonical_attempt_count(None));self.assertEqual(3,canonical_attempt_count(3))
        for wrong in (False,True,0,-1,1.0,'1'):
            self.error('invalid_payload',canonical_attempt_count,wrong)
    def test_missing_attempt_remains_distinct_from_null(self):
        data=base.match();del data['attempt_count']
        self.error('invalid_payload',request_match,data)
    def test_attack_null_attempt_preserves_null(self):
        data=base.match();data['attempt_count']=None
        result=put_match(self.store,self.profile,data,0,'save')
        self.assertIsNone(result['match']['attempt_count']);self.assertEqual(1,len(self.store.state(self.profile)['matches']))
    def test_anonymous_defense_has_no_fake_identity_alias_snapshot(self):
        result=put_match(self.store,self.profile,anonymous(),0,'save')
        self.assertIsNone(result['match']['opponent_identity_id']);self.assertIsNone(result['match']['opponent_display_name'])
        state=self.store.state(self.profile)
        self.assertEqual(2,state['version']);self.assertEqual([],state['opponents']);self.assertEqual([],state['snapshots']);self.assertEqual([],state['jokbo'])
        persisted=json.loads(self.store._path(self.profile).read_text(encoding='utf-8'))
        self.assertIsNone(persisted['matches'][0]['attempt_count'])
    def test_half_null_attack_null_and_blanks_rejected_without_write(self):
        for change in ({'opponent_identity_id':'known'}, {'opponent_display_name':'Name'},
                       {'opponent_identity_id':'','opponent_display_name':''},
                       {'opponent_identity_id':'known','opponent_display_name':' '}, {'kind':'attack'}):
            data=anonymous();data.update(change)
            self.error('invalid_payload',put_match,self.store,self.profile,data,0,'bad')
            self.assertFalse(self.store._path(self.profile).exists())
    def test_restart_and_original_null_retry_do_not_revert_edit(self):
        data=anonymous();first=put_match(self.store,self.profile,data,0,'save')
        edit=anonymous();edit.update(attempt_count=4,opponent_identity_id='known',opponent_display_name='Known')
        put_match(self.store,self.profile,edit,1,'edit')
        restarted=TacticalV2Store(self.root,JsonRepository(self.root))
        self.assertEqual(first,put_match(restarted,self.profile,data,0,'save'))
        state=restarted.state(self.profile);self.assertEqual(2,state['revision']);self.assertEqual(4,state['matches'][0]['attempt_count'])
        self.assertEqual(['known'],[o['identity_id'] for o in state['opponents']])
    def test_same_key_different_null_payload_conflicts(self):
        put_match(self.store,self.profile,anonymous(),0,'save')
        data=anonymous();data['attempt_count']=1
        self.error('idempotency_conflict',put_match,self.store,self.profile,data,1,'save')
    def test_atomic_replace_failure_retains_exact_previous_bytes(self):
        put_match(self.store,self.profile,anonymous(),0,'save')
        path=self.store._path(self.profile);before=path.read_bytes()
        def fail(stage):
            if stage=='before_replace':raise OSError('synthetic')
        failing=TacticalV2Store(self.root,self.repository,fault=fail)
        self.error('persistence_failed',put_match,failing,self.profile,anonymous('second'),1,'second')
        self.assertEqual(before,path.read_bytes())
        self.assertEqual(2,put_match(self.store,self.profile,anonymous('second'),1,'second')['revision'])
    def test_two_unknown_defenses_do_not_form_an_opponent_or_duplicate_cohort(self):
        put_match(self.store,self.profile,anonymous('one'),0,'one')
        put_match(self.store,self.profile,anonymous('two'),1,'two')
        result=TacticalStatisticsV2.query(self.store.state(self.profile),filters())
        self.assertEqual((2,2,0),(result['population']['match_count'],result['population']['defense_match_count'],result['population']['opponent_count']))
        self.assertEqual([],result['opponents']);self.assertEqual(0,result['quality']['distinct_opponent_count']);self.assertEqual(0,result['quality']['suspected_duplicate_count'])
    def test_known_opponent_filter_excludes_unknown_defenses(self):
        put_match(self.store,self.profile,anonymous(),0,'one')
        put_match(self.store,self.profile,base.match(),1,'known')
        state=self.store.state(self.profile)
        result=TacticalStatisticsV2.query(state,filters(opponent_identity_id='opponent-one'))
        self.assertEqual(1,result['population']['match_count']);self.assertEqual(1,len(result['opponents']))
        self.assertEqual(1,TacticalStatisticsV2.query(state,filters())['population']['opponent_count'])
    def test_anonymous_defense_does_not_change_trends_or_recommendation_evidence(self):
        before=self.store.state(self.profile)
        target=recommendation_filters(opponent_identity_id='opponent-one')
        trends=canonical_json(TacticalTrendsV2.query(before,trend_filters(season='34',as_of='2026-10-16T00:00:00+09:00')))
        rec=canonical_json(TacticalRecommendationV2.query(before,target))
        put_match(self.store,self.profile,anonymous(),0,'save');after=self.store.state(self.profile)
        self.assertEqual(trends,canonical_json(TacticalTrendsV2.query(after,trend_filters(season='34',as_of='2026-10-16T00:00:00+09:00'))))
        self.assertEqual(rec,canonical_json(TacticalRecommendationV2.query(after,target)))
    def test_anonymous_defense_is_not_shareable_and_has_no_shared_identity(self):
        put_match(self.store,self.profile,anonymous(),0,'save')
        shares=TacticalShareV1Store(self.root,self.repository,self.store)
        request={'match_id':'defense-unknown','scope_id':'scope-34','contributor_id':'contributor',
            'consent':{'enabled':True,'scope_id':'scope-34','contributor_id':'contributor','consented_at':'2026-10-15T00:00:00+09:00','include_original_media':False},
            'attempt_session_id':'session','attempt_index':1,'shared_at':'2026-10-15T01:00:00+09:00','patch':'synthetic'}
        self.error('not_shareable',shares.prepare,self.profile,request)
        self.assertEqual([],shares.state(self.profile)['records'])
    def test_corrupt_attack_null_identity_is_rejected_before_anonymization(self):
        put_match(self.store,self.profile,base.match(),0,'known')
        state=self.store._read(self.profile);state['matches'][0]['opponent_identity_id']=None
        self.store._write(self.store._path(self.profile),state)
        shares=TacticalShareV1Store(self.root,self.repository,self.store)
        request={'match_id':'m1','scope_id':'scope-34','contributor_id':'contributor',
            'consent':{'enabled':True,'scope_id':'scope-34','contributor_id':'contributor','consented_at':'2026-10-15T00:00:00+09:00','include_original_media':False},
            'attempt_session_id':'session','attempt_index':1,'shared_at':'2026-10-15T01:00:00+09:00','patch':'synthetic'}
        with self.assertRaises(RepositoryError) as caught:shares.prepare(self.profile,request)
        self.assertEqual('not_shareable',caught.exception.code)
        self.assertIn('known opponent identity',str(caught.exception))
    def test_legacy_unknown_attempt_can_be_edited_without_inventing_one(self):
        self.case.legacy.upsert_match(self.profile,base.v1_match(),0,'legacy')
        preview=legacy_preview(self.store,self.profile)
        legacy_commit(self.store,self.profile,preview['source_revision'],preview['source_fingerprint'],0,'migrate')
        state=self.store.state(self.profile);item=state['matches'][0]
        self.assertIsNone(item['attempt_count'])
        data={key:item[key] for key in base.match()};data['notes']='edited without guessing'
        result=put_match(self.store,self.profile,data,state['revision'],'edit')
        self.assertIsNone(result['match']['attempt_count'])
    def test_excel_missing_attempt_still_requires_explicit_review(self):
        from tests import test_tactical_excel_store as excel
        case=excel.ExcelAtomicBatchTests();case.setUp()
        try:
            case.write(excel.values(opponent='Rival',attempts=''))
            self.assertEqual(0,excel.preview(case.store,case.data)['summary']['eligible_rows'])
            self.error('import_review_required',excel.commit,case.store,case.request())
        finally:case.tearDown()
    def test_actual_null_request_response_state_validate(self):
        request={'protocol':1,'id':'fd176','type':'request','method':'tactical.v2.match.upsert',
            'payload':{'profile_id':self.profile,'match':anonymous(),'expected_revision':0,'idempotency_key':'null'}}
        self.validator.validate(request)
        response=TacticalProtocolV2(self.store).handle(request);self.validator.validate(response)
        self.validator.validate(TacticalProtocolV2(self.store).handle({'protocol':1,'id':'state','type':'request','method':'tactical.v2.state.get','payload':{'profile_id':self.profile}}))
    def test_schema_rejects_half_null_empty_missing_and_boolean(self):
        for change in ({'kind':'attack'},{'opponent_display_name':'Name'},{'opponent_identity_id':'known'},
                       {'opponent_identity_id':'','opponent_display_name':''},{'attempt_count':False}):
            data=anonymous();data.update(change)
            req={'protocol':1,'id':'bad','type':'request','method':'tactical.v2.match.upsert','payload':{'profile_id':self.profile,'match':data,'expected_revision':0,'idempotency_key':'bad'}}
            self.assertTrue(list(self.validator.iter_errors(req)))
    def test_fd176_fixture_matches_runtime_and_strict_schema(self):
        cases=json.loads((ROOT/'contracts/fixtures/tactical_fb6b_nulls_v2.json').read_text(encoding='utf-8'))['cases']
        for case in cases:
            request={'protocol':1,'id':'fixture','type':'request','method':'tactical.v2.match.upsert',
                'payload':{'profile_id':self.profile,'match':case['input'],'expected_revision':0,'idempotency_key':'fixture'}}
            with self.subTest(case=case['name']):
                if case['valid']:
                    self.validator.validate(request);request_match(case['input'])
                else:
                    self.assertTrue(list(self.validator.iter_errors(request)))
                    self.error('invalid_payload',request_match,case['input'])

if __name__=='__main__':unittest.main()
