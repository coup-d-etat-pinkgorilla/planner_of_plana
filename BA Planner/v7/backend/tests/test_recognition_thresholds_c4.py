"""C4: recognition thresholds live in core.recognition_thresholds, not as literals.

A threshold literal is a float constant that is compared, passed as a threshold/margin-like
argument or default, or assigned to a threshold/margin-like name. Every remaining one in a
migrated file must be on the explicit allowlist below.
"""
import ast
from pathlib import Path
import unittest

from core import recognition_thresholds as rt


BACKEND = Path(__file__).resolve().parents[1]
V7 = BACKEND.parent
MIGRATED = (
    "core/scanner_matchers.py",
    "core/inventory_navigation.py",
    "core/inventory_detail_recovery.py",
    "core/student_panel_recovery.py",
    "core/student_identity_recovery.py",
    "core/student_equipment_recovery.py",
    "core/student_weapon_recognizer.py",
    "core/student_level_recognizer.py",
    "core/student_star_recognizer.py",
    "core/student_skill_recognizer.py",
    "core/student_potential_recognizer.py",
    "core/studio_numeric_bank.py",
    "core/student_scan_recognizer.py",
    "core/student_equipment_recognizer.py",
)
NAMES = ("threshold", "margin", "floor", "minimum", "min_score", "min_margin", "score", "tolerance")
# (file, value, detector) -> reason. Not thresholds: neutral defaults, blend weights, geometry.
ALLOWLIST = {
    ("core/scanner_matchers.py", 0.0, "default:threshold"): "TemplateMatcher.match: 0 means no gate; callers pass registry values",
    ("core/scanner_matchers.py", 0.0, "default:margin"): "TemplateMatcher.match: 0 means no gate; callers pass registry values",
    ("core/inventory_detail_recovery.py", 0.4, "assign"): "visual/name blend weight of the detail identity score",
    ("core/inventory_detail_recovery.py", 0.6, "assign"): "visual/name blend weight of the detail identity score",
    ("core/student_identity_recovery.py", 0.7, "assign"): "correlation/colour blend weight of the attribute score",
    ("core/student_identity_recovery.py", 0.3, "assign"): "correlation/colour blend weight of the attribute score",
    ("core/student_identity_recovery.py", 0.35, "assign"): "correlation/colour blend weight of the entry-screen flag score",
    ("core/student_identity_recovery.py", 0.65, "assign"): "correlation/colour blend weight of the entry-screen flag score",
    ("core/student_weapon_recognizer.py", 0.0, "assign"): "min(..., default=0.0): no digit read means zero score",
    ("core/student_potential_recognizer.py", 0.55, "assign"): "IoU/correlation blend weight of the basic potential glyph score",
    ("core/student_potential_recognizer.py", 0.45, "assign"): "IoU/correlation blend weight of the basic potential glyph score",
    ("core/student_scan_recognizer.py", 0.0, "assign"): "margin/score fallback when fewer than two labels ranked, and clamp floor",
    ("core/student_scan_recognizer.py", 1.0, "assign"): "confidence clamp / 1 - similarity complement",
    ("core/student_scan_recognizer.py", 0.35, "assign"): "star residual -> confidence scaling, not an acceptance gate",
    ("core/student_equipment_recognizer.py", 0.0, "assign"): "margin fallback when fewer than two labels ranked",
    ("core/student_equipment_recognizer.py", 0.0, "compare"): "zero-denominator guard in normalized correlation",
    ("core/inventory_navigation.py", 0.0, "assign"): "clipped (unreadable) page view uses no edge margin; geometry, not a gate",
    ("core/student_equipment_recognizer.py", 0.85, "assign"): "correlation/mean-difference blend weight of the synthesized tier score",
    ("core/student_equipment_recognizer.py", 0.15, "assign"): "correlation/mean-difference blend weight of the synthesized tier score",
}


def threshold_literals(path: str) -> set[tuple[str, float, str, int]]:
    tree = ast.parse((BACKEND / path).read_text(encoding="utf-8"))

    def floats(node):
        return [item for item in ast.walk(node) if isinstance(item, ast.Constant) and isinstance(item.value, float)]

    def named(name: str) -> bool:
        return any(part in name.lower() for part in NAMES)

    hits = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Compare):
            for side in (node.left, *node.comparators):
                if isinstance(side, ast.Constant) and isinstance(side.value, float):
                    hits.add((path, side.value, "compare", side.lineno))
        elif isinstance(node, ast.keyword) and node.arg and named(node.arg):
            hits.update((path, item.value, f"kwarg:{node.arg}", item.lineno) for item in floats(node.value))
        elif isinstance(node, ast.FunctionDef):
            arguments = node.args
            positional = arguments.args[-len(arguments.defaults):] if arguments.defaults else []
            pairs = list(zip(positional, arguments.defaults)) + [
                (arg, default) for arg, default in zip(arguments.kwonlyargs, arguments.kw_defaults) if default is not None]
            for arg, default in pairs:
                if named(arg.arg):
                    hits.update((path, item.value, f"default:{arg.arg}", item.lineno) for item in floats(default))
        elif isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and named(target.id) for target in node.targets):
            hits.update((path, item.value, "assign", item.lineno) for item in floats(node.value))
    return hits


class RecognitionThresholdRegistryTests(unittest.TestCase):
    def test_migrated_files_have_no_unregistered_threshold_literals(self):
        for path in MIGRATED:
            with self.subTest(path=path):
                unexpected = sorted((value, detector, line) for file, value, detector, line in threshold_literals(path)
                                    if (file, value, detector) not in ALLOWLIST)
                self.assertEqual([], unexpected)

    def test_allowlist_has_no_stale_entries(self):
        present = {(file, value, detector) for path in MIGRATED for file, value, detector, _ in threshold_literals(path)}
        self.assertEqual(set(), set(ALLOWLIST) - present)

    def test_every_entry_is_named_typed_and_traceable(self):
        for entry in rt.THRESHOLDS.values():
            with self.subTest(name=entry.name):
                self.assertIn(entry.kind, {"score", "margin", "similarity", "ratio", "intensity", "hue"})
                self.assertTrue(0 <= entry.value <= {"intensity": 255, "hue": 360}.get(entry.kind, 1))
                self.assertRegex(entry.phase, r"^(P\d+|F\d+|S\d+[a-z]?|D\d+|C\d+)$")
                self.assertTrue((V7 / entry.doc).exists(), entry.doc)
                self.assertIn(entry.resolution, {"*", "native1280", "native2560"})

    def test_same_frame_thresholds_are_distinct_named_decisions(self):
        # C4 named the three "same frame" values; C5 replaced the drag no-motion similarity (.97) and the
        # histogram row overlap with a measured pixel shift, so two remain plus the shift thresholds.
        self.assertEqual(0.995, rt.value("inventory.wheel.same_frame"))
        self.assertEqual(0.985, rt.value("inventory.scroll.settled_same"))
        self.assertNotIn("inventory.scroll.no_motion_same", rt.THRESHOLDS)
        self.assertEqual([rt.THRESHOLDS["inventory.shift.no_motion"]],
                         rt.lookup("scroll_terminal", "verified_no_motion", "ratio", "native1280"))

if __name__ == "__main__":
    unittest.main()
