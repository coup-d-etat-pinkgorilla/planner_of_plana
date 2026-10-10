"""S-FB2b narrow dependency guard; existing untracked C6 WIP excluded from HEAD lane."""
import ast
from pathlib import Path
import unittest

CORE = Path(__file__).parents[1] / "core"

class ScannerModuleHygieneC6Tests(unittest.TestCase):
    def test_scanner_inventory_rebase_does_not_import_repository_facade(self):
        scanner = ast.parse((CORE / "scanner_session.py").read_text(encoding="utf-8"))
        imports = {node.module for node in ast.walk(scanner)
                   if isinstance(node, ast.ImportFrom) and node.module is not None}
        self.assertNotIn("core.repository_store", imports)
        self.assertNotIn("core.repository_transaction", imports)
        self.assertIn("core.repository_inventory", imports)
        helper = ast.parse((CORE / "repository_inventory.py").read_text(encoding="utf-8"))
        helper_imports = {node.module for node in ast.walk(helper)
                          if isinstance(node, ast.ImportFrom) and node.module is not None}
        self.assertEqual(helper_imports, {"__future__", "typing", "core.inventory_catalog", "core.repository_dto"})
        repository = ast.parse((CORE / "repository_store.py").read_text(encoding="utf-8"))
        self.assertTrue(any(isinstance(node, ast.ImportFrom) and node.module == "core.repository_inventory"
                            and any(alias.name == "rebase_inventory_snapshot" for alias in node.names)
                            for node in repository.body))
