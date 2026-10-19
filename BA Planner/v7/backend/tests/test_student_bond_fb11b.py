from copy import deepcopy
import hashlib
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError
from referencing import Registry, Resource

from core import gift_meta, student_meta
from core.protocol_v1 import PlanningProtocolV1
from core.repository_dto import InventorySnapshot
from core.student_bond import calculate_bond, gift_affinity, required_experience
from core.student_bond_data import FAVOR_EXP_BY_RANK, GIFT_IDENTITIES, GROUP_BY_CHARACTER, PROVENANCE

ROOT = Path(__file__).parents[2]
CONTRACTS = ROOT / 'contracts'


class StudentBondTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = json.loads((CONTRACTS / 'fixtures/planning_student_bond_v1.json').read_text(encoding='utf-8'))['cases']
        schemas = [json.loads(p.read_text(encoding='utf-8')) for p in CONTRACTS.glob('*.schema.json')]
        registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas)
        cls.validator = Draft202012Validator(next(s for s in schemas if s['$id'].endswith('planning-student-calculate-v1.schema.json')), registry=registry)

    def test_real_policy_fixtures_schema_replay_and_growth_fields_unchanged(self):
        for case in self.cases:
            with self.subTest(case=case['name']):
                request = deepcopy(case['request'])
                before = deepcopy(request)
                self.validator.validate(request)
                response = PlanningProtocolV1().handle(request)
                self.validator.validate(response)
                self.assertEqual(case['response'], response)
                self.assertEqual(before, request)
                request['payload'].pop('bond')
                growth = PlanningProtocolV1().handle(request)['payload']
                self.assertEqual(growth, {k: v for k, v in response['payload'].items() if k != 'bond'})
                self.assertFalse(any(r['category'] == 'present' for r in growth['resources']))

    def test_rank_boundaries_and_one_based_groups(self):
        self.assertEqual(15, required_experience(1, 2, 1))
        self.assertEqual(45, required_experience(1, 3, 1))
        self.assertEqual(75, required_experience(1, 4, 1))
        self.assertEqual(150, required_experience(10, 12, 1))
        self.assertEqual(0, required_experience(100, 100, 1))
        self.assertEqual(FAVOR_EXP_BY_RANK[98][0], required_experience(99, 100, 1))
        with patch('core.student_bond.FAVOR_EXP_BY_RANK', ((15, 100), (30, 200))):
            self.assertEqual(300, required_experience(1, 3, 2))
        for group in (0, 2, True):
            with self.assertRaises(ValueError):
                required_experience(1, 3, group)

    def test_runtime_snapshot_matches_approved_rows_and_all_student_groups(self):
        evidence = json.loads((ROOT / 'docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json').read_text(encoding='utf-8'))
        rows = evidence['tables']['FavorLevelExcel']['rows']
        self.assertEqual(tuple(tuple(r['exp_type']) for r in rows), FAVOR_EXP_BY_RANK)
        digest = hashlib.sha256(json.dumps(rows, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(PROVENANCE['favor_rows_sha256'], digest)
        self.assertEqual('confirmed-per-level-required-exp', evidence['expTypeAnalysis']['status'])
        self.assertEqual({1}, {GROUP_BY_CHARACTER[student_meta.schaledb_id(s)] for s in student_meta.all_ids()})
        self.assertEqual(set(gift_meta.all_ids()), set(GIFT_IDENTITIES))

    def test_affinity_port_includes_universal_tags_only_for_a_match_and_caps_at_three(self):
        self.assertEqual((3, True), gift_affinity('aru', 5017))
        self.assertEqual((1, False), gift_affinity('aru', 5000))
        with patch('core.student_bond.student_meta.favor_item_tags', return_value=('A',)), patch('core.student_bond.student_meta.favor_item_unique_tags', return_value=('B',)), patch('core.student_bond.gift_meta.tags', return_value=('A', 'B', 'BC', 'Bc', 'ew')):
            self.assertEqual((4, True), gift_affinity('aru', 5000))
        with patch('core.student_bond.gift_meta.tags', return_value=('BC', 'Bc', 'ew')):
            self.assertEqual((1, False), gift_affinity('aru', 5000))

    def test_quantity_first_shortage_ceiling_and_unknown_quantities(self):
        normal = self.cases[1]['response']['payload']['bond']['plans']['normal']
        self.assertEqual([(5000, 6), (5017, 1)], [(r['gift_id'], r['required']) for r in normal['gifts']])
        self.assertEqual(180, normal['provided_exp'])
        self.assertEqual(0, normal['shortage'])
        large = self.cases[2]['response']['payload']['bond']['plans']['preferred_large']
        self.assertEqual(1, large['shortage'])
        unknown = self.cases[0]['response']['payload']['bond']
        self.assertIsNone(unknown['plans']['normal']['shortage'])
        self.assertIsNone(unknown['plans']['normal']['gifts'][0]['owned'])
        explicit_null = deepcopy(self.cases[0]['request'])
        key = unknown['plans']['normal']['gifts'][0]['resource_key']
        explicit_null['payload']['inventory']['entries'] = [{'key': key, 'quantity': None}]
        self.assertEqual(unknown, PlanningProtocolV1().handle(explicit_null)['payload']['bond'])
        payload = deepcopy(self.cases[2]['request']['payload'])
        payload['inventory']['entries'].reverse()
        self.assertEqual(self.cases[2]['response']['payload']['bond'], PlanningProtocolV1().handle({**self.cases[2]['request'], 'payload': payload})['payload']['bond'])

    def test_petting_no_daily_count_or_initial_wait_is_invented(self):
        for case in self.cases:
            bond = case['response']['payload']['bond']
            petting = bond['plans']['petting']
            self.assertIsNone(petting['available_count'])
            self.assertEqual('current_rank_start', bond['assumption'])
            self.assertEqual('immediate', petting['first_interaction'])
        petting = self.cases[0]['response']['payload']['bond']['plans']['petting']
        self.assertEqual((3, 6), (petting['required_count'], petting['minimum_hours']))
        one = calculate_bond('aru', 1, 2, InventorySnapshot(entries=()))['plans']['petting']
        self.assertEqual((1, 0), (one['required_count'], one['minimum_hours']))

    def test_unknown_current_group_or_preferred_gifts_stays_unavailable(self):
        missing = calculate_bond('missing', 1, 3, InventorySnapshot(entries=()))
        self.assertIsNone(missing['required_exp'])
        self.assertFalse(missing['plans']['normal']['available'])
        self.assertTrue(missing['warnings'])
        with patch('core.student_bond.gift_affinity', return_value=(1, False)):
            no_preference = calculate_bond('aru', 1, 3, InventorySnapshot(entries=()))
            self.assertFalse(no_preference['plans']['preferred_large']['available'])
            self.assertTrue(no_preference['plans']['normal']['available'])

    def test_strict_request_response_rejects_progress_and_unverified_counts(self):
        for bond in (None, {}, [], {'current_rank': True}, {'current_rank': 0}, {'current_rank': 101}, {'current_rank': '1'}, {'current_rank': 1, 'progress': 1}, {'current_rank': 1, 'target_rank': 3}):
            request = deepcopy(self.cases[0]['request'])
            request['payload']['bond'] = bond
            with self.assertRaises(ValidationError):
                self.validator.validate(request)
            self.assertEqual('invalid_payload', PlanningProtocolV1().handle(request)['payload']['error']['code'])
        for mutate in (
            lambda b: b.update(assumption='partial_rank'),
            lambda b: b.update(extra=0),
            lambda b: b['plans']['petting'].update(available_count=8),
            lambda b: b['plans']['normal']['gifts'][0].update(multiplier=True),
            lambda b: b.pop('required_exp'),
        ):
            response = deepcopy(self.cases[0]['response'])
            mutate(response['payload']['bond'])
            with self.assertRaises(ValidationError):
                self.validator.validate(response)


if __name__ == '__main__':
    unittest.main()
