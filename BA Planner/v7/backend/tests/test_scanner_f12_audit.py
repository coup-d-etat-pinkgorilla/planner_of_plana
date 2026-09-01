from __future__ import annotations

import json
import unittest
from pathlib import Path

from tools.audit_scanner_f12 import ROOT, build_audit


class ScannerF12AuditTests(unittest.TestCase):
    def test_contract_forbids_mutating_validation_actions(self) -> None:
        path = ROOT / "backend/tests/fixtures/scanner_fallback_restoration/f12-integration-contract.json"
        contract = json.loads(path.read_text(encoding="utf-8"))
        forbidden = set(contract["safety"]["forbidden"])
        self.assertTrue(
            {
                "automatic repository commit",
                "automatic profile write",
                "automatic permanent learning",
            }
            <= forbidden
        )

    def test_all_restoration_rows_resolve_to_code_fixture_test_and_result(self) -> None:
        audit = build_audit()
        self.assertEqual([row["id"] for row in audit["rows"]], [f"R{i:02d}" for i in range(1, 25)])
        self.assertEqual(audit["summary"]["failed"], [])
        self.assertTrue(all(row["trace_partition"] == "historical_native_scan" for row in audit["rows"]))


if __name__ == "__main__":
    unittest.main()
