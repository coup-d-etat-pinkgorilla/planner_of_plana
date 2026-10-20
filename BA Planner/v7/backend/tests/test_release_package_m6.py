"""Offline synthetic M6 packaging: no real build/store/game or user state."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from jsonschema import Draft202012Validator, FormatChecker
from tools import package_release as m6

ROOT = Path(__file__).parents[2]


class ReleasePackageM6Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ba-m6-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / 'bundle'
        self.output = self.root / 'publish'
        self.bundle.mkdir()
        self.put('backend/data/metadata/v1/catalog.json', b'{"students":[]}\n')
        self.put('backend/core/backend_process.py', b'# synthetic runtime\n')
        self.put('ba_planner_v7.exe', b'inert executable fixture')
        self.launcher = self.root / 'launcher.exe'
        self.launcher.write_bytes(b'inert launcher fixture')
        self.lock = self.root / 'ba-data.lock'
        self.lock.write_bytes(m6.json_bytes({'schema':'ba-client-data.lock.v1','consumer':'v7',
            'store_root':str(self.root / 'never-open-store'),'written_utc':'2026-10-20T00:00:00Z',
            'pins':{'jp':{'version_id':'jp-1.73.0-test','client_version':'1.73.0','bundle_revision':None,'files':{'catalog.json':'a'*64}}},
            'extracts':[{'server':'jp','version_id':'jp-1.73.0-test','kind':'student-stats',
                'path':'extracts/jp/jp-1.73.0-test/student-stats','provenance_sha256':'b'*64,
                'files':{'stats.json':'c'*64}}]}))

    def put(self, name, raw):
        p = self.bundle / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(raw)
        return p

    def run_package(self, mode='data', **kwargs):
        options = {'bundle_dir':self.bundle,'output_dir':self.output,'lock_path':self.lock,
                   'mode':mode,'app_version':'7.0.0-alpha.1',
                   'zip_url':'https://example.invalid/releases/{filename}', 'notes':'Synthetic data update'}
        if mode == 'app':
            options['launcher'] = self.launcher
        options.update(kwargs)
        return m6.generate_release(**options)

    def validate(self, filename, payload):
        schema = json.loads((ROOT / 'contracts' / filename).read_text(encoding='utf-8'))
        Draft202012Validator.check_schema(schema)
        Draft202012Validator(schema, format_checker=FormatChecker()).validate(payload)

    def test_data_zip_exact_scope_manifest_hashes_and_real_descriptor(self):
        before = {p:p.read_bytes() for p in self.bundle.rglob('*') if p.is_file()}
        result = self.run_package()
        self.validate('data-snapshot-v1.schema.json', result['snapshot'])
        self.validate('release-latest-v1.schema.json', result['latest'])
        archive = Path(result['zip'])
        self.assertEqual(m6.file_pin(archive)['sha256'], result['latest']['sha256'])
        with zipfile.ZipFile(archive) as z:
            self.assertEqual(set(z.namelist()), {'release-manifest.json',
                'app/.ba_planner_data_snapshot.json','app/CHANGELOG-data.md',
                'app/backend/data/metadata/v1/catalog.json'})
            manifest = json.loads(z.read('release-manifest.json'))
            self.validate('release-package-v1.schema.json', manifest)
            for entry in manifest['files']:
                raw = z.read(entry['path'])
                self.assertEqual(entry['sha256'], m6.sha(raw))
                self.assertEqual(entry['bytes'], len(raw))
            self.assertEqual(result['latest']['dataSnapshotSha256'], m6.sha(z.read('app/.ba_planner_data_snapshot.json')))
        self.assertEqual(before, {p:p.read_bytes() for p in self.bundle.rglob('*') if p.is_file()})
        self.assertNotIn('store_root', json.dumps(result['snapshot']))
        self.assertNotIn(str(self.root), json.dumps(result['snapshot']))

    def test_full_zip_has_bootstrap_and_app_and_omits_separate_devtools(self):
        self.put('developer_tools/private.exe', b'do not distribute')
        result = self.run_package('app')
        with zipfile.ZipFile(result['zip']) as z:
            self.assertEqual(z.read('BA Planner v7.exe'), self.launcher.read_bytes())
            self.assertIn('app/ba_planner_v7.exe', z.namelist())
            self.assertIn('app/backend/core/backend_process.py', z.namelist())
            self.assertFalse(any('developer_tools' in name for name in z.namelist()))

    def test_repeat_is_byte_identical_and_changelog_appends_once(self):
        first = self.run_package()
        raw = Path(first['zip']).read_bytes()
        notes = (self.output / 'CHANGELOG-data.md').read_bytes()
        second = self.run_package()
        self.assertEqual(raw, Path(second['zip']).read_bytes())
        self.assertEqual(notes, (self.output / 'CHANGELOG-data.md').read_bytes())
        self.assertEqual(notes.count(b'<!-- ba-data:'), 1)

    def test_same_game_pin_new_data_gets_new_snapshot_and_zip_identity(self):
        first = self.run_package()
        self.put('backend/data/metadata/v1/catalog.json', b'{"students":["new"]}\n')
        second = self.run_package()
        self.assertEqual(first['latest']['appVersion'], second['latest']['appVersion'])
        self.assertEqual(first['latest']['dataVersionId'], second['latest']['dataVersionId'])
        self.assertNotEqual(first['latest']['dataSnapshotSha256'], second['latest']['dataSnapshotSha256'])
        self.assertNotEqual(first['zip'], second['zip'])
        self.assertEqual((self.output / 'CHANGELOG-data.md').read_bytes().count(b'<!-- ba-data:'), 2)

    def test_same_identity_changed_notes_cannot_republish(self):
        self.run_package()
        old = (self.output / 'latest.json').read_bytes()
        with self.assertRaisesRegex(ValueError, 'different changelog notes'):
            self.run_package(notes='silently changed')
        self.assertEqual(old, (self.output / 'latest.json').read_bytes())

    def test_missing_app_executable_or_launcher_rejected(self):
        with self.assertRaises(ValueError): self.run_package('app', launcher=None)
        (self.bundle / 'ba_planner_v7.exe').unlink()
        with self.assertRaises(ValueError): self.run_package('app')
        self.assertFalse(self.output.exists())

    def test_unknown_mode_versions_and_unsafe_urls_rejected_before_writes(self):
        for kwargs in ({'mode':'all'},{'app_version':'../7'},{'min_launcher':'1'},
                       {'zip_url':'http://example.invalid/a.zip'},
                       {'zip_url':'https://user:pass@example.invalid/a.zip'},
                       {'zip_url':'https://example.invalid/{filename}#fragment'},
                       {'zip_url':'https://example.invalid/wrong.zip'},{'notes':''}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError): self.run_package(**kwargs)
        self.assertFalse(self.output.exists())

    def test_shared_store_or_data_input_output_rejected(self):
        for path in (self.root/'never-open-store'/'publish',self.bundle/'backend/data/publish'):
            with self.subTest(path=path), self.assertRaises(ValueError): self.run_package(output_dir=path)
            self.assertFalse(path.exists())

    def test_invalid_lock_does_not_produce_output_or_touch_store(self):
        lock = json.loads(self.lock.read_bytes());lock['extracts'][0]['version_id']='jp-other'
        self.lock.write_bytes(m6.json_bytes(lock))
        with self.assertRaises(ValueError): self.run_package()
        self.assertFalse(self.output.exists())
        self.assertFalse((self.root/'never-open-store').exists())

    def test_private_data_developer_writer_and_game_images_reject_full_zip(self):
        for name in ('repository/profile.json','backend/tools/developer_tools.py',
                     'data/flutter_assets/assets/student_portraits/test.png',
                     'backend/assets/recognition/v1/test.png','data/flutter_assets/assets/GyeonggiTitle-Medium.ttf'):
            p = self.put(name, b'private synthetic sentinel')
            with self.subTest(name=name), self.assertRaises(ValueError): self.run_package('app')
            p.unlink()
            # Keep only empty parent directories; a private directory is itself a rejection.
            for parent in sorted(self.bundle.rglob('*'), reverse=True):
                if parent.is_dir() and not any(parent.iterdir()): parent.rmdir()
        self.assertFalse(self.output.exists())

    def test_data_zip_rejects_code_in_data_and_does_not_include_other_app_code(self):
        p = self.put('backend/data/hidden.py', b'not data')
        with self.assertRaises(ValueError): self.run_package()
        p.unlink()
        self.assertFalse(self.output.exists())

    def test_input_mutation_during_archiving_does_not_publish_latest(self):
        original = m6._zip_entry
        def mutate(archive, name, **kwargs):
            if name.endswith('catalog.json'):
                kwargs['source'].write_bytes(b'changed in flight')
            return original(archive, name, **kwargs)
        with patch.object(m6, '_zip_entry', side_effect=mutate), self.assertRaisesRegex(ValueError, 'changed while archiving'):
            self.run_package()
        self.assertFalse((self.output/'latest.json').exists())
        self.assertEqual(list(self.output.iterdir()), [])

    def test_output_inside_bundle_does_not_archive_previous_release_recursively(self):
        self.output = self.bundle
        self.run_package()
        result = self.run_package()
        with zipfile.ZipFile(result['zip']) as z:
            self.assertFalse(any(name.endswith(('.zip','.sha256','latest.json')) for name in z.namelist()))

    def test_schema_fixture_positive_and_negative(self):
        fixture = json.loads((ROOT/'contracts/fixtures/release_latest_v1.json').read_text())
        schema = json.loads((ROOT/'contracts/release-latest-v1.schema.json').read_text())
        validator = Draft202012Validator(schema, format_checker=FormatChecker())
        for case in fixture['cases']:
            with self.subTest(case=case['id']):
                self.assertEqual(validator.is_valid(case['message']), case['valid'])
        bad = deepcopy(fixture['cases'][0]['message']);bad['extra']=True
        self.assertFalse(validator.is_valid(bad))

    def test_snapshot_and_zip_schemas_reject_traversal_at_every_depth(self):
        for schema_name in ('data-snapshot-v1.schema.json','release-package-v1.schema.json'):
            schema = json.loads((ROOT/'contracts'/schema_name).read_text())
            validator = Draft202012Validator(schema['properties']['files']['items'])
            for path in ('backend/data/../outside.json','backend/data/sub/../../outside.json',
                         '../outside.json','/absolute.json','C:/outside.json',
                         'backend/data/./file.json','backend/data/a\\file.json','backend/data/a\x00.json'):
                with self.subTest(schema=schema_name,path=path):
                    self.assertFalse(validator.is_valid({'path':path,'bytes':1,'sha256':'a'*64}))
            self.assertTrue(validator.is_valid({'path':'backend/data/v1/a.json','bytes':1,'sha256':'a'*64}))

    def test_explicit_debug_artifact_output_is_allowed(self):
        result = self.run_package(output_dir=self.root/'debug'/'m6-artifact')
        self.assertTrue(Path(result['zip']).is_file())


if __name__ == '__main__':
    unittest.main()
