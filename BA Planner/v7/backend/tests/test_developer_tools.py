from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

from tools import developer_tools


class DeveloperToolsTests(unittest.TestCase):
    def test_replace_assignment_preserves_surrounding_source(self) -> None:
        source = "before = 1\nVALUE: dict[str, int] = {\n    'old': 1,\n}\nafter = 2\n"
        result = developer_tools._replace_assignment(source, "VALUE", "VALUE: dict[str, int] = {'new': 2}")
        self.assertEqual(
            "before = 1\nVALUE: dict[str, int] = {'new': 2}\nafter = 2\n",
            result,
        )

    def test_metadata_list_uses_v7_generated_catalog(self) -> None:
        response = developer_tools.dispatch(
            {"version": 1, "method": "metadata.list", "params": {"query": "hoshino"}}
        )
        ids = {row["student_id"] for row in response["result"]["students"]}
        self.assertIn("hoshino", ids)
        self.assertGreater(response["result"]["total"], 200)

    def test_template_preview_uses_ratio_crop(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            image_path = Path(directory) / "source.png"
            Image.new("RGB", (200, 100), "navy").save(image_path)
            with patch.object(
                developer_tools,
                "_student_region",
                return_value=({"x1": 0.1, "y1": 0.2, "x2": 0.8, "y2": 0.9}, Path(directory)),
            ):
                result = developer_tools.template_preview({"image_path": str(image_path)})
            self.assertEqual([20, 20, 160, 90], result["crop"])
            self.assertTrue(Path(result["preview_path"]).is_file())

    def test_student_manifest_entry_is_replaced_with_current_integrity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image_path = root / "templates" / "students" / "sample.png"
            image_path.parent.mkdir(parents=True)
            image_path.write_bytes(b"new-png")
            (root / "manifest.json").write_text(
                json.dumps(
                    {
                        "version": 1,
                        "assets": [
                            {
                                "path": "old.png",
                                "scan_kind": "student",
                                "purpose": "student-template",
                                "student_id": "sample",
                            },
                            {"path": "keep.png", "scan_kind": "inventory", "purpose": "inventory-template"},
                        ],
                    }
                ),
                encoding="utf-8",
            )
            developer_tools._update_student_manifest(root, "sample", image_path)
            manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
            matching = [entry for entry in manifest["assets"] if entry.get("student_id") == "sample"]
            self.assertEqual(1, len(matching))
            self.assertEqual(len(b"new-png"), matching[0]["bytes"])
            self.assertEqual(hashlib.sha256(b"new-png").hexdigest(), matching[0]["sha256"])


if __name__ == "__main__":
    unittest.main()
