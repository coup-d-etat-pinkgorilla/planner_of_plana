from __future__ import annotations
import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.client_data_store_tools import diff_versions as diff
from tools.client_data_store_tools import register_client as register
from tools.client_data_store_tools._validation import contained
from tools.client_data_store_tools.row_identity import compare_rows, load_reviewed_keys, table_rows

FIXTURE_ROOT = None  # Artifact runner sets this; product tests use an ordinary synthetic temp root.
CAPTURE = None       # Optional artifact-only CLI receipt writer.


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def fingerprint(root):
    return {'dirs': sorted(str(path.relative_to(root)) for path in root.rglob('*') if path.is_dir()),
            'files': {str(path.relative_to(root)): {'bytes': path.stat().st_size,
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                      for path in sorted(root.rglob('*')) if path.is_file()}}


class StoreToolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(FIXTURE_ROOT or tempfile.mkdtemp(prefix='ba-store-tools-synthetic-'))
        cls.store = cls.root / 'store'
        cls.store.mkdir(parents=True, exist_ok=True)
        (cls.store / 'README.md').write_text('SYNTHETIC ONLY\n', encoding='utf-8')
        cls.a, cls.b = 'steam-r1-synthetic', 'steam-r2-synthetic'
        for identity in (cls.a, cls.b):
            write(cls.store / 'clients/steam' / identity / 'manifest.json', {
                'schema': 'ba-client-data.client-manifest.v1', 'server': 'steam', 'version_id': identity,
                'files': {'synthetic.dll': {'sha256': 'a'*64, 'size': 1}}})
        rows_a = [{'id':1,'value':'removed'}, {'id':2,'value':'old'}, {'id':3,'value':'same'}]
        rows_b = [{'id':2,'value':'new'}, {'id':3,'value':'same'}, {'id':4,'value':'added'}]
        for identity, rows in ((cls.a,rows_a),(cls.b,rows_b)):
            directory = cls.store / 'extracts/steam' / identity
            write(directory / 'exceldb-json/SyntheticExcel.json', {'data_list': rows})
            write(directory / 'common/provenance.json', {'files':[{'path':'synthetic.json','sha256':'a'*64}]})
            write(directory / ('removed-kind' if identity == cls.a else 'added-kind') / 'provenance.json', {'files':[]})
        cls.policy = cls.root / 'synthetic-reviewed-keys.json'
        write(cls.policy, {'schema':'ba-client-data.reviewed-row-keys.v1', 'tables':{
            'SyntheticExcel.json':{'id_key':'id','evidence':'Synthetic test-only identity review'}}})
        cls.client = cls.root / 'synthetic-install'
        cls.client.mkdir(parents=True, exist_ok=True)
        (cls.client / 'GameAssembly.dll').write_bytes(b'SYNTHETIC-NOT-A-CLIENT\n')
        metadata = cls.client / 'BlueArchive_Data/il2cpp_data/Metadata/global-metadata.dat'
        metadata.parent.mkdir(parents=True, exist_ok=True)
        metadata.write_bytes(b'SYNTHETIC-NOT-METADATA\n')
        table = cls.client / 'BlueArchive_Data/StreamingAssets/PUB/Resource/Preload/TableBundles'
        table.mkdir(parents=True, exist_ok=True)
        (table / 'Excel.zip').write_bytes(b'SYNTHETIC-NOT-A-ZIP\n')
        cls.output = cls.root / 'outside-output'
        cls.output.mkdir(parents=True, exist_ok=True)

    def args(self):
        return ['--server','steam','--a',self.a,'--b',self.b,'--store',str(self.store)]

    def register_args(self):
        return ['--server','steam','--root',str(self.client),'--revision','2','--store',str(self.store)]

    def invoke(self, function, args, receipt=None):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = function(args)
        if CAPTURE and receipt:
            CAPTURE(receipt, {'argv':args,'return':result,'stdout':stdout.getvalue(),'stderr':stderr.getvalue()})
        return result, stdout.getvalue()

    def test_01_stable_add_remove_change_each_one(self):
        result = compare_rows([{'id':1,'x':1},{'id':2,'x':1},{'id':3,'x':1}],
                              [{'id':2,'x':2},{'id':3,'x':1},{'id':4,'x':1}], 'id')
        self.assertEqual((result['rows_added'],result['rows_removed'],result['rows_changed']),(1,1,1))

    def test_02_self_identity_zero(self):
        rows=[{'id':1,'x':'a'},{'id':2,'x':'b'}]
        result=compare_rows(rows,rows,'id')
        self.assertEqual((result['status'],result['rows_added'],result['rows_removed'],result['rows_changed']),('same',0,0,0))

    def test_03_identity_order_ignored(self):
        rows=[{'id':1},{'id':2}]
        self.assertEqual(compare_rows(rows,list(reversed(rows)),'id')['status'],'same')

    def test_04_int_and_string_ids_do_not_collapse(self):
        result=compare_rows([{'id':1},{'id':'1'}],[{'id':'1'}],'id')
        self.assertEqual((result['rows_removed'],result['rows_changed']),(1,0))

    def test_05_duplicate_a_rejected_without_fallback(self):
        result=compare_rows([{'id':1},{'id':1}],[{'id':1}],'id')
        self.assertEqual(result['status'],'invalid_identity')
        self.assertIsNone(result['rows_changed'])
        self.assertEqual(result['identity_errors'][0]['reason'],'duplicate_id')

    def test_06_duplicate_b_rejected(self):
        self.assertEqual(compare_rows([], [{'id':2},{'id':2}], 'id')['status'],'invalid_identity')

    def test_07_missing_id_rejected(self):
        result=compare_rows([{'value':1}],[],'id')
        self.assertEqual(result['identity_errors'],[{'side':'a','row':0,'reason':'missing_id'}])

    def test_08_invalid_id_types_rejected(self):
        for identity in (None,True,1.0,[],{},''):
            with self.subTest(identity=identity):
                self.assertEqual(compare_rows([{'id':identity}],[],'id')['status'],'invalid_identity')

    def test_09_no_key_keeps_set_hash_and_changed_unknown(self):
        result=compare_rows([{'x':1}],[{'x':2}])
        self.assertEqual((result['rows_added'],result['rows_removed'],result['rows_changed']),(1,1,None))
        self.assertEqual(result['comparison_mode'],'row_set_hash')

    def test_10_no_key_duplicate_multiplicity_is_labeled(self):
        result=compare_rows([{'x':1},{'x':1}],[{'x':1}])
        self.assertEqual((result['status'],result['duplicate_rows_a']),('same',1))
        self.assertIn('multiplicity',result['limitation'])

    def test_11_arrays_and_both_wrappers_supported(self):
        for number,obj in enumerate(([{'x':1}],{'data_list':[{'x':1}]},{'rows':[{'x':1}]})):
            path=self.root/f'rows-{number}.json'
            write(path,obj)
            self.assertEqual(table_rows(path),[{'x':1}])

    def test_12_invalid_rows_shape_rejected(self):
        path=self.root/'invalid-rows.json'
        write(path,{'data_list':{}})
        with self.assertRaises(ValueError): table_rows(path)

    def test_13_default_policy_empty(self):
        self.assertEqual(load_reviewed_keys(None),{})

    def test_14_reviewed_explicit_policy(self):
        self.assertEqual(load_reviewed_keys(self.policy),{'SyntheticExcel.json':'id'})

    def test_15_duplicate_policy_object_key_rejected(self):
        path=self.root/'duplicate-policy.json'
        path.write_text('{"schema":"a","schema":"b","tables":{}}',encoding='utf-8')
        with self.assertRaises(ValueError): load_reviewed_keys(path)

    def test_16_unreviewed_or_escape_policy_rejected(self):
        for number,record in enumerate(({'id_key':'id','evidence':''},{'id_key':'a.b','evidence':'x'})):
            path=self.root/f'invalid-policy-{number}.json'
            write(path,{'schema':'ba-client-data.reviewed-row-keys.v1','tables':{'Synthetic.json':record}})
            with self.assertRaises(ValueError): load_reviewed_keys(path)

    def test_17_kind_union_reports_both_absent_sides(self):
        result=diff.build_report(self.store,'steam',self.a,self.b,load_reviewed_keys(self.policy),generated_utc='2026-10-10T00:00:00+00:00')
        kinds=result['level2_extracts']
        self.assertEqual(kinds['removed-kind']['status'],'only_in_a')
        self.assertEqual(kinds['added-kind']['status'],'only_in_b')
        self.assertEqual(kinds['exceldb-json']['SyntheticExcel.json']['rows_changed'],1)
        self.assertTrue(result['level3_behavior'].startswith('NOT_COMPUTED'))
        self.assertEqual(len(result),8)

    def test_18_same_version_all_differences_zero(self):
        result=diff.build_report(self.store,'steam',self.a,self.a,load_reviewed_keys(self.policy))
        self.assertTrue(all(value=='same' for value in result['level1_files'].values()))
        table=result['level2_extracts']['exceldb-json']['SyntheticExcel.json']
        self.assertEqual((table['rows_added'],table['rows_removed'],table['rows_changed']),(0,0,0))
        for name in ('common','removed-kind'):
            self.assertEqual(result['level2_extracts'][name]['changed'],[])
            self.assertEqual(result['level2_extracts'][name]['only_in_a'],[])
            self.assertEqual(result['level2_extracts'][name]['only_in_b'],[])

    def test_19_cross_server_version_rejected(self):
        with self.assertRaises(ValueError): diff.build_report(self.store,'steam','jp-synthetic',self.b)

    def test_20_version_path_escape_rejected(self):
        with self.assertRaises(ValueError): diff.build_report(self.store,'steam','../steam-escape',self.b)

    def test_21_manifest_identity_mismatch_rejected(self):
        with patch.object(diff,'read_json',return_value={'server':'jp','version_id':self.a,'files':{}}):
            with self.assertRaises(ValueError): diff.build_report(self.store,'steam',self.a,self.b)

    def test_22_resolved_escape_rejected(self):
        with self.assertRaises(ValueError): contained(self.store,'..','outside')

    def test_23_stdout_has_no_writes_or_mkdir(self):
        before=fingerprint(self.store)
        with patch.object(Path,'mkdir',side_effect=AssertionError('mkdir forbidden')), patch.object(diff,'write_json',side_effect=AssertionError('store write forbidden')):
            status,stdout=self.invoke(diff.main,self.args()+['--stdout','--id-keys',str(self.policy)],'diff-stdout')
        self.assertEqual(status,0)
        self.assertEqual(json.loads(stdout)['schema'],'ba-client-data.changelog.v1')
        self.assertEqual(before,fingerprint(self.store))

    def test_24_out_writes_one_new_external_report_no_mkdir(self):
        before=fingerprint(self.store)
        with patch.object(Path,'mkdir',side_effect=AssertionError('mkdir forbidden')), patch.object(diff,'write_json',side_effect=AssertionError('store write forbidden')):
            status,stdout=self.invoke(diff.main,self.args()+['--out',str(self.output)],'diff-out')
        self.assertEqual(status,0)
        result=json.loads(stdout)
        self.assertIs(result['store_written'],False)
        self.assertTrue(Path(result['written']).is_file())
        self.assertEqual(before,fingerprint(self.store))

    def test_25_out_inside_store_rejected(self):
        with self.assertRaises(SystemExit): self.invoke(diff.main,self.args()+['--out',str(self.store)])

    def test_26_out_does_not_create_missing_directory(self):
        path=self.root/'must-not-be-created'
        with self.assertRaises(SystemExit): self.invoke(diff.main,self.args()+['--out',str(path)])
        self.assertFalse(path.exists())

    def test_27_out_does_not_overwrite(self):
        directory=self.root/'preexisting-output'
        directory.mkdir(exist_ok=True)
        path=directory/f'{self.a}__{self.b}.json'
        path.write_text('SYNTHETIC-PRESERVE\n',encoding='utf-8')
        before=path.read_bytes()
        with self.assertRaises(SystemExit): self.invoke(diff.main,self.args()+['--out',str(directory)])
        self.assertEqual(before,path.read_bytes())

    def test_28_register_dryrun_no_write_mkdir_or_archive(self):
        before=fingerprint(self.store)
        with patch.object(Path,'mkdir',side_effect=AssertionError('mkdir forbidden')), patch.object(register,'write_json',side_effect=AssertionError('register forbidden')), patch.object(register.shutil,'copyfile',side_effect=AssertionError('copy forbidden')):
            status,stdout=self.invoke(register.main,self.register_args()+['--dry-run','--archive'],'register-dry-run')
        result=json.loads(stdout)
        self.assertEqual((status,result['action'],result['written'],result['archive_written']),(0,'WOULD_REGISTER',False,False))
        self.assertEqual(result['would_archive'],['Excel.zip','global-metadata.dat'])
        self.assertEqual(result['candidate_manifest']['archive'],[])
        self.assertEqual(before,fingerprint(self.store))

    def test_29_registered_preview_stops_and_timestamp_is_ignored(self):
        # Pure helper with an explicit synthetic existing manifest; never runs registration.
        manifest={'schema':'ba-client-data.client-manifest.v1','server':'steam','version_id':self.a,
                  'registered_utc':'new','files':{},'archive':[]}
        existing={**manifest,'registered_utc':'old','archive':['Excel.zip']}
        with patch.object(register,'read_json',return_value=existing):
            result=register.registration_preview(self.store,manifest,{},False)
        self.assertEqual((result['action'],result['would_register']),('STOP_ALREADY_REGISTERED',False))
        self.assertIs(result['content_match_ignoring_registration_time_and_archive'],True)

    def test_30_register_escape_revision_rejected(self):
        with self.assertRaises(SystemExit):
            self.invoke(register.main,self.register_args()+['--revision','../escape','--dry-run'])

    def test_31_legacy_diff_summary_and_write_are_preserved(self):
        with patch.object(diff,'write_json',return_value=True) as writer:
            status,stdout=self.invoke(diff.main,self.args(),'diff-legacy-mocked')
        self.assertEqual(status,0)
        self.assertIn('"level2_kinds"',stdout)
        self.assertIn('wrote ',stdout)
        self.assertEqual(writer.call_args.args[0],self.store/'changelog/steam'/f'{self.a}__{self.b}.json')
        self.assertEqual(writer.call_args.kwargs,{'overwrite':True})

    def test_32_legacy_register_summary_and_write_are_preserved(self):
        with patch.object(register,'write_json',return_value=True) as writer:
            status,stdout=self.invoke(register.main,self.register_args(),'register-legacy-mocked')
        result=json.loads(stdout)
        self.assertEqual((status,set(result),result['written']),(0,{'version_id','written','files'},True))
        self.assertEqual(writer.call_count,1)
        self.assertEqual(writer.call_args.args[1]['archive'],[])

    def test_33_one_side_table_reports_added_rows(self):
        left,right=self.root/'one-side-left',self.root/'one-side-right'
        left.mkdir(exist_ok=True); right.mkdir(exist_ok=True)
        write(right/'Known.json',{'data_list':[{'id':1}]})
        result=diff.diff_exceldb(left,right,{'Known.json':'id'})['Known.json']
        self.assertEqual((result['status'],result['rows_added'],result['rows_removed'],result['rows_changed']),('only_in_b',1,0,0))

    def test_34_type_count_behavior_preserved(self):
        left,right=self.root/'types-left',self.root/'types-right'
        write(left/'types.json',[{'name':'T','methods':[],'fields':[]}])
        write(right/'types.json',[{'name':'T','methods':[{}],'fields':[]}])
        self.assertEqual(diff.diff_types(left,right)['changed_count'],1)

    def test_35_policy_requires_evidence_and_no_path_keys(self):
        path=self.root/'escape-policy.json'
        write(path,{'schema':'ba-client-data.reviewed-row-keys.v1','tables':{'../Known.json':{'id_key':'id','evidence':'x'}}})
        with self.assertRaises(ValueError): load_reviewed_keys(path)


if __name__ == '__main__':
    unittest.main()
