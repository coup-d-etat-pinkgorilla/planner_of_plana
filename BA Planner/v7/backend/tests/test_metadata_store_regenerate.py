"""Reviewed regeneration: synthetic source decisions and immutable staging."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from core.canonical_metadata import CanonicalMetadataCatalog
from tools.metadata_store_preview import digest
from tools import metadata_store_regenerate as generator


class Reader:
    def __init__(self, source):
        self.lock = {'pins': {'jp': {'version_id': 'jp-test'}}}
        self.source = source

    def read_json_extract(self, server, kind, name):
        assert server == 'jp'
        if kind == 'exceldb-json':
            return {'data_list': [{'id': 11, 'school': 'TEST'}]}
        assert kind == 'gift-affinity'
        return deepcopy(self.source)


class RegenerateTests(unittest.TestCase):
    def setUp(self):
        self.catalog = CanonicalMetadataCatalog.from_payload({
            'version': 1, 'students': {'local': {'display_name': 'KR retained',
                'template_name': 'local.png', 'group': 'local', 'school': 'translated'}},
            'forms': {'local': [{'display_name': 'manual form'}]},
            'server_availability': {'jp_only_student_ids': ['local']},
            'favorite_items': {'student_ids': ['local'], 'max_tier': 'T2'},
            'provider_refs': {'schaledb': {'student_ids': {'local': 11}}},
            'gift_affinities': {'local': {'preferred_tags': ['B', 'A'], 'unique_tags': []}}})
        self.source = {'schema': 'ba-planner.gift-affinity-source.v1', 'server': 'jp', 'versionId': 'jp-test',
            'd_enumComparison': {'Tag': {'equal': True, 'jp': {'A': 1, 'B': 2}}},
            'a_characterAcademyTags': {'rowCount': 1, 'rows': [{'characterId': 11, 'rowSha': 'a'*64,
                'favorItemTags': [1, 2], 'favorItemTagNames': ['A', 'B'],
                'favorItemUniqueTags': [], 'favorItemUniqueTagNames': []}]},
            'b_favorItems': {'rowCount': 1, 'rows': [{'id': 5000, 'rowSha': 'b'*64,
                'tags': [1, 2], 'tagNames': ['A', 'B']}]}}
        self.reader = Reader(self.source)
        self.crosswalk = {'version': 1, 'lock_sha256': digest(self.reader.lock),
            'catalog_sha256': digest(self.catalog.to_payload()), 'students': {'local': {'row_id': 11,
                'fields': {'school': {'source': 'school', 'values': {'"TEST"': 'translated'}}}}}}
        self.frozen = {'schemaVersion': 1, 'gifts': {'5000': {'exp_value': 20,
            'provenance': {'kind': 'approved-frozen', 'versionId': 'frozen-test',
                'table': 'GIFT_ITEMS', 'rowSha': 'c'*64, 'tool': 'test'}}}}
        self.gifts = {5000: {'id': 5000, 'category': 'Favor', 'tags': ['B', 'A'], 'exp_value': 20}}
        self.stats_patch = patch.object(generator, 'load_store_pairs', return_value=[
            ('synthetic', 'catalog.json', b'{"catalog":"TEST_ONLY"}', SimpleNamespace(students={11:object(),12:object()})),
            ('synthetic', 'formula.json', b'{"formula":"TEST_ONLY"}', object())])
        self.stats_patch.start()
        self.addCleanup(self.stats_patch.stop)

    def generate(self):
        return generator.regenerate(self.catalog, self.reader, self.crosswalk, self.frozen, self.gifts)

    def test_complete_values_preserve_manual_forms_server_order_and_inputs(self):
        before = deepcopy((self.catalog.to_payload(), self.crosswalk, self.frozen, self.gifts, self.source))
        result = self.generate()
        self.assertEqual(result['catalog'].to_payload(), self.catalog.to_payload())
        self.assertEqual(result['gifts'], self.gifts)
        self.assertEqual(before, (self.catalog.to_payload(), self.crosswalk, self.frozen, self.gifts, self.source))
        self.assertEqual(result['provenance']['retained_fields']['students.local.display_name']['source'], 'retained-local')
        self.assertIn('gift_affinities.local.preferred_tags', result['provenance']['projected_fields'])

    def test_lock_catalog_and_complete_crosswalk_are_mandatory(self):
        for key in ('lock_sha256', 'catalog_sha256'):
            with self.subTest(key=key):
                self.crosswalk[key] = '0'*64
                with self.assertRaises(ValueError): self.generate()
                self.crosswalk[key] = digest(self.reader.lock if key == 'lock_sha256' else self.catalog.to_payload())
        self.crosswalk['students'].clear()
        with self.assertRaises(ValueError): self.generate()

    def test_version_duplicate_identity_and_unmapped_tags_fail_closed(self):
        original = deepcopy(self.source)
        cases = [lambda: self.source.update(versionId='jp-other'),
                 lambda: self.source['b_favorItems']['rows'].append(deepcopy(self.source['b_favorItems']['rows'][0])),
                 lambda: self.source['b_favorItems']['rows'][0].update(tags=[True]),
                 lambda: self.source['d_enumComparison']['Tag'].update(equal=False)]
        for mutate in cases:
            self.source.clear(); self.source.update(deepcopy(original))
            mutate()
            with self.assertRaises(ValueError): self.generate()

    def test_missing_gift_and_experience_drift_are_rejected(self):
        for exp in (True, 0, 21):
            self.frozen['gifts']['5000']['exp_value'] = exp
            with self.subTest(exp=exp), self.assertRaises(ValueError): self.generate()
        self.frozen['gifts'].clear()
        with self.assertRaises(ValueError): self.generate()

    def test_raw_tag_change_is_reported_without_relabeling_experience(self):
        self.gifts[5000]['tags'] = ['A']
        result = self.generate()
        self.assertEqual(result['raw_gift_tag_changes'], [{'gift_id': 5000, 'before': ['A'], 'after': ['A', 'B']}])
        self.assertEqual(result['gifts'][5000]['exp_value'], 20)
        self.assertEqual(result['provenance']['projected_fields']['gifts.5000.exp_value']['provenance'],
                         self.frozen['gifts']['5000']['provenance'])

    def test_generated_python_executes_with_exact_legacy_values(self):
        result = self.generate()
        for source, name, expected in (
                (generator.render_student_source(result['catalog']), 'STUDENTS', self.catalog.legacy_students()),
                (generator.render_gift_source(result['gifts']), 'GIFT_ITEMS', self.gifts)):
            namespace = {}
            exec(compile(source, '<generated-test>', 'exec'), namespace)
            self.assertEqual(namespace[name], expected)

    def test_new_staging_only_refuses_overwrite_and_protected_roots(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            forbidden = root / 'store'
            target = root / 'staging'
            result = self.generate()
            with self.assertRaises(ValueError):
                generator.write_bundle(result, forbidden/'new', forbidden_roots=[forbidden])
            manifest = generator.write_bundle(result, target, forbidden_roots=[forbidden])
            self.assertEqual(len(manifest), 8)
            self.assertEqual(json.loads((target/'data/metadata/v1/student_catalog.json').read_bytes()),
                             self.catalog.to_payload())
            with self.assertRaises(ValueError): generator.write_bundle(result, target)

    def test_multi_form_bindings_are_explicit_and_preserved_in_generated_bundle(self):
        payload = self.catalog.to_payload()
        payload['forms']['local'].append({'display_name':'second local form'})
        self.catalog = CanonicalMetadataCatalog.from_payload(payload)
        self.crosswalk['catalog_sha256'] = digest(payload)
        with self.assertRaisesRegex(ValueError, 'explicit local binding'):
            self.generate()
        forms = {'schemaVersion':1,'students':{'local':[11,12]},'provenance':{'source':'retained local'}}
        result = generator.regenerate(self.catalog,self.reader,self.crosswalk,self.frozen,self.gifts,forms)
        self.assertEqual(result['client_refs']['students']['local'],[11,12])

    def test_cli_stages_complete_bundle_without_installing_or_rewriting_inputs(self):
        from core import client_data_store
        from tools import export_canonical_metadata as exporter
        import sys
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            catalog=root/'catalog.json';catalog.write_text(json.dumps(self.catalog.to_payload()))
            crosswalk=root/'crosswalk.json';crosswalk.write_text(json.dumps(self.crosswalk))
            frozen=root/'frozen.json';frozen.write_text(json.dumps(self.frozen))
            gifts=root/'gifts.py';gifts.write_text(generator.render_gift_source(self.gifts))
            before={p.name:p.read_bytes() for p in root.iterdir()}
            self.reader.root=root/'read-only-store'
            argv=['export','--from-store','--catalog',str(catalog),'--crosswalk',str(crosswalk),
                  '--frozen-gift-exp',str(frozen),'--gift-source',str(gifts),
                  '--form-bindings',str(root/'no-forms.json'),'--bundle-output',str(root/'staged')]
            with patch.object(sys,'argv',argv),patch.object(client_data_store,'ClientDataStore',return_value=self.reader):
                self.assertEqual(exporter.main(),0)
            self.assertEqual(before,{p.name:p.read_bytes() for p in root.iterdir() if p.is_file()})
            self.assertEqual(len(list((root/'staged').rglob('*.json'))),6)


if __name__ == '__main__':
    unittest.main()
