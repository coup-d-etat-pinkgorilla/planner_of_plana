from __future__ import annotations

import unittest

import numpy as np
from PIL import Image, ImageDraw

from core.quad_roi import warp_quad_region
from core.screen_crop_set import ScreenCropSet


class ScreenCropSetTests(unittest.TestCase):
    def setUp(self) -> None:
        self.image = Image.new("RGB", (400, 240), (15, 25, 35))
        draw = ImageDraw.Draw(self.image)
        draw.rectangle((80, 48, 199, 119), fill=(220, 180, 60))
        self.regions = {
            "rect": {"x1": 0.2, "y1": 0.2, "x2": 0.5, "y2": 0.5},
            "quad": {
                "points_ratio": [
                    {"x": 0.20, "y": 0.20},
                    {"x": 0.50, "y": 0.20},
                    {"x": 0.48, "y": 0.50},
                    {"x": 0.18, "y": 0.50},
                ],
                "output_size": [64, 40],
            },
        }

    def test_rect_and_quad_are_prepared_without_retaining_full_screen(self) -> None:
        crops = ScreenCropSet.from_image(self.image, self.regions)
        self.assertEqual((120, 72), crops.get("rect").image.size)
        self.assertLess(crops.get("quad").image.width, self.image.width)
        self.assertLess(crops.get("quad").image.height, self.image.height)
        self.assertLess(crops.memory_bytes(), self.image.width * self.image.height * 3)

    def test_prepared_quad_matches_direct_quad(self) -> None:
        crops = ScreenCropSet.from_image(self.image, self.regions)
        prepared = crops.get("quad")
        direct = warp_quad_region(self.image, self.regions["quad"], output_size=(64, 40))
        local = warp_quad_region(prepared.image, prepared.region, output_size=(64, 40))
        delta = np.abs(np.asarray(direct, dtype=np.int16) - np.asarray(local, dtype=np.int16))
        self.assertLess(float(delta.mean()), 0.2)
        self.assertLessEqual(int(delta.max()), 4)


if __name__ == "__main__":
    unittest.main()
