from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.runtime_paths import PACKAGED_RECOGNITION_ASSET_DIR, resolve_recognition_asset_dir
from core.scanner_session import ScannerError


ASSETS = PACKAGED_RECOGNITION_ASSET_DIR


class RecognitionAssetTests(unittest.TestCase):
    def test_production_manifest_hashes_and_runtime_resolution(self) -> None:
        catalog = RecognitionAssetCatalog(ASSETS)
        status = catalog.verify()
        self.assertTrue(status["ready"])
        self.assertEqual(256, len(catalog.assets("student", "student-template")))
        self.assertEqual(497, len(catalog.assets("inventory", "inventory-template")))
        self.assertEqual(10, len(catalog.assets("inventory", "inventory-count-template")))
        self.assertEqual(17, len(catalog.assets("student", "student-basic-skill-template")))
        self.assertEqual(19, len(catalog.assets("student", "student-basic-level-digit-template")))
        self.assertEqual(187, len(catalog.assets("student", "student-basic-combat-digit-template")))
        self.assertEqual(10, len(catalog.assets("student", "student-basic-weapon-level-digit-template")))
        self.assertEqual(1114, status["asset_count"])
        self.assertEqual(
            "adapted:../v6/templates/students/airi.png#top-bar-removed-82px",
            next(
                item["source_path"]
                for item in catalog.load()["assets"]
                if item["path"] == "templates/students/airi.png"
            ),
        )
        portrait_region = catalog.region("student")["student_texture_region"]
        self.assertEqual(0.0653, portrait_region["y1"])
        self.assertEqual(0.4333, portrait_region["y2"])
        portrait_box = (
            round(2560 * portrait_region["x1"]),
            round(1440 * portrait_region["y1"]),
            round(2560 * portrait_region["x2"]),
            round(1440 * portrait_region["y2"]),
        )
        self.assertEqual((647, 530), (
            portrait_box[2] - portrait_box[0],
            portrait_box[3] - portrait_box[1],
        ))
        for asset in catalog.assets("student", "student-template"):
            with Image.open(catalog.resolve(asset.path)) as template:
                self.assertEqual(530, template.height)
        for asset in catalog.load()["assets"]:
            self.assertTrue(catalog.resolve(asset["path"]).is_file())

    def test_missing_corrupt_and_version_mismatch_fail_readiness(self) -> None:
        with TemporaryDirectory() as root:
            copied = Path(root) / "assets"
            shutil.copytree(ASSETS, copied)
            catalog = RecognitionAssetCatalog(copied)
            (copied / "templates/students/airi.png").unlink()
            self.assertFalse(catalog.verify()["ready"])
            shutil.copy2(ASSETS / "templates/students/airi.png", copied / "templates/students/airi.png")
            (copied / "templates/students/airi.png").write_bytes(b"corrupt")
            self.assertIn("templates/students/airi.png", catalog.verify()["corrupt"])
            shutil.copy2(ASSETS / "templates/students/airi.png", copied / "templates/students/airi.png")
            basic_digit = copied / "templates/student_basic/weaponlevel_glyph/0.png"
            basic_digit.write_bytes(b"corrupt")
            self.assertIn(
                "templates/student_basic/weaponlevel_glyph/0.png",
                catalog.verify()["corrupt"],
            )
            manifest = json.loads((copied / "manifest.json").read_text(encoding="utf-8"))
            manifest["version"] = 2
            (copied / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ScannerError, "version"):
                catalog.verify()

    def test_default_and_environment_override_roots_are_separate(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(PACKAGED_RECOGNITION_ASSET_DIR, resolve_recognition_asset_dir())
        with TemporaryDirectory() as root:
            override = Path(root) / "recognition-v1"
            with patch.dict(os.environ, {"BA_PLANNER_RECOGNITION_ASSET_DIR": str(override)}):
                self.assertEqual(override, resolve_recognition_asset_dir())
                self.assertEqual(override, RecognitionAssetCatalog().root)

if __name__ == "__main__":
    unittest.main()
