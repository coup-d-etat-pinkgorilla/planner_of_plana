import unittest

from core.tactical_screenshot import _CandidateScore, _merge_candidate_scores


class TacticalScreenshotCandidateTests(unittest.TestCase):
    def test_merge_reranks_fallback_candidates_ahead_of_priority_candidates(self) -> None:
        priority = [
            _CandidateScore(0.68, "sumire"),
            _CandidateScore(0.67, "yuuka"),
        ]
        fallback = [
            _CandidateScore(0.90, "aris"),
            _CandidateScore(0.75, "kazusa"),
        ]

        ranked = _merge_candidate_scores(priority, fallback)

        self.assertEqual(["aris", "kazusa", "sumire", "yuuka"], [row.student_id for row in ranked])

    def test_merge_keeps_best_score_when_cache_and_full_pool_overlap(self) -> None:
        cached = [_CandidateScore(0.86, "aris")]
        full_pool = [
            _CandidateScore(0.90, "aris"),
            _CandidateScore(0.75, "kazusa"),
        ]

        ranked = _merge_candidate_scores(cached, full_pool)

        self.assertEqual(["aris", "kazusa"], [row.student_id for row in ranked])
        self.assertAlmostEqual(0.90, ranked[0].score)


if __name__ == "__main__":
    unittest.main()
