from __future__ import annotations

from pathlib import Path
import unittest

from PIL import Image

from core.studio_roi_suggestion import extract_studio_roi, load_studio_suggestion


ROOT = Path(__file__).resolve().parents[2]
SUGGESTION = ROOT / "suggestion.json"


class StudioRoiSuggestionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.suggestion = load_studio_suggestion(SUGGESTION)

    def test_user_studio_file_has_expected_reference_and_named_digit_rois(self) -> None:
        self.assertEqual((2560, 1440), self.suggestion.reference_size)
        self.assertEqual(16, len(self.suggestion.rois))
        self.assertEqual(
            {
                "weaponlevel_digit1", "weaponlevel_digit2",
                "equip1level_digit1", "equip1level_digit2",
                "equip2level_digit1", "equip2level_digit2",
                "equip3level_digit1", "equip3level_digit2",
                "studentlevel_digit1", "studentlevel_digit2",
                "affectionlevel_digit1", "affectionlevel_digit2",
                "affectionlevel_1digit_digit1",
                "affectionlevel_3digit_digit1", "affectionlevel_3digit_digit2",
                "affectionlevel_3digit_digit3",
            },
            {roi.name for roi in self.suggestion.rois},
        )

    def test_points_preserve_v6_studio_slant_bounding_geometry(self) -> None:
        student = next(roi for roi in self.suggestion.rois if roi.name == "studentlevel_digit1")
        self.assertEqual("parallelogram", student.shape)
        self.assertEqual(8, student.slant)
        self.assertEqual(((120.0, 1197.0), (138.0, 1197.0), (130.0, 1224.0), (112.0, 1224.0)), student.points)
        self.assertEqual(26, int(max(x for x, _y in student.points) - min(x for x, _y in student.points)))

    def test_exact_reference_extract_keeps_source_pixels_and_polygon_alpha(self) -> None:
        roi = next(roi for roi in self.suggestion.rois if roi.name == "weaponlevel_digit1")
        with Image.open(self.suggestion.reference_path) as opened:
            source = opened.convert("RGBA")
        crop = extract_studio_roi(source, roi, reference_size=self.suggestion.reference_size)
        try:
            self.assertEqual((30, 32), crop.size)
            alpha = crop.getchannel("A")
            self.assertEqual(0, alpha.getpixel((0, 0)))
            self.assertEqual(255, alpha.getpixel((15, 16)))
            left = int(min(x for x, _y in roi.points))
            top = int(min(y for _x, y in roi.points))
            for y in range(crop.height):
                for x in range(crop.width):
                    if alpha.getpixel((x, y)):
                        self.assertEqual(
                            source.getpixel((left + x, top + y))[:3],
                            crop.getpixel((x, y))[:3],
                        )
        finally:
            crop.close()
            source.close()

    def test_template_extract_intersects_polygon_with_existing_alpha(self) -> None:
        roi = next(roi for roi in self.suggestion.rois if roi.name == "weaponlevel_digit1")
        source = Image.new("RGBA", self.suggestion.reference_size)
        source.putpixel((1620, 930), (255, 255, 255, 255))
        crop = extract_studio_roi(
            source,
            roi,
            reference_size=self.suggestion.reference_size,
            preserve_source_alpha=True,
        )
        try:
            alpha = crop.getchannel("A")
            self.assertEqual(1, sum(value > 0 for value in alpha.getdata()))
        finally:
            crop.close()
            source.close()


if __name__ == "__main__":
    unittest.main()
