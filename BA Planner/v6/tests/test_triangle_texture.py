import unittest

from PySide6.QtCore import QRectF
from PySide6.QtGui import QImage, QPainter

from gui.triangle_texture import TriangleTextureConfig, paint_triangle_texture


class TriangleTextureConfigTests(unittest.TestCase):
    def _config(self, **changes):
        values = dict(
            base_color="#10131c",
            panel_color="#313b59",
            soft_color="#efe4f2",
            accent_color="#f266b3",
        )
        values.update(changes)
        return TriangleTextureConfig(**values)

    def test_normalized_clamps_visual_controls(self):
        config = self._config(
            triangle_size=1,
            tessellation_contrast=4,
            light_strength=-2,
            fog_strength=3,
            macro_triangle_chance=2,
            macro_triangle_scale=20,
            macro_triangle_contrast=1,
            light_center_x=2,
            light_center_y=-1,
            edge_vignette_strength=2,
        ).normalized()

        self.assertEqual(config.triangle_size, 6.0)
        self.assertEqual(config.tessellation_contrast, 0.18)
        self.assertEqual(config.light_strength, 0.0)
        self.assertEqual(config.fog_strength, 0.3)
        self.assertEqual(config.macro_triangle_chance, 0.35)
        self.assertEqual(config.macro_triangle_scale, 6.0)
        self.assertEqual(config.macro_triangle_contrast, 0.12)
        self.assertEqual(config.light_center_x, 1.0)
        self.assertEqual(config.light_center_y, 0.0)
        self.assertEqual(config.edge_vignette_strength, 0.45)

    def test_normalized_wraps_layer_directions(self):
        config = self._config(light_direction_degrees=492, fog_direction_degrees=-18).normalized()

        self.assertEqual(config.light_direction_degrees, 132.0)
        self.assertEqual(config.fog_direction_degrees, 342.0)

    def test_renderer_fills_surface_and_responds_to_direction(self):
        def render(light: float, fog: float) -> QImage:
            image = QImage(240, 140, QImage.Format.Format_ARGB32_Premultiplied)
            image.fill(0)
            painter = QPainter(image)
            paint_triangle_texture(
                painter,
                QRectF(image.rect()),
                self._config(light_direction_degrees=light, fog_direction_degrees=fog),
            )
            painter.end()
            return image

        first = render(132, 18)
        second = render(312, 198)

        self.assertEqual(first.pixelColor(120, 70).alpha(), 255)
        self.assertNotEqual(first.pixelColor(32, 28).rgba(), second.pixelColor(32, 28).rgba())

    def test_random_seed_is_stable_and_changes_face_distribution(self):
        def render(seed: int) -> QImage:
            image = QImage(240, 140, QImage.Format.Format_ARGB32_Premultiplied)
            painter = QPainter(image)
            paint_triangle_texture(
                painter,
                QRectF(image.rect()),
                self._config(random_seed=seed, light_strength=0, fog_strength=0),
            )
            painter.end()
            return image

        first = render(17)
        repeated = render(17)
        changed = render(18)

        self.assertEqual(first, repeated)
        self.assertNotEqual(first, changed)


if __name__ == "__main__":
    unittest.main()
