from __future__ import annotations

import json
import unittest
from dataclasses import asdict
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace

from core.planning import GrowthPlan, StudentGoal, load_plan, save_plan
from core.planning_calc import calculate_goal_cost
from core.runtime_paths import PLANNING_DATA_DIR


FIXTURE_PATH = Path(__file__).parents[2] / "contracts" / "fixtures" / "planning_v6_parity.json"


class PlanningParityTests(unittest.TestCase):
    def test_v6_cost_fixture_is_unchanged(self) -> None:
        fixture = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
        record = SimpleNamespace(**fixture["record"])
        goal = StudentGoal(**fixture["goal"])

        self.assertEqual(asdict(calculate_goal_cost(record, goal)), fixture["expected"])

    def test_plan_round_trip_and_unknown_field_compatibility(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "growth_plan.json"
            path.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "goals": [
                            {
                                "student_id": "ayane",
                                "target_level": 999,
                                "future_field": "ignored",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            loaded = load_plan(path)
            self.assertEqual(loaded.goals[0].target_level, 90)
            save_plan(path, GrowthPlan(goals=loaded.goals))
            self.assertEqual(load_plan(path), loaded)

    def test_packaged_planning_tables_are_available(self) -> None:
        self.assertTrue((PLANNING_DATA_DIR / "reference_tables.json").is_file())
        self.assertTrue((PLANNING_DATA_DIR / "student_growth_patterns.json").is_file())


if __name__ == "__main__":
    unittest.main()

