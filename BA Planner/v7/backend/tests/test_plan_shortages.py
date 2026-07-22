from __future__ import annotations

import unittest
from unittest.mock import patch

from core.plan_shortages import derive_plan_shortages
from core.planning import GrowthPlan, StudentGoal
from core.planning_calc import PlanCostSummary


class PlanShortageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.plan = GrowthPlan(version=1, goals=[StudentGoal(student_id="ayane")])
        self.gross = PlanCostSummary(
            credits=777,
            level_exp_items={"Item_Icon_ExpItem_0 T1": 5, "unknown material": 2},
        )
        self.per_student = PlanCostSummary(
            level_exp_items={"Item_Icon_ExpItem_0 T1": 5, "unknown material": 2}
        )

    def _derive(self, entries: list[dict[str, object]]) -> dict[str, object]:
        with (
            patch("core.plan_shortages.calculate_plan_totals", return_value=self.gross),
            patch("core.plan_shortages.calculate_goal_cost", return_value=self.per_student),
        ):
            return derive_plan_shortages({"ayane": object()}, self.plan, entries)

    def test_explicit_zero_unknown_unresolved_and_affected_students_are_distinct(self) -> None:
        result = self._derive([
            {"key": "Item_Icon_ExpItem_0", "item_id": "Item_Icon_ExpItem_0", "quantity": "0"},
        ])
        by_key = {row["resource_key"]: row for row in result["rows"]}
        known = by_key["Item_Icon_ExpItem_0"]
        self.assertEqual((known["required"], known["owned"], known["shortage"]), (5, 0, 5))
        self.assertEqual(known["affected_student_ids"], ["ayane"])
        unresolved = by_key["unresolved:unknown material"]
        self.assertIsNone(unresolved["owned"])
        self.assertIsNone(unresolved["shortage"])
        self.assertFalse(unresolved["resolved"])
        self.assertNotIn("gross_totals", result)
        self.assertEqual(self.gross.credits, 777)

    def test_missing_and_null_quantity_are_unknown(self) -> None:
        missing = self._derive([])["rows"][0]
        explicit_unknown = self._derive([
            {"key": "Item_Icon_ExpItem_0", "item_id": "Item_Icon_ExpItem_0", "quantity": None},
        ])["rows"][0]
        self.assertIsNone(missing["owned"])
        self.assertIsNone(missing["shortage"])
        self.assertIsNone(explicit_unknown["owned"])
        self.assertIsNone(explicit_unknown["shortage"])

    def test_name_only_guess_duplicate_and_noncanonical_quantity_are_rejected(self) -> None:
        name_only = self._derive([
            {"key": "legacy-name-row", "name": "Activity report T1", "quantity": "4"},
        ])["rows"][0]
        self.assertIsNone(name_only["owned"])
        with self.assertRaises(ValueError):
            self._derive([
                {"key": "Item_Icon_ExpItem_0", "quantity": "1"},
                {"key": "Item_Icon_ExpItem_0", "quantity": "2"},
            ])
        for invalid in ("", "-1", "01", "١", 1):
            with self.subTest(quantity=invalid), self.assertRaises(ValueError):
                self._derive([{"key": "Item_Icon_ExpItem_0", "quantity": invalid}])


if __name__ == "__main__":
    unittest.main()
