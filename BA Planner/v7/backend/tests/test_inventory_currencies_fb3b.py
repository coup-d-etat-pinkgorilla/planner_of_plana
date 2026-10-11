"""NOT_RUN draft. Normal plan-present atomicity differs from common legacy migration."""
from copy import deepcopy
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from core import inventory_catalog as catalog
from core.repository_dto import canonical_json
from core.repository_protocol_v1 import RepositoryProtocolV1
from core.repository_store import JsonRepository, RepositoryError
from core.repository_transaction import JOURNAL
from core.scan_commit_history_context import ScanCommitHistoryContext

AT = datetime(2026, 10, 10, 6, 0, tzinfo=timezone.utc)
CURRENCIES = ('credits', 'Item_Icon_SecretStone')
MATERIAL = 'Item_Icon_ExpItem_0'


class InventoryCurrenciesFB3bTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.clock_calls = 0
        def clock():
            self.clock_calls += 1
            return AT
        self.repo = JsonRepository(self.root, clock=clock)
        self.pid = self.repo.create_profile('FB3 synthetic', 'create')['profile']['profile_id']

    def snapshot(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes()
                for p in self.root.rglob('*') if p.is_file() and '.repository.' not in p.name}

    @staticmethod
    def inventory(entries):
        return {'version': 1, 'entries': entries}

    def context(self, applied, excluded=(), candidate='seed'):
        # Internal writer fixture, not evidence that currencies have a scanner UI/profile.
        return ScanCommitHistoryContext.from_wire({
            'source': 'scan', 'session_id': 'synthetic-fb3', 'generation': 1,
            'candidate_id': candidate, 'candidate_revision': 0, 'scan_kind': 'item',
            'inventory_scan_profile': 'activity_reports', 'applied_keys': list(applied),
            'excluded_keys': list(excluded), 'retry_of': None}, bucket='inventory')

    def seed(self, quantity='0'):
        rows = [{'key': key, 'quantity': quantity, 'name': 'preserved raw label',
                 'observed_slot': 13} for key in CURRENCIES]
        rows.append({'key': MATERIAL, 'item_id': MATERIAL, 'quantity': '1'})
        self.repo.update_inventory(self.pid, self.inventory(rows), 0, 'seed',
                                   history_context=self.context(CURRENCIES + (MATERIAL,)))
        return deepcopy(self.repo.get_state(self.pid)['inventory'])

    def assert_guard(self, payload, revision, key, manual):
        before, calls = self.snapshot(), self.clock_calls
        with self.assertRaises(RepositoryError) as caught:
            self.repo.update_inventory(self.pid, payload, revision, key, manual=manual)
        self.assertEqual('invalid_payload', caught.exception.code)
        self.assertEqual('currency_read_only', caught.exception.details['reason'])
        self.assertEqual(before, self.snapshot())
        self.assertEqual(calls, self.clock_calls)
        self.assertFalse((self.root / JOURNAL).exists())

    def test_currency_catalog_exact_ids_order_metadata_and_scan_exclusion(self):
        rows = [row.to_dict() for row in catalog.CATALOG if row.profile_id == 'currencies']
        self.assertEqual(list(CURRENCIES), [row['resource_key'] for row in rows])
        self.assertEqual([None, 'Item_Icon_SecretStone'], [row['item_id'] for row in rows])
        self.assertEqual([0, 1], [row['order_index'] for row in rows])
        self.assertTrue(all(row['zero_fill_allowed'] is False for row in rows))
        self.assertTrue(all((row['school'], row['family'], row['tier']) == (None, None, None) for row in rows))
        self.assertEqual(list(CURRENCIES), [row.resource_key for row in catalog.CATALOG[-2:]])
        self.assertNotIn('currencies', catalog.SCAN_PROFILES)
        self.assertNotIn('currencies', catalog.ITEM_SCAN_PROFILES)

    def test_addition_null_and_zero_are_distinct_atomic_manual_and_unattributed(self):
        for manual in (True, False):
            for key in CURRENCIES:
                for quantity in (None, '0', '7'):
                    with self.subTest(manual=manual, key=key, quantity=quantity):
                        self.assert_guard(self.inventory([{'key': key, 'quantity': quantity}]),
                                          0, 'rejected-add', manual)

    def test_quantity_change_and_omission_deletion_are_atomic(self):
        original = self.seed(None)
        for manual in (True, False):
            for key in CURRENCIES:
                for quantity in ('0', '7', 'omit'):
                    changed = deepcopy(original)
                    if quantity == 'omit':
                        changed['entries'] = [row for row in changed['entries'] if row['key'] != key]
                    else:
                        next(row for row in changed['entries'] if row['key'] == key)['quantity'] = quantity
                    with self.subTest(manual=manual, key=key, quantity=quantity):
                        self.assert_guard(changed, 1, 'rejected-change', manual)

    def test_unchanged_full_currency_rows_survive_material_edit_without_snapshot_metadata(self):
        original = self.seed()
        currencies = [row for row in original['entries'] if row['key'] in CURRENCIES]
        changed = deepcopy(original)
        next(row for row in changed['entries'] if row['key'] == MATERIAL)['quantity'] = '2'
        self.repo.update_inventory(self.pid, changed, 1, 'material', manual=True)
        current = self.repo.get_state(self.pid)['inventory']
        self.assertEqual(currencies, [row for row in current['entries'] if row['key'] in CURRENCIES])
        self.assertTrue(all(not {'school', 'family', 'tier'} & set(row) for row in current['entries']))
        self.assertEqual('manual', self.repo._profile(self.pid)['current_history']['events'][-1]['source'])

    def test_same_catalog_pre_guard_receipt_replays_before_guard_and_different_request_conflicts(self):
        payload = self.inventory([{'key': 'credits', 'quantity': '7'}])
        # Same catalog revision: an actual contextless receipt made with only the guard disabled.
        # This does not claim pre-FB3 catalog revisions replay across a catalog hash change.
        with patch('core.repository_store._assert_currency_quantities_unchanged'):
            receipt = self.repo.update_inventory(self.pid, payload, 0, 'old')
        before = self.snapshot()
        fresh = JsonRepository(self.root, clock=lambda: self.fail('Replay sampled clock'))
        self.assertEqual(receipt, fresh.update_inventory(self.pid, payload, 0, 'old'))
        self.assertEqual(before, self.snapshot())
        altered = deepcopy(payload)
        altered['entries'][0]['quantity'] = '8'
        with self.assertRaises(RepositoryError) as caught:
            fresh.update_inventory(self.pid, altered, 0, 'old')
        self.assertEqual('idempotency_conflict', caught.exception.code)
        self.assertEqual(before, self.snapshot())

    def test_catalog_revision_change_preserves_existing_rebase_fingerprint_conflict(self):
        payload = self.inventory([{'key': 'credits', 'quantity': '7'}])
        # TEST_ONLY old revision in a temporary store, never a product parity pin.
        with patch('core.repository_inventory.CATALOG_REVISION', '0' * 64), \
                patch('core.repository_store._assert_currency_quantities_unchanged'):
            self.repo.update_inventory(self.pid, payload, 0, 'old-catalog')
        before, calls = self.snapshot(), self.clock_calls
        with patch('core.repository_store._assert_currency_quantities_unchanged',
                   side_effect=AssertionError('Conflict should precede guard')), \
                self.assertRaises(RepositoryError) as caught:
            self.repo.update_inventory(self.pid, payload, 0, 'old-catalog')
        self.assertEqual('idempotency_conflict', caught.exception.code)
        self.assertEqual(before, self.snapshot())
        self.assertEqual(calls, self.clock_calls)

    def test_public_rpc_reports_reason_and_cannot_forge_internal_source(self):
        protocol = RepositoryProtocolV1(self.repo)
        payload = {'profile_id': self.pid, 'expected_revision': 0, 'idempotency_key': 'rpc',
                   'inventory': self.inventory([{'key': 'credits', 'quantity': '0'}])}
        before = self.snapshot()
        for extra in ({}, {'source': 'scan'}, {'history_context': self.context(['credits']).to_wire()}):
            wire = {'protocol': 1, 'id': 'rpc', 'type': 'request',
                    'method': 'repository.inventory.update', 'payload': {**payload, **extra}}
            error = protocol.handle(wire)['payload']['error']
            self.assertEqual('invalid_payload', error['code'])
            if not extra:
                self.assertEqual('currency_read_only', error['details']['reason'])
            self.assertEqual(before, self.snapshot())

    def test_nochange_scope_updates_only_approved_freshness_and_manual_edit_does_not(self):
        original = self.seed()
        self.repo.update_inventory(self.pid, original, 1, 'nochange',
            history_context=self.context([MATERIAL], CURRENCIES, 'nochange'))
        history = self.repo._profile(self.pid)['current_history']
        self.assertEqual([], history['events'][-1]['inventory_changes'])
        self.assertNotIn('excluded_keys', history['events'][-1])
        def latest():
            result = self.repo.get_history_scan_latest({'profile_id': self.pid,
                'resource_keys': list(CURRENCIES) + [MATERIAL]})
            return {row['resource_key']: row['latest_scan']['sequence'] for row in result['by_resource_key']}
        self.assertEqual({'credits': 1, 'Item_Icon_SecretStone': 1, MATERIAL: 2}, latest())
        changed = deepcopy(original)
        next(row for row in changed['entries'] if row['key'] == MATERIAL)['quantity'] = '2'
        self.repo.update_inventory(self.pid, changed, 2, 'manual-material', manual=True)
        self.assertEqual({'credits': 1, 'Item_Icon_SecretStone': 1, MATERIAL: 2}, latest())

    def test_allowed_material_write_rolls_back_before_commit_then_replays_after_committed_recovery(self):
        original = self.seed()
        changed = deepcopy(original)
        next(row for row in changed['entries'] if row['key'] == MATERIAL)['quantity'] = '2'
        before = self.snapshot()
        def fail(stage):
            if stage == 'before_commit':
                raise OSError('synthetic rollback')
        with self.assertRaises(RepositoryError):
            JsonRepository(self.root, clock=lambda: AT, fault=fail).update_inventory(
                self.pid, changed, 1, 'rollback', manual=True)
        self.repo.get_history_summary([self.pid])
        self.assertEqual(before, self.snapshot())
        def committed(stage):
            if stage == 'journal_committed':
                raise OSError('synthetic committed recovery')
        with self.assertRaises(RepositoryError):
            JsonRepository(self.root, clock=lambda: AT, fault=committed).update_inventory(
                self.pid, changed, 1, 'committed', manual=True)
        self.repo.get_history_summary([self.pid])
        after = self.snapshot()
        fresh = JsonRepository(self.root, clock=lambda: self.fail('Recovered replay sampled clock'))
        self.assertEqual({'revision': 2}, fresh.update_inventory(self.pid, changed, 1, 'committed', manual=True))
        self.assertEqual(after, self.snapshot())

    def test_legacy_plan_absent_migration_precedes_guard_and_may_write_then_revision_conflict(self):
        path = self.repo._profile_path(self.pid)
        legacy = json.loads(path.read_text(encoding='utf-8'))
        legacy.pop('plan')
        path.write_text(canonical_json(legacy), encoding='utf-8')
        before = self.snapshot()
        payload = self.inventory([{'key': 'credits', 'quantity': '0'}])
        with self.assertRaises(RepositoryError) as caught:
            self.repo.update_inventory(self.pid, payload, 0, 'legacy-stale', manual=True)
        self.assertEqual('revision_conflict', caught.exception.code)
        migrated = self.repo._profile(self.pid)
        self.assertIn('plan', migrated)
        self.assertEqual(1, migrated['revision'])
        self.assertNotEqual(before, self.snapshot())
        # Once migrated, normal new-revision refusal is atomic. Do not claim the first call wrote zero bytes.
        self.assert_guard(payload, 1, 'legacy-now-normal', True)


if __name__ == '__main__':
    unittest.main()
