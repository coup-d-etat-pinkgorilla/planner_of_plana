"""C0 golden: fixed replay inputs must keep producing byte-identical candidate JSON.

A diff here in a behavior-preserving phase (C3, C4, C6) is a stop condition; record the
reason in almanac/workflows/scanner-structural-consolidation-status.md before any rewrite
with `py -3.11 -m tools.scanner_consolidation_replay --write`.
"""
import difflib
import unittest

from tools.scanner_consolidation_replay import dumps, golden_path, load_scenarios, run_scenario, verify_inputs


REQUIRED_COVERAGE = {
    "student_single_mika_1280", "student_full_ring_1280", "student_forms_hoshino_1280",
    "inventory_item_tech_notes_1280", "inventory_equipment_1280",
}


class ScannerConsolidationGoldenTests(unittest.TestCase):
    def test_scenario_set_covers_c0_combinations(self):
        ids = {scenario["id"] for scenario in load_scenarios()}
        self.assertLessEqual(REQUIRED_COVERAGE, ids)
        for scenario_id in ids:
            self.assertTrue(golden_path(scenario_id).is_file(), scenario_id)

    def test_replay_matches_golden_including_evidence_order(self):
        for scenario in load_scenarios():
            with self.subTest(scenario=scenario["id"]):
                self.assertEqual([], verify_inputs(scenario), "recorded input frames changed")
                expected = golden_path(scenario["id"]).read_text(encoding="utf-8").replace("\r\n", "\n")
                actual = dumps(run_scenario(scenario))
                if actual != expected:
                    diff = "".join(difflib.unified_diff(
                        expected.splitlines(True), actual.splitlines(True), "golden", "replay", n=2))
                    self.fail(f"{scenario['id']} golden diff:\n{diff[:6000]}")


if __name__ == "__main__":
    unittest.main()
