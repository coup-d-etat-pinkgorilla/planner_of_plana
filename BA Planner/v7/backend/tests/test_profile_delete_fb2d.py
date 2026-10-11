from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import itertools
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from core import profile_delete_transaction as deletion
from core.repository_dto import canonical_json
from core.repository_store import JsonRepository, RepositoryError
from core.repository_protocol_v1 import RepositoryProtocolV1
from core.repository_transaction import acquire, release
from core.repository_participant_lock import MARKERS, acquire_participant, release_participant
from core.tactical_store import TacticalStore
from core.tactical_v2 import TacticalV2Store
from core.tactical_share_v1 import TacticalShareV1Store

BACKEND = Path(__file__).resolve().parents[1]
STAGES = ('delete_before_journal', 'delete_journal_prepared', 'delete_catalog_written',
          'delete_profile_removed', 'delete_renamed_v1', 'delete_renamed_v2',
          'delete_unlinked_v1', 'delete_unlinked_v2', 'delete_scenario_removed',
          'delete_presets_removed', 'delete_share_removed', 'delete_tombstones_written',
          'delete_journal_committed', 'delete_journal_removed')


class ProfileDeletionFB2dTests(unittest.TestCase):
    def prepare(self, presence=(True, True, True, True, True)):
        temp = tempfile.TemporaryDirectory(prefix='ba-delete-product-')
        self.addCleanup(temp.cleanup)
        root = Path(temp.name).resolve()
        repo = JsonRepository(root)
        profile_id = repo.create_profile('Main', 'main')['profile']['profile_id']
        other = repo.create_profile('Other', 'other')['profile']['profile_id']
        v1, v2 = TacticalStore(root, repo), TacticalV2Store(root, repo)
        share = TacticalShareV1Store(root, repo, v2)
        contents = (v1._empty(profile_id), v2._empty(profile_id), {'scenario_fixture': True},
                    {'presets_fixture': True}, share._empty(profile_id))
        names = deletion.targets(profile_id)
        for name, value, present in zip(names[2:], contents, presence):
            if present:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(canonical_json(value).encode('utf-8') + b'\r\n')
        unrelated = root / 'tactical-share' / f'{other}.v1.json'
        unrelated.parent.mkdir(parents=True, exist_ok=True)
        unrelated.write_bytes(b'unrelated profile sentinel\r\n')
        return root, repo, profile_id, other

    def images(self, root, profile_id):
        return {name: (root / name).read_bytes() if (root / name).is_file() else None
                for name in deletion.targets(profile_id) + [deletion.TOMBSTONES]}

    def assert_complete(self, root, profile_id, other, before, committed):
        observed = self.images(root, profile_id)
        if not committed:
            self.assertEqual(before, observed)
        else:
            self.assertTrue(all(observed[name] is None for name in deletion.targets(profile_id)[1:]))
            catalog = json.loads(observed['catalog.json'])
            self.assertEqual([other], [row['profile_id'] for row in catalog['profiles']])
            self.assertEqual(other, catalog['selected_profile_id'])
            self.assertEqual({'revision': 1}, deletion.read_tombstones(root, RepositoryError)['profiles'][profile_id]['response'])
        self.assertEqual(b'unrelated profile sentinel\r\n', (root / 'tactical-share' / f'{other}.v1.json').read_bytes())
        self.assertFalse((root / deletion.JOURNAL).exists())
        self.assertFalse(list((root / 'tactical').glob('*.delete')))
        self.assertFalse(any((root / marker).exists() for marker in MARKERS))

    def crash_delete(self, root, profile_id, stage):
        script = '''import os, sys
from pathlib import Path
from core.repository_store import JsonRepository
def fault(stage):
    if stage == sys.argv[3]: os._exit(73)
JsonRepository(Path(sys.argv[1]), fault=fault).delete_profile(sys.argv[2], 0, 'delete')
'''
        result = subprocess.run([sys.executable, '-c', script, str(root), profile_id, stage],
                                cwd=BACKEND, capture_output=True, timeout=15)
        self.assertEqual(73, result.returncode, result.stderr)

    def test_success_exact_seven_paths_and_idempotent_restart(self):
        root, repo, profile_id, other = self.prepare()
        before = self.images(root, profile_id)
        self.assertEqual({'revision': 1}, repo.delete_profile(profile_id, 0, 'delete'))
        self.assert_complete(root, profile_id, other, before, True)
        fresh = JsonRepository(root)
        unchanged = self.images(root, profile_id)
        self.assertEqual({'revision': 1}, fresh.delete_profile(profile_id, 0, 'delete'))
        self.assertEqual(unchanged, self.images(root, profile_id))
        with self.assertRaises(RepositoryError) as caught:
            fresh.delete_profile(profile_id, 1, 'delete')
        self.assertEqual('idempotency_conflict', caught.exception.code)
        with self.assertRaises(RepositoryError) as caught:
            fresh.delete_profile(profile_id, 0, 'other-key')
        self.assertEqual('profile_not_found', caught.exception.code)

    def test_optional_absence_all_32_combinations(self):
        for presence in itertools.product((False, True), repeat=5):
            with self.subTest(presence=presence):
                root, repo, profile_id, other = self.prepare(presence)
                before = self.images(root, profile_id)
                self.assertEqual({'revision': 1}, repo.delete_profile(profile_id, 0, 'delete'))
                self.assert_complete(root, profile_id, other, before, True)

    def test_ordinary_failure_rolls_back_every_prepared_phase(self):
        for stage in STAGES[:-2]:
            with self.subTest(stage=stage):
                root, repo, profile_id, other = self.prepare()
                before = self.images(root, profile_id)
                def fail(current):
                    if current == stage:
                        raise OSError('fixture deletion failure')
                with self.assertRaises(RepositoryError) as caught:
                    JsonRepository(root, fault=fail).delete_profile(profile_id, 0, 'delete')
                self.assertEqual('persistence_failed', caught.exception.code)
                self.assert_complete(root, profile_id, other, before, False)

    def test_failure_after_commit_rolls_forward_and_retries_original_response(self):
        for stage in STAGES[-2:]:
            root, repo, profile_id, other = self.prepare()
            before = self.images(root, profile_id)
            def fail(current):
                if current == stage:
                    raise OSError('fixture response loss')
            with self.assertRaises(RepositoryError):
                JsonRepository(root, fault=fail).delete_profile(profile_id, 0, 'delete')
            self.assert_complete(root, profile_id, other, before, True)
            self.assertEqual({'revision': 1}, JsonRepository(root).delete_profile(profile_id, 0, 'delete'))

    def test_actual_child_termination_56_cases_recovery_via_repository_api(self):
        presences = ((False, False, True, True, False), (False, True, True, True, True),
                     (True, False, True, True, True), (True, True, True, True, True))
        count = 0
        for presence in presences:
            for stage in STAGES:
                with self.subTest(presence=presence, stage=stage):
                    root, repo, profile_id, other = self.prepare(presence)
                    before = self.images(root, profile_id)
                    self.crash_delete(root, profile_id, stage)
                    JsonRepository(root).list_profiles()  # Actual entry automatically recovers.
                    committed = stage in STAGES[-2:]
                    self.assert_complete(root, profile_id, other, before, committed)
                    JsonRepository(root).list_profiles()
                    self.assert_complete(root, profile_id, other, before, committed)
                    if committed:
                        self.assertEqual({'revision': 1}, JsonRepository(root).delete_profile(profile_id, 0, 'delete'))
                    count += 1
        self.assertEqual(56, count)

    def test_interrupted_recovery_child_8_cases_is_repeatable(self):
        for state in ('prepared', 'committed'):
            for stage in ('recovered_0', 'recovered_2', 'recovered_6', 'before_recovery_cleanup'):
                root, repo, profile_id, other = self.prepare()
                before = self.images(root, profile_id)
                self.crash_delete(root, profile_id, 'delete_unlinked_v1' if state == 'prepared' else 'delete_journal_committed')
                script = '''import os, sys
from pathlib import Path
from core import profile_delete_transaction as d
from core.repository_store import JsonRepository
original = d.recover_profile_delete_locked
def fault(stage):
    if stage == sys.argv[2]: os._exit(73)
d.recover_profile_delete_locked = lambda root, error: original(root, error, fault=fault)
JsonRepository(Path(sys.argv[1])).list_profiles()
'''
                result = subprocess.run([sys.executable, '-c', script, str(root), stage],
                                        cwd=BACKEND, capture_output=True, timeout=15)
                self.assertEqual(73, result.returncode, result.stderr)
                self.assertTrue((root / deletion.JOURNAL).exists())
                JsonRepository(root).list_profiles()
                self.assert_complete(root, profile_id, other, before, state == 'committed')

    def test_corrupt_late_entries_validated_before_any_write(self):
        variants = ('hash', 'duplicate', 'traversal', 'version_bool', 'tx_id', 'extra',
                    'delete_after', 'tombstone_transition', 'catalog_transition', 'absent_profile')
        for variant in variants:
            with self.subTest(variant=variant):
                root, repo, profile_id, other = self.prepare()
                self.crash_delete(root, profile_id, 'delete_unlinked_v1')
                path = root / deletion.JOURNAL
                record = json.loads(path.read_text())
                if variant == 'hash': record['entries'][-1]['before'] = {'data': 'eA==', 'sha256': '0' * 64}
                elif variant == 'duplicate': record['entries'][-1]['path'] = 'catalog.json'
                elif variant == 'traversal': record['entries'][-1]['path'] = '../outside'
                elif variant == 'version_bool': record['version'] = True
                elif variant == 'tx_id': record['tx_id'] = '../bad'
                elif variant == 'extra': record['extra'] = True
                elif variant == 'delete_after': record['entries'][6]['after'] = deletion.image(b'{}')
                elif variant == 'tombstone_transition': record['entries'][-1]['after'] = deletion.image(b'{"version":1,"profiles":{}}')
                elif variant == 'catalog_transition': record['entries'][0]['after'] = record['entries'][0]['before']
                elif variant == 'absent_profile': record['entries'][1]['before'] = None
                path.write_text(json.dumps(record), encoding='utf-8')
                raw, observed = path.read_bytes(), self.images(root, profile_id)
                with self.assertRaises(RepositoryError) as caught:
                    JsonRepository(root).list_profiles()
                self.assertEqual('corrupt_data', caught.exception.code)
                self.assertEqual(raw, path.read_bytes())
                self.assertEqual(observed, self.images(root, profile_id))

    def test_rollback_failure_retains_journal_for_next_api_recovery(self):
        root, repo, profile_id, other = self.prepare()
        before = self.images(root, profile_id)
        original = deletion._apply
        def apply(path, raw):
            if path.name == f'{profile_id}.v2.json' and raw is not None:
                raise OSError('fixture rollback interruption')
            return original(path, raw)
        def fault(stage):
            if stage == 'delete_unlinked_v1': raise OSError('fixture deletion interruption')
        with patch.object(deletion, '_apply', apply), self.assertRaises(RepositoryError) as caught:
            JsonRepository(root, fault=fault).delete_profile(profile_id, 0, 'delete')
        self.assertTrue(caught.exception.details['rollback_failed'])
        self.assertTrue((root / deletion.JOURNAL).exists())
        JsonRepository(root).list_profiles()
        self.assert_complete(root, profile_id, other, before, False)

    def test_legacy_manual_markers_never_reclaimed(self):
        for marker in MARKERS:
            root, repo, profile_id, other = self.prepare()
            before = self.images(root, profile_id)
            (root / marker).write_bytes(b'manual legacy lock')
            with self.assertRaises(RepositoryError) as caught:
                repo.delete_profile(profile_id, 0, 'delete')
            self.assertEqual('repository_busy', caught.exception.code)
            self.assertEqual(before, self.images(root, profile_id))
            self.assertEqual(b'manual legacy lock', (root / marker).read_bytes())
            self.assertFalse((root / deletion.JOURNAL).exists())

    def test_stale_owned_markers_reclaimed_only_after_os_guard(self):
        root, repo, profile_id, other = self.prepare()
        for marker in MARKERS:
            (root / marker).write_text(canonical_json({'version': 1, 'owner': 'repository_participant', 'marker': marker}), encoding='utf-8')
        self.assertEqual({'revision': 1}, repo.delete_profile(profile_id, 0, 'delete'))
        self.assertFalse(any((root / marker).exists() for marker in MARKERS))

    def test_all_tactical_writers_take_root_before_local_markers(self):
        root, repo, profile_id, other = self.prepare()
        v1, v2 = TacticalStore(root, repo), TacticalV2Store(root, repo)
        share = TacticalShareV1Store(root, repo, v2)
        functions = (lambda: v1._mutate(profile_id, 0, 'v1', {}, lambda state, owned: None),
                     lambda: v2._mutation(profile_id, 0, 'v2', {}, lambda state: {}),
                     lambda: share._mutate(profile_id, 0, 'share', {}, lambda state: {}))
        lease = acquire(root, RepositoryError)
        try:
            def run(fn):
                try: fn()
                except RepositoryError as error: return error.code
                return 'unexpected success'
            with ThreadPoolExecutor(max_workers=1) as executor:
                self.assertEqual(['repository_busy'] * 3, list(executor.map(run, functions)))
            self.assertFalse(any((root / marker).exists() for marker in MARKERS))
        finally:
            release(lease)

    def test_nested_same_thread_participant_never_reclaims_live_marker(self):
        root, repo, profile_id, other = self.prepare()
        for marker in MARKERS:
            lease = acquire_participant(root, marker, RepositoryError)
            try:
                before = (root / marker).read_bytes()
                with self.assertRaises(RepositoryError) as caught:
                    acquire_participant(root, marker, RepositoryError)
                self.assertEqual('repository_busy', caught.exception.code)
                self.assertEqual(before, (root / marker).read_bytes())
                # A nested repository read keeps the outer participant live.
                self.assertEqual(2, len(repo.list_profiles()['profiles']))
                self.assertEqual(before, (root / marker).read_bytes())
            finally:
                release_participant(lease)
            self.assertFalse((root / marker).exists())

    def test_cross_process_guard_blocks_delete_without_mutation(self):
        root, repo, profile_id, other = self.prepare()
        before = self.images(root, profile_id)
        lease = acquire(root, RepositoryError)
        try:
            script = '''import sys
from pathlib import Path
from core.repository_store import JsonRepository, RepositoryError
try: JsonRepository(Path(sys.argv[1])).delete_profile(sys.argv[2], 0, 'delete')
except RepositoryError as error:
    print(error.code); sys.exit(0 if error.code == 'repository_busy' else 1)
sys.exit(2)
'''
            done = subprocess.run([sys.executable, '-c', script, str(root), profile_id], cwd=BACKEND,
                                  capture_output=True, timeout=15)
            self.assertEqual(0, done.returncode, done.stderr)
            self.assertEqual(b'repository_busy', done.stdout.strip())
            self.assertEqual(before, self.images(root, profile_id))
        finally:
            release(lease)

    def test_deleted_profile_cannot_be_resurrected_by_old_create_retry(self):
        root, repo, profile_id, other = self.prepare()
        repo.delete_profile(profile_id, 0, 'delete')
        with self.assertRaises(RepositoryError) as caught:
            JsonRepository(root).create_profile('Main', 'main')
        self.assertEqual('idempotency_conflict', caught.exception.code)
        fresh = JsonRepository(root).create_profile('Main', 'main-new-key')
        self.assertNotEqual(profile_id, fresh['profile']['profile_id'])

    def test_invalid_stale_and_reused_key_requests_write_nothing(self):
        for args in ((True, 'delete'), (-1, 'delete'), (0, ''), (1, 'delete')):
            root, repo, profile_id, other = self.prepare()
            before = self.images(root, profile_id)
            with self.assertRaises(RepositoryError): repo.delete_profile(profile_id, *args)
            self.assertEqual(before, self.images(root, profile_id))
        root, repo, profile_id, other = self.prepare()
        repo.update_profile(profile_id, 'Main', 'hasumi', 0, 'used')
        before = self.images(root, profile_id)
        with self.assertRaises(RepositoryError) as caught: repo.delete_profile(profile_id, 1, 'used')
        self.assertEqual('idempotency_conflict', caught.exception.code)
        self.assertEqual(before, self.images(root, profile_id))

    def test_protocol_wire_shape_unchanged_and_retry_after_restart(self):
        root, repo, profile_id, other = self.prepare()
        request = {'protocol': 1, 'id': 'delete', 'type': 'request', 'method': 'repository.profile.delete',
                   'payload': {'profile_id': profile_id, 'expected_revision': 0, 'idempotency_key': 'delete'}}
        result = RepositoryProtocolV1(repo, v6_root=root / 'unused').handle(request)
        self.assertEqual({'revision': 1}, result['payload'])
        self.assertEqual(result, RepositoryProtocolV1(JsonRepository(root), v6_root=root / 'unused').handle(request))
        self.assertNotIn('deleted_paths', result['payload'])
        fixture = json.loads((BACKEND.parent / 'contracts/fixtures/profile_delete_fb2d_v1.json').read_text())
        self.assertEqual(7, len(fixture['targets']))
        self.assertFalse(fixture['wire_shape_changed'])

    def test_tactical_reads_trigger_recovery_before_returning_state(self):
        for kind in ('v1', 'v2', 'share'):
            root, repo, profile_id, other = self.prepare()
            before = self.images(root, profile_id)
            self.crash_delete(root, profile_id, 'delete_share_removed')
            fresh = JsonRepository(root)
            v1, v2 = TacticalStore(root, fresh), TacticalV2Store(root, fresh)
            stores = {'v1': v1, 'v2': v2, 'share': TacticalShareV1Store(root, fresh, v2)}
            self.assertEqual(profile_id, stores[kind].state(profile_id)['profile_id'])
            self.assert_complete(root, profile_id, other, before, False)

    def test_noncanonical_target_rejected_before_journal_write(self):
        root, repo, profile_id, other = self.prepare()
        path = root / deletion.targets(profile_id)[6]
        outside = root / 'outside-sentinel'
        outside.write_bytes(b'outside')
        original = Path.is_symlink
        with patch.object(Path, 'is_symlink', lambda p: p == path or original(p)):
            with self.assertRaises((ValueError, RepositoryError)):
                repo.delete_profile(profile_id, 0, 'delete')
        self.assertEqual(b'outside', outside.read_bytes())
        self.assertFalse((root / deletion.JOURNAL).exists())


if __name__ == '__main__':
    unittest.main()
