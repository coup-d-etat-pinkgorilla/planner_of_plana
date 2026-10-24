from pathlib import Path
import json
import shutil
import tempfile
import unittest
import os
import subprocess
import sys
from core import user_state_migration as migration


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)/'BA Planner';self.root.mkdir()
        for name,raw in {'repository/catalog.json':b'private catalog bytes',
            'repository/recognition_samples/sample.png':b'private sample',
            'recognition-assets/cache/manifest.json':b'cached manifest',
            'assets/current/data/value.json':b'override data'}.items():
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)

    def test_copy_once_preserves_originals_and_exact_manifest_bytes(self):
        before=migration._inventory(self.root)
        result=migration.migrate(self.root)
        self.assertEqual(result['copied_files'],len(before))
        self.assertEqual(migration._inventory(self.root),before)
        self.assertEqual(migration._inventory(self.root/'v7'),before)
        self.assertTrue(json.loads((self.root/'v7/.v7-migration.json').read_bytes())['source_kept'])
        self.assertEqual(migration.migrate(self.root)['state'],'existing')

    def test_existing_v7_is_not_merged_or_overwritten(self):
        target=self.root/'v7';target.mkdir();(target/'keep').write_bytes(b'new user state')
        with self.assertRaisesRegex(migration.UserStateMigrationError,'destination_unrecognised'):
            migration.migrate(self.root)
        self.assertEqual(list(target.iterdir()),[target/'keep'])
        self.assertEqual((target/'keep').read_bytes(),b'new user state')

    def test_copy_failure_leaves_originals_and_no_published_destination(self):
        before=migration._inventory(self.root)
        def fail(*args):raise OSError('synthetic copy failure')
        with self.assertRaises(OSError):migration.migrate(self.root,copy_file=fail)
        self.assertEqual(migration._inventory(self.root),before)
        self.assertFalse((self.root/'v7').exists())

    def test_changed_source_is_detected_without_publishing_partial_copy(self):
        changed=False
        def copy(source,target):
            nonlocal changed
            shutil.copy2(source,target)
            if not changed:source.write_bytes(b'changed concurrently');changed=True
        with self.assertRaisesRegex(migration.UserStateMigrationError,'changed_during'):
            migration.migrate(self.root,copy_file=copy)
        self.assertFalse((self.root/'v7').exists())

    def test_existing_repository_guard_and_pending_journal_block_copy(self):
        with migration._guard(self.root/'repository/.repository.guard'):
            with self.assertRaisesRegex(migration.UserStateMigrationError,'busy'):
                migration.migrate(self.root)
        (self.root/'repository/.repository.transaction.json').write_text('{}')
        with self.assertRaisesRegex(migration.UserStateMigrationError,'recovery_required'):
            migration.migrate(self.root)
        self.assertFalse((self.root/'v7').exists())

    def test_default_v7_namespace_and_explicit_overrides_are_distinct(self):
        env={'LOCALAPPDATA':str(self.root.parent)}
        self.assertEqual(migration.user_root(env),self.root/'v7')
        env['BA_PLANNER_USER_DIR']=str(self.root/'explicit')
        self.assertEqual(migration.user_root(env),self.root/'explicit')
        self.assertEqual(migration.ensure_default_user_root(env)['state'],'explicit-override')
        self.assertFalse((self.root/'v7').exists())

    def test_actual_backend_startup_migrates_only_synthetic_default_root(self):
        env={**os.environ, 'LOCALAPPDATA':str(self.root.parent),
             'BA_PLANNER_DISABLE_GAME_DISCOVERY':'1'}
        for name in ('BA_PLANNER_USER_DIR','BA_PLANNER_STORAGE_ROOT'):
            env.pop(name,None)
        # No catalog is needed for a planning lookup. Avoid inventing a private
        # repository schema: this test's old state is an opaque sample file.
        (self.root/'repository/catalog.json').unlink()
        before=migration._inventory(self.root)
        request={'protocol':1,'id':'startup','type':'request',
                 'method':'planning.student.get','payload':{'student_id':'ayane'}}
        result=subprocess.run([sys.executable,'-m','core.backend_process'],
            input=json.dumps(request)+'\n',text=True,encoding='utf-8',
            stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=10,env=env,
            cwd=Path(__file__).resolve().parents[1])
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout)['id'],'startup')
        self.assertEqual(migration._inventory(self.root),before)
        for name,entry in before.items():
            self.assertEqual((self.root/name).read_bytes(),(self.root/'v7'/name).read_bytes())
        self.assertTrue((self.root/'v7/.v7-migration.json').is_file())


if __name__=='__main__':unittest.main(verbosity=2)
