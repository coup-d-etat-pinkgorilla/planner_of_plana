import unittest

from PySide6.QtCore import QRectF
from PySide6.QtGui import QImage, QPainter
from PySide6.QtWidgets import QApplication

from gui.triangle_texture import (
    TriangleTextureConfig,
    TriangleTextureWidget,
    _base_triangle_faces,
    _effective_row_height_jitter,
    _wave_arrival_times,
    paint_triangle_texture,
)


class TriangleTextureConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

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
            origin_jitter=2,
            row_phase_jitter=2,
            row_height_jitter=2,
            row_height_jitter_target_rows=30,
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
        self.assertEqual(config.origin_jitter, 0.5)
        self.assertEqual(config.row_phase_jitter, 0.3)
        self.assertEqual(config.row_height_jitter, 0.1)
        self.assertEqual(config.row_height_jitter_target_rows, 12.0)

    def test_normalized_wraps_layer_directions(self):
        config = self._config(light_direction_degrees=492, fog_direction_degrees=-18).normalized()

        self.assertEqual(config.light_direction_degrees, 132.0)
        self.assertEqual(config.fog_direction_degrees, 342.0)

    def test_default_light_is_centered_without_a_directional_layer(self):
        config = self._config(
            tessellation_contrast=0,
            macro_triangle_chance=0,
            fog_strength=0,
            edge_vignette_strength=0,
        )
        self.assertIsNone(config.light_direction_degrees)

        image = QImage(200, 100, QImage.Format.Format_ARGB32_Premultiplied)
        image.fill(0)
        painter = QPainter(image)
        paint_triangle_texture(painter, QRectF(image.rect()), config)
        painter.end()
        self.assertEqual(image.pixelColor(40, 50), image.pixelColor(159, 50))
        center = image.pixelColor(100, 50)
        edge = image.pixelColor(10, 50)
        self.assertGreater(center.red() + center.green() + center.blue(), edge.red() + edge.green() + edge.blue())

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

    def test_warped_pattern_keeps_common_coordinates_stable_across_sizes(self):
        def render(width: int, height: int) -> QImage:
            image = QImage(width, height, QImage.Format.Format_ARGB32_Premultiplied)
            painter = QPainter(image)
            paint_triangle_texture(
                painter,
                QRectF(image.rect()),
                self._config(
                    random_seed=91,
                    light_strength=0,
                    fog_strength=0,
                    edge_vignette_strength=0,
                    macro_triangle_chance=0,
                    row_height_jitter_target_rows=0,
                ),
            )
            painter.end()
            return image

        small = render(240, 140)
        large = render(360, 220)

        for x, y in ((8, 8), (47, 31), (119, 69), (219, 121)):
            self.assertEqual(small.pixelColor(x, y), large.pixelColor(x, y))

    def test_small_surfaces_receive_stronger_row_height_variation(self):
        base = 0.06
        nominal_height = 48.5

        small = _effective_row_height_jitter(148, nominal_height, base, 6)
        large = _effective_row_height_jitter(900, nominal_height, base, 6)

        self.assertEqual(small, 0.1)
        self.assertEqual(large, base)

    def test_wave_arrival_field_is_seeded_connected_and_centered(self):
        rect = QRectF(0, 0, 960, 540)
        config = self._config(triangle_size=96).normalized()
        faces = _base_triangle_faces(rect, config)

        first = _wave_arrival_times(faces, rect, config.triangle_size, 451)
        repeated = _wave_arrival_times(faces, rect, config.triangle_size, 451)
        changed = _wave_arrival_times(faces, rect, config.triangle_size, 452)

        self.assertEqual(first, repeated)
        self.assertNotEqual(first, changed)
        self.assertEqual(min(first), 0.0)
        self.assertAlmostEqual(max(first), 0.82)
        source = first.index(0.0)
        self.assertLess(abs(faces[source].center.x() - rect.center().x()), config.triangle_size)
        self.assertLess(abs(faces[source].center.y() - rect.center().y()), config.triangle_size)

    def test_hold_and_restore_wave_update_persistent_tint(self):
        widget = TriangleTextureWidget(self._config())
        widget.resize(640, 360)

        widget.playWave("#f266b3", duration_ms=900, mode="hold")
        widget._wave_animation.stop()
        widget._finish_wave()
        self.assertTrue(widget.hasHeldWave())

        widget.playWave("#aeb7c6", duration_ms=900, mode="restore")
        widget._wave_animation.stop()
        widget._finish_wave()
        self.assertFalse(widget.hasHeldWave())


if __name__ == "__main__":
    unittest.main()
