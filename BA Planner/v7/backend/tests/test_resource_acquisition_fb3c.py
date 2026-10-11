"""NOT_RUN draft: packaged empty authority, strict loader, actual protocol/schema/stdio."""
from copy import deepcopy
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource
from core.inventory_catalog import BY_KEY, CATALOG_REVISION
from core.protocol_v1 import PlanningProtocolV1
from core.repository_store import JsonRepository
from core.resource_acquisition import (
    AcquisitionDataError, load_packaged_resource_acquisition, load_resource_acquisition_bytes,
    validate_resource_acquisition, resource_acquisition_payload,
)
from core.stdio_server import serve

ROOT = Path(__file__).resolve().parents[2]
METHOD = 'planning.inventory.acquisition.get'
KEY = 'Item_Icon_ExpItem_0'


def request(key=KEY, **extra):
    return {'protocol': 1, 'id': 'acquisition', 'type': 'request', 'method': METHOD,
            'payload': {'resource_key': key, **extra}}


def table(quantity=None, selectors=None, date='2026-10-10'):
    # TEST_ONLY synthetic metadata. Never install this in backend/data.
    return {'version': 1, 'resources': {KEY: {'methods': [{
        'method_id': 'test-only-method', 'kind': 'shop', 'label': 'TEST_ONLY',
        'weekly_quantity': quantity, 'selector_resource_keys': selectors,
        'source': {'server': 'KR', 'reference': 'TEST_ONLY no current acquisition fact',
                   'reviewed_at': date}}]}}}


