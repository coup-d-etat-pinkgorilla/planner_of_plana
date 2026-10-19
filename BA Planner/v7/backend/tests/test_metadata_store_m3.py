"""M3 preview/store sync: synthetic registered store, no external source selection."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from core.canonical_metadata import CanonicalMetadataCatalog
from core.client_data_store import ClientDataStoreError
from core.student_stats_types import StudentStatsDataError
from jsonschema import Draft202012Validator, FormatChecker
from tests import test_client_data_store_m1 as m1
from tools.metadata_store_preview import preview, digest
from tools import export_canonical_metadata as export
from tools import sync_student_stats_from_extracted as sync


class MetadataStoreM3Tests(unittest.TestCase):
    def setUp(self):
        self.fixture = m1.ClientDataStoreM1Tests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        self.catalog = CanonicalMetadataCatalog.from_payload({
            'version': 1, 'students': {'local': {'display_name': 'KR manual', 'template_name': 'local.png',
                'group': 'local', 'school': 'old'}}, 'forms': {},
            'server_availability': {'jp_only_student_ids': []}, 'favorite_items': {'student_ids': [], 'max_tier': 'T2'},
            'provider_refs': {'schaledb': {'student_ids': {'local': 11}}},
            'gift_affinities': {'local': {'preferred_tags': ['frozen'], 'unique_tags': []}}})

    def crosswalk(self):
        reader = self.fixture.reader()
        return {'version': 1, 'lock_sha256': digest(reader.lock), 'catalog_sha256': digest(self.catalog.to_payload()),
            'students': {'local': {'row_id': 11, 'fields': {'school': {'source': 'school', 'values': {'"TEST_A"': 'new'}}}}}}

    def test_unreviewed_ids_are_candidates_and_never_removal_zero(self):
        before = self.fixture.snapshot()
        result = preview(self.catalog, self.fixture.reader())
        self.assertEqual(self.catalog.to_payload(), result['proposed_catalog'])
        self.assertEqual({}, result['projected_fields'])
        self.assertEqual('unverified-existing-crosswalk', result['candidate_associations'][0]['association'])
        self.assertIsNone(result['removal_comparison']['difference_count'])
        self.assertEqual('blocked', result['removal_comparison']['state'])
        self.assertEqual(before, self.fixture.snapshot())

    def test_explicit_projection_has_row_provenance_and_preserves_manual_sections(self):
        result = preview(self.catalog, self.fixture.reader(), self.crosswalk())
        self.assertEqual(1, result['selected_field_difference_count'])
        self.assertEqual('new', result['proposed_catalog']['students']['local']['school'])
        self.assertEqual('KR manual', result['proposed_catalog']['students']['local']['display_name'])
        for section in result['preserved_sections']:
            self.assertEqual(self.catalog.to_payload()[section], result['proposed_catalog'][section])
        schema = json.loads((Path(__file__).parents[2]/'contracts/metadata-provenance-v1.schema.json').read_text())
        validator = Draft202012Validator(schema, format_checker=FormatChecker())
        validator.validate(result['projected_fields']['students.local.school'])

    def test_wrong_lock_or_catalog_binding_rejected(self):
        for key in ('lock_sha256', 'catalog_sha256'):
            mapping = self.crosswalk(); mapping[key] = '0'*64
            with self.subTest(key=key), self.assertRaises(ValueError):
                preview(self.catalog, self.fixture.reader(), mapping)

    def test_bool_or_missing_row_and_unknown_student_rejected(self):
        for sid, row in (('local', True), ('local', 999), ('missing', 11)):
            mapping = self.crosswalk(); spec = mapping['students'].pop('local'); spec['row_id'] = row
            mapping['students'][sid] = spec
            with self.subTest(sid=sid, row=row), self.assertRaises(ValueError):
                preview(self.catalog, self.fixture.reader(), mapping)

    def test_wrong_source_unmapped_enum_and_wrong_type_rejected(self):
        for rule in ({'source': 'tags', 'values': {}}, {'source': 'school', 'values': {'999': 'new'}},
                     {'source': 'school', 'values': {'"TEST_A"': False}}):
            mapping = self.crosswalk(); mapping['students']['local']['fields']['school'] = rule
            with self.subTest(rule=rule), self.assertRaises(ValueError):
                preview(self.catalog, self.fixture.reader(), mapping)

    def test_gift_tags_cannot_be_projected_from_character_tags(self):
        mapping = self.crosswalk()
        mapping['students']['local']['fields'] = {'favor_item_tags': {'source': 'tags', 'values': {'[]': []}}}
        with self.assertRaises(ValueError): preview(self.catalog, self.fixture.reader(), mapping)

    def test_duplicate_rows_rejected(self):
        reader = self.fixture.reader()
        with patch.object(reader, 'read_json_extract', return_value={'data_list': [{'id':11},{'id':11}]}):
            with self.assertRaises(ValueError): preview(self.catalog, reader)

    def test_store_hash_failure_has_no_preview_or_source_write(self):
        path = self.fixture.store/'extracts/jp/jp-test-a/exceldb-json/CharacterExcel.json'
        path.write_text('{}')
        before = self.fixture.snapshot()
        with self.assertRaises(ClientDataStoreError): preview(self.catalog, self.fixture.reader())
        self.assertEqual(before, self.fixture.snapshot())

    def stats_store(self, bad_formula=False):
        ex = self.fixture.lock['extracts'][0]
        ex['kind'] = 'stats-fixture'
        ex['path'] = 'extracts/jp/jp-test-a/stats-fixture'
        (self.fixture.store/ex['path']).mkdir()
        records = []
        for source, target, _ in sync.PAIRS:
            raw = (Path(__file__).parents[1]/'data/student_stats/v1'/target).read_bytes()
            if bad_formula and target == 'formula.json': raw = b'{}'
            path = self.fixture.store/ex['path']/source
            path.write_bytes(raw)
            records.append({'path':source, 'sha256':hashlib.sha256(raw).hexdigest(), 'size':len(raw)})
        ex['files'] = {r['path']:r['sha256'] for r in records}
        prov = {'schema':'ba-client-data.extract-provenance.v1','server':'jp','version_id':'jp-test-a',
                'kind':ex['kind'],'client_manifest_files':self.fixture.lock['pins']['jp']['files'],
                'hash_claims':[],'files':records}
        raw = json.dumps(prov).encode()
        (self.fixture.store/ex['path']/'provenance.json').write_bytes(raw)
        ex['provenance_sha256'] = hashlib.sha256(raw).hexdigest()
        self.fixture.write_lock()

    def args(self, *extra):
        return ['sync', '--from-store', 'stats-fixture', '--lock', str(self.fixture.lock_path),
                '--store-root', str(self.fixture.store), '--output-dir', str(self.root/'output'), *extra]

    def test_from_store_dry_run_validates_both_and_writes_nothing(self):
        self.stats_store(); before = self.fixture.snapshot()
        with patch.object(sys, 'argv', self.args('--dry-run')): self.assertEqual(0, sync.main())
        self.assertEqual(before, self.fixture.snapshot())

    def test_from_store_sync_preserves_payload_bytes_and_provenance_validates(self):
        self.stats_store()
        with patch.object(sys, 'argv', self.args()): self.assertEqual(0, sync.main())
        schema = json.loads((Path(__file__).parents[2]/'contracts/metadata-provenance-v1.schema.json').read_text())
        validator = Draft202012Validator(schema, format_checker=FormatChecker())
        provenance = json.loads((self.root/'output/store-provenance.json').read_text())
        for source, target, _ in sync.PAIRS:
            self.assertEqual((self.fixture.store/self.fixture.lock['extracts'][0]['path']/source).read_bytes(),
                             (self.root/'output'/target).read_bytes())
            validator.validate(provenance[target])

    def test_invalid_second_document_preserves_old_output_bytes(self):
        self.stats_store(bad_formula=True)
        out=self.root/'output'; out.mkdir(); (out/'catalog.json').write_bytes(b'old')
        before = self.fixture.snapshot()
        with patch.object(sys, 'argv', self.args()), self.assertRaises(StudentStatsDataError): sync.main()
        self.assertEqual(before, self.fixture.snapshot())

    def test_unpinned_kind_rejected_without_fallback(self):
        before = self.fixture.snapshot()
        with self.assertRaises(ClientDataStoreError): sync.load_store_pairs(self.fixture.reader(), 'missing')
        self.assertEqual(before, self.fixture.snapshot())

    def test_source_flags_are_exclusive(self):
        with patch.object(sys, 'argv', self.args('--extracted', str(self.root))), self.assertRaises(SystemExit): sync.main()

    def test_export_store_path_requires_preview_and_cannot_apply_catalog(self):
        with patch.object(sys, 'argv', ['export', '--from-store']), self.assertRaises(SystemExit): export.main()

    def test_existing_extracted_directory_path_preserves_both_payloads(self):
        extracted = self.root/'legacy'; extracted.mkdir()
        for source, target, _ in sync.PAIRS:
            (extracted/source).write_bytes((Path(__file__).parents[1]/'data/student_stats/v1'/target).read_bytes())
        args=['sync','--extracted',str(extracted),'--output-dir',str(self.root/'output')]
        before=self.fixture.snapshot()
        with patch.object(sys,'argv',args+['--dry-run']): self.assertEqual(0,sync.main())
        self.assertEqual(before,self.fixture.snapshot())
        with patch.object(sys,'argv',args): self.assertEqual(0,sync.main())
        for source,target,_ in sync.PAIRS:
            self.assertEqual((extracted/source).read_bytes(),(self.root/'output'/target).read_bytes())
        self.assertFalse((self.root/'output/store-provenance.json').exists())

    def test_export_store_preview_creates_only_report(self):
        catalog=self.root/'frozen.json'; catalog.write_text(json.dumps(self.catalog.to_payload()))
        output=self.root/'preview.json'
        before=self.fixture.snapshot()
        args=['export','--from-store','--lock',str(self.fixture.lock_path),'--store-root',str(self.fixture.store),
              '--catalog',str(catalog),'--preview',str(output)]
        with patch.object(sys,'argv',args): self.assertEqual(0,export.main())
        output.unlink()
        self.assertEqual(before,self.fixture.snapshot())

    def test_store_sync_refuses_output_inside_store(self):
        self.stats_store();before=self.fixture.snapshot()
        with patch.object(sys,'argv',self.args('--output-dir',str(self.fixture.store/'output'))), self.assertRaisesRegex(ValueError,'outside'):
            sync.main()
        self.assertEqual(before,self.fixture.snapshot())

    def test_preview_refuses_catalog_lock_and_store_output(self):
        catalog=self.root/'frozen.json'; catalog.write_text(json.dumps(self.catalog.to_payload()))
        for destination in (catalog,self.fixture.lock_path,self.fixture.store/'report.json'):
            before=self.fixture.snapshot()
            args=['export','--from-store','--lock',str(self.fixture.lock_path),'--store-root',str(self.fixture.store),
                  '--catalog',str(catalog),'--preview',str(destination)]
            with self.subTest(destination=destination),patch.object(sys,'argv',args),self.assertRaises(SystemExit):export.main()
            self.assertEqual(before,self.fixture.snapshot())
