"""Regression tests: M1 handler/envelope/legacy preservation regressions."""
from copy import deepcopy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator, FormatChecker, ValidationError
from referencing import Registry, Resource
from tools import developer_tools, metadata_manager_m1 as manager


class MetadataManagerM1Tests(unittest.TestCase):
    def test_contract_requests_responses_errors_and_diff_state_relations(self):
        contracts=Path(__file__).parents[2]/'contracts'
        schema=json.loads((contracts/'developer-tools-metadata-manager-v1.schema.json').read_text())
        asset=json.loads((contracts/'asset-map-v1.schema.json').read_text())
        Draft202012Validator.check_schema(schema)
        registry=Registry().with_resources([(s['$id'],Resource.from_contents(s)) for s in (schema,asset)])
        validator=Draft202012Validator(schema,registry=registry,format_checker=FormatChecker())
        fixture=json.loads((contracts/'fixtures/developer_tools_metadata_manager_m1_v1.json').read_text())
        for row in fixture['requests']: validator.validate(row['request'])
        for row in fixture['responses']: validator.validate(row['message'])
        validator.validate(fixture['envelope_error'])
        for message in fixture['diff_state_oracles']: validator.validate(message)
        for index in (0,2,3):
            with self.assertRaises(ValidationError): validator.validate(fixture['negative_requests'][index]['request'])
        for state,report in (('available',None),('missing',fixture['diff_state_oracles'][2]['result']['report'])):
            message=deepcopy(fixture['diff_state_oracles'][2]); message['result'].update(state=state,report=report)
            with self.assertRaises(ValidationError): validator.validate(message)
        message=deepcopy(fixture['responses'][0]['message']); message['result']['unexpected']=1
        with self.assertRaises(ValidationError): validator.validate(message)

    def test_existing_method_stays_available_without_store_or_new_module(self):
        expected={'students':[{'student_id':'test_student'}],'total':1,'fields':[]}
        with patch.dict(developer_tools.METHODS,{'metadata.list':lambda _:deepcopy(expected)}), patch.object(developer_tools,'_metadata_manager_m1',side_effect=AssertionError('Legacy call must not load M1')):
            self.assertEqual({'version':1,'ok':True,'result':expected},developer_tools.dispatch({'version':1,'method':'metadata.list','params':{}}))

    def test_existing_falsey_params_and_extra_envelope_keys_keep_legacy_dispatch(self):
        observed=[]
        with patch.dict(developer_tools.METHODS,{'metadata.list':lambda params:observed.append(params) or {}}), patch.object(developer_tools,'_metadata_manager_m1',side_effect=AssertionError('Legacy isolation')):
            for params in (None,False,[],0):
                developer_tools.dispatch({'version':1,'method':'metadata.list','params':params,'legacy_extra':True})
        self.assertEqual([{}, {}, {}, {}],observed)

    def test_new_only_strict_envelope_does_not_coerce_null_false_empty_list(self):
        for params in (None,False,[],0):
            with self.subTest(params=params), self.assertRaises(ValueError):
                developer_tools.dispatch({'version':1,'method':'store.status','params':params})
        with self.assertRaises(ValueError):
            developer_tools.dispatch({'version':True,'method':'store.status','params':{}})

    def test_main_preserves_existing_error_envelope_type_message_and_exit1(self):
        output=io.StringIO()
        with patch.object(developer_tools.sys,'stdin',io.StringIO('{bad')), patch.object(developer_tools.sys,'stdout',output):
            self.assertEqual(1,developer_tools.main())
        response=json.loads(output.getvalue())
        self.assertEqual({'version','ok','error'},set(response))
        self.assertEqual({'type','message'},set(response['error']))
        self.assertFalse(response['ok'])

    def test_metadata_effective_values_forms_and_null_keep_unknown_provenance(self):
        current={'student_id':'test_student','jp_only':False,'metadata':{'display_name':'가상 학생','school':None}}
        forms={'forms':[{'label':'TEST_ONLY'}]}
        result=manager.metadata_source_view({'student_id':'test_student'},lambda _:deepcopy(current),lambda _:deepcopy(forms))
        fields={r['field']:r for r in result['fields']}
        self.assertEqual('unknown',fields['metadata.school']['value_state'])
        self.assertFalse(fields['server_availability.jp_only']['value'])
        self.assertEqual(forms['forms'],fields['forms']['value'])
        for row in fields.values():
            self.assertIsNone(row['provenance']); self.assertEqual([],row['comparisons'])
        self.assertEqual('not_verified',result['comparison_state'])

    def test_new_params_reject_unknown_keys_and_local_student_path_escape(self):
        for params in ({'student_id':'../x'},{'student_id':'test_student','extra':1}):
            with self.assertRaises(ValueError): manager.metadata_source_view(params,lambda _:None,lambda _:None)

    def test_asset_check_local_missing_is_distinct_from_manual_and_M4(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); present=root/'frontend/assets/test.txt'; present.parent.mkdir(parents=True); present.write_text('TEST_ONLY')
            row={'plannerPath':'frontend/assets/test.txt','role':'ui','addressKey':None,'bundle':None,'textureName':None,'source':'manual','clientKind':'steam','note':'TEST_ONLY'}
            missing={**row,'plannerPath':'backend/assets/recognition/v1/missing.txt','role':'recognition'}
            payload={'version':1,'generatedAt':'2026-01-01T00:00:00Z','status':'M0-draft','inventory':{},'catalogs':[],'assets':[row,missing]}
            path=root/'asset-map.json'; path.write_text(json.dumps(payload)); before=path.read_bytes()
            result=manager.asset_map_check({'scope':'all'},path,root)
            self.assertEqual(['present','missing'],[r['local_file_state'] for r in result['rows']])
            self.assertEqual(['manual','manual'],[r['mapping_state'] for r in result['rows']])
            self.assertTrue(all(r['physical_state']=='not_verified' for r in result['rows']))
            self.assertEqual('M4_required',result['physical_validation'])
            self.assertEqual(1,len(manager.asset_map_check({'scope':'ui'},path,root)['rows']))
            self.assertEqual(before,path.read_bytes())

    def test_asset_scope_path_escape_duplicate_and_manual_mapping_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); path=root/'asset-map.json'
            row={'plannerPath':'frontend/assets/test.txt','role':'ui','addressKey':None,'bundle':None,'textureName':None,'source':'manual','clientKind':'steam','note':'TEST_ONLY'}
            payload={'version':1,'generatedAt':'2026-01-01T00:00:00Z','status':'M0-draft','inventory':{},'catalogs':[],'assets':[row]}
            path.write_text(json.dumps(payload))
            with self.assertRaises(ValueError): manager.asset_map_check({'scope':'physical_install'},path,root)
            for rows in ([{**row,'plannerPath':'../escape'}],[row,row],[{**row,'addressKey':'invented-key'}]):
                payload['assets']=rows; path.write_text(json.dumps(payload))
                with self.assertRaises(ValueError): manager.asset_map_check({'scope':'all'},path,root)


    def test_actual_stdio_six_methods_keep_disconnected_unknown_and_local_only_states(self):
        import os
        import subprocess
        import sys

        root = Path(__file__).parents[2]
        lock = json.loads((root / 'ba-data.lock').read_text(encoding='utf-8'))
        server, pin = next(iter(lock['pins'].items()))
        ref = {'server': server, 'version_id': pin['version_id']}
        requests = [
            ('store.status', {}), ('store.versions', {}),
            ('store.diff', {'from': ref, 'to': ref}),
            ('metadata.source.view', {'student_id': 'ayane'}),
            ('asset_map.list', {}), ('asset_map.check', {'scope': 'ui'}),
        ]
        schema = json.loads((root / 'contracts/developer-tools-metadata-manager-v1.schema.json').read_text(encoding='utf-8'))
        asset = json.loads((root / 'contracts/asset-map-v1.schema.json').read_text(encoding='utf-8'))
        registry = Registry().with_resources([(s['$id'], Resource.from_contents(s)) for s in (schema, asset)])
        validator = Draft202012Validator(schema, registry=registry, format_checker=FormatChecker())
        results = {}
        with tempfile.TemporaryDirectory() as temporary:
            env = dict(os.environ, BA_CLIENT_DATA_DIR=str(Path(temporary) / 'not-connected'))
            for method, params in requests:
                with self.subTest(method=method):
                    request = {'version': 1, 'method': method, 'params': params}
                    run = subprocess.run(
                        [sys.executable, '-B', '-X', 'utf8', 'tools/developer_tools.py'],
                        input=json.dumps(request).encode('utf-8'), capture_output=True,
                        cwd=root / 'backend', env=env, timeout=15,
                    )
                    self.assertEqual(0, run.returncode, run.stderr.decode('utf-8', 'replace')[-2000:])
                    message = json.loads(run.stdout.decode('utf-8'))
                    validator.validate(message)
                    self.assertTrue(message['ok'])
                    results[method] = message['result']
            malformed = {'version': 1, 'method': 'store.status', 'params': {}, 'extra': True}
            run = subprocess.run([sys.executable, '-B', '-X', 'utf8', 'tools/developer_tools.py'],
                                 input=json.dumps(malformed).encode('utf-8'), capture_output=True,
                                 cwd=root / 'backend', env=env, timeout=15)
            self.assertEqual(1, run.returncode)
            error = json.loads(run.stdout.decode('utf-8'))
            self.assertFalse(error['ok'])
            self.assertEqual({'type', 'message'}, set(error['error']))
            self.assertIn('invalid_params', error['error']['message'])
        self.assertEqual('disconnected', results['store.status']['state'])
        self.assertEqual({'state': 'disconnected', 'versions': []}, results['store.versions'])
        self.assertEqual('disconnected', results['store.diff']['state'])
        self.assertIsNone(results['store.diff']['report'])
        self.assertEqual('not_verified', results['metadata.source.view']['comparison_state'])
        self.assertTrue(all(row['provenance'] is None and row['comparisons'] == []
                            for row in results['metadata.source.view']['fields']))
        self.assertEqual('M4_required', results['asset_map.check']['physical_validation'])
        self.assertTrue(all(row['physical_state'] == 'not_verified'
                            for row in results['asset_map.check']['rows']))
        self.assertGreater(len(results['asset_map.list']['assets']), 0)


if __name__=='__main__': unittest.main()
