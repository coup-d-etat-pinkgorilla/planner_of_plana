from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from core import matcher
from core.student_meta import ids_matching_attributes


class StudentAttributeTemplateTests(unittest.TestCase):
    def test_every_saved_attribute_template_classifies_itself(self) -> None:
        root = Path("templates/student_basic_attributes")
        for field_dir in sorted(path for path in root.iterdir() if path.is_dir()):
            for template in sorted(field_dir.glob("*.png")):
                with self.subTest(field=field_dir.name, label=template.stem):
                    crop = Image.open(template).convert("RGB")
                    result = matcher.read_basic_student_attribute_result(crop, field_dir.name)
                    self.assertEqual(template.stem, result.value)
                    self.assertFalse(result.uncertain)

    def test_complete_attribute_intersection_is_small(self) -> None:
        candidates = ids_matching_attributes({
            "attack_type": "piercing",
            "defense_type": "special",
            "position": "front",
            "combat_class": "striker",
            "role": "tanker",
        })
        self.assertIn("tsubaki", candidates)
        self.assertLessEqual(len(candidates), 10)


class StudentAttributeInjectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.crop = Image.new("RGB", (16, 16), "white")
        self.candidates = {
            "visual": "visual.png",
            "attribute": "attribute.png",
            "other": "other.png",
        }

    def test_attribute_candidate_is_added_outside_visual_topk(self) -> None:
        with (
            patch.object(matcher, "_top_student_texture_candidates", return_value={"visual": "visual.png"}),
            patch.object(matcher, "_student_texture_prefilter_decision", return_value=("attribute", 0.95, 0.20)),
            patch.object(matcher, "_match_student_texture_robust", return_value=("attribute", 0.94, 0.15)) as robust,
            patch.object(matcher, "_match_student_texture_precise") as precise,
        ):
            result = matcher._match_student_texture_with_topk_decision(
                self.crop,
                self.candidates,
                label="test",
                top_k=1,
                method="fusion",
                injected_candidate_ids={"attribute"},
            )
        self.assertEqual(("attribute", 0.94, 0.15, True), result)
        self.assertEqual({"visual", "attribute"}, set(robust.call_args.args[1]))
        precise.assert_not_called()

    def test_visual_winner_outside_attribute_guard_forces_full_fallback(self) -> None:
        with (
            patch.object(matcher, "_top_student_texture_candidates", return_value={"visual": "visual.png"}),
            patch.object(matcher, "_student_texture_prefilter_decision", return_value=("visual", 0.95, 0.20)),
            patch.object(matcher, "_match_student_texture_robust", return_value=("visual", 0.94, 0.15)),
            patch.object(matcher, "_match_student_texture_precise", return_value=("attribute", 0.91, 0.12)) as precise,
        ):
            result = matcher._match_student_texture_with_topk_decision(
                self.crop,
                self.candidates,
                label="test",
                top_k=1,
                method="fusion",
                injected_candidate_ids={"attribute"},
            )
        self.assertEqual(("attribute", 0.91, 0.12, False), result)
        precise.assert_called_once()


if __name__ == "__main__":
    unittest.main()
