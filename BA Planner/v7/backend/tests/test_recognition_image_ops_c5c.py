"""C5c (X15): shared image operations live in core.recognition_image_ops."""
import unittest

from PIL import Image, ImageDraw

from core import recognition_image_ops as ops
from core import student_equipment_recognizer, student_scan_recognizer, student_weapon_recognizer


def tile(colour):
    image = Image.new("RGB", (117, 96), (230, 230, 230))
    draw = ImageDraw.Draw(image)
    draw.polygon([(30, 10), (85, 14), (80, 70), (26, 66)], fill=colour)
    draw.ellipse((45, 25, 65, 45), fill=(20, 20, 20))
    return image


class RecognitionImageOpsTests(unittest.TestCase):
    def test_old_private_names_are_the_moved_functions(self):
        # Kept until C6 for tools/tests; core modules import the public names.
        self.assertIs(student_weapon_recognizer._normalized_correlation, ops.ncc_signed_lanczos)
        self.assertIs(student_weapon_recognizer._color_similarity, ops.color_similarity)
        self.assertIs(student_equipment_recognizer._normalized_correlation, ops.ncc_unit_bilinear)
        self.assertIs(student_equipment_recognizer._mean_difference, ops.mean_difference)
        for private, public in (("_pixels", "pixels"), ("_mask_from_predicate", "mask_from_predicate"),
                                ("_normalize_mask", "normalize_mask"), ("_binary_iou", "binary_iou"),
                                ("_otsu_binary", "otsu_binary"), ("_ncc_difference_score", "ncc_difference_score")):
            self.assertIs(getattr(student_scan_recognizer, private), getattr(ops, public))

    def test_the_two_grey_ncc_variants_keep_their_ranges(self):
        light, dark = tile((200, 60, 60)), tile((200, 60, 60)).point(lambda value: 255 - value)
        self.assertLess(ops.ncc_signed_lanczos(light, dark), 0)
        self.assertEqual(0.0, ops.ncc_unit_bilinear(light, dark))
        self.assertAlmostEqual(1.0, ops.ncc_signed_lanczos(light, light), places=6)

    def test_per_channel_icon_ncc_separates_same_shape_different_colour(self):
        # E2 M4: grey NCC cannot tell colour tiers of one shape apart; per-channel NCC can.
        red, blue = tile((210, 50, 50)), tile((50, 50, 210))
        self.assertAlmostEqual(1.0, ops.ncc_per_channel_icon(red, red), places=6)
        self.assertGreater(ops.ncc_signed_lanczos(red, blue), 0.95)
        self.assertLess(ops.ncc_per_channel_icon(red, blue), ops.ncc_per_channel_icon(red, red) - 0.3)


if __name__ == "__main__":
    unittest.main()
