from __future__ import annotations

import ast
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import core.student_meta as student_meta
from core import config as core_config
from core import student_meta_data
from core.scanner import InventoryScannerComponent, Scanner, ScannerRuntimeComponent, StudentScannerComponent
from gui.viewer_app_qt import StudentViewerWindow
from gui.viewer_components.inventory import InventoryTabComponent
from gui.viewer_components.planner import PlannerTabComponent
from gui.viewer_components.scan import ScanTabComponent
from tools import student_meta_tool


ROOT = Path(__file__).resolve().parent.parent


class StudentMetadataBoundaryTests(unittest.TestCase):
    def test_lookup_api_uses_generated_data_module(self) -> None:
        self.assertEqual(set(student_meta.STUDENTS), set(student_meta_data.STUDENTS))
        self.assertEqual(set(student_meta.MULTI_FORM_STUDENTS), set(student_meta_data.MULTI_FORM_STUDENTS))
        self.assertEqual(student_meta.display_name("hoshino"), student_meta_data.STUDENTS["hoshino"]["display_name"])

    def test_generated_assignments_are_not_in_lookup_api(self) -> None:
        api_tree = ast.parse((ROOT / "core" / "student_meta.py").read_text(encoding="utf-8"))
        data_tree = ast.parse((ROOT / "core" / "student_meta_data.py").read_text(encoding="utf-8"))

        def generated_dict_assignments(tree: ast.Module) -> set[str]:
            names: set[str] = set()
            for node in tree.body:
                if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and isinstance(node.value, ast.Dict):
                    names.add(node.target.id)
                elif isinstance(node, ast.Assign) and isinstance(node.value, ast.Dict):
                    names.update(target.id for target in node.targets if isinstance(target, ast.Name))
            return names

        self.assertNotIn("STUDENTS", generated_dict_assignments(api_tree))
        self.assertIn("STUDENTS", generated_dict_assignments(data_tree))
        self.assertEqual(student_meta_tool.MODULE_PATH, ROOT / "core" / "student_meta_data.py")

    def test_external_generated_data_asset_remains_loadable(self) -> None:
        original_students = student_meta.STUDENTS
        original_forms = student_meta.MULTI_FORM_STUDENTS
        try:
            with tempfile.TemporaryDirectory() as raw_dir:
                asset_root = Path(raw_dir)
                data_path = asset_root / "core" / "student_meta_data.py"
                data_path.parent.mkdir(parents=True)
                data_path.write_text(
                    "STUDENTS = {'external_test': {'display_name': 'External'}}\n"
                    "MULTI_FORM_STUDENTS = {}\n",
                    encoding="utf-8",
                )
                with patch.object(core_config, "DEFAULT_ASSET_DIR", asset_root):
                    student_meta._load_external_student_meta()
                self.assertEqual(student_meta.display_name("external_test"), "External")
        finally:
            student_meta.STUDENTS = original_students
            student_meta.MULTI_FORM_STUDENTS = original_forms


class ViewerBoundaryTests(unittest.TestCase):
    def test_viewer_facade_composes_feature_components(self) -> None:
        self.assertTrue(issubclass(StudentViewerWindow, ScanTabComponent))
        self.assertTrue(issubclass(StudentViewerWindow, InventoryTabComponent))
        self.assertTrue(issubclass(StudentViewerWindow, PlannerTabComponent))


class ScannerBoundaryTests(unittest.TestCase):
    def test_scanner_facade_composes_focused_components(self) -> None:
        self.assertTrue(issubclass(Scanner, ScannerRuntimeComponent))
        self.assertTrue(issubclass(Scanner, InventoryScannerComponent))
        self.assertTrue(issubclass(Scanner, StudentScannerComponent))

    def test_scanner_facade_preserves_runtime_constructor(self) -> None:
        regions = {}
        scanner = Scanner(regions)

        self.assertIs(scanner.r, regions)

    def test_components_can_be_imported_without_loading_facade_first(self) -> None:
        command = (
            "import core.scanner_components.inventory; "
            "import core.scanner_components.student; "
            "import gui.viewer_components.inventory; "
            "import gui.viewer_components.planner"
        )
        completed = subprocess.run(
            [sys.executable, "-c", command],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)


if __name__ == "__main__":
    unittest.main()
