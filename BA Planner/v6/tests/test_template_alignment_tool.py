import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools.template_alignment_tool import (
    AlignmentProject, LayerSpec, RoiSpec, export_alignment, load_project,
    render_virtual, save_project,
)


class TemplateAlignmentToolTests(unittest.TestCase):
    def test_exact_pixel_composite(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "layer.png"
            Image.new("RGBA", (2, 2), (255, 0, 0, 255)).save(path)
            project = AlignmentProject(layers=[LayerSpec(str(path), "red", 3, 4, 2, 2, 100)])
            result = render_virtual(project, (8, 8))
            self.assertEqual(result.getpixel((3, 4)), (255, 0, 0, 255))
            self.assertEqual(result.getpixel((2, 4)), (0, 0, 0, 0))

    def test_round_trip_and_export(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            reference, layer = root / "reference.png", root / "layer.png"
            Image.new("RGBA", (10, 10), (10, 20, 30, 255)).save(reference)
            Image.new("RGBA", (4, 4), (200, 100, 50, 255)).save(layer)
            project = AlignmentProject(str(reference), [LayerSpec(str(layer), "icon", 2, 3, 4, 4, 100)], RoiSpec(2, 3, 3, 2))
            project_path = root / "project.json"
            save_project(project, project_path)
            loaded = load_project(project_path)
            self.assertEqual(loaded.roi, RoiSpec(2, 3, 3, 2))
            output = root / "out"
            self.assertEqual(len(export_alignment(loaded, output)), 5)
            self.assertEqual(Image.open(output / "virtual_template_roi.png").size, (3, 2))
            metadata = json.loads((output / "alignment.json").read_text(encoding="utf-8"))
            self.assertEqual(metadata["roi"]["x"], 2)


if __name__ == "__main__":
    unittest.main()
