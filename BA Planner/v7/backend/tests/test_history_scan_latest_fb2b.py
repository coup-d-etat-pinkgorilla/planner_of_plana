"""FB-2b memory contracts and actual repository/scanner/RPC/stdio regressions."""
from copy import deepcopy
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from core.current_history import empty_history, history_from_wire, summary, HistoryError
from core.history_scan_latest import query_scan_latest, scan_latest_request

ROOT = Path(__file__).resolve().parents[2]
PID = 'a' * 24
ENTRY_KEYS = {'sequence', 'recorded_at', 'session_id', 'scan_kind', 'inventory_scan_profile'}
RESULT_KEYS = {'profile_id', 'revision', 'history_sequence', 'last_scan_at', 'by_kind',
               'by_student_id', 'by_resource_key', 'by_kind_next_after_sequence'}

class HistoryScanLatestMemoryTests(unittest.TestCase):
    schema_directories = [ROOT / 'contracts']

    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((ROOT / 'contracts/fixtures/repository_history_scan_latest_v1.json').read_text(encoding='utf-8'))
        cls.cases = {case['id']: case for case in cls.fixture['valid_history_cases']}
        # The artifact runner supplies unchanged schemas separately, never copies a store.
        schemas = {}
        for directory in cls.schema_directories:
            for path in directory.glob('*.schema.json'):
                schemas[path.name] = json.loads(path.read_text(encoding='utf-8'))
        registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas.values())
        cls.protocol = Draft202012Validator(schemas['repository-protocol-v1.schema.json'], registry=registry)
        schema = schemas['repository-history-scan-latest-v1.schema.json']
        cls.request_schema = Draft202012Validator({**schema, '$ref': '#/$defs/request'}, registry=registry)
        cls.result_schema = Draft202012Validator({**schema, '$ref': '#/$defs/result'}, registry=registry)
        cls.history_schema = Draft202012Validator(schemas['current-history-v1.schema.json'], registry=registry)
        cls.schemas = schemas

    def query(self, case, **overrides):
        return query_scan_latest(PID, case['revision'], case['history'], {**case['request'], **overrides})

    def error(self, payload, reason='invalid_history_query'):
        with self.assertRaises(HistoryError) as caught:
            scan_latest_request(payload)
        self.assertEqual(caught.exception.reason, reason)

    def test_valid_full_history_fixture_results_and_schema(self):
        for case in self.cases.values():
            with self.subTest(case=case['id']):
                original = json.dumps(case['history'], sort_keys=True)
                if case['history'] is not None:
                    history_from_wire(case['history'])
                    self.history_schema.validate(case['history'])
                result = self.query(case)
                self.assertEqual(result, case['expected'])
                self.assertEqual(set(result), RESULT_KEYS)
                self.result_schema.validate(result)
                self.request_schema.validate(case['request'])
                for type_, value in (('request', case['request']), ('response', result)):
                    self.protocol.validate({'protocol': 1, 'id': case['id'], 'type': type_,
                                            'method': 'repository.history.scan_latest', 'payload': value})
                self.assertEqual(json.dumps(case['history'], sort_keys=True), original)

    def test_independent_metadata_oracles_are_separate_from_persisted_history(self):
        for case in self.fixture['metadata_policy_oracles']:
            with self.subTest(oracle=case['id']):
                self.assertIn('not_persisted_history', case['fixture_kind'])
                model = deepcopy(case['model'])
                # Four metadata fields only. Never validate this projection as full history.
                h = None if not model['history_recorded'] else {
                    'next_sequence': model['history_sequence']+1,
                    'last_applied_at': {'scan': model['last_scan_at']},
                    'latest_scans': model['latest_scans']}
                before = deepcopy(h)
                expected = case['expected']
                if 'payload' in expected:
                    result = query_scan_latest(PID, model['revision'], h, case['request'])
                    self.assertEqual(result, expected['payload'])
                    self.result_schema.validate(result)
                else:
                    with self.assertRaises(HistoryError) as caught:
                        query_scan_latest(PID, model['revision'], h, case['request'])
                    self.assertEqual(caught.exception.reason, expected['error']['reason'])
                self.assertEqual(h, before)

    def test_summary_thirteen_keys_preserves_twelve_existing_values(self):
        fixture = json.loads((ROOT / 'contracts/fixtures/current_history_v1.json').read_text(encoding='utf-8'))
        expected = fixture['summary']
        result = summary(PID, expected['revision'], fixture['cases'][1]['history'])
        self.assertEqual(result, expected)
        self.assertEqual(len(result), 13)
        for case in self.cases.values():
            got = summary(PID, case['revision'], case['history'])
            self.assertEqual(got['last_scan_at'] is None, got['total_counts']['scan'] == 0)

    def test_null_scan_time_keeps_requested_rows_and_empty_kind_list(self):
        for name in ('unrecorded_requested_row', 'empty_requested_row', 'manual_only_scan_time_null'):
            result = self.query(self.cases[name])
            self.assertIsNone(result['last_scan_at'])
            self.assertEqual(result['by_kind'], [])
            self.assertEqual(len(result['by_student_id']) + len(result['by_resource_key']), 1)
        # Explicit boundary oracle with stale indices is not claimed to be valid history.
        projection = {'next_sequence': 4, 'last_applied_at': {'scan': None},
                      'latest_scans': deepcopy(self.cases['default_no_all_index']['history']['latest_scans'])}
        result = query_scan_latest(PID, 3, projection, {'profile_id': PID, 'student_ids': ['approved'], 'include_by_kind': True})
        self.assertEqual(result['by_kind'], [])
        self.assertIsNone(result['by_student_id'][0]['latest_scan'])

    def test_empty_filters_never_erase_profile_last_scan(self):
        result = self.query(self.cases['default_no_all_index'])
        self.assertIsNotNone(result['last_scan_at'])
        self.assertEqual([result[key] for key in ('by_kind', 'by_student_id', 'by_resource_key')], [[], [], []])

    def test_nochange_approved_freshness_excluded_prior_and_missing_null(self):
        case = self.cases['nochange_approved_excluded_unknown_alias']
        self.assertTrue(all(not e['student_changes'] and not e['inventory_changes'] for e in case['history']['events']))
        rows = self.query(case)['by_student_id']
        self.assertEqual([row['latest_scan']['sequence'] if row['latest_scan'] else None for row in rows], [3, 1, None])
        self.assertEqual(rows[-1]['reason'], 'scan_not_found')
        for row in rows[:2]:
            self.assertEqual(set(row['latest_scan']), ENTRY_KEYS)
            self.assertIsNone(row['reason'])

    def test_pruned_events_cannot_determine_latest_indices(self):
        case = self.cases['pruned_latest_index_keeps_old_scan']
        self.assertEqual(case['history']['baseline']['sequence'], 2)
        self.assertEqual([e['sequence'] for e in case['history']['events']], [3])
        result = self.query(case)
        self.assertEqual([entry['sequence'] for entry in result['by_kind']], [2, 3])
        self.assertEqual(result['by_student_id'][1]['latest_scan']['sequence'], 1)
        got = summary(PID, 3, case['history'])
        self.assertEqual((got['total_counts']['scan'], got['total_scan_session_count'], got['retained_scan_session_count']), (3, 2, 1))

    def test_clock_rollback_uses_apply_sequence_and_preserves_raw_nullable_metadata(self):
        result = self.query(self.cases['nochange_approved_excluded_unknown_alias'])
        self.assertEqual(result['last_scan_at'], '2026-10-10T11:00:00.000003Z')
        self.assertLess(result['last_scan_at'], result['by_resource_key'][0]['latest_scan']['recorded_at'])
        self.assertEqual([(s['scan_kind'], s['inventory_scan_profile']) for s in result['by_kind']], [(' B 새 ', ' ??? '), (' A未知 ', None)])
        self.assertEqual(result['by_kind'][-1]['session_id'], ' session 가나다 ')

    def test_kind_pages_seek_exclusive_latest_sequence_with_anchor(self):
        first = self.query(self.cases['first_kind_page_latest_sequence_order'])
        second = self.query(self.cases['second_kind_page_exclusive_anchor'])
        self.assertEqual([row['sequence'] for row in first['by_kind'] + second['by_kind']], [2, 3])
        self.assertEqual(first['by_kind_next_after_sequence'], 2)
        self.assertIsNone(second['by_kind_next_after_sequence'])

    def test_manual_apply_stales_anchor_while_goal_revision_does_not(self):
        case = self.cases['manual_revision_new_anchor_old_scan_time']
        before = deepcopy(case['history'])
        with self.assertRaises(HistoryError) as caught:
            self.query(case, anchor_history_sequence=3, by_kind_after_sequence=2)
        self.assertEqual(caught.exception.reason, 'stale_scan_latest')
        self.assertEqual(case['history'], before)
        self.assertEqual(self.query(self.cases['goal_revision_same_anchor'])['history_sequence'], 3)

    def test_defaults_raw_unicode_scalar_sort_and_alias_canonicalization(self):
        req = scan_latest_request({'profile_id': PID})
        self.assertEqual((req['student_ids'], req['resource_keys'], req['include_by_kind'], req['by_kind_limit']), ([], [], False, 100))
        ids = ['😀', '𐀀', ' \t ', 'unknown', 'aru']
        result = self.query(self.cases['default_no_all_index'], student_ids=ids,
                            resource_keys=['Item_Icon_SkillBook_Ultimate_Piece', ' raw unknown '])
        self.assertEqual([row['student_id'] for row in result['by_student_id']], sorted(ids))
        self.assertEqual([row['resource_key'] for row in result['by_resource_key']], [' raw unknown ', 'Item_Icon_SkillBook_Ultimate'])

    def test_duplicate_raw_and_canonical_alias_rejected(self):
        self.error({'profile_id': PID, 'student_ids': ['aru', 'aru']}, 'duplicate_identity')
        self.error({'profile_id': PID, 'resource_keys': ['Item_Icon_SkillBook_Ultimate_Piece', 'Item_Icon_SkillBook_Ultimate']}, 'duplicate_identity')

    def test_utf8_byte_limits_surrogate_and_target_count(self):
        for text in ('a'*1024, '😀'*256, ' '):
            self.assertEqual(scan_latest_request({'profile_id': PID, 'student_ids': [text]})['student_ids'], [text])
        for text in ('a'*1025, '😀'*256 + 'a', '\ud800', '\udfff', ''):
            self.error({'profile_id': PID, 'student_ids': [text]})
            self.error({'profile_id': PID, 'resource_keys': [text]})
        self.assertEqual(len(scan_latest_request({'profile_id': PID, 'student_ids': [str(i) for i in range(256)]})['student_ids']), 256)
        self.error({'profile_id': PID, 'student_ids': [str(i) for i in range(257)]})

    def test_exact_shape_type_optional_null_and_page_controls(self):
        bad = [None, [], {}, {'profile_id': PID, 'extra': 1}, {'profile_id': PID.upper()},
               {'profile_id': PID, 'student_ids': None}, {'profile_id': PID, 'resource_keys': 'x'},
               {'profile_id': PID, 'include_by_kind': 1}, {'profile_id': PID, 'by_kind_limit': 1}]
        for key, values in (('by_kind_limit', [True, 1.0, '1', None, 0, 201]),
                            ('by_kind_after_sequence', [True, 1.0, None, -1]),
                            ('anchor_history_sequence', [False, 1.0, None, -1])):
            bad.extend({'profile_id': PID, 'include_by_kind': True, key: value} for value in values)
        bad += [{'profile_id': PID, 'include_by_kind': True, 'by_kind_after_sequence': 1},
                {'profile_id': PID, 'include_by_kind': True, 'by_kind_after_sequence': 2, 'anchor_history_sequence': 1}]
        for value in bad:
            with self.subTest(value=value):
                self.error(value)
        self.assertEqual(scan_latest_request({'profile_id': PID, 'include_by_kind': True, 'by_kind_limit': 200})['by_kind_limit'], 200)

    def test_duplicate_kind_latest_sequence_is_new_endpoint_corrupt_without_repair(self):
        # All scans pruned; legacy validator accepts distinct kind identities at
        # same old sequence. Its behavior is preserved, not retroactively tightened.
        h = deepcopy(self.cases['manual_revision_new_anchor_old_scan_time']['history'])
        h['latest_scans']['by_kind'][0]['sequence'] = h['latest_scans']['by_kind'][1]['sequence']
        history_from_wire(h)
        original = deepcopy(h)
        for include in (False, True):
            with self.assertRaises(HistoryError) as caught:
                query_scan_latest(PID, 4, h, {'profile_id': PID, 'include_by_kind': include})
            self.assertEqual(caught.exception.reason, 'corrupt_data')
        self.assertEqual(h, original)

    def test_response_new_utf8_boundary_does_not_modify_legacy_validator(self):
        h = deepcopy(self.cases['manual_revision_new_anchor_old_scan_time']['history'])
        h['latest_scans']['by_kind'][0]['scan_kind'] = '\ud800'
        original = deepcopy(h)
        with self.assertRaises(HistoryError) as caught:
            query_scan_latest(PID, 4, h, {'profile_id': PID})
        self.assertEqual(caught.exception.reason, 'corrupt_data')
        self.assertEqual(h, original)

    def test_return_values_are_detached_and_repeated_reads_do_not_mutate_memory(self):
        case = self.cases['nochange_approved_excluded_unknown_alias']
        before = deepcopy(case)
        first = self.query(case)
        first['by_kind'].clear()
        first['by_student_id'][0]['latest_scan']['session_id'] = 'altered'
        self.assertEqual(case, before)
        self.assertEqual(self.query(case), case['expected'])

    def test_schema_documents_valid_exact_summary_and_error_envelopes(self):
        for name in ('repository-history-scan-latest-v1.schema.json', 'repository-protocol-v1.schema.json'):
            Draft202012Validator.check_schema(self.schemas[name])
        fixture = json.loads((ROOT / 'contracts/fixtures/current_history_v1.json').read_text(encoding='utf-8'))
        for case in fixture['messages']:
            self.assertEqual(not list(self.protocol.iter_errors(case['message'])), case['valid'], case['id'])
        good = {'protocol': 1, 'id': 'test', 'type': 'response', 'method': 'repository.history.scan_latest',
                'payload': {'error': {'code': 'invalid_payload', 'message': 'History changed', 'retryable': False,
                                      'details': {'reason': 'stale_scan_latest'}}}}
        self.protocol.validate(good)
        response = self.query(self.cases['default_no_all_index'])
        for mutation in ('extra', 'missing'):
            bad = deepcopy(response)
            if mutation == 'extra': bad['extra'] = True
            else: del bad['last_scan_at']
            self.assertTrue(list(self.result_schema.iter_errors(bad)))


