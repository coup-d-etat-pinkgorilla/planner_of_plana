"""Regression tests: synthetic fixture only; no game/external store access."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from core.client_data_store import ClientDataStore, ClientDataStoreError, _relative

FIXTURE=Path(__file__).parent/'fixtures/client_data_store_m1.json'


class ClientDataStoreM1Tests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.store=self.root/'synthetic-store'
        self.fixture=json.loads(FIXTURE.read_text(encoding='utf-8'))
        self.lock=deepcopy(self.fixture['lock'])
        self.lock_path=self.root/'ba-data.lock'
        for rel,text in self.fixture['files'].items():
            p=self.store/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(text.encode('utf-8'))
        self.write_lock()

    def write_lock(self):
        self.lock_path.write_text(json.dumps(self.lock),encoding='utf-8')

    def reader(self): return ClientDataStore(self.lock_path,self.store)

    def assert_code(self,code,call):
        with self.assertRaises(ClientDataStoreError) as raised: call()
        self.assertEqual(code,raised.exception.code)

    def snapshot(self):
        return {p.relative_to(self.root).as_posix():p.read_bytes() for p in self.root.rglob('*') if p.is_file()}

    def refs(self):
        return {'server':'jp','version_id':'jp-test-a'},{'server':'jp','version_id':'jp-test-b'}

    def rewrite_provenance(self,mutate):
        p=self.store/'extracts/jp/jp-test-a/exceldb-json/provenance.json'
        value=json.loads(p.read_text()); mutate(value)
        raw=json.dumps(value).encode(); p.write_bytes(raw)
        self.lock['extracts'][0]['provenance_sha256']=hashlib.sha256(raw).hexdigest()
        self.write_lock()

    def test_pinned_read_versions_and_existing_diff_do_not_write_or_open_installed_files(self):
        before=self.snapshot(); original=Path.read_bytes; accesses=[]
        def observed(p):
            accesses.append(p)
            self.assertNotIn('TEST_ONLY_DO_NOT_OPEN',str(p))
            return original(p)
        with patch.object(Path,'read_bytes',observed):
            reader=self.reader()
            self.assertEqual('jp-test-a',reader.status()['pins']['jp']['version_id'])
            self.assertEqual([{'id':11,'school':'TEST_A'}],reader.read_json_extract('jp','exceldb-json','CharacterExcel.json')['data_list'])
            self.assertEqual(2,len(reader.versions()['versions']))
            result=reader.diff(*self.refs())
            self.assertEqual('available',result['state'])
            self.assertEqual(self.fixture['expected_diff'],result['report'])
        self.assertEqual(before,self.snapshot())
        self.assertFalse(any('/extracts/jp/jp-test-b/' in p.as_posix() for p in accesses))

    def test_missing_store_is_disconnected_with_no_fake_zero_diff(self):
        reader=ClientDataStore(self.lock_path,self.root/'missing-store')
        self.assertEqual('disconnected',reader.status()['state'])
        self.assertEqual({'state':'disconnected','versions':[]},reader.versions())
        result=reader.diff(*self.refs())
        self.assertEqual('disconnected',result['state']); self.assertIsNone(result['report'])

    def test_available_store_missing_report_is_distinct_from_disconnected(self):
        (self.store/'changelog/jp/jp-test-a__jp-test-b.json').unlink()
        result=self.reader().diff(*self.refs())
        self.assertEqual('missing',result['state']); self.assertIsNone(result['report'])

    def test_extract_payload_hash_mismatch_is_rejected_even_valid_json(self):
        p=self.store/'extracts/jp/jp-test-a/exceldb-json/CharacterExcel.json'
        p.write_bytes(p.read_bytes()+b' ')
        self.assert_code('store_hash_mismatch',lambda:self.reader().read_extract('jp','exceldb-json','CharacterExcel.json'))

    def test_provenance_hash_mismatch_precedes_decode(self):
        p=self.store/'extracts/jp/jp-test-a/exceldb-json/provenance.json'; p.write_bytes(b'not JSON')
        self.assert_code('store_hash_mismatch',lambda:self.reader().read_extract('jp','exceldb-json','CharacterExcel.json'))

    def test_mixed_extract_lock_version_is_rejected(self):
        self.lock['extracts'][0]['version_id']='jp-test-b'; self.write_lock()
        self.assert_code('store_mixed_version',self.reader)

    def test_claimed_mixed_provenance_is_rejected_even_after_lock_hash_refresh(self):
        self.rewrite_provenance(lambda p:p.update(version_id='jp-test-b'))
        self.assert_code('store_mixed_version',lambda:self.reader().read_extract('jp','exceldb-json','CharacterExcel.json'))

    def test_explicit_mismatched_import_claim_is_not_promoted_verified(self):
        self.rewrite_provenance(lambda p:p.update(hash_claims=[{'matches_client_manifest':False}]))
        self.assert_code('store_mixed_version',lambda:self.reader().read_extract('jp','exceldb-json','CharacterExcel.json'))

    def test_pinned_manifest_change_is_rejected_without_check_client(self):
        p=self.store/'clients/jp/jp-test-a/manifest.json'; value=json.loads(p.read_text())
        value['files']['GameAssembly.dll']['sha256']='0'*64; p.write_text(json.dumps(value))
        self.assert_code('store_hash_mismatch',lambda:self.reader().read_extract('jp','exceldb-json','CharacterExcel.json'))

    def test_missing_extract_and_unpinned_kind_are_explicit_errors(self):
        reader=self.reader()
        self.assert_code('store_unpinned_extract',lambda:reader.read_extract('jp','not-pinned','x.json'))
        (self.store/'extracts/jp/jp-test-a/exceldb-json/CharacterExcel.json').unlink()
        self.assert_code('store_missing_data',lambda:reader.read_extract('jp','exceldb-json','CharacterExcel.json'))

    def test_paths_reject_traversal_drive_backslash_ADS_and_reserved_device(self):
        for rel in ('../x','/x','C:/x','a\\b','a:b','a/../b','CON','file.','file '):
            with self.subTest(rel=rel):
                self.assert_code('store_invalid_path',lambda:_relative(self.store,rel))

    def test_resolved_symlink_escape_is_rejected_without_symlink_privilege(self):
        original=Path.resolve
        def resolve(p,*args,**kwargs):
            if p==self.store/'escape.json': return self.root/'outside.json'
            return original(p,*args,**kwargs)
        with patch.object(Path,'resolve',resolve):
            self.assert_code('store_invalid_path',lambda:_relative(self.store,'escape.json'))

    def test_report_wrong_requested_pair_server_and_malformed_JSON_are_rejected(self):
        p=self.store/'changelog/jp/jp-test-a__jp-test-b.json'
        for field,value in (('a','jp-other'),('b','jp-other'),('server','steam')):
            report=deepcopy(self.fixture['expected_diff']); report[field]=value; p.write_text(json.dumps(report))
            self.assert_code('store_mixed_version',lambda:self.reader().diff(*self.refs()))
        p.write_text('{bad JSON')
        self.assert_code('store_malformed_data',lambda:self.reader().diff(*self.refs()))

    def test_cross_server_request_and_manifest_identity_mismatch_are_rejected(self):
        a,b=self.refs(); b['server']='steam'; b['version_id']='steam-test-b'
        self.assert_code('store_mixed_version',lambda:self.reader().diff(a,b))
        p=self.store/'clients/jp/jp-test-b/manifest.json'; value=json.loads(p.read_text()); value['version_id']='jp-other'
        p.write_text(json.dumps(value))
        self.assert_code('store_mixed_version',lambda:self.reader().diff(*self.refs()))

    def test_duplicate_JSON_key_and_nonfinite_lock_are_rejected(self):
        for raw in ('{"schema":1,"schema":2}','{"schema":NaN}'):
            self.lock_path.write_text(raw)
            self.assert_code('store_malformed_data',self.reader)

    def test_report_path_escape_request_and_bad_UTC_timestamp_are_rejected(self):
        a,b=self.refs(); b['version_id']='../outside'
        self.assert_code('store_invalid_path',lambda:self.reader().diff(a,b))
        p=self.store/'changelog/jp/jp-test-a__jp-test-b.json'
        for stamp in ('not-time','2026-01-01T00:00:00','2026-01-01T00:00:00+09:00'):
            report=deepcopy(self.fixture['expected_diff']); report['generated_utc']=stamp
            p.write_text(json.dumps(report))
            self.assert_code('store_malformed_data',lambda:self.reader().diff(*self.refs()))

    def test_lock_shape_and_nullable_pin_metadata_are_explicit_errors(self):
        self.lock['pins']['jp']['client_version']=False; self.write_lock()
        self.assert_code('store_invalid_lock',self.reader)
        self.lock=deepcopy(self.fixture['lock']); self.lock['unexpected']=1; self.write_lock()
        self.assert_code('store_invalid_lock',self.reader)


if __name__=='__main__': unittest.main()
