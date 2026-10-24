"""Synthetic-only Windows staging regression and fail-closed JSONL startup."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from jsonschema import Draft202012Validator
from core import user_state_migration as migration

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT/'contracts/startup-user-data-v1.schema.json').read_bytes())


class StartupMigrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ba-migration-synthetic-')
        self.addCleanup(self.tmp.cleanup)
        self.local = Path(self.tmp.name)
        def cleanup_long_fixture():
            # Only this test's freshly allocated, checked temp root is owned.
            self.assertEqual(self.local.resolve().parent,Path(tempfile.gettempdir()).resolve())
            self.assertTrue(self.local.name.startswith('ba-migration-synthetic-'))
            native=migration._filesystem_path(self.local)
            if native.exists():shutil.rmtree(native)
        self.addCleanup(cleanup_long_fixture)
        self.legacy = self.local/'BA Planner'
        self.legacy.mkdir()
        path = self.legacy/'repository/opaque-synthetic-state.bin'
        path.parent.mkdir();path.write_bytes(b'only synthetic user state')

    def environment(self):
        env = {**os.environ, 'LOCALAPPDATA':str(self.local), 'BA_PLANNER_DISABLE_GAME_DISCOVERY':'1'}
        for name in ('BA_PLANNER_USER_DIR','BA_PLANNER_STORAGE_ROOT'):
            env.pop(name,None)
        return env

    def request(self, method, index):
        return {'protocol':1,'id':str(index),'type':'request','method':method,'payload':{}}

    def test_extended_names_cover_drive_unc_existing_prefix_and_normalization(self):
        cases = {r'C:\alpha\..\beta':r'\\?\C:\beta',
                 r'\\server\share\one\..\two':r'\\?\UNC\server\share\two',
                 r'\\?\C:\already':r'\\?\C:\already'}
        for name, expected in cases.items():
            self.assertEqual(migration._windows_extended_name(name),expected)
        for name in ('relative',r'\rooted-without-drive',r'C:relative'):
            with self.assertRaises(ValueError):migration._windows_extended_name(name)

    @unittest.skipUnless(os.name=='nt','native extended-path I/O requires Windows')
    def test_staging_over_max_path_copies_and_publishes_exact_bytes(self):
        parent = self.legacy/'repository/recognition_samples'
        short = parent/'x'/'sample.json'
        padding = 'a'*(240-len(str(short))+1)
        source = parent/padding/'sample.json'
        self.assertEqual(len(str(source)),240)
        native = migration._filesystem_path(source)
        native.parent.mkdir(parents=True)
        native.write_bytes(b'{"synthetic":"long-path"}')
        before = migration._inventory(self.legacy)
        observed=[]
        def copy(old,new):
            observed.append((str(old),str(new)))
            self.assertTrue(str(old).startswith('\\\\?\\'))
            self.assertTrue(str(new).startswith('\\\\?\\'))
            return shutil.copy2(old,new)
        result=migration.migrate(self.legacy,copy_file=copy)
        self.assertEqual(result['copied_files'],len(before))
        self.assertTrue(any(len(target.removeprefix('\\\\?\\'))>260 for _,target in observed))
        self.assertEqual(migration._inventory(self.legacy),before)
        self.assertEqual(migration._inventory(self.legacy/'v7'),before)

    @unittest.skipUnless(os.name=='nt','native extended-path I/O requires Windows')
    def test_deep_source_and_failed_copy_clean_only_owned_stage(self):
        source=self.legacy/'repository'/('a'*110)/('b'*110)/'synthetic.bin'
        native=migration._filesystem_path(source)
        self.assertGreater(len(str(source)),260)
        native.parent.mkdir(parents=True);native.write_bytes(b'deep original retained')
        before=migration._inventory(self.legacy)
        unknown=self.legacy/'.v7-migration-unowned';unknown.mkdir()
        (unknown/'keep').write_bytes(b'unknown staging retained')
        def fail_after_copy(old,new):
            shutil.copy2(old,new)
            raise OSError('synthetic failure after a real extended-path copy')
        with self.assertRaises(OSError):migration.migrate(self.legacy,copy_file=fail_after_copy)
        self.assertEqual(migration._inventory(self.legacy),before)
        self.assertFalse((self.legacy/'v7').exists())
        self.assertEqual(list(self.legacy.glob('.v7-migration-*')),[unknown])
        self.assertEqual((unknown/'keep').read_bytes(),b'unknown staging retained')

    def test_existing_guard_file_is_an_anchor_not_a_busy_or_stale_marker(self):
        anchor=self.legacy/'.v7-migration.guard';anchor.write_bytes(b'old anchor')
        with migration._guard(anchor):
            with self.assertRaisesRegex(migration.UserStateMigrationError,'user_data_busy'):
                migration.migrate(self.legacy)
        migration.migrate(self.legacy)
        self.assertEqual(anchor.read_bytes(),b'old anchor')

    def test_actual_failed_startup_correlates_all_domains_without_any_repository_publish(self):
        target=self.legacy/'v7';target.mkdir();(target/'keep').write_bytes(b'unrecognised destination')
        before=migration._inventory(self.legacy)
        poison=self.local/'synthetic-invalid-catalog.json'
        poison.write_bytes(b'not a catalog - must never be loaded during blocked startup')
        env=self.environment();env['BA_PLANNER_METADATA_PATH']=str(poison)
        methods=('planning.student.get','repository.profile.list','scanner.target.list','assets.prepare.status')
        requests=[self.request(method,index) for index,method in enumerate(methods)]
        wire='not-json\n'+''.join(json.dumps(row)+'\n' for row in requests)
        process=subprocess.run([sys.executable,'-m','core.backend_process'],cwd=ROOT/'backend',
            env=env,input=wire,text=True,encoding='utf-8',capture_output=True,timeout=10)
        self.assertEqual(process.returncode,0,process.stderr)
        responses=[json.loads(line) for line in process.stdout.splitlines()]
        self.assertEqual(len(responses),4)
        for request,response in zip(requests,responses):
            Draft202012Validator(SCHEMA).validate(response)
            self.assertEqual(response['id'],request['id'])
            self.assertEqual(response['method'],request['method'])
            self.assertEqual(response['payload']['error']['details']['reason'],'v7_destination_unrecognised')
        self.assertEqual(migration._inventory(self.legacy),before)
        self.assertEqual(list(target.iterdir()),[target/'keep'])
        self.assertNotIn(str(self.legacy),process.stdout+process.stderr)

    def test_os_error_never_constructs_scanner_and_never_leaks_exception_paths(self):
        code='''from unittest.mock import patch
import core.backend_process as backend
with patch('core.user_state_migration.ensure_default_user_root',side_effect=PermissionError('PRIVATE_FILENAME_MUST_NOT_LEAK')), patch.object(backend,'build_scanner_service',side_effect=AssertionError('scanner must not initialise')):
    backend.main()
'''
        process=subprocess.run([sys.executable,'-c',code],cwd=ROOT/'backend',env=self.environment(),
            input=json.dumps(self.request('repository.profile.list',1))+'\n',
            text=True,encoding='utf-8',capture_output=True,timeout=10)
        self.assertEqual(process.returncode,0,process.stderr)
        response=json.loads(process.stdout);Draft202012Validator(SCHEMA).validate(response)
        self.assertEqual(response['payload']['error']['details']['reason'],'user_data_io_error')
        self.assertNotIn('PRIVATE_FILENAME',process.stdout+process.stderr)
        self.assertFalse((self.legacy/'v7').exists())

    def test_developer_tool_reports_safe_existing_error_shape_after_reading_request(self):
        target=self.legacy/'v7';target.mkdir();(target/'keep').write_bytes(b'preserve')
        process=subprocess.run([sys.executable,'-m','tools.developer_tools'],cwd=ROOT/'backend',
            env=self.environment(),input=json.dumps({'version':1,'method':'metadata.list','params':{}}),
            text=True,encoding='utf-8',capture_output=True,timeout=10)
        self.assertEqual(process.returncode,1,process.stderr)
        response=json.loads(process.stdout)
        self.assertEqual(set(response),{'version','ok','error'})
        self.assertFalse(response['ok'])
        self.assertEqual(response['error']['type'],'UserStateMigrationError')
        self.assertEqual(set(response['error']),{'type','message'})
        self.assertIn('v7_destination_unrecognised',response['error']['message'])
        self.assertNotIn(str(self.legacy),process.stdout+process.stderr)
        self.assertEqual(list(target.iterdir()),[target/'keep'])

    def test_blocked_protocol_ignores_untrusted_and_sanitizes_unknown_reason(self):
        protocol=migration.MigrationBlockedProtocol(migration.UserStateMigrationError('PRIVATE_PATH'))
        self.assertIsNone(protocol.handle({'protocol':1,'payload':{}}))
        response=protocol.handle(self.request('planning.student.get',1))
        Draft202012Validator(SCHEMA).validate(response)
        self.assertEqual(response['payload']['error']['details']['reason'],'user_data_migration_failed')
        self.assertNotIn('PRIVATE_PATH',json.dumps(response))


if __name__=='__main__':unittest.main(verbosity=2)
