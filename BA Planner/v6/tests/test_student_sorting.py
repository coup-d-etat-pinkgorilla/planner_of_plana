from __future__ import annotations

import unittest
from types import SimpleNamespace

from gui.student_filters import student_growth_sort_key


class StudentGrowthSortKeyTests(unittest.TestCase):
    def test_uses_current_student_star_before_weapon_star(self) -> None:
        four_star = SimpleNamespace(star=4, weapon_star=5)
        five_star = SimpleNamespace(star=5, weapon_star=None)

        self.assertLess(student_growth_sort_key(four_star), student_growth_sort_key(five_star))

    def test_uses_weapon_star_to_rank_students_after_five_star(self) -> None:
        five_star = SimpleNamespace(star=5, weapon_star=None)
        ue_two = SimpleNamespace(star=5, weapon_star=2)
        ue_three = SimpleNamespace(star=5, weapon_star=3)

        self.assertEqual(
            sorted((ue_two, five_star, ue_three), key=student_growth_sort_key),
            [five_star, ue_two, ue_three],
        )

    def test_ignores_weapon_star_below_five_star(self) -> None:
        unexpected_weapon_value = SimpleNamespace(star=4, weapon_star=3)

        self.assertEqual(student_growth_sort_key(unexpected_weapon_value), (4, 0))


if __name__ == "__main__":
    unittest.main()
