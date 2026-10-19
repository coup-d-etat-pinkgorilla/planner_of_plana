"""Standard-library diagnostics tests, including the unchanged golden failure path.

The AST harness supplies synthetic payloads to the exact runner/test functions;
it is not a production scanner replay or a substitute for native golden gates.
"""
import ast
import difflib
import hashlib
import io
import json
import os
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from tools.scanner_golden_dump import DUMP_ENV, dump_comparison


BACKEND = Path(__file__).resolve().parents[1]
SCENARIOS = (
    "student_single_mika_1280", "student_single_mika_2560", "student_single_miyu_1280",
    "student_single_shizuko_skill_panel_unopened_1280", "student_forms_hoshino_1280",
    "student_full_ring_1280",
)


def _load_definition(path, name, namespace):
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    node = next(node for node in tree.body if getattr(node, "name", None) == name)
    exec(compile(ast.Module(body=[node], type_ignores=[]), str(path), "exec"), namespace)
    return namespace[name]


class ScannerGoldenDumpTests(unittest.TestCase):
    def test_default_off_does_not_write(self):
        with TemporaryDirectory() as directory, patch.dict(os.environ, {}, clear=True):
            with patch("tools.scanner_golden_dump.Path") as path:
                self.assertIsNone(dump_comparison("example", "old", "new"))
                path.assert_not_called()
            self.assertEqual([], list(Path(directory).iterdir()))

    def test_full_unicode_bytes_and_diff_are_saved_without_reserialization(self):
        expected = '{\r\n "text": "' + "이전 값" * 3000 + '"\r\n}\r\n'
        actual = '{\n "text": "' + "실제 값" * 3000 + '", "tail": "complete"\n}\n'
        with TemporaryDirectory() as directory:
            dump_comparison("example", expected, actual, directory)
            root = Path(directory)
            self.assertEqual(expected.encode("utf-8"), (root / "expected/example.json").read_bytes())
            self.assertEqual(actual.encode("utf-8"), (root / "actual/example.json").read_bytes())
            diff = "".join(difflib.unified_diff(expected.splitlines(True), actual.splitlines(True),
                                             "golden", "replay", n=3))
            self.assertGreater(len(diff), 12000)
            self.assertEqual(diff.encode("utf-8"), (root / "full-diff/example.diff").read_bytes())
            metadata = json.loads((root / "comparisons/example.json").read_bytes())
            self.assertEqual(hashlib.sha256(actual.encode("utf-8")).hexdigest(), metadata["actual_sha256"])
            self.assertEqual(len(actual.encode("utf-8")), metadata["actual_bytes"])
            self.assertFalse(metadata["strict_equal"])

    def test_identical_rerun_is_allowed_and_conflicting_rerun_preserves_evidence(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            dump_comparison("example", "old", "new", directory)
            before = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
            dump_comparison("example", "old", "new", directory)
            with self.assertRaises(FileExistsError):
                dump_comparison("example", "different", "changed", directory)
            self.assertEqual(before, {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()})

    def test_scenario_id_cannot_escape_dump_directory(self):
        with TemporaryDirectory() as directory:
            for scenario_id in ("../other", "a/b", "a\\b", "", ".", "C:escape"):
                with self.subTest(scenario_id=scenario_id), self.assertRaises(ValueError):
                    dump_comparison(scenario_id, "old", "new", directory)
            self.assertEqual([], list(Path(directory).iterdir()))

    def test_exact_golden_test_keeps_six_failures_and_saves_full_synthetic_actual(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            golden = root / "golden"
            golden.mkdir()
            documents = {sid: {"scenario": sid, "padding": "new" * 6000, "tail": "complete"} for sid in SCENARIOS}
            serialize = lambda value: json.dumps(value, ensure_ascii=False, indent=1, sort_keys=True) + "\n"
            for sid in SCENARIOS:
                (golden / f"{sid}.json").write_text(serialize({"scenario": sid, "padding": "old" * 6000}), encoding="utf-8")
            namespace = {
                "unittest": unittest, "Path": Path, "difflib": difflib,
                "load_scenarios": lambda: [{"id": sid} for sid in SCENARIOS],
                "golden_path": lambda sid: golden / f"{sid}.json",
                "verify_inputs": lambda scenario: [], "dumps": serialize,
                "run_scenario": lambda scenario: documents[scenario["id"]],
                "dump_comparison": dump_comparison,
            }
            cls = _load_definition(BACKEND / "tests/test_scanner_consolidation_golden.py",
                                   "ScannerConsolidationGoldenTests", namespace)
            result = unittest.TestResult()
            with patch.dict(os.environ, {DUMP_ENV: str(root / "dump")}):
                cls("test_replay_matches_golden_including_evidence_order").run(result)
            self.assertEqual(6, len(result.failures))
            self.assertEqual([], result.errors)
            for sid in SCENARIOS:
                data = (root / "dump/actual" / f"{sid}.json").read_bytes()
                self.assertGreater(len(data), 12000)
                self.assertEqual(serialize(documents[sid]).encode("utf-8"), data)
                self.assertEqual(documents[sid], json.loads(data))

    def test_exact_cli_retains_diff_exit_and_supports_explicit_dump_directory(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            expected, actual = '{"value": "old"}\n', '{"value": "new"}\n'
            golden = root / "golden.json"
            golden.write_text(expected, encoding="utf-8")
            namespace = {
                "load_scenarios": lambda: [{"id": "example"}], "verify_inputs": lambda scenario: [],
                "dumps": lambda document: actual, "run_scenario": lambda scenario: {},
                "golden_path": lambda sid: golden, "dump_comparison": dump_comparison,
            }
            main = _load_definition(BACKEND / "tools/scanner_consolidation_replay.py", "main", namespace)
            with patch.dict(os.environ, {}, clear=True), patch("sys.argv", ["replay", "--dump-dir", str(root / "dump")]), patch("sys.stdout", io.StringIO()):
                with self.assertRaises(SystemExit) as raised:
                    main()
            self.assertEqual(1, raised.exception.code)
            self.assertEqual(expected, golden.read_text(encoding="utf-8"))
            self.assertEqual(actual.encode("utf-8"), (root / "dump/actual/example.json").read_bytes())


if __name__ == "__main__":
    unittest.main()
