"""FB-3s focused regression draft; run in backend only after master product assignment."""
from __future__ import annotations

import json
from pathlib import Path
from threading import Event
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, Mock, patch

from core import inventory_catalog as catalog
from core.inventory_navigation import CATEGORY_FILTERS, InventoryNavigation
from core.scanner_session import ScannerError


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_SCAN = (
    "equipment", "activity_reports", "tech_notes", "tactical_bd",
    "ooparts", "presents", "student_elephs",
)
EXPECTED_ITEM = EXPECTED_SCAN[1:]


class InventoryScanSupportFB3sTests(unittest.TestCase):
    def test_existing_support_values_and_order_remain_exact(self) -> None:
        self.assertEqual(EXPECTED_SCAN, catalog.SCAN_PROFILES)
        self.assertEqual(EXPECTED_ITEM, catalog.ITEM_SCAN_PROFILES)
        self.assertEqual(set(EXPECTED_ITEM), set(CATEGORY_FILTERS))
        self.assertNotIn("equipment", CATEGORY_FILTERS)

    def test_catalog_only_profiles_do_not_expand_scan_support(self) -> None:
        old = tuple(catalog.CATALOG)
        extra = (
            catalog.InventoryCatalogRow("synthetic:currency", None, "Synthetic currency", "synthetic", "currencies", 2, False),
            catalog.InventoryCatalogRow("synthetic:unknown", None, "Synthetic future", "synthetic", "unreviewed_profile", 0, False),
        )
        expanded = old + extra
        self.assertEqual(EXPECTED_SCAN, catalog._scan_profiles_for_catalog(expanded))
        self.assertEqual(EXPECTED_ITEM, catalog._SUPPORTED_ITEM_SCAN_PROFILES)
        self.assertEqual([row.to_dict() for row in old], [row.to_dict() for row in expanded[:-2]])
        self.assertNotEqual(catalog._catalog_revision([row.to_dict() for row in old]),
                            catalog._catalog_revision([row.to_dict() for row in expanded]))
        self.assertEqual(old, tuple(catalog.CATALOG))

    def test_catalog_iteration_order_does_not_reorder_scanner_support(self) -> None:
        self.assertEqual(EXPECTED_SCAN, catalog._scan_profiles_for_catalog(reversed(catalog.CATALOG)))

    def test_missing_supported_catalog_profile_fails_without_unknown_fallback(self) -> None:
        for missing in EXPECTED_SCAN:
            rows = tuple(row for row in catalog.CATALOG if row.profile_id != missing)
            with self.subTest(profile=missing), self.assertRaisesRegex(RuntimeError, missing):
                catalog._scan_profiles_for_catalog(rows)

    def test_schema_start_request_profile_enum_remains_exact(self) -> None:
        schema = json.loads((ROOT / "contracts/scanner-protocol-v1.schema.json").read_text(encoding="utf-8"))
        definition = next(item for item in schema["$defs"]["request"]["allOf"][1]["oneOf"]
                          if item["properties"]["method"].get("const") == "scanner.session.start")
        enum = definition["properties"]["payload"]["properties"]["inventory_scan_profile"]["enum"]
        self.assertEqual(list(EXPECTED_SCAN), enum)
        self.assertNotIn("currencies", enum)
        self.assertNotIn("unreviewed_profile", enum)

    def test_coin_and_unknown_controls_never_reach_capture(self) -> None:
        nav = object.__new__(InventoryNavigation)
        nav.capture = Mock()
        nav.regions = {"controls": {}}
        nav.trace = []
        for name in ("coin_filter", "other_filter", "collectible_filter", "unreviewed_filter"):
            with self.subTest(control=name), self.assertRaises(ScannerError) as exc:
                nav.click({}, Event(), name)
            self.assertEqual("control_not_allowed", exc.exception.code)
        nav.capture.click.assert_not_called()

    def test_catalog_only_profiles_cannot_prepare_item_or_equipment(self) -> None:
        for source in ("item", "equipment"):
            for profile in ("currencies", "unreviewed_profile"):
                nav = object.__new__(InventoryNavigation)
                nav.detail_recognizer = SimpleNamespace(classify=lambda _: source)
                nav.open_menu = Mock(side_effect=AssertionError("unsupported profile reached menu"))
                with self.subTest(source=source, profile=profile), self.assertRaises(ScannerError) as exc:
                    nav.prepare({"inventory_scan_profile": profile}, Event(), object())
                expected = "inventory_profile_required" if source == "item" else "inventory_profile_mismatch"
                self.assertEqual(expected, exc.exception.code)
                nav.open_menu.assert_not_called()

    def test_equipment_retains_its_dedicated_prepare_path(self) -> None:
        nav = object.__new__(InventoryNavigation)
        nav.detail_recognizer = SimpleNamespace(classify=lambda _: "equipment")
        nav.open_menu = MagicMock()
        nav.ensure_sort = Mock(return_value=True)
        nav.switch_tab = Mock()
        nav.ensure_category = Mock()
        nav.click = Mock()
        frame = Mock()
        nav.observe = Mock(return_value=frame)
        target = {"inventory_scan_profile": "equipment"}
        cancel = Event()
        result = nav.prepare(target, cancel, object())
        nav.open_menu.assert_called_once_with(target, cancel, "equipment")
        nav.ensure_sort.assert_called_once_with(target, cancel, "equipment", "equipment")
        nav.click.assert_called_once_with(target, cancel, "eq_filter_confirm_button")
        nav.switch_tab.assert_not_called()
        nav.ensure_category.assert_not_called()
        frame.close.assert_called_once_with()
        self.assertEqual(("equipment", "equipment", True, True),
                         (result.source, result.profile_id, result.filter_verified, result.sort_verified))


if __name__ == "__main__":
    unittest.main()