# Actual applied-source integration below. Synthetic scanner sessions use the
# accepted S-FB2b fixture factory, never an OS scanner/runtime factory.
from datetime import datetime, timezone
import subprocess
import sys
import tempfile
from unittest.mock import patch

from core.application_protocol_v1 import ApplicationProtocolV1
from core.current_history import apply_event, append_history, projection
from core.repository_dto import canonical_json
from core.repository_store import JsonRepository, RepositoryError
from core.repository_transaction import write_transaction, JOURNAL
from tests import test_scanner_commit_history_sfb2b as sfb

class HistoryScanLatestActualTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture = json.loads((ROOT / 'contracts/fixtures/repository_history_scan_latest_v1.json').read_text(encoding='utf-8'))
        cls.cases = {case['id']: case for case in fixture['valid_history_cases']}
        schemas = {p.name: json.loads(p.read_text(encoding='utf-8')) for p in (ROOT/'contracts').glob('*.schema.json')}
        registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas.values())
        cls.protocol_schema = Draft202012Validator(schemas['repository-protocol-v1.schema.json'], registry=registry)

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.clock_calls = 0
        def clock():
            self.clock_calls += 1
            return datetime(2026,10,10,10,0,tzinfo=timezone.utc)
        self.repo = JsonRepository(self.root, id_factory=lambda: PID, clock=clock)
        self.pid = self.repo.create_profile('FB-2b actual synthetic', 'create')['profile']['profile_id']

    def snapshot(self, root=None):
        root = root or self.root
        return {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob('*')
                if p.is_file() and '.repository.' not in p.name}

    def install(self, name):
        case = deepcopy(self.cases[name])
        # create_profile derives its stable ID from the creation key, rather
        # than id_factory; adapt only this persisted fixture's query/expectation.
        case['request']['profile_id'] = self.pid
        case['expected']['profile_id'] = self.pid
        history = case['history']
        current = {k: deepcopy(history['baseline'][k]) for k in ('students','inventory')}
        for event in history['events']:
            current = apply_event(current, event)
        profile_path = self.repo._profile_path(self.pid)
        value = json.loads(profile_path.read_text(encoding='utf-8'))
        value.update(revision=case['revision'], current_history=history,
                     students=[{'version':1, **item} for item in current['students']],
                     inventory={'version':1,'entries':[{'key':row['resource_key'],'quantity':row['quantity']} for row in current['inventory']]})
        profile_path.write_text(canonical_json(value), encoding='utf-8')
        catalog = json.loads(self.repo.catalog_path.read_text(encoding='utf-8'))
        catalog['profiles'][0]['revision'] = case['revision']
        self.repo.catalog_path.write_text(canonical_json(catalog), encoding='utf-8')
        self.repo._profile(self.pid)  # Validate this is a full persisted fixture.
        return case

    def get(self, **fields):
        return self.repo.get_history_scan_latest({'profile_id': self.pid, **fields})

    def test_normal_reads_preserve_all_file_bytes_clock_cache_history_and_detach(self):
        case = self.install('nochange_approved_excluded_unknown_alias')
        before, clock = self.snapshot(), self.clock_calls
        with patch.object(self.repo, '_atomic_write', side_effect=AssertionError('Normal query wrote data')):
            first = self.repo.get_history_scan_latest(case['request'])
            self.assertEqual(first, case['expected'])
            first['by_kind'].clear()
            first['by_student_id'][0]['latest_scan']['session_id'] = 'mutated return'
            self.assertEqual(self.repo.get_history_scan_latest(case['request']), case['expected'])
        self.assertEqual((self.snapshot(),self.clock_calls), (before,clock))
        restarted = JsonRepository(self.root, clock=lambda: self.fail('Restart read sampled clock'))
        self.assertEqual(restarted.get_history_scan_latest(case['request']), case['expected'])
        self.assertEqual(self.snapshot(), before)

    def test_legacy_unrecorded_alias_inventory_has_no_migration_history_or_creation(self):
        path = self.repo._profile_path(self.pid)
        profile = json.loads(path.read_text(encoding='utf-8'))
        for key in ('current_history','plan','plan_authoring'):
            profile.pop(key,None)
        profile['inventory'] = {'version':1,'entries':[{'key':'Item_Icon_SkillBook_Ultimate_Piece','quantity':'7'}]}
        path.write_text(canonical_json(profile),encoding='utf-8')
        before, clock = self.snapshot(),self.clock_calls
        with patch.object(self.repo, '_ensure_plan_locked', side_effect=AssertionError('Migrated')):
            result = self.get(student_ids=['missing'], resource_keys=['Item_Icon_SkillBook_Ultimate_Piece'], include_by_kind=True)
        self.assertIsNone(result['last_scan_at'])
        self.assertEqual(result['by_kind'], [])
        self.assertEqual(result['by_resource_key'], [{'resource_key':'Item_Icon_SkillBook_Ultimate','latest_scan':None,'reason':'unrecorded'}])
        self.assertEqual(result['by_student_id'][0]['reason'],'unrecorded')
        self.assertEqual((self.snapshot(),self.clock_calls),(before,clock))

    def test_persisted_pruned_index_and_clock_rollback_survive_restart(self):
        for name in ('pruned_latest_index_keeps_old_scan','nochange_approved_excluded_unknown_alias'):
            with self.subTest(case=name):
                case = self.install(name)
                before = self.snapshot()
                reader = JsonRepository(self.root,clock=lambda:self.fail('Read clock'))
                result = reader.get_history_scan_latest(case['request'])
                self.assertEqual(result,case['expected'])
                self.assertEqual(reader.get_history_summary([self.pid])['profiles'][0]['last_scan_at'], result['last_scan_at'])
                self.assertEqual(self.snapshot(),before)

    def test_pages_anchor_preserved_for_goal_revision_and_stale_after_manual_apply(self):
        self.install('first_kind_page_latest_sequence_order')
        first = self.get(include_by_kind=True,by_kind_limit=1)
        self.assertEqual(first['by_kind_next_after_sequence'],2)
        self.repo.save_goals(self.pid,{'version':1,'goals':[]},first['revision'],'goal-only')
        second = self.get(include_by_kind=True,by_kind_limit=1,by_kind_after_sequence=2,
                          anchor_history_sequence=first['history_sequence'])
        self.assertEqual([x['sequence'] for x in second['by_kind']],[3])
        self.assertIsNone(second['by_kind_next_after_sequence'])
        self.assertEqual(second['history_sequence'],first['history_sequence'])
        self.assertGreater(second['revision'],first['revision'])
        profile = self.repo._profile(self.pid)
        self.repo.update_students(self.pid,profile['students'],profile['revision'],'manual',manual=True)
        before = self.snapshot()
        with self.assertRaises(RepositoryError) as caught:
            self.get(include_by_kind=True,by_kind_after_sequence=2,anchor_history_sequence=first['history_sequence'])
        self.assertEqual((caught.exception.code,caught.exception.details,caught.exception.retryable),
                         ('invalid_payload',{'reason':'stale_scan_latest'},False))
        self.assertEqual(self.get()['last_scan_at'],first['last_scan_at'])
        self.assertEqual(self.snapshot(),before)

    def test_existing_common_recovery_prepared_and_committed_before_query(self):
        for committed in (False, True):
            with self.subTest(committed=committed), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                repo = JsonRepository(root,id_factory=lambda:PID)
                pid = repo.create_profile('Recovery','create')['profile']['profile_id']
                path = repo._profile_path(pid)
                before = json.loads(path.read_text(encoding='utf-8'))
                after = deepcopy(before)
                state = projection(after['students'],after['inventory'])
                after['current_history'] = append_history(after['current_history'],state,state,source='manual',
                    recorded_at='2026-10-10T10:00:00.000000Z',revision_before=0,revision_after=1,catalog_revision=None)
                after['revision'] = 1
                class Stop(BaseException): pass
                def fault(stage):
                    if stage == ('journal_committed' if committed else 'profile_written'): raise Stop()
                with self.assertRaises(Stop):
                    write_transaction(root,[(path,after)],repo._atomic_write,fault,RepositoryError)
                self.assertTrue((root/JOURNAL).exists())
                reader = JsonRepository(root,clock=lambda:self.fail('Recovery query sampled clock'))
                result = reader.get_history_scan_latest({'profile_id':pid,'student_ids':['unknown']})
                self.assertEqual((result['revision'],result['history_sequence']),(1,1) if committed else (0,0))
                self.assertEqual(json.loads(path.read_text(encoding='utf-8')),after if committed else before)
                self.assertFalse((root/JOURNAL).exists())
                recovered = self.snapshot(root)
                self.assertEqual(reader.get_history_scan_latest({'profile_id':pid,'student_ids':['unknown']}),result)
                self.assertEqual(self.snapshot(root),recovered)

    def test_actual_unicode_scalar_e000_precedes_10000_and_invalid_surrogate_is_read_only(self):
        before, clock = self.snapshot(), self.clock_calls
        result = self.get(student_ids=['\U00010000','\ue000'],resource_keys=['\U00010000','\ue000'])
        for bucket,identity in (('by_student_id','student_id'),('by_resource_key','resource_key')):
            self.assertEqual([row[identity] for row in result[bucket]],['\ue000','\U00010000'])
        for bucket in ('student_ids','resource_keys'):
            for scalar in ('\ud800','\udfff'):
                with self.subTest(bucket=bucket,scalar=ascii(scalar)),self.assertRaises(RepositoryError) as caught:
                    self.get(**{bucket:[scalar]})
                self.assertEqual(caught.exception.code,'invalid_payload')
                self.assertFalse(caught.exception.retryable)
        self.assertEqual((self.snapshot(),self.clock_calls),(before,clock))

    def test_impossible_duplicate_kind_sequence_rejected_only_new_endpoint_without_repair(self):
        self.install('manual_revision_new_anchor_old_scan_time')
        path = self.repo._profile_path(self.pid)
        value = json.loads(path.read_text(encoding='utf-8'))
        entries = value['current_history']['latest_scans']['by_kind']
        entries[0]['sequence'] = entries[1]['sequence']
        path.write_text(canonical_json(value),encoding='utf-8')
        self.repo._profile(self.pid)  # Existing validator remains permissive.
        self.assertEqual(self.repo.get_history_summary([self.pid])['profiles'][0]['revision'],4)
        before = self.snapshot()
        for include in (False,True):
            with self.subTest(include=include),self.assertRaises(RepositoryError) as caught:
                self.get(include_by_kind=include)
            self.assertEqual(caught.exception.code,'corrupt_data')
            self.assertFalse(caught.exception.retryable)
        self.assertEqual(self.snapshot(),before)

    def setup_scanner(self,case):
        helper = sfb.ScannerCommitHistoryIntegrationTests(methodName='runTest')
        helper.fixture = json.loads((ROOT/'contracts/fixtures/scanner_commit_history_sfb2b_v1.json').read_text(encoding='utf-8'))
        self.addCleanup(helper.doCleanups)
        return helper.setup_case(case)

    def test_actual_sfb_approved_nochange_excluded_and_alias_freshness_matches_scope(self):
        fixture = json.loads((ROOT/'contracts/fixtures/scanner_commit_history_sfb2b_v1.json').read_text(encoding='utf-8'))
        for case in fixture['cases']:
            with self.subTest(case=case['id']):
                repo,port,service,request,case = self.setup_scanner(case)
                service.commit(**request)
                bucket = 'student_ids' if case['kind']=='student' else 'resource_keys'
                targets = sorted(set(case['applied_keys']+case['excluded_keys']+['never-approved']))
                query = {'profile_id':request['profile_id'],bucket:targets,'include_by_kind':True}
                result = repo.get_history_scan_latest(query)
                rows = result['by_student_id'] if bucket=='student_ids' else result['by_resource_key']
                identity = 'student_id' if bucket=='student_ids' else 'resource_key'
                mapping = {r[identity]:r for r in rows}
                for key in case['applied_keys']:
                    self.assertEqual(mapping[key]['latest_scan']['sequence'],2)
                    self.assertEqual(mapping[key]['latest_scan']['inventory_scan_profile'],case['raw_profile'])
                for key in case['excluded_keys']+['never-approved']:
                    self.assertIsNone(mapping[key]['latest_scan'])
                    self.assertEqual(mapping[key]['reason'],'scan_not_found')
                before = self.snapshot(repo.root)
                self.assertEqual(service.commit(**request)['revision'],2)
                restarted = JsonRepository(repo.root,clock=lambda:self.fail('Replay read clock'))
                self.assertEqual(restarted.get_history_scan_latest(query),result)
                self.assertEqual(self.snapshot(repo.root),before)
                self.assertEqual((port.reads,len(port.calls)),(1,1))

    def test_actual_sfb_response_loss_restart_replay_keeps_freshness_and_history_anchor(self):
        fixture = json.loads((ROOT/'contracts/fixtures/scanner_commit_history_sfb2b_v1.json').read_text(encoding='utf-8'))
        repo,port,service,request,case = self.setup_scanner(fixture['cases'][0])
        port.lose = True
        with self.assertRaises(OSError): service.commit(**request)
        query = {'profile_id':request['profile_id'],'student_ids':case['applied_keys'],'include_by_kind':True}
        after_apply = repo.get_history_scan_latest(query)
        before = self.snapshot(repo.root)
        port.repo = JsonRepository(repo.root,clock=lambda:self.fail('Durable replay clock'))
        self.assertEqual(service.commit(**request)['revision'],2)
        self.assertEqual(port.calls[0],port.calls[1])
        self.assertEqual(port.repo.get_history_scan_latest(query),after_apply)
        self.assertEqual(self.snapshot(repo.root),before)
        self.assertEqual(port.reads,1)

    def test_actual_application_route_error_envelopes_and_correlation(self):
        app = ApplicationProtocolV1(storage_root=self.root,scanner_service=None)
        self.addCleanup(app.close)
        before = self.snapshot()
        payloads = [{'profile_id':self.pid}, {'profile_id':'b'*24},
                    {'profile_id':self.pid,'resource_keys':['Item_Icon_SkillBook_Ultimate_Piece','Item_Icon_SkillBook_Ultimate']},
                    {'profile_id':self.pid,'student_ids':['\ud800']},
                    {'profile_id':self.pid,'include_by_kind':True,'anchor_history_sequence':1},
                    {'profile_id':self.pid,'extra':True}]
        for i,payload in enumerate(payloads):
            request = {'protocol':1,'id':f'fb2b-{i}','type':'request','method':'repository.history.scan_latest','payload':payload}
            response = app.handle(request)
            self.assertEqual((response['id'],response['method'],response['protocol'],response['type']),
                             (request['id'],request['method'],1,'response'))
            self.protocol_schema.validate(response)
            if i:
                self.assertEqual(response['payload']['error']['code'],'profile_not_found' if i==1 else 'invalid_payload')
                self.assertFalse(response['payload']['error']['retryable'])
        malformed = {'protocol':1,'id':'invalid-envelope','type':'request','method':'repository.history.scan_latest','payload':{},'extra':True}
        self.assertIsNone(app.handle(malformed))
        self.assertEqual(self.snapshot(),before)

    def test_actual_python_stdio_process_routes_new_method_and_utf8_without_scanner_factory(self):
        before = self.snapshot()
        payloads = [{'profile_id':self.pid,'student_ids':['\U00010000','\ue000',' 가나다 ']},
                    {'profile_id':self.pid,'student_ids':['\ud800']}]
        requests = [{'protocol':1,'id':f'stdio-{i}','type':'request','method':'repository.history.scan_latest','payload':p}
                    for i,p in enumerate(payloads)]
        child = "from pathlib import Path; import sys; from core.application_protocol_v1 import ApplicationProtocolV1; from core.stdio_server import serve; serve(protocol=ApplicationProtocolV1(storage_root=Path(sys.argv[1]),scanner_service=None))"
        result = subprocess.run([sys.executable,'-B','-X','utf8','-c',child,str(self.root)],
            cwd=ROOT/'backend',input=''.join(json.dumps(r,ensure_ascii=True)+'\n' for r in requests),
            capture_output=True,text=True,encoding='utf-8',timeout=20)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stderr,'')
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(len(responses),2)
        for request,response in zip(requests,responses):
            self.protocol_schema.validate(response)
            self.assertEqual((response['id'],response['method']),(request['id'],request['method']))
        self.assertEqual([r['student_id'] for r in responses[0]['payload']['by_student_id']],[' 가나다 ','\ue000','\U00010000'])
        self.assertEqual(responses[1]['payload']['error']['code'],'invalid_payload')
        self.assertEqual(self.snapshot(),before)

if __name__ == '__main__':
    unittest.main()
