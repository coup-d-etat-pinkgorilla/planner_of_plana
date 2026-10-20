"""Forward contract only; does not claim practice runtime or native replay."""
from copy import deepcopy
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

ROOT = Path(__file__).parents[2] / 'contracts'


class TutorialPracticeContractTests(unittest.TestCase):
    def setUp(self):
        self.schema = json.loads((ROOT/'tutorial-practice-v1.schema.json').read_text())
        Draft202012Validator.check_schema(self.schema)
        self.validator = Draft202012Validator(self.schema)
        self.fixture = json.loads((ROOT/'fixtures/tutorial_practice_v1.json').read_text())

    def test_all_frozen_request_response_and_negative_cases(self):
        self.assertIs(self.fixture['runtimeImplemented'], False)
        for case in self.fixture['cases']:
            with self.subTest(case=case['id']):
                self.assertEqual(self.validator.is_valid(case['message']), case['valid'])

    def test_unknown_request_keys_and_nonboolean_practice_profile_rejected(self):
        case = deepcopy(self.fixture['cases'][0]['message'])
        case['payload']['real_profile_data'] = {'overwrite':True}
        self.assertFalse(self.validator.is_valid(case))
        for flag in (0,1,None,'true'):
            case = deepcopy(self.fixture['cases'][1]['message'])
            case['payload']['practice']['is_practice'] = flag
            self.assertFalse(self.validator.is_valid(case))

    def test_end_reason_and_revision_are_strict(self):
        case = next(deepcopy(c['message']) for c in self.fixture['cases']
                    if c['message']['method']=='repository.practice.end' and c['message']['type']=='request')
        case['payload']['reason'] = 'delete-real-account'
        self.assertFalse(self.validator.is_valid(case))
        case['payload']['reason'] = 'completed';case['payload']['expected_revision'] = True
        self.assertFalse(self.validator.is_valid(case))

    def test_profile_extension_is_optional_for_legacy_regular_profiles(self):
        ext = self.schema['$defs']['readProfileExtension']
        validator = Draft202012Validator(ext)
        self.assertTrue(validator.is_valid({}))
        self.assertTrue(validator.is_valid({'is_practice':False}))
        self.assertFalse(validator.is_valid({'is_tutorial':True}))


if __name__ == '__main__':
    unittest.main()
