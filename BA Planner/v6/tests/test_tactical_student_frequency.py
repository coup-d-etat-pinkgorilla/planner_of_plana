import unittest

import core.student_meta as student_meta
from core.tactical_challenge import (
    TacticalChallengeData,
    TacticalDeck,
    TacticalMatch,
    tactical_student_frequency,
)


class TacticalStudentFrequencyTest(unittest.TestCase):
    def _student_for_role(self, role: str) -> str:
        for student_id in student_meta.all_ids():
            if student_meta.combat_class(student_id) == role:
                return student_id
        raise AssertionError(f"no student for role {role}")

    def test_counts_current_season_students_by_role(self) -> None:
        striker = self._student_for_role("striker")
        special = self._student_for_role("special")
        old_striker = next(
            student_id
            for student_id in student_meta.all_ids()
            if student_meta.combat_class(student_id) == "striker" and student_id != striker
        )
        data = TacticalChallengeData(
            season="season-a",
            matches=[
                TacticalMatch(
                    id="current",
                    date="2026-07-03",
                    opponent="",
                    result="win",
                    season="season-a",
                    my_attack=TacticalDeck(strikers=[student_meta.display_name(striker)], supports=[student_meta.display_name(special)]),
                    opponent_defense=TacticalDeck(strikers=[student_meta.display_name(striker)]),
                ),
                TacticalMatch(
                    id="old",
                    date="2026-06-01",
                    opponent="",
                    result="loss",
                    season="season-b",
                    my_attack=TacticalDeck(strikers=[student_meta.display_name(old_striker)]),
                ),
            ],
        )

        ranked = tactical_student_frequency(data, "season-a", limit=20)

        self.assertEqual(striker, ranked["striker"][0])
        self.assertEqual(special, ranked["special"][0])
        self.assertNotIn(old_striker, ranked["striker"])


if __name__ == "__main__":
    unittest.main()