from __future__ import annotations

import unittest
from unittest.mock import patch

from PIL import Image

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
                "_match_student_texture_precise",
                side_effect=[
                    ("student_1", 0.98, 0.20),
                    ("student_2", 0.99, 0.25),
                ],
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
                "_match_student_texture_precise",
                return_value=("student_1", 0.98, 0.20),
            ) as precise,
        ):
            result = matcher._match_student_texture_with_topk(
                self.crop,
                self.candidates,
                label="test",
                top_k=10,
                method="fusion",
            )

        self.assertEqual(result, ("student_1", 0.98, 0.20))
        precise.assert_called_once()


if __name__ == "__main__":
    unittest.main()
