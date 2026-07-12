import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from PIL import Image

from core.inventory_answer_samples import (
    inventory_resolution_key,
    merge_answer_samples,
    resolution_sample_catalog,
    resolution_sample_dir,
)
from core.scanner import Scanner
from core.scanner import ItemEntry
from main import App


class InventoryAnswerSampleTests(unittest.TestCase):
    def test_resolution_key_accepts_only_positive_width_and_height(self) -> None:
        self.assertEqual("2560x1440", inventory_resolution_key([2560, 1440]))
        self.assertEqual("1920x1080", inventory_resolution_key("1920X1080"))
        self.assertIsNone(inventory_resolution_key([None, None]))
        self.assertIsNone(inventory_resolution_key("../2560x1440"))

    def test_catalog_is_isolated_by_resolution_and_supports_multiple_samples(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            item_id = "Item_Icon_Test"
            first_dir = resolution_sample_dir(root, "2560x1440", "ooparts", item_id)
            other_dir = resolution_sample_dir(root, "1920x1080", "ooparts", item_id)
            assert first_dir is not None and other_dir is not None
            first_dir.mkdir(parents=True)
            other_dir.mkdir(parents=True)
            Image.new("RGB", (4, 4), "red").save(first_dir / "scan_a.png")
            Image.new("RGB", (4, 4), "blue").save(first_dir / "scan_b.png")
            Image.new("RGB", (4, 4), "green").save(other_dir / "scan_c.png")

            catalog = resolution_sample_catalog(root, "2560x1440", "ooparts")

            self.assertEqual(2, len(catalog[item_id]))
            self.assertTrue(all("2560x1440" in path for path in catalog[item_id]))

    def test_answer_samples_precede_bundled_asset_but_keep_it_as_fallback(self) -> None:
        merged = merge_answer_samples(
            [("item_a", "bundled_a.png"), ("item_b", "bundled_b.png")],
            {"item_a": ["sample_1.png", "sample_2.png"]},
        )
        self.assertEqual(
            [
                ("item_a", "sample_1.png"),
                ("item_a", "sample_2.png"),
                ("item_a", "bundled_a.png"),
                ("item_b", "bundled_b.png"),
            ],
            merged,
        )

    def test_scanner_uses_only_the_active_resolution_samples(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            scanner = Scanner({}, inventory_detail_override_dir=root, inventory_capture_resolution=(2560, 1440))
            item_id, bundled = scanner._inventory_detail_template_catalog_for_scan("ooparts")[0]
            exact_dir = resolution_sample_dir(root, "2560x1440", "ooparts", item_id)
            other_dir = resolution_sample_dir(root, "1920x1080", "ooparts", item_id)
            assert exact_dir is not None and other_dir is not None
            exact_dir.mkdir(parents=True)
            other_dir.mkdir(parents=True)
            Image.new("RGB", (4, 4), "red").save(exact_dir / "exact.png")
            Image.new("RGB", (4, 4), "blue").save(other_dir / "other.png")

            catalog = scanner._inventory_detail_template_catalog_for_scan("ooparts")
            paths = [path for candidate_id, path in catalog if candidate_id == item_id]

            self.assertTrue(paths[0].endswith("exact.png"))
            self.assertIn(bundled, paths)
            self.assertFalse(any(path.endswith("other.png") for path in paths))

    def test_multiple_samples_for_one_item_do_not_count_as_competing_items(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            scanner = Scanner({}, inventory_detail_override_dir=root, inventory_capture_resolution=(2560, 1440))
            item_id, bundled = scanner._inventory_detail_template_catalog_for_scan("ooparts")[0]
            sample_dir = resolution_sample_dir(root, "2560x1440", "ooparts", item_id)
            assert sample_dir is not None
            sample_dir.mkdir(parents=True)
            sample = Image.open(bundled).convert("RGB")
            sample.save(sample_dir / "first.png")
            sample.save(sample_dir / "second.png")

            matched_id, score = scanner._match_inventory_detail_crop(sample, "ooparts")

            self.assertEqual(item_id, matched_id)
            self.assertGreaterEqual(score, 0.88)

    def test_confirmed_review_saves_account_local_resolution_sample(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            app = App.__new__(App)
            app._storage = SimpleNamespace(root=Path(tmp))
            app._overlay = SimpleNamespace(add_log=lambda _message: None)
            item = ItemEntry(
                name="Test item",
                quantity="12",
                item_id="Item_Icon_Test",
                source="item",
                scan_meta={
                    "profile_id": "ooparts",
                    "review_confirmed": True,
                    "capture_resolution": "2560x1440",
                },
                detail_crop=Image.new("RGB", (8, 8), "red"),
                detail_name_crop=Image.new("RGB", (8, 4), "white"),
            )

            saved = app._save_confirmed_inventory_templates(
                [{"item": item}],
                {"scan_id": "2026-07-12_110000", "window_size": [1920, 1080]},
            )

            self.assertEqual(1, saved)
            detail_path = Path(item.scan_meta["user_template_path"])
            name_path = Path(item.scan_meta["user_name_template_path"])
            self.assertTrue(detail_path.exists())
            self.assertTrue(name_path.exists())
            self.assertIn("2560x1440", detail_path.parts)
            self.assertEqual("Item_Icon_Test", detail_path.parent.name)
            self.assertEqual("2026-07-12_110000.png", detail_path.name)

            second_saved = app._save_confirmed_inventory_templates(
                [{"item": item}],
                {"scan_id": "2026-07-12_110000", "window_size": [1920, 1080]},
            )
            self.assertEqual(1, second_saved)
            self.assertEqual("2026-07-12_110000_2.png", Path(item.scan_meta["user_template_path"]).name)

    def test_unconfirmed_or_unknown_resolution_rows_do_not_train_samples(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            app = App.__new__(App)
            app._storage = SimpleNamespace(root=Path(tmp))
            app._overlay = SimpleNamespace(add_log=lambda _message: None)
            unconfirmed = ItemEntry(
                name="Unconfirmed",
                quantity="1",
                item_id="Item_Icon_Unconfirmed",
                scan_meta={"profile_id": "ooparts", "capture_resolution": "2560x1440"},
                detail_crop=Image.new("RGB", (4, 4), "red"),
            )
            unknown_resolution = ItemEntry(
                name="Unknown resolution",
                quantity="1",
                item_id="Item_Icon_Unknown",
                scan_meta={"profile_id": "ooparts", "review_confirmed": True},
                detail_crop=Image.new("RGB", (4, 4), "blue"),
            )

            saved = app._save_confirmed_inventory_templates(
                [{"item": unconfirmed}, {"item": unknown_resolution}],
                {"scan_id": "scan", "window_size": [None, None]},
            )

            self.assertEqual(0, saved)
            self.assertFalse((Path(tmp) / "templates").exists())


if __name__ == "__main__":
    unittest.main()
