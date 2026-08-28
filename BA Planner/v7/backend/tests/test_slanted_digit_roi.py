from __future__ import annotations

import unittest

from PIL import Image, ImageDraw

from core.slanted_digit_roi import split_parallelogram_digit_cells


class SlantedDigitRoiTests(unittest.TestCase):
    @staticmethod
    def _two_digit_mask() -> Image.Image:
        mask = Image.new("L", (48, 32))
        draw = ImageDraw.Draw(mask)
        # Two right-leaning source glyphs. Their pixels are deliberately not
        # deskewed before or after the split.
        draw.polygon(((8, 4), (15, 4), (10, 27), (3, 27)), fill=255)
        draw.polygon(((31, 4), (38, 4), (33, 27), (26, 27)), fill=255)
        return mask

    def test_split_preserves_source_pixels_and_yields_two_cells(self) -> None:
        mask = self._two_digit_mask()
        cells = split_parallelogram_digit_cells(mask, 2, shear=-0.20)
        try:
            self.assertEqual(2, len(cells))
            self.assertTrue(all(cell.image.getbbox() is not None for cell in cells))
            self.assertEqual(
                sum(pixel >= 127 for pixel in mask.getdata()),
                sum(
                    pixel >= 127
                    for cell in cells
                    for pixel in cell.image.getdata()
                ),
            )
            # Binary pixels prove that no bicubic/bilinear affine resampling
            # occurred while extracting either parallelogram.
            self.assertTrue(
                all(
                    pixel in (0, 255)
                    for cell in cells
                    for pixel in cell.image.getdata()
                )
            )
        finally:
            for cell in cells:
                cell.close()
            mask.close()

    def test_single_digit_uses_one_slanted_cell(self) -> None:
        mask = self._two_digit_mask().crop((0, 0, 22, 32))
        cells = split_parallelogram_digit_cells(mask, 1, shear=-0.25)
        try:
            self.assertEqual(1, len(cells))
            left_top, _right_top, _right_bottom, left_bottom = cells[0].polygon
            self.assertGreater(left_top[0], left_bottom[0])
        finally:
            for cell in cells:
                cell.close()
            mask.close()

    def test_invalid_digit_count_is_rejected(self) -> None:
        mask = self._two_digit_mask()
        try:
            self.assertEqual((), split_parallelogram_digit_cells(mask, 0, shear=-0.20))
            self.assertEqual((), split_parallelogram_digit_cells(mask, 4, shear=-0.20))
        finally:
            mask.close()


if __name__ == "__main__":
    unittest.main()
