from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from tools import inventory_grid_match_inspector_model as model


class InventoryGridMatchInspectorModelTests(unittest.TestCase):
    def _case(self, root: Path) -> model.CaptureCase:
        case_dir = root / "item" / "tech_notes" / "captures" / "scroll_01_try_01"
        case_dir.mkdir(parents=True)
        before = case_dir / "before_capture.png"
        after = case_dir / "after_capture.png"
        Image.new("RGB", (100, 100), (10, 20, 30)).save(before)
        Image.new("RGB", (100, 100), (40, 50, 60)).save(after)
        summary = {
            "slot_count": 1,
            "before_y_offset_px": 0,
            "after_y_offset_px": 10,
            "new_scan_slot_indices_0_based": [0],
            "before_capture": str(before),
            "after_capture": str(after),
        }
        summary_path = case_dir / "summary.json"
        summary_path.write_text(json.dumps(summary), encoding="utf-8")
        return model.discover_capture_cases(root)[0]

    def test_before_and_after_records_apply_phase_y_offsets(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            case = self._case(Path(tmp_dir))
            section = {"grid_slots": [{"x1": 0.1, "y1": 0.1, "x2": 0.4, "y2": 0.3}]}
            with patch.object(model, "load_region_section", return_value=section):
                records = model.slot_records(case, "both")

        self.assertEqual(len(records), 2)
        self.assertAlmostEqual(records[0].region["y1"], 0.1)
        self.assertAlmostEqual(records[1].region["y1"], 0.2)
        self.assertEqual(records[0].slot_crop.size, (30, 20))

    def test_discovers_legacy_inventory_scroll_capture_layout(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            case_dir = root / "20260704_195256_item_ooparts" / "scroll_01_try_01"
            case_dir.mkdir(parents=True)
            before = case_dir / "before_capture.png"
            before.write_bytes(b"not-needed-for-discovery")
            (case_dir / "summary.json").write_text(
                json.dumps({"slot_count": 20, "before_capture": str(before)}),
                encoding="utf-8",
            )

            cases = model.discover_capture_cases(root)

        self.assertEqual(len(cases), 1)
        self.assertEqual(cases[0].source, "item")
        self.assertEqual(cases[0].profile_id, "ooparts")

    def test_session_round_trip_preserves_experiment(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            path = root / "session.json"
            experiment = model.InspectorExperiment(
                crop_ratio={"left": 0.2, "right": 0.2, "top": 0.1, "bottom": 0.3},
                sample_box={"x": 31, "y": 44, "width": 5, "height": 5},
                fixed_sample=True,
                selected_candidates={"slot": "item"},
            )
            model.save_session(path, root, "tech_notes", experiment)
            loaded_root, profile_id, loaded = model.load_session(path)

        self.assertEqual(loaded_root, root)
        self.assertEqual(profile_id, "tech_notes")
        self.assertEqual(loaded.crop_ratio, experiment.crop_ratio)
        self.assertEqual(loaded.sample_box, experiment.sample_box)
        self.assertTrue(loaded.fixed_sample)
        self.assertEqual(loaded.selected_candidates, {"slot": "item"})

    def test_fixed_sample_collapses_search_box(self) -> None:
        base = {"tier_hint": {"sample_box": {"x": 1, "y": 2, "width": 3, "height": 4}}}
        experiment = model.InspectorExperiment(
            sample_box={"x": 9, "y": 8, "width": 7, "height": 6},
            sample_search_box={"x": 0, "y": 0, "width": 20, "height": 20},
            fixed_sample=True,
        )

        config = model.effective_matching_config(base, experiment)

        self.assertEqual(config["tier_hint"]["sample_search_box"], experiment.sample_box)
        self.assertEqual(config["tier_hint"]["sample_stride"], 7.0)


if __name__ == "__main__":
    unittest.main()
