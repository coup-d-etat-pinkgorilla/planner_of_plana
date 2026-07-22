from __future__ import annotations

import json
from pathlib import Path
import shutil
from tempfile import TemporaryDirectory
import unittest

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_session import ScannerError


ASSETS = Path(__file__).parents[1] / "core" / "recognition_assets"


class RecognitionAssetTests(unittest.TestCase):
    def test_production_manifest_hashes_and_runtime_resolution(self) -> None:
        catalog = RecognitionAssetCatalog(ASSETS)
        status = catalog.verify()
        self.assertTrue(status["ready"])
        self.assertEqual(16, status["asset_count"])
        self.assertEqual(2, len(catalog.assets("student", "student-template")))
        self.assertEqual(2, len(catalog.assets("inventory", "inventory-template")))
        self.assertEqual(10, len(catalog.assets("inventory", "inventory-count-template")))
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
            manifest = json.loads((copied / "manifest.json").read_text(encoding="utf-8"))
            manifest["version"] = 2
            (copied / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ScannerError, "version"):
                catalog.verify()

if __name__ == "__main__":
    unittest.main()
