from copy import deepcopy
import json
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator, FormatChecker
from core.repository_dto import canonical_json
from core.tactical_stats_v2 import TacticalStatisticsV2
from core.tactical_trends_v2 import TacticalTrendsV2
from core.tactical_recommend_v2 import TacticalRecommendationV2

ROOT=Path(__file__).resolve().parents[2]
class TacticalTypedReadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema=json.loads((ROOT/'contracts/tactical-protocol-v2.schema.json').read_text(encoding='utf-8'))
        Draft202012Validator.check_schema(cls.schema)
        cls.validator=Draft202012Validator(cls.schema,format_checker=FormatChecker())
        cls.cases=json.loads((ROOT/'contracts/fixtures/tactical_typed_read_responses_v2.json').read_text(encoding='utf-8'))['cases']
        cls.queries={'stats':TacticalStatisticsV2.query,'trends':TacticalTrendsV2.query,'recommend':TacticalRecommendationV2.query}
    def samples(self):
        for case in self.cases:
            if not case['name'].endswith('populated'): continue
            payload=case['response']['payload']
            for key in ('public_signatures','opponents','freshness','recommendations','hidden_slots','ambiguity','evidence_summary'):
                if key in payload:
                    item=payload[key][0] if isinstance(payload[key],list) and payload[key] else payload[key] if isinstance(payload[key],dict) else None
                    if item is not None: yield case,key,item
    def test_existing_actual_response_bytes_unchanged(self):
        for case in self.cases:
            result=self.queries[case['name'].split('-')[0]](deepcopy(case['state']),deepcopy(case['filters']))
            with self.subTest(case=case['name']): self.assertEqual(canonical_json(case['response']['payload']),canonical_json(result))
    def test_populated_and_unavailable_responses_validate(self):
        self.assertEqual(6,len(self.cases))
        for case in self.cases:
            with self.subTest(case=case['name']): self.validator.validate(case['response'])
    def test_all_requested_nested_shapes_are_exercised(self):
        self.assertEqual({'public_signatures','opponents','freshness','recommendations','hidden_slots','ambiguity','evidence_summary'}, {key for _,key,_ in self.samples()})
    def test_unknown_nested_keys_rejected(self):
        for case,key,_ in self.samples():
            bad=deepcopy(case['response']);value=bad['payload'][key]
            (value[0] if isinstance(value,list) else value)['unexpected']=1
            with self.subTest(shape=key): self.assertTrue(list(self.validator.iter_errors(bad)))
    def test_missing_nested_keys_rejected(self):
        for case,key,item in self.samples():
            bad=deepcopy(case['response']);value=bad['payload'][key];value=value[0] if isinstance(value,list) else value
            del value[next(iter(item))]
            with self.subTest(shape=key): self.assertTrue(list(self.validator.iter_errors(bad)))
    def test_wrong_nested_types_rejected(self):
        mutations={'public_signatures':('exposure_count',True),'opponents':('match_count',True),
            'freshness':('stale','false'),'recommendations':('score','0.5'),'hidden_slots':('position',0),
            'ambiguity':('variant_defense_possible',0),'evidence_summary':('included_snapshot_count',False)}
        for case,key,_ in self.samples():
            bad=deepcopy(case['response']);value=bad['payload'][key];value=value[0] if isinstance(value,list) else value
            field,wrong=mutations[key];value[field]=wrong
            with self.subTest(shape=key): self.assertTrue(list(self.validator.iter_errors(bad)))
    def test_nested_candidate_and_component_keys_are_strict(self):
        for case in self.cases:
            p=case['response']['payload']
            if p.get('hidden_slots'):
                bad=deepcopy(case['response']);bad['payload']['hidden_slots'][0]['candidates'][0]['extra']=None
                self.assertTrue(list(self.validator.iter_errors(bad)))
            if p.get('recommendations'):
                bad=deepcopy(case['response']);bad['payload']['recommendations'][0]['score_components']['extra']=0
                self.assertTrue(list(self.validator.iter_errors(bad)))

if __name__=='__main__': unittest.main()
