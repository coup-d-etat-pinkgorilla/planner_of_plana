from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import build_beta_release


class BuildBetaReleaseAssetTests(unittest.TestCase):
    def _write(self, root: Path, rel: str, data: bytes = b"x") -> Path:
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def test_asset_pack_includes_runtime_font_assets(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            self._write(root, "templates/icons/temp/square.png")
            self._write(root, "regions/student_normal_info_regions.json", b"{}")
            self._write(root, "data/planning/reference_tables.json", b"{}")
            self._write(root, "core/student_meta.py", b"STUDENTS = {}\n")
            self._write(root, "gui/font/runtime.ttf")
            self._write(root, "assets/plana/working.png")

            with patch.object(build_beta_release, "ROOT_DIR", root):
                files = build_beta_release._iter_asset_files()
                build_beta_release.validate_asset_inputs(files)

            rels = {path.relative_to(root).as_posix() for path in files}
            self.assertIn("gui/font/runtime.ttf", rels)
            self.assertIn("assets/plana/working.png", rels)

    def test_asset_validation_fails_when_runtime_fonts_are_missing(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            self._write(root, "templates/icons/temp/square.png")
            self._write(root, "regions/student_normal_info_regions.json", b"{}")
            self._write(root, "data/planning/reference_tables.json", b"{}")
            self._write(root, "core/student_meta.py", b"STUDENTS = {}\n")
            (root / "gui/font").mkdir(parents=True)
            self._write(root, "assets/plana/working.png")

            with patch.object(build_beta_release, "ROOT_DIR", root):
                files = build_beta_release._iter_asset_files()
                with self.assertRaisesRegex(RuntimeError, "gui/font/\\*.ttf"):
                    build_beta_release.validate_asset_inputs(files)


if __name__ == "__main__":
    unittest.main()