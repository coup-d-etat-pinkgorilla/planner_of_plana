from __future__ import annotations

import json
from pathlib import Path
import unittest

from PIL import Image

from core.studio_roi_suggestion import (
    load_studio_suggestion,
    load_studio_text_layers,
    render_studio_text_layer,
)
from tools.build_student_studio_text_templates import (
    RELATIONSHIP_LAYOUT_TEXT_SUGGESTIONS,
    SUGGESTION,
    TEXT_SUGGESTION,
    _best_shift,
    _keep_digit_component,
    build,
)


ROOT = Path(__file__).resolve().parents[2]


class StudioTextTemplateTests(unittest.TestCase):
    def test_best_shift_normalizes_reference_template_to_actual_roi_size(self) -> None:
        template = Image.new("L", (18, 26))
        for y in range(2, 24):
            for x in range(5, 13):
                template.putpixel((x, y), 255)
        source = template.resize((9, 13), Image.Resampling.NEAREST)

        score, dx, dy, shifted = _best_shift(source, template)

        self.assertEqual((dx, dy), (0, 0))
        self.assertEqual(score, 1.0)
        self.assertEqual(shifted.size, source.size)
        shifted.close()
        source.close()
        template.close()

    def test_relationship_rois_contain_updated_fill_alpha_without_right_edge_clip(self) -> None:
        suggestion = load_studio_suggestion(SUGGESTION)
        _reference, _size, layers = load_studio_text_layers(TEXT_SUGGESTION)
        rois = {roi.name: roi for roi in suggestion.rois}
        relationship_layers = [
            layer for layer in layers if layer.font_size == 32 and layer.text.strip() in {"3", "7"}
        ]
        for roi_name, layer, expected_right in zip(
            ("affectionlevel_digit1", "affectionlevel_digit2"),
            sorted(relationship_layers, key=lambda item: item.x),
            (112, 129),
        ):
            rendered = render_studio_text_layer(layer, white_mask=True, include_stroke=False)
            bbox = rendered.getchannel("A").getbbox()
            rendered.close()
            self.assertIsNotNone(bbox)
            assert bbox is not None
            absolute = (
                layer.x + bbox[0], layer.y + bbox[1],
                layer.x + bbox[2], layer.y + bbox[3],
            )
            roi = rois[roi_name]
            left = min(x for x, _y in roi.points)
            top = min(y for _x, y in roi.points)
            right = max(x for x, _y in roi.points)
            bottom = max(y for _x, y in roi.points)
            self.assertGreaterEqual(absolute[0], left)
            self.assertGreaterEqual(absolute[1], top)
            self.assertLessEqual(absolute[2], right)
            self.assertLessEqual(absolute[3], bottom)
            self.assertEqual(right, expected_right)

    def test_single_and_three_digit_relationship_rois_contain_authoritative_layers(self) -> None:
        suggestion = load_studio_suggestion(SUGGESTION)
        rois = {roi.name: roi for roi in suggestion.rois}
        expected = {
            1: [("affectionlevel_1digit_digit1", 103, 120)],
            3: [
                ("affectionlevel_3digit_digit1", 86, 103),
                ("affectionlevel_3digit_digit2", 103, 120),
                ("affectionlevel_3digit_digit3", 120, 137),
            ],
        }
        for digit_count, rows in expected.items():
            _reference, _size, layers = load_studio_text_layers(
                RELATIONSHIP_LAYOUT_TEXT_SUGGESTIONS[digit_count]
            )
            relationship_layers = sorted(
                (layer for layer in layers if layer.font_size == 32),
                key=lambda item: item.x,
            )
            self.assertEqual(len(relationship_layers), digit_count)
            for (roi_name, expected_left, expected_right), layer in zip(rows, relationship_layers):
                rendered = render_studio_text_layer(layer, white_mask=True, include_stroke=False)
                bbox = rendered.getchannel("A").getbbox()
                rendered.close()
                self.assertIsNotNone(bbox)
                assert bbox is not None
                absolute = (
                    layer.x + bbox[0], layer.y + bbox[1],
                    layer.x + bbox[2], layer.y + bbox[3],
                )
                roi = rois[roi_name]
                left = min(x for x, _y in roi.points)
                top = min(y for _x, y in roi.points)
                right = max(x for x, _y in roi.points)
                bottom = max(y for _x, y in roi.points)
                self.assertEqual((left, right), (expected_left, expected_right))
                self.assertGreaterEqual(absolute[0], left)
                self.assertGreaterEqual(absolute[1], top)
                self.assertLessEqual(absolute[2], right)
                self.assertLessEqual(absolute[3], bottom)

    def test_tall_digit_mode_rejects_short_dot_even_when_digit_touches_border(self) -> None:
        mask = Image.new("L", (12, 14))
        pixels = mask.load()
        for y in range(1, 13):
            for x in range(4, 12):
                pixels[x, y] = 255
        pixels[1, 11] = 255
        pixels[1, 12] = 255

        cleaned, stats = _keep_digit_component(mask, prefer_largest_tall=True)

        self.assertEqual(cleaned.getpixel((1, 11)), 0)
        self.assertEqual(cleaned.getpixel((11, 6)), 255)
        self.assertEqual(stats["components"], 2)
        cleaned.close()
        mask.close()

    def test_user_layers_freeze_font_sizes_shear_and_border_metadata(self) -> None:
        _reference, size, layers = load_studio_text_layers(TEXT_SUGGESTION)
        self.assertEqual((2560, 1440), size)
        self.assertEqual(12, len(layers))
        self.assertEqual({"경기천년제목_Bold.ttf"}, {layer.font_path.name for layer in layers})
        self.assertEqual({37}, {layer.font_size for layer in layers[:2]})
        self.assertEqual({28}, {layer.font_size for layer in layers[2:8]})
        self.assertEqual({32}, {layer.font_size for layer in layers[8:10]})
        self.assertEqual({33}, {layer.font_size for layer in layers[10:12]})
        self.assertEqual({-0.25}, {layer.shear for layer in (*layers[:8], *layers[10:12])})
        self.assertEqual({0.0}, {layer.shear for layer in layers[8:10]})
        self.assertEqual({0}, {layer.stroke_width for layer in layers[8:10]})

    def test_builder_outputs_white_binary_templates_and_is_deterministic(self) -> None:
        first = build()
        first_bytes = Path(first["spec"]).read_bytes()
        second = build()
        self.assertEqual(first_bytes, Path(second["spec"]).read_bytes())
        report = json.loads(first_bytes.decode("utf-8"))
        self.assertFalse(report["processing"]["production"])
        self.assertEqual("GyeonggiTitle Bold", report["font"]["family"])
        self.assertEqual(16, len(report["calibration"]))
        self.assertEqual(160, len(report["templates"]))
        self.assertGreaterEqual(min(row["score"] for row in report["calibration"]), 0.68)
        self.assertEqual(
            {"fill_only"},
            {
                row["selected_variant"]
                for row in report["calibration"]
                if row["field"] in {"weapon_level", "equipment_level"}
            },
        )
        self.assertEqual(
            {"configured_stroke"},
            {
                row["selected_variant"]
                for row in report["calibration"]
                if row["field"] == "relationship_rank"
            },
        )
        for row in report["templates"]:
            self.assertEqual("#FFFFFF", row["template_color"])
            with Image.open(ROOT / row["path"]) as template:
                self.assertEqual("L", template.mode)
                self.assertTrue(set(template.getdata()).issubset({0, 255}))
                self.assertIsNotNone(template.getbbox())


if __name__ == "__main__":
    unittest.main()
