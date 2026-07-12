from __future__ import annotations

import unittest

from gui.viewer_shared import (
    _equipment_resource_display_name,
    _max_affordable_student_count,
)


class InventoryCapacityPresentationTests(unittest.TestCase):
    def test_equipment_requirement_name_includes_tier(self) -> None:
        self.assertEqual(
            _equipment_resource_display_name(
                "Equipment_Icon_Watch_Tier6",
                "고딕풍 손목 시계",
            ),
            "고딕풍 손목 시계 (T6)",
        )

    def test_capacity_uses_cheapest_current_students_then_full_students(self) -> None:
        self.assertEqual(
            _max_affordable_student_count(1_100, [100, 300, 500], 500),
            3,
        )

    def test_capacity_can_exceed_known_student_cost_rows(self) -> None:
        self.assertEqual(
            _max_affordable_student_count(2_100, [100, 300], 500),
            5,
        )


if __name__ == "__main__":
    unittest.main()
