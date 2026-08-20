from __future__ import annotations

import unittest

from core.planning_document import planning_document_from_wire
from tools.seed_ui_test_profile import scenario_specs


class SeedUiTestProfileTests(unittest.TestCase):
    def test_eight_named_scenarios_are_valid_and_cover_list_shapes(self) -> None:
        scenarios = scenario_specs()

        self.assertEqual(len(scenarios), 8)
        self.assertEqual(len({name for name, _description, _document in scenarios}), 8)
        documents = [planning_document_from_wire(document) for _name, _description, document in scenarios]
        self.assertTrue(all(document.kind == "scenario" for document in documents))
        self.assertTrue(any(len(document.phases) > 1 for document in documents))
        self.assertTrue(any(len(document.phases[0].stages) >= 9 for document in documents))


if __name__ == "__main__":
    unittest.main()
