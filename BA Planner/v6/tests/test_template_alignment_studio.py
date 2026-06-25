import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools.template_alignment_studio_model import (
    LayerSpec, RoiSpec, StudioProject, export_project, load_project,
    render_text_layer, render_virtual, save_project,
)


class TemplateAlignmentStudioTests(unittest.TestCase):
    def test_text_layer_is_rendered(self):
        layer = LayerSpec(
            "level", "text", x=5, y=7, width=160, height=50,
            opacity=100, text="Lv.70", font_size=28,
        )
        image = render_virtual(StudioProject(layers=[layer]), (220, 100))
        alpha = image.getchannel("A")
        self.assertIsNotNone(alpha.getbbox())
        self.assertGreaterEqual(alpha.getbbox()[0], 5)
        self.assertGreaterEqual(alpha.getbbox()[1], 7)


    def test_text_bold_is_saved_and_rendered_heavier(self):
        normal = LayerSpec(
            "normal", "text", width=120, height=50, opacity=100,
            text="Lv.70", font_path="missing-font.ttf", font_size=28,
        )
        bold = LayerSpec(
            "bold", "text", width=120, height=50, opacity=100,
            text="Lv.70", font_path="missing-font.ttf", font_size=28,
            text_bold=True,
        )
        normal_alpha = sum(render_text_layer(normal).getchannel("A").getdata())
        bold_alpha = sum(render_text_layer(bold).getchannel("A").getdata())
        self.assertGreater(bold_alpha, normal_alpha)

        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "studio.json"
            save_project(StudioProject(layers=[bold]), target)
            loaded = load_project(target)
            self.assertTrue(loaded.layers[0].text_bold)
    def test_named_rois_export_independently(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            reference = root / "reference.png"
            Image.new("RGBA", (100, 80), (20, 30, 40, 255)).save(reference)
            project = StudioProject(
                str(reference), [],
                [RoiSpec("favorite_t1_marker", 5, 6, 20, 15),
                 RoiSpec("favorite_t2_marker", 30, 10, 18, 12)],
            )
            paths = export_project(project, root / "out")
            self.assertTrue((root / "out/favorite_t1_marker_reference.png").exists())
            self.assertTrue((root / "out/favorite_t2_marker_virtual_template.png").exists())
            self.assertEqual(Image.open(paths[0]).size, (20, 15))

    def test_old_project_format_is_upgraded(self):
        source = Path("debug/260622/template_alignment.json")
        project = load_project(source)
        self.assertGreaterEqual(len(project.layers), 6)
        self.assertEqual("main", project.rois[0].name)
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "studio.json"
            save_project(project, target)
            loaded = load_project(target)
            self.assertGreaterEqual(len(loaded.layers), 6)
            self.assertEqual("main", loaded.rois[0].name)


if __name__ == "__main__":
    unittest.main()
