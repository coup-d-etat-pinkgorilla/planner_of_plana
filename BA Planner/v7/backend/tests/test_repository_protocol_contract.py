from __future__ import annotations

import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator


ROOT = Path(__file__).parents[2]


class RepositoryProtocolContractTests(unittest.TestCase):
    def test_shared_fixture_matches_repository_schema(self) -> None:
        schema = json.loads((ROOT / "contracts/repository-protocol-v1.schema.json").read_text(encoding="utf-8"))
        fixture = json.loads((ROOT / "contracts/fixtures/repository_protocol_v1.json").read_text(encoding="utf-8"))
        validator = Draft202012Validator(schema)
        self.assertEqual(fixture["version"], 1)
        self.assertGreaterEqual(len(fixture["cases"]), 12)
        for case in fixture["cases"]:
            with self.subTest(case_id=case["id"]):
                self.assertEqual(not bool(list(validator.iter_errors(case["message"]))), case["valid"])


if __name__ == "__main__":
    unittest.main()
