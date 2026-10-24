"""Offline tests of the compiled Windows C# updater; no app is executed."""
from pathlib import Path
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT/'backend/tests/fixtures/distribution_updater'
EXE = None
def encode(value): return (json.dumps(value,sort_keys=True,ensure_ascii=False)+'\n').encode()
def sha(raw): return hashlib.sha256(raw).hexdigest()
def pin(path,raw): return {'path':path,'bytes':len(raw),'sha256':sha(raw)}

def snapshot(files,version='jp-test-2'):
    return encode({'schemaVersion':1,'dataVersionId':version,'lockSha256':'a'*64,
        'pins':{'jp':{'versionId':version,'clientVersion':None,'bundleRevision':None,'files':{'test':'b'*64}}},
        'extracts':[],'provenanceScope':'lock-records-only; shipped-files-hashed-separately; manual-fields-retained',
        'files':[pin(name,raw) for name,raw in sorted(files.items())]})


class WindowsUpdaterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        global EXE
        cls.compiled = tempfile.TemporaryDirectory(prefix='ba-updater-compiled-')
        cls.addClassCleanup(cls.compiled.cleanup)
        EXE = Path(cls.compiled.name)/'UpdaterHarness.exe'
        shell = shutil.which('powershell.exe')
        if shell is None:
            raise unittest.SkipTest('Windows .NET Framework updater requires Windows PowerShell')
        result = subprocess.run([shell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            str(FIXTURES/'compile.ps1'), '-Updater',
            str(ROOT/'frontend/windows/release_launcher/DistributionUpdater.cs'),
            '-Harness', str(FIXTURES/'Harness.cs'), '-Output', str(EXE)],
            capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)

    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='ba-updater-offline-')
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.app=self.root/'app'; self.app.mkdir()
        files={'backend/data/a.json':b'old-data','backend/data/removed.json':b'old-removed'}
        for name,raw in {**files,'ba_planner_v7.exe':b'inert old EXE',
                         'backend/core/keep.py':b'keep-code'}.items():
            path=self.app/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
        raw=snapshot(files,'jp-test-1')
        (self.app/'.ba_planner_data_snapshot.json').write_bytes(raw)
        (self.app/'.ba_planner_install.json').write_bytes(encode({'appVersion':'1.0.0',
            'dataVersionId':'jp-test-1','dataSnapshotSha256':sha(raw)}))
        self.preferences=self.root/'prefs';self.preferences.mkdir()
        self.fixture=self.root/'fixtures';self.fixture.mkdir()
        self.channel={'latestAppUrl':'https://test.invalid/latest-app.json',
                      'latestDataUrl':'https://test.invalid/latest-data.json'}
        (self.root/'update-channel.json').write_bytes(encode(self.channel))
        self.map={}

    def tree(self):
        return {p.relative_to(self.app).as_posix():p.read_bytes() for p in self.app.rglob('*') if p.is_file()}

    def package(self,kind='app',version='2.0.0',*,extra=None,unlisted=None,bad_pin=False,link=False):
        data={'backend/data/a.json':b'new-data'}
        snap=snapshot(data)
        payload={'app/'+name:raw for name,raw in data.items()}
        payload.update({'app/.ba_planner_data_snapshot.json':snap,'app/CHANGELOG-data.md':b'new changelog'})
        if kind=='app':payload.update({'BA Planner v7.exe':b'inert new launcher',
                                       'app/ba_planner_v7.exe':b'inert new app'})
        payload.update(extra or {})
        manifest={'schemaVersion':1,'releaseType':kind,'appVersion':version,'dataVersionId':'jp-test-2',
                  'dataSnapshotSha256':sha(snap),'files':[pin(name,raw) for name,raw in sorted(payload.items())]}
        if bad_pin:manifest['files'][0]['sha256']='0'*64
        out=io.BytesIO()
        with zipfile.ZipFile(out,'w') as archive:
            archive.writestr('release-manifest.json',encode(manifest))
            for index,(name,raw) in enumerate(payload.items()):
                info=zipfile.ZipInfo(name)
                if link and index==0:info.create_system=3;info.external_attr=0xA1FF<<16
                archive.writestr(info,raw)
            for name,raw in (unlisted or {}).items():archive.writestr(name,raw)
        raw=out.getvalue()
        descriptor={'schemaVersion':1,'releaseType':kind,'appVersion':version,'dataVersionId':'jp-test-2',
            'dataSnapshotSha256':sha(snap),'zipUrl':'https://test.invalid/'+kind+'.zip','sha256':sha(raw),
            'notes':'TEST_ONLY','minLauncher':'1.0.0'}
        return descriptor,raw

    def run_harness(self,*args,ok=True):
        p=subprocess.run([str(EXE),*map(str,args)],capture_output=True,text=True,encoding='utf-8',timeout=20)
        if ok:self.assertEqual(p.returncode,0,p.stderr)
        else:self.assertNotEqual(p.returncode,0,p.stdout)
        return p.stdout.strip()

    def install(self,descriptor,raw,*,ok=True):
        desc=self.fixture/'descriptor.json';desc.write_bytes(encode(descriptor))
        archive=self.fixture/'payload.zip';archive.write_bytes(raw)
        return self.run_harness('install',self.root,desc,archive,descriptor['releaseType'],ok=ok)

    def serve(self,url,raw):
        path=self.fixture/(str(len(self.map))+'.bin');path.write_bytes(raw)
        self.map[url]=str(path)

    def attempt(self):
        path=self.fixture/'map.json';path.write_bytes(encode(self.map))
        return json.loads(self.run_harness('try',self.root,self.preferences,path))

    def test_full_app_swap_changes_app_and_keeps_launcher_and_user_files(self):
        (self.root/'BA Planner v7.exe').write_bytes(b'running launcher')
        (self.preferences/'private.json').write_bytes(b'user state')
        self.install(*self.package())
        self.assertEqual((self.app/'ba_planner_v7.exe').read_bytes(),b'inert new app')
        self.assertEqual((self.root/'BA Planner v7.exe').read_bytes(),b'running launcher')
        self.assertEqual((self.preferences/'private.json').read_bytes(),b'user state')
        self.assertFalse((self.root/'app-previous').exists())
        self.assertEqual(json.loads((self.app/'.ba_planner_install.json').read_bytes())['appVersion'],'2.0.0')

    def test_data_swap_preserves_code_removes_only_obsolete_staged_data(self):
        self.install(*self.package('data','1.0.0'))
        self.assertEqual((self.app/'ba_planner_v7.exe').read_bytes(),b'inert old EXE')
        self.assertEqual((self.app/'backend/core/keep.py').read_bytes(),b'keep-code')
        self.assertFalse((self.app/'backend/data/removed.json').exists())
        self.assertEqual((self.app/'backend/data/a.json').read_bytes(),b'new-data')

    def test_bad_zip_hash_never_changes_current_app(self):
        before=self.tree();desc,raw=self.package();desc['sha256']='0'*64
        self.install(desc,raw,ok=False);self.assertEqual(self.tree(),before)

    def test_bad_member_hash_never_publishes_staging(self):
        before=self.tree();self.install(*self.package(bad_pin=True),ok=False)
        self.assertEqual(self.tree(),before);self.assertFalse((self.root/'app-staging').exists())

    def test_traversal_and_windows_reserved_names_fail_closed(self):
        before=self.tree()
        for name in ('../escape','app/../escape','app/C:/escape','app/NUL.txt','app/file.','app/evil\\file'):
            with self.subTest(name=name):
                self.install(*self.package(extra={name:b'bad'}),ok=False)
                self.assertEqual(self.tree(),before)
        self.assertFalse((self.root.parent/'escape').exists())

    def test_case_collision_unlisted_file_and_link_are_rejected(self):
        before=self.tree()
        for options in ({'extra':{'app/BACKEND/data/A.JSON':b'duplicate'}},
                        {'unlisted':{'app/extra.bin':b'unlisted'}},{'link':True}):
            self.install(*self.package(**options),ok=False);self.assertEqual(self.tree(),before)

    def test_data_package_cannot_update_code_or_another_app_version(self):
        before=self.tree()
        self.install(*self.package('data','1.0.0',extra={'app/backend/core/attack.py':b'bad'}),ok=False)
        self.install(*self.package('data','2.0.0'),ok=False)
        self.assertEqual(self.tree(),before)

    def test_min_launcher_unknown_fields_and_bool_version_rejected(self):
        before=self.tree()
        for change in ({'minLauncher':'9.0.0'},{'extra':True},{'schemaVersion':True},
                       {'zipUrl':'https://user:password@test.invalid/app.zip'}):
            desc,raw=self.package();desc.update(change)
            self.install(desc,raw,ok=False);self.assertEqual(self.tree(),before)

    def test_disabled_automatic_updates_do_not_contact_feed(self):
        (self.preferences/'auto_update_disabled.flag').touch()
        result=self.attempt();self.assertFalse(result['changed']);self.assertEqual(result['requested'],[])

    def test_manual_check_overrides_disabled_and_installs_app_before_data(self):
        (self.preferences/'auto_update_disabled.flag').touch();(self.preferences/'check_now.flag').touch()
        desc,raw=self.package();self.serve(self.channel['latestAppUrl'],encode(desc));self.serve(desc['zipUrl'],raw)
        result=self.attempt();self.assertTrue(result['changed'])
        self.assertEqual(result['requested'],[self.channel['latestAppUrl'],desc['zipUrl']])
        self.assertFalse((self.preferences/'check_now.flag').exists())

    def test_same_app_uses_only_compatible_data_snapshot(self):
        app_desc,_=self.package('app','1.0.0');data_desc,raw=self.package('data','1.0.0')
        self.serve(self.channel['latestAppUrl'],encode(app_desc))
        self.serve(self.channel['latestDataUrl'],encode(data_desc));self.serve(data_desc['zipUrl'],raw)
        self.assertTrue(self.attempt()['changed'])
        self.assertEqual((self.app/'backend/core/keep.py').read_bytes(),b'keep-code')

    def test_wrong_app_data_and_downgrade_never_download_payload(self):
        app_desc,_=self.package('app','1.0.0');data_desc,_=self.package('data','2.0.0')
        self.serve(self.channel['latestAppUrl'],encode(app_desc));self.serve(self.channel['latestDataUrl'],encode(data_desc))
        result=self.attempt();self.assertFalse(result['changed']);self.assertEqual(len(result['requested']),2)
        old,_=self.package('app','0.9.0');self.serve(self.channel['latestAppUrl'],encode(old))
        result=self.attempt();self.assertFalse(result['changed']);self.assertEqual(len(result['requested']),1)

    def test_offline_keeps_current_app_without_throwing(self):
        before=self.tree();result=self.attempt()
        self.assertFalse(result['changed']);self.assertEqual(self.tree(),before)

    def test_interrupted_old_app_move_is_recovered_before_any_network(self):
        before=self.tree();self.app.rename(self.root/'app-previous')
        (self.root/'.update-transaction.json').write_bytes(encode({'schemaVersion':1,'owner':'ba-planner-updater'}))
        result=self.attempt();self.assertFalse(result['changed']);self.assertEqual(self.tree(),before)
        self.assertFalse((self.root/'.update-transaction.json').exists())

    def test_unknown_staging_is_not_deleted_or_overwritten(self):
        staging=self.root/'app-staging';staging.mkdir();(staging/'keep').write_bytes(b'unknown existing')
        before=self.tree();self.install(*self.package(),ok=False)
        self.assertEqual(self.tree(),before);self.assertEqual((staging/'keep').read_bytes(),b'unknown existing')

    def test_publish_failure_rolls_back_old_app_then_recovers_transaction(self):
        before=self.tree();desc,raw=self.package()
        descriptor=self.fixture/'descriptor.json';descriptor.write_bytes(encode(desc))
        archive=self.fixture/'payload.zip';archive.write_bytes(raw)
        self.run_harness('installfail',self.root,descriptor,archive,'app',ok=False)
        self.assertEqual(self.tree(),before)
        self.attempt()
        self.assertEqual(self.tree(),before);self.assertFalse((self.root/'.update-transaction.json').exists())

    def test_recovery_restores_verified_previous_app_if_new_data_is_corrupt(self):
        before=self.tree();shutil.copytree(self.app,self.root/'app-previous')
        (self.app/'backend/data/a.json').write_bytes(b'corrupt interrupted app')
        (self.root/'.update-transaction.json').write_bytes(encode({'schemaVersion':1,'owner':'ba-planner-updater'}))
        self.attempt()
        self.assertEqual(self.tree(),before)
        self.assertEqual(len(list(self.root.glob('app-rejected-*'))),1)

    def test_semantic_versions_do_not_overflow_and_order_prereleases(self):
        for a,b,sign in [('1.0.0','1.0.0-alpha',1),('1.0.0-alpha.9','1.0.0-alpha.10',-1),
                         ('999999999999999999999.0.0','2.0.0',1),('1.0.0','1.0.0',0),
                         ('1.0.0-2','1.0.0-beta',-1)]:
            result=int(self.run_harness('versions',a,b))
            self.assertEqual((result>0)-(result<0),sign)

    def test_committed_m6_packager_app_and_data_are_consumed_without_translation(self):
        from test_release_package_m6 import ReleasePackageM6Tests
        fixture=ReleasePackageM6Tests();fixture.setUp();self.addCleanup(fixture.doCleanups)
        first=fixture.run_package('app')
        self.install(first['latest'],Path(first['zip']).read_bytes())
        self.assertEqual((self.app/'backend/core/backend_process.py').read_bytes(),b'# synthetic runtime\n')
        fixture.put('backend/data/metadata/v1/catalog.json',b'{"students":["updated"]}\n')
        second=fixture.run_package('data')
        self.install(second['latest'],Path(second['zip']).read_bytes())
        self.assertEqual((self.app/'backend/data/metadata/v1/catalog.json').read_bytes(),b'{"students":["updated"]}\n')
        self.assertEqual((self.app/'backend/core/backend_process.py').read_bytes(),b'# synthetic runtime\n')


if __name__=='__main__':
    unittest.main(verbosity=2)
