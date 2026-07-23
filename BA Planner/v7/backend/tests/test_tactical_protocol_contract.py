from __future__ import annotations

import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator, FormatChecker


ROOT = Path(__file__).resolve().parents[2]


class TacticalProtocolContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        schema = json.loads((ROOT / "contracts/tactical-protocol-v1.schema.json").read_text(encoding="utf-8"))
        cls.fixture = json.loads((ROOT / "contracts/fixtures/tactical_protocol_v1.json").read_text(encoding="utf-8"))
        cls.validator = Draft202012Validator(schema, format_checker=FormatChecker())

    def test_shared_fixture_matches_schema_expectations(self) -> None:
        self.assertEqual(1, self.fixture["version"])
        for case in self.fixture["cases"]:
            with self.subTest(case=case["name"]):
                self.assertEqual(case["valid"], self.validator.is_valid(case["message"]))

    def test_schema_rejects_duplicate_deck_semantically_in_store(self) -> None:
        # JSON Schema protects shape; canonical store validation protects catalog class and duplicates.
        valid = self.fixture["cases"][2]["message"]
        self.assertTrue(self.validator.is_valid(valid))


if __name__ == "__main__":
    unittest.main()