class ResourceAcquisitionFB3cTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.known = frozenset(BY_KEY)
        schemas = {p.name: json.loads(p.read_text(encoding='utf-8'))
                   for p in (ROOT / 'contracts').glob('*.schema.json')}
        registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas.values())
        cls.schema = Draft202012Validator(schemas['planning-protocol-v1.schema.json'],
                                         registry=registry, format_checker=FormatChecker())
        cls.local_schema = Draft202012Validator(json.loads((ROOT / 'backend/data/metadata/v1/resource_acquisition.schema.json')
            .read_text(encoding='utf-8')), format_checker=FormatChecker())

    def test_packaged_empty_table_known_null_methods_and_canonical_legacy_alias(self):
        real = load_packaged_resource_acquisition(self.known)
        self.assertEqual({'version': 1, 'resources': {}}, real)
        handler = PlanningProtocolV1()
        for key in (KEY, 'credits', 'Item_Icon_SecretStone', 'Item_Icon_SkillBook_Ultimate_Piece'):
            wire = handler.handle(request(key))
            self.schema.validate(wire)
            payload = wire['payload']
            self.assertEqual({'resource_key', 'methods', 'acquisition_revision'}, set(payload))
            self.assertEqual([], payload['methods'])
            self.assertEqual('Item_Icon_SkillBook_Ultimate' if key.endswith('_Piece') else key, payload['resource_key'])
            self.assertEqual(resource_acquisition_payload(KEY, real)['acquisition_revision'], payload['acquisition_revision'])

    def test_invalid_payload_and_unknown_key_fail_before_table_load(self):
        loader = Mock(side_effect=AssertionError('Invalid/unknown request loaded table'))
        handler = PlanningProtocolV1(resource_acquisition=loader)
        invalid = [request('', page=1), request(True), request('\ud800'), request('x' * 1025)]
        for wire in invalid:
            self.assertEqual('invalid_payload', handler.handle(wire)['payload']['error']['code'])
        unknown = handler.handle(request('test-only:unknown'))
        self.assertEqual('resource_not_found', unknown['payload']['error']['code'])
        self.schema.validate(unknown)
        loader.assert_not_called()

    def test_missing_corrupt_duplicate_and_wrong_version_are_failures_not_known_empty(self):
        for raw in (b'{', b'\xff', b'{"version":1,"version":1,"resources":{}}',
                    b'{"version":true,"resources":{}}', b'{"version":2,"resources":{}}'):
            with self.subTest(raw=raw), self.assertRaises(AcquisitionDataError):
                load_resource_acquisition_bytes(raw, self.known)
        diagnostics = []
        for failure in (OSError('TEST_ONLY missing path'), AcquisitionDataError('TEST_ONLY private detail')):
            handler = PlanningProtocolV1(resource_acquisition=Mock(side_effect=failure), diagnostic=diagnostics.append)
            result = handler.handle(request())
            self.assertEqual('resource_acquisition_failed', result['payload']['error']['code'])
            self.assertNotIn('TEST_ONLY', result['payload']['error']['message'])
            self.schema.validate(result)
        self.assertEqual(2, len(diagnostics))
        with patch('core.resource_acquisition.Path.read_bytes', side_effect=OSError('TEST_ONLY')):
            with self.assertRaises(AcquisitionDataError):
                load_packaged_resource_acquisition(self.known)

    def test_exact_fields_source_real_calendar_and_canonical_quantities(self):
        self.local_schema.validate(table())
        for quantity in ('0', '9007199254740993', None):
            valid = validate_resource_acquisition(table(quantity=quantity), self.known)
            self.assertEqual(quantity, valid['resources'][KEY]['methods'][0]['weekly_quantity'])
        for quantity in (0, 1.0, True, '-1', '01', ' 1 ', '1.5', '１'):
            with self.subTest(quantity=quantity), self.assertRaises(AcquisitionDataError):
                validate_resource_acquisition(table(quantity=quantity), self.known)
        for reviewed in ('2026-02-29', '2026-13-01', '0000-01-01', '2026-1-01'):
            with self.subTest(date=reviewed), self.assertRaises(AcquisitionDataError):
                validate_resource_acquisition(table(date=reviewed), self.known)
        self.local_schema.validate(table(date='2024-02-29'))
        bads = []
        extra = table(); extra['resources'][KEY]['methods'][0]['extra'] = 1; bads.append(extra)
        jp = table(); jp['resources'][KEY]['methods'][0]['source']['server'] = 'JP'; bads.append(jp)
        extra_source = table(); extra_source['resources'][KEY]['methods'][0]['source']['extra'] = None; bads.append(extra_source)
        alias = table(); alias['resources'] = {'Item_Icon_SkillBook_Ultimate_Piece': alias['resources'][KEY]}; bads.append(alias)
        for bad in bads:
            with self.assertRaises(AcquisitionDataError): validate_resource_acquisition(bad, self.known)

    def test_selector_null_empty_order_detachment_and_revision_independence(self):
        revisions = []
        for selectors in (None, [], ['credits', KEY]):
            original = table(selectors=selectors)
            validated = validate_resource_acquisition(original, self.known)
            payload = resource_acquisition_payload(KEY, validated)
            self.assertEqual(selectors, payload['methods'][0]['selector_resource_keys'])
            revisions.append(payload['acquisition_revision'])
            payload['methods'].clear()
            self.assertEqual(1, len(original['resources'][KEY]['methods']))
            self.assertEqual(1, len(validated['resources'][KEY]['methods']))
        self.assertEqual(3, len(set(revisions)))
        self.assertEqual(CATALOG_REVISION, __import__('core.inventory_catalog', fromlist=['CATALOG_REVISION']).CATALOG_REVISION)
        for selectors in ([KEY, KEY], ['test-only:unknown'], ['Item_Icon_SkillBook_Ultimate_Piece']):
            with self.assertRaises(AcquisitionDataError): validate_resource_acquisition(table(selectors=selectors), self.known)

    def test_shared_schema_and_strict_scalar_oracles_stay_distinct(self):
        fixture = json.loads((ROOT / 'contracts/fixtures/resource_acquisition_v1.json').read_text(encoding='utf-8'))
        for group in ('responses', 'requests', 'errors'):
            for case in fixture[group]:
                with self.subTest(case=case['name']):
                    self.assertEqual(case['schema_valid'], self.schema.is_valid(case['wire']))
        for case in fixture['table_cases']:
            with self.subTest(table=case['name']):
                self.assertEqual(case['schema_valid'], self.local_schema.is_valid(case['table']))
                if case['pure_loader_valid']:
                    validate_resource_acquisition(case['table'], self.known)
                else:
                    with self.assertRaises(AcquisitionDataError):
                        validate_resource_acquisition(case['table'], self.known)
        # Strict response oracles are shared for CF to run through its actual Dart DTO.
        self.assertTrue(fixture['strict_response_cases'])
        self.assertTrue(fixture['test_only'])
        self.assertFalse(fixture['current_KR_acquisition_fact'])

    def test_query_is_readonly_for_initialized_store_bytes_clock_revision_and_acquisition_cache(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = JsonRepository(root)
            pid = repo.create_profile('Read-only synthetic', 'create')['profile']['profile_id']
            def snapshot():
                return {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob('*')
                        if p.is_file() and '.repository.' not in p.name}
            before, revision, catalog_revision = snapshot(), repo._profile(pid)['revision'], CATALOG_REVISION
            repo._clock = lambda: self.fail('Acquisition sampled repository clock')
            handler = PlanningProtocolV1()
            for _ in range(2): self.schema.validate(handler.handle(request()))
            self.assertEqual(before, snapshot())
            self.assertEqual(revision, repo._profile(pid)['revision'])
            self.assertEqual(catalog_revision, CATALOG_REVISION)

    def test_real_stdio_process_correlates_catalog_and_acquisition_and_schema(self):
        queries = [{'protocol': 1, 'id': 'catalog', 'type': 'request',
                    'method': 'planning.inventory.catalog', 'payload': {}}, request()]
        # Real JSONL process/catalog/query; no scanner factory or untracked recognition dependencies.
        process = subprocess.run([sys.executable, '-c', 'from core.stdio_server import serve; serve()'], cwd=ROOT / 'backend',
            input='\n'.join(json.dumps(w) for w in queries) + '\n', capture_output=True,
            text=True, encoding='utf-8', timeout=20)
        self.assertEqual(0, process.returncode, process.stderr)
        results = [json.loads(line) for line in process.stdout.splitlines()]
        self.assertEqual(['catalog', 'acquisition'], [row['id'] for row in results])
        self.assertEqual(10, len(results[0]['payload']['items'][0]))
        for wire in results: self.schema.validate(wire)
        self.assertEqual([], results[1]['payload']['methods'])
        stdin, stdout, stderr = io.StringIO(json.dumps(request()) + '\n'), io.StringIO(), io.StringIO()
        self.assertIsNone(serve(stdin, stdout, stderr))
        self.schema.validate(json.loads(stdout.getvalue()))


if __name__ == '__main__':
    unittest.main()
