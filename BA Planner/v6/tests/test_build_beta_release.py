from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
import zipfile
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
            self._write(root, "core/student_meta_data.py", b"STUDENTS = {}\n")
            self._write(root, "gui/font/runtime.ttf")
            self._write(root, "assets/plana/working.png")
            self._write(root, "debug/region_captures/filtermenu_button.region.json", b"{}")
            self._write(root, "debug/region_captures/eq_filtermenu_button.region.json", b"{}")

            with patch.object(build_beta_release, "ROOT_DIR", root):
                files = build_beta_release._iter_asset_files()
                build_beta_release.validate_asset_inputs(files)

            rels = {path.relative_to(root).as_posix() for path in files}
            self.assertIn("gui/font/runtime.ttf", rels)
            self.assertIn("assets/plana/working.png", rels)
            self.assertIn("debug/region_captures/filtermenu_button.region.json", rels)
            self.assertIn("debug/region_captures/eq_filtermenu_button.region.json", rels)

    def test_pyinstaller_app_bundle_embeds_runtime_asset_roots(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            self._write(root, "templates/icons/temp/square.png")
            self._write(root, "regions/item_regions.json", b"{}")
            self._write(root, "data/planning/reference_tables.json", b"{}")
            self._write(root, "core/student_meta_data.py", b"STUDENTS = {}\n")
            self._write(root, "gui/font/runtime.ttf")
            self._write(root, "gui/main_ui_color_palete.txt")
            self._write(root, "assets/plana/working.png")
            self._write(root, "debug/region_captures/filtermenu_button.region.json", b"{}")
            self._write(root, "debug/region_captures/eq_filtermenu_button.region.json", b"{}")

            with patch.object(build_beta_release, "ROOT_DIR", root):
                args = build_beta_release._pyinstaller_asset_data_args()

        data_args = [args[index + 1] for index, value in enumerate(args) if value == "--add-data"]
        self.assertIn("templates;assets/templates", data_args)
        self.assertIn("gui/quick/qml;gui/quick/qml", data_args)
        self.assertIn("regions;assets/regions", data_args)
        self.assertIn("data/planning;assets/data/planning", data_args)
        self.assertIn("core/student_meta_data.py;assets/core", data_args)
        self.assertIn("debug/region_captures;assets/debug/region_captures", data_args)

    def test_asset_validation_fails_when_runtime_fonts_are_missing(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            self._write(root, "templates/icons/temp/square.png")
            self._write(root, "regions/student_normal_info_regions.json", b"{}")
            self._write(root, "data/planning/reference_tables.json", b"{}")
            self._write(root, "core/student_meta_data.py", b"STUDENTS = {}\n")
            (root / "gui/font").mkdir(parents=True)
            self._write(root, "assets/plana/working.png")
            self._write(root, "debug/region_captures/filtermenu_button.region.json", b"{}")
            self._write(root, "debug/region_captures/eq_filtermenu_button.region.json", b"{}")

            with patch.object(build_beta_release, "ROOT_DIR", root):
                files = build_beta_release._iter_asset_files()
                with self.assertRaisesRegex(RuntimeError, "gui/font/\\*.ttf"):
                    build_beta_release.validate_asset_inputs(files)

    def test_unmanaged_gui_image_fails_full_release_input_validation(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            managed = self._write(root, "assets/ui/managed.png")
            self._write(root, "gui/new_feature/banner.png")

            with patch.object(build_beta_release, "ROOT_DIR", root):
                with self.assertRaisesRegex(RuntimeError, "gui/new_feature/banner.png"):
                    build_beta_release.validate_no_unmanaged_runtime_assets([managed])

    def test_asset_archive_verification_detects_missing_file(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            archive_path = root / "assets.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("assets/one.png", b"one")
            files = {
                "assets/one.png": {"size": 3, "sha256": hashlib.sha256(b"one").hexdigest()},
                "assets/two.png": {"size": 3, "sha256": hashlib.sha256(b"two").hexdigest()},
            }
            with self.assertRaisesRegex(RuntimeError, "missing: assets/two.png"):
                build_beta_release.validate_asset_archive(archive_path, files)

    def test_full_release_verifies_embedded_asset_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            asset_archive = root / "ba-planner-assets-1.0.zip"
            asset_archive.write_bytes(b"assets")
            asset_manifest = {
                "archive_name": asset_archive.name,
                "sha256": hashlib.sha256(b"assets").hexdigest(),
                "files": {},
            }
            asset_manifest_path = root / "asset_manifest.json"
            asset_manifest_path.write_text(json.dumps(asset_manifest), encoding="utf-8")

            app_archive = root / "ba-planner-windows-1.0.zip"
            with zipfile.ZipFile(app_archive, "w") as archive:
                archive.writestr("BA Planner/BA Planner.exe", b"exe")
                archive.writestr("BA Planner/asset_manifest.json", json.dumps(asset_manifest))
                archive.writestr("BA Planner/app_manifest.json", "{}")
            app_manifest = {
                "archive_name": app_archive.name,
                "sha256": build_beta_release._sha256(app_archive),
            }
            app_manifest_path = root / "app_manifest.json"
            app_manifest_path.write_text(json.dumps(app_manifest), encoding="utf-8")

            build_beta_release.validate_full_release(
                app_archive=app_archive,
                asset_archive=asset_archive,
                asset_manifest_path=asset_manifest_path,
                app_manifest_path=app_manifest_path,
            )


class BuildBetaReleaseRegionCaptureValidationTests(unittest.TestCase):
    def _write(self, root: Path, rel: str, data: bytes = b"x") -> Path:
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def test_asset_validation_fails_when_region_capture_buttons_are_missing(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            self._write(root, "templates/icons/temp/square.png")
            self._write(root, "regions/student_normal_info_regions.json", b"{}")
            self._write(root, "data/planning/reference_tables.json", b"{}")
            self._write(root, "core/student_meta_data.py", b"STUDENTS = {}\n")
            self._write(root, "gui/font/runtime.ttf")
            self._write(root, "assets/plana/working.png")
            (root / "debug/region_captures").mkdir(parents=True)

            with patch.object(build_beta_release, "ROOT_DIR", root):
                files = build_beta_release._iter_asset_files()
                with self.assertRaisesRegex(RuntimeError, "filtermenu_button\.region\.json"):
                    build_beta_release.validate_asset_inputs(files)


if __name__ == "__main__":
    unittest.main()
