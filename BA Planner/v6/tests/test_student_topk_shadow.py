from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from PIL import Image, ImageDraw

from core import matcher


class StudentTopKShadowTests(unittest.TestCase):
    def setUp(self) -> None:
        self.crop = Image.new("RGB", (16, 16), "white")
        self.candidates = {f"student_{index}": f"template_{index}.png" for index in range(11)}

    def test_fusion10_is_the_default_without_environment_override(self) -> None:
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(matcher._student_texture_topk_from_env(), 10)
            self.assertEqual(matcher._student_texture_topk_method_from_env(), "fusion")

    def test_shadow_mode_returns_authoritative_full_pool_result(self) -> None:
        with (
            patch.dict("os.environ", {matcher.STUDENT_TEXTURE_TOPK_SHADOW_ENV: "1"}),
            patch.object(
                matcher,
                "_top_student_texture_candidates",
                return_value={"student_1": "template_1.png"},
            ),
            patch.object(
                matcher,
                "_student_texture_prefilter_decision",
                return_value=("student_1", 0.98, 0.20),
            ),
            patch.object(
                matcher,
                "_match_student_texture_robust",
                return_value=("student_1", 0.95, 0.20),
            ),
            patch.object(
                matcher,
                "_match_student_texture_precise",
                return_value=("student_2", 0.99, 0.25),
            ),
        ):
            result = matcher._match_student_texture_with_topk(
                self.crop,
                self.candidates,
                label="test",
                top_k=10,
                method="fusion",
            )

        self.assertEqual(result, ("student_2", 0.99, 0.25))

    def test_normal_mode_keeps_topk_shortcut_result(self) -> None:
        with (
            patch.dict("os.environ", {matcher.STUDENT_TEXTURE_TOPK_SHADOW_ENV: "0"}),
            patch.object(
                matcher,
                "_top_student_texture_candidates",
                return_value={"student_1": "template_1.png"},
            ),
            patch.object(
                matcher,
                "_student_texture_prefilter_decision",
                return_value=("student_1", 0.98, 0.20),
            ),
            patch.object(
                matcher,
                "_match_student_texture_robust",
                return_value=("student_1", 0.95, 0.20),
            ) as robust,
            patch.object(matcher, "_match_student_texture_precise") as precise,
        ):
            result = matcher._match_student_texture_with_topk(
                self.crop,
                self.candidates,
                label="test",
                top_k=10,
                method="fusion",
            )

        self.assertEqual(result, ("student_1", 0.95, 0.20))
        robust.assert_called_once()
        precise.assert_not_called()

    def test_near_consensus_fast_verifies_single_winner(self) -> None:
        with (
            patch.dict("os.environ", {matcher.STUDENT_TEXTURE_TOPK_SHADOW_ENV: "0"}),
            patch.object(
                matcher,
                "_top_student_texture_candidates",
                return_value={"student_1": "template_1.png", "student_2": "template_2.png"},
            ),
            patch.object(
                matcher,
                "_student_texture_prefilter_decision",
                return_value=("student_1", 0.98, 0.07),
            ),
            patch.object(
                matcher,
                "_match_student_texture_robust",
                return_value=("student_1", 0.84, 0.21),
            ),
            patch.object(
                matcher,
                "_match_student_texture_precise",
                return_value=("student_1", 0.72, 0.72),
            ) as precise,
        ):
            result = matcher._match_student_texture_with_topk(
                self.crop,
                self.candidates,
                label="test",
                top_k=10,
                method="fusion",
            )

        self.assertEqual(result, ("student_1", 0.72, 0.72))
        precise.assert_called_once()
        self.assertEqual({"student_1": "template_1.png"}, precise.call_args.args[1])

    def test_failed_fast_verify_still_falls_back_to_full_pool(self) -> None:
        with (
            patch.object(
                matcher,
                "_top_student_texture_candidates",
                return_value={"student_1": "template_1.png", "student_2": "template_2.png"},
            ),
            patch.object(
                matcher,
                "_student_texture_prefilter_decision",
                return_value=("student_1", 0.98, 0.07),
            ),
            patch.object(
                matcher,
                "_match_student_texture_robust",
                return_value=("student_1", 0.84, 0.21),
            ),
            patch.object(
                matcher,
                "_match_student_texture_precise",
                side_effect=[(None, 0.65, 0.65), ("student_3", 0.91, 0.16)],
            ) as precise,
        ):
            result = matcher._match_student_texture_with_topk(
                self.crop,
                self.candidates,
                label="test",
                top_k=10,
                method="fusion",
            )

        self.assertEqual(result, ("student_3", 0.91, 0.16))
        self.assertEqual(2, precise.call_count)
        self.assertEqual({"student_1": "template_1.png"}, precise.call_args_list[0].args[1])
        self.assertEqual(self.candidates, precise.call_args_list[1].args[1])

    def test_consensus_disagreement_falls_back_to_full_pool(self) -> None:
        with (
            patch.object(
                matcher,
                "_top_student_texture_candidates",
                return_value={"student_1": "template_1.png"},
            ),
            patch.object(
                matcher,
                "_student_texture_prefilter_decision",
                return_value=("student_1", 0.98, 0.20),
            ),
            patch.object(
                matcher,
                "_match_student_texture_robust",
                return_value=("student_2", 0.95, 0.20),
            ),
            patch.object(
                matcher,
                "_match_student_texture_precise",
                return_value=("student_3", 0.91, 0.16),
            ) as precise,
        ):
            result = matcher._match_student_texture_with_topk(
                self.crop,
                self.candidates,
                label="test",
                top_k=10,
                method="fusion",
            )

        self.assertEqual(result, ("student_3", 0.91, 0.16))
        precise.assert_called_once()

    def test_robust_score_tolerates_window_resampling(self) -> None:
        template = Image.new("RGB", (320, 300), (32, 48, 64))
        draw = ImageDraw.Draw(template)
        draw.ellipse((70, 35, 245, 230), fill=(220, 150, 90))
        draw.rectangle((125, 110, 175, 285), fill=(45, 175, 220))

        small = template.resize((160, 150), Image.Resampling.LANCZOS)
        sample = small.resize(template.size, Image.Resampling.LANCZOS)

        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "student.png"
            template.save(path)
            score = matcher._student_texture_robust_score(sample, str(path))

        self.assertGreater(score, 0.85)


if __name__ == "__main__":
    unittest.main()
