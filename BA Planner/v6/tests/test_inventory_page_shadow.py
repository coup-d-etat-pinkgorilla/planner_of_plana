from __future__ import annotations

import unittest

from core.inventory_page_shadow import (
    InventoryPageShadowResult,
    InventoryShadowAssignment,
    InventoryShadowCandidate,
    InventoryShadowSlotEvidence,
    solve_inventory_shadow_page,
)


class InventoryPageShadowSolverTests(unittest.TestCase):
    def test_joint_order_resolves_ambiguous_middle_slot(self) -> None:
        evidence = (
            InventoryShadowSlotEvidence(0, (InventoryShadowCandidate("a", 0.92, 0),)),
            InventoryShadowSlotEvidence(
                1,
                (
                    InventoryShadowCandidate("a", 0.91, 0),
                    InventoryShadowCandidate("b", 0.86, 1),
                ),
            ),
            InventoryShadowSlotEvidence(2, (InventoryShadowCandidate("c", 0.94, 2),)),
        )

        result = solve_inventory_shadow_page(evidence)

        self.assertEqual([row.item_id for row in result], ["a", "b", "c"])

    def test_missing_profile_positions_are_allowed(self) -> None:
        evidence = (
            InventoryShadowSlotEvidence(0, (InventoryShadowCandidate("a", 0.90, 0),)),
            InventoryShadowSlotEvidence(1, (InventoryShadowCandidate("d", 0.91, 3),)),
        )

        result = solve_inventory_shadow_page(evidence)

        self.assertEqual([row.item_id for row in result], ["a", "d"])

    def test_weak_candidate_remains_unresolved(self) -> None:
        evidence = (
            InventoryShadowSlotEvidence(0, (InventoryShadowCandidate("a", 0.54, 0),)),
        )

        result = solve_inventory_shadow_page(evidence, min_score=0.55)

        self.assertEqual(result[0].item_id, None)

    def test_shadow_comparison_reports_without_changing_actual_values(self) -> None:
        actual = {0: "a", 1: "legacy", 3: "actual-only"}
        result = InventoryPageShadowResult(
            (
                InventoryShadowAssignment(0, "a", 0.9, 0),
                InventoryShadowAssignment(1, "b", 0.8, 1),
                InventoryShadowAssignment(2, "shadow-only", 0.7, 2),
            ),
            worker_count=2,
        )

        comparison = result.comparison(actual)

        self.assertEqual(
            comparison,
            {"comparable": 2, "agreed": 1, "disagreed": 1, "shadow_only": 1, "actual_only": 1},
        )
        self.assertEqual(actual, {0: "a", 1: "legacy", 3: "actual-only"})


if __name__ == "__main__":
    unittest.main()
