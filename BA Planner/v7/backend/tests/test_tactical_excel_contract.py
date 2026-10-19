from copy import deepcopy
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator, FormatChecker
from core.tactical_v2 import TacticalProtocolV2
from tests import test_tactical_excel_store as store_tests
from tests.test_tactical_excel_interpreter import values, resolution


class ExcelContractTests(unittest.TestCase):
    def setUp(self):
        self.case = store_tests.ExcelAtomicBatchTests()
        self.case.setUp()
        path = Path(__file__).resolve().parents[2] / 'contracts/tactical-protocol-v2.schema.json'
        schema = json.loads(path.read_text(encoding='utf-8'))
        Draft202012Validator.check_schema(schema)
        self.validator = Draft202012Validator(schema, format_checker=FormatChecker())
        self.protocol = TacticalProtocolV2(self.case.store)

    def tearDown(self):
        self.case.tearDown()

    def request(self, method, payload):
        request = {'protocol': 1, 'id': 'excel-contract', 'type': 'request', 'method': method, 'payload': payload}
        self.assertEqual([], list(self.validator.iter_errors(request)))
        result = self.protocol.handle(request)
        self.assertEqual([], list(self.validator.iter_errors(result)))
        return result

    def test_actual_preview_commit_state_and_error_match_strict_schema(self):
        self.request('tactical.v2.excel.preview', self.case.data)
        self.request('tactical.v2.excel.commit', self.case.request(save_rules=True))
        self.request('tactical.v2.state.get', {'profile_id': self.case.profile})
        raw = self.case.request('bad'); raw['expected_fingerprint'] = 'b' * 64
        self.assertEqual('import_source_changed', self.request('tactical.v2.excel.commit', raw)['payload']['error']['code'])

    def test_unresolved_groups_and_explicit_choices_match_schema(self):
        self.case.write(values(opponent='Rival', own_striker_1='무장리오', result='승(2트)', attempts=''))
        result = self.request('tactical.v2.excel.preview', self.case.data)
        self.assertTrue(result['payload']['string_groups'])
        raw = self.case.request('unresolved')
        self.assertEqual('import_review_required', self.request('tactical.v2.excel.commit', raw)['payload']['error']['code'])

    def test_missing_mapping_requires_approval_and_is_typed(self):
        raw = deepcopy(self.case.data); raw['column_mapping'] = None
        self.assertEqual('mapping_confirmation_required', self.request('tactical.v2.excel.preview', raw)['payload']['issues'][0]['code'])

    def test_mutated_response_element_types_and_extra_fields_are_rejected(self):
        response = self.request('tactical.v2.excel.preview', self.case.data)
        for change in ('row_extra','raw_extra','summary_type','status','match_type'):
            bad = deepcopy(response)
            if change == 'row_extra': bad['payload']['rows'][0]['unexpected'] = True
            if change == 'raw_extra': bad['payload']['rows'][0]['raw_cells'][0]['unexpected'] = True
            if change == 'summary_type': bad['payload']['summary']['eligible_rows'] = True
            if change == 'status': bad['payload']['rows'][0]['status'] = 'auto_accepted'
            if change == 'match_type': bad['payload']['rows'][0]['match']['attempt_count'] = True
            with self.subTest(change=change): self.assertTrue(list(self.validator.iter_errors(bad)))

    def test_resolution_and_mapping_invalid_shapes_are_rejected(self):
        valid = {'protocol': 1, 'id': 'excel', 'type': 'request', 'method': 'tactical.v2.excel.preview', 'payload': deepcopy(self.case.data)}
        for change in ('resolution_extra','wildcard_required','bool_column','duplicate_unknown','overwrite_null'):
            bad = deepcopy(valid)
            if change == 'resolution_extra': bad['payload']['resolutions'][0]['auto'] = True
            if change == 'wildcard_required': bad['payload']['resolutions'] = [resolution('attempts', '', action='wildcard')]
            if change == 'bool_column': bad['payload']['column_mapping']['columns']['date'] = True
            if change == 'duplicate_unknown': bad['payload']['column_mapping']['columns']['other'] = 19
            if change == 'overwrite_null': bad['payload']['row_decisions'] = [{'row': 2, 'action': 'overwrite', 'target_match_id': None}]
            with self.subTest(change=change): self.assertTrue(list(self.validator.iter_errors(bad)))


if __name__ == '__main__':
    unittest.main()
