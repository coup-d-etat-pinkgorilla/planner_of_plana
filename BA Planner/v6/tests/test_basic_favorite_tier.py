from __future__ import annotations

from pathlib import Path
import unittest

from PIL import Image

from core.config import TEMPLATE_DIR
from core.matcher import read_basic_favorite_tier_result


class BasicFavoriteTierTests(unittest.TestCase):
    REGION = {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0}

    def test_reads_dedicated_tier_templates(self) -> None:
        for tier in ("T1", "T2"):
            with self.subTest(tier=tier):
                image = Image.open(
                    Path(TEMPLATE_DIR) / "equip4_basic" / f"equip4_{tier}.png"
                ).convert("RGB")
                result = read_basic_favorite_tier_result(image, self.REGION)
                self.assertEqual(result.value, tier)
                self.assertFalse(result.uncertain)

    def test_blank_slot_does_not_guess_a_tier(self) -> None:
        image = Image.new("RGB", (35, 30), "white")
        result = read_basic_favorite_tier_result(image, self.REGION)
        self.assertIsNone(result.value)
        self.assertTrue(result.uncertain)


if __name__ == "__main__":
    unittest.main()
